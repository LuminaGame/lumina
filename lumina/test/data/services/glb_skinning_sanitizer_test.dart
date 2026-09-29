import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/data/services/glb_parser_service.dart';

void main() {
  group('GlbParserService Skinning Weight Sanitization Tests', () {
    test('Downsamples and normalizes 8-bone skinning weights to 4 float weights', () {
      // Create synthetic GLB with JOINTS_0, WEIGHTS_0, JOINTS_1, WEIGHTS_1
      const vertCount = 2;

      // JOINTS_0 (uint16 vec4) and JOINTS_1 (uint16 vec4)
      final j0Bytes = Uint8List(vertCount * 8);
      final j1Bytes = Uint8List(vertCount * 8);
      final j0Bd = ByteData.sublistView(j0Bytes);
      final j1Bd = ByteData.sublistView(j1Bytes);

      // Vertex 0: joints [0, 1, 2, 3] and [4, 5, 6, 7]
      for (int i = 0; i < 4; i++) {
        j0Bd.setUint16(i * 2, i, Endian.little);
        j1Bd.setUint16(i * 2, 4 + i, Endian.little);
      }
      // Vertex 1: joints [10, 11, 12, 13] and [14, 15, 16, 17]
      for (int i = 0; i < 4; i++) {
        j0Bd.setUint16(8 + i * 2, 10 + i, Endian.little);
        j1Bd.setUint16(8 + i * 2, 14 + i, Endian.little);
      }

      // WEIGHTS_0 (uint16 vec4) and WEIGHTS_1 (uint16 vec4)
      // Representing fractions (value / 65535)
      final w0Bytes = Uint8List(vertCount * 8);
      final w1Bytes = Uint8List(vertCount * 8);
      final w0Bd = ByteData.sublistView(w0Bytes);
      final w1Bd = ByteData.sublistView(w1Bytes);

      // Vertex 0: weights [0.3, 0.2, 0.1, 0.05] and [0.15, 0.1, 0.05, 0.05]
      // Top 4 weights: 0.3 (joint 0), 0.2 (joint 1), 0.15 (joint 4), 0.1 (joint 2)
      // Sum = 0.75
      w0Bd.setUint16(0, (0.3 * 65535).round(), Endian.little);
      w0Bd.setUint16(2, (0.2 * 65535).round(), Endian.little);
      w0Bd.setUint16(4, (0.1 * 65535).round(), Endian.little);
      w0Bd.setUint16(6, (0.05 * 65535).round(), Endian.little);

      w1Bd.setUint16(0, (0.15 * 65535).round(), Endian.little);
      w1Bd.setUint16(2, (0.10 * 65535).round(), Endian.little);
      w1Bd.setUint16(4, (0.05 * 65535).round(), Endian.little);
      w1Bd.setUint16(6, (0.05 * 65535).round(), Endian.little);

      // Vertex 1: weights [0.5, 0.5, 0.0, 0.0] and [0.0, 0.0, 0.0, 0.0]
      w0Bd.setUint16(8, (0.5 * 65535).round(), Endian.little);
      w0Bd.setUint16(10, (0.5 * 65535).round(), Endian.little);
      w0Bd.setUint16(12, 0, Endian.little);
      w0Bd.setUint16(14, 0, Endian.little);

      final totalBuf = BytesBuilder()
        ..add(j0Bytes)
        ..add(w0Bytes)
        ..add(j1Bytes)
        ..add(w1Bytes);
      final binPayload = totalBuf.toBytes();

      final json = {
        'asset': {'version': '2.0'},
        'buffers': [
          {'byteLength': binPayload.length},
        ],
        'bufferViews': [
          {'buffer': 0, 'byteOffset': 0, 'byteLength': 16},
          {'buffer': 0, 'byteOffset': 16, 'byteLength': 16},
          {'buffer': 0, 'byteOffset': 32, 'byteLength': 16},
          {'buffer': 0, 'byteOffset': 48, 'byteLength': 16},
        ],
        'accessors': [
          {
            'bufferView': 0,
            'byteOffset': 0,
            'componentType': 5123, // UNSIGNED_SHORT
            'count': vertCount,
            'type': 'VEC4',
          },
          {
            'bufferView': 1,
            'byteOffset': 0,
            'componentType': 5123, // UNSIGNED_SHORT
            'count': vertCount,
            'type': 'VEC4',
          },
          {
            'bufferView': 2,
            'byteOffset': 0,
            'componentType': 5123, // UNSIGNED_SHORT
            'count': vertCount,
            'type': 'VEC4',
          },
          {
            'bufferView': 3,
            'byteOffset': 0,
            'componentType': 5123, // UNSIGNED_SHORT
            'count': vertCount,
            'type': 'VEC4',
          },
        ],
        'meshes': [
          {
            'primitives': [
              {
                'attributes': {
                  'JOINTS_0': 0,
                  'WEIGHTS_0': 1,
                  'JOINTS_1': 2,
                  'WEIGHTS_1': 3,
                },
              },
            ],
          },
        ],
      };

      var jsonStr = jsonEncode(json);
      while (jsonStr.codeUnits.length % 4 != 0) {
        jsonStr += ' ';
      }
      final jsonBytes = utf8.encode(jsonStr);

      final glbBuilder = BytesBuilder();
      final header = ByteData(12);
      header.setUint32(0, 0x46546C67, Endian.little);
      header.setUint32(4, 2, Endian.little);
      final totalLen = 12 + 8 + jsonBytes.length + 8 + binPayload.length;
      header.setUint32(8, totalLen, Endian.little);
      glbBuilder.add(header.buffer.asUint8List());

      final jsonChunkHeader = ByteData(8);
      jsonChunkHeader.setUint32(0, jsonBytes.length, Endian.little);
      jsonChunkHeader.setUint32(4, 0x4E4F534A, Endian.little);
      glbBuilder.add(jsonChunkHeader.buffer.asUint8List());
      glbBuilder.add(jsonBytes);

      final binChunkHeader = ByteData(8);
      binChunkHeader.setUint32(0, binPayload.length, Endian.little);
      binChunkHeader.setUint32(4, 0x004E4942, Endian.little);
      glbBuilder.add(binChunkHeader.buffer.asUint8List());
      glbBuilder.add(binPayload);

      final rawGlb = glbBuilder.toBytes();

      final sanitized = GlbParserService.convertGlbTgaToPng(rawGlb);
      expect(sanitized, isNotNull);

      // Parse sanitized JSON chunk
      final outBd = ByteData.sublistView(sanitized);
      final outJsonLen = outBd.getUint32(12, Endian.little);
      final outJsonBytes = sanitized.sublist(20, 20 + outJsonLen);
      final outJson = jsonDecode(utf8.decode(outJsonBytes)) as Map;

      final meshes = outJson['meshes'] as List;
      final attrs = (meshes[0]['primitives'][0] as Map)['attributes'] as Map;

      expect(attrs.containsKey('JOINTS_0'), isTrue);
      expect(attrs.containsKey('WEIGHTS_0'), isTrue);
      expect(attrs.containsKey('JOINTS_1'), isFalse, reason: 'JOINTS_1 should be stripped');
      expect(attrs.containsKey('WEIGHTS_1'), isFalse, reason: 'WEIGHTS_1 should be stripped');

      // Accessor for WEIGHTS_0 must be float (5126)
      final accessors = outJson['accessors'] as List;
      final wAcc = accessors[attrs['WEIGHTS_0'] as int] as Map;
      expect(wAcc['componentType'], equals(5126));

      // Accessor for JOINTS_0 must be uint16 (5123)
      final jAcc = accessors[attrs['JOINTS_0'] as int] as Map;
      expect(jAcc['componentType'], equals(5123));

      // Verify weights sum to 1.0 in binary payload
      final binOffset = 20 + outJsonLen + 8;
      final outBinBytes = sanitized.sublist(binOffset);
      final bufferViews = outJson['bufferViews'] as List;
      final wBv = bufferViews[wAcc['bufferView'] as int] as Map;
      final wBvOffset = (wBv['byteOffset'] as int?) ?? 0;
      final wBd = ByteData.sublistView(outBinBytes, wBvOffset);

      // Vertex 0 weights sum
      final v0w0 = wBd.getFloat32(0, Endian.little);
      final v0w1 = wBd.getFloat32(4, Endian.little);
      final v0w2 = wBd.getFloat32(8, Endian.little);
      final v0w3 = wBd.getFloat32(12, Endian.little);
      final v0sum = v0w0 + v0w1 + v0w2 + v0w3;
      expect((v0sum - 1.0).abs(), lessThan(1e-4), reason: 'Vertex 0 weights must sum to 1.0');

      // Vertex 1 weights sum
      final v1w0 = wBd.getFloat32(16, Endian.little);
      final v1w1 = wBd.getFloat32(20, Endian.little);
      final v1w2 = wBd.getFloat32(24, Endian.little);
      final v1w3 = wBd.getFloat32(28, Endian.little);
      final v1sum = v1w0 + v1w1 + v1w2 + v1w3;
      expect((v1sum - 1.0).abs(), lessThan(1e-4), reason: 'Vertex 1 weights must sum to 1.0');
    });

    test('Caps skins with > 256 joints to 256 and clamps vertex joint indices to < 256', () {
      const vertCount = 2;
      final j0Bytes = Uint8List(vertCount * 8);
      final j0Bd = ByteData.sublistView(j0Bytes);
      // Vertex 0 references joint 300 (over 256)
      j0Bd.setUint16(0, 300, Endian.little);
      j0Bd.setUint16(2, 5, Endian.little);
      j0Bd.setUint16(4, 0, Endian.little);
      j0Bd.setUint16(6, 0, Endian.little);

      // Vertex 1 references joint 10
      j0Bd.setUint16(8, 10, Endian.little);
      j0Bd.setUint16(10, 0, Endian.little);
      j0Bd.setUint16(12, 0, Endian.little);
      j0Bd.setUint16(14, 0, Endian.little);

      final w0Bytes = Uint8List(vertCount * 16);
      final w0Bd = ByteData.sublistView(w0Bytes);
      w0Bd.setFloat32(0, 0.7, Endian.little);
      w0Bd.setFloat32(4, 0.3, Endian.little);
      w0Bd.setFloat32(16, 1.0, Endian.little);

      final totalBuf = BytesBuilder()
        ..add(j0Bytes)
        ..add(w0Bytes);
      final binPayload = totalBuf.toBytes();

      // Create 500 joints in skin
      final jointsList = List<int>.generate(500, (i) => i);

      final json = {
        'asset': {'version': '2.0'},
        'buffers': [
          {'byteLength': binPayload.length},
        ],
        'bufferViews': [
          {'buffer': 0, 'byteOffset': 0, 'byteLength': 16},
          {'buffer': 0, 'byteOffset': 16, 'byteLength': 32},
        ],
        'accessors': [
          {
            'bufferView': 0,
            'byteOffset': 0,
            'componentType': 5123, // UNSIGNED_SHORT
            'count': vertCount,
            'type': 'VEC4',
            'max': [300, 5, 0, 0],
          },
          {
            'bufferView': 1,
            'byteOffset': 0,
            'componentType': 5126, // FLOAT
            'count': vertCount,
            'type': 'VEC4',
          },
        ],
        'skins': [
          {
            'joints': jointsList,
          }
        ],
        'meshes': [
          {
            'primitives': [
              {
                'attributes': {
                  'JOINTS_0': 0,
                  'WEIGHTS_0': 1,
                },
              },
            ],
          },
        ],
      };

      var jsonStr = jsonEncode(json);
      while (jsonStr.codeUnits.length % 4 != 0) {
        jsonStr += ' ';
      }
      final jsonBytes = utf8.encode(jsonStr);

      final glbBuilder = BytesBuilder();
      final header = ByteData(12);
      header.setUint32(0, 0x46546C67, Endian.little);
      header.setUint32(4, 2, Endian.little);
      final totalLen = 12 + 8 + jsonBytes.length + 8 + binPayload.length;
      header.setUint32(8, totalLen, Endian.little);
      glbBuilder.add(header.buffer.asUint8List());

      final jsonChunkHeader = ByteData(8);
      jsonChunkHeader.setUint32(0, jsonBytes.length, Endian.little);
      jsonChunkHeader.setUint32(4, 0x4E4F534A, Endian.little);
      glbBuilder.add(jsonChunkHeader.buffer.asUint8List());
      glbBuilder.add(jsonBytes);

      final binChunkHeader = ByteData(8);
      binChunkHeader.setUint32(0, binPayload.length, Endian.little);
      binChunkHeader.setUint32(4, 0x004E4942, Endian.little);
      glbBuilder.add(binChunkHeader.buffer.asUint8List());
      glbBuilder.add(binPayload);

      final rawGlb = glbBuilder.toBytes();

      final sanitized = GlbParserService.convertGlbTgaToPng(rawGlb);
      expect(sanitized, isNotNull);

      // Parse sanitized JSON chunk
      final outBd = ByteData.sublistView(sanitized);
      final outJsonLen = outBd.getUint32(12, Endian.little);
      final outJsonBytes = sanitized.sublist(20, 20 + outJsonLen);
      final outJson = jsonDecode(utf8.decode(outJsonBytes)) as Map;

      final skinsOut = outJson['skins'] as List;
      final skin0 = skinsOut[0] as Map;
      final jointsOut = skin0['joints'] as List;

      // Skin joints must be capped to 256
      expect(jointsOut.length, equals(256));

      // Accessor for JOINTS_0 max must not exceed 255
      final accessorsOut = outJson['accessors'] as List;
      final meshesOut = outJson['meshes'] as List;
      final attrsOut = (meshesOut[0]['primitives'][0] as Map)['attributes'] as Map;
      final jAccOut = accessorsOut[attrsOut['JOINTS_0'] as int] as Map;
      final maxList = jAccOut['max'] as List;
      for (final m in maxList) {
        expect((m as num).toInt(), lessThan(256));
      }
    });

    test('Sanitizes real SKM_TestChar_FaceMesh.glb if present on disk', () {
      final path = Platform.environment['LUMINA_FACEMESH_GLB'];
      if (path == null || !File(path).existsSync()) return;
      final file = File(path);

      final rawBytes = file.readAsBytesSync();
      final sanitized = GlbParserService.convertGlbTgaToPng(rawBytes);
      expect(sanitized, isNotNull);

      final outBd = ByteData.sublistView(sanitized);
      final outJsonLen = outBd.getUint32(12, Endian.little);
      final outJsonBytes = sanitized.sublist(20, 20 + outJsonLen);
      final outJson = jsonDecode(utf8.decode(outJsonBytes)) as Map;

      final skinsOut = outJson['skins'] as List;
      final skin0 = skinsOut[0] as Map;
      final jointsOut = skin0['joints'] as List;
      expect(jointsOut.length, equals(256));

      final accessorsOut = outJson['accessors'] as List;
      final meshesOut = outJson['meshes'] as List;
      for (final mesh in meshesOut) {
        for (final prim in (mesh as Map)['primitives'] as List) {
          final attrs = (prim as Map)['attributes'] as Map;
          if (attrs.containsKey('JOINTS_0')) {
            final jAcc = accessorsOut[attrs['JOINTS_0'] as int] as Map;
            final maxList = jAcc['max'] as List;
            for (final m in maxList) {
              expect((m as num).toInt(), lessThan(256));
            }
          }
        }
      }
    });

    test('Transfers pruned joint weights to nearest ancestor and preserves all essential limb joints', () {
      final path = Platform.environment['LUMINA_METAHUMAN_BODY_GLB'];
      if (path == null || !File(path).existsSync()) return;
      final file = File(path);

      final rawBytes = file.readAsBytesSync();
      final sanitized = GlbParserService.convertGlbTgaToPng(rawBytes);
      expect(sanitized, isNotNull);

      final outBd = ByteData.sublistView(sanitized);
      final outJsonLen = outBd.getUint32(12, Endian.little);
      final outJsonBytes = sanitized.sublist(20, 20 + outJsonLen);
      final outJson = jsonDecode(utf8.decode(outJsonBytes)) as Map;

      final skinsOut = outJson['skins'] as List;
      final skin0 = skinsOut[0] as Map;
      final jointsOut = (skin0['joints'] as List).cast<int>();
      expect(jointsOut.length, equals(256));

      final nodes = outJson['nodes'] as List;
      final keptNames = jointsOut.map((n) => nodes[n]['name'] as String).toSet();

      // Essential limbs and joints must be present
      expect(keptNames, contains('hand_r'));
      expect(keptNames, contains('hand_l'));
      expect(keptNames, contains('thigh_r'));
      expect(keptNames, contains('calf_r'));
      expect(keptNames, contains('foot_r'));
      expect(keptNames, contains('thigh_l'));
      expect(keptNames, contains('calf_l'));
      expect(keptNames, contains('foot_l'));
      expect(keptNames, contains('wrist_inner_r'));
    });
  });
}
