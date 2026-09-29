import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_filament/flutter_filament.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Transcoder Tests', () {
    test('Enum values match Transcoder.h', () {
      expect(ComponentType.byte.index, equals(0));
      expect(ComponentType.ubyte.index, equals(1));
      expect(ComponentType.short.index, equals(2));
      expect(ComponentType.ushort.index, equals(3));
      expect(ComponentType.half.index, equals(4));
      expect(ComponentType.float.index, equals(5));
    });

    test('normalized SHORT: [32767, 0, -32767, -32768] -> [1.0, 0.0, -1.0, -1.0]', () {
      final input = Int16List.fromList([32767, 0, -32767, -32768]);
      final transcoder = Transcoder(TranscoderConfig(
        componentType: ComponentType.short,
        normalized: true,
        componentCount: 1,
      ));

      final output = transcoder.run(input, 4);
      expect(output.length, equals(4));
      expect(output[0], closeTo(1.0, 1e-4));
      expect(output[1], closeTo(0.0, 1e-4));
      expect(output[2], closeTo(-1.0, 1e-4));
      expect(output[3], closeTo(-1.0, 1e-4));
    });

    test('normalized UBYTE: [255, 128, 0] -> [1.0, ~0.502, 0.0]', () {
      final input = Uint8List.fromList([255, 128, 0]);
      final transcoder = Transcoder(TranscoderConfig(
        componentType: ComponentType.ubyte,
        normalized: true,
        componentCount: 1,
      ));

      final output = transcoder.run(input, 3);
      expect(output.length, equals(3));
      expect(output[0], closeTo(1.0, 1e-4));
      expect(output[1], closeTo(128 / 255.0, 1e-3));
      expect(output[2], closeTo(0.0, 1e-4));
    });

    test('normalized=false SHORT: values are converted to plain floats', () {
      final input = Int16List.fromList([100, -250, 4096]);
      final transcoder = Transcoder(TranscoderConfig(
        componentType: ComponentType.short,
        normalized: false,
        componentCount: 1,
      ));

      final output = transcoder.run(input, 3);
      expect(output.length, equals(3));
      expect(output[0], equals(100.0));
      expect(output[1], equals(-250.0));
      expect(output[2], equals(4096.0));
    });

    test('short3 normal data (componentCount=3, stride=6B) -> float3 output', () {
      // 2 vertices of short3
      final input = Int16List.fromList([
        0, 32767, 0, // (0, 1, 0)
        32767, 0, 0, // (1, 0, 0)
      ]);
      final transcoder = Transcoder(TranscoderConfig(
        componentType: ComponentType.short,
        normalized: true,
        componentCount: 3,
        inputStrideBytes: 0,
      ));

      final output = transcoder.run(input, 2);
      expect(output.length, equals(6));
      expect(output[0], closeTo(0.0, 1e-4));
      expect(output[1], closeTo(1.0, 1e-4));
      expect(output[2], closeTo(0.0, 1e-4));
      expect(output[3], closeTo(1.0, 1e-4));
      expect(output[4], closeTo(0.0, 1e-4));
      expect(output[5], closeTo(0.0, 1e-4));
    });

    test('Strided (interleaved) source: extracting UV from stride=16B', () {
      // Each vertex is 16 bytes: float2 position (8B) + ushort2 UV (4B) + 4B padding
      // Let's create a ByteData with 2 vertices
      final byteData = ByteData(32);
      // Vertex 0: pos (0, 0), uv (65535, 32767.5) -> (1.0, 0.5)
      byteData.setFloat32(0, 0.0, Endian.host);
      byteData.setFloat32(4, 0.0, Endian.host);
      byteData.setUint16(8, 65535, Endian.host);
      byteData.setUint16(10, 32767, Endian.host);

      // Vertex 1: pos (1, 1), uv (0, 65535) -> (0.0, 1.0)
      byteData.setFloat32(16, 1.0, Endian.host);
      byteData.setFloat32(20, 1.0, Endian.host);
      byteData.setUint16(24, 0, Endian.host);
      byteData.setUint16(26, 65535, Endian.host);

      final transcoder = Transcoder(TranscoderConfig(
        componentType: ComponentType.ushort,
        normalized: true,
        componentCount: 2,
        inputStrideBytes: 16,
      ));

      // Pass slice pointing to offset 8
      final sourceBytes = Uint8List.view(byteData.buffer, 8);
      final output = transcoder.run(sourceBytes, 2);

      expect(output.length, equals(4));
      expect(output[0], closeTo(1.0, 1e-4));
      expect(output[1], closeTo(32767 / 65535.0, 1e-3));
      expect(output[2], closeTo(0.0, 1e-4));
      expect(output[3], closeTo(1.0, 1e-4));
    });

    test('HALF input: known half bit patterns unpack correctly', () {
      // 0x3C00 is half 1.0, 0xC000 is half -2.0, 0x0000 is half 0.0
      final input = Uint16List.fromList([0x3C00, 0xC000, 0x0000]);
      final transcoder = Transcoder(TranscoderConfig(
        componentType: ComponentType.half,
        normalized: false,
        componentCount: 1,
      ));

      final output = transcoder.run(input, 3);
      expect(output.length, equals(3));
      expect(output[0], closeTo(1.0, 1e-4));
      expect(output[1], closeTo(-2.0, 1e-4));
      expect(output[2], closeTo(0.0, 1e-4));
    });
  });
}
