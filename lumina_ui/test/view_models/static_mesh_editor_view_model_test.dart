import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/data/models/lumina_asset.dart';
import 'package:lumina/data/repositories/asset_repository.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/static_mesh_collision.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/static_mesh_editor_view_model.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('static_mesh_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('StaticMeshEditorViewModel Tests', () {
    test('Stats: parses geometry stats and bounds accurately from asset', () async {
      final assetFile = File('${tempDir.path}/SM_Cube.lmas');
      
      final asset = LuminaAsset(
        assetId: 'SM_Cube',
        name: 'SM_Cube',
        type: AssetType.filamesh,
        metadata: {
          'triangle_count': '12',
          'vertex_count': '8',
          'uv_channels': '1',
          'sections': '1',
          'min_bounds': '-0.5,-0.5,-0.5',
          'max_bounds': '0.5,0.5,0.5',
        },
      );
      await assetFile.writeAsBytes(asset.toProtoBufferBytes());

      final vm = StaticMeshEditorViewModel(assetPath: assetFile.path, initialAsset: asset);
      await vm.load();

      expect(vm.triangleCount, 12);
      expect(vm.vertexCount, 8);
      expect(vm.uvChannelsCount, 1);
      expect(vm.sectionCount, 1);
      // cm, Z up: the 1 m cube is 100 cm on each side.
      expect(vm.boundsWidth, closeTo(100.0, 0.001));
      expect(vm.boundsDepth, closeTo(100.0, 0.001));
      expect(vm.boundsHeight, closeTo(100.0, 0.001));
    });

    test('Missing asset: handles missing file cleanly without scanning other paths', () async {
      final missingFile = File('${tempDir.path}/NonExistent.lmas');
      final vm = StaticMeshEditorViewModel(assetPath: missingFile.path);
      await vm.load();

      expect(vm.hasError, isTrue);
      expect(vm.triangleCount, 0);
      expect(vm.vertexCount, 0);
    });

    test('Slot binding: assignMaterial updates references and persists to disk', () async {
      final assetFile = File('${tempDir.path}/SM_Props.lmas');
      final asset = LuminaAsset(
        assetId: 'SM_Props',
        name: 'SM_Props',
        type: AssetType.filamesh,
        metadata: {'sections': '2'},
      );
      await assetFile.writeAsBytes(asset.toProtoBufferBytes());

      final vm = StaticMeshEditorViewModel(assetPath: assetFile.path, initialAsset: asset);
      await vm.load();

      vm.assignMaterial(0, materialAssetPath: 'contents/materials/M_Wood.lmas', materialAssetId: 'M_Wood');
      expect(vm.materialSlots[0].assignedMaterialPath, 'contents/materials/M_Wood.lmas');
      expect(vm.isDirty, isTrue);

      await vm.save();

      // Reload from disk
      final reloaded = StaticMeshEditorViewModel(assetPath: assetFile.path);
      await reloaded.load();
      expect(reloaded.materialSlots[0].assignedMaterialPath, 'contents/materials/M_Wood.lmas');
      expect(reloaded.materialSlots[0].assignedMaterialId, 'M_Wood');
    });

    test('Box collision: generates box shape from AABB and persists', () async {
      final assetFile = File('${tempDir.path}/SM_BoxTest.lmas');
      final asset = LuminaAsset(
        assetId: 'SM_BoxTest',
        name: 'SM_BoxTest',
        type: AssetType.filamesh,
        metadata: {
          'min_bounds': '-1.0,-1.0,-1.0',
          'max_bounds': '1.0,1.0,1.0',
        },
      );
      await assetFile.writeAsBytes(asset.toProtoBufferBytes());

      final vm = StaticMeshEditorViewModel(assetPath: assetFile.path, initialAsset: asset);
      await vm.load();

      vm.generateCollision(StaticMeshCollisionShapeType.box);
      expect(vm.collisionShapes.length, 1);
      final box = vm.collisionShapes.first;
      expect(box.type, StaticMeshCollisionShapeType.box);
      expect(box.center, [0.0, 0.0, 0.0]);
      expect(box.extents, [100.0, 100.0, 100.0], reason: 'cm');

      await vm.save();

      // Reload
      final reloaded = StaticMeshEditorViewModel(assetPath: assetFile.path);
      await reloaded.load();
      expect(reloaded.collisionShapes.length, 1);
      expect(reloaded.collisionShapes.first.type, StaticMeshCollisionShapeType.box);

      // Remove collision
      reloaded.removeCollision();
      expect(reloaded.collisionShapes.isEmpty, isTrue);
      await reloaded.save();

      final reloaded2 = StaticMeshEditorViewModel(assetPath: assetFile.path);
      await reloaded2.load();
      expect(reloaded2.collisionShapes.isEmpty, isTrue);
    });

    test('Capsule collision on elongated mesh selects dominant axis', () async {
      final assetFile = File('${tempDir.path}/SM_Pillar.lmas');
      final asset = LuminaAsset(
        assetId: 'SM_Pillar',
        name: 'SM_Pillar',
        type: AssetType.filamesh,
        // GLB bounds (metres, Y up): 2 m tall along glTF +Y.
        metadata: {
          'min_bounds': '-0.1,-1.0,-0.1',
          'max_bounds': '0.1,1.0,0.1',
        },
      );
      await assetFile.writeAsBytes(asset.toProtoBufferBytes());

      final vm = StaticMeshEditorViewModel(assetPath: assetFile.path, initialAsset: asset);
      await vm.load();

      vm.generateCollision(StaticMeshCollisionShapeType.capsule);
      expect(vm.collisionShapes.length, 1);
      final cap = vm.collisionShapes.first;
      expect(cap.type, StaticMeshCollisionShapeType.capsule);
      // cm, and the tall axis is authored Z.
      expect(cap.radius, closeTo(10, 0.01));
      expect(cap.halfHeight, closeTo(90, 0.01));
      expect(cap.axis, 'Z');
    });

    test('Physics properties: mass and center of mass persist to disk', () async {
      final assetFile = File('${tempDir.path}/SM_Phys.lmas');
      final asset = LuminaAsset(assetId: 'SM_Phys', name: 'SM_Phys', type: AssetType.filamesh);
      await assetFile.writeAsBytes(asset.toProtoBufferBytes());

      final vm = StaticMeshEditorViewModel(assetPath: assetFile.path, initialAsset: asset);
      await vm.load();

      vm.setMass(12.5);
      vm.setCenterOfMassOffset([0.0, 0.5, 0.0]);
      vm.setCollisionComplexity('use_complex_as_simple');

      await vm.save();

      final reloaded = StaticMeshEditorViewModel(assetPath: assetFile.path);
      await reloaded.load();
      expect(reloaded.massKg, 12.5);
      expect(reloaded.centerOfMassOffset, [0.0, 0.5, 0.0]);
      expect(reloaded.collisionComplexity, 'use_complex_as_simple');
    });
  });

  // The import binds a mesh's materials as `material_slot_<n>`; the
  // editor read only `element_<n>` and rebuilt `references` from its slots on
  // Save, so an imported mesh opened unbound and Save deleted the import's links.
  group('an imported mesh keeps its material references', () {
    final barrel = '${Directory.current.parent.path}/test-assets/Props/Barrels/empty_barrel.glb';
    late String meshPath;
    late AssetReference importedRef;

    setUp(() async {
      if (!File(barrel).existsSync()) return;
      final info = await AssetRepository().importExternalFile(projectPath: tempDir.path, sourceFilePath: barrel);
      meshPath = '${tempDir.path}/${info.relativePath}';
      importedRef = LuminaAsset.fromBytes(File(meshPath).readAsBytesSync()).references.single;
    });

    List<AssetReference> referencesOnDisk() => LuminaAsset.fromBytes(File(meshPath).readAsBytesSync()).references;

    test('the slot shows the material the import bound, and Save keeps it', () async {
      if (!File(barrel).existsSync()) return markTestSkipped('needs test-assets/Props/Barrels');
      expect(importedRef.slotName, 'material_slot_0', reason: 'the import convention this test guards');

      final vm = StaticMeshEditorViewModel(assetPath: meshPath);
      await vm.load();
      expect(vm.materialSlots.first.assignedMaterialPath, importedRef.assetPath);
      expect(vm.materialSlots.first.assignedMaterialId, importedRef.assetId);

      vm.setMass(20);
      await vm.save();

      final refs = referencesOnDisk();
      expect(refs.map((r) => r.assetPath), [importedRef.assetPath],
          reason: 'Save must not delete the material the mesh uses, nor duplicate it');
      final reloaded = StaticMeshEditorViewModel(assetPath: meshPath);
      await reloaded.load();
      expect(reloaded.materialSlots.first.assignedMaterialPath, importedRef.assetPath);
    });

    test('clearing the slot really unbinds it; references and the thumbnail it does not own survive', () async {
      if (!File(barrel).existsSync()) return markTestSkipped('needs test-assets/Props/Barrels');
      // A reference the static mesh editor knows nothing about, and a real PNG
      // (one of the textures the import wrote) as the asset's thumbnail.
      final png = Directory('${tempDir.path}/contents/textures')
          .listSync(recursive: true)
          .whereType<File>()
          .firstWhere((f) => f.path.endsWith('.png'))
          .readAsBytesSync();
      final asset = LuminaAsset.fromBytes(File(meshPath).readAsBytesSync());
      File(meshPath).writeAsBytesSync(LuminaAsset(
        assetId: asset.assetId,
        name: asset.name,
        type: asset.type,
        hasThumbnail: true,
        thumbnailPng: png,
        rawPayload: asset.rawPayload,
        metadata: asset.metadata,
        references: [...asset.references, const AssetReference(slotName: 'physics_asset', assetId: 'PHYS_Barrel', assetPath: 'contents/physics/PHYS_Barrel.lmas')],
      ).toProtoBufferBytes());

      final vm = StaticMeshEditorViewModel(assetPath: meshPath);
      await vm.load();
      vm.clearMaterial(0);
      await vm.save();

      final refs = referencesOnDisk();
      expect(refs.map((r) => r.slotName), ['physics_asset']);
      final saved = LuminaAsset.fromBytes(File(meshPath).readAsBytesSync());
      expect(saved.hasThumbnail, isTrue, reason: 'Save must not drop the Content Browser thumbnail');
      expect(saved.thumbnailPng, png);
      final reloaded = StaticMeshEditorViewModel(assetPath: meshPath);
      await reloaded.load();
      expect(reloaded.materialSlots.first.assignedMaterialPath, isNull, reason: 'a cleared slot stays cleared');
    });
  });
}
