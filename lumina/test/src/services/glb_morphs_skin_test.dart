import 'dart:convert';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:lumina/data/services/glb_parser_service.dart';

void main() {
  group('GlbParserService morph targets & skin weights', () {
    Uint8List buildGlbWithMorphs({List<String>? targetNames}) {
      // 1 triangle, 3 vertices: (0,0,0), (1,0,0), (0,1,0)
      final posFloats = Float32List.fromList([
        0.0, 0.0, 0.0,
        1.0, 0.0, 0.0,
        0.0, 1.0, 0.0,
      ]);
      // Target 0: (0, 0.5, 0), (0, 0, 0), (0, 0, 0)
      final t0Floats = Float32List.fromList([
        0.0, 0.5, 0.0,
        0.0, 0.0, 0.0,
        0.0, 0.0, 0.0,
      ]);
      // Target 1: (0, 0, 0), (0, 0.2, 0), (0, 0, 0)
      final t1Floats = Float32List.fromList([
        0.0, 0.0, 0.0,
        0.0, 0.2, 0.0,
        0.0, 0.0, 0.0,
      ]);

      final binBuilder = BytesBuilder();
      binBuilder.add(posFloats.buffer.asUint8List()); // 36 bytes (offset 0)
      binBuilder.add(t0Floats.buffer.asUint8List());  // 36 bytes (offset 36)
      binBuilder.add(t1Floats.buffer.asUint8List());  // 36 bytes (offset 72)
      final binBytes = binBuilder.toBytes();

      final gltf = {
        'asset': {'version': '2.0'},
        'buffers': [
          {'byteLength': binBytes.length}
        ],
        'bufferViews': [
          {'buffer': 0, 'byteOffset': 0, 'byteLength': 36, 'target': 34962},
          {'buffer': 0, 'byteOffset': 36, 'byteLength': 36, 'target': 34962},
          {'buffer': 0, 'byteOffset': 72, 'byteLength': 36, 'target': 34962},
        ],
        'accessors': [
          {'bufferView': 0, 'byteOffset': 0, 'componentType': 5126, 'count': 3, 'type': 'VEC3'},
          {'bufferView': 1, 'byteOffset': 0, 'componentType': 5126, 'count': 3, 'type': 'VEC3'},
          {'bufferView': 2, 'byteOffset': 0, 'componentType': 5126, 'count': 3, 'type': 'VEC3'},
        ],
        'meshes': [
          {
            'name': 'MorphMesh',
            if (targetNames != null) 'extras': {'targetNames': targetNames},
            'primitives': [
              {
                'attributes': {'POSITION': 0},
                'targets': [
                  {'POSITION': 1},
                  {'POSITION': 2},
                ],
              }
            ],
          }
        ],
        'nodes': [
          {'name': 'Node0', 'mesh': 0}
        ],
        'scene': 0,
        'scenes': [
          {
            'nodes': [0]
          }
        ],
      };

      final jsonStr = jsonEncode(gltf);
      final jsonBytes = utf8.encode(jsonStr);
      final jsonPaddedLen = (jsonBytes.length + 3) & ~3;
      final binPaddedLen = (binBytes.length + 3) & ~3;

      final totalLen = 12 + 8 + jsonPaddedLen + 8 + binPaddedLen;
      final out = Uint8List(totalLen);
      final bd = ByteData.sublistView(out);

      bd.setUint32(0, 0x46546C67, Endian.little);
      bd.setUint32(4, 2, Endian.little);
      bd.setUint32(8, totalLen, Endian.little);

      bd.setUint32(12, jsonPaddedLen, Endian.little);
      bd.setUint32(16, 0x4E4F534A, Endian.little);
      out.setRange(20, 20 + jsonBytes.length, jsonBytes);
      for (int i = 20 + jsonBytes.length; i < 20 + jsonPaddedLen; i++) {
        out[i] = 0x20;
      }

      final binHeaderOffset = 20 + jsonPaddedLen;
      bd.setUint32(binHeaderOffset, binPaddedLen, Endian.little);
      bd.setUint32(binHeaderOffset + 4, 0x004E4942, Endian.little);
      out.setRange(binHeaderOffset + 8, binHeaderOffset + 8 + binBytes.length, binBytes);

      return out;
    }

    test('parses morph targets with named extras.targetNames', () async {
      final glb = buildGlbWithMorphs(targetNames: ['smile', 'frown']);
      final mesh = await GlbParserService.parseGlb(glb);
      expect(mesh, isNotNull);
      expect(mesh!.morphTargets.length, 2);
      expect(mesh.morphTargets[0].name, 'smile');
      expect(mesh.morphTargets[1].name, 'frown');
      expect(mesh.morphTargets[0].positionDeltas.length, 9);
      // Vertex 0 delta in smile: (0, 0.5, 0)
      expect(mesh.morphTargets[0].positionDeltas[0], 0.0);
      expect(mesh.morphTargets[0].positionDeltas[1], 0.5);
      expect(mesh.morphTargets[0].positionDeltas[2], 0.0);
    });

    test('parses morph targets fallback to morph_0 and morph_1 when targetNames missing', () async {
      final glb = buildGlbWithMorphs(targetNames: null);
      final mesh = await GlbParserService.parseGlb(glb);
      expect(mesh, isNotNull);
      expect(mesh!.morphTargets.length, 2);
      expect(mesh.morphTargets[0].name, 'morph_0');
      expect(mesh.morphTargets[1].name, 'morph_1');
    });

    test('parses JOINTS_0 (u8) and WEIGHTS_0 (normalized u16)', () async {
      final posFloats = Float32List.fromList([
        0.0, 0.0, 0.0,
        1.0, 0.0, 0.0,
        0.0, 1.0, 0.0,
      ]);
      // 3 vertices, each with 4 joints (u8): [0, 1, 0, 0], [1, 2, 0, 0], [0, 0, 0, 0]
      final jointsBytes = Uint8List.fromList([
        0, 1, 0, 0,
        1, 2, 0, 0,
        0, 0, 0, 0,
      ]);
      // 3 vertices, each with 4 weights (normalized u16):
      // V0: [0.75, 0.25, 0.0, 0.0] -> [49151, 16384, 0, 0]
      // V1: [0.0, 1.0, 0.0, 0.0] -> [0, 65535, 0, 0]
      // V2: [1.0, 0.0, 0.0, 0.0] -> [65535, 0, 0, 0]
      final weightsU16 = Uint16List.fromList([
        49151, 16384, 0, 0,
        0, 65535, 0, 0,
        65535, 0, 0, 0,
      ]);

      final binBuilder = BytesBuilder();
      binBuilder.add(posFloats.buffer.asUint8List()); // 36 bytes (offset 0)
      binBuilder.add(jointsBytes);                    // 12 bytes (offset 36)
      binBuilder.add(weightsU16.buffer.asUint8List()); // 24 bytes (offset 48)
      final binBytes = binBuilder.toBytes();

      final gltf = {
        'asset': {'version': '2.0'},
        'buffers': [
          {'byteLength': binBytes.length}
        ],
        'bufferViews': [
          {'buffer': 0, 'byteOffset': 0, 'byteLength': 36, 'target': 34962},
          {'buffer': 0, 'byteOffset': 36, 'byteLength': 12, 'target': 34962},
          {'buffer': 0, 'byteOffset': 48, 'byteLength': 24, 'target': 34962},
        ],
        'accessors': [
          {'bufferView': 0, 'byteOffset': 0, 'componentType': 5126, 'count': 3, 'type': 'VEC3'},
          {'bufferView': 1, 'byteOffset': 0, 'componentType': 5121, 'count': 3, 'type': 'VEC4'},
          {'bufferView': 2, 'byteOffset': 0, 'componentType': 5123, 'count': 3, 'type': 'VEC4', 'normalized': true},
        ],
        'meshes': [
          {
            'name': 'SkinMesh',
            'primitives': [
              {
                'attributes': {
                  'POSITION': 0,
                  'JOINTS_0': 1,
                  'WEIGHTS_0': 2,
                },
              }
            ],
          }
        ],
        'nodes': [
          {'name': 'Node0', 'mesh': 0}
        ],
        'scene': 0,
        'scenes': [
          {
            'nodes': [0]
          }
        ],
      };

      final jsonStr = jsonEncode(gltf);
      final jsonBytes = utf8.encode(jsonStr);
      final jsonPaddedLen = (jsonBytes.length + 3) & ~3;
      final binPaddedLen = (binBytes.length + 3) & ~3;

      final totalLen = 12 + 8 + jsonPaddedLen + 8 + binPaddedLen;
      final out = Uint8List(totalLen);
      final bd = ByteData.sublistView(out);

      bd.setUint32(0, 0x46546C67, Endian.little);
      bd.setUint32(4, 2, Endian.little);
      bd.setUint32(8, totalLen, Endian.little);

      bd.setUint32(12, jsonPaddedLen, Endian.little);
      bd.setUint32(16, 0x4E4F534A, Endian.little);
      out.setRange(20, 20 + jsonBytes.length, jsonBytes);
      for (int i = 20 + jsonBytes.length; i < 20 + jsonPaddedLen; i++) {
        out[i] = 0x20;
      }

      final binHeaderOffset = 20 + jsonPaddedLen;
      bd.setUint32(binHeaderOffset, binPaddedLen, Endian.little);
      bd.setUint32(binHeaderOffset + 4, 0x004E4942, Endian.little);
      out.setRange(binHeaderOffset + 8, binHeaderOffset + 8 + binBytes.length, binBytes);

      final mesh = await GlbParserService.parseGlb(out);
      expect(mesh, isNotNull);
      expect(mesh!.jointsPerVertex, isNotNull);
      expect(mesh.weightsPerVertex, isNotNull);
      expect(mesh.maxInfluences, 4);

      // The parser hands Filament four normalized float influences per vertex,
      // sorted by weight with empty slots last (b556b0f): compare
      // each vertex's joint → weight influences, not slot order.
      Map<int, double> influences(int v) => {
            for (var i = 0; i < 4; i++)
              if (mesh.weightsPerVertex![v * 4 + i] > 1e-6) mesh.jointsPerVertex![v * 4 + i]: mesh.weightsPerVertex![v * 4 + i],
          };
      void expectInfluences(int v, Map<int, double> expected) {
        final got = influences(v);
        expect(got.keys.toSet(), expected.keys.toSet(), reason: 'vertex $v joints: $got');
        for (final e in expected.entries) {
          expect(got[e.key], closeTo(e.value, 1e-3), reason: 'vertex $v joint ${e.key}: $got');
        }
        expect(got.values.fold(0.0, (a, b) => a + b), closeTo(1.0, 1e-6), reason: 'vertex $v weights sum to 1');
      }

      // V0: joints 0, 1 at 0.75, 0.25 — already heaviest first.
      expect(mesh.jointsPerVertex!.sublist(0, 2), [0, 1]);
      expect(mesh.weightsPerVertex![0], closeTo(0.75, 1e-3));
      expect(mesh.weightsPerVertex![1], closeTo(0.25, 1e-3));
      expectInfluences(0, {0: 0.75, 1: 0.25});
      // V1: joints (1, 2) weighted (0, 1) — only joint 2 influences it, and it
      // moves to the first slot.
      expectInfluences(1, {2: 1.0});
      expect(mesh.jointsPerVertex![4], 2);
      expect(mesh.weightsPerVertex![4], closeTo(1.0, 1e-3));
      // V2: joint 0 at 1.0.
      expectInfluences(2, {0: 1.0});
    });
  });
}
