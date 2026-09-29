import 'dart:typed_data';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:test/test.dart';

void main() {
  group('Texture Smoke Tests', () {
    late FilamentEngine engine;

    setUp(() {
      engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
    });

    tearDown(() {
      engine.dispose();
    });

    test('Texture factories and properties', () {
      final texture2D = FilamentTexture.create2D(
        engine: engine,
        width: 128,
        height: 64,
        format: TextureFormat.rgba8,
        levels: 1,
        usage: 0,
      );
      
      expect(texture2D.width(), 128);
      expect(texture2D.height(), 64);
      expect(texture2D.depth(), 1);
      expect(texture2D.levels, 1);
      expect(texture2D.target, TextureSamplerType.sampler2d);
      expect(texture2D.format, TextureFormat.rgba8);
      
      texture2D.dispose();
      
      final textureCubemap = FilamentTexture.createCubemap(
        engine: engine,
        size: 256,
        format: TextureFormat.r16f,
        levels: 2,
      );
      
      expect(textureCubemap.width(), 256);
      expect(textureCubemap.height(), 256);
      expect(textureCubemap.depth(), 1);
      expect(textureCubemap.levels, 2);
      expect(textureCubemap.target, TextureSamplerType.samplerCubemap);
      expect(textureCubemap.format, TextureFormat.r16f);
      
      textureCubemap.dispose();
    });

    test('Texture setImage and generateMipmaps', () {
      final texture = FilamentTexture.create2D(
        engine: engine,
        width: 4,
        height: 4,
        format: TextureFormat.rgba8,
        levels: 3,
        usage: TextureUsage.defaultUsage | TextureUsage.genMipmappable,
      );

      final pixels = Uint8List(4 * 4 * 4);
      for (var i = 0; i < pixels.length; i++) {
        pixels[i] = 255;
      }
      
      // Test setImage
      texture.setImage(
        pixelData: pixels,
        width: 4,
        height: 4,
        pixelFormat: PixelFormat.rgba,
        pixelType: PixelType.ubyte,
      );
      
      // Test mipmaps
      texture.generateMipmaps(engine);
      
      // Pump queues to make sure async commands are handled
      engine.flushAndWait();
      engine.pumpMessageQueues();
      
      expect(texture.width(level: 0), 4);
      expect(texture.height(level: 0), 4);
      
      texture.dispose();
    });

    test('TextureSampler parameter fidelity', () {
      // Default sampler
      const defaultSampler = TextureSampler();
      expect(defaultSampler.filterMin, SamplerMinFilter.nearest);
      expect(defaultSampler.filterMag, SamplerMagFilter.nearest);
      expect(defaultSampler.wrapS, SamplerWrapMode.clampToEdge);
      expect(defaultSampler.wrapT, SamplerWrapMode.clampToEdge);
      expect(defaultSampler.wrapR, SamplerWrapMode.clampToEdge);
      expect(defaultSampler.anisotropyLog2, 0);
      expect(defaultSampler.compareMode, SamplerCompareMode.none);
      expect(defaultSampler.compareFunc, SamplerCompareFunc.le);
      
      // Custom sampler (e.g. trilinear shortcut)
      const trilinear = TextureSampler.trilinear(wrap: SamplerWrapMode.repeat, anisotropy: 8.0);
      expect(trilinear.filterMin, SamplerMinFilter.linearMipmapLinear);
      expect(trilinear.filterMag, SamplerMagFilter.linear);
      expect(trilinear.wrapS, SamplerWrapMode.repeat);
      expect(trilinear.wrapT, SamplerWrapMode.repeat);
      expect(trilinear.wrapR, SamplerWrapMode.repeat);
      expect(trilinear.anisotropyLog2, 3);
      expect(trilinear.compareMode, SamplerCompareMode.none);
      
      // Test packed value equality and hash code
      const sameAsTrilinear = TextureSampler(
        filterMin: SamplerMinFilter.linearMipmapLinear,
        filterMag: SamplerMagFilter.linear,
        wrapS: SamplerWrapMode.repeat,
        wrapT: SamplerWrapMode.repeat,
        wrapR: SamplerWrapMode.repeat,
        anisotropy: 8.0,
      );
      
      expect(trilinear.packed, sameAsTrilinear.packed);
      expect(trilinear == sameAsTrilinear, isTrue);
      expect(trilinear.hashCode, sameAsTrilinear.hashCode);
      
      // Compare shortcut
      const compareSampler = TextureSampler.compare(SamplerCompareFunc.ge);
      expect(compareSampler.compareMode, SamplerCompareMode.compareToTexture);
      expect(compareSampler.compareFunc, SamplerCompareFunc.ge);
    });
  });
}
