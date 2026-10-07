import 'dart:convert';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';

void main() {
  test('GlbParserService parses skins[].joints and tags bones precisely', () async {
    // Construct minimal synthetic GLB with 4 nodes:
    // Node 0: "Root" (meshIdx: null)
    // Node 1: "pelvis" (meshIdx: null, listed in skins.joints)
    // Node 2: "spine_01" (meshIdx: null, listed in skins.joints)
    // Node 3: "MeshNode" (meshIdx: 0)
    final gltf = {
      'asset': {'version': '2.0'},
      'nodes': [
        {'name': 'Root', 'children': [1, 3]},
        {'name': 'pelvis', 'children': [2]},
        {'name': 'spine_01'},
        {'name': 'MeshNode', 'mesh': 0},
      ],
      'scenes': [
        {
          'nodes': [0]
        }
      ],
      'scene': 0,
      'meshes': [
        {
          'name': 'CubeMesh',
          'primitives': [
            {'attributes': {'POSITION': 0}}
          ]
        }
      ],
      'accessors': [
        {
          'bufferView': 0,
          'componentType': 5126,
          'count': 3,
          'type': 'VEC3',
          'min': [0.0, 0.0, 0.0],
          'max': [1.0, 1.0, 1.0]
        }
      ],
      'bufferViews': [
        {'buffer': 0, 'byteOffset': 0, 'byteLength': 36}
      ],
      'buffers': [
        {'byteLength': 36}
      ],
      'skins': [
        {
          'name': 'ArmatureSkin',
          'joints': [1, 2],
        }
      ],
    };

    final jsonStr = jsonEncode(gltf);
    final jsonBytes = utf8.encode(jsonStr);
    final jsonPaddedLen = (jsonBytes.length + 3) & ~3;
    final jsonChunk = Uint8List(jsonPaddedLen)
      ..fillRange(0, jsonPaddedLen, 0x20) // glTF pads the JSON chunk with spaces
      ..setRange(0, jsonBytes.length, jsonBytes);

    // 3 vertices (36 bytes)
    final binData = Float32List.fromList([
      0.0, 0.0, 0.0,
      1.0, 0.0, 0.0,
      0.0, 1.0, 0.0,
    ]).buffer.asUint8List();
    final binPaddedLen = (binData.length + 3) & ~3;
    final binChunk = Uint8List(binPaddedLen)..setRange(0, binData.length, binData);

    final totalLen = 12 + 8 + jsonPaddedLen + 8 + binPaddedLen;
    final glbBytes = Uint8List(totalLen);
    final bd = ByteData.sublistView(glbBytes);

    // Header
    bd.setUint32(0, 0x46546C67, Endian.little); // 'glTF'
    bd.setUint32(4, 2, Endian.little); // version
    bd.setUint32(8, totalLen, Endian.little);

    // JSON Chunk
    bd.setUint32(12, jsonPaddedLen, Endian.little);
    bd.setUint32(16, 0x4E4F534A, Endian.little); // 'JSON'
    glbBytes.setRange(20, 20 + jsonPaddedLen, jsonChunk);

    // BIN Chunk
    final binHeaderOffset = 20 + jsonPaddedLen;
    bd.setUint32(binHeaderOffset, binPaddedLen, Endian.little);
    bd.setUint32(binHeaderOffset + 4, 0x004E4942, Endian.little); // 'BIN\0'
    glbBytes.setRange(binHeaderOffset + 8, binHeaderOffset + 8 + binPaddedLen, binChunk);

    final meshData = await GlbParserService.parseGlb(glbBytes);
    expect(meshData, isNotNull);
    expect(meshData!.skeletonJointIndices, containsAll([1, 2]));
    expect(meshData.boneCount, 2);

    expect(meshData.allNodes[0].type, GlbNodeType.group);
    expect(meshData.allNodes[1].type, GlbNodeType.bone);
    expect(meshData.allNodes[2].type, GlbNodeType.bone);
    expect(meshData.allNodes[3].type, GlbNodeType.mesh);
  });
}
