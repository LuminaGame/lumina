// `openAssetEditorByPath` (MCP `open_asset_editor`, File → New
// Asset) opens every asset in the editor a Content Browser double-click opens
// — it used to send skeletal meshes, animations, Blueprints… to the Static
// Mesh editor.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/features/main_editor/services/asset_editor_category.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';

void main() {
  late Directory tmp;
  late EditorViewModel vm;
  late String projectDir;

  void writeAsset(String relativePath, AssetType type, {Map<String, String> metadata = const {}, Object? payload}) {
    final file = File('$projectDir/$relativePath')..parent.createSync(recursive: true);
    final name = relativePath.split('/').last.replaceAll('.lmas', '');
    file.writeAsBytesSync(LuminaAsset(
      assetId: 'id_$name',
      name: name,
      type: type,
      metadata: metadata,
      rawPayload: payload == null ? null : Uint8List.fromList(utf8.encode(jsonEncode(payload))),
    ).toProtoBufferBytes());
  }

  // What a Content Browser double-click opens for each asset
  // (content_browser_widget.dart `_openSubEditor`).
  const expected = <String, String>{
    'contents/meshes/static/SM_Barrel.lmas': 'Mesh',
    'contents/meshes/skeletal/SKM_Superhero_Female.lmas': 'Skeleton',
    'contents/animations/MF_Walk_Fwd.lmas': 'Animation',
    'contents/animations/ABP_Quinn.lmas': 'AnimBlueprint',
    'contents/animations/BS_Locomotion.lmas': 'BlendSpace',
    'contents/ui/WBP_Hud.lmas': 'Widget',
    'contents/particles/P_Sparks.lmas': 'Particle',
    'contents/physics/PHYS_Quinn.lmas': 'PhysicsAsset',
    'contents/cinematics/SEQ_Intro.lmas': 'Sequencer',
    'contents/materials/M_Rust.lmas': 'Material',
    'contents/textures/T_Rust.lmas': 'Texture',
    'contents/audio/A_Hit.lmas': 'Audio',
    'contents/landscapes/LS_Hills.lmas': 'Landscape',
    'contents/blueprints/BP_Door.lmas': 'Blueprint',
  };

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('open_asset_by_path_');
    projectDir = '${tmp.path}/OpenByPath';
    writeAsset('contents/meshes/static/SM_Barrel.lmas', AssetType.filamesh);
    writeAsset('contents/meshes/skeletal/SKM_Superhero_Female.lmas', AssetType.filameshSk);
    writeAsset('contents/animations/MF_Walk_Fwd.lmas', AssetType.animation);
    writeAsset('contents/animations/ABP_Quinn.lmas', AssetType.animBlueprint);
    writeAsset('contents/animations/BS_Locomotion.lmas', AssetType.blendSpace);
    writeAsset('contents/ui/WBP_Hud.lmas', AssetType.widget);
    writeAsset('contents/particles/P_Sparks.lmas', AssetType.particle);
    writeAsset('contents/physics/PHYS_Quinn.lmas', AssetType.physicsAsset);
    writeAsset('contents/cinematics/SEQ_Intro.lmas', AssetType.sequencer);
    writeAsset('contents/materials/M_Rust.lmas', AssetType.filamat);
    writeAsset('contents/textures/T_Rust.lmas', AssetType.texture);
    writeAsset('contents/audio/A_Hit.lmas', AssetType.audio);
    writeAsset('contents/landscapes/LS_Hills.lmas', AssetType.landscape);
    writeAsset('contents/blueprints/BP_Door.lmas', AssetType.actor,
        metadata: {'parent_class': 'LuminaActor'}, payload: {'kind': 'class', 'parent_class': 'LuminaActor'});
    writeAsset('contents/levels/L_Arena.lmas', AssetType.level);
    vm = EditorViewModel(
      initialProject: const LuminaProject(projectName: 'OpenByPath'),
      projectLocation: tmp.path,
      enableTimers: false,
      autoInitAssets: false,
    );
  });

  tearDown(() {
    vm.dispose();
    tmp.deleteSync(recursive: true);
  });

  test('each asset opens the editor a Content Browser double-click opens', () {
    for (final entry in expected.entries) {
      vm.openAssetEditorByPath(entry.key);
      expect(vm.currentTab.category, entry.value, reason: entry.key);
      expect(vm.currentTab.asset?.relativePath, entry.key);
    }
  });

  test('an absolute path opens the same editor as the relative one', () {
    vm.openAssetEditorByPath('$projectDir/contents/meshes/skeletal/SKM_Superhero_Female.lmas');
    expect(vm.currentTab.category, 'Skeleton');
  });

  test('both paths share one mapping: subEditorCategoryFor decides every scanned asset', () {
    vm.openAssetEditorByPath(expected.keys.first); // scans the project
    for (final asset in vm.realAssets.where((a) => a.type != AssetType.level)) {
      vm.openAssetEditorByPath(asset.relativePath);
      expect(vm.currentTab.category, subEditorCategoryFor(asset, extensions: vm.extensionRegistry), reason: asset.relativePath);
    }
  });

  test('a level opens in the level editor, as a double-click does', () {
    vm.openAssetEditorByPath('contents/levels/L_Arena.lmas');
    expect(vm.project.activeLevel, 'contents/levels/L_Arena.lmas');
    expect(vm.openTabs.where((t) => t.category == 'Level' && t.asset?.relativePath == 'contents/levels/L_Arena.lmas'), isEmpty,
        reason: 'no sub-editor tab for a level');
  });
}
