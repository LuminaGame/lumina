part of '../view_options.dart';

enum QualityLevel {
  low,
  medium,
  high,
  ultra;

  int toNative() => index;

  static QualityLevel fromNative(int val) => QualityLevel.values[val];
}

/// Which upscaler turns a dynamically scaled frame into the output.
enum Upscaler {
  /// Filament's own: bilinear, SGSR1 or FSR1 by [DynamicResolutionOptions.quality].
  builtin,

  /// An upscaler registered on the view from outside Filament ([Dlss]); falls
  /// back to FSR1 when none is registered or it declines the resolution.
  external;

  int toNative() => index;

  static Upscaler fromNative(int val) => Upscaler.values[val];
}

enum BlendMode {
  opaque,
  translucent;

  int toNative() => index;

  static BlendMode fromNative(int val) => BlendMode.values[val];
}

class DynamicResolutionOptions {
  final double minScaleX;
  final double minScaleY;
  final double maxScaleX;
  final double maxScaleY;
  final double sharpness;
  final bool enabled;
  final bool homogeneousScaling;
  final QualityLevel quality;

  /// Which upscaler reconstructs the output; [Upscaler.external] hands the
  /// frame to the view's external upscaler (DLSS). Default [Upscaler.builtin].
  final Upscaler upscaler;

  const DynamicResolutionOptions({
    this.minScaleX = 0.5,
    this.minScaleY = 0.5,
    this.maxScaleX = 1.0,
    this.maxScaleY = 1.0,
    this.sharpness = 0.9,
    this.enabled = false,
    this.homogeneousScaling = false,
    this.quality = QualityLevel.low,
    this.upscaler = Upscaler.builtin,
  });

  DynamicResolutionOptions copyWith({
    double? minScaleX,
    double? minScaleY,
    double? maxScaleX,
    double? maxScaleY,
    double? sharpness,
    bool? enabled,
    bool? homogeneousScaling,
    QualityLevel? quality,
    Upscaler? upscaler,
  }) {
    return DynamicResolutionOptions(
      minScaleX: minScaleX ?? this.minScaleX,
      minScaleY: minScaleY ?? this.minScaleY,
      maxScaleX: maxScaleX ?? this.maxScaleX,
      maxScaleY: maxScaleY ?? this.maxScaleY,
      sharpness: sharpness ?? this.sharpness,
      enabled: enabled ?? this.enabled,
      homogeneousScaling: homogeneousScaling ?? this.homogeneousScaling,
      quality: quality ?? this.quality,
      upscaler: upscaler ?? this.upscaler,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DynamicResolutionOptions &&
          runtimeType == other.runtimeType &&
          minScaleX == other.minScaleX &&
          minScaleY == other.minScaleY &&
          maxScaleX == other.maxScaleX &&
          maxScaleY == other.maxScaleY &&
          sharpness == other.sharpness &&
          enabled == other.enabled &&
          homogeneousScaling == other.homogeneousScaling &&
          quality == other.quality &&
          upscaler == other.upscaler;

  @override
  int get hashCode => Object.hash(
        minScaleX,
        minScaleY,
        maxScaleX,
        maxScaleY,
        sharpness,
        enabled,
        homogeneousScaling,
        quality,
        upscaler,
      );

  void copyToNative(ffi_gen.filament_dynamic_resolution_options out) {
    out.minScale[0] = minScaleX;
    out.minScale[1] = minScaleY;
    out.maxScale[0] = maxScaleX;
    out.maxScale[1] = maxScaleY;
    out.sharpness = sharpness;
    out.enabled = enabled;
    out.homogeneousScaling = homogeneousScaling;
    out.quality = quality.toNative();
    out.upscaler = upscaler.toNative();
  }

  factory DynamicResolutionOptions.fromNative(ffi_gen.filament_dynamic_resolution_options out) {
    return DynamicResolutionOptions(
      minScaleX: out.minScale[0],
      minScaleY: out.minScale[1],
      maxScaleX: out.maxScale[0],
      maxScaleY: out.maxScale[1],
      sharpness: out.sharpness,
      enabled: out.enabled,
      homogeneousScaling: out.homogeneousScaling,
      quality: QualityLevel.fromNative(out.quality),
      upscaler: Upscaler.fromNative(out.upscaler),
    );
  }
}
