import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_filament/src/third_party/filament_c.g.dart' as c;
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/testing.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:vector_math/vector_math_64.dart';

import '../helpers/locomotion_fbx_fixture.dart';

/// Traversal on GPU 1: the UEFN mannequin with the Game Animation Sample
/// locomotion clips (motion matching in an Animation Blueprint) and its
/// traversal clips (test-assets) runs at five obstacles and jumps in front
/// of each: a hurdle over a thin wall, a vault over a wall at a platform's
/// edge (falling after), a low and a high mantle at a run and a low mantle
/// from standing — root motion warped onto the measured ledges, played in
/// the Animation Blueprint's slot and handed back to motion matching.
void main() {
  final traversalDir = Directory('${LocomotionFbxFixture.directory.path}/Traversal');
  final skip = LocomotionFbxFixture.available && traversalDir.existsSync()
      ? null
      : 'test-assets/FBX/GameAnimationSample(/Traversal) is missing';
  test('Scenario 01: hurdle, vault, low and high mantle with root motion and motion warping',
      () => _scenario('traversal_smoke_test: Scenario 01 hurdle vault mantle', traversalDir),
      skip: skip, timeout: const Timeout(Duration(minutes: 10)));
}

/// One obstacle lane: where it is, what it is, and what should happen.
class _Lane {
  final String label;
  final double x;
  final double floor;
  final double height;
  final double depth;
  final double speed;
  final LuminaTraversalActionType action;
  const _Lane(this.label, this.x, this.floor, this.height, this.depth, this.speed, this.action);
}

Future<void> _scenario(String testName, Directory traversalDir) async {
  const width = SmokeVideo.defaultWidth;
  const height = SmokeVideo.defaultHeight;
  final metadata = jsonDecode(File('${traversalDir.path}/metadata.json').readAsStringSync()) as Map<String, dynamic>;
  var glb = await LocomotionFbxFixture.mergedGlb();
  final sources = <String, Uint8List>{};
  for (final f in traversalDir.listSync().whereType<File>().where((f) => f.path.endsWith('.fbx'))) {
    final name = LocomotionFbxFixture.clipName(f);
    sources[name] = (await FbxImportService.convert(f.path)).glb;
    glb = GlbAnimationRetargeter.retargetInto(target: glb, clip: sources[name]!, clipName: name).glb;
  }
  final rows = GaspTraversal.withWarpPointOffsets([
    for (final r in GaspTraversal.rows(metadata))
      if (sources.containsKey(r.clip)) r,
  ], sources);
  final usedAssets = [
    'test-assets/FBX/GameAnimationSample/SKM_UEFN_Mannequin.fbx',
    '${LocomotionFbxFixture.clipFiles.length} locomotion clips from test-assets/FBX/GameAnimationSample (FBX)',
    for (final clip in sources.keys) 'test-assets/FBX/GameAnimationSample/Traversal/$clip.fbx',
  ];
  final tempDir = Directory.systemTemp.createTempSync('lumina_traversal_smoke_');
  final meshPath = '${tempDir.path}/SKM_UEFN_Mannequin_Traversal.glb';
  File(meshPath).writeAsBytesSync(await GlbParserService.convertGlbTgaToPngAsync(glb));
  LuminaPoseSearchDatabaseRuntime.clearShared();
  final databasePath = '${tempDir.path}/PSD_Locomotion.lmas';
  final document = LocomotionFbxFixture.document(targetMesh: meshPath);

  final engine = FilamentEngine.create()!;
  final scene = engine.createScene();
  final view = engine.createView();
  final renderer = engine.createRenderer();
  final swapChain = engine.createHeadlessSwapChain(width, height);
  final cameraEntity = engine.createEntity();
  final camera = engine.createCamera(cameraEntity);
  view
    ..scene = scene
    ..camera = camera
    ..setViewport(0, 0, width, height);
  camera.setProjectionFov(fovDegrees: 50, aspect: width / height, near: 10.0, far: 100000.0);
  final skybox = FilamentSkybox.build(engine, color: Vector4(0.4, 0.56, 0.82, 1.0), intensity: 30000.0);
  scene.setSkybox(skybox);
  final sunEntity = engine.createEntity();
  LightBuilder(LightType.directional)
      .color(1.0, 0.97, 0.9)
      .intensity(100000.0)
      .direction(-0.6, -0.7, -0.3)
      .castShadows(true)
      .build(engine, sunEntity);
  scene.addEntity(sunEntity);
  final indirectLight = FilamentIndirectLight.build(engine,
      irradiance: SphericalHarmonics(bands: 1, coefficients: [0.6, 0.65, 0.7]), intensity: 30000.0);
  scene.setIndirectLight(indirectLight);

  final world = LuminaWorld(worldType: LuminaWorldType.game);
  world.initializeNativeContext(engine, scene, view: view);
  world.registerSubsystem(LuminaCollisionSubsystem());
  void box(Vector3 min, Vector3 max, Vector3 color) {
    world.persistentLevel.registerActor(LuminaPrimitiveActor(
        shape: LuminaPrimitiveShape.box, size: max - min, color: color, location: (min + max) * 0.5));
  }

  // Lanes along −Z, obstacle faces at z = −600.
  const lanes = [
    _Lane('01 hurdle', -900, 0, 100, 20, 450, LuminaTraversalActionType.hurdle),
    _Lane('02 vault', -450, 150, 100, 30, 450, LuminaTraversalActionType.vault),
    _Lane('03 low mantle', 0, 0, 110, 900, 450, LuminaTraversalActionType.mantle),
    _Lane('04 high mantle', 450, 0, 220, 900, 450, LuminaTraversalActionType.mantle),
    _Lane('05 mantle from standing', 900, 0, 120, 900, 0, LuminaTraversalActionType.mantle),
  ];
  box(Vector3(-3000, -100, -3000), Vector3(3000, 0, 1500), Vector3(0.45, 0.47, 0.5));
  for (final l in lanes) {
    final grey = Vector3(0.75, 0.72, 0.62);
    if (l.floor > 0) box(Vector3(l.x - 150, 0, -600 - l.depth), Vector3(l.x + 150, l.floor, 800), Vector3(0.55, 0.6, 0.66));
    box(Vector3(l.x - 150, l.floor, -600 - l.depth), Vector3(l.x + 150, l.floor + l.height, -600), grey);
  }

  const halfHeight = 90.0;
  final character = LuminaCharacter(location: Vector3(lanes.first.x, halfHeight + 0.2, 300));
  character.capsuleComponent
    ..capsuleHalfHeight = halfHeight
    ..capsuleRadius = 35.0;
  character.characterMovement.maxWalkSpeed = 450;
  final mesh = LuminaAnimatedMeshComponent(meshAssetPath: meshPath, location: Vector3(0.0, -halfHeight, 0.0));
  final abp = LuminaAnimBlueprintDocument(
    variables: const [LuminaBlueprintVariable(name: LuminaAnimBlueprintInstance.matchedClipVariable, typeName: 'String', defaultValue: '')],
    eventGraph: LuminaBlueprintGraph(
        nodes: [LuminaBlueprintNodeLibrary.place(LuminaBlueprintNodeLibrary.updateAnimation, nodeId: 'update', x: 0, y: 0)]),
    stateMachines: [
      LuminaAnimStateMachine(name: 'Locomotion', entryState: 'Locomotion', states: [
        LuminaAnimState('Locomotion', LuminaAnimPose.motionMatching(databasePath, orientToMovement: true)),
      ], transitions: const []),
    ],
  );
  final cls = LuminaAnimBlueprintClass.fromDocument(abp, name: 'ABP_Traversal', poseDatabases: {databasePath: document});
  expect(cls.hasErrors, isFalse, reason: '${cls.diagnostics}');
  final anim = cls.instantiate(mesh);
  final traversal = LuminaTraversalComponent(animations: rows, rootBone: GaspTraversal.rootBone);
  character
    ..addComponent(anim)
    ..addComponent(mesh)
    ..addComponent(traversal);
  world.persistentLevel.registerActor(character);
  world.beginPlay();
  await mesh.loaded;
  await anim.motionMatching.load(databasePath);
  world.tick(1 / 60);

  final eye = Vector3.zero();
  final target = Vector3.zero();
  void placeCamera({bool snap = false}) {
    final p = character.actorLocation;
    final goalTarget = Vector3(p.x, p.y + 20.0, p.z - 60.0);
    final goalEye = Vector3(p.x + 520.0, p.y + 160.0, p.z + 120.0);
    if (snap || target.length2 == 0) {
      target.setFrom(goalTarget);
      eye.setFrom(goalEye);
    }
    target.setFrom(target + (goalTarget - target) * 0.15);
    eye.setFrom(eye + (goalEye - eye) * 0.15);
    camera.lookAt(eyeX: eye.x, eyeY: eye.y, eyeZ: eye.z, centerX: target.x, centerY: target.y, centerZ: target.z);
  }

  final pixels = calloc<ffi.Uint8>(width * height * 4);
  final video = SmokeVideoRecorder(width: width, height: height, fps: 30, testName: testName);
  addTearDown(video.discard);
  Uint8List render() {
    placeCamera();
    if (renderer.beginFrame(swapChain)) {
      renderer.render(view);
      c.filament_renderer_read_pixels(
          renderer.nativePointer, engine.nativePointer, 0, 0, width, height, pixels.cast(), ffi.nullptr, ffi.nullptr);
      renderer.endFrame();
    }
    engine.flushAndWait();
    return Uint8List.fromList(pixels.asTypedList(width * height * 4));
  }

  var frame = 0;
  void step({Vector3? input}) {
    if (input != null) character.characterMovement.addInputVector(input);
    world.tick(1 / 60);
    world.flushDebugShapes();
    if (frame++ % 2 == 0) video.addFrame(render());
  }

  final forward = Vector3(0, 0, -1);
  final results = <String, String>{};
  final micros = <int>[];
  for (final lane in lanes) {
    character.characterMovement.stopMovementImmediately();
    character.actorLocation = Vector3(lane.x, lane.floor + halfHeight + 0.2, lane.speed > 0 ? 200 : -520);
    LuminaMotionMatchingCharacter.setFacingYaw(character, 3.14159265);
    placeCamera(snap: true);
    // Run (or stand) up to the obstacle, then jump: traversal.
    var started = false;
    for (var i = 0; i < 240 && !started; i++) {
      final face = -600.0 - character.actorLocation.z;
      final close = lane.speed > 0 ? face > -260 : i > 30;
      if (close) {
        final watch = Stopwatch()..start();
        started = traversal.tryTraversalAction();
        micros.add(watch.elapsedMicroseconds);
        if (!started) fail('${lane.label}: no traversal (${traversal.lastCheck})');
      }
      step(input: lane.speed > 0 ? forward : null);
    }
    expect(traversal.lastCheck!.actionType, lane.action, reason: '${lane.label}: ${traversal.lastCheck}');
    final clip = traversal.lastChoice!.animation.clip;
    var shot = false;
    while (traversal.isTraversing) {
      step(input: lane.speed > 0 ? forward : null);
      final p = traversal.player;
      if (!shot && p != null && p.time > (p.windows.isEmpty ? 0.6 : p.windows.first.end)) {
        shot = true;
        SmokeArtifacts.saveScreenshot('$testName ${lane.label}', SmokeArtifacts.encodePng(width, height, render()),
            usedAssets: usedAssets);
      }
    }
    for (var i = 0; i < 50; i++) {
      step(input: lane.speed > 0 ? forward : null);
    }
    final y = character.actorLocation.y - halfHeight;
    results[lane.label] = '$clip -> feet y ${y.toStringAsFixed(1)}, z ${character.actorLocation.z.toStringAsFixed(0)}, '
        'state ${anim.currentState}, matched ${anim.variables[LuminaAnimBlueprintInstance.matchedClipVariable]}';
    expect(identical(mesh.poseDriver, anim.motionMatching.player), isTrue, reason: '${lane.label}: motion matching took the mesh back');
    if (lane.action == LuminaTraversalActionType.mantle) {
      expect(y, closeTo(lane.floor + lane.height, 5), reason: '${lane.label}: on top');
    } else if (lane.action == LuminaTraversalActionType.hurdle) {
      expect(y, closeTo(lane.floor, 5), reason: '${lane.label}: on the floor behind');
      expect(character.actorLocation.z, lessThan(-600 - lane.depth), reason: lane.label);
    } else {
      expect(character.actorLocation.z, lessThan(-600 - lane.depth), reason: '${lane.label}: over the wall');
      expect(y, lessThan(lane.floor), reason: '${lane.label}: dropped off the platform');
    }
  }
  // ignore: avoid_print
  print('traversal smoke: $results; check + choose µs: $micros');
  expect(video.seconds, greaterThanOrEqualTo(SmokeArtifacts.minimumVideoSeconds));
  SmokeArtifacts.saveVideo(testName, video.finish(), usedAssets: usedAssets);

  calloc.free(pixels);
  world.cleanup();
  skybox.dispose();
  indirectLight.dispose();
  engine.destroyEntity(sunEntity);
  view.dispose();
  scene.dispose();
  engine.destroyEntity(cameraEntity);
  camera.dispose();
  renderer.dispose();
  swapChain.dispose();
  engine.dispose();
  LuminaPoseSearchDatabaseRuntime.clearShared();
  tempDir.deleteSync(recursive: true);
}
