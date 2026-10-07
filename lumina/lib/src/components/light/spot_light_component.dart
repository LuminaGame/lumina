import 'dart:math' as math;
import 'package:flutter_filament/flutter_filament.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina/src/components/light/light_component.dart';

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

  /// Builds wireframe line segments (pairs of vertices in world space, runtime Y-up)
  /// representing the spot light cone (outer circle and 8 boundary rays, inner circle
  /// and 4 boundary rays, and central forward beam axis).
  List<Vector3> buildConeWireframe({int segments = 24}) {
    final pts = <Vector3>[];
    final r = falloffRadius;
    if (r <= 0) return pts;

    final apex = worldLocation;
    final fwd = lightDirection;
    final right = rightVector..normalize();
    final up = upVector..normalize();

    final step = (2.0 * math.pi) / segments;

    // Outer cone base circle and boundary rays
    final thetaOuter = _outerConeAngleDegrees * math.pi / 180.0;
    final distOuter = r * math.cos(thetaOuter);
    final radiusOuter = r * math.sin(thetaOuter);
    final centerOuter = apex + (fwd * distOuter);

    for (int i = 0; i < segments; i++) {
      final a1 = i * step;
      final a2 = (i + 1) * step;
      final p1 = centerOuter + (right * (radiusOuter * math.cos(a1))) + (up * (radiusOuter * math.sin(a1)));
      final p2 = centerOuter + (right * (radiusOuter * math.cos(a2))) + (up * (radiusOuter * math.sin(a2)));
      pts.add(p1);
      pts.add(p2);
    }

    const outerRays = 8;
    for (int k = 0; k < outerRays; k++) {
      final angle = (2.0 * math.pi * k) / outerRays;
      final target = centerOuter + (right * (radiusOuter * math.cos(angle))) + (up * (radiusOuter * math.sin(angle)));
      pts.add(apex);
      pts.add(target);
    }

    // Inner cone base circle and boundary rays (if inner cone angle is positive and less than outer)
    if (_innerConeAngleDegrees > 0) {
      final thetaInner = _innerConeAngleDegrees * math.pi / 180.0;
      final distInner = r * math.cos(thetaInner);
      final radiusInner = r * math.sin(thetaInner);
      final centerInner = apex + (fwd * distInner);

      for (int i = 0; i < segments; i++) {
        final a1 = i * step;
        final a2 = (i + 1) * step;
        final p1 = centerInner + (right * (radiusInner * math.cos(a1))) + (up * (radiusInner * math.sin(a1)));
        final p2 = centerInner + (right * (radiusInner * math.cos(a2))) + (up * (radiusInner * math.sin(a2)));
        pts.add(p1);
        pts.add(p2);
      }

      const innerRays = 4;
      for (int k = 0; k < innerRays; k++) {
        final angle = (2.0 * math.pi * k) / innerRays;
        final target = centerInner + (right * (radiusInner * math.cos(angle))) + (up * (radiusInner * math.sin(angle)));
        pts.add(apex);
        pts.add(target);
      }
    }

    // Central forward beam axis line
    pts.add(apex);
    pts.add(apex + (fwd * r));

    return pts;
  }
}
