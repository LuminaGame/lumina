part of '../view_options.dart';

enum DofFilter {
  none,
  unused,
  median;

  int toNative() => index;

  static DofFilter fromNative(int val) => DofFilter.values[val];
}

class DepthOfFieldOptions {
  final double cocScale;
  final double cocAspectRatio;
  final double maxApertureDiameter;
  final bool enabled;
  final DofFilter filter;
  final bool nativeResolution;
  final int foregroundRingCount;
  final int backgroundRingCount;
  final int fastGatherRingCount;
  final int maxForegroundCOC;
  final int maxBackgroundCOC;

  const DepthOfFieldOptions({
    this.cocScale = 1.0,
    this.cocAspectRatio = 1.0,
    this.maxApertureDiameter = 0.01,
    this.enabled = false,
    this.filter = DofFilter.median,
    this.nativeResolution = false,
    this.foregroundRingCount = 0,
    this.backgroundRingCount = 0,
    this.fastGatherRingCount = 0,
    this.maxForegroundCOC = 0,
    this.maxBackgroundCOC = 0,
  });

  DepthOfFieldOptions copyWith({
    double? cocScale,
    double? cocAspectRatio,
    double? maxApertureDiameter,
    bool? enabled,
    DofFilter? filter,
    bool? nativeResolution,
    int? foregroundRingCount,
    int? backgroundRingCount,
    int? fastGatherRingCount,
    int? maxForegroundCOC,
    int? maxBackgroundCOC,
  }) {
    return DepthOfFieldOptions(
      cocScale: cocScale ?? this.cocScale,
      cocAspectRatio: cocAspectRatio ?? this.cocAspectRatio,
      maxApertureDiameter: maxApertureDiameter ?? this.maxApertureDiameter,
      enabled: enabled ?? this.enabled,
      filter: filter ?? this.filter,
      nativeResolution: nativeResolution ?? this.nativeResolution,
      foregroundRingCount: foregroundRingCount ?? this.foregroundRingCount,
      backgroundRingCount: backgroundRingCount ?? this.backgroundRingCount,
      fastGatherRingCount: fastGatherRingCount ?? this.fastGatherRingCount,
      maxForegroundCOC: maxForegroundCOC ?? this.maxForegroundCOC,
      maxBackgroundCOC: maxBackgroundCOC ?? this.maxBackgroundCOC,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DepthOfFieldOptions &&
          runtimeType == other.runtimeType &&
          cocScale == other.cocScale &&
          cocAspectRatio == other.cocAspectRatio &&
          maxApertureDiameter == other.maxApertureDiameter &&
          enabled == other.enabled &&
          filter == other.filter &&
          nativeResolution == other.nativeResolution &&
          foregroundRingCount == other.foregroundRingCount &&
          backgroundRingCount == other.backgroundRingCount &&
          fastGatherRingCount == other.fastGatherRingCount &&
          maxForegroundCOC == other.maxForegroundCOC &&
          maxBackgroundCOC == other.maxBackgroundCOC;

  @override
  int get hashCode => Object.hash(
        cocScale,
        cocAspectRatio,
        maxApertureDiameter,
        enabled,
        filter,
        nativeResolution,
        foregroundRingCount,
        backgroundRingCount,
        fastGatherRingCount,
        maxForegroundCOC,
        maxBackgroundCOC,
      );

  void copyToNative(ffi_gen.filament_depth_of_field_options out) {
    out.cocScale = cocScale;
    out.cocAspectRatio = cocAspectRatio;
    out.maxApertureDiameter = maxApertureDiameter;
    out.enabled = enabled;
    out.filter = filter.toNative();
    out.nativeResolution = nativeResolution;
    out.foregroundRingCount = foregroundRingCount;
    out.backgroundRingCount = backgroundRingCount;
    out.fastGatherRingCount = fastGatherRingCount;
    out.maxForegroundCOC = maxForegroundCOC;
    out.maxBackgroundCOC = maxBackgroundCOC;
  }

  factory DepthOfFieldOptions.fromNative(ffi_gen.filament_depth_of_field_options out) {
    return DepthOfFieldOptions(
      cocScale: out.cocScale,
      cocAspectRatio: out.cocAspectRatio,
      maxApertureDiameter: out.maxApertureDiameter,
      enabled: out.enabled,
      filter: DofFilter.fromNative(out.filter),
      nativeResolution: out.nativeResolution,
      foregroundRingCount: out.foregroundRingCount,
      backgroundRingCount: out.backgroundRingCount,
      fastGatherRingCount: out.fastGatherRingCount,
      maxForegroundCOC: out.maxForegroundCOC,
      maxBackgroundCOC: out.maxBackgroundCOC,
    );
  }
}

class VignetteOptions {
  final double midPoint;
  final double roundness;
  final double feather;
  final double colorR;
  final double colorG;
  final double colorB;
  final double colorA;
  final bool enabled;

  const VignetteOptions({
    this.midPoint = 0.5,
    this.roundness = 0.5,
    this.feather = 0.5,
    this.colorR = 0.0,
    this.colorG = 0.0,
    this.colorB = 0.0,
    this.colorA = 1.0,
    this.enabled = false,
  });

  VignetteOptions copyWith({
    double? midPoint,
    double? roundness,
    double? feather,
    double? colorR,
    double? colorG,
    double? colorB,
    double? colorA,
    bool? enabled,
  }) {
    return VignetteOptions(
      midPoint: midPoint ?? this.midPoint,
      roundness: roundness ?? this.roundness,
      feather: feather ?? this.feather,
      colorR: colorR ?? this.colorR,
      colorG: colorG ?? this.colorG,
      colorB: colorB ?? this.colorB,
      colorA: colorA ?? this.colorA,
      enabled: enabled ?? this.enabled,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VignetteOptions &&
          runtimeType == other.runtimeType &&
          midPoint == other.midPoint &&
          roundness == other.roundness &&
          feather == other.feather &&
          colorR == other.colorR &&
          colorG == other.colorG &&
          colorB == other.colorB &&
          colorA == other.colorA &&
          enabled == other.enabled;

  @override
  int get hashCode => Object.hash(
        midPoint,
        roundness,
        feather,
        colorR,
        colorG,
        colorB,
        colorA,
        enabled,
      );

  void copyToNative(ffi_gen.filament_vignette_options out) {
    out.midPoint = midPoint;
    out.roundness = roundness;
    out.feather = feather;
    out.color[0] = colorR;
    out.color[1] = colorG;
    out.color[2] = colorB;
    out.color[3] = colorA;
    out.enabled = enabled;
  }

  factory VignetteOptions.fromNative(ffi_gen.filament_vignette_options out) {
    return VignetteOptions(
      midPoint: out.midPoint,
      roundness: out.roundness,
      feather: out.feather,
      colorR: out.color[0],
      colorG: out.color[1],
      colorB: out.color[2],
      colorA: out.color[3],
      enabled: out.enabled,
    );
  }
}

class RenderQuality {
  final QualityLevel hdrColorBuffer;

  const RenderQuality({
    this.hdrColorBuffer = QualityLevel.high,
  });

  RenderQuality copyWith({
    QualityLevel? hdrColorBuffer,
  }) {
    return RenderQuality(
      hdrColorBuffer: hdrColorBuffer ?? this.hdrColorBuffer,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RenderQuality &&
          runtimeType == other.runtimeType &&
          hdrColorBuffer == other.hdrColorBuffer;

  @override
  int get hashCode => hdrColorBuffer.hashCode;

  void copyToNative(ffi_gen.filament_render_quality out) {
    out.hdrColorBuffer = hdrColorBuffer.toNative();
  }

  factory RenderQuality.fromNative(ffi_gen.filament_render_quality out) {
    return RenderQuality(
      hdrColorBuffer: QualityLevel.fromNative(out.hdrColorBuffer),
    );
  }
}
