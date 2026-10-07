import 'dart:typed_data';

import 'package:lumina/src/object/lumina_object_key.dart';
import 'package:vector_math/vector_math_64.dart';

import 'package:lumina/src/collision/collision_hull.dart';
import 'package:lumina/src/collision/collision_primitive.dart';
import 'package:lumina/src/components/collision/collision_component.dart';
import 'package:lumina/src/components/mesh/static_mesh_component.dart';
import 'package:lumina/src/object/actor.dart';

/// A placed static mesh and its simple collision.
///
/// The root [meshComponent] draws the mesh asset as a plain
/// [LuminaStaticMeshComponent] does. Every entry of [collisionHulls] becomes
/// one [LuminaCollisionComponent.convexHull] in [collisionComponents]:
/// `worldStatic`, blocking everything, at the mesh's origin. Scene components
/// do not inherit their parent's scale, so each hull component carries the
/// actor's scale itself, and [actorScale] keeps them in step.
///
/// Every entry of [collisionPrimitives] (authored boxes, spheres and
/// capsules) becomes one more collider next to them, sized for
/// the actor's scale.
///
/// A mesh with neither has no collision.
///
/// `materialOverrideAsset` is drawn on every section in place of the mesh's
/// own materials ([LuminaStaticMeshComponent.materialOverrideAsset]).
class LuminaStaticMeshActor extends LuminaActor {
  /// The drawn mesh (the root component).
  final LuminaStaticMeshComponent meshComponent;

  /// The authored hulls, in [collisionComponents] order.
  final List<LuminaCollisionHull> collisionHulls;

  /// The authored box / sphere / capsule shapes, in
  /// [primitiveComponents] order.
  final List<LuminaCollisionPrimitive> collisionPrimitives;

  /// One convex collision component per hull, then one per primitive.
  final List<LuminaCollisionComponent> collisionComponents = [];

  /// The components of [collisionPrimitives].
  final List<LuminaCollisionComponent> primitiveComponents = [];

  LuminaStaticMeshActor({
    LuminaObjectKey? key,
    Vector3? location,
    Quaternion? rotation,
    Vector3? scale,
    required String meshAssetPath,
    bool castShadows = true,
    bool visible = true,
    List<LuminaCollisionHull> collisionHulls = const [],
    List<LuminaCollisionPrimitive> collisionPrimitives = const [],
    Future<Uint8List> Function(String path)? assetProvider,
    String? materialOverrideAsset,
  }) : this._(
          key,
          LuminaStaticMeshComponent(
            location: location,
            rotation: rotation,
            scale: scale,
            meshAssetPath: meshAssetPath,
            castShadows: castShadows,
            visible: visible,
            assetProvider: assetProvider,
            materialOverrideAsset: materialOverrideAsset,
          ),
          collisionHulls,
          collisionPrimitives,
        );

  LuminaStaticMeshActor._(LuminaObjectKey? key, this.meshComponent, this.collisionHulls, this.collisionPrimitives)
      : super(key: key, root: meshComponent) {
    for (final hull in collisionHulls) {
      final points = hull.runtimePoints;
      if (points.isEmpty) continue;
      final collision = LuminaCollisionComponent.convexHull(points: points, scale: meshComponent.relativeScale.clone());
      // BlockAll, as a WorldStatic object (the static mesh default).
      CollisionProfile.applyBlockAll(collision);
      collision.objectType = CollisionObjectType.worldStatic;
      collisionComponents.add(collision);
      addComponent(collision);
    }
    for (final primitive in collisionPrimitives) {
      final collision = primitive.createComponent(meshComponent.relativeScale);
      CollisionProfile.applyBlockAll(collision);
      collision.objectType = CollisionObjectType.worldStatic;
      primitiveComponents.add(collision);
      collisionComponents.add(collision);
      addComponent(collision);
    }
  }

  @override
  set actorScale(Vector3 v) {
    super.actorScale = v;
    for (final c in collisionComponents) {
      if (c.shapeType == CollisionShapeType.convex) c.relativeScale = v;
    }
    for (var i = 0; i < primitiveComponents.length; i++) {
      collisionPrimitives[i].applyTo(primitiveComponents[i], v);
    }
  }
}
