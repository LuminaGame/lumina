import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_filament/flutter_filament.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Ktx2Reader Async Tests', () {
    late FilamentEngine engine;
    late Uint8List srgbKtx2Bytes;

    setUpAll(() {
      engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
      final srgbFile = File('test/assets/color_grid_uastc_zstd.ktx2');
      expect(srgbFile.existsSync(), isTrue);
      srgbKtx2Bytes = srgbFile.readAsBytesSync();
    });

    tearDownAll(() {
      engine.dispose();
    });

    test('asyncCreate returns non-null handle and texture is available immediately', () {
      final reader = Ktx2Reader(engine);
      reader.requestFormat(TextureFormat.srgb8A8);
      reader.requestFormat(TextureFormat.rgba8);

      final asyncLoad = reader.loadAsync(srgbKtx2Bytes, Ktx2TransferFunction.sRGB);
      expect(asyncLoad, isNotNull);
      final tex = asyncLoad!.texture;
      expect(tex.isDisposed, isFalse);

      asyncLoad.destroy();
      tex.dispose();
      reader.destroy();
    });

    test('Synchronous flow: doTranscoding + uploadImages completes cleanly', () {
      final reader = Ktx2Reader(engine);
      reader.requestFormat(TextureFormat.srgb8A8);
      reader.requestFormat(TextureFormat.rgba8);

      final asyncLoad = reader.loadAsync(srgbKtx2Bytes, Ktx2TransferFunction.sRGB);
      expect(asyncLoad, isNotNull);

      asyncLoad!.doTranscoding();
      asyncLoad.uploadImages();

      final tex = asyncLoad.texture;
      expect(tex.isDisposed, isFalse);

      asyncLoad.destroy();
      tex.dispose();
      reader.destroy();
    });

    test('Isolate flow: transcode runs in an Isolate.run and uploadImages runs on main isolate', () async {
      final reader = Ktx2Reader(engine);
      reader.requestFormat(TextureFormat.srgb8A8);
      reader.requestFormat(TextureFormat.rgba8);

      final asyncLoad = reader.loadAsync(srgbKtx2Bytes, Ktx2TransferFunction.sRGB);
      expect(asyncLoad, isNotNull);

      await asyncLoad!.transcode();
      asyncLoad.uploadImages();

      final tex = asyncLoad.texture;
      expect(tex.isDisposed, isFalse);

      asyncLoad.destroy();
      tex.dispose();
      reader.destroy();
    });

    test('Calling uploadImages before transcoding is safe', () {
      final reader = Ktx2Reader(engine);
      reader.requestFormat(TextureFormat.srgb8A8);
      reader.requestFormat(TextureFormat.rgba8);

      final asyncLoad = reader.loadAsync(srgbKtx2Bytes, Ktx2TransferFunction.sRGB);
      expect(asyncLoad, isNotNull);

      final tex = asyncLoad!.texture;
      expect(() => asyncLoad.uploadImages(), returnsNormally);

      asyncLoad.destroy();
      tex.dispose();
      reader.destroy();
    });

    test('asyncDestroy before transcoding completes is safe and leak-free', () {
      final reader = Ktx2Reader(engine);
      reader.requestFormat(TextureFormat.srgb8A8);
      reader.requestFormat(TextureFormat.rgba8);

      final asyncLoad = reader.loadAsync(srgbKtx2Bytes, Ktx2TransferFunction.sRGB);
      expect(asyncLoad, isNotNull);

      final tex = asyncLoad!.texture;
      // Immediately destroy before transcode
      asyncLoad.destroy();
      tex.dispose();
      reader.destroy();
    });

    test('Garbage data returns null from loadAsync', () {
      final reader = Ktx2Reader(engine);
      reader.requestFormat(TextureFormat.srgb8A8);
      reader.requestFormat(TextureFormat.rgba8);

      final garbage = Uint8List.fromList(List.filled(64, 42));
      final asyncLoad = reader.loadAsync(garbage, Ktx2TransferFunction.sRGB);
      expect(asyncLoad, isNull);

      reader.destroy();
    });

    test('loadStreamed convenience method works end-to-end', () async {
      final reader = Ktx2Reader(engine);
      reader.requestFormat(TextureFormat.srgb8A8);
      reader.requestFormat(TextureFormat.rgba8);

      int uploadCallbacks = 0;
      final tex = await reader.loadStreamed(
        srgbKtx2Bytes,
        Ktx2TransferFunction.sRGB,
        onMipUploaded: () {
          uploadCallbacks++;
        },
      );

      expect(tex, isNotNull);
      expect(tex!.isDisposed, isFalse);
      expect(uploadCallbacks, greaterThanOrEqualTo(1));

      tex.dispose();
      reader.destroy();
    });
  });
}
