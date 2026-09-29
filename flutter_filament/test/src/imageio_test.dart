import 'dart:typed_data';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:test/test.dart';

void main() {
  group('ImageIO Tests (Task 06)', () {
    test('encodeImage PNG and decodeImage round trip', () {
      final img = LinearImage(4, 4, 4);
      for (var y = 0; y < 4; y++) {
        for (var x = 0; x < 4; x++) {
          img.setPixel(x, y, 0, x / 3.0);
          img.setPixel(x, y, 1, y / 3.0);
          img.setPixel(x, y, 2, 0.5);
          img.setPixel(x, y, 3, 1.0);
        }
      }

      final pngBytes = encodeImage(ImageEncoderFormat.png, img);
      expect(pngBytes, isNotEmpty);
      // PNG Magic Header: 0x89, 'P', 'N', 'G' (0x89, 0x50, 0x4E, 0x47)
      expect(pngBytes[0], equals(0x89));
      expect(pngBytes[1], equals(0x50));
      expect(pngBytes[2], equals(0x4E));
      expect(pngBytes[3], equals(0x47));

      final decoded = decodeImage(pngBytes, sourceName: 'test.png');
      expect(decoded.width, equals(4));
      expect(decoded.height, equals(4));
      expect(decoded.channels, equals(4));

      expect(decoded.getPixel(0, 0, 0), closeTo(0.0, 0.05));
      expect(decoded.getPixel(3, 3, 0), closeTo(1.0, 0.05));

      img.destroy();
      decoded.destroy();
    });

    test('encodeImage HDR and decodeImage HDR', () {
      final img = LinearImage(2, 2, 3);
      img.setPixel(0, 0, 0, 2.5);
      img.setPixel(0, 0, 1, 0.5);
      img.setPixel(0, 0, 2, 10.0);

      final hdrBytes = encodeImage(ImageEncoderFormat.hdr, img);
      expect(hdrBytes, isNotEmpty);

      final decoded = decodeImage(hdrBytes, colorSpace: ImageColorSpace.linear, sourceName: 'test.hdr');
      expect(decoded.width, equals(2));
      expect(decoded.height, equals(2));
      expect(decoded.getPixel(0, 0, 0), closeTo(2.5, 0.1));
      expect(decoded.getPixel(0, 0, 2), closeTo(10.0, 0.5));

      img.destroy();
      decoded.destroy();
    });

    test('BasisEncoderBuilder compresses mip chain to KTX2 container', () {
      final mip0 = LinearImage(4, 4, 4);
      final mip1 = LinearImage(2, 2, 4);
      final mip2 = LinearImage(1, 1, 4);

      clearToValue(mip0, 0.5);
      clearToValue(mip1, 0.5);
      clearToValue(mip2, 0.5);

      final builder = BasisEncoderBuilder(mipCount: 3);
      builder.mipLevel(0, mip0);
      builder.mipLevel(1, mip1);
      builder.mipLevel(2, mip2);

      final ktx2Bytes = builder.buildAndEncode();
      expect(ktx2Bytes, isNotEmpty);

      // KTX2 Identifier: «KTX 20»\r\n\x1A\n (0xAB, 0x4B, 0x54, 0x58, 0x20, 0x32, 0x30, 0xBB)
      expect(ktx2Bytes[0], equals(0xAB));
      expect(ktx2Bytes[1], equals(0x4B));
      expect(ktx2Bytes[2], equals(0x54));
      expect(ktx2Bytes[3], equals(0x58));

      mip0.destroy();
      mip1.destroy();
      mip2.destroy();
    });

    test('Decoding corrupt bytes throws FormatException', () {
      final corrupt = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
      expect(() => decodeImage(corrupt, sourceName: 'corrupt.png'), throwsFormatException);
    });
  });
}
