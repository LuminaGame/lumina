import 'dart:io';

import 'package:lumina_core/lumina_core.dart';
import 'package:test/test.dart';

import 'glb_timed_pose.dart';

/// The Third Person template character with its clips (Blender glTF, T-pose).
final File _superhero = File(
  '${Directory.current.parent.path}/lumina/assets/templates/third_person/SKM_Superhero_Female.glb',
);

Directory get _assets => Directory(
  Platform.environment['LUMINA_TEST_ASSETS'] ??
      '${Directory.current.parent.path}/test-assets',
);

/// Manny: other bone axes, A-pose arms, twist bones.
File get _manny => File('${_assets.path}/mannequin/SKM_Manny_Simple.glb');

const _clips = ['Idle_Loop', 'Walk_Fwd_Loop', 'Jog_Fwd_Loop', 'Jump_Start', 'Roll'];

const _bones = ['pelvis', 'spine_03', 'head', 'hand_l', 'hand_r', 'foot_l', 'foot_r', 'lowerarm_twist_01_l'];

/// Node indices each animation of [doc] has a channel for.
List<Set<int>> _keyedNodes(GlbDocument doc) => [
  for (final a in (doc.json['animations'] as List).cast<Map>())
    {for (final c in (a['channels'] as List).cast<Map>()) (c['target'] as Map)['node'] as int},
];

void main() {
  final skip = !_superhero.existsSync()
      ? 'the Third Person template GLB is missing'
      : !_manny.existsSync()
      ? 'test-assets/mannequin/SKM_Manny_Simple.glb is missing'
      : false;

  test('a batch retarget poses every clip exactly like one retarget per clip, in a smaller GLB', () {
    final clip = _superhero.readAsBytesSync();
    final target = _manny.readAsBytesSync();
    final names = GlbAnimationMerger.animationNames(clip);
    final baseAnimations = GlbAnimationMerger.animationNames(target).length;

    var sequential = target;
    final batch = GlbRetargetBatch(target);
    final sequentialIndex = <String, int>{};
    for (final name in _clips) {
      final index = names.indexOf(name);
      expect(index, greaterThanOrEqualTo(0), reason: '$name is a template clip');
      final one = GlbAnimationRetargeter.retargetInto(target: sequential, clip: clip, clipName: name, animationIndex: index);
      sequential = one.glb;
      sequentialIndex[name] = one.clipIndex;
      final added = batch.add(clip: clip, clipName: name, animationIndex: index);
      expect(added.clipIndex, one.clipIndex);
      expect(added.mappedBones, one.mappedBones);
      expect(added.duration, closeTo(one.duration, 1e-9));
    }
    final done = batch.finish();
    expect(batch.length, _clips.length);
    expect(done.clips.map((r) => r.clipName), _clips);
    expect(done.clips.every((r) => identical(r.glb, done.glb)), isTrue);
    expect(GlbAnimationMerger.animationNames(done.glb).length, baseAnimations + _clips.length);
    expect(done.glb.length, lessThan(sequential.length), reason: 'shared, pruned rest channels');

    final batchDoc = GlbDocument.parse(done.glb);
    final sequentialDoc = GlbDocument.parse(sequential);
    for (final r in done.clips) {
      final a = GlbTimedPose(batchDoc, animationIndex: r.clipIndex);
      final b = GlbTimedPose(sequentialDoc, animationIndex: sequentialIndex[r.clipName]);
      expect(a.duration, closeTo(b.duration, 1e-6), reason: r.clipName);
      for (var k = 0; k <= 6; k++) {
        final t = r.duration * k / 6;
        a.time = t;
        b.time = t;
        for (final bone in _bones) {
          if (a.index(bone) < 0) continue;
          expect(
            (a.position(bone) - b.position(bone)).length,
            lessThan(1e-4),
            reason: '$bone of ${r.clipName} at ${t.toStringAsFixed(2)} s',
          );
        }
      }
    }

    // A bone one clip moves has a channel in every clip of the batch, so a
    // clip never inherits where the previous one left it.
    final keyed = _keyedNodes(batchDoc).sublist(baseAnimations);
    final moved = keyed.reduce((x, y) => x.union(y));
    for (final (i, nodes) in keyed.indexed) {
      expect(nodes, moved, reason: '${_clips[i]} keys every moved bone');
    }
  }, skip: skip);

  test('a finished batch takes no more clips', () {
    final batch = GlbRetargetBatch(_manny.readAsBytesSync());
    batch.finish();
    expect(
      () => batch.add(clip: _superhero.readAsBytesSync(), clipName: 'Idle_Loop'),
      throwsStateError,
    );
    expect(batch.finish, throwsStateError);
  }, skip: skip);
}
