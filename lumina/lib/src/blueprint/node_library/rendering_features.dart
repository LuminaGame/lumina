part of '../node_library.dart';

const String _renderingCategory = 'Settings|Ray Tracing & Upscaling';

const List<String> _rayTracingKeywords = ['rtx', 'ray tracing', 'raytracing', 'rt', 'graphics', 'settings'];
const List<String> _upscalingKeywords = ['upscaler', 'upscaling', 'super resolution', 'dlss', 'fsr', 'fsr3', 'graphics', 'settings'];
const List<String> _frameGenerationKeywords = [
  'frame generation', 'framegen', 'multi frame generation', 'mfg', 'dlss', 'fsr3', 'interpolation', 'fps', 'graphics', 'settings',
];

/// A setter of the game user settings: staged, committed by Apply
/// Scalability Settings.
LuminaBlueprintNodeSpec _renderingSet(String id, String title, LuminaBlueprintPinSpec pin, List<String> keywords) =>
    LuminaBlueprintNodeSpec(
      id: id,
      title: title,
      category: _renderingCategory,
      kind: LuminaBlueprintNodeKind.impure,
      headerColor: _function,
      keywords: keywords,
      inputs: [_execIn, pin],
      outputs: const [_execOut],
    );

LuminaBlueprintNodeSpec _renderingGet(String id, String title, LuminaPinType type, List<String> keywords) =>
    LuminaBlueprintNodeSpec(
      id: id,
      title: title,
      category: _renderingCategory,
      kind: LuminaBlueprintNodeKind.pure,
      headerColor: _pure,
      keywords: keywords,
      outputs: [_ret(type)],
    );

/// Built-in nodes: the game user settings' ray tracing (sun shadows, ReSTIR),
/// upscaler (None / FSR3 / DLSS / DLSS RR) with quality and sharpness, frame
/// generation (FSR3 or DLSS with its generated frames), and what the GPU
/// supports.
final List<LuminaBlueprintNodeSpec> _renderingFeatureNodes = <LuminaBlueprintNodeSpec>[
  _renderingSet('set_ray_tracing_enabled', 'Set Ray Tracing Enabled', _b('enabled', 'Enabled', true), _rayTracingKeywords),
  _renderingGet('get_ray_tracing_enabled', 'Get Ray Tracing Enabled', LuminaPinType.boolean, _rayTracingKeywords),
  _renderingSet('set_ray_traced_shadows_enabled', 'Set Ray Traced Shadows Enabled', _b('enabled', 'Enabled', true),
      [..._rayTracingKeywords, 'shadows', 'sun', 'ray traced shadows']),
  _renderingGet('get_ray_traced_shadows_enabled', 'Get Ray Traced Shadows Enabled', LuminaPinType.boolean,
      [..._rayTracingKeywords, 'shadows', 'sun']),
  _renderingSet('set_restir_enabled', 'Set ReSTIR Enabled', _b('enabled', 'Enabled', true),
      [..._rayTracingKeywords, 'restir', 'direct lighting', 'lights']),
  _renderingGet('get_restir_enabled', 'Get ReSTIR Enabled', LuminaPinType.boolean, [..._rayTracingKeywords, 'restir']),
  _renderingSet('set_restir_candidates', 'Set ReSTIR Candidates', _i('candidates', 'Candidates', 8),
      [..._rayTracingKeywords, 'restir', 'samples', 'quality']),
  _renderingGet('get_restir_candidates', 'Get ReSTIR Candidates', LuminaPinType.integer, [..._rayTracingKeywords, 'restir']),
  _renderingSet('set_restir_spatial_samples', 'Set ReSTIR Spatial Samples', _i('samples', 'Samples', 2),
      [..._rayTracingKeywords, 'restir', 'spatial', 'reuse', 'quality']),
  _renderingGet('get_restir_spatial_samples', 'Get ReSTIR Spatial Samples', LuminaPinType.integer,
      [..._rayTracingKeywords, 'restir', 'spatial']),
  _renderingSet('set_upscaler', 'Set Upscaler', _s('upscaler', 'Upscaler', 'FSR3'), [..._upscalingKeywords, 'none', 'off']),
  _renderingGet('get_upscaler', 'Get Upscaler', LuminaPinType.string, _upscalingKeywords),
  _renderingSet('set_upscaler_quality', 'Set Upscaler Quality', _s('quality', 'Quality', 'Quality'),
      [..._upscalingKeywords, 'quality', 'balanced', 'performance', 'ultra performance', 'native aa', 'dlaa']),
  _renderingGet('get_upscaler_quality', 'Get Upscaler Quality', LuminaPinType.string, [..._upscalingKeywords, 'quality']),
  _renderingSet('set_upscaler_sharpness', 'Set Upscaler Sharpness', _f('sharpness', 'Sharpness', 0.5),
      [..._upscalingKeywords, 'sharpness', 'sharpen', 'rcas']),
  _renderingGet('get_upscaler_sharpness', 'Get Upscaler Sharpness', LuminaPinType.float, [..._upscalingKeywords, 'sharpness']),
  _renderingSet('set_frame_generation_enabled', 'Set Frame Generation Enabled', _b('enabled', 'Enabled', true),
      [..._upscalingKeywords, 'frame generation', 'framegen', 'interpolation', 'fps']),
  _renderingGet('get_frame_generation_enabled', 'Get Frame Generation Enabled', LuminaPinType.boolean,
      [..._upscalingKeywords, 'frame generation', 'framegen']),
  _renderingSet('set_frame_generator', 'Set Frame Generator', _s('generator', 'Generator', 'DLSS'),
      _frameGenerationKeywords),
  _renderingGet('get_frame_generator', 'Get Frame Generator', LuminaPinType.string, _frameGenerationKeywords),
  _renderingSet('set_dlss_generated_frames', 'Set DLSS Generated Frames', _i('frames', 'Frames', 1),
      [..._frameGenerationKeywords, 'generated frames', '2x', '3x', '4x']),
  _renderingGet('get_dlss_generated_frames', 'Get DLSS Generated Frames', LuminaPinType.integer,
      [..._frameGenerationKeywords, 'generated frames']),
  _renderingGet('is_ray_reconstruction_supported', 'Is Ray Reconstruction Supported', LuminaPinType.boolean,
      [..._upscalingKeywords, 'ray reconstruction', 'dlss rr', 'denoiser', 'supported', 'capability', 'nvidia']),
  _renderingGet('is_dlss_frame_generation_supported', 'Is DLSS Frame Generation Supported', LuminaPinType.boolean,
      [..._frameGenerationKeywords, 'supported', 'capability', 'nvidia']),
  _renderingGet('get_max_dlss_generated_frames', 'Get Max DLSS Generated Frames', LuminaPinType.integer,
      [..._frameGenerationKeywords, 'max', 'supported', 'capability', 'rtx 50']),
  _renderingGet('is_ray_tracing_supported', 'Is Ray Tracing Supported', LuminaPinType.boolean,
      [..._rayTracingKeywords, 'supported', 'capability', 'gpu', 'vulkan']),
  _renderingGet('is_dlss_supported', 'Is DLSS Supported', LuminaPinType.boolean,
      [..._upscalingKeywords, 'supported', 'capability', 'nvidia', 'gpu']),
  _renderingGet('is_fsr3_supported', 'Is FSR3 Supported', LuminaPinType.boolean,
      [..._upscalingKeywords, 'supported', 'capability', 'amd', 'fidelityfx']),
  _renderingGet('is_frame_generation_supported', 'Is Frame Generation Supported', LuminaPinType.boolean,
      [..._upscalingKeywords, 'frame generation', 'supported', 'capability']),
  LuminaBlueprintNodeSpec(
    id: 'get_supported_upscalers',
    title: 'Get Supported Upscalers',
    category: _renderingCategory,
    kind: LuminaBlueprintNodeKind.pure,
    headerColor: _pure,
    keywords: const [..._upscalingKeywords, 'supported', 'list', 'options', 'menu'],
    outputs: const [LuminaBlueprintPinSpec(_returnValue, 'Return Value', LuminaPinType.array, elementType: LuminaPinType.string)],
  ),
  _renderingGet('get_active_upscaler', 'Get Active Upscaler', LuminaPinType.string,
      [..._upscalingKeywords, 'active', 'fallback', 'current']),
  _renderingGet('is_ray_tracing_active', 'Is Ray Tracing Active', LuminaPinType.boolean,
      [..._rayTracingKeywords, 'active', 'fallback', 'current']),
  for (final (id, title, verb) in const [
    ('save_game_user_settings', 'Save Game User Settings', 'save'),
    ('load_game_user_settings', 'Load Game User Settings', 'load'),
  ])
    LuminaBlueprintNodeSpec(
      id: id,
      title: title,
      category: _renderingCategory,
      kind: LuminaBlueprintNodeKind.impure,
      headerColor: _function,
      keywords: [verb, 'settings', 'user settings', 'game user settings', 'options', 'graphics', 'persist'],
      inputs: const [_execIn],
      outputs: const [_execOut],
    ),
];
