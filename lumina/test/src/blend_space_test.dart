import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:lumina/lumina.dart';

class CountingAnimationClip extends LuminaAnimationClip {
  int sampleCount = 0;

  CountingAnimationClip({
    required super.name,
    required super.duration,
    required super.tracks,
  });

  @override
  void samplePose(
    double time,
    List<Matrix4> outLocalPose, {
    bool looping = true,
    double weight = 1.0,
  }) {
    sampleCount++;
    super.samplePose(time, outLocalPose, looping: looping, weight: weight);
  }
}

void main() {
  group('LuminaBlendSpace1D and 2D Parametric Animation', () {
    late CountingAnimationClip idleClip;
    late CountingAnimationClip walkClip;
    late CountingAnimationClip runClip;

    setUp(() {
      idleClip = CountingAnimationClip(
        name: 'idle',
        duration: 2.0,
        tracks: [
          BoneTrack(
            boneIndex: 0,
            times: [0.0, 2.0],
            positions: [Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.0, 0.0)],
          ),
        ],
      );

      walkClip = CountingAnimationClip(
        name: 'walk',
        duration: 1.0,
        tracks: [
          BoneTrack(
            boneIndex: 0,
            times: [0.0, 1.0],
            positions: [Vector3(2.0, 0.0, 0.0), Vector3(2.0, 0.0, 0.0)],
          ),
        ],
      );

      runClip = CountingAnimationClip(
        name: 'run',
        duration: 0.5,
        tracks: [
          BoneTrack(
            boneIndex: 0,
            times: [0.0, 0.5],
            positions: [Vector3(6.0, 0.0, 0.0), Vector3(6.0, 0.0, 0.0)],
          ),
        ],
      );
    });

    test('1D [idle@0, walk@2, run@6], param 1.0 -> weights {idle: 0.5, walk: 0.5}, run is never sampled', () {
      final bs1d = LuminaBlendSpace1D(
        samples: [
          BlendSample(idleClip, 0.0),
          BlendSample(walkClip, 2.0),
          BlendSample(runClip, 6.0),
        ],
        minAxis: 0.0,
        maxAxis: 6.0,
      );

      bs1d.setParameter(1.0);
      bs1d.advance(0.0);

      final pose = [Matrix4.identity()];
      bs1d.samplePhase(0.0, pose);

      expect(idleClip.sampleCount, equals(1));
      expect(walkClip.sampleCount, equals(1));
      expect(runClip.sampleCount, equals(0)); // Run is 0 weight, not sampled
    });

    test('1D parameter clamping and boundary evaluations', () {
      final bs1d = LuminaBlendSpace1D(
        samples: [
          BlendSample(idleClip, 0.0),
          BlendSample(walkClip, 2.0),
          BlendSample(runClip, 6.0),
        ],
        minAxis: 0.0,
        maxAxis: 6.0,
      );

      // Parameter 2.0 exact -> walk weight 1.0
      bs1d.setParameter(2.0);
      bs1d.advance(0.0);
      expect(bs1d.sampleWeights[1], equals(1.0));
      expect(bs1d.sampleWeights[0], equals(0.0));
      expect(bs1d.sampleWeights[2], equals(0.0));

      // Parameter 4.0 -> walk 0.5, run 0.5
      bs1d.setParameter(4.0);
      bs1d.advance(0.0);
      expect(bs1d.sampleWeights[1], equals(0.5));
      expect(bs1d.sampleWeights[2], equals(0.5));

      // Parameter 9.0 -> clamped to 6.0 (run weight 1.0)
      bs1d.setParameter(9.0);
      bs1d.advance(0.0);
      expect(bs1d.sampleWeights[2], equals(1.0));

      // Parameter -1.0 -> clamped to 0.0 (idle weight 1.0)
      bs1d.setParameter(-1.0);
      bs1d.advance(0.0);
      expect(bs1d.sampleWeights[0], equals(1.0));
    });

    test('1D pose math: idle (x=0) and walk (x=2) at param 1.0 yields local x == 1.0', () {
      final bs1d = LuminaBlendSpace1D(
        samples: [
          BlendSample(idleClip, 0.0),
          BlendSample(walkClip, 2.0),
        ],
        minAxis: 0.0,
        maxAxis: 2.0,
      );

      bs1d.setParameter(1.0);
      bs1d.advance(0.0);

      final pose = [Matrix4.identity()];
      bs1d.samplePhase(0.5, pose);

      expect(pose[0].getTranslation().x, closeTo(1.0, 1e-6));
    });

    test('Phase sync: idle dur 2.0s, walk dur 1.0s, weights 0.5/0.5 -> phaseDuration == 1.5s', () {
      final bs1d = LuminaBlendSpace1D(
        samples: [
          BlendSample(idleClip, 0.0),
          BlendSample(walkClip, 2.0),
        ],
        minAxis: 0.0,
        maxAxis: 2.0,
      );

      bs1d.setParameter(1.0);
      bs1d.advance(0.0);

      expect(bs1d.phaseDuration, closeTo(1.5, 1e-6));

      // Advance by 0.75s -> phase == 0.5
      bs1d.advance(0.75);
      expect(bs1d.normalizedPhase, closeTo(0.5, 1e-6));
    });

    test('Parameter interpolation smoothing: interpolationTime 0.5s', () {
      final bs1d = LuminaBlendSpace1D(
        samples: [
          BlendSample(idleClip, 0.0),
          BlendSample(runClip, 6.0),
        ],
        minAxis: 0.0,
        maxAxis: 6.0,
        interpolationTime: 0.5,
      );

      bs1d.setParameter(6.0);
      bs1d.advance(0.1);
      // current moves: 0 + (6 - 0) * (0.1 / 0.5) = 1.2
      expect(bs1d.currentParameter, closeTo(1.2, 1e-5));

      // Advance multiple steps to accumulate >= 0.5s of dt
      for (int i = 0; i < 50; i++) {
        bs1d.advance(0.05);
      }
      expect(bs1d.currentParameter, closeTo(6.0, 0.05));
    });

    test('Constructor validation: empty samples, duplicate x, minAxis >= maxAxis', () {
      expect(
        () => LuminaBlendSpace1D(samples: [], minAxis: 0, maxAxis: 1),
        throwsArgumentError,
      );

      expect(
        () => LuminaBlendSpace1D(
          samples: [BlendSample(idleClip, 1.0), BlendSample(walkClip, 1.0)],
          minAxis: 0,
          maxAxis: 2,
        ),
        throwsArgumentError,
      );

      expect(
        () => LuminaBlendSpace1D(
          samples: [BlendSample(idleClip, 0.0)],
          minAxis: 5,
          maxAxis: 2,
        ),
        throwsArgumentError,
      );
    });

    test('2D 4-corner setup: corners of [-1,1]^2', () {
      final c00 = CountingAnimationClip(name: 'c00', duration: 1.0, tracks: []);
      final c10 = CountingAnimationClip(name: 'c10', duration: 1.0, tracks: []);
      final c01 = CountingAnimationClip(name: 'c01', duration: 1.0, tracks: []);
      final c11 = CountingAnimationClip(name: 'c11', duration: 1.0, tracks: []);

      final bs2d = LuminaBlendSpace2D(
        samples: [
          BlendSample(c00, -1.0, -1.0),
          BlendSample(c10, 1.0, -1.0),
          BlendSample(c01, -1.0, 1.0),
          BlendSample(c11, 1.0, 1.0),
        ],
        minAxis: Vector2(-1.0, -1.0),
        maxAxis: Vector2(1.0, 1.0),
      );

      // (0,0) center -> 4 equal weights (0.25 each)
      bs2d.setParameters(0.0, 0.0);
      bs2d.advance(0.0);
      for (final w in bs2d.sampleWeights) {
        expect(w, closeTo(0.25, 1e-4));
      }

      // (1,1) corner -> c11 weight == 1.0
      bs2d.setParameters(1.0, 1.0);
      bs2d.advance(0.0);
      expect(bs2d.sampleWeights[3], closeTo(1.0, 1e-4));

      // (1,0) right edge -> c10 and c11 each 0.5
      bs2d.setParameters(1.0, 0.0);
      bs2d.advance(0.0);
      expect(bs2d.sampleWeights[1], closeTo(0.5, 1e-4));
      expect(bs2d.sampleWeights[3], closeTo(0.5, 1e-4));
    });

    test('2D grid bake determinism and weight sum normalization across 5x5 sweep', () {
      final c00 = CountingAnimationClip(name: 'c00', duration: 1.0, tracks: []);
      final c10 = CountingAnimationClip(name: 'c10', duration: 1.0, tracks: []);
      final c01 = CountingAnimationClip(name: 'c01', duration: 1.0, tracks: []);
      final c11 = CountingAnimationClip(name: 'c11', duration: 1.0, tracks: []);

      final samples = [
        BlendSample(c00, -1.0, -1.0),
        BlendSample(c10, 1.0, -1.0),
        BlendSample(c01, -1.0, 1.0),
        BlendSample(c11, 1.0, 1.0),
      ];

      final bs1 = LuminaBlendSpace2D(samples: samples, minAxis: Vector2(-1, -1), maxAxis: Vector2(1, 1));
      final bs2 = LuminaBlendSpace2D(samples: samples, minAxis: Vector2(-1, -1), maxAxis: Vector2(1, 1));

      for (double x = -1.0; x <= 1.0; x += 0.5) {
        for (double y = -1.0; y <= 1.0; y += 0.5) {
          bs1.setParameters(x, y);
          bs2.setParameters(x, y);
          bs1.advance(0.0);
          bs2.advance(0.0);

          double sum = 0.0;
          for (int i = 0; i < 4; i++) {
            expect(bs1.sampleWeights[i], equals(bs2.sampleWeights[i]));
            sum += bs1.sampleWeights[i];
          }
          expect(sum, closeTo(1.0, 1e-8));
        }
      }
    });

    test('State machine integration: AnimState backed by LuminaBlendSpace1D', () {
      final bone0 = BoneNode(id: 0, name: 'Root', parentIndex: -1);
      final skeleton = Skeleton([bone0]);
      final mesh = LuminaSkinnedMeshComponent()..setSkeleton(skeleton);

      final bs1d = LuminaBlendSpace1D(
        samples: [
          BlendSample(idleClip, 0.0),
          BlendSample(walkClip, 2.0),
        ],
        minAxis: 0.0,
        maxAxis: 2.0,
      );

      final anim = LuminaAnimInstance(
        mesh: mesh,
        states: [
          AnimState(name: 'locomotion', poseSource: bs1d),
        ],
        transitions: [],
        initialState: 'locomotion',
      );

      bs1d.setParameter(1.0);
      anim.update(0.1);

      expect(skeleton[0].localTransform.getTranslation().x, closeTo(1.0, 1e-5));
    });
  });
}
