import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_core/testing.dart';
import 'package:vector_math/vector_math_64.dart';

/// Motion matching playback: the springs, the trajectory predictor, the
/// inertializer, the player's search scheduling and switching on a
/// synthetic rig, and the mesh pose driver on a real (headless) engine.
void main() {
  group('springs', () {
    test('a decaying offset halves in one halflife and never overshoots', () {
      var x = 1.0, v = 0.0;
      const h = 0.1;
      var min = 1.0;
      for (var i = 0; i < 100; i++) {
        (x, v) = LuminaSpringMath.decaySpringDamper(x, v, h, 0.001);
        min = math.min(min, x);
      }
      // A critically damped spring with zero start velocity: x(h) = (1 + y h) e^(−y h), y = 2 ln2 / h.
      final y = 2 * math.ln2 / h;
      expect(x, closeTo((1 + y * h) * math.exp(-y * h), 1e-3));
      expect(min, greaterThanOrEqualTo(0.0));
    });

    test('the character spring reaches the goal velocity and its position integrates its velocity', () {
      const h = 0.2, goal = 200.0;
      final (_, v4, _) = LuminaSpringMath.springCharacter(0, 0, 0, goal, h, 4 * h);
      expect(v4, greaterThan(0.95 * goal));
      final (x1, _, _) = LuminaSpringMath.springCharacter(0, 0, 0, goal, h, 1.0);
      var integral = 0.0;
      const n = 10000;
      for (var i = 0; i < n; i++) {
        final (_, v, _) = LuminaSpringMath.springCharacter(0, 0, 0, goal, h, (i + 0.5) / n);
        integral += v / n;
      }
      expect(x1, closeTo(integral, 1e-3));
    });
  });

  group('trajectory predictor', () {
    test('forward input from standing predicts monotonically increasing forward samples', () {
      final p = LuminaTrajectoryPredictor();
      final points = p.predict(
        position: Vector3.zero(),
        yaw: 0,
        velocity: Vector3.zero(),
        desiredVelocity: Vector3(0, 0, 150),
        desiredYaw: 0,
        times: const [0.33, 0.67, 1.0],
      );
      expect(points[0].position.z, greaterThan(0));
      expect(points[1].position.z, greaterThan(points[0].position.z));
      expect(points[2].position.z, greaterThan(points[1].position.z));
      expect(points[2].position.z, lessThan(150.0));
      expect(points[2].position.z, greaterThan(150.0 * (1.0 - 0.2 / math.ln2)));
    });

    test('the facing turns toward a sideways desired yaw; the past comes from the history', () {
      final p = LuminaTrajectoryPredictor();
      for (var i = 0; i < 60; i++) {
        p.record(Vector3(0, 0, i * 2.5), 0, Vector3(0, 0, 150), 1 / 60);
      }
      final points = p.predict(
        position: Vector3(0, 0, 150),
        yaw: 0,
        velocity: Vector3(0, 0, 150),
        desiredVelocity: Vector3(150, 0, 0),
        desiredYaw: math.pi / 2,
        times: const [-0.5, 1.0],
      );
      expect(points[0].position.z, closeTo(150 - 75, 3.0));
      expect(points[1].yaw, greaterThan(math.pi / 2 * 0.9));
      expect(points[1].position.x, greaterThan(50));
    });
  });

  group('inertializer', () {
    Float64List pose(double angle, double tx) {
      final p = Float64List(10);
      p.setAll(0, [tx, 0, 0, 0, math.sin(angle / 2), 0, math.cos(angle / 2), 1, 1, 1]);
      return p;
    }

    double angleOf(Float64List p) => 2 * math.acos(p[6].abs().clamp(0.0, 1.0));

    test('a 90° switch starts from the shown pose and decays below 5 % by the blend time', () {
      const blend = 0.2;
      final ine = LuminaInertializer(1, halflife: blend / 4);
      final shown = pose(math.pi / 2, 10);
      final target = pose(0, 0);
      final zero = Float64List(6);
      ine.transition(shown, zero, target, zero);
      final out = Float64List(10);
      ine.update(0, target, out);
      expect(angleOf(out), closeTo(math.pi / 2, 1e-6));
      expect(out[0], closeTo(10, 1e-9));
      var t = 0.0;
      while (t < blend - 1e-9) {
        ine.update(1 / 60, target, out);
        t += 1 / 60;
      }
      expect(angleOf(out), lessThan(0.05 * math.pi / 2));
      expect(out[0].abs(), lessThan(0.5));
    });

    test('no offset leaves the target untouched', () {
      final ine = LuminaInertializer(1);
      final target = pose(0.7, 3);
      final out = Float64List(10);
      ine.update(1 / 60, target, out);
      for (var k = 0; k < 10; k++) {
        expect(out[k], closeTo(target[k], 1e-12));
      }
    });
  });

  group('player', () {
    late LuminaPoseSearchDatabaseRuntime db;
    setUpAll(() async {
      final glb = LuminaSyntheticLocomotionRig.build([
        LuminaSyntheticLocomotionRig.idle('Idle'),
        LuminaSyntheticLocomotionRig.start('Start'),
        LuminaSyntheticLocomotionRig.walk('WalkF', 0, 1),
        LuminaSyntheticLocomotionRig.stop('Stop'),
      ]);
      db = await LuminaPoseSearchDatabaseRuntime.fromGlb(
        glb,
        const LuminaPoseSearchDatabaseDocument(clips: [
          LuminaPoseSearchClip('Idle', loop: true),
          LuminaPoseSearchClip('Start'),
          LuminaPoseSearchClip('WalkF', loop: true),
          LuminaPoseSearchClip('Stop'),
        ]),
      );
    });

    /// Runs a character whose velocity springs toward the scripted desired
    /// velocity (cm/s) and returns the clips played, consecutive repeats
    /// collapsed.
    final states = <LuminaMotionMatchingPlayer, (Vector3, Vector3, List<double>)>{};
    List<String> run(LuminaMotionMatchingPlayer player, List<(double seconds, double speed)> script) {
      final (position, velocity, accelBox) = states.putIfAbsent(player, () => (Vector3.zero(), Vector3.zero(), [0.0]));
      var accel = accelBox[0];
      const dt = 1 / 60;
      final played = <String>[];
      for (final (seconds, speed) in script) {
        for (var t = 0.0; t < seconds; t += dt) {
          final input = LuminaMotionMatchingInput(
            position: position.clone(),
            facingYaw: 0,
            velocity: velocity.clone(),
            desiredVelocity: Vector3(0, 0, speed),
          );
          player.update(dt, input);
          final clip = player.matchedClip!;
          if (played.isEmpty || played.last != clip) played.add(clip);
          final (dz, v, a) = LuminaSpringMath.springCharacter(position.z, velocity.z, accel, speed, 0.2, dt);
          position.z = dz;
          velocity.z = v;
          accel = a;
        }
      }
      accelBox[0] = accel;
      return played;
    }

    test('standing, walking forward and releasing plays idle, start, loop, stop, idle in order', () {
      final player = LuminaMotionMatchingPlayer(db);
      final played = run(player, [(1.0, 0.0), (3.0, 150.0), (3.0, 0.0)]);
      expect(played, ['Idle', 'Start', 'WalkF', 'Stop', 'Idle']);
    });

    test('searches every interval, at once on a sharp input change, and keeps the loop under constant input', () {
      final player = LuminaMotionMatchingPlayer(db);
      run(player, [(1.0, 0.0)]);
      final searches = player.searchCount;
      expect(searches, inInclusiveRange(10, 12), reason: '1 s at 0.1 s per search (plus the first)');
      final before = player.searchCount;
      player.update(1 / 60,
          LuminaMotionMatchingInput(position: Vector3.zero(), facingYaw: 0, velocity: Vector3.zero(), desiredVelocity: Vector3(0, 0, 150)));
      expect(player.searchCount, before + 1, reason: 'the input jumped from 0 to 150 cm/s');

      final looping = LuminaMotionMatchingPlayer(db);
      run(looping, [(3.0, 150.0)]);
      final switches = looping.switchCount;
      run(looping, [(3.0, 150.0)]);
      expect(looping.switchCount, switches, reason: 'continuing the loop is cheapest under constant input');
      expect(looping.matchedClip, 'WalkF');
    });
  });

  group('mesh pose driver', () {
    late FilamentEngine engine;
    late FilamentScene scene;
    late LuminaWorld world;

    setUp(() {
      engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
      scene = engine.createScene();
      world = LuminaWorld(worldType: LuminaWorldType.game);
      world.initializeNativeContext(engine, scene);
    });

    tearDown(() {
      world.cleanup();
      scene.dispose();
      engine.dispose();
    });

    test('the mannequin shows the matched frame with root motion removed', () async {
      const bundle = LuminaThirdPersonContent.bundledMeshPath;
      final glb = File(bundle).readAsBytesSync();
      final db = await LuminaPoseSearchDatabaseRuntime.fromGlb(
        glb,
        const LuminaPoseSearchDatabaseDocument(targetMesh: bundle, clips: [
          LuminaPoseSearchClip('Idle_Loop', loop: true),
          LuminaPoseSearchClip('Walk_Fwd_Loop', loop: true),
        ]),
      );
      final mesh = LuminaAnimatedMeshComponent(meshAssetPath: bundle);
      final mm = LuminaMotionMatchingComponent(runtime: db, mesh: mesh);
      world.persistentLevel.registerActor(LuminaActor(root: mesh)..addComponent(mm));
      world.beginPlay();
      await mesh.loaded;
      await mm.ready;
      for (var i = 0; i < 10; i++) {
        world.tick(1 / 60);
      }
      final player = mm.player!;
      expect(player.matchedClip, 'Idle_Loop');
      // The joint holds exactly what the player showed.
      final thigh = db.sampler.indexOfNode('thigh_l');
      final local = mesh.jointLocalTransform('thigh_l')!;
      final shown = Matrix4.compose(
        Vector3(player.pose[thigh * 10], player.pose[thigh * 10 + 1], player.pose[thigh * 10 + 2]),
        Quaternion(player.pose[thigh * 10 + 3], player.pose[thigh * 10 + 4], player.pose[thigh * 10 + 5], player.pose[thigh * 10 + 6]),
        Vector3(player.pose[thigh * 10 + 7], player.pose[thigh * 10 + 8], player.pose[thigh * 10 + 9]),
      );
      for (var k = 0; k < 16; k++) {
        expect(local.storage[k], closeTo(shown.storage[k], 1e-5));
      }
      // And it is the sampled frame: no switch since the first, so the
      // inertializer has nothing to add.
      final expected = Float64List(db.sampler.nodeCount * 10);
      db.poser.pose(db.samplerClips[player.clip]!, player.matchedTime, false, expected);
      for (var k = 0; k < 7; k++) {
        expect(player.pose[thigh * 10 + k], closeTo(expected[thigh * 10 + k], 1e-6));
      }
      final root = db.rig.root;
      expect(player.pose[root * 10].abs() + player.pose[root * 10 + 2].abs(), lessThan(1e-6));
    });
  });
}
