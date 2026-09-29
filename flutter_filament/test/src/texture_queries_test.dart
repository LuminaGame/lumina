import 'package:flutter_filament/flutter_filament.dart';
import 'package:test/test.dart';

void main() {
  group('Texture Queries and Mipmaps Tests', () {
    late FilamentEngine engine;

    setUp(() {
      engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
    });

    tearDown(() {
      if (!engine.isDisposed) {
        engine.dispose();
      }
    });

    test('Mip level properties: width, target, format, levels', () {
      final texture = FilamentTexture.create2D(
        engine: engine,
        width: 8,
        height: 8,
        levels: 4,
        format: TextureFormat.rgba8,
      );

      expect(texture.levels, 4);
      expect(texture.width(level: 0), 8);
      expect(texture.width(level: 1), 4);
      expect(texture.width(level: 3), 1);
      expect(texture.target, TextureSamplerType.sampler2d);
      expect(texture.format, TextureFormat.rgba8);

      texture.dispose();
    });

    test('generateMipmaps is safe on levels=1 and twice in a row', () {
      final texture = FilamentTexture.create2D(
        engine: engine,
        width: 8,
        height: 8,
        levels: 1,
        format: TextureFormat.rgba8,
      );

      // levels=1 is a no-op
      expect(() => texture.generateMipmaps(engine), returnsNormally);

      final textureMip = FilamentTexture.create2D(
        engine: engine,
        width: 8,
        height: 8,
        levels: 4,
        format: TextureFormat.rgba8,
        usage: TextureUsage.genMipmappable | TextureUsage.uploadable | TextureUsage.sampleable,
      );

      // Twice in a row should be safe
      expect(() => textureMip.generateMipmaps(engine), returnsNormally);
      expect(() => textureMip.generateMipmaps(engine), returnsNormally);

      texture.dispose();
      textureMip.dispose();
    });

    test('isFormatSupported and isFormatCompressed', () {
      expect(FilamentTexture.isFormatSupported(engine, TextureFormat.rgba8), isTrue);
      
      expect(FilamentTexture.isFormatCompressed(TextureFormat.rgba8), isFalse);
      expect(FilamentTexture.isFormatCompressed(TextureFormat.etc2Rgb8), isTrue);
      expect(FilamentTexture.isFormatCompressed(TextureFormat.dxt1Rgba), isTrue);
    });

    test('computeDataSize reflects stride and alignment', () {
      // 4 pixels wide * 4 bytes per pixel = 16 bytes per row
      // 16 bytes per row * 4 height = 64 bytes
      final tightSize = FilamentTexture.computeDataSize(
        format: PixelFormat.rgba,
        type: PixelType.ubyte,
        strideInPixels: 4, // 4 wide
        height: 4,
        alignment: 1,
      );
      expect(tightSize, 64);

      // 3 pixels wide = 12 bytes per row.
      // Alignment 4 means row padding is not needed (12 is multiple of 4).
      // Wait, 3 width, 4 alignment, RGB format (3 bytes) -> 3*3 = 9 bytes. 
      // 9 bytes aligned to 4 -> 12 bytes per row.
      // 12 bytes per row * 4 height = 48 bytes.
      final paddedSize = FilamentTexture.computeDataSize(
        format: PixelFormat.rgb,
        type: PixelType.ubyte,
        strideInPixels: 3,
        height: 4,
        alignment: 4,
      );
      expect(paddedSize, 48);
    });

    test('maxSize and maxArrayLayers limits', () {
      expect(FilamentTexture.maxSize(engine, TextureSamplerType.sampler2d), greaterThanOrEqualTo(2048));
      expect(FilamentTexture.maxArrayLayers(engine), greaterThanOrEqualTo(64));
    });

    test('isFormatMipmappable capabilities', () {
      expect(FilamentTexture.isFormatMipmappable(engine, TextureFormat.rgba8), isTrue);
      // Depending on backend, depth32f might be mipmappable. It reports true here.
      expect(FilamentTexture.isFormatMipmappable(engine, TextureFormat.depth32f), isTrue);
    });
  });
}
