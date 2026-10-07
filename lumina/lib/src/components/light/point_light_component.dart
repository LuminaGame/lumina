import 'dart:math' as math;
import 'package:flutter_filament/flutter_filament.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;
import 'package:lumina/src/math/units.dart';
import 'package:lumina/src/components/light/light_component.dart';

/// Omnidirectional point light component with luminous flux intensity in lumens (or candela).
class LuminaPointLightComponent extends LuminaLightComponent {
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

  LuminaPointLightComponent({
    super.key,
    super.location,
    super.rotation,
    super.scale,
    super.color,
    super.intensity = 10000.0, // Default: 10,000 lumens
    this.intensityInCandela = false,
    this._falloffRadius = 1000.0, // cm
    super.castShadows = false,
    super.shadowOptions,
    super.visible = true,
  });

  @override
  LightBuilder createLightBuilder() {
    final builder = LightBuilder(LightType.point)
      ..color(color.x, color.y, color.z)
      ..falloff(falloffRadius)
      ..castShadows(castShadows);

    // Authored in physical units; Filament gets the cm-world power.
    if (intensityInCandela) {
      builder.intensityCandela(LuminaUnits.lightPower(intensity));
    } else {
      builder.intensity(LuminaUnits.lightPower(intensity));
    }

    final pos = worldLocation;
    builder.position(pos.x, pos.y, pos.z);
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
    lm.setPosition(entity, pos.x, pos.y, pos.z);
  }

  /// Builds wireframe line segments (pairs of vertices in world space, runtime Y-up)
  /// representing the point light sphere of influence (3 orthogonal circles and center cross).
  List<Vector3> buildSphereWireframe({int segments = 24}) {
    final pts = <Vector3>[];
    final r = falloffRadius;
    if (r <= 0) return pts;

    final center = worldLocation;
    final right = rightVector..normalize();
    final up = upVector..normalize();
    final fwd = forwardVector..normalize();

    final step = (2.0 * math.pi) / segments;
    for (int i = 0; i < segments; i++) {
      final a1 = i * step;
      final a2 = (i + 1) * step;

      final cos1 = math.cos(a1);
      final sin1 = math.sin(a1);
      final cos2 = math.cos(a2);
      final sin2 = math.sin(a2);

      // Ring 1: Right - Up plane
      pts.add(center + (right * (cos1 * r)) + (up * (sin1 * r)));
      pts.add(center + (right * (cos2 * r)) + (up * (sin2 * r)));

      // Ring 2: Right - Forward plane
      pts.add(center + (right * (cos1 * r)) + (fwd * (sin1 * r)));
      pts.add(center + (right * (cos2 * r)) + (fwd * (sin2 * r)));

      // Ring 3: Up - Forward plane
      pts.add(center + (up * (cos1 * r)) + (fwd * (sin1 * r)));
      pts.add(center + (up * (cos2 * r)) + (fwd * (sin2 * r)));
    }

    // Center cross
    final crossSize = math.min(15.0, r * 0.2);
    pts.add(center - (right * crossSize));
    pts.add(center + (right * crossSize));
    pts.add(center - (up * crossSize));
    pts.add(center + (up * crossSize));
    pts.add(center - (fwd * crossSize));
    pts.add(center + (fwd * crossSize));

    return pts;
  }
}
