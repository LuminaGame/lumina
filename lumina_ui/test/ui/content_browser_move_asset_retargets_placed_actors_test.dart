import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';

import '../helpers/temp_project.dart';

/// Dragging an asset onto a Content Browser folder
/// (`moveAssetToFolder`) must re-point the open level's actors that use it,
/// as Rename does — not only the files on disk.
void main() {
  final assets = Platform.environment['LUMINA_TEST_ASSETS'] ?? '${Directory.current.parent.path}/test-assets';
  final barrel = File('$assets/Props/Barrels/fuel_barrel_red.glb');
  final skip = barrel.existsSync() ? null : 'test-assets missing';

  test('a placed barrel follows its mesh into the folder it was dragged onto', () async {
    final root = Directory.systemTemp.createTempSync('lumina_bug112_');
    final dir = Directory('${root.path}/MoveGame')..createSync();
    Directory('${dir.path}/contents/levels').createSync(recursive: true);
    File('${dir.path}/MoveGame.lmproject').writeAsStringSync('{"project_name": "MoveGame", "active_level": "contents/levels/L_Main.lmas"}');
    final vm = EditorViewModel(
      initialProject: const LuminaProject(projectName: 'MoveGame', activeLevel: 'contents/levels/L_Main.lmas'),
      projectLocation: root.path,
      enableTimers: false,
      autoInitAssets: false,
    );
    addTearDown(() async {
      await vm.close();
      await deleteTempProject(root);
    });
    await vm.ensureDefaultLevelAssets();
    await vm.processImportPipeline(sourceFilePath: barrel.path);
    final mesh = vm.realAssets.firstWhere((a) => a.type == AssetType.filamesh && a.fileName == 'fuel_barrel_red.lmas');
    await vm.spawnActorFromAsset(mesh);
    final actor = vm.actors.last;
    expect(actor.meshAssetPath, isNotNull);

    await vm.moveAssetToFolder(mesh, 'contents/Props');

    final ref = actor.meshAssetPath!.replaceAll(r'\', '/');
    expect(ref, endsWith('contents/Props/fuel_barrel_red.lmas'), reason: 'the placed actor still points at the moved mesh');
    final file = RegExp(r'^([A-Za-z]:|/)').hasMatch(ref) ? File(ref) : File('${dir.path}/$ref');
    expect(file.existsSync(), isTrue);
  }, skip: skip);
}
