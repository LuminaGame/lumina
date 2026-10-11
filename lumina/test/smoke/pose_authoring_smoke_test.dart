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

/// The test-assets mannequin posed through pose authoring handles alone (no
/// clip): the right hand raised, the left elbow out, a look around, a chest
/// bend, a step with the right foot, a crouch on planted feet; then the pose
/// is captured, reset and applied again.
void main() {
  test('Animation Smoke Scenario: pose authoring handles pose the mannequin, and a captured pose is restored', () async {
    const testTitle = 'Animation Smoke Scenario: pose authoring handles pose the mannequin, and a captured pose is restored';
    final assets = SmokeArtifacts.testAssetsDir.path;
    final manny = File('$assets/mannequin/SKM_Manny_Simple.glb');
    if (!manny.existsSync()) return markTestSkipped('test-assets missing mannequin/SKM_Manny_Simple.glb');
    const w = 1280, h = 800;
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
    camera.setProjection(fovDegrees: 40, aspect: w / h, near: 10, far: 100000, direction: FovDirection.vertical);
    scene.setSkybox(FilamentSkybox.build(engine, color: Vector4(0.42, 0.52, 0.66, 1), intensity: 30000));
    scene.setIndirectLight(FilamentIndirectLight.build(engine,
        irradiance: SphericalHarmonics(bands: 1, coefficients: [0.75, 0.75, 0.8]), intensity: 32000));
    final pixels = calloc<ffi.Uint8>(w * h * 4);
    final world = LuminaWorld(worldType: LuminaWorldType.game)..initializeNativeContext(engine, scene);
    addTearDown(() {
      world.cleanup();
      calloc.free(pixels);
      engine.dispose();
    });
    world.bindView(view);

    world.persistentLevel.registerActor(LuminaPrimitiveActor(
        location: Vector3(0, -10, 0), shape: LuminaPrimitiveShape.box, size: Vector3(1600, 20, 1600), color: Vector3(0.5, 0.5, 0.48)));
    world.persistentLevel.registerActor(LuminaActor(
        root: LuminaDirectionalLightComponent(rotation: LuminaAxes.rotation([-50, 0, 35]), intensity: 100000, castShadows: true)));
    const props = [
      ('Props/Barrels/fuel_barrel_red.glb', -110.0, -40.0),
      ('Props/Barrels/dented_barrel.glb', 120.0, -70.0),
      ('Props/AC_units/roof_aircon_unit_150x150_a.glb', 20.0, -210.0),
    ];
    final propMeshes = <LuminaStaticMeshComponent>[];
    for (final (path, x, z) in props) {
      final mesh = LuminaStaticMeshComponent(meshAssetPath: '$assets/$path', location: Vector3(x, 0, z));
      propMeshes.add(mesh);
      world.persistentLevel.registerActor(LuminaActor(root: mesh));
    }

    final mesh = LuminaAnimatedMeshComponent(meshAssetPath: manny.path);
    final character = LuminaActor(root: mesh);
    final poser = LuminaPoseAuthoringComponent(mesh: mesh);
    character.addComponent(poser);
    world.persistentLevel.registerActor(character);
    world.beginPlay();
    await mesh.loaded.timeout(const Duration(seconds: 60));
    for (final p in propMeshes) {
      await p.loaded.timeout(const Duration(seconds: 60));
    }
    await poser.ready.timeout(const Duration(seconds: 60));
    final usedAssets = ['mannequin/SKM_Manny_Simple.glb', for (final p in props) p.$1];
    for (final a in usedAssets) {
      SmokeArtifacts.recordAsset('$assets/$a');
    }

    Uint8List shot() {
      camera.lookAt(eyeX: 170, eyeY: 150, eyeZ: 360, centerX: 0, centerY: 95, centerZ: 0);
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

    world.tick(1 / 60);
    Vector3 at(String handle) => poser.handleWorldLocation(handle)!;
    final start = {for (final hdl in poser.handles.keys) hdl: at(hdl)};
    double ease(double t) => t <= 0 ? 0 : (t >= 1 ? 1 : t * t * (3 - 2 * t));
    Vector3 lerp(Vector3 a, Vector3 b, double t) => a + (b - a) * ease(t);

    final video = SmokeVideoRecorder(width: w, height: h, fps: 30, testName: testTitle);
    addTearDown(video.discard);
    final solveUs = <int>[];
    final saved = <String>{};
    void save(String name, Map<String, Object?> metrics) {
      if (!saved.add(name)) return;
      SmokeArtifacts.saveScreenshot('$testTitle $name', SmokeArtifacts.encodePng(w, h, shot()), usedAssets: usedAssets, metrics: metrics);
    }

    // Targets, from the rest pose (mannequin faces +Z, its left is +X).
    final handUp = start['hand_r']! + Vector3(-8, 42, 22);
    final elbowOut = start['elbow_l']! + Vector3(30, 15, -10);
    final chestBend = start['chest']! + Vector3(0, -6, 18);
    final stepForward = start['foot_r']! + Vector3(0, 15, 30);
    AuthoredPose? captured;
    final measured = <String, double>{};
    const seconds = 14.0;
    final frames = (seconds * 60).round();
    for (var f = 0; f < frames; f++) {
      final t = f / 60;
      if (t >= 1 && t < 3) poser.setHandleTarget('hand_r', lerp(start['hand_r']!, handUp, (t - 1) / 1.6));
      if (t >= 3 && t < 4.5) poser.setHandleTarget('elbow_l', lerp(start['elbow_l']!, elbowOut, (t - 3) / 1.2));
      if (t >= 4.5 && t < 6.5) {
        // Around the neck (the chest handle sits at its base).
        final yaw = math.sin((t - 4.5) / 2 * 2 * math.pi) * 0.9;
        final pitch = math.sin((t - 4.5) / 2 * 4 * math.pi) * 0.25;
        final d = start['head']! - start['chest']!;
        final turned = LuminaPoseQuat.qRotate(
            LuminaPoseQuat.qMul(Quaternion.axisAngle(Vector3(0, 1, 0), yaw), Quaternion.axisAngle(Vector3(1, 0, 0), pitch)), d);
        poser.setHandleTarget('head', start['chest']! + turned);
      }
      if (t >= 6.5 && t < 8) poser.setHandleTarget('chest', lerp(start['chest']!, chestBend, (t - 6.5) / 1.2));
      if (t >= 8 && t < 9.5) {
        final k = ease((t - 8) / 1.2);
        poser.setHandleTarget('foot_r', lerp(start['foot_r']!, stepForward, k) + Vector3(0, math.sin(k * math.pi) * 18, 0));
      }
      if (t >= 9.5 && t < 11) {
        if (!poser.handles['foot_l']!.hasTarget) poser.setHandleTarget('foot_l', at('foot_l'));
        poser.setHandleTarget('pelvis', lerp(start['pelvis']!, start['pelvis']! - Vector3(0, 28, -4), (t - 9.5) / 1.2));
      }
      if (f == (11 * 60)) {
        captured = poser.toAuthoredPose('Smoke');
        measured['plantedFootRDriftCm'] = at('foot_r').distanceTo(stepForward);
        poser.resetToReference();
      }
      if (f == (11.6 * 60).round()) poser.applyAuthoredPose(captured!, blendSeconds: 1.2);

      world.tick(1 / 60);
      if (poser.handles.values.any((h) => h.hasTarget)) solveUs.add(poser.lastSolveMicros);
      if (f.isEven) video.addFrame(shot());
      if (f == 3 * 60 - 1) {
        measured['handRDriftCm'] = at('hand_r').distanceTo(handUp);
        save('01 right hand raised', {'handToTargetCm': measured['handRDriftCm']});
      }
      if (f == (4.5 * 60).round() - 1) save('02 left elbow out', {'elbowToHandleCm': at('elbow_l').distanceTo(elbowOut)});
      if (f == (5 * 60)) save('03 looking around', {});
      if (f == 8 * 60 - 1) save('04 chest bent', {'chestToTargetCm': at('chest').distanceTo(chestBend)});
      if (f == (9.5 * 60).round() - 1) {
        measured['footRDriftCm'] = at('foot_r').distanceTo(stepForward);
        save('05 right foot stepped', {'footToTargetCm': measured['footRDriftCm']});
      }
      if (f == 11 * 60 - 1) save('06 crouched on planted feet', {'pelvisDropCm': start['pelvis']!.y - at('pelvis').y});
      if (f == (11.3 * 60).round()) save('07 reset to the reference pose', {});
      if (f == frames - 1) save('08 captured pose applied again', {});
    }
    solveUs.sort();
    final warm = solveUs.skip(math.min(30, solveUs.length ~/ 4)).toList();
    final mean = warm.isEmpty ? 0.0 : warm.reduce((a, b) => a + b) / warm.length / 1000;
    final metrics = <String, Object?>{
      'solveFrames': solveUs.length,
      'solveMeanMs': mean,
      'solveMedianMs': warm.isEmpty ? 0.0 : warm[warm.length ~/ 2] / 1000,
      'solveP95Ms': warm.isEmpty ? 0.0 : warm[(warm.length * 0.95).floor().clamp(0, warm.length - 1)] / 1000,
      'solveMaxMs': solveUs.isEmpty ? 0.0 : solveUs.last / 1000,
      'rigSlots': poser.rig!.length,
      ...measured,
    };
    // ignore: avoid_print
    print('pose authoring smoke: $metrics');
    expect(measured['handRDriftCm']!, lessThan(0.5));
    expect(measured['footRDriftCm']!, lessThan(0.5));
    expect(measured['plantedFootRDriftCm']!, lessThan(0.5), reason: 'the stepped foot stays planted through the crouch');
    // The re-applied pose matches the captured one.
    final now = poser.toAuthoredPose('Now');
    for (final e in captured!.bones.entries) {
      final q = now.bones[e.key]!.r;
      final d = (q.x * e.value.r.x + q.y * e.value.r.y + q.z * e.value.r.z + q.w * e.value.r.w).abs();
      expect(1 - d, lessThan(1e-6), reason: e.key);
    }
    // The in-frame numbers share the CPU with rendering, frame reads and
    // their garbage collections; the budget (0.2 ms per character per frame)
    // is checked on the solve alone: every handle of the rig held, 1200
    // frames back to back.
    for (final name in poser.handles.keys) {
      poser.setHandleTarget(name, at(name) + Vector3(0, 2, 1));
    }
    final pose = poser.rig!.restPoseCopy();
    final isolated = Stopwatch();
    for (var i = 0; i < 1500; i++) {
      if (i == 300) isolated.start();
      poser.modifyPose(pose, mesh.renderTransform, 1 / 60);
    }
    isolated.stop();
    final allHandlesMs = isolated.elapsedMicroseconds / 1200 / 1000;
    metrics['solveAllHandlesMs'] = allHandlesMs;
    // ignore: avoid_print
    print('pose authoring smoke, all ${poser.handles.length} handles held: $allHandlesMs ms per solve');
    expect(allHandlesMs, lessThan(0.2), reason: 'solve cost per character per frame on desktop');
    SmokeArtifacts.saveVideo(testTitle, video.finish(), usedAssets: usedAssets);
    SmokeArtifacts.saveScreenshot('$testTitle 09 metrics', SmokeArtifacts.encodePng(w, h, shot()), usedAssets: usedAssets, metrics: metrics);
  }, timeout: const Timeout(Duration(minutes: 10)));
}
