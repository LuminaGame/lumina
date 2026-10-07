import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

import 'anim_blueprints.dart';
import 'anim_rig.dart';
import 'third_person_blueprint.dart';

/// Animation Blueprints — the update graph, the state machine
/// and blend spaces, and ABP_Character reproducing the Dart locomotion driver.
void main() {
  final abp = LuminaThirdPersonContent.animBlueprint;
  final walk = LuminaThirdPersonContent.walkBlendSpace;
  LuminaAnimBlueprintClass manny() => LuminaAnimBlueprintClass.fromDocument(
        LuminaThirdPersonContent.animBlueprint,
        name: LuminaThirdPersonContent.animBlueprintName,
        blendSpaces: LuminaThirdPersonContent.blendSpaces,
      );

  group('documents', () {
    test('ABP and blend-space documents round-trip through JSON byte-for-byte', () {
      final abpJson = jsonEncode(abp.toJson());
      expect(jsonEncode(LuminaAnimBlueprintDocument.fromJson(jsonDecode(abpJson) as Map<String, dynamic>).toJson()), abpJson);
      final bsJson = jsonEncode(walk.toJson());
      expect(jsonEncode(LuminaBlendSpaceDocument.fromJson(jsonDecode(bsJson) as Map<String, dynamic>).toJson()), bsJson);
    });

    test('ABP_Character validates with no errors or warnings', () {
      final cls = manny();
      expect(cls.diagnostics, isEmpty, reason: '${cls.diagnostics}');
    });

    test('a transition whose Result is not connected can never be taken, and says so', () {
      final doc = LuminaAnimBlueprintDocument(stateMachines: [
        LuminaAnimStateMachine(name: 'Locomotion', entryState: 'A', states: const [
          LuminaAnimState('A', LuminaAnimPose.hold()),
          LuminaAnimState('B', LuminaAnimPose.hold()),
        ], transitions: [
          LuminaAnimTransition(
            id: 'a_to_b',
            from: 'A',
            to: 'B',
            rule: LuminaBlueprintGraph(nodes: [
              LuminaBlueprintNodeLibrary.place(LuminaBlueprintNodeLibrary.transitionResult, nodeId: 'result'),
            ]),
          ),
        ]),
      ]);
      final warning = validateAnimBlueprint(doc).where((d) => !d.isError).single;
      expect(warning.message, "Transition 'a_to_b' (A → B) can never be taken: nothing is connected to its Result.");
      expect(warning.nodeId, 'result');
    });

    test('a rule with an impure node, a missing blend space or entry state is a compile error', () {
      final json = abp.toJson();
      final broken = LuminaAnimBlueprintDocument.fromJson(jsonDecode(jsonEncode(json)) as Map<String, dynamic>);
      final cls = LuminaAnimBlueprintClass.fromDocument(broken, name: 'ABP_Broken');
      expect(cls.hasErrors, isTrue);
      expect(cls.diagnostics.map((d) => d.message), contains(contains("missing blend space '${LuminaThirdPersonContent.projectLocomotionBlendSpacePath}'")));

      final noEntry = LuminaAnimBlueprintDocument(stateMachines: [
        LuminaAnimStateMachine(name: 'Locomotion', entryState: 'Nowhere', states: const [], transitions: const []),
      ]);
      expect(LuminaAnimBlueprintClass.fromDocument(noEntry).diagnostics.map((d) => d.message),
          contains("Entry state 'Nowhere' does not exist."));

      final impure = LuminaAnimBlueprintDocument(stateMachines: [
        LuminaAnimStateMachine(name: 'Locomotion', entryState: 'A', states: const [
          LuminaAnimState('A', LuminaAnimPose.hold()),
          LuminaAnimState('B', LuminaAnimPose.hold()),
        ], transitions: [
          LuminaAnimTransition(
            id: 'a_to_b',
            from: 'A',
            to: 'B',
            rule: LuminaBlueprintGraph(nodes: [
              LuminaBlueprintNodeLibrary.place('jump', nodeId: 'jump'),
              LuminaBlueprintNodeLibrary.place(LuminaBlueprintNodeLibrary.transitionResult, nodeId: 'result'),
            ]),
          ),
        ]),
      ]);
      expect(LuminaAnimBlueprintClass.fromDocument(impure).diagnostics.map((d) => d.message),
          contains("Transition 'a_to_b': a rule can use pure nodes only."));
    });
  });

  group('calculate_direction', () {
    test('is the signed yaw from the facing to the velocity, right positive', () {
      const zero = LuminaRotator.zero();
      expect(LuminaBlueprintFunctionLibrary.calculateDirection(Vector3(0, 250, 0), zero), closeTo(0, 1e-9));
      expect(LuminaBlueprintFunctionLibrary.calculateDirection(Vector3(250, 0, 0), zero), closeTo(90, 1e-9));
      expect(LuminaBlueprintFunctionLibrary.calculateDirection(Vector3(-250, 0, 0), zero), closeTo(-90, 1e-9));
      expect(LuminaBlueprintFunctionLibrary.calculateDirection(Vector3(0, 0, 400), zero), 0.0, reason: 'vertical only');
    });

    test("matches the locomotion driver's 45° bins at any facing", () {
      const clips = LuminaThirdPersonContent.mannequinLocomotion;
      for (var yaw = -170.0; yaw <= 180.0; yaw += 37.0) {
        final rotation = LuminaRotator(0, 0, yaw);
        final facing = LuminaBlueprintFunctionLibrary.toRuntime(LuminaBlueprintFunctionLibrary.getForwardVector(rotation));
        for (var heading = -179.0; heading <= 180.0; heading += 7.0) {
          final r = (yaw + heading) * math.pi / 180.0;
          // Authoring: forward +Y, right +X; a positive yaw turns right... as the pawn does.
          final world = LuminaBlueprintFunctionLibrary.getForwardVector(LuminaRotator(0, 0, yaw + heading)) * 250.0;
          final direction = LuminaBlueprintFunctionLibrary.calculateDirection(world, rotation);
          final driver = selectLocomotionPose(
            clips: clips,
            velocity: LuminaBlueprintFunctionLibrary.toRuntime(world),
            facing: facing,
            isFalling: false,
          );
          final sample = LuminaThirdPersonContent.walkBlendSpace.nearest(direction);
          expect(sample!.clip, driver.clip, reason: 'yaw $yaw, heading $heading (${r.toStringAsFixed(3)} rad) → $direction°');
        }
      }
    });
  });

  group('blend space', () {
    test('nearest sample on the walk axis, ties to the outer sample like the driver rounds', () {
      expect(walk.nearest(0)!.clip, 'Walk_Fwd_Loop');
      expect(walk.nearest(45)!.clip, 'Walk_Fwd_Right_Loop');
      expect(walk.nearest(22.5)!.clip, 'Walk_Fwd_Right_Loop');
      expect(walk.nearest(-22.5)!.clip, 'Walk_Fwd_Left_Loop');
      expect(walk.nearest(170)!.clip, 'Walk_Bwd_Loop');
      expect(walk.nearest(-170)!.clip, 'Walk_Bwd_Loop');
      expect(walk.nearest(-100)!.clip, 'Walk_Left_Loop');
    });

    test('a 2D idle/walk space picks idle at speed 0 and walk forward-right at (45, 250)', () {
      final idleWalk = LuminaBlendSpaceDocument(
        axes: const [LuminaBlendSpaceAxis('Direction', -180, 180), LuminaBlendSpaceAxis('GroundSpeed', 0, 250)],
        samples: [
          for (final d in [-180.0, -90.0, 0.0, 90.0, 180.0]) LuminaBlendSpaceSample('Idle_Loop', d, 0),
          for (final s in walk.samples) LuminaBlendSpaceSample(s.clip, s.x, 250),
        ],
      );
      expect(idleWalk.nearest(30, 0)!.clip, 'Idle_Loop');
      expect(idleWalk.nearest(45, 250)!.clip, 'Walk_Fwd_Right_Loop');
    });
  });

  group('state machine', () {
    test('Idle → Walk → Jump → FallLoop → Land → Walk → Idle, each change crossfading over its blend duration', () {
      final r = AnimRig.abp((mesh) => manny().instantiate(mesh)..clipDurationFallbacks.addAll(templateClipDurations));
      expect(r.anim!.currentState, 'Idle');
      expect(r.mesh.currentClip, 'Idle_Loop');
      r.walk(Vector3(0, 0, -1), 60);
      expect(r.anim!.currentState, 'Walk');
      expect(r.mesh.currentClip, 'Walk_Fwd_Loop');
      expect(r.mesh.fades.last, (clip: 'Walk_Fwd_Loop', duration: 0.2, sync: false));
      r.character.jump();
      r.walk(Vector3(0, 0, -1), 5);
      expect(r.anim!.currentState, 'Jump');
      expect(r.mesh.currentClip, 'Jump_Start');
      expect(r.mesh.playRate, 1.0);
      r.walk(Vector3(0, 0, -1), 15);
      expect(r.anim!.currentState, 'FallLoop', reason: 'still airborne 0.3 s into Jump_Start');
      expect(r.mesh.currentClip, 'Jump_Loop');
      r.walk(Vector3(0, 0, -1), 100);
      expect(r.anim!.currentState, 'Walk', reason: 'landed walking: Land handed straight to Walk');
      expect(r.mesh.fades.map((f) => f.clip), contains('Jump_Land'));
      r.walk(Vector3.zero(), 60);
      expect(r.anim!.currentState, 'Idle');
      expect(r.mesh.fades.last, (clip: 'Idle_Loop', duration: 0.2, sync: false));
    });

    test('when two rules hold, the lower priority number wins', () {
      LuminaBlueprintGraph always() => LuminaBlueprintGraph(nodes: [
            LuminaBlueprintNodeLibrary.place(LuminaBlueprintNodeLibrary.transitionResult,
                nodeId: 'result', literals: {'can_enter': true}),
          ]);
      final doc = LuminaAnimBlueprintDocument(stateMachines: [
        LuminaAnimStateMachine(name: 'Locomotion', entryState: 'A', states: const [
          LuminaAnimState('A', LuminaAnimPose.clip('Idle_Loop')),
          LuminaAnimState('B', LuminaAnimPose.clip('Walk_Fwd_Loop')),
          LuminaAnimState('C', LuminaAnimPose.clip('Walk_Bwd_Loop')),
        ], transitions: [
          LuminaAnimTransition(id: 'a_to_b', from: 'A', to: 'B', priority: 1, blendDuration: 0.4, rule: always()),
          LuminaAnimTransition(id: 'a_to_c', from: 'A', to: 'C', priority: 0, blendDuration: 0.3, rule: always()),
        ]),
      ]);
      final cls = LuminaAnimBlueprintClass.fromDocument(doc, name: 'ABP_Priority');
      expect(cls.hasErrors, isFalse, reason: '${cls.diagnostics}');
      final r = AnimRig.abp(cls.factory);
      r.walk(Vector3.zero(), 1);
      expect(r.anim!.currentState, 'C');
      expect(r.mesh.fades.last, (clip: 'Walk_Bwd_Loop', duration: 0.3, sync: false));
    });

    test('walking plays the blend-space sample at the ground speed over 100 cm/s', () {
      final r = AnimRig.abp(manny().factory, maxWalkSpeed: 125);
      // Forward-right: 45° right of the facing.
      r.walk(Vector3(1, 0, -1), 90);
      expect(r.mesh.currentClip, 'Walk_Fwd_Right_Loop');
      expect(r.anim!.variables['GroundSpeed'] as double, closeTo(125, 1e-6));
      expect(r.mesh.playRate, closeTo(1.25, 1e-6));
    });
  });

  group('parity with LuminaDirectionalLocomotionComponent', () {
    test('ABP_Character selects the same clip, crossfades and rate on every grounded tick', () {
      final driver = AnimRig.driver();
      final vm = AnimRig.abp((mesh) => manny().instantiate(mesh)..clipDurationFallbacks.addAll(templateClipDurations));
      final a = driver.script();
      final b = vm.script();
      expect(a.length, greaterThan(400));
      expect(b.length, a.length);
      // The driver holds the walk pose through the jump; ABP_Character plays
      // Jump_Start / Jump_Loop / Jump_Land. Everything up to the
      // jump (tick 210) and from 1 s after landing on matches tick for tick.
      final airborne = [for (var i = 0; i < a.length; i++) if (a[i].rate == 0.0) i];
      expect(airborne, isNotEmpty, reason: 'the driver held a pose while falling');
      final landed = airborne.last + 60;
      for (var i = 0; i < a.length; i++) {
        if (i >= airborne.first && i < landed) continue;
        expect(b[i], a[i], reason: 'tick $i');
      }
      expect({for (final s in b.sublist(airborne.first, landed)) s.clip}, containsAll(['Jump_Start', 'Jump_Loop', 'Jump_Land']));
      // The script really went through every state.
      final clips = {for (final s in a) s.clip};
      expect(clips, containsAll(['Idle_Loop', 'Walk_Fwd_Loop', 'Walk_Right_Loop', 'Walk_Bwd_Left_Loop']));
      // Every crossfade up to the jump is the driver's; landing adds a
      // Jump_Land → walk fade the driver never needs.
      final beforeJump = vm.mesh.fades.indexWhere((f) => f.clip == 'Jump_Start');
      expect(beforeJump, greaterThan(3));
      expect(vm.mesh.fades.sublist(0, beforeJump), driver.mesh.fades.sublist(0, beforeJump));
      expect(vm.mesh.fades.last, driver.mesh.fades.last, reason: 'both settle into idle the same way');
      expect(driver.mesh.fades.where((f) => f.sync), isNotEmpty, reason: 'walk → walk fades keep phase');
    });
  });

  group('Blueprint Skeletal Mesh', () {
    final actions = ProjectInputBinder.bind(GameTemplateCatalog.thirdPerson.input).actions.values.toList();
    test("a mesh with Anim Class ABP_Character animates a VM-spawned character", () {
      final doc = thirdPersonCharacterBlueprint(inputActions: actions);
      doc.components.add(LuminaBlueprintComponent(
        id: 'mesh',
        name: 'Mesh',
        type: 'LuminaSkeletalMeshComponent',
        parentId: 'capsule',
        properties: {
          'skeletalMeshAsset': 'never_loaded.glb',
          'location': [0.0, 0.0, -LuminaTemplateCharacterTuning.thirdPersonCapsuleHalfHeight],
          'animMode': 'Use Animation Blueprint',
          'animClass': LuminaThirdPersonContent.projectAnimBlueprintPath,
        },
      ));
      final anim = manny();
      final cls = LuminaBlueprintClass.fromDocument(
        doc,
        name: 'BP_ThirdPersonCharacter',
        inputActions: actions,
        animBlueprints: (path) => path == LuminaThirdPersonContent.projectAnimBlueprintPath ? anim.factory : null,
      );
      expect(cls.hasErrors, isFalse, reason: '${cls.diagnostics}');
      final character = cls.instantiate() as LuminaBlueprintCharacter;
      final mesh = character.blueprintComponents['mesh'] as LuminaAnimatedMeshComponent;
      final instance = character.blueprintComponents['mesh.anim'] as LuminaAnimBlueprintInstance;
      expect(instance.mesh, same(mesh));
      expect(character.components.indexOf(instance), lessThan(character.components.indexOf(mesh)),
          reason: 'the pose is chosen before the mesh applies it');

      final world = AnimRig.floorWorld();
      character.actorLocation = Vector3(0, 100, 0);
      world.persistentLevel.registerActor(character);
      world.beginPlay();
      for (var i = 0; i < 30; i++) {
        world.tick(1 / 60);
      }
      expect(mesh.currentClip, 'Idle_Loop');
      for (var i = 0; i < 60; i++) {
        character.characterMovement.addInputVector(Vector3(1, 0, 0));
        world.tick(1 / 60);
      }
      expect(instance.currentState, 'Walk');
      expect(mesh.currentClip, 'Walk_Right_Loop');
    });

    test('an Anim Class nobody resolves is a warning and the mesh stays unanimated', () {
      final doc = thirdPersonCharacterBlueprint(inputActions: actions);
      doc.components.add(LuminaBlueprintComponent(
        id: 'mesh',
        name: 'Mesh',
        type: 'LuminaSkeletalMeshComponent',
        properties: {'skeletalMeshAsset': 'never_loaded.glb', 'animMode': 'Use Animation Blueprint', 'animClass': 'ABP_Missing'},
      ));
      final cls = LuminaBlueprintClass.fromDocument(doc, name: 'BP_NoAnim', inputActions: actions);
      final character = cls.instantiate() as LuminaBlueprintCharacter;
      expect(character.blueprintComponents.containsKey('mesh.anim'), isFalse);
      expect(cls.diagnostics.map((d) => d.message), contains(contains("'ABP_Missing' is not available")));
    });
  });
}
