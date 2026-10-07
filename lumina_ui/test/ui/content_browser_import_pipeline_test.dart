import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';

import '../helpers/cc_body_asset.dart';

void main() {
  group('Content Browser Import Pipeline', () {
    late Directory tempProjectsDir;
    late Directory pDir;
    late AssetRepository assetRepo;

    setUp(() {
      tempProjectsDir = Directory.systemTemp.createTempSync('import_pipeline_test_');
      pDir = Directory('${tempProjectsDir.path}/SmokeProject');
      pDir.createSync(recursive: true);
      Directory('${pDir.path}/contents').createSync();
      
      assetRepo = AssetRepository();
    });

    tearDown(() {
      if (tempProjectsDir.existsSync()) {
        tempProjectsDir.deleteSync(recursive: true);
      }
    });

    test('Step 3: Auto-organize OFF creates sibling folders', () {
      final paths = assetRepo.resolveTargetPaths(
        projectPath: pDir.path,
        baseName: 'MyMesh',
        primaryType: AssetType.filamesh,
        autoOrganize: false,
        browserSelectedFolder: 'contents/custom_folder',
        extractedSubAssets: ['M_Mat1', 'T_Tex1'],
      );
      
      expect(paths['primary'], equals('contents/custom_folder/MyMesh.lmas'));
      expect(paths['M_Mat1'], equals('contents/custom_folder/materials/M_Mat1.lmas'));
      expect(paths['T_Tex1'], equals('contents/custom_folder/textures/T_Tex1.lmas'));
    });
    
    test('Step 3: Auto-organize ON routes correctly', () {
      final paths = assetRepo.resolveTargetPaths(
        projectPath: pDir.path,
        baseName: 'MyMesh',
        primaryType: AssetType.filamesh,
        autoOrganize: true,
        browserSelectedFolder: null,
        extractedSubAssets: ['M_Mat1', 'T_Tex1'],
      );
      
      expect(paths['primary'], equals('contents/meshes/static/MyMesh.lmas'));
      expect(paths['M_Mat1'], equals('contents/materials/MyMesh/M_Mat1.lmas'));
      expect(paths['T_Tex1'], equals('contents/textures/MyMesh/T_Tex1.lmas'));
    });

    test('Step 1: stageImport with generateLods logs honesty and returns no LODs', () async {
      final sourceFile = File('${tempProjectsDir.path}/test_mesh.glb');
      sourceFile.writeAsBytesSync([0x67, 0x6C, 0x54, 0x46, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]); // GLTF magic
      
      final result = await assetRepo.stageImport(
        projectPath: pDir.path, 
        sourceFilePath: sourceFile.path, 
        generateLods: true,
      );
      
      expect(result['stagedPath'], endsWith('test_mesh.glb'));
      expect(result['metadata']['lod_count'], isNull); 
    });

    test('Full Pipeline: Stage -> Convert -> Emit -> round trips', () async {
      final sourceFile = File('${tempProjectsDir.path}/test_mesh.glb');
      sourceFile.writeAsBytesSync([0x67, 0x6C, 0x54, 0x46, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]); // GLTF magic
      
      final info = await assetRepo.importExternalFile(
        projectPath: pDir.path, 
        sourceFilePath: sourceFile.path, 
        autoOrganize: true,
      );
      
      expect(info.fileName, equals('test_mesh.lmas'));
      
      final lmasFile = File(info.lmasPath!);
      expect(lmasFile.existsSync(), isTrue);
      
      final bytes = lmasFile.readAsBytesSync();
      expect(bytes.length, greaterThan(4));
      expect(bytes[0], equals(0x4C)); // L
      expect(bytes[1], equals(0x4D)); // M
      expect(bytes[2], equals(0x41)); // A
      expect(bytes[3], equals(0x53)); // S
      
      final asset = LuminaAsset.fromBytes(bytes);
      expect(asset.name, equals('test_mesh'));
      expect(asset.type, equals(AssetType.filamesh));
    });

    test('Import skeletal mesh GLB with embedded materials and textures', () async {
      // Found portably; skipped with the reason when absent.
      final body = CcBodyAsset.resolve(CcBodyAsset.male);
      if (body.file == null) return markTestSkipped(body.skipReason!);
      final realGlb = body.file!;

      final info = await assetRepo.importExternalFile(
        projectPath: pDir.path,
        sourceFilePath: realGlb.path,
        autoOrganize: true,
      );

      // 1. Mesh verification
      expect(info.type, equals(AssetType.filameshSk));
      expect(info.fileName, equals('CCMH_Body_Male.lmas'));
      expect(info.relativePath, equals('contents/meshes/skeletal/CCMH_Body_Male.lmas'));

      final meshLmas = File('${pDir.path}/contents/meshes/skeletal/CCMH_Body_Male.lmas');
      expect(meshLmas.existsSync(), isTrue);
      final meshAsset = LuminaAsset.fromBytes(meshLmas.readAsBytesSync());
      expect(meshAsset.type, equals(AssetType.filameshSk));
      expect(meshAsset.references.length, equals(1));
      expect(meshAsset.references.first.slotName, equals('material_slot_0'));
      expect(meshAsset.references.first.assetPath, contains('contents/materials/CCMH_Body_Male/'));

      // Companion GLB
      final companionGlb = File('${pDir.path}/contents/meshes/skeletal/CCMH_Body_Male.entity.glb');
      expect(companionGlb.existsSync(), isTrue);

      // 2. Material verification
      final matDir = Directory('${pDir.path}/contents/materials/CCMH_Body_Male');
      expect(matDir.existsSync(), isTrue);
      final matFiles = matDir.listSync().whereType<File>().where((f) => f.path.endsWith('.lmas')).toList();
      expect(matFiles.length, equals(1));

      final matAsset = LuminaAsset.fromBytes(matFiles.first.readAsBytesSync());
      expect(matAsset.type, equals(AssetType.filamat));
      expect(matAsset.rawMatSource, isNotEmpty);
      expect(matAsset.references.length, equals(4)); // baseColor, metallicRoughness, normal, specular
      final slotNames = matAsset.references.map((r) => r.slotName).toSet();
      expect(slotNames, containsAll(['baseColorMap', 'metallicRoughnessMap', 'normalMap', 'specularMap']));

      // 3. Texture verification
      final texDir = Directory('${pDir.path}/contents/textures/CCMH_Body_Male');
      expect(texDir.existsSync(), isTrue);
      final texLmasFiles = texDir.listSync().whereType<File>().where((f) => f.path.endsWith('.lmas')).toList();
      expect(texLmasFiles.length, equals(4));

      for (final tf in texLmasFiles) {
        final texAsset = LuminaAsset.fromBytes(tf.readAsBytesSync());
        expect(texAsset.type, equals(AssetType.texture));
        expect(texAsset.rawPayload, isNotNull);
        expect(texAsset.rawPayload!.length, greaterThan(1000));
        // PNG magic check
        expect(texAsset.rawPayload![0], equals(0x89));
        expect(texAsset.rawPayload![1], equals(0x50));
        expect(texAsset.rawPayload![2], equals(0x4E));
        expect(texAsset.rawPayload![3], equals(0x47));

        // Companion .png file
        final companionPng = File(tf.path.replaceAll(RegExp(r'\.lmas$'), '.png'));
        expect(companionPng.existsSync(), isTrue);
        expect(companionPng.lengthSync(), equals(texAsset.rawPayload!.length));
      }

      // 4. Scan Project Contents verification
      final allScanned = assetRepo.scanProjectContents(pDir.path);
      expect(allScanned.length, equals(6)); // 1 skeletal mesh + 1 material + 4 textures
    });

    test('EditorViewModel.processImportPipeline imports skeletal mesh GLB with materials and textures', () async {
      // Found portably; skipped with the reason when absent.
      final body = CcBodyAsset.resolve(CcBodyAsset.male);
      if (body.file == null) return markTestSkipped(body.skipReason!);
      final realGlb = body.file!;

      final vm = EditorViewModel(
        projectDirPath: pDir.path,
        enableTimers: false,
        autoInitAssets: false,
      );

      await vm.processImportPipeline(sourceFilePath: realGlb.path);

      expect(vm.realAssets.length, equals(6));
      final skmAsset = vm.realAssets.firstWhere((a) => a.type == AssetType.filameshSk);
      expect(skmAsset.fileName, equals('CCMH_Body_Male.lmas'));
      expect(skmAsset.references.length, equals(1));

      final matAsset = vm.realAssets.firstWhere((a) => a.type == AssetType.filamat);
      expect(matAsset.fileName, equals('M_Skin_Body_CCMH_CCMH_Body_Male.lmas'));
      expect(matAsset.references.length, equals(4));

      final texAssets = vm.realAssets.where((a) => a.type == AssetType.texture).toList();
      expect(texAssets.length, equals(4));
    });
  });
}
