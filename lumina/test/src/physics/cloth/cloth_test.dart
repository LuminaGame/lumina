import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_jolt/flutter_jolt.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina/src/physics/jolt/jolt_physics_backend.dart';
import 'package:lumina/testing.dart';
import 'package:vector_math/vector_math_64.dart';

import '../physics_fixture.dart';

/// Cloth: a grid hangs from its pins without stretching, follows a moving
/// parent, drapes over a box and a character's capsule, blows in the wind;
/// a real towel from test-assets hangs from its top; the Dart backend draws
/// the rest pose without crashing.
void main() {
  tearDown(() => LuminaPhysicsSubsystem.defaultBackend = LuminaPhysicsBackendKind.auto);

  Vector3 at(Float32List p, int i) => Vector3(p[3 * i], p[3 * i + 1], p[3 * i + 2]);

  /// Worst relative stretch of [cloth]'s edges against its rest pose.
  double worstStretch(LuminaClothComponent cloth) {
    final g = cloth.geometry!;
    final p = cloth.currentSimPositions();
    var worst = 0.0;
    final t = g.simTriangles;
    for (var i = 0; i + 2 < t.length; i += 3) {
      for (final (a, b) in [(t[i], t[i + 1]), (t[i + 1], t[i + 2]), (t[i + 2], t[i])]) {
        final rest = g.simVertex(a).distanceTo(g.simVertex(b));
        if (rest < 1e-6) continue;
        worst = math.max(worst, at(p, a).distanceTo(at(p, b)) / rest - 1);
      }
    }
    return worst;
  }

  Future<(PhysicsWorld, LuminaClothComponent)> hang(LuminaClothComponent cloth, {Vector3? at}) async {
    final w = PhysicsWorld();
    cloth.relativeLocation = at ?? Vector3(0, 300, 0);
    w.world.persistentLevel.registerActor(LuminaActor(root: cloth));
    w.begin();
    await cloth.ready;
    return (w, cloth);
  }

  group('geometry', () {
    test('a 4 x 3 grid has 20 vertices, 24 triangles, its top edge pins 5 vertices at y = 0', () {
      final g = LuminaClothGeometry.grid(width: 100, height: 60, columns: 4, rows: 3);
      expect(g.simVertexCount, 20);
      expect(g.simTriangles.length, 24 * 3);
      final top = g.pinnedBy(LuminaClothPinning.topEdge);
      expect(top, hasLength(5));
      for (final i in top) {
        expect(g.simVertex(i).y, 0);
      }
      expect(g.pinnedBy(LuminaClothPinning.topCorners), hasLength(2));
      expect(g.pinnedBy(LuminaClothPinning.leftEdge), hasLength(4));
      expect(g.bounds.min.y, -60);
    });

    test('vertices split at a seam are welded for the simulation and mapped back', () {
      // Two triangles of a quad whose shared edge is duplicated (a UV seam).
      final pos = Float32List.fromList([0, 0, 0, 10, 0, 0, 0, 10, 0, 10, 0, 0, 10, 10, 0, 0, 10, 0]);
      final g = LuminaClothGeometry.weld(pos, Float32List(12), Uint32List.fromList([0, 1, 2, 3, 4, 5]));
      expect(g.renderVertexCount, 6);
      expect(g.simVertexCount, 4);
      expect(g.renderToSim[3], g.renderToSim[1]);
      expect(g.renderToSim[5], g.renderToSim[2]);
      expect(at(g.renderNormals, 0).z, closeTo(1, 1e-9));
    });

    test('properties round-trip, wind in authoring axes', () {
      final cloth = LuminaClothComponent(
        pinning: LuminaClothPinning.leftEdge,
        pinnedVertices: [3, 7],
        massKg: 2,
        stiffness: 0.8,
        wind: LuminaAxes.location([500, 0, 0]),
        color: Vector3(0.1, 0.2, 0.3),
      );
      final p = cloth.toProperties();
      expect(p['wind'], [500.0, 0.0, 0.0]);
      final back = LuminaClothComponent.fromProperties(p);
      expect(back.pinning, LuminaClothPinning.leftEdge);
      expect(back.pinnedVertices, [3, 7]);
      expect(back.massKg, 2);
      expect(back.stiffness, 0.8);
      expect(back.wind.x, closeTo(500, 1e-9));
      expect(back.color.z, closeTo(0.3, 1e-9));
      expect(LuminaClothComponent.fromProperties(const {}).pinning, LuminaClothPinning.topEdge);
    });
  });

  group('on Jolt', () {
    setUp(() => LuminaPhysicsSubsystem.defaultBackend = LuminaPhysicsBackendKind.jolt);

    test('a 2 x 1.5 m flag pinned on its top edge hangs: pins stay, the bottom hangs, edges stretch under 5 %', () async {
      final (w, cloth) = await hang(LuminaClothComponent(gridWidth: 200, gridHeight: 150, gridColumns: 16, gridRows: 12));
      addTearDown(w.dispose);
      expect(w.physics.backendKind, LuminaPhysicsBackendKind.jolt);
      expect(cloth.isSimulating, isTrue);
      // Lift it level so it falls into its hanging pose.
      w.run(3);
      final p = cloth.currentSimPositions();
      expect(p.every((v) => v.isFinite), isTrue);
      final g = cloth.geometry!;
      for (final i in cloth.resolvePinnedVertices()) {
        expect(at(p, i).distanceTo(g.simVertex(i)), lessThan(0.5), reason: 'pin $i stays');
      }
      final bottom = at(p, g.simVertexCount - 1);
      expect(bottom.y, lessThan(-140));
      expect(worstStretch(cloth), lessThan(0.05));
    });

    test('pins follow a moving parent: the actor moves 2 m and the whole cloth follows', () async {
      final (w, cloth) = await hang(LuminaClothComponent(gridWidth: 100, gridHeight: 100, gridColumns: 8, gridRows: 8));
      addTearDown(w.dispose);
      w.run(1);
      final actor = cloth.owner!;
      for (var i = 1; i <= 60; i++) {
        actor.rootComponent.relativeLocation = Vector3(200.0 * i / 60, 300, 0);
        w.run(1 / 60);
      }
      w.run(2);
      final p = cloth.currentSimPositions();
      // Local frame: the cloth hangs below the moved origin again.
      final g = cloth.geometry!;
      final bottom = at(p, g.simVertexCount - 1);
      expect(bottom.x.abs() - 50, lessThan(10), reason: 'swung back under its pins');
      expect(bottom.y, lessThan(-90));
    });

    test('a sheet dropped on a box drapes over it and a cloth over a character capsule stays outside it', () async {
      final w = PhysicsWorld();
      addTearDown(w.dispose);
      final box = LuminaBoxComponent(location: Vector3(0, 40, 0), boxExtent: Vector3.all(40))
        ..objectType = CollisionObjectType.worldStatic;
      w.world.persistentLevel.registerActor(LuminaActor(root: box));
      final capsule = LuminaCapsuleComponent(location: Vector3(400, 90, 0), radius: 35, halfHeight: 90)
        ..objectType = CollisionObjectType.pawn;
      w.world.persistentLevel.registerActor(LuminaActor(root: capsule));
      // Two sheets lying flat (rotated to face up), no pins.
      LuminaClothComponent sheet(Vector3 at) => LuminaClothComponent(
            location: at,
            rotation: Quaternion.axisAngle(Vector3(1, 0, 0), -math.pi / 2),
            gridWidth: 160,
            gridHeight: 160,
            gridColumns: 16,
            gridRows: 16,
            pinning: LuminaClothPinning.none,
            thickness: 1.5,
          );
      final overBox = sheet(Vector3(0, 120, -80));
      final overCapsule = sheet(Vector3(400, 220, -80));
      w.world.persistentLevel.registerActor(LuminaActor(root: overBox));
      w.world.persistentLevel.registerActor(LuminaActor(root: overCapsule));
      w.begin();
      await overBox.ready;
      await overCapsule.ready;
      w.run(4);
      List<Vector3> world(LuminaClothComponent c) {
        final p = c.currentSimPositions();
        return [for (var i = 0; i < p.length ~/ 3; i++) c.worldTransform.transform3(at(p, i))];
      }

      final draped = world(overBox);
      var inside = 0.0;
      for (final v in draped) {
        final d = math.min(40 - v.x.abs(), math.min(80 - v.y, 40 - v.z.abs()));
        if (v.y > 0) inside = math.max(inside, d);
      }
      expect(inside, lessThan(2.0), reason: 'no vertex deep inside the box');
      final onTop = [for (final v in draped) if (v.x.abs() < 30 && v.z.abs() < 30) v.y];
      expect(onTop, isNotEmpty);
      expect(onTop.reduce((a, b) => a + b) / onTop.length, closeTo(81.5, 3), reason: 'the middle lies on the box top');
      expect(draped.map((v) => v.y).reduce(math.min), lessThan(60), reason: 'the edges hang down its sides');
      // Outside the capsule's segment by its radius.
      var deepest = 0.0;
      for (final v in world(overCapsule)) {
        final y = v.y.clamp(35.0, 145.0);
        final d = 35 - (v - Vector3(400, y, 0)).length;
        deepest = math.max(deepest, d);
      }
      expect(deepest, lessThan(2.0), reason: 'the cloth rests on the capsule');
    });

    test('wind of 6 m/s along +Z lifts a hanging flag toward +Z; switching simulation off draws the rest pose', () async {
      final (w, cloth) = await hang(LuminaClothComponent(gridWidth: 120, gridHeight: 80, gridColumns: 12, gridRows: 8));
      addTearDown(w.dispose);
      w.run(2);
      double meanZ() {
        final p = cloth.currentSimPositions();
        var z = 0.0;
        for (var i = 0; i < p.length ~/ 3; i++) {
          z += p[3 * i + 2];
        }
        return z / (p.length ~/ 3);
      }

      final calm = meanZ();
      cloth.wind = Vector3(0, 0, 600);
      cloth.windDrag = 2;
      w.run(3);
      expect(meanZ() - calm, greaterThan(15), reason: 'blown downwind');
      final version = cloth.settingsVersion;
      cloth.stiffness = 0.9;
      expect(cloth.settingsVersion, version + 1);
      cloth.simulate = false;
      expect(cloth.isSimulating, isFalse);
      expect(cloth.currentSimPositions(), cloth.geometry!.simPositions);
      cloth.simulate = true;
      expect(cloth.isSimulating, isTrue);
    });

    test('the towel from test-assets hangs from its top: it settles below its pins and does not stretch', () async {
      final towel = File('${SmokeArtifacts.testAssetsDir.path}/Props/Clothes Line/towel.glb');
      if (!towel.existsSync()) return markTestSkipped('test-assets missing Props/Clothes Line/towel.glb');
      final (w, cloth) = await hang(LuminaClothComponent(meshAsset: towel.path, thickness: 0.5));
      addTearDown(w.dispose);
      final g = cloth.geometry!;
      expect(g.simVertexCount, lessThan(g.renderVertexCount), reason: 'welded at its UV seams');
      expect(cloth.resolvePinnedVertices(), isNotEmpty);
      cloth.wind = Vector3(300, 0, 0);
      w.run(3);
      final p = cloth.currentSimPositions();
      expect(p.every((v) => v.isFinite), isTrue);
      expect(worstStretch(cloth), lessThan(0.15));
      final backend = w.physics.backend as LuminaJoltPhysicsBackend;
      expect(backend.joltWorld.clothVertexCount(backend.clothBodyOf(cloth)!), g.simVertexCount);
    });
  });

  group('on Dart', () {
    setUp(() => LuminaPhysicsSubsystem.defaultBackend = LuminaPhysicsBackendKind.dart);

    test('cloth is not simulated: it draws its rest pose, logs once, and nothing crashes', () async {
      final before = EngineLoggerService().logs.length;
      final (w, cloth) = await hang(LuminaClothComponent(gridColumns: 4, gridRows: 4));
      addTearDown(w.dispose);
      w.run(1);
      expect(w.physics.backend.cloth, isNull);
      expect(cloth.isSimulating, isFalse);
      expect(cloth.currentSimPositions(), cloth.geometry!.simPositions);
      cloth.reset();
      cloth.wind = Vector3(100, 0, 0);
      w.run(0.5);
      final warnings = EngineLoggerService().logs.skip(before).where((e) => e.message.contains('Cloth needs the Jolt'));
      expect(warnings, hasLength(1));
    });
  });
}
