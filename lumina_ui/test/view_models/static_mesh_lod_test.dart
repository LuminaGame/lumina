import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/static_mesh_collision.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/static_mesh_editor_view_model.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('static_mesh_lod_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('StaticMesh LOD Tests', () {
    test('LOD table round-trip: add LOD1 + LOD2 with override, save and reload intact', () async {
      final assetFile = File('${tempDir.path}/SM_LODTest.lmas');
      final asset = LuminaAsset(
        assetId: 'SM_LODTest',
        name: 'SM_LODTest',
        type: AssetType.filamesh,
        metadata: {
          'triangle_count': '1000',
          'vertex_count': '600',
          'sections': '1',
          'min_bounds': '-1,-1,-1',
          'max_bounds': '1,1,1',
        },
      );
      assetFile.writeAsBytesSync(asset.toProtoBufferBytes());

      final vm = StaticMeshEditorViewModel(assetPath: assetFile.path, initialAsset: asset);
      await vm.load();

      expect(vm.lods.length, 1);
      expect(vm.lods[0].level, 0);
      expect(vm.lods[0].reductionRatio, 1.0);

      // Add LOD1
      vm.addLod();
      expect(vm.lods.length, 2);
      expect(vm.lods[1].level, 1);
      expect(vm.lods[1].reductionRatio, closeTo(0.5, 0.01));

      // Add LOD2
      vm.addLod();
      expect(vm.lods.length, 3);
      expect(vm.lods[2].level, 2);

      // Set material override on LOD1
      vm.setLodMaterialOverride(1, 'element_0', 'contents/materials/M_Override.lmas');
      expect(vm.lods[1].materialOverrides['element_0'], 'contents/materials/M_Override.lmas');

      await vm.save();

      // Reload from disk
      final reloaded = StaticMeshEditorViewModel(assetPath: assetFile.path);
      await reloaded.load();

      expect(reloaded.lods.length, 3);
      expect(reloaded.lods[0].level, 0);
      expect(reloaded.lods[1].level, 1);
      expect(reloaded.lods[1].materialOverrides['element_0'], 'contents/materials/M_Override.lmas');
      expect(reloaded.lods[2].level, 2);
    });

    test('Threshold validation: screenSize must be strictly decreasing', () async {
      final assetFile = File('${tempDir.path}/SM_Threshold.lmas');
      final asset = LuminaAsset(
        assetId: 'SM_Threshold',
        name: 'SM_Threshold',
        type: AssetType.filamesh,
        metadata: {'triangle_count': '100', 'vertex_count': '50'},
      );
      assetFile.writeAsBytesSync(asset.toProtoBufferBytes());

      final vm = StaticMeshEditorViewModel(assetPath: assetFile.path, initialAsset: asset);
      await vm.load();

      vm.addLod(); // LOD1 (screenSize ~ 0.5)
      vm.addLod(); // LOD2 (screenSize ~ 0.25)

      // Invalid: Setting LOD2 screenSize higher than LOD1 (e.g. 0.8 > 0.5)
      final valid = vm.setLodScreenSize(2, 0.8);
      expect(valid, isFalse);

      // Valid: Setting LOD2 screenSize lower than LOD1 (e.g. 0.2 < 0.5)
      final valid2 = vm.setLodScreenSize(2, 0.2);
      expect(valid2, isTrue);
      expect(vm.lods[2].screenSize, 0.2);
    });

    test('Remove LOD: removing intermediate LOD reindexes remaining slots cleanly', () async {
      final assetFile = File('${tempDir.path}/SM_RemoveLOD.lmas');
      final asset = LuminaAsset(
        assetId: 'SM_RemoveLOD',
        name: 'SM_RemoveLOD',
        type: AssetType.filamesh,
        metadata: {'triangle_count': '500', 'vertex_count': '300'},
      );
      assetFile.writeAsBytesSync(asset.toProtoBufferBytes());

      final vm = StaticMeshEditorViewModel(assetPath: assetFile.path, initialAsset: asset);
      await vm.load();

      vm.addLod(); // LOD1
      vm.addLod(); // LOD2
      expect(vm.lods.length, 3);

      // Remove LOD1 -> LOD2 becomes LOD1
      vm.removeLod(1);
      expect(vm.lods.length, 2);
      expect(vm.lods[0].level, 0);
      expect(vm.lods[1].level, 1);
    });

    test('Forced LOD: setting and resetting forced LOD updates active preview index', () async {
      final assetFile = File('${tempDir.path}/SM_ForcedLOD.lmas');
      final asset = LuminaAsset(
        assetId: 'SM_ForcedLOD',
        name: 'SM_ForcedLOD',
        type: AssetType.filamesh,
        metadata: {'triangle_count': '500', 'vertex_count': '300'},
      );
      assetFile.writeAsBytesSync(asset.toProtoBufferBytes());

      final vm = StaticMeshEditorViewModel(assetPath: assetFile.path, initialAsset: asset);
      await vm.load();

      vm.addLod(); // LOD1
      expect(vm.forcedLod, isNull);

      vm.setForcedLod(1);
      expect(vm.forcedLod, 1);
      expect(vm.activePreviewLod.level, 1);

      vm.setForcedLod(null);
      expect(vm.forcedLod, isNull);
      expect(vm.activePreviewLod.level, 0);
    });
  });
}
