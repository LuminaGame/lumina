part of '../view_options.dart';

class MultiSampleAntiAliasingOptions {
  final bool enabled;
  final int sampleCount;
  final bool customResolve;

  const MultiSampleAntiAliasingOptions({
    this.enabled = false,
    this.sampleCount = 4,
    this.customResolve = false,
  });

  MultiSampleAntiAliasingOptions copyWith({
    bool? enabled,
    int? sampleCount,
    bool? customResolve,
  }) {
    return MultiSampleAntiAliasingOptions(
      enabled: enabled ?? this.enabled,
      sampleCount: sampleCount ?? this.sampleCount,
      customResolve: customResolve ?? this.customResolve,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MultiSampleAntiAliasingOptions &&
          runtimeType == other.runtimeType &&
          enabled == other.enabled &&
          sampleCount == other.sampleCount &&
          customResolve == other.customResolve;

  @override
  int get hashCode => Object.hash(enabled, sampleCount, customResolve);

  void copyToNative(ffi_gen.filament_multi_sample_anti_aliasing_options out) {
    out.enabled = enabled;
    out.sampleCount = sampleCount;
    out.customResolve = customResolve;
  }

  factory MultiSampleAntiAliasingOptions.fromNative(ffi_gen.filament_multi_sample_anti_aliasing_options out) {
    return MultiSampleAntiAliasingOptions(
      enabled: out.enabled,
      sampleCount: out.sampleCount,
      customResolve: out.customResolve,
    );
  }
}

enum TaaBoxType {
  aabb,
  aabbVariance;

  int toNative() => index;

  static TaaBoxType fromNative(int val) => TaaBoxType.values[val];
}

enum TaaBoxClipping {
  accurate,
  clamp,
  none;

  int toNative() => index;

  static TaaBoxClipping fromNative(int val) => TaaBoxClipping.values[val];
}

/// Which temporal anti-aliasing and upscaling algorithm a view runs.
enum TaaAlgorithm {
  /// Filament's temporal anti-aliasing.
  filament,

  /// The FidelityFX Super Resolution 3 upscaler as fragment passes: uses the
  /// view's motion vectors (implied, see [MotionVectorsOptions]), honours `upscaling`, `sharpness`,
  /// `lodBias` and `jitterPattern`; feature level 1 and no stereo. An external
  /// upscaler (DLSS) takes precedence.
  fsr3;

  int toNative() => index;

  static TaaAlgorithm fromNative(int value) =>
      value >= 0 && value < TaaAlgorithm.values.length ? TaaAlgorithm.values[value] : TaaAlgorithm.filament;
}

enum TaaJitterPattern {
  rgssX4,
  uniformHelixX4,
  halton23X8,
  halton23X16,
  halton23X32;

  int toNative() => index;

  static TaaJitterPattern fromNative(int val) => TaaJitterPattern.values[val];
}

class TemporalAntiAliasingOptions {
  final double filterWidth;
  final double feedback;
  final double lodBias;
  final double sharpness;
  final bool enabled;
  final double upscaling;
  final bool filterHistory;
  final bool filterInput;
  final bool useYCoCg;
  final bool hdr;
  final TaaBoxType boxType;
  final TaaBoxClipping boxClipping;
  final TaaJitterPattern jitterPattern;
  final double varianceGamma;
  final bool preventFlickering;
  final bool historyReprojection;

  /// Relaxes history rejection under low camera motion to reduce flickering on static content.
  final bool motionAdaptiveHistory;

  /// Camera motion, in texels, above which history rejection is applied at full strength.
  final double motionDeltaThreshold;

  /// Minimum history clamping strength when the camera is static, in (0, 1].
  final double minBoxStrength;

  /// Minimum history feedback scale when the camera is static, in (0, 1].
  final double minAlphaStrength;

  /// Normalized depth below which distant and sky pixels always use full history rejection.
  final double skyDepthThreshold;

  /// Frames to keep full history rejection after camera motion stops (0 disables).
  final double motionHoldFrames;

  /// Depth-based disocclusion detection, which reduces ghosting around moving objects.
  final bool depthDisocclusion;

  /// Depth difference threshold of the disocclusion detection.
  final double disocclusionDepthThreshold;

  /// Reduces false disocclusions on thin static geometry, at a higher GPU cost.
  final bool disocclusionHistoryNeighborhood;

  /// A wider reconstruction filter for more sharpness at 1:1 resolution, at a higher GPU cost.
  final bool exactLanczosSupport;

  /// Filament's TAA or the FSR3 upscaler. Default [TaaAlgorithm.filament].
  final TaaAlgorithm algorithm;

  /// FSR3 frame generation: an interpolated frame is presented before each
  /// rendered frame, doubling the presented rate at half a frame of latency.
  /// Needs [TaaAlgorithm.fsr3] and a view rendering into the swap chain
  /// without guard band. Default false.
  final bool frameGeneration;

  const TemporalAntiAliasingOptions({
    this.filterWidth = 1.0,
    this.feedback = 0.12,
    this.lodBias = -1.0,
    this.sharpness = 0.0,
    this.enabled = false,
    this.upscaling = 1.0,
    this.filterHistory = true,
    this.filterInput = true,
    this.useYCoCg = false,
    this.hdr = true,
    this.boxType = TaaBoxType.aabb,
    this.boxClipping = TaaBoxClipping.accurate,
    this.jitterPattern = TaaJitterPattern.halton23X16,
    this.varianceGamma = 0.7,
    this.preventFlickering = false,
    this.historyReprojection = true,
    this.motionAdaptiveHistory = false,
    this.motionDeltaThreshold = 1.0,
    this.minBoxStrength = 0.1,
    this.minAlphaStrength = 0.3,
    this.skyDepthThreshold = 0.001,
    this.motionHoldFrames = 12.0,
    this.depthDisocclusion = false,
    this.disocclusionDepthThreshold = 0.001,
    this.disocclusionHistoryNeighborhood = true,
    this.exactLanczosSupport = false,
    this.algorithm = TaaAlgorithm.filament,
    this.frameGeneration = false,
  });

  TemporalAntiAliasingOptions copyWith({
    double? filterWidth,
    double? feedback,
    double? lodBias,
    double? sharpness,
    bool? enabled,
    double? upscaling,
    bool? filterHistory,
    bool? filterInput,
    bool? useYCoCg,
    bool? hdr,
    TaaBoxType? boxType,
    TaaBoxClipping? boxClipping,
    TaaJitterPattern? jitterPattern,
    double? varianceGamma,
    bool? preventFlickering,
    bool? historyReprojection,
    bool? motionAdaptiveHistory,
    double? motionDeltaThreshold,
    double? minBoxStrength,
    double? minAlphaStrength,
    double? skyDepthThreshold,
    double? motionHoldFrames,
    bool? depthDisocclusion,
    double? disocclusionDepthThreshold,
    bool? disocclusionHistoryNeighborhood,
    bool? exactLanczosSupport,
    TaaAlgorithm? algorithm,
    bool? frameGeneration,
  }) {
    return TemporalAntiAliasingOptions(
      filterWidth: filterWidth ?? this.filterWidth,
      feedback: feedback ?? this.feedback,
      lodBias: lodBias ?? this.lodBias,
      sharpness: sharpness ?? this.sharpness,
      enabled: enabled ?? this.enabled,
      upscaling: upscaling ?? this.upscaling,
      filterHistory: filterHistory ?? this.filterHistory,
      filterInput: filterInput ?? this.filterInput,
      useYCoCg: useYCoCg ?? this.useYCoCg,
      hdr: hdr ?? this.hdr,
      boxType: boxType ?? this.boxType,
      boxClipping: boxClipping ?? this.boxClipping,
      jitterPattern: jitterPattern ?? this.jitterPattern,
      varianceGamma: varianceGamma ?? this.varianceGamma,
      preventFlickering: preventFlickering ?? this.preventFlickering,
      historyReprojection: historyReprojection ?? this.historyReprojection,
      motionAdaptiveHistory: motionAdaptiveHistory ?? this.motionAdaptiveHistory,
      motionDeltaThreshold: motionDeltaThreshold ?? this.motionDeltaThreshold,
      minBoxStrength: minBoxStrength ?? this.minBoxStrength,
      minAlphaStrength: minAlphaStrength ?? this.minAlphaStrength,
      skyDepthThreshold: skyDepthThreshold ?? this.skyDepthThreshold,
      motionHoldFrames: motionHoldFrames ?? this.motionHoldFrames,
      depthDisocclusion: depthDisocclusion ?? this.depthDisocclusion,
      disocclusionDepthThreshold: disocclusionDepthThreshold ?? this.disocclusionDepthThreshold,
      disocclusionHistoryNeighborhood: disocclusionHistoryNeighborhood ?? this.disocclusionHistoryNeighborhood,
      exactLanczosSupport: exactLanczosSupport ?? this.exactLanczosSupport,
      algorithm: algorithm ?? this.algorithm,
      frameGeneration: frameGeneration ?? this.frameGeneration,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TemporalAntiAliasingOptions &&
          runtimeType == other.runtimeType &&
          filterWidth == other.filterWidth &&
          feedback == other.feedback &&
          lodBias == other.lodBias &&
          sharpness == other.sharpness &&
          enabled == other.enabled &&
          upscaling == other.upscaling &&
          filterHistory == other.filterHistory &&
          filterInput == other.filterInput &&
          useYCoCg == other.useYCoCg &&
          hdr == other.hdr &&
          boxType == other.boxType &&
          boxClipping == other.boxClipping &&
          jitterPattern == other.jitterPattern &&
          varianceGamma == other.varianceGamma &&
          preventFlickering == other.preventFlickering &&
          historyReprojection == other.historyReprojection &&
          motionAdaptiveHistory == other.motionAdaptiveHistory &&
          motionDeltaThreshold == other.motionDeltaThreshold &&
          minBoxStrength == other.minBoxStrength &&
          minAlphaStrength == other.minAlphaStrength &&
          skyDepthThreshold == other.skyDepthThreshold &&
          motionHoldFrames == other.motionHoldFrames &&
          depthDisocclusion == other.depthDisocclusion &&
          disocclusionDepthThreshold == other.disocclusionDepthThreshold &&
          disocclusionHistoryNeighborhood == other.disocclusionHistoryNeighborhood &&
          exactLanczosSupport == other.exactLanczosSupport &&
          algorithm == other.algorithm &&
          frameGeneration == other.frameGeneration;

  @override
  int get hashCode => Object.hashAll([
        filterWidth,
        feedback,
        lodBias,
        sharpness,
        enabled,
        upscaling,
        filterHistory,
        filterInput,
        useYCoCg,
        hdr,
        boxType,
        boxClipping,
        jitterPattern,
        varianceGamma,
        preventFlickering,
        historyReprojection,
        motionAdaptiveHistory,
        motionDeltaThreshold,
        minBoxStrength,
        minAlphaStrength,
        skyDepthThreshold,
        motionHoldFrames,
        depthDisocclusion,
        disocclusionDepthThreshold,
        disocclusionHistoryNeighborhood,
        exactLanczosSupport,
        algorithm,
        frameGeneration,
      ]);

  void copyToNative(ffi_gen.filament_temporal_anti_aliasing_options out) {
    out.filterWidth = filterWidth;
    out.feedback = feedback;
    out.lodBias = lodBias;
    out.sharpness = sharpness;
    out.enabled = enabled;
    out.upscaling = upscaling;
    out.filterHistory = filterHistory;
    out.filterInput = filterInput;
    out.useYCoCg = useYCoCg;
    out.hdr = hdr;
    out.boxType = boxType.toNative();
    out.boxClipping = boxClipping.toNative();
    out.jitterPattern = jitterPattern.toNative();
    out.varianceGamma = varianceGamma;
    out.preventFlickering = preventFlickering;
    out.historyReprojection = historyReprojection;
    out.motionAdaptiveHistory = motionAdaptiveHistory;
    out.motionDeltaThreshold = motionDeltaThreshold;
    out.minBoxStrength = minBoxStrength;
    out.minAlphaStrength = minAlphaStrength;
    out.skyDepthThreshold = skyDepthThreshold;
    out.motionHoldFrames = motionHoldFrames;
    out.depthDisocclusion = depthDisocclusion;
    out.disocclusionDepthThreshold = disocclusionDepthThreshold;
    out.disocclusionHistoryNeighborhood = disocclusionHistoryNeighborhood;
    out.exactLanczosSupport = exactLanczosSupport;
    out.algorithm = algorithm.toNative();
    out.frameGeneration = frameGeneration;
  }

  factory TemporalAntiAliasingOptions.fromNative(ffi_gen.filament_temporal_anti_aliasing_options out) {
    return TemporalAntiAliasingOptions(
      filterWidth: out.filterWidth,
      feedback: out.feedback,
      lodBias: out.lodBias,
      sharpness: out.sharpness,
      enabled: out.enabled,
      upscaling: out.upscaling,
      filterHistory: out.filterHistory,
      filterInput: out.filterInput,
      useYCoCg: out.useYCoCg,
      hdr: out.hdr,
      boxType: TaaBoxType.fromNative(out.boxType),
      boxClipping: TaaBoxClipping.fromNative(out.boxClipping),
      jitterPattern: TaaJitterPattern.fromNative(out.jitterPattern),
      varianceGamma: out.varianceGamma,
      preventFlickering: out.preventFlickering,
      historyReprojection: out.historyReprojection,
      motionAdaptiveHistory: out.motionAdaptiveHistory,
      motionDeltaThreshold: out.motionDeltaThreshold,
      minBoxStrength: out.minBoxStrength,
      minAlphaStrength: out.minAlphaStrength,
      skyDepthThreshold: out.skyDepthThreshold,
      motionHoldFrames: out.motionHoldFrames,
      depthDisocclusion: out.depthDisocclusion,
      disocclusionDepthThreshold: out.disocclusionDepthThreshold,
      disocclusionHistoryNeighborhood: out.disocclusionHistoryNeighborhood,
      exactLanczosSupport: out.exactLanczosSupport,
      algorithm: TaaAlgorithm.fromNative(out.algorithm),
      frameGeneration: out.frameGeneration,
    );
  }
}

/// The view's motion vectors ([FilamentView.motionVectorsOptions]): the
/// screen-space motion of every pixel since the previous frame, from the
/// camera, transform and instance animation, and the pose of skinned and
/// morphed renderables (a shared skinning buffer keeps no previous palette).
/// TAA reprojects moving objects with them; DLSS, FSR3 (which implies them),
/// frame generation and the external post pass read them, and
/// [FilamentView.motionVectorTexture] exports them. Needs post-processing, a
/// mono view and [FilamentView.motionVectorsSupported].
class MotionVectorsOptions {
  /// Renders the motion vectors. Default false.
  final bool enabled;

  const MotionVectorsOptions({this.enabled = false});

  MotionVectorsOptions copyWith({bool? enabled}) => MotionVectorsOptions(enabled: enabled ?? this.enabled);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is MotionVectorsOptions && other.enabled == enabled;

  @override
  int get hashCode => enabled.hashCode;

  @override
  String toString() => 'MotionVectorsOptions(enabled: $enabled)';
}
