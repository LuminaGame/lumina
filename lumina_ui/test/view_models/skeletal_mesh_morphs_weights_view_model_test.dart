import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/skeletal_mesh_editor_view_model.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('skel_morph_vm_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Uint8List buildGlbWithMorphsAndSkin() {
    // 2 vertices: V0 = (0,0,0), V1 = (1,0,0)
    // 1 triangle: [0, 1, 0]
    final posFloats = Float32List.fromList([
      0.0, 0.0, 0.0,
      1.0, 0.0, 0.0,
      0.0, 1.0, 0.0,
    ]);
    // Target 0 ("smile"): delta for V0 is (0, 0.5, 0), others (0,0,0)
    final t0Floats = Float32List.fromList([
      0.0, 0.5, 0.0,
      0.0, 0.0, 0.0,
      0.0, 0.0, 0.0,
    ]);
    // JOINTS_0: V0 is bone 0, V1 is bone 1, V2 is bone 0
    final jointsBytes = Uint8List.fromList([
      0, 0, 0, 0,
      1, 0, 0, 0,
      0, 0, 0, 0,
    ]);
    // WEIGHTS_0: V0 is 1.0 on bone 0, V1 is 1.0 on bone 1, V2 is 0.8 (non-normalized)
    final weightsFloats = Float32List.fromList([
      1.0, 0.0, 0.0, 0.0,
      1.0, 0.0, 0.0, 0.0,
      0.8, 0.0, 0.0, 0.0,
    ]);

    final binBuilder = BytesBuilder();
    binBuilder.add(posFloats.buffer.asUint8List());     // 36 bytes (offset 0)
    binBuilder.add(t0Floats.buffer.asUint8List());      // 36 bytes (offset 36)
    binBuilder.add(jointsBytes);                        // 12 bytes (offset 72)
    binBuilder.add(weightsFloats.buffer.asUint8List()); // 48 bytes (offset 84)
    final binBytes = binBuilder.toBytes();

    final gltf = {
      'asset': {'version': '2.0'},
      'buffers': [
        {'byteLength': binBytes.length}
      ],
      'bufferViews': [
        {'buffer': 0, 'byteOffset': 0, 'byteLength': 36, 'target': 34962},
        {'buffer': 0, 'byteOffset': 36, 'byteLength': 36, 'target': 34962},
        {'buffer': 0, 'byteOffset': 72, 'byteLength': 12, 'target': 34962},
        {'buffer': 0, 'byteOffset': 84, 'byteLength': 48, 'target': 34962},
      ],
      'accessors': [
        {'bufferView': 0, 'byteOffset': 0, 'componentType': 5126, 'count': 3, 'type': 'VEC3'},
        {'bufferView': 1, 'byteOffset': 0, 'componentType': 5126, 'count': 3, 'type': 'VEC3'},
        {'bufferView': 2, 'byteOffset': 0, 'componentType': 5121, 'count': 3, 'type': 'VEC4'},
        {'bufferView': 3, 'byteOffset': 0, 'componentType': 5126, 'count': 3, 'type': 'VEC4'},
      ],
      'meshes': [
        {
          'name': 'HeroMesh',
          'extras': {
            'targetNames': ['smile']
          },
          'primitives': [
            {
              'attributes': {
                'POSITION': 0,
                'JOINTS_0': 2,
                'WEIGHTS_0': 3,
              },
              'targets': [
                {'POSITION': 1}
              ],
            }
          ],
        }
      ],
      'nodes': [
        {'name': 'Armature', 'children': [1]},
        {'name': 'pelvis', 'children': [2]},
        {'name': 'spine_01'},
        {'name': 'MeshNode', 'mesh': 0},
      ],
      'skins': [
        {
          'joints': [1, 2],
        }
      ],
      'scene': 0,
      'scenes': [
        {
          'nodes': [0, 3]
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

  test('SkeletalMeshEditorViewModel morph weights and deformedPositions reuse', () async {
    final glbBytes = buildGlbWithMorphsAndSkin();
    final assetFile = File('${tempDir.path}/SK_Hero.lmas');
    final asset = LuminaAsset(
      assetId: 'SK_Hero',
      name: 'SK_Hero',
      type: AssetType.filamesh,
      rawPayload: glbBytes,
    );
    assetFile.writeAsBytesSync(asset.toProtoBufferBytes());

    final vm = SkeletalMeshEditorViewModel(assetPath: assetFile.path, initialAsset: asset);
    await vm.load();

    expect(vm.morphTargets.length, 1);
    expect(vm.morphTargets[0].name, 'smile');

    // Base position of V0: (0, 0, 0)
    final p0 = vm.deformedPositions();
    expect(p0[0], 0.0);
    expect(p0[1], 0.0);
    expect(p0[2], 0.0);

    // Set weight = 1.0 -> V0 becomes (0, 0.5, 0)
    vm.setMorphWeight('smile', 1.0);
    expect(vm.activeMorphTargetCount, 1);
    final p1 = vm.deformedPositions();
    expect(p1[0], 0.0);
    expect(p1[1], 0.5);
    expect(p1[2], 0.0);
    expect(identical(p0, p1), isTrue, reason: 'deformedPositions() must reuse the same Float32List instance');

    // Set weight = 0.5 -> V0 becomes (0, 0.25, 0)
    vm.setMorphWeight('smile', 0.5);
    final p2 = vm.deformedPositions();
    expect(p2[1], 0.25);
  });

  test('SkeletalMeshEditorViewModel skin weight heatmap colors and vertex influences', () async {
    final glbBytes = buildGlbWithMorphsAndSkin();
    final assetFile = File('${tempDir.path}/SK_Hero.lmas');
    final asset = LuminaAsset(
      assetId: 'SK_Hero',
      name: 'SK_Hero',
      type: AssetType.filamesh,
      rawPayload: glbBytes,
    );
    assetFile.writeAsBytesSync(asset.toProtoBufferBytes());

    final vm = SkeletalMeshEditorViewModel(assetPath: assetFile.path, initialAsset: asset);
    await vm.load();

    // Heatmap disabled -> returns null
    expect(vm.heatmapColors(0), isNull);

    // Enable heatmap
    vm.toggleHeatmap();
    expect(vm.heatmapEnabled, isTrue);

    // Bone 0: V0 has weight 1.0 -> Red (r=255, g=0, b=0), V1 has weight 0.0 -> Blue (r=0, g=0, b=255)
    final colors0 = vm.heatmapColors(0);
    expect(colors0, isNotNull);
    // V0 (offset 0)
    expect(colors0![0], 255); // Red
    expect(colors0[2], 0);
    // V1 (offset 3)
    expect(colors0[3], 0);
    expect(colors0[5], 255); // Blue

    // Bone 1: V0 has weight 0.0 -> Blue, V1 has weight 1.0 -> Red
    final colors1 = vm.heatmapColors(1);
    expect(colors1, isNotNull);
    // V0 (offset 0)
    expect(colors1![0], 0);
    expect(colors1[2], 255); // Blue
    // V1 (offset 3)
    expect(colors1[3], 255); // Red
    expect(colors1[5], 0);

    // Vertex Influences table for V0
    final influences0 = vm.getVertexInfluences(0);
    expect(influences0.values.first, 1.0);
    expect(vm.getVertexWeightSum(0), 1.0);

    // Vertex Influences table for V2 (sanitized/normalized to 1.0)
    expect(vm.getVertexWeightSum(2), closeTo(1.0, 1e-4));
  });

  test('SkeletalMeshEditorViewModel morph defaults persistence round-trip', () async {
    final glbBytes = buildGlbWithMorphsAndSkin();
    final assetFile = File('${tempDir.path}/SK_Hero.lmas');
    final asset = LuminaAsset(
      assetId: 'SK_Hero',
      name: 'SK_Hero',
      type: AssetType.filamesh,
      rawPayload: glbBytes,
    );
    assetFile.writeAsBytesSync(asset.toProtoBufferBytes());

    final vm = SkeletalMeshEditorViewModel(assetPath: assetFile.path, initialAsset: asset);
    await vm.load();

    vm.setMorphWeight('smile', 0.7);
    await vm.save();

    // Re-read file from disk
    final reloaded = LuminaAsset.fromBytes(assetFile.readAsBytesSync());
    expect(reloaded.metadata.containsKey('morph_defaults'), isTrue);
    final morphMap = jsonDecode(reloaded.metadata['morph_defaults']!) as Map;
    expect(morphMap['smile'], 0.7);

    // New ViewModel load verifies round-trip
    final vm2 = SkeletalMeshEditorViewModel(assetPath: assetFile.path);
    await vm2.load();
    expect(vm2.morphWeights['smile'], 0.7);
  });
}
