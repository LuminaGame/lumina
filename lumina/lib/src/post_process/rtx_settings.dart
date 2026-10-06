import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_filament/flutter_filament.dart';

/// Hardware ray tracing for a view: the scene's acceleration structures,
/// ray-traced sun shadows and ReSTIR direct lighting of the punctual lights.
///
/// Everything needs a Vulkan engine created after [LuminaRtxController.requestExtensions]
/// on a GPU with ray query support; without it the settings are kept and the
/// shadow maps and the froxel light loop render as before.
class LuminaRayTracingSettings {
  const LuminaRayTracingSettings({
    this.enabled = false,
    this.sunShadows = true,
    this.restir = false,
    this.restirCandidates = 8,
    this.restirSpatialSamples = 2,
  });

  /// Keep the scene's acceleration structures (the switch for everything below).
  final bool enabled;

  /// Replace the directional light's cascaded shadow maps with ray-traced hard shadows.
  final bool sunShadows;

  /// Shade the punctual lights with ReSTIR direct lighting instead of the froxel loop.
  final bool restir;

  /// Lights sampled per pixel and frame by ReSTIR before reuse (1 to 64).
  final int restirCandidates;

  /// Neighbouring reservoirs ReSTIR merges per pixel (0 to 8).
  final int restirSpatialSamples;

  /// The ReSTIR options these settings describe.
  RestirOptions get restirOptions => RestirOptions(
        enabled: enabled && restir,
        initialCandidates: restirCandidates.clamp(1, 64),
        spatialSamples: restirSpatialSamples.clamp(0, 8),
      );

  LuminaRayTracingSettings copyWith({
    bool? enabled,
    bool? sunShadows,
    bool? restir,
    int? restirCandidates,
    int? restirSpatialSamples,
  }) {
    return LuminaRayTracingSettings(
      enabled: enabled ?? this.enabled,
      sunShadows: sunShadows ?? this.sunShadows,
      restir: restir ?? this.restir,
      restirCandidates: (restirCandidates ?? this.restirCandidates).clamp(1, 64),
      restirSpatialSamples: (restirSpatialSamples ?? this.restirSpatialSamples).clamp(0, 8),
    );
  }

  Map<String, dynamic> toMap() => {
        'enabled': enabled,
        'sun_shadows': sunShadows,
        'restir': restir,
        'restir_candidates': restirCandidates,
        'restir_spatial_samples': restirSpatialSamples,
      };

  factory LuminaRayTracingSettings.fromMap(Map<String, dynamic> map) {
    final candidates = map['restir_candidates'];
    final spatial = map['restir_spatial_samples'];
    return LuminaRayTracingSettings(
      enabled: map['enabled'] as bool? ?? false,
      sunShadows: map['sun_shadows'] as bool? ?? true,
      restir: map['restir'] as bool? ?? false,
      restirCandidates: candidates is int ? candidates.clamp(1, 64) : 8,
      restirSpatialSamples: spatial is int ? spatial.clamp(0, 8) : 2,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LuminaRayTracingSettings &&
      other.enabled == enabled &&
      other.sunShadows == sunShadows &&
      other.restir == restir &&
      other.restirCandidates == restirCandidates &&
      other.restirSpatialSamples == restirSpatialSamples;

  @override
  int get hashCode => Object.hash(enabled, sunShadows, restir, restirCandidates, restirSpatialSamples);

  @override
  String toString() =>
      'LuminaRayTracingSettings(enabled: $enabled, sunShadows: $sunShadows, restir: $restir, candidates: $restirCandidates, spatial: $restirSpatialSamples)';
}

/// DLSS Super Resolution for a view: the view renders at the resolution NVIDIA
/// NGX picks for [quality] and DLSS reconstructs the output size. Needs the
/// fetched NGX runtime ([LuminaRtxController.dlssAvailable]) and a Vulkan
/// engine created after [LuminaRtxController.requestExtensions].
class LuminaDlssSettings {
  const LuminaDlssSettings({this.enabled = false, this.quality = DlssQuality.balanced});

  final bool enabled;
  final DlssQuality quality;

  LuminaDlssSettings copyWith({bool? enabled, DlssQuality? quality}) =>
      LuminaDlssSettings(enabled: enabled ?? this.enabled, quality: quality ?? this.quality);

  Map<String, dynamic> toMap() => {'enabled': enabled, 'quality': quality.name};

  factory LuminaDlssSettings.fromMap(Map<String, dynamic> map) {
    final name = map['quality'];
    return LuminaDlssSettings(
      enabled: map['enabled'] as bool? ?? false,
      quality: DlssQuality.values.where((q) => q.name == name).firstOrNull ?? DlssQuality.balanced,
    );
  }

  @override
  bool operator ==(Object other) => other is LuminaDlssSettings && other.enabled == enabled && other.quality == quality;

  @override
  int get hashCode => Object.hash(enabled, quality);

  @override
  String toString() => 'LuminaDlssSettings(enabled: $enabled, quality: ${quality.name})';
}

/// Applies [LuminaRayTracingSettings] and [LuminaDlssSettings] to one view: the
/// scene's acceleration structures, the directional lights' shadow options, the
/// view's ReSTIR options and a [Dlss] instance that follows the viewport size.
///
/// Call [requestExtensions] once before the engine exists. [apply] is cheap to
/// call every frame: it only touches Filament when something changed.
class LuminaRtxController {
  LuminaRtxController({required this.engine, required this.view, required this.scene});

  final FilamentEngine engine;
  final FilamentView view;
  final FilamentScene scene;

  Dlss? _dlss;
  LuminaRayTracingSettings? _appliedRayTracing;
  LuminaDlssSettings? _appliedDlss;
  (int, int)? _dlssOutputSize;
  final Set<int> _rayTracedSuns = <int>{};

  /// Asks the engines created from now on for the Vulkan ray query extensions
  /// and, when the NGX runtime is present, the DLSS ones. [dlssRuntimeDir] names
  /// the fetched NGX SDK (or the folder of its runtime) to look in first.
  /// Returns whether ray tracing could be requested on this platform.
  static bool requestExtensions({String? dlssRuntimeDir}) {
    var requested = false;
    try {
      requested = RayTracing.requestExtensions();
    } catch (e) {
      debugPrint('[LuminaRtxController] ray tracing extensions not requested: $e');
    }
    try {
      if (dlssRuntimeDir != null) Dlss.runtimeDirectory = dlssRuntimeDir;
      if (Dlss.available) Dlss.requestExtensions();
    } catch (e) {
      debugPrint('[LuminaRtxController] DLSS extensions not requested: $e');
    }
    return requested;
  }

  /// The NGX runtime was found and an NVIDIA Vulkan device exists.
  static bool get dlssAvailable {
    try {
      return Dlss.available;
    } catch (_) {
      return false;
    }
  }

  /// The engine traces rays (ray query extensions enabled on a capable GPU).
  bool get rayTracingSupported => engine.supportsRayQuery;

  /// The live DLSS instance, while DLSS is applied and the engine supports it.
  Dlss? get dlss => _dlss;

  /// The ray tracing settings last applied.
  LuminaRayTracingSettings? get appliedRayTracing => _appliedRayTracing;

  /// The DLSS settings last applied.
  LuminaDlssSettings? get appliedDlss => _appliedDlss;

  /// Applies both settings. [baseTaa] and [baseDynamicResolution] are the
  /// view's values without DLSS (the scalability profile's), restored when DLSS
  /// turns off; DLSS itself needs TAA with motion vectors.
  void apply(
    LuminaRayTracingSettings rayTracing,
    LuminaDlssSettings dlss, {
    required TemporalAntiAliasingOptions baseTaa,
    required DynamicResolutionOptions baseDynamicResolution,
  }) {
    _applyRayTracing(rayTracing);
    _applyDlss(dlss, baseTaa: baseTaa, baseDynamicResolution: baseDynamicResolution);
  }

  void _applyRayTracing(LuminaRayTracingSettings settings) {
    final supported = rayTracingSupported;
    final active = settings.enabled && supported;
    if (_appliedRayTracing != settings || _rayTracedSuns.isEmpty != !(active && settings.sunShadows)) {
      scene.rayTracingEnabled = active;
      view.restirOptions = active ? settings.restirOptions : const RestirOptions();
      _applySunShadows(active && settings.sunShadows);
      _appliedRayTracing = settings;
    } else if (active && settings.sunShadows) {
      // lights added since the last apply
      _applySunShadows(true);
    }
  }

  void _applySunShadows(bool rayTraced) {
    final lm = FilamentLightManager(engine);
    for (final entity in lm.entities) {
      if (!scene.hasEntity(entity) || !lm.isDirectional(entity)) continue;
      final current = lm.getShadowOptions(entity);
      final was = _rayTracedSuns.contains(entity);
      if (current.rayTraced == rayTraced && was == rayTraced) continue;
      current.rayTraced = rayTraced;
      lm.setShadowOptions(entity, current);
      if (rayTraced) {
        _rayTracedSuns.add(entity);
      } else {
        _rayTracedSuns.remove(entity);
      }
    }
    if (!rayTraced) _rayTracedSuns.clear();
  }

  void _applyDlss(
    LuminaDlssSettings settings, {
    required TemporalAntiAliasingOptions baseTaa,
    required DynamicResolutionOptions baseDynamicResolution,
  }) {
    final (_, _, width, height) = view.viewport;
    final wanted = settings.enabled && dlssAvailable && width > 0 && height > 0;
    final sizeChanged = _dlssOutputSize != null && _dlssOutputSize != (width, height);
    if (!wanted || sizeChanged) {
      if (_dlss != null) {
        _dlss!.destroy();
        _dlss = null;
        _dlssOutputSize = null;
        view.dynamicResolutionOptions = baseDynamicResolution;
        view.temporalAntiAliasingOptions = baseTaa;
      }
    }
    if (wanted && _dlss == null) {
      view.temporalAntiAliasingOptions = baseTaa.copyWith(enabled: true, motionVectors: true);
      try {
        _dlss = Dlss.create(
          engine: engine,
          view: view,
          options: DlssOptions(quality: settings.quality, outputWidth: width, outputHeight: height),
        );
        _dlssOutputSize = (width, height);
      } catch (e) {
        debugPrint('[LuminaRtxController] DLSS not created: $e');
        view.temporalAntiAliasingOptions = baseTaa;
        view.dynamicResolutionOptions = baseDynamicResolution;
      }
    } else if (wanted && _dlss != null && _appliedDlss?.quality != settings.quality) {
      _dlss!.quality = settings.quality;
    }
    _appliedDlss = settings;
  }

  /// Releases the DLSS instance; the view keeps the last ray tracing settings.
  void dispose() {
    _dlss?.destroy();
    _dlss = null;
    _dlssOutputSize = null;
  }
}
