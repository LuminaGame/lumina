import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart' show kSecondaryMouseButton;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The editor viewport ticks while mounted, so `pumpAndSettle` never settles:
/// pump a bounded run of frames on the live clock instead.
Future<void> settle(WidgetTester tester, {int frames = 20}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const scenario = 'Content Browser Smoke Scenario: Rename and Duplicate an asset';
  testWidgets(scenario, (tester) async {
    // Asset cards had no Rename / Duplicate.
    const barrelRel = 'Props/Barrels/fuel_barrel_red.glb';
    const airconRel = 'Props/AC_units/aircon_small.glb';
    for (final rel in [barrelRel, airconRel]) {
      if (!File('${SmokeArtifacts.testAssetsDir.path}/$rel').existsSync()) {
        markTestSkipped('test asset missing: $rel');
        return;
      }
    }
    final root = Directory.systemTemp.createTempSync('content_browser_rename_smoke_');
    final pDir = Directory('${root.path}/RenameSmoke')..createSync(recursive: true);
    const project = LuminaProject(projectName: 'RenameSmoke', activeLevel: 'contents/levels/L_Main.lmas');
    File('${pDir.path}/RenameSmoke.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
    EditorViewModel? vm;
    try {
      vm = EditorViewModel(initialProject: project, projectLocation: root.path, enableTimers: false);
      final editor = vm;
      await tester.runAsync(() => editor.ensureDefaultLevelAssets());
      for (final rel in [barrelRel, airconRel]) {
        await tester.runAsync(() => editor.processImportPipeline(sourceFilePath: '${SmokeArtifacts.testAssetsDir.path}/$rel'));
      }
      editor.refreshAssets();
      final barrelAsset =
          editor.realAssets.firstWhere((a) => a.fileName == 'fuel_barrel_red.lmas' && a.type == AssetType.filamesh);
      await tester.runAsync(() => editor.spawnActorFromAsset(barrelAsset, location: [-150.0, 0.0, 0.0]));
      final barrel = editor.actors.last;
      expect(barrel.meshData, isNotNull);

      final boundary = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: boundary,
        child: ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: editor)),
      ));
      await settle(tester);
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundary));
      await rec.hold(const Duration(milliseconds: 1500));

      editor.selectedFolder = 'contents/meshes/static';
      await settle(tester);
      Finder tile(String fileName) => find.byWidgetPredicate((w) {
            final k = w.key;
            return k is ValueKey<String> && k.value.startsWith('asset_item_') && k.value.endsWith(fileName);
          });

      // Right-click → Rename… → SM_OilDrum.
      await tester.tapAt(tester.getCenter(tile('fuel_barrel_red.lmas')), buttons: kSecondaryMouseButton);
      await settle(tester);
      await rec.hold(const Duration(seconds: 1));
      await tester.tap(find.text('Rename...'));
      await settle(tester);
      await rec.typeText(find.byKey(const ValueKey('asset_rename_field')), 'SM_OilDrum');
      await settle(tester, frames: 5);
      await rec.hold(const Duration(seconds: 1));
      final pngRename = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundary));
      SmokeArtifacts.saveScreenshot('$scenario: the Rename dialog', pngRename);
      await tester.tap(find.byKey(const ValueKey('asset_rename_confirm')));
      await settle(tester, frames: 30);

      final drum = File('${pDir.path}/contents/meshes/static/SM_OilDrum.lmas');
      expect(drum.existsSync(), isTrue);
      expect(File('${pDir.path}/contents/meshes/static/fuel_barrel_red.lmas').existsSync(), isFalse);
      expect(tile('SM_OilDrum.lmas'), findsOneWidget);
      expect(editor.actors.firstWhere((a) => a.id == barrel.id).meshAssetPath, drum.path,
          reason: 'the placed barrel follows the rename');
      await rec.hold(const Duration(milliseconds: 1500));

      // File → Save Level writes the new path into the level.
      await tester.runAsync(() => editor.saveLevelAndGenerateCode());
      await settle(tester);
      final level = File('${pDir.path}/contents/levels/L_Main.lmas').readAsStringSync();
      expect(level, contains('SM_OilDrum.lmas'));
      expect(level, isNot(contains('fuel_barrel_red.lmas')));

      // Select the air-con card, Ctrl+D duplicates it, and the copy places.
      // A click on the card selects it and gives the browser the keyboard.
      await tester.tap(tile('aircon_small.lmas'));
      await settle(tester, frames: 30);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await settle(tester, frames: 30);
      final copy = File('${pDir.path}/contents/meshes/static/aircon_small_1.lmas');
      expect(copy.existsSync(), isTrue);
      expect(tile('aircon_small_1.lmas'), findsOneWidget);
      editor.refreshAssets();
      final copyAsset = editor.realAssets.firstWhere((a) => a.fileName == 'aircon_small_1.lmas');
      await tester.runAsync(() => editor.spawnActorFromAsset(copyAsset, location: [150.0, 0.0, 0.0]));
      await settle(tester, frames: 30);
      expect(editor.actors.last.meshData, isNotNull, reason: 'the duplicate renders');
      await rec.hold(const Duration(seconds: 2));
      final pngAfter = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundary));
      SmokeArtifacts.saveScreenshot('$scenario: renamed drum and duplicated air-con placed', pngAfter);

      // F2 renames the selected copy; the placed copy follows.
      final placedCopy = editor.actors.last;
      await tester.tap(tile('aircon_small_1.lmas'));
      await settle(tester, frames: 30);
      await tester.sendKeyEvent(LogicalKeyboardKey.f2);
      await settle(tester);
      await rec.typeText(find.byKey(const ValueKey('asset_rename_field')), 'SM_AirconSpare');
      await tester.tap(find.byKey(const ValueKey('asset_rename_confirm')));
      await settle(tester, frames: 30);
      final spare = File('${pDir.path}/contents/meshes/static/SM_AirconSpare.lmas');
      expect(spare.existsSync(), isTrue);
      expect(editor.actors.firstWhere((a) => a.id == placedCopy.id).meshAssetPath, spare.path);
      await rec.hold(const Duration(seconds: 2));
      rec.save(scenario);
    } finally {
      vm?.dispose();
      if (root.existsSync()) root.deleteSync(recursive: true);
    }
  });
}
