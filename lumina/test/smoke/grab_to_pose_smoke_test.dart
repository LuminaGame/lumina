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

/// The mannequin posed by a mouse grabber (synthesized cursor and button,
/// never the OS mouse): it hovers the right hand (highlighted), drags it up,
/// pulls the left elbow out, turns the head left, steps the right foot
/// forward, lets go each time (the pose stays), then undoes the last grab.
void main() {
  test('Animation Smoke Scenario: a mouse grabber hovers, grabs and drags pose handles; the pose stays and undo restores', () async {
    const testTitle = 'Animation Smoke Scenario: a mouse grabber hovers, grabs and drags pose handles; the pose stays and undo restores';
    final assets = SmokeArtifacts.testAssetsDir.path;
    final manny = File('$assets/mannequin/SKM_Manny_Simple.glb');
    if (!manny.existsSync()) return markTestSkipped('test-assets missing mannequin/SKM_Manny_Simple.glb');
    const w = 1280, h = 800;
    const fov = 40.0;
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
    camera.setProjection(fovDegrees: fov, aspect: w / h, near: 10, far: 100000, direction: FovDirection.vertical);
    scene.setSkybox(FilamentSkybox.build(engine, color: Vector4(0.36, 0.4, 0.48, 1), intensity: 30000));
    scene.setIndirectLight(FilamentIndirectLight.build(engine,
        irradiance: SphericalHarmonics(bands: 1, coefficients: [0.7, 0.68, 0.66]), intensity: 30000));
    final pixels = calloc<ffi.Uint8>(w * h * 4);
    final world = LuminaWorld(worldType: LuminaWorldType.game)..initializeNativeContext(engine, scene);
    addTearDown(() {
      world.cleanup();
      calloc.free(pixels);
      engine.dispose();
    });
    world.bindView(view);

    // A room: floor, back and side walls, a table.
    for (final (at, size, color) in [
      (Vector3(0, -10, 0), Vector3(900, 20, 900), Vector3(0.46, 0.44, 0.4)),
      (Vector3(0, 200, -320), Vector3(900, 420, 20), Vector3(0.62, 0.6, 0.56)),
      (Vector3(-330, 200, 0), Vector3(20, 420, 900), Vector3(0.55, 0.58, 0.6)),
      (Vector3(-150, 37, -120), Vector3(90, 74, 60), Vector3(0.42, 0.3, 0.22)),
    ]) {
      world.persistentLevel.registerActor(LuminaPrimitiveActor(location: at, shape: LuminaPrimitiveShape.box, size: size, color: color));
    }
    world.persistentLevel.registerActor(LuminaActor(
        root: LuminaDirectionalLightComponent(rotation: LuminaAxes.rotation([-55, 0, 30]), intensity: 90000, castShadows: true)));
    world.persistentLevel.registerActor(LuminaActor(root: LuminaPointLightComponent(location: Vector3(60, 260, 120), intensity: 60000)));
    final props = [
      ('Props/Barrels/fuel_barrel_yellow.glb', Vector3(130, 0, -110), 1.0),
      ('Props/Barrels/empty_barrel.glb', Vector3(200, 0, -40), 1.0),
      ('Props/Access_cards/access_card_blue.glb', Vector3(-165, 75, -115), 3.0),
      ('Props/Access_cards/access_card_red.glb', Vector3(-130, 75, -125), 3.0),
    ];
    final propMeshes = <LuminaStaticMeshComponent>[];
    for (final (path, at, scale) in props) {
      final mesh = LuminaStaticMeshComponent(meshAssetPath: '$assets/$path', location: at, scale: Vector3.all(scale));
      propMeshes.add(mesh);
      world.persistentLevel.registerActor(LuminaActor(root: mesh));
    }

    final mesh = LuminaAnimatedMeshComponent(meshAssetPath: manny.path);
    final character = LuminaActor(root: mesh);
    final poser = LuminaPoseAuthoringComponent(mesh: mesh);
    character.addComponent(poser);
    world.persistentLevel.registerActor(character);

    // The player: a grab interactor driven by a mouse grabber whose cursor
    // and button this test sets (no OS input).
    // The camera stands 3.7 m away: the mouse ray reaches further than the
    // 3 m a hand-held controller's does.
    final interactor = LuminaPoseGrabInteractor(idleAlpha: 0.35, rayMaxDistance: 1000);
    final player = LuminaActor(root: LuminaSceneComponent());
    player.addComponent(interactor);
    world.persistentLevel.registerActor(player);
    final mouse = LuminaMouseGrabber();
    interactor.registerGrabber(mouse);
    final events = <String>[];
    interactor
      ..onHandleGrabbed = ((hdl, g) => events.add('grab ${hdl.handle}'))
      ..onHandleReleased = ((hdl, g) => events.add('release ${hdl.handle}'))
      ..onHandleHovered = ((hdl, g) => events.add('hover ${hdl?.handle}'));

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

    // The camera, for the render and for the mouse.
    final eye = Vector3(150, 160, 330), center = Vector3(0, 100, 0);
    final look = (center - eye).normalized();
    final right = look.cross(Vector3(0, 1, 0)).normalized();
    final up = right.cross(look);
    mouse
      ..fovYDegrees = fov
      ..viewportSize.setValues(w.toDouble(), h.toDouble())
      ..cameraLocation.setFrom(eye)
      ..cameraRotation.setFrom(Quaternion.fromRotation(Matrix3.columns(right, up, -look))..normalize());
    final tanHalf = math.tan(fov * math.pi / 360);
    Vector2 pixelOf(Vector3 p) {
      final d = p - eye;
      final z = d.dot(look);
      return Vector2((d.dot(right) / (z * tanHalf * w / h) + 1) * w / 2, (1 - d.dot(up) / (z * tanHalf)) * h / 2);
    }

    Uint8List shot() {
      camera.lookAt(eyeX: eye.x, eyeY: eye.y, eyeZ: eye.z, centerX: center.x, centerY: center.y, centerZ: center.z);
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
    final start = {for (final n in poser.handles.keys) n: poser.handleWorldLocation(n)!};
    double ease(double t) => t <= 0 ? 0 : (t >= 1 ? 1 : t * t * (3 - 2 * t));

    // Each grab: hover [from] to [handle], press, drag to [to] (world), let go.
    final grabs = [
      (handle: 'hand_r', at: 0.8, to: start['hand_r']! + Vector3(-12, 42, 10), wheel: 0.0),
      (handle: 'elbow_l', at: 3.4, to: start['elbow_l']! + Vector3(40, 16, -10), wheel: 0.0),
      (handle: 'head', at: 6.0, to: start['head']! + Vector3(24, -3, -6), wheel: 0.0),
      (handle: 'foot_r', at: 8.6, to: start['foot_r']! + Vector3(-12, 16, 26), wheel: 2.5),
    ];
    const approach = 0.6, pressAt = 0.9, dragFor = 1.4, releaseAt = 2.45;

    final video = SmokeVideoRecorder(width: w, height: h, fps: 30, testName: testTitle);
    addTearDown(video.discard);
    final saved = <String>{};
    final metrics = <String, Object?>{};
    void save(String name, [Map<String, Object?> m = const {}]) {
      if (!saved.add(name)) return;
      SmokeArtifacts.saveScreenshot('$testTitle $name', SmokeArtifacts.encodePng(w, h, shot()), usedAssets: usedAssets, metrics: m);
    }

    Vector3? footBeforeUndo, footAfterGrab;
    const seconds = 13.5;
    final frames = (seconds * 60).round();
    var cursor = Vector2(w * 0.85, h * 0.2);
    for (var f = 0; f < frames; f++) {
      final t = f / 60;
      for (final g in grabs) {
        final local = t - g.at;
        if (local < 0 || local > releaseAt + 0.1) continue;
        final over = pixelOf(start[g.handle]!);
        if (local < approach) {
          cursor = cursor + (over - cursor) * 0.12;
          if (local > approach - 0.1) cursor = over.clone();
        } else if (local < pressAt) {
          cursor = over.clone();
        } else if (local < pressAt + dragFor) {
          mouse.leftDown = true;
          final k = ease((local - pressAt) / dragFor);
          cursor = over + (pixelOf(g.to) - over) * k;
          if (g.wheel != 0) mouse.wheel(g.wheel / (dragFor * 60));
        } else if (local >= releaseAt) {
          mouse.leftDown = false;
        }
      }
      mouse.cursor.setFrom(cursor);
      if (f == (11.6 * 60).round()) {
        footBeforeUndo = poser.handleWorldLocation('foot_r');
        metrics['undo'] = interactor.undoLastGrab();
      }
      world.tick(1 / 60);
      if (f.isEven) video.addFrame(shot());
      if (f == ((0.8 + pressAt - 0.05) * 60).round()) save('01 hovering the right hand', {'hovered': interactor.hoveredBy(mouse)?.handle});
      if (f == ((0.8 + releaseAt + 0.3) * 60).round()) {
        metrics['handRaisedCm'] = poser.handleWorldLocation('hand_r')!.y - start['hand_r']!.y;
        save('02 right hand dragged up and let go', {'handRaisedCm': metrics['handRaisedCm']});
      }
      if (f == ((3.4 + pressAt + 0.7) * 60).round()) save('03 dragging the left elbow out', {'held': interactor.heldBy(mouse)?.handle});
      if (f == ((6.0 + releaseAt + 0.3) * 60).round()) save('04 head turned left', {});
      if (f == ((8.6 + releaseAt + 0.1) * 60).round()) {
        footAfterGrab = poser.handleWorldLocation('foot_r');
        save('05 right foot stepped forward', {'footMovedCm': footAfterGrab!.distanceTo(start['foot_r']!)});
      }
      if (f == (12.4 * 60).round()) {
        metrics['footAfterUndoCm'] = poser.handleWorldLocation('foot_r')!.distanceTo(start['foot_r']!);
        save('06 last grab undone', {'footFromStartCm': metrics['footAfterUndoCm']});
      }
    }
    metrics['events'] = events.join(', ');
    metrics['handStillRaisedCm'] = poser.handleWorldLocation('hand_r')!.y - start['hand_r']!.y;
    // ignore: avoid_print
    print('grab to pose smoke: $metrics');
    expect(events.where((e) => e.startsWith('grab ')).toList(), ['grab hand_r', 'grab elbow_l', 'grab head', 'grab foot_r']);
    expect(events.where((e) => e.startsWith('release ')), hasLength(4));
    expect(events, contains('hover hand_r'));
    expect(metrics['handRaisedCm'] as double, greaterThan(15));
    expect(metrics['handStillRaisedCm'] as double, closeTo(metrics['handRaisedCm'] as double, 0.05), reason: 'the pose stays');
    expect(footBeforeUndo!.distanceTo(start['foot_r']!), greaterThan(10));
    expect(metrics['footAfterUndoCm'] as double, lessThan(0.05), reason: 'undo restores the targets before the foot grab');
    SmokeArtifacts.saveVideo(testTitle, video.finish(), usedAssets: usedAssets);
    SmokeArtifacts.saveScreenshot('$testTitle 07 metrics', SmokeArtifacts.encodePng(w, h, shot()), usedAssets: usedAssets, metrics: metrics);
  }, timeout: const Timeout(Duration(minutes: 10)));
}
