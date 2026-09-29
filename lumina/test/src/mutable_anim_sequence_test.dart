import 'dart:math' as math;
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina/src/animation/keyframe_track.dart';

void main() {
  group('LuminaMutableAnimSequence & KeyframeTrack Tests', () {
    test('Keyframe insertion maintains sorted time order', () {
      final track = FloatCurveTrack(curveName: 'JumpHeight');
      track.setKey(1.0, 10.0);
      track.setKey(0.0, 0.0);
      track.setKey(0.5, 5.0);

      expect(track.keys.length, equals(3));
      expect(track.keys[0].timeSeconds, equals(0.0));
      expect(track.keys[1].timeSeconds, equals(0.5));
      expect(track.keys[2].timeSeconds, equals(1.0));
    });

    test('FloatCurveTrack linear evaluation returns correct midpoint', () {
      final track = FloatCurveTrack(curveName: 'Opacity');
      track.setKey(0.0, 0.0);
      track.setKey(1.0, 10.0);

      expect(track.evaluate(0.0), equals(0.0));
      expect(track.evaluate(0.5), closeTo(5.0, 1e-4));
      expect(track.evaluate(1.0), equals(10.0));
      expect(track.evaluate(1.5), equals(10.0)); // Clamped to last key
    });

    test('Cubic Hermite interpolation computes smooth curve with tangents', () {
      final track = FloatCurveTrack(
        curveName: 'Speed',
        interpolation: KeyframeInterpolation.cubic,
      );
      track.setKey(0.0, 0.0, outTangent: 0.0);
      track.setKey(1.0, 1.0, inTangent: 0.0);

      // Smooth S-curve: at t=0.5 value should be 0.5 with zero slope at endpoints
      expect(track.evaluate(0.5), closeTo(0.5, 0.01));
      // at t=0.25 Hermite S-curve value is 3*(0.25)^2 - 2*(0.25)^3 = 0.15625
      expect(track.evaluate(0.25), closeTo(0.15625, 0.01));
    });

    test('BoneTransformTrack evaluates translation, rotation, and scale matrices smoothly', () {
      final boneTrack = BoneTransformTrack(boneIndex: 0, boneName: 'root');
      boneTrack.setTranslationKey(0.0, Vector3(0, 0, 0));
      boneTrack.setTranslationKey(1.0, Vector3(0, 100, 0));

      boneTrack.setRotationKey(0.0, Quaternion.identity());
      boneTrack.setRotationKey(1.0, Quaternion.axisAngle(Vector3(0, 1, 0), math.pi / 2));

      final matAtHalf = boneTrack.evaluateLocalTransform(0.5);
      final pos = matAtHalf.getTranslation();
      expect(pos.y, closeTo(50.0, 1e-4));

      final rot = Quaternion.fromRotation(matAtHalf.getRotation());
      expect(rot.y, closeTo(math.sin(math.pi / 8), 0.05));
    });

    test('LuminaMutableAnimSequence updates pose and compiles to immutable LuminaAnimationClip', () {
      final seq = LuminaMutableAnimSequence(name: 'Hero_Walk', duration: 2.0, frameRate: 30.0);
      seq.setKeyframe(
        boneIndex: 0,
        boneName: 'root',
        time: 0.0,
        translation: Vector3(0, 0, 0),
        rotation: Quaternion.identity(),
      );
      seq.setKeyframe(
        boneIndex: 0,
        boneName: 'root',
        time: 2.0,
        translation: Vector3(0, 200, 0),
        rotation: Quaternion.identity(),
      );

      final outPose = [Matrix4.identity()];
      final outCurves = <String, double>{};
      seq.evaluatePose(1.0, outPose, outCurves);
      expect(outPose[0].getTranslation().y, closeTo(100.0, 1e-4));

      // Bake to immutable clip
      final clip = seq.toImmutableClip();
      expect(clip.name, equals('Hero_Walk'));
      expect(clip.duration, equals(2.0));
      expect(clip.tracks.length, equals(1));
      expect(clip.tracks.first.positions.length, equals(2));
    });
  });
}
