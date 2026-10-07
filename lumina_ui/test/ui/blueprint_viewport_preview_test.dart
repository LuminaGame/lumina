import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart' hide BoxShape;
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/blueprint_sub_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/sub_editor_3d_viewport.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../helpers/scaffold_game_project.dart';

/// The Blueprint editor's 3D Viewport showed the Material Editor's
/// preview sphere (with its shape selector) for BP_ThirdPersonCharacter: the
/// Quinn mesh `.lmas` of a Third Person project has no payload, so the
/// viewport got no mesh. It must build the Blueprint's actor the way Play
/// does, on a real scaffolded Third Person project.
void main() {
  late Directory root;
  late String dir;

  setUpAll(() async {
    root = Directory.systemTemp.createTempSync('lumina_bp_viewport_');
    dir = await scaffoldGameProject(root, name: 'bp_viewport', widgetLibrary: 'flutter');
  });
  tearDownAll(() => root.deleteSync(recursive: true));

  Future<void> frames(WidgetTester tester, [int n = 10]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
    }
  }

  testWidgets("BP_ThirdPersonCharacter's 3D Viewport shows the Blueprint's components, not the material preview sphere",
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(
        child: BlueprintSubEditor(
          assetName: LuminaThirdPersonContent.characterBlueprintName,
          assetPath: '$dir/${LuminaThirdPersonContent.characterBlueprintPath}',
        ),
      ),
    ));
    final state = tester.state<BlueprintSubEditorState>(find.byType(BlueprintSubEditor));
    for (var i = 0; i < 200 && state.viewModel.document.components.length < 5; i++) {
      await frames(tester, 1);
    }
    expect(state.viewModel.document.components.map((c) => c.name),
        containsAll(['CapsuleComponent', 'CameraBoom', 'FollowCamera', 'Mesh', 'CharacterMovement']));

    await tester.tap(find.text('3D Viewport'));
    await frames(tester);
    final viewport = tester.widget<SubEditor3DViewport>(find.byType(SubEditor3DViewport));
    expect(viewport.showShapeSelector, isFalse, reason: 'a Blueprint actor has no primitive shape selector');
    expect(viewport.onPreviewWorldReady, isNotNull,
        reason: 'the viewport must build the Blueprint actor in a preview world, not fall back to a sphere');

    // The actor Play would spawn, in the viewport's world.
    final dynamic vm = state.viewModel;
    for (var i = 0; i < 100 && !(vm.preview.isAttached as bool); i++) {
      await frames(tester, 1);
    }
    expect(vm.preview.isAttached as bool, isTrue, reason: 'the viewport handed its world to the Blueprint preview');
    expect(vm.preview.actor, isA<LuminaCharacter>());
    final mesh = vm.preview.componentFor('mesh');
    expect(mesh, isA<LuminaAnimatedMeshComponent>(), reason: 'the Mesh component draws its skeletal mesh');
    expect((mesh as LuminaAnimatedMeshComponent).meshAssetPath, '$dir/${LuminaThirdPersonContent.projectMeshGlbPath}',
        reason: 'SKM_Superhero_Female.lmas loads through its .entity.glb, as Play resolves it');
    const halfHeight = LuminaTemplateCharacterTuning.thirdPersonCapsuleHalfHeight;
    expect(mesh.worldLocation.y, closeTo(-halfHeight, 1e-6), reason: 'at its relative transform (cm, Z up → Y up)');
    expect(vm.preview.animInstanceFor('mesh'), isNotNull, reason: 'Mesh plays its Anim Class, ABP_Character');
    expect(vm.preview.animInstanceFor('mesh').currentState, 'Idle');

    // Capsule, spring arm and camera are drawn; the selected one highlighted.
    final ids = {for (final set in vm.preview.overlays) set.id as String};
    expect(ids, containsAll(['capsule', 'boom', 'camera']));
    await tester.tap(find.text('CameraBoom').first);
    await frames(tester, 3);
    final selected = {for (final set in vm.preview.overlays) if (set.selected as bool) set.id as String};
    expect(selected, {'boom'});

    await tester.pumpWidget(const SizedBox());
    await frames(tester, 3);
  });
}
