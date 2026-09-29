import 'dart:math' as math;
import 'package:flutter/foundation.dart' show Key;
import 'package:vector_math/vector_math_64.dart';
import '../../collision/collision_filter.dart';
import '../../collision/collision_preset.dart';
import '../../collision/collision_query.dart';
import '../../collision/shapes.dart';
import '../base/scene_component.dart';
import '../../math/euler.dart';
import '../../physics/primitive_physics.dart';

export '../../collision/collision_filter.dart';
export '../../collision/collision_preset.dart';
export '../../collision/collision_query.dart';
export '../../collision/shapes.dart';
export '../../physics/primitive_physics.dart';

/// [convex] is a [ConvexHullShape]: imported `UCX_` hulls.
/// [heightfield] is a [HeightfieldShape]: a landscape's heightmap.
enum CollisionShapeType { sphere, box, capsule, cone, cylinder, convex, heightfield }

/// Component handling collision geometry, layer bitmasking, and early-exit AABB/OBB filtering.
///
/// Its Physics section ([LuminaPrimitivePhysics]) makes it a
/// rigid body with Simulate Physics on.
class LuminaCollisionComponent extends LuminaSceneComponent with LuminaPrimitivePhysics {
  static int _nextId = 1;
  final int componentId = _nextId++;

  final CollisionShapeType shapeType;
  bool collisionEnabled = true;

  /// Whether this component takes part in overlap events (Generate
  /// Overlap Events): the subsystem raises begin / end
  /// overlap for a pair only when both have it. Blocking is unaffected.
  bool generateOverlapEvents = true;

  int collisionLayer = 1 << 0; // Layer 1
  int collisionLayerMask = 0xFFFFFFFF; // Interacts with all layers by default
  CollisionObjectType objectType = CollisionObjectType.worldDynamic;

  final Map<CollisionObjectType, CollisionResponse> _responses = {
    CollisionObjectType.worldStatic: CollisionResponse.block,
    CollisionObjectType.worldDynamic: CollisionResponse.block,
    CollisionObjectType.pawn: CollisionResponse.block,
  };

  // Primitive dimensions, in world units (cm).
  double radius = 50.0;
  Vector3 boxExtent = Vector3(50.0, 50.0, 50.0);
  double halfHeight = 80.0;
  double height = 160.0;

  Aabb3? _cachedAabb;
  Obb3? _cachedObb;

  // Overlap & Hit delegates
  void Function(LuminaCollisionComponent self, LuminaCollisionComponent other)? onComponentBeginOverlap;
  void Function(LuminaCollisionComponent self, LuminaCollisionComponent other)? onComponentEndOverlap;
  void Function(LuminaCollisionComponent self, LuminaCollisionComponent other, HitResult hit)? onComponentHit;

  final Set<LuminaCollisionComponent> _overlapping = <LuminaCollisionComponent>{};

  /// Current snapshot of overlapping collision components.
  List<LuminaCollisionComponent> get overlappingComponents => List.unmodifiable(_overlapping);

  void addOverlappingComponent(LuminaCollisionComponent other) {
    _overlapping.add(other);
  }

  void removeOverlappingComponent(LuminaCollisionComponent other) {
    _overlapping.remove(other);
  }

  /// The hull of a [CollisionShapeType.convex] component, in its local frame
  /// (world units); null for the other shapes.
  final ConvexHullShape? convexHull;

  /// The heightmap of a [CollisionShapeType.heightfield] component, in its
  /// local frame; null for the other shapes.
  final HeightfieldShape? heightfield;

  /// [scale] only shapes a [CollisionShapeType.box] or
  /// [CollisionShapeType.convex] component; a [CollisionShapeType.convex] one
  /// needs [convexPoints] (see [LuminaCollisionComponent.convexHull]).
  LuminaCollisionComponent({
    super.key,
    super.location,
    super.rotation,
    super.scale,
    required this.shapeType,
    this.radius = 50.0,
    this.halfHeight = 80.0,
    List<Vector3>? convexPoints,
    this.heightfield,
  }) : convexHull = convexPoints == null ? null : ConvexHullShape(convexPoints) {
    if (shapeType == CollisionShapeType.convex && convexHull == null) {
      throw ArgumentError('a convex collision component needs convexPoints');
    }
    if (shapeType == CollisionShapeType.heightfield && heightfield == null) {
      throw ArgumentError('a heightfield collision component needs a heightfield shape');
    }
  }

  /// A landscape's collider: [shape]'s heightmap, transformed by
  /// this component's world transform including its own [scale].
  LuminaCollisionComponent.heightfield({
    Key? key,
    Vector3? location,
    Quaternion? rotation,
    Vector3? scale,
    required HeightfieldShape shape,
  }) : this(
          key: key,
          location: location,
          rotation: rotation,
          scale: scale,
          shapeType: CollisionShapeType.heightfield,
          heightfield: shape,
        );

  /// A convex collision component: the hull of [points] (local frame, world
  /// units), transformed by this component's world transform including its
  /// own [scale].
  LuminaCollisionComponent.convexHull({
    Key? key,
    Vector3? location,
    Quaternion? rotation,
    Vector3? scale,
    required List<Vector3> points,
  }) : this(
          key: key,
          location: location,
          rotation: rotation,
          scale: scale,
          shapeType: CollisionShapeType.convex,
          convexPoints: points,
        );

  /// The oriented axis vector (along +Y local).
  Vector3 get axis => upVector;

  /// The top apex point in world space for a cone.
  Vector3 get apex => worldLocation + (axis * (height * 0.5));

  /// Decoupled value-type collision shape descriptor.
  CollisionShape get worldShape {
    switch (shapeType) {
      case CollisionShapeType.sphere:
        return SphereShape(radius);
      case CollisionShapeType.box:
        return BoxShape(boxExtent);
      case CollisionShapeType.capsule:
        return CapsuleShape(radius, halfHeight);
      case CollisionShapeType.cone:
        return ConeShape(radius, height);
      case CollisionShapeType.cylinder:
        return CylinderShape(radius, height);
      case CollisionShapeType.convex:
        return convexHull!;
      case CollisionShapeType.heightfield:
        return heightfield!;
    }
  }

  /// Sets the 1-based [layerIndex] for this object.
  void setLayer(int layerIndex) {
    collisionLayer = CollisionLayers.layer(layerIndex);
  }

  /// Adds a target 1-based [layerIndex] to the interaction mask.
  void addTargetLayer(int layerIndex) {
    collisionLayerMask = (collisionLayerMask | CollisionLayers.layer(layerIndex)) & 0xFFFFFFFF;
  }

  /// Removes a target 1-based [layerIndex] from the interaction mask.
  void removeTargetLayer(int layerIndex) {
    collisionLayerMask = (collisionLayerMask & ~CollisionLayers.layer(layerIndex)) & 0xFFFFFFFF;
  }

  /// Returns the configured response towards the specified [channel].
  CollisionResponse getResponse(CollisionObjectType channel) {
    return _responses[channel] ?? CollisionResponse.block;
  }

  /// Sets the response towards the specified [channel].
  void setResponse(CollisionObjectType channel, CollisionResponse r) {
    _responses[channel] = r;
  }

  /// Sets the response towards all channels.
  void setResponseToAll(CollisionResponse r) {
    for (final t in CollisionObjectType.values) {
      _responses[t] = r;
    }
  }

  /// Convenience getter/setter for global response compatibility.
  CollisionResponse get response => getResponse(CollisionObjectType.worldDynamic);
  set response(CollisionResponse r) => setResponseToAll(r);

  /// The per-channel responses, by channel.
  Map<CollisionObjectType, CollisionResponse> get responses => Map.unmodifiable(_responses);

  // --- Presets -------------------------------------------------

  /// This component's whole collision setup as a value; setting it applies
  /// object type, the response grid, overlap events and enabled.
  LuminaCollisionProfile get profile => LuminaCollisionProfile(
        objectType: objectType,
        responses: _responses,
        generateOverlapEvents: generateOverlapEvents,
        collisionEnabled: collisionEnabled,
      );

  set profile(LuminaCollisionProfile p) {
    objectType = p.objectType;
    for (final t in CollisionObjectType.values) {
      _responses[t] = p.responses[t] ?? CollisionResponse.block;
    }
    generateOverlapEvents = p.generateOverlapEvents;
    collisionEnabled = p.collisionEnabled;
  }

  /// Applies the preset table for [preset] (see [LuminaCollisionPreset]);
  /// [LuminaCollisionPreset.custom] leaves the grid as it is.
  void applyPreset(LuminaCollisionPreset preset) {
    if (preset == LuminaCollisionPreset.custom) return;
    profile = LuminaCollisionProfile.forPreset(preset, generateOverlapEvents: generateOverlapEvents);
  }

  /// The preset the grid matches, else [LuminaCollisionPreset.custom].
  LuminaCollisionPreset get preset => profile.preset;

  /// The collision JSON the editor and Blueprint components store:
  /// `{'preset', 'objectType', 'responses', 'generateOverlapEvents', 'collisionEnabled'}`.
  Map<String, dynamic> toCollisionJson() => profile.toJson();

  /// Applies [toCollisionJson]'s shape; keys the map lacks keep their values.
  void applyCollisionJson(Map<String, dynamic> json) {
    profile = LuminaCollisionProfile.fromJson(json, base: profile);
  }

  /// This shape's wireframe as line segments (pairs of world-space points) for
  /// the editor's and the debug draw's closed loops; the base class draws its
  /// OBB.
  List<Vector3> buildWireframe({int segments = 16}) {
    final obb = getOBB();
    final c = obb.center;
    final e = obb.halfExtents;
    final ax = [obb.axis0 * e.x, obb.axis1 * e.y, obb.axis2 * e.z];
    Vector3 corner(int i) => c + ax[0] * (i & 1 == 0 ? -1.0 : 1.0) + ax[1] * (i & 2 == 0 ? -1.0 : 1.0) + ax[2] * (i & 4 == 0 ? -1.0 : 1.0);
    final pts = <Vector3>[];
    for (var i = 0; i < 8; i++) {
      for (final bit in [1, 2, 4]) {
        if (i & bit == 0) {
          pts.add(corner(i));
          pts.add(corner(i | bit));
        }
      }
    }
    return pts;
  }

  /// Marks cached AABB and OBB bounding structures as dirty.
  void markCollisionDirty() {
    _cachedAabb = null;
    _cachedObb = null;
  }

  @override
  void onTransformChanged() {
    markCollisionDirty();
    super.onTransformChanged();
  }

  /// Evaluates whether this collision component interacts with another based on layer bitmasks.
  bool canInteractWith(LuminaCollisionComponent other) {
    if (!collisionEnabled || !other.collisionEnabled) {
      return false;
    }
    return (collisionLayer & other.collisionLayerMask) != 0 &&
           (other.collisionLayer & collisionLayerMask) != 0;
  }

  /// Calculates Axis-Aligned Bounding Box (AABB) for broad-phase filtering.
  Aabb3 getAABB() {
    if (_cachedAabb != null) {
      return _cachedAabb!;
    }

    final pos = worldLocation;
    Vector3 min;
    Vector3 max;

    switch (shapeType) {
      case CollisionShapeType.sphere:
        final r = Vector3.all(radius);
        min = pos - r;
        max = pos + r;
        break;

      case CollisionShapeType.box:
        final rotMat = worldRotation.asRotationMatrix();
        final ex = (rotMat.entry(0, 0).abs() * boxExtent.x) +
                   (rotMat.entry(0, 1).abs() * boxExtent.y) +
                   (rotMat.entry(0, 2).abs() * boxExtent.z);
        final ey = (rotMat.entry(1, 0).abs() * boxExtent.x) +
                   (rotMat.entry(1, 1).abs() * boxExtent.y) +
                   (rotMat.entry(1, 2).abs() * boxExtent.z);
        final ez = (rotMat.entry(2, 0).abs() * boxExtent.x) +
                   (rotMat.entry(2, 1).abs() * boxExtent.y) +
                   (rotMat.entry(2, 2).abs() * boxExtent.z);
        final ext = Vector3(ex, ey, ez);
        min = pos - ext;
        max = pos + ext;
        break;

      case CollisionShapeType.capsule:
        final u = upVector;
        final effHalf = (halfHeight >= radius) ? halfHeight - radius : 0.0;
        final p1 = pos - (u * effHalf);
        final p2 = pos + (u * effHalf);
        final minX = math.min(p1.x, p2.x) - radius;
        final maxX = math.max(p1.x, p2.x) + radius;
        final minY = math.min(p1.y, p2.y) - radius;
        final maxY = math.max(p1.y, p2.y) + radius;
        final minZ = math.min(p1.z, p2.z) - radius;
        final maxZ = math.max(p1.z, p2.z) + radius;
        min = Vector3(minX, minY, minZ);
        max = Vector3(maxX, maxY, maxZ);
        break;

      case CollisionShapeType.cylinder:
        final u = upVector;
        final hHalf = height * 0.5;
        final ex = (u.x.abs() * hHalf) + radius * math.sqrt(math.max(0.0, 1.0 - u.x * u.x));
        final ey = (u.y.abs() * hHalf) + radius * math.sqrt(math.max(0.0, 1.0 - u.y * u.y));
        final ez = (u.z.abs() * hHalf) + radius * math.sqrt(math.max(0.0, 1.0 - u.z * u.z));
        final ext = Vector3(ex, ey, ez);
        min = pos - ext;
        max = pos + ext;
        break;

      case CollisionShapeType.cone:
        final u = upVector;
        final pBase = pos - (u * (height * 0.5));
        final pApex = pos + (u * (height * 0.5));
        final rx = radius * math.sqrt(math.max(0.0, 1.0 - u.x * u.x));
        final ry = radius * math.sqrt(math.max(0.0, 1.0 - u.y * u.y));
        final rz = radius * math.sqrt(math.max(0.0, 1.0 - u.z * u.z));
        final minX = math.min(pBase.x - rx, pApex.x);
        final maxX = math.max(pBase.x + rx, pApex.x);
        final minY = math.min(pBase.y - ry, pApex.y);
        final maxY = math.max(pBase.y + ry, pApex.y);
        final minZ = math.min(pBase.z - rz, pApex.z);
        final maxZ = math.max(pBase.z + rz, pApex.z);
        min = Vector3(minX, minY, minZ);
        max = Vector3(maxX, maxY, maxZ);
        break;

      case CollisionShapeType.convex:
        final t = worldTransform;
        min = Vector3.all(double.infinity);
        max = Vector3.all(-double.infinity);
        for (final v in convexHull!.vertices) {
          final w = t.transform3(v.clone());
          Vector3.min(min, w, min);
          Vector3.max(max, w, max);
        }
        break;

      case CollisionShapeType.heightfield:
        // The terrain's footprint × its whole height range, so a sculpt
        // never leaves the box.
        final t = worldTransform;
        final b = heightfield!.localBounds;
        min = Vector3.all(double.infinity);
        max = Vector3.all(-double.infinity);
        for (var i = 0; i < 8; i++) {
          final w = t.transform3(Vector3(
            i & 1 == 0 ? b.min.x : b.max.x,
            i & 2 == 0 ? b.min.y : b.max.y,
            i & 4 == 0 ? b.min.z : b.max.z,
          ));
          Vector3.min(min, w, min);
          Vector3.max(max, w, max);
        }
        break;
    }

    return _cachedAabb = Aabb3.minMax(min, max);
  }

  /// Calculates Oriented Bounding Box (OBB) reflecting component transform.
  Obb3 getOBB() {
    if (_cachedObb != null) {
      return _cachedObb!;
    }

    Vector3 halfExt;
    switch (shapeType) {
      case CollisionShapeType.sphere:
        halfExt = Vector3(radius, radius, radius);
        break;
      case CollisionShapeType.box:
        halfExt = boxExtent.clone();
        break;
      case CollisionShapeType.capsule:
        halfExt = Vector3(radius, halfHeight, radius);
        break;
      case CollisionShapeType.cone:
      case CollisionShapeType.cylinder:
        halfExt = Vector3(radius, height * 0.5, radius);
        break;
      case CollisionShapeType.heightfield:
        final b = heightfield!.localBounds;
        final obb = Obb3();
        obb.center.setFrom(worldTransform.transform3((b.min + b.max)..scale(0.5)));
        obb.halfExtents
          ..setFrom((b.max - b.min)..scale(0.5))
          ..multiply(Vector3(relativeScale.x.abs(), relativeScale.y.abs(), relativeScale.z.abs()));
        obb.axis0.setFrom(rightVector);
        obb.axis1.setFrom(upVector);
        obb.axis2.setFrom(worldRotation.rotateVector(Vector3(0, 0, 1)));
        return _cachedObb = obb;
      case CollisionShapeType.convex:
        final hull = convexHull!;
        final obb = Obb3();
        obb.center.setFrom(worldTransform.transform3(hull.localCenter));
        obb.halfExtents
          ..setFrom((hull.localMax - hull.localMin)..scale(0.5))
          ..multiply(Vector3(relativeScale.x.abs(), relativeScale.y.abs(), relativeScale.z.abs()));
        obb.axis0.setFrom(rightVector);
        obb.axis1.setFrom(upVector);
        obb.axis2.setFrom(worldRotation.rotateVector(Vector3(0, 0, 1)));
        return _cachedObb = obb;
    }

    final obb = Obb3();
    obb.center.setFrom(worldLocation);
    obb.halfExtents.setFrom(halfExt);
    obb.axis0.setFrom(rightVector);
    obb.axis1.setFrom(upVector);
    obb.axis2.setFrom(worldRotation.rotateVector(Vector3(0, 0, 1)));

    return _cachedObb = obb;
  }
}
