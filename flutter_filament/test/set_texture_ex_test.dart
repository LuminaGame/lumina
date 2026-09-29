import 'dart:typed_data';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:test/test.dart';

void main() {
  group('MaterialInstance setTexture with TextureSampler (set_texture_ex)', () {
    late FilamentEngine engine;
    late FilamentMaterial material;

    setUp(() {
      engine = FilamentEngine.create(backend: FilamentBackend.noop)!;

      FilamentMaterialBuilder.initEngine();
      final builder = FilamentMaterialBuilder.create();
      builder.setName('UnlitTextureTest');
      builder.setShading(FilamatShading.unlit);
      builder.addSamplerParameter('albedo');
      builder.requireAttribute(3); // UV0
      builder.setCode('''
        void material(inout MaterialInputs material) {
          prepareMaterial(material);
          material.baseColor = texture(materialParams_albedo, getUV0());
        }
      ''');

      final filamatBytes = builder.build();
      builder.dispose();

      expect(filamatBytes, isNotNull);
      material = FilamentMaterial.fromBuffer(
        engine: engine,
        filamatBuffer: filamatBytes!,
      );
    });

    tearDown(() {
      material.dispose();
      FilamentMaterialBuilder.shutdownEngine();
      engine.dispose();
    });

    test('setTexture with custom TextureSampler (repeat, linear, trilinear)', () {
      final mi = material.createInstance();
      final texture = FilamentTexture.create2D(
        engine: engine,
        width: 16,
        height: 16,
        format: TextureFormat.rgba8,
      );

      final pixels = Uint8List(16 * 16 * 4);
      for (int i = 0; i < pixels.length; i += 4) {
        pixels[i] = 255;
        pixels[i + 1] = 0;
        pixels[i + 2] = 0;
        pixels[i + 3] = 255;
      }
      texture.setImage(
        width: 16,
        height: 16,
        pixelData: pixels,
        pixelFormat: PixelFormat.rgba,
        pixelType: PixelType.ubyte,
      );

      // Default sampler
      expect(() => mi.setTexture('albedo', texture), returnsNormally);

      // Trilinear repeating sampler
      expect(
        () => mi.setTexture(
          'albedo',
          texture,
          sampler: const TextureSampler.trilinear(wrap: SamplerWrapMode.repeat),
        ),
        returnsNormally,
      );

      // Clamped nearest sampler
      expect(
        () => mi.setTexture(
          'albedo',
          texture,
          sampler: const TextureSampler(
            filterMin: SamplerMinFilter.nearest,
            filterMag: SamplerMagFilter.nearest,
            wrapS: SamplerWrapMode.clampToEdge,
            wrapT: SamplerWrapMode.clampToEdge,
          ),
        ),
        returnsNormally,
      );

      // Raw pointer overload
      expect(
        () => mi.setTexture(
          'albedo',
          texture.nativePointer,
          sampler: const TextureSampler.trilinear(),
        ),
        returnsNormally,
      );

      texture.dispose();
      mi.dispose();
    });

    test('Multiple material instances with distinct samplers on same texture', () {
      final mi1 = material.createInstance();
      final mi2 = material.createInstance();

      final texture = FilamentTexture.create2D(
        engine: engine,
        width: 8,
        height: 8,
        format: TextureFormat.rgba8,
      );

      mi1.setTexture(
        'albedo',
        texture,
        sampler: const TextureSampler(wrapS: SamplerWrapMode.repeat),
      );

      mi2.setTexture(
        'albedo',
        texture,
        sampler: const TextureSampler(wrapS: SamplerWrapMode.clampToEdge),
      );

      texture.dispose();
      mi1.dispose();
      mi2.dispose();
    });
  });
}
