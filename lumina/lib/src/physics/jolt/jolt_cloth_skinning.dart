import 'dart:typed_data';

import 'package:flutter_jolt/flutter_jolt.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:vector_math/vector_math_64.dart';

import 'package:lumina/src/physics/cloth/skinned_cloth_component.dart';
import 'package:lumina/src/physics/jolt/jolt_body_shapes.dart';
import 'package:lumina/src/physics/ragdoll/ragdoll_skeleton.dart';

// dart format off
/// A `LuminaPoseMath` affine (12 doubles: 3x3 column-major, translation) at
/// [o] as a column-major 4x4 matrix, scaled by [scale] (cm → m).
Matrix4 _matrix(Float64List a, int o, [double scale = 1]) => Matrix4(
      a[o] * scale, a[o + 1] * scale, a[o + 2] * scale, 0,
      a[o + 3] * scale, a[o + 4] * scale, a[o + 5] * scale, 0,
      a[o + 6] * scale, a[o + 7] * scale, a[o + 8] * scale, 0,
      a[o + 9] * scale, a[o + 10] * scale, a[o + 11] * scale, 1,
    );
// dart format on

/// The Jolt skin of [cloth] for a soft body built at [centre] (m, identity
/// rotation): each joint's bind pose is its rest pose (mesh space) placed by
/// the cloth's current world transform, then taken into the body's frame
/// and inverted; weights and max distances (cm → m) per vertex.
JoltClothSkin? clothSkinFor(LuminaSkinnedClothComponent cloth, Vector3 centre) {
  final skin = cloth.skin;
  if (skin == null) return null;
  // World (m) of mesh space (m): the cloth's transform with its cm → m.
  final meshToWorld = Matrix4.diagonal3Values(kJoltScale, kJoltScale, kJoltScale)
    ..multiply(cloth.worldTransform)
    ..scaleByDouble(kLuminaScale, kLuminaScale, kLuminaScale, 1);
  final toBody = Matrix4.translation(-centre)..multiply(meshToWorld);
  final count = skin.restAffines.length ~/ LuminaPoseMath.affineStride;
  return JoltClothSkin(
    inverseBinds: [
      for (var j = 0; j < count; j++)
        Matrix4.inverted(toBody * _matrix(skin.restAffines, j * LuminaPoseMath.affineStride)),
    ],
    joints: skin.joints,
    weights: skin.weights,
    maxDistances: Float32List.fromList([for (final d in skin.maxDistances) d * kJoltScale]),
    backstopDistances: skin.backstopDistances == null
        ? null
        : Float32List.fromList([for (final d in skin.backstopDistances!) d * kJoltScale]),
    backstopRadius: skin.backstopRadius * kJoltScale,
  );
}

/// The skeleton's world affines (cm, as the mesh poses them) as Jolt joint
/// matrices (m), 16 floats each.
Float32List clothJointMatrices(Float64List worldAffines) {
  final count = worldAffines.length ~/ LuminaPoseMath.affineStride;
  final out = Float32List(count * 16);
  for (var j = 0; j < count; j++) {
    final m = _matrix(worldAffines, j * LuminaPoseMath.affineStride, kJoltScale)..setEntry(3, 3, 1);
    // Rotation columns carry the mesh's unit scale (×100) times cm → m: 1.
    out.setRange(16 * j, 16 * j + 16, m.storage);
  }
  return out;
}

/// The character's limbs as kinematic Jolt bodies a skinned cloth collides
/// with: one per physics asset body generated from the skeleton, moved to
/// its bone every step. They belong to the cloth's owner and are marked as
/// its colliders; rigid bodies never collide with them.
class LuminaJoltClothColliders {
  LuminaJoltClothColliders._(this._world, this._bodies);

  final JoltWorld _world;
  final List<({int id, int slot, Vector3 offset, Quaternion rotation})> _bodies;

  /// Kinematic bodies for [asset]'s bodies on [skeleton], posed by
  /// [worldAffines] (cm).
  static LuminaJoltClothColliders create(
    JoltWorld world,
    LuminaPhysicsAssetData asset,
    LuminaRagdollSkeleton skeleton,
    Float64List worldAffines, {
    required int owner,
    required int profile,
  }) {
    final bodies = <({int id, int slot, Vector3 offset, Quaternion rotation})>[];
    for (final data in asset.bodies) {
      final slot = skeleton.slotNamed(data.bone);
      if (slot < 0) continue;
      final shape = switch (data.shape) {
        LuminaPhysicsBodyShape.sphere => JoltShape.sphere(data.radius * kJoltScale),
        LuminaPhysicsBodyShape.box => JoltShape.box(
          Vector3(data.halfExtents[0], data.halfExtents[1], data.halfExtents[2]) * kJoltScale,
          convexRadius: 0.005,
        ),
        LuminaPhysicsBodyShape.capsule => JoltShape.capsule(
          (data.effectiveHalfHeight - data.radius) * kJoltScale,
          data.radius * kJoltScale,
        ),
      };
      final (position, rotation) = _pose(worldAffines, slot, data.offsetVector, data.offsetQuaternion);
      final id = world.createBody(
        shape,
        JoltBodySettings(motionType: JoltMotionType.kinematic, position: position, rotation: rotation),
      );
      shape.release();
      world
        ..setBodyOwner(id, owner)
        ..setBodyProfiles(id, [profile])
        ..setBodyClothCollider(id, true);
      bodies.add((id: id, slot: slot, offset: data.offsetVector, rotation: data.offsetQuaternion));
    }
    return LuminaJoltClothColliders._(world, bodies);
  }

  static (Vector3, Quaternion) _pose(Float64List worldAffines, int slot, Vector3 offset, Quaternion offsetRotation) {
    final bone = LuminaRagdollSkeleton.frameOf(worldAffines, slot);
    final position = bone.position + (offset.clone()..applyQuaternion(bone.rotation));
    return (position * kJoltScale, (bone.rotation * offsetRotation)..normalize());
  }

  /// Moves every limb to its bone in [worldAffines] over [dt].
  void move(Float64List worldAffines, double dt) {
    for (final b in _bodies) {
      final (position, rotation) = _pose(worldAffines, b.slot, b.offset, b.rotation);
      _world.moveKinematic(b.id, position, rotation, dt);
    }
  }

  /// Puts every limb on its bone in [worldAffines] at once (a teleport).
  void place(Float64List worldAffines) {
    for (final b in _bodies) {
      final (position, rotation) = _pose(worldAffines, b.slot, b.offset, b.rotation);
      _world
        ..setBodyTransform(b.id, position, rotation)
        ..setBodyVelocity(b.id, Vector3.zero(), Vector3.zero());
    }
  }

  int get length => _bodies.length;

  void destroy() {
    for (final b in _bodies) {
      _world.destroyBody(b.id);
    }
    _bodies.clear();
  }
}
