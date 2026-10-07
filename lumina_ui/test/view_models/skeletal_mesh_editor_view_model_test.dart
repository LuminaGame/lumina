import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina/data/services/glb_parser_service.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/skeletal_mesh_editor_view_model.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('skel_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Uint8List buildSkinnedGlb() {
    final gltf = {
      'asset': {'version': '2.0'},
      'nodes': [
        {'name': 'Armature', 'children': [1, 3]},
        {'name': 'pelvis', 'children': [2]},
        {'name': 'spine_01'},
        {'name': 'CharacterMesh', 'mesh': 0},
      ],
      'scenes': [
        {
          'nodes': [0]
        }
      ],
      'scene': 0,
      'meshes': [
        {
          'name': 'Mesh0',
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
    final jsonChunk = Uint8List(jsonPaddedLen)..setRange(0, jsonBytes.length, jsonBytes);

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

    bd.setUint32(0, 0x46546C67, Endian.little);
    bd.setUint32(4, 2, Endian.little);
    bd.setUint32(8, totalLen, Endian.little);

    bd.setUint32(12, jsonPaddedLen, Endian.little);
    bd.setUint32(16, 0x4E4F534A, Endian.little);
    glbBytes.setRange(20, 20 + jsonPaddedLen, jsonChunk);

    final binHeaderOffset = 20 + jsonPaddedLen;
    bd.setUint32(binHeaderOffset, binPaddedLen, Endian.little);
    bd.setUint32(binHeaderOffset + 4, 0x004E4942, Endian.little);
    glbBytes.setRange(binHeaderOffset + 8, binHeaderOffset + 8 + binPaddedLen, binChunk);

    return glbBytes;
  }

  test('GlbParserService: skins.joints correctly tags joints as GlbNodeType.bone', () async {
    final glbBytes = buildSkinnedGlb();
    final mesh = await GlbParserService.parseGlb(glbBytes);
    expect(mesh, isNotNull);
    expect(mesh!.boneCount, 2);
    expect(mesh.allNodes[0].type, GlbNodeType.group);
    expect(mesh.allNodes[1].type, GlbNodeType.bone);
    expect(mesh.allNodes[1].name, 'pelvis');
    expect(mesh.allNodes[2].type, GlbNodeType.bone);
    expect(mesh.allNodes[2].name, 'spine_01');
    expect(mesh.allNodes[3].type, GlbNodeType.mesh);
  });

  test('SkeletalMeshEditorViewModel: socket CRUD and persistence round-trip', () async {
    final glbBytes = buildSkinnedGlb();
    final assetFile = File('${tempDir.path}/SK_Hero.lmas');
    final asset = LuminaAsset(
      assetId: 'SK_Hero',
      name: 'SK_Hero',
      type: AssetType.filamesh,
      rawPayload: glbBytes,
    );
    await assetFile.writeAsBytes(asset.toProtoBufferBytes());

    final vm = SkeletalMeshEditorViewModel(assetPath: assetFile.path);
    await vm.load();

    expect(vm.isLoading, isFalse);
    expect(vm.hasError, isFalse);
    expect(vm.boneCount, 2);
    expect(vm.allBones.map((b) => b.name), containsAll(['pelvis', 'spine_01']));

    // Add Socket
    vm.selectBone(vm.allBones.first); // pelvis
    final added = vm.addSocket();
    expect(added, isTrue);
    expect(vm.sockets.length, 1);
    expect(vm.sockets.first.name, 'pelvis_socket');
    expect(vm.sockets.first.parentBone, 'pelvis');

    // Add second socket with custom name
    vm.addSocket(parentBone: 'spine_01', name: 'hand_r_socket');
    expect(vm.sockets.length, 2);

    // Edit transform
    vm.setSocketTransform('hand_r_socket', location: [10.0, 5.0, 0.0], rotation: [0.0, 90.0, 0.0]);
    final s2 = vm.sockets.where((s) => s.name == 'hand_r_socket').first;
    expect(s2.relativeLocation, [10.0, 5.0, 0.0]);
    expect(s2.relativeRotation, [0.0, 90.0, 0.0]);

    // Unique name validation
    final duplicateRename = vm.renameSocket('hand_r_socket', 'pelvis_socket');
    expect(duplicateRename, isFalse);

    // Reparent socket
    final reparented = vm.reparentSocket('hand_r_socket', 'pelvis');
    expect(reparented, isTrue);
    expect(vm.sockets.where((s) => s.name == 'hand_r_socket').first.parentBone, 'pelvis');

    // Retargeting option
    vm.setBoneRetargeting('pelvis', 'Animation');
    expect(vm.boneRetargeting['pelvis'], 'Animation');

    // Save
    final saved = await vm.save();
    expect(saved, isTrue);

    // Reload from disk
    final vm2 = SkeletalMeshEditorViewModel(assetPath: assetFile.path);
    await vm2.load();

    expect(vm2.sockets.length, 2);
    expect(vm2.sockets.map((s) => s.name), containsAll(['pelvis_socket', 'hand_r_socket']));
    final reloadedHand = vm2.sockets.where((s) => s.name == 'hand_r_socket').first;
    expect(reloadedHand.relativeLocation, [10.0, 5.0, 0.0]);
    expect(reloadedHand.parentBone, 'pelvis');
    expect(vm2.boneRetargeting['pelvis'], 'Animation');

    // Remove socket
    final removed = vm2.removeSocket('pelvis_socket');
    expect(removed, isTrue);
    expect(vm2.sockets.length, 1);
  });
}
