import 'dart:math' as math;

/// Utilities to compute exposure value at ISO 100 (EV100), photometric exposure,
/// luminance, and illuminance using a physically-based camera model.
///
/// Direct pure-Dart reimplementation of `filament::Exposure`.
class Exposure {
  /// Computes the exposure value (EV at ISO 100) from exposure parameters.
  ///
  /// `EV100 = log2((aperture^2 / shutterSpeed) * (100 / sensitivity))`
  static double ev100({
    required double aperture,
    required double shutterSpeed,
    required double sensitivity,
  }) {
    return math.log((aperture * aperture) / shutterSpeed * 100.0 / sensitivity) / math.ln2;
  }

  /// Computes the exposure value (EV at ISO 100) for the given average scene [luminance] (cd/m²).
  ///
  /// Calibration constant K = 12.5.
  /// `EV100 = log2(luminance * 100 / 12.5)`
  static double ev100FromLuminance(double luminance) {
    return math.log(luminance * (100.0 / 12.5)) / math.ln2;
  }

  /// Computes the exposure value (EV at ISO 100) for the given [illuminance] (lux).
  ///
  /// Calibration constant C = 250.
  /// `EV100 = log2(illuminance * 100 / 250)`
  static double ev100FromIlluminance(double illuminance) {
    return math.log(illuminance * (100.0 / 250.0)) / math.ln2;
  }

  /// Computes the photometric exposure from direct camera parameters.
  ///
  /// `exposure = 1 / (1.2 * e)` where `e = (aperture^2 / shutterSpeed) * (100 / sensitivity)`.
  static double exposure({
    required double aperture,
    required double shutterSpeed,
    required double sensitivity,
  }) {
    final e = (aperture * aperture) / shutterSpeed * 100.0 / sensitivity;
    return 1.0 / (1.2 * e);
  }

  /// Computes the photometric exposure for the given [ev100].
  ///
  /// `exposure = 1 / (1.2 * 2^EV100)`
  static double exposureFromEv100(double ev100) {
    return 1.0 / (1.2 * math.pow(2.0, ev100));
  }

  /// Computes incident luminance in cd/m² for the specified camera parameters acting as a spot meter.
  static double luminance({
    required double aperture,
    required double shutterSpeed,
    required double sensitivity,
  }) {
    final e = (aperture * aperture) / shutterSpeed * 100.0 / sensitivity;
    return e * 0.125;
  }

  /// Converts [ev100] to luminance in cd/m².
  ///
  /// `L = 2^(EV100 - 3)`
  static double luminanceFromEv100(double ev100) {
    return math.pow(2.0, ev100 - 3.0).toDouble();
  }

  /// Computes illuminance in lux for the specified camera parameters acting as an incident light meter.
  static double illuminance({
    required double aperture,
    required double shutterSpeed,
    required double sensitivity,
  }) {
    final e = (aperture * aperture) / shutterSpeed * 100.0 / sensitivity;
    return 2.5 * e;
  }

  /// Converts [ev100] to illuminance in lux.
  ///
  /// `E = 2.5 * 2^EV100`
  static double illuminanceFromEv100(double ev100) {
    return 2.5 * math.pow(2.0, ev100).toDouble();
  }
}
