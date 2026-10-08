import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:lumina_core/lumina_core.dart';
import 'package:lumina_core/testing.dart';
import 'package:test/test.dart';

/// Pose search databases: the document, the CPU clip sampler, feature
/// extraction in the character frame, normalization, mirroring, the search
/// and the feature cache — on a synthetic rig whose motion is known exactly.
void main() {
  final clips = [
    LuminaSyntheticLocomotionRig.idle('Idle'),
    LuminaSyntheticLocomotionRig.walk('WalkF', 0, 1),
    LuminaSyntheticLocomotionRig.walk('WalkL', 1, 0),
    LuminaSyntheticLocomotionRig.walk('WalkR', -1, 0),
    LuminaSyntheticLocomotionRig.walk('WalkFL', math.sqrt1_2, math.sqrt1_2),
    LuminaSyntheticLocomotionRig.walk('WalkFR', -math.sqrt1_2, math.sqrt1_2, footSign: -1),
    LuminaSyntheticLocomotionRig.start('Start'),
    LuminaSyntheticLocomotionRig.stop('Stop'),
    LuminaSyntheticLocomotionRig.turn('TurnL', math.pi / 2),
  ];
  final glb = LuminaSyntheticLocomotionRig.build(clips);
  LuminaPoseSearchDatabaseDocument doc(List<LuminaPoseSearchClip> entries, {LuminaPoseSearchSchema? schema}) =>
      LuminaPoseSearchDatabaseDocument(targetMesh: 'contents/meshes/Rig.lmas', clips: entries, schema: schema ?? const LuminaPoseSearchSchema());

  group('document', () {
    test('round-trips through JSON byte for byte, with the documented defaults', () {
      final d = doc([
        const LuminaPoseSearchClip('WalkF', loop: true, mirror: true, tags: ['walk']),
        const LuminaPoseSearchClip('Stop', enabled: false),
      ]);
      final json = jsonEncode(d.toJson());
      expect(jsonEncode(LuminaPoseSearchDatabaseDocument.fromJson(jsonDecode(json) as Map<String, dynamic>).toJson()), json);
      const s = LuminaPoseSearchSchema();
      expect(s.sampleRate, 30);
      expect(s.trajectoryTimes, [-0.33, 0.33, 0.67, 1.0]);
      expect(s.bones.map((b) => '${b.name}:${b.position}:${b.velocity}'), ['foot_l:1.0:1.0', 'foot_r:1.0:1.0', 'pelvis:0.0:1.0']);
      expect(d.enabledClips.map((c) => c.clip), ['WalkF']);
      expect(d.tags, ['walk']);
    });
  });

  group('sampler', () {
    final sampler = LuminaGlbAnimationSampler.fromGlb(glb);

    test('reads the skeleton, the skin and every clip', () {
      expect(sampler.nodeNames, ['Armature', 'root', 'pelvis', 'foot_l', 'foot_r', 'hand_l', 'hand_r']);
      expect(sampler.skinJoints, [1, 2, 3, 4, 5, 6]);
      expect(sampler.topJoint, 1);
      expect(sampler.clips.map((c) => c.name), clips.map((c) => c.name));
      expect(sampler.clips[sampler.clipIndex('WalkF')!].duration, closeTo(2.0, 1e-6));
      expect(sampler.nodeNames[sampler.mirror[3]], 'foot_r');
      expect(sampler.nodeNames[sampler.mirror[6]], 'hand_l');
      expect(sampler.mirror[2], 2);
    });

    test('samples the root at 0.5 s and puts the feet below the moving root', () {
      final local = Float64List(sampler.nodeCount * 10);
      final world = Float64List(sampler.nodeCount * 12);
      sampler.sampleLocal(sampler.clipIndex('WalkF')!, 0.5, local);
      expect(local[1 * 10 + 2], closeTo(0.75, 1e-5), reason: 'root z = 1.5 m/s × 0.5 s');
      sampler.world(local, world);
      expect(world[3 * 12 + 9], closeTo(0.1, 1e-5));
      expect(world[3 * 12 + 10], closeTo(0.05, 1e-5));
      // foot_l z = root z + swing (0.3 sin(π)) = 0.75.
      expect(world[3 * 12 + 11], closeTo(0.75, 1e-4));
    });
  });

  group('features', () {
    final entries = [for (final c in clips) LuminaPoseSearchClip(c.name, loop: c.name.startsWith('Walk') || c.name == 'Idle')];
    final built = LuminaPoseSearchBuilder.buildWithStats(glb, doc(entries));
    final index = built.index;
    final layout = index.layout;
    int row(String clip, double time) => index.rowAt(entries.indexWhere((e) => e.clip == clip), time, false);

    test('a forward walk is 1.5 m ahead after 1 s, facing straight on', () {
      final r = row('WalkF', 0.5);
      final k = layout.trajectorySamples - 1; // +1.0 s
      expect(index.rawFeature(r, layout.trajectoryPositionOffset(k)), closeTo(0.0, 1e-4));
      expect(index.rawFeature(r, layout.trajectoryPositionOffset(k) + 1), closeTo(1.5, 1e-3));
      expect(index.rawFeature(r, layout.trajectoryFacingOffset(k)), closeTo(0.0, 1e-4));
      expect(index.rawFeature(r, layout.trajectoryFacingOffset(k) + 1), closeTo(1.0, 1e-4));
      // −0.33 s: behind.
      expect(index.rawFeature(r, layout.trajectoryPositionOffset(0) + 1), closeTo(-0.495, 1e-3));
    });

    test('a turn of 90° left over 1 s faces +X one second on', () {
      final r = row('TurnL', 0.0);
      final k = layout.trajectorySamples - 1;
      expect(index.rawFeature(r, layout.trajectoryFacingOffset(k)), closeTo(1.0, 1e-3));
      expect(index.rawFeature(r, layout.trajectoryFacingOffset(k) + 1), closeTo(0.0, 1e-3));
    });

    test('a one-shot clip extrapolates its start velocity into the past and a loop wraps', () {
      final start = row('Start', 0.0);
      expect(index.rawFeature(start, layout.trajectoryPositionOffset(0) + 1), lessThanOrEqualTo(1e-6),
          reason: 'the start is at rest: extrapolating backwards stays put');
      final stop = row('Stop', 0.0);
      expect(index.rawFeature(stop, layout.trajectoryPositionOffset(0) + 1), closeTo(-0.33 * 1.5, 0.02),
          reason: 'the stop starts at walking speed: its past continues backwards');
      final loopEnd = row('WalkF', 1.9);
      expect(index.rawFeature(loopEnd, layout.trajectoryPositionOffset(layout.trajectorySamples - 1) + 1), closeTo(1.5, 1e-3),
          reason: 'one second past 1.9 s wraps into the next cycle');
    });

    test('foot velocity is a world velocity in the character frame', () {
      final r = row('WalkF', 0.5);
      final g = layout.group('boneVelocity', 'foot_l')!;
      // dz = root 1.5 + swing 0.3 · 2π · cos(π) = 1.5 − 1.885 (the foot swings back).
      expect(index.rawFeature(r, g.offset + 2), closeTo(1.5 - 0.3 * 2 * math.pi, 0.05));
      expect(index.rawFeature(row('Idle', 1.0), g.offset + 2), closeTo(0.0, 1e-6));
    });

    test('normalization divides each group by its mean std and the weight scales the squared cost', () {
      for (final g in layout.groups) {
        final s = index.inverseScale[g.offset];
        for (var d = g.offset; d < g.offset + g.length; d++) {
          expect(index.inverseScale[d], s, reason: 'one scale per group (${g.name})');
        }
      }
      final heavier = LuminaPoseSearchBuilder.build(
          glb, doc(entries, schema: const LuminaPoseSearchSchema(trajectoryPositionWeight: 2.0)));
      expect(heavier.weights[0], 4.0 * index.weights[0]);
    });

    test('stats count rows, clips and bones', () {
      expect(built.stats.clips, clips.length);
      expect(built.stats.rows, index.rowCount);
      expect(built.stats.missingBones, isEmpty);
      expect(built.stats.staticRootClips, ['Idle']);
      expect(built.stats.dimensions, 4 * 4 + 6 + 6 + 3);
    });
  });

  group('mirror', () {
    test('the mirror of walking forward-left is walking forward-right', () {
      final entries = [
        const LuminaPoseSearchClip('WalkFL', loop: true, mirror: true),
        const LuminaPoseSearchClip('WalkFR', loop: true),
      ];
      final index = LuminaPoseSearchBuilder.build(glb, doc(entries));
      for (final t in [0.0, 0.4, 1.3]) {
        final mirrored = index.rowAt(0, t, true);
        final right = index.rowAt(1, t, false);
        expect(index.isMirrored(mirrored), isTrue);
        for (var d = 0; d < index.dimensions; d++) {
          expect(index.rawFeature(mirrored, d), closeTo(index.rawFeature(right, d), 1e-4), reason: 'dim $d at $t s');
        }
      }
    });

    test('the mirrored pose swaps the feet and negates the lateral axis', () {
      final sampler = LuminaGlbAnimationSampler.fromGlb(glb);
      final poser = LuminaPoseSearchPoser(LuminaPoseSearchRig(sampler, const LuminaPoseSearchSchema()));
      final plain = Float64List(sampler.nodeCount * 10);
      final mirrored = Float64List(sampler.nodeCount * 10);
      final clip = sampler.clipIndex('WalkFL')!;
      poser.pose(clip, 0.25, false, plain);
      poser.pose(clip, 0.25, true, mirrored);
      // foot_l (node 3) mirrored = foot_r (node 4) reflected: x −(−0.1), z same.
      expect(mirrored[3 * 10], closeTo(-plain[4 * 10], 1e-6));
      expect(mirrored[3 * 10 + 2], closeTo(plain[4 * 10 + 2], 1e-6));
      expect(mirrored[4 * 10 + 2], closeTo(plain[3 * 10 + 2], 1e-6));
    });

    test('the pose keeps the root at the origin facing forward (root motion removed)', () {
      final sampler = LuminaGlbAnimationSampler.fromGlb(glb);
      final poser = LuminaPoseSearchPoser(LuminaPoseSearchRig(sampler, const LuminaPoseSearchSchema()));
      final out = Float64List(sampler.nodeCount * 10);
      final g = poser.pose(sampler.clipIndex('TurnL')!, 0.5, false, out);
      expect(g.yaw, closeTo(math.pi / 4, 1e-4));
      expect(out[1 * 10], closeTo(0, 1e-9));
      expect(out[1 * 10 + 2], closeTo(0, 1e-9));
      expect(out[1 * 10 + 6].abs(), closeTo(1.0, 1e-9), reason: 'identity root rotation');
    });
  });

  group('search', () {
    final entries = [
      const LuminaPoseSearchClip('Idle', loop: true),
      const LuminaPoseSearchClip('WalkF', loop: true, tags: ['walk']),
      const LuminaPoseSearchClip('WalkL', loop: true, tags: ['walk']),
      const LuminaPoseSearchClip('WalkR', loop: true, tags: ['walk']),
      const LuminaPoseSearchClip('Stop'),
    ];
    final index = LuminaPoseSearchBuilder.build(glb, doc(entries));
    final layout = index.layout;

    Float32List query(double dx, double dz) {
      // A trajectory moving at 1.5 m/s along (dx, dz), facing +Z, with the
      // pose features of the clip's own frame (the feet at mid stride).
      final q = Float32List(index.dimensions);
      final source = index.rowAt(dx == 0 && dz == 0 ? 0 : (dz > 0 ? 1 : (dx > 0 ? 2 : 3)), 0.5, false);
      for (var d = 0; d < index.dimensions; d++) {
        q[d] = index.rawFeature(source, d);
      }
      for (var k = 0; k < layout.trajectorySamples; k++) {
        final t = layout.schema.trajectoryTimes[k];
        q[layout.trajectoryPositionOffset(k)] = dx * 1.5 * t;
        q[layout.trajectoryPositionOffset(k) + 1] = dz * 1.5 * t;
        q[layout.trajectoryFacingOffset(k)] = 0;
        q[layout.trajectoryFacingOffset(k) + 1] = 1;
      }
      index.normalize(q);
      return q;
    }

    String clipOf(LuminaPoseSearchResult r) => index.clipNames[index.rowClip[r.row]];

    test('finds the clip whose trajectory matches the query', () {
      expect(clipOf(index.search(query(0, 1))), 'WalkF');
      expect(clipOf(index.search(query(1, 0))), 'WalkL');
      expect(clipOf(index.search(query(-1, 0))), 'WalkR');
      expect(clipOf(index.search(query(0, 0))), 'Idle');
    });

    test('pruned search equals brute force on 1000 random queries', () {
      final random = math.Random(7);
      for (var i = 0; i < 1000; i++) {
        final q = Float32List.fromList([for (var d = 0; d < index.dimensions; d++) random.nextDouble() * 4 - 2]);
        final a = index.search(q);
        final b = index.search(q, bruteForce: true);
        expect(a.row, b.row);
        expect(a.cost, closeTo(b.cost, 1e-9));
      }
    });

    test('required tags exclude untagged clips; the end of a one-shot clip is never returned', () {
      final r = index.search(query(0, 0), requiredTags: index.tagMask(['walk']));
      expect(clipOf(r), startsWith('Walk'));
      expect(index.search(query(0, 0), requiredTags: index.tagMask(['crouch'])).row, -1);
      final stopClip = entries.indexWhere((e) => e.clip == 'Stop');
      for (var row = 0; row < index.rowCount; row++) {
        if (index.rowClip[row] == stopClip && index.rowTime[row] > 1.5 - 0.3 + 1e-6) {
          expect(index.isSearchable(row), isFalse);
        }
      }
    });

    test('a bound returns nothing when no row beats it', () {
      final q = query(0, 1);
      final best = index.search(q);
      expect(index.search(q, bound: best.cost).row, -1);
      expect(index.search(q, excludeRow: best.row).row, isNot(best.row));
    });
  });

  group('cache', () {
    final d = doc([const LuminaPoseSearchClip('WalkF', loop: true, mirror: true), const LuminaPoseSearchClip('Stop')]);

    test('encode → decode keeps every feature bit-exact', () {
      final index = LuminaPoseSearchBuilder.build(glb, d);
      final bytes = index.encode();
      expect(LuminaPoseSearchIndex.fingerprintOf(bytes), index.fingerprint);
      final back = LuminaPoseSearchIndex.decode(bytes);
      expect(back.rowCount, index.rowCount);
      expect(back.features, index.features);
      expect(back.rowTime, index.rowTime);
      expect(back.rowFlags, index.rowFlags);
      expect(back.mean, index.mean);
      expect(back.clipNames, index.clipNames);
      expect(() => LuminaPoseSearchIndex.decode(Uint8List.fromList([1, 2, 3])), throwsFormatException);
    });

    test('the fingerprint changes with the clips and with the GLB', () {
      final a = LuminaPoseSearchBuilder.fingerprint(glb, d);
      expect(LuminaPoseSearchBuilder.fingerprint(glb, d.copyWith(clips: [...d.clips, const LuminaPoseSearchClip('Idle')])), isNot(a));
      final other = LuminaSyntheticLocomotionRig.build([LuminaSyntheticLocomotionRig.walk('WalkF', 0, 1, speed: 2)]);
      expect(LuminaPoseSearchBuilder.fingerprint(other, d), isNot(a));
    });

    test('building in the background gives the same rows', () async {
      final result = await LuminaPoseSearchBuilder.buildInBackground(glb, d);
      final local = LuminaPoseSearchBuilder.build(glb, d);
      final back = LuminaPoseSearchIndex.decode(result.cache);
      expect(back.features, local.features);
      expect(result.stats.rows, local.rowCount);
    });
  });
}
