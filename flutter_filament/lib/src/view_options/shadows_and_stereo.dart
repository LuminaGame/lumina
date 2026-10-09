part of '../view_options.dart';

enum ShadowType {
  pcf,
  vsm,
  dpcf,
  pcss,
  pcfd;

  int toNative() => index;

  static ShadowType fromNative(int val) => ShadowType.values[val];
}

class VsmShadowOptions {
  final int anisotropy;
  final bool mipmapping;
  final int msaaSamples;
  final bool highPrecision;
  final double minVarianceScale;
  final double lightBleedReduction;

  const VsmShadowOptions({
    this.anisotropy = 0,
    this.mipmapping = false,
    this.msaaSamples = 1,
    this.highPrecision = false,
    this.minVarianceScale = 0.5,
    this.lightBleedReduction = 0.15,
  });

  VsmShadowOptions copyWith({
    int? anisotropy,
    bool? mipmapping,
    int? msaaSamples,
    bool? highPrecision,
    double? minVarianceScale,
    double? lightBleedReduction,
  }) {
    return VsmShadowOptions(
      anisotropy: anisotropy ?? this.anisotropy,
      mipmapping: mipmapping ?? this.mipmapping,
      msaaSamples: msaaSamples ?? this.msaaSamples,
      highPrecision: highPrecision ?? this.highPrecision,
      minVarianceScale: minVarianceScale ?? this.minVarianceScale,
      lightBleedReduction: lightBleedReduction ?? this.lightBleedReduction,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VsmShadowOptions &&
          runtimeType == other.runtimeType &&
          anisotropy == other.anisotropy &&
          mipmapping == other.mipmapping &&
          msaaSamples == other.msaaSamples &&
          highPrecision == other.highPrecision &&
          minVarianceScale == other.minVarianceScale &&
          lightBleedReduction == other.lightBleedReduction;

  @override
  int get hashCode => Object.hash(
        anisotropy,
        mipmapping,
        msaaSamples,
        highPrecision,
        minVarianceScale,
        lightBleedReduction,
      );

  void copyToNative(ffi_gen.filament_vsm_shadow_options out) {
    out.anisotropy = anisotropy;
    out.mipmapping = mipmapping;
    out.msaaSamples = msaaSamples;
    out.highPrecision = highPrecision;
    out.minVarianceScale = minVarianceScale;
    out.lightBleedReduction = lightBleedReduction;
  }

  factory VsmShadowOptions.fromNative(ffi_gen.filament_vsm_shadow_options out) {
    return VsmShadowOptions(
      anisotropy: out.anisotropy,
      mipmapping: out.mipmapping,
      msaaSamples: out.msaaSamples,
      highPrecision: out.highPrecision,
      minVarianceScale: out.minVarianceScale,
      lightBleedReduction: out.lightBleedReduction,
    );
  }
}

class SoftShadowOptions {
  final double penumbraScale;
  final double penumbraRatioScale;
  final double maxPenumbraRatio;
  final double maxSearchRadius;

  const SoftShadowOptions({
    this.penumbraScale = 1.0,
    this.penumbraRatioScale = 1.0,
    this.maxPenumbraRatio = 10.0,
    this.maxSearchRadius = 1.0,
  });

  SoftShadowOptions copyWith({
    double? penumbraScale,
    double? penumbraRatioScale,
    double? maxPenumbraRatio,
    double? maxSearchRadius,
  }) {
    return SoftShadowOptions(
      penumbraScale: penumbraScale ?? this.penumbraScale,
      penumbraRatioScale: penumbraRatioScale ?? this.penumbraRatioScale,
      maxPenumbraRatio: maxPenumbraRatio ?? this.maxPenumbraRatio,
      maxSearchRadius: maxSearchRadius ?? this.maxSearchRadius,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SoftShadowOptions &&
          runtimeType == other.runtimeType &&
          penumbraScale == other.penumbraScale &&
          penumbraRatioScale == other.penumbraRatioScale &&
          maxPenumbraRatio == other.maxPenumbraRatio &&
          maxSearchRadius == other.maxSearchRadius;

  @override
  int get hashCode => Object.hash(
        penumbraScale,
        penumbraRatioScale,
        maxPenumbraRatio,
        maxSearchRadius,
      );

  void copyToNative(ffi_gen.filament_soft_shadow_options out) {
    out.penumbraScale = penumbraScale;
    out.penumbraRatioScale = penumbraRatioScale;
    out.maxPenumbraRatio = maxPenumbraRatio;
    out.maxSearchRadius = maxSearchRadius;
  }

  factory SoftShadowOptions.fromNative(ffi_gen.filament_soft_shadow_options out) {
    return SoftShadowOptions(
      penumbraScale: out.penumbraScale,
      penumbraRatioScale: out.penumbraRatioScale,
      maxPenumbraRatio: out.maxPenumbraRatio,
      maxSearchRadius: out.maxSearchRadius,
    );
  }
}

class StereoscopicOptions {
  final bool enabled;

  const StereoscopicOptions({
    this.enabled = false,
  });

  void copyToNative(ffi_gen.filament_stereoscopic_options out) {
    out.enabled = enabled;
  }

  factory StereoscopicOptions.fromNative(ffi_gen.filament_stereoscopic_options out) {
    return StereoscopicOptions(
      enabled: out.enabled,
    );
  }
}
