import 'dart:typed_data';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_filament/src/third_party/filament_c.g.dart' as c;
import 'package:test/test.dart';

void main() {
  group('Texture Builder Expansion Tests', () {
    late FilamentEngine engine;

    setUp(() {
      engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
    });

    tearDown(() {
      if (!engine.isDisposed) {
        engine.dispose();
      }
    });

    test('Enum fidelity: TextureFormat (109 formats)', () {
      for (final format in TextureFormat.values) {
        final cVal = c.filament_enum_internal_format(format.value);
        expect(cVal, equals(format.value),
            reason: 'Mismatch for TextureFormat.${format.name}');
      }
    });

    test('Enum fidelity: TextureSamplerType', () {
      for (final sampler in TextureSamplerType.values) {
        final cVal = c.filament_enum_sampler_type(sampler.value);
        expect(cVal, equals(sampler.value),
            reason: 'Mismatch for TextureSamplerType.${sampler.name}');
      }
    });

    test('Enum fidelity: TextureSwizzle', () {
      for (final swizzle in TextureSwizzle.values) {
        final cVal = c.filament_enum_texture_swizzle(swizzle.value);
        expect(cVal, equals(swizzle.value),
            reason: 'Mismatch for TextureSwizzle.${swizzle.name}');
      }
    });

    test('2D RGBA8 16x16 levels=1 creation and setImage upload', () {
      final tex = FilamentTexture.create2D(
        engine: engine,
        width: 16,
        height: 16,
        format: TextureFormat.rgba8,
        levels: 1,
      );
      expect(tex.isDisposed, isFalse);

      final pixels = Uint8List(16 * 16 * 4);
      tex.setImage(
        level: 0,
        pixelData: pixels,
        width: 16,
        height: 16,
        pixelFormat: PixelFormat.rgba,
        pixelType: PixelType.ubyte,
      );

      tex.dispose();
      expect(tex.isDisposed, isTrue);
    });

    test('2D RGBA8 16x16 levels=5 mip chain creation and destroy', () {
      final tex = FilamentTexture.create2D(
        engine: engine,
        width: 16,
        height: 16,
        format: TextureFormat.rgba8,
        levels: 5,
      );
      expect(tex.isDisposed, isFalse);
      tex.dispose();
      expect(tex.isDisposed, isTrue);
    });

    test('CUBEMAP 8x8 creation and destroy', () {
      final cubeTex = FilamentTexture.createCubemap(
        engine: engine,
        size: 8,
        format: TextureFormat.rgba8,
        levels: 1,
      );
      expect(cubeTex.isDisposed, isFalse);
      cubeTex.dispose();
      expect(cubeTex.isDisposed, isTrue);
    });

    test('2D_ARRAY 8x8 depth=4 and 3D 8x8x8 creation and destroy', () {
      final arrayTex = FilamentTexture.create2DArray(
        engine: engine,
        width: 8,
        height: 8,
        layers: 4,
        format: TextureFormat.rgba8,
        levels: 1,
      );
      expect(arrayTex.isDisposed, isFalse);
      arrayTex.dispose();
      expect(arrayTex.isDisposed, isTrue);

      final tex3d = FilamentTexture.create3D(
        engine: engine,
        width: 8,
        height: 8,
        depth: 8,
        format: TextureFormat.rgba8,
        levels: 1,
      );
      expect(tex3d.isDisposed, isFalse);
      tex3d.dispose();
      expect(tex3d.isDisposed, isTrue);
    });

    test('usage = colorAttachment | sampleable creation', () {
      final colorAttachmentTex = FilamentTexture.create(
        engine: engine,
        desc: const TextureDescriptor(
          width: 64,
          height: 64,
          format: TextureFormat.rgba8,
          usage: TextureUsage.colorAttachment | TextureUsage.sampleable,
        ),
      );
      expect(colorAttachmentTex.isDisposed, isFalse);
      colorAttachmentTex.dispose();
      expect(colorAttachmentTex.isDisposed, isTrue);
    });

    test('usage = depthAttachment with TextureFormat.depth32f', () {
      final depthTex = FilamentTexture.create(
        engine: engine,
        desc: const TextureDescriptor(
          width: 64,
          height: 64,
          format: TextureFormat.depth32f,
          usage: TextureUsage.depthAttachment | TextureUsage.sampleable,
        ),
      );
      expect(depthTex.isDisposed, isFalse);
      depthTex.dispose();
      expect(depthTex.isDisposed, isTrue);
    });

    test('Swizzle: create an R8 texture with swizzle (r, r, r, one)', () {
      final swizzledTex = FilamentTexture.create(
        engine: engine,
        desc: const TextureDescriptor(
          width: 16,
          height: 16,
          format: TextureFormat.r8,
          swizzle: [
            TextureSwizzle.channel0,
            TextureSwizzle.channel0,
            TextureSwizzle.channel0,
            TextureSwizzle.substituteOne,
          ],
        ),
      );
      expect(swizzledTex.isDisposed, isFalse);
      swizzledTex.dispose();
      expect(swizzledTex.isDisposed, isTrue);
    });
  });
}
