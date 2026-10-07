import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_filament/flutter_filament.dart' show FogOptions;
import 'package:vector_math/vector_math_64.dart';

import 'package:lumina/src/game/primitive_actor.dart' show luminaHexToRgb, luminaRgbToHex;
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina/src/object/actor.dart';
import 'package:lumina/src/post_process/post_process_blender.dart';
import 'package:lumina/src/world/world.dart';
import 'package:lumina/src/components/base/scene_component.dart';

/// Exponential Height Fog settings, mapped onto Filament's per-view
/// `FogOptions`. Filament's fog is global and exponential in
/// height, so this is a field-for-field mapping, not an approximation:
///
/// | Setting                 | Filament `FogOptions`                 |
/// |-------------------------|---------------------------------------|
/// | Fog Density (/m)        | `density` (/cm)                       |
/// | Fog Height Falloff (/m) | `heightFalloff` (/cm)                 |
/// | Start Distance (cm)     | `distance`                            |
/// | Fog Cutoff Distance (cm)| `cutOffDistance` (0 → infinity)       |
/// | Fog Max Opacity         | `maximumOpacity`                      |
/// | Fog Inscattering Color  | `colorR/G/B`                          |
/// | Use sky colour          | `fogColorFromIbl`                     |
/// | the actor's Z           | `height` (the runtime Y, cm)          |
///
/// Density and falloff are per metre in content and divided by [LuminaUnits.unitsPerMetre] once, here.
class LuminaHeightFogSettings {
  const LuminaHeightFogSettings({
    this.enabled = true,
    this.fogDensity = 0.02,
    this.fogHeightFalloff = 0.2,
    this.startDistance = 0.0,
    this.fogCutoffDistance = 0.0,
    this.fogMaxOpacity = 1.0,
    this.inscatteringColor = defaultInscatteringColor,
    this.useSkyColor = false,
    this.height = 0.0,
  });

  static const LuminaHeightFogSettings defaults = LuminaHeightFogSettings();

  /// The default inscattering colour (0.447, 0.638, 1.0).
  static const Vector3Const defaultInscatteringColor = Vector3Const(0.447, 0.638, 1.0);

  final bool enabled;

  /// Per metre (default 0.02).
  final double fogDensity;

  /// Per metre (default 0.2).
  final double fogHeightFalloff;

  /// cm.
  final double startDistance;

  /// cm; 0 means no cutoff.
  final double fogCutoffDistance;

  /// 0..1.
  final double fogMaxOpacity;
  final Vector3Const inscatteringColor;
  final bool useSkyColor;

  /// The fog's reference height in runtime axes (Y up), cm — the fog actor's
  /// authored Z.
  final double height;

  factory LuminaHeightFogSettings.fromProperties(Map<String, dynamic>? p, {double height = 0.0}) {
    final m = p ?? const <String, dynamic>{};
    double num_(String k, double d) => m[k] is num ? (m[k] as num).toDouble() : d;
    bool bool_(String k, bool d) => m[k] is bool ? m[k] as bool : d;
    final hex = m['inscatteringColorHex'];
    final colour = hex is String ? luminaHexToRgb(hex) : null;
    return LuminaHeightFogSettings(
      enabled: bool_('enabled', defaults.enabled),
      fogDensity: num_('fogDensity', defaults.fogDensity).clamp(0.0, 10.0),
      fogHeightFalloff: num_('fogHeightFalloff', defaults.fogHeightFalloff).clamp(0.0, 100.0),
      startDistance: num_('startDistance', defaults.startDistance).clamp(0.0, 1e9),
      fogCutoffDistance: num_('fogCutoffDistance', defaults.fogCutoffDistance).clamp(0.0, 1e9),
      fogMaxOpacity: num_('fogMaxOpacity', defaults.fogMaxOpacity).clamp(0.0, 1.0),
      inscatteringColor: colour == null ? defaults.inscatteringColor : Vector3Const(colour.x, colour.y, colour.z),
      useSkyColor: bool_('useSkyColor', defaults.useSkyColor),
      height: height,
    );
  }

  /// The editor component's `properties` map (no height: that is the actor's Z).
  Map<String, dynamic> toProperties() => <String, dynamic>{
        'enabled': enabled,
        'fogDensity': fogDensity,
        'fogHeightFalloff': fogHeightFalloff,
        'startDistance': startDistance,
        'fogCutoffDistance': fogCutoffDistance,
        'fogMaxOpacity': fogMaxOpacity,
        'inscatteringColorHex': inscatteringColorHex,
        'useSkyColor': useSkyColor,
      };

  String get inscatteringColorHex =>
      luminaRgbToHex(Vector3(inscatteringColor.x, inscatteringColor.y, inscatteringColor.z));

  /// Filament's options, keeping from [base] what these settings have no field for
  /// (sun in-scattering, the sky colour texture).
  FogOptions toFogOptions(FogOptions base) => base.copyWith(
        enabled: enabled,
        density: fogDensity / LuminaUnits.unitsPerMetre,
        heightFalloff: fogHeightFalloff / LuminaUnits.unitsPerMetre,
        distance: startDistance,
        cutOffDistance: fogCutoffDistance > 0 ? fogCutoffDistance : double.infinity,
        maximumOpacity: fogMaxOpacity,
        height: height,
        colorR: inscatteringColor.x,
        colorG: inscatteringColor.y,
        colorB: inscatteringColor.z,
        fogColorFromIbl: useSkyColor,
      );

  LuminaHeightFogSettings copyWith({
    bool? enabled,
    double? fogDensity,
    double? fogHeightFalloff,
    double? startDistance,
    double? fogCutoffDistance,
    double? fogMaxOpacity,
    Vector3Const? inscatteringColor,
    bool? useSkyColor,
    double? height,
  }) =>
      LuminaHeightFogSettings(
        enabled: enabled ?? this.enabled,
        fogDensity: fogDensity ?? this.fogDensity,
        fogHeightFalloff: fogHeightFalloff ?? this.fogHeightFalloff,
        startDistance: startDistance ?? this.startDistance,
        fogCutoffDistance: fogCutoffDistance ?? this.fogCutoffDistance,
        fogMaxOpacity: fogMaxOpacity ?? this.fogMaxOpacity,
        inscatteringColor: inscatteringColor ?? this.inscatteringColor,
        useSkyColor: useSkyColor ?? this.useSkyColor,
        height: height ?? this.height,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LuminaHeightFogSettings &&
          enabled == other.enabled &&
          fogDensity == other.fogDensity &&
          fogHeightFalloff == other.fogHeightFalloff &&
          startDistance == other.startDistance &&
          fogCutoffDistance == other.fogCutoffDistance &&
          fogMaxOpacity == other.fogMaxOpacity &&
          inscatteringColor == other.inscatteringColor &&
          useSkyColor == other.useSkyColor &&
          height == other.height;

  @override
  int get hashCode => Object.hash(enabled, fogDensity, fogHeightFalloff, startDistance, fogCutoffDistance,
      fogMaxOpacity, inscatteringColor, useSkyColor, height);

  @override
  String toString() => 'LuminaHeightFogSettings(${toProperties()}, height: $height)';
}

/// A const-able RGB triple (vector_math's `Vector3` has no const constructor).
class Vector3Const {
  const Vector3Const(this.x, this.y, this.z);
  final double x;
  final double y;
  final double z;

  Vector3 toVector3() => Vector3(x, y, z);

  @override
  bool operator ==(Object other) => other is Vector3Const && x == other.x && y == other.y && z == other.z;

  @override
  int get hashCode => Object.hash(x, y, z);

  @override
  String toString() => '($x, $y, $z)';
}

/// The runtime form of the Exponential Height Fog actor.
///
/// It writes nothing to the view itself: each render prep it publishes its
/// [settings] — with its own world height — onto the world's
/// [LuminaPostProcessBlender], which composes them with the level baseline
/// and any Post Process / Local Fog volumes and applies the result. One per
/// world: a second component replaces the first (Filament has one fog per
/// view) and says so in the log.
class LuminaExponentialHeightFogComponent extends LuminaSceneComponent {
  LuminaExponentialHeightFogComponent({
    super.key,
    super.location,
    super.rotation,
    this.enabled = true,
    this.fogDensity = 0.02,
    this.fogHeightFalloff = 0.2,
    this.startDistance = 0.0,
    this.fogCutoffDistance = 0.0,
    this.fogMaxOpacity = 1.0,
    Vector3? inscatteringColor,
    this.useSkyColor = false,
    bool visible = true,
  })  : inscatteringColor = inscatteringColor ?? LuminaHeightFogSettings.defaultInscatteringColor.toVector3(),
        super(isVisible: visible);

  /// From the editor component's `properties` map (see
  /// [LuminaHeightFogSettings.fromProperties]).
  factory LuminaExponentialHeightFogComponent.fromProperties(
    Map<String, dynamic>? properties, {
    Vector3? location,
    Quaternion? rotation,
    bool visible = true,
  }) {
    final s = LuminaHeightFogSettings.fromProperties(properties);
    return LuminaExponentialHeightFogComponent(
      location: location,
      rotation: rotation,
      enabled: s.enabled,
      fogDensity: s.fogDensity,
      fogHeightFalloff: s.fogHeightFalloff,
      startDistance: s.startDistance,
      fogCutoffDistance: s.fogCutoffDistance,
      fogMaxOpacity: s.fogMaxOpacity,
      inscatteringColor: s.inscatteringColor.toVector3(),
      useSkyColor: s.useSkyColor,
      visible: visible,
    );
  }

  bool enabled;
  double fogDensity;
  double fogHeightFalloff;
  double startDistance;
  double fogCutoffDistance;
  double fogMaxOpacity;
  Vector3 inscatteringColor;
  bool useSkyColor;

  bool get visible => isVisible;
  set visible(bool v) => isVisible = v;

  /// Enabled and visible: what the blender sees.
  bool get isActive => enabled && isVisible;

  /// The settings as published: the fog height is this component's world Y.
  LuminaHeightFogSettings get settings => LuminaHeightFogSettings(
        enabled: isActive,
        fogDensity: fogDensity,
        fogHeightFalloff: fogHeightFalloff,
        startDistance: startDistance,
        fogCutoffDistance: fogCutoffDistance,
        fogMaxOpacity: fogMaxOpacity,
        inscatteringColor: Vector3Const(inscatteringColor.x, inscatteringColor.y, inscatteringColor.z),
        useSkyColor: useSkyColor,
        height: worldLocation.y,
      );

  LuminaHeightFogSettings? _published;
  LuminaPostProcessBlender? _blender;

  @override
  void onRegister(LuminaActor ownerActor) {
    super.onRegister(ownerActor);
    _publish();
  }

  @override
  void onTick(double deltaTime) {
    super.onTick(deltaTime);
    _publish();
  }

  @override
  void onRenderPrep(LuminaWorld world) {
    super.onRenderPrep(world);
    _publish();
  }

  /// Pushes [settings] to the world's blender when they changed.
  void _publish() {
    final w = world;
    if (w == null) return;
    final blender = w.postProcessBlender;
    final s = settings;
    if (identical(_blender, blender) && _published == s) return;
    if (blender.heightFogOwner != null && !identical(blender.heightFogOwner, this)) {
      debugPrint('[Lumina] A level has more than one Exponential Height Fog; Filament has one fog per view, the latest wins.');
    }
    blender.setHeightFog(s, owner: this);
    _blender = blender;
    _published = s;
  }

  @override
  void onUnregister() {
    _blender?.clearHeightFogOf(this);
    _blender = null;
    _published = null;
    super.onUnregister();
  }
}
