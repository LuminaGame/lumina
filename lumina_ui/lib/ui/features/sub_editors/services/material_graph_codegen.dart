import 'package:lumina/lumina.dart' show LuminaBlueprintGraph, LuminaBlueprintNode;

import '../models/material_graph.dart';
import 'mat_source.dart';
import 'material_graph_types.dart';

/// Writes a material graph as `.mat` source.
///
/// The `material` header is the current source's, with `parameters` and
/// `requires` rewritten from the graph (every other key kept as written);
/// blocks other than `fragment` are kept as written. The fragment is the
/// graph: expressions inline, a local for every value used more than once (or
/// named in the source it was parsed from), what feeds Normal before
/// `prepareMaterial(material)`, everything else after it. A Custom (Fragment)
/// node replaces the generated fragment with its code, verbatim.
class MaterialGraphCodegen {
  static String generate(
    LuminaBlueprintGraph graph, {
    required String currentSource,
    required MaterialSurface surface,
    MaterialGraphAnalysis? analysis,
    String? materialName,
  }) {
    final checked = analysis ?? MaterialGraphChecker.check(graph, surface);
    MatSource src;
    try {
      src = MatSource.parse(currentSource);
    } on FormatException {
      src = const MatSource([], []);
    }

    final fragmentNode = graph.nodes.where((n) => n.registryId == MaterialNodes.customFragment).firstOrNull;
    final emitter = _Emitter(graph, checked, surface);
    final fragment = fragmentNode != null
        ? 'fragment {\n${fragmentNode.literals['code'] ?? ''}\n}'
        : emitter.fragment();

    final header = List<MatEntry>.of(src.header);
    void put(String key, MatValue value, {List<String> after = const []}) {
      final at = header.indexWhere((e) => e.key == key);
      if (at >= 0) {
        header[at] = MatEntry(key, value);
        return;
      }
      var insert = 0;
      for (final a in after) {
        final k = header.indexWhere((e) => e.key == a);
        if (k >= 0 && k + 1 > insert) insert = k + 1;
      }
      header.insert(insert, MatEntry(key, value));
    }

    if (!header.any((e) => e.key == 'name')) {
      put('name', MatString(materialName ?? src.materialName ?? 'Material'));
    }
    final requires = <String>[...src.requires];
    for (final r in emitter.requires(fragmentNode)) {
      if (!requires.contains(r)) requires.add(r);
    }
    if (requires.isNotEmpty) {
      put('requires', MatList([for (final r in requires) MatAtom(r)]), after: const ['name', 'shadingModel', 'blending']);
    }
    final parameters = _parameters(graph);
    if (parameters.isNotEmpty || header.any((e) => e.key == 'parameters')) {
      put('parameters', MatList(parameters), after: const ['name', 'shadingModel', 'blending', 'requires']);
    }

    final out = StringBuffer();
    var wroteHeader = false;
    var wroteFragment = false;
    void write(String block) {
      if (out.isNotEmpty) out.write('\n\n');
      out.write(block);
    }

    for (final b in src.blocks) {
      if (b.name == 'material') {
        write(MatSource.renderHeader(header));
        wroteHeader = true;
      } else if (b.name == 'fragment') {
        if (!wroteHeader) {
          write(MatSource.renderHeader(header));
          wroteHeader = true;
        }
        write(fragment);
        wroteFragment = true;
      } else {
        write('${b.name} {${b.body}}');
      }
    }
    if (!wroteHeader) {
      final rest = out.toString();
      out
        ..clear()
        ..write(MatSource.renderHeader(header));
      if (rest.isNotEmpty) out.write('\n\n$rest');
    }
    if (!wroteFragment) write(fragment);
    return '${out.toString()}\n';
  }

  /// The `.mat` parameters the graph declares, in header order.
  static List<MatValue> _parameters(LuminaBlueprintGraph graph) {
    final decls = <({int order, int index, String name, MatObject decl})>[];
    final seen = <String>{};
    var index = 0;
    for (final n in graph.nodes) {
      final l = n.literals;
      MatObject? decl;
      String? name;
      switch (n.registryId) {
        case MaterialNodes.scalarParameter:
          name = l['name'] as String?;
          decl = MatObject([
            const MatEntry('type', MatAtom('float')),
            MatEntry('name', MatAtom('$name')),
            MatEntry('default', MatAtom(MaterialNodes.formatNumber(l['default']))),
          ]);
        case MaterialNodes.vectorParameter:
          name = l['name'] as String?;
          final value = l['default'];
          decl = MatObject([
            MatEntry('type', MatAtom((l['declType'] as String?) ?? 'float4')),
            MatEntry('name', MatAtom('$name')),
            if (value is List) MatEntry('default', MatList([for (final v in value) MatAtom(MaterialNodes.formatNumber(v))])),
          ]);
        case MaterialNodes.textureParameter:
          name = l['name'] as String?;
          decl = MatObject([const MatEntry('type', MatAtom('sampler2d')), MatEntry('name', MatAtom('$name'))]);
        case MaterialNodes.textureSample:
          if (graph.wireInto(n.id, 'tex') != null) break;
          name = l['parameter'] as String?;
          decl = MatObject([const MatEntry('type', MatAtom('sampler2d')), MatEntry('name', MatAtom('$name'))]);
      }
      index++;
      if (decl == null || name == null || name.isEmpty || !seen.add(name)) continue;
      final order = (l['declOrder'] as num?)?.toInt() ?? 1 << 20;
      decls.add((order: order, index: index, name: name, decl: decl));
    }
    decls.sort((a, b) => a.order != b.order ? a.order.compareTo(b.order) : a.index.compareTo(b.index));
    final extras = graph.node(MaterialNodes.outputNodeId)?.literals['extraParameters'];
    return [
      for (final d in decls) d.decl,
      if (extras is List)
        for (final raw in extras) MatAtom('$raw'),
    ];
  }
}

class _Emitter {
  final LuminaBlueprintGraph graph;
  final MaterialGraphAnalysis analysis;
  final MaterialSurface surface;

  _Emitter(this.graph, this.analysis, this.surface);

  late final Map<String, int> _uses = () {
    final m = <String, int>{};
    for (final w in graph.wires) {
      if (!analysis.reachable.contains(w.toNodeId)) continue;
      m[w.fromNodeId] = (m[w.fromNodeId] ?? 0) + 1;
    }
    return m;
  }();

  late final Set<String> _feedingNormal = () {
    final start = graph.wireInto(MaterialNodes.outputNodeId, MaterialNodes.normal);
    if (start == null || !surface.uses(MaterialNodes.normal)) return <String>{};
    final out = <String>{};
    final stack = [start.fromNodeId];
    while (stack.isNotEmpty) {
      final id = stack.removeLast();
      if (!out.add(id)) continue;
      for (final w in graph.wires) {
        if (w.toNodeId == id) stack.add(w.fromNodeId);
      }
    }
    return out;
  }();

  static const _inlineOnly = {
    MaterialNodes.scalarParameter,
    MaterialNodes.vectorParameter,
    MaterialNodes.textureParameter,
    MaterialNodes.textureCoordinate,
    MaterialNodes.time,
    MaterialNodes.vertexColor,
  };

  final Map<String, String> _localNames = {};
  final Set<String> _declared = {};
  final List<String> _pre = [];
  final List<String> _post = [];
  final Map<String, int> _customIndex = {};
  final List<String> _helpers = [];
  bool _fresnel = false;

  bool _wantsLocal(LuminaBlueprintNode n) {
    if (_inlineOnly.contains(n.registryId) || n.registryId == MaterialNodes.output) return false;
    if (n.literals['varName'] is String) return true;
    if ((_uses[n.id] ?? 0) >= 2) return true;
    // A float Constant wired into an input that has an inline constant would
    // read back as that inline constant; a local keeps it a node.
    if (n.registryId == MaterialNodes.constant) {
      for (final w in graph.wires.where((w) => w.fromNodeId == n.id)) {
        final target = graph.node(w.toNodeId);
        if (target == null) continue;
        final pin = MaterialNodes.inputsOf(target, surface).where((p) => p.id == w.toPinId).firstOrNull;
        if (pin?.defaultValue != null) return true;
      }
    }
    return false;
  }

  String _localName(LuminaBlueprintNode n) {
    final existing = _localNames[n.id];
    if (existing != null) return existing;
    final taken = _localNames.values.toSet();
    final wanted = n.literals['varName'];
    String name;
    if (wanted is String && RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(wanted) && !taken.contains(wanted) && !wanted.startsWith('gl_')) {
      name = wanted;
    } else {
      final spec = MaterialNodes.spec(n.registryId)!;
      final base = spec.title.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
      final stem = base.isEmpty ? 'value' : '${base[0].toLowerCase()}${base.substring(1)}';
      var k = 0;
      while (taken.contains('${stem}_$k')) {
        k++;
      }
      name = '${stem}_$k';
    }
    _localNames[n.id] = name;
    return name;
  }

  MaterialValueType _typeOf(String nodeId, String pinId) => analysis.outputType(nodeId, pinId) ?? MaterialValueType.float1;

  /// The node's value as a whole: a vec4 for RGBA nodes, else its output.
  MaterialValueType _baseType(LuminaBlueprintNode n) =>
      MaterialNodes.outputsOf(n).length > 1 ? MaterialValueType.float4 : _typeOf(n.id, 'out');

  void _ensure(LuminaBlueprintNode n) {
    if (_declared.contains(n.id)) return;
    for (final w in graph.wires.where((w) => w.toNodeId == n.id)) {
      final src = graph.node(w.fromNodeId);
      if (src != null) _ensure(src);
    }
    if (!_wantsLocal(n)) return;
    _declared.add(n.id);
    final line = '${_baseType(n).glsl} ${_localName(n)} = ${_expr(n)};';
    (_feedingNormal.contains(n.id) ? _pre : _post).add(line);
  }

  String _value(String nodeId, String pinId) {
    final n = graph.node(nodeId)!;
    _ensure(n);
    final base = _declared.contains(n.id) ? _localNames[n.id]! : _expr(n);
    if (MaterialNodes.outputsOf(n).length > 1) {
      final swizzle = MaterialNodes.rgbaSwizzles[pinId] ?? '';
      return swizzle.isEmpty ? base : '$base.$swizzle';
    }
    return base;
  }

  String _operand(LuminaBlueprintNode n, String pinId, {MaterialValueType? castTo}) {
    final wire = graph.wireInto(n.id, pinId);
    String code;
    MaterialValueType type;
    if (wire != null) {
      code = _value(wire.fromNodeId, wire.fromPinId);
      type = _typeOf(wire.fromNodeId, wire.fromPinId);
    } else {
      final pin = MaterialNodes.inputsOf(n, surface).where((p) => p.id == pinId).firstOrNull;
      final literal = n.literals[pinId] ?? pin?.defaultValue ?? 0.0;
      if (literal is List) {
        code = 'vec${literal.length}(${literal.map(MaterialNodes.formatNumber).join(', ')})';
        type = MaterialValueType.ofWidth(literal.length);
      } else {
        code = MaterialNodes.formatNumber(literal);
        type = MaterialValueType.float1;
      }
    }
    if (castTo != null && type == MaterialValueType.float1 && castTo.width > 1) return '${castTo.glsl}($code)';
    return code;
  }

  String _expr(LuminaBlueprintNode n) {
    final l = n.literals;
    switch (n.registryId) {
      case MaterialNodes.constant:
        return MaterialNodes.formatNumber(l['value']);
      case MaterialNodes.constant2:
      case MaterialNodes.constant3:
      case MaterialNodes.constant4:
        final v = (l['value'] as List?) ?? const [];
        return 'vec${v.length}(${v.map(MaterialNodes.formatNumber).join(', ')})';
      case MaterialNodes.scalarParameter:
      case MaterialNodes.vectorParameter:
        return 'materialParams.${l['name']}';
      case MaterialNodes.textureSample:
        final tex = graph.wireInto(n.id, 'tex');
        final param = tex == null ? l['parameter'] : graph.node(tex.fromNodeId)?.literals['name'];
        final uv = graph.wireInto(n.id, 'uvs') == null
            ? 'getUV0()'
            : _operand(n, 'uvs', castTo: MaterialValueType.float2);
        return 'texture(materialParams_$param, $uv)';
      case MaterialNodes.textureCoordinate:
        final index = (l['index'] as num?)?.toInt() ?? 0;
        final u = (l['uTiling'] as num?)?.toDouble() ?? 1.0;
        final v = (l['vTiling'] as num?)?.toDouble() ?? 1.0;
        final uv = 'getUV$index()';
        return u == 1.0 && v == 1.0
            ? uv
            : '($uv * vec2(${MaterialNodes.formatNumber(u)}, ${MaterialNodes.formatNumber(v)}))';
      case MaterialNodes.time:
        return 'getUserTime().x';
      case MaterialNodes.vertexColor:
        return 'getColor()';
      case MaterialNodes.fresnel:
        _fresnel = true;
        return 'lumina_fresnel(${_operand(n, 'exponent')}, ${_operand(n, 'base_reflect_fraction')})';
      case MaterialNodes.add:
      case MaterialNodes.subtract:
      case MaterialNodes.multiply:
      case MaterialNodes.divide:
        const ops = {
          MaterialNodes.add: '+',
          MaterialNodes.subtract: '-',
          MaterialNodes.multiply: '*',
          MaterialNodes.divide: '/',
        };
        return '(${_operand(n, 'a')} ${ops[n.registryId]} ${_operand(n, 'b')})';
      case MaterialNodes.lerp:
        final t = _typeOf(n.id, 'out');
        return 'mix(${_operand(n, 'a', castTo: t)}, ${_operand(n, 'b', castTo: t)}, ${_operand(n, 'alpha')})';
      case MaterialNodes.oneMinus:
        return '(1.0 - ${_operand(n, 'in')})';
      case MaterialNodes.clamp:
        return 'clamp(${_operand(n, 'in')}, ${_operand(n, 'min')}, ${_operand(n, 'max')})';
      case MaterialNodes.power:
        final t = _typeOf(n.id, 'out');
        return 'pow(${_operand(n, 'base')}, ${_operand(n, 'exp', castTo: t)})';
      case MaterialNodes.dot:
        return 'dot(${_operand(n, 'a')}, ${_operand(n, 'b')})';
      case MaterialNodes.normalize:
        return 'normalize(${_operand(n, 'in')})';
      case MaterialNodes.componentMask:
        final channels = MaterialNodes.maskChannels(n);
        final wire = graph.wireInto(n.id, 'in');
        final width = wire == null ? 1 : _typeOf(wire.fromNodeId, wire.fromPinId).width;
        final input = _operand(n, 'in');
        return channels == 'rgba'.substring(0, width) ? input : '$input.$channels';
      case MaterialNodes.appendVector:
        return '${_typeOf(n.id, 'out').glsl}(${_operand(n, 'a')}, ${_operand(n, 'b')})';
      case MaterialNodes.custom:
        final index = _customIndex.putIfAbsent(n.id, () {
          final k = _customIndex.length;
          _helpers.add(_customHelper(n, k));
          return k;
        });
        final args = [for (final name in MaterialNodes.customInputs(n)) _operand(n, name)];
        return 'lumina_custom_$index(${args.join(', ')})';
      default:
        return '0.0';
    }
  }

  String _customHelper(LuminaBlueprintNode n, int index) {
    final out = MaterialValueType.parse(n.literals['outputType'] as String?) ?? MaterialValueType.float3;
    final params = [
      for (final name in MaterialNodes.customInputs(n))
        '${(analysis.inputType(n.id, name) ?? MaterialValueType.float1).glsl} $name',
    ];
    final description = n.literals['description'];
    final code = '${n.literals['code'] ?? ''}'.split('\n').map((l) => l.isEmpty ? l : '        $l').join('\n');
    return [
      if (description is String && description.isNotEmpty && description != 'Custom') '    // Custom: $description',
      '    ${out.glsl} lumina_custom_$index(${params.join(', ')}) {',
      code,
      '    }',
    ].join('\n');
  }

  String? _pin(String pinId) {
    if (!surface.uses(pinId)) return null;
    final w = graph.wireInto(MaterialNodes.outputNodeId, pinId);
    return w == null ? null : _value(w.fromNodeId, w.fromPinId);
  }

  MaterialValueType _pinType(String pinId) {
    final w = graph.wireInto(MaterialNodes.outputNodeId, pinId)!;
    return _typeOf(w.fromNodeId, w.fromPinId);
  }

  String fragment() {
    final normal = _pin(MaterialNodes.normal);
    String? normalLine;
    if (normal != null) {
      final t = _pinType(MaterialNodes.normal);
      final v = switch (t) {
        MaterialValueType.float4 => '$normal.xyz',
        MaterialValueType.float1 => 'vec3($normal)',
        _ => normal,
      };
      normalLine = 'material.normal = $v;';
    }

    final assignments = <String>[];
    final baseColor = _pin(MaterialNodes.baseColor);
    final opacity = _pin(MaterialNodes.opacity);
    if (baseColor != null) {
      final t = _pinType(MaterialNodes.baseColor);
      final alpha = opacity ?? '1.0';
      assignments.add(switch (t) {
        MaterialValueType.float4 when opacity == null => 'material.baseColor = $baseColor;',
        MaterialValueType.float4 => 'material.baseColor = vec4($baseColor.rgb, $alpha);',
        MaterialValueType.float1 => 'material.baseColor = vec4(vec3($baseColor), $alpha);',
        _ => 'material.baseColor = vec4($baseColor, $alpha);',
      });
    } else if (opacity != null) {
      assignments.add('material.baseColor.a = $opacity;');
    }
    for (final pin in [MaterialNodes.metallic, MaterialNodes.roughness, MaterialNodes.specular, MaterialNodes.ambientOcclusion]) {
      final v = _pin(pin);
      if (v != null) assignments.add('material.${MaterialNodes.outputFields[pin]} = $v;');
    }
    final emissive = _pin(MaterialNodes.emissive);
    if (emissive != null) {
      assignments.add(switch (_pinType(MaterialNodes.emissive)) {
        MaterialValueType.float4 => 'material.emissive = $emissive;',
        MaterialValueType.float1 => 'material.emissive = vec4(vec3($emissive), 1.0);',
        _ => 'material.emissive = vec4($emissive, 1.0);',
      });
    }

    final b = StringBuffer('fragment {\n');
    if (_fresnel) {
      b.write('    float lumina_fresnel(float exponent, float baseReflectFraction) {\n'
          '        float facing = 1.0 - max(dot(shading_normal, shading_view), 0.0);\n'
          '        return baseReflectFraction + (1.0 - baseReflectFraction) * pow(facing, exponent);\n'
          '    }\n\n');
    }
    for (final h in _helpers) {
      b.write('$h\n\n');
    }
    b.write('    void material(inout MaterialInputs material) {\n');
    for (final line in _pre) {
      b.write('        $line\n');
    }
    if (normalLine != null) b.write('        $normalLine\n');
    b.write('        prepareMaterial(material);\n');
    for (final line in _post) {
      b.write('        $line\n');
    }
    for (final line in assignments) {
      b.write('        $line\n');
    }
    b.write('    }\n}');
    return b.toString();
  }

  /// The vertex attributes the fragment reads.
  List<String> requires(LuminaBlueprintNode? fragmentNode) {
    final out = <String>[];
    void add(String r) {
      if (!out.contains(r)) out.add(r);
    }

    if (fragmentNode != null) {
      final code = '${fragmentNode.literals['code'] ?? ''}';
      if (code.contains('getUV0()')) add('uv0');
      if (code.contains('getUV1()')) add('uv1');
      if (code.contains('getColor()')) add('color');
      return out;
    }
    for (final n in graph.nodes) {
      if (!analysis.reachable.contains(n.id)) continue;
      switch (n.registryId) {
        case MaterialNodes.textureSample:
          if (graph.wireInto(n.id, 'uvs') == null) add('uv0');
        case MaterialNodes.textureCoordinate:
          add((n.literals['index'] as num?)?.toInt() == 1 ? 'uv1' : 'uv0');
        case MaterialNodes.vertexColor:
          add('color');
        case MaterialNodes.custom:
          final code = '${n.literals['code'] ?? ''}';
          if (code.contains('getUV0()')) add('uv0');
          if (code.contains('getUV1()')) add('uv1');
          if (code.contains('getColor()')) add('color');
      }
    }
    return out;
  }
}
