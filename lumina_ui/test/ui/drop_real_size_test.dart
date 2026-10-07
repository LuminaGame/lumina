import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/features/main_editor/services/viewport_picker.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';

/// A dropped glTF mesh spawns at scale 1 and appears at its real
/// size: glTF is metres and the centimetre world draws it ×100 (no span
/// heuristic).
void main() {
  test('dropping the barrel spawns scale 1 at its real centimetre height', () async {
    final glb = File('${Directory.current.parent.path}/test-assets/Props/Barrels/fuel_barrel_red.glb');
    if (!glb.existsSync()) return markTestSkipped('needs test-assets/Props/Barrels/fuel_barrel_red.glb');
    final root = Directory.systemTemp.createTempSync('lumina_drop_size_');
    addTearDown(() => root.deleteSync(recursive: true));
    final vm = EditorViewModel(projectLocation: root.path, enableTimers: false, autoInitAssets: false);
    addTearDown(vm.dispose);
    await vm.processImportPipeline(sourceFilePath: glb.path);
    vm.refreshAssets();
    final mesh = vm.realAssets.firstWhere((a) => a.type == AssetType.filamesh);

    await vm.spawnActorFromAsset(mesh, location: [0.0, 0.0, 0.0]);
    final actor = vm.actors.last;
    expect(actor.scale, [1.0, 1.0, 1.0], reason: 'no ×100 guess: the asset unit scale does it');
    final box = ViewportPicker.editorSpaceBounds(actor)!;
    final height = box.max.z - box.min.z;
    expect(height, inInclusiveRange(50.0, 200.0), reason: 'a barrel is about a metre tall, got $height cm');
  });
}
