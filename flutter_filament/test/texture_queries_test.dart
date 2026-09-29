import 'dart:typed_data';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:test/test.dart';

void main() {
  group('Texture Queries and generateMipmaps Tests', () {
    late FilamentEngine engine;

    setUp(() {
      engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
    });

    tearDown(() {
      if (!engine.isDisposed) {
        engine.dispose();
      }
    });

    test('Geometry getters on 8x8 RGBA8 with levels=4', () {
      final tex = FilamentTexture.create2D(
        engine: engine,
        width: 8,
        height: 8,
        format: TextureFormat.rgba8,
        levels: 4,
      );

      expect(tex.levels, equals(4));
      expect(tex.width(level: 0), equals(8));
      expect(tex.height(level: 0), equals(8));
      expect(tex.depth(level: 0), equals(1));

      expect(tex.width(level: 1), equals(4));
      expect(tex.height(level: 1), equals(4));

      expect(tex.width(level: 2), equals(2));
      expect(tex.height(level: 2), equals(2));

      expect(tex.width(level: 3), equals(1));
      expect(tex.height(level: 3), equals(1));

      expect(tex.target, equals(TextureSamplerType.sampler2d));
      expect(tex.format, equals(TextureFormat.rgba8));

      tex.dispose();
    });

    test('generateMipmaps execution on mipmapped texture', () {
      final tex = FilamentTexture.create2D(
        engine: engine,
        width: 8,
        height: 8,
        format: TextureFormat.rgba8,
        levels: 4,
        usage: TextureUsage.uploadable | TextureUsage.sampleable | TextureUsage.genMipmappable,
      );

      final pixels = Uint8List(8 * 8 * 4);
      tex.setImage(
        width: 8,
        height: 8,
        buffer: PixelBuffer.fromBytes(pixels),
      );

      tex.generateMipmaps(engine);
      engine.flushAndWait();

      tex.dispose();
    });

    test('generateMipmaps on levels=1 is a safe no-op', () {
      final tex = FilamentTexture.create2D(
        engine: engine,
        width: 8,
        height: 8,
        format: TextureFormat.rgba8,
        levels: 1,
      );

      tex.generateMipmaps(engine);
      tex.generateMipmaps(engine);

      tex.dispose();
    });

    test('Static format queries: isFormatSupported and isFormatMipmappable', () {
      expect(FilamentTexture.isFormatSupported(engine, TextureFormat.rgba8), isTrue);
      expect(FilamentTexture.isFormatMipmappable(engine, TextureFormat.rgba8), isTrue);
    });

    test('Static format queries: isFormatCompressed', () {
      expect(FilamentTexture.isFormatCompressed(TextureFormat.rgba8), isFalse);
      expect(FilamentTexture.isFormatCompressed(TextureFormat.r8), isFalse);
      expect(FilamentTexture.isFormatCompressed(TextureFormat.etc2Rgb8), isTrue);
      expect(FilamentTexture.isFormatCompressed(TextureFormat.dxt1Rgb), isTrue);
      expect(FilamentTexture.isFormatCompressed(TextureFormat.rgbaAstc4x4), isTrue);
    });

    test('Static computeDataSize query matches exact row and pixel math', () {
      // 4x4 RGBA UBYTE tightly packed = 4 * 4 * 4 = 64 bytes
      final size = FilamentTexture.computeDataSize(
        format: PixelFormat.rgba,
        type: PixelType.ubyte,
        strideInPixels: 4,
        height: 4,
        alignment: 1,
      );
      expect(size, equals(64));
    });

    test('Static capability queries: maxSize and maxArrayLayers', () {
      expect(FilamentTexture.maxSize(engine, TextureSamplerType.sampler2d), greaterThanOrEqualTo(2048));
      expect(FilamentTexture.maxArrayLayers(engine), greaterThanOrEqualTo(64));
    });
  });
}
