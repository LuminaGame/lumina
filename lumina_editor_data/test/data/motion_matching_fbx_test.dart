import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:vector_math/vector_math_64.dart';

import '../helpers/locomotion_fbx_fixture.dart';

/// Motion matching on real mocap: the Game Animation Sample idle / walk /
/// run clips imported from FBX onto the UEFN mannequin build a pose search
/// database, and a scripted character standing, walking forward and stopping
/// plays an idle, a start, the forward loop, a stop and an idle again.
void main() {
  final skip = LocomotionFbxFixture.available ? null : 'test-assets/FBX/GameAnimationSample is missing';

  late Uint8List glb;
  late LuminaPoseSearchDatabaseRuntime db;
  setUpAll(() async {
    if (skip != null) return;
    final watch = Stopwatch()..start();
    glb = await LocomotionFbxFixture.mergedGlb();
    // ignore: avoid_print
    print('import: ${LocomotionFbxFixture.clipFiles.length} clips in ${watch.elapsedMilliseconds} ms, GLB ${glb.length ~/ 1024} KiB');
    db = await LuminaPoseSearchDatabaseRuntime.fromGlb(glb, LocomotionFbxFixture.document());
  });

  test('a root bone without skin weights keeps its root motion through the retarget', () {
    final sampler = LuminaGlbAnimationSampler.fromGlb(glb);
    final root = sampler.indexOfNode('root');
    expect(sampler.joints.contains(root), isFalse, reason: 'the mannequin skins nothing to its root bone');
    final local = Float64List(sampler.nodeCount * 10);
    sampler.sampleLocal(sampler.clipIndex('M_Neutral_Walk_Loop_F')!, 4.0, local);
    expect(local[root * 10 + 2], closeTo(8.0, 0.01), reason: 'the 4 s loop walks 8 m forward on the root bone');
  }, skip: skip);

  test('the database builds from the imported clips, with timings', () async {
    final result = LuminaPoseSearchBuilder.buildWithStats(glb, LocomotionFbxFixture.document());
    final stats = result.stats;
    // ignore: avoid_print
    print('build: ${stats.clips} clips, ${stats.rows} rows (${stats.mirroredRows} mirrored), ${stats.dimensions} dims, '
        '${(stats.buildMicroseconds / 1000).toStringAsFixed(0)} ms, cache ${result.index.encode().length ~/ 1024} KiB; '
        'static root: ${stats.staticRootClips}');
    expect(stats.missingClips, isEmpty);
    expect(stats.missingBones, isEmpty);
    expect(stats.clips, LocomotionFbxFixture.clipFiles.length);
    expect(stats.staticRootClips, isNot(contains('M_Neutral_Walk_Loop_F')), reason: 'the walk carries root motion');

    // The forward walk loop moves forward: +1 s of trajectory is ahead.
    final index = result.index;
    final walk = index.clipNames.indexOf('M_Neutral_Walk_Loop_F');
    final row = index.rowAt(walk, 0.5, false);
    final k = index.layout.trajectorySamples - 1;
    final ahead = index.rawFeature(row, index.layout.trajectoryPositionOffset(k) + 1);
    final side = index.rawFeature(row, index.layout.trajectoryPositionOffset(k));
    // ignore: avoid_print
    print('Walk_Loop_F: 1 s ahead ${ahead.toStringAsFixed(2)} m, sideways ${side.toStringAsFixed(2)} m');
    expect(ahead, greaterThan(0.8));
    expect(side.abs(), lessThan(0.2));

    // Search timing over 1000 queries (each a row's features plus noise).
    final random = math.Random(3);
    final times = <int>[];
    var agree = 0;
    for (var i = 0; i < 1000; i++) {
      final source = random.nextInt(index.rowCount);
      final q = Float32List.fromList([
        for (var d = 0; d < index.dimensions; d++) index.feature(source, d) + (random.nextDouble() - 0.5) * 0.2,
      ]);
      final w = Stopwatch()..start();
      final r = index.search(q);
      w.stop();
      times.add(w.elapsedMicroseconds);
      if (r.row == index.search(q, bruteForce: true).row) agree++;
    }
    times.sort();
    final mean = times.reduce((a, b) => a + b) / times.length;
    // ignore: avoid_print
    print('search: mean ${mean.toStringAsFixed(0)} µs, p50 ${times[500]} µs, p99 ${times[990]} µs, max ${times.last} µs');
    expect(agree, 1000);
    expect(mean, lessThan(1000));
  }, skip: skip, timeout: const Timeout(Duration(minutes: 10)));

  test('standing, walking forward and stopping plays idle, a start, the forward loop, a stop and idle', () {
    final player = LuminaMotionMatchingPlayer(db);
    // The walk speed of the clips: the forward loop's root speed (cm/s).
    final walkClip = db.document.clips.indexWhere((c) => c.clip == 'M_Neutral_Walk_Loop_F');
    final walkSpeed = db.rootSpeed(walkClip, 0.5) * 100.0;
    // ignore: avoid_print
    print('walk speed ${walkSpeed.toStringAsFixed(0)} cm/s');
    player.requiredTags = {'walk'};

    final position = Vector3.zero();
    final velocity = Vector3.zero();
    var accel = 0.0;
    const dt = 1 / 60;
    final played = <String>[];
    void run(double seconds, double speed) {
      for (var t = 0.0; t < seconds; t += dt) {
        player.update(
          dt,
          LuminaMotionMatchingInput(
            position: position.clone(),
            facingYaw: 0,
            velocity: velocity.clone(),
            desiredVelocity: Vector3(0, 0, speed),
            desiredYaw: 0,
          ),
        );
        final clip = player.matchedClip!;
        if (played.isEmpty || played.last != clip) played.add(clip);
        final (z, v, a) = LuminaSpringMath.springCharacter(position.z, velocity.z, accel, speed, 0.25, dt);
        position.z = z;
        velocity.z = v;
        accel = a;
      }
    }

    run(2.0, 0.0);
    run(6.0, walkSpeed);
    run(4.0, 0.0);
    // ignore: avoid_print
    print('played: ${played.join(' → ')}');
    // ignore: avoid_print
    print('player: ${player.searchCount} searches, ${player.switchCount} switches, search mean '
        '${player.meanSearchMicroseconds.toStringAsFixed(0)} µs max ${player.maxSearchMicroseconds} µs, update mean '
        '${player.meanUpdateMicroseconds.toStringAsFixed(0)} µs max ${player.maxUpdateMicroseconds} µs');

    int find(bool Function(String) test, int from) {
      for (var i = from; i < played.length; i++) {
        if (test(played[i])) return i;
      }
      return -1;
    }

    expect(played.first, contains('Idle'));
    final start = find((c) => c.contains('Walk_Start_F'), 0);
    expect(start, isNonNegative, reason: 'a forward start after standing: $played');
    final loop = find((c) => c == 'M_Neutral_Walk_Loop_F', start);
    expect(loop, greaterThan(start), reason: 'then the forward loop: $played');
    final stop = find((c) => c.contains('Walk_Stop_F'), loop);
    expect(stop, greaterThan(loop), reason: 'then a forward stop: $played');
    expect(played.last, contains('Idle'), reason: 'and idle at the end: $played');
    expect(player.meanUpdateMicroseconds, lessThan(2000));
  }, skip: skip, timeout: const Timeout(Duration(minutes: 5)));
}
