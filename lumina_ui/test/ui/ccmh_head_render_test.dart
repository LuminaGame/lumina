import 'dart:convert';
import 'dart:ffi' as ffi;

import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_filament/src/third_party/filament_c.g.dart' as c;
import 'package:lumina/lumina.dart';
import 'package:lumina/data/services/glb_parser_service.dart';
import 'package:lumina_ui/testing.dart';


void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Render CCMH_Head_Female to check visual distortion', () async {
    File? modelFile;
    final candidates = [
      '/tmp/ccmh_head_4bone_normalized.glb',
      '/tmp/lumina_test_openLevelCWGGTB/TestProj/contents/meshes/skeletal/CCMH_Head_Female.entity.glb',
      '${Directory.current.parent.path}/test-assets/Characters/CCMH_Head_Female.glb',
    ];
    for (final path in candidates) {
      final f = File(path);
      if (f.existsSync()) {
        modelFile = f;
        break;
      }
    }
    if (modelFile == null) {
      return;
    }

    final rawBytes = GlbParserService.convertGlbTgaToPng(modelFile.readAsBytesSync());


    final engine = FilamentEngine.create(backend: FilamentBackend.defaultBackend)!;
    final scene = engine.createScene();
    final view = engine.createView();
    final cameraEntity = engine.createEntity();
    final camera = engine.createCamera(cameraEntity);
    final renderer = engine.createRenderer();
    const w = 512;
    const h = 512;
    final swapChain = engine.createHeadlessSwapChain(w, h);

    view.scene = scene;
    view.camera = camera;
    view.setViewport(0, 0, w, h);

    camera.setProjection(
      fovDegrees: 45,
      aspect: w / h,
      near: 0.05,
      far: 100.0,
    );

    // Look at head (Y ~ 1.5)
    camera.lookAt(
      eyeX: 0.0,
      eyeY: 1.5,
      eyeZ: 0.6,
      centerX: 0.0,
      centerY: 1.5,
      centerZ: 0.0,
    );

    final lightManager = FilamentLightManager(engine);
    final keyEntity = engine.createEntity();
    lightManager.createLight(
      entity: keyEntity,
      type: LightType.directional,
      colorR: 1.0,
      colorG: 1.0,
      colorB: 1.0,
      intensity: 100000.0,
      dirX: 0.0,
      dirY: -0.5,
      dirZ: -1.0,
      castShadows: false,
    );
    scene.addEntity(keyEntity);

    final materialProvider = FilamentMaterialProvider.createJitShader(engine: engine)!;
    final assetLoader = FilamentAssetLoader.create(engine: engine, materialProvider: materialProvider)!;
    final resourceLoader = FilamentResourceLoader.create(engine: engine, normalizeSkinningWeights: true)!;
    resourceLoader.registerDefaultProviders(engine);

    final asset = assetLoader.createAsset(rawBytes)!;
    resourceLoader.loadResources(asset);

    final rm = FilamentRenderableManager(engine);
    expect(rm.getMorphTargetCount(6), equals(27));
    expect(asset.getMorphTargetNameAt(6, 13), equals('mod_mouth_size'));

    asset.animator.updateBoneMatrices();
    asset.addToScene(scene);

    // Set morph target weights
    final weights = Float32List(27);
    weights[12] = 1.0; // mod_mouth_height
    weights[13] = 1.0; // mod_mouth_size
    weights[17] = 1.0; // mod_nose_size
    rm.setMorphWeights(6, weights);
    engine.flushAndWait();

    final pixelBuffer = calloc<ffi.Uint8>(w * h * 4);
    var rendered = 0;
    for (var attempt = 0; attempt < 30 && rendered < 5; attempt++) {
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
    final outDir = Directory('${Directory.current.parent.path}/build/smoke');
    if (!outDir.existsSync()) outDir.createSync(recursive: true);
    final pngBytes = SmokeArtifacts.encodeRgbaToPng(framePixels, w, h);
    File('${outDir.path}/head_morphed.png').writeAsBytesSync(pngBytes);
    print('Saved ${outDir.path}/head_morphed.png');

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
