import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_filament/src/third_party/filament_c.g.dart' as c;
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/testing.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:vector_math/vector_math_64.dart';

import '../helpers/locomotion_fbx_fixture.dart';

/// Motion matching on GPU 1: the UEFN mannequin with the Game Animation
/// Sample idle / walk / run clips (imported from FBX) as a pose search
/// database walks the Third Person template map under scripted input —
/// stand, walk, turn, stop, strafe, stop — its capsule moving it while the
/// matched frames follow; the desired (green) and matched (orange)
/// trajectories are drawn over the frames. Scenario 01 drives the mesh with a
/// `LuminaMotionMatchingComponent`, Scenario 02 with an Animation Blueprint
/// (VM) whose Locomotion and Strafe states play motion matching.
void main() {
  final skip = LocomotionFbxFixture.available ? null : 'test-assets/FBX/GameAnimationSample is missing';

  test('Scenario 01: motion matching drives the mannequin from scripted input',
      () => _scenario('animation_motion_matching_smoke_test: Scenario 01 motion matching locomotion', animBlueprint: false),
      skip: skip, timeout: const Timeout(Duration(minutes: 10)));

  test('Scenario 02: an Animation Blueprint motion matching state drives the mannequin',
      () => _scenario('animation_motion_matching_smoke_test: Scenario 02 anim blueprint motion matching state', animBlueprint: true),
      skip: skip, timeout: const Timeout(Duration(minutes: 10)));
}

/// An Animation Blueprint with two Motion Matching states over [database]:
/// Locomotion (turns the pawn toward its movement) and Strafe (keeps the
/// pawn's facing), switched by the `Strafing` variable.
LuminaAnimBlueprintDocument _motionMatchingAbp(String database) {
  final variables = [
    const LuminaBlueprintVariable(name: 'Strafing', typeName: 'Bool', defaultValue: false),
    const LuminaBlueprintVariable(name: LuminaAnimBlueprintInstance.matchedClipVariable, typeName: 'String', defaultValue: ''),
  ];
  final context = LuminaBlueprintTypeContext(variables: variables);
  LuminaBlueprintNode place(String id, String nodeId, double x, [Map<String, dynamic>? literals]) =>
      LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, x: x, y: 0, literals: literals, context: context);
  LuminaBlueprintGraph strafing({bool not = false}) => LuminaBlueprintGraph(
        nodes: [
          place(LuminaBlueprintNodeLibrary.variableGet, 'flag', 0, {'variable': 'Strafing'}),
          if (not) place('bool_not', 'not', 240),
          place(LuminaBlueprintNodeLibrary.transitionResult, 'result', 480),
        ],
        wires: [
          if (not) ...[
            LuminaBlueprintWire(id: 'w0', fromNodeId: 'flag', fromPinId: 'value', toNodeId: 'not', toPinId: 'a'),
            LuminaBlueprintWire(id: 'w1', fromNodeId: 'not', fromPinId: 'return_value', toNodeId: 'result', toPinId: 'can_enter'),
          ] else
            LuminaBlueprintWire(id: 'w0', fromNodeId: 'flag', fromPinId: 'value', toNodeId: 'result', toPinId: 'can_enter'),
        ],
      );
  return LuminaAnimBlueprintDocument(
    variables: variables,
    eventGraph: LuminaBlueprintGraph(nodes: [
      LuminaBlueprintNodeLibrary.place(LuminaBlueprintNodeLibrary.updateAnimation, nodeId: 'update', x: 0, y: 0),
    ]),
    stateMachines: [
      LuminaAnimStateMachine(
        name: 'Locomotion',
        entryState: 'Locomotion',
        states: [
          LuminaAnimState('Locomotion',
              LuminaAnimPose.motionMatching(database, orientToMovement: true, debugDraw: true, requiredTags: const ['walk'])),
          LuminaAnimState('Strafe', LuminaAnimPose.motionMatching(database, debugDraw: true, requiredTags: const ['walk'])),
        ],
        transitions: [
          LuminaAnimTransition(id: 'locomotion_to_strafe', from: 'Locomotion', to: 'Strafe', rule: strafing()),
          LuminaAnimTransition(id: 'strafe_to_locomotion', from: 'Strafe', to: 'Locomotion', rule: strafing(not: true)),
        ],
      ),
    ],
  );
}

Future<void> _scenario(String testName, {required bool animBlueprint}) async {
  {
    final usedAssets = [
      'test-assets/FBX/GameAnimationSample/SKM_UEFN_Mannequin.fbx',
      '${LocomotionFbxFixture.clipFiles.length} clips from test-assets/FBX/GameAnimationSample (Idle, Walk, Run; FBX)',
    ];
    final glb = await LocomotionFbxFixture.mergedGlb();
    final tempDir = Directory.systemTemp.createTempSync('lumina_mm_smoke_');
    final meshPath = '${tempDir.path}/SKM_UEFN_Mannequin_Locomotion.glb';
    // What an import stores: the GLB sanitized like an imported mesh.
    File(meshPath).writeAsBytesSync(await GlbParserService.convertGlbTgaToPngAsync(glb));
    final buildWatch = Stopwatch()..start();
    final db = await LuminaPoseSearchDatabaseRuntime.fromGlb(glb, LocomotionFbxFixture.document(targetMesh: meshPath));
    buildWatch.stop();

    const width = SmokeVideo.defaultWidth;
    const height = SmokeVideo.defaultHeight;
    final engine = FilamentEngine.create()!;
    final scene = engine.createScene();
    final view = engine.createView();
    final renderer = engine.createRenderer();
    final swapChain = engine.createHeadlessSwapChain(width, height);
    final cameraEntity = engine.createEntity();
    final camera = engine.createCamera(cameraEntity);
    view.scene = scene;
    view.camera = camera;
    view.setViewport(0, 0, width, height);
    const fov = 45.0;
    camera.setProjectionFov(fovDegrees: fov, aspect: width / height, near: 10.0, far: 100000.0);

    final skybox = FilamentSkybox.build(engine, color: Vector4(0.35, 0.55, 0.85, 1.0), intensity: 30000.0);
    scene.setSkybox(skybox);
    final sunEntity = engine.createEntity();
    LightBuilder(LightType.directional)
        .color(1.0, 0.97, 0.9)
        .intensity(100000.0)
        .direction(-0.5, -0.8, -0.35)
        .castShadows(true)
        .build(engine, sunEntity);
    scene.addEntity(sunEntity);
    final indirectLight = FilamentIndirectLight.build(
      engine,
      irradiance: SphericalHarmonics(bands: 1, coefficients: [0.6, 0.65, 0.7]),
      intensity: 30000.0,
    );
    scene.setIndirectLight(indirectLight);

    final world = LuminaWorld(worldType: LuminaWorldType.game);
    world.initializeNativeContext(engine, scene, view: view);
    world.registerSubsystem(LuminaCollisionSubsystem());
    Vector3? start;
    for (final actor in GameTemplateCatalog.thirdPerson.levelActors) {
      final loc = (actor['location'] as List).cast<double>();
      if (actor['type'] == 'PlayerStart') start = LuminaAxes.location(loc);
      if (actor['type'] != 'Primitive') continue;
      final props = Map<String, dynamic>.from(((actor['components'] as List).first as Map)['properties'] as Map);
      world.persistentLevel.registerActor(LuminaPrimitiveActor.fromComponentProperties(props, location: LuminaAxes.location(loc)));
    }
    expect(start, isNotNull);

    const halfHeight = 90.0;
    final character = LuminaCharacter(location: start);
    character.capsuleComponent.capsuleHalfHeight = halfHeight;
    character.capsuleComponent.capsuleRadius = 35.0;
    final walkClip = db.document.clips.indexWhere((c) => c.clip == 'M_Neutral_Walk_Loop_F');
    final walkSpeed = db.rootSpeed(walkClip, 0.5) * 100.0;
    character.characterMovement.maxWalkSpeed = walkSpeed;
    final mesh = LuminaAnimatedMeshComponent(meshAssetPath: meshPath, location: Vector3(0.0, -halfHeight, 0.0));
    LuminaMotionMatchingComponent? mm;
    LuminaAnimBlueprintInstance? anim;
    final databasePath = '${tempDir.path}/PSD_Locomotion.lmas';
    if (animBlueprint) {
      final cls = LuminaAnimBlueprintClass.fromDocument(_motionMatchingAbp(databasePath),
          name: 'ABP_MotionMatching', poseDatabases: {databasePath: db.document});
      expect(cls.hasErrors, isFalse, reason: '${cls.diagnostics}');
      anim = cls.instantiate(mesh);
      character.addComponent(anim);
    } else {
      mm = LuminaMotionMatchingComponent(runtime: db, mesh: mesh, orientToMovement: true, debugDraw: true)
        ..requiredTags = {'walk'};
      character.addComponent(mm);
    }
    character.addComponent(mesh);
    world.persistentLevel.registerActor(character);
    world.beginPlay();
    await mesh.loaded;
    if (anim != null) {
      // The instance loads the database itself (from the document, building
      // and writing the .posedb next to the asset).
      final loaded = await anim.motionMatching.load(databasePath);
      expect(File(LuminaPoseSearchDatabaseRuntime.cachePathOf(databasePath)).existsSync(), isTrue);
      expect(loaded.index.rowCount, db.index.rowCount);
      world.tick(1 / 60);
    } else {
      await mm!.ready;
    }
    LuminaMotionMatchingPlayer player() => anim != null ? anim.motionMatching.player! : mm!.player!;

    // A chase camera behind and above the character, looking at its chest.
    final eye = Vector3.zero();
    final target = Vector3.zero();
    void placeCamera() {
      final p = character.actorLocation;
      final goalTarget = Vector3(p.x, p.y + 10.0, p.z);
      final goalEye = Vector3(p.x + 330.0, p.y + 170.0, p.z + 330.0);
      if (target.length2 == 0) {
        target.setFrom(goalTarget);
        eye.setFrom(goalEye);
      }
      target.setFrom(target + (goalTarget - target) * 0.1);
      eye.setFrom(eye + (goalEye - eye) * 0.1);
      camera.lookAt(eyeX: eye.x, eyeY: eye.y, eyeZ: eye.z, centerX: target.x, centerY: target.y, centerZ: target.z);
    }

    // The debug trajectories, projected with the same camera, drawn over the frame.
    void overlay(Uint8List rgba) {
      final viewMatrix = makeViewMatrix(eye, target, Vector3(0.0, 1.0, 0.0));
      final projection = makePerspectiveMatrix(fov * math.pi / 180.0, width / height, 10.0, 100000.0);
      final vp = projection * viewMatrix;
      (double, double)? project(Vector3 p) {
        final v = vp.transform(Vector4(p.x, p.y, p.z, 1.0));
        if (v.w <= 1e-6) return null;
        return ((v.x / v.w * 0.5 + 0.5) * width, (1.0 - (v.y / v.w * 0.5 + 0.5)) * height);
      }

      void dot(double x, double y, List<int> color, int r) {
        for (var dy = -r; dy <= r; dy++) {
          for (var dx = -r; dx <= r; dx++) {
            if (dx * dx + dy * dy > r * r) continue;
            final px = x.round() + dx, py = y.round() + dy;
            if (px < 0 || py < 0 || px >= width || py >= height) continue;
            final o = (py * width + px) * 4;
            rgba[o] = color[0];
            rgba[o + 1] = color[1];
            rgba[o + 2] = color[2];
          }
        }
      }

      void path(List<Vector3> points, List<int> color, double lift) {
        final ground = character.actorLocation.y - halfHeight + lift;
        final projected = [for (final p in points) project(Vector3(p.x, ground, p.z))];
        for (var i = 0; i + 1 < projected.length; i++) {
          final a = projected[i], b = projected[i + 1];
          if (a == null || b == null) continue;
          for (var k = 0; k <= 24; k++) {
            dot(a.$1 + (b.$1 - a.$1) * k / 24, a.$2 + (b.$2 - a.$2) * k / 24, color, 2);
          }
        }
        for (final p in projected) {
          if (p != null) dot(p.$1, p.$2, color, 5);
        }
      }

      path(player().desiredTrajectory, const [40, 230, 70], 2.0);
      path(player().matchedTrajectory, const [255, 150, 20], 4.0);
    }

    final pixelBuf = calloc<ffi.Uint8>(width * height * 4);
    final video = SmokeVideoRecorder(width: width, height: height, fps: 30, testName: testName);
    addTearDown(video.discard);
    Uint8List render() {
      placeCamera();
      if (renderer.beginFrame(swapChain)) {
        renderer.render(view);
        c.filament_renderer_read_pixels(
            renderer.nativePointer, engine.nativePointer, 0, 0, width, height, pixelBuf.cast(), ffi.nullptr, ffi.nullptr);
        renderer.endFrame();
      }
      engine.flushAndWait();
      final frame = Uint8List.fromList(pixelBuf.asTypedList(width * height * 4));
      overlay(frame);
      return frame;
    }

    final phases = <String, List<String>>{};
    var tick = 0;
    void run(String phase, double seconds, Vector3 input, {double? lockYaw}) {
      if (mm != null) {
        mm.orientToMovement = lockYaw == null;
        mm.desiredYaw = lockYaw == null ? null : () => lockYaw;
      } else {
        anim!.variables['Strafing'] = lockYaw != null;
      }
      final ticks = (seconds * 60).round();
      final clips = phases.putIfAbsent(phase, () => []);
      for (var i = 0; i < ticks; i++) {
        if (input.length2 > 0) character.characterMovement.addInputVector(input);
        world.tick(1 / 60);
        world.flushDebugShapes();
        final pl = player();
        final clip = pl.matchedClip == null ? null : '${pl.matchedClip}${pl.matchedMirrored ? ' (mirrored)' : ''}';
        if (clip != null && (clips.isEmpty || clips.last != clip)) clips.add(clip);
        if (tick++ % 2 == 0) video.addFrame(render());
      }
    }

    void shot(String phase) {
      SmokeArtifacts.saveScreenshot('$testName $phase', SmokeArtifacts.encodePng(width, height, render()), usedAssets: usedAssets);
    }

    final forward = Vector3(0.0, 0.0, -1.0);
    final right = Vector3(1.0, 0.0, 0.0);
    run('idle', 1.5, Vector3.zero());
    shot('01 idle');
    // The drawn mesh faces where the capsule moves (the mesh's +Z, turned to
    // the owner's facing).
    void expectFacingMovement(String phase) {
      final v = Vector3(character.characterMovement.velocity.x, 0.0, character.characterMovement.velocity.z).normalized();
      final drawn = mesh.worldTransform.getRotation().transformed(Vector3(0.0, 0.0, 1.0))..y = 0.0;
      expect(drawn.normalized().dot(v), greaterThan(0.9), reason: '$phase: the body faces its movement');
    }

    run('walk', 3.0, forward);
    expectFacingMovement('walk');
    shot('02 walking forward');
    run('turn', 2.0, right);
    expectFacingMovement('turn');
    shot('03 turned right');
    run('stop', 2.0, Vector3.zero());
    shot('04 stopped');
    final facing = LuminaMotionMatchingCharacter.facingYaw(character);
    run('strafe', 2.5, forward, lockYaw: facing);
    if (anim != null) expect(anim.currentState, 'Strafe');
    shot('05 strafing');
    run('stop2', 3.0, Vector3.zero());
    shot('06 idle again');

    // ignore: avoid_print
    print('phases: $phases');
    final player0 = player();
    if (anim != null) {
      expect(anim.variables[LuminaAnimBlueprintInstance.matchedClipVariable], player0.matchedClip);
    }
    // ignore: avoid_print
    print('database: ${db.index.rowCount} rows ${db.index.dimensions} dims, loaded in ${buildWatch.elapsedMilliseconds} ms; '
        'player: ${player0.searchCount} searches ${player0.switchCount} switches, search mean '
        '${player0.meanSearchMicroseconds.toStringAsFixed(0)} µs max ${player0.maxSearchMicroseconds} µs, frame mean '
        '${player0.meanUpdateMicroseconds.toStringAsFixed(0)} µs max ${player0.maxUpdateMicroseconds} µs');

    expect(phases['idle']!.last, contains('Idle'));
    expect(phases['walk']!.any((c) => c.contains('Walk_Start') || c.contains('Walk_Loop_F')), isTrue, reason: '${phases['walk']}');
    expect(phases['walk']!.last, isNot(contains('Stop')));
    expect(phases['stop']!.any((c) => c.contains('Stop')), isTrue, reason: '${phases['stop']}');
    expect(phases['stop']!.last, contains('Idle'));
    expect(phases['strafe']!.any((c) => RegExp(r'_(LL|LR|RL|RR)').hasMatch(c)), isTrue,
        reason: 'walking sideways while facing ahead plays a strafe: ${phases['strafe']}');
    expect(phases['stop2']!.any((c) => c.contains('Stop') || c.contains('Idle')), isTrue, reason: '${phases['stop2']}');
    expect(player0.matchedRootSpeed, lessThan(10.0), reason: 'standing again: the matched frame no longer moves');
    expect(character.characterMovement.isFalling, isFalse);
    expect(player0.meanUpdateMicroseconds, lessThan(2000));
    expect(video.seconds, greaterThanOrEqualTo(SmokeArtifacts.minimumVideoSeconds));
    SmokeArtifacts.saveVideo(testName, video.finish(), usedAssets: usedAssets);

    calloc.free(pixelBuf);
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
    tempDir.deleteSync(recursive: true);
  }
}
