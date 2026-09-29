import 'package:flutter_filament/flutter_filament.dart';
import 'light_component.dart';

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
}
