import 'package:flutter_filament/filament.dart';
import 'package:lumina_core/lumina_core.dart' show EngineLoggerService;

import 'package:lumina/src/post_process/fsr3_settings.dart';

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
  const LuminaDlssSettings({this.enabled = false, this.quality = DlssQuality.balanced, this.rayReconstruction = false});

  final bool enabled;
  final DlssQuality quality;

  /// Run DLSS Ray Reconstruction (the denoising upscaler, `nvngx_dlssd`)
  /// instead of Super Resolution; it reads the view's guide buffers.
  final bool rayReconstruction;

  LuminaDlssSettings copyWith({bool? enabled, DlssQuality? quality, bool? rayReconstruction}) => LuminaDlssSettings(
        enabled: enabled ?? this.enabled,
        quality: quality ?? this.quality,
        rayReconstruction: rayReconstruction ?? this.rayReconstruction,
      );

  Map<String, dynamic> toMap() => {'enabled': enabled, 'quality': quality.name, 'ray_reconstruction': rayReconstruction};

  factory LuminaDlssSettings.fromMap(Map<String, dynamic> map) {
    final name = map['quality'];
    return LuminaDlssSettings(
      enabled: map['enabled'] as bool? ?? false,
      quality: DlssQuality.values.where((q) => q.name == name).firstOrNull ?? DlssQuality.balanced,
      rayReconstruction: map['ray_reconstruction'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LuminaDlssSettings &&
      other.enabled == enabled &&
      other.quality == quality &&
      other.rayReconstruction == rayReconstruction;

  @override
  int get hashCode => Object.hash(enabled, quality, rayReconstruction);

  @override
  String toString() =>
      'LuminaDlssSettings(enabled: $enabled, quality: ${quality.name}, rayReconstruction: $rayReconstruction)';
}

/// DLSS Frame Generation for a view: [generatedFrames] frames generated
/// before each rendered one (0 is off, 1 is 2x, up to 5 for 6x on RTX 50
/// class GPUs). Extra presents happen only for views rendered into a
/// SwapChain; a view drawn by Flutter shows one generated frame per rendered
/// frame.
class LuminaDlssFrameGenerationSettings {
  const LuminaDlssFrameGenerationSettings({this.generatedFrames = 0});

  final int generatedFrames;

  bool get enabled => generatedFrames > 0;

  Map<String, dynamic> toMap() => {'generated_frames': generatedFrames};

  factory LuminaDlssFrameGenerationSettings.fromMap(Map<String, dynamic> map) {
    final n = map['generated_frames'];
    return LuminaDlssFrameGenerationSettings(generatedFrames: n is int ? n.clamp(0, 5) : 0);
  }

  @override
  bool operator ==(Object other) =>
      other is LuminaDlssFrameGenerationSettings && other.generatedFrames == generatedFrames;

  @override
  int get hashCode => generatedFrames.hashCode;

  @override
  String toString() => 'LuminaDlssFrameGenerationSettings(generatedFrames: $generatedFrames)';
}

/// Applies [LuminaRayTracingSettings], [LuminaDlssSettings] and
/// [LuminaFsr3Settings] to one view: the scene's acceleration structures, the
/// directional lights' shadow options, the view's ReSTIR options, a [Dlss]
/// instance that follows the viewport size, and the FSR3 TAA options when
/// DLSS is not active.
///
/// Call [requestExtensions] once before the engine exists. [apply] is cheap to
/// call every frame: it only touches Filament when something changed.
class LuminaRtxController {
  LuminaRtxController({required this.engine, required this.view, required this.scene});

  final FilamentEngine engine;
  final FilamentView view;
  final FilamentScene scene;

  Dlss? _dlss;
  DlssRayReconstruction? _rayReconstruction;
  DlssFrameGenerator? _frameGenerator;
  LuminaDlssFrameGenerationSettings? _appliedFrameGeneration;
  LuminaRayTracingSettings? _appliedRayTracing;
  LuminaDlssSettings? _appliedDlss;
  LuminaFsr3Settings? _appliedFsr3;
  bool _fsr3OnView = false;
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
      EngineLoggerService().log('ray tracing extensions not requested: $e', level: 'warning', source: 'LuminaRtxController');
    }
    try {
      if (dlssRuntimeDir != null) Dlss.runtimeDirectory = dlssRuntimeDir;
      if (Dlss.available) Dlss.requestExtensions();
      if (DlssFrameGeneration.available) DlssFrameGeneration.requestExtensions();
    } catch (e) {
      EngineLoggerService().log('DLSS extensions not requested: $e', level: 'warning', source: 'LuminaRtxController');
    }
    return requested;
  }

  static final Expando<bool> _rayReconstructionByEngine = Expando<bool>('rayReconstruction');
  static final Expando<int> _generatedFramesByEngine = Expando<int>('dlssGeneratedFrames');

  /// Whether [engine]'s GPU and driver run DLSS Ray Reconstruction (asked
  /// once per engine: NGX starts for the query).
  static bool rayReconstructionSupported(FilamentEngine engine) {
    final cached = _rayReconstructionByEngine[engine];
    if (cached != null) return cached;
    var supported = false;
    try {
      supported = DlssRayReconstruction.available && DlssRayReconstruction.supported(engine);
    } catch (_) {
      supported = false;
    }
    _rayReconstructionByEngine[engine] = supported;
    return supported;
  }

  /// The most frames DLSS Frame Generation generates per rendered frame on
  /// [engine]'s GPU (0 without it; asked once per engine).
  static int maxDlssGeneratedFrames(FilamentEngine engine) {
    final cached = _generatedFramesByEngine[engine];
    if (cached != null) return cached;
    var max = 0;
    try {
      if (DlssFrameGeneration.available) {
        final probe = DlssFrameGeneration.probe(engine);
        if (probe != null && probe.available && !probe.needsUpdatedDriver) {
          max = probe.multiFrameCountMax < 1 ? 1 : probe.multiFrameCountMax.clamp(1, 5);
        }
      }
    } catch (_) {
      max = 0;
    }
    _generatedFramesByEngine[engine] = max;
    return max;
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

  /// The live DLSS Ray Reconstruction instance, while it is applied.
  DlssRayReconstruction? get rayReconstruction => _rayReconstruction;

  /// The live DLSS frame generator, while DLSS frame generation is applied.
  DlssFrameGenerator? get frameGenerator => _frameGenerator;

  /// The DLSS frame generation settings last applied.
  LuminaDlssFrameGenerationSettings? get appliedFrameGeneration => _appliedFrameGeneration;

  /// The ray tracing settings last applied.
  LuminaRayTracingSettings? get appliedRayTracing => _appliedRayTracing;

  /// The DLSS settings last applied.
  LuminaDlssSettings? get appliedDlss => _appliedDlss;

  /// The FSR3 settings last applied.
  LuminaFsr3Settings? get appliedFsr3 => _appliedFsr3;

  /// FSR3 is on the view right now (enabled, motion vectors available, no DLSS).
  bool get fsr3Active => _fsr3OnView;

  /// The engine renders the structure pass motion vectors FSR3 needs.
  bool get fsr3Supported => view.motionVectorsSupported;

  /// Applies the settings. [baseTaa] and [baseDynamicResolution] are the
  /// view's values without DLSS or FSR3 (the scalability profile's), restored
  /// when both are off; DLSS itself needs TAA with motion vectors and takes
  /// precedence over [fsr3] while it runs.
  void apply(
    LuminaRayTracingSettings rayTracing,
    LuminaDlssSettings dlss, {
    LuminaFsr3Settings fsr3 = const LuminaFsr3Settings(),
    LuminaDlssFrameGenerationSettings dlssFrameGeneration = const LuminaDlssFrameGenerationSettings(),
    required TemporalAntiAliasingOptions baseTaa,
    required DynamicResolutionOptions baseDynamicResolution,
  }) {
    _applyRayTracing(rayTracing);
    _applyDlss(dlss, baseTaa: baseTaa, baseDynamicResolution: baseDynamicResolution);
    _applyFsr3(fsr3, baseTaa: baseTaa, baseDynamicResolution: baseDynamicResolution);
    _applyFrameGeneration(dlssFrameGeneration);
  }

  void _applyFrameGeneration(LuminaDlssFrameGenerationSettings settings) {
    final wanted = settings.enabled && maxDlssGeneratedFrames(engine) > 0;
    if (!wanted) {
      _frameGenerator?.destroy();
      _frameGenerator = null;
    } else if (_frameGenerator == null) {
      try {
        _frameGenerator = DlssFrameGenerator.create(engine: engine, view: view, generatedFrames: settings.generatedFrames);
      } catch (e) {
        EngineLoggerService().log('DLSS frame generation not created: $e', level: 'warning', source: 'LuminaRtxController');
      }
    } else if (_frameGenerator!.generatedFrames != settings.generatedFrames) {
      _frameGenerator!.generatedFrames = settings.generatedFrames;
    }
    _appliedFrameGeneration = settings;
  }

  void _applyFsr3(
    LuminaFsr3Settings settings, {
    required TemporalAntiAliasingOptions baseTaa,
    required DynamicResolutionOptions baseDynamicResolution,
  }) {
    final wanted = settings.enabled && _dlss == null && _rayReconstruction == null && fsr3Supported;
    if (wanted && (!_fsr3OnView || _appliedFsr3 != settings)) {
      view.temporalAntiAliasingOptions = settings.taaOptions(baseTaa);
      view.dynamicResolutionOptions = settings.dynamicResolutionOptions;
      _fsr3OnView = true;
    } else if (!wanted && _fsr3OnView) {
      _fsr3OnView = false;
      if (_dlss == null && _rayReconstruction == null) {
        view.temporalAntiAliasingOptions = baseTaa;
        view.dynamicResolutionOptions = baseDynamicResolution;
      }
    }
    _appliedFsr3 = settings;
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
    final wantRayReconstruction = wanted && settings.rayReconstruction && rayReconstructionSupported(engine);
    final modeChanged = (wantRayReconstruction && _dlss != null) || (!wantRayReconstruction && _rayReconstruction != null);
    if (!wanted || sizeChanged || modeChanged) {
      if (_dlss != null || _rayReconstruction != null) {
        _dlss?.destroy();
        _dlss = null;
        _rayReconstruction?.destroy();
        _rayReconstruction = null;
        _dlssOutputSize = null;
        view.dynamicResolutionOptions = baseDynamicResolution;
        view.temporalAntiAliasingOptions = baseTaa;
        _fsr3OnView = false; // FSR3, if wanted, is put back by _applyFsr3
      }
    }
    if (wantRayReconstruction) {
      if (_rayReconstruction == null) {
        _fsr3OnView = false;
        try {
          _rayReconstruction = DlssRayReconstruction.create(
            engine: engine,
            view: view,
            options: DlssRayReconstructionOptions(quality: settings.quality, outputWidth: width, outputHeight: height),
          );
          _dlssOutputSize = (width, height);
        } catch (e) {
          EngineLoggerService().log('DLSS Ray Reconstruction not created: $e', level: 'warning', source: 'LuminaRtxController');
          view.temporalAntiAliasingOptions = baseTaa;
          view.dynamicResolutionOptions = baseDynamicResolution;
        }
      } else if (_appliedDlss?.quality != settings.quality) {
        _rayReconstruction!.quality = settings.quality;
      }
      _appliedDlss = settings;
      return;
    }
    if (wanted && _dlss == null) {
      _fsr3OnView = false; // DLSS owns the TAA options from here
      view.temporalAntiAliasingOptions = baseTaa.copyWith(enabled: true, motionVectors: true);
      try {
        _dlss = Dlss.create(
          engine: engine,
          view: view,
          options: DlssOptions(quality: settings.quality, outputWidth: width, outputHeight: height),
        );
        _dlssOutputSize = (width, height);
      } catch (e) {
        EngineLoggerService().log('DLSS not created: $e', level: 'warning', source: 'LuminaRtxController');
        view.temporalAntiAliasingOptions = baseTaa;
        view.dynamicResolutionOptions = baseDynamicResolution;
      }
    } else if (wanted && _dlss != null && _appliedDlss?.quality != settings.quality) {
      _dlss!.quality = settings.quality;
    }
    _appliedDlss = settings;
  }

  /// Forgets what this controller put on the view, so the next [apply] pushes
  /// everything again (DLSS is recreated). Call it after something else
  /// rewrote the view's TAA or dynamic resolution options, such as a
  /// scalability profile.
  void invalidate() {
    _dlss?.destroy();
    _dlss = null;
    _rayReconstruction?.destroy();
    _rayReconstruction = null;
    _frameGenerator?.destroy();
    _frameGenerator = null;
    _appliedFrameGeneration = null;
    _dlssOutputSize = null;
    _fsr3OnView = false;
    _appliedRayTracing = null;
    _appliedDlss = null;
    _appliedFsr3 = null;
  }

  /// Releases the DLSS instance; the view keeps the last ray tracing settings.
  void dispose() {
    _dlss?.destroy();
    _dlss = null;
    _rayReconstruction?.destroy();
    _rayReconstruction = null;
    _frameGenerator?.destroy();
    _frameGenerator = null;
    _dlssOutputSize = null;
  }
}
