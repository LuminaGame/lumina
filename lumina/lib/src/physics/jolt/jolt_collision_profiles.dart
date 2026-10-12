import 'package:flutter_jolt/flutter_jolt.dart';

import 'package:lumina/src/components/collision/collision_component.dart';

/// What decides whether a collision component blocks another: enabled,
/// object type, the response to each object type, layer and mask.
class _Profile {
  _Profile(this.enabled, this.objectType, this.responses, this.layer, this.mask);

  /// A body shape without a component: blocks what blocks `worldDynamic`.
  _Profile.none()
      : enabled = true,
        objectType = CollisionObjectType.worldDynamic,
        responses = [for (final _ in CollisionObjectType.values) CollisionResponse.block],
        layer = 0xFFFFFFFF,
        mask = 0xFFFFFFFF;

  final bool enabled;
  final CollisionObjectType objectType;
  final List<CollisionResponse> responses;
  final int layer;
  final int mask;

  String get key => '${enabled ? 1 : 0}:${objectType.index}:${responses.map((r) => r.index).join()}:$layer:$mask';

  bool blocks(_Profile other) {
    if (!enabled || !other.enabled) return false;
    if ((layer & other.mask) == 0 || (other.layer & mask) == 0) return false;
    final a = responses[other.objectType.index];
    final b = other.responses[objectType.index];
    return a == CollisionResponse.block && b == CollisionResponse.block;
  }
}

/// Lumina's collision settings as Jolt profiles: each distinct combination of
/// a component's `collisionEnabled`, object type, channel responses, layer
/// and mask gets a profile index, and the world's profile matrix says which
/// pairs block (both respond Block to the other's object type and the layer
/// masks let them interact). A body shape without a component uses profile
/// 0, which blocks whatever blocks `worldDynamic`.
class LuminaJoltCollisionProfiles {
  LuminaJoltCollisionProfiles(this.world) {
    _add(_Profile.none());
  }

  final JoltWorld world;
  final List<_Profile> _profiles = [];
  final Map<String, int> _index = {};
  bool _dirty = true;

  /// The number of profiles so far.
  int get length => _profiles.length;

  /// The profile index of [component] (0 for none), adding a profile when
  /// its settings are new.
  int profileOf(LuminaCollisionComponent? component) {
    if (component == null) return 0;
    final p = _Profile(
      component.collisionEnabled,
      component.objectType,
      [for (final t in CollisionObjectType.values) component.getResponse(t)],
      component.collisionLayer,
      component.collisionLayerMask,
    );
    return _index[p.key] ?? _add(p);
  }

  /// A profile that blocks nothing (a skinned cloth's limb colliders, which
  /// only cloth touches).
  late final int clothColliderProfile = _add(_Profile(false, CollisionObjectType.worldDynamic,
      [for (final _ in CollisionObjectType.values) CollisionResponse.ignore], 0, 0));

  /// Whether profiles [a] and [b] block each other.
  bool blocks(int a, int b) => _profiles[a].blocks(_profiles[b]);

  int _add(_Profile p) {
    final i = _profiles.length;
    _profiles.add(p);
    _index[p.key] = i;
    _dirty = true;
    return i;
  }

  /// Sends the matrix to Jolt when profiles were added since the last call.
  void flush() {
    if (!_dirty) return;
    _dirty = false;
    world.setProfileMatrix([
      for (var i = 0; i < _profiles.length; i++) [for (var j = 0; j < _profiles.length; j++) blocks(i, j)],
    ]);
  }
}
