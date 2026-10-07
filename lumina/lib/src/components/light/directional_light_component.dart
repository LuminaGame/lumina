import 'package:flutter_filament/flutter_filament.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;
import 'package:lumina/src/components/light/light_component.dart';

/// Directional or Sun light component with illuminance intensity in lux.
class LuminaDirectionalLightComponent extends LuminaLightComponent {
  final bool isSun;
  final double sunAngularRadius;
  final double sunHaloSize;
  final double sunHaloFalloff;

  LuminaDirectionalLightComponent({
    super.key,
    super.location,
    super.rotation,
    super.scale,
    super.color,
    super.intensity = 100000.0, // Default: 100,000 lux (sun at noon)
    super.castShadows = false,
    super.shadowOptions,
    super.visible = true,
    this.isSun = true,
    this.sunAngularRadius = 0.545,
    this.sunHaloSize = 10.0,
    this.sunHaloFalloff = 80.0,
  });

  @override
  LightBuilder createLightBuilder() {
    final builder = LightBuilder(isSun ? LightType.sun : LightType.directional)
      ..color(color.x, color.y, color.z)
      ..intensity(intensity)
      ..castShadows(castShadows);

    final dir = lightDirection;
    builder.direction(dir.x, dir.y, dir.z);

    if (isSun) {
      builder
        ..sunAngularRadius(sunAngularRadius)
        ..sunHaloSize(sunHaloSize)
        ..sunHaloFalloff(sunHaloFalloff);
    }

    return builder;
  }

  @override
  void syncNativeTransform(FilamentLightManager lm, int entity) {
    final dir = lightDirection;
    lm.setDirection(entity, dir.x, dir.y, dir.z);
  }

  /// Builds wireframe line segments (pairs of vertices in world space, runtime Y-up)
  /// representing the directional light direction (stem arrow, 4 fins, and tail cross).
  List<Vector3> buildArrowWireframe({double length = 120.0}) {
    final pts = <Vector3>[];
    final origin = worldLocation;
    final fwd = lightDirection;
    final right = rightVector..normalize();
    final up = upVector..normalize();

    // Central stem
    final tip = origin + (fwd * length);
    pts.add(origin);
    pts.add(tip);

    // 4 arrow head fins
    final head = length * 0.2;
    final spread = length * 0.08;
    final finBase = tip - (fwd * head);
    for (final (fx, fy) in [(1.0, 0.0), (-1.0, 0.0), (0.0, 1.0), (0.0, -1.0)]) {
      final fin = finBase + (right * (fx * spread)) + (up * (fy * spread));
      pts.add(tip);
      pts.add(fin);
    }

    // Tail cross
    const tailSize = 20.0;
    pts.add(origin - (right * tailSize));
    pts.add(origin + (right * tailSize));
    pts.add(origin - (up * tailSize));
    pts.add(origin + (up * tailSize));

    return pts;
  }
}
