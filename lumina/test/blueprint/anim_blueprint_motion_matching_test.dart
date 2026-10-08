import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_core/testing.dart';
import 'package:vector_math/vector_math_64.dart';

import 'generated/abp_motion_matching.g.dart';
import 'motion_matching_blueprint.dart';

/// Motion Matching as an Animation Blueprint state: the pose's document
/// form, the validator, and the VM and the generated class driving the same
/// mesh identically from the pawn's movement.
void main() {
  group('document', () {
    test('a motion matching pose round-trips through JSON', () {
      const pose = LuminaAnimPose.motionMatching('contents/animations/PSD.lmas',
          blendTime: 0.3, poseWeight: 0.5, trajectoryWeight: 2.0, requiredTags: ['walk'], orientToMovement: true, debugDraw: true);
      final json = jsonEncode(pose.toJson());
      final back = LuminaAnimPose.fromJson(jsonDecode(json) as Map<String, dynamic>);
      expect(jsonEncode(back.toJson()), json);
      expect(back.kind, LuminaAnimPoseKind.motionMatching);
      expect(back.requiredTags, ['walk']);
      final doc = MotionMatchingBlueprintFixture.animBlueprint();
      expect(jsonEncode(LuminaAnimBlueprintDocument.fromJson(jsonDecode(jsonEncode(doc.toJson())) as Map<String, dynamic>).toJson()),
          jsonEncode(doc.toJson()));
    });

    test('a missing pose search database is a compile error naming it', () {
      final cls = LuminaAnimBlueprintClass.fromDocument(MotionMatchingBlueprintFixture.animBlueprint());
      expect(cls.hasErrors, isTrue);
      expect(cls.diagnostics.map((d) => d.message),
          contains("State 'Locomotion' plays a missing pose search database '${MotionMatchingBlueprintFixture.databasePath}'."));
      final ok = LuminaAnimBlueprintClass.fromDocument(MotionMatchingBlueprintFixture.animBlueprint(),
          poseDatabases: {MotionMatchingBlueprintFixture.databasePath: MotionMatchingBlueprintFixture.database});
      expect(ok.diagnostics.where((d) => d.isError), isEmpty, reason: '${ok.diagnostics}');
    });
  });

  group('runtime', () {
    late FilamentEngine engine;
    late FilamentScene scene;
    late Directory project;
    String? previousProjectDir;

    setUp(() {
      engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
      scene = engine.createScene();
      project = Directory.systemTemp.createTempSync('lumina_abp_mm_');
      File('${project.path}/${MotionMatchingBlueprintFixture.meshPath}')
        ..createSync(recursive: true)
        ..writeAsBytesSync(LuminaSyntheticLocomotionRig.build(MotionMatchingBlueprintFixture.clips()));
      Directory('${project.path}/contents/animations').createSync(recursive: true);
      previousProjectDir = LuminaAssets.projectDir;
      LuminaAssets.projectDir = project.path;
      LuminaPoseSearchDatabaseRuntime.clearShared();
    });

    tearDown(() {
      LuminaAssets.projectDir = previousProjectDir;
      LuminaPoseSearchDatabaseRuntime.clearShared();
      scene.dispose();
      engine.dispose();
      project.deleteSync(recursive: true);
    });

    /// Runs a pawn standing 1 s, walking forward 3 s and standing 3 s, then
    /// frozen 0.5 s; returns the matched clips (repeats collapsed), the last
    /// pose and the instance.
    Future<(List<String>, Float64List, LuminaAnimBlueprintInstance)> run(
        LuminaAnimBlueprintInstance Function(LuminaAnimatedMeshComponent mesh) make) async {
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      world.initializeNativeContext(engine, scene);
      final mesh = LuminaAnimatedMeshComponent(meshAssetPath: MotionMatchingBlueprintFixture.meshPath);
      final movement = LuminaCharacterMovementComponent()..maxWalkSpeed = 150.0;
      final anim = make(mesh);
      final pawn = LuminaActor(root: LuminaSceneComponent())
        ..addComponent(movement)
        ..addComponent(anim)
        ..addComponent(mesh);
      world.persistentLevel.registerActor(pawn);
      world.beginPlay();
      await mesh.loaded;
      await anim.motionMatching.load(MotionMatchingBlueprintFixture.databasePath);
      final played = <String>[];
      void tick(double seconds, {Vector3? input}) {
        for (var i = 0; i < (seconds * 60).round(); i++) {
          if (input != null) movement.addInputVector(input);
          world.tick(1 / 60);
          final clip = anim.variables[LuminaAnimBlueprintInstance.matchedClipVariable] as String? ?? '';
          if (clip.isNotEmpty && (played.isEmpty || played.last != clip)) played.add(clip);
        }
      }

      tick(1.0);
      tick(3.0, input: Vector3(0, 0, -1));
      tick(3.0);
      final pose = Float64List.fromList(anim.motionMatching.player!.pose);
      expect(mesh.poseDriver, isNotNull, reason: 'motion matching drives the mesh');
      anim.variables['Freeze'] = true;
      tick(0.5);
      expect(anim.currentState, 'Frozen');
      expect(mesh.poseDriver, isNull, reason: 'leaving the state hands the joints back to gltfio');
      expect(mesh.currentClip, anim.motionMatching.player!.matchedClip, reason: 'gltfio continues the matched clip');
      world.cleanup();
      return (played, pose, anim);
    }

    final databases = {MotionMatchingBlueprintFixture.databasePath: MotionMatchingBlueprintFixture.database};

    test('every Motion Matching state starts loading its database at begin play, before it is entered', () async {
      final base = MotionMatchingBlueprintFixture.animBlueprint();
      final machine = base.stateMachine!;
      const second = 'contents/animations/PSD_Rig_Second.lmas';
      final doc = LuminaAnimBlueprintDocument(
        targetMesh: base.targetMesh,
        variables: base.variables,
        eventGraph: base.eventGraph,
        stateMachines: [
          LuminaAnimStateMachine(
            name: machine.name,
            entryState: machine.entryState,
            states: [machine.states.first, const LuminaAnimState('Frozen', LuminaAnimPose.motionMatching(second))],
            transitions: machine.transitions,
          ),
        ],
      );
      final cls = LuminaAnimBlueprintClass.fromDocument(doc,
          poseDatabases: {...databases, second: MotionMatchingBlueprintFixture.database});
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      world.initializeNativeContext(engine, scene);
      final mesh = LuminaAnimatedMeshComponent(meshAssetPath: MotionMatchingBlueprintFixture.meshPath);
      final anim = cls.instantiate(mesh);
      world.persistentLevel.registerActor(LuminaActor(root: LuminaSceneComponent())
        ..addComponent(LuminaCharacterMovementComponent())
        ..addComponent(anim)
        ..addComponent(mesh));
      world.beginPlay();
      await mesh.loaded;
      for (var i = 0; i < 500 && !anim.motionMatching.isLoaded(second); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(anim.currentState, 'Locomotion');
      expect(anim.motionMatching.isLoaded(MotionMatchingBlueprintFixture.databasePath), isTrue);
      expect(anim.motionMatching.isLoaded(second), isTrue, reason: 'loaded without entering Frozen');
      world.cleanup();
    });

    test('the VM plays idle, start, loop, stop and idle as the pawn walks and stops', () async {
      final cls = LuminaAnimBlueprintClass.fromDocument(MotionMatchingBlueprintFixture.animBlueprint(), poseDatabases: databases);
      final (played, _, _) = await run(cls.instantiate);
      expect(played, ['Idle', 'Start', 'WalkF', 'Stop', 'Idle']);
    });

    test('the generated class matches the VM clip for clip and joint for joint', () async {
      final cls = LuminaAnimBlueprintClass.fromDocument(MotionMatchingBlueprintFixture.animBlueprint(), poseDatabases: databases);
      final (vmPlayed, vmPose, _) = await run(cls.instantiate);
      LuminaPoseSearchDatabaseRuntime.clearShared();
      final (genPlayed, genPose, gen) = await run(AbpMotionMatching.create);
      expect(gen, isA<AbpMotionMatching>());
      expect(genPlayed, vmPlayed);
      for (var k = 0; k < vmPose.length; k++) {
        expect(genPose[k], closeTo(vmPose[k], 1e-6));
      }
    });
  });
}
