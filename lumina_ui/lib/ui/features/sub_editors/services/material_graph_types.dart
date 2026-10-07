import 'package:flutter_filament/flutter_filament.dart' show FilamatShading;
import 'package:lumina_editor_data/lumina_editor.dart' show LuminaBlueprintGraph, LuminaBlueprintNode;

import 'package:lumina_ui/ui/features/sub_editors/models/material_graph.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/material_logic_nodes.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/material_vertex_variables.dart';

/// A problem the type checker found on a node (or one of its inputs), worded
/// as a material compiler message.
class MaterialGraphDiagnostic {
  final String? nodeId;
  final String? pinId;
  final String message;
  final bool isError;

  const MaterialGraphDiagnostic(this.message, {this.nodeId, this.pinId, this.isError = true});

  @override
  String toString() => '${isError ? 'error' : 'warning'}${nodeId == null ? '' : ' [$nodeId]'}: $message';
}

/// The resolved types and diagnostics of one material graph.
class MaterialGraphAnalysis {
  final Map<String, MaterialValueType> _outputs;
  final Map<String, MaterialValueType> _inputs;
  final List<MaterialGraphDiagnostic> diagnostics;

  /// Nodes that feed the Material output node (or are it): the fragment.
  final Set<String> reachable;

  /// Nodes that feed a Set Vertex Variable (or are one): the vertex block.
  /// A node can be in both sets; each stage evaluates it.
  final Set<String> vertexReachable;

  const MaterialGraphAnalysis._(this._outputs, this._inputs, this.diagnostics, this.reachable, this.vertexReachable);

  static const MaterialGraphAnalysis empty = MaterialGraphAnalysis._({}, {}, [], {}, {});

  MaterialValueType? outputType(String nodeId, String pinId) => _outputs['$nodeId.$pinId'];
  MaterialValueType? inputType(String nodeId, String pinId) => _inputs['$nodeId.$pinId'];

  bool get hasErrors => diagnostics.any((d) => d.isError);

  Set<String> get errorNodeIds => {for (final d in diagnostics) if (d.isError && d.nodeId != null) d.nodeId!};

  List<MaterialGraphDiagnostic> diagnosticsFor(String nodeId) => [for (final d in diagnostics) if (d.nodeId == nodeId) d];

  /// Whether the wire into [nodeId].[pinId] carries a type error.
  bool inputHasError(String nodeId, String pinId) =>
      diagnostics.any((d) => d.isError && d.nodeId == nodeId && d.pinId == pinId);
}

/// Infers every pin's type (float1–float4 with implicit scalar
/// broadcast, a texture, or a comparison's bool) and reports what cannot
/// compile.
class MaterialGraphChecker {
  final LuminaBlueprintGraph graph;
  final MaterialSurface surface;

  final Map<String, MaterialValueType> _outputs = {};
  final Map<String, MaterialValueType> _inputs = {};
  final Map<String, List<MaterialGraphDiagnostic>> _byNode = {};
  final Set<String> _evaluated = {};
  final Set<String> _visiting = {};

  MaterialGraphChecker._(this.graph, this.surface);

  static MaterialGraphAnalysis check(LuminaBlueprintGraph graph, MaterialSurface surface) =>
      MaterialGraphChecker._(graph, surface)._run();

  MaterialGraphAnalysis _run() {
    for (final n in graph.nodes) {
      _eval(n);
    }
    final reachable = _reachable([MaterialNodes.outputNodeId]);
    final vertexReachable = _reachable([
      for (final n in graph.nodes)
        if (n.registryId == MaterialNodes.setVertexVariable) n.id,
    ]);
    _checkVertexStage(reachable, vertexReachable);
    final diagnostics = <MaterialGraphDiagnostic>[];
    for (final n in graph.nodes) {
      if (!reachable.contains(n.id) && !vertexReachable.contains(n.id) && n.registryId != MaterialNodes.customFragment) {
        continue;
      }
      diagnostics.addAll(_byNode[n.id] ?? const []);
    }
    _checkFresnelIntoNormal(diagnostics);
    return MaterialGraphAnalysis._(Map.of(_outputs), Map.of(_inputs), diagnostics, reachable, vertexReachable);
  }

  /// The vertex stage's rules: what can feed a Set Vertex Variable, the
  /// variable names and matc's limit on them, a hand-written vertex block the
  /// graph would overwrite, and Vertex Variable reads of undeclared names.
  void _checkVertexStage(Set<String> fragment, Set<String> vertex) {
    final setters = [
      for (final n in graph.nodes)
        if (n.registryId == MaterialNodes.setVertexVariable) n,
    ];
    final firstSetter = <String, String>{};
    for (final id in vertex) {
      final n = graph.node(id);
      if (n == null || n.registryId == MaterialNodes.setVertexVariable) continue;
      if (!MaterialNodes.isVertexAvailable(n.registryId)) {
        final feeds = setters.where((s) => _feeds(n.id, s.id)).map((s) => "'${s.literals['name']}'").join(', ');
        _error(n, 'not available in the vertex stage (it feeds Set Vertex Variable $feeds); only constants, '
            'parameters, TexCoord, VertexColor, Time, WorldPosition, math, logic and Custom run per vertex');
      }
    }
    final output = graph.node(MaterialNodes.outputNodeId);
    final handWritten = output?.literals['vertexVerbatim'];
    final extras = {for (final e in MaterialVertexVariables.extraVariables(graph)) ?MaterialVertexVariables.declaredVariableName(e)};
    final usesColor = graph.nodes.any((n) =>
        n.registryId == MaterialNodes.vertexColor && (fragment.contains(n.id) || vertex.contains(n.id)));
    final limit = usesColor ? MaterialNodes.maxVariablesWithColor : MaterialNodes.maxVariables;
    final ordered = List.of(setters)
      ..sort((a, b) {
        final oa = (a.literals['declOrder'] as num?)?.toInt() ?? 1 << 20;
        final ob = (b.literals['declOrder'] as num?)?.toInt() ?? 1 << 20;
        return oa != ob ? oa.compareTo(ob) : graph.nodes.indexOf(a).compareTo(graph.nodes.indexOf(b));
      });
    final names = <String>{...extras};
    for (final s in ordered) {
      final name = s.literals['name'];
      if (handWritten is String) {
        _error(s, 'the vertex block is hand-written code the graph cannot express ($handWritten), and a Set Vertex '
            'Variable would replace it; edit that block in the GLSL tab instead');
      }
      if (name is! String || !_isIdentifier(name) || name.startsWith('gl_')) {
        _error(s, "'$name' is not a valid variable name (a GLSL identifier)");
        continue;
      }
      if (firstSetter.containsKey(name)) {
        _error(s, "'$name' is already written by another Set Vertex Variable");
        continue;
      }
      firstSetter[name] = s.id;
      names.add(name);
      if (names.length > limit) {
        _error(s, 'a material has at most $limit vertex variables'
            '${usesColor ? ' when it reads the vertex colour (the colour takes the fifth)' : ''}; '
            "'$name' is number ${names.length}");
      }
    }
    for (final id in fragment) {
      final n = graph.node(id);
      if (n == null || n.registryId != MaterialNodes.vertexVariable) continue;
      final name = n.literals['name'];
      if (name is! String || !_isIdentifier(name)) {
        _error(n, "'$name' is not a valid variable name");
      } else if (!names.contains(name)) {
        _error(n, "no Set Vertex Variable writes '$name' and the material header does not declare it");
      }
    }
  }

  /// Whether [from] feeds [to] through wires.
  bool _feeds(String from, String to) => _reachable([to]).contains(from);

  Set<String> _reachable(List<String> roots) {
    final out = <String>{};
    final stack = List<String>.of(roots);
    while (stack.isNotEmpty) {
      final id = stack.removeLast();
      if (!out.add(id)) continue;
      for (final w in graph.wires) {
        if (w.toNodeId == id) stack.add(w.fromNodeId);
      }
    }
    return out;
  }

  /// Nodes upstream of the output's Normal pin.
  Set<String> _feedingNormal() {
    final start = graph.wireInto(MaterialNodes.outputNodeId, MaterialNodes.normal);
    if (start == null) return const {};
    final out = <String>{};
    final stack = <String>[start.fromNodeId];
    while (stack.isNotEmpty) {
      final id = stack.removeLast();
      if (!out.add(id)) continue;
      for (final w in graph.wires) {
        if (w.toNodeId == id) stack.add(w.fromNodeId);
      }
    }
    return out;
  }

  void _checkFresnelIntoNormal(List<MaterialGraphDiagnostic> diagnostics) {
    for (final id in _feedingNormal()) {
      final n = graph.node(id);
      if (n?.registryId == MaterialNodes.fresnel) {
        diagnostics.add(MaterialGraphDiagnostic(
          'Fresnel cannot drive Normal: it reads the shading normal that Normal defines',
          nodeId: id,
        ));
      }
    }
  }

  void _error(LuminaBlueprintNode node, String message, {String? pinId}) =>
      (_byNode[node.id] ??= []).add(MaterialGraphDiagnostic('${MaterialNodes.titleOf(node)}: $message', nodeId: node.id, pinId: pinId));

  void _warn(LuminaBlueprintNode node, String message, {String? pinId}) => (_byNode[node.id] ??= [])
      .add(MaterialGraphDiagnostic(message, nodeId: node.id, pinId: pinId, isError: false));

  MaterialValueType? _out(String nodeId, String pinId) {
    final n = graph.node(nodeId);
    if (n == null) return null;
    _eval(n);
    return _outputs['$nodeId.$pinId'];
  }

  /// The type flowing into [pin]: its wire's source, else its constant.
  MaterialValueType? _in(LuminaBlueprintNode node, MaterialPinDef pin) {
    final wire = graph.wireInto(node.id, pin.id);
    MaterialValueType? t;
    if (wire != null) {
      t = _out(wire.fromNodeId, wire.fromPinId);
      if (t == null && _visiting.contains(wire.fromNodeId)) {
        _error(node, 'the graph loops back into ${pin.name}', pinId: pin.id);
      }
    } else {
      final literal = node.literals[pin.id] ?? pin.defaultValue;
      if (literal is num) t = MaterialValueType.float1;
      if (literal is List && literal.isNotEmpty && literal.length <= 4) t = MaterialValueType.ofWidth(literal.length);
    }
    if (t != null) _inputs['${node.id}.${pin.id}'] = t;
    return t;
  }

  /// [pin]'s type, reporting a missing input.
  MaterialValueType? _required(LuminaBlueprintNode node, MaterialPinDef pin) {
    final t = _in(node, pin);
    if (t == null && graph.wireInto(node.id, pin.id) == null) {
      _error(node, "missing input '${pin.name}'", pinId: pin.id);
    }
    if (t == MaterialValueType.texture) {
      _error(node, '${pin.name} cannot take a Texture2D; sample it with a TextureSample', pinId: pin.id);
      return null;
    }
    if (t == MaterialValueType.boolean && pin.type != MaterialValueType.boolean) {
      _error(node, '${pin.name} cannot take a bool; pick a value with an If node', pinId: pin.id);
      return null;
    }
    return t;
  }

  /// A bool input of a logic node (an If's Condition, And / Or / Not).
  void _requiredBool(LuminaBlueprintNode node, MaterialPinDef pin) {
    final t = _in(node, pin);
    if (t == null && graph.wireInto(node.id, pin.id) == null) {
      _error(node, "missing input '${pin.name}'", pinId: pin.id);
    } else if (t != null && t != MaterialValueType.boolean) {
      _error(node, '${pin.name} expects bool, got ${t.label} (compare it with a Compare node)', pinId: pin.id);
    }
  }

  /// Compare, And, Or, Not and If.
  Map<String, MaterialValueType?> _logicTypes(LuminaBlueprintNode node, MaterialNodeSpec spec) {
    if (node.registryId == MaterialLogicNodes.compare) {
      for (final p in spec.inputs) {
        final t = _required(node, p);
        if (t != null && t != MaterialValueType.float1) _error(node, '${p.name} expects float, got ${t.label}', pinId: p.id);
      }
      final op = node.literals['op'];
      if (op != null && !MaterialLogicNodes.operators.contains(op)) _error(node, "'$op' is not a comparison operator");
      return {'out': MaterialValueType.boolean};
    }
    if (node.registryId != MaterialLogicNodes.ifNode) {
      for (final p in spec.inputs) {
        _requiredBool(node, p);
      }
      return {'out': MaterialValueType.boolean};
    }
    _requiredBool(node, _pin(spec, 'condition'));
    final t = _required(node, _pin(spec, 'then'));
    final f = _required(node, _pin(spec, 'else'));
    if (t != null && f != null && t != f && t != MaterialValueType.float1 && f != MaterialValueType.float1) {
      _error(node, 'Then and Else must be the same type (${t.label} vs ${f.label})', pinId: 'else');
      return {'out': null};
    }
    return {'out': _broadcast(node, t, f, 'If')};
  }

  /// The arithmetic rule: equal types, or a float with anything.
  MaterialValueType? _broadcast(LuminaBlueprintNode node, MaterialValueType? a, MaterialValueType? b, String what,
      {List<String> pins = const []}) {
    if (a == null || b == null) return a ?? b;
    if (a == b) return a;
    if (a == MaterialValueType.float1) return b;
    if (b == MaterialValueType.float1) return a;
    for (final p in pins) {
      _error(node, '$what between ${a.label} and ${b.label} is undefined', pinId: p);
    }
    if (pins.isEmpty) _error(node, '$what between ${a.label} and ${b.label} is undefined');
    return null;
  }

  void _eval(LuminaBlueprintNode node) {
    if (_evaluated.contains(node.id) || _visiting.contains(node.id)) return;
    _visiting.add(node.id);
    final spec = MaterialNodes.spec(node.registryId);
    if (spec == null) {
      _error(node, "unknown expression '${node.registryId}'");
    } else {
      for (final e in _types(node, spec).entries) {
        if (e.value != null) _outputs['${node.id}.${e.key}'] = e.value!;
      }
    }
    _visiting.remove(node.id);
    _evaluated.add(node.id);
  }

  MaterialPinDef _pin(MaterialNodeSpec spec, String id) => spec.inputs.firstWhere((p) => p.id == id);

  /// Output pin id → type for [node].
  Map<String, MaterialValueType?> _types(LuminaBlueprintNode node, MaterialNodeSpec spec) {
    Map<String, MaterialValueType?> fixed() => {for (final o in spec.outputs) o.id: o.type};
    MaterialValueType? single(MaterialValueType? t) => t;
    switch (node.registryId) {
      case MaterialNodes.output:
        _checkOutput(node);
        return const {};
      case MaterialNodes.customFragment:
        // Its own wires only show the code's flow; any other wire into the
        // Material node would be silently ignored.
        final wired = graph.wires.any((w) => w.toNodeId == MaterialNodes.outputNodeId && w.fromNodeId != node.id);
        if (wired) {
          _error(node, 'it writes the whole fragment, so wires into the Material node are ignored; '
              'delete it to build the material from the graph');
        }
        return const {};
      case MaterialNodes.textureSample:
        final tex = graph.wireInto(node.id, 'tex');
        if (tex != null) {
          if (_in(node, _pin(spec, 'tex')) != MaterialValueType.texture) {
            _error(node, 'Tex takes a TextureParameter', pinId: 'tex');
          }
        } else {
          final p = node.literals['parameter'];
          if (p is! String || !_isIdentifier(p)) _error(node, 'no texture parameter name');
        }
        final uv = _in(node, _pin(spec, 'uvs'));
        if (uv != null && uv != MaterialValueType.float2 && uv != MaterialValueType.float1) {
          _error(node, 'UVs expects float2, got ${uv.label}', pinId: 'uvs');
        }
        return fixed();
      case MaterialNodes.scalarParameter:
      case MaterialNodes.vectorParameter:
      case MaterialNodes.textureParameter:
        final name = node.literals['name'];
        if (name is! String || !_isIdentifier(name)) _error(node, "'$name' is not a valid parameter name");
        return fixed();
      case MaterialNodes.fresnel:
        if (surface.shading == FilamatShading.unlit) {
          _error(node, 'needs a lit shading model (it reads the surface normal)');
        }
        for (final p in spec.inputs) {
          final t = _in(node, p);
          if (t != null && t != MaterialValueType.float1) _error(node, '${p.name} expects float, got ${t.label}', pinId: p.id);
        }
        return fixed();
      case MaterialNodes.add:
      case MaterialNodes.subtract:
      case MaterialNodes.multiply:
      case MaterialNodes.divide:
        final a = _required(node, _pin(spec, 'a'));
        final b = _required(node, _pin(spec, 'b'));
        return {'out': single(_broadcast(node, a, b, 'arithmetic', pins: const ['a', 'b']))};
      case MaterialNodes.lerp:
        final a = _required(node, _pin(spec, 'a'));
        final b = _required(node, _pin(spec, 'b'));
        final t = _broadcast(node, a, b, 'interpolation', pins: const ['a', 'b']);
        final alpha = _required(node, _pin(spec, 'alpha'));
        if (t != null && alpha != null && alpha != MaterialValueType.float1 && alpha != t) {
          _error(node, 'Alpha must be float or ${t.label}, got ${alpha.label}', pinId: 'alpha');
        }
        return {'out': t};
      case MaterialNodes.oneMinus:
      case MaterialNodes.normalize:
        return {'out': _required(node, _pin(spec, 'in'))};
      case MaterialNodes.clamp:
        final t = _required(node, _pin(spec, 'in'));
        for (final id in ['min', 'max']) {
          final b = _required(node, _pin(spec, id));
          if (t != null && b != null && b != MaterialValueType.float1 && b != t) {
            _error(node, '${_pin(spec, id).name} must be float or ${t.label}, got ${b.label}', pinId: id);
          }
        }
        return {'out': t};
      case MaterialNodes.power:
        final t = _required(node, _pin(spec, 'base'));
        final e = _required(node, _pin(spec, 'exp'));
        if (t != null && e != null && e != MaterialValueType.float1 && e != t) {
          _error(node, 'Exp must be float or ${t.label}, got ${e.label}', pinId: 'exp');
        }
        return {'out': t};
      case MaterialNodes.dot:
        final a = _required(node, _pin(spec, 'a'));
        final b = _required(node, _pin(spec, 'b'));
        if (a != null && b != null && a != b) {
          _error(node, 'A and B must be the same type (${a.label} vs ${b.label})', pinId: 'b');
        }
        return fixed();
      case MaterialNodes.componentMask:
        final t = _required(node, _pin(spec, 'in'));
        final channels = MaterialNodes.maskChannels(node);
        if (channels.isEmpty) {
          _error(node, 'no channel selected');
          return {'out': null};
        }
        if (t != null) {
          for (final c in channels.split('')) {
            if ('rgba'.indexOf(c) >= t.width) {
              _error(node, 'input ${t.label} has no ${c.toUpperCase()} channel', pinId: 'in');
            }
          }
        }
        return {'out': MaterialValueType.ofWidth(channels.length)};
      case MaterialNodes.appendVector:
        final a = _required(node, _pin(spec, 'a'));
        final b = _required(node, _pin(spec, 'b'));
        if (a == null || b == null) return {'out': null};
        if (a.width + b.width > 4) {
          _error(node, '${a.label} and ${b.label} make more than four components', pinId: 'b');
          return {'out': null};
        }
        return {'out': MaterialValueType.ofWidth(a.width + b.width)};
      case MaterialNodes.setVertexVariable:
        _required(node, _pin(spec, 'value'));
        return const {};
      case MaterialLogicNodes.compare:
      case MaterialLogicNodes.and:
      case MaterialLogicNodes.or:
      case MaterialLogicNodes.not:
      case MaterialLogicNodes.ifNode:
        return _logicTypes(node, spec);
      case MaterialNodes.custom:
        final outType = MaterialValueType.parse(node.literals['outputType'] as String?);
        if (outType == null) _error(node, "output type '${node.literals['outputType']}' is not float/float2/float3/float4");
        final names = MaterialNodes.customInputs(node);
        final seen = <String>{};
        for (final name in names) {
          if (!_isIdentifier(name) || !seen.add(name)) _error(node, "input name '$name' is not a unique GLSL identifier");
          final pin = MaterialPinDef(name, name);
          if (graph.wireInto(node.id, name) == null) {
            _error(node, "input '$name' is not connected", pinId: name);
          } else {
            final t = _in(node, pin);
            if (t == MaterialValueType.texture) _error(node, "input '$name' cannot take a Texture2D", pinId: name);
            if (t == MaterialValueType.boolean) _error(node, "input '$name' cannot take a bool", pinId: name);
          }
        }
        final code = node.literals['code'];
        if (code is! String || code.trim().isEmpty) _error(node, 'no code');
        return {'out': outType};
      default:
        return fixed();
    }
  }

  void _checkOutput(LuminaBlueprintNode node) {
    for (final pin in MaterialNodes.inputsOf(node, surface)) {
      final wire = graph.wireInto(node.id, pin.id);
      if (wire == null) continue;
      if (pin.unused) {
        _warn(node, '${pin.name.replaceAll(' (unused)', '')} is not used by the '
            '${surface.shading.name} shading model${pin.id == MaterialNodes.opacity ? ' with ${_blendName()} blending' : ''}',
            pinId: pin.id);
        continue;
      }
      final t = _in(node, pin);
      if (t == null) continue;
      final ok = switch (pin.id) {
        MaterialNodes.baseColor || MaterialNodes.emissive || MaterialNodes.normal =>
          t == MaterialValueType.float1 || t == MaterialValueType.float3 || t == MaterialValueType.float4,
        _ => t == MaterialValueType.float1,
      };
      if (!ok) {
        final expected = pin.type == MaterialValueType.float3 ? 'float3' : 'float';
        (_byNode[node.id] ??= []).add(MaterialGraphDiagnostic('${pin.name} expects $expected, got ${t.label}',
            nodeId: node.id, pinId: pin.id));
      }
    }
  }

  String _blendName() => surface.blending.name;

  static bool _isIdentifier(String s) => RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(s);
}
