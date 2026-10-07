import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/material_slot_binding.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/skeletal_mesh_editor_view_model.dart';

/// Coverage for the Skeletal Mesh editor's material slots and textures.
///
/// Real temp project on disk, real `.lmas` containers, no mocks (NO_MOCK_DATA).
void main() {
  late Directory projectDir;

  setUp(() {
    projectDir = Directory.systemTemp.createTempSync('skel_mat_');
    Directory('${projectDir.path}/contents/materials').createSync(recursive: true);
    Directory('${projectDir.path}/contents/textures').createSync(recursive: true);
    Directory('${projectDir.path}/contents/meshes/skeletal').createSync(recursive: true);
  });

  tearDown(() {
    if (projectDir.existsSync()) projectDir.deleteSync(recursive: true);
  });

  /// Writes a skeletal mesh `.lmas` carrying a two-section skinned GLB.
  Future<File> writeMeshAsset({List<AssetReference> references = const []}) async {
    final file = File('${projectDir.path}/contents/meshes/skeletal/SK_Hero.lmas');
    final asset = LuminaAsset(
      assetId: 'SK_Hero',
      name: 'SK_Hero',
      type: AssetType.filamesh,
      rawPayload: _twoSectionSkinnedGlb(),
      references: references,
    );
    await file.writeAsBytes(asset.toProtoBufferBytes());
    return file;
  }

  Future<File> writeMaterial(String name, {String matSource = _basicMatSource}) async {
    final file = File('${projectDir.path}/contents/materials/$name.lmas');
    final asset = LuminaAsset(
      assetId: name,
      name: name,
      type: AssetType.filamat,
      rawMatSource: matSource,
    );
    await file.writeAsBytes(asset.toProtoBufferBytes());
    return file;
  }

  Future<File> writeTexture(String name) async {
    final file = File('${projectDir.path}/contents/textures/$name.lmas');
    final asset = LuminaAsset(
      assetId: name,
      name: name,
      type: AssetType.texture,
      rawPayload: Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]),
    );
    await file.writeAsBytes(asset.toProtoBufferBytes());
    return file;
  }

  group('SkeletalMeshEditorViewModel material slots', () {
    test('builds one slot per geometry section, all unbound', () async {
      final meshFile = await writeMeshAsset();

      final vm = SkeletalMeshEditorViewModel(assetPath: meshFile.path);
      await vm.load();

      expect(vm.materialSlots, hasLength(2));
      expect(vm.materialSlots.map((s) => s.slotName), equals(['element_0', 'element_1']));
      expect(vm.materialSlots.every((s) => s.assignedMaterialPath == null), isTrue);
    });

    test('reports the mesh\'s own material name for an unbound slot', () async {
      final meshFile = await writeMeshAsset();
      final vm = SkeletalMeshEditorViewModel(assetPath: meshFile.path);
      await vm.load();

      // An unbound slot is not "nothing applied" — the mesh ships its own
      // material, and the panel has to say which one, or the user cannot tell
      // what they are about to replace.
      expect(vm.materialSlots[0].sourceMaterialName, equals('Body'));
      expect(vm.materialSlots[1].sourceMaterialName, equals('Body'));
      expect(vm.materialSlots[0].effectiveMaterialLabel, equals('Body'));
    });

    test('collapses nothing when two sections share a GLB material name', () async {
      // Both primitives in the fixture point at materials named the same way on
      // purpose: slots are keyed by section index, never by material name.
      final meshFile = await writeMeshAsset();
      final vm = SkeletalMeshEditorViewModel(assetPath: meshFile.path);
      await vm.load();

      expect(vm.materialSlots, hasLength(2));
      expect(vm.materialSlots[0].index, 0);
      expect(vm.materialSlots[1].index, 1);
    });

    test('lists only FILAMAT assets from this project in the picker', () async {
      await writeMaterial('M_Skin');
      await writeMaterial('M_Cloth');
      await writeTexture('T_Diffuse');
      final meshFile = await writeMeshAsset();

      final vm = SkeletalMeshEditorViewModel(assetPath: meshFile.path);
      await vm.load();

      expect(
        vm.availableMaterials.map((m) => m.fileName).toSet(),
        equals({'M_Skin.lmas', 'M_Cloth.lmas'}),
      );
      expect(vm.availableTextures.map((t) => t.fileName).toSet(), equals({'T_Diffuse.lmas'}));
    });

    test('binding a material round-trips through the .lmas', () async {
      final matFile = await writeMaterial('M_Cloth');
      final meshFile = await writeMeshAsset();

      final vm = SkeletalMeshEditorViewModel(assetPath: meshFile.path);
      await vm.load();
      vm.assignMaterial(1, materialAssetPath: matFile.path, materialAssetId: 'M_Cloth');
      expect(vm.isDirty, isTrue);
      expect(await vm.save(), isTrue);
      expect(vm.isDirty, isFalse);

      final reloaded = SkeletalMeshEditorViewModel(assetPath: meshFile.path);
      await reloaded.load();

      expect(reloaded.materialSlots[0].assignedMaterialPath, isNull);
      expect(reloaded.materialSlots[1].assignedMaterialPath, equals(matFile.path));
      expect(reloaded.materialSlots[1].assignedMaterialId, equals('M_Cloth'));

      final onDisk = LuminaAsset.fromBytes(await meshFile.readAsBytes());
      final refs = onDisk.references.where((r) => r.slotName == 'element_1').toList();
      expect(refs, hasLength(1));
      expect(refs.single.assetId, equals('M_Cloth'));
    });

    test('merges pre-existing references and never duplicates them on re-save', () async {
      final matFile = await writeMaterial('M_Skin');
      final meshFile = await writeMeshAsset(
        references: [
          AssetReference(slotName: 'element_0', assetId: 'M_Skin', assetPath: matFile.path),
        ],
      );

      final vm = SkeletalMeshEditorViewModel(assetPath: meshFile.path);
      await vm.load();
      expect(vm.materialSlots[0].assignedMaterialId, equals('M_Skin'));
      expect(vm.materialSlots[1].assignedMaterialPath, isNull);

      await vm.save();
      await vm.save();

      final onDisk = LuminaAsset.fromBytes(await meshFile.readAsBytes());
      expect(onDisk.references.where((r) => r.slotName == 'element_0'), hasLength(1));
    });

    test('exposes the bound material\'s declared samplers, and nothing else', () async {
      final matFile = await writeMaterial(
        'M_Skin',
        matSource: '''
material {
    name : Skin,
    parameters : [
        { type : sampler2d, name : baseColorMap },
        { type : sampler2d, name : roughnessMap },
        { type : float, name : roughness }
    ],
    shadingModel : lit
}
''',
      );
      final meshFile = await writeMeshAsset();

      final vm = SkeletalMeshEditorViewModel(assetPath: meshFile.path);
      await vm.load();

      expect(vm.samplerNamesForSlot(0), isEmpty, reason: 'unbound slot declares nothing');

      vm.assignMaterial(0, materialAssetPath: matFile.path, materialAssetId: 'M_Skin');
      await vm.refreshSlotSamplers();

      expect(vm.samplerNamesForSlot(0), equals(['baseColorMap', 'roughnessMap']));
      expect(
        vm.samplerNamesForSlot(0),
        isNot(contains('normalMap')),
        reason: 'a sampler the material does not declare must not be invented',
      );
    });

    test('texture override round-trips through metadata', () async {
      final matFile = await writeMaterial('M_Skin');
      final texFile = await writeTexture('T_Diffuse');
      final meshFile = await writeMeshAsset();

      final vm = SkeletalMeshEditorViewModel(assetPath: meshFile.path);
      await vm.load();
      vm.assignMaterial(0, materialAssetPath: matFile.path, materialAssetId: 'M_Skin');
      vm.assignTexture(0, 'baseColorMap', textureAssetPath: texFile.path, textureAssetId: 'T_Diffuse');
      await vm.save();

      final onDisk = LuminaAsset.fromBytes(await meshFile.readAsBytes());
      final overrides = jsonDecode(onDisk.metadata['materialTextures']!) as Map<String, dynamic>;
      expect(overrides['element_0/baseColorMap'], isA<Map>());
      expect((overrides['element_0/baseColorMap'] as Map)['assetId'], equals('T_Diffuse'));

      final reloaded = SkeletalMeshEditorViewModel(assetPath: meshFile.path);
      await reloaded.load();
      expect(
        reloaded.materialSlots[0].textureBindings['baseColorMap']?.assetPath,
        equals(texFile.path),
      );
    });

    test('a bound material already carrying compiled bytes reaches the preview', () async {
      // The viewport swaps these onto the section's primitive; without them,
      // picking a material changes the asset on disk and nothing on screen.
      final compiled = Uint8List.fromList([0x46, 0x49, 0x4C, 0x41, 0x07, 0x07]);
      final matFile = File('${projectDir.path}/contents/materials/M_Compiled.lmas');
      matFile.writeAsBytesSync(
        LuminaAsset(
          assetId: 'M_Compiled',
          name: 'M_Compiled',
          type: AssetType.filamat,
          rawMatSource: _basicMatSource,
          rawPayload: compiled,
        ).toProtoBufferBytes(),
      );
      final meshFile = await writeMeshAsset();

      final vm = SkeletalMeshEditorViewModel(assetPath: meshFile.path);
      await vm.load();
      expect(vm.slotCompiledMaterials, isEmpty);

      vm.assignMaterial(1, materialAssetPath: matFile.path, materialAssetId: 'M_Compiled');
      await vm.refreshSlotMaterials();

      expect(vm.slotCompiledMaterials.keys, equals({1}));
      expect(vm.slotCompiledMaterials[1], equals(compiled));

      vm.clearMaterial(1);
      await vm.refreshSlotMaterials();
      expect(vm.slotCompiledMaterials, isEmpty);
    });

    test('highlight targets exactly one slot', () async {
      final meshFile = await writeMeshAsset();
      final vm = SkeletalMeshEditorViewModel(assetPath: meshFile.path);
      await vm.load();

      vm.highlightMaterial(1, true);

      expect(vm.materialSlots[0].isHighlighted, isFalse);
      expect(vm.materialSlots[1].isHighlighted, isTrue);
      expect(
        vm.highlightedSectionIndices,
        equals({1}),
        reason: 'the preview tints exactly the highlighted section',
      );
    });

    test('isolating a slot marks the others hidden and restores them', () async {
      final meshFile = await writeMeshAsset();
      final vm = SkeletalMeshEditorViewModel(assetPath: meshFile.path);
      await vm.load();

      vm.isolateMaterial(1, true);
      expect(vm.materialSlots[1].isIsolated, isTrue);
      expect(vm.hiddenSectionIndices, equals({0}));

      vm.isolateMaterial(1, false);
      expect(vm.hiddenSectionIndices, isEmpty);
    });

    test('binding changes mark the view model dirty', () async {
      final matFile = await writeMaterial('M_Skin');
      final meshFile = await writeMeshAsset();
      final vm = SkeletalMeshEditorViewModel(assetPath: meshFile.path);
      await vm.load();

      expect(vm.isDirty, isFalse);
      vm.assignMaterial(0, materialAssetPath: matFile.path, materialAssetId: 'M_Skin');
      expect(vm.isDirty, isTrue);
    });
  });

  group('MaterialSlotBinding shared model', () {
    test('is importable from its own file and carries texture bindings', () {
      final slot = MaterialSlotBinding(index: 0, slotName: 'element_0');
      expect(slot.textureBindings, isEmpty);

      slot.textureBindings['baseColorMap'] =
          const MaterialTextureBinding(assetId: 'T', assetPath: '/tmp/T.lmas');
      expect(slot.textureBindings['baseColorMap']!.assetId, equals('T'));
    });
  });
}

const String _basicMatSource = '''
material {
    name : Basic,
    parameters : [
        { type : sampler2d, name : baseColorMap }
    ],
    shadingModel : lit
}
''';

/// A skinned GLB with two primitives, each pointing at its own material, so the
/// parser produces two sub-primitives.
Uint8List _twoSectionSkinnedGlb() {
  final positions = Float32List.fromList([
    0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, //
    0.0, 0.0, 1.0, 1.0, 0.0, 1.0, 0.0, 1.0, 1.0,
  ]);
  final bin = positions.buffer.asUint8List();

  final gltf = {
    'asset': {'version': '2.0'},
    'nodes': [
      {
        'name': 'Armature',
        'children': [1, 3],
      },
      {
        'name': 'pelvis',
        'children': [2],
      },
      {'name': 'spine_01'},
      {'name': 'CharacterMesh', 'mesh': 0},
    ],
    'scenes': [
      {
        'nodes': [0],
      }
    ],
    'scene': 0,
    'meshes': [
      {
        'name': 'Mesh0',
        'primitives': [
          {
            'attributes': {'POSITION': 0},
            'material': 0,
          },
          {
            'attributes': {'POSITION': 1},
            'material': 1,
          },
        ],
      }
    ],
    'materials': [
      {'name': 'Body'},
      {'name': 'Body'},
    ],
    'accessors': [
      {
        'bufferView': 0,
        'componentType': 5126,
        'count': 3,
        'type': 'VEC3',
        'min': [0.0, 0.0, 0.0],
        'max': [1.0, 1.0, 0.0],
      },
      {
        'bufferView': 1,
        'componentType': 5126,
        'count': 3,
        'type': 'VEC3',
        'min': [0.0, 0.0, 1.0],
        'max': [1.0, 1.0, 1.0],
      },
    ],
    'bufferViews': [
      {'buffer': 0, 'byteOffset': 0, 'byteLength': 36},
      {'buffer': 0, 'byteOffset': 36, 'byteLength': 36},
    ],
    'buffers': [
      {'byteLength': bin.length},
    ],
    'skins': [
      {
        'name': 'ArmatureSkin',
        'joints': [1, 2],
      }
    ],
  };

  final jsonBytes = utf8.encode(jsonEncode(gltf));
  final jsonPadded = (jsonBytes.length + 3) & ~3;
  final jsonChunk = Uint8List(jsonPadded)
    ..fillRange(0, jsonPadded, 0x20)
    ..setRange(0, jsonBytes.length, jsonBytes);

  final binPadded = (bin.length + 3) & ~3;
  final binChunk = Uint8List(binPadded)..setRange(0, bin.length, bin);

  final total = 12 + 8 + jsonPadded + 8 + binPadded;
  final glb = Uint8List(total);
  final bd = ByteData.sublistView(glb);

  bd.setUint32(0, 0x46546C67, Endian.little);
  bd.setUint32(4, 2, Endian.little);
  bd.setUint32(8, total, Endian.little);
  bd.setUint32(12, jsonPadded, Endian.little);
  bd.setUint32(16, 0x4E4F534A, Endian.little);
  glb.setRange(20, 20 + jsonPadded, jsonChunk);

  final binHeader = 20 + jsonPadded;
  bd.setUint32(binHeader, binPadded, Endian.little);
  bd.setUint32(binHeader + 4, 0x004E4942, Endian.little);
  glb.setRange(binHeader + 8, binHeader + 8 + binPadded, binChunk);

  return glb;
}
