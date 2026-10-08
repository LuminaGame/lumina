import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_core/testing.dart';
import 'package:vector_math/vector_math_64.dart';

import '../../../blueprint/motion_matching_blueprint.dart';
import '../../../blueprint/traversal_blueprint.dart';

/// The traversal component on a Blueprint character (Jump → Try Traversal
/// Action → Jump when it fails) in a headless world, and the Animation
/// Blueprint's default slot handing back to motion matching.
void main() {
  final actions = [const LuminaInputAction('IA_Jump')];

  ({LuminaWorld world, LuminaBlueprintCharacter character, LuminaInputSubsystem input, LuminaPlayerController pc, LuminaTraversalComponent traversal})
      spawn({double height = 100, double depth = 30}) {
    final world = LuminaWorld(worldType: LuminaWorldType.game);
    world.subsystems.registerSubsystem<LuminaCollisionSubsystem>(LuminaCollisionSubsystem(), world);
    final input = world.registerSubsystem(LuminaInputSubsystem())
      ..addMappingContext(LuminaInputMappingContext()..mapKey(LuminaKey.keySpace, actions.first));
    TraversalBlueprintFixture.level(world, height: height, depth: depth);
    final character = LuminaBlueprintClass.fromDocument(TraversalBlueprintFixture.characterBlueprint(inputActions: actions),
            inputActions: actions)
        .instantiate(location: Vector3(0, 90.2, 0)) as LuminaBlueprintCharacter;
    world.persistentLevel.registerActor(character);
    final pc = LuminaPlayerController();
    pc.possess(character);
    world.beginPlay();
    final traversal = character.blueprintComponents['traversal'] as LuminaTraversalComponent;
    traversal.useRig(TraversalBlueprintFixture.rig());
    for (var i = 0; i < 5; i++) {
      pc.onTick(1 / 60);
      world.tick(1 / 60);
    }
    return (world: world, character: character, input: input, pc: pc, traversal: traversal);
  }

  /// Presses Space while running at [speed] toward −Z, then ticks until the
  /// action ends (or [seconds]); returns the root location when the clip
  /// time passed [mark].
  Vector3? pressJump(
    ({LuminaWorld world, LuminaBlueprintCharacter character, LuminaInputSubsystem input, LuminaPlayerController pc, LuminaTraversalComponent traversal}) s, {
    double speed = 400,
    double mark = -1,
    double seconds = 3,
  }) {
    s.character.characterMovement.velocity.setValues(0, 0, -speed);
    s.input.injectKeyDown(LuminaKey.keySpace);
    Vector3? atMark;
    for (var i = 0; i < seconds * 60; i++) {
      if (i == 2) s.input.injectKeyUp(LuminaKey.keySpace);
      s.pc.onTick(1 / 60);
      s.world.tick(1 / 60);
      final p = s.traversal.player;
      if (p != null && atMark == null && p.time >= mark - 1e-9 && mark >= 0) atMark = p.rootLocation.clone();
      if (i > 2 && !s.traversal.isTraversing && s.traversal.actionCount > 0) break;
    }
    return atMark;
  }

  test('jumping at a 100 cm wall hurdles it: root on the front ledge and the back floor, walking behind it', () {
    final s = spawn();
    final mode = <MovementMode>{};
    s.traversal.onTraversalFinished = (action, interrupted) => mode.add(s.character.characterMovement.movementMode);
    s.character.characterMovement.velocity.setValues(0, 0, -400);
    s.input.injectKeyDown(LuminaKey.keySpace);
    s.pc.onTick(1 / 60);
    s.world.tick(1 / 60);
    expect(s.traversal.isTraversing, isTrue, reason: '${s.traversal.lastCheck}');
    expect(s.traversal.currentAction, LuminaTraversalActionType.hurdle);
    expect(s.character.characterMovement.movementMode, MovementMode.custom);
    final check = s.traversal.lastCheck!;
    expect(check.frontLedge.z, closeTo(-200, 0.5));
    Vector3? atFront, atFloor;
    for (var i = 0; i < 180 && s.traversal.isTraversing; i++) {
      if (i == 1) s.input.injectKeyUp(LuminaKey.keySpace);
      s.pc.onTick(1 / 60);
      s.world.tick(1 / 60);
      final p = s.traversal.player;
      if (p == null) break;
      if (atFront == null && p.time >= 0.55 - 1e-6) atFront = p.rootLocation.clone();
      if (atFloor == null && p.time >= 1.05 - 1e-6) atFloor = p.rootLocation.clone();
    }
    expect(atFront!.distanceTo(check.frontLedge), lessThan(10.0),
        reason: 'one frame of root motion past the window end at most; $atFront vs ${check.frontLedge}');
    expect(atFloor!.y, closeTo(check.backFloor.y, 2.0));
    expect(s.traversal.isTraversing, isFalse);
    expect(mode.single, MovementMode.walking);
    expect(s.character.actorLocation.z, lessThan(-230 - 35), reason: 'behind the wall');
    expect(s.character.actorLocation.y, closeTo(90, 2.0), reason: 'on the floor');
    expect(s.traversal.actionCount, 1);
  });

  test('the root lands exactly on the warp target at the window end', () {
    final s = spawn();
    final atFront = pressJump(s, mark: 0.55);
    final check = s.traversal.lastCheck!;
    // The window end falls between two ticks: the root is within one tick of
    // root motion (≈ 2.7 cm at 160 cm/s) past it.
    expect(atFront!.distanceTo(check.frontLedge), lessThan(6.0), reason: '$atFront vs ${check.frontLedge}');
  });

  test('a deep box is mantled: the character ends on top', () {
    final s = spawn(height: 120, depth: 300);
    pressJump(s, speed: 300);
    expect(s.traversal.lastChoice?.animation.action, isNotNull, reason: '${s.traversal.lastCheck}');
    expect(s.traversal.lastChoice!.animation.action, LuminaTraversalActionType.mantle);
    expect(s.character.actorLocation.y, closeTo(120 + 90, 3.0), reason: 'standing on the box');
    expect(s.character.characterMovement.isWalking, isTrue);
  });

  test('with nothing ahead the Blueprint falls back to Jump', () {
    final s = spawn(height: 0);
    s.input.injectKeyDown(LuminaKey.keySpace);
    s.pc.onTick(1 / 60);
    s.world.tick(1 / 60);
    expect(s.traversal.isTraversing, isFalse);
    expect(s.traversal.lastCheck!.reason, 'nothing ahead');
    expect(s.character.characterMovement.isFalling, isTrue, reason: 'jumped');
  });

  test('component properties round-trip the chooser rows', () {
    final c = LuminaTraversalComponent.fromProperties({
      'animations': [for (final a in TraversalBlueprintFixture.animations) a.toJson()],
      'maxLedgeHeight': 200.0,
    });
    expect(c.animations.length, 3);
    expect(c.animations.first.windows.length, 2);
    expect(c.animations.first.windows.first.warpRotation, isTrue);
    expect(c.maxLedgeHeight, 200.0);
  });

  group('Animation Blueprint slot', () {
    late FilamentEngine engine;
    late FilamentScene scene;
    late Directory project;
    String? previousProjectDir;

    setUp(() {
      engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
      scene = engine.createScene();
      project = Directory.systemTemp.createTempSync('lumina_traversal_slot_');
      File('${project.path}/${MotionMatchingBlueprintFixture.meshPath}')
        ..createSync(recursive: true)
        ..writeAsBytesSync(LuminaSyntheticLocomotionRig.build(
            [...MotionMatchingBlueprintFixture.clips(), TraversalBlueprintFixture.hurdle()]));
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

    test('a slot montage takes the mesh from motion matching and hands it back blended', () async {
      final cls = LuminaAnimBlueprintClass.fromDocument(MotionMatchingBlueprintFixture.animBlueprint(),
          poseDatabases: {MotionMatchingBlueprintFixture.databasePath: MotionMatchingBlueprintFixture.database});
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      world.initializeNativeContext(engine, scene);
      final mesh = LuminaAnimatedMeshComponent(meshAssetPath: MotionMatchingBlueprintFixture.meshPath);
      final movement = LuminaCharacterMovementComponent()..maxWalkSpeed = 150.0;
      final anim = cls.instantiate(mesh);
      final pawn = LuminaActor(root: LuminaSceneComponent())
        ..addComponent(movement)
        ..addComponent(anim)
        ..addComponent(mesh);
      world.persistentLevel.registerActor(pawn);
      world.beginPlay();
      await mesh.loaded;
      await anim.motionMatching.load(MotionMatchingBlueprintFixture.databasePath);
      for (var i = 0; i < 90; i++) {
        movement.addInputVector(Vector3(0, 0, -1));
        world.tick(1 / 60);
      }
      final mm = anim.motionMatching.player!;
      expect(mesh.poseDriver, same(mm));
      final rig = mm.database.rig;
      final shownBefore = Float64List.fromList(mm.pose);
      var ended = 0;
      final player = LuminaRootMotionMontagePlayer(
        rig: rig,
        clip: rig.sampler.clipIndex('Hurdle')!,
        montage: const LuminaRootMotionMontage(clip: 'Hurdle', endTime: 0.5),
        owner: pawn,
        worldUnitsPerModelUnit: 100,
        onEnded: (_, interrupted) => ended++,
      );
      final start = pawn.actorLocation.clone();
      anim.playSlot(player);
      expect(anim.slotPlayer, same(player));
      double distance(Float64List a, Float64List b) {
        var m = 0.0;
        for (var i = 0; i < a.length; i++) {
          m = math.max(m, (a[i] - b[i]).abs());
        }
        return m;
      }

      expect(distance(player.pose, shownBefore), lessThan(1e-9), reason: 'starts from the motion matching pose');
      final state = anim.currentState;
      for (var i = 0; i < 30; i++) {
        world.tick(1 / 60);
        expect(anim.currentState, state, reason: 'the state machine holds');
      }
      expect(ended, 1);
      expect(anim.slotPlayer, isNull);
      expect(pawn.actorLocation.distanceTo(start), greaterThan(70), reason: 'the root motion moved the pawn');
      final last = Float64List.fromList(player.pose);
      world.tick(1 / 60);
      expect(mesh.poseDriver, same(mm), reason: 'motion matching takes the mesh back');
      expect(distance(mm.pose, last), lessThan(0.05), reason: 'blending from the montage\'s last pose, not popping');
      world.cleanup();
    });
  });
}
