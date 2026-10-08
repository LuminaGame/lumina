import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

import 'ragdoll_fixture.dart';

double _angleDeg(Quaternion a, Quaternion b) {
  final d = (a.x * b.x + a.y * b.y + a.z * b.z + a.w * b.w).abs().clamp(0.0, 1.0);
  return 2 * math.acos(d) * 180 / math.pi;
}

void main() {
  group('ragdoll poser', () {
    test('the pose written from the bodies reproduces every body through the parent chain', () {
      final mesh = meshTransformAt(Vector3(0, 150, 0));
      final r = RagdollWorld(mesh);
      r.ragdoll.addImpulse(Vector3(300, 0, 900), bone: 'head');
      r.w.run(1.2);
      final targets = r.ragdoll.boneFrames();
      final meshAffine = LuminaRagdollSkeleton.affineOf(mesh);
      final poser = LuminaRagdollPoser(r.skeleton, targets.keys);
      final pose = copyPose(r.skeleton.restPose);
      poser.apply(pose, meshAffine, targets, 1.0);

      final world = Float64List(r.skeleton.length * 12);
      r.skeleton.world(pose, meshAffine, world);
      var worstAngle = 0.0, worstOffset = 0.0;
      for (final b in r.ragdoll.bodies) {
        final frame = LuminaRagdollSkeleton.frameOf(world, b.slot);
        worstAngle = math.max(worstAngle, _angleDeg(frame.rotation, targets[b.bone]!.rotation));
        final d = (frame.position - targets[b.bone]!.position).length;
        if (b.bone == 'pelvis') expect(d, lessThan(0.01));
        worstOffset = math.max(worstOffset, d);
        // The body the bone carries lands where the body is.
        final body = b.bodyFrameFor(frame);
        final (origin, _) = b.body.interpolatedOrigin(1.0);
        expect((body.position - origin).length, lessThan(r.ragdoll.maxJointError * 4 + 0.05), reason: b.bone);
      }
      expect(worstAngle, lessThan(0.1));
      // Bones keep their lengths: only the joints' separation shows.
      expect(worstOffset, lessThan(r.ragdoll.maxJointError * 4 + 0.05));
      r.dispose();
    });

    test('weight 0 leaves the animated pose, 0.5 goes halfway', () {
      final mesh = meshTransformAt(Vector3(0, 150, 0));
      final r = RagdollWorld(mesh);
      final meshAffine = LuminaRagdollSkeleton.affineOf(mesh);
      final poser = LuminaRagdollPoser(r.skeleton, ['pelvis']);
      final rest = poser.frames(r.skeleton.restPose, meshAffine)['pelvis']!;
      final turned = (position: rest.position + Vector3(0, -40, 0), rotation: Quaternion.axisAngle(Vector3(1, 0, 0), math.pi / 2) * rest.rotation);
      final zero = copyPose(r.skeleton.restPose);
      poser.apply(zero, meshAffine, {'pelvis': turned}, 0.0);
      expect(zero, r.skeleton.restPose);
      final half = copyPose(r.skeleton.restPose);
      poser.apply(half, meshAffine, {'pelvis': turned}, 0.5);
      final frame = poser.frames(half, meshAffine)['pelvis']!;
      expect(_angleDeg(frame.rotation, rest.rotation), closeTo(45, 0.01));
      expect(frame.position.y - rest.position.y, closeTo(-20, 0.01));
      r.dispose();
    });
  }, skip: mannySkip);
}
