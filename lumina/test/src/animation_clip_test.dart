import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:lumina/lumina.dart';
import 'dart:math' as math;

void main() {
  group('LuminaAnimationClip and BoneTrack Sampling', () {
    test('Clip sampling: 1-bone track (t=0 -> x=0, t=1 -> x=2) at t=0.5, t=1.5 looping/non-looping', () {
      final track = BoneTrack(
        boneIndex: 0,
        times: [0.0, 1.0],
        positions: [Vector3(0.0, 0.0, 0.0), Vector3(2.0, 0.0, 0.0)],
      );

      final clip = LuminaAnimationClip(
        name: 'test_clip',
        duration: 1.0,
        tracks: [track],
      );

      final outPose = [Matrix4.identity()];

      // t = 0.5 -> x = 1.0
      clip.samplePose(0.5, outPose, looping: true);
      expect(outPose[0].getTranslation().x, closeTo(1.0, 1e-6));

      // t = 1.5 with looping -> x = 1.0
      clip.samplePose(1.5, outPose, looping: true);
      expect(outPose[0].getTranslation().x, closeTo(1.0, 1e-6));

      // t = 1.5 non-looping -> clamped x = 2.0
      clip.samplePose(1.5, outPose, looping: false);
      expect(outPose[0].getTranslation().x, closeTo(2.0, 1e-6));
    });

    test('Rotation shortest path: 170 deg and -170 deg yaw sampled midway gives 180 deg (not 0 deg)', () {
      // 170 deg around Y
      final q170 = Quaternion.axisAngle(Vector3(0.0, 1.0, 0.0), 170.0 * math.pi / 180.0);
      // -170 deg around Y (same as +190 deg)
      final qMinus170 = Quaternion.axisAngle(Vector3(0.0, 1.0, 0.0), -170.0 * math.pi / 180.0);

      final track = BoneTrack(
        boneIndex: 0,
        times: [0.0, 1.0],
        rotations: [q170, qMinus170],
      );

      final clip = LuminaAnimationClip(
        name: 'yaw_clip',
        duration: 1.0,
        tracks: [track],
      );

      final outPose = [Matrix4.identity()];
      clip.samplePose(0.5, outPose);

      final rotMatrix = outPose[0].getRotation();
      final sampledRot = Quaternion.fromRotation(rotMatrix);

      // Rotating vector (1, 0, 0) by 180 deg around Y should give (-1, 0, 0)
      final rotatedVec = sampledRot.rotate(Vector3(1.0, 0.0, 0.0));
      expect(rotatedVec.x, closeTo(-1.0, 1e-5));
      expect(rotatedVec.z, closeTo(0.0, 1e-5));
    });

    test('Empty channel: a track with rotations only leaves the bone bind translation untouched', () {
      final q = Quaternion.axisAngle(Vector3(0.0, 1.0, 0.0), math.pi / 4.0);
      final track = BoneTrack(
        boneIndex: 0,
        times: [0.0, 1.0],
        rotations: [q, q],
      );

      final clip = LuminaAnimationClip(
        name: 'rot_only',
        duration: 1.0,
        tracks: [track],
      );

      // Pre-populate outPose with bind translation (5.0, 10.0, 15.0)
      final outPose = [Matrix4.translationValues(5.0, 10.0, 15.0)];
      clip.samplePose(0.5, outPose);

      final trans = outPose[0].getTranslation();
      expect(trans.x, closeTo(5.0, 1e-6));
      expect(trans.y, closeTo(10.0, 1e-6));
      expect(trans.z, closeTo(15.0, 1e-6));
    });
  });
}
