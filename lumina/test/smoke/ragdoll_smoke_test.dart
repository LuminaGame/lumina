import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_filament/src/third_party/filament_c.g.dart' as c;
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina/testing.dart';
import 'package:vector_math/vector_math_64.dart';

import '../src/physics/ragdoll/ragdoll_fixture.dart';

/// The mannequin walks off a 7 m ledge: past 1000 cm/s it goes limp in the
/// air (its joints pulled toward a flail pose), lands, settles, and gets up
/// with the get-up clip that lies like it, then stands on its capsule again.
void main() {
  test('Physics Smoke Scenario 02: the mannequin falls off a ledge into a ragdoll, settles and gets up', () async {
    const testTitle = 'Physics Smoke Scenario 02: the mannequin falls off a ledge into a ragdoll, settles and gets up';
    if (!mannyFile.existsSync()) return markTestSkipped('test-assets missing mannequin/SKM_Manny_Simple.glb');
    const w = 1024, h = 768;
    final engine = FilamentEngine.create()!;
    final scene = engine.createScene();
    final view = engine.createView();
    final renderer = engine.createRenderer();
    final swapChain = engine.createHeadlessSwapChain(w, h);
    final camera = engine.createCamera(engine.createEntity());
    view
      ..scene = scene
      ..camera = camera
      ..setViewport(0, 0, w, h);
    camera.setProjection(fovDegrees: 45, aspect: w / h, near: 10, far: 100000, direction: FovDirection.vertical);
    scene.setSkybox(FilamentSkybox.build(engine, color: Vector4(0.45, 0.58, 0.8, 1), intensity: 30000));
    scene.setIndirectLight(FilamentIndirectLight.build(engine,
        irradiance: SphericalHarmonics(bands: 1, coefficients: [0.7, 0.7, 0.75]), intensity: 30000));
    final pixels = calloc<ffi.Uint8>(w * h * 4);
    final dir = Directory.systemTemp.createTempSync('ragdoll_smoke_');
    final world = LuminaWorld(worldType: LuminaWorldType.game)..initializeNativeContext(engine, scene);
    addTearDown(() {
      world.cleanup();
      calloc.free(pixels);
      engine.dispose();
      dir.deleteSync(recursive: true);
    });
    world.registerSubsystem(LuminaCollisionSubsystem());
    final physics = world.registerSubsystem(LuminaPhysicsSubsystem());
    world.bindView(view);
    SmokeArtifacts.recordAsset(mannyFile.path);

    // Floor, and a 7 m block whose edge the mannequin walks off.
    const ledge = 700.0;
    world.persistentLevel.registerActor(LuminaPrimitiveActor(
        location: Vector3(0, -10, 0), shape: LuminaPrimitiveShape.box, size: Vector3(4000, 20, 4000), color: Vector3(0.5, 0.52, 0.5)));
    world.persistentLevel.registerActor(LuminaPrimitiveActor(
        location: Vector3(-300, ledge / 2, 0), shape: LuminaPrimitiveShape.box, size: Vector3(400, ledge, 400), color: Vector3(0.62, 0.5, 0.4)));
    world.persistentLevel.registerActor(LuminaActor(
        root: LuminaDirectionalLightComponent(rotation: LuminaAxes.rotation([-55, 0, 40]), intensity: 100000, castShadows: true)));

    // The mannequin with an idle, two get-up clips and a flail pose.
    var glb = mannyWithGetUps();
    final sampler0 = LuminaGlbAnimationSampler.fromGlb(glb);
    final pelvis = sampler0.indexOfNode('pelvis');
    final rest = sampler0.rest.sublist(pelvis * 10, pelvis * 10 + 10).toList();
    glb = GlbAuthoredClipWriter.write(
            meshGlb: glb,
            clip: AuthoredAnimationClip(name: 'Idle', frameRate: 30, lengthFrames: 30)
              ..setKey('pelvis', AuthoredChannel.rotation, 0, rest.sublist(3, 7))
              ..setKey('pelvis', AuthoredChannel.rotation, 30, rest.sublist(3, 7)))
        .glb;
    final meshFile = File('${dir.path}/manny_ragdoll.glb')..writeAsBytesSync(glb);
    final sampler = LuminaGlbAnimationSampler.fromGlb(glb);

    final capsule = LuminaCapsuleComponent(location: Vector3(-380, ledge + 90, 0), radius: 35, halfHeight: 90)
      ..objectType = CollisionObjectType.pawn;
    final character = LuminaActor(root: capsule);
    final movement = LuminaCharacterMovementComponent()..maxWalkSpeed = 250;
    character.addComponent(movement);
    final mesh = LuminaAnimatedMeshComponent(meshAssetPath: meshFile.path)
      ..relativeLocation = Vector3(0, -90, 0)
      // The mannequin faces glb +Z; the walk goes along world +X.
      ..relativeRotation = Quaternion.axisAngle(Vector3(0, 1, 0), math.pi / 2);
    mesh.attachToComponent(capsule);
    character.addComponent(mesh);
    final ragdoll = LuminaRagdollComponent(
      mesh: mesh,
      getUpClips: const ['GetUp_Front', 'GetUp_Back'],
      flailClip: 'Flail',
      ragdollFallSpeed: 1000,
      getUpBlendIn: 0.35,
    )..setUp(sampler, LuminaPhysicsAssetGenerator.fromSampler(sampler));
    character.addComponent(ragdoll);
    world.persistentLevel.registerActor(character);
    world.beginPlay();
    await mesh.loaded.timeout(const Duration(seconds: 60));
    mesh.play('Idle');

    final focus = Vector3(-380, ledge, 0);
    Uint8List shot() {
      final target = capsule.worldLocation;
      focus.add((target - focus) * 0.12);
      camera.lookAt(
          eyeX: focus.x + 120, eyeY: focus.y + 180, eyeZ: focus.z + 640, centerX: focus.x, centerY: focus.y, centerZ: focus.z);
      for (var i = 0; i < 2; i++) {
        if (renderer.beginFrame(swapChain)) {
          renderer.render(view);
          if (i == 1) {
            c.filament_renderer_read_pixels(renderer.nativePointer, engine.nativePointer, 0, 0, w, h, pixels.cast(), ffi.nullptr, ffi.nullptr);
          }
          renderer.endFrame();
        }
        engine.flushAndWait();
      }
      return Uint8List.fromList(pixels.asTypedList(w * h * 4));
    }

    final usedAssets = ['mannequin/SKM_Manny_Simple.glb'];
    final video = SmokeVideoRecorder(width: w, height: h, fps: 30, testName: testTitle);
    addTearDown(video.discard);
    final saved = <String>{};
    void save(String name, Map<String, Object?> metrics) {
      if (!saved.add(name)) return;
      SmokeArtifacts.saveScreenshot('$testTitle $name', SmokeArtifacts.encodePng(w, h, shot()), usedAssets: usedAssets, metrics: metrics);
    }

    double? limpAt, limpHeight, settledAt, gotUpAt;
    String? clip;
    ragdoll.onGetUpStarted = (name) => clip = name;
    var maxStepUs = 0, stepUsSum = 0, stepFrames = 0;
    var worstJoint = 0.0;
    final frames = 14 * 60;
    for (var f = 0; f < frames; f++) {
      final t = f / 60;
      if (ragdoll.state == LuminaRagdollState.animated && limpAt == null) movement.addInputVector(Vector3(1, 0, 0));
      final watch = Stopwatch()..start();
      world.tick(1 / 60);
      watch.stop();
      if (ragdoll.isRagdoll) {
        stepUsSum += watch.elapsedMicroseconds;
        stepFrames++;
        maxStepUs = math.max(maxStepUs, watch.elapsedMicroseconds);
        worstJoint = math.max(worstJoint, ragdoll.ragdoll!.maxJointError);
      }
      if (limpAt == null && ragdoll.isRagdoll) {
        limpAt = t;
        limpHeight = ragdoll.ragdoll!.root.boneFrame().position.y;
      }
      if (settledAt == null && ragdoll.state == LuminaRagdollState.gettingUp) settledAt = t;
      if (gotUpAt == null && settledAt != null && ragdoll.state == LuminaRagdollState.animated) gotUpAt = t;
      if (f.isEven) video.addFrame(shot());
      if (f == 30) save('01 on the ledge', {'capsuleY': capsule.worldLocation.y});
      if (limpAt != null && t > limpAt + 0.15) save('02 limp in the air', {'pelvisY': limpHeight, 'limpAt': limpAt});
      if (limpAt != null && t > limpAt + 1.4 && ragdoll.isRagdoll) save('03 on the ground', {'jointError': worstJoint});
      if (settledAt != null && t > settledAt + 0.4 && ragdoll.state == LuminaRagdollState.gettingUp) {
        save('04 getting up', {'clip': clip});
      }
      if (gotUpAt != null && t > gotUpAt + 0.5) save('05 standing again', {'capsuleY': capsule.worldLocation.y});
    }
    final metrics = <String, Object?>{
      'limpAtSeconds': limpAt,
      'limpPelvisHeightCm': limpHeight,
      'getUpStartedSeconds': settledAt,
      'standingSeconds': gotUpAt,
      'getUpClip': clip,
      'ragdollFrameMeanMs': stepFrames == 0 ? null : stepUsSum / stepFrames / 1000,
      'ragdollFrameMaxMs': maxStepUs / 1000,
      'worstJointErrorCm': worstJoint,
      'bodies': physics.bodies.length,
    };
    // ignore: avoid_print
    print('ragdoll smoke: $metrics');
    expect(limpAt, isNotNull, reason: 'went limp');
    expect(limpHeight!, greaterThan(100), reason: 'in the air');
    expect(settledAt, isNotNull, reason: 'settled and started getting up');
    expect(gotUpAt, isNotNull, reason: 'stood up again');
    expect(movement.movementMode, MovementMode.walking);
    expect(capsule.worldLocation.y - 90, closeTo(0, 6), reason: 'the capsule stands on the floor');
    expect(worstJoint, lessThan(3.0));
    SmokeArtifacts.saveVideo(testTitle, video.finish(), usedAssets: usedAssets);
    SmokeArtifacts.saveScreenshot('$testTitle 06 metrics', SmokeArtifacts.encodePng(w, h, shot()), usedAssets: usedAssets, metrics: metrics);
  }, timeout: const Timeout(Duration(minutes: 10)));
}
