import 'package:flutter_filament/filament.dart';

/// The render-resolution presets of FSR3 upscaling: the view renders at
/// `1 / scale` of the output per axis and the upscaler reconstructs the rest.
enum LuminaFsr3Quality {
  /// Full resolution; FSR3 only anti-aliases (native AA).
  nativeAA(1.0),

  /// Two thirds of the output per axis.
  quality(1.5),

  /// 59% of the output per axis.
  balanced(1.7),

  /// Half of the output per axis.
  performance(2.0),

  /// A third of the output per axis.
  ultraPerformance(3.0);

  const LuminaFsr3Quality(this.scale);

  /// The upscaling ratio per axis ([TemporalAntiAliasingOptions.upscaling]).
  final double scale;
}

/// FidelityFX Super Resolution 3 for a view: the view renders smaller and
/// Filament's fragment-pass port of the FSR3 upscaler reconstructs the output,
/// optionally presenting an interpolated frame before each rendered one.
///
/// Works on every backend with the structure pass motion vectors (feature
/// level 1). When DLSS is active on the same view it takes precedence.
class LuminaFsr3Settings {
  const LuminaFsr3Settings({
    this.enabled = false,
    this.quality = LuminaFsr3Quality.quality,
    this.sharpness = 0.5,
    this.frameGeneration = false,
  });

  final bool enabled;

  /// The render-resolution preset.
  final LuminaFsr3Quality quality;

  /// RCAS sharpening after the upscale (0 none, 1 strongest).
  final double sharpness;

  /// Present an interpolated frame before each rendered frame.
  final bool frameGeneration;

  /// The TAA options for [base] with FSR3 switched on.
  TemporalAntiAliasingOptions taaOptions(TemporalAntiAliasingOptions base) => base.copyWith(
        enabled: true,
        algorithm: TaaAlgorithm.fsr3,
        upscaling: quality.scale,
        sharpness: sharpness.clamp(0.0, 1.0),
        frameGeneration: frameGeneration,
      );

  /// Dynamic resolution pinned at the preset's render scale.
  DynamicResolutionOptions get dynamicResolutionOptions => DynamicResolutionOptions(
        enabled: quality.scale > 1.0,
        minScaleX: 1 / quality.scale,
        minScaleY: 1 / quality.scale,
        maxScaleX: 1 / quality.scale,
        maxScaleY: 1 / quality.scale,
        homogeneousScaling: true,
      );

  LuminaFsr3Settings copyWith({bool? enabled, LuminaFsr3Quality? quality, double? sharpness, bool? frameGeneration}) =>
      LuminaFsr3Settings(
        enabled: enabled ?? this.enabled,
        quality: quality ?? this.quality,
        sharpness: (sharpness ?? this.sharpness).clamp(0.0, 1.0),
        frameGeneration: frameGeneration ?? this.frameGeneration,
      );

  Map<String, dynamic> toMap() => {
        'enabled': enabled,
        'quality': quality.name,
        'sharpness': sharpness,
        'frame_generation': frameGeneration,
      };

  factory LuminaFsr3Settings.fromMap(Map<String, dynamic> map) {
    final name = map['quality'];
    final sharpness = map['sharpness'];
    return LuminaFsr3Settings(
      enabled: map['enabled'] as bool? ?? false,
      quality: LuminaFsr3Quality.values.where((q) => q.name == name).firstOrNull ?? LuminaFsr3Quality.quality,
      sharpness: sharpness is num ? sharpness.toDouble().clamp(0.0, 1.0) : 0.5,
      frameGeneration: map['frame_generation'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LuminaFsr3Settings &&
      other.enabled == enabled &&
      other.quality == quality &&
      other.sharpness == sharpness &&
      other.frameGeneration == frameGeneration;

  @override
  int get hashCode => Object.hash(enabled, quality, sharpness, frameGeneration);

  @override
  String toString() =>
      'LuminaFsr3Settings(enabled: $enabled, quality: ${quality.name}, sharpness: $sharpness, frameGeneration: $frameGeneration)';
}
