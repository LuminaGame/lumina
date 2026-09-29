import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_filament/flutter_filament.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('IBLPrefilter EquirectangularToCubemap Tests', () {
    late FilamentEngine engine;

    setUpAll(() {
      engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
    });

    tearDownAll(() {
      engine.dispose();
    });

    test('Context creation and destruction', () {
      final ctx = IblPrefilterContext(engine);
      expect(() => ctx.destroy(), returnsNormally);
    });

    test('Repeated context and functor destruction in a loop', () {
      for (int i = 0; i < 10; i++) {
        final ctx = IblPrefilterContext(engine);
        final equirectToCube = EquirectangularToCubemap(ctx, mirror: true);
        equirectToCube.destroy();
        ctx.destroy();
      }
    });

    test('Synthetic equirect texture conversion to cubemap', () {
      final ctx = IblPrefilterContext(engine);
      final equirectToCube = EquirectangularToCubemap(ctx, mirror: true);

      // Create a 64x32 2D equirect texture with all mip levels (7 levels for 64x32: 64, 32, 16, 8, 4, 2, 1)
      final equirect = FilamentTexture.create2D(
        engine: engine,
        width: 64,
        height: 32,
        levels: 7,
        format: TextureFormat.rgba16f,
        usage: TextureUsage.sampleable |
            TextureUsage.uploadable |
            TextureUsage.colorAttachment |
            TextureUsage.genMipmappable,
      );

      // Populate level 0 with synthetic float16 data (64 * 32 * 4 * 2 bytes = 16384 bytes)
      final dummyPixels = Uint8List(64 * 32 * 8);
      equirect.setImage(
        width: 64,
        height: 32,
        level: 0,
        pixelData: dummyPixels,
        pixelFormat: PixelFormat.rgba,
        pixelType: PixelType.half,
      );

      final outCubemap = equirectToCube.run(equirect);
      expect(outCubemap, isNotNull);
      expect(outCubemap.isDisposed, isFalse);

      outCubemap.dispose();
      equirect.dispose();
      equirectToCube.destroy();
      ctx.destroy();
    });

    test('Pre-allocated outCubemap returns the same texture', () {
      final ctx = IblPrefilterContext(engine);
      final equirectToCube = EquirectangularToCubemap(ctx, mirror: false);

      final equirect = FilamentTexture.create2D(
        engine: engine,
        width: 64,
        height: 32,
        levels: 7,
        format: TextureFormat.rgba16f,
        usage: TextureUsage.sampleable |
            TextureUsage.uploadable |
            TextureUsage.colorAttachment |
            TextureUsage.genMipmappable,
      );

      final preAllocatedCube = FilamentTexture.createCubemap(
        engine: engine,
        size: 32,
        levels: 6,
        format: TextureFormat.rgba16f,
        usage: TextureUsage.sampleable |
            TextureUsage.uploadable |
            TextureUsage.colorAttachment |
            TextureUsage.genMipmappable,
      );

      final result = equirectToCube.run(equirect, outCubemap: preAllocatedCube);
      expect(result.nativePointer, equals(preAllocatedCube.nativePointer));

      preAllocatedCube.dispose();
      equirect.dispose();
      equirectToCube.destroy();
      ctx.destroy();
    });
  });
}
