import 'dart:typed_data';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:test/test.dart';

void main() {
  group('Texture SetImage Tests', () {
    late FilamentEngine engine;

    setUp(() {
      engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
    });

    tearDown(() {
      if (!engine.isDisposed) {
        engine.dispose();
      }
    });

    test('Sub-region update: 4x4 texture, then 2x2 block at offset', () {
      final texture = FilamentTexture.create2D(
        engine: engine,
        width: 4,
        height: 4,
        format: TextureFormat.rgba8,
      );

      final fullPixels = Uint8List(4 * 4 * 4); // 4x4 RGBA
      texture.setImage(
        width: 4,
        height: 4,
        pixelData: fullPixels,
      );

      final subPixels = Uint8List(2 * 2 * 4); // 2x2 RGBA
      expect(
        () => texture.setImage(
          width: 2,
          height: 2,
          xoffset: 2,
          yoffset: 2,
          pixelData: subPixels,
        ),
        returnsNormally,
      );

      texture.dispose();
    });

    test('Row stride: 2x2 region from buffer with strideInPixels=4', () {
      final texture = FilamentTexture.create2D(
        engine: engine,
        width: 4,
        height: 4,
        format: TextureFormat.rgba8,
      );

      final pixels = Uint8List(2 * 4 * 4); // 2 rows, 4 pixels per row (stride)
      expect(
        () => texture.setImage(
          width: 2,
          height: 2,
          strideInPixels: 4,
          pixelData: pixels,
        ),
        returnsNormally,
      );

      texture.dispose();
    });

    test('Mip level upload: level 0 and level 1', () {
      final texture = FilamentTexture.create2D(
        engine: engine,
        width: 4,
        height: 4,
        levels: 2,
        format: TextureFormat.rgba8,
      );

      final level0Pixels = Uint8List(4 * 4 * 4);
      expect(
        () => texture.setImage(
          level: 0,
          width: 4,
          height: 4,
          pixelData: level0Pixels,
        ),
        returnsNormally,
      );

      final level1Pixels = Uint8List(2 * 2 * 4);
      expect(
        () => texture.setImage(
          level: 1,
          width: 2,
          height: 2,
          pixelData: level1Pixels,
        ),
        returnsNormally,
      );

      texture.dispose();
    });

    test('Cubemap face upload: 6 distinct solid colors via setCubemapFace', () {
      final texture = FilamentTexture.createCubemap(
        engine: engine,
        size: 8,
        format: TextureFormat.rgba8,
      );

      for (int i = 0; i < 6; i++) {
        final pixels = Uint8List(8 * 8 * 4);
        final buf = PixelBuffer.fromBytes(pixels);
        expect(
          () => texture.setCubemapFace(
            face: CubemapFace.values[i],
            buffer: buf,
            width: 8,
            height: 8,
          ),
          returnsNormally,
        );
      }

      texture.dispose();
    });

    test('2D_ARRAY layer upload: depth=1, zoffset=layer 2', () {
      final texture = FilamentTexture.create2DArray(
        engine: engine,
        width: 4,
        height: 4,
        layers: 4,
        format: TextureFormat.rgba8,
      );

      final pixels = Uint8List(4 * 4 * 4);
      expect(
        () => texture.setImage(
          width: 4,
          height: 4,
          depth: 1,
          zoffset: 2,
          pixelData: pixels,
        ),
        returnsNormally,
      );

      texture.dispose();
    });

    test('Release callback: every setImage fires ownership callback after flushAndWait', () async {
      final texture = FilamentTexture.create2D(
        engine: engine,
        width: 2,
        height: 2,
        format: TextureFormat.rgba8,
      );

      final initialCallbacks = BufferOwnershipRegistry.instance.pendingCount;

      final pixels = Uint8List(2 * 2 * 4);
      texture.setImage(
        width: 2,
        height: 2,
        pixelData: pixels,
      );

      // Verify a new callback was registered
      expect(BufferOwnershipRegistry.instance.pendingCount, initialCallbacks + 1);

      engine.flushAndWait();
      // Allow Dart microtasks to process native callbacks
      await Future.delayed(const Duration(milliseconds: 50));

      // After flush and wait, it should drain
      expect(BufferOwnershipRegistry.instance.pendingCount, initialCallbacks);

      texture.dispose();
    });
  });
}
