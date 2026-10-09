part of '../material_graph_parser.dart';

// ---------------------------------------------------------------------------
// Lowering into nodes
// ---------------------------------------------------------------------------

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

class _Lowering with _ControlFlow {
  final MatSource src;
  final LuminaBlueprintGraph graph;
  int _ids = 0;

  @override
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

  @override
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
      _resetLocals();
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

  @override
  void _statement(_Parser p) {
    final first = p.next();
    if (!first.isIdent) throw _Unsupported("unexpected '${first.text}' in material()");
    final word = first.text;
    if (word == 'if') return _ifChain(p);
    if (const {'for', 'while', 'do', 'return', 'switch', 'discard', 'else', 'break', 'continue'}.contains(word)) {
      throw _Unsupported("'$word' statements have no material node");
    }
    if (word == 'prepareMaterial') {
      if (_vertex) throw _Unsupported('prepareMaterial belongs in the fragment');
      if (_branchDepth > 0) throw _Unsupported('an if branch calls prepareMaterial');
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
    if (_localTypes.containsKey(typeWord)) return _declaration(p, typeWord);
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
    if (path.length == 1) return _assignLocal(word, op, rhs);
    if (path.first != 'material') throw _Unsupported('only material fields and locals can be assigned');
    if (_branchDepth > 0) throw _Unsupported('an if branch writes ${path.join('.')}; only branches that assign locals become If nodes');
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
  @override
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
        _Neg(:final e) || _Not(:final e) => _readsShading(e),
        _Cond(:final c, :final t, :final f) => _readsShading(c) || _readsShading(t) || _readsShading(f),
        _Num() || _ValExpr() => false,
      };

  // -- Expressions --------------------------------------------------------

  @override
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
        throw _undeclared(name);
      case _Bin(:final op, :final a, :final b) when _logicOps.contains(op):
        return _logicBin(op, a, b);
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
      case _Cond() || _Not():
        return _logic(e);
    }
  }

  _Val _out(LuminaBlueprintNode node, MaterialValueType type, [String pin = 'out']) => _Val.node(node.id, pin, type);

  /// Connects [v] to [node].[pin]: a float literal stays an inline constant
  /// where the pin has one, anything else is wired.
  @override
  void _input(LuminaBlueprintNode node, String pin, _Val v, {bool inline = true}) {
    _checkBoolPin(node, pin, v);
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

  @override
  MaterialValueType _broadcastType(_Val a, _Val b) {
    final ta = a.type, tb = b.type;
    if (ta == MaterialValueType.boolean || tb == MaterialValueType.boolean) throw _Unsupported('a bool in float math');
    if (ta == tb) return ta;
    if (ta == MaterialValueType.float1) return b.broadcastTo != null ? MaterialValueType.ofWidth(b.broadcastTo!) : tb;
    if (tb == MaterialValueType.float1) return ta;
    throw _Unsupported('arithmetic between ${ta.label} and ${tb.label}');
  }

  @override
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
}
