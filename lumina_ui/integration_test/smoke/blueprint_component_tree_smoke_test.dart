import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart' hide BoxShape;
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/blueprint_sub_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/component_tree.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../test/helpers/scaffold_game_project.dart';

/// Smoke: the Blueprint Components panel, built like the World Outliner,
/// attaches components by drag and drop in BP_ThirdPersonCharacter (the
/// Third Person template's mannequin): the follow camera dragged off the
/// boom onto the empty area goes to the root and back onto the boom, and the
/// mannequin's Mesh dragged onto the boom follows it in the 3D Viewport, then
/// back onto the capsule. Runs on GPU 1.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const testName = 'Blueprint Component Tree Smoke: components attach by drag and drop as in the World Outliner';
  const usedAssets = ['mannequin/SKM_Superhero_Female.glb (the Third Person template mannequin)'];

  testWidgets(testName, (tester) async {
    final root = Directory.systemTemp.createTempSync('lumina_smoke_bp_tree_');
    addTearDown(() => root.deleteSync(recursive: true));
    final projectDir =
        (await tester.runAsync(() => scaffoldGameProject(root, name: 'bp_tree_smoke', widgetLibrary: 'flutter')))!;
    final project = LuminaProject.fromMap(Map<String, dynamic>.from(
        jsonDecode(File('$projectDir/bp_tree_smoke.lmproject').readAsStringSync()) as Map));
    final vm = EditorViewModel(initialProject: project, projectLocation: root.path);
    addTearDown(vm.dispose);
    await tester.runAsync(vm.ensureDefaultLevelAssets);

    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<void> settle([int frames = 12]) async {
      for (var i = 0; i < frames; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
      }
    }

    final boundaryKey = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: boundaryKey,
      child: ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)),
    ));
    await settle(40);
    final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
    Future<void> shot(String name) async {
      final png = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
      SmokeArtifacts.saveScreenshot(name, png, usedAssets: usedAssets);
    }

    final asset = vm.realAssets.firstWhere((a) => a.relativePath == LuminaThirdPersonContent.characterBlueprintPath);
    vm.openSubEditorTab('Blueprint', asset: asset);
    await settle(20);
    final bp = tester.state<BlueprintSubEditorState>(find.byType(BlueprintSubEditor)).viewModel;
    for (var i = 0; i < 200 && bp.document.components.length < 5; i++) {
      await settle(2);
    }
    await tester.tap(find.text('3D Viewport'));
    for (var i = 0; i < 400 && !bp.preview.hasNativeWorld; i++) {
      await settle(2);
    }
    await rec.hold(const Duration(milliseconds: 1500));
    await shot('blueprint_component_tree_before');

    Finder row(String id) => find.descendant(
          of: find.byType(BlueprintComponentTree),
          matching: find.byKey(ValueKey('component_row_$id')),
        );
    Future<void> dragOnto(String id, Finder to) async {
      final from = tester.getCenter(row(id));
      final target = tester.getCenter(to);
      final g = await tester.startGesture(from);
      await rec.hold(const Duration(milliseconds: 150));
      for (var i = 1; i <= 30; i++) {
        await g.moveTo(Offset.lerp(from, target, i / 30)!);
        await rec.hold(const Duration(milliseconds: 25));
      }
      await rec.hold(const Duration(milliseconds: 300));
      await g.up();
      await rec.hold(const Duration(milliseconds: 1200));
    }

    expect(bp.getComponent('camera')!.parentId, 'boom');
    await dragOnto('camera', find.byKey(const ValueKey('components_empty_area')));
    expect(bp.getComponent('camera')!.parentId, bp.rootComponent!.id, reason: 'the empty area attaches to the root');
    await shot('blueprint_component_tree_camera_on_root');
    await dragOnto('camera', row('boom'));
    expect(bp.getComponent('camera')!.parentId, 'boom');

    final meshParent = bp.getComponent('mesh')!.parentId;
    await dragOnto('mesh', row('boom'));
    expect(bp.getComponent('mesh')!.parentId, 'boom');
    await rec.hold(const Duration(milliseconds: 1500));
    await shot('blueprint_component_tree_mesh_on_boom');
    await dragOnto('mesh', row(meshParent!));
    expect(bp.getComponent('mesh')!.parentId, meshParent);

    // The character's capsule: centred on the actor, so the Details panel
    // explains where the meshes go instead of offering a transform, and the
    // preview stands it (and the mannequin's feet) on the floor.
    await tester.tap(row('capsule'));
    await rec.hold(const Duration(milliseconds: 1200));
    expect(find.byKey(const ValueKey('character_capsule_transform_note')), findsOneWidget);
    expect(bp.preview.groundLift, greaterThan(0));
    await shot('blueprint_component_tree_character_capsule');
    while (rec.recorded < const Duration(milliseconds: 10500)) {
      await rec.hold(const Duration(milliseconds: 250));
    }
    await shot('blueprint_component_tree_after');
    rec.save(testName, usedAssets: usedAssets);
  });
}
