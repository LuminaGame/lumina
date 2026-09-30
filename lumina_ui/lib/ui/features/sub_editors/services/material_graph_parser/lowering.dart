part of '../material_graph_parser.dart';

// ---------------------------------------------------------------------------
// Lowering into nodes
// ---------------------------------------------------------------------------

/// A value during lowering: a node output, or a literal not yet given a node.
class _Val {
  final String? nodeId;
  final String? pinId;
  final List<double>? literal;
  final MaterialValueType type;

  /// `vec3(x)` of a float: the float, which every consumer broadcasts.
  final int? broadcastTo;

  const _Val.node(this.nodeId, this.pinId, this.type, {this.broadcastTo}) : literal = null;
  _Val.lit(List<double> values, {this.broadcastTo})
      : literal = values,
        nodeId = null,
        pinId = null,
        type = MaterialValueType.ofWidth(values.length);

  bool get isLiteral => literal != null;
  bool get isScalarLiteral => literal != null && literal!.length == 1;

  /// Width as a `vecN(...)` argument sees it.
  int get argWidth => broadcastTo ?? type.width;

  _Val withBroadcast(int n) =>
      isLiteral ? _Val.lit(literal!, broadcastTo: n) : _Val.node(nodeId, pinId, type, broadcastTo: n);
}

class _Helper {
  final String name;
  final String returnType;
  final List<String> params;
  final String body;
  final String? description;
  _Helper(this.name, this.returnType, this.params, this.body, this.description);
}

const _componentWise1 = {
  'abs', 'sign', 'floor', 'ceil', 'fract', 'sin', 'cos', 'tan', 'asin', 'acos', 'exp', 'exp2', 'log', 'log2', //
  'sqrt', 'inversesqrt', 'radians', 'degrees', 'saturate', 'round', 'trunc',
};

const _componentWise2 = {'min', 'max', 'mod', 'step', 'atan'};

/// Filament getters and shading globals with a known type: read through a
/// Custom expression node.
const _knownValues = {
  'getWorldCameraPosition()': MaterialValueType.float3,
  'getWorldNormalVector()': MaterialValueType.float3,
  'getWorldViewVector()': MaterialValueType.float3,
  'getWorldReflectedVector()': MaterialValueType.float3,
  'getWorldGeometricNormalVector()': MaterialValueType.float3,
  'getNdotV()': MaterialValueType.float1,
  'getResolution()': MaterialValueType.float4,
  'getUserTime()': MaterialValueType.float4,
  'shading_normal': MaterialValueType.float3,
  'shading_view': MaterialValueType.float3,
  'shading_position': MaterialValueType.float3,
  'shading_reflected': MaterialValueType.float3,
  'shading_NoV': MaterialValueType.float1,
};

/// The vertex block's getters with a known type, read through a Custom
/// expression node (`getPosition()` is the object-space position).
const _vertexKnownValues = {
  'getUserTime()': MaterialValueType.float4,
  'getPosition()': MaterialValueType.float4,
};

/// Fragment getters and the generator's fragment helpers: the vertex block
/// reads `material.uv0` / `material.color` instead, and has no shading values.
const _fragmentOnlyCalls = {
  'texture',
  'getUV0',
  'getUV1',
  'getColor',
  'lumina_fresnel',
  'getUserWorldPosition',
  'getWorldPosition',
  'getWorldNormalVector',
  'getWorldViewVector',
  'getWorldReflectedVector',
  'getWorldGeometricNormalVector',
  'getNdotV',
};

/// Filament's `MaterialInputs` defaults (`initMaterial`), for a field read
/// or compounded before it is assigned.
const _fieldDefaults = <String, List<double>>{
  'baseColor': [1, 1, 1, 1],
  'metallic': [0],
  'roughness': [1],
  'reflectance': [0.5],
  'ambientOcclusion': [1],
  'emissive': [0, 0, 0, 1],
  'normal': [0, 0, 1],
};

class _Lowering {
  final MatSource src;
  final LuminaBlueprintGraph graph;
  int _ids = 0;

  final Map<String, _Val> _locals = {};
  final Map<String, _Val> _fields = {};
  final Map<String, String> _paramNodes = {};
  final Map<String, String> _shared = {};
  final Map<String, _Helper> _helpers = {};
  final Set<String> _usedSamplers = {};
  late final Map<String, MatParameterDecl> _decls = {for (final p in src.parameters) p.name: p};
  late final List<String> _declOrder = [for (final p in src.parameters) p.name];

  _Lowering(this.src, {LuminaBlueprintGraph? graph}) : graph = graph ?? LuminaBlueprintGraph();

  String _newId() => 'n${++_ids}';

  LuminaBlueprintNode _add(String kind, [Map<String, dynamic>? literals]) {
    final node = MaterialNodes.create(kind, id: _newId(), literals: literals);
    graph.nodes.add(node);
    return node;
  }

  void _wire(String fromNode, String fromPin, String toNode, String toPin) {
    graph.wires.removeWhere((w) => w.toNodeId == toNode && w.toPinId == toPin);
    graph.wires.add(LuminaBlueprintWire(
      id: 'w${graph.wires.length + 1}_$toNode$toPin',
      fromNodeId: fromNode,
      fromPinId: fromPin,
      toNodeId: toNode,
      toPinId: toPin,
    ));
  }

  void _retitle(LuminaBlueprintNode n) => n.title = MaterialNodes.titleOf(n);

  // -- Entry --------------------------------------------------------------

  /// Why the vertex block was kept as written, and other things a later
  /// graph edit will not keep.
  final List<String> notes = [];

  /// Lowering the vertex block (`materialVertex`) rather than the fragment.
  bool _vertex = false;

  late final List<MatVariableDecl> _variables = src.variables;

  /// What the vertex block writes to each declared variable, in write order.
  final Map<String, _Val> _vertexWrites = {};

  void run(String fragmentBody, {String? vertexBody}) {
    final output = MaterialNodes.ensureOutput(graph, materialName: src.materialName);
    final written = vertexBody == null ? const <String>{} : _runVertex(vertexBody, output);
    final body = _scanTopLevel(fragmentBody);
    _statements(_lex(body));
    _wireOutputs();
    declareHeaderParameters(unusedOnly: true);
    _keepUncalledHelpers();
    output.literals['extraVariables'] = [
      for (final v in _variables)
        if (!written.contains(v.name)) v.raw.render(),
    ];
  }

  void _keepUncalledHelpers() {
    for (final h in _helpers.values.where((h) => h.name.startsWith('lumina_custom_') && !_calledHelpers.contains(h.name))) {
      // A Custom helper nothing calls: keep it visible as a node.
      _customNodeFor(h);
    }
  }

  /// Lowers the vertex block into Set Vertex Variable nodes, one per
  /// declared variable it writes; returns the names written. A block that
  /// writes no variable, or does anything the graph cannot express (moves
  /// vertices, writes `material.color`, control flow), leaves the graph
  /// untouched and stays as written.
  Set<String> _runVertex(String body, LuminaBlueprintNode output) {
    final nodeCount = graph.nodes.length;
    final wireCount = graph.wires.length;
    final ids = _ids;
    final paramNodes = Map.of(_paramNodes);
    final shared = Map.of(_shared);
    final usedSamplers = Set.of(_usedSamplers);
    void rollback() {
      graph.nodes.removeRange(nodeCount, graph.nodes.length);
      graph.wires.removeRange(wireCount, graph.wires.length);
      _ids = ids;
      _paramNodes
        ..clear()
        ..addAll(paramNodes);
      _shared
        ..clear()
        ..addAll(shared);
      _usedSamplers
        ..clear()
        ..addAll(usedSamplers);
    }

    _vertex = true;
    try {
      final p = _Parser(_lex(_scanTopLevel(body, entry: 'materialVertex')));
      while (!p.done) {
        _statement(p);
      }
      if (_vertexWrites.isEmpty) {
        rollback();
        return const {};
      }
      for (final (index, decl) in _variables.indexed) {
        final value = _vertexWrites[decl.name];
        if (value == null) continue;
        final node = _add(MaterialNodes.setVertexVariable, {
          'name': decl.name,
          'declOrder': index,
          if (decl.precision != null) 'precision': decl.precision,
        });
        _retitle(node);
        _input(node, 'value', value, inline: false);
      }
      _keepUncalledHelpers();
      output.literals['vertexGraph'] = true;
      return _vertexWrites.keys.toSet();
    } on _Unsupported catch (e) {
      rollback();
      output.literals['vertexVerbatim'] = e.reason;
      notes.add('The vertex block is kept as written: ${e.reason}.');
      return const {};
    } finally {
      _vertex = false;
      _locals.clear();
      _helpers.clear();
      _calledHelpers.clear();
      _vertexWrites.clear();
    }
  }

  final Set<String> _calledHelpers = {};

  /// Collects the block's functions; returns the body of its [entry]
  /// function (`material()`, or `materialVertex()` for the vertex block).
  String _scanTopLevel(String s, {String entry = 'material'}) {
    final what = _vertex ? 'vertex block' : 'fragment';
    var i = 0;
    String? materialBody;
    String? pendingDescription;
    while (i < s.length) {
      final ws = RegExp(r'\s+').matchAsPrefix(s, i);
      if (ws != null) {
        i = ws.end;
        continue;
      }
      final comment = RegExp(r'//([^\n]*)').matchAsPrefix(s, i);
      if (comment != null) {
        final text = comment.group(1)!.trim();
        if (text.startsWith('Custom:')) pendingDescription = text.substring(7).trim();
        i = comment.end;
        continue;
      }
      final block = RegExp(r'/\*[\s\S]*?\*/').matchAsPrefix(s, i);
      if (block != null) {
        i = block.end;
        continue;
      }
      final fn = RegExp(r'([A-Za-z_][A-Za-z0-9_]*)\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(([^)]*)\)\s*\{').matchAsPrefix(s, i);
      if (fn == null) throw _Unsupported('the $what has top-level code other than functions');
      final open = fn.end - 1;
      final close = MatSource.matchingBrace(s, open);
      final inner = s.substring(open + 1, close);
      final name = fn.group(2)!;
      if (name == entry) {
        final inputs = _vertex ? 'MaterialVertexInputs' : 'MaterialInputs';
        if (fn.group(1) != 'void' || !RegExp('^\\s*inout\\s+$inputs\\s+material\\s*\$').hasMatch(fn.group(3)!)) {
          throw _Unsupported('$entry() has an unexpected signature');
        }
        materialBody = inner;
      } else if (name == 'lumina_fresnel') {
        // The generator's own helper; regenerated from the Fresnel node.
      } else if (name.startsWith('lumina_custom_')) {
        final params = <String>[];
        for (final p in fn.group(3)!.split(',').map((p) => p.trim()).where((p) => p.isNotEmpty)) {
          final parts = p.split(RegExp(r'\s+'));
          if (parts.length != 2) throw _Unsupported('Custom helper $name has an unexpected parameter');
          params.add(parts[1]);
        }
        _helpers[name] = _Helper(name, fn.group(1)!, params, _dedent(inner), pendingDescription);
      } else {
        throw _Unsupported('the $what defines a function the graph has no node for ($name)');
      }
      pendingDescription = null;
      i = close + 1;
    }
    if (materialBody == null) throw _Unsupported('the $what has no $entry() function');
    return materialBody;
  }

  static String _dedent(String body) {
    final lines = body.split('\n');
    while (lines.isNotEmpty && lines.first.trim().isEmpty) {
      lines.removeAt(0);
    }
    while (lines.isNotEmpty && lines.last.trim().isEmpty) {
      lines.removeLast();
    }
    final indents = [
      for (final l in lines)
        if (l.trim().isNotEmpty) l.length - l.trimLeft().length,
    ];
    final cut = indents.isEmpty ? 0 : indents.reduce(math.min);
    return lines.map((l) => l.length >= cut ? l.substring(cut) : l.trimLeft()).join('\n');
  }

  // -- Statements ---------------------------------------------------------

  bool _prepared = false;

  void _statements(List<_Tok> tokens) {
    final p = _Parser(tokens);
    while (!p.done) {
      _statement(p);
    }
    if (!_prepared) throw _Unsupported('material() never calls prepareMaterial(material)');
  }

  static const _types = {'float': 1, 'vec2': 2, 'vec3': 3, 'vec4': 4};

  void _statement(_Parser p) {
    final first = p.next();
    if (!first.isIdent) throw _Unsupported("unexpected '${first.text}' in material()");
    final word = first.text;
    if (const {'if', 'for', 'while', 'do', 'return', 'switch', 'discard', 'else', 'break', 'continue'}.contains(word)) {
      throw _Unsupported("'$word' statements have no material node");
    }
    if (word == 'prepareMaterial') {
      if (_vertex) throw _Unsupported('prepareMaterial belongs in the fragment');
      p.expect('(');
      final arg = p.next();
      if (arg.text != 'material') throw _Unsupported('prepareMaterial takes material');
      p.expect(')');
      p.expect(';');
      if (_prepared) throw _Unsupported('prepareMaterial is called twice');
      _prepared = true;
      return;
    }
    var typeWord = word;
    if (const {'const', 'highp', 'mediump', 'lowp'}.contains(typeWord)) {
      typeWord = p.next().text;
      if (const {'highp', 'mediump', 'lowp'}.contains(typeWord)) typeWord = p.next().text;
    }
    if (_types.containsKey(typeWord)) {
      final name = p.next();
      if (!name.isIdent) throw _Unsupported('expected a variable name');
      if (p.peek != '=') throw _Unsupported('a declaration without a value has no material node');
      p.next();
      final value = _lower(p.expr());
      p.expect(';');
      if (value.argWidth != _types[typeWord]) {
        throw _Unsupported('$typeWord ${name.text} is given a ${value.type.label}');
      }
      _locals[name.text] = _bindLocal(name.text, value);
      return;
    }
    // An assignment: local, material field, or baseColor.a / baseColor.rgb.
    final path = <String>[word];
    while (p.peek == '.') {
      p.next();
      path.add(p.next().text);
    }
    final op = p.next().text;
    if (!const {'=', '+=', '-=', '*=', '/='}.contains(op)) throw _Unsupported("unexpected '$op' after ${path.join('.')}");
    final rhs = p.expr();
    p.expect(';');
    if (path.length == 1) {
      final current = _locals[word];
      if (current == null) throw _Unsupported("'$word' is not declared");
      final value = op == '=' ? _lower(rhs) : _arith(op.substring(0, 1), current, _lower(rhs));
      _locals[word] = value;
      return;
    }
    if (path.first != 'material') throw _Unsupported('only material fields and locals can be assigned');
    if (_vertex) {
      _assignVariable(path.sublist(1), op, rhs);
      return;
    }
    _assignField(path.sublist(1), op, rhs);
  }

  /// `material.<variable> = …;` in the vertex block: what a Set Vertex
  /// Variable writes. Anything else the vertex block writes has no node.
  void _assignVariable(List<String> path, String op, _E rhs) {
    final field = path.first;
    if (!_variables.any((v) => v.name == field)) {
      throw _Unsupported('it writes material.${path.join('.')}, which has no node (Set Vertex Variable writes the '
          'declared variables only)');
    }
    if (path.length != 1) throw _Unsupported('it writes part of material.$field (material.${path.join('.')})');
    if (op != '=') throw _Unsupported('it compounds material.$field ($op)');
    _vertexWrites[field] = _variableValue(rhs);
  }

  /// A variable's value, without the widening to vec4 the codegen writes:
  /// `vec4(x)` of a float, `vec4(xy, 0.0, 1.0)`, `vec4(xyz, 1.0)`.
  _Val _variableValue(_E rhs) {
    if (rhs is _Call && rhs.callee == 'vec4' && rhs.args.isNotEmpty) {
      final vals = [for (final a in rhs.args) _lower(a)];
      final first = vals.first;
      if (vals.length == 1 && first.type == MaterialValueType.float1 && first.broadcastTo == null) return first;
      final rest = vals.skip(1).toList();
      if (first.broadcastTo == null && rest.isNotEmpty && rest.every((v) => v.isScalarLiteral && v.broadcastTo == null)) {
        final tail = [for (final v in rest) v.literal!.single];
        final widened = switch (first.type) {
          MaterialValueType.float3 => tail.length == 1 && tail[0] == 1.0,
          MaterialValueType.float2 => tail.length == 2 && tail[0] == 0.0 && tail[1] == 1.0,
          _ => false,
        };
        if (widened) return first;
      }
      return _constructVals('vec4', vals);
    }
    final v = _lower(rhs);
    if (v.argWidth != 4 || v.broadcastTo != null) throw _Unsupported('a variable is a float4, it is given a ${v.type.label}');
    return v;
  }

  /// A literal bound to a local becomes a Constant node named after it, so a
  /// generated `float k = 2.0;` reads back as the Constant it came from.
  _Val _bindLocal(String name, _Val value) {
    if (value.isLiteral && value.broadcastTo == null) {
      final node = _constantNode(value.literal!);
      node.literals['varName'] = name;
      return _Val.node(node.id, 'out', value.type);
    }
    final id = value.nodeId;
    if (id != null) {
      final node = graph.node(id)!;
      final base = MaterialNodes.outputsOf(node).length > 1 ? 'rgba' : 'out';
      if (value.pinId == base && node.literals['varName'] == null && value.broadcastTo == null) {
        node.literals['varName'] = name;
      }
    }
    return value;
  }

  void _assignField(List<String> path, String op, _E rhs) {
    final field = path.first;
    if (!_fieldDefaults.containsKey(field)) throw _Unsupported("material.$field has no Material output pin");
    if (field == 'normal' && _prepared) {
      throw _Unsupported('material.normal is set after prepareMaterial, where Filament ignores it');
    }
    if (field != 'normal' && !_prepared && _readsShading(rhs)) {
      throw _Unsupported('material.$field reads shading values before prepareMaterial');
    }
    if (path.length == 2 && field == 'baseColor') {
      final swizzle = path[1];
      if (op != '=') throw _Unsupported('compound assignment to material.baseColor.$swizzle');
      if (swizzle == 'a' || swizzle == 'w') {
        _fields['opacity'] = _lower(rhs);
        return;
      }
      if (swizzle == 'rgb' || swizzle == 'xyz') {
        _fields['baseColor'] = _lower(rhs);
        return;
      }
    }
    if (path.length != 1) throw _Unsupported('material.${path.join('.')} has no Material output pin');

    if (op == '=') {
      // vec4(color, alpha) into baseColor / emissive: the colour is the pin's
      // value, the alpha is Opacity (1.0 is the default and needs no wire).
      if ((field == 'baseColor' || field == 'emissive') && rhs is _Call && rhs.callee == 'vec4' && rhs.args.length == 2) {
        final rgb = _lower(rhs.args[0]);
        final alpha = _lower(rhs.args[1]);
        if (rgb.argWidth == 3 && alpha.type == MaterialValueType.float1) {
          final opaque = alpha.isScalarLiteral && alpha.literal!.single == 1.0;
          if (field == 'baseColor') {
            _fields['baseColor'] = rgb;
            if (opaque) {
              _fields.remove('opacity');
            } else {
              _fields['opacity'] = alpha;
            }
            return;
          }
          if (opaque) {
            _fields['emissive'] = rgb;
            return;
          }
          _fields['emissive'] = _append(rgb, alpha);
          return;
        }
      }
      if (field == 'normal' && rhs is _Mem && (rhs.name == 'xyz' || rhs.name == 'rgb')) {
        final inner = _lower(rhs.target);
        if (inner.type == MaterialValueType.float4) {
          _fields['normal'] = inner;
          return;
        }
      }
      _fields[field] = _lower(rhs);
      return;
    }
    _fields[field] = _arith(op.substring(0, 1), _currentField(field), _lower(rhs));
  }

  _Val _currentField(String field) {
    if (field == 'baseColor' && _fields.containsKey('baseColor') && _fields['baseColor']!.argWidth == 3) {
      // A split vec4(rgb, alpha) assignment: put it back together.
      final alpha = _fields.remove('opacity') ?? _Val.lit([1.0]);
      final whole = _append(_fields['baseColor']!, alpha);
      return whole;
    }
    return _fields[field] ?? _Val.lit(List.of(_fieldDefaults[field]!));
  }

  bool _readsShading(_E e) => switch (e) {
        _Id(:final name) => name.startsWith('shading_'),
        _Call(:final callee, :final args) =>
          callee == 'lumina_fresnel' || callee.startsWith('getWorld') || args.any(_readsShading),
        _Mem(:final target) => _readsShading(target),
        _Bin(:final a, :final b) => _readsShading(a) || _readsShading(b),
        _Neg(:final e) => _readsShading(e),
        _Num() || _ValExpr() => false,
      };

  // -- Expressions --------------------------------------------------------

  _Val _lower(_E e) {
    switch (e) {
      case _Num(:final value):
        return _Val.lit([value]);
      case _Neg(:final e):
        return _arith('*', _lower(e), _Val.lit([-1.0]));
      case _Id(:final name):
        final local = _locals[name];
        if (local != null) return local;
        if (!_vertex && name.startsWith('variable_')) {
          final variable = name.substring('variable_'.length);
          if (_variables.any((v) => v.name == variable)) return _readVariable(variable);
        }
        final known = (_vertex ? _vertexKnownValues : _knownValues)[name];
        if (known != null) return _customExpr('return $name;', const [], known);
        throw _Unsupported("'$name' is not declared");
      case _Bin(:final op, :final a, :final b):
        if (op == '-' && a is _Num && a.value == 1.0 && b is! _Num) {
          final v = _lower(b);
          final node = _add(MaterialNodes.oneMinus);
          _input(node, 'in', v);
          return _out(node, v.type);
        }
        final uvIndex = switch (a) {
          _Call(callee: 'getUV0', args: []) when !_vertex => 0,
          _Call(callee: 'getUV1', args: []) when !_vertex => 1,
          _Mem(target: _Id(name: 'material'), name: 'uv0') when _vertex => 0,
          _Mem(target: _Id(name: 'material'), name: 'uv1') when _vertex => 1,
          _ => null,
        };
        if (op == '*' && uvIndex != null && b is _Call && b.callee == 'vec2') {
          final tiling = _lower(b);
          if (tiling.isLiteral && tiling.literal!.length == 2 && tiling.broadcastTo == null) {
            return _texCoord(uvIndex, tiling.literal![0], tiling.literal![1]);
          }
          return _arith(op, _lower(a), tiling);
        }
        return _arith(op, _lower(a), _lower(b));
      case _Mem(:final target, :final name):
        return _member(target, name);
      case _Call():
        return _call(e);
      case _ValExpr(:final value):
        return value;
    }
  }

  _Val _out(LuminaBlueprintNode node, MaterialValueType type, [String pin = 'out']) => _Val.node(node.id, pin, type);

  /// Connects [v] to [node].[pin]: a float literal stays an inline constant
  /// where the pin has one, anything else is wired.
  void _input(LuminaBlueprintNode node, String pin, _Val v, {bool inline = true}) {
    if (inline && v.isScalarLiteral) {
      final def = MaterialNodes.inputsOf(node).where((p) => p.id == pin).firstOrNull;
      if (def?.defaultValue is num && (def!.defaultValue as num).toDouble() == v.literal!.single) {
        // The pin's own default: nothing to store (a new node reads the same).
        node.literals.remove(pin);
      } else {
        node.literals[pin] = v.literal!.single;
      }
      return;
    }
    final source = _materialize(v);
    _wire(source.nodeId!, source.pinId!, node.id, pin);
  }

  _Val _materialize(_Val v) {
    if (!v.isLiteral) return v;
    final node = _constantNode(v.literal!);
    return _Val.node(node.id, 'out', v.type, broadcastTo: v.broadcastTo);
  }

  LuminaBlueprintNode _constantNode(List<double> values) {
    final kind = switch (values.length) {
      1 => MaterialNodes.constant,
      2 => MaterialNodes.constant2,
      3 => MaterialNodes.constant3,
      _ => MaterialNodes.constant4,
    };
    return _add(kind, {'value': values.length == 1 ? values.single : List<double>.of(values)});
  }

  MaterialValueType _broadcastType(_Val a, _Val b) {
    final ta = a.type, tb = b.type;
    if (ta == tb) return ta;
    if (ta == MaterialValueType.float1) return b.broadcastTo != null ? MaterialValueType.ofWidth(b.broadcastTo!) : tb;
    if (tb == MaterialValueType.float1) return ta;
    throw _Unsupported('arithmetic between ${ta.label} and ${tb.label}');
  }

  _Val _arith(String op, _Val a, _Val b) {
    final kind = switch (op) {
      '+' => MaterialNodes.add,
      '-' => MaterialNodes.subtract,
      '*' => MaterialNodes.multiply,
      '/' => MaterialNodes.divide,
      _ => throw _Unsupported("the '$op' operator has no material node"),
    };
    var type = _broadcastType(a, b);
    for (final v in [a, b]) {
      if (v.broadcastTo != null && v.broadcastTo! > type.width) type = MaterialValueType.ofWidth(v.broadcastTo!);
    }
    final node = _add(kind);
    _input(node, 'a', a);
    _input(node, 'b', b);
    return _out(node, type);
  }

  _Val _append(_Val a, _Val b) {
    final width = a.argWidth + b.argWidth;
    if (width > 4) throw _Unsupported('a vector wider than four components');
    if (a.broadcastTo != null || b.broadcastTo != null) throw _Unsupported('a broadcast inside a vector constructor');
    final node = _add(MaterialNodes.appendVector);
    _input(node, 'a', a, inline: false);
    _input(node, 'b', b, inline: false);
    return _out(node, MaterialValueType.ofWidth(width));
  }

  _Val _texCoord(int index, double u, double v) {
    final key = 'uv$index/$u/$v';
    final existing = _shared[key];
    if (existing != null) return _Val.node(existing, 'out', MaterialValueType.float2);
    final node = _add(MaterialNodes.textureCoordinate, {'index': index, 'uTiling': u, 'vTiling': v});
    _retitle(node);
    _shared[key] = node.id;
    return _out(node, MaterialValueType.float2);
  }

  _Val _sharedNode(String kind, String pin, MaterialValueType type) {
    final id = _shared[kind] ??= _add(kind).id;
    return _Val.node(id, pin, type);
  }

  static final RegExp _swizzle = RegExp(r'^([xyzw]{1,4}|[rgba]{1,4})$');

  /// The one Vertex Variable node reading [name] in the fragment.
  _Val _readVariable(String name) {
    final id = _shared['variable:$name'] ??= () {
      final node = _add(MaterialNodes.vertexVariable, {'name': name});
      _retitle(node);
      return node.id;
    }();
    return _Val.node(id, 'rgba', MaterialValueType.float4);
  }

  /// The one WorldPosition node of [space].
  _Val _worldPosition(String space) {
    final id = _shared['world:$space'] ??= () {
      final node = _add(MaterialNodes.worldPosition, {'space': space});
      _retitle(node);
      return node.id;
    }();
    return _Val.node(id, 'out', MaterialValueType.float3);
  }

  /// `material.worldPosition` in the vertex block.
  static bool _isVertexWorldPosition(_E e) =>
      e is _Mem && e.name == 'worldPosition' && e.target is _Id && (e.target as _Id).name == 'material';

  /// `mulMat4x4Float3(getUserWorldFromWorldMatrix(), material.worldPosition.xyz)`:
  /// the absolute world position the codegen writes in the vertex block.
  static bool _isUserWorldPosition(_E e) =>
      e is _Call &&
      e.callee == 'mulMat4x4Float3' &&
      e.args.length == 2 &&
      e.args[0] is _Call &&
      (e.args[0] as _Call).callee == 'getUserWorldFromWorldMatrix' &&
      (e.args[0] as _Call).args.isEmpty &&
      e.args[1] is _Mem &&
      (e.args[1] as _Mem).name == 'xyz' &&
      _isVertexWorldPosition((e.args[1] as _Mem).target);

  _Val _member(_E target, String name) {
    if (target is _Id && target.name == 'materialParams') return _parameter(name);
    if (_vertex) {
      if (target is _Id && target.name == 'material') {
        switch (name) {
          case 'uv0' || 'uv1':
            return _texCoord(name == 'uv0' ? 0 : 1, 1.0, 1.0);
          case 'color':
            return _sharedNode(MaterialNodes.vertexColor, 'rgba', MaterialValueType.float4);
        }
        final written = _vertexWrites[name];
        if (written != null) return written;
        throw _Unsupported('material.$name has no node in the vertex block');
      }
      if (_isVertexWorldPosition(target)) {
        return _member(_ValExpr(_worldPosition(MaterialNodes.cameraRelativeSpace)), name);
      }
      if (_isUserWorldPosition(target)) {
        return _member(_ValExpr(_worldPosition(MaterialNodes.absoluteSpace)), name);
      }
    }
    if (target is _Id && target.name == 'material') {
      if (!_fieldDefaults.containsKey(name)) throw _Unsupported('material.$name has no Material output pin');
      return _currentField(name);
    }
    if (target is _Call && target.callee == 'getUserTime' && target.args.isEmpty && name == 'x') {
      return _sharedNode(MaterialNodes.time, 'out', MaterialValueType.float1);
    }
    if (!_swizzle.hasMatch(name)) throw _Unsupported(".$name is not a swizzle");
    final v = _lower(target);
    final letters = name.replaceAll('x', 'r').replaceAll('y', 'g').replaceAll('z', 'b').replaceAll('w', 'a');
    final indices = [for (final c in letters.split('')) 'rgba'.indexOf(c)];
    if (indices.any((k) => k >= v.type.width)) throw _Unsupported('.$name reads past a ${v.type.label}');
    if (v.isLiteral) return _Val.lit([for (final k in indices) v.literal![k]]);
    final node = graph.node(v.nodeId!)!;
    final named = MaterialNodes.outputsOf(node).length > 1 && v.pinId == 'rgba';
    if (named) {
      const byLetters = {'rgb': 'rgb', 'r': 'r', 'g': 'g', 'b': 'b', 'a': 'a', 'rgba': 'rgba'};
      final pin = byLetters[letters];
      if (pin != null) return _Val.node(node.id, pin, pin == 'rgba' ? MaterialValueType.float4 : (pin == 'rgb' ? MaterialValueType.float3 : MaterialValueType.float1));
    }
    final ordered = [for (var k = 1; k < indices.length; k++) indices[k] > indices[k - 1]].every((x) => x);
    if (ordered && indices.length == v.type.width) return v;
    if (ordered) {
      final mask = _add(MaterialNodes.componentMask, {for (final c in ['r', 'g', 'b', 'a']) c: letters.contains(c)});
      _retitle(mask);
      _input(mask, 'in', v, inline: false);
      return _out(mask, MaterialValueType.ofWidth(indices.length));
    }
    return _customExpr('return In0.$name;', [v], MaterialValueType.ofWidth(indices.length));
  }

  _Val _parameter(String name) {
    final decl = _decls[name];
    if (decl == null) throw _Unsupported('materialParams.$name is not declared in the header');
    final type = decl.type.toLowerCase();
    if (type == 'float') {
      return _Val.node(_paramNode(decl), 'out', MaterialValueType.float1);
    }
    if (const {'float3', 'float4', 'vec3', 'vec4', 'color'}.contains(type)) {
      return _Val.node(_paramNode(decl), 'rgba', MaterialValueType.float4);
    }
    if (type == 'float2' || type == 'vec2') {
      return _customExpr('return materialParams.$name;', const [], MaterialValueType.float2);
    }
    throw _Unsupported('a ${decl.type} parameter has no material node');
  }

  /// The one node standing for header parameter [decl].
  String _paramNode(MatParameterDecl decl) {
    final existing = _paramNodes[decl.name];
    if (existing != null) return existing;
    final type = decl.type.toLowerCase();
    final LuminaBlueprintNode node;
    if (type == 'float') {
      node = _add(MaterialNodes.scalarParameter, {'name': decl.name, 'default': _number(decl.defaultValue) ?? 0.0});
    } else if (decl.isSampler) {
      node = _add(MaterialNodes.textureParameter, {'name': decl.name});
    } else {
      node = _add(MaterialNodes.vectorParameter, {
        'name': decl.name,
        'default': _vector4(decl.defaultValue),
        if (type != 'float4') 'declType': decl.type,
      });
    }
    node.literals['declOrder'] = _declOrder.indexOf(decl.name);
    _retitle(node);
    _paramNodes[decl.name] = node.id;
    return node.id;
  }

  static double? _number(MatValue? v) => v is MatAtom ? double.tryParse(v.text) : null;

  static List<double> _vector4(MatValue? v) {
    final out = <double>[];
    if (v is MatList) {
      for (final i in v.items) {
        final d = _number(i);
        if (d != null) out.add(d);
      }
    }
    if (out.isEmpty) return [1.0, 1.0, 1.0, 1.0];
    while (out.length < 4) {
      out.add(1.0);
    }
    return out.take(4).toList();
  }

  /// Declared parameters the fragment never reads still get nodes, so a graph
  /// edit keeps them in the header (and in the panel).
  void declareHeaderParameters({required bool unusedOnly}) {
    final extras = <String>[];
    for (final decl in src.parameters) {
      if (unusedOnly && (_paramNodes.containsKey(decl.name) || _usedSamplers.contains(decl.name))) continue;
      final type = decl.type.toLowerCase();
      if (type == 'float' || decl.isSampler || const {'float3', 'float4', 'vec3', 'vec4', 'color'}.contains(type)) {
        _paramNode(decl);
      } else {
        extras.add(decl.raw.render());
      }
    }
    if (extras.isNotEmpty) {
      final output = graph.node(MaterialNodes.outputNodeId)!;
      output.literals['extraParameters'] = extras;
    }
  }

  _Val _call(_Call c) {
    final args = c.args;
    if (_vertex && _fragmentOnlyCalls.contains(c.callee)) {
      throw _Unsupported('${c.callee}() is not available in the vertex block');
    }
    switch (c.callee) {
      case 'getUserWorldPosition' || 'getWorldPosition' when args.isEmpty:
        return _worldPosition(
            c.callee == 'getUserWorldPosition' ? MaterialNodes.absoluteSpace : MaterialNodes.cameraRelativeSpace);
      case 'texture':
        if (args.length != 2 || args[0] is! _Id || !(args[0] as _Id).name.startsWith('materialParams_')) {
          throw _Unsupported('texture() is only read from a material sampler parameter');
        }
        final param = (args[0] as _Id).name.substring('materialParams_'.length);
        _usedSamplers.add(param);
        final node = _add(MaterialNodes.textureSample, {'parameter': param});
        final order = _declOrder.indexOf(param);
        if (order >= 0) node.literals['declOrder'] = order;
        _retitle(node);
        final uv = args[1];
        if (!(uv is _Call && uv.callee == 'getUV0' && uv.args.isEmpty)) {
          _input(node, 'uvs', _lower(uv), inline: false);
        }
        return _out(node, MaterialValueType.float4, 'rgba');
      case 'getUV0':
      case 'getUV1':
        if (args.isNotEmpty) throw _Unsupported('${c.callee} takes no arguments');
        return _texCoord(c.callee == 'getUV0' ? 0 : 1, 1.0, 1.0);
      case 'getColor':
        return _sharedNode(MaterialNodes.vertexColor, 'rgba', MaterialValueType.float4);
      case 'mix':
        _arity(c, 3);
        final a = _lower(args[0]), b = _lower(args[1]), t = _lower(args[2]);
        final node = _add(MaterialNodes.lerp);
        _input(node, 'a', a);
        _input(node, 'b', b);
        _input(node, 'alpha', t);
        return _out(node, _broadcastType(a, b));
      case 'clamp':
        _arity(c, 3);
        final x = _lower(args[0]);
        final node = _add(MaterialNodes.clamp);
        _input(node, 'in', x, inline: false);
        _input(node, 'min', _lower(args[1]));
        _input(node, 'max', _lower(args[2]));
        return _out(node, x.type);
      case 'pow':
        _arity(c, 2);
        final x = _lower(args[0]);
        final node = _add(MaterialNodes.power);
        _input(node, 'base', x, inline: false);
        _input(node, 'exp', _lower(args[1]));
        return _out(node, x.type);
      case 'dot':
        _arity(c, 2);
        final node = _add(MaterialNodes.dot);
        _input(node, 'a', _lower(args[0]), inline: false);
        _input(node, 'b', _lower(args[1]), inline: false);
        return _out(node, MaterialValueType.float1);
      case 'normalize':
        _arity(c, 1);
        final x = _lower(args[0]);
        final node = _add(MaterialNodes.normalize);
        _input(node, 'in', x, inline: false);
        return _out(node, x.type);
      case 'lumina_fresnel':
        _arity(c, 2);
        final node = _add(MaterialNodes.fresnel);
        _input(node, 'exponent', _lower(args[0]));
        _input(node, 'base_reflect_fraction', _lower(args[1]));
        return _out(node, MaterialValueType.float1);
      case 'float':
      case 'vec2':
      case 'vec3':
      case 'vec4':
        return _construct(c);
    }
    final helper = _helpers[c.callee];
    if (helper != null) {
      _calledHelpers.add(helper.name);
      if (args.length != helper.params.length) throw _Unsupported('${c.callee} is called with ${args.length} arguments');
      final node = _customNodeFor(helper);
      for (var k = 0; k < args.length; k++) {
        _input(node, helper.params[k], _lower(args[k]), inline: false);
      }
      final out = MaterialValueType.parse(helper.returnType);
      if (out == null) throw _Unsupported('${c.callee} returns ${helper.returnType}');
      return _out(node, out);
    }
    if (args.isEmpty) {
      final known = (_vertex ? _vertexKnownValues : _knownValues)['${c.callee}()'];
      if (known != null) return _customExpr('return ${c.callee}();', const [], known);
    }
    if (_componentWise1.contains(c.callee) && args.length == 1) {
      final x = _lower(args[0]);
      return _customCall(c.callee, [x], x.type);
    }
    if ((_componentWise2.contains(c.callee) && args.length == 2) || (c.callee == 'smoothstep' && args.length == 3)) {
      final vals = [for (final a in args) _lower(a)];
      var type = vals.first.type;
      for (final v in vals.skip(1)) {
        type = _broadcastType(_Val.lit(List.filled(type.width, 0)), v);
      }
      return _customCall(c.callee, vals, type);
    }
    if ((c.callee == 'length' && args.length == 1) || (c.callee == 'distance' && args.length == 2)) {
      return _customCall(c.callee, [for (final a in args) _lower(a)], MaterialValueType.float1);
    }
    if (c.callee == 'cross' && args.length == 2) {
      return _customCall(c.callee, [for (final a in args) _lower(a)], MaterialValueType.float3);
    }
    if (c.callee == 'reflect' && args.length == 2) {
      final vals = [for (final a in args) _lower(a)];
      return _customCall(c.callee, vals, vals.first.type);
    }
    throw _Unsupported('${c.callee}() has no material node');
  }

  void _arity(_Call c, int n) {
    if (c.args.length != n) throw _Unsupported('${c.callee}() takes $n arguments');
  }

  _Val _construct(_Call c) => _constructVals(c.callee, [for (final a in c.args) _lower(a)]);

  _Val _constructVals(String callee, List<_Val> vals) {
    final n = callee == 'float' ? 1 : int.parse(callee.substring(3));
    if (vals.isEmpty) throw _Unsupported('$callee() needs arguments');
    if (vals.length == 1) {
      final v = vals.single;
      if (v.type.width == n && v.broadcastTo == null) return v;
      if (v.type == MaterialValueType.float1) return n == 1 ? v : v.withBroadcast(n);
      if (v.type.width > n) {
        const letters = ['r', 'rg', 'rgb'];
        return _member(_ValExpr(v), letters[n - 1]);
      }
      throw _Unsupported('$callee() of a ${v.type.label}');
    }
    if (vals.every((v) => v.isLiteral && v.broadcastTo == null) && vals.fold<int>(0, (s, v) => s + v.type.width) == n) {
      return _Val.lit([for (final v in vals) ...v.literal!]);
    }
    // Mixed: group consecutive float literals into one Constant, append the rest.
    final parts = <_Val>[];
    final pending = <double>[];
    void flush() {
      if (pending.isEmpty) return;
      parts.add(_Val.lit(List.of(pending)));
      pending.clear();
    }

    for (final v in vals) {
      if (v.isLiteral && v.broadcastTo == null) {
        pending.addAll(v.literal!);
      } else {
        flush();
        parts.add(v);
      }
    }
    flush();
    if (parts.fold<int>(0, (s, v) => s + v.argWidth) != n) throw _Unsupported('$callee() arguments do not add up');
    var acc = parts.first;
    for (final part in parts.skip(1)) {
      acc = _append(acc, part);
    }
    return acc;
  }

  LuminaBlueprintNode _customNodeFor(_Helper h) {
    final node = _add(MaterialNodes.custom, {
      'description': h.description ?? 'Custom',
      'outputType': MaterialValueType.parse(h.returnType)?.label ?? h.returnType,
      'inputs': List<String>.of(h.params),
      'code': h.body,
    });
    _retitle(node);
    return node;
  }

  /// A GLSL built-in the catalog has no node for, as a Custom expression.
  _Val _customCall(String fn, List<_Val> args, MaterialValueType type) {
    final names = <String>[];
    final wired = <_Val>[];
    for (final v in args) {
      if (v.isLiteral && v.broadcastTo == null) {
        names.add(_literalGlsl(v.literal!));
      } else {
        names.add('In${wired.length}');
        wired.add(v);
      }
    }
    return _customExpr('return $fn(${names.join(', ')});', wired, type);
  }

  static String _literalGlsl(List<double> v) =>
      v.length == 1 ? MaterialNodes.formatNumber(v.single) : 'vec${v.length}(${v.map(MaterialNodes.formatNumber).join(', ')})';

  _Val _customExpr(String code, List<_Val> inputs, MaterialValueType type) {
    final node = _add(MaterialNodes.custom, {
      'description': 'Custom',
      'outputType': type.label,
      'inputs': [for (var k = 0; k < inputs.length; k++) 'In$k'],
      'code': code,
    });
    for (var k = 0; k < inputs.length; k++) {
      _input(node, 'In$k', inputs[k], inline: false);
    }
    return _out(node, type);
  }

  // -- Output -------------------------------------------------------------

  void _wireOutputs() {
    const pins = {
      'baseColor': MaterialNodes.baseColor,
      'opacity': MaterialNodes.opacity,
      'metallic': MaterialNodes.metallic,
      'roughness': MaterialNodes.roughness,
      'reflectance': MaterialNodes.specular,
      'ambientOcclusion': MaterialNodes.ambientOcclusion,
      'normal': MaterialNodes.normal,
      'emissive': MaterialNodes.emissive,
    };
    for (final e in pins.entries) {
      final v = _fields[e.key];
      if (v == null) continue;
      final source = _materialize(v);
      _wire(source.nodeId!, source.pinId!, MaterialNodes.outputNodeId, e.value);
    }
  }
}

/// A lowered value handed back to [_Lowering._member] as if it were syntax.
class _ValExpr extends _E {
  final _Val value;
  _ValExpr(this.value);
}
