import 'package:flutter_filament/filament.dart';

import 'package:lumina/src/post_process/fsr3_settings.dart';
import 'package:lumina/src/post_process/rtx_settings.dart';
import 'package:lumina/src/utility/lumina_platform.dart';

/// The upscaler a game renders with: none (native resolution and the
/// anti-aliasing setting), FidelityFX Super Resolution 3, NVIDIA DLSS
/// Super Resolution, or NVIDIA DLSS Ray Reconstruction (a denoising upscaler
/// for ray-traced lighting).
enum LuminaUpscaler {
  none('None'),
  fsr3('FSR3'),
  dlss('DLSS'),
  dlssRayReconstruction('DLSS RR');

  const LuminaUpscaler(this.displayName);

  /// The name the Blueprint nodes and the settings file use.
  final String displayName;

  /// [text] as an upscaler: the display name in any case, `fsr` for FSR3;
  /// anything else is [none].
  static LuminaUpscaler parse(String? text) {
    final t = (text ?? '').trim().toLowerCase();
    if (t == 'fsr3' || t == 'fsr') return fsr3;
    if (t == 'dlss') return dlss;
    final compact = t.replaceAll(RegExp(r'[\s_\-]'), '');
    if (compact == 'dlssrr' || compact == 'rayreconstruction' || compact == 'dlssrayreconstruction') {
      return dlssRayReconstruction;
    }
    return none;
  }
}

/// Which technique generates frames when frame generation is on: AMD's FSR3
/// frame interpolation (with the FSR3 upscaler) or NVIDIA DLSS Frame
/// Generation (any upscaler; up to five generated frames per rendered frame
/// on RTX 50 class GPUs).
enum LuminaFrameGenerator {
  fsr3('FSR3'),
  dlss('DLSS');

  const LuminaFrameGenerator(this.displayName);

  /// The name the Blueprint nodes and the settings file use.
  final String displayName;

  /// [text] as a generator: `DLSS` in any case is [dlss], anything else [fsr3].
  static LuminaFrameGenerator parse(String? text) =>
      (text ?? '').trim().toLowerCase().startsWith('dlss') ? dlss : fsr3;
}

/// How far below the output resolution an upscaler renders, one scale for
/// both upscalers: each maps to the matching FSR3 and DLSS preset.
enum LuminaUpscalerQuality {
  /// Full resolution: the upscaler only anti-aliases (FSR3 native AA, DLAA).
  nativeAA('Native AA', LuminaFsr3Quality.nativeAA, DlssQuality.dlaa),

  /// About two thirds of the output per axis.
  quality('Quality', LuminaFsr3Quality.quality, DlssQuality.maxQuality),

  /// About 58% of the output per axis.
  balanced('Balanced', LuminaFsr3Quality.balanced, DlssQuality.balanced),

  /// Half of the output per axis.
  performance('Performance', LuminaFsr3Quality.performance, DlssQuality.maxPerformance),

  /// A third of the output per axis.
  ultraPerformance('Ultra Performance', LuminaFsr3Quality.ultraPerformance, DlssQuality.ultraPerformance);

  const LuminaUpscalerQuality(this.displayName, this.fsr3, this.dlss);

  /// The name the Blueprint nodes and the settings file use.
  final String displayName;

  /// The FSR3 preset of this quality.
  final LuminaFsr3Quality fsr3;

  /// The DLSS quality mode of this quality.
  final DlssQuality dlss;

  /// [text] as a quality, ignoring case, spaces and underscores (`DLAA` and
  /// `native` are [nativeAA]); anything else is [quality].
  static LuminaUpscalerQuality parse(String? text) {
    final t = (text ?? '').toLowerCase().replaceAll(RegExp(r'[\s_\-]'), '');
    switch (t) {
      case 'nativeaa':
      case 'native':
      case 'dlaa':
        return nativeAA;
      case 'balanced':
        return balanced;
      case 'performance':
        return performance;
      case 'ultraperformance':
        return ultraPerformance;
      default:
        return quality;
    }
  }
}

/// What the game's GPU and engine can do, with the reason for each "no".
class LuminaRenderingFeatureSupport {
  const LuminaRenderingFeatureSupport({
    required this.rayTracing,
    required this.dlss,
    required this.fsr3,
    required this.frameGeneration,
    this.rayReconstruction = false,
    this.dlssFrameGeneration = false,
    this.maxDlssGeneratedFrames = 0,
    this.rayTracingReason = '',
    this.dlssReason = '',
    this.fsr3Reason = '',
    this.frameGenerationReason = '',
    this.rayReconstructionReason = 'not probed',
    this.dlssFrameGenerationReason = 'not probed',
  });

  /// Nothing is supported, for [reason] (the web, no renderer bound).
  factory LuminaRenderingFeatureSupport.none(String reason) => LuminaRenderingFeatureSupport(
        rayTracing: false,
        dlss: false,
        fsr3: false,
        frameGeneration: false,
        rayTracingReason: reason,
        dlssReason: reason,
        fsr3Reason: reason,
        frameGenerationReason: reason,
        rayReconstructionReason: reason,
        dlssFrameGenerationReason: reason,
      );

  /// Asks [engine] and [view]: ray tracing needs Vulkan ray query (the
  /// extensions requested before the engine was created, see
  /// [LuminaRtxController.requestExtensions]); DLSS needs the Vulkan backend,
  /// an NVIDIA GPU and the NGX runtime; FSR3 and its frame generation need
  /// the structure pass motion vectors (feature level 1 or higher). Nothing
  /// on the web.
  static LuminaRenderingFeatureSupport probe({
    required FilamentEngine? engine,
    required FilamentView? view,
    bool isWeb = LuminaPlatform.isWeb,
  }) {
    if (isWeb) return LuminaRenderingFeatureSupport.none('not available on the web');
    if (engine == null || view == null) return LuminaRenderingFeatureSupport.none('no renderer is bound to the world');
    bool ask(bool Function() f) {
      try {
        return f();
      } catch (_) {
        return false;
      }
    }

    final rayTracing = ask(() => engine.supportsRayQuery);
    final vulkan = ask(() => engine.backend == FilamentBackend.vulkan);
    final dlss = vulkan && LuminaRtxController.dlssAvailable;
    final motionVectors = ask(() => view.motionVectorsSupported);
    const fsr3Reason = 'needs motion vectors (a GPU backend at feature level 1 or higher)';
    final rayReconstruction = dlss && ask(() => LuminaRtxController.rayReconstructionSupported(engine));
    final frameGenerationMax = vulkan ? LuminaRtxController.maxDlssGeneratedFrames(engine) : 0;
    return LuminaRenderingFeatureSupport(
      rayTracing: rayTracing,
      dlss: dlss,
      fsr3: motionVectors,
      frameGeneration: motionVectors,
      rayReconstruction: rayReconstruction,
      dlssFrameGeneration: frameGenerationMax > 0,
      maxDlssGeneratedFrames: frameGenerationMax,
      rayReconstructionReason: rayReconstruction
          ? ''
          : vulkan
              ? 'needs an NVIDIA RTX GPU and the NGX Ray Reconstruction runtime (nvngx_dlssd)'
              : 'needs the Vulkan backend',
      dlssFrameGenerationReason: frameGenerationMax > 0
          ? ''
          : vulkan
              ? 'needs an NVIDIA RTX 40 or newer GPU and the NGX Frame Generation runtime (nvngx_dlssg)'
              : 'needs the Vulkan backend',
      rayTracingReason:
          rayTracing ? '' : 'needs Vulkan ray query (a ray tracing GPU and driver, extensions requested before the engine)',
      dlssReason: dlss
          ? ''
          : vulkan
              ? 'needs an NVIDIA GPU and the NGX runtime (nvngx_dlss)'
              : 'needs the Vulkan backend',
      fsr3Reason: motionVectors ? '' : fsr3Reason,
      frameGenerationReason: motionVectors ? '' : fsr3Reason,
    );
  }

  final bool rayTracing;
  final bool dlss;
  final bool fsr3;

  /// FSR3 frame generation (needs the FSR3 upscaler when applied).
  final bool frameGeneration;

  /// DLSS Ray Reconstruction (the `nvngx_dlssd` runtime on an RTX GPU).
  final bool rayReconstruction;

  /// DLSS Frame Generation (the `nvngx_dlssg` runtime on an RTX 40 or newer GPU).
  final bool dlssFrameGeneration;

  /// The most frames DLSS can generate per rendered frame on this GPU (1 is
  /// 2x; 3 to 5 are Multi Frame Generation on RTX 50 class GPUs); 0 without
  /// [dlssFrameGeneration].
  final int maxDlssGeneratedFrames;

  final String rayTracingReason;
  final String dlssReason;
  final String fsr3Reason;
  final String frameGenerationReason;
  final String rayReconstructionReason;
  final String dlssFrameGenerationReason;

  /// This support with DLSS (and Ray Reconstruction) turned off for [reason]
  /// (DLSS failed to start).
  LuminaRenderingFeatureSupport withoutDlss(String reason) => LuminaRenderingFeatureSupport(
        rayTracing: rayTracing,
        dlss: false,
        fsr3: fsr3,
        frameGeneration: frameGeneration,
        rayReconstruction: false,
        dlssFrameGeneration: dlssFrameGeneration,
        maxDlssGeneratedFrames: maxDlssGeneratedFrames,
        rayTracingReason: rayTracingReason,
        dlssReason: reason,
        fsr3Reason: fsr3Reason,
        frameGenerationReason: frameGenerationReason,
        rayReconstructionReason: reason,
        dlssFrameGenerationReason: dlssFrameGenerationReason,
      );

  /// This support with Ray Reconstruction turned off for [reason] (it failed
  /// to start).
  LuminaRenderingFeatureSupport withoutRayReconstruction(String reason) => LuminaRenderingFeatureSupport(
        rayTracing: rayTracing,
        dlss: dlss,
        fsr3: fsr3,
        frameGeneration: frameGeneration,
        rayReconstruction: false,
        dlssFrameGeneration: dlssFrameGeneration,
        maxDlssGeneratedFrames: maxDlssGeneratedFrames,
        rayTracingReason: rayTracingReason,
        dlssReason: dlssReason,
        fsr3Reason: fsr3Reason,
        frameGenerationReason: frameGenerationReason,
        rayReconstructionReason: reason,
        dlssFrameGenerationReason: dlssFrameGenerationReason,
      );

  /// The upscalers that can be chosen, [LuminaUpscaler.none] always first.
  List<LuminaUpscaler> get supportedUpscalers => [
        LuminaUpscaler.none,
        if (fsr3) LuminaUpscaler.fsr3,
        if (dlss) LuminaUpscaler.dlss,
        if (rayReconstruction) LuminaUpscaler.dlssRayReconstruction,
      ];

  @override
  String toString() => 'LuminaRenderingFeatureSupport(rayTracing: $rayTracing, dlss: $dlss, fsr3: $fsr3, '
      'frameGeneration: $frameGeneration, rayReconstruction: $rayReconstruction, '
      'dlssFrameGeneration: $dlssFrameGeneration (max $maxDlssGeneratedFrames))';
}

/// What the game's ray tracing / upscaler choice resolves to on one GPU:
/// [settings] is what is applied, [fallbacks] says what was changed and why.
class LuminaResolvedRenderingFeatures {
  const LuminaResolvedRenderingFeatures(this.settings, this.fallbacks);

  final LuminaRenderingFeatureSettings settings;
  final List<String> fallbacks;
}

/// The player's ray tracing and upscaling choice, part of the game user
/// settings: hardware ray tracing (ray-traced sun shadows, ReSTIR direct
/// lighting), the upscaler with its quality and sharpness, and FSR3 frame
/// generation. Immutable, with value equality and a JSON form.
class LuminaRenderingFeatureSettings {
  const LuminaRenderingFeatureSettings({
    this.rayTracing = false,
    this.rayTracedShadows = true,
    this.restir = false,
    this.restirCandidates = 8,
    this.restirSpatialSamples = 2,
    this.upscaler = LuminaUpscaler.none,
    this.upscalerQuality = LuminaUpscalerQuality.quality,
    this.sharpness = 0.5,
    this.frameGeneration = false,
    this.frameGenerator = LuminaFrameGenerator.fsr3,
    this.dlssGeneratedFrames = 1,
  });

  /// Hardware ray tracing (the switch for [rayTracedShadows] and [restir]).
  final bool rayTracing;

  /// The sun casts ray-traced hard shadows instead of shadow maps.
  final bool rayTracedShadows;

  /// Punctual lights are shaded with ReSTIR direct lighting.
  final bool restir;

  /// Lights ReSTIR samples per pixel and frame (1 to 64).
  final int restirCandidates;

  /// Neighbouring reservoirs ReSTIR merges per pixel (0 to 8).
  final int restirSpatialSamples;

  final LuminaUpscaler upscaler;
  final LuminaUpscalerQuality upscalerQuality;

  /// Sharpening after the upscale, 0 to 1 (FSR3's RCAS; DLSS ignores it).
  final double sharpness;

  /// Frame generation: generated frames before each rendered one, by
  /// [frameGenerator].
  final bool frameGeneration;

  /// Who generates the frames: FSR3 (one interpolated frame, with the FSR3
  /// upscaler) or DLSS ([dlssGeneratedFrames] frames, any upscaler).
  final LuminaFrameGenerator frameGenerator;

  /// Frames DLSS generates per rendered frame, 1 (2x) to 5 (6x).
  final int dlssGeneratedFrames;

  /// The ray tracing settings for the view.
  LuminaRayTracingSettings get rayTracingSettings => LuminaRayTracingSettings(
        enabled: rayTracing,
        sunShadows: rayTracedShadows,
        restir: restir,
        restirCandidates: restirCandidates,
        restirSpatialSamples: restirSpatialSamples,
      );

  /// The FSR3 settings for the view (enabled when [upscaler] is FSR3).
  LuminaFsr3Settings get fsr3Settings => LuminaFsr3Settings(
        enabled: upscaler == LuminaUpscaler.fsr3,
        quality: upscalerQuality.fsr3,
        sharpness: sharpness,
        frameGeneration: frameGeneration && frameGenerator == LuminaFrameGenerator.fsr3,
      );

  /// The DLSS settings for the view (enabled when [upscaler] is DLSS or DLSS
  /// Ray Reconstruction).
  LuminaDlssSettings get dlssSettings => LuminaDlssSettings(
        enabled: upscaler == LuminaUpscaler.dlss || upscaler == LuminaUpscaler.dlssRayReconstruction,
        quality: upscalerQuality.dlss,
        rayReconstruction: upscaler == LuminaUpscaler.dlssRayReconstruction,
      );

  /// The DLSS frame generation settings for the view (off unless frame
  /// generation is on with the DLSS generator).
  LuminaDlssFrameGenerationSettings get dlssFrameGenerationSettings => LuminaDlssFrameGenerationSettings(
        generatedFrames: frameGeneration && frameGenerator == LuminaFrameGenerator.dlss ? dlssGeneratedFrames : 0,
      );

  /// These settings on a GPU with [support]: ray tracing off when it cannot
  /// trace rays; DLSS falls back to FSR3, FSR3 to none; frame generation only
  /// with the FSR3 upscaler. Each change is reported.
  LuminaResolvedRenderingFeatures resolve(LuminaRenderingFeatureSupport support) {
    final fallbacks = <String>[];
    var rt = rayTracing;
    if (rt && !support.rayTracing) {
      rt = false;
      fallbacks.add('Ray tracing is off: ${support.rayTracingReason}.');
    }
    var up = upscaler;
    if (up == LuminaUpscaler.dlssRayReconstruction && !rt) {
      up = LuminaUpscaler.dlss;
      fallbacks.add('DLSS Ray Reconstruction needs ray tracing; using DLSS.');
    }
    if (up == LuminaUpscaler.dlssRayReconstruction && !support.rayReconstruction) {
      up = LuminaUpscaler.dlss;
      fallbacks.add('DLSS Ray Reconstruction is unavailable (${support.rayReconstructionReason}); using DLSS.');
    }
    if (up == LuminaUpscaler.dlss && !support.dlss) {
      up = support.fsr3 ? LuminaUpscaler.fsr3 : LuminaUpscaler.none;
      fallbacks.add('DLSS is unavailable (${support.dlssReason}); using ${up.displayName}.');
    }
    if (up == LuminaUpscaler.fsr3 && !support.fsr3) {
      up = LuminaUpscaler.none;
      fallbacks.add('FSR3 is unavailable (${support.fsr3Reason}); using None.');
    }
    var fg = frameGeneration;
    var generator = frameGenerator;
    var generated = dlssGeneratedFrames;
    if (fg && generator == LuminaFrameGenerator.dlss) {
      if (!support.dlssFrameGeneration) {
        generator = LuminaFrameGenerator.fsr3;
        fallbacks.add('DLSS frame generation is unavailable (${support.dlssFrameGenerationReason}); trying FSR3.');
      } else if (generated > support.maxDlssGeneratedFrames) {
        fallbacks.add('This GPU generates at most ${support.maxDlssGeneratedFrames} frame(s) per rendered frame '
            '(asked for $generated).');
        generated = support.maxDlssGeneratedFrames;
      }
    }
    if (fg && generator == LuminaFrameGenerator.fsr3) {
      if (!support.frameGeneration) {
        fg = false;
        fallbacks.add('Frame generation is off: ${support.frameGenerationReason}.');
      } else if (up != LuminaUpscaler.fsr3) {
        fg = false;
        fallbacks.add('Frame generation is off: it needs the FSR3 upscaler (active: ${up.displayName}).');
      }
    }
    return LuminaResolvedRenderingFeatures(
      copyWith(rayTracing: rt, upscaler: up, frameGeneration: fg, frameGenerator: generator, dlssGeneratedFrames: generated),
      List.unmodifiable(fallbacks),
    );
  }

  LuminaRenderingFeatureSettings copyWith({
    bool? rayTracing,
    bool? rayTracedShadows,
    bool? restir,
    int? restirCandidates,
    int? restirSpatialSamples,
    LuminaUpscaler? upscaler,
    LuminaUpscalerQuality? upscalerQuality,
    double? sharpness,
    bool? frameGeneration,
    LuminaFrameGenerator? frameGenerator,
    int? dlssGeneratedFrames,
  }) =>
      LuminaRenderingFeatureSettings(
        rayTracing: rayTracing ?? this.rayTracing,
        rayTracedShadows: rayTracedShadows ?? this.rayTracedShadows,
        restir: restir ?? this.restir,
        restirCandidates: (restirCandidates ?? this.restirCandidates).clamp(1, 64),
        restirSpatialSamples: (restirSpatialSamples ?? this.restirSpatialSamples).clamp(0, 8),
        upscaler: upscaler ?? this.upscaler,
        upscalerQuality: upscalerQuality ?? this.upscalerQuality,
        sharpness: (sharpness ?? this.sharpness).clamp(0.0, 1.0).toDouble(),
        frameGeneration: frameGeneration ?? this.frameGeneration,
        frameGenerator: frameGenerator ?? this.frameGenerator,
        dlssGeneratedFrames: (dlssGeneratedFrames ?? this.dlssGeneratedFrames).clamp(1, 5),
      );

  Map<String, dynamic> toMap() => {
        'ray_tracing': rayTracing,
        'ray_traced_shadows': rayTracedShadows,
        'restir': restir,
        'restir_candidates': restirCandidates,
        'restir_spatial_samples': restirSpatialSamples,
        'upscaler': upscaler.displayName,
        'upscaler_quality': upscalerQuality.displayName,
        'sharpness': sharpness,
        'frame_generation': frameGeneration,
        'frame_generator': frameGenerator.displayName,
        'dlss_generated_frames': dlssGeneratedFrames,
      };

  factory LuminaRenderingFeatureSettings.fromMap(Map<String, dynamic> map) {
    const d = LuminaRenderingFeatureSettings();
    final candidates = map['restir_candidates'];
    final spatial = map['restir_spatial_samples'];
    final sharpness = map['sharpness'];
    final generated = map['dlss_generated_frames'];
    return d.copyWith(
      rayTracing: map['ray_tracing'] is bool ? map['ray_tracing'] as bool : null,
      rayTracedShadows: map['ray_traced_shadows'] is bool ? map['ray_traced_shadows'] as bool : null,
      restir: map['restir'] is bool ? map['restir'] as bool : null,
      restirCandidates: candidates is int ? candidates : null,
      restirSpatialSamples: spatial is int ? spatial : null,
      upscaler: map['upscaler'] is String ? LuminaUpscaler.parse(map['upscaler'] as String) : null,
      upscalerQuality:
          map['upscaler_quality'] is String ? LuminaUpscalerQuality.parse(map['upscaler_quality'] as String) : null,
      sharpness: sharpness is num ? sharpness.toDouble() : null,
      frameGeneration: map['frame_generation'] is bool ? map['frame_generation'] as bool : null,
      frameGenerator:
          map['frame_generator'] is String ? LuminaFrameGenerator.parse(map['frame_generator'] as String) : null,
      dlssGeneratedFrames: generated is int ? generated : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LuminaRenderingFeatureSettings &&
      other.rayTracing == rayTracing &&
      other.rayTracedShadows == rayTracedShadows &&
      other.restir == restir &&
      other.restirCandidates == restirCandidates &&
      other.restirSpatialSamples == restirSpatialSamples &&
      other.upscaler == upscaler &&
      other.upscalerQuality == upscalerQuality &&
      other.sharpness == sharpness &&
      other.frameGeneration == frameGeneration &&
      other.frameGenerator == frameGenerator &&
      other.dlssGeneratedFrames == dlssGeneratedFrames;

  @override
  int get hashCode => Object.hash(rayTracing, rayTracedShadows, restir, restirCandidates, restirSpatialSamples, upscaler,
      upscalerQuality, sharpness, frameGeneration, frameGenerator, dlssGeneratedFrames);

  @override
  String toString() => 'LuminaRenderingFeatureSettings(${toMap()})';
}
