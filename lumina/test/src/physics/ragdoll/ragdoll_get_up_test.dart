import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

import 'ragdoll_fixture.dart';

void main() {
  group('get-up', () {
    late LuminaGlbAnimationSampler sampler;
    late LuminaRagdollGetUp getUp;
    setUpAll(() {
      sampler = LuminaGlbAnimationSampler.fromGlb(mannyWithGetUps());
      getUp = LuminaRagdollGetUp(sampler);
    });

    /// The rest pose's frames of the main bones turned by [turn] about the
    /// pelvis, lying with the pelvis 15 cm above y = 0, at [at] turned [yaw].
    Map<String, LuminaBoneFrame> lying(Quaternion turn, Vector3 at, double yaw) {
      final skeleton = getUp.skeleton;
      final world = skeleton.restWorld(LuminaRagdollSkeleton.affineOf(Matrix4.diagonal3Values(100, 100, 100)));
      final pelvis = LuminaRagdollSkeleton.frameOf(world, skeleton.slotNamed('pelvis'));
      final spin = Quaternion.axisAngle(Vector3(0, 1, 0), yaw) * turn;
      return {
        for (final n in ['pelvis', 'spine_02', 'spine_04', 'head', 'hand_l', 'hand_r', 'foot_l', 'foot_r', 'calf_l', 'calf_r', 'lowerarm_l', 'lowerarm_r'])
          n: (() {
            final f = LuminaRagdollSkeleton.frameOf(world, skeleton.slotNamed(n));
            final p = ((f.position - pelvis.position)..applyQuaternion(spin)) + at + Vector3(0, 15, 0);
            return (position: p, rotation: spin * f.rotation);
          })(),
      };
    }

    test('face down picks the front clip, face up the back clip', () {
      const clips = ['GetUp_Back', 'GetUp_Front'];
      final down = lying(Quaternion.axisAngle(Vector3(1, 0, 0), math.pi / 2), Vector3(100, 0, 50), 0.7);
      final up = lying(Quaternion.axisAngle(Vector3(1, 0, 0), -math.pi / 2), Vector3(100, 0, 50), 0.7);
      expect(getUp.isFaceDown(down['pelvis']!), isTrue);
      expect(getUp.isFaceDown(up['pelvis']!), isFalse);
      expect(getUp.plan(down, clips, 0)!.clip, 'GetUp_Front');
      expect(getUp.plan(up, clips, 0)!.clip, 'GetUp_Back');
      expect(getUp.plan(down, const ['Missing'], 0), isNull);
    });

    test('the plan places the clip\'s first frame where the ragdoll lies, facing its way', () {
      for (final yaw in [0.0, 1.2, -2.5]) {
        final down = lying(Quaternion.axisAngle(Vector3(1, 0, 0), math.pi / 2), Vector3(-40, 0, 220), yaw);
        final plan = getUp.plan(down, const ['GetUp_Front', 'GetUp_Back'], 3.0)!;
        expect(plan.origin.y, 3.0);
        final pose = Float64List(getUp.skeleton.length * 10);
        final g = getUp.sample(plan.clipIndex, 0, pose);
        final mesh = getUp.meshTransformAt(plan, g, g);
        final world = Float64List(getUp.skeleton.length * 12);
        getUp.skeleton.world(pose, LuminaRagdollSkeleton.affineOf(mesh), world);
        final pelvis = LuminaRagdollSkeleton.frameOf(world, getUp.skeleton.slotNamed('pelvis'));
        final head = LuminaRagdollSkeleton.frameOf(world, getUp.skeleton.slotNamed('head'));
        final dx = pelvis.position.x - down['pelvis']!.position.x, dz = pelvis.position.z - down['pelvis']!.position.z;
        expect(math.sqrt(dx * dx + dz * dz), lessThan(0.5), reason: 'yaw $yaw');
        final clipYaw = LuminaRagdollGetUp.axisYaw(pelvis.position, head.position);
        final ragYaw = LuminaRagdollGetUp.axisYaw(down['pelvis']!.position, down['head']!.position);
        expect(LuminaPoseMath.wrapAngle(clipYaw - ragYaw).abs(), lessThan(0.01), reason: 'yaw $yaw');
      }
    });
  }, skip: mannySkip);
}
