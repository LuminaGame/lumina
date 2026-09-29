import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart';

/// Type of color conversion to use when converting to/from sRGB and linear spaces.
enum ColorConversion {
  /// Accurate piecewise conversion per IEC 61966-2-1 standard.
  accurate,

  /// Fast conversion using a simple gamma 2.2 curve.
  fast,
}

/// Color manipulation and colorimetry utilities.
///
/// Direct pure-Dart reimplementation of `filament::Color` and `ColorSpaceUtils.h`.
class FilamentColor {
  // XYZ to sRGB conversion matrix (column-major)
  static final Matrix3 _xyzToSrgb = Matrix3(
     3.2404542, -0.9692660,  0.0556434,
    -1.5371385,  1.8760108, -0.2040259,
    -0.4985314,  0.0415560,  1.0572252,
  );

  /// Converts an RGB color in sRGB space to linear space.
  static Vector3 toLinear(
    Vector3 srgb, [
    ColorConversion conversion = ColorConversion.accurate,
  ]) {
    if (conversion == ColorConversion.fast) {
      return Vector3(
        math.pow(srgb.x, 2.2).toDouble(),
        math.pow(srgb.y, 2.2).toDouble(),
        math.pow(srgb.z, 2.2).toDouble(),
      );
    }
    return Vector3(
      _eotfSrgbChannel(srgb.x),
      _eotfSrgbChannel(srgb.y),
      _eotfSrgbChannel(srgb.z),
    );
  }

  /// Converts an RGB color in linear space to sRGB space.
  static Vector3 toSRGB(
    Vector3 linear, [
    ColorConversion conversion = ColorConversion.accurate,
  ]) {
    if (conversion == ColorConversion.fast) {
      const p = 1.0 / 2.2;
      return Vector3(
        math.pow(linear.x, p).toDouble(),
        math.pow(linear.y, p).toDouble(),
        math.pow(linear.z, p).toDouble(),
      );
    }
    return Vector3(
      _oetfSrgbChannel(linear.x),
      _oetfSrgbChannel(linear.y),
      _oetfSrgbChannel(linear.z),
    );
  }

  /// Converts an RGBA color in sRGB space to linear space, leaving alpha unmodified.
  static Vector4 toLinearRgba(
    Vector4 srgba, [
    ColorConversion conversion = ColorConversion.accurate,
  ]) {
    final rgb = toLinear(srgba.xyz, conversion);
    return Vector4(rgb.x, rgb.y, rgb.z, srgba.w);
  }

  /// Converts an RGBA color in linear space to sRGB space, leaving alpha unmodified.
  static Vector4 toSRGBRgba(
    Vector4 linearA, [
    ColorConversion conversion = ColorConversion.accurate,
  ]) {
    final rgb = toSRGB(linearA.xyz, conversion);
    return Vector4(rgb.x, rgb.y, rgb.z, linearA.w);
  }

  /// Converts a Correlated Color Temperature [kelvin] (1,000K to 15,000K)
  /// to a linear RGB color in sRGB space.
  ///
  /// Output is normalized such that the maximum component equals 1.0.
  static Vector3 cct(double kelvin) {
    final kClamped = kelvin.clamp(1000.0, 15000.0);
    final k2 = kClamped * kClamped;

    final u = (0.860117757 + 1.54118254e-4 * kClamped + 1.28641212e-7 * k2) /
        (1.0 + 8.42420235e-4 * kClamped + 7.08145163e-7 * k2);
    final v = (0.317398726 + 4.22806245e-5 * kClamped + 4.20481691e-8 * k2) /
        (1.0 - 2.89741816e-5 * kClamped + 1.61456053e-7 * k2);

    final d = 1.0 / (2.0 * u - 8.0 * v + 4.0);
    final xyz = _xyYToXYZ(3.0 * u * d, 2.0 * v * d, 1.0);
    final linear = _xyzToSrgb.transformed(xyz);

    final maxVal = math.max(1e-5, math.max(linear.x, math.max(linear.y, linear.z)));
    return Vector3(
      (linear.x / maxVal).clamp(0.0, 1.0),
      (linear.y / maxVal).clamp(0.0, 1.0),
      (linear.z / maxVal).clamp(0.0, 1.0),
    );
  }

  /// Converts a CIE standard illuminant series D temperature [kelvin] (4,000K to 25,000K)
  /// to a linear RGB color in sRGB space.
  ///
  /// Output is normalized such that the maximum component equals 1.0.
  static Vector3 illuminantD(double kelvin) {
    final kClamped = kelvin.clamp(4000.0, 25000.0);
    final ik = 1.0 / kClamped;
    final ik2 = ik * ik;

    final x = kClamped <= 7000.0
        ? 0.244063 + 0.09911e3 * ik + 2.9678e6 * ik2 - 4.6070e9 * ik2 * ik
        : 0.237040 + 0.24748e3 * ik + 1.9018e6 * ik2 - 2.0064e9 * ik2 * ik;
    final y = -3.0 * x * x + 2.87 * x - 0.275;

    final xyz = _xyYToXYZ(x, y, 1.0);
    final linear = _xyzToSrgb.transformed(xyz);

    final maxVal = math.max(1e-5, math.max(linear.x, math.max(linear.y, linear.z)));
    return Vector3(
      (linear.x / maxVal).clamp(0.0, 1.0),
      (linear.y / maxVal).clamp(0.0, 1.0),
      (linear.z / maxVal).clamp(0.0, 1.0),
    );
  }

  /// Computes Beer-Lambert absorption coefficients from [transmittanceColor] and [distance].
  static Vector3 absorptionAtDistance(Vector3 transmittanceColor, double distance) {
    final d = math.max(1e-5, distance);
    return Vector3(
      -math.log(transmittanceColor.x.clamp(1e-5, 1.0)) / d,
      -math.log(transmittanceColor.y.clamp(1e-5, 1.0)) / d,
      -math.log(transmittanceColor.z.clamp(1e-5, 1.0)) / d,
    );
  }

  static double _eotfSrgbChannel(double x) {
    if (x <= 0.04045) {
      return x / 12.92;
    }
    return math.pow((x + 0.055) / 1.055, 2.4).toDouble();
  }

  static double _oetfSrgbChannel(double x) {
    if (x <= 0.0031308) {
      return x * 12.92;
    }
    return 1.055 * math.pow(x, 1.0 / 2.4) - 0.055;
  }

  static Vector3 _xyYToXYZ(double x, double y, double bigY) {
    final a = bigY / math.max(y, 1e-5);
    return Vector3(x * a, bigY, (1.0 - x - y) * a);
  }
}
