import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:lumina/lumina.dart';

void main() {
  group('LuminaAnimMontage and Slot Blending', () {
    late LuminaSkinnedMeshComponent mesh;
    late Skeleton skeleton;
    late LuminaAnimationClip baseClip;
    late LuminaAnimationClip attackClip;

    setUp(() {
      final bone0 = BoneNode(id: 0, name: 'Root', parentIndex: -1);
      final bone1 = BoneNode(id: 1, name: 'Arm', parentIndex: 0);
      skeleton = Skeleton([bone0, bone1]);

      mesh = LuminaSkinnedMeshComponent();
      mesh.setSkeleton(skeleton);

      baseClip = LuminaAnimationClip(
        name: 'idle_base',
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

      attackClip = LuminaAnimationClip(
        name: 'slash',
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
            positions: [Vector3(0.0, 3.0, 0.0), Vector3(0.0, 3.0, 0.0)],
          ),
        ],
      );
    });

    test('montagePlay on 1.0s clip returns duration, isMontagePlaying == true, default section', () {
      final anim = LuminaAnimInstance(
        mesh: mesh,
        states: [AnimState(name: 'idle', clip: baseClip)],
        transitions: [],
        initialState: 'idle',
      );

      final montage = LuminaAnimMontage(
        name: 'attack_montage',
        clip: attackClip,
      );

      final len1 = anim.montagePlay(montage);
      expect(len1, equals(1.0));
      expect(anim.isMontagePlaying, isTrue);
      expect(anim.currentMontageSection, equals('default'));

      final len2 = anim.montagePlay(montage, playRate: 2.0);
      expect(len2, equals(0.5));
    });

    test('Blend-in weight: base (x=0) to montage (x=2) with blendInTime 0.2s yields x=1.0 at 0.1s and x=2.0 at 0.2s', () {
      final anim = LuminaAnimInstance(
        mesh: mesh,
        states: [AnimState(name: 'idle', clip: baseClip)],
        transitions: [],
        initialState: 'idle',
      );

      final montage = LuminaAnimMontage(
        name: 'attack_montage',
        clip: attackClip,
        blendInTime: 0.2,
        blendOutTime: 0.2,
      );

      anim.montagePlay(montage);

      // After 0.1s: half weight (1.0)
      anim.update(0.1);
      expect(skeleton[0].localTransform.getTranslation().x, closeTo(1.0, 1e-5));

      // After 0.2s: full weight (2.0)
      anim.update(0.1);
      expect(skeleton[0].localTransform.getTranslation().x, closeTo(2.0, 1e-5));
    });

    test('Base pose keeps running underneath during montage playback', () {
      final movingBaseClip = LuminaAnimationClip(
        name: 'moving_base',
        duration: 2.0,
        tracks: [
          BoneTrack(
            boneIndex: 0,
            times: [0.0, 2.0],
            positions: [Vector3(0.0, 0.0, 0.0), Vector3(10.0, 0.0, 0.0)],
          ),
        ],
      );

      final anim = LuminaAnimInstance(
        mesh: mesh,
        states: [AnimState(name: 'walk', clip: movingBaseClip)],
        transitions: [],
        initialState: 'walk',
      );

      final montage = LuminaAnimMontage(
        name: 'quick_hit',
        clip: attackClip,
        blendInTime: 0.1,
        blendOutTime: 0.1,
      );

      anim.montagePlay(montage);

      // Tick 0.5s into montage
      anim.update(0.5);
      expect(anim.currentStateTime, closeTo(0.5, 1e-5));

      // Let montage complete (total 1.0s)
      anim.update(0.5);
      expect(anim.isMontagePlaying, isFalse);

      // At t=1.0s, base clip has advanced to halfway: x = 5.0
      expect(skeleton[0].localTransform.getTranslation().x, closeTo(5.0, 1e-5));
    });

    test('Notifies at t=0.30 and t=0.35 with single dt=0.10 from pos 0.28 fire in order', () {
      final fired = <String>[];

      final montage = LuminaAnimMontage(
        name: 'notify_montage',
        clip: attackClip,
        notifies: [
          AnimNotify(name: 'HitWindowStart', time: 0.30, callback: (_) => fired.add('start')),
          AnimNotify(name: 'HitDamage', time: 0.35, callback: (_) => fired.add('damage')),
        ],
      );

      final anim = LuminaAnimInstance(
        mesh: mesh,
        states: [AnimState(name: 'idle', clip: baseClip)],
        transitions: [],
        initialState: 'idle',
      );

      anim.montagePlay(montage);

      // Advance to 0.28s
      anim.update(0.28);
      expect(fired, isEmpty);

      // Single large step 0.10s -> advances to 0.38s crossing both notifies
      anim.update(0.10);
      expect(fired, equals(['start', 'damage']));
    });

    test('Sections [start@0.0 -> combo@0.4 -> null] and runtime rewiring to loop in start', () {
      final montage = LuminaAnimMontage(
        name: 'combo_montage',
        clip: attackClip,
        sections: [
          MontageSection(name: 'start', startTime: 0.0, nextSection: 'combo'),
          MontageSection(name: 'combo', startTime: 0.4, nextSection: null),
        ],
      );

      final anim = LuminaAnimInstance(
        mesh: mesh,
        states: [AnimState(name: 'idle', clip: baseClip)],
        transitions: [],
        initialState: 'idle',
      );

      anim.montagePlay(montage);
      expect(anim.currentMontageSection, equals('start'));

      // Rewire start to loop back to start
      anim.montageSetNextSection('start', 'start');

      // Update past 0.4s
      anim.update(0.45);
      // Wrapped back into start section
      expect(anim.currentMontageSection, equals('start'));
      expect(anim.montagePosition, closeTo(0.05, 1e-4));
    });

    test('montageJumpToSection jumps position without firing skipped notifies', () {
      final fired = <String>[];

      final montage = LuminaAnimMontage(
        name: 'jump_montage',
        clip: attackClip,
        sections: [
          MontageSection(name: 'start', startTime: 0.0, nextSection: 'combo'),
          MontageSection(name: 'combo', startTime: 0.4, nextSection: null),
        ],
        notifies: [
          AnimNotify(name: 'SkippedNotify', time: 0.3, callback: (_) => fired.add('skipped')),
        ],
      );

      final anim = LuminaAnimInstance(
        mesh: mesh,
        states: [AnimState(name: 'idle', clip: baseClip)],
        transitions: [],
        initialState: 'idle',
      );

      anim.montagePlay(montage);
      anim.update(0.1);

      // Jump to combo section at 0.4s
      anim.montageJumpToSection('combo');
      expect(anim.montagePosition, equals(0.4));
      expect(anim.currentMontageSection, equals('combo'));

      anim.update(0.05);
      expect(fired, isEmpty); // skipped notify did not fire
    });

    test('Natural end: onMontageBlendingOut and onMontageEnded fire with interrupted: false', () {
      bool blendingOutFired = false;
      bool endedFired = false;
      bool blendingOutInterrupted = true;
      bool endedInterrupted = true;

      final montage = LuminaAnimMontage(
        name: 'short_montage',
        clip: attackClip,
        blendInTime: 0.1,
        blendOutTime: 0.2,
      );

      final anim = LuminaAnimInstance(
        mesh: mesh,
        states: [AnimState(name: 'idle', clip: baseClip)],
        transitions: [],
        initialState: 'idle',
      );

      anim.onMontageBlendingOut = (m, interrupted) {
        blendingOutFired = true;
        blendingOutInterrupted = interrupted;
      };
      anim.onMontageEnded = (m, interrupted) {
        endedFired = true;
        endedInterrupted = interrupted;
      };

      anim.montagePlay(montage);

      // Advance to 0.75s (duration is 1.0s, blendOutTime is 0.2s -> auto blendOut starts at 0.8s)
      anim.update(0.75);
      expect(blendingOutFired, isFalse);

      // Cross 0.8s
      anim.update(0.1);
      expect(blendingOutFired, isTrue);
      expect(blendingOutInterrupted, isFalse);
      expect(endedFired, isFalse);

      // Complete blend out (to 1.0s)
      anim.update(0.2);
      expect(endedFired, isTrue);
      expect(endedInterrupted, isFalse);
      expect(anim.isMontagePlaying, isFalse);
    });

    test('montageStop at full weight ramps weight to 0 with interrupted: true', () {
      bool endedInterrupted = false;

      final montage = LuminaAnimMontage(
        name: 'stop_montage',
        clip: attackClip,
        blendInTime: 0.1,
        blendOutTime: 0.2,
      );

      final anim = LuminaAnimInstance(
        mesh: mesh,
        states: [AnimState(name: 'idle', clip: baseClip)],
        transitions: [],
        initialState: 'idle',
      );

      anim.onMontageEnded = (m, interrupted) {
        endedInterrupted = interrupted;
      };

      anim.montagePlay(montage);
      anim.update(0.2); // full weight (x=2.0)

      anim.montageStop();
      // Midpoint of blend out (0.1s of 0.2s)
      anim.update(0.1);
      expect(skeleton[0].localTransform.getTranslation().x, closeTo(1.0, 1e-4));

      // Finish blend out
      anim.update(0.15);
      expect(endedInterrupted, isTrue);
      expect(anim.isMontagePlaying, isFalse);
    });

    test('Playing montage B while A is active interrupts A immediately', () {
      final events = <String>[];

      final montageA = LuminaAnimMontage(name: 'MontageA', clip: attackClip);
      final montageB = LuminaAnimMontage(name: 'MontageB', clip: attackClip);

      final anim = LuminaAnimInstance(
        mesh: mesh,
        states: [AnimState(name: 'idle', clip: baseClip)],
        transitions: [],
        initialState: 'idle',
      );

      anim.onMontageEnded = (m, interrupted) {
        events.add('${m.name}_ended_interrupted_$interrupted');
      };

      anim.montagePlay(montageA);
      anim.update(0.3);

      anim.montagePlay(montageB);
      expect(events, equals(['MontageA_ended_interrupted_true']));
      expect(anim.isMontagePlaying, isTrue);
    });
  });
}
