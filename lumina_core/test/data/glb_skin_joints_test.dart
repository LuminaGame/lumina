import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:lumina_core/lumina_core.dart';
import 'package:test/test.dart';

/// A GLB with two meshes, each drawn by its own node with its own skin over
/// one skeleton: mesh A's skin is `[jointA]`, mesh B's `[jointB]`, and every
/// vertex of both is weighted fully to skin joint 0.
Uint8List _twoSkinGlb() {
  final bin = BytesBuilder();
  final positions = Float32List.fromList([0, 0, 0, 1, 0, 0, 0, 1, 0]);
  bin.add(positions.buffer.asUint8List());
  bin.add(Uint8List(12)); // JOINTS_0: 3 × [0, 0, 0, 0]
  final weights = Float32List.fromList([1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0]);
  bin.add(weights.buffer.asUint8List());
  final binBytes = bin.toBytes();
  final primitive = {
    'attributes': {'POSITION': 0, 'JOINTS_0': 1, 'WEIGHTS_0': 2},
  };
  final json = {
    'asset': {'version': '2.0'},
    'scene': 0,
    'scenes': [
      {
        'nodes': [0, 1, 2, 3],
      },
    ],
    'nodes': [
      {'name': 'MeshA', 'mesh': 0, 'skin': 0},
      {'name': 'MeshB', 'mesh': 1, 'skin': 1},
      {'name': 'jointA'},
      {'name': 'jointB'},
    ],
    'meshes': [
      {
        'primitives': [primitive],
      },
      {
        'primitives': [primitive],
      },
    ],
    'skins': [
      {
        'joints': [2],
      },
      {
        'joints': [3],
      },
    ],
    'buffers': [
      {'byteLength': binBytes.length},
    ],
    'bufferViews': [
      {'buffer': 0, 'byteOffset': 0, 'byteLength': 36},
      {'buffer': 0, 'byteOffset': 36, 'byteLength': 12},
      {'buffer': 0, 'byteOffset': 48, 'byteLength': 48},
    ],
    'accessors': [
      {
        'bufferView': 0,
        'componentType': 5126,
        'count': 3,
        'type': 'VEC3',
        'min': [0, 0, 0],
        'max': [1, 1, 0],
      },
      {'bufferView': 1, 'componentType': 5121, 'count': 3, 'type': 'VEC4'},
      {'bufferView': 2, 'componentType': 5126, 'count': 3, 'type': 'VEC4'},
    ],
  };
  var jsonBytes = utf8.encode(jsonEncode(json));
  jsonBytes = Uint8List.fromList([...jsonBytes, ...List.filled((4 - jsonBytes.length % 4) % 4, 0x20)]);
  final out = BytesBuilder();
  void u32(int v) => out.add((ByteData(4)..setUint32(0, v, Endian.little)).buffer.asUint8List());
  u32(0x46546C67);
  u32(2);
  u32(12 + 8 + jsonBytes.length + 8 + binBytes.length);
  u32(jsonBytes.length);
  u32(0x4E4F534A);
  out.add(jsonBytes);
  u32(binBytes.length);
  u32(0x004E4942);
  out.add(binBytes);
  return out.toBytes();
}

void main() {
  test('each mesh part reads its skin joints as node indices, with several skins over one skeleton', () async {
    final dir = Directory.systemTemp.createTempSync('lumina_glb_skins_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/two_skins.glb')..writeAsBytesSync(_twoSkinGlb());
    final mesh = await GlbReader.parse(await file.readAsBytes());
    expect(mesh, isNotNull);
    final joints = mesh!.jointsPerVertex!;
    expect(mesh.vertexCount, 6);
    String nameOf(int v) => mesh.allNodes[joints[v * 4]].name;
    expect([for (var v = 0; v < 3; v++) nameOf(v)], everyElement('jointA'), reason: 'mesh A: skin 0 → jointA');
    expect([for (var v = 3; v < 6; v++) nameOf(v)], everyElement('jointB'), reason: 'mesh B: skin 1 → jointB');
  });

  final quinn = File('${LuminaWorkspace.testAssets}/mannequin/exports/SKM_Quinn_Simple.glb');
  test('the Quinn mannequin: the top of the head is weighted to the head bone (its skin starts at node 1)', () async {
    final mesh = (await GlbReader.parse(await quinn.readAsBytes()))!;
    final joints = mesh.jointsPerVertex!;
    final weights = mesh.weightsPerVertex!;
    var top = 0;
    for (var v = 1; v < mesh.vertexCount; v++) {
      if (mesh.positions[v * 3 + 1] > mesh.positions[top * 3 + 1]) top = v;
    }
    var best = 0;
    for (var i = 1; i < 4; i++) {
      if (weights[top * 4 + i] > weights[top * 4 + best]) best = i;
    }
    expect(mesh.allNodes[joints[top * 4 + best]].name, 'head');
    // Every weighted joint is one of the skin's joint nodes.
    for (var i = 0; i < joints.length; i++) {
      if (weights[i] > 0) expect(mesh.skeletonJointIndices, contains(joints[i]));
    }
  }, skip: quinn.existsSync() ? false : 'test-assets/mannequin/exports/SKM_Quinn_Simple.glb is missing');
}
