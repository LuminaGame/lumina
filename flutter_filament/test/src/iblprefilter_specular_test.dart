import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_filament/flutter_filament.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('IBLPrefilter Specular & Irradiance Filter Tests', () {
    late FilamentEngine engine;
    late IblPrefilterContext ctx;
    late FilamentTexture equirectTex;
    late FilamentTexture envCubemap;

    setUpAll(() {
      engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
      ctx = IblPrefilterContext(engine);

      // Create a 64x32 2D equirect texture with 7 mip levels
      equirectTex = FilamentTexture.create2D(
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

      final dummyPixels = Uint8List(64 * 32 * 8);
      equirectTex.setImage(
        width: 64,
        height: 32,
        level: 0,
        pixelData: dummyPixels,
        pixelFormat: PixelFormat.rgba,
        pixelType: PixelType.half,
      );

      final equirectToCube = EquirectangularToCubemap(ctx, mirror: true);
      envCubemap = equirectToCube.run(equirectTex);
      equirectToCube.destroy();
    });

    tearDownAll(() {
      envCubemap.dispose();
      equirectTex.dispose();
      ctx.destroy();
      engine.dispose();
    });

    test('Option defaults match Filament exactly', () {
      const specOpt = SpecularFilterOptions();
      expect(specOpt.hdrLinear, equals(1024.0));
      expect(specOpt.hdrMax, equals(16384.0));
      expect(specOpt.lodOffset, equals(1.0));
      expect(specOpt.generateMipmap, isTrue);

      const irradOpt = IrradianceFilterOptions();
      expect(irradOpt.hdrLinear, equals(1024.0));
      expect(irradOpt.hdrMax, equals(16384.0));
      expect(irradOpt.lodOffset, equals(2.0));
      expect(irradOpt.generateMipmap, isTrue);
    });

    test('sampleCount > 2048 throws ArgumentError in Dart', () {
      expect(
        () => SpecularFilter(ctx, SpecularFilterConfig(sampleCount: 2049)),
        throwsArgumentError,
      );
      expect(
        () => IrradianceFilter(ctx, IrradianceFilterConfig(sampleCount: 4096)),
        throwsArgumentError,
      );
    });

    test('End-to-end SpecularFilter.run returns non-null reflection texture', () {
      final specFilter = SpecularFilter(
        ctx,
        SpecularFilterConfig(
          sampleCount: 64,
          levelCount: 5,
        ),
      );

      final reflections = specFilter.run(envCubemap);
      expect(reflections, isNotNull);
      expect(reflections.isDisposed, isFalse);

      reflections.dispose();
      specFilter.destroy();
    });

    test('Pre-allocated outReflections is used in place', () {
      final specFilter = SpecularFilter(
        ctx,
        SpecularFilterConfig(
          sampleCount: 64,
          levelCount: 5,
        ),
      );

      final preAlloc = FilamentTexture.createCubemap(
        engine: engine,
        size: 256,
        levels: 5,
        format: TextureFormat.r11fG11fB10f,
        usage: TextureUsage.sampleable | TextureUsage.colorAttachment,
      );

      final result = specFilter.run(envCubemap, outReflections: preAlloc);
      expect(result.nativePointer, equals(preAlloc.nativePointer));

      preAlloc.dispose();
      specFilter.destroy();
    });

    test('IrradianceFilter.run returns non-null irradiance cubemap', () {
      final irradFilter = IrradianceFilter(
        ctx,
        IrradianceFilterConfig(sampleCount: 64),
      );

      final irradiance = irradFilter.run(envCubemap);
      expect(irradiance, isNotNull);
      expect(irradiance.isDisposed, isFalse);

      irradiance.dispose();
      irradFilter.destroy();
    });

    test('Reusing SpecularFilter instance for multiple consecutive runs', () {
      final specFilter = SpecularFilter(
        ctx,
        SpecularFilterConfig(
          sampleCount: 32,
          levelCount: 5,
        ),
      );

      for (int i = 0; i < 3; i++) {
        final reflections = specFilter.run(envCubemap);
        expect(reflections, isNotNull);
        reflections.dispose();
      }

      specFilter.destroy();
    });
  });
}
