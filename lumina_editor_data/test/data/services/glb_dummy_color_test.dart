import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';

void main() {
  group('GlbParserService Dummy COLOR_0 Tests', () {
    test(
      'Strips dummy black COLOR_0 vertex attribute from CCMH_Body_Female.glb',
      () {
        final path = Platform.environment['LUMINA_CCMH_BODY_GLB'];
        final file = File(path ?? '');
        if (path == null || !file.existsSync()) {
          // Skip gracefully if external fixture is not present
          return;
        }

        final rawBytes = file.readAsBytesSync();
        final sanitized = GlbParserService.convertGlbTgaToPng(rawBytes);

        expect(sanitized, isNotNull);
        expect(sanitized.length, greaterThan(20));

        // Parse JSON chunk of sanitized GLB
        final byteData = ByteData.sublistView(sanitized);
        final magic = byteData.getUint32(0, Endian.little);
        expect(magic, equals(0x46546C67));

        final jsonLength = byteData.getUint32(12, Endian.little);
        final jsonBytes = sanitized.sublist(20, 20 + jsonLength);
        final json = jsonDecode(utf8.decode(jsonBytes)) as Map;

        final meshes = json['meshes'] as List;
        for (final m in meshes) {
          final prims = (m as Map)['primitives'] as List;
          for (final p in prims) {
            final attrs = (p as Map)['attributes'] as Map;
            expect(
              attrs.containsKey('COLOR_0'),
              isFalse,
              reason: 'Dummy black COLOR_0 attribute should be stripped',
            );
          }
        }
      },
    );

    test('Preserves legitimate non-black vertex colors in GLB', () {
      // Create a minimal synthetic GLB with white vertex colors (255, 255, 255, 255)
      final colorBytes = Uint8List.fromList([
        255, 255, 255, 255, // vertex 0: white
        255, 200, 180, 255, // vertex 1: skin/pinkish
        255, 255, 255, 255, // vertex 2: white
      ]);

      final json = {
        'asset': {'version': '2.0'},
        'buffers': [
          {'byteLength': colorBytes.length},
        ],
        'bufferViews': [
          {'buffer': 0, 'byteOffset': 0, 'byteLength': colorBytes.length},
        ],
        'accessors': [
          {
            'bufferView': 0,
            'byteOffset': 0,
            'componentType': 5121, // UNSIGNED_BYTE
            'count': 3,
            'type': 'VEC4',
          },
        ],
        'meshes': [
          {
            'primitives': [
              {
                'attributes': {'COLOR_0': 0},
              },
            ],
          },
        ],
      };

      var jsonStr = jsonEncode(json);
      var jsonBytes = utf8.encode(jsonStr);
      final pad = (4 - (jsonBytes.length % 4)) % 4;
      if (pad > 0) {
        jsonStr += ' ' * pad;
        jsonBytes = utf8.encode(jsonStr);
      }

      final totalLen = 12 + 8 + jsonBytes.length + 8 + colorBytes.length;
      final builder = BytesBuilder();

      final header = ByteData(12)
        ..setUint32(0, 0x46546C67, Endian.little)
        ..setUint32(4, 2, Endian.little)
        ..setUint32(8, totalLen, Endian.little);
      builder.add(header.buffer.asUint8List());

      final jsonHeader = ByteData(8)
        ..setUint32(0, jsonBytes.length, Endian.little)
        ..setUint32(4, 0x4E4F534A, Endian.little);
      builder.add(jsonHeader.buffer.asUint8List());
      builder.add(jsonBytes);

      final binHeader = ByteData(8)
        ..setUint32(0, colorBytes.length, Endian.little)
        ..setUint32(4, 0x004E4942, Endian.little);
      builder.add(binHeader.buffer.asUint8List());
      builder.add(colorBytes);

      final syntheticGlb = builder.toBytes();
      final result = GlbParserService.convertGlbTgaToPng(syntheticGlb);

      // Verify that COLOR_0 was NOT stripped because it has legitimate colors
      final outByteData = ByteData.sublistView(result);
      final outJsonLen = outByteData.getUint32(12, Endian.little);
      final outJsonBytes = result.sublist(20, 20 + outJsonLen);
      final outJson = jsonDecode(utf8.decode(outJsonBytes)) as Map;

      final meshes = outJson['meshes'] as List;
      final attrs = (meshes[0]['primitives'][0] as Map)['attributes'] as Map;
      expect(
        attrs.containsKey('COLOR_0'),
        isTrue,
        reason: 'Legitimate colored COLOR_0 attribute should be preserved',
      );
    });
  });
}
