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
  /// structure pass motion vectors (implied), honours `upscaling`, `sharpness`,
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

  /// Renders per-pixel motion vectors in the structure pass (which then runs
  /// at full resolution) and reprojects the TAA history with them instead of
  /// with the camera matrices alone, so moving, transform-animated, skinned
  /// and morphed objects stop ghosting (a shared skinning buffer keeps no
  /// previous palette). The buffer can be exported with
  /// [FilamentView.motionVectorTexture]; needs
  /// [FilamentView.motionVectorsSupported].
  final bool motionVectors;

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
    this.varianceGamma = 1.0,
    this.preventFlickering = false,
    this.historyReprojection = true,
    this.motionVectors = false,
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
    bool? motionVectors,
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
      motionVectors: motionVectors ?? this.motionVectors,
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
          motionVectors == other.motionVectors &&
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
        motionVectors,
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
    out.motionVectors = motionVectors;
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
      motionVectors: out.motionVectors,
      algorithm: TaaAlgorithm.fromNative(out.algorithm),
      frameGeneration: out.frameGeneration,
    );
  }
}
