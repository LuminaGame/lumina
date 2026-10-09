import 'package:flutter_filament/filament.dart';
import 'package:lumina_core/lumina_core.dart' show EngineLoggerService;

import 'package:lumina/src/post_process/rendering_features.dart';
import 'package:lumina/src/post_process/rtx_settings.dart';
import 'package:lumina/src/world/subsystem/world_subsystem.dart';

/// The ray tracing and upscaler half of the game user settings: the player's
/// choice ([renderingFeatures]), what the GPU supports ([renderingSupport]),
/// what is actually on ([activeRenderingFeatures]) and why something fell
/// back ([renderingFallbacks]).
///
/// Setters only stage the choice; [applyRenderingFeatures] (called by the
/// subsystem's `applySettings`) resolves it against the GPU and puts it on
/// the world's bound view through a [LuminaRtxController].
mixin LuminaUserSettingsRenderingFeatures on LuminaWorldSubsystem {
  LuminaRenderingFeatureSettings _features = const LuminaRenderingFeatureSettings();
  LuminaResolvedRenderingFeatures? _resolved;
  LuminaRtxController? _rtx;
  FilamentView? _rtxView;
  String? _dlssFailure;
  TemporalAntiAliasingOptions? _baseTaa;
  DynamicResolutionOptions? _baseDynamicResolution;
  List<String> _loggedFallbacks = const [];

  /// The player's ray tracing / upscaler choice (staged until applied).
  LuminaRenderingFeatureSettings get renderingFeatures => _features;

  /// Stages [settings] as the whole choice.
  void setRenderingFeatures(LuminaRenderingFeatureSettings settings) => _features = settings;

  bool get rayTracingEnabled => _features.rayTracing;
  void setRayTracingEnabled(bool enabled) => _features = _features.copyWith(rayTracing: enabled);

  bool get rayTracedShadowsEnabled => _features.rayTracedShadows;
  void setRayTracedShadowsEnabled(bool enabled) => _features = _features.copyWith(rayTracedShadows: enabled);

  bool get restirEnabled => _features.restir;
  void setRestirEnabled(bool enabled) => _features = _features.copyWith(restir: enabled);

  /// Lights ReSTIR samples per pixel and frame (clamped to 1–64).
  int get restirCandidates => _features.restirCandidates;
  void setRestirCandidates(int candidates) => _features = _features.copyWith(restirCandidates: candidates);

  /// Neighbouring reservoirs ReSTIR merges per pixel (clamped to 0–8).
  int get restirSpatialSamples => _features.restirSpatialSamples;
  void setRestirSpatialSamples(int samples) => _features = _features.copyWith(restirSpatialSamples: samples);

  /// The chosen upscaler: `None`, `FSR3` or `DLSS`.
  String get upscaler => _features.upscaler.displayName;
  void setUpscaler(String upscaler) => _features = _features.copyWith(upscaler: LuminaUpscaler.parse(upscaler));

  /// `Native AA`, `Quality`, `Balanced`, `Performance` or `Ultra Performance`.
  String get upscalerQuality => _features.upscalerQuality.displayName;
  void setUpscalerQuality(String quality) =>
      _features = _features.copyWith(upscalerQuality: LuminaUpscalerQuality.parse(quality));

  /// Sharpening after the upscale, 0–1 (FSR3; DLSS ignores it).
  double get upscalerSharpness => _features.sharpness;
  void setUpscalerSharpness(double sharpness) => _features = _features.copyWith(sharpness: sharpness);

  /// FSR3 frame generation.
  bool get frameGenerationEnabled => _features.frameGeneration;
  void setFrameGenerationEnabled(bool enabled) => _features = _features.copyWith(frameGeneration: enabled);

  /// What the world's renderer supports right now (nothing without one).
  LuminaRenderingFeatureSupport get renderingSupport {
    final w = world;
    final support = LuminaRenderingFeatureSupport.probe(engine: w?.filamentEngineOrNull, view: w?.filamentViewOrNull);
    final failure = _dlssFailure;
    return failure != null && support.dlss ? support.withoutDlss(failure) : support;
  }

  bool get isRayTracingSupported => renderingSupport.rayTracing;
  bool get isDlssSupported => renderingSupport.dlss;
  bool get isFsr3Supported => renderingSupport.fsr3;
  bool get isFrameGenerationSupported => renderingSupport.frameGeneration;

  /// The display names of the upscalers this GPU can run, `None` first.
  List<String> get supportedUpscalers => [for (final u in renderingSupport.supportedUpscalers) u.displayName];

  /// The settings last applied, after fallback (all off before the first apply).
  LuminaRenderingFeatureSettings get activeRenderingFeatures =>
      _resolved?.settings ?? const LuminaRenderingFeatureSettings();

  /// The upscaler actually rendering.
  String get activeUpscaler => activeRenderingFeatures.upscaler.displayName;

  /// Ray tracing is actually on.
  bool get rayTracingActive => activeRenderingFeatures.rayTracing;

  /// What the last apply changed from the choice, and why.
  List<String> get renderingFallbacks => _resolved?.fallbacks ?? const [];

  /// The sun should trace its shadows: ray tracing and its shadows are
  /// chosen and the GPU supports them.
  bool get rayTracedSunShadowsWanted {
    final s = _features.resolve(renderingSupport).settings;
    return s.rayTracing && s.rayTracedShadows;
  }

  /// The controller driving the world's view, while one is bound.
  LuminaRtxController? get rtxController => _rtx;

  /// Resolves the choice against the GPU and applies it to the world's view.
  /// [baseTaa] and [baseDynamicResolution] are the scalability profile's
  /// values, which the upscalers replace and give back when turned off.
  void applyRenderingFeatures({
    required TemporalAntiAliasingOptions baseTaa,
    required DynamicResolutionOptions baseDynamicResolution,
  }) {
    final baseChanged = baseTaa != _baseTaa || baseDynamicResolution != _baseDynamicResolution;
    _baseTaa = baseTaa;
    _baseDynamicResolution = baseDynamicResolution;
    var resolved = _features.resolve(renderingSupport);
    final controller = _controller();
    if (controller != null) {
      // The profile just rewrote the view's TAA / dynamic resolution.
      if (baseChanged) controller.invalidate();
      _push(controller, resolved.settings);
      final (_, _, width, height) = controller.view.viewport;
      if (resolved.settings.upscaler == LuminaUpscaler.dlss && controller.dlss == null && width > 0 && height > 0) {
        String? error;
        try {
          error = Dlss.lastErrorMessage;
        } catch (_) {}
        _dlssFailure = 'DLSS could not start: ${error ?? 'the engine was created without the DLSS extensions'}';
        resolved = _features.resolve(renderingSupport);
        _push(controller, resolved.settings);
      }
    }
    _resolved = resolved;
    _report(resolved.fallbacks);
  }

  /// Keeps DLSS on the viewport size and ray-traced shadows on newly added
  /// suns; cheap when nothing changed.
  void tickRenderingFeatures() {
    final controller = _rtx;
    final resolved = _resolved;
    if (controller == null || resolved == null || !identical(world?.filamentViewOrNull, _rtxView)) return;
    _push(controller, resolved.settings);
  }

  /// Releases DLSS and forgets the view.
  void disposeRenderingFeatures() {
    _rtx?.dispose();
    _rtx = null;
    _rtxView = null;
  }

  LuminaRtxController? _controller() {
    final w = world;
    final engine = w?.filamentEngineOrNull;
    final scene = w?.filamentSceneOrNull;
    final view = w?.filamentViewOrNull;
    if (engine == null || scene == null || view == null) {
      disposeRenderingFeatures();
      return null;
    }
    if (_rtx == null || !identical(_rtxView, view)) {
      _rtx?.dispose();
      _rtx = LuminaRtxController(engine: engine, view: view, scene: scene);
      _rtxView = view;
      _dlssFailure = null;
    }
    return _rtx;
  }

  void _push(LuminaRtxController controller, LuminaRenderingFeatureSettings s) {
    try {
      controller.apply(
        s.rayTracingSettings,
        s.dlssSettings,
        fsr3: s.fsr3Settings,
        baseTaa: _baseTaa ?? const TemporalAntiAliasingOptions(),
        baseDynamicResolution: _baseDynamicResolution ?? const DynamicResolutionOptions(),
      );
    } catch (e) {
      EngineLoggerService().log('ray tracing / upscaler settings not applied: $e',
          level: 'warning', source: 'LuminaUserSettingsSubsystem');
    }
  }

  void _report(List<String> fallbacks) {
    if (_sameList(fallbacks, _loggedFallbacks)) return;
    _loggedFallbacks = fallbacks;
    for (final m in fallbacks) {
      EngineLoggerService().log(m, level: 'warning', source: 'LuminaUserSettingsSubsystem');
    }
  }

  static bool _sameList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
