import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

import 'physics_fixture.dart';

/// Every collision shape simulates — cylinders, cones, capsules
/// and convex hulls land and rest by their shape (feature-clipped contacts on
/// the GJK/EPA narrow phase), and a static mesh with no collision falls as
/// its bounds box.
void main() {
  LuminaActor drop(PhysicsWorld w, LuminaCollisionComponent c) {
    c
      ..simulatePhysics = true
      ..overrideMass = true
      ..massKg = 8;
    final a = LuminaActor(root: c);
    w.world.persistentLevel.registerActor(a);
    return a;
  }

  test('a cylinder on its side, a cone on its base, a lying capsule and a convex hull all come to rest on the floor', () {
    final w = PhysicsWorld();
    addTearDown(w.dispose);
    final sideways = Quaternion.axisAngle(Vector3(0, 0, 1), math.pi / 2);
    final cylinder = LuminaCylinderComponent(location: Vector3(0, 60, 0), rotation: sideways, radius: 20, halfHeight: 40);
    final cone = LuminaConeComponent(location: Vector3(200, 80, 0), radius: 30, halfHeight: 30);
    final capsule = LuminaCapsuleComponent(location: Vector3(400, 60, 0), radius: 15, halfHeight: 50)..relativeRotation = sideways;
    final hull = LuminaConvexComponent(location: Vector3(600, 60, 0), points: [
      for (var i = 0; i < 12; i++) Vector3(30 * math.cos(i * math.pi / 3), i < 6 ? -20 : 20, 30 * math.sin(i * math.pi / 3)),
    ]);
    for (final c in [cylinder, cone, capsule, hull]) {
      drop(w, c);
    }
    w.begin();
    w.run(4);
    // Resting heights: the cylinder's radius, the cone's half height
    // (origin mid-height), the capsule's radius, the hexagonal prism's half height.
    expect(cylinder.worldLocation.y, closeTo(20, 1.0), reason: 'cylinder on its side');
    expect(cone.worldLocation.y, closeTo(30, 1.0), reason: 'cone on its base');
    expect(capsule.worldLocation.y, closeTo(15, 1.0), reason: 'capsule lying down');
    expect(hull.worldLocation.y, closeTo(20, 1.0), reason: 'hexagonal prism on a face');
    for (final c in [cylinder, cone, capsule, hull]) {
      final body = c.physicsBody!;
      expect(body.linearVelocity.length + body.angularVelocity.length * 30, lessThan(5), reason: '${c.runtimeType} at rest');
    }
  });

  test('a tilted cylinder standing on its rim falls onto its side', () {
    final w = PhysicsWorld();
    addTearDown(w.dispose);
    final tilted = Quaternion.axisAngle(Vector3(0, 0, 1), 0.5);
    final cylinder = LuminaCylinderComponent(location: Vector3(0, 60, 0), rotation: tilted, radius: 15, halfHeight: 50);
    drop(w, cylinder);
    w.begin();
    w.run(4);
    expect(tiltDegrees(cylinder.worldRotation), closeTo(90, 3), reason: 'lying on its side');
    expect(cylinder.worldLocation.y, closeTo(15, 1.0));
  });

  test('a static mesh with Simulate Physics and no collision falls as its bounds box', () {
    final w = PhysicsWorld();
    addTearDown(w.dispose);
    final mesh = LuminaStaticMeshComponent(meshAssetPath: 'no-native/mesh.glb', location: Vector3(0, 300, 0))
      ..simulatePhysics = true;
    final actor = LuminaActor(root: mesh);
    w.world.persistentLevel.registerActor(actor);
    w.begin();
    expect(mesh.physicsBody, isNotNull);
    final proxy = mesh.childComponents.whereType<LuminaBoxComponent>().single;
    expect(identical(proxy.physicsBody, mesh.physicsBody), isTrue, reason: 'the proxy box is the body\'s shape');
    w.run(2);
    // No mesh loaded (no native context): a 50 cm cube.
    expect(mesh.worldLocation.y, closeTo(25, 1.0));
  });
}
