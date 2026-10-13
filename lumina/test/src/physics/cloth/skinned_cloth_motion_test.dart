import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

import '../ragdoll/ragdoll_fixture.dart';
import 'skinned_fixture.dart';

/// A garment under sudden motion: a teleport or a half turn within one
/// frame puts it back on the body without over-stretching, the inertia
/// scale sets how much it lags when the character moves, the hands of a
/// walking character stay outside the skirt, and a 3000-vertex garment
/// steps within budget.
void main() {
  setUp(() => LuminaPhysicsSubsystem.defaultBackend = LuminaPhysicsBackendKind.jolt);
  tearDown(() => LuminaPhysicsSubsystem.defaultBackend = LuminaPhysicsBackendKind.auto);

  /// How far (cm) the hem ring's centre trails where the skin puts it along x.
  double hemLag(Dressed d) {
    final now = d.worldVertices(), rest = d.restVertices();
    final n = now.length;
    var lag = 0.0;
    for (var i = n - 32; i < n; i++) {
      lag += rest[i].x - now[i].x;
    }
    return lag / 32;
  }

  test('a half turn within one frame puts the skirt back on the body without over-stretching', () async {
    final d = await Dressed.create();
    addTearDown(d.w.dispose);
    d.pose();
    d.run(1);
    d.actor.rootComponent.relativeRotation = Quaternion.axisAngle(Vector3(0, 1, 0), math.pi);
    d.pose();
    d.run(1 / 60);
    expect(d.maxStretch(), lessThan(0.1), reason: 'stretch right after the turn');
    final now = d.worldVertices(), rest = d.restVertices();
    for (var i = 0; i < now.length; i++) {
      expect(
        now[i].distanceTo(rest[i]),
        lessThan(d.cloth.skin!.maxDistances[i] + 2.0),
        reason: 'vertex $i on the body',
      );
    }
    d.run(0.5);
    expect(d.maxStretch(), lessThan(0.1), reason: 'stretch after half a second');
  }, skip: mannySkip);

  test('a teleport and half turn whose pose arrives a frame late does not pull the skirt back', () async {
    final d = await Dressed.create();
    addTearDown(d.w.dispose);
    d.pose();
    d.run(1);
    d.actor.rootComponent
      ..relativeLocation = Vector3(500, 0, 0)
      ..relativeRotation = Quaternion.axisAngle(Vector3(0, 1, 0), math.pi);
    // The step runs with the pose taken before the move, then a fresh one.
    d.w.world.tick(1 / 60);
    expect(d.maxStretch(), lessThan(0.1));
    d.pose();
    d.w.world.tick(1 / 60);
    expect(d.maxStretch(), lessThan(0.1));
    final centre = d.worldVertices().fold(Vector3.zero(), (a, v) => a..add(v))..scale(1 / d.restVertices().length);
    expect(centre.x, closeTo(500, 10));
  }, skip: mannySkip);

  test('while a pose is a frame late the limbs move with the character, never back through the skirt', () async {
    final d = await Dressed.create();
    addTearDown(d.w.dispose);
    // One leg forward: the pose turned round is not the same pose.
    final stride = Float64List.fromList(d.cloth.skeleton!.restPose);
    final o = d.cloth.skeleton!.slotNamed('thigh_l') * LuminaPoseMath.trsStride;
    final q =
        Quaternion(stride[o + 3], stride[o + 4], stride[o + 5], stride[o + 6]) *
        Quaternion.axisAngle(Vector3(0, 0, 1), 0.6);
    stride.setRange(o + 3, o + 7, [q.x, q.y, q.z, q.w]);
    d.pose(stride);
    d.w.run(1, (_) => d.pose(stride));
    bool legs(String bone) => bone.startsWith('thigh') || bone.startsWith('calf');
    final settled = d.deepestIn(legs);
    // Turned round with the pose a frame late: the limbs go with the
    // character, so the skirt stays outside them.
    d.actor.rootComponent.relativeRotation = Quaternion.axisAngle(Vector3(0, 1, 0), math.pi);
    d.w.world.tick(1 / 60);
    d.pose(stride);
    expect(d.deepestIn(legs), lessThan(settled + 1.0));
    // Put back on its skin at once (the stride's own skinning stretch, about
    // 26 %); limbs swept back to the old pose tore it by over 200 %.
    expect(d.maxStretch(), lessThan(0.5));
    d.w.run(0.5, (_) => d.pose(stride));
    expect(d.maxStretch(), lessThan(0.1));
    expect(d.deepestIn(legs), lessThan(2.0));
  }, skip: mannySkip);

  test('the inertia scale sets how far the hem lags a fast move: 0 carries it with the body', () async {
    Future<double> lagWith(double inertia) async {
      final d = await Dressed.create(
        garment: (mesh) => LuminaSkinnedClothComponent(mesh: mesh, sampler: mannySampler)..inertiaScale = inertia,
      );
      addTearDown(d.w.dispose);
      d.pose();
      d.run(1);
      final still = hemLag(d);
      var worst = 0.0;
      for (var f = 1; f <= 12; f++) {
        d.actor.rootComponent.relativeLocation = Vector3(9.0 * f, 0, 0);
        d.pose();
        d.run(1 / 60);
        worst = math.max(worst, hemLag(d) - still);
      }
      return worst;
    }

    final full = await lagWith(1), none = await lagWith(0);
    // ignore: avoid_print
    print('hem lag at 5.4 m/s: inertia 1 ${full.toStringAsFixed(2)} cm, inertia 0 ${none.toStringAsFixed(2)} cm');
    expect(full, greaterThan(2));
    expect(none, lessThan(full * 0.5));
  }, skip: mannySkip);

  test('a max-distance map of zeros keeps every vertex on its skinned position', () async {
    final d = await Dressed.create(
      garment: (mesh) => LuminaSkinnedClothComponent(
        mesh: mesh,
        sampler: mannySampler,
        maxDistanceMap: List.filled(32 * 13, 0),
        wind: Vector3(0, 0, -600),
      ),
    );
    addTearDown(d.w.dispose);
    expect(d.cloth.skin!.maxDistances.every((v) => v == 0), isTrue);
    d.pose();
    d.run(1);
    final now = d.worldVertices(), rest = d.restVertices();
    for (var i = 0; i < now.length; i++) {
      expect(now[i].distanceTo(rest[i]), lessThan(0.5), reason: 'vertex $i');
    }
  }, skip: mannySkip);

  test('a backstop keeps the front of the skirt from being blown into the legs', () async {
    /// How far (cm) the front half of the skirt went behind its skinned
    /// surface at most, under a wind blowing at the character's front.
    Future<double> deepestBehind(double? backstop) async {
      final d = await Dressed.create(
        garment: (mesh) => LuminaSkinnedClothComponent(
          mesh: mesh,
          sampler: mannySampler,
          backstopDistance: backstop,
          wind: Vector3(0, 0, -900),
          windDrag: 3,
        ),
      );
      addTearDown(d.w.dispose);
      d.pose();
      d.run(1.5);
      final now = d.worldVertices(), rest = d.restVertices();
      final axis = rest.take(32).fold(Vector3.zero(), (a, v) => a..add(v))..scale(1 / 32);
      var deepest = 0.0;
      for (var i = 32; i < now.length; i++) {
        final out = Vector3(rest[i].x - axis.x, 0, rest[i].z - axis.z);
        if (out.z <= 0) continue;
        out.normalize();
        deepest = math.max(deepest, -(now[i] - rest[i]).dot(out));
      }
      return deepest;
    }

    final free = await deepestBehind(null), held = await deepestBehind(0);
    // ignore: avoid_print
    print('front behind its skin: no backstop ${free.toStringAsFixed(2)} cm, backstop 0 ${held.toStringAsFixed(2)} cm');
    expect(held, lessThan(1.5));
    expect(free, greaterThan(held + 2));
  }, skip: mannySkip);

  group('walking', () {
    late LuminaGlbAnimationSampler walk;
    late int clip;
    Object? skip = mannySkip;
    final walkFile = File('${testAssets.path}/mannequin/MF_Unarmed_Walk_Fwd.glb');
    if (skip == false && !walkFile.existsSync()) skip = 'test-assets/mannequin/MF_Unarmed_Walk_Fwd.glb is missing';

    setUpAll(() {
      if (skip != false) return;
      walk = LuminaGlbAnimationSampler.fromGlb(
        GlbAnimationMerger.merge(
          base: mannyFile.readAsBytesSync(),
          clips: [GlbClipSource(name: 'Walk', bytes: walkFile.readAsBytesSync())],
        ),
      );
      clip = walk.clipIndex('Walk')!;
    });

    test(
      'a walking character keeps its hands, forearms and legs outside the skirt, which never over-stretches',
      () async {
        final d = await Dressed.create(sampler: walk);
        addTearDown(d.w.dispose);
        final local = Float64List(walk.nodeNames.length * LuminaPoseMath.trsStride);
        var t = 0.0;
        void step() {
          walk.sampleLocal(clip, t, local);
          d.poseSampled(local);
          t += 1 / 60;
        }

        step();
        d.w.run(0.5, (_) => step());
        var deepest = 0.0, deepestLegs = 0.0, stretch = 0.0;
        for (var f = 0; f < 180; f++) {
          d.w.world.tick(1 / 60);
          step();
          deepest = math.max(deepest, d.deepestIn((b) => b.startsWith('hand') || b.startsWith('lowerarm')));
          deepestLegs = math.max(deepestLegs, d.deepestIn((b) => b.startsWith('thigh') || b.startsWith('calf')));
          stretch = math.max(stretch, d.maxStretch());
        }
        // ignore: avoid_print
        print(
          'walk: deepest in a hand or forearm ${deepest.toStringAsFixed(2)} cm, in a leg '
          '${deepestLegs.toStringAsFixed(2)} cm, stretch ${(stretch * 100).toStringAsFixed(1)} %',
        );
        expect(deepest, lessThan(1.5));
        expect(deepestLegs, lessThan(2.0));
        expect(stretch, lessThan(0.25));
      },
      skip: skip,
    );
  });

  test(
    'a 3000-vertex garment steps within 1.5 ms at 120 Hz',
    () async {
      final d = await Dressed.create(
        garment: (mesh) =>
            LuminaSkinnedClothComponent(mesh: mesh, sampler: mannySampler, skirtColumns: 100, skirtRows: 29),
      );
      addTearDown(d.w.dispose);
      expect(d.cloth.geometry!.simVertexCount, 3000);
      d.pose();
      d.run(0.5);
      // The best of many short windows of 6 steps over up to 3 s: other work
      // on the machine (test files run side by side, each with Jolt's
      // worker threads) only ever slows a window down, and short windows
      // find the moments it leaves the cores free.
      var us = double.infinity;
      final budget = Stopwatch()..start();
      for (var run = 0; run < 400 && budget.elapsedMilliseconds < 3000; run++) {
        final watch = Stopwatch()..start();
        for (var i = 0; i < 6; i++) {
          if (i.isEven) d.pose();
          d.w.physics.step(1 / 120);
        }
        us = math.min(us, watch.elapsedMicroseconds / 6);
      }
      // ignore: avoid_print
      print('garment step: ${us.toStringAsFixed(0)} µs for 3000 vertices');
      expect(us, lessThan(1500));
    },
    skip: mannySkip,
    // A timing: test files running side by side can slow one run down.
    retry: 2,
  );
}
