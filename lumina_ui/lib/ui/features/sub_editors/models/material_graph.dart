import 'package:flutter_filament/flutter_filament.dart' show BlendingMode, FilamatShading;
import 'package:lumina/lumina.dart'
    show LuminaBlueprintGraph, LuminaBlueprintNode, LuminaBlueprintWire;

/// The value a material expression pin carries: a float vector of one to four
/// components, or a texture object.
enum MaterialValueType {
  float1(1),
  float2(2),
  float3(3),
  float4(4),
  texture(0);

  final int width;
  const MaterialValueType(this.width);

  bool get isNumeric => this != texture;

  /// The type's name, as compiler messages use it.
  String get label => switch (this) {
        float1 => 'float',
        float2 => 'float2',
        float3 => 'float3',
        float4 => 'float4',
        texture => 'Texture2D',
      };

  /// The GLSL type a local of this type is declared with.
  String get glsl => switch (this) {
        float1 => 'float',
        float2 => 'vec2',
        float3 => 'vec3',
        float4 => 'vec4',
        texture => 'sampler2D',
      };

  static MaterialValueType ofWidth(int width) => switch (width) {
        1 => float1,
        2 => float2,
        3 => float3,
        _ => float4,
      };

  /// Reads a stored type name (`float3`, `vec3`, `float`).
  static MaterialValueType? parse(String? name) => switch (name?.trim()) {
        'float' || 'float1' => float1,
        'float2' || 'vec2' => float2,
        'float3' || 'vec3' => float3,
        'float4' || 'vec4' => float4,
        _ => null,
      };
}

/// One pin of a material expression. A null [type] is a dynamic numeric pin
/// (Multiply's A and B): its type comes from what is wired into it.
class MaterialPinDef {
  final String id;
  final String name;
  final MaterialValueType? type;

  /// The constant an unconnected input uses (e.g. "Const A"); edited inline
  /// on the node. Null when the input must be wired (or is [optional]).
  final Object? defaultValue;

  /// An unconnected optional input falls back to built-in behaviour
  /// (TextureSample's UVs read UV0).
  final bool optional;

  /// Set on Material output pins the current shading model or blend mode
  /// ignores (the canvas greys them out).
  final bool unused;

  const MaterialPinDef(this.id, this.name, {this.type, this.defaultValue, this.optional = false, this.unused = false});

  MaterialPinDef asUnused() => MaterialPinDef(id, '$name (unused)', type: type, defaultValue: defaultValue, optional: true, unused: true);
}

/// A material expression kind: its palette entry and pins.
class MaterialNodeSpec {
  final String id;
  final String title;
  final String category;
  final List<String> keywords;
  final int headerColor;
  final List<MaterialPinDef> inputs;
  final List<MaterialPinDef> outputs;

  /// Node settings a new node starts with.
  final Map<String, dynamic> defaults;

  final String tooltip;

  const MaterialNodeSpec({
    required this.id,
    required this.title,
    required this.category,
    required this.headerColor,
    this.keywords = const [],
    this.inputs = const [],
    this.outputs = const [],
    this.defaults = const {},
    this.tooltip = '',
  });
}

/// The surface the Material output node shades: which of its pins are used.
class MaterialSurface {
  final FilamatShading shading;
  final BlendingMode blending;
  const MaterialSurface({this.shading = FilamatShading.lit, this.blending = BlendingMode.opaque});

  bool get usesOpacity =>
      blending == BlendingMode.transparent || blending == BlendingMode.masked || blending == BlendingMode.fade;

  /// Whether the output pin [pinId] feeds anything for this shading model and
  /// blend mode (Filament's `MaterialInputs` has no field for the rest).
  bool uses(String pinId) {
    if (pinId == MaterialNodes.opacity) return usesOpacity;
    switch (shading) {
      case FilamatShading.unlit:
        return pinId == MaterialNodes.baseColor || pinId == MaterialNodes.emissive;
      case FilamatShading.cloth:
        return pinId != MaterialNodes.metallic && pinId != MaterialNodes.specular;
      default:
        return true;
    }
  }
}

// design-token-exempt: node header colours follow material node conventions
// (green parameters, purple textures), not the editor chrome palette.
const int _constantColor = 0xFF455A64;
const int _parameterColor = 0xFF2E7D32;
const int _textureColor = 0xFF6A1B9A;
const int _mathColor = 0xFF283593;
const int _utilityColor = 0xFF00695C;
const int _customColor = 0xFF5D4037;
const int _outputColor = 0xFF37474F;

/// The material expression catalog and the helpers that
/// read a node's settings. A material graph is lumina's [LuminaBlueprintGraph]:
/// a node's `registryId` is one of these ids, its settings and inline input
/// constants live in `literals`, its place in `x`/`y`.
abstract final class MaterialNodes {
  static const String output = 'mat_output';
  static const String constant = 'mat_constant';
  static const String constant2 = 'mat_constant2';
  static const String constant3 = 'mat_constant3';
  static const String constant4 = 'mat_constant4';
  static const String scalarParameter = 'mat_scalar_parameter';
  static const String vectorParameter = 'mat_vector_parameter';
  static const String textureParameter = 'mat_texture_parameter';
  static const String textureSample = 'mat_texture_sample';
  static const String textureCoordinate = 'mat_texture_coordinate';
  static const String add = 'mat_add';
  static const String subtract = 'mat_subtract';
  static const String multiply = 'mat_multiply';
  static const String divide = 'mat_divide';
  static const String lerp = 'mat_lerp';
  static const String oneMinus = 'mat_one_minus';
  static const String clamp = 'mat_clamp';
  static const String power = 'mat_power';
  static const String dot = 'mat_dot';
  static const String normalize = 'mat_normalize';
  static const String componentMask = 'mat_component_mask';
  static const String appendVector = 'mat_append_vector';
  static const String time = 'mat_time';
  static const String vertexColor = 'mat_vertex_color';
  static const String fresnel = 'mat_fresnel';
  static const String custom = 'mat_custom';
  static const String customFragment = 'mat_custom_fragment';

  /// The Material output node's fixed id: every graph has exactly one.
  static const String outputNodeId = 'material_output';

  // Material output pins.
  static const String baseColor = 'base_color';
  static const String metallic = 'metallic';
  static const String roughness = 'roughness';
  static const String specular = 'specular';
  static const String normal = 'normal';
  static const String emissive = 'emissive';
  static const String opacity = 'opacity';
  static const String ambientOcclusion = 'ambient_occlusion';

  /// Output pin → the Filament `MaterialInputs` field it writes.
  static const Map<String, String> outputFields = {
    baseColor: 'baseColor',
    metallic: 'metallic',
    roughness: 'roughness',
    specular: 'reflectance',
    normal: 'normal',
    emissive: 'emissive',
    ambientOcclusion: 'ambientOcclusion',
  };

  static const List<MaterialPinDef> _rgbaOutputs = [
    MaterialPinDef('rgb', 'RGB', type: MaterialValueType.float3),
    MaterialPinDef('r', 'R', type: MaterialValueType.float1),
    MaterialPinDef('g', 'G', type: MaterialValueType.float1),
    MaterialPinDef('b', 'B', type: MaterialValueType.float1),
    MaterialPinDef('a', 'A', type: MaterialValueType.float1),
    MaterialPinDef('rgba', 'RGBA', type: MaterialValueType.float4),
  ];

  /// The swizzle each RGBA output reads from its vec4.
  static const Map<String, String> rgbaSwizzles = {'rgb': 'rgb', 'r': 'r', 'g': 'g', 'b': 'b', 'a': 'a', 'rgba': ''};

  static const List<MaterialNodeSpec> all = [
    MaterialNodeSpec(
      id: output,
      title: 'Material',
      category: 'Output',
      headerColor: _outputColor,
      inputs: [
        MaterialPinDef(baseColor, 'Base Color', type: MaterialValueType.float3, optional: true),
        MaterialPinDef(metallic, 'Metallic', type: MaterialValueType.float1, optional: true),
        MaterialPinDef(roughness, 'Roughness', type: MaterialValueType.float1, optional: true),
        MaterialPinDef(specular, 'Specular', type: MaterialValueType.float1, optional: true),
        MaterialPinDef(normal, 'Normal', type: MaterialValueType.float3, optional: true),
        MaterialPinDef(emissive, 'Emissive Color', type: MaterialValueType.float3, optional: true),
        MaterialPinDef(opacity, 'Opacity', type: MaterialValueType.float1, optional: true),
        MaterialPinDef(ambientOcclusion, 'Ambient Occlusion', type: MaterialValueType.float1, optional: true),
      ],
    ),
    MaterialNodeSpec(
      id: constant,
      title: 'Constant',
      category: 'Constants',
      headerColor: _constantColor,
      keywords: ['scalar', 'float', 'number', '1'],
      outputs: [MaterialPinDef('out', '', type: MaterialValueType.float1)],
      defaults: {'value': 0.0},
      tooltip: 'A float constant.',
    ),
    MaterialNodeSpec(
      id: constant2,
      title: 'Constant2Vector',
      category: 'Constants',
      headerColor: _constantColor,
      keywords: ['float2', 'vec2', '2'],
      outputs: [MaterialPinDef('out', '', type: MaterialValueType.float2)],
      defaults: {'value': [0.0, 0.0]},
    ),
    MaterialNodeSpec(
      id: constant3,
      title: 'Constant3Vector',
      category: 'Constants',
      headerColor: _constantColor,
      keywords: ['float3', 'vec3', 'color', 'rgb', '3'],
      outputs: [MaterialPinDef('out', '', type: MaterialValueType.float3)],
      defaults: {'value': [1.0, 1.0, 1.0]},
    ),
    MaterialNodeSpec(
      id: constant4,
      title: 'Constant4Vector',
      category: 'Constants',
      headerColor: _constantColor,
      keywords: ['float4', 'vec4', 'rgba', '4'],
      outputs: [MaterialPinDef('out', '', type: MaterialValueType.float4)],
      defaults: {'value': [1.0, 1.0, 1.0, 1.0]},
    ),
    MaterialNodeSpec(
      id: scalarParameter,
      title: 'ScalarParameter',
      category: 'Parameters',
      headerColor: _parameterColor,
      keywords: ['param', 'float', 'uniform'],
      outputs: [MaterialPinDef('out', '', type: MaterialValueType.float1)],
      defaults: {'name': 'Param', 'default': 0.0},
      tooltip: 'A float parameter: a `float` in the `.mat` parameters block, edited in the panel on the right.',
    ),
    MaterialNodeSpec(
      id: vectorParameter,
      title: 'VectorParameter',
      category: 'Parameters',
      headerColor: _parameterColor,
      keywords: ['param', 'color', 'float4', 'uniform'],
      outputs: _rgbaOutputs,
      defaults: {'name': 'Color', 'default': [1.0, 1.0, 1.0, 1.0]},
      tooltip: 'A colour parameter: a `float4` in the `.mat` parameters block.',
    ),
    MaterialNodeSpec(
      id: textureParameter,
      title: 'TextureParameter',
      category: 'Parameters',
      headerColor: _parameterColor,
      keywords: ['param', 'texture', 'sampler', 'object'],
      outputs: [MaterialPinDef('tex', 'Texture', type: MaterialValueType.texture)],
      defaults: {'name': 'Texture'},
      tooltip: 'A texture parameter (a `sampler2d`) for a TextureSample\'s Tex input.',
    ),
    MaterialNodeSpec(
      id: textureSample,
      title: 'TextureSample',
      category: 'Texture',
      headerColor: _textureColor,
      keywords: ['texture', 'sample', 'sampler', 'map', 'image'],
      inputs: [
        MaterialPinDef('uvs', 'UVs', type: MaterialValueType.float2, optional: true),
        MaterialPinDef('tex', 'Tex', type: MaterialValueType.texture, optional: true),
      ],
      outputs: _rgbaOutputs,
      defaults: {'parameter': 'Texture'},
      tooltip: 'Samples a texture parameter (its sampler is declared in the `.mat` header; bind the texture on the right).',
    ),
    MaterialNodeSpec(
      id: textureCoordinate,
      title: 'TextureCoordinate',
      category: 'Texture',
      headerColor: _textureColor,
      keywords: ['uv', 'texcoord', 'tiling'],
      outputs: [MaterialPinDef('out', '', type: MaterialValueType.float2)],
      defaults: {'index': 0, 'uTiling': 1.0, 'vTiling': 1.0},
    ),
    MaterialNodeSpec(
      id: add,
      title: 'Add',
      category: 'Math',
      headerColor: _mathColor,
      keywords: ['+', 'plus', 'sum'],
      inputs: [MaterialPinDef('a', 'A', defaultValue: 0.0), MaterialPinDef('b', 'B', defaultValue: 1.0)],
      outputs: [MaterialPinDef('out', '')],
    ),
    MaterialNodeSpec(
      id: subtract,
      title: 'Subtract',
      category: 'Math',
      headerColor: _mathColor,
      keywords: ['-', 'minus'],
      inputs: [MaterialPinDef('a', 'A', defaultValue: 1.0), MaterialPinDef('b', 'B', defaultValue: 1.0)],
      outputs: [MaterialPinDef('out', '')],
    ),
    MaterialNodeSpec(
      id: multiply,
      title: 'Multiply',
      category: 'Math',
      headerColor: _mathColor,
      keywords: ['*', 'times', 'mul'],
      inputs: [MaterialPinDef('a', 'A', defaultValue: 0.0), MaterialPinDef('b', 'B', defaultValue: 1.0)],
      outputs: [MaterialPinDef('out', '')],
    ),
    MaterialNodeSpec(
      id: divide,
      title: 'Divide',
      category: 'Math',
      headerColor: _mathColor,
      keywords: ['/', 'div'],
      inputs: [MaterialPinDef('a', 'A', defaultValue: 1.0), MaterialPinDef('b', 'B', defaultValue: 2.0)],
      outputs: [MaterialPinDef('out', '')],
    ),
    MaterialNodeSpec(
      id: lerp,
      title: 'Lerp',
      category: 'Math',
      headerColor: _mathColor,
      keywords: ['linearinterpolate', 'mix', 'blend'],
      inputs: [
        MaterialPinDef('a', 'A', defaultValue: 0.0),
        MaterialPinDef('b', 'B', defaultValue: 1.0),
        MaterialPinDef('alpha', 'Alpha', defaultValue: 0.5),
      ],
      outputs: [MaterialPinDef('out', '')],
    ),
    MaterialNodeSpec(
      id: oneMinus,
      title: 'OneMinus',
      category: 'Math',
      headerColor: _mathColor,
      keywords: ['1-x', 'invert'],
      inputs: [MaterialPinDef('in', 'In')],
      outputs: [MaterialPinDef('out', '')],
    ),
    MaterialNodeSpec(
      id: clamp,
      title: 'Clamp',
      category: 'Math',
      headerColor: _mathColor,
      keywords: ['saturate', 'limit'],
      inputs: [
        MaterialPinDef('in', 'In'),
        MaterialPinDef('min', 'Min', defaultValue: 0.0),
        MaterialPinDef('max', 'Max', defaultValue: 1.0),
      ],
      outputs: [MaterialPinDef('out', '')],
    ),
    MaterialNodeSpec(
      id: power,
      title: 'Power',
      category: 'Math',
      headerColor: _mathColor,
      keywords: ['pow', 'exponent'],
      inputs: [MaterialPinDef('base', 'Base'), MaterialPinDef('exp', 'Exp', defaultValue: 2.0)],
      outputs: [MaterialPinDef('out', '')],
    ),
    MaterialNodeSpec(
      id: dot,
      title: 'Dot',
      category: 'Math',
      headerColor: _mathColor,
      keywords: ['dotproduct'],
      inputs: [MaterialPinDef('a', 'A'), MaterialPinDef('b', 'B')],
      outputs: [MaterialPinDef('out', '', type: MaterialValueType.float1)],
    ),
    MaterialNodeSpec(
      id: normalize,
      title: 'Normalize',
      category: 'Math',
      headerColor: _mathColor,
      keywords: ['unit', 'length'],
      inputs: [MaterialPinDef('in', 'In')],
      outputs: [MaterialPinDef('out', '')],
    ),
    MaterialNodeSpec(
      id: componentMask,
      title: 'ComponentMask',
      category: 'Utility',
      headerColor: _utilityColor,
      keywords: ['mask', 'swizzle', 'channel', 'rgb'],
      inputs: [MaterialPinDef('in', 'In')],
      outputs: [MaterialPinDef('out', '')],
      defaults: {'r': true, 'g': true, 'b': false, 'a': false},
    ),
    MaterialNodeSpec(
      id: appendVector,
      title: 'AppendVector',
      category: 'Utility',
      headerColor: _utilityColor,
      keywords: ['append', 'combine', 'make'],
      inputs: [MaterialPinDef('a', 'A'), MaterialPinDef('b', 'B')],
      outputs: [MaterialPinDef('out', '')],
    ),
    MaterialNodeSpec(
      id: time,
      title: 'Time',
      category: 'Utility',
      headerColor: _utilityColor,
      keywords: ['seconds', 'animate'],
      outputs: [MaterialPinDef('out', '', type: MaterialValueType.float1)],
    ),
    MaterialNodeSpec(
      id: vertexColor,
      title: 'VertexColor',
      category: 'Utility',
      headerColor: _utilityColor,
      keywords: ['color', 'vertex'],
      outputs: _rgbaOutputs,
    ),
    MaterialNodeSpec(
      id: fresnel,
      title: 'Fresnel',
      category: 'Utility',
      headerColor: _utilityColor,
      keywords: ['rim', 'edge'],
      inputs: [
        MaterialPinDef('exponent', 'ExponentIn', type: MaterialValueType.float1, defaultValue: 5.0),
        MaterialPinDef('base_reflect_fraction', 'BaseReflectFractionIn', type: MaterialValueType.float1, defaultValue: 0.04),
      ],
      outputs: [MaterialPinDef('out', '', type: MaterialValueType.float1)],
    ),
    MaterialNodeSpec(
      id: custom,
      title: 'Custom',
      category: 'Custom',
      headerColor: _customColor,
      keywords: ['glsl', 'code', 'hlsl', 'expression'],
      outputs: [MaterialPinDef('out', '')],
      defaults: {'description': 'Custom', 'outputType': 'float3', 'inputs': <String>[], 'code': 'return vec3(1.0);'},
      tooltip: 'Raw GLSL: a function body over the named inputs that returns the output type.',
    ),
    MaterialNodeSpec(
      id: customFragment,
      title: 'Custom (Fragment)',
      category: 'Custom',
      headerColor: _customColor,
      defaults: {'code': ''},
      tooltip: 'Hand-written fragment code the graph cannot express, kept verbatim.',
    ),
  ];

  static final Map<String, MaterialNodeSpec> _byId = {for (final s in all) s.id: s};

  static MaterialNodeSpec? spec(String? id) => _byId[id];

  /// Kinds that declare a `.mat` parameter.
  static bool isParameter(String registryId) =>
      registryId == scalarParameter || registryId == vectorParameter || registryId == textureParameter;

  /// The node's inputs, resolved for its settings and the [surface]: a Custom
  /// node's named inputs; the output node's pins, the unused ones marked.
  static List<MaterialPinDef> inputsOf(LuminaBlueprintNode node, [MaterialSurface surface = const MaterialSurface()]) {
    final s = spec(node.registryId);
    if (s == null) return const [];
    if (node.registryId == custom) {
      return [for (final name in customInputs(node)) MaterialPinDef(name, name)];
    }
    if (node.registryId == output) {
      return [for (final p in s.inputs) surface.uses(p.id) ? p : p.asUnused()];
    }
    return s.inputs;
  }

  static List<MaterialPinDef> outputsOf(LuminaBlueprintNode node) => spec(node.registryId)?.outputs ?? const [];

  static List<String> customInputs(LuminaBlueprintNode node) {
    final raw = node.literals['inputs'];
    if (raw is! List) return const [];
    return [for (final e in raw) if (e is String && e.isNotEmpty) e];
  }

  /// A ComponentMask's selected channels, in RGBA order (`'rg'`).
  static String maskChannels(LuminaBlueprintNode node) =>
      ['r', 'g', 'b', 'a'].where((c) => node.literals[c] == true).join();

  /// The `.mat` parameter a TextureSample, parameter node or wired
  /// TextureParameter names, or null for other nodes.
  static String? parameterName(LuminaBlueprintNode node) {
    if (node.registryId == textureSample) return node.literals['parameter'] as String?;
    if (isParameter(node.registryId)) return node.literals['name'] as String?;
    return null;
  }

  /// The title the canvas shows: a constant's value and a parameter's name
  /// in the header.
  static String titleOf(LuminaBlueprintNode node) {
    final l = node.literals;
    switch (node.registryId) {
      case constant:
        return formatNumber(l['value']);
      case constant2:
      case constant3:
      case constant4:
        final v = l['value'];
        return v is List ? v.map(formatNumber).join(', ') : spec(node.registryId)!.title;
      case scalarParameter:
        return '${l['name'] ?? 'Param'} (${formatNumber(l['default'])})';
      case vectorParameter:
      case textureParameter:
        return '${l['name'] ?? spec(node.registryId)!.title}';
      case textureSample:
        return 'Texture Sample · ${l['parameter'] ?? '?'}';
      case textureCoordinate:
        final u = (l['uTiling'] as num?)?.toDouble() ?? 1.0;
        final v = (l['vTiling'] as num?)?.toDouble() ?? 1.0;
        final tiling = u == 1.0 && v == 1.0 ? '' : ' ×${formatNumber(u)},${formatNumber(v)}';
        return 'TexCoord[${l['index'] ?? 0}]$tiling';
      case componentMask:
        final channels = maskChannels(node).toUpperCase().split('').join(' ');
        return 'Mask ( $channels )';
      case custom:
        final d = l['description'];
        return d is String && d.isNotEmpty ? d : 'Custom';
      default:
        return spec(node.registryId)?.title ?? node.registryId;
    }
  }

  /// A float as GLSL and the canvas write it: always with a decimal point.
  static String formatNumber(Object? value) {
    final d = value is num ? value.toDouble() : 0.0;
    if (d.isNaN || d.isInfinite) return '0.0';
    var s = d.toString();
    if (!s.contains('.') && !s.contains('e')) s = '$s.0';
    if (s.contains('e')) {
      // GLSL accepts `1e-05`, but a fixed form reads better on a node.
      s = d.toStringAsFixed(8).replaceFirst(RegExp(r'0+$'), '');
      if (s.endsWith('.')) s = '${s}0';
    }
    return s;
  }

  /// A new node of [registryId] with its default settings.
  static LuminaBlueprintNode create(
    String registryId, {
    required String id,
    double x = 0,
    double y = 0,
    Map<String, dynamic>? literals,
  }) {
    final s = spec(registryId)!;
    final node = LuminaBlueprintNode(
      id: id,
      registryId: registryId,
      title: s.title,
      category: s.category,
      x: x,
      y: y,
      headerColor: s.headerColor,
      literals: {..._deepCopy(s.defaults), ...?literals},
    );
    node.title = titleOf(node);
    return node;
  }

  static Map<String, dynamic> _deepCopy(Map<String, dynamic> m) =>
      {for (final e in m.entries) e.key: e.value is List ? List.of(e.value as List) : e.value};

  /// The Material output node of [graph], created at [x]/[y] if missing.
  static LuminaBlueprintNode ensureOutput(LuminaBlueprintGraph graph, {String? materialName}) {
    final existing = graph.node(outputNodeId);
    if (existing != null) return existing;
    final node = create(output, id: outputNodeId);
    if (materialName != null && materialName.isNotEmpty) node.title = materialName;
    graph.nodes.add(node);
    return node;
  }

  /// The wire into input [pinId] of [nodeId], if any.
  static LuminaBlueprintWire? wireInto(LuminaBlueprintGraph graph, String nodeId, String pinId) =>
      graph.wireInto(nodeId, pinId);
}
