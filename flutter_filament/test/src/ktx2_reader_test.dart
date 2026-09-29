import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_filament/flutter_filament.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Ktx2Reader Tests', () {
    late FilamentEngine engine;
    late Uint8List srgbKtx2Bytes;
    late Uint8List linearKtx2Bytes;

    setUpAll(() {
      engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
      final srgbFile = File('test/assets/color_grid_uastc_zstd.ktx2');
      expect(srgbFile.existsSync(), isTrue);
      srgbKtx2Bytes = srgbFile.readAsBytesSync();

      final linearFile = File('test/assets/roughness.ktx2');
      expect(linearFile.existsSync(), isTrue);
      linearKtx2Bytes = linearFile.readAsBytesSync();
    });

    tearDownAll(() {
      engine.dispose();
    });

    test('Enum values match Ktx2Reader.h exactly', () {
      expect(Ktx2TransferFunction.linear.index, equals(0));
      expect(Ktx2TransferFunction.sRGB.index, equals(1));

      expect(Ktx2Result.success.index, equals(0));
      expect(Ktx2Result.compressedTranscodeFailure.index, equals(1));
      expect(Ktx2Result.uncompressedTranscodeFailure.index, equals(2));
      expect(Ktx2Result.formatUnsupported.index, equals(3));
      expect(Ktx2Result.formatAlreadyRequested.index, equals(4));
    });

    test('Valid UASTC .ktx2 golden loads with sRGB transfer function', () {
      final reader = Ktx2Reader(engine);

      final r1 = reader.requestFormat(TextureFormat.srgb8A8);
      expect(r1, equals(Ktx2Result.success));
      final r2 = reader.requestFormat(TextureFormat.rgba8);
      expect(r2, equals(Ktx2Result.success));

      final tex = reader.load(srgbKtx2Bytes, Ktx2TransferFunction.sRGB);
      expect(tex, isNotNull);
      expect(tex!.isDisposed, isFalse);

      tex.dispose();
      reader.destroy();
    });

    test('Linear .ktx2 golden loads with linear transfer function', () {
      final reader = Ktx2Reader(engine);

      reader.requestFormat(TextureFormat.r8);
      reader.requestFormat(TextureFormat.rgba8);
      final tex = reader.load(linearKtx2Bytes, Ktx2TransferFunction.linear);
      expect(tex, isNotNull);

      tex!.dispose();
      reader.destroy();
    });

    test('Transfer function conflict returns null (contract test)', () {
      final reader = Ktx2Reader(engine);
      reader.requestFormat(TextureFormat.rgba8);

      // Requesting linear on an sRGB marked file returns null
      final tex = reader.load(srgbKtx2Bytes, Ktx2TransferFunction.linear);
      expect(tex, isNull);

      reader.destroy();
    });

    test('Priority order: falls through unsupported format to RGBA8', () {
      final reader = Ktx2Reader(engine);

      // Request DXT5 and RGBA8
      reader.requestFormat(TextureFormat.dxt5Srgba);
      reader.requestFormat(TextureFormat.srgb8A8);
      reader.requestFormat(TextureFormat.rgba8);

      final tex = reader.load(srgbKtx2Bytes, Ktx2TransferFunction.sRGB);
      expect(tex, isNotNull);

      tex!.dispose();
      reader.destroy();
    });

    test('Requesting the same format twice returns formatAlreadyRequested', () {
      final reader = Ktx2Reader(engine);

      final first = reader.requestFormat(TextureFormat.rgba8);
      expect(first, equals(Ktx2Result.success));

      final second = reader.requestFormat(TextureFormat.rgba8);
      expect(second, equals(Ktx2Result.formatAlreadyRequested));

      reader.destroy();
    });

    test('unrequestFormat removes format and prevents transcoding', () {
      final reader = Ktx2Reader(engine);

      reader.requestFormat(TextureFormat.rgba8);
      reader.unrequestFormat(TextureFormat.rgba8);

      // No formats requested, load should return null
      final tex = reader.load(srgbKtx2Bytes, Ktx2TransferFunction.sRGB);
      expect(tex, isNull);

      reader.destroy();
    });

    test('Garbage data returns null without crashing', () {
      final reader = Ktx2Reader(engine);
      reader.requestFormat(TextureFormat.rgba8);

      final garbage = Uint8List.fromList(List.filled(64, 42));
      final tex = reader.load(garbage, Ktx2TransferFunction.sRGB);
      expect(tex, isNull);

      reader.destroy();
    });

    test('Double destroy and operations after destroy throw StateError', () {
      final reader = Ktx2Reader(engine);
      reader.destroy();

      expect(() => reader.destroy(), returnsNormally);
      expect(() => reader.requestFormat(TextureFormat.rgba8), throwsStateError);
      expect(() => reader.load(srgbKtx2Bytes, Ktx2TransferFunction.sRGB), throwsStateError);
    });
  });
}
