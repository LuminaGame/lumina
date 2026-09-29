import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_filament/src/third_party/filament_c.g.dart' as c;
import 'package:lumina/data/services/glb_parser_service.dart';
import 'package:lumina_ui/testing.dart';

import '../helpers/cc_body_asset.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Verify CCMH_Body_Female renders with textures and materials on GPU',
    () async {
      // Found portably; skipped with the reason when absent.
      final body = CcBodyAsset.resolve(CcBodyAsset.female);
      if (body.file == null) return markTestSkipped(body.skipReason!);
      final originalFile = body.file!;

      final rawBytes = originalFile.readAsBytesSync();
      // Sanitize with GlbParserService (strips dummy COLOR_0, embeds PNG textures)
      final sanitizedGlb = GlbParserService.convertGlbTgaToPng(rawBytes);

      final engine = FilamentEngine.create(
        backend: FilamentBackend.defaultBackend,
      );
      expect(engine, isNotNull);

      final scene = engine!.createScene();
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
        near: 0.1,
        far: 100.0,
      );

      camera.lookAt(
        eyeX: 0.0,
        eyeY: 0.9,
        eyeZ: 2.2,
        centerX: 0.0,
        centerY: 0.8,
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
        castShadows: false,
      );
      scene.addEntity(keyEntity);

      final materialProvider = FilamentMaterialProvider.createJitShader(
        engine: engine,
      );
      final assetLoader = FilamentAssetLoader.create(
        engine: engine,
        materialProvider: materialProvider,
      );
      final resourceLoader = FilamentResourceLoader.create(
        engine: engine,
        normalizeSkinningWeights: true,
      );
      // Crucial: register default texture providers!
      resourceLoader.registerDefaultProviders(engine);

      final asset = assetLoader.createAsset(sanitizedGlb);
      expect(asset, isNotNull);
      final loadOk = resourceLoader.loadResources(asset!);
      expect(loadOk, isTrue);

      asset.addToScene(scene);

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

      final framePixels = Uint8List.fromList(
        pixelBuffer.asTypedList(w * h * 4),
      );
      final outDir = Directory('${Directory.current.parent.path}/build/smoke');
      if (!outDir.existsSync()) outDir.createSync(recursive: true);
      final pngBytes = SmokeArtifacts.encodeRgbaToPng(framePixels, w, h);
      File('${outDir.path}/ccmh_fixed.png').writeAsBytesSync(pngBytes);

      // Count textured skin-tone foreground pixels (RGB brightness > 30)
      int coloredPixels = 0;
      for (int i = 0; i < framePixels.length; i += 4) {
        final r = framePixels[i];
        final g = framePixels[i + 1];
        final b = framePixels[i + 2];
        if (r > 30 || g > 30 || b > 30) {
          coloredPixels++;
        }
      }

      printOnFailure('CCMH Rendered textured/colored pixels: $coloredPixels / ${w * h}');
      expect(
        coloredPixels,
        greaterThan(3000),
        reason:
            'Character mesh should render with full skin textures rather than pitch black',
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
    },
  );
}
