import 'dart:io';
import 'package:flutter/material.dart' show Shortcuts; 
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/content_browser_widget.dart';

void main() {
  group('Content Browser Search, Filters, & Collections', () {
    late Directory tempDir;
    late EditorViewModel vm;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('lumina_cb_test_');
      
      final contents = Directory('${tempDir.path}/MyFirstLuminaGame/contents')..createSync(recursive: true);
      Directory('${contents.path}/meshes/static').createSync(recursive: true);
      Directory('${contents.path}/textures/mannequin').createSync(recursive: true);
      Directory('${contents.path}/materials').createSync(recursive: true);
      Directory('${contents.path}/blueprints').createSync(recursive: true);

      _createDummyAsset(contents.path, 'meshes/static/mesh1.lmas', AssetType.filamesh, 1024, metadata: {'format': 'GLB'});
      _createDummyAsset(contents.path, 'textures/mannequin/tex1.lmas', AssetType.texture, 512, metadata: {'parentMesh': 'mannequin'});
      _createDummyAsset(contents.path, 'materials/mat1.lmas', AssetType.filamat, 256);
      _createDummyAsset(contents.path, 'blueprints/bp1.lmas', AssetType.actor, 2048);
      
      vm = EditorViewModel(projectDirPath: tempDir.path, enableTimers: false, autoInitAssets: false);
      vm.refreshAssets();
      // The root lists its own folder only; Show All lists the project as these filter tests expect.
      vm.showAllAssets = true;
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('Source folders tree lists real nested folders, not hardcoded', () {
      final folders = vm.sourceFolders;
      expect(folders, contains('contents/meshes/static'));
      expect(folders, contains('contents/textures/mannequin'));
      
      vm.selectedFolder = 'contents/textures/mannequin';
      expect(vm.visibleAssets.length, 1);
      expect(vm.visibleAssets.first.fileName, 'tex1.lmas');
    });

    test('Chip correctness regression', () {
      vm.activeTypeFilters = {AssetType.filamat};
      expect(vm.visibleAssets.every((a) => a.type == AssetType.filamat), isTrue);
      expect(vm.visibleAssets.length, 1);
      expect(vm.visibleAssets.first.fileName, 'mat1.lmas');
      
      vm.activeTypeFilters = {AssetType.actor};
      expect(vm.visibleAssets.every((a) => a.type == AssetType.actor), isTrue);
      expect(vm.visibleAssets.length, 1);
      
      vm.activeTypeFilters = {AssetType.filamesh, AssetType.texture};
      expect(vm.visibleAssets.length, 2);
    });

    test('Metadata search', () {
      vm.searchQuery = 'mannequin';
      expect(vm.visibleAssets.length, 1);
      expect(vm.visibleAssets.first.fileName, 'tex1.lmas');
      
      vm.searchQuery = 'zero_hits_expected';
      expect(vm.visibleAssets, isEmpty);
    });

    test('Sort modes', () {
      vm.sortMode = 'Size ↓';
      final sortedBySize = vm.visibleAssets;
      expect(sortedBySize.first.bytes, greaterThanOrEqualTo(sortedBySize.last.bytes));
    });

    test('Collections persist and heal', () async {
      await vm.loadCollections();
      vm.createCollection('Props');
      vm.addToCollection('Props', vm.visibleAssets.first.assetId!);
      
      final vm2 = EditorViewModel(projectDirPath: tempDir.path, enableTimers: false, autoInitAssets: false);
      await vm2.loadCollections();
      expect(vm2.collections.any((c) => c.name == 'Props'), isTrue);
    });

    test('Recently Modified smart view', () {
      final recent = vm.recentlyModified(2);
      expect(recent.length, 2);
    });
  });
}

void _createDummyAsset(String basePath, String relPath, AssetType type, int size, {Map<String, String>? metadata}) {
  final file = File('$basePath/$relPath');
  final asset = LuminaAsset(
    assetId: relPath.replaceAll('/', '_'),
    name: relPath.split('/').last,
    type: type,
    metadata: metadata ?? {},
    rawPayload: size > 0 ? Uint8List(size) : null,
  );
  file.writeAsBytesSync(asset.toProtoBufferBytes());
}
