import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

import 'anim_blueprints.dart';
import 'anim_rig.dart';

/// ABP_Character's whole movement set on a real character in a
/// real world (no GPU: the mesh never loads, so the instance is told the
/// bundle's clip lengths). Part 2: the dash and the wall jump through the
/// character Blueprint's IA_Dash graph and wall trace.
void main() {
  /// Clip lengths read from the shipped bundle (max key time per clip).
  Map<String, double> bundleDurations() {
    final doc = GlbDocument.parse(File(LuminaThirdPersonContent.bundledMeshPath).readAsBytesSync());
    final accessors = (doc.json['accessors'] as List).cast<Map<String, dynamic>>();
    return {
      for (final a in (doc.json['animations'] as List).cast<Map<String, dynamic>>())
        a['name'] as String: (a['samplers'] as List)
            .map((s) => ((accessors[(s as Map)['input'] as int]['max'] as List).first as num).toDouble())
            .reduce(math.max),
    };
  }

  late final durations = bundleDurations();

  AnimRig rig({int seed = 5}) => AnimRig.abp((mesh) => templateAnimClass().instantiate(mesh)
    ..clipDurationFallbacks.addAll(durations)
    ..random = math.Random(seed));

  /// [rig] on ABP_Character built for a bundle that has turn-in-place clips
  /// (2 s each; the shipped one has none).
  AnimRig turningRig({int seed = 5}) => AnimRig.abp((mesh) => turningAnimClass().instantiate(mesh)
    ..clipDurationFallbacks.addAll({...durations, ...turningClipDurations})
    ..random = math.Random(seed));

  /// Ticks [frames] with [direction] and returns the state after each.
  List<String?> run(AnimRig r, int frames, [Vector3? direction]) => [
        for (var i = 0; i < frames; i++) ...[
          () {
            r.walk(direction ?? Vector3.zero(), 1);
            return r.anim!.currentState;
          }(),
        ],
      ];

  /// The distinct states in order of first appearance.
  List<String?> sequence(List<String?> states) {
    final out = <String?>[];
    for (final s in states) {
      if (out.isEmpty || out.last != s) out.add(s);
    }
    return out;
  }

  test('the bundle lengths the rig uses match the constants the other tests assume', () {
    expect(durations.keys, containsAll(LuminaThirdPersonContent.clipNames));
    for (final e in templateClipDurations.entries) {
      expect(durations[e.key], closeTo(e.value, 1e-3), reason: e.key);
    }
  });

  test('ABP_Character validates clean with the full state machine', () {
    final cls = templateAnimClass();
    expect(cls.diagnostics, isEmpty, reason: '${cls.diagnostics}');
    final machine = LuminaThirdPersonContent.animBlueprint.stateMachine!;
    expect(machine.states.map((s) => s.name).toList(), [
      'Idle', 'IdleBreak', 'Walk', 'Jump', 'FallLoop', 'Land', 'Dash', 'WallJump', //
    ]);
    expect(LuminaThirdPersonContent.mannequinLocomotion.maxWalkRate,
        greaterThanOrEqualTo(LuminaTemplateCharacterTuning.thirdPersonMaxWalkSpeed / LuminaThirdPersonContent.walkReferenceSpeed));
    expect(machine.state('Dash')!.pose.clip, LuminaThirdPersonContent.dashClip);
    expect(machine.state('Dash')!.pose.loop, isFalse);
    expect(machine.state('WallJump')!.pose.clip, LuminaThirdPersonContent.wallJumpClip);
    expect(machine.state('WallJump')!.pose.loop, isFalse);
    expect(LuminaThirdPersonContent.animBlueprint.variables.map((v) => v.name), containsAll(['IsDashing', 'WallAhead']));
    // Every grounded state dashes; the air wall-jumps.
    for (final from in ['Idle', 'IdleBreak', 'Walk', 'Land']) {
      expect(machine.transitionsFrom(from).first.to, 'Dash', reason: from);
    }
    for (final from in ['Jump', 'FallLoop']) {
      expect(machine.transitionsFrom(from).first.to, 'WallJump', reason: from);
    }
    expect(machine.transitionsFrom('WallJump').map((t) => t.to), contains('FallLoop'));
    expect(machine.transitionsFrom('Dash').map((t) => t.to), containsAll(['Idle', 'Walk']));
    expect(machine.state('IdleBreak')!.pose.clips, LuminaThirdPersonContent.idleBreakClips);
    expect(machine.state('Jump')!.pose.loop, isFalse);
    expect(machine.state('Land')!.pose.loop, isFalse);
    expect(machine.state('FallLoop')!.pose.loop, isTrue);
    // No turn-in-place clips: a standing character turns with its capsule.
    expect(machine.state('Idle')!.pose.plantsFeet, isFalse);
    expect(machine.state('Walk')!.pose.plantsFeet, isFalse);

    // Built for a bundle with turn clips, the turn states come back and the
    // idle plants its feet; every grounded state still dashes first.
    final turning = LuminaThirdPersonContent.animBlueprintWith(turns: testTurnClips).stateMachine!;
    expect(turningAnimClass().diagnostics, isEmpty);
    expect(turning.states.map((s) => s.name).skip(8), ['TurnRight180', 'TurnLeft180', 'TurnRight90', 'TurnLeft90']);
    expect(turning.state('TurnLeft180')!.pose.rootYawDegrees, -180.0);
    expect(turning.state('TurnRight90')!.pose.clip, 'Turn_Right_90');
    expect(turning.state('Idle')!.pose.plantsFeet, isTrue);
    for (final from in ['TurnRight90', 'TurnLeft180']) {
      expect(turning.transitionsFrom(from).first.to, 'Dash', reason: from);
    }
  });

  test('standing 8 s: Idle → IdleBreak (one of the three idle clips, once) → Idle', () {
    final r = rig();
    final states = run(r, 8 * 60);
    expect(sequence(states), ['Idle', 'IdleBreak']);
    expect(r.mesh.currentClip, isIn(LuminaThirdPersonContent.idleBreakClips));
    expect(r.mesh.oneShots, [r.mesh.currentClip]);
    final breakAt = states.indexOf('IdleBreak');
    // 0.5 s of rig setup + the rest of the 6 s wait (the 2.5 s idle cycle
    // has played through by then).
    expect((breakAt + 30) / 60, closeTo(LuminaThirdPersonContent.idleBreakAfterSeconds, 0.05));
    expect(r.anim!.variables['IdleTime'] as double, greaterThan(6.0));
    final after = run(r, (durations[r.mesh.currentClip!]! * 60).ceil() + 2);
    expect(after.last, 'Idle');
    expect(r.mesh.currentClip, 'Idle_Loop');
    expect(r.mesh.fades.last, (clip: 'Idle_Loop', duration: 0.2, sync: false));
  });

  test('a jump press: Jump → FallLoop → Land → Idle, Jump_Start and Jump_Land once each, the loop looping', () {
    final r = rig();
    r.character.jump();
    final states = run(r, 150);
    expect(sequence(states), ['Jump', 'FallLoop', 'Land', 'Idle']);
    expect(r.mesh.oneShots, ['Jump_Start', 'Jump_Land']);
    expect(r.mesh.fades.map((f) => f.clip).toList(), ['Jump_Start', 'Jump_Loop', 'Jump_Land', 'Idle_Loop']);
    // A 500 cm/s jump stays up ~1 s: Jump_Start hands over to the loop once it
    // is still airborne past 0.3 s, and Jump_Land plays through on the ground.
    final jumpFrames = states.where((s) => s == 'Jump').length;
    expect(jumpFrames / 60, closeTo(LuminaThirdPersonContent.jumpToFallAfterSeconds, 0.02));
    final landFrames = states.where((s) => s == 'Land').length;
    expect(landFrames / 60, closeTo(durations['Jump_Land']!, 0.02));
    expect(r.anim!.variables['IsRising'], isFalse);
  });

  test('a short hop cut early lands before Jump_Start ends: Jump → Land', () {
    final r = rig();
    r.character.characterMovement.jumpZVelocity = 150.0;
    r.character.jump();
    final states = run(r, 90);
    expect(sequence(states).take(2), ['Jump', 'Land']);
    expect(states, isNot(contains('FallLoop')));
  });

  test('jumping while walking lands into Walk without stopping', () {
    final r = rig();
    run(r, 30, Vector3(0, 0, -1));
    expect(r.anim!.currentState, 'Walk');
    r.character.jump();
    final states = run(r, 120, Vector3(0, 0, -1));
    expect(sequence(states), ['Jump', 'FallLoop', 'Land', 'Walk']);
    expect(states.where((s) => s == 'Land').length, lessThan(5), reason: 'momentum wins over the landing clip');
  });

  test('walking off the ledge: FallLoop without Jump', () {
    final r = rig();
    r.character.actorLocation = Vector3(3900, 100, 0); // the floor box ends at x = 4000
    run(r, 5);
    final states = run(r, 240, Vector3(1, 0, 0));
    expect(states, isNot(contains('Jump')));
    expect(sequence(states), ['Walk', 'FallLoop']);
    expect(r.anim!.variables['IsRising'], isFalse);
    expect(r.mesh.currentClip, 'Jump_Loop');
  });

  group('turn in place', () {
    void turnBy(AnimRig r, double yawDegrees) {
      final e = luminaPawnQuaternionToEuler(r.character.actorRotation);
      r.character.actorRotation = luminaPawnEulerToQuaternion(e.x, e.y + yawDegrees, e.z);
    }

    test('without turn clips, a standing character turns with its capsule', () {
      final r = rig();
      turnBy(r, 100.0);
      final states = run(r, 30);
      expect(sequence(states), ['Idle']);
      expect(r.anim!.rootYawOffsetDegrees, 0.0);
    });

    test('yaw +100° while standing → TurnRight90 → Idle; yaw −170° → TurnLeft180', () {
      final r = turningRig();
      turnBy(r, 100.0);
      final states = run(r, 130);
      expect(sequence(states), ['TurnRight90', 'Idle']);
      expect(states.where((s) => s == 'TurnRight90').length / 60, closeTo(2.0, 0.02));
      expect(r.mesh.oneShots, ['Turn_Right_90']);
      expect(r.anim!.rootYawOffsetDegrees, closeTo(-10.0, 1e-6));

      turnBy(r, -170.0);
      final left = run(r, 130);
      expect(sequence(left), ['TurnLeft180', 'Idle']);
      expect(r.mesh.oneShots, ['Turn_Right_90', 'Turn_Left_180']);
      expect(r.anim!.rootYawOffsetDegrees, closeTo(-10.0 + 170.0 - 180.0, 1e-6));
    });

    test('a 40° turn is absorbed by the planted idle; a −70° turn is TurnLeft90', () {
      final r = turningRig();
      turnBy(r, 40.0);
      expect(sequence(run(r, 30)), ['Idle']);
      expect(r.anim!.rootYawOffsetDegrees, closeTo(-40.0, 1e-6));
      turnBy(r, -110.0);
      expect(sequence(run(r, 5)), ['TurnLeft90']);
      // The turn starts unwinding the tick after the state is entered.
      expect(r.anim!.variables['RootYawOffset'] as double, closeTo(70.0 - 90.0 * 4 / 120, 1e-6));
    });

    test('walking interrupts a turn and blends the offset out', () {
      final r = turningRig();
      turnBy(r, 100.0);
      run(r, 10);
      expect(r.anim!.currentState, 'TurnRight90');
      final states = run(r, 60, r.character.rootComponent.forwardVector);
      expect(states.first, 'Walk', reason: 'the first step already interrupts the turn');
      expect(states.toSet(), {'Walk'});
      expect(r.mesh.currentClip, 'Walk_Fwd_Loop');
      expect(r.anim!.rootYawOffsetDegrees, 0.0);
    });
  });

  group('dash and wall jump (part 2: the character Blueprint drives the anim variables)', () {
    /// BP_ThirdPersonCharacter run by the VM on the template's real input
    /// manifest, animated by ABP_Character, standing on the rig floor.
    ({AnimRig rig, LuminaInputSubsystem input, LuminaPlayerController pc}) character({int seed = 5}) {
      final world = AnimRig.floorWorld();
      final bound = ProjectInputBinder.bind(GameTemplateCatalog.thirdPerson.input);
      final input = world.registerSubsystem(LuminaInputSubsystem());
      for (final c in bound.contexts) {
        input.addMappingContext(c.context, priority: c.priority);
      }
      final actions = bound.actions.values.toList();
      final anim = templateAnimClass();
      final mesh = RecordingMesh();
      final character = LuminaBlueprintClass.fromDocument(
        LuminaThirdPersonContent.characterBlueprint(inputActions: actions, meshAsset: 'never_loaded.glb'),
        name: LuminaThirdPersonContent.characterBlueprintName,
        inputActions: actions,
        animBlueprints: (path) => path == LuminaThirdPersonContent.projectAnimBlueprintPath
            ? (m) => (anim.instantiate(mesh)
              ..clipDurationFallbacks.addAll(durations)
              ..random = math.Random(seed))
            : null,
      ).instantiate(location: Vector3(0.0, 100.0, 0.0)) as LuminaCharacter;
      final pc = LuminaPlayerController();
      world.persistentLevel.registerActor(character);
      pc.possess(character);
      world.beginPlay();
      final instance = (character as LuminaBlueprintRuntime).blueprintComponents['mesh.anim'] as LuminaAnimBlueprintInstance;
      for (var i = 0; i < 30; i++) {
        pc.onTick(1 / 60);
        world.tick(1 / 60);
      }
      expect(character.characterMovement.isFalling, isFalse);
      return (rig: AnimRig.attached(world, character, mesh, instance), input: input, pc: pc);
    }

    /// Ticks [frames] with [keys] held, returning the state after each.
    List<String?> play(({AnimRig rig, LuminaInputSubsystem input, LuminaPlayerController pc}) c, int frames,
        {List<LuminaKey> keys = const []}) {
      for (final k in keys) {
        c.input.injectKeyDown(k);
      }
      final out = <String?>[];
      for (var i = 0; i < frames; i++) {
        c.pc.onTick(1 / 60);
        c.rig.world.tick(1 / 60);
        out.add(c.rig.anim!.currentState);
      }
      for (final k in keys) {
        c.input.injectKeyUp(k);
      }
      return out;
    }

    test('the manifest binds IA_Sprint to Left Shift + the left thumbstick and IA_Dash to Left Ctrl + the face-right button', () {
      final bound = ProjectInputBinder.bind(GameTemplateCatalog.thirdPerson.input);
      final sprint = bound.actionByName('IA_Sprint')!;
      final dash = bound.actionByName('IA_Dash')!;
      expect(sprint.valueType, InputValueType.digitalBool);
      expect(dash.valueType, InputValueType.digitalBool);
      final gameplay = bound.contexts.single.context;
      expect(gameplay.mappingsForKey(LuminaKey.keyLeftShift).single.action, sprint);
      expect(gameplay.mappingsForKey(LuminaKey.gamepadLeftThumbstick).single.action, sprint);
      expect(gameplay.mappingsForKey(LuminaKey.keyLeftControl).single.action, dash);
      expect(gameplay.mappingsForKey(LuminaKey.gamepadFaceButtonRight).single.action, dash);
      expect(bound.unboundKeys, isEmpty);
    });

    test('sprint plays the jog row: Left Shift reaches 480 cm/s on Jog_Fwd_Loop at rate 1; released, back to Walk_Fwd_Loop; strafing left while sprinting jogs left', () {
      final c = character();
      expect(play(c, 60, keys: const [LuminaKey.keyW]).last, 'Walk');
      c.input.injectKeyDown(LuminaKey.keyW);
      final walkSpeed = c.rig.character.characterMovement.velocity.length;
      expect(walkSpeed, closeTo(LuminaTemplateCharacterTuning.thirdPersonMaxWalkSpeed, 1.0));
      expect(c.rig.mesh.currentClip, 'Walk_Fwd_Loop');
      final walkRate = c.rig.mesh.playRate;
      expect(walkRate, closeTo(300.0 / LuminaThirdPersonContent.walkReferenceSpeed, 0.02), reason: 'the walk row at 300 cm/s');
      final states = play(c, 60, keys: const [LuminaKey.keyLeftShift]);
      expect(states.toSet(), {'Walk'}, reason: 'the sprint only changes speed: the Walk state jogs on BS_Locomotion');
      expect(c.rig.character.characterMovement.maxWalkSpeed, LuminaTemplateCharacterTuning.thirdPersonSprintSpeed);
      expect(c.rig.character.characterMovement.velocity.length, closeTo(LuminaTemplateCharacterTuning.thirdPersonSprintSpeed, 1.0));
      expect(c.rig.anim!.variables['IsSprinting'], isTrue);
      expect(c.rig.mesh.currentClip, 'Jog_Fwd_Loop', reason: 'the dominant sample is the forward jog');
      final weights = c.rig.anim!.blendWeights;
      final jogWeight = [for (final clip in LuminaThirdPersonClips.jogs) weights[clip] ?? 0.0].fold(0.0, (a, b) => a + b);
      expect(jogWeight, greaterThan(0.5), reason: 'GroundSpeed 480 is nearer the jog row: $weights');
      expect(c.rig.mesh.playRate, closeTo(480.0 / LuminaThirdPersonContent.jogReferenceSpeed, 0.02), reason: 'the jog at its own rate, not the walk at 4.8×');
      // Released (Completed): the walk cap, the walk clip and its rate come back.
      play(c, 60);
      expect(c.rig.character.characterMovement.maxWalkSpeed, LuminaTemplateCharacterTuning.thirdPersonMaxWalkSpeed);
      expect(c.rig.character.characterMovement.velocity.length, closeTo(walkSpeed, 1.0));
      expect(c.rig.anim!.variables['IsSprinting'], isFalse);
      expect(c.rig.mesh.currentClip, 'Walk_Fwd_Loop');
      expect(c.rig.mesh.playRate, closeTo(walkRate, 0.02));
      c.input.injectKeyUp(LuminaKey.keyW);

      // Strafing left (A) while sprinting: the left jog.
      play(c, 60);
      c.input.injectKeyDown(LuminaKey.keyA);
      c.input.injectKeyDown(LuminaKey.keyLeftShift);
      play(c, 90);
      expect(c.rig.character.characterMovement.velocity.length, closeTo(LuminaTemplateCharacterTuning.thirdPersonSprintSpeed, 1.0));
      expect(c.rig.mesh.currentClip, 'Jog_Left_Loop');
      c.input.injectKeyUp(LuminaKey.keyA);
      c.input.injectKeyUp(LuminaKey.keyLeftShift);
    });

    test('Left Ctrl while walking: Dash for ~1.2 s, launched at 600 cm/s, then Walk; standing, Roll plays through', () {
      final c = character();
      expect(play(c, 30, keys: const [LuminaKey.keyW]).last, 'Walk');
      c.input.injectKeyDown(LuminaKey.keyW);
      final states = play(c, 90, keys: const [LuminaKey.keyLeftControl]);
      c.input.injectKeyUp(LuminaKey.keyW);
      // Started fires on the press frame, so the dash begins at once.
      expect(sequence(states), ['Dash', 'Walk']);
      expect(states.where((s) => s == 'Dash').length / 60, closeTo(LuminaThirdPersonContent.dashWalkAfterSeconds, 0.04));
      expect(c.rig.mesh.oneShots, ['Roll']);
      expect(c.rig.anim!.variables['IsDashing'], isFalse, reason: 'the 0.4 s timer cleared it');

      // Standing still, the dash clip (1.47 s) plays to its end, then Idle.
      play(c, 90);
      expect(c.rig.anim!.currentState, 'Idle');
      final speedBefore = c.rig.character.characterMovement.velocity.length;
      expect(speedBefore, lessThan(1.0));
      final standing = play(c, 2, keys: const [LuminaKey.keyLeftControl]);
      expect(standing.last, 'Dash');
      expect(c.rig.character.characterMovement.velocity.length, closeTo(LuminaThirdPersonContent.dashSpeed, 60.0),
          reason: 'launched along the look yaw, XY override');
      final rest = play(c, 90);
      expect(sequence([...standing, ...rest]), ['Dash', 'Idle']);
      expect(([...standing, ...rest].where((s) => s == 'Dash').length) / 60, closeTo(durations['Roll']!, 0.04));
      expect(c.rig.mesh.oneShots, ['Roll', 'Roll']);
    });

    test('jumping with a wall 40 cm ahead: WallJump (once) → Land; without the wall, Jump', () {
      final c = character();
      // A 3 m wall whose face is 40 cm ahead of the character (it faces -Z in
      // runtime space; the trace starts at its eyes, above the location).
      final wall = LuminaPrimitiveActor(
        shape: LuminaPrimitiveShape.box,
        size: Vector3(400.0, 300.0, 50.0),
        color: Vector3.all(0.5),
        location: Vector3(0.0, 150.0, -(40.0 + 25.0)),
      );
      c.rig.world.persistentLevel.registerActor(wall);
      play(c, 5);
      expect(c.rig.anim!.variables['WallAhead'], isTrue, reason: 'the Tick trace (60 cm) touches the wall');
      final states = play(c, 150, keys: const [LuminaKey.keySpace]);
      // Jump for the press frame (the rule lives on Jump / FallLoop), then the
      // wall jump, which lands before its clip ends.
      expect(sequence(states).take(3), ['Jump', 'WallJump', 'Land']);
      expect(states.where((s) => s == 'Jump').length, 1);
      expect(states.where((s) => s == 'WallJump').length / 60, lessThanOrEqualTo(durations['NinjaJump_Start']! + 0.02));
      expect(c.rig.mesh.oneShots.take(2), ['Jump_Start', 'NinjaJump_Start']);

      wall.destroy();
      play(c, 60);
      expect(c.rig.anim!.currentState, 'Idle');
      expect(c.rig.anim!.variables['WallAhead'], isFalse);
      final open = play(c, 150, keys: const [LuminaKey.keySpace]);
      expect(sequence(open).take(2), ['Jump', 'FallLoop']);
      expect(open, isNot(contains('WallJump')));
    });
  });
}
