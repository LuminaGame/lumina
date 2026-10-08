import 'dart:io';
import 'dart:typed_data';

import 'package:lumina_core/lumina_core.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';

import 'glb_timed_pose.dart';

/// The Third Person template character: a Blender glTF export (bones run
/// along their local Y, T-pose arms), carrying the template's clips.
final File _superhero = File(
  '${Directory.current.parent.path}/lumina/assets/templates/third_person/SKM_Superhero_Female.glb',
);

Directory get _assets => Directory(
  Platform.environment['LUMINA_TEST_ASSETS'] ??
      '${Directory.current.parent.path}/test-assets',
);

/// Manny: bones run along their local X, A-pose arms, twist bones.
File get _manny => File('${_assets.path}/mannequin/SKM_Manny_Simple.glb');

/// A MetaHuman exported by the MetaHuman Creator plugin. MetaHuman data is
/// never committed: `LUMINA_METAHUMAN_GLB` names one, otherwise the first
/// `SK_MH_*.entity.glb` of a project in `~/Lumina Projects` is used.
File? _metaHuman() {
  final named = Platform.environment['LUMINA_METAHUMAN_GLB'];
  if (named != null) return File(named).existsSync() ? File(named) : null;
  final home =
      Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
  if (home == null) return null;
  final projects = Directory('$home/Lumina Projects');
  if (!projects.existsSync()) return null;
  for (final project in projects.listSync().whereType<Directory>()) {
    final skeletal = Directory('${project.path}/contents/meshes/skeletal');
    if (!skeletal.existsSync()) continue;
    for (final f in skeletal.listSync().whereType<File>()) {
      final name = f.uri.pathSegments.last;
      if (name.startsWith('SK_MH_') && name.endsWith('.entity.glb')) return f;
    }
  }
  return null;
}

/// Limb segments (joint → joint) both skeletons have.
const _limbs = [
  ('upperarm_l', 'lowerarm_l'),
  ('lowerarm_l', 'hand_l'),
  ('upperarm_r', 'lowerarm_r'),
  ('lowerarm_r', 'hand_r'),
  ('thigh_l', 'calf_l'),
  ('calf_l', 'foot_l'),
  ('foot_l', 'ball_l'),
  ('thigh_r', 'calf_r'),
  ('calf_r', 'foot_r'),
  ('foot_r', 'ball_r'),
  ('hand_l', 'middle_01_l'),
  ('hand_r', 'middle_01_r'),
];

/// [name], or its capitalised spelling (the Superhero's head is `Head`).
String _bone(GlbTimedPose pose, String name) => pose.index(name) >= 0
    ? name
    : '${name[0].toUpperCase()}${name.substring(1)}';

/// Retargets [clipName] of the Superhero onto [target] and checks, at
/// [samples] times across the clip, that every limb segment points where the
/// clip's segment points, that the hip line turns with the clip's, and that
/// twist bones follow their limb.
void _expectLimbsFollowTheClip(
  Uint8List target,
  String clipName, {
  int samples = 8,
  double toleranceDeg = 3,
}) {
  final clip = _superhero.readAsBytesSync();
  final index = GlbAnimationMerger.animationNames(clip).indexOf(clipName);
  expect(
    index,
    greaterThanOrEqualTo(0),
    reason: '$clipName is a template clip',
  );
  final result = GlbAnimationRetargeter.retargetInto(
    target: target,
    clip: clip,
    clipName: clipName,
    animationIndex: index,
  );

  final source = GlbTimedPose(GlbDocument.parse(clip), animationIndex: index);
  final out = GlbTimedPose(
    GlbDocument.parse(result.glb),
    animationIndex: result.clipIndex,
  );
  final rest = GlbTimedPose(GlbDocument.parse(target));
  final sourceRest = GlbTimedPose(GlbDocument.parse(clip));
  Vector3 dir(GlbTimedPose p, String a, String b) =>
      p.position(_bone(p, b)) - p.position(_bone(p, a));

  for (var k = 0; k < samples; k++) {
    final t = source.duration * k / samples;
    source.time = t;
    out.time = t;
    for (final (a, b) in _limbs) {
      // A hand lies by the best fit over all its fingers, whose spread
      // differs between characters, so the middle finger is a little looser.
      final tolerance = a.startsWith('hand') ? toleranceDeg + 3 : toleranceDeg;
      expect(
        angleBetweenDeg(dir(source, a, b), dir(out, a, b)),
        lessThan(tolerance),
        reason: '$a → $b of $clipName at ${t.toStringAsFixed(2)} s',
      );
    }
    expect(
      angleBetweenDeg(
        dir(source, 'thigh_l', 'thigh_r'),
        dir(out, 'thigh_l', 'thigh_r'),
      ),
      lessThan(toleranceDeg + 2),
      reason: 'hip line of $clipName at ${t.toStringAsFixed(2)} s',
    );
    // The trunk, shoulders and head keep the target's own build: they move
    // like the clip's but stay off it by their rest difference, plus a little
    // where the spine bones split the back at other heights.
    for (final (a, b) in const [
      ('pelvis', 'neck_01'),
      ('spine_01', 'neck_01'),
      ('clavicle_l', 'upperarm_l'),
      ('clavicle_r', 'upperarm_r'),
      ('neck_01', 'head'),
    ]) {
      final restOffset = angleBetweenDeg(
        dir(sourceRest, a, b),
        dir(rest, a, b),
      );
      expect(
        angleBetweenDeg(dir(source, a, b), dir(out, a, b)),
        lessThan(restOffset + toleranceDeg + 3),
        reason:
            '$a → $b of $clipName at ${t.toStringAsFixed(2)} s (rest offset ${restOffset.toStringAsFixed(1)}°)',
      );
    }

    // Twist bones ride on their limb: relative to the parent they keep the
    // rest offset, except a forearm twist bone that rolls about the forearm.
    for (final side in ['l', 'r']) {
      for (final twist in [
        'upperarm_twist_01_$side',
        'upperarm_twist_02_$side',
        'thigh_twist_01_$side',
        'calf_twist_01_$side',
        'lowerarm_twist_01_$side',
        'lowerarm_twist_02_$side',
      ]) {
        final node = out.index(twist);
        if (node < 0) continue;
        final parent = out.parentOf(node);
        Quaternion relative(GlbTimedPose p) {
          final pq = Quaternion.fromRotation(p.world(parent).getRotation())
            ..normalize();
          final q = Quaternion.fromRotation(p.world(node).getRotation())
            ..normalize();
          return (pq.conjugated() * q)..normalize();
        }

        final now = relative(out), atRest = relative(rest);
        final change = (now * atRest.conjugated())..normalize();
        if (twist.startsWith('lowerarm')) {
          // Only a roll about the forearm: no swing left once the twist
          // about the elbow → wrist axis is taken out.
          final axis =
              (rest.position('hand_$side') - rest.position('lowerarm_$side'))
                  .normalized();
          final localAxis =
              (rest.world(parent).getRotation()..transpose()).transformed(axis)
                ..normalize();
          final along =
              change.x * localAxis.x +
              change.y * localAxis.y +
              change.z * localAxis.z;
          final roll = Quaternion(
            localAxis.x * along,
            localAxis.y * along,
            localAxis.z * along,
            change.w,
          )..normalize();
          final swing = (change * roll.conjugated())..normalize();
          expect(
            rotationAngleDeg(swing, Quaternion.identity()),
            lessThan(1.0),
            reason:
                '$twist only rolls about the forearm at ${t.toStringAsFixed(2)} s',
          );
        } else {
          expect(
            rotationAngleDeg(now, atRest),
            lessThan(1.0),
            reason: '$twist follows its parent at ${t.toStringAsFixed(2)} s',
          );
        }
      }
    }
  }
}

void main() {
  final haveSuperhero = _superhero.existsSync();

  group('GlbAnimationRetargeter limb directions', () {
    test(
      'the Superhero clips onto the Superhero itself reproduce every limb',
      () {
        if (!haveSuperhero) {
          return markTestSkipped('${_superhero.path} missing');
        }
        final self = _superhero.readAsBytesSync();
        _expectLimbsFollowTheClip(self, 'Idle_Loop', toleranceDeg: 0.5);
        _expectLimbsFollowTheClip(self, 'Jog_Fwd_Loop', toleranceDeg: 0.5);
      },
    );

    test(
      'Superhero (bones along Y, T-pose) onto Manny (bones along X, A-pose): limbs point where the clip points',
      () {
        if (!haveSuperhero) {
          return markTestSkipped('${_superhero.path} missing');
        }
        if (!_manny.existsSync()) {
          return markTestSkipped('${_manny.path} missing');
        }
        final manny = _manny.readAsBytesSync();
        _expectLimbsFollowTheClip(manny, 'Idle_Loop');
        _expectLimbsFollowTheClip(manny, 'Jog_Fwd_Loop');
        _expectLimbsFollowTheClip(manny, 'Walk_Left_Loop');
      },
    );

    test(
      'Superhero onto a MetaHuman (926 bones, twist and corrective joints, A-pose): limbs point where the clip points',
      () {
        if (!haveSuperhero) {
          return markTestSkipped('${_superhero.path} missing');
        }
        final metaHuman = _metaHuman();
        if (metaHuman == null) {
          return markTestSkipped(
            'no MetaHuman export (set LUMINA_METAHUMAN_GLB)',
          );
        }
        final target = metaHuman.readAsBytesSync();
        _expectLimbsFollowTheClip(target, 'Idle_Loop');
        _expectLimbsFollowTheClip(target, 'Jog_Fwd_Loop');
        _expectLimbsFollowTheClip(target, 'Walk_Left_Loop');
      },
    );
  });
}
