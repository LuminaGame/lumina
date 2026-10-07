import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';

Uint8List createGlbWithAnimations() {
  // We construct a valid binary glTF 2.0 with 2 animation clips:
  // - "Idle": duration 2.0s, animating node 1 (pelvis) rotation
  // - "Walk": duration 1.5s, animating node 1 (pelvis) translation and node 2 (spine) rotation

  // Buffer layout:
  // Accessor 0: Positions [0,0,0, 1,0,0, 0,1,0] (3 vec3 floats = 36 bytes)
  // Accessor 1: Indices [0, 1, 2] (3 uint16 = 6 bytes + 2 pad = 8 bytes)
  // Accessor 2: "Idle" Time [0.0, 1.0, 2.0] (3 scalar floats = 12 bytes)
  // Accessor 3: "Idle" Rotation quaternions (3 vec4 floats = 48 bytes)
  // Accessor 4: "Walk" Time [0.0, 0.75, 1.5] (3 scalar floats = 12 bytes)
  // Accessor 5: "Walk" Translation (3 vec3 floats = 36 bytes)

  final BytesBuilder bin = BytesBuilder();

  // Acc 0: pos
  final posData = Float32List.fromList([
    0.0, 0.0, 0.0,
    1.0, 0.0, 0.0,
    0.0, 1.0, 0.0,
  ]);
  bin.add(posData.buffer.asUint8List()); // 36 bytes (offset 0..36)

  // Acc 1: ind
  final indData = Uint16List.fromList([0, 1, 2]);
  bin.add(indData.buffer.asUint8List()); // 6 bytes (offset 36..42)
  bin.add(Uint8List(2)); // pad to 44

  // Acc 2: Idle times
  final idleTimes = Float32List.fromList([0.0, 1.0, 2.0]);
  bin.add(idleTimes.buffer.asUint8List()); // 12 bytes (offset 44..56)

  // Acc 3: Idle quats
  final idleQuats = Float32List.fromList([
    0.0, 0.0, 0.0, 1.0,
    0.0, 0.707, 0.0, 0.707,
    0.0, 0.0, 0.0, 1.0,
  ]);
  bin.add(idleQuats.buffer.asUint8List()); // 48 bytes (offset 56..104)

  // Acc 4: Walk times
  final walkTimes = Float32List.fromList([0.0, 0.75, 1.5]);
  bin.add(walkTimes.buffer.asUint8List()); // 12 bytes (offset 104..116)

  // Acc 5: Walk trans
  final walkTrans = Float32List.fromList([
    0.0, 0.0, 0.0,
    0.0, 0.0, 1.0,
    0.0, 0.0, 2.0,
  ]);
  bin.add(walkTrans.buffer.asUint8List()); // 36 bytes (offset 116..152)

  final binBytes = bin.toBytes();

  final jsonMap = {
    'asset': {'version': '2.0'},
    'nodes': [
      {'name': 'Armature', 'children': [1]},
      {'name': 'pelvis', 'children': [2]},
      {'name': 'spine_01'},
      {'name': 'MeshNode', 'mesh': 0},
    ],
    'scenes': [
      {
        'nodes': [0, 3]
      }
    ],
    'scene': 0,
    'meshes': [
      {
        'name': 'SimpleMesh',
        'primitives': [
          {
            'attributes': {'POSITION': 0},
            'indices': 1,
          }
        ]
      }
    ],
    'accessors': [
      {
        'bufferView': 0,
        'byteOffset': 0,
        'componentType': 5126,
        'count': 3,
        'type': 'VEC3',
        'min': [0.0, 0.0, 0.0],
        'max': [1.0, 1.0, 0.0],
      },
      {
        'bufferView': 1,
        'byteOffset': 0,
        'componentType': 5123,
        'count': 3,
        'type': 'SCALAR',
      },
      {
        'bufferView': 2,
        'byteOffset': 0,
        'componentType': 5126,
        'count': 3,
        'type': 'SCALAR',
        'min': [0.0],
        'max': [2.0],
      },
      {
        'bufferView': 3,
        'byteOffset': 0,
        'componentType': 5126,
        'count': 3,
        'type': 'VEC4',
      },
      {
        'bufferView': 4,
        'byteOffset': 0,
        'componentType': 5126,
        'count': 3,
        'type': 'SCALAR',
        'min': [0.0],
        'max': [1.5],
      },
      {
        'bufferView': 5,
        'byteOffset': 0,
        'componentType': 5126,
        'count': 3,
        'type': 'VEC3',
      },
    ],
    'bufferViews': [
      {'buffer': 0, 'byteOffset': 0, 'byteLength': 36},
      {'buffer': 0, 'byteOffset': 36, 'byteLength': 6},
      {'buffer': 0, 'byteOffset': 44, 'byteLength': 12},
      {'buffer': 0, 'byteOffset': 56, 'byteLength': 48},
      {'buffer': 0, 'byteOffset': 104, 'byteLength': 12},
      {'buffer': 0, 'byteOffset': 116, 'byteLength': 36},
    ],
    'buffers': [
      {'byteLength': binBytes.length}
    ],
    'animations': [
      {
        'name': 'Idle',
        'samplers': [
          {'input': 2, 'output': 3, 'interpolation': 'LINEAR'}
        ],
        'channels': [
          {
            'sampler': 0,
            'target': {'node': 1, 'path': 'rotation'}
          }
        ]
      },
      {
        'name': 'Walk',
        'samplers': [
          {'input': 4, 'output': 5, 'interpolation': 'LINEAR'}
        ],
        'channels': [
          {
            'sampler': 0,
            'target': {'node': 1, 'path': 'translation'}
          },
          {
            'sampler': 0,
            'target': {'node': 2, 'path': 'rotation'}
          }
        ]
      }
    ],
  };

  final jsonStr = jsonEncode(jsonMap);
  final jsonBytes = utf8.encode(jsonStr);
  final jsonPad = (4 - (jsonBytes.length % 4)) % 4;
  final finalJsonBytes = Uint8List(jsonBytes.length + jsonPad)
    ..setAll(0, jsonBytes)
    ..fillRange(jsonBytes.length, jsonBytes.length + jsonPad, 0x20);

  final totalLength = 12 + 8 + finalJsonBytes.length + 8 + binBytes.length;
  final glb = BytesBuilder();
  // Header
  final h = ByteData(12)
    ..setUint32(0, 0x46546C67, Endian.little)
    ..setUint32(4, 2, Endian.little)
    ..setUint32(8, totalLength, Endian.little);
  glb.add(h.buffer.asUint8List());

  // JSON Chunk
  final jh = ByteData(8)
    ..setUint32(0, finalJsonBytes.length, Endian.little)
    ..setUint32(4, 0x4E4F534A, Endian.little);
  glb.add(jh.buffer.asUint8List());
  glb.add(finalJsonBytes);

  // BIN Chunk
  final bh = ByteData(8)
    ..setUint32(0, binBytes.length, Endian.little)
    ..setUint32(4, 0x004E4942, Endian.little);
  glb.add(bh.buffer.asUint8List());
  glb.add(binBytes);

  return glb.toBytes();
}

void main() {
  test('GlbParserService parses animation clips, durations, and targeted bone nodes', () async {
    final glbBytes = createGlbWithAnimations();

    final meshData = await GlbParserService.parseGlb(glbBytes);
    expect(meshData, isNotNull);

    expect(meshData!.animations.length, equals(2));

    final idle = meshData.animations[0];
    expect(idle.name, equals('Idle'));
    expect(idle.duration, closeTo(2.0, 1e-4));
    expect(idle.animatedNodeIndices, contains(1)); // pelvis
    expect(idle.channelTargetPaths, contains('rotation'));

    final walk = meshData.animations[1];
    expect(walk.name, equals('Walk'));
    expect(walk.duration, closeTo(1.5, 1e-4));
    expect(walk.animatedNodeIndices, containsAll([1, 2])); // pelvis, spine_01
    expect(walk.channelTargetPaths, containsAll(['translation', 'rotation']));

    // GlbMeshData helper
    expect(meshData.animatedNodeIndices, containsAll([1, 2]));
  });
}
