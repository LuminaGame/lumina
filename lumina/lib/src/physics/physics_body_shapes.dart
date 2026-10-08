import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart';

import 'package:lumina/src/components/base/scene_component.dart';
import 'package:lumina/src/components/collision/collision_component.dart';
import 'package:lumina/src/components/mesh/static_mesh_component.dart';
import 'package:lumina/src/physics/mass_properties.dart';
import 'package:lumina/src/physics/rigid_body.dart';

/// The shapes and mass a primitive component simulates with: its collision
/// component's shape, or a static mesh's collision children (its bounds box
/// for the mass when it has none), and the mass rule of
/// [LuminaPrimitivePhysics].
abstract final class LuminaPhysicsBodyShapes {
  /// The mass properties [component] simulates with (see
  /// [LuminaPrimitivePhysics] for the mass rule).
  static LuminaMassProperties resolveMassProperties(LuminaPrimitivePhysics component, [List<LuminaBodyShape>? shapes]) {
    final pieces = shapes ?? shapesFor(component, forMass: true);
    final parts = [for (final s in pieces) (mass: s.massProperties, position: s.position, rotation: s.rotation)];
    var volume = 0.0;
    for (final p in parts) {
      volume += p.mass.volume;
    }
    final mesh = meshPhysicsOf(component);
    final double mass;
    if (component.overrideMass && component.massKg > 0) {
      mass = component.massKg;
    } else if (mesh?.massKg != null) {
      mass = mesh!.massKg!;
    } else {
      // g/cm³ × cm³ → kg.
      mass = math.max(component.effectivePhysicalMaterial.density * volume / 1000.0, 1e-3);
    }
    final offset = component.centerOfMassOffset ?? mesh?.runtimeCenterOfMassOffset;
    return LuminaMassProperties.combine(parts, mass: mass, centerOfMassOffset: offset);
  }

  /// The static mesh physics [component] inherits: its own, else the nearest
  /// static mesh component's in its actor (a parent, then a child, then any).
  static LuminaMeshPhysics? meshPhysicsOf(LuminaPrimitivePhysics component) {
    if (component.meshPhysics != null) return component.meshPhysics;
    for (var p = component.parentComponent; p != null; p = p.parentComponent) {
      if (p is LuminaStaticMeshComponent && p.meshPhysics != null) return p.meshPhysics;
    }
    LuminaMeshPhysics? fromChildren(LuminaSceneComponent c) {
      for (final child in c.childComponents) {
        if (child is LuminaStaticMeshComponent && child.meshPhysics != null) return child.meshPhysics;
        final deeper = fromChildren(child);
        if (deeper != null) return deeper;
      }
      return null;
    }

    final child = fromChildren(component);
    if (child != null) return child;
    final owner = component.owner;
    if (owner == null) return null;
    for (final c in owner.components) {
      if (c is LuminaStaticMeshComponent && c.meshPhysics != null) return c.meshPhysics;
    }
    return null;
  }

  static List<LuminaBodyShape> shapesFor(LuminaPrimitivePhysics component, {bool forMass = false}) {
    if (component is LuminaCollisionComponent) {
      final s = _shapeOf(component, Vector3.zero(), Quaternion.identity());
      return s == null ? const [] : [s];
    }
    if (component is! LuminaStaticMeshComponent) return const [];
    final mesh = component;
    final out = <LuminaBodyShape>[];
    final invRot = mesh.worldRotation.conjugated();
    final origin = mesh.worldLocation;
    void walk(LuminaSceneComponent c) {
      for (final child in c.childComponents) {
        if (child is LuminaCollisionComponent && !child.simulatePhysics) {
          final p = (child.worldLocation - origin)..applyQuaternion(invRot);
          final q = invRot * child.worldRotation;
          final s = _shapeOf(child, p, q);
          if (s != null) out.add(s);
        }
        if (child is! LuminaStaticMeshComponent) walk(child);
      }
    }

    walk(mesh);
    if (out.isEmpty && forMass) {
      final (center, extent) = meshBox(mesh);
      out.add(LuminaBodyShape(BoxShape(extent), position: center));
    }
    return out;
  }

  static LuminaBodyShape? _shapeOf(LuminaCollisionComponent c, Vector3 position, Quaternion rotation) {
    final s = c.relativeScale;
    final abs = Vector3(s.x.abs(), s.y.abs(), s.z.abs());
    final CollisionShape shape;
    var scale = Vector3(1, 1, 1);
    switch (c.shapeType) {
      case CollisionShapeType.sphere:
        shape = SphereShape(c.radius);
      case CollisionShapeType.box:
        shape = BoxShape(c.boxExtent.clone()..multiply(abs));
      case CollisionShapeType.capsule:
        shape = CapsuleShape(c.radius, c.halfHeight);
      case CollisionShapeType.cylinder:
        shape = CylinderShape(c.radius, c.height);
      case CollisionShapeType.cone:
        shape = ConeShape(c.radius, c.height);
      case CollisionShapeType.convex:
        shape = c.convexHull!;
        scale = s.clone();
      case CollisionShapeType.heightfield:
        return null;
    }
    return LuminaBodyShape(shape, position: position, rotation: rotation, scale: scale, component: c);
  }

  /// The mesh's bounds box in its own frame (cm, its scale applied); a 50 cm
  /// cube until the mesh has loaded.
  static (Vector3, Vector3) meshBox(LuminaStaticMeshComponent mesh) {
    final b = mesh.localBounds;
    final s = mesh.relativeScale;
    final abs = Vector3(s.x.abs(), s.y.abs(), s.z.abs());
    if (b == null) return (Vector3.zero(), Vector3.all(25.0));
    final center = ((b.min + b.max)..scale(0.5))..multiply(s);
    final extent = ((b.max - b.min)..scale(0.5))..multiply(abs);
    return (center, Vector3(math.max(extent.x, 0.5), math.max(extent.y, 0.5), math.max(extent.z, 0.5)));
  }
}
