import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/data/services/tga_decoder_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TgaDecoderService Tests', () {
    test('Should decode uncompressed 24-bit TGA and convert to valid PNG bytes', () async {
      // Create a 2x2 24-bit uncompressed TGA in memory
      // Header: 18 bytes
      final tgaBytes = Uint8List.fromList([
        0, 0, 2, // Uncompressed TrueColor
        0, 0, 0, 0, 0, // Color map spec
        0, 0, 0, 0, // Origin (0, 0)
        2, 0, // Width = 2
        2, 0, // Height = 2
        24, // 24 bpp (BGR)
        0, // Descriptor (bottom-to-top)
        // Pixel data: 4 pixels in BGR order
        255, 0, 0, // Blue
        0, 255, 0, // Green
        0, 0, 255, // Red
        255, 255, 255, // White
      ]);

      expect(TgaDecoderService.isTga(tgaBytes), isTrue);

      final decoded = TgaDecoderService.decode(tgaBytes);
      expect(decoded, isNotNull);
      expect(decoded!.width, equals(2));
      expect(decoded.height, equals(2));
      expect(decoded.rgbaBytes.length, equals(16)); // 2x2x4

      final pngBytes = TgaDecoderService.tgaToPng(tgaBytes);
      expect(pngBytes, isNotNull);
      expect(pngBytes!.length, greaterThan(20));

      // Verify that Flutter can natively decode the generated PNG
      final codec = await ui.instantiateImageCodec(pngBytes);
      final frame = await codec.getNextFrame();
      expect(frame.image.width, equals(2));
      expect(frame.image.height, equals(2));
    });

    test('Should decode RLE 32-bit TGA and convert to PNG', () async {
      // 2x1 32-bit RLE TGA with 2 identical red pixels
      final tgaBytes = Uint8List.fromList([
        0, 0, 10, // RLE TrueColor
        0, 0, 0, 0, 0,
        0, 0, 0, 0,
        2, 0, // Width = 2
        1, 0, // Height = 1
        32, // 32 bpp (BGRA)
        0x20, // Top-to-bottom descriptor
        // RLE packet: run-length 2 (count-1 = 1 -> 0x80 | 1 = 0x81)
        0x81,
        0, 0, 255, 255, // Red BGRA
      ]);

      expect(TgaDecoderService.isTga(tgaBytes), isTrue);

      final decoded = TgaDecoderService.decode(tgaBytes);
      expect(decoded, isNotNull);
      expect(decoded!.width, equals(2));
      expect(decoded.height, equals(1));

      final pngBytes = TgaDecoderService.tgaToPng(tgaBytes);
      expect(pngBytes, isNotNull);

      final codec = await ui.instantiateImageCodec(pngBytes!);
      final frame = await codec.getNextFrame();
      expect(frame.image.width, equals(2));
    });
  });
}
