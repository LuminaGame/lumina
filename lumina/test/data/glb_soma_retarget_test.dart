import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/data/services/glb_animation_merger.dart';
import 'package:lumina/data/services/glb_animation_retargeter.dart';
import 'package:vector_math/vector_math_64.dart';

import 'glb_soma_pose.dart';

void main() {
  final clipPath = Platform.environment['GEMX_TEST_CLIP'];
  final targetPath = Platform.environment['GEMX_TEST_MESH_GLB'];
  final skip = clipPath == null || targetPath == null
      ? 'Set real SOMA clip and target mesh GLB paths'
      : false;
  test(
    'legacy SOMA export without neutral reference requires regeneration',
    () {
      final legacy = Platform.environment['GEMX_LEGACY_CLIP'];
      if (legacy == null) {
        markTestSkipped('Set GEMX_LEGACY_CLIP to an actual earlier capture');
        return;
      }
      expect(
        () => GlbAnimationRetargeter.retargetInto(
          target: File(targetPath!).readAsBytesSync(),
          clip: File(legacy).readAsBytesSync(),
          clipName: 'Earlier SOMA capture',
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('Generate the motion again'),
          ),
        ),
      );
    },
    skip: skip,
  );

  test(
    'neutral SOMA reference preserves the target skeleton and pelvis placement',
    () {
      final source = GlbDocument.parse(File(clipPath!).readAsBytesSync());
      final neutral = neutralClip(source);
      final target = File(targetPath!).readAsBytesSync();
      final result = GlbAnimationRetargeter.retargetInto(
        target: target,
        clip: neutral,
        clipName: 'SOMA neutral reference',
      );
      final rest = GlbPose(GlbDocument.parse(target));
      final pose = GlbPose(
        GlbDocument.parse(result.glb),
        animationIndex: result.clipIndex,
      );
      for (final name in [
        'pelvis',
        'spine_01',
        'head',
        'thigh_l',
        'calf_l',
        'foot_l',
        'thigh_r',
        'calf_r',
        'foot_r',
      ]) {
        final index = rest.index(name);
        expect(
          pose
              .world(index)
              .getTranslation()
              .distanceTo(rest.world(index).getTranslation()),
          lessThan(0.0001),
          reason: '$name must preserve neutral placement',
        );
        final a = Quaternion.fromRotation(pose.world(index).getRotation());
        final b = Quaternion.fromRotation(rest.world(index).getRotation());
        final dot = a.x * b.x + a.y * b.y + a.z * b.z + a.w * b.w;
        expect(
          dot.abs(),
          closeTo(1, 0.00001),
          reason: '$name must preserve neutral axes',
        );
      }
    },
    skip: skip,
  );

  test(
    'SOMA legs map and retain anatomical height throughout captured motion',
    () {
      final result = GlbAnimationRetargeter.retargetInto(
        target: File(targetPath!).readAsBytesSync(),
        clip: File(clipPath!).readAsBytesSync(),
        clipName: 'SOMA capture',
      );
      expect(
        result.mappedBones,
        containsAll([
          'thigh_l',
          'calf_l',
          'foot_l',
          'thigh_r',
          'calf_r',
          'foot_r',
        ]),
      );
      final pose = GlbPose(
        GlbDocument.parse(result.glb),
        animationIndex: result.clipIndex,
      );
      for (final frame in [0, 30, 90, 150, 210, 299]) {
        pose.frame = frame;
        final pelvis = pose.world(pose.index('pelvis')).getTranslation();
        final head = pose.world(pose.index('head')).getTranslation();
        final leftFoot = pose.world(pose.index('foot_l')).getTranslation();
        expect(
          head.y - pelvis.y,
          greaterThan(0.3),
          reason: 'upright captured torso at frame $frame',
        );
        expect(
          pelvis.y - leftFoot.y,
          greaterThan(0.4),
          reason: 'unfolded captured leg at frame $frame',
        );
      }
      final output = Platform.environment['GEMX_RETARGET_OUTPUT'];
      if (output != null) File(output).writeAsBytesSync(result.glb);
    },
    skip: skip,
  );

  test('SOMA captured upper arms and forearms preserve source directions', () {
    final clip = File(clipPath!).readAsBytesSync();
    final result = GlbAnimationRetargeter.retargetInto(
      target: File(targetPath!).readAsBytesSync(),
      clip: clip,
      clipName: 'SOMA arm direction capture',
    );
    final source = GlbPose(GlbDocument.parse(clip), animationIndex: 0);
    final target = GlbPose(
      GlbDocument.parse(result.glb),
      animationIndex: result.clipIndex,
    );
    for (final frame in [0, 30, 90, 150, 210, 299]) {
      source.frame = target.frame = frame;
      for (final side in ['l', 'r']) {
        final prefix = side == 'l' ? 'Left' : 'Right';
        for (final bones in [
          (
            '${prefix}Arm',
            '${prefix}ForeArm',
            'upperarm_$side',
            'lowerarm_$side',
          ),
          ('${prefix}ForeArm', '${prefix}Hand', 'lowerarm_$side', 'hand_$side'),
        ]) {
          final a =
              source.world(source.index(bones.$2)).getTranslation() -
              source.world(source.index(bones.$1)).getTranslation();
          final b =
              target.world(target.index(bones.$4)).getTranslation() -
              target.world(target.index(bones.$3)).getTranslation();
          expect(
            a.normalized().dot(b.normalized()),
            greaterThan(0.98),
            reason: '${bones.$3} direction at frame $frame',
          );
        }
      }
    }
  }, skip: skip);
}

Uint8List neutralClip(GlbDocument source) {
  final nodes = source.json['nodes'] as List;
  final animation = (source.json['animations'] as List).first as Map;
  final data = ByteData.sublistView(source.bin);
  for (final channel in (animation['channels'] as List).cast<Map>()) {
    final target = channel['target'] as Map;
    final node = nodes[target['node'] as int] as Map;
    final values = ((node[target['path']] as List?) ?? [0.0, 0.0, 0.0])
        .cast<num>();
    final sampler =
        (animation['samplers'] as List)[channel['sampler'] as int] as Map;
    final accessor =
        (source.json['accessors'] as List)[sampler['output'] as int] as Map;
    final view =
        (source.json['bufferViews'] as List)[accessor['bufferView'] as int]
            as Map;
    final offset =
        (view['byteOffset'] as int? ?? 0) +
        (accessor['byteOffset'] as int? ?? 0);
    for (var i = 0; i < (accessor['count'] as int); i++) {
      for (var c = 0; c < values.length; c++) {
        data.setFloat32(
          offset + (i * values.length + c) * 4,
          values[c].toDouble(),
          Endian.little,
        );
      }
    }
  }
  return source.encode();
}
