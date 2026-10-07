import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart';

import 'package:lumina/src/world/world.dart';
import 'package:lumina/src/components/camera/camera_component.dart';
import 'package:lumina/src/components/light/directional_light_component.dart';
import 'package:lumina/src/components/light/light_component.dart';
import 'package:lumina/src/components/light/point_light_component.dart';
import 'package:lumina/src/components/light/spot_light_component.dart';

/// The camera exposure a level's lights call for, the
/// default auto exposure that the editor viewport,
/// Play-In-Editor and the generated game all use.
///
/// Every camera used to keep Filament's sunny-16 exposure (f/16, 1/125 s,
/// ISO 100, EV100 ≈ 15) whatever lit the level, so a level lit only by point
/// and spot lights rendered 7–9 stops under-exposed: black. The exposure is
/// now metered from the lights, like an incident light meter (EV100 =
/// log2(E · 100 / C), C = 250):
///
/// - a sky light (an image-based light in the scene) is daylight: sunny 16;
/// - a directional light meters its illuminance (lux) — the 80 000 lux and
///   brighter suns templates use stay at sunny 16;
/// - a point or spot light meters its illuminance at [keyDistanceMetres],
///   the distance a lamp typically lights a room from;
/// - the brightest of those is the key; nothing to meter keeps sunny 16.
///
/// The result is clamped to [[minEv100], [daylightEv100]], so no level is
/// rendered darker than before. Filament renders no luminance histogram, so
/// this is metered from the lights rather than from the frame.
abstract final class LuminaAutoExposure {
  /// The default photographic exposure every camera starts from.
  static const double aperture = 16.0;
  static const double shutterSpeed = 1.0 / 125.0;
  static const double sensitivity = 100.0;

  /// EV100 of the default exposure (sunny 16): log2(N² / t).
  static final double daylightEv100 = _log2(aperture * aperture / shutterSpeed);

  /// The darkest scene the exposure follows down to: EV100 3, a candle-lit
  /// room in the photographic exposure tables. Dimmer lamps than ~1 000 lm
  /// render darker instead of being brightened further.
  static const double minEv100 = 3.0;

  /// Where a point or spot light is metered from (a typical
  /// attenuation radius is 10 m; a lamp lights a room from about 2 m).
  static const double keyDistanceMetres = 2.0;

  /// Incident-light meter calibration constant C (lux).
  static const double meterCalibration = 250.0;

  static double _log2(double v) => math.log(v) / math.ln2;

  /// The physical luminous intensity (candela) of a point or spot light, as
  /// Filament converts its lumens (point: lm / 4π; spot: lm / π).
  static double candelaOf(LuminaLightComponent light) => switch (light) {
        LuminaPointLightComponent(intensityInCandela: true) => light.intensity,
        LuminaPointLightComponent() => light.intensity / (4 * math.pi),
        LuminaSpotLightComponent(intensityInCandela: true) => light.intensity,
        LuminaSpotLightComponent() => light.intensity / math.pi,
        _ => 0.0,
      };

  /// The illuminance (lux) [light] is metered at.
  static double keyIlluminance(LuminaLightComponent light) {
    if (!light.visible || light.intensity <= 0) return 0.0;
    if (light is LuminaDirectionalLightComponent) return light.intensity;
    return candelaOf(light) / (keyDistanceMetres * keyDistanceMetres);
  }

  /// The EV100 [lights] call for; [skyLight] when the scene has an
  /// image-based light.
  static double ev100For(Iterable<LuminaLightComponent> lights, {bool skyLight = false}) {
    if (skyLight) return daylightEv100;
    var key = 0.0;
    for (final light in lights) {
      key = math.max(key, keyIlluminance(light));
    }
    if (key <= 0) return daylightEv100;
    return _log2(key * sensitivity / meterCalibration).clamp(minEv100, daylightEv100);
  }

  /// The shutter speed (s) that gives [ev100] at f/16 and ISO 100: N² / 2^EV.
  /// The shutter, not the ISO, carries the exposure, because Filament clamps
  /// the ISO to 204 800 (EV100 ≈ 4) but the shutter only at 60 s (EV100 ≈ 2).
  static double shutterSpeedFor(double ev100) => aperture * aperture / math.pow(2.0, ev100);

  /// Filament's exposure factor for [ev100]: 1 / (1.2 · 2^EV100).
  static double exposureFactor(double ev100) => 1.0 / (1.2 * math.pow(2.0, ev100));

  /// The light components registered in [world]'s levels.
  static Iterable<LuminaLightComponent> lightsIn(LuminaWorld world) sync* {
    for (final level in world.levels) {
      for (final actor in level.actors) {
        for (final component in actor.components) {
          if (component is LuminaLightComponent) yield component;
        }
      }
    }
  }

  /// The EV100 [world]'s lights and sky call for.
  static double ev100ForWorld(LuminaWorld world) => ev100For(
        lightsIn(world),
        skyLight: world.hasNativeContext && world.filamentScene.indirectLight != null,
      );

  /// Points [camera] at [ev100] through its photographic settings, unless
  /// its exposure is set by hand ([LuminaCameraComponent.autoExposure] off).
  static void applyTo(LuminaCameraComponent camera, double ev100) {
    if (!camera.autoExposure) return;
    camera
      ..aperture = aperture
      ..shutterSpeed = shutterSpeedFor(ev100)
      ..sensitivity = sensitivity;
  }
}

/// A light colour picked as `#RRGGBB` (sRGB, what the colour picker
/// shows) in the linear RGB Filament's lights take. [fallback] for a missing or malformed value.
Vector3 luminaLightColorFromHex(String? hex, {Vector3? fallback}) {
  var h = (hex ?? '').trim();
  if (h.startsWith('#')) h = h.substring(1);
  if (h.length == 8) h = h.substring(2);
  final v = h.length == 6 ? int.tryParse(h, radix: 16) : null;
  if (v == null) return fallback?.clone() ?? Vector3(1, 1, 1);
  return Vector3(
    luminaSrgbToLinear(((v >> 16) & 0xFF) / 255.0),
    luminaSrgbToLinear(((v >> 8) & 0xFF) / 255.0),
    luminaSrgbToLinear((v & 0xFF) / 255.0),
  );
}

/// The sRGB transfer function's inverse for one 0..1 channel.
double luminaSrgbToLinear(double c) =>
    c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
