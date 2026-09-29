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

  const scenario = 'Content Browser Smoke Scenario: deleting an asset removes the actors that reference it and moves its files to the project trash';
  testWidgets(scenario, (tester) async {
    // The delete cascade used to remove every actor whose NAME
    // contained the asset's file name, and nothing could undo it.
    const props = {
      'Props/Barrels/fuel_barrel_red.glb': [-150.0, 100.0, 0.0],
      'Props/AC_units/aircon_small.glb': [200.0, -100.0, 0.0],
    };
    for (final rel in props.keys) {
      if (!File('${SmokeArtifacts.testAssetsDir.path}/$rel').existsSync()) {
        markTestSkipped('test asset missing: $rel');
        return;
      }
    }
    final root = Directory.systemTemp.createTempSync('content_browser_delete_smoke_');
    final pDir = Directory('${root.path}/DeleteSmoke')..createSync(recursive: true);
    const project = LuminaProject(projectName: 'DeleteSmoke', activeLevel: 'contents/levels/L_Main.lmas');
    File('${pDir.path}/DeleteSmoke.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
    EditorViewModel? vm;
    try {
      vm = EditorViewModel(initialProject: project, projectLocation: root.path, enableTimers: false);
      final editor = vm;
      await tester.runAsync(() => editor.ensureDefaultLevelAssets());

      final placed = <String, EditorActorNode>{};
      for (final entry in props.entries) {
        await tester.runAsync(
            () => editor.processImportPipeline(sourceFilePath: '${SmokeArtifacts.testAssetsDir.path}/${entry.key}'));
        editor.refreshAssets();
        final stem = entry.key.split('/').last.replaceAll('.glb', '');
        final asset = editor.realAssets.firstWhere((a) => a.fileName == '$stem.lmas' && a.type == AssetType.filamesh);
        await tester.runAsync(() => editor.spawnActorFromAsset(asset, location: entry.value));
        placed[stem] = editor.actors.last;
        expect(editor.actors.last.meshData, isNotNull, reason: '$stem renders its imported mesh');
      }
      final barrel = placed['fuel_barrel_red']!;
      final aircon = placed['aircon_small']!;
      // Renamed, so its name no longer contains the asset name...
      editor.renameActor(barrel.id, 'Barrel');
      // ...while two primitives that never used the asset do.
      editor.spawnNewActor('Primitive');
      final marker = editor.actors.last..location = [0.0, 250.0, 0.0];
      editor.renameActor(marker.id, 'fuel_barrel_red_marker');
      editor.spawnNewActor('Primitive');
      final wall = editor.actors.last..location = [0.0, -250.0, 0.0];
      editor.renameActor(wall.id, 'Fuel_Barrel_Red_Wall');
      final idsBefore = editor.actors.map((a) => a.id).toList();
      // The files go to the project trash, not away.
      final barrelLmas = File('${pDir.path}/contents/meshes/static/fuel_barrel_red.lmas');
      final barrelBytes = barrelLmas.readAsBytesSync();

      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: editor)),
        ),
      );
      await settle(tester);
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundary));
      await rec.hold(const Duration(milliseconds: 1500));

      // Content Browser: open the static meshes folder, select the barrel asset.
      editor.selectedFolder = 'contents/meshes/static';
      await settle(tester);
      final tile = find.byWidgetPredicate((w) {
        final k = w.key;
        return k is ValueKey<String> && k.value.startsWith('asset_item_') && k.value.endsWith('fuel_barrel_red.lmas');
      });
      expect(tile, findsOneWidget);
      // A right-click selects the tile at once (a left click waits out the
      // double-click window); close the menu and use the toolbar's Delete.
      await tester.tapAt(tester.getCenter(tile), buttons: kSecondaryMouseButton);
      await settle(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);
      expect(find.text('Delete (1)'), findsOneWidget, reason: 'the barrel asset is selected');
      await rec.hold(const Duration(seconds: 1));

      // The browser's Delete button opens the confirmation, which names the
      // one actor that really uses the asset.
      await tester.tap(find.text('Delete (1)'));
      await settle(tester);
      final note = find.byKey(const ValueKey('delete_affected_actors'));
      expect(note, findsOneWidget);
      final noteText = (tester.widget(note) as Text).data!;
      expect(noteText, contains('1 placed actor'));
      expect(noteText, contains('Barrel'));
      expect(noteText, isNot(contains('marker')));
      await rec.hold(const Duration(milliseconds: 1500));
      final pngDialog = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundary));
      SmokeArtifacts.saveScreenshot('$scenario: the confirmation lists Barrel', pngDialog);

      await tester.tap(find.text('Delete Selected'));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await settle(tester, frames: 30);
      final ids = editor.actors.map((a) => a.id).toSet();
      expect(ids.contains(barrel.id), isFalse, reason: 'the referencing actor is removed');
      expect(ids, containsAll([marker.id, wall.id, aircon.id]), reason: 'name matches and other assets survive');
      expect(File('${pDir.path}/contents/meshes/static/fuel_barrel_red.lmas').existsSync(), isFalse);
      expect(editor.projectTrash.list(), hasLength(1), reason: 'one trash entry');
      expect(find.byKey(const ValueKey('delete_trash_toast')), findsOneWidget, reason: 'the toast names the entry');
      await rec.hold(const Duration(seconds: 2));
      final pngAfter = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundary));
      SmokeArtifacts.saveScreenshot('$scenario: primitives and the air-con stay', pngAfter);

      // Edit → Undo brings the barrel actor back where it was.
      await tester.tap(find.text('Edit'));
      await settle(tester);
      await rec.hold(const Duration(seconds: 1));
      // The label names the delete ("Delete Asset …", or "Delete N Assets" with
      // the linked materials and textures the dialog pre-selects).
      expect(editor.transactions.undoLabel, startsWith('Undo Delete'));
      await tester.tap(find.text(editor.transactions.undoLabel).last);
      await settle(tester, frames: 30);
      expect(editor.actors.map((a) => a.id).toList(), idsBefore);
      expect(barrelLmas.readAsBytesSync(), barrelBytes, reason: 'undo restores the file byte-identical');
      expect(editor.projectTrash.list(), isEmpty);
      await rec.hold(const Duration(seconds: 2));
      final pngUndo = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundary));
      SmokeArtifacts.saveScreenshot('$scenario: undo restores Barrel', pngUndo);

      // Edit → Redo removes it again (only it), and a second Undo restores it.
      await tester.tap(find.text('Edit'));
      await settle(tester);
      await rec.hold(const Duration(milliseconds: 800));
      await tester.tap(find.text(editor.transactions.redoLabel).last);
      await settle(tester, frames: 30);
      final afterRedo = editor.actors.map((a) => a.id).toSet();
      expect(afterRedo.contains(barrel.id), isFalse);
      expect(afterRedo, containsAll([marker.id, wall.id, aircon.id]));
      await rec.hold(const Duration(milliseconds: 1500));
      expect(editor.commands.execute('edit.undo'), isTrue);
      await settle(tester, frames: 30);
      expect(editor.actors.map((a) => a.id).toList(), idsBefore);
      await rec.hold(const Duration(milliseconds: 1500));
      rec.save(scenario);
    } finally {
      vm?.dispose();
      if (root.existsSync()) root.deleteSync(recursive: true);
    }
  });
}
