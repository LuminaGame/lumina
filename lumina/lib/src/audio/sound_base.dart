import 'dart:math' as math;

/// Attenuation curve models for distance-based 3D sound volume falloff.
enum LuminaAttenuationModel {
  /// Linear falloff from 1.0 at innerRadius to 0.0 at innerRadius + falloffDistance.
  linear,

  /// Logarithmic curve approximating natural acoustic falloff.
  logarithmic,

  /// Inverse square law falloff with minimum volume floor.
  inverse,
}

/// Distance-based 3D spatial attenuation settings.
class LuminaSoundAttenuation {
  double innerRadius;
  double falloffDistance;
  LuminaAttenuationModel model;

  LuminaSoundAttenuation({
    this.innerRadius = 200.0, // cm
    this.falloffDistance = 800.0,
    this.model = LuminaAttenuationModel.linear,
  });

  /// Calculates the volume gain factor (0.0 to 1.0) for a given distance in world units (cm).
  double calculateGain(double distance) {
    if (distance <= innerRadius) {
      return 1.0;
    }
    if (falloffDistance <= 0.0) {
      return 0.0;
    }
    final d = distance - innerRadius;
    if (d >= falloffDistance) {
      return model == LuminaAttenuationModel.linear ? 0.0 : 0.001;
    }

    final t = (d / falloffDistance).clamp(0.0, 1.0);
    switch (model) {
      case LuminaAttenuationModel.linear:
        return 1.0 - t;
      case LuminaAttenuationModel.logarithmic:
        return 1.0 - (math.log(1.0 + 9.0 * t) / math.ln10);
      case LuminaAttenuationModel.inverse:
        return 1.0 / (1.0 + t * 9.0);
    }
  }
}

/// Abstract base descriptor for sound assets and streams.
abstract class LuminaSoundBase {
  final String soundId;
  double baseVolume;
  double basePitch;
  bool looping;
  LuminaSoundAttenuation? attenuation;
  double? duration;

  LuminaSoundBase({
    required this.soundId,
    this.baseVolume = 1.0,
    this.basePitch = 1.0,
    this.looping = false,
    this.attenuation,
    this.duration,
  });
}

/// File or bundle-backed sound wave asset descriptor.
class LuminaSoundWave extends LuminaSoundBase {
  final String assetPath;

  LuminaSoundWave({
    required this.assetPath,
    String? soundId,
    super.baseVolume = 1.0,
    super.basePitch = 1.0,
    super.looping = false,
    super.attenuation,
    super.duration,
  }) : super(soundId: soundId ?? assetPath);
}
