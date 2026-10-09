part of '../blueprint_function_library.dart';

/// [LuminaBlueprintFunctionLibrary.callShapes]: the game user settings' ray
/// tracing and upscaler nodes.
const Map<String, LuminaBlueprintCallShape> _renderingFeatureCallShapes = <String, LuminaBlueprintCallShape>{
  'set_ray_tracing_enabled': LuminaBlueprintCallShape('setRayTracingEnabled', ['enabled'], self: true),
  'get_ray_tracing_enabled': LuminaBlueprintCallShape('getRayTracingEnabled', [], self: true, outputs: LuminaBlueprintFunctionLibrary._r),
  'set_ray_traced_shadows_enabled': LuminaBlueprintCallShape('setRayTracedShadowsEnabled', ['enabled'], self: true),
  'get_ray_traced_shadows_enabled':
      LuminaBlueprintCallShape('getRayTracedShadowsEnabled', [], self: true, outputs: LuminaBlueprintFunctionLibrary._r),
  'set_restir_enabled': LuminaBlueprintCallShape('setRestirEnabled', ['enabled'], self: true),
  'get_restir_enabled': LuminaBlueprintCallShape('getRestirEnabled', [], self: true, outputs: LuminaBlueprintFunctionLibrary._r),
  'set_restir_candidates': LuminaBlueprintCallShape('setRestirCandidates', ['candidates'], self: true),
  'get_restir_candidates': LuminaBlueprintCallShape('getRestirCandidates', [], self: true, outputs: LuminaBlueprintFunctionLibrary._r),
  'set_restir_spatial_samples': LuminaBlueprintCallShape('setRestirSpatialSamples', ['samples'], self: true),
  'get_restir_spatial_samples':
      LuminaBlueprintCallShape('getRestirSpatialSamples', [], self: true, outputs: LuminaBlueprintFunctionLibrary._r),
  'set_upscaler': LuminaBlueprintCallShape('setUpscaler', ['upscaler'], self: true),
  'get_upscaler': LuminaBlueprintCallShape('getUpscaler', [], self: true, outputs: LuminaBlueprintFunctionLibrary._r),
  'set_upscaler_quality': LuminaBlueprintCallShape('setUpscalerQuality', ['quality'], self: true),
  'get_upscaler_quality': LuminaBlueprintCallShape('getUpscalerQuality', [], self: true, outputs: LuminaBlueprintFunctionLibrary._r),
  'set_upscaler_sharpness': LuminaBlueprintCallShape('setUpscalerSharpness', ['sharpness'], self: true),
  'get_upscaler_sharpness': LuminaBlueprintCallShape('getUpscalerSharpness', [], self: true, outputs: LuminaBlueprintFunctionLibrary._r),
  'set_frame_generation_enabled': LuminaBlueprintCallShape('setFrameGenerationEnabled', ['enabled'], self: true),
  'get_frame_generation_enabled':
      LuminaBlueprintCallShape('getFrameGenerationEnabled', [], self: true, outputs: LuminaBlueprintFunctionLibrary._r),
  'set_frame_generator': LuminaBlueprintCallShape('setFrameGenerator', ['generator'], self: true),
  'get_frame_generator': LuminaBlueprintCallShape('getFrameGenerator', [], self: true, outputs: LuminaBlueprintFunctionLibrary._r),
  'set_dlss_generated_frames': LuminaBlueprintCallShape('setDlssGeneratedFrames', ['frames'], self: true),
  'get_dlss_generated_frames':
      LuminaBlueprintCallShape('getDlssGeneratedFrames', [], self: true, outputs: LuminaBlueprintFunctionLibrary._r),
  'is_ray_reconstruction_supported':
      LuminaBlueprintCallShape('isRayReconstructionSupported', [], self: true, outputs: LuminaBlueprintFunctionLibrary._r),
  'is_dlss_frame_generation_supported':
      LuminaBlueprintCallShape('isDlssFrameGenerationSupported', [], self: true, outputs: LuminaBlueprintFunctionLibrary._r),
  'get_max_dlss_generated_frames':
      LuminaBlueprintCallShape('getMaxDlssGeneratedFrames', [], self: true, outputs: LuminaBlueprintFunctionLibrary._r),
  'is_ray_tracing_supported': LuminaBlueprintCallShape('isRayTracingSupported', [], self: true, outputs: LuminaBlueprintFunctionLibrary._r),
  'is_dlss_supported': LuminaBlueprintCallShape('isDlssSupported', [], self: true, outputs: LuminaBlueprintFunctionLibrary._r),
  'is_fsr3_supported': LuminaBlueprintCallShape('isFsr3Supported', [], self: true, outputs: LuminaBlueprintFunctionLibrary._r),
  'is_frame_generation_supported':
      LuminaBlueprintCallShape('isFrameGenerationSupported', [], self: true, outputs: LuminaBlueprintFunctionLibrary._r),
  'get_supported_upscalers': LuminaBlueprintCallShape('getSupportedUpscalers', [], self: true, outputs: LuminaBlueprintFunctionLibrary._r),
  'get_active_upscaler': LuminaBlueprintCallShape('getActiveUpscaler', [], self: true, outputs: LuminaBlueprintFunctionLibrary._r),
  'is_ray_tracing_active': LuminaBlueprintCallShape('isRayTracingActive', [], self: true, outputs: LuminaBlueprintFunctionLibrary._r),
  'save_game_user_settings': LuminaBlueprintCallShape('saveGameUserSettings', [], self: true),
  'load_game_user_settings': LuminaBlueprintCallShape('loadGameUserSettings', [], self: true),
};

/// Runs a setter node's [effect]; it has no outputs.
Map<String, Object?> _settingsEffect(void Function() effect) {
  effect();
  return const {};
}

/// [LuminaBlueprintFunctionLibrary.builtInFunctions]: the game user settings'
/// ray tracing and upscaler nodes.
final Map<String, LuminaBlueprintFunction> _renderingFeatureFunctions = <String, LuminaBlueprintFunction>{
  'set_ray_tracing_enabled': (c, i) => _settingsEffect(() => _setRayTracingEnabled(c.self, i['enabled'] as bool? ?? true)),
  'get_ray_tracing_enabled': (c, i) => LuminaBlueprintFunctionLibrary._ret(_getRayTracingEnabled(c.self)),
  'set_ray_traced_shadows_enabled': (c, i) => _settingsEffect(() => _setRayTracedShadowsEnabled(c.self, i['enabled'] as bool? ?? true)),
  'get_ray_traced_shadows_enabled': (c, i) => LuminaBlueprintFunctionLibrary._ret(_getRayTracedShadowsEnabled(c.self)),
  'set_restir_enabled': (c, i) => _settingsEffect(() => _setRestirEnabled(c.self, i['enabled'] as bool? ?? true)),
  'get_restir_enabled': (c, i) => LuminaBlueprintFunctionLibrary._ret(_getRestirEnabled(c.self)),
  'set_restir_candidates': (c, i) =>
      _settingsEffect(() => _setRestirCandidates(c.self, LuminaBlueprintFunctionLibrary._n(i['candidates'], 8))),
  'get_restir_candidates': (c, i) => LuminaBlueprintFunctionLibrary._ret(_getRestirCandidates(c.self)),
  'set_restir_spatial_samples': (c, i) =>
      _settingsEffect(() => _setRestirSpatialSamples(c.self, LuminaBlueprintFunctionLibrary._n(i['samples'], 2))),
  'get_restir_spatial_samples': (c, i) => LuminaBlueprintFunctionLibrary._ret(_getRestirSpatialSamples(c.self)),
  'set_upscaler': (c, i) => _settingsEffect(() => _setUpscaler(c.self, i['upscaler'] as String? ?? 'FSR3')),
  'get_upscaler': (c, i) => LuminaBlueprintFunctionLibrary._ret(_getUpscaler(c.self)),
  'set_upscaler_quality': (c, i) => _settingsEffect(() => _setUpscalerQuality(c.self, i['quality'] as String? ?? 'Quality')),
  'get_upscaler_quality': (c, i) => LuminaBlueprintFunctionLibrary._ret(_getUpscalerQuality(c.self)),
  'set_upscaler_sharpness': (c, i) =>
      _settingsEffect(() => _setUpscalerSharpness(c.self, LuminaBlueprintFunctionLibrary._d(i['sharpness'], 0.5))),
  'get_upscaler_sharpness': (c, i) => LuminaBlueprintFunctionLibrary._ret(_getUpscalerSharpness(c.self)),
  'set_frame_generation_enabled': (c, i) => _settingsEffect(() => _setFrameGenerationEnabled(c.self, i['enabled'] as bool? ?? true)),
  'get_frame_generation_enabled': (c, i) => LuminaBlueprintFunctionLibrary._ret(_getFrameGenerationEnabled(c.self)),
  'set_frame_generator': (c, i) => _settingsEffect(() => _setFrameGenerator(c.self, i['generator'] as String? ?? 'DLSS')),
  'get_frame_generator': (c, i) => LuminaBlueprintFunctionLibrary._ret(_getFrameGenerator(c.self)),
  'set_dlss_generated_frames': (c, i) =>
      _settingsEffect(() => _setDlssGeneratedFrames(c.self, LuminaBlueprintFunctionLibrary._n(i['frames'], 1))),
  'get_dlss_generated_frames': (c, i) => LuminaBlueprintFunctionLibrary._ret(_getDlssGeneratedFrames(c.self)),
  'is_ray_reconstruction_supported': (c, i) => LuminaBlueprintFunctionLibrary._ret(_isRayReconstructionSupported(c.self)),
  'is_dlss_frame_generation_supported': (c, i) => LuminaBlueprintFunctionLibrary._ret(_isDlssFrameGenerationSupported(c.self)),
  'get_max_dlss_generated_frames': (c, i) => LuminaBlueprintFunctionLibrary._ret(_getMaxDlssGeneratedFrames(c.self)),
  'is_ray_tracing_supported': (c, i) => LuminaBlueprintFunctionLibrary._ret(_isRayTracingSupported(c.self)),
  'is_dlss_supported': (c, i) => LuminaBlueprintFunctionLibrary._ret(_isDlssSupported(c.self)),
  'is_fsr3_supported': (c, i) => LuminaBlueprintFunctionLibrary._ret(_isFsr3Supported(c.self)),
  'is_frame_generation_supported': (c, i) => LuminaBlueprintFunctionLibrary._ret(_isFrameGenerationSupported(c.self)),
  'get_supported_upscalers': (c, i) => LuminaBlueprintFunctionLibrary._ret(_getSupportedUpscalers(c.self)),
  'get_active_upscaler': (c, i) => LuminaBlueprintFunctionLibrary._ret(_getActiveUpscaler(c.self)),
  'is_ray_tracing_active': (c, i) => LuminaBlueprintFunctionLibrary._ret(_isRayTracingActive(c.self)),
  'save_game_user_settings': (c, i) => _settingsEffect(() => _saveGameUserSettings(c.self)),
  'load_game_user_settings': (c, i) => _settingsEffect(() => _loadGameUserSettings(c.self)),
};

void _setRayTracingEnabled(LuminaActor self, [bool enabled = true]) => _userSettings(self).setRayTracingEnabled(enabled);
bool _getRayTracingEnabled(LuminaActor self) => _userSettings(self).rayTracingEnabled;

void _setRayTracedShadowsEnabled(LuminaActor self, [bool enabled = true]) =>
    _userSettings(self).setRayTracedShadowsEnabled(enabled);
bool _getRayTracedShadowsEnabled(LuminaActor self) => _userSettings(self).rayTracedShadowsEnabled;

void _setRestirEnabled(LuminaActor self, [bool enabled = true]) => _userSettings(self).setRestirEnabled(enabled);
bool _getRestirEnabled(LuminaActor self) => _userSettings(self).restirEnabled;

void _setRestirCandidates(LuminaActor self, [int candidates = 8]) => _userSettings(self).setRestirCandidates(candidates);
int _getRestirCandidates(LuminaActor self) => _userSettings(self).restirCandidates;

void _setRestirSpatialSamples(LuminaActor self, [int samples = 2]) => _userSettings(self).setRestirSpatialSamples(samples);
int _getRestirSpatialSamples(LuminaActor self) => _userSettings(self).restirSpatialSamples;

/// `None`, `FSR3`, `DLSS` or `DLSS RR`; committed by Apply Scalability Settings.
void _setUpscaler(LuminaActor self, [String upscaler = 'FSR3']) => _userSettings(self).setUpscaler(upscaler);
String _getUpscaler(LuminaActor self) => _userSettings(self).upscaler;

/// `Native AA`, `Quality`, `Balanced`, `Performance` or `Ultra Performance`.
void _setUpscalerQuality(LuminaActor self, [String quality = 'Quality']) => _userSettings(self).setUpscalerQuality(quality);
String _getUpscalerQuality(LuminaActor self) => _userSettings(self).upscalerQuality;

void _setUpscalerSharpness(LuminaActor self, [double sharpness = 0.5]) => _userSettings(self).setUpscalerSharpness(sharpness);
double _getUpscalerSharpness(LuminaActor self) => _userSettings(self).upscalerSharpness;

void _setFrameGenerationEnabled(LuminaActor self, [bool enabled = true]) =>
    _userSettings(self).setFrameGenerationEnabled(enabled);
bool _getFrameGenerationEnabled(LuminaActor self) => _userSettings(self).frameGenerationEnabled;

/// `FSR3` or `DLSS`: who generates the frames when frame generation is on.
void _setFrameGenerator(LuminaActor self, [String generator = 'DLSS']) => _userSettings(self).setFrameGenerator(generator);
String _getFrameGenerator(LuminaActor self) => _userSettings(self).frameGenerator;

/// Frames DLSS generates per rendered frame, 1 (2x) to 5 (6x, RTX 50 class GPUs).
void _setDlssGeneratedFrames(LuminaActor self, [int frames = 1]) => _userSettings(self).setDlssGeneratedFrames(frames);
int _getDlssGeneratedFrames(LuminaActor self) => _userSettings(self).dlssGeneratedFrames;

bool _isRayReconstructionSupported(LuminaActor self) => _userSettings(self).isRayReconstructionSupported;
bool _isDlssFrameGenerationSupported(LuminaActor self) => _userSettings(self).isDlssFrameGenerationSupported;
int _getMaxDlssGeneratedFrames(LuminaActor self) => _userSettings(self).maxDlssGeneratedFrames;

bool _isRayTracingSupported(LuminaActor self) => _userSettings(self).isRayTracingSupported;
bool _isDlssSupported(LuminaActor self) => _userSettings(self).isDlssSupported;
bool _isFsr3Supported(LuminaActor self) => _userSettings(self).isFsr3Supported;
bool _isFrameGenerationSupported(LuminaActor self) => _userSettings(self).isFrameGenerationSupported;

/// The upscalers this GPU can run, `None` first.
List<Object?> _getSupportedUpscalers(LuminaActor self) => List<Object?>.of(_userSettings(self).supportedUpscalers);

/// The upscaler rendering after the last apply (a fallback may differ from Get Upscaler).
String _getActiveUpscaler(LuminaActor self) => _userSettings(self).activeUpscaler;
bool _isRayTracingActive(LuminaActor self) => _userSettings(self).rayTracingActive;

/// Writes the user settings to `GameUserSettings.json` in the background.
void _saveGameUserSettings(LuminaActor self) => unawaited(_userSettings(self).saveSettings());

/// Reads `GameUserSettings.json` in the background and applies it when it
/// arrives (nothing changes when there is none).
void _loadGameUserSettings(LuminaActor self) => unawaited(_userSettings(self).loadSettings());
