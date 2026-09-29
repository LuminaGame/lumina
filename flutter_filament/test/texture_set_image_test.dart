import 'dart:typed_data';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_filament/src/third_party/filament_c.g.dart' as c;
import 'package:test/test.dart';

void main() {
  group('Full setImage & PixelBuffer Tests', () {
    late FilamentEngine engine;

    setUp(() {
      engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
    });

    tearDown(() {
      if (!engine.isDisposed) {
        engine.dispose();
      }
    });

    test('Enum fidelity: PixelFormat and PixelType', () {
      for (final format in PixelFormat.values) {
        final cVal = c.filament_enum_pixel_format(format.value);
        expect(cVal, equals(format.value),
            reason: 'Mismatch for PixelFormat.${format.name}');
      }

      for (final type in [
        PixelType.ubyte,
        PixelType.byteType,
        PixelType.ushort,
        PixelType.shortType,
        PixelType.uint,
        PixelType.intType,
        PixelType.half,
        PixelType.floatType,
      ]) {
        final cVal = c.filament_enum_pixel_type(type.value);
        expect(cVal, equals(type.value),
            reason: 'Mismatch for PixelType.${type.name}');
      }
    });

    test('Sub-region update with xoffset and yoffset', () {
      final tex = FilamentTexture.create2D(
        engine: engine,
        width: 4,
        height: 4,
        format: TextureFormat.rgba8,
        levels: 1,
      );

      // Base 4x4 blue buffer
      final bluePixels = Uint8List(4 * 4 * 4);
      for (int i = 0; i < 4 * 4; i++) {
        bluePixels[i * 4 + 2] = 255; // B
        bluePixels[i * 4 + 3] = 255; // A
      }
      tex.setImage(
        width: 4,
        height: 4,
        buffer: PixelBuffer.fromBytes(bluePixels),
      );

      // Sub-region 2x2 red buffer at (2, 2)
      final redPixels = Uint8List(2 * 2 * 4);
      for (int i = 0; i < 2 * 2; i++) {
        redPixels[i * 4 + 0] = 255; // R
        redPixels[i * 4 + 3] = 255; // A
      }
      tex.setImage(
        xoffset: 2,
        yoffset: 2,
        width: 2,
        height: 2,
        buffer: PixelBuffer.fromBytes(redPixels),
      );

      engine.flushAndWait();
      tex.dispose();
      expect(tex.isDisposed, isTrue);
    });

    test('Row stride upload (strideInPixels > width)', () {
      final tex = FilamentTexture.create2D(
        engine: engine,
        width: 4,
        height: 4,
        format: TextureFormat.rgba8,
        levels: 1,
      );

      // 4x4 backing buffer with row stride of 4 pixels (16 bytes per row), uploading a 2x2 sub-rect
      final paddedData = Uint8List(4 * 4 * 4);
      tex.setImage(
        width: 2,
        height: 2,
        buffer: PixelBuffer.fromBytes(
          paddedData,
          strideInPixels: 4,
          alignment: 1,
        ),
      );

      engine.flushAndWait();
      tex.dispose();
    });

    test('Mip level uploads (level 0 and level 1)', () {
      final tex = FilamentTexture.create2D(
        engine: engine,
        width: 4,
        height: 4,
        format: TextureFormat.rgba8,
        levels: 2,
      );

      final level0Data = Uint8List(4 * 4 * 4);
      final level1Data = Uint8List(2 * 2 * 4);

      tex.setImage(
        level: 0,
        width: 4,
        height: 4,
        buffer: PixelBuffer.fromBytes(level0Data),
      );

      tex.setImage(
        level: 1,
        width: 2,
        height: 2,
        buffer: PixelBuffer.fromBytes(level1Data),
      );

      engine.flushAndWait();
      tex.dispose();
    });

    test('Cubemap face uploads via setCubemapFace', () {
      final cubeTex = FilamentTexture.createCubemap(
        engine: engine,
        size: 8,
        format: TextureFormat.rgba8,
        levels: 1,
      );

      for (final face in CubemapFace.values) {
        final faceData = Uint8List(8 * 8 * 4);
        faceData.fillRange(0, faceData.length, (face.value + 1) * 30);
        cubeTex.setCubemapFace(
          face: face,
          width: 8,
          height: 8,
          buffer: PixelBuffer.fromBytes(faceData),
        );
      }

      engine.flushAndWait();
      cubeTex.dispose();
    });

    test('2D_ARRAY layer upload via zoffset', () {
      final arrayTex = FilamentTexture.create2DArray(
        engine: engine,
        width: 8,
        height: 8,
        layers: 4,
        format: TextureFormat.rgba8,
        levels: 1,
      );

      final layerData = Uint8List(8 * 8 * 4);
      arrayTex.setImage(
        zoffset: 2, // Layer index 2
        width: 8,
        height: 8,
        depth: 1,
        buffer: PixelBuffer.fromBytes(layerData),
      );

      engine.flushAndWait();
      arrayTex.dispose();
    });

    test('NativeBuffer zero-copy ownership release callback on setImage', () async {
      final tex = FilamentTexture.create2D(
        engine: engine,
        width: 8,
        height: 8,
        format: TextureFormat.rgba8,
      );

      final rawBytes = Uint8List(8 * 8 * 4);
      final nativeBuf = NativeBuffer.copy(rawBytes);
      expect(nativeBuf.isReleased, isFalse);

      bool freed = false;
      final (user, callback, token) = BufferOwnershipRegistry.instance.register(
        nativeBuf,
        onFree: () {
          freed = true;
          nativeBuf.free();
        },
      );

      final releaseFuture = BufferOwnershipRegistry.instance.whenReleased(token);

      c.filament_texture_set_image_ex(
        engine.nativePointer,
        tex.nativePointer,
        0,
        0,
        0,
        0,
        8,
        8,
        1,
        PixelFormat.rgba.value,
        PixelType.ubyte.value,
        0,
        1,
        nativeBuf.pointer.cast(),
        nativeBuf.sizeInBytes,
        callback,
        user,
      );

      expect(freed, isFalse);

      // After flushAndWait, Filament finishes processing the upload and fires free callback
      engine.flushAndWait();
      await releaseFuture;

      expect(freed, isTrue);
      expect(nativeBuf.isReleased, isTrue);
      tex.dispose();
    });

    test('PixelBuffer.fromBytes auto-frees backing buffer after engine.flushAndWait', () async {
      final tex = FilamentTexture.create2D(
        engine: engine,
        width: 8,
        height: 8,
        format: TextureFormat.rgba8,
      );

      final rawBytes = Uint8List(8 * 8 * 4);
      final pixelBuf = PixelBuffer.fromBytes(rawBytes);
      expect(pixelBuf.data.isReleased, isFalse);

      tex.setImage(
        width: 8,
        height: 8,
        buffer: pixelBuf,
      );

      engine.flushAndWait();
      await Future<void>.delayed(Duration.zero);
      expect(pixelBuf.data.isReleased, isTrue);
      tex.dispose();
    });
  });
}
