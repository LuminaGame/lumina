import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';

/// What the outliner hides, Play does not show: an actor hidden itself or
/// through a folder above it is spawned hidden, and the editor's own actors
/// keep their flags.
void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('lumina_pie_hidden_');
    addTearDown(() => tempDir.deleteSync(recursive: true));
  });

  testWidgets('Play spawns outliner-hidden actors hidden, folders included', (tester) async {
    final vm = EditorViewModel(
      initialProject: const LuminaProject(projectName: 'HiddenGame', activeLevel: 'contents/levels/L_Main.lmas'),
      projectLocation: tempDir.path,
      enableTimers: false,
      autoInitAssets: false,
    );
    addTearDown(vm.dispose);
    await tester.runAsync(vm.ensureDefaultLevelAssets);
    vm.restoreSnapshot([
      EditorActorNode(id: 'start', name: 'PlayerStart', type: 'PlayerStart', location: [0.0, 0.0, 0.0]),
      EditorActorNode(id: 'props', name: 'Props', type: 'Folder', location: [0.0, 0.0, 0.0], isVisible: false),
      EditorActorNode(
        id: 'crate',
        name: 'Crate',
        type: 'StaticMesh',
        parentId: 'props',
        location: [100.0, 0.0, 0.0],
        meshAssetPath: 'contents/meshes/SM_Crate.lmas',
      ),
      EditorActorNode(
        id: 'barrel',
        name: 'Barrel',
        type: 'StaticMesh',
        location: [200.0, 0.0, 0.0],
        meshAssetPath: 'contents/meshes/SM_Barrel.lmas',
        isVisible: false,
      ),
      EditorActorNode(
        id: 'shown',
        name: 'Shown',
        type: 'StaticMesh',
        location: [300.0, 0.0, 0.0],
        meshAssetPath: 'contents/meshes/SM_Barrel.lmas',
      ),
    ]);
    expect(vm.isEffectivelyVisible('crate'), isFalse, reason: 'hidden through its folder');
    expect(vm.actors.firstWhere((a) => a.id == 'crate').isVisible, isTrue, reason: 'the editor keeps the child flag');

    final world = LuminaWorld();
    vm.pieController.startHeadlessForTest(world);
    LuminaActor runtimeOf(String id) => world.persistentLevel.actors.firstWhere((a) => a.key == LuminaObjectKey(id));
    expect(runtimeOf('crate').hiddenInGame, isTrue);
    expect(runtimeOf('crate').rootComponent.isVisible, isFalse);
    expect(runtimeOf('barrel').hiddenInGame, isTrue);
    expect(runtimeOf('shown').hiddenInGame, isFalse);
    expect(runtimeOf('shown').rootComponent.isVisible, isTrue);
    vm.pieController.stopHeadlessForTest();
    expect(vm.actors.firstWhere((a) => a.id == 'crate').isVisible, isTrue, reason: 'Play changed nothing in the editor');
  });
}
