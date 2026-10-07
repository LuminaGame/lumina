import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_filament/src/third_party/filament_c.g.dart' as c;
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina/testing.dart';
import 'package:vector_math/vector_math_64.dart';

import '../../../lumina/test/blueprint/anim_blueprints.dart';
import '../blueprint/blueprint_function_fixture.dart';
import '../../../lumina/test/blueprint/fixtures/project_functions/blueprint/blueprint_functions.g.dart';
import '../../../lumina/test/blueprint/fixtures/project_functions/markers.dart';
import '../../../lumina/test/blueprint/generated/bp_anim_character.g.dart';
import '../../../lumina/test/blueprint/generated/bp_third_person_template.g.dart';
import '../../../lumina/test/blueprint/generated/project_registry/blueprint_registry.g.dart';
import '../blueprint/registry_project_fixture.dart';
import '../../../lumina/test/blueprint/level_blueprint_fixture.dart';
import '../../../lumina/test/blueprint/level_load_fixture.dart';
import '../data/project_template_test.dart' show realFilesystemRunner;
import '../../../lumina/test/blueprint/third_person_blueprint.dart';
import '../helpers/lumina_package.dart';

/// Blueprint smokes on a real GPU, in the Third Person yard.
const _w = SmokeVideo.defaultWidth; // smoke videos are at least 1024×768
const _h = SmokeVideo.defaultHeight;

class _Yard {
  _Yard() {
    engine = FilamentEngine.create()!;
    scene = engine.createScene();
    view = engine.createView();
    renderer = engine.createRenderer();
    swapChain = engine.createHeadlessSwapChain(_w, _h);
    camera = engine.createCamera(engine.createEntity());
    view
      ..scene = scene
      ..camera = camera
      ..setViewport(0, 0, _w, _h);
    camera.setProjection(fovDegrees: 60, aspect: _w / _h, near: 10, far: 100000, direction: FovDirection.vertical);
    world = LuminaWorld(worldType: LuminaWorldType.game)..initializeNativeContext(engine, scene);
    world.registerSubsystem(LuminaCollisionSubsystem());
    world.bindView(view);
    // The stored template level, converted as the generated game does.
    for (final a in GameTemplateCatalog.thirdPerson.levelActors) {
      final loc = (a['location'] as List).cast<num>();
      final rot = (a['rotation'] as List? ?? const [0, 0, 0]).cast<num>();
      if (a['type'] == 'PlayerStart') start = LuminaAxes.location(loc);
      if (a['type'] == 'DirectionalLight') {
        world.persistentLevel.registerActor(LuminaActor(
            root: LuminaDirectionalLightComponent(rotation: LuminaAxes.rotation(rot), intensity: 100000, castShadows: true)));
      }
      if (a['type'] != 'Primitive') continue;
      final props = Map<String, dynamic>.from(((a['components'] as List).first as Map)['properties'] as Map);
      world.persistentLevel.registerActor(
          LuminaPrimitiveActor.fromComponentProperties(props, location: LuminaAxes.location(loc)));
    }
    scene.setSkybox(FilamentSkybox.build(engine, color: Vector4(0.4, 0.55, 0.8, 1), intensity: 30000));
    scene.setIndirectLight(FilamentIndirectLight.build(
      engine,
      irradiance: SphericalHarmonics(bands: 1, coefficients: [0.6, 0.65, 0.7]),
      intensity: 30000,
    ));
  }

  late final FilamentEngine engine;
  late final FilamentScene scene;
  late final FilamentView view;
  late final FilamentRenderer renderer;
  late final FilamentSwapChain swapChain;
  late final FilamentCamera camera;
  late final LuminaWorld world;
  Vector3 start = Vector3.zero();
  final ffi.Pointer<ffi.Uint8> _pixels = calloc<ffi.Uint8>(_w * _h * 4);

  /// Looks from [cameraComponent] and reads one frame back.
  Uint8List capture(LuminaCameraComponent cameraComponent, Vector3 target) {
    final eye = cameraComponent.worldLocation;
    camera.lookAt(eyeX: eye.x, eyeY: eye.y, eyeZ: eye.z, centerX: target.x, centerY: target.y, centerZ: target.z);
    for (var i = 0; i < 3; i++) {
      if (renderer.beginFrame(swapChain)) {
        renderer.render(view);
        if (i == 2) {
          c.filament_renderer_read_pixels(renderer.nativePointer, engine.nativePointer, 0, 0, _w, _h, _pixels.cast(), ffi.nullptr, ffi.nullptr);
        }
        renderer.endFrame();
      }
      engine.flushAndWait();
    }
    return Uint8List.fromList(_pixels.asTypedList(_w * _h * 4));
  }

  /// Reads one frame back as the world aimed the bound view's camera (its
  /// active camera, or the player camera manager's view target / blend),
  /// without re-aiming it.
  Uint8List captureView() {
    for (var i = 0; i < 3; i++) {
      if (renderer.beginFrame(swapChain)) {
        renderer.render(view);
        if (i == 2) {
          c.filament_renderer_read_pixels(renderer.nativePointer, engine.nativePointer, 0, 0, _w, _h, _pixels.cast(), ffi.nullptr, ffi.nullptr);
        }
        renderer.endFrame();
      }
      engine.flushAndWait();
    }
    return Uint8List.fromList(_pixels.asTypedList(_w * _h * 4));
  }

  void dispose() {
    world.cleanup();
    calloc.free(_pixels);
    engine.dispose();
  }
}

/// The template character's Event Tick ([tick]) and the last exec output of
/// the chain it drives ([node].[pin]), where a scenario splices its own Tick
/// work: a Blueprint holds one Event Tick, and the template's already traces
/// for WallAhead.
({String tick, String node, String pin}) _templateTickTail(LuminaBlueprintDocument doc) {
  final graph = doc.eventGraph;
  final tick = graph.nodes.singleWhere((n) => n.registryId == 'event_tick');
  var node = tick;
  var pin = 'exec_tick_out';
  while (true) {
    final next = graph.wires.where((w) => w.fromNodeId == node.id && w.fromPinId == pin).toList();
    if (next.isEmpty) return (tick: tick.id, node: node.id, pin: pin);
    node = graph.node(next.single.toNodeId)!;
    pin = node.outputs.firstWhere((p) => p.type == LuminaPinType.exec).id;
  }
}

void main() {
  test('blueprint: node library functions drive a real character', () async {
    final yard = _Yard();
    addTearDown(yard.dispose);
    final character = LuminaTemplateCharacter(
      thirdPerson: true,
      meshAssetPath: luminaPackageFile(LuminaThirdPersonContent.bundledMeshPath),
      location: yard.start,
    );
    final pc = LuminaPlayerController()..possess(character);
    yard.world.persistentLevel.registerActor(character);
    yard.world.beginPlay();
    await character.bodyMesh!.loaded;

    // Only function-library calls, the way a Blueprint graph drives it.
    final startLocation = LuminaBlueprintFunctionLibrary.getActorLocation(character);
    for (var frame = 0; frame < 120; frame++) {
      if (frame < 40) {
        LuminaBlueprintFunctionLibrary.addMovementInput(character, LuminaBlueprintFunctionLibrary.getForwardVector(LuminaRotator(0, 0, LuminaBlueprintFunctionLibrary.getControlRotation(character).yaw)), 1);
      } else if (frame < 70) {
        LuminaBlueprintFunctionLibrary.addControllerYawInput(character, 3.0); // 90° over 30 frames
      } else {
        LuminaBlueprintFunctionLibrary.addMovementInput(character, LuminaBlueprintFunctionLibrary.getForwardVector(LuminaRotator(0, 0, LuminaBlueprintFunctionLibrary.getControlRotation(character).yaw)), 1);
        if (frame == 90) LuminaBlueprintFunctionLibrary.jump(character);
        if (frame == 96) LuminaBlueprintFunctionLibrary.stopJumping(character);
      }
      pc.onTick(1 / 60); // LuminaGame ticks its primary controller like this
      yard.world.tick(1 / 60);
    }
    final moved = LuminaBlueprintFunctionLibrary.getActorLocation(character) - startLocation;
    expect(LuminaBlueprintFunctionLibrary.vectorLengthXY(moved), greaterThan(200), reason: 'walked $moved cm');
    expect(LuminaBlueprintFunctionLibrary.getControlRotation(character).yaw, closeTo(90, 1e-6));

    final png = SmokeArtifacts.encodePng(_w, _h,
        yard.capture(character.cameraComponent, character.actorLocation + Vector3(0, 90, 0)));
    SmokeArtifacts.saveScreenshot('blueprint: node library functions drive a real character', png,
        usedAssets: const [LuminaThirdPersonContent.bundledMeshPath]);
  }, timeout: const Timeout(Duration(minutes: 3)));

  // The Third Person character as a Blueprint, run by the VM,
  // driven by real Enhanced Input (W + mouse through the project's contexts).
  test('blueprint: VM character walks the Third Person yard', () async {
    const name = 'blueprint: VM character walks the Third Person yard';
    final yard = _Yard();
    addTearDown(yard.dispose);
    final input = ProjectInputBinder.bind(GameTemplateCatalog.thirdPerson.input);
    final subsystem = yard.world.registerSubsystem(LuminaInputSubsystem());
    for (final c in input.contexts) {
      subsystem.addMappingContext(c.context, priority: c.priority);
    }
    final actions = input.actions.values.toList();
    final doc = thirdPersonCharacterBlueprint(inputActions: actions);
    // The mannequin, facing the Blueprint's forward (+Y authoring). Not
    // animated and not re-aimed per frame until the ABP.
    doc.components.add(LuminaBlueprintComponent(
      id: 'mesh',
      name: 'Mesh',
      type: 'LuminaSkeletalMeshComponent',
      parentId: 'capsule',
      properties: {
        'location': [0.0, 0.0, -LuminaTemplateCharacterTuning.thirdPersonCapsuleHalfHeight],
        'rotation': [0.0, 0.0, 180.0],
        'skeletalMeshAsset': luminaPackageFile(LuminaThirdPersonContent.bundledMeshPath),
      },
    ));
    final cls = LuminaBlueprintClass.fromDocument(doc,
        name: 'BP_ThirdPersonCharacter', inputActions: actions, assetProvider: (path) => File(path).readAsBytes());
    expect(cls.hasErrors, isFalse, reason: '${cls.diagnostics}');
    final character = cls.instantiate(location: yard.start) as LuminaBlueprintCharacter;
    final pc = LuminaPlayerController();
    yard.world.persistentLevel.registerActor(character);
    pc.possess(character);
    yard.world.beginPlay();
    await (character.blueprintComponents['mesh'] as LuminaAnimatedMeshComponent).loaded;
    final camera = character.blueprintComponents['camera'] as LuminaCameraComponent;
    Uint8List shot() => yard.capture(camera, character.actorLocation + Vector3(0, 60, 0));

    final start = character.actorLocation.clone();
    final video = SmokeVideoRecorder(width: _w, height: _h, fps: 30, testName: name);
    addTearDown(video.discard);
    SmokeArtifacts.saveScreenshot('$name 01 start', SmokeArtifacts.encodePng(_w, _h, shot()),
        usedAssets: const [LuminaThirdPersonContent.bundledMeshPath]);
    // 10 s at 60 Hz, W held: north, a 45° turn, north-east, another 45° to
    // east, then a 90° turn to south — a loop around the hurdle that stays in
    // the open yard. Every 2nd tick is a video frame (30 fps, real time).
    bool turning(int frame) =>
        (frame >= 60 && frame < 120) || (frame >= 180 && frame < 240) || (frame >= 360 && frame < 480);
    var turnFrames = 0;
    subsystem.injectKeyDown(LuminaKey.keyW);
    for (var frame = 0; frame < 600; frame++) {
      if (turning(frame)) {
        subsystem.injectAnalog(LuminaKey.mouseX, 5.0);
        turnFrames++;
      }
      pc.onTick(1 / 60);
      yard.world.tick(1 / 60);
      if (frame % 2 == 0) video.addFrame(shot());
    }
    subsystem.injectKeyUp(LuminaKey.keyW);
    final walked = (character.actorLocation - start)..y = 0;
    expect(walked.length, greaterThan(400), reason: 'walked ${walked.length} cm in 10 s');
    expect(pc.controlRotation.y, closeTo(turnFrames * 5.0 * LuminaTemplateCharacterTuning.lookSensitivity, 1e-6));
    SmokeArtifacts.saveScreenshot(name, SmokeArtifacts.encodePng(_w, _h, shot()),
        usedAssets: const [LuminaThirdPersonContent.bundledMeshPath]);
    SmokeArtifacts.saveVideo(
      name,
      video.finish(),
      usedAssets: const [LuminaThirdPersonContent.bundledMeshPath],
    );
  }, timeout: const Timeout(Duration(minutes: 3)));

  // BP_ThirdPersonCharacter's mesh is animated by ABP_Character —
  // the update graph, the Idle / Walk / Jump / FallLoop / Land state machine and the walk
  // blend space — driven by real Enhanced Input.
  test('blueprint: ABP_Character animates the walking mannequin', () async {
    const name = 'blueprint: ABP_Character animates the walking mannequin';
    final yard = _Yard();
    addTearDown(yard.dispose);
    final run = _MannyRun.vm(yard);
    await run.mesh.loaded;
    expect(run.mesh.clipNames, containsAll(LuminaThirdPersonContent.clipNames));

    final video = SmokeVideoRecorder(width: _w, height: _h, fps: 30, testName: name);
    addTearDown(video.discard);
    final seen = <String, Set<String?>>{};
    for (final phase in _MannyRun.script) {
      seen[phase.name] = {};
      phase.begin(run.input);
      for (var frame = 0; frame < phase.frames; frame++) {
        phase.during?.call(run.input, frame);
        run.step();
        seen[phase.name]!.add(run.anim.currentState);
        if (frame % 2 == 0) video.addFrame(run.shot());
        if (frame == phase.frames ~/ 2) {
          SmokeArtifacts.saveScreenshot('$name ${phase.name}', SmokeArtifacts.encodePng(_w, _h, run.shot()),
              usedAssets: const [LuminaThirdPersonContent.bundledMeshPath]);
        }
      }
      phase.end(run.input);
      switch (phase.name) {
        case '01 idle':
          expect(run.mesh.currentClip, LuminaThirdPersonContent.idleClip);
        case '02 walk forward':
          expect(run.mesh.currentClip, 'Walk_Fwd_Loop');
          expect(run.mesh.playRate, closeTo(LuminaTemplateCharacterTuning.thirdPersonMaxWalkSpeed / 250.0, 0.05));
        case '03 strafe right':
          expect(run.mesh.currentClip, 'Walk_Right_Loop');
      }
    }
    expect(seen['04 jump']!, containsAll(['Jump', 'Land']), reason: 'Jump_Start then Jump_Land');
    expect(run.mesh.missingClip, isNull);
    SmokeArtifacts.saveVideo(name, video.finish(), usedAssets: const [LuminaThirdPersonContent.bundledMeshPath]);
  }, timeout: const Timeout(Duration(minutes: 4)));

  // The generated BP_AnimCharacter (and the generated ABP it
  // names) next to the VM running the same documents, on the same input.
  test('blueprint: generated character matches the VM on screen', () async {
    const name = 'blueprint: generated character matches the VM on screen';
    final vmYard = _Yard();
    addTearDown(vmYard.dispose);
    final genYard = _Yard();
    addTearDown(genYard.dispose);
    final vm = _MannyRun.vm(vmYard);
    final gen = _MannyRun.generated(genYard);
    expect(gen.character, isA<BpAnimCharacter>());
    await vm.mesh.loaded;
    await gen.mesh.loaded;

    // VM on the left, generated on the right.
    final video = SmokeVideoRecorder(width: _w * 2, height: _h, fps: 30, testName: name);
    addTearDown(video.discard);
    final vmClips = <String?>[];
    final genClips = <String?>[];
    for (final phase in _MannyRun.script) {
      for (final r in [vm, gen]) {
        phase.begin(r.input);
      }
      for (var frame = 0; frame < phase.frames; frame++) {
        for (final r in [vm, gen]) {
          phase.during?.call(r.input, frame);
          r.step();
        }
        vmClips.add(vm.mesh.currentClip);
        genClips.add(gen.mesh.currentClip);
        if (frame % 2 == 0) video.addFrame(_sideBySide(vm.shot(), gen.shot()));
      }
      for (final r in [vm, gen]) {
        phase.end(r.input);
      }
    }
    expect(genClips, vmClips);
    expect((gen.character.actorLocation - vm.character.actorLocation).length, lessThan(1e-6));

    final a = vm.shot();
    final b = gen.shot();
    SmokeArtifacts.saveScreenshot('$name VM', SmokeArtifacts.encodePng(_w, _h, a),
        usedAssets: const [LuminaThirdPersonContent.bundledMeshPath]);
    SmokeArtifacts.saveScreenshot('$name generated', SmokeArtifacts.encodePng(_w, _h, b),
        usedAssets: const [LuminaThirdPersonContent.bundledMeshPath]);
    var differing = 0;
    for (var i = 0; i < a.length; i += 4) {
      final d = (a[i] - b[i]).abs() + (a[i + 1] - b[i + 1]).abs() + (a[i + 2] - b[i + 2]).abs();
      if (d > 24) differing++;
    }
    expect(differing / (_w * _h), lessThan(0.01), reason: '$differing of ${_w * _h} pixels differ');
    SmokeArtifacts.saveVideo(name, video.finish(), usedAssets: const [LuminaThirdPersonContent.bundledMeshPath]);
  }, timeout: const Timeout(Duration(minutes: 6)));

  // A project on disk whose Maps & Modes names a GameMode
  // Blueprint; the registry compiles it, its Default Pawn Class (the Manny
  // character) and that mesh's Anim Class from their .lmas files, and the
  // game mode spawns and possesses the character at the PlayerStart.
  test('blueprint: GameMode Blueprint spawns the Blueprint character', () async {
    const name = 'blueprint: GameMode Blueprint spawns the Blueprint character';
    final project = Directory.systemTemp.createTempSync('lumina_bp05_smoke_');
    addTearDown(() => project.deleteSync(recursive: true));
    void write(String path, AssetType type, Map<String, dynamic> document) {
      final assetName = path.split('/').last.replaceAll('.lmas', '');
      File('${project.path}/$path')
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(LuminaAsset(
          assetId: assetName,
          name: assetName,
          type: type,
          rawPayload: utf8.encode(jsonEncode(document)),
        ).toProtoBufferBytes());
    }

    const pawnPath = 'contents/blueprints/BP_AnimCharacter.lmas';
    const modePath = 'contents/blueprints/GM_ThirdPerson.lmas';
    File('${project.path}/bp05.lmproject').writeAsStringSync(jsonEncode(LuminaProject(
      projectName: 'bp05',
      template: 'third_person',
      input: GameTemplateCatalog.thirdPerson.input,
      mapsAndModes: const ProjectMapsAndModes(defaultGameMode: modePath),
    ).toMap()));
    final bound = ProjectInputBinder.bind(GameTemplateCatalog.thirdPerson.input);
    final actions = bound.actions.values.toList();
    write(pawnPath, AssetType.actor,
        templateCharacterBlueprint(inputActions: actions, meshAsset: File(LuminaThirdPersonContent.bundledMeshPath).absolute.path)
            .toJson());
    write(LuminaThirdPersonContent.projectAnimBlueprintPath, AssetType.animBlueprint,
        LuminaThirdPersonContent.animBlueprint.toJson());
    write(LuminaThirdPersonContent.projectWalkBlendSpacePath, AssetType.blendSpace,
        LuminaThirdPersonContent.walkBlendSpace.toJson());
    write(LuminaThirdPersonContent.projectLocomotionBlendSpacePath, AssetType.blendSpace,
        LuminaThirdPersonContent.locomotionBlendSpace.toJson());
    write(modePath, AssetType.actor, LuminaBlueprintDocument(
      parentClass: 'LuminaGameMode',
      classDefaults: {'defaultPawnClass': pawnPath, 'playerControllerClass': 'LuminaPlayerController'},
    ).toJson());

    final yard = _Yard();
    addTearDown(yard.dispose);
    final registry = LuminaBlueprintClassRegistry(project.path);
    final modes = LuminaProject.fromMap(
            jsonDecode(File('${project.path}/bp05.lmproject').readAsStringSync()) as Map<String, dynamic>)
        .mapsAndModes;
    final mode = registry.createGameMode(modes);
    expect(mode, isNotNull, reason: '${registry.diagnostics}');
    final input = yard.world.registerSubsystem(LuminaInputSubsystem());
    for (final c in bound.contexts) {
      input.addMappingContext(c.context, priority: c.priority);
    }
    yard.world.persistentLevel.registerActor(LuminaPlayerStart(location: yard.start.clone()));
    yard.world.gameMode = mode;
    yard.world.beginPlay();
    final pc = mode!.login();
    // A spawned actor registers (and its meshes start loading) on the next tick.
    yard.world.tick(1 / 60);
    final character = pc.pawn as LuminaBlueprintCharacter;
    expect(character.blueprintClass.name, 'BP_AnimCharacter');
    expect(((character.actorLocation - yard.start)..y = 0).length, lessThan(1e-3), reason: 'spawned at the PlayerStart');
    final mesh = character.blueprintComponents['mesh'] as LuminaAnimatedMeshComponent;
    final anim = character.blueprintComponents['mesh.anim'] as LuminaAnimBlueprintInstance;
    await mesh.loaded.timeout(const Duration(seconds: 60));
    final camera = character.blueprintComponents['camera'] as LuminaCameraComponent;
    Uint8List shot() => yard.capture(camera, character.actorLocation + Vector3(0, 60, 0));

    final video = SmokeVideoRecorder(width: _w, height: _h, fps: 30, testName: name);
    addTearDown(video.discard);
    final states = <String?>{};
    // 10.5 s at 60 Hz: stand, then walk a loop with W and the mouse.
    for (var frame = 0; frame < 630; frame++) {
      if (frame == 90) input.injectKeyDown(LuminaKey.keyW);
      if (frame >= 180 && frame < 420) input.injectAnalog(LuminaKey.mouseX, 2.0);
      if (frame == 560) input.injectKeyUp(LuminaKey.keyW);
      pc.onTick(1 / 60);
      yard.world.tick(1 / 60);
      states.add(anim.currentState);
      if (frame % 2 == 0) video.addFrame(shot());
      if (frame == 300) {
        SmokeArtifacts.saveScreenshot(name, SmokeArtifacts.encodePng(_w, _h, shot()),
            usedAssets: const [LuminaThirdPersonContent.bundledMeshPath]);
      }
    }
    expect(states, containsAll(['Idle', 'Walk']));
    expect((character.actorLocation - yard.start)..y = 0, isNot(Vector3.zero()));
    SmokeArtifacts.saveVideo(name, video.finish(), usedAssets: const [LuminaThirdPersonContent.bundledMeshPath]);
  }, timeout: const Timeout(Duration(minutes: 4)));

  // A freshly scaffolded Third Person project played the way
  // its generated game plays it — the compiled BP_ThirdPersonCharacter (the
  // committed golden the scaffold's output is checked against), its assets
  // read from the project folder through LuminaAssets.defaultProvider, the
  // project input, and the GameMode Blueprint's pawn at the PlayerStart.
  test('blueprint: Third Person template plays as Blueprints', () async {
    const name = 'blueprint: Third Person template plays as Blueprints';
    final root = Directory.systemTemp.createTempSync('lumina_bp06_smoke_');
    final configDir = Directory.systemTemp.createTempSync('lumina_bp06_smoke_cfg_');
    addTearDown(() {
      root.deleteSync(recursive: true);
      configDir.deleteSync(recursive: true);
    });
    await ProjectRepository(configDir: configDir, processRunner: realFilesystemRunner())
        .createProject(projectName: 'tp_smoke', projectLocation: root.path, template: kThirdPersonTemplateId);
    final dir = '${root.path}/tp_smoke';
    final previousProvider = LuminaAssets.defaultProvider;
    LuminaAssets.defaultProvider = (path) => File(path.startsWith('/') ? path : '$dir/$path').readAsBytes();
    addTearDown(() => LuminaAssets.defaultProvider = previousProvider);

    final yard = _Yard();
    addTearDown(yard.dispose);
    final bound = ProjectInputBinder.bind(GameTemplateCatalog.thirdPerson.input);
    final input = yard.world.registerSubsystem(LuminaInputSubsystem());
    for (final c in bound.contexts) {
      input.addMappingContext(c.context, priority: c.priority);
    }
    yard.world.persistentLevel.registerActor(LuminaPlayerStart(location: yard.start.clone()));
    // What BP_ThirdPersonGameMode compiles to.
    final mode = LuminaGameMode(
      defaultPawnFactory: () => BpThirdPersonCharacter(),
      playerControllerFactory: () => LuminaPlayerController(playerName: 'Player'),
    );
    yard.world.gameMode = mode;
    yard.world.beginPlay();
    final pc = mode.login();
    yard.world.tick(1 / 60);
    final character = pc.pawn as BpThirdPersonCharacter;
    final mesh = character.blueprintComponents['mesh'] as LuminaAnimatedMeshComponent;
    final anim = character.blueprintComponents['mesh.anim'] as LuminaAnimBlueprintInstance;
    final camera = character.blueprintComponents['camera'] as LuminaCameraComponent;
    expect(mesh.meshAssetPath, LuminaThirdPersonContent.projectMeshGlbPath);
    await mesh.loaded.timeout(const Duration(seconds: 60));
    expect(mesh.clipNames, containsAll(LuminaThirdPersonContent.clipNames));
    Uint8List shot() => yard.capture(camera, character.actorLocation + Vector3(0, 60, 0));

    final video = SmokeVideoRecorder(width: _w, height: _h, fps: 30, testName: name);
    addTearDown(video.discard);
    final phases = <(String, int, void Function(int frame))>[
      ('01 idle', 120, (_) {}),
      ('02 walk', 150, (f) {
        if (f == 0) input.injectKeyDown(LuminaKey.keyW);
      }),
      ('03 turn', 150, (f) => input.injectAnalog(LuminaKey.mouseX, 3.0)),
      ('04 jump', 120, (f) {
        if (f == 10) input.injectKeyDown(LuminaKey.keySpace);
        if (f == 20) input.injectKeyUp(LuminaKey.keySpace);
      }),
      ('05 stop', 90, (f) {
        if (f == 0) input.injectKeyUp(LuminaKey.keyW);
      }),
    ];
    final states = <String, Set<String?>>{};
    for (final (phase, frames, step) in phases) {
      states[phase] = {};
      for (var frame = 0; frame < frames; frame++) {
        step(frame);
        pc.onTick(1 / 60);
        yard.world.tick(1 / 60);
        states[phase]!.add(anim.currentState);
        if (frame % 2 == 0) video.addFrame(shot());
        if (frame == frames ~/ 2) {
          SmokeArtifacts.saveScreenshot('$name $phase', SmokeArtifacts.encodePng(_w, _h, shot()),
              usedAssets: const [LuminaThirdPersonContent.bundledMeshPath]);
        }
      }
    }
    expect(states['01 idle'], {'Idle'});
    expect(states['02 walk'], contains('Walk'));
    expect(states['04 jump'], containsAll(['Jump', 'Land']));
    expect(states['05 stop'], contains('Idle'));
    expect(pc.controlRotation.y.abs(), greaterThan(10), reason: 'the mouse turned the character');
    SmokeArtifacts.saveVideo(name, video.finish(), usedAssets: const [LuminaThirdPersonContent.bundledMeshPath]);
  }, timeout: const Timeout(Duration(minutes: 5)));

  // A Dart function exposed with @BlueprintCallable runs as a
  // Blueprint node. The fixture project's lib/ is scanned (Spawn Marker and
  // Marker Ring Offset come out with their pins), the committed registration
  // — what the scanner generates, byte for byte — registers them, and an Actor
  // Blueprint (the mannequin beside a barrel from test-assets) calls Spawn
  // Marker three times, 3 s apart, on a ring around itself, in the VM on a
  // real GPU world while the camera circles it.
  test('blueprint: an annotated Dart function runs as a Blueprint node', () async {
    const name = 'blueprint: an annotated Dart function runs as a Blueprint node';
    final project = createBlueprintFunctionFixtureProject();
    addTearDown(() => project.deleteSync(recursive: true));
    const scanner = BlueprintFunctionScanner();
    final scan = await scanner.scan(Directory('${project.path}/lib'));
    expect(scan.function(spawnMarkerId)!.spec.inputs.map((p) => '${p.id}:${p.type.name}'), ['exec_in:exec', 'at:vector']);
    expect(scan.function(markerRingId)!.spec.kind, LuminaBlueprintNodeKind.pure);
    expect(scanner.generateRegistration(scan, libraryName: 'fixture'),
        File(blueprintFunctionRegistrationGolden).readAsStringSync(),
        reason: 'the registration this smoke runs is the generated one');
    registerProjectBlueprintFunctions();
    addTearDown(LuminaBlueprintFunctionRegistry.clear);

    final barrel = '${SmokeArtifacts.testAssetsDir.absolute.path}/Props/Barrels/fuel_barrel_red.glb';
    final nodes = <LuminaBlueprintNode>[
      LuminaBlueprintNodeLibrary.place('event_beginplay', nodeId: 'begin'),
      LuminaBlueprintNodeLibrary.place('get_actor_location', nodeId: 'here', y: 300),
      LuminaBlueprintNodeLibrary.place('print_string', nodeId: 'done', x: 2400, literals: {'in_string': 'three markers'}),
    ];
    final wires = <LuminaBlueprintWire>[];
    var from = ('begin', 'exec_out');
    for (var i = 0; i < 3; i++) {
      nodes.addAll([
        LuminaBlueprintNodeLibrary.place(markerRingId, nodeId: 'ring$i', x: 300.0 + 700 * i, y: 300, literals: {'index': i}),
        LuminaBlueprintNodeLibrary.place('vector_add', nodeId: 'at$i', x: 500.0 + 700 * i, y: 200),
        LuminaBlueprintNodeLibrary.place(spawnMarkerId, nodeId: 'spawn$i', x: 600.0 + 700 * i),
        if (i < 2) LuminaBlueprintNodeLibrary.place('delay', nodeId: 'wait$i', x: 850.0 + 700 * i, literals: {'duration': 3.0}),
      ]);
      wires.addAll([
        LuminaBlueprintWire(id: 'x$i', fromNodeId: from.$1, fromPinId: from.$2, toNodeId: 'spawn$i', toPinId: 'exec_in'),
        LuminaBlueprintWire(id: 'a$i', fromNodeId: 'here', fromPinId: 'return_value', toNodeId: 'at$i', toPinId: 'a'),
        LuminaBlueprintWire(id: 'b$i', fromNodeId: 'ring$i', fromPinId: 'return_value', toNodeId: 'at$i', toPinId: 'b'),
        LuminaBlueprintWire(id: 'v$i', fromNodeId: 'at$i', fromPinId: 'return_value', toNodeId: 'spawn$i', toPinId: 'at'),
        if (i < 2)
          LuminaBlueprintWire(id: 'd$i', fromNodeId: 'spawn$i', fromPinId: 'exec_out', toNodeId: 'wait$i', toPinId: 'exec_in'),
      ]);
      from = i < 2 ? ('wait$i', 'exec_out') : ('spawn$i', 'exec_out');
    }
    wires.add(LuminaBlueprintWire(id: 'end', fromNodeId: from.$1, fromPinId: from.$2, toNodeId: 'done', toPinId: 'exec_in'));
    final doc = LuminaBlueprintDocument(
      components: [
        LuminaBlueprintComponent(id: 'root', name: 'DefaultSceneRoot', type: 'LuminaSceneComponent'),
        LuminaBlueprintComponent(
          id: 'mesh',
          name: 'Mesh',
          type: 'LuminaSkeletalMeshComponent',
          parentId: 'root',
          properties: {
            'rotation': [0.0, 0.0, 180.0],
            'skeletalMeshAsset': luminaPackageFile(LuminaThirdPersonContent.bundledMeshPath),
          },
        ),
        LuminaBlueprintComponent(
          id: 'barrel',
          name: 'Barrel',
          type: 'LuminaStaticMeshComponent',
          parentId: 'root',
          properties: {
            'location': [90.0, 0.0, 0.0],
            'staticMeshAsset': barrel,
          },
        ),
      ],
      eventGraph: LuminaBlueprintGraph(nodes: nodes, wires: wires),
    );
    final cls = LuminaBlueprintClass.fromDocument(doc,
        name: 'BP_MarkerPlanter', assetProvider: (path) => File(path).readAsBytes());
    expect(cls.diagnostics, isEmpty);

    final yard = _Yard();
    addTearDown(yard.dispose);
    final ground = Vector3(yard.start.x, 0.0, yard.start.z);
    final planter = cls.instantiate(location: ground.clone()) as LuminaBlueprintActor;
    final trace = <LuminaBlueprintTraceEvent>[];
    planter.trace = trace.add;
    final eye = LuminaActor(root: LuminaCameraComponent());
    yard.world.persistentLevel
      ..registerActor(planter)
      ..registerActor(eye);
    yard.world.beginPlay();
    await (planter.blueprintComponents['mesh'] as LuminaAnimatedMeshComponent).loaded.timeout(const Duration(seconds: 60));
    await (planter.blueprintComponents['barrel'] as LuminaStaticMeshComponent).loaded.timeout(const Duration(seconds: 60));
    // The yard's own primitives; the markers are the ones added after.
    final yardActors = yard.world.persistentLevel.actors.toSet();
    List<LuminaPrimitiveActor> markers() => [
          for (final a in yard.world.persistentLevel.actors)
            if (a is LuminaPrimitiveActor && !yardActors.contains(a)) a,
        ];
    final target = ground + Vector3(0, 80, 0);
    Uint8List shot(int frame) {
      // A slow circle round the planter: 100° over the 11 s.
      final angle = (-40.0 + 100.0 * frame / 660) * math.pi / 180.0;
      eye.actorLocation = ground + Vector3(math.sin(angle) * 850.0, 420.0, math.cos(angle) * 850.0);
      return yard.capture(eye.rootComponent as LuminaCameraComponent, target);
    }

    final video = SmokeVideoRecorder(width: _w, height: _h, fps: 30, testName: name);
    addTearDown(video.discard);
    final placed = <int, int>{};
    // 11 s at 60 Hz; every 2nd tick is a video frame (30 fps, real time).
    final shown = <LuminaPrimitiveActor>{};
    for (var frame = 0; frame < 660; frame++) {
      yard.world.tick(1 / 60);
      placed[frame] = markersPlacedBy(planter);
      // A marker's mesh is built asynchronously: show it from the frame it
      // was placed on.
      for (final m in markers()) {
        if (shown.add(m)) await m.meshComponent.loaded.timeout(const Duration(seconds: 30));
      }
      if (frame % 2 == 0) video.addFrame(shot(frame));
      if (frame == 120) {
        SmokeArtifacts.saveScreenshot('$name 01 first marker', SmokeArtifacts.encodePng(_w, _h, shot(frame)),
            usedAssets: [LuminaThirdPersonContent.bundledMeshPath, barrel]);
      }
    }
    expect(placed[60], 1, reason: 'BeginPlay placed the first marker');
    expect(placed[240], 2, reason: 'the second after the 3 s Delay');
    expect(placed[450], 3, reason: 'the third after another 3 s');
    expect(markers(), hasLength(3), reason: 'three posts stand in the world');
    final expected = [
      for (var i = 0; i < 3; i++)
        LuminaBlueprintFunctionLibrary.toRuntime(LuminaBlueprintFunctionLibrary.toAuthoring(ground) + markerRing(i)) +
            Vector3(0, 90, 0),
    ];
    for (final (i, m) in markers().indexed) {
      expect((m.actorLocation - expected[i]).length, lessThan(1e-6), reason: 'marker $i on the ring');
    }
    expect(trace.where((t) => t.registryId == spawnMarkerId), hasLength(3));
    expect(trace.last.printed, 'three markers');
    SmokeArtifacts.saveScreenshot(name, SmokeArtifacts.encodePng(_w, _h, shot(659)),
        usedAssets: [LuminaThirdPersonContent.bundledMeshPath, barrel]);
    SmokeArtifacts.saveVideo(name, video.finish(), usedAssets: [LuminaThirdPersonContent.bundledMeshPath, barrel]);
  }, timeout: const Timeout(Duration(minutes: 4)));

  // A typed widget variable, Get FPSCounter → Set Text (Text)
  // on every Tick, in a real world on the GPU. The frame-rate string is
  // `1 / Delta Seconds → Round → To String → Format Text`.
  test('blueprint: widget element text updates every tick', () async {
    const name = 'blueprint: widget element text updates every tick';
    const hud = LuminaBlueprintWidgetClass(name: 'WBP_HUD', elements: [
      LuminaBlueprintWidgetElement(name: 'FPSCounter', typeName: 'text', props: {'text': 'FPS: 0'}),
      LuminaBlueprintWidgetElement(name: 'Health', typeName: 'progressBar', props: {'percent': 1.0}),
    ]);
    LuminaWidgetClassRegistry.register(hud);
    addTearDown(LuminaWidgetClassRegistry.clear);

    final actions = ProjectInputBinder.bind(GameTemplateCatalog.thirdPerson.input).actions.values.toList();
    final doc = thirdPersonCharacterBlueprint(inputActions: actions);
    final barrel = '${SmokeArtifacts.testAssetsDir.absolute.path}/Props/Barrels/fuel_barrel_red.glb';
    doc.components.addAll([
      LuminaBlueprintComponent(
        id: 'mesh',
        name: 'Mesh',
        type: 'LuminaSkeletalMeshComponent',
        parentId: 'capsule',
        properties: {
          'location': [0.0, 0.0, -LuminaTemplateCharacterTuning.thirdPersonCapsuleHalfHeight],
          'rotation': [0.0, 0.0, 180.0],
          'skeletalMeshAsset': luminaPackageFile(LuminaThirdPersonContent.bundledMeshPath),
        },
      ),
      LuminaBlueprintComponent(
        id: 'barrel',
        name: 'Barrel',
        type: 'LuminaStaticMeshComponent',
        parentId: 'capsule',
        properties: {
          'location': [120.0, 150.0, -LuminaTemplateCharacterTuning.thirdPersonCapsuleHalfHeight],
          'staticMeshAsset': barrel,
        },
      ),
    ]);
    doc.variables.add(const LuminaBlueprintVariable(name: 'HudWidget', typeName: 'Widget:WBP_HUD'));
    final context = LuminaBlueprintTypeContext.forDocument(doc, inputActions: actions, className: 'BP_HudCharacter');
    LuminaBlueprintNode place(String id, String nodeId, [Map<String, dynamic>? literals]) =>
        LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: context);
    var n = 0;
    LuminaBlueprintWire wire(String from, String fromPin, String to, String toPin) =>
        LuminaBlueprintWire(id: 'hw${n++}', fromNodeId: from, fromPinId: fromPin, toNodeId: to, toPinId: toPin);
    doc.eventGraph.nodes.addAll([
      place(LuminaBlueprintNodeLibrary.variableGet, 'hud', {'variable': 'HudWidget'}),
      place(LuminaBlueprintNodeLibrary.isValidBranch, 'hud_valid'),
      place(LuminaBlueprintNodeLibrary.getWidgetElement, 'fps', {'element': 'FPSCounter'}),
      place('float_divide', 'inverse', {'a': 1.0}),
      place('round', 'rounded'),
      place('int_to_string', 'digits'),
      place('format_string', 'label', {'format': 'FPS: {0}'}),
      place('set_element_text', 'set_fps'),
      place('create_widget', 'create', {'class': 'WBP_HUD'}),
      place(LuminaBlueprintNodeLibrary.variableSet, 'set_hud', {'variable': 'HudWidget'}),
      place('add_to_viewport', 'show'),
    ]);
    // The template character already has an Event Tick (its WallAhead
    // trace); the HUD chain runs after its last exec node.
    final tick = _templateTickTail(doc);
    doc.eventGraph.wires.addAll([
      wire(tick.node, tick.pin, 'hud_valid', 'exec_in'),
      wire('hud', 'value', 'hud_valid', 'input_object'),
      wire('hud_valid', 'is_valid', 'set_fps', 'exec_in'),
      wire('hud', 'value', 'fps', 'target'),
      wire('fps', 'return_value', 'set_fps', 'target'),
      wire(tick.tick, 'delta_seconds', 'inverse', 'b'),
      wire('inverse', 'return_value', 'rounded', 'a'),
      wire('rounded', 'return_value', 'digits', 'in_int'),
      wire('digits', 'return_value', 'label', 'arg_0'),
      wire('label', 'return_value', 'set_fps', 'in_text'),
      wire('hud_valid', 'is_not_valid', 'create', 'exec_in'),
      wire('create', 'exec_out', 'set_hud', 'exec_in'),
      wire('create', 'return_value', 'set_hud', 'value'),
      wire('set_hud', 'exec_out', 'show', 'exec_in'),
      wire('set_hud', 'value', 'show', 'target'),
    ]);
    final cls = LuminaBlueprintClass.fromDocument(doc,
        name: 'BP_HudCharacter', inputActions: actions, assetProvider: (path) => File(path).readAsBytes());
    expect(cls.diagnostics, isEmpty, reason: '${cls.diagnostics}');
    expect(doc.eventGraph.node('fps')!.pin('return_value')!.objectClass, 'WidgetElement:text');

    final yard = _Yard();
    addTearDown(yard.dispose);
    final character = cls.instantiate(location: yard.start.clone()) as LuminaBlueprintCharacter;
    final trace = <LuminaBlueprintTraceEvent>[];
    character.trace = trace.add;
    final pc = LuminaPlayerController();
    yard.world.persistentLevel.registerActor(character);
    pc.possess(character);
    yard.world.beginPlay();
    await (character.blueprintComponents['mesh'] as LuminaAnimatedMeshComponent).loaded.timeout(const Duration(seconds: 60));
    await (character.blueprintComponents['barrel'] as LuminaStaticMeshComponent).loaded.timeout(const Duration(seconds: 60));
    final subsystem = yard.world.getSubsystem<LuminaWidgetSubsystem>()!;
    var notified = 0;
    subsystem.activeWidgets.addListener(() => notified++);
    final texts = <String>{};
    for (var frame = 0; frame < 30; frame++) {
      pc.onTick(1 / 60);
      yard.world.tick(1 / 60);
      final widget = character.variables['HudWidget'];
      if (widget is Map<String, Object?>) {
        texts.add(LuminaBlueprintFunctionLibrary.getElementText(LuminaBlueprintFunctionLibrary.getWidgetElement(widget, 'FPSCounter')));
      }
    }
    final widget = subsystem.widgets.single;
    expect(widget['class'], 'WBP_HUD');
    final elements = widget['elements'] as Map<String, Object?>;
    expect((elements['FPSCounter'] as Map)['text'], matches(RegExp(r'^FPS: \d+$')));
    expect((elements['FPSCounter'] as Map)['text'], 'FPS: 60');
    expect((elements['Health'] as Map)['percent'], 1.0, reason: 'the other element is untouched');
    expect(texts, {'FPS: 0', 'FPS: 60'}, reason: 'created on the first tick, written from the second');
    expect(notified, 30, reason: 'Add to Viewport once, then one notification per Set Text');
    expect(trace.where((t) => t.registryId == 'set_element_text').length, 29);
    expect(trace.where((t) => t.registryId == 'create_widget').length, 1);

    final camera = character.blueprintComponents['camera'] as LuminaCameraComponent;
    final png = SmokeArtifacts.encodePng(_w, _h, yard.capture(camera, character.actorLocation + Vector3(0, 60, 0)));
    SmokeArtifacts.saveScreenshot(name, png, usedAssets: [LuminaThirdPersonContent.bundledMeshPath, barrel]);
  }, timeout: const Timeout(Duration(minutes: 3)));

  // Tick → DoN(3) → Print String in a real world on the GPU:
  // three prints, then none, over ten ticks. The trace log is the evidence,
  // saved with the frame's sidecar.
  test('blueprint: flow control drives a counter', () async {
    const name = 'blueprint: flow control drives a counter';
    final actions = ProjectInputBinder.bind(GameTemplateCatalog.thirdPerson.input).actions.values.toList();
    final doc = thirdPersonCharacterBlueprint(inputActions: actions);
    final barrel = '${SmokeArtifacts.testAssetsDir.absolute.path}/Props/Barrels/fuel_barrel_red.glb';
    doc.components.add(LuminaBlueprintComponent(
      id: 'barrel',
      name: 'Barrel',
      type: 'LuminaStaticMeshComponent',
      parentId: 'capsule',
      properties: {'location': [0.0, 200.0, -LuminaTemplateCharacterTuning.thirdPersonCapsuleHalfHeight], 'staticMeshAsset': barrel},
    ));
    doc.variables.add(const LuminaBlueprintVariable(name: 'Ticks', typeName: 'Int', defaultValue: 0));
    final context = LuminaBlueprintTypeContext.forDocument(doc, inputActions: actions, className: 'BP_Counter');
    LuminaBlueprintNode place(String id, String nodeId, [Map<String, dynamic>? literals]) =>
        LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: context);
    var n = 0;
    LuminaBlueprintWire wire(String from, String fromPin, String to, String toPin) =>
        LuminaBlueprintWire(id: 'cw${n++}', fromNodeId: from, fromPinId: fromPin, toNodeId: to, toPinId: toPin);
    doc.eventGraph.nodes.addAll([
      place('sequence', 'seq'),
      place(LuminaBlueprintNodeLibrary.variableGet, 'ticks', {'variable': 'Ticks'}),
      place('int_increment', 'inc'),
      place(LuminaBlueprintNodeLibrary.variableSet, 'set_ticks', {'variable': 'Ticks'}),
      place('do_n', 'three', {'n': 3}),
      place('int_to_string', 'count_text'),
      place('append', 'label', {'a': 'count '}),
      place('print_string', 'say'),
    ]);
    // After the template's own Tick chain (its WallAhead trace).
    final tick = _templateTickTail(doc);
    doc.eventGraph.wires.addAll([
      wire(tick.node, tick.pin, 'seq', 'exec_in'),
      wire('seq', 'then_0', 'set_ticks', 'exec_in'),
      wire('ticks', 'value', 'inc', 'a'),
      wire('inc', 'return_value', 'set_ticks', 'value'),
      wire('seq', 'then_1', 'three', 'exec_in'),
      wire('three', 'exit', 'say', 'exec_in'),
      wire('three', 'counter', 'count_text', 'in_int'),
      wire('count_text', 'return_value', 'label', 'b'),
      wire('label', 'return_value', 'say', 'in_string'),
    ]);
    final cls = LuminaBlueprintClass.fromDocument(doc,
        name: 'BP_Counter', inputActions: actions, assetProvider: (path) => File(path).readAsBytes());
    expect(cls.diagnostics, isEmpty, reason: '${cls.diagnostics}');

    final yard = _Yard();
    addTearDown(yard.dispose);
    final character = cls.instantiate(location: yard.start.clone()) as LuminaBlueprintCharacter;
    final trace = <LuminaBlueprintTraceEvent>[];
    character.trace = trace.add;
    final pc = LuminaPlayerController();
    yard.world.persistentLevel.registerActor(character);
    pc.possess(character);
    yard.world.beginPlay();
    await (character.blueprintComponents['barrel'] as LuminaStaticMeshComponent).loaded.timeout(const Duration(seconds: 60));
    final printedPerTick = <int>[];
    for (var tick = 0; tick < 10; tick++) {
      final before = trace.where((t) => t.printed != null).length;
      pc.onTick(1 / 60);
      yard.world.tick(1 / 60);
      printedPerTick.add(trace.where((t) => t.printed != null).length - before);
    }
    expect(printedPerTick, [1, 1, 1, 0, 0, 0, 0, 0, 0, 0]);
    expect([for (final t in trace) if (t.printed != null) t.printed], ['count 1', 'count 2', 'count 3']);
    expect(character.variables['Ticks'], 10);
    expect(character.blueprintFlowState['three'], 3);
    expect(trace.where((t) => t.registryId == 'do_n').length, 10, reason: 'DoN traced every tick, blocked after three');

    final camera = character.blueprintComponents['camera'] as LuminaCameraComponent;
    final png = SmokeArtifacts.encodePng(_w, _h, yard.capture(camera, character.actorLocation + Vector3(0, 60, 0)));
    final file = SmokeArtifacts.saveScreenshot(name, png, usedAssets: [barrel]);
    // The trace log rides in the frame's sidecar, where the report reads it.
    final sidecar = File(file.path.replaceFirst(RegExp(r'\.png$'), '.json'));
    final meta = jsonDecode(sidecar.readAsStringSync()) as Map<String, dynamic>;
    meta['trace'] = [for (final t in trace) t.toString()];
    sidecar.writeAsStringSync(jsonEncode(meta), flush: true);
  }, timeout: const Timeout(Duration(minutes: 3)));

  // The character traces along its look direction every tick
  // and hits the barrel straight ahead (not the two beside it); after one
  // second its Blueprint blends the view to a security camera over three
  // seconds. The video shows the blend; the PNG is the security camera's
  // view; the trace log rides in the PNG's sidecar.
  test('blueprint: look-forward trace and camera blend', () async {
    const name = 'blueprint: look-forward trace and camera blend';
    final barrel = '${SmokeArtifacts.testAssetsDir.absolute.path}/Props/Barrels/fuel_barrel_red.glb';
    final acUnit = '${SmokeArtifacts.testAssetsDir.absolute.path}/Props/AC_units/aircon_small.glb';
    final actions = ProjectInputBinder.bind(GameTemplateCatalog.thirdPerson.input).actions.values.toList();

    // BP_Target: a barrel with a capsule the trace can hit.
    final targetDoc = LuminaBlueprintDocument(parentClass: 'LuminaActor', components: [
      LuminaBlueprintComponent(id: 'cap', name: 'Capsule', type: 'LuminaCapsuleComponent', properties: {
        'capsuleRadius': 45.0,
        'capsuleHalfHeight': 170.0,
        'location': [0.0, 0.0, 170.0],
      }),
      LuminaBlueprintComponent(id: 'mesh', name: 'Barrel', type: 'LuminaStaticMeshComponent', parentId: 'cap', properties: {
        'location': [0.0, 0.0, -170.0],
        'staticMeshAsset': barrel,
      }),
    ]);
    final targetClass = LuminaBlueprintClass.fromDocument(targetDoc, name: 'BP_Target', assetProvider: (path) => File(path).readAsBytes());
    expect(targetClass.diagnostics, isEmpty, reason: '${targetClass.diagnostics}');
    // BP_SecurityCamera: an AC unit on a pole with an inactive camera looking down at the yard.
    final camDoc = LuminaBlueprintDocument(parentClass: 'LuminaActor', components: [
      LuminaBlueprintComponent(id: 'cam', name: 'Cam', type: 'LuminaCameraComponent', properties: {
        'autoActivate': false,
        'fieldOfView': 70.0,
        'location': [0.0, 0.0, 400.0],
        'rotation': [-28.0, 0.0, 0.0],
      }),
      LuminaBlueprintComponent(id: 'mesh', name: 'Housing', type: 'LuminaStaticMeshComponent', properties: {
        'location': [0.0, -60.0, 180.0],
        'staticMeshAsset': acUnit,
      }),
    ]);
    final camClass = LuminaBlueprintClass.fromDocument(camDoc, name: 'BP_SecurityCamera', assetProvider: (path) => File(path).readAsBytes());
    expect(camClass.diagnostics, isEmpty, reason: '${camClass.diagnostics}');

    // The character: Tick → Line Trace Forward → Branch → Print the hit actor;
    // Tick → Delay 1 s (DoOnce) → Set View Target with Blend (3 s, EaseInOut).
    final doc = thirdPersonCharacterBlueprint(inputActions: actions);
    doc.components.add(LuminaBlueprintComponent(
      id: 'mesh',
      name: 'Mesh',
      type: 'LuminaSkeletalMeshComponent',
      parentId: 'capsule',
      properties: {
        'location': [0.0, 0.0, -LuminaTemplateCharacterTuning.thirdPersonCapsuleHalfHeight],
        'rotation': [0.0, 0.0, 180.0],
        'skeletalMeshAsset': luminaPackageFile(LuminaThirdPersonContent.bundledMeshPath),
      },
    ));
    final context = LuminaBlueprintTypeContext.forDocument(doc, inputActions: actions, className: 'BP_Watcher',
        actorParents: {'BP_Target': 'LuminaActor', 'BP_SecurityCamera': 'LuminaActor'});
    LuminaBlueprintNode place(String id, String nodeId, [Map<String, dynamic>? literals]) =>
        LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: context);
    var n = 0;
    LuminaBlueprintWire wire(String from, String fromPin, String to, String toPin) =>
        LuminaBlueprintWire(id: 'tw${n++}', fromNodeId: from, fromPinId: fromPin, toNodeId: to, toPinId: toPin);
    doc.eventGraph.nodes.addAll([
      place('sequence', 'seq'),
      place('line_trace_forward', 'trace', {'distance': 800.0, 'channel': 'Visibility', 'draw_debug': true}),
      place('branch', 'if_hit'),
      place('break_hit_result', 'hit'),
      place('get_display_name', 'who'),
      place('float_to_string', 'dist_text', {'decimals': 0}),
      place('append_3', 'line', {'b': ' at '}),
      place('print_string', 'say_hit'),
      place('do_once', 'once'),
      place('delay', 'wait', {'duration': 1.0}),
      place('get_all_actors_of_class', 'cams', {'class': 'Actor:BP_SecurityCamera'}),
      place('array_first', 'cam', {'type': 'object', 'class': 'Actor:BP_SecurityCamera'}),
      place('set_view_target_with_blend', 'blend', {'blend_time': 3.0, 'blend_func': 'EaseInOut', 'blend_exp': 2.0}),
      place('print_string', 'say_blend', {'in_string': 'blending to the security camera'}),
    ]);
    // After the template's own Tick chain (its WallAhead trace).
    final tick = _templateTickTail(doc);
    doc.eventGraph.wires.addAll([
      wire(tick.node, tick.pin, 'seq', 'exec_in'),
      wire('seq', 'then_0', 'trace', 'exec_in'),
      wire('trace', 'exec_out', 'if_hit', 'exec_in'),
      wire('trace', 'return_value', 'if_hit', 'condition'),
      wire('trace', 'out_hit', 'hit', 'hit'),
      wire('if_hit', 'true_out', 'say_hit', 'exec_in'),
      wire('hit', 'hit_actor', 'who', 'object'),
      wire('hit', 'distance', 'dist_text', 'in_float'),
      wire('who', 'return_value', 'line', 'a'),
      wire('dist_text', 'return_value', 'line', 'c'),
      wire('line', 'return_value', 'say_hit', 'in_string'),
      wire('seq', 'then_1', 'once', 'exec_in'),
      wire('once', 'completed', 'wait', 'exec_in'),
      wire('wait', 'exec_out', 'blend', 'exec_in'),
      wire('cams', 'return_value', 'cam', 'target_array'),
      wire('cam', 'return_value', 'blend', 'target'),
      wire('blend', 'exec_out', 'say_blend', 'exec_in'),
    ]);
    final cls = LuminaBlueprintClass.fromDocument(doc,
        name: 'BP_Watcher', inputActions: actions, assetProvider: (path) => File(path).readAsBytes());
    expect(cls.diagnostics, isEmpty, reason: '${cls.diagnostics}');

    final yard = _Yard();
    addTearDown(yard.dispose);
    final world = yard.world;
    // Three barrels: one straight ahead (+Y authoring), two beside it; the camera post behind-right.
    final start = LuminaAxes.toAuthoringLocation(yard.start);
    final targets = <LuminaActor>[];
    for (final offset in const [[-160.0, 420.0], [0.0, 320.0], [160.0, 420.0]]) {
      final t = targetClass.instantiate(location: LuminaAxes.location([start[0] + offset[0], start[1] + offset[1], 0.0]));
      targets.add(t);
      world.persistentLevel.registerActor(t);
    }
    final security = camClass.instantiate(location: LuminaAxes.location([start[0] + 350.0, start[1] - 450.0, 0.0]));
    // Aim the post at the barrels: yaw the actor so its camera looks across the yard.
    security.actorRotation = LuminaAxes.rotation([0.0, 0.0, 38.0]);
    world.persistentLevel.registerActor(security);
    final character = cls.instantiate(location: yard.start.clone()) as LuminaBlueprintCharacter;
    final trace = <LuminaBlueprintTraceEvent>[];
    character.trace = trace.add;
    final pc = LuminaPlayerController();
    world.persistentLevel.registerActor(character);
    pc.possess(character);
    world.beginPlay();
    await (character.blueprintComponents['mesh'] as LuminaAnimatedMeshComponent).loaded.timeout(const Duration(seconds: 60));
    for (final t in targets) {
      await ((t as LuminaBlueprintRuntime).blueprintComponents['mesh'] as LuminaStaticMeshComponent).loaded.timeout(const Duration(seconds: 60));
    }
    await ((security as LuminaBlueprintRuntime).blueprintComponents['mesh'] as LuminaStaticMeshComponent).loaded.timeout(const Duration(seconds: 60));

    final video = SmokeVideoRecorder(width: _w, height: _h, fps: 30, testName: name);
    addTearDown(video.discard);
    final follow = character.blueprintComponents['camera'] as LuminaCameraComponent;
    final securityCam = security.blueprintComponents['cam'] as LuminaCameraComponent;
    var midBlendDistance = 0.0;
    // 12 s at 30 Hz: the follow camera, the 3 s blend from t = 1 s, then the security camera.
    for (var frame = 0; frame < 360; frame++) {
      pc.onTick(1 / 30);
      world.tick(1 / 30);
      if (frame == 75) {
        final pov = world.viewPov!;
        midBlendDistance = (pov.location - securityCam.worldLocation).length;
        expect(pc.cameraManager.isBlending, isTrue);
        expect((pov.location - follow.worldLocation).length, greaterThan(50.0), reason: 'half-way: away from the follow camera');
        expect(midBlendDistance, greaterThan(50.0), reason: 'half-way: not at the security camera yet');
      }
      video.addFrame(yard.captureView());
    }
    final hits = [for (final t in trace) if (t.printed != null && t.printed!.startsWith('BP_Target')) t.printed!];
    expect(hits.length, greaterThan(300), reason: 'the trace hits the middle barrel every tick');
    expect(hits.toSet().length, lessThanOrEqualTo(3), reason: 'a steady distance: ${hits.toSet()}');
    expect(int.parse(hits.first.split(' at ').last), inInclusiveRange(200, 330), reason: '320 cm minus the capsule radius');
    expect(trace.where((t) => t.printed == 'blending to the security camera').length, 1);
    expect(pc.cameraManager.viewTarget, same(security));
    expect(pc.cameraManager.isBlending, isFalse);
    final pov = world.viewPov!;
    expect((pov.location - securityCam.worldLocation).length, lessThan(1e-3), reason: 'the view sits on the security camera');
    expect(world.debugShapes, isNotEmpty, reason: 'the last trace drew its debug segment');
    // The green line starts at head height, not a metre above it.
    final traceLine = world.debugShapes.lastWhere((s) => s.kind == LuminaDebugShapeKind.line && s.color[0] == 0.0 && s.color[1] == 1.0);
    final feet = character.actorLocation.y - character.capsuleComponent.halfHeight;
    expect(traceLine.points.first.y - feet, closeTo(LuminaTemplateCharacterTuning.eyeHeightAboveFeet, 5.0),
        reason: 'the trace starts at eye height: $traceLine');
    // The debug segment as a thin green bar, seen from the side next to the
    // mannequin, so the PNG shows where the trace starts.
    final segment = traceLine.points.last - traceLine.points.first;
    final bar = LuminaStaticMeshComponent(
      meshAssetPath: 'smoke-blueprint:trace-bar',
      assetUnitScale: 1.0,
      castShadows: false,
      assetProvider: (_) async => PrimitiveGlbFactory.build(shape: 'box', sizeX: 4.0, sizeY: 4.0, sizeZ: segment.length, colorHex: '#22FF33'),
    );
    world.persistentLevel.registerActor(LuminaActor(
      root: bar,
      location: traceLine.points.first + segment * 0.5,
      rotation: Quaternion.fromTwoVectors(Vector3(0.0, 0.0, 1.0), segment.normalized()),
    ));
    await bar.loaded.timeout(const Duration(seconds: 60));
    final middle = traceLine.points.first + segment * 0.5;
    final sideEye = LuminaCameraComponent(location: Vector3(middle.x + 520.0, feet + 150.0, middle.z));
    final side = yard.capture(sideEye, Vector3(middle.x, feet + 110.0, middle.z));
    SmokeArtifacts.saveScreenshot('$name side view: the trace starts at head height', SmokeArtifacts.encodePng(_w, _h, side),
        usedAssets: [LuminaThirdPersonContent.bundledMeshPath, barrel, acUnit],
        metrics: {'traceStartAboveFeet': traceLine.points.first.y - feet});

    final png = SmokeArtifacts.encodePng(_w, _h, yard.captureView());
    final file = SmokeArtifacts.saveScreenshot(name, png, usedAssets: [LuminaThirdPersonContent.bundledMeshPath, barrel, acUnit]);
    final sidecar = File(file.path.replaceFirst(RegExp(r'\.png$'), '.json'));
    final meta = jsonDecode(sidecar.readAsStringSync()) as Map<String, dynamic>;
    meta['trace'] = [for (final t in trace) if (t.printed != null) t.toString()];
    meta['midBlendDistanceToSecurityCamera'] = midBlendDistance;
    sidecar.writeAsStringSync(jsonEncode(meta), flush: true);
    SmokeArtifacts.saveVideo(name, video.finish(), usedAssets: [LuminaThirdPersonContent.bundledMeshPath, barrel, acUnit]);
  }, timeout: const Timeout(Duration(minutes: 5)));

  // Mouse up / down through Enhanced Input (IA_Look, Mouse Y × −1) turns the
  // follow camera, and the character's Line Trace Forward (Draw Debug, drawn
  // here as a red bar along the debug segment) follows it: up with the
  // camera, then down to the ground in front of the barrels.
  test('blueprint: looking up and down aims the forward trace with the camera', () async {
    const name = 'blueprint: looking up and down aims the forward trace with the camera';
    final barrel = '${SmokeArtifacts.testAssetsDir.absolute.path}/Props/Barrels/fuel_barrel_red.glb';
    final yard = _Yard();
    addTearDown(yard.dispose);
    final world = yard.world;
    final input = ProjectInputBinder.bind(GameTemplateCatalog.thirdPerson.input);
    final subsystem = world.registerSubsystem(LuminaInputSubsystem());
    for (final c in input.contexts) {
      subsystem.addMappingContext(c.context, priority: c.priority);
    }
    final actions = input.actions.values.toList();
    final doc = thirdPersonCharacterBlueprint(inputActions: actions);
    doc.components.add(LuminaBlueprintComponent(
      id: 'mesh',
      name: 'Mesh',
      type: 'LuminaSkeletalMeshComponent',
      parentId: 'capsule',
      properties: {
        'location': [0.0, 0.0, -LuminaTemplateCharacterTuning.thirdPersonCapsuleHalfHeight],
        'rotation': [0.0, 0.0, 180.0],
        'skeletalMeshAsset': luminaPackageFile(LuminaThirdPersonContent.bundledMeshPath),
      },
    ));
    final context = LuminaBlueprintTypeContext.forDocument(doc, inputActions: actions, className: 'BP_Aimer');
    doc.eventGraph.nodes.add(LuminaBlueprintNodeLibrary.place('line_trace_forward',
        nodeId: 'aim_trace', literals: {'distance': 1000.0, 'channel': 'Visibility', 'draw_debug': true}, context: context));
    final tick = _templateTickTail(doc);
    doc.eventGraph.wires.add(LuminaBlueprintWire(id: 'aim_w0', fromNodeId: tick.node, fromPinId: tick.pin, toNodeId: 'aim_trace', toPinId: 'exec_in'));
    final cls = LuminaBlueprintClass.fromDocument(doc, name: 'BP_Aimer', inputActions: actions, assetProvider: (path) => File(path).readAsBytes());
    expect(cls.diagnostics.where((d) => d.isError), isEmpty, reason: '${cls.diagnostics}');

    // Barrels ahead (+Y authoring) for scale: the downward trace lands before them.
    final start = LuminaAxes.toAuthoringLocation(yard.start);
    final barrels = <LuminaStaticMeshComponent>[];
    for (final offset in const [[-220.0, 900.0], [0.0, 1000.0], [220.0, 900.0]]) {
      final mesh = LuminaStaticMeshComponent(meshAssetPath: barrel);
      barrels.add(mesh);
      world.persistentLevel.registerActor(LuminaActor(root: mesh, location: LuminaAxes.location([start[0] + offset[0], start[1] + offset[1], 0.0])));
    }
    final character = cls.instantiate(location: yard.start.clone()) as LuminaBlueprintCharacter;
    final pc = LuminaPlayerController();
    world.persistentLevel.registerActor(character);
    pc.possess(character);
    world.beginPlay();
    await (character.blueprintComponents['mesh'] as LuminaAnimatedMeshComponent).loaded.timeout(const Duration(seconds: 60));
    for (final b in barrels) {
      await b.loaded.timeout(const Duration(seconds: 60));
    }
    // The debug segment as a thin red bar, re-aimed every frame.
    final bar = LuminaStaticMeshComponent(
      meshAssetPath: 'smoke-blueprint:aim-bar',
      assetUnitScale: 1.0,
      castShadows: false,
      assetProvider: (_) async => PrimitiveGlbFactory.build(shape: 'box', sizeX: 8.0, sizeY: 8.0, sizeZ: 1.0, colorHex: '#FF2222'),
    );
    final barActor = LuminaActor(root: bar);
    world.persistentLevel.registerActor(barActor);
    await bar.loaded.timeout(const Duration(seconds: 60));

    final follow = character.blueprintComponents['camera'] as LuminaCameraComponent;
    ({Vector3 from, Vector3 to}) segment() {
      final lines = world.debugShapes.where((s) => s.kind == LuminaDebugShapeKind.line).toList();
      return (from: lines.first.points.first.clone(), to: lines.last.points.last.clone());
    }

    /// The trace seen from the character's right, 11 m out, so the PNG shows
    /// the segment's slope (from behind it hides behind the head).
    Uint8List sideView(({double camera, double trace, Vector3 from, Vector3 to}) a) {
      final middle = (a.from + a.to) * 0.5;
      // Never below the eyes: looking down, the segment runs on under the floor.
      final eye = LuminaCameraComponent(location: Vector3(middle.x + 1100.0, math.max(middle.y, a.from.y), middle.z));
      return yard.capture(eye, middle);
    }

    /// Up (runtime +Y) components of the camera's view and of the traced segment.
    ({double camera, double trace, Vector3 from, Vector3 to}) aim() {
      final s = segment();
      final view = follow.worldRotation.rotateVector(Vector3(0, 0, -1));
      return (camera: view.y, trace: (s.to - s.from).normalized().y, from: s.from, to: s.to);
    }

    const sens = LuminaTemplateCharacterTuning.lookSensitivity;
    // 12 s at 30 Hz: level for 1 s, mouse up 2 s (to +35°), hold, mouse down
    // 4 s (to −30°), hold.
    final video = SmokeVideoRecorder(width: _w, height: _h, fps: 30, testName: name);
    addTearDown(video.discard);
    late ({double camera, double trace, Vector3 from, Vector3 to}) up;
    late ({double camera, double trace, Vector3 from, Vector3 to}) down;
    for (var frame = 0; frame < 360; frame++) {
      // Screen Y grows downward: moving the mouse up is a negative delta.
      if (frame >= 30 && frame < 90) subsystem.injectAnalog(LuminaKey.mouseY, -35.0 / (60 * sens));
      if (frame >= 150 && frame < 270) subsystem.injectAnalog(LuminaKey.mouseY, 65.0 / (120 * sens));
      pc.onTick(1 / 30);
      world.tick(1 / 30);
      final s = segment();
      final d = s.to - s.from;
      barActor.actorLocation = s.from + d * 0.5;
      barActor.actorRotation = Quaternion.fromTwoVectors(Vector3(0.0, 0.0, 1.0), d.normalized());
      barActor.rootComponent.relativeScale = Vector3(1.0, 1.0, d.length);
      final png = yard.captureView();
      video.addFrame(png);
      if (frame == 140) {
        up = aim();
        expect(pc.controlRotation.x, closeTo(35.0, 1e-6), reason: 'mouse up raises the control pitch');
        SmokeArtifacts.saveScreenshot('$name 01 looking up', SmokeArtifacts.encodePng(_w, _h, png),
            usedAssets: [LuminaThirdPersonContent.bundledMeshPath, barrel], metrics: {'cameraUp': up.camera, 'traceUp': up.trace});
        SmokeArtifacts.saveScreenshot('$name 01 looking up, side view', SmokeArtifacts.encodePng(_w, _h, sideView(up)),
            usedAssets: [LuminaThirdPersonContent.bundledMeshPath, barrel], metrics: {'cameraUp': up.camera, 'traceUp': up.trace});
      }
      if (frame == 350) {
        down = aim();
        expect(pc.controlRotation.x, closeTo(-30.0, 1e-6), reason: 'mouse down lowers the control pitch');
        SmokeArtifacts.saveScreenshot('$name 02 looking down', SmokeArtifacts.encodePng(_w, _h, png),
            usedAssets: [LuminaThirdPersonContent.bundledMeshPath, barrel], metrics: {'cameraUp': down.camera, 'traceUp': down.trace});
        SmokeArtifacts.saveScreenshot('$name 02 looking down, side view', SmokeArtifacts.encodePng(_w, _h, sideView(down)),
            usedAssets: [LuminaThirdPersonContent.bundledMeshPath, barrel], metrics: {'cameraUp': down.camera, 'traceUp': down.trace});
      }
    }
    expect(up.camera, closeTo(math.sin(35 * math.pi / 180), 0.02), reason: 'the camera looks 35° up');
    expect(up.trace, closeTo(up.camera, 5e-3), reason: 'the trace climbs with the camera: ${up.from} → ${up.to}');
    expect(down.camera, closeTo(-math.sin(30 * math.pi / 180), 0.02), reason: 'the camera looks 30° down');
    expect(down.trace, closeTo(down.camera, 5e-3), reason: 'the trace dips with the camera: ${down.from} → ${down.to}');
    SmokeArtifacts.saveScreenshot(name, SmokeArtifacts.encodePng(_w, _h, yard.captureView()),
        usedAssets: [LuminaThirdPersonContent.bundledMeshPath, barrel]);
    SmokeArtifacts.saveVideo(name, video.finish(), usedAssets: [LuminaThirdPersonContent.bundledMeshPath, barrel]);
  }, timeout: const Timeout(Duration(minutes: 5)));

  // Two Blueprints loaded from .lmas files in a temp project
  // through the class registry. BP_Door sets a one-shot timer that plays a
  // Timeline swinging the barrel over 90° and, when it finishes, calls its
  // OnDoorOpened dispatcher; a looping timer pulses every half second.
  // BP_Watcher binds its custom event to the door's dispatcher and prints
  // the angle it receives. The video shows the swing; the trace logs of
  // both ride in the PNG's sidecar.
  test('blueprint: timers, timeline and dispatcher', () async {
    const name = 'blueprint: timers, timeline and dispatcher';
    final project = Directory.systemTemp.createTempSync('lumina_bp11_smoke_');
    addTearDown(() => project.deleteSync(recursive: true));
    void write(String path, Map<String, dynamic> document) {
      final assetName = path.split('/').last.replaceAll('.lmas', '');
      File('${project.path}/$path')
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(LuminaAsset(assetId: assetName, name: assetName, type: AssetType.actor, rawPayload: utf8.encode(jsonEncode(document)))
            .toProtoBufferBytes());
    }

    final barrel = '${SmokeArtifacts.testAssetsDir.absolute.path}/Props/Barrels/fuel_barrel_red.glb';
    var n = 0;
    LuminaBlueprintWire wire(String from, String fromPin, String to, String toPin) =>
        LuminaBlueprintWire(id: 'dw${n++}', fromNodeId: from, fromPinId: fromPin, toNodeId: to, toPinId: toPin);

    // BP_Door.
    final doorDoc = LuminaBlueprintDocument(
      components: [
        LuminaBlueprintComponent(id: 'cap', name: 'Capsule', type: 'LuminaCapsuleComponent', properties: {'capsuleRadius': 45.0, 'capsuleHalfHeight': 60.0}),
        LuminaBlueprintComponent(id: 'mesh', name: 'Barrel', type: 'LuminaStaticMeshComponent', parentId: 'cap', properties: {'staticMeshAsset': barrel}),
      ],
      dispatchers: [
        LuminaBlueprintDispatcher(name: 'OnDoorOpened', parameters: [const LuminaBlueprintVariable(name: 'Angle', typeName: 'Float', defaultValue: 0.0)]),
      ],
    );
    final dc = LuminaBlueprintTypeContext.forDocument(doorDoc, className: 'BP_Door');
    LuminaBlueprintNode d(String id, String nodeId, [Map<String, dynamic>? literals]) =>
        LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: dc);
    doorDoc.eventGraph.nodes.addAll([
      d('event_beginplay', 'begin'),
      d('custom_event', 'open', {'name': 'Open'}),
      d('custom_event', 'pulse', {'name': 'Pulse'}),
      d('set_timer_by_event', 'open_timer', {'time': 1.0}),
      d('set_timer_by_event', 'pulse_timer', {'time': 0.5, 'looping': true}),
      d('print_string', 'say_pulse', {'in_string': 'pulse'}),
      d('timeline', 'swing', {
        'name': 'Swing',
        'length': 3.0,
        'tracks': [
          {
            'name': 'Angle',
            'type': 'float',
            'keys': [
              {'time': 0.0, 'value': 0.0, 'interp': 'cubic'},
              {'time': 3.0, 'value': 90.0, 'interp': 'cubic'},
            ],
          },
        ],
      }),
      d('make_rotator', 'rot'),
      d('set_actor_rotation', 'turn'),
      d('float_to_string', 'angle_text', {'decimals': 0}),
      d('append', 'done_line', {'a': 'swing finished at '}),
      d('print_string', 'say_done'),
      d('call_dispatcher', 'opened', {'dispatcher': 'OnDoorOpened'}),
    ]);
    doorDoc.eventGraph.wires.addAll([
      wire('begin', 'exec_out', 'open_timer', 'exec_in'),
      wire('open', 'delegate', 'open_timer', 'event'),
      wire('open_timer', 'exec_out', 'pulse_timer', 'exec_in'),
      wire('pulse', 'delegate', 'pulse_timer', 'event'),
      wire('pulse', 'exec_out', 'say_pulse', 'exec_in'),
      wire('open', 'exec_out', 'swing', 'play'),
      wire('swing', 'update', 'turn', 'exec_in'),
      wire('swing', 'Angle', 'rot', 'x'),
      wire('rot', 'return_value', 'turn', 'new_rotation'),
      wire('swing', 'finished', 'say_done', 'exec_in'),
      wire('swing', 'Angle', 'angle_text', 'in_float'),
      wire('angle_text', 'return_value', 'done_line', 'b'),
      wire('done_line', 'return_value', 'say_done', 'in_string'),
      wire('say_done', 'exec_out', 'opened', 'exec_in'),
      wire('swing', 'Angle', 'opened', 'Angle'),
    ]);
    // BP_Watcher: the Third Person character binding to the door.
    final actions = ProjectInputBinder.bind(GameTemplateCatalog.thirdPerson.input).actions.values.toList();
    final watcherDoc = thirdPersonCharacterBlueprint(inputActions: actions);
    watcherDoc.components.add(LuminaBlueprintComponent(
      id: 'mesh',
      name: 'Mesh',
      type: 'LuminaSkeletalMeshComponent',
      parentId: 'capsule',
      properties: {
        'location': [0.0, 0.0, -LuminaTemplateCharacterTuning.thirdPersonCapsuleHalfHeight],
        'rotation': [0.0, 0.0, 180.0],
        'skeletalMeshAsset': File(LuminaThirdPersonContent.bundledMeshPath).absolute.path,
      },
    ));
    watcherDoc.variables.add(const LuminaBlueprintVariable(name: 'Door', typeName: 'Actor:BP_Door'));
    final wc = LuminaBlueprintTypeContext.forDocument(watcherDoc, inputActions: actions, className: 'BP_Watcher', actorParents: {'BP_Door': 'LuminaActor'});
    LuminaBlueprintNode w(String id, String nodeId, [Map<String, dynamic>? literals]) =>
        LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: wc);
    watcherDoc.eventGraph.nodes.addAll([
      w('event_beginplay', 'begin'),
      w('get_all_actors_of_class', 'doors', {'class': 'Actor:BP_Door'}),
      w('array_first', 'door', {'type': 'object', 'class': 'Actor:BP_Door'}),
      w(LuminaBlueprintNodeLibrary.variableSet, 'set_door', {'variable': 'Door'}),
      w('bind_event_to_dispatcher', 'bind', {'dispatcher': 'OnDoorOpened'}),
      w('custom_event', 'door_opened', {'name': 'DoorOpened', 'parameters': [{'name': 'Angle', 'type': 'Float'}]}),
      w('float_to_string', 'text', {'decimals': 0}),
      w('append', 'line', {'a': 'door opened at '}),
      w('print_string', 'say'),
    ]);
    watcherDoc.eventGraph.wires.addAll([
      wire('begin', 'exec_out', 'set_door', 'exec_in'),
      wire('doors', 'return_value', 'door', 'target_array'),
      wire('door', 'return_value', 'set_door', 'value'),
      wire('set_door', 'exec_out', 'bind', 'exec_in'),
      wire('set_door', 'value', 'bind', 'target'),
      wire('door_opened', 'delegate', 'bind', 'event'),
      wire('door_opened', 'exec_out', 'say', 'exec_in'),
      wire('door_opened', 'Angle', 'text', 'in_float'),
      wire('text', 'return_value', 'line', 'b'),
      wire('line', 'return_value', 'say', 'in_string'),
    ]);
    const doorPath = 'contents/blueprints/BP_Door.lmas';
    const watcherPath = 'contents/blueprints/BP_Watcher.lmas';
    write(doorPath, doorDoc.toJson());
    write(watcherPath, watcherDoc.toJson());
    final registry = LuminaBlueprintClassRegistry(project.path, inputActions: actions, resolveAsset: (stored) => stored);
    final doorClass = registry.classFor(doorPath)!;
    final watcherClass = registry.classFor(watcherPath)!;
    expect(doorClass.diagnostics, isEmpty, reason: '${doorClass.diagnostics}');
    expect(watcherClass.diagnostics, isEmpty, reason: '${watcherClass.diagnostics}');
    expect(LuminaBlueprintActorClasses.has('BP_Door'), isTrue, reason: 'the registry registers compiled classes for Spawn Actor');
    addTearDown(LuminaBlueprintActorClasses.clear);

    final yard = _Yard();
    addTearDown(yard.dispose);
    final world = yard.world;
    final start = LuminaAxes.toAuthoringLocation(yard.start);
    final door = doorClass.instantiate(location: LuminaAxes.location([start[0] + 170.0, start[1] + 320.0, 60.0])) as LuminaBlueprintActor;
    final doorTrace = <LuminaBlueprintTraceEvent>[];
    door.trace = doorTrace.add;
    world.persistentLevel.registerActor(door);
    final watcher = watcherClass.instantiate(location: yard.start.clone()) as LuminaBlueprintCharacter;
    final watcherTrace = <LuminaBlueprintTraceEvent>[];
    watcher.trace = watcherTrace.add;
    final pc = LuminaPlayerController();
    world.persistentLevel.registerActor(watcher);
    pc.possess(watcher);
    world.beginPlay();
    await (watcher.blueprintComponents['mesh'] as LuminaAnimatedMeshComponent).loaded.timeout(const Duration(seconds: 60));
    await (door.blueprintComponents['mesh'] as LuminaStaticMeshComponent).loaded.timeout(const Duration(seconds: 60));
    expect(door.blueprintDispatcher('OnDoorOpened').isBound, isTrue, reason: 'the watcher bound at BeginPlay');

    final camera = watcher.blueprintComponents['camera'] as LuminaCameraComponent;
    final video = SmokeVideoRecorder(width: _w, height: _h, fps: 30, testName: name);
    addTearDown(video.discard);
    Uint8List shot() => yard.capture(camera, door.actorLocation);
    // 12 s at 30 Hz: the timer fires at 1 s, the swing runs to 4 s, the dispatcher reports 90.
    for (var frame = 0; frame < 360; frame++) {
      pc.onTick(1 / 30);
      world.tick(1 / 30);
      video.addFrame(shot());
    }
    List<String> printed(List<LuminaBlueprintTraceEvent> t) => [for (final e in t) if (e.printed != null) e.printed!];
    expect(printed(doorTrace).where((p) => p == 'pulse').length, inInclusiveRange(20, 24), reason: 'every 0.5 s from t = 1 s');
    expect(printed(doorTrace), contains('swing finished at 90'));
    expect(printed(watcherTrace), ['door opened at 90']);
    expect(door.blueprintTimelines['swing']!.position, 3.0);
    final pitch = LuminaBlueprintFunctionLibrary.getActorRotation(door).pitch;
    expect(pitch, closeTo(90.0, 1.0), reason: 'the barrel lies at 90°');
    expect(doorTrace.where((t) => t.registryId == 'set_actor_rotation').length, greaterThan(80), reason: 'Update every tick of the swing');

    final png = SmokeArtifacts.encodePng(_w, _h, shot());
    final file = SmokeArtifacts.saveScreenshot(name, png, usedAssets: [LuminaThirdPersonContent.bundledMeshPath, barrel]);
    final sidecar = File(file.path.replaceFirst(RegExp(r'\.png$'), '.json'));
    final meta = jsonDecode(sidecar.readAsStringSync()) as Map<String, dynamic>;
    meta['doorTrace'] = [for (final t in doorTrace) if (t.printed != null || t.registryId == 'call_dispatcher' || t.registryId == 'timeline') t.toString()];
    meta['watcherTrace'] = [for (final t in watcherTrace) t.toString()];
    sidecar.writeAsStringSync(jsonEncode(meta), flush: true);
    SmokeArtifacts.saveVideo(name, video.finish(), usedAssets: [LuminaThirdPersonContent.bundledMeshPath, barrel]);
  }, timeout: const Timeout(Duration(minutes: 5)));

  // Gameplay statics from one Blueprint on the GPU. BP_Player
  // (the mannequin with ABP_Character and a point light) saves a slot to disk at
  // BeginPlay and reads it back, plays a sound through the engine's audio
  // subsystem, plays a montage of a real bundle clip, and flips its lamp
  // every second; the video shows the montage and the blinking light, the
  // PNGs are the lit and unlit scene, the trace log rides in the sidecar.
  test('blueprint: gameplay statics from a Blueprint', () async {
    const name = 'blueprint: gameplay statics from a Blueprint';
    final saves = Directory.systemTemp.createTempSync('lumina_bp12_smoke_saves_');
    addTearDown(() => saves.deleteSync(recursive: true));
    LuminaBlueprintSaveGameClasses.register(const LuminaBlueprintSaveGameDocument(name: 'SG_Smoke', fields: [
      LuminaBlueprintVariable(name: 'Score', typeName: 'Int', defaultValue: 0),
    ]));
    LuminaBlueprintMontages.register(const LuminaBlueprintMontageDocument(
      name: 'AM_Walk',
      clip: 'Walk_Fwd_Loop',
      length: 1.5,
      notifies: [LuminaBlueprintMontageNotify(name: 'Step', time: 0.75)],
    ));
    addTearDown(() {
      LuminaBlueprintSaveGameClasses.clear();
      LuminaBlueprintMontages.clear();
    });
    final actions = ProjectInputBinder.bind(GameTemplateCatalog.thirdPerson.input).actions.values.toList();
    final doc = templateCharacterBlueprint(inputActions: actions);
    doc.components.add(LuminaBlueprintComponent(
        id: 'lamp', name: 'Lamp', type: 'LuminaPointLightComponent', parentId: 'capsule', properties: {
      'intensity': 800000.0,
      'color': [1.0, 0.6, 0.25],
      'location': [0.0, 80.0, 170.0],
      'attenuationRadius': 1200.0,
    }));
    doc.variables.add(const LuminaBlueprintVariable(name: 'Save', typeName: 'SaveGame:SG_Smoke'));
    final context = LuminaBlueprintTypeContext.forDocument(doc, inputActions: actions, className: 'BP_Player');
    LuminaBlueprintNode place(String id, String nodeId, [Map<String, dynamic>? literals]) =>
        LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: context);
    var n = 0;
    LuminaBlueprintWire wire(String from, String fromPin, String to, String toPin) =>
        LuminaBlueprintWire(id: 'gw${n++}', fromNodeId: from, fromPinId: fromPin, toNodeId: to, toPinId: toPin);
    doc.eventGraph.nodes.addAll([
      place('event_beginplay', 'begin'),
      place('create_save_game_object', 'create', {'class': 'SG_Smoke'}),
      place(LuminaBlueprintNodeLibrary.variableSet, 'set_save', {'variable': 'Save'}),
      place('set_save_field', 'set_score', {'class': 'SG_Smoke', 'field': 'Score', 'value': 77}),
      place('save_game_to_slot', 'save', {'slot_name': 'smoke'}),
      place('load_game_from_slot', 'load', {'slot_name': 'smoke', 'class': 'SG_Smoke'}),
      place('get_save_field', 'score', {'class': 'SG_Smoke', 'field': 'Score'}),
      place('int_to_string', 'score_text'),
      place('append', 'score_line', {'a': 'loaded score '}),
      place('print_string', 'say_score'),
      place('play_sound_2d', 'chime', {'sound': 'contents/audio/chime.wav', 'volume': 0.7}),
      place('play_anim_montage', 'walk', {'montage': 'AM_Walk'}),
      place('float_to_string', 'len_text', {'decimals': 2}),
      place('append', 'len_line', {'a': 'montage length '}),
      place('print_string', 'say_len'),
      place('set_timer_by_event', 'blink_timer', {'time': 1.0, 'looping': true}),
      place('custom_event', 'blink', {'name': 'Blink'}),
      place(LuminaBlueprintNodeLibrary.getComponent, 'lamp', {'component': 'Lamp'}),
      place('toggle_light_visibility', 'flip'),
      place('print_string', 'say_blink', {'in_string': 'blink', 'key': 'blink'}),
      place('event_montage_ended', 'ended'),
      place('print_string', 'say_ended', {'in_string': 'montage ended'}),
      place('event_anim_notify', 'notify'),
      place('append', 'notify_line', {'a': 'notify '}),
      place('print_string', 'say_notify'),
    ]);
    doc.eventGraph.wires.addAll([
      wire('begin', 'exec_out', 'create', 'exec_in'),
      wire('create', 'exec_out', 'set_save', 'exec_in'),
      wire('create', 'return_value', 'set_save', 'value'),
      wire('set_save', 'exec_out', 'set_score', 'exec_in'),
      wire('set_save', 'value', 'set_score', 'target'),
      wire('set_score', 'exec_out', 'save', 'exec_in'),
      wire('set_save', 'value', 'save', 'save_game_object'),
      wire('save', 'exec_out', 'load', 'exec_in'),
      wire('load', 'exec_out', 'say_score', 'exec_in'),
      wire('load', 'return_value', 'score', 'target'),
      wire('score', 'return_value', 'score_text', 'in_int'),
      wire('score_text', 'return_value', 'score_line', 'b'),
      wire('score_line', 'return_value', 'say_score', 'in_string'),
      wire('say_score', 'exec_out', 'chime', 'exec_in'),
      wire('chime', 'exec_out', 'walk', 'exec_in'),
      wire('walk', 'exec_out', 'say_len', 'exec_in'),
      wire('walk', 'return_value', 'len_text', 'in_float'),
      wire('len_text', 'return_value', 'len_line', 'b'),
      wire('len_line', 'return_value', 'say_len', 'in_string'),
      wire('say_len', 'exec_out', 'blink_timer', 'exec_in'),
      wire('blink', 'delegate', 'blink_timer', 'event'),
      wire('blink', 'exec_out', 'flip', 'exec_in'),
      wire('lamp', 'return_value', 'flip', 'target'),
      wire('flip', 'exec_out', 'say_blink', 'exec_in'),
      wire('ended', 'exec_out', 'say_ended', 'exec_in'),
      wire('notify', 'exec_out', 'say_notify', 'exec_in'),
      wire('notify', 'notify_name', 'notify_line', 'b'),
      wire('notify_line', 'return_value', 'say_notify', 'in_string'),
    ]);
    final anim = templateAnimClass();
    final cls = LuminaBlueprintClass.fromDocument(doc,
        name: 'BP_Player',
        inputActions: actions,
        assetProvider: (path) => File(path).readAsBytes(),
        animBlueprints: (path) => path == LuminaThirdPersonContent.projectAnimBlueprintPath ? anim.factory : null);
    expect(cls.diagnostics, isEmpty, reason: '${cls.diagnostics}');

    final yard = _Yard();
    addTearDown(yard.dispose);
    final world = yard.world;
    world.registerSubsystem(LuminaSaveGameSubsystem(saveDirectoryPath: saves.path));
    final backend = NullAudioBackend();
    world.registerSubsystem(LuminaAudioSubsystem(backend: backend));
    final player = cls.instantiate(location: yard.start.clone()) as LuminaBlueprintCharacter;
    final trace = <LuminaBlueprintTraceEvent>[];
    player.trace = trace.add;
    final pc = LuminaPlayerController();
    world.persistentLevel.registerActor(player);
    pc.possess(player);
    // Dusk: the sun goes down to a glow so the lamp is what lights the mannequin.
    yard.scene.setSkybox(FilamentSkybox.build(yard.engine, color: Vector4(0.05, 0.06, 0.1, 1), intensity: 2000));
    yard.scene.setIndirectLight(FilamentIndirectLight.build(yard.engine,
        irradiance: SphericalHarmonics(bands: 1, coefficients: [0.08, 0.09, 0.12]), intensity: 1500));
    for (final actor in world.actors) {
      for (final c in actor.components) {
        if (c is LuminaDirectionalLightComponent) c.intensity = 800.0;
      }
    }
    world.beginPlay();
    await (player.blueprintComponents['mesh'] as LuminaAnimatedMeshComponent).loaded.timeout(const Duration(seconds: 60));
    List<String> printed() => [for (final t in trace) if (t.printed != null) t.printed!];
    expect(printed().first, 'loaded score 77');
    expect(File('${saves.path}/smoke_user_0.sav').existsSync(), isTrue);
    expect(backend.playCalls.single.volume, closeTo(0.7, 1e-9));
    expect(printed(), contains('montage length 1.50'));
    expect(player.blueprintMontage, isNotNull);
    final lamp = player.blueprintComponents['lamp'] as LuminaPointLightComponent;
    expect(lamp.visible, isTrue);

    final camera = player.blueprintComponents['camera'] as LuminaCameraComponent;
    Uint8List shot() => yard.capture(camera, player.actorLocation + Vector3(0, 90, 0));
    final video = SmokeVideoRecorder(width: _w, height: _h, fps: 30, testName: name);
    addTearDown(video.discard);
    Uint8List? lit;
    Uint8List? unlit;
    // 12 s at 30 Hz: the montage plays for 1.5 s (a notify half-way), the lamp blinks every second.
    for (var frame = 0; frame < 360; frame++) {
      pc.onTick(1 / 30);
      world.tick(1 / 30);
      final pixels = shot();
      video.addFrame(pixels);
      if (frame == 15) lit = pixels;
      if (frame == 45) unlit = pixels;
    }
    expect(printed(), contains('notify Step'));
    expect(printed(), contains('montage ended'));
    expect(player.blueprintMontage, isNull);
    final blinks = printed().where((p) => p == 'blink').length;
    expect(blinks, inInclusiveRange(10, 12));
    expect(lamp.visible, blinks.isEven, reason: 'every blink flips the lamp');
    // The lamp really lights the scene: the lit frame is brighter than the unlit one.
    double brightness(Uint8List rgba) {
      var sum = 0;
      for (var i = 0; i < rgba.length; i += 4) {
        sum += rgba[i] + rgba[i + 1] + rgba[i + 2];
      }
      return sum / (rgba.length / 4 * 3);
    }
    final litFrame = lit!, unlitFrame = unlit!;
    SmokeArtifacts.saveScreenshot('$name 01 lit', SmokeArtifacts.encodePng(_w, _h, litFrame), usedAssets: const [LuminaThirdPersonContent.bundledMeshPath]);
    SmokeArtifacts.saveScreenshot('$name 02 unlit', SmokeArtifacts.encodePng(_w, _h, unlitFrame), usedAssets: const [LuminaThirdPersonContent.bundledMeshPath]);
    expect(brightness(litFrame), greaterThan(brightness(unlitFrame) + 1.0),
        reason: 'lit ${brightness(litFrame)} vs unlit ${brightness(unlitFrame)}');
    final file = SmokeArtifacts.saveScreenshot(name, SmokeArtifacts.encodePng(_w, _h, shot()), usedAssets: const [LuminaThirdPersonContent.bundledMeshPath]);
    final sidecar = File(file.path.replaceFirst(RegExp(r'\.png$'), '.json'));
    final meta = jsonDecode(sidecar.readAsStringSync()) as Map<String, dynamic>;
    meta['trace'] = [for (final t in trace) if (t.printed != null || t.registryId.startsWith('save_') || t.registryId == 'play_sound_2d') t.toString()];
    meta['saveFile'] = File('${saves.path}/smoke_user_0.sav').readAsStringSync();
    sidecar.writeAsStringSync(jsonEncode(meta), flush: true);
    SmokeArtifacts.saveVideo(name, video.finish(), usedAssets: const [LuminaThirdPersonContent.bundledMeshPath]);
  }, timeout: const Timeout(Duration(minutes: 5)));

  // A temp project's Blueprint assets generate the project
  // registry (checked against the committed golden, whose
  // registerProjectBlueprints() this test runs); the registries then serve a
  // VM character's BeginPlay: Spawn Actor from Class BP_Door (the generated
  // class), Play Anim Montage AM_Wave and Spawn Emitter P_Sparks by path.
  // The video shows the door arriving and the montage; the sidecar lists the
  // generated files and the registry source.
  test('blueprint: generated game bootstraps every registry', () async {
    const name = 'blueprint: generated game bootstraps every registry';
    final barrel = '${SmokeArtifacts.testAssetsDir.absolute.path}/Props/Barrels/fuel_barrel_red.glb';
    final project = Directory.systemTemp.createTempSync('lumina_bp13_smoke_');
    addTearDown(() => project.deleteSync(recursive: true));
    await writeRegistryProjectAssets(project.path, barrelGlb: barrel);
    final generator = DartCodeGeneratorService();
    expect(generator.writeProjectBlueprintRegistry(project.path), isTrue);
    final registrySource = File('${project.path}/lib/blueprint_registry.g.dart').readAsStringSync();
    expect(registrySource, File('../lumina/test/blueprint/generated/project_registry/blueprint_registry.g.dart').readAsStringSync(),
        reason: 'the function run below is this project\'s registry');
    final generatedFiles = [
      for (final f in Directory('${project.path}/lib').listSync(recursive: true).whereType<File>()) f.path.substring(project.path.length + 1),
    ]..sort();

    void clearRegistries() {
      LuminaBlueprintActorClasses.clear();
      LuminaBlueprintEnums.clear();
      LuminaBlueprintInterfaces.clear();
      LuminaBlueprintSaveGameClasses.clear();
      LuminaBlueprintMontages.clear();
      LuminaBlueprintParticleTemplates.clear();
    }

    clearRegistries();
    addTearDown(clearRegistries);
    registerProjectBlueprints();
    expect(LuminaBlueprintEnums.lookup('E_DoorState'), isNotNull);
    expect(LuminaBlueprintSaveGameClasses.lookup('SG_Player'), isNotNull);
    // The generated BP_Door loads its barrel from the project, as a built
    // game reads it from its bundle.
    final previousProvider = LuminaAssets.defaultProvider;
    LuminaAssets.defaultProvider = (path) => File(path.startsWith('/') ? path : '${project.path}/$path').readAsBytes();
    addTearDown(() => LuminaAssets.defaultProvider = previousProvider);

    final yard = _Yard();
    addTearDown(yard.dispose);
    final world = yard.world;
    final start = LuminaAxes.toAuthoringLocation(yard.start);
    final doorAt = [start[0] + 60.0, start[1] + 260.0, 0.0];
    final actions = ProjectInputBinder.bind(GameTemplateCatalog.thirdPerson.input).actions.values.toList();
    final doc = templateCharacterBlueprint(inputActions: actions);
    final context = LuminaBlueprintTypeContext.forDocument(doc, inputActions: actions, className: 'BP_Bootstrap',
        actorParents: {'BP_Door': 'LuminaActor'});
    LuminaBlueprintNode place(String id, String nodeId, [Map<String, dynamic>? literals]) =>
        LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: context);
    var n = 0;
    LuminaBlueprintWire wire(String from, String fromPin, String to, String toPin) =>
        LuminaBlueprintWire(id: 'rw${n++}', fromNodeId: from, fromPinId: fromPin, toNodeId: to, toPinId: toPin);
    doc.eventGraph.nodes.addAll([
      place('event_beginplay', 'begin'),
      place('spawn_actor_from_class', 'spawn', {
        'class': 'Actor:BP_Door',
        'spawn_transform': {'location': doorAt, 'rotation': [0.0, 0.0, 0.0], 'scale': [1.0, 1.0, 1.0]},
      }),
      place('get_display_name', 'who'),
      place('append', 'spawned_line', {'a': 'spawned '}),
      place('print_string', 'say_spawned'),
      place('play_anim_montage', 'wave', {'montage': 'AM_Wave'}),
      place('float_to_string', 'len_text', {'decimals': 2}),
      place('append', 'len_line', {'a': 'montage length '}),
      place('print_string', 'say_len'),
      place('spawn_emitter_at_location', 'sparks', {'emitter_template': registrySparksPath, 'location': [doorAt[0], doorAt[1], 200.0]}),
      place('event_anim_notify', 'notify'),
      place('append', 'notify_line', {'a': 'notify '}),
      place('print_string', 'say_notify'),
    ]);
    doc.eventGraph.wires.addAll([
      wire('begin', 'exec_out', 'spawn', 'exec_in'),
      wire('spawn', 'exec_out', 'say_spawned', 'exec_in'),
      wire('spawn', 'return_value', 'who', 'object'),
      wire('who', 'return_value', 'spawned_line', 'b'),
      wire('spawned_line', 'return_value', 'say_spawned', 'in_string'),
      wire('say_spawned', 'exec_out', 'wave', 'exec_in'),
      wire('wave', 'exec_out', 'say_len', 'exec_in'),
      wire('wave', 'return_value', 'len_text', 'in_float'),
      wire('len_text', 'return_value', 'len_line', 'b'),
      wire('len_line', 'return_value', 'say_len', 'in_string'),
      wire('say_len', 'exec_out', 'sparks', 'exec_in'),
      wire('notify', 'exec_out', 'say_notify', 'exec_in'),
      wire('notify', 'notify_name', 'notify_line', 'b'),
      wire('notify_line', 'return_value', 'say_notify', 'in_string'),
    ]);
    final anim = templateAnimClass();
    final cls = LuminaBlueprintClass.fromDocument(doc,
        name: 'BP_Bootstrap',
        inputActions: actions,
        assetProvider: (path) => File(path).readAsBytes(),
        animBlueprints: (path) => path == LuminaThirdPersonContent.projectAnimBlueprintPath ? anim.factory : null);
    expect(cls.diagnostics.where((d) => d.isError), isEmpty, reason: '${cls.diagnostics}');

    final player = cls.instantiate(location: yard.start.clone()) as LuminaBlueprintCharacter;
    final trace = <LuminaBlueprintTraceEvent>[];
    player.trace = trace.add;
    final pc = LuminaPlayerController();
    world.persistentLevel.registerActor(player);
    pc.possess(player);
    world.beginPlay();
    await (player.blueprintComponents['mesh'] as LuminaAnimatedMeshComponent).loaded.timeout(const Duration(seconds: 60));
    List<String> printed() => [for (final t in trace) if (t.printed != null) t.printed!];
    final door = world.actors.whereType<LuminaBlueprintRuntime>().where((a) => a.blueprintClassName == 'BP_Door').single;
    expect(door.runtimeType.toString(), 'BpDoor', reason: 'the generated class from actors.g.dart');
    await (door.blueprintComponents['mesh'] as LuminaStaticMeshComponent).loaded.timeout(const Duration(seconds: 60));
    expect(printed(), containsAllInOrder(['spawned BP_Door', 'montage length 1.50']));
    expect(world.screenMessages.values.map((m) => m.text), contains('BP_Door ready'), reason: 'the spawned generated class ran its BeginPlay');
    expect(player.blueprintMontage?.montage.name, 'AM_Wave');
    expect(world.actors.expand((a) => a.components).whereType<LuminaParticleSystemComponent>(), isNotEmpty,
        reason: 'Spawn Emitter found P_Sparks by path');

    final camera = player.blueprintComponents['camera'] as LuminaCameraComponent;
    Uint8List shot() => yard.capture(camera, player.actorLocation + Vector3(0, 90, 0));
    final video = SmokeVideoRecorder(width: _w, height: _h, fps: 30, testName: name);
    addTearDown(video.discard);
    // 11 s at 30 Hz: the 1.5 s montage (its Step notify half-way), then idle beside the door.
    for (var frame = 0; frame < 330; frame++) {
      pc.onTick(1 / 30);
      world.tick(1 / 30);
      video.addFrame(shot());
    }
    expect(printed(), contains('notify Step'));
    final used = [LuminaThirdPersonContent.bundledMeshPath, barrel];
    final file = SmokeArtifacts.saveScreenshot(name, SmokeArtifacts.encodePng(_w, _h, shot()), usedAssets: used);
    final sidecar = File(file.path.replaceFirst(RegExp(r'\.png$'), '.json'));
    final meta = jsonDecode(sidecar.readAsStringSync()) as Map<String, dynamic>;
    meta['generatedFiles'] = generatedFiles;
    meta['blueprintRegistry'] = registrySource;
    meta['trace'] = [for (final t in trace) if (t.printed != null) t.toString()];
    sidecar.writeAsStringSync(jsonEncode(meta), flush: true);
    SmokeArtifacts.saveVideo(name, video.finish(), usedAssets: used);
  }, timeout: const Timeout(Duration(minutes: 5)));

  // A temp project's level L_Test and its Level Blueprint, run
  // by the VM on a real world: Level Loaded, then Level BeginPlay calls Open
  // on the placed Door_01 (a BP_Door showing a real AC unit) and plays the
  // DoorSwing timeline, which turns the door 90° in one second. The video
  // shows the swing; the PNG the door turned.
  test('blueprint: level blueprint opens a door', () async {
    const name = 'blueprint: level blueprint opens a door';
    final mesh = '${SmokeArtifacts.testAssetsDir.absolute.path}/Props/AC_units/ac_unit_b_600x600.glb';
    final project = Directory.systemTemp.createTempSync('lumina_bp14_smoke_');
    addTearDown(() => project.deleteSync(recursive: true));
    writeLevelTestProject(project.path, meshGlb: mesh);
    final registry = LuminaBlueprintClassRegistry(project.path, inputActions: const []);

    final yard = _Yard();
    addTearDown(yard.dispose);
    final world = yard.world;
    final doorAt = yard.start + Vector3(0, 0, -400);
    final door = registry.classFor(levelDoorPath)!.instantiate(key: const LuminaObjectKey('door_01'), location: doorAt.clone());
    final trace = <String>[];
    (door as LuminaBlueprintRuntime).trace = (e) {
      if (e.printed != null) trace.add('BP_Door: ${e.printed}');
    };
    world.persistentLevel.registerActor(door);
    world.persistentLevel.registerActor(
        LuminaTriggerVolume(key: const LuminaObjectKey('trigger_01'), extent: Vector3(100, 100, 100), location: yard.start + Vector3(0, 50, -1500)));
    world.persistentLevel.registerActor(LuminaPlayerStart(key: const LuminaObjectKey('player_start'), location: yard.start.clone()));
    final script = registry.levelScriptFor(levelTestPath);
    expect(script, isNotNull, reason: '${registry.diagnostics}');
    script!.trace = (e) {
      if (e.printed != null) trace.add('L_Test: ${e.printed}');
    };
    world.persistentLevel.scriptActor = script;
    final eye = LuminaActor(root: LuminaCameraComponent(), location: doorAt + Vector3(260, 220, 380));
    world.persistentLevel.registerActor(eye);
    final camera = eye.rootComponent as LuminaCameraComponent;

    world.beginPlay();
    await (door.blueprintComponents['mesh'] as LuminaStaticMeshComponent).loaded.timeout(const Duration(seconds: 60));
    expect(trace.first, 'L_Test: level loaded', reason: 'Level Loaded before any BeginPlay');
    expect(trace, containsAllInOrder(['BP_Door: Door ready', 'BP_Door: Door opened', 'L_Test: player starts 1']));

    Uint8List shot() => yard.capture(camera, doorAt + Vector3(0, 60, 0));
    final video = SmokeVideoRecorder(width: _w, height: _h, fps: 30, testName: name);
    addTearDown(video.discard);
    // 11 s at 30 Hz: the one-second swing, then the door standing open.
    for (var frame = 0; frame < 330; frame++) {
      world.tick(1 / 30);
      video.addFrame(shot());
    }
    final yaw = LuminaBlueprintFunctionLibrary.getActorRotation(door).z;
    expect(yaw.abs(), closeTo(90.0, 0.5), reason: 'DoorSwing turned Door_01');
    expect(script.variables['Ticks'], 330);
    final used = [mesh];
    final file = SmokeArtifacts.saveScreenshot(name, SmokeArtifacts.encodePng(_w, _h, shot()), usedAssets: used);
    final sidecar = File(file.path.replaceFirst(RegExp(r'\.png$'), '.json'));
    final meta = jsonDecode(sidecar.readAsStringSync()) as Map<String, dynamic>;
    meta['trace'] = trace;
    meta['doorYaw'] = yaw;
    meta['levelBlueprint'] = levelTestBlueprint().toJson();
    sidecar.writeAsStringSync(jsonEncode(meta), flush: true);
    SmokeArtifacts.saveVideo(name, video.finish(), usedAssets: used);
    world.persistentLevel.unloadActors();
    expect(trace.last, 'L_Test: level end');
  }, timeout: const Timeout(Duration(minutes: 5)));

  // Two walls of one Blueprint class (a Block All box carrying
  // a red fuel barrel) placed in a temp project's level; the second has a per-
  // instance Overlap All override, saved in the level .lmas as the level
  // Details saves it. The generated level wraps only that wall in
  // luminaWithCollisionOverrides; applied the same way here, the character
  // walking north is stopped by the first wall and walks through the second.
  test('blueprint: placed Blueprint collision overrides', () async {
    const name = 'blueprint: placed Blueprint collision overrides';
    final barrel = '${SmokeArtifacts.testAssetsDir.absolute.path}/Props/Barrels/fuel_barrel_red.glb';
    const wallPath = 'contents/blueprints/BP_Wall.lmas';
    const meshPath = 'contents/meshes/fuel_barrel_red.glb';
    const levelPath = 'contents/levels/L_Walls.lmas';
    final project = Directory.systemTemp.createTempSync('lumina_bp15_smoke_');
    addTearDown(() => project.deleteSync(recursive: true));
    File('${project.path}/$meshPath')
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(File(barrel).readAsBytesSync());
    final wallDoc = LuminaBlueprintDocument(parentClass: 'LuminaActor', components: [
      LuminaBlueprintComponent(id: 'root', name: 'DefaultSceneRoot', type: 'LuminaSceneComponent'),
      LuminaBlueprintComponent(id: 'box', name: 'WallBox', type: 'LuminaBoxComponent', parentId: 'root', properties: {
        'boxExtent': [150.0, 20.0, 100.0],
        'preset': 'BlockAll',
        'location': [0.0, 0.0, 100.0],
      }),
      LuminaBlueprintComponent(id: 'mesh', name: 'Unit', type: 'LuminaStaticMeshComponent', parentId: 'root', properties: {
        'staticMeshAsset': meshPath,
      }),
    ]);
    File('${project.path}/$wallPath')
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(LuminaAsset(
        assetId: 'bp_BP_Wall',
        name: 'BP_Wall',
        type: AssetType.actor,
        rawPayload: Uint8List.fromList(utf8.encode(jsonEncode(wallDoc.toJson()))),
        metadata: {'parent_class': 'LuminaActor'},
      ).toProtoBufferBytes());

    final yard = _Yard();
    addTearDown(yard.dispose);
    final world = yard.world;
    final start = LuminaAxes.toAuthoringLocation(yard.start);
    const wallY = 350.0; // authoring cm north of the start
    const passX = 450.0;
    Map<String, dynamic> wall(String id, double x, {bool overlap = false}) => {
          'id': id,
          'name': id,
          'type': 'Blueprint',
          'blueprintClass': wallPath,
          'location': [start[0] + x, start[1] + wallY, 0.0],
          'rotation': [0.0, 0.0, 0.0],
          'scale': [1.0, 1.0, 1.0],
          'components': [
            if (overlap)
              {
                'id': '$id.collision.box',
                'type': 'LuminaBoxComponent',
                'name': 'WallBox',
                'enabled': true,
                'properties': {
                  'blueprintComponentId': 'box',
                  ...LuminaCollisionProfile.forPreset(LuminaCollisionPreset.overlapAll).toJson(),
                },
              },
          ],
        };
    LuminaLevelRepository(project.path)
        .save(LuminaLevelDocument(relativePath: levelPath)..actors = [wall('wall_block', 0), wall('wall_pass', passX, overlap: true)]);

    // The saved level, as the generator and the game read it.
    final placed = LuminaLevelRepository(project.path).load(levelPath)!.actors;
    final level = DartCodeGeneratorService().generateLevelDart(levelName: 'L_Walls', actors: const [], actorMaps: placed);
    expect(level, contains("luminaWithCollisionOverrides(luminaBlueprintFactories['$wallPath']!(key: const LuminaObjectKey('wall_pass')"));
    expect(level, contains("luminaBlueprintFactories['$wallPath']!(key: const LuminaObjectKey('wall_block')"));
    expect(level, isNot(contains("luminaWithCollisionOverrides(luminaBlueprintFactories['$wallPath']!(key: const LuminaObjectKey('wall_block')")));

    final registry = LuminaBlueprintClassRegistry(project.path, inputActions: const []);
    final walls = <String, LuminaBlueprintRuntime>{};
    for (final a in placed) {
      final actor = registry.classFor(wallPath)!.instantiate(
          key: LuminaObjectKey(a['id']), location: LuminaAxes.location((a['location'] as List).cast<num>()));
      walls[a['id'] as String] = luminaWithCollisionOverrides(actor, LuminaBlueprintCollisionOverrides.fromActorMap(a)) as LuminaBlueprintRuntime;
      world.persistentLevel.registerActor(actor);
    }
    LuminaBoxComponent boxOf(String id) => walls[id]!.blueprintComponents['box'] as LuminaBoxComponent;
    expect(boxOf('wall_block').preset, LuminaCollisionPreset.blockAll);
    expect(boxOf('wall_pass').preset, LuminaCollisionPreset.overlapAll);

    final input = ProjectInputBinder.bind(GameTemplateCatalog.thirdPerson.input);
    final subsystem = world.registerSubsystem(LuminaInputSubsystem());
    for (final c in input.contexts) {
      subsystem.addMappingContext(c.context, priority: c.priority);
    }
    final actions = input.actions.values.toList();
    final doc = thirdPersonCharacterBlueprint(inputActions: actions);
    doc.components.add(LuminaBlueprintComponent(
      id: 'mesh',
      name: 'Mesh',
      type: 'LuminaSkeletalMeshComponent',
      parentId: 'capsule',
      properties: {
        'location': [0.0, 0.0, -LuminaTemplateCharacterTuning.thirdPersonCapsuleHalfHeight],
        'rotation': [0.0, 0.0, 180.0],
        'skeletalMeshAsset': luminaPackageFile(LuminaThirdPersonContent.bundledMeshPath),
      },
    ));
    final cls = LuminaBlueprintClass.fromDocument(doc,
        name: 'BP_ThirdPersonCharacter', inputActions: actions, assetProvider: (path) => File(path).readAsBytes());
    expect(cls.hasErrors, isFalse, reason: '${cls.diagnostics}');
    final character = cls.instantiate(location: yard.start.clone()) as LuminaBlueprintCharacter;
    final pc = LuminaPlayerController();
    world.persistentLevel.registerActor(character);
    pc.possess(character);
    world.beginPlay();
    await Future.wait([
      (character.blueprintComponents['mesh'] as LuminaAnimatedMeshComponent).loaded,
      for (final w in walls.values) (w.blueprintComponents['mesh'] as LuminaStaticMeshComponent).loaded,
    ]).timeout(const Duration(seconds: 60));
    final radius = character.capsuleComponent.radius;
    final camera = character.blueprintComponents['camera'] as LuminaCameraComponent;
    Uint8List shot() => yard.capture(camera, character.actorLocation + Vector3(0, 60, 0));
    double north() => LuminaAxes.toAuthoringLocation(character.actorLocation)[1] - start[1];

    final video = SmokeVideoRecorder(width: _w, height: _h, fps: 30, testName: name);
    addTearDown(video.discard);
    final used = [LuminaThirdPersonContent.bundledMeshPath, barrel];
    // 11 s at 60 Hz. 0-5 s: walk north into the Block All wall. At 5 s,
    // step to the overridden wall's lane; 5.25-11 s: walk north through it.
    final track = <double>[];
    for (var frame = 0; frame < 660; frame++) {
      if (frame == 15 || frame == 315) subsystem.injectKeyDown(LuminaKey.keyW);
      if (frame == 300) {
        subsystem.injectKeyUp(LuminaKey.keyW);
        SmokeArtifacts.saveScreenshot('$name 01 stopped by the Block All wall', SmokeArtifacts.encodePng(_w, _h, shot()),
            usedAssets: used);
        character.actorLocation = LuminaAxes.location([start[0] + passX, start[1], start[2]]);
      }
      pc.onTick(1 / 60);
      world.tick(1 / 60);
      track.add(north());
      if (frame.isEven) video.addFrame(shot());
    }
    subsystem.injectKeyUp(LuminaKey.keyW);

    final stopped = track[299];
    expect(stopped, lessThan(wallY - 20.0 - radius + 1.0), reason: 'the class wall blocks (north $stopped cm)');
    expect(stopped, greaterThan(wallY - 20.0 - radius - 20.0), reason: 'it walked up to the wall (north $stopped cm)');
    expect((track[299] - track[209]).abs(), lessThan(1.0), reason: 'pushing into the wall, not moving');
    expect(track.last, greaterThan(wallY + 20.0 + radius), reason: 'the overridden wall lets it through (north ${track.last} cm)');

    final file = SmokeArtifacts.saveScreenshot(name, SmokeArtifacts.encodePng(_w, _h, shot()), usedAssets: used);
    final sidecar = File(file.path.replaceFirst(RegExp(r'\.png$'), '.json'));
    final meta = jsonDecode(sidecar.readAsStringSync()) as Map<String, dynamic>;
    meta['generatedLevel'] = level;
    meta['placedActors'] = placed;
    meta['stoppedAtCm'] = stopped;
    meta['passedToCm'] = track.last;
    sidecar.writeAsStringSync(jsonEncode(meta), flush: true);
    SmokeArtifacts.saveVideo(name, video.finish(), usedAssets: used);
  }, timeout: const Timeout(Duration(minutes: 5)));

  // The loading-screen flow on the GPU. BP_LoadingScreen,
  // placed in L_First, adds WBP_Loading to the viewport, waits two seconds,
  // then Load Level L_Second: every On Progress writes "LOADING <pct>%
  // (<loaded>/<total>) <content>" into the widget's text and fills its bar;
  // On Success says so, holds, then Change Level L_Second. The host swaps
  // the world on the same engine; the meshes the preload uploaded are what
  // L_Second draws (the switch uploads nothing again). The widget is drawn
  // over each frame from the widget subsystem's state (text and bar).
  test('blueprint: loading screen changes level', () async {
    const name = 'blueprint: loading screen changes level';
    final project = Directory.systemTemp.createTempSync('lvl_smoke_');
    final dir = project.resolveSymbolicLinksSync();
    writeLevelLoadProject(dir);
    const hudClass = LuminaBlueprintWidgetClass(name: 'WBP_Loading', elements: [
      LuminaBlueprintWidgetElement(name: 'Progress', typeName: 'text', props: {'text': 'LOADING'}),
      LuminaBlueprintWidgetElement(name: 'Bar', typeName: 'progressBar', props: {'percent': 0.0}),
    ]);
    LuminaWidgetClassRegistry.register(hudClass);
    final savedPreloader = LuminaLevelPreloader.instance;
    final yard = _Yard();
    addTearDown(() {
      LuminaWidgetClassRegistry.clear();
      LuminaLevelPreloader.instance.reset();
      LuminaLevelPreloader.instance = savedPreloader;
      LuminaGame.onChangeLevelRequested = null;
      LuminaAssetIndex.close(dir);
      yard.dispose();
      project.deleteSync(recursive: true);
    });
    // Meshes upload into the yard engine's cache, read as the level's
    // components read them (the disk); everything else is pinned bytes. One
    // asset per eight rendered frames, so the progress is seen on screen.
    var framesRendered = 0;
    LuminaLevelPreloader.instance = LuminaLevelPreloader(
      manifestResolver: (level) => LuminaLevelAssetManifest.forProjectLevel(dir, level),
      engine: yard.engine,
      maxConcurrent: 1,
    )..betweenItems = () async {
        final due = framesRendered + 8;
        while (framesRendered < due) {
          await Future<void>.delayed(const Duration(milliseconds: 1));
        }
      };
    final registry = LuminaBlueprintClassRegistry(dir, inputActions: const []);

    // BP_LoadingScreen.
    final doc = LuminaBlueprintDocument(parentClass: 'LuminaActor', components: [
      LuminaBlueprintComponent(id: 'root', name: 'DefaultSceneRoot', type: 'LuminaSceneComponent'),
    ], variables: const [
      LuminaBlueprintVariable(name: 'Hud', typeName: 'Widget:WBP_Loading'),
    ]);
    final context = LuminaBlueprintTypeContext.forDocument(doc, className: 'BP_LoadingScreen');
    LuminaBlueprintNode place(String id, String nodeId, [Map<String, dynamic>? literals]) =>
        LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: context);
    var n = 0;
    LuminaBlueprintWire wire(String from, String fromPin, String to, String toPin) =>
        LuminaBlueprintWire(id: 'ls${n++}', fromNodeId: from, fromPinId: fromPin, toNodeId: to, toPinId: toPin);
    doc.eventGraph.nodes.addAll([
      place('event_beginplay', 'begin'),
      place('create_widget', 'create', {'class': 'WBP_Loading'}),
      place(LuminaBlueprintNodeLibrary.variableSet, 'set_hud', {'variable': 'Hud'}),
      place('add_to_viewport', 'show'),
      place('delay', 'wait', {'duration': 2.0}),
      place(LuminaBlueprintNodeLibrary.loadLevel, 'load', {'level_name': 'L_Second'}),
      place(LuminaBlueprintNodeLibrary.variableGet, 'hud', {'variable': 'Hud'}),
      place(LuminaBlueprintNodeLibrary.getWidgetElement, 'progress', {'element': 'Progress'}),
      place(LuminaBlueprintNodeLibrary.getWidgetElement, 'bar', {'element': 'Bar'}),
      place('round', 'pct_round'),
      place('int_to_string', 'pct_text'),
      place('int_to_string', 'loaded_text'),
      place('int_to_string', 'total_text'),
      place('format_string', 'label', {'format': 'LOADING {0}% ({1}/{2}) {3}'}),
      place('set_element_text', 'set_label'),
      place('float_divide', 'fraction', {'b': 100.0}),
      place('set_element_percent', 'set_bar'),
      place('set_element_text', 'set_done', {'in_text': 'LOADED - CHANGING LEVEL'}),
      place('delay', 'hold', {'duration': 1.5}),
      place(LuminaBlueprintNodeLibrary.changeLevel, 'change', {'level_name': 'L_Second'}),
      place('print_string', 'say_changed', {'in_string': 'changed', 'print_to_screen': false}),
      place('set_element_text', 'set_error'),
    ]);
    doc.eventGraph.wires.addAll([
      wire('begin', 'exec_out', 'create', 'exec_in'),
      wire('create', 'exec_out', 'set_hud', 'exec_in'),
      wire('create', 'return_value', 'set_hud', 'value'),
      wire('set_hud', 'exec_out', 'show', 'exec_in'),
      wire('set_hud', 'value', 'show', 'target'),
      wire('show', 'exec_out', 'wait', 'exec_in'),
      wire('wait', 'exec_out', 'load', 'exec_in'),
      wire('hud', 'value', 'progress', 'target'),
      wire('hud', 'value', 'bar', 'target'),
      wire('load', 'on_progress', 'set_label', 'exec_in'),
      wire('progress', 'return_value', 'set_label', 'target'),
      wire('load', 'percent', 'pct_round', 'a'),
      wire('pct_round', 'return_value', 'pct_text', 'in_int'),
      wire('load', 'loaded_count', 'loaded_text', 'in_int'),
      wire('load', 'total_count', 'total_text', 'in_int'),
      wire('pct_text', 'return_value', 'label', 'arg_0'),
      wire('loaded_text', 'return_value', 'label', 'arg_1'),
      wire('total_text', 'return_value', 'label', 'arg_2'),
      wire('load', 'current_content', 'label', 'arg_3'),
      wire('label', 'return_value', 'set_label', 'in_text'),
      wire('set_label', 'exec_out', 'set_bar', 'exec_in'),
      wire('bar', 'return_value', 'set_bar', 'target'),
      wire('load', 'percent', 'fraction', 'a'),
      wire('fraction', 'return_value', 'set_bar', 'in_percent'),
      wire('load', 'on_success', 'set_done', 'exec_in'),
      wire('progress', 'return_value', 'set_done', 'target'),
      wire('set_done', 'exec_out', 'hold', 'exec_in'),
      wire('hold', 'exec_out', 'change', 'exec_in'),
      wire('change', 'on_success', 'say_changed', 'exec_in'),
      wire('load', 'on_error', 'set_error', 'exec_in'),
      wire('progress', 'return_value', 'set_error', 'target'),
      wire('load', 'error', 'set_error', 'in_text'),
    ]);
    final cls = LuminaBlueprintClass.fromDocument(doc, name: 'BP_LoadingScreen');
    expect(cls.diagnostics.where((d) => d.isError), isEmpty, reason: '${cls.diagnostics}');

    // The levels as their actors say, in the yard's light.
    final meshes = <LuminaStaticMeshComponent>[];
    void addMesh(LuminaWorld world, String path, Vector3 location) {
      final mesh = LuminaStaticMeshComponent(meshAssetPath: '$dir/$path');
      meshes.add(mesh);
      world.persistentLevel.registerActor(LuminaActor(root: mesh, location: location));
    }

    final first = yard.world;
    first.persistentLevel.levelName = 'L_First';
    addMesh(first, redBarrelPath, yard.start + Vector3(0, -90, -450));
    final screen = cls.instantiate(location: yard.start.clone());
    final printed = <String>[];
    (screen as LuminaBlueprintRuntime).trace = (e) {
      if (e.printed != null) printed.add(e.printed!);
    };
    first.persistentLevel.registerActor(screen);

    final host = LevelLoadTestHost(first, build: (level, world) {
      world.initializeNativeContext(yard.engine, yard.scene);
      world.registerSubsystem(LuminaCollisionSubsystem());
      world.bindView(yard.view);
      world.persistentLevel.registerActor(LuminaActor(
          root: LuminaDirectionalLightComponent(rotation: LuminaAxes.rotation(const [0, -50, 30]), intensity: 100000, castShadows: true)));
      world.persistentLevel.registerActor(LuminaPrimitiveActor(
          shape: LuminaPrimitiveShape.plane, size: Vector3(3000, 0, 3000), color: Vector3(0.35, 0.42, 0.3), location: yard.start + Vector3(0, -90, -500)));
      addMesh(world, acUnitPath, yard.start + Vector3(-420, -90, -800));
      addMesh(world, dentedBarrelPath, yard.start + Vector3(260, -90, -500));
      world.persistentLevel.registerActor(registry.classFor(crateClassPath)!.instantiate(location: yard.start + Vector3(0, -90, -350)));
      // The same sky and image-based light as the yard.
      yard.scene.setSkybox(FilamentSkybox.build(yard.engine, color: Vector4(0.4, 0.55, 0.8, 1), intensity: 30000));
      yard.scene.setIndirectLight(FilamentIndirectLight.build(
        yard.engine,
        irradiance: SphericalHarmonics(bands: 1, coefficients: [0.6, 0.65, 0.7]),
        intensity: 30000,
      ));
    })
      ..install();
    first.beginPlay();

    final eye = yard.start + Vector3(0, 250, 500);
    final target = yard.start + Vector3(0, -40, -500);
    Uint8List frame() {
      yard.camera.lookAt(eyeX: eye.x, eyeY: eye.y, eyeZ: eye.z, centerX: target.x, centerY: target.y, centerZ: target.z);
      final pixels = yard.captureView();
      // WBP_Loading as the widget subsystem holds it: its text and bar.
      final widgets = host.world.getSubsystem<LuminaWidgetSubsystem>()?.widgets ?? const [];
      if (widgets.isNotEmpty) {
        final elements = widgets.first['elements'] as Map;
        _drawLoadingWidget(pixels, '${(elements['Progress'] as Map)['text']}', ((elements['Bar'] as Map)['percent'] as num).toDouble());
      }
      return pixels;
    }

    final video = SmokeVideoRecorder(width: _w, height: _h, fps: 30, testName: name);
    addTearDown(video.discard);
    Uint8List? midLoad;
    String? midLoadText;
    var uploadsBeforeSwitch = -1;
    Set<String>? keysBeforeSwitch;
    var switchedAt = -1;
    final texts = <String>[];
    // 11 s at 30 Hz: the loading screen, the load, the hold, then L_Second.
    for (var i = 0; i < 330; i++) {
      host.world.tick(1 / 30);
      await Future<void>.delayed(const Duration(milliseconds: 4));
      final shot = frame();
      video.addFrame(shot);
      framesRendered++;
      final widget = first.getSubsystem<LuminaWidgetSubsystem>()?.widgets.firstOrNull;
      final text = widget == null ? null : '${((widget['elements'] as Map)['Progress'] as Map)['text']}';
      if (text != null && (texts.isEmpty || texts.last != text)) texts.add(text);
      if (midLoad == null && text != null && RegExp(r'LOADING (\d+)% \(3/6\)').hasMatch(text)) {
        midLoad = shot;
        midLoadText = text;
      }
      if (uploadsBeforeSwitch < 0 && LuminaLevelPreloader.instance.isLoaded('L_Second')) {
        uploadsBeforeSwitch = LuminaMeshAssetCache.forEngine(yard.engine).uploadCount;
        keysBeforeSwitch = {for (final e in LuminaMeshAssetCache.forEngine(yard.engine).entries) e.key};
      }
      if (switchedAt < 0 && printed.contains('changed')) switchedAt = i;
    }
    expect(switchedAt, greaterThan(0), reason: 'Change Level fired On Success; texts $texts');
    expect(midLoad, isNotNull, reason: 'a frame at 3 of 6; texts $texts');
    expect(texts.where((t) => t.startsWith('LOADING ') && t.contains('/6)')), hasLength(6), reason: '$texts');
    expect(texts, contains('LOADED - CHANGING LEVEL'));
    expect(host.log, contains('L_Second BeginPlay'));
    expect(host.world.persistentLevel.levelName, 'L_Second');
    await Future.wait([for (final m in meshes) m.loaded]).timeout(const Duration(seconds: 60));
    final cache = LuminaMeshAssetCache.forEngine(yard.engine);
    final uploads = cache.uploadCount;
    // Uploaded after the preload finished: only what no manifest names (the
    // generated floor of L_Second), never one of the level's meshes.
    final uploadedAfter = [for (final e in cache.entries) if (!keysBeforeSwitch!.contains(e.key)) e.sourcePath];
    expect(uploadedAfter.where((p) => levelSecondAssets.any((a) => p.endsWith(a))), isEmpty,
        reason: 'L_Second draws the meshes the preload uploaded; new uploads: $uploadedAfter');
    expect(uploads - uploadsBeforeSwitch, uploadedAfter.length);
    final after = frame();
    final used = [for (final p in levelLoadSourceMeshes().values) p];
    final file = SmokeArtifacts.saveScreenshot(name, SmokeArtifacts.encodePng(_w * 2, _h, _sideBySide(midLoad!, after)), usedAssets: used);
    final sidecar = File(file.path.replaceFirst(RegExp(r'\.png$'), '.json'));
    final meta = jsonDecode(sidecar.readAsStringSync()) as Map<String, dynamic>;
    meta['left'] = 'mid-load: $midLoadText';
    meta['right'] = 'after Change Level: L_Second';
    meta['widgetTexts'] = texts;
    meta['preloadPacing'] = 'one asset per 8 rendered frames (LuminaLevelPreloader.betweenItems)';
    meta['meshUploads'] = uploads;
    meta['uploadedAfterPreload'] = uploadedAfter;
    meta['switchedAtFrame'] = switchedAt;
    sidecar.writeAsStringSync(jsonEncode(meta), flush: true);
    SmokeArtifacts.saveVideo(name, video.finish(), usedAssets: used);
    host.world.persistentLevel.unloadActors();
    host.uninstall();
  }, timeout: const Timeout(Duration(minutes: 5)));
}

/// Two RGBA frames of the same size, side by side.
Uint8List _sideBySide(Uint8List left, Uint8List right) {
  final out = Uint8List(left.length * 2);
  const row = _w * 4;
  for (var y = 0; y < _h; y++) {
    out.setRange(y * row * 2, y * row * 2 + row, left, y * row);
    out.setRange(y * row * 2 + row, (y + 1) * row * 2, right, y * row);
  }
  return out;
}

/// One phase of the mannequin script: keys pressed at its start and released
/// at its end, and what happens on each of its 60 Hz frames.
class _Phase {
  final String name;
  final int frames;
  final List<LuminaKey> keys;
  final void Function(LuminaInputSubsystem input, int frame)? during;
  const _Phase(this.name, this.frames, this.keys, [this.during]);

  void begin(LuminaInputSubsystem input) {
    for (final k in keys) {
      input.injectKeyDown(k);
    }
  }

  void end(LuminaInputSubsystem input) {
    for (final k in keys) {
      input.injectKeyUp(k);
    }
  }
}

/// BP_AnimCharacter (the Third Person character with ABP_Character on its mesh)
/// possessed in a yard, run by the VM or as generated Dart.
class _MannyRun {
  final _Yard yard;
  final LuminaCharacter character;
  final LuminaPlayerController pc;
  final LuminaInputSubsystem input;

  _MannyRun._(this.yard, this.character, this.pc, this.input);

  LuminaAnimatedMeshComponent get mesh =>
      (character as LuminaBlueprintRuntime).blueprintComponents['mesh'] as LuminaAnimatedMeshComponent;
  LuminaAnimBlueprintInstance get anim =>
      (character as LuminaBlueprintRuntime).blueprintComponents['mesh.anim'] as LuminaAnimBlueprintInstance;
  LuminaCameraComponent get camera =>
      (character as LuminaBlueprintRuntime).blueprintComponents['camera'] as LuminaCameraComponent;

  static _MannyRun _spawn(_Yard yard, LuminaCharacter Function(List<LuminaInputAction> actions) make) {
    final bound = ProjectInputBinder.bind(GameTemplateCatalog.thirdPerson.input);
    final input = yard.world.registerSubsystem(LuminaInputSubsystem());
    for (final c in bound.contexts) {
      input.addMappingContext(c.context, priority: c.priority);
    }
    final character = make(bound.actions.values.toList());
    character.actorLocation = yard.start.clone();
    final pc = LuminaPlayerController();
    yard.world.persistentLevel.registerActor(character);
    pc.possess(character);
    yard.world.beginPlay();
    return _MannyRun._(yard, character, pc, input);
  }

  static _MannyRun vm(_Yard yard) => _spawn(yard, (actions) {
        final anim = templateAnimClass();
        final cls = LuminaBlueprintClass.fromDocument(
          templateCharacterBlueprint(inputActions: actions),
          name: 'BP_AnimCharacter',
          inputActions: actions,
          animBlueprints: (path) => path == LuminaThirdPersonContent.projectAnimBlueprintPath ? anim.factory : null,
        );
        expect(cls.diagnostics, isEmpty, reason: '${cls.diagnostics}');
        return cls.instantiate() as LuminaCharacter;
      });

  static _MannyRun generated(_Yard yard) => _spawn(yard, (_) => BpAnimCharacter());

  void step() {
    pc.onTick(1 / 60);
    yard.world.tick(1 / 60);
  }

  Uint8List shot() => yard.capture(camera, character.actorLocation + Vector3(0, 60, 0));

  /// 11 s at 60 Hz: stand, walk forward, strafe right, jump while walking
  /// forward and turning, land and stop.
  static final List<_Phase> script = [
    const _Phase('01 idle', 120, []),
    const _Phase('02 walk forward', 180, [LuminaKey.keyW]),
    const _Phase('03 strafe right', 150, [LuminaKey.keyD]),
    _Phase('04 jump', 120, const [LuminaKey.keyW], (input, frame) {
      if (frame == 10) input.injectKeyDown(LuminaKey.keySpace);
      if (frame == 20) input.injectKeyUp(LuminaKey.keySpace);
      if (frame >= 40 && frame < 100) input.injectAnalog(LuminaKey.mouseX, 3.0);
    }),
    const _Phase('05 stop', 90, []),
  ];
}

/// Draws the loading widget (level load smoke) over an RGBA frame: a dark
/// panel with [text] in a 5×7 pixel font and a bar filled to [percent] (0–1).
void _drawLoadingWidget(Uint8List rgba, String text, double percent) {
  void fill(int x0, int y0, int x1, int y1, int r, int g, int b, [double a = 1.0]) {
    for (var y = y0.clamp(0, _h); y < y1.clamp(0, _h); y++) {
      for (var x = x0.clamp(0, _w); x < x1.clamp(0, _w); x++) {
        final i = (y * _w + x) * 4;
        rgba[i] = (rgba[i] * (1 - a) + r * a).round();
        rgba[i + 1] = (rgba[i + 1] * (1 - a) + g * a).round();
        rgba[i + 2] = (rgba[i + 2] * (1 - a) + b * a).round();
      }
    }
  }

  const panelTop = _h - 150;
  fill(40, panelTop, _w - 40, _h - 40, 12, 14, 20, 0.82);
  const scale = 4;
  var x = 64;
  for (final ch in text.toUpperCase().split('')) {
    final glyph = _font[ch] ?? _font['?']!;
    for (var row = 0; row < 7; row++) {
      for (var col = 0; col < 5; col++) {
        if (glyph[row] & (1 << (4 - col)) != 0) {
          fill(x + col * scale, panelTop + 22 + row * scale, x + (col + 1) * scale, panelTop + 22 + (row + 1) * scale, 240, 240, 245);
        }
      }
    }
    x += 6 * scale;
    if (x > _w - 80) break;
  }
  const barTop = _h - 82;
  fill(64, barTop, _w - 64, barTop + 22, 50, 55, 70);
  fill(64, barTop, 64 + ((_w - 128) * percent.clamp(0.0, 1.0)).round(), barTop + 22, 70, 170, 255);
}

/// A 5×7 pixel font: seven rows of five bits per glyph.
const Map<String, List<int>> _font = {
  ' ': [0, 0, 0, 0, 0, 0, 0],
  'A': [14, 17, 17, 31, 17, 17, 17], 'B': [30, 17, 17, 30, 17, 17, 30], 'C': [14, 17, 16, 16, 16, 17, 14],
  'D': [30, 17, 17, 17, 17, 17, 30], 'E': [31, 16, 16, 30, 16, 16, 31], 'F': [31, 16, 16, 30, 16, 16, 16],
  'G': [14, 17, 16, 23, 17, 17, 15], 'H': [17, 17, 17, 31, 17, 17, 17], 'I': [14, 4, 4, 4, 4, 4, 14],
  'J': [7, 2, 2, 2, 2, 18, 12], 'K': [17, 18, 20, 24, 20, 18, 17], 'L': [16, 16, 16, 16, 16, 16, 31],
  'M': [17, 27, 21, 21, 17, 17, 17], 'N': [17, 17, 25, 21, 19, 17, 17], 'O': [14, 17, 17, 17, 17, 17, 14],
  'P': [30, 17, 17, 30, 16, 16, 16], 'Q': [14, 17, 17, 17, 21, 18, 13], 'R': [30, 17, 17, 30, 20, 18, 17],
  'S': [15, 16, 16, 14, 1, 1, 30], 'T': [31, 4, 4, 4, 4, 4, 4], 'U': [17, 17, 17, 17, 17, 17, 14],
  'V': [17, 17, 17, 17, 17, 10, 4], 'W': [17, 17, 17, 21, 21, 21, 10], 'X': [17, 17, 10, 4, 10, 17, 17],
  'Y': [17, 17, 10, 4, 4, 4, 4], 'Z': [31, 1, 2, 4, 8, 16, 31],
  '0': [14, 17, 19, 21, 25, 17, 14], '1': [4, 12, 4, 4, 4, 4, 14], '2': [14, 17, 1, 2, 4, 8, 31],
  '3': [31, 2, 4, 2, 1, 17, 14], '4': [2, 6, 10, 18, 31, 2, 2], '5': [31, 16, 30, 1, 1, 17, 14],
  '6': [6, 8, 16, 30, 17, 17, 14], '7': [31, 1, 2, 4, 8, 8, 8], '8': [14, 17, 17, 14, 17, 17, 14],
  '9': [14, 17, 17, 15, 1, 2, 12],
  '%': [24, 25, 2, 4, 8, 19, 3], '(': [2, 4, 8, 8, 8, 4, 2], ')': [8, 4, 2, 2, 2, 4, 8],
  '/': [0, 1, 2, 4, 8, 16, 0], '_': [0, 0, 0, 0, 0, 0, 31], '-': [0, 0, 0, 31, 0, 0, 0],
  '.': [0, 0, 0, 0, 0, 12, 12], ':': [0, 12, 12, 0, 12, 12, 0], '?': [14, 17, 1, 2, 4, 0, 4],
};
