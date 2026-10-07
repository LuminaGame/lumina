import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';

/// Deleting an asset removed every level actor whose *name*
/// contained the asset's file name, left the actors that really referenced it
/// in place, and recorded no undo. No mocks: a real temp project and
/// a real GLB through the real import pipeline.
void main() {
  late Directory tempDir;
  late Directory projDir;
  final barrelGlb = File('${Directory.current.path}/../test-assets/Props/Barrels/fuel_barrel_red.glb');

  const project = LuminaProject(
    projectName: 'CascadeGame',
    activeLevel: 'contents/levels/L_Main.lmas',
  );

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('lumina_asset_delete_cascade_');
    projDir = Directory('${tempDir.path}/CascadeGame')..createSync(recursive: true);
    Directory('${projDir.path}/contents/levels').createSync(recursive: true);
    File('${projDir.path}/CascadeGame.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  EditorActorNode spawnPrimitiveNamed(EditorViewModel vm, String name) {
    vm.spawnNewActor('Primitive');
    final node = vm.actors.last;
    vm.renameActor(node.id, name);
    return node;
  }

  test('deleting an asset removes the actors that reference it, not the ones whose name matches, and undo restores them',
      () async {
    if (!barrelGlb.existsSync()) {
      markTestSkipped('test asset missing: ${barrelGlb.path}');
      return;
    }
    final vm = EditorViewModel(initialProject: project, projectLocation: tempDir.path, enableTimers: false);
    addTearDown(vm.dispose);
    await vm.ensureDefaultLevelAssets();

    await vm.processImportPipeline(sourceFilePath: barrelGlb.path);
    vm.refreshAssets();
    final asset = vm.realAssets.firstWhere((a) => a.fileName == 'fuel_barrel_red.lmas' && a.type == AssetType.filamesh);

    // The actor placed from the asset, renamed so its name no longer matches.
    await vm.spawnActorFromAsset(asset, location: [0, 0, 0]);
    final barrel = vm.actors.last;
    vm.renameActor(barrel.id, 'Barrel');
    expect(barrel.meshAssetPath, isNotNull, reason: 'the placed barrel references the asset');

    // Primitives whose names contain (or don't contain) the asset name.
    final marker = spawnPrimitiveNamed(vm, 'fuel_barrel_red_marker');
    final wall = spawnPrimitiveNamed(vm, 'Fuel_Barrel_Red_Wall');
    final crate = spawnPrimitiveNamed(vm, 'Crate_01');
    vm.selectActors([barrel.id, marker.id]);

    // What the delete confirmations list: exactly the referencing actor.
    expect(vm.actorsReferencingAssets([asset]).map((a) => a.id), [barrel.id]);

    final idsBefore = vm.actors.map((a) => a.id).toList();
    final removed = await vm.deleteAssetCascadeAndCleanScene(asset);
    expect(removed.map((a) => a.id), [barrel.id]);

    final ids = vm.actors.map((a) => a.id).toSet();
    expect(ids, containsAll([marker.id, wall.id, crate.id]),
        reason: 'primitives that merely share the name are not touched');
    expect(ids.contains(barrel.id), isFalse, reason: 'the actor that references the deleted asset is removed');
    expect(vm.selectedActorIds.contains(barrel.id), isFalse, reason: 'no dangling selection');
    expect(vm.selectedActorIds, contains(marker.id), reason: 'unaffected selection survives');

    // Edit → Undo puts the removed actor back, in place and still referencing its mesh path.
    expect(vm.transactions.canUndo, isTrue);
    vm.transactions.undo();
    expect(vm.actors.map((a) => a.id).toList(), idsBefore);
    final restored = vm.actors.firstWhere((a) => a.id == barrel.id);
    expect(restored.name, 'Barrel');
    expect(restored.meshAssetPath, barrel.meshAssetPath);
  });
}
