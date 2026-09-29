// ignore_for_file: avoid_print, unnecessary_non_null_assertion

import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_filament/src/third_party/filament_c.g.dart' as c;
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Simulate continuous render loop with mannequin drop, selection box, gizmo and readPixels', () async {
    final lmasFile = File(Platform.environment['LUMINA_MANNY_LMAS'] ?? '');
    Uint8List? rawBytes;
    String assetName = 'mannequin/SKM_Manny_Simple.glb';

    if (lmasFile.existsSync()) {
      final mesh = await AssetRepository.loadMeshFromDisk(lmasFile.path);
      rawBytes = mesh?.rawPayload;
    } else {
      final fallbackGlb = File('${SmokeArtifacts.testAssetsDir.path}/mannequin/SKM_Manny_Simple.glb');
      if (fallbackGlb.existsSync()) {
        rawBytes = fallbackGlb.readAsBytesSync();
      }
    }

    if (rawBytes == null) {
      print('SKM_Manny_Simple not found on disk.');
      return;
    }

    final engine = FilamentEngine.create(backend: FilamentBackend.defaultBackend);
    expect(engine, isNotNull);

    final scene = engine!.createScene();
    final view = engine.createView();
    final cameraEntity = engine.createEntity();
    final camera = engine.createCamera(cameraEntity);
    final renderer = engine.createRenderer();
    const w = 800;
    const h = 600;
    final swapChain = engine.createHeadlessSwapChain(w, h);

    view.scene = scene;
    view.camera = camera;
    view.setViewport(0, 0, w, h);

    camera.lookAt(
      eyeX: 0.0,
      eyeY: 1.5,
      eyeZ: 3.0,
      centerX: 0.0,
      centerY: 0.9,
      centerZ: 0.0,
    );

    final lightManager = FilamentLightManager(engine);
    final sunEntity = engine.createEntity();
    lightManager.createLight(
      entity: sunEntity,
      type: LightType.sun,
      colorR: 1.0,
      colorG: 0.98,
      colorB: 0.92,
      intensity: 110000.0,
      dirX: -0.6,
      dirY: -1.0,
      dirZ: -0.8,
      castShadows: true,
    );
    scene.addEntity(sunEntity);

    final grid = FilamentEditorGrid.create(engine: engine, extent: 2000.0, step: 50.0);
    grid.addToScene(scene);

    final selectionBox = FilamentSelectionBox(engine);
    final gizmo = FilamentTransformGizmo(engine);

    final materialProvider = FilamentMaterialProvider.createJitShader(engine: engine);
    final assetLoader = FilamentAssetLoader.create(engine: engine, materialProvider: materialProvider!);
    final resourceLoader = FilamentResourceLoader.create(engine: engine, normalizeSkinningWeights: true);

    final pixelBuffer = calloc<ffi.Uint8>(w * h * 4);

    // Frame loop before drop (5 frames)
    var preRendered = 0;
    for (var attempt = 0; attempt < 50 && preRendered < 5; attempt++) {
      sleep(const Duration(milliseconds: 16));
      if (renderer.beginFrame(swapChain)) {
        preRendered++;
        renderer.render(view);
        renderer.endFrame();
        engine.flushAndWait();
      }
    }

    print('Frames before drop completed. Now dropping mannequin...');

    // Drop mannequin (simulate _syncActorAssets)
    final asset = assetLoader!.createAsset(rawBytes);
    expect(asset, isNotNull);
    engine.flushAndWait();
    resourceLoader!.loadResources(asset!);
    engine.flushAndWait();
    asset.animator.updateBoneMatrices();
    asset.addToScene(scene);
    engine.flushAndWait();

    final aabb = asset.getBoundingBox();

    // Update SelectionBox and Gizmo
    selectionBox.updateBounds(
      scene: scene,
      minBounds: [aabb.min.x, aabb.min.y, aabb.min.z],
      maxBounds: [aabb.max.x, aabb.max.y, aabb.max.z],
      baseScale: 1.0,
    );
    selectionBox.addToScene(scene);
    gizmo.addToScene(scene);
    engine.flushAndWait();

    print('Mannequin added. Now rendering frames with readPixels...');

    // Frame loop after drop (5 frames)
    var postRendered = 0;
    for (var attempt = 0; attempt < 50 && postRendered < 5; attempt++) {
      sleep(const Duration(milliseconds: 16));
      if (renderer.beginFrame(swapChain)) {
        postRendered++;
        renderer.render(view);
        if (postRendered == 5) {
          c.filament_renderer_read_pixels(
            renderer.nativePointer,
            engine.nativePointer,
            0,
            0,
            w,
            h,
            pixelBuffer.cast(),
            ffi.nullptr,
            ffi.nullptr,
          );
        }
        renderer.endFrame();
        engine.flushAndWait();
      }
    }

    final framePixels = Uint8List.fromList(pixelBuffer.asTypedList(w * h * 4));
    final pngBytes = SmokeArtifacts.encodeRgbaToPng(framePixels, w, h);
    SmokeArtifacts.saveScreenshot(
      'mannequin: drop selection gizmo test',
      pngBytes,
      usedAssets: [assetName],
    );

    print('Post-drop frames rendered successfully!');

    calloc.free(pixelBuffer);
    asset.removeFromScene(scene);
    asset.dispose();
    selectionBox.dispose();
    gizmo.dispose();
    grid.dispose();
    resourceLoader.dispose();
    assetLoader.dispose();
    materialProvider.dispose();
    renderer.dispose();
    view.dispose();
    scene.dispose();
    camera.dispose();
    engine.destroyEntity(cameraEntity);
    engine.destroyEntity(sunEntity);
    swapChain.dispose();
    engine.dispose();
  });
}

