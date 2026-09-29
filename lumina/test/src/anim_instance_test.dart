import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:lumina/lumina.dart';

void main() {
  group('LuminaAnimInstance State Machine and Blending', () {
    late LuminaSkinnedMeshComponent mesh;
    late Skeleton skeleton;
    late LuminaAnimationClip idleClip;
    late LuminaAnimationClip runClip;

    setUp(() {
      final bone0 = BoneNode(id: 0, name: 'Root', parentIndex: -1);
      final bone1 = BoneNode(id: 1, name: 'Spine', parentIndex: 0);
      skeleton = Skeleton([bone0, bone1]);

      mesh = LuminaSkinnedMeshComponent();
      mesh.setSkeleton(skeleton);

      idleClip = LuminaAnimationClip(
        name: 'idle',
        duration: 1.0,
        tracks: [
          BoneTrack(
            boneIndex: 0,
            times: [0.0, 1.0],
            positions: [Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.0, 0.0)],
          ),
          BoneTrack(
            boneIndex: 1,
            times: [0.0, 1.0],
            positions: [Vector3(0.0, 1.0, 0.0), Vector3(0.0, 1.0, 0.0)],
          ),
        ],
      );

      runClip = LuminaAnimationClip(
        name: 'run',
        duration: 1.0,
        tracks: [
          BoneTrack(
            boneIndex: 0,
            times: [0.0, 1.0],
            positions: [Vector3(2.0, 0.0, 0.0), Vector3(2.0, 0.0, 0.0)],
          ),
          BoneTrack(
            boneIndex: 1,
            times: [0.0, 1.0],
            positions: [Vector3(0.0, 1.5, 0.0), Vector3(0.0, 1.5, 0.0)],
          ),
        ],
      );
    });

    test('State machine transition triggers on condition and enters blending state', () {
      final states = [
        AnimState(name: 'idle', clip: idleClip),
        AnimState(name: 'run', clip: runClip),
      ];

      final transitions = [
        AnimTransition(
          from: 'idle',
          to: 'run',
          condition: (anim) => anim.getVariable('speed') > 0.5,
          blendDuration: 0.2,
        ),
      ];

      final anim = LuminaAnimInstance(
        mesh: mesh,
        states: states,
        transitions: transitions,
        initialState: 'idle',
      );

      anim.update(0.016);
      expect(anim.currentStateName, equals('idle'));
      expect(anim.isBlending, isFalse);

      anim.setVariable('speed', 1.0);
      anim.update(0.016);
      expect(anim.currentStateName, equals('run'));
      expect(anim.isBlending, isTrue);
    });

    test('Cross-fade math: idle (x=0) to run (x=2) over 0.2s yields x=1.0 at 0.1s and completes at 0.2s', () {
      final states = [
        AnimState(name: 'idle', clip: idleClip),
        AnimState(name: 'run', clip: runClip),
      ];

      final transitions = [
        AnimTransition(
          from: 'idle',
          to: 'run',
          condition: (anim) => anim.getVariable('speed') > 0.5,
          blendDuration: 0.2,
        ),
      ];

      final anim = LuminaAnimInstance(
        mesh: mesh,
        states: states,
        transitions: transitions,
        initialState: 'idle',
      );

      anim.setVariable('speed', 1.0);
      // First update starts the transition and advances 0.1s
      anim.update(0.1);
      expect(anim.isBlending, isTrue);
      expect(skeleton[0].localTransform.getTranslation().x, closeTo(1.0, 1e-5));

      // Second update completes the blend
      anim.update(0.1);
      expect(anim.isBlending, isFalse);
      expect(skeleton[0].localTransform.getTranslation().x, closeTo(2.0, 1e-5));
    });

    test('Target clip starts from time 0 upon transition', () {
      final asymRunClip = LuminaAnimationClip(
        name: 'asym_run',
        duration: 1.0,
        tracks: [
          BoneTrack(
            boneIndex: 0,
            times: [0.0, 1.0],
            positions: [Vector3(10.0, 0.0, 0.0), Vector3(20.0, 0.0, 0.0)],
          ),
        ],
      );

      final anim = LuminaAnimInstance(
        mesh: mesh,
        states: [
          AnimState(name: 'idle', clip: idleClip),
          AnimState(name: 'run', clip: asymRunClip),
        ],
        transitions: [
          AnimTransition(
            from: 'idle',
            to: 'run',
            condition: (anim) => anim.getVariable('trigger') > 0.0,
            blendDuration: 0.0, // instant switch
          ),
        ],
        initialState: 'idle',
      );

      // Idle runs for 0.5s
      anim.update(0.5);
      expect(anim.currentStateTime, closeTo(0.5, 1e-6));

      // Trigger run transition
      anim.setVariable('trigger', 1.0);
      anim.update(0.016);

      // Run state starts near 0 + dt, not at 0.5 + dt
      expect(anim.currentStateName, equals('run'));
      expect(anim.currentStateTime, closeTo(0.016, 1e-6));
    });

    test('playRate: 2.0 advances time at 2x; playRate: 0.0 freezes animation', () {
      final fastState = AnimState(name: 'fast', clip: idleClip, playRate: 2.0);
      final frozenState = AnimState(name: 'frozen', clip: idleClip, playRate: 0.0);

      final fastAnim = LuminaAnimInstance(
        mesh: mesh,
        states: [fastState],
        transitions: [],
        initialState: 'fast',
      );
      fastAnim.update(0.1);
      expect(fastAnim.currentStateTime, closeTo(0.2, 1e-6));

      final frozenAnim = LuminaAnimInstance(
        mesh: mesh,
        states: [frozenState],
        transitions: [],
        initialState: 'frozen',
      );
      frozenAnim.update(0.1);
      expect(frozenAnim.currentStateTime, closeTo(0.0, 1e-6));
    });

    test('Priority: lower priority value is evaluated first and wins', () {
      final anim = LuminaAnimInstance(
        mesh: mesh,
        states: [
          AnimState(name: 'idle', clip: idleClip),
          AnimState(name: 'walk', clip: idleClip),
          AnimState(name: 'run', clip: runClip),
        ],
        transitions: [
          AnimTransition(
            from: 'idle',
            to: 'run',
            condition: (anim) => true,
            priority: 10,
          ),
          AnimTransition(
            from: 'idle',
            to: 'walk',
            condition: (anim) => true,
            priority: 1, // higher precedence
          ),
        ],
        initialState: 'idle',
      );

      anim.update(0.016);
      expect(anim.currentStateName, equals('walk'));
    });

    test('Forward Kinematics global transforms are updated through parent chain after anim update', () {
      final anim = LuminaAnimInstance(
        mesh: mesh,
        states: [AnimState(name: 'run', clip: runClip)],
        transitions: [],
        initialState: 'run',
      );

      anim.update(0.1);

      // Bone0 local: (2.0, 0, 0)
      // Bone1 local: (0, 1.5, 0)
      // Bone1 global: Parent global (2.0, 0, 0) * Local (0, 1.5, 0) -> (2.0, 1.5, 0)
      final bone1Global = skeleton[1].globalTransform.getTranslation();
      expect(bone1Global.x, closeTo(2.0, 1e-5));
      expect(bone1Global.y, closeTo(1.5, 1e-5));
      expect(bone1Global.z, closeTo(0.0, 1e-5));
    });

    test('Determinism: two instances fed identical inputs produce identical localTransform buffers', () {
      final anim1 = LuminaAnimInstance(
        mesh: mesh,
        states: [
          AnimState(name: 'idle', clip: idleClip),
          AnimState(name: 'run', clip: runClip),
        ],
        transitions: [
          AnimTransition(
            from: 'idle',
            to: 'run',
            condition: (a) => a.getVariable('speed') > 0.5,
            blendDuration: 0.2,
          ),
        ],
        initialState: 'idle',
      );

      final mesh2 = LuminaSkinnedMeshComponent();
      final skel2 = Skeleton([
        BoneNode(id: 0, name: 'Root', parentIndex: -1),
        BoneNode(id: 1, name: 'Spine', parentIndex: 0),
      ]);
      mesh2.setSkeleton(skel2);

      final anim2 = LuminaAnimInstance(
        mesh: mesh2,
        states: [
          AnimState(name: 'idle', clip: idleClip),
          AnimState(name: 'run', clip: runClip),
        ],
        transitions: [
          AnimTransition(
            from: 'idle',
            to: 'run',
            condition: (a) => a.getVariable('speed') > 0.5,
            blendDuration: 0.2,
          ),
        ],
        initialState: 'idle',
      );

      for (int i = 0; i < 100; i++) {
        final speed = (i > 30 && i < 70) ? 1.0 : 0.0;
        anim1.setVariable('speed', speed);
        anim2.setVariable('speed', speed);
        anim1.update(0.016);
        anim2.update(0.016);

        for (int b = 0; b < 2; b++) {
          for (int m = 0; m < 16; m++) {
            expect(
              skeleton[b].localTransform.storage[m],
              equals(skel2[b].localTransform.storage[m]),
            );
          }
        }
      }
    });
  });
}
