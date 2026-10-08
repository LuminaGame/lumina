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

import '../support/morph_glb.dart';

/// Two soft blobs ride on barrels that hop; the left one has springs driving
/// its morph targets (it squashes on landing and wobbles back), the right
/// one has none (it stays rigid).
void main() {
  test('Skeletal Mesh Smoke Scenario 05: spring-driven morph targets jiggle a soft blob on a hopping barrel', () async {
    const testTitle = 'Skeletal Mesh Smoke Scenario 05: spring-driven morph targets jiggle a soft blob on a hopping barrel';
    const barrels = ['Props/Barrels/fuel_barrel_red.glb', 'Props/Barrels/dented_barrel.glb'];
    for (final b in barrels) {
      if (!File('${SmokeArtifacts.testAssetsDir.path}/$b').existsSync()) return markTestSkipped('test-assets missing $b');
    }
    const w = SmokeVideo.defaultWidth;
    const h = SmokeVideo.defaultHeight;
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
    scene.setSkybox(FilamentSkybox.build(engine, color: Vector4(0.42, 0.55, 0.78, 1), intensity: 30000));
    scene.setIndirectLight(FilamentIndirectLight.build(engine,
        irradiance: SphericalHarmonics(bands: 1, coefficients: [0.65, 0.65, 0.7]), intensity: 30000));
    final pixels = calloc<ffi.Uint8>(w * h * 4);
    final dir = Directory.systemTemp.createTempSync('spring_smoke_');
    final world = LuminaWorld(worldType: LuminaWorldType.game)..initializeNativeContext(engine, scene);
    addTearDown(() {
      world.cleanup();
      calloc.free(pixels);
      engine.dispose();
      dir.deleteSync(recursive: true);
    });
    world.bindView(view);
    world.persistentLevel.registerActor(LuminaPrimitiveActor(
        location: Vector3(0, -10, 0), shape: LuminaPrimitiveShape.box, size: Vector3(2400, 20, 2400), color: Vector3(0.52, 0.5, 0.47)));
    world.persistentLevel.registerActor(LuminaActor(
        root: LuminaDirectionalLightComponent(rotation: LuminaAxes.rotation([-50, 0, 30]), intensity: 100000, castShadows: true)));

    final jellyRed = writeJellyGlb(dir, name: 'jelly_red.glb');
    final jellyBlue = writeJellyGlb(dir, color: const [0.25, 0.45, 0.9, 1], name: 'jelly_blue.glb');
    final barrelPaths = [for (final b in barrels) '${SmokeArtifacts.testAssetsDir.path}/$b'];
    for (final p in barrelPaths) {
      SmokeArtifacts.recordAsset(p);
    }

    // Each column: a barrel, and a blob that sits on top of it.
    final barrelActors = <LuminaActor>[];
    final blobs = <LuminaAnimatedMeshComponent>[];
    LuminaSpringMorphComponent? springs;
    for (var i = 0; i < 2; i++) {
      final x = i == 0 ? -90.0 : 90.0;
      final barrel = LuminaActor(root: LuminaStaticMeshComponent(meshAssetPath: barrelPaths[i], location: Vector3(x, 0, 0)));
      final blob = LuminaAnimatedMeshComponent(meshAssetPath: (i == 0 ? jellyRed : jellyBlue).path);
      final actor = LuminaActor(root: blob);
      if (i == 0) {
        springs = LuminaSpringMorphComponent(springs: [
          LuminaMorphSpring(
            name: 'blob',
            offset: Vector3(0, 45, 0),
            frequency: 2.6,
            damping: 0.12,
            range: 15,
            limit: 15,
            morphs: const {'+y': 'Up', '-y': 'Down', '+x': 'Right', '-x': 'Left', '+z': 'Forward', '-z': 'Back'},
          ),
        ]);
        actor.addComponent(springs);
      }
      world.persistentLevel.registerActor(barrel);
      world.persistentLevel.registerActor(actor);
      barrelActors.add(barrel);
      blobs.add(blob);
    }
    world.beginPlay();
    await Future.wait([
      for (final m in world.persistentLevel.actors.expand((a) => a.components).whereType<LuminaStaticMeshComponent>()) m.loaded,
    ]).timeout(const Duration(seconds: 120));
    // The barrels' height, read from their bounds, puts the blobs on top.
    final tops = <double>[];
    for (final b in barrelActors) {
      final mesh = b.rootComponent as LuminaStaticMeshComponent;
      final box = mesh.localBounds;
      tops.add(box == null ? 90.0 : box.max.y);
    }

    Uint8List shot() {
      camera.lookAt(eyeX: 60, eyeY: 170, eyeZ: 520, centerX: 0, centerY: 95, centerZ: 0);
      for (var i = 0; i < 3; i++) {
        if (renderer.beginFrame(swapChain)) {
          renderer.render(view);
          if (i == 2) {
            c.filament_renderer_read_pixels(renderer.nativePointer, engine.nativePointer, 0, 0, w, h, pixels.cast(), ffi.nullptr, ffi.nullptr);
          }
          renderer.endFrame();
        }
        engine.flushAndWait();
      }
      return Uint8List.fromList(pixels.asTypedList(w * h * 4));
    }

    // Hops of 60 cm every 1.5 s, sliding sideways on the second half.
    const jumpSpeed = 343.0, gravity = 980.0, airTime = 2 * jumpSpeed / gravity;
    double heightAt(double t) {
      final phase = t % 1.5;
      return phase < airTime ? jumpSpeed * phase - 0.5 * gravity * phase * phase : 0.0;
    }

    final usedAssets = [...barrels];
    final video = SmokeVideoRecorder(width: w, height: h, fps: 30, testName: testTitle);
    addTearDown(video.discard);
    var largestDown = 0.0, largestUp = 0.0;
    const ticks = 11 * 60;
    for (var tick = 0; tick < ticks; tick++) {
      final t = tick / 60;
      final y = heightAt(t);
      final slide = t > 5.5 ? math.sin((t - 5.5) * 2.4) * 40 : 0.0;
      for (var i = 0; i < 2; i++) {
        final x = (i == 0 ? -90.0 : 90.0) + slide;
        barrelActors[i].rootComponent.relativeLocation = Vector3(x, y, 0);
        blobs[i].relativeLocation = Vector3(x, y + tops[i], 0);
      }
      world.tick(1 / 60);
      largestDown = math.max(largestDown, blobs[0].getMorphTarget('Down'));
      largestUp = math.max(largestUp, blobs[0].getMorphTarget('Up'));
      expect(blobs[1].hasMorphTarget('Down'), isTrue);
      expect(blobs[1].getMorphTarget('Down'), 0, reason: 'the blob without springs stays rigid');
      if (tick.isEven) video.addFrame(shot());
      // Just after a landing: the blob squashes.
      if (tick == 46) {
        SmokeArtifacts.saveScreenshot('$testTitle 01 landing squash', SmokeArtifacts.encodePng(w, h, shot()),
            usedAssets: usedAssets, metrics: {'down': blobs[0].getMorphTarget('Down'), 'up': blobs[0].getMorphTarget('Up')});
      }
    }
    expect(largestDown, greaterThan(0.3), reason: 'the red blob lags down at take-off and squashes on landing');
    expect(largestUp, greaterThan(0.1), reason: 'and bounces back up');
    expect(springs!.offsetOf('blob'), isNotNull);
    SmokeArtifacts.saveScreenshot('$testTitle 02 end', SmokeArtifacts.encodePng(w, h, shot()), usedAssets: usedAssets);
    SmokeArtifacts.saveVideo(testTitle, video.finish(), usedAssets: usedAssets);
  }, timeout: const Timeout(Duration(minutes: 8)));
}
