import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

import 'anim_blueprints.dart';
import 'anim_rig.dart';

/// What `LuminaAnimBlueprintInstance` adds for the full
/// movement set — random-clip poses, one-shot clips with the reserved
/// `ClipFinished` / `StateTime` variables (and the transition properties that
/// gate on them), and the planted-feet root yaw offset that turn-in-place
/// clips unwind through `rootYawDegrees`.
void main() {
  LuminaBlueprintGraph always() => LuminaBlueprintGraph(nodes: [
        LuminaBlueprintNodeLibrary.place(LuminaBlueprintNodeLibrary.transitionResult,
            nodeId: 'result', literals: {'can_enter': true}),
      ]);
  LuminaBlueprintGraph flag(String variable) => LuminaBlueprintGraph(
        nodes: [
          LuminaBlueprintNodeLibrary.place(LuminaBlueprintNodeLibrary.variableGet, nodeId: 'flag', literals: {'variable': variable}),
          LuminaBlueprintNodeLibrary.place(LuminaBlueprintNodeLibrary.transitionResult, nodeId: 'result'),
        ],
        wires: [LuminaBlueprintWire(id: 'w0', fromNodeId: 'flag', fromPinId: 'value', toNodeId: 'result', toPinId: 'can_enter')],
      );
  const reserved = [
    LuminaBlueprintVariable(name: LuminaAnimBlueprintInstance.stateTimeVariable, typeName: 'Float', defaultValue: 0.0),
    LuminaBlueprintVariable(name: LuminaAnimBlueprintInstance.clipFinishedVariable, typeName: 'Bool', defaultValue: false),
    LuminaBlueprintVariable(name: LuminaAnimBlueprintInstance.rootYawOffsetVariable, typeName: 'Float', defaultValue: 0.0),
  ];

  /// Idle (loops, 1 s) → Break (one of three idle breaks, 0.5 s, once) on
  /// ClipFinished → Idle on ClipFinished.
  LuminaAnimBlueprintClass breakClass() => LuminaAnimBlueprintClass.fromDocument(
        LuminaAnimBlueprintDocument(variables: reserved.toList(), stateMachines: [
          LuminaAnimStateMachine(name: 'Locomotion', entryState: 'Idle', states: [
            const LuminaAnimState('Idle', LuminaAnimPose.clip('Idle_Loop')),
            LuminaAnimState('Break', LuminaAnimPose.randomClip(['Idle_Talking_Loop', 'Idle_FoldArms_Loop', 'Yes'])),
          ], transitions: [
            LuminaAnimTransition(id: 'idle_to_break', from: 'Idle', to: 'Break', rule: flag('ClipFinished')),
            LuminaAnimTransition(id: 'break_to_idle', from: 'Break', to: 'Idle', rule: flag('ClipFinished')),
          ]),
        ]),
        name: 'ABP_Breaks',
      );
  const durations = {'Idle_Loop': 1.0, 'Idle_Talking_Loop': 0.5, 'Idle_FoldArms_Loop': 0.5, 'Yes': 0.5};

  /// A rig whose instance knows [clipDurations] (and a seeded random) from
  /// the first tick — an unknown length counts as finished at once.
  AnimRig rig(LuminaAnimBlueprintClass cls, {Map<String, double> clipDurations = templateClipDurations, int? seed}) =>
      AnimRig.abp((mesh) {
        final instance = cls.instantiate(mesh)..clipDurationFallbacks.addAll(clipDurations);
        if (seed != null) instance.random = math.Random(seed);
        return instance;
      });

  group('random clip pose', () {
    test('the document round-trips the random set, loop, rootYaw and plantsFeet through JSON', () {
      final pose = LuminaAnimPose.randomClip(['Idle_Talking_Loop', 'Idle_FoldArms_Loop'], rootYawDegrees: 90, plantsFeet: true);
      expect(pose.kind, LuminaAnimPoseKind.clip);
      expect(pose.clip, 'Idle_Talking_Loop', reason: 'a reader that knows one clip sees the first');
      expect(pose.isRandom, isTrue);
      expect(pose.loop, isFalse, reason: 'idle breaks play once by default');
      final back = LuminaAnimPose.fromJson(pose.toJson());
      expect(back.clips, ['Idle_Talking_Loop', 'Idle_FoldArms_Loop']);
      expect(back.loop, isFalse);
      expect(back.rootYawDegrees, 90.0);
      expect(back.plantsFeet, isTrue);
      expect(back.toJson(), pose.toJson());
      const plain = LuminaAnimPose.clip('Jump_Start', loop: false);
      expect(LuminaAnimPose.fromJson(plain.toJson()).loop, isFalse);
      expect(plain.candidates, ['Jump_Start']);
      expect(const LuminaAnimPose.clip('Idle_Loop').isRandom, isFalse);
      final t = LuminaAnimTransition(id: 't', from: 'A', to: 'B', minStateTime: 0.4, automaticRule: true);
      final tb = LuminaAnimTransition.fromJson(t.toJson());
      expect((tb.minStateTime, tb.automaticRule), (0.4, true));
    });

    test('a seeded instance picks the same idle break every run; other seeds pick others', () {
      final cls = breakClass();
      expect(cls.diagnostics, isEmpty, reason: '${cls.diagnostics}');
      String pick(int seed) {
        final r = rig(cls, clipDurations: durations, seed: seed);
        r.walk(Vector3.zero(), 45); // 1.25 s in all: inside the break after the 1 s idle cycle
        expect(r.anim!.currentState, 'Break');
        expect(r.mesh.currentClip, isIn(['Idle_Talking_Loop', 'Idle_FoldArms_Loop', 'Yes']));
        expect(r.mesh.currentClip, r.anim!.currentStateClip);
        expect(r.mesh.oneShots, [r.mesh.currentClip], reason: 'the break plays once');
        return r.mesh.currentClip!;
      }

      expect(pick(3), pick(3));
      expect({for (var seed = 0; seed < 12; seed++) pick(seed)}.length, greaterThan(1));
    });

    test('ClipFinished turns true after the break; the instance is back in Idle for the next cycle', () {
      final r = rig(breakClass(), clipDurations: durations, seed: 1);
      // The rig already stood 0.5 s; the idle cycle ends at 1 s.
      r.walk(Vector3.zero(), 29);
      expect(r.anim!.currentState, 'Idle');
      expect(r.anim!.clipFinished, isFalse);
      expect(r.anim!.variables['ClipFinished'], isFalse);
      expect(r.anim!.stateTimeRemaining, closeTo(1.0 - 59 / 60, 1e-9));
      r.walk(Vector3.zero(), 1);
      expect(r.anim!.variables['ClipFinished'], isTrue, reason: 'what the rules read this tick: 1 s of the 1 s idle');
      expect(r.anim!.currentState, 'Break', reason: 'taken the tick the clip finished');
      expect(r.anim!.stateTime, 0.0);
      expect(r.anim!.clipFinished, isFalse);
      r.walk(Vector3.zero(), 29);
      expect(r.anim!.currentState, 'Break');
      expect(r.anim!.clipFinished, isFalse);
      expect(r.anim!.stateTimeRemaining, closeTo(1 / 60, 1e-9));
      r.walk(Vector3.zero(), 1);
      expect(r.anim!.variables['StateTime'], closeTo(0.5, 1e-9));
      expect(r.anim!.variables['ClipFinished'], isTrue, reason: '0.5 s of a 0.5 s clip');
      expect(r.anim!.currentState, 'Idle');
      expect(r.anim!.stateTime, 0.0);
      expect(r.mesh.currentClip, 'Idle_Loop');
      expect(r.mesh.oneShots.length, 1);
    });

    test('a clip of unknown length counts as finished at once; a blend space never does', () {
      final r = rig(breakClass(), clipDurations: const {'Idle_Talking_Loop': 9.0, 'Idle_FoldArms_Loop': 9.0, 'Yes': 9.0});
      expect(r.anim!.currentState, 'Break', reason: 'Idle_Loop has no known length');
      expect(r.anim!.stateTime, closeTo(29 / 60, 1e-9), reason: 'left Idle on the first tick');
      expect(r.anim!.stateTimeRemaining, closeTo(9.0 - 29 / 60, 1e-9));
      final manny = AnimRig.abp(templateAnimClass().factory);
      manny.walk(Vector3(0, 0, -1), 60);
      expect(manny.anim!.currentState, 'Walk');
      expect(manny.anim!.clipFinished, isFalse);
      expect(manny.anim!.stateTimeRemaining, isNull);
    });
  });

  group('transition properties', () {
    test('automaticRule waits for the clip, minStateTime holds the state, and neither trips the validator', () {
      final doc = LuminaAnimBlueprintDocument(stateMachines: [
        LuminaAnimStateMachine(name: 'Locomotion', entryState: 'A', states: const [
          LuminaAnimState('A', LuminaAnimPose.clip('Jump_Start', loop: false)),
          LuminaAnimState('B', LuminaAnimPose.clip('Idle_Loop')),
        ], transitions: [
          LuminaAnimTransition(id: 'a_to_b', from: 'A', to: 'B', automaticRule: true, rule: always()),
          LuminaAnimTransition(id: 'b_to_a', from: 'B', to: 'A', minStateTime: 1.0, rule: always()),
        ]),
      ]);
      final cls = LuminaAnimBlueprintClass.fromDocument(doc, name: 'ABP_Auto');
      expect(cls.diagnostics, isEmpty, reason: '${cls.diagnostics}');
      // Without automaticRule an unconnected Result still warns.
      final unconnected = LuminaAnimTransition(id: 'x', from: 'A', to: 'B', rule: LuminaBlueprintGraph(nodes: [
        LuminaBlueprintNodeLibrary.place(LuminaBlueprintNodeLibrary.transitionResult, nodeId: 'result'),
      ]));
      final warned = validateAnimBlueprint(LuminaAnimBlueprintDocument(stateMachines: [
        LuminaAnimStateMachine(name: 'L', entryState: 'A', states: doc.stateMachine!.states, transitions: [unconnected]),
      ]));
      expect(warned.map((d) => d.message), contains(contains('can never be taken')));

      final r = rig(cls, clipDurations: const {'Jump_Start': 0.6});
      // The rig stood 0.5 s of the 0.6 s clip.
      expect(r.anim!.currentState, 'A');
      expect(r.mesh.oneShots, ['Jump_Start']);
      r.walk(Vector3.zero(), 5);
      expect(r.anim!.currentState, 'A');
      r.walk(Vector3.zero(), 1);
      expect(r.anim!.currentState, 'B');
      r.walk(Vector3.zero(), 59);
      expect(r.anim!.currentState, 'B', reason: 'held for minStateTime');
      r.walk(Vector3.zero(), 1);
      expect(r.anim!.currentState, 'A');
      expect(r.mesh.oneShots, ['Jump_Start', 'Jump_Start']);
    });
  });

  group('root yaw', () {
    /// Where the mesh faces in the world (its authored +Z, drawn as the
    /// owner's forward), on the ground plane.
    Vector3 facing(RecordingMesh mesh) {
      final f = mesh.worldTransform.getRotation().transformed(Vector3(0.0, 0.0, 1.0));
      return Vector3(f.x, 0.0, f.z).normalized();
    }

    void turnBy(AnimRig r, double yawDegrees) {
      final e = luminaPawnQuaternionToEuler(r.character.actorRotation);
      r.character.actorRotation = luminaPawnEulerToQuaternion(e.x, e.y + yawDegrees, e.z);
    }

    test('a planted idle keeps facing where it was while the pawn turns right; RootYawOffset reads −100', () {
      final r = rig(turningAnimClass(), clipDurations: turningClipDurations);
      final before = facing(r.mesh);
      final forwardBefore = r.character.rootComponent.forwardVector.clone();
      expect(before.dot(forwardBefore), closeTo(1.0, 1e-6), reason: 'the mesh faces the pawn forward at rest');

      turnBy(r, 100.0);
      r.walk(Vector3.zero(), 1);
      final forward = r.character.rootComponent.forwardVector;
      expect(forward.dot(forwardBefore), closeTo(math.cos(100 * math.pi / 180), 1e-6), reason: 'the pawn turned 100°');
      expect(forward.cross(forwardBefore).y, greaterThan(0), reason: 'to the right (+yaw), as the mouse turns it');
      expect(r.anim!.rootYawOffsetDegrees, closeTo(-100.0, 1e-6));
      expect(r.anim!.variables['RootYawOffset'], closeTo(-100.0, 1e-6));
      expect(facing(r.mesh).dot(before), closeTo(1.0, 1e-6), reason: 'the feet stayed planted');
      expect(r.anim!.currentState, 'TurnRight90');
    });

    test('TurnRight90 turns the mesh 90° over its 2 s and hands back to Idle facing 10° short of the pawn', () {
      final r = rig(turningAnimClass(), clipDurations: turningClipDurations);
      turnBy(r, 100.0);
      r.walk(Vector3.zero(), 1);
      expect(r.anim!.currentState, 'TurnRight90');
      expect(r.mesh.currentClip, 'Turn_Right_90');
      expect(r.mesh.oneShots, ['Turn_Right_90']);
      r.walk(Vector3.zero(), 60);
      expect(r.anim!.rootYawOffsetDegrees, closeTo(-100.0 + 45.0, 1e-6), reason: 'half the clip, half the turn');
      r.walk(Vector3.zero(), 59);
      expect(r.anim!.currentState, 'TurnRight90', reason: 'one frame short of the clip');
      expect(r.anim!.rootYawOffsetDegrees, closeTo(-100.0 + 90.0 * 119 / 120, 1e-6));
      r.walk(Vector3.zero(), 1);
      expect(r.anim!.currentState, 'Idle', reason: 'taken the tick the clip finished');
      expect(r.anim!.rootYawOffsetDegrees, closeTo(-10.0, 1e-6), reason: 'the residual stays planted in Idle');
      final drawn = facing(r.mesh);
      final forward = r.character.rootComponent.forwardVector;
      expect(drawn.dot(forward), closeTo(math.cos(10 * math.pi / 180), 1e-6));
    });

    test('a −170° turn picks TurnLeft180; walking blends the offset out', () {
      final r = rig(turningAnimClass(), clipDurations: turningClipDurations);
      turnBy(r, -170.0);
      r.walk(Vector3.zero(), 1);
      expect(r.anim!.rootYawOffsetDegrees, closeTo(170.0, 1e-6));
      expect(r.anim!.currentState, 'TurnLeft180');
      r.walk(Vector3(0, 0, -1), 60);
      expect(r.anim!.currentState, 'Walk');
      expect(r.anim!.rootYawOffsetDegrees, 0.0, reason: 'blended out at 540°/s');
      expect(facing(r.mesh).dot(r.character.rootComponent.forwardVector), closeTo(1.0, 1e-6));
    });
  });
}
