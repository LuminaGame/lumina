import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart';

/// Editor-side solar position and colour-temperature helpers for the
/// Environment Lighting mixer.
///
/// These are deterministic editor conveniences, not a sky simulation: the
/// time-of-day slider is mapped onto a simple day arc (sunrise 06:00, zenith
/// at 12:00, sunset 18:00) and the Kelvin slider onto a Planckian-locus
/// approximation. The level and the generated game only ever receive the
/// *final* light values (direction + colour) computed here.
class SolarMath {
  const SolarMath._();

  static const double sunriseHour = 6.0;
  static const double sunsetHour = 18.0;

  /// Elevation reached at 12:00 (zenith).
  static const double maxElevationDeg = 90.0;

  /// Degrees of azimuth the sun travels per hour (a full turn per day).
  static const double degreesPerHour = 360.0 / 24.0;

  /// Solar elevation (degrees above the horizon, negative at night) and
  /// azimuth (degrees clockwise from north: 0 = N, 90 = E, 180 = S, 270 = W)
  /// for [timeOfDay] in hours (0–24, 24 wraps to midnight).
  static ({double elevation, double azimuth}) anglesForTime(double timeOfDay) {
    final t = _wrapHours(timeOfDay);
    final phase = (t - sunriseHour) / (sunsetHour - sunriseHour);
    final elevation = maxElevationDeg * math.sin(math.pi * phase);
    return (elevation: _zeroSnap(elevation), azimuth: t * degreesPerHour);
  }

  /// Inverse of the azimuth half of [anglesForTime]: the hour at which the
  /// sun sits at [azimuthDeg] (used when the viewport gizmo drives the slider).
  static double timeForAzimuth(double azimuthDeg) => _wrapDegrees(azimuthDeg) / degreesPerHour;

  /// Direction the sunlight travels (from the sun toward the scene), Y-up,
  /// unit length. +X is east, -Z is north.
  static Vector3 lightDirection(double elevationDeg, double azimuthDeg) {
    final el = radians(elevationDeg);
    final az = radians(azimuthDeg);
    final sun = Vector3(
      math.cos(el) * math.sin(az),
      math.sin(el),
      -math.cos(el) * math.cos(az),
    );
    return (-sun)..normalize();
  }

  /// The stored (Z-up) rotation `[x, y, z]` in degrees of a Sun
  /// actor whose light travels along [lightDirection]. This is what the level
  /// actor stores, so PIE and the generated game build the same light.
  static List<double> eulerForAngles(double elevationDeg, double azimuthDeg) {
    return eulerForDirection(lightDirection(elevationDeg, azimuthDeg));
  }

  /// The stored rotation `[x (pitch), 0, z (yaw)]` in degrees whose drawn −Z
  /// is [direction] (runtime, Y-up). A light follows its drawn rotation:
  /// `LuminaAxes.rotation([x, 0, z])` = `Ry(−z)·Rx(x)`, whose
  /// −Z is `(sin z·cos x, sin x, −cos z·cos x)`.
  static List<double> eulerForDirection(Vector3 direction) {
    final d = direction.normalized();
    final pitch = math.asin(d.y.clamp(-1.0, 1.0));
    final horizontal = math.sqrt(d.x * d.x + d.z * d.z);
    final yaw = horizontal < 1e-9 ? 0.0 : math.atan2(d.x, -d.z);
    return [_zeroSnap(degrees(pitch)), 0.0, _zeroSnap(degrees(yaw))];
  }

  /// Linear RGB (0..1) for a colour temperature in Kelvin (Tanner Helland's
  /// approximation of the Planckian locus), valid for 1000–40000 K.
  static Vector3 kelvinToRgb(double kelvin) {
    final temp = kelvin.clamp(1000.0, 40000.0) / 100.0;
    double r, g, b;
    if (temp <= 66.0) {
      r = 255.0;
      g = 99.4708025861 * math.log(temp) - 161.1195681661;
      b = temp <= 19.0 ? 0.0 : 138.5177312231 * math.log(temp - 10.0) - 305.0447927307;
    } else {
      r = 329.698727446 * math.pow(temp - 60.0, -0.1332047592);
      g = 288.1221695283 * math.pow(temp - 60.0, -0.0755148492);
      b = 255.0;
    }
    return Vector3(
      (r / 255.0).clamp(0.0, 1.0),
      (g / 255.0).clamp(0.0, 1.0),
      (b / 255.0).clamp(0.0, 1.0),
    );
  }

  /// `#RRGGBB` for a 0..1 RGB vector.
  static String rgbToHex(Vector3 rgb) {
    String ch(double v) => (v.clamp(0.0, 1.0) * 255).round().toRadixString(16).padLeft(2, '0');
    return '#${ch(rgb.x)}${ch(rgb.y)}${ch(rgb.z)}'.toUpperCase();
  }

  /// Parses `#RRGGBB` / `#AARRGGBB` into a 0..1 RGB vector; white on error.
  static Vector3 hexToRgb(String hex) {
    var h = hex.trim();
    if (h.startsWith('#')) h = h.substring(1);
    if (h.length == 8) h = h.substring(2);
    final v = h.length == 6 ? int.tryParse(h, radix: 16) : null;
    if (v == null) return Vector3(1.0, 1.0, 1.0);
    return Vector3(((v >> 16) & 0xFF) / 255.0, ((v >> 8) & 0xFF) / 255.0, (v & 0xFF) / 255.0);
  }

  /// `HH:MM` for a time-of-day in hours.
  static String formatTime(double timeOfDay) {
    final t = _wrapHours(timeOfDay);
    final totalMinutes = (t * 60).floor();
    final hour = (totalMinutes ~/ 60) % 24;
    final minute = totalMinutes % 60;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  /// Human day-phase label for the HUD (`14:30 — Afternoon`).
  static String dayPhase(double timeOfDay) {
    final t = _wrapHours(timeOfDay);
    if (t < 5.0) return 'Night';
    if (t < 7.0) return 'Dawn';
    if (t < 12.0) return 'Morning';
    if (t < 13.0) return 'Noon';
    if (t < 17.0) return 'Afternoon';
    if (t < 19.0) return 'Dusk';
    if (t < 21.0) return 'Evening';
    return 'Night';
  }

  static double _wrapHours(double hours) {
    final t = hours % 24.0;
    return t < 0 ? t + 24.0 : t;
  }

  static double _wrapDegrees(double degrees) {
    final d = degrees % 360.0;
    return d < 0 ? d + 360.0 : d;
  }

  /// Sunrise/sunset land on sin(0)/sin(pi) which carry floating noise.
  static double _zeroSnap(double v) => v.abs() < 1e-9 ? 0.0 : v;
}
