// ignore_for_file: avoid_print, unnecessary_non_null_assertion

import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_filament/src/third_party/filament_c.g.dart' as c;
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Load and render SKM_Manny_Simple into FilamentEngine without crash', () async {
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
    final w = 640;
    final h = 360;
    final swapChain = engine.createHeadlessSwapChain(w, h);

    view.scene = scene;
    view.camera = camera;
    view.setViewport(0, 0, w, h);

    camera.lookAt(
      eyeX: 0.0,
      eyeY: 1.2,
      eyeZ: 2.5,
      centerX: 0.0,
      centerY: 0.9,
      centerZ: 0.0,
    );

    final lightManager = FilamentLightManager(engine);
    final keyEntity = engine.createEntity();
    lightManager.createLight(
      entity: keyEntity,
      type: LightType.directional,
      colorR: 1.0,
      colorG: 0.98,
      colorB: 0.95,
      intensity: 90000.0,
      dirX: -0.4,
      dirY: -0.6,
      dirZ: -0.7,
      castShadows: true,
    );
    scene.addEntity(keyEntity);

    final materialProvider = FilamentMaterialProvider.createJitShader(engine: engine);
    expect(materialProvider, isNotNull);

    final assetLoader = FilamentAssetLoader.create(engine: engine, materialProvider: materialProvider!);
    expect(assetLoader, isNotNull);

    final resourceLoader = FilamentResourceLoader.create(engine: engine, normalizeSkinningWeights: true);
    expect(resourceLoader, isNotNull);

    final asset = assetLoader!.createAsset(rawBytes);
    expect(asset, isNotNull);

    final loaded = resourceLoader!.loadResources(asset!);
    expect(loaded, isTrue);

    asset.addToScene(scene);

    final pixelBuffer = calloc<ffi.Uint8>(w * h * 4);

    var rendered = 0;
    for (var attempt = 0; attempt < 50 && rendered < 5; attempt++) {
      sleep(const Duration(milliseconds: 16));
      if (renderer.beginFrame(swapChain)) {
        rendered++;
        renderer.render(view);
        if (rendered == 5) {
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
      'manny: load and render skm manny simple',
      pngBytes,
      usedAssets: [assetName],
    );

    calloc.free(pixelBuffer);

    asset.removeFromScene(scene);
    asset.dispose();
    resourceLoader.dispose();
    assetLoader.dispose();
    materialProvider.dispose();
    renderer.dispose();
    view.dispose();
    scene.dispose();
    camera.dispose();
    engine.destroyEntity(cameraEntity);
    engine.destroyEntity(keyEntity);
    swapChain.dispose();
    engine.dispose();
  });
}

