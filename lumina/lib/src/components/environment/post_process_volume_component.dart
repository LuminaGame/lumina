import 'package:vector_math/vector_math_64.dart';

import '../../math/axes.dart';
import '../../object/actor.dart';
import '../../post_process/post_process_blender.dart';
import '../../world/world.dart';
import '../base/scene_component.dart';

/// The runtime form of a Post Process Volume: an
/// oriented box (or unbound volume) with a priority, a blend radius and a
/// blend weight, and a block of per-setting overrides. It registers a
/// [LuminaPostProcessVolume] with the world's [LuminaPostProcessBlender] and
/// keeps its transform and fields current every render prep; the blender
/// decides what the camera sees.
///
/// Filament applies one post-process state to the whole view, so the volume
/// blends by camera position — never per pixel.
class LuminaPostProcessVolumeComponent extends LuminaSceneComponent {
  LuminaPostProcessVolumeComponent({
    super.key,
    super.location,
    super.rotation,
    super.scale,
    Vector3? extent,
    this.unbound = false,
    this.enabled = true,
    this.priority = 0.0,
    this.blendRadius = 100.0,
    this.blendWeight = 1.0,
    this.overrides = const LuminaPostProcessOverrides(),
    bool visible = true,
  })  : extent = extent ?? Vector3.all(400.0),
        super(isVisible: visible);

  /// From the editor component's `properties`: `extentX/Y/Z` authored Z-up in
  /// cm (→ runtime axes), `unbound`, `enabled`, `priority`, `blendRadius`,
  /// `blendWeight`, and the override block ([LuminaPostProcessOverrides.fromProperties]).
  factory LuminaPostProcessVolumeComponent.fromProperties(
    Map<String, dynamic>? properties, {
    Vector3? location,
    Quaternion? rotation,
    Vector3? scale,
    bool visible = true,
  }) {
    final p = properties ?? const <String, dynamic>{};
    double num_(String k, double d) => p[k] is num ? (p[k] as num).toDouble() : d;
    bool bool_(String k, bool d) => p[k] is bool ? p[k] as bool : d;
    return LuminaPostProcessVolumeComponent(
      location: location,
      rotation: rotation,
      scale: scale,
      extent: LuminaAxes.scale([num_('extentX', 400.0), num_('extentY', 400.0), num_('extentZ', 400.0)]),
      unbound: bool_('unbound', false),
      enabled: bool_('enabled', true),
      priority: num_('priority', 0.0),
      blendRadius: num_('blendRadius', 100.0).clamp(0.0, 1e9),
      blendWeight: num_('blendWeight', 1.0).clamp(0.0, 1.0),
      overrides: LuminaPostProcessOverrides.fromProperties(p),
      visible: visible,
    );
  }

  /// Half size in cm, runtime axes, before the actor's scale.
  Vector3 extent;
  bool unbound;
  bool enabled;
  double priority;

  /// cm, outside the box.
  double blendRadius;

  /// 0..1.
  double blendWeight;
  LuminaPostProcessOverrides overrides;

  bool get visible => isVisible;
  set visible(bool v) => isVisible = v;

  /// The shape the blender evaluates (a live object the component updates).
  final LuminaPostProcessVolume volume = LuminaPostProcessVolume();
  LuminaPostProcessBlender? _blender;

  /// Whether [world] (runtime axes) is inside the box; unbound → true.
  bool containsPoint(Vector3 world) {
    _refresh();
    return volume.containsPoint(world);
  }

  void _refresh() {
    volume
      ..enabled = enabled && isVisible
      ..unbound = unbound
      ..priority = priority
      ..blendRadius = blendRadius
      ..blendWeight = blendWeight
      ..overrides = overrides
      ..worldTransform = worldTransform
      ..halfExtent = extent
      ..sphereRadius = null
      ..owner = this;
  }

  void _ensureRegistered() {
    final w = world;
    if (w == null) return;
    if (!identical(_blender, w.postProcessBlender)) {
      _blender?.removeVolume(volume);
      _blender = w.postProcessBlender;
      _blender!.addVolume(volume);
    }
    _refresh();
  }

  @override
  void onRegister(LuminaActor ownerActor) {
    super.onRegister(ownerActor);
    _ensureRegistered();
  }

  @override
  void onTick(double deltaTime) {
    super.onTick(deltaTime);
    _ensureRegistered();
  }

  @override
  void onRenderPrep(LuminaWorld world) {
    super.onRenderPrep(world);
    _ensureRegistered();
  }

  @override
  void onUnregister() {
    _blender?.removeVolume(volume);
    _blender = null;
    super.onUnregister();
  }
}
