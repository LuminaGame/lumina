part of '../view_options.dart';

class ScreenSpaceReflectionsOptions {
  final double thickness;
  final double bias;
  final double maxDistance;
  final double stride;
  final bool enabled;

  const ScreenSpaceReflectionsOptions({
    this.thickness = 0.1,
    this.bias = 0.01,
    this.maxDistance = 3.0,
    this.stride = 2.0,
    this.enabled = false,
  });

  ScreenSpaceReflectionsOptions copyWith({
    double? thickness,
    double? bias,
    double? maxDistance,
    double? stride,
    bool? enabled,
  }) {
    return ScreenSpaceReflectionsOptions(
      thickness: thickness ?? this.thickness,
      bias: bias ?? this.bias,
      maxDistance: maxDistance ?? this.maxDistance,
      stride: stride ?? this.stride,
      enabled: enabled ?? this.enabled,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScreenSpaceReflectionsOptions &&
          runtimeType == other.runtimeType &&
          thickness == other.thickness &&
          bias == other.bias &&
          maxDistance == other.maxDistance &&
          stride == other.stride &&
          enabled == other.enabled;

  @override
  int get hashCode => Object.hash(thickness, bias, maxDistance, stride, enabled);

  void copyToNative(ffi_gen.filament_screen_space_reflections_options out) {
    out.thickness = thickness;
    out.bias = bias;
    out.maxDistance = maxDistance;
    out.stride = stride;
    out.enabled = enabled;
  }

  factory ScreenSpaceReflectionsOptions.fromNative(ffi_gen.filament_screen_space_reflections_options out) {
    return ScreenSpaceReflectionsOptions(
      thickness: out.thickness,
      bias: out.bias,
      maxDistance: out.maxDistance,
      stride: out.stride,
      enabled: out.enabled,
    );
  }
}

class GuardBandOptions {
  final bool enabled;

  const GuardBandOptions({
    this.enabled = false,
  });

  GuardBandOptions copyWith({
    bool? enabled,
  }) {
    return GuardBandOptions(
      enabled: enabled ?? this.enabled,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GuardBandOptions &&
          runtimeType == other.runtimeType &&
          enabled == other.enabled;

  @override
  int get hashCode => enabled.hashCode;

  void copyToNative(ffi_gen.filament_guard_band_options out) {
    out.enabled = enabled;
  }

  factory GuardBandOptions.fromNative(ffi_gen.filament_guard_band_options out) {
    return GuardBandOptions(
      enabled: out.enabled,
    );
  }
}

enum AntiAliasing {
  none,
  fxaa;

  int toNative() => index;

  static AntiAliasing fromNative(int val) => AntiAliasing.values[val];
}

enum Dithering {
  none,
  temporal;

  int toNative() => index;

  static Dithering fromNative(int val) => Dithering.values[val];
}
