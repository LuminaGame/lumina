import 'dart:math' as math;
import 'package:flutter_filament/flutter_filament.dart';
import '../../math/units.dart';
import 'light_component.dart';

/// Focused or standard spot light component with cone angles in degrees (converted to radians at FFI boundary).
class LuminaSpotLightComponent extends LuminaLightComponent {
  final bool intensityInCandela;
  double _falloffRadius;

  /// Sphere of influence, in world units (cm); the attenuation radius.
  /// Reaches Filament live.
  double get falloffRadius => _falloffRadius;
  set falloffRadius(double value) {
    _falloffRadius = value;
    final w = owner?.world;
    if (lightEntity != null && w != null && w.hasNativeContext) {
      FilamentLightManager(w.filamentEngine).setFalloff(lightEntity!, value);
    }
  }

  /// Sphere of influence, in world units (cm); alias for [falloffRadius].
  double get attenuationRadius => falloffRadius;
  set attenuationRadius(double value) => falloffRadius = value;

  double _innerConeAngleDegrees;
  double _outerConeAngleDegrees;

  LuminaSpotLightComponent({
    super.key,
    super.location,
    super.rotation,
    super.scale,
    super.color,
    super.intensity = 10000.0, // Default: 10,000 lumens
    this.intensityInCandela = false,
    this._falloffRadius = 1000.0, // cm
    double innerConeAngleDegrees = 30.0,
    double outerConeAngleDegrees = 45.0,
    super.castShadows = false,
    super.shadowOptions,
    super.visible = true,
  }) : _innerConeAngleDegrees = innerConeAngleDegrees,
       _outerConeAngleDegrees = outerConeAngleDegrees {
    if (innerConeAngleDegrees < 0.0 || innerConeAngleDegrees > outerConeAngleDegrees || outerConeAngleDegrees > 90.0) {
      throw ArgumentError('Invalid spot cone angles: must satisfy 0 <= inner <= outer <= 90');
    }
  }

  double get innerConeAngleDegrees => _innerConeAngleDegrees;
  double get outerConeAngleDegrees => _outerConeAngleDegrees;

  /// Inner cone angle in degrees.
  double get innerConeAngle => _innerConeAngleDegrees;
  set innerConeAngle(double value) {
    final v = value.clamp(0.0, 90.0);
    setConeAngles(innerDegrees: v, outerDegrees: math.max(v, _outerConeAngleDegrees));
  }

  /// Outer cone angle in degrees.
  double get outerConeAngle => _outerConeAngleDegrees;
  set outerConeAngle(double value) {
    final v = value.clamp(0.0, 90.0);
    setConeAngles(innerDegrees: math.min(v, _innerConeAngleDegrees), outerDegrees: v);
  }

  /// Sets inner and outer cone angles in degrees with validation (`0 <= inner <= outer <= 90`).
  void setConeAngles({required double innerDegrees, required double outerDegrees}) {
    if (innerDegrees < 0.0 || innerDegrees > outerDegrees || outerDegrees > 90.0) {
      throw ArgumentError('Invalid spot cone angles: must satisfy 0 <= inner <= outer <= 90');
    }
    _innerConeAngleDegrees = innerDegrees;
    _outerConeAngleDegrees = outerDegrees;

    final w = owner?.world;
    if (lightEntity != null && w != null && w.hasNativeContext) {
      final lm = FilamentLightManager(w.filamentEngine);
      final innerRad = math.max(0.00873, innerDegrees * math.pi / 180.0);
      final outerRad = math.max(innerRad, outerDegrees * math.pi / 180.0);
      lm.setSpotLightCone(lightEntity!, innerRad, outerRad);
    }
  }

  @override
  LightBuilder createLightBuilder() {
    final innerRad = math.max(0.00873, _innerConeAngleDegrees * math.pi / 180.0);
    final outerRad = math.max(innerRad, _outerConeAngleDegrees * math.pi / 180.0);

    final builder = LightBuilder(LightType.spot)
      ..color(color.x, color.y, color.z)
      ..falloff(falloffRadius)
      ..spotLightCone(innerRad, outerRad)
      ..castShadows(castShadows);

    // Authored in physical units; Filament gets the cm-world power.
    if (intensityInCandela) {
      builder.intensityCandela(LuminaUnits.lightPower(intensity));
    } else {
      builder.intensity(LuminaUnits.lightPower(intensity));
    }

    final pos = worldLocation;
    final dir = lightDirection;
    builder.position(pos.x, pos.y, pos.z);
    builder.direction(dir.x, dir.y, dir.z);
    return builder;
  }

  @override
  void applyIntensity(FilamentLightManager lm, int entity, double intensity) {
    if (intensityInCandela) {
      lm.setIntensityCandela(entity, LuminaUnits.lightPower(intensity));
    } else {
      lm.setIntensity(entity, LuminaUnits.lightPower(intensity));
    }
  }

  @override
  void syncNativeTransform(FilamentLightManager lm, int entity) {
    final pos = worldLocation;
    final dir = lightDirection;
    lm.setPosition(entity, pos.x, pos.y, pos.z);
    lm.setDirection(entity, dir.x, dir.y, dir.z);
  }
}
