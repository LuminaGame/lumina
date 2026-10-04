import 'package:flutter_filament/flutter_filament.dart';
import '../../math/units.dart';
import 'light_component.dart';

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
}
