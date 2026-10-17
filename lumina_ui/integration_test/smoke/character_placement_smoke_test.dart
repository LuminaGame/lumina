import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart' hide BoxShape;
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/main_editor/views/viewport_widget.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../test/helpers/scaffold_game_project.dart';
import '../../test/helpers/temp_project.dart';

/// Smoke: a Character Blueprint dragged from the Content Browser onto the
/// level viewport stands on the ground: its origin, the capsule centre, is
/// placed a capsule half height above the drop point, so the Third Person
/// mannequin's feet rest on the floor (as Play stands it), not half under it.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const testName = 'Character Placement Smoke: a Character Blueprint dropped in the level stands on the ground';
  const usedAssets = ['mannequin/SKM_Superhero_Female.glb (the Third Person template mannequin)'];

  testWidgets(testName, (tester) async {
    final root = Directory.systemTemp.createTempSync('lumina_smoke_char_place_');
    // The editors' git probe may still hold the folder on Windows.
    addTearDown(() => deleteTempProject(root));
    final projectDir =
        (await tester.runAsync(() => scaffoldGameProject(root, name: 'char_place', widgetLibrary: 'flutter')))!;
    final project = LuminaProject.fromMap(
        Map<String, dynamic>.from(jsonDecode(File('$projectDir/char_place.lmproject').readAsStringSync()) as Map));
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

    // Open contents/blueprints in the Content Browser (double-click its folder).
    final folder = find.byKey(const ValueKey('folder_tile_contents/blueprints'));
    await tester.tap(folder);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tap(folder);
    await rec.hold(const Duration(milliseconds: 800));
    final tile = find.byWidgetPredicate(
        (w) => w is Draggable<RealAssetInfo> && w.data?.relativePath == LuminaThirdPersonContent.characterBlueprintPath);
    expect(tile, findsOneWidget, reason: 'the Content Browser shows BP_ThirdPersonCharacter');

    final before = vm.actors.length;
    final viewport = tester.getRect(find.byType(ViewportWidget));
    await rec.drag(tester.getCenter(tile), viewport.center + Offset(viewport.width * 0.1, viewport.height * 0.1), steps: 40);
    await rec.hold(const Duration(seconds: 2));
    expect(vm.actors.length, before + 1, reason: 'the drop placed the character');
    final placed = vm.actors.last;
    expect(placed.blueprintClass, LuminaThirdPersonContent.characterBlueprintPath);
    expect(placed.location[2], closeTo(LuminaTemplateCharacterTuning.thirdPersonCapsuleHalfHeight, 1e-6),
        reason: 'the capsule centre a half height above the floor: ${placed.location}');
    debugPrint('[char_place_smoke] placed at ${placed.location}');

    // Frame it and look around: the feet are on the grid.
    vm.focusCameraOnActor(placed);
    await rec.hold(const Duration(milliseconds: 800));
    // Pull back (the scroll-wheel dolly) until the whole figure and the floor show.
    while (vm.cameraDistance < 420.0) {
      vm.dollyCamera(12.0);
      await rec.hold(const Duration(milliseconds: 40));
    }
    await rec.hold(const Duration(milliseconds: 1200));
    await shot('character_placement_on_ground');
    final c = tester.getCenter(find.byType(ViewportWidget));
    final orbit = await tester.startGesture(c, buttons: 1);
    for (var i = 0; i < 60; i++) {
      await orbit.moveBy(const Offset(4, 0));
      await rec.hold(const Duration(milliseconds: 40));
    }
    await orbit.up();
    while (rec.recorded < const Duration(milliseconds: 10500)) {
      await rec.hold(const Duration(milliseconds: 250));
    }
    await shot('character_placement_on_ground_orbit');
    rec.save(testName, usedAssets: usedAssets);
  });
}
