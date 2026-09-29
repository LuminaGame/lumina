import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_filament/flutter_filament.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Ktx1Bundle & Ktx1Reader Tests', () {
    late FilamentEngine engine;
    late Uint8List iblBytes;
    late Uint8List image2dBytes;

    setUpAll(() {
      engine = FilamentEngine.create(backend: FilamentBackend.noop)!;

      final iblFile = File('test/assets/lightroom_ibl.ktx');
      expect(iblFile.existsSync(), isTrue);
      iblBytes = iblFile.readAsBytesSync();

      final imgFile = File('test/assets/conftestimage_R11_EAC.ktx');
      expect(imgFile.existsSync(), isTrue);
      image2dBytes = imgFile.readAsBytesSync();
    });

    tearDownAll(() {
      engine.dispose();
    });

    test('Golden 2D .ktx properties', () {
      final bundle = Ktx1Bundle(image2dBytes);
      expect(bundle.numMipLevels, greaterThanOrEqualTo(1));
      expect(bundle.arrayLength, equals(1));
      expect(bundle.isCubemap, isFalse);
      bundle.destroy();
    });

    test('Golden cubemap IBL .ktx spherical harmonics', () {
      final bundle = Ktx1Bundle(iblBytes);
      expect(bundle.isCubemap, isTrue);

      final sh = bundle.getSphericalHarmonics();
      expect(sh, isNotNull);
      expect(sh!.length, equals(27));

      bundle.destroy();
    });

    test('Metadata round-trip and serialization', () {
      final bundle = Ktx1Bundle(iblBytes);
      bundle.setMetadata('author', 'lumina');
      expect(bundle.getMetadata('author'), equals('lumina'));

      final serialized = bundle.serialize();
      expect(serialized.length, equals(bundle.serializedLength));

      // Check KTX 11 magic: «KTX 11»\r\n\x1a\n -> [0xAB, 0x4B, 0x54, 0x58, 0x20, 0x31, 0x31, 0xBB, 0x0D, 0x0A, 0x1A, 0x0A]
      expect(serialized[0], equals(0xAB));
      expect(serialized[1], equals(0x4B)); // 'K'
      expect(serialized[2], equals(0x54)); // 'T'
      expect(serialized[3], equals(0x58)); // 'X'

      // Round-trip deserialize
      final reloaded = Ktx1Bundle(serialized);
      expect(reloaded.getMetadata('author'), equals('lumina'));

      bundle.destroy();
      reloaded.destroy();
    });

    test('Missing metadata returns null and garbage bytes throw error', () {
      final bundle = Ktx1Bundle(iblBytes);
      expect(bundle.getMetadata('nonexistent_key_xyz'), isNull);
      bundle.destroy();

      final garbage = Uint8List.fromList(List.filled(32, 0xFF));
      expect(() => Ktx1Bundle(garbage), throwsArgumentError);
    });

    test('Ktx1Reader.createTexture creates non-null texture and invalidates bundle', () {
      final bundle = Ktx1Bundle(iblBytes);
      final tex = Ktx1Reader.createTexture(engine, bundle, srgb: false);
      expect(tex, isNotNull);
      expect(tex!.isDisposed, isFalse);

      // Bundle is consumed / invalidated by createTexture
      expect(bundle.isDestroyed, isTrue);
      expect(() => bundle.numMipLevels, throwsStateError);

      tex.dispose();
    });

    test('Empty bundle creation and setBlob / serialize workflow', () {
      final empty = Ktx1Bundle.empty(
        numMipLevels: 1,
        arrayLength: 1,
        isCubemap: false,
      );
      expect(empty.numMipLevels, equals(1));
      expect(empty.arrayLength, equals(1));
      expect(empty.isCubemap, isFalse);

      final dummyBlob = Uint8List.fromList([255, 0, 0, 255]); // 1x1 RGBA8
      final success = empty.setBlob(mipLevel: 0, face: 0, data: dummyBlob);
      expect(success, isTrue);

      final roundTrip = empty.getBlob(mipLevel: 0, face: 0);
      expect(roundTrip, equals(dummyBlob));
      expect(empty.getBlob(mipLevel: 5, face: 0), isNull);

      empty.destroy();
    });
  });
}
