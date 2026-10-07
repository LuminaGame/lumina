import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/features/main_editor/services/pie_controller.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

/// Pressing Play used to mount the level and stop there: no pawn was
/// spawned, nothing was possessed, and no key or mouse event reached the world.
///
/// These tests drive the gameplay half of PIE against a real [LuminaWorld],
/// without Filament: mounting into the native scene is the viewport's job and
/// is covered by the GPU smoke.
void main() {
  List<EditorActorNode> templateActors(String templateId) => GameTemplateCatalog.byId(templateId)
      .levelActors
      .map(EditorActorNode.fromMap)
      .toList();

  /// Everything except the primitives, whose mesh upload needs a live engine.
  List<EditorActorNode> gameplayActorsOf(String templateId) =>
      templateActors(templateId).where((a) => a.type != 'Primitive').toList();

  EditorPieGame startedGame(String templateId, {List<EditorActorNode>? actors}) {
    final project = LuminaProject(projectName: 'PieGame', template: templateId);
    final game = EditorPieGame(
      actors ?? gameplayActorsOf(templateId),
      templateKind: GameTemplateCatalog.byId(templateId).kind,
      input: ProjectInputBinder.bind(project.input.actions.isEmpty
          ? GameTemplateCatalog.byId(templateId).input
          : project.input),
    );
    final world = LuminaWorld();
    game.mountIntoWorldForTest(world);
    return game;
  }

  group('mapEditorActor learns the types the templates seed', () {
    test('a PlayerStart becomes a real LuminaPlayerStart the game mode can find', () {
      final mapped = EditorPieGame.mapEditorActor(
        EditorActorNode(id: 'ps', name: 'PlayerStart', type: 'PlayerStart', location: [1, 2, 3]),
      );
      expect(mapped, isA<LuminaPlayerStart>());
      // Stored Z-up (1, 2, 3) → runtime (1, 3, −2): height is Y at runtime.
      expect((mapped as LuminaPlayerStart).actorLocation, Vector3(1, 3, -2));
    });

    test('a Primitive becomes geometry with a collider, not an empty transform', () {
      final mapped = EditorPieGame.mapEditorActor(EditorActorNode.fromMap(<String, dynamic>{
        'id': 'floor',
        'name': 'Floor',
        'type': 'Primitive',
        'location': [0.0, 0.0, 0.0],
        'components': [
          {
            'id': 'floor_mesh',
            'type': 'LuminaProceduralMeshComponent',
            'properties': {'shape': 'plane', 'sizeX': 2000.0, 'sizeY': 2000.0, 'sizeZ': 0.0, 'colorHex': '#6E7681'},
          },
        ],
      }));
      expect(mapped, isA<LuminaPrimitiveActor>());
      final primitive = mapped as LuminaPrimitiveActor;
      expect(primitive.shape, LuminaPrimitiveShape.plane);
      expect(primitive.size.x, 2000.0);
      expect(primitive.collisionComponent.objectType, CollisionObjectType.worldStatic);
    });
  });

  group('a template project spawns and possesses a character', () {
    test('first person: the pawn stands at the player start and sees from eye height', () {
      final game = startedGame(kFirstPersonTemplateId);

      final controller = game.playerController;
      expect(controller, isNotNull, reason: 'login() must create the local player controller');

      final pawn = controller!.pawn;
      expect(pawn, isA<LuminaTemplateCharacter>());
      final character = pawn as LuminaTemplateCharacter;
      expect(character.thirdPerson, isFalse);
      expect(character.springArmComponent, isNull);

      final start = gameplayActorsOf(kFirstPersonTemplateId).firstWhere((a) => a.type == 'PlayerStart');
      // The stored start is Z up; the runtime spawns at (x, z, −y).
      final spawn = LuminaAxes.location(start.location);
      expect(character.actorLocation.x, closeTo(spawn.x, 1e-6));
      expect(character.actorLocation.z, closeTo(spawn.z, 1e-6));

      expect(character.cameraComponent.worldLocation.y,
          closeTo(character.actorLocation.y + LuminaTemplateCharacterTuning.firstPersonBaseEyeHeight, 1e-6));
    });

    test('third person: the camera rides the boom behind the character', () {
      final game = startedGame(kThirdPersonTemplateId);
      final character = game.playerController!.pawn as LuminaTemplateCharacter;
      expect(character.thirdPerson, isTrue);
      expect(character.springArmComponent!.targetArmLength, LuminaTemplateCharacterTuning.boomLength);
    });

    test('a blank project plays with no pawn, and says so instead of failing', () {
      final game = startedGame(kBlank3dTemplateId, actors: gameplayActorsOf(kBlank3dTemplateId));
      expect(game.playerController, isNull);
      expect(game.playerPawn, isNull);
    });
  });

  group('input reaches the possessed pawn', () {
    test('holding W walks the character forward', () {
      final game = startedGame(kFirstPersonTemplateId);
      final character = game.playerPawn!;
      // The pawn is spawned deferred, so the first tick is what registers it
      // and its input component. Input arrives after that, as it does in the
      // editor, where the user presses a key some frames after pressing Play.
      game.tickGame(1 / 60);
      final before = character.actorLocation.clone();

      game.injectKeyDown(LuminaKey.keyW);
      for (var i = 0; i < 30; i++) {
        game.tickGame(1 / 60);
      }
      game.injectKeyUp(LuminaKey.keyW);

      // Horizontal only: gravity moves the character down whatever the input
      // does, so a distance that included Y would pass with no input at all.
      final moved = character.actorLocation - before;
      final horizontal = math.sqrt(moved.x * moved.x + moved.z * moved.z);
      expect(horizontal, greaterThan(50),
          reason: 'half a second of W must walk the character, got $horizontal cm');
    });

    test('with no key held the character does not walk anywhere', () {
      final game = startedGame(kFirstPersonTemplateId);
      final character = game.playerPawn!;
      game.tickGame(1 / 60);
      final before = character.actorLocation.clone();
      for (var i = 0; i < 30; i++) {
        game.tickGame(1 / 60);
      }
      final moved = character.actorLocation - before;
      expect(math.sqrt(moved.x * moved.x + moved.z * moved.z), lessThan(1e-6),
          reason: 'the walking test must not be able to pass on gravity alone');
    });

    test('a mouse delta yaws the controller, and the pawn follows it', () {
      final game = startedGame(kFirstPersonTemplateId);
      final controller = game.playerController!;
      game.tickGame(1 / 60);
      final yawBefore = controller.controlRotation.y;

      game.injectMouseDelta(120.0, 0.0);
      game.tickGame(1 / 60);

      expect(controller.controlRotation.y,
          closeTo(yawBefore + 120.0 * LuminaTemplateCharacterTuning.lookSensitivity, 1e-6));
    });

    test('pitch is clamped by the controller, not left to run away', () {
      final game = startedGame(kFirstPersonTemplateId);
      final controller = game.playerController!;
      game.tickGame(1 / 60);
      for (var i = 0; i < 20; i++) {
        game.injectMouseDelta(0.0, -500.0);
        game.tickGame(1 / 60);
      }
      expect(controller.controlRotation.x.abs(), greaterThan(80.0),
          reason: 'the pitch must actually move, or the clamp is not being tested');
      expect(controller.controlRotation.x.abs(), lessThanOrEqualTo(89.9));
    });

    test('nothing is injected into a game that is not playing a pawn', () {
      final game = startedGame(kBlank3dTemplateId);
      // Must not throw: the editor forwards events without knowing the shape
      // of the project.
      game.injectKeyDown(LuminaKey.keyW);
      game.injectMouseDelta(10.0, 10.0);
      game.tickGame(1 / 60);
    });
  });

  group('input routing follows the session state', () {
    PieController controllerFor({required bool playing, required bool paused, required bool ejected}) {
      final vm = EditorViewModel(
        initialProject: LuminaProject(projectName: 'PieGame', template: kFirstPersonTemplateId),
        projectLocation: '/tmp',
        enableTimers: false,
        autoInitAssets: false,
      );
      addTearDown(vm.dispose);
      return PieController(vm)
        ..isPlaying = playing
        ..isPaused = paused
        ..isEjected = ejected;
    }

    test('the game only takes input while playing, unpaused and possessing', () {
      expect(controllerFor(playing: true, paused: false, ejected: false).acceptsGameInput, isTrue);
      expect(controllerFor(playing: false, paused: false, ejected: false).acceptsGameInput, isFalse);
      expect(controllerFor(playing: true, paused: true, ejected: false).acceptsGameInput, isFalse);
      expect(controllerFor(playing: true, paused: false, ejected: true).acceptsGameInput, isFalse,
          reason: 'an ejected user flies the editor camera instead');
    });
  });

  group('the editor wires PIE to the project', () {
    test('the controller reads the template and the input settings off the manifest', () {
      final template = GameTemplateCatalog.byId(kThirdPersonTemplateId);
      final vm = EditorViewModel(
        initialProject: LuminaProject(
          projectName: 'PieGame',
          template: kThirdPersonTemplateId,
          input: template.input,
        ),
        projectLocation: '/tmp',
        enableTimers: false,
        autoInitAssets: false,
      );
      addTearDown(vm.dispose);
      final pie = PieController(vm);

      expect(pie.templateKindForProject(), GameTemplateKind.thirdPerson);
      expect(pie.acceptsGameInput, isFalse, reason: 'nothing is playing yet');
      final bound = pie.boundInputForProject();
      expect(bound.actionByName('IA_Move'), isNotNull);
      expect(bound.contexts.single.context.mappingsForKey(LuminaKey.keyW), isNotEmpty);
    });
  });

  // The Third Person template's mannequin, in Play.
  group('the Third Person mannequin', () {
    EditorPieGame thirdPersonGame({String? mannequin, String templateId = kThirdPersonTemplateId}) {
      final game = EditorPieGame(
        gameplayActorsOf(templateId),
        templateKind: GameTemplateCatalog.byId(templateId).kind,
        input: ProjectInputBinder.bind(GameTemplateCatalog.byId(templateId).input),
        mannequinMeshPath: mannequin,
      );
      game.mountIntoWorldForTest(LuminaWorld());
      return game;
    }

    test('a third-person project with a mannequin plays it', () {
      final game = thirdPersonGame(mannequin: '/p/${LuminaThirdPersonContent.projectMeshGlbPath}');
      final character = game.playerPawn!;
      expect(character.bodyMesh, isNotNull);
      expect(character.bodyMesh!.meshAssetPath, '/p/${LuminaThirdPersonContent.projectMeshGlbPath}');
      expect(character.locomotion, isNotNull);
    });

    test('an older third-person project without one still plays, with no body', () {
      final game = thirdPersonGame();
      expect(game.playerPawn!.bodyMesh, isNull);
    });

    test('first person never gets the mannequin', () {
      final game = thirdPersonGame(mannequin: '/p/m.glb', templateId: kFirstPersonTemplateId);
      expect(game.playerPawn!.bodyMesh, isNull);
    });

    test('the template level brings its own sun; a level without one does not', () {
      expect(thirdPersonGame().providesSunlight, isTrue);

      final noSun = EditorPieGame(
        gameplayActorsOf(kThirdPersonTemplateId).where((a) => a.type != 'DirectionalLight').toList(),
        templateKind: GameTemplateKind.thirdPerson,
        input: ProjectInputBinder.bind(GameTemplateCatalog.byId(kThirdPersonTemplateId).input),
      )..mountIntoWorldForTest(LuminaWorld());
      expect(noSun.providesSunlight, isFalse);
    });

    test('the controller finds the mannequin a Third Person project carries, and only then', () {
      final tempDir = Directory.systemTemp.createTempSync('lumina_pie_mannequin_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final vm = EditorViewModel(
        initialProject: const LuminaProject(projectName: 'MannequinGame', template: kThirdPersonTemplateId),
        projectLocation: tempDir.path,
        enableTimers: false,
        autoInitAssets: false,
      );
      addTearDown(vm.dispose);
      final pie = PieController(vm);

      expect(pie.mannequinPathForProject(), isNull, reason: 'no mesh on disk yet');

      final glb = File('${tempDir.path}/MannequinGame/${LuminaThirdPersonContent.projectMeshGlbPath}')
        ..createSync(recursive: true)
        ..writeAsBytesSync([0x67, 0x6C, 0x54, 0x46]);
      expect(pie.mannequinPathForProject(), glb.path);
    });
  });

  // Turning with the mouse must not shake the boom camera: the
  // spring arm writes the camera's offset for the pawn's rotation of that
  // frame, so the pawn must have turned before the arm ticks.
  test('while turning, the third-person camera stays on its boom socket', () {
    final game = EditorPieGame(
      gameplayActorsOf(kThirdPersonTemplateId),
      templateKind: GameTemplateKind.thirdPerson,
      input: ProjectInputBinder.bind(GameTemplateCatalog.byId(kThirdPersonTemplateId).input),
    )..mountIntoWorldForTest(LuminaWorld());
    game.tickGame(1 / 60);
    final character = game.playerPawn!;
    final arm = character.springArmComponent!;
    arm.bEnableCameraLag = false;
    arm.bEnableCameraRotationLag = false;

    for (var i = 0; i < 20; i++) {
      game.injectMouseDelta(30.0, 0.0);
      game.tickGame(1 / 60);
      final eye = character.cameraComponent.worldLocation;
      final socket = arm.socketWorldLocation;
      expect((eye - socket).length, lessThan(1e-6), reason: 'frame $i: camera off its socket by ${(eye - socket).length} m');
    }
    expect(game.playerController!.controlRotation.y.abs(), greaterThan(10.0), reason: 'the mouse must have turned the view');
  });

  // Play takes the editor's own actors out of the scene; Stop
  // restores the level from a serialized snapshot. The parsed meshes cannot be
  // serialized, and without them the viewport has nothing to put back.
  test('restoring the pre-Play snapshot keeps every actor\'s parsed mesh', () async {
    final tempDir = Directory.systemTemp.createTempSync('lumina_pie_snapshot_');
    addTearDown(() => tempDir.deleteSync(recursive: true));
    final vm = EditorViewModel(
      initialProject: const LuminaProject(projectName: 'SnapshotGame'),
      projectLocation: tempDir.path,
      enableTimers: false,
      autoInitAssets: false,
    );
    addTearDown(vm.dispose);

    final mesh = (await GlbParserService.parseGlb(
      PrimitiveGlbFactory.build(shape: 'box', sizeX: 1, sizeY: 1, sizeZ: 1),
    ))!;
    final crate = EditorActorNode(id: 'crate', name: 'Crate', type: 'Primitive', location: [0, 0, 0])
      ..meshData = mesh;
    vm.addActorNodeForTest(crate);

    final snapshot = vm.actors.map((a) => EditorActorNode.fromMap(a.toMap())).toList();
    expect(snapshot.single.meshData, isNull, reason: 'the premise: a snapshot cannot carry the parsed mesh');

    vm.restoreSnapshot(snapshot);
    expect(vm.actors.single.meshData, same(mesh));
  });
}
