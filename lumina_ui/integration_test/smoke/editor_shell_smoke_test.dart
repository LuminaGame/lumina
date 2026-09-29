import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/main_editor/views/new_level_dialog.dart';
import 'package:lumina_ui/ui/features/main_editor/views/outliner_widget.dart';
import 'package:lumina_ui/ui/features/main_editor/views/viewport_widget.dart';
import 'package:lumina_ui/ui/features/main_editor/views/content_browser_widget.dart';
import 'package:lumina_ui/ui/features/main_editor/views/details_widget.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

/// The editor viewport runs tickers for as long as it is on screen (fly
/// camera, procedural sky), so `pumpAndSettle` never settles with it mounted.
/// Pumps a bounded run of frames on the live clock instead.
Future<void> settle(WidgetTester tester, {int frames = 20}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Editor Shell Smoke Scenario: Menu Dispatch & Layout Toggles', (tester) async {
    final tempProjectsDir = Directory.systemTemp.createTempSync('editor_shell_smoke_');
    final pDir = Directory('${tempProjectsDir.path}/SmokeProject');
    pDir.createSync(recursive: true);
    Directory('${pDir.path}/contents/levels').createSync(recursive: true);

    try {
      final p = LuminaProject(projectName: 'SmokeProject', activeLevel: 'contents/levels/L_Main.lmas', settings: EngineScalabilitySettings(targetFps: 60));
      final manifestFile = File('${pDir.path}/SmokeProject.lmproject');
      manifestFile.writeAsStringSync('{}');

      final vm = EditorViewModel(initialProject: p, projectDirPath: tempProjectsDir.path);
      final repaintBoundaryKey = GlobalKey();

      await tester.pumpWidget(
        RepaintBoundary(
          key: repaintBoundaryKey,
          child: ShadcnApp(
            theme: luminaEditorTheme(),
            home: MainEditorView(viewModel: vm),
          ),
        ),
      );
      await settle(tester);
      final rec = SmokeRecorder(tester, boundary: find.byKey(repaintBoundaryKey));
      await rec.hold(const Duration(milliseconds: 1500));

      // Ensure the editor loads
      // The editor chrome no longer prints the project name; its menu bar is
      // the sign the shell loaded.
      expect(find.byType(MainEditorView), findsOneWidget);
      expect(find.text('File'), findsOneWidget);

      // Open Tools -> Material Editor
      await tester.tap(find.text('Tools'));
      await settle(tester);
      await rec.hold(const Duration(seconds: 1));
      await tester.tap(find.text('Material Editor').last);
      await settle(tester);
      // The workspace tab opens (its title and the editor's own header).
      expect(vm.openTabs.where((t) => t.category == 'material'), hasLength(1));
      expect(find.text('Material Editor'), findsWidgets);
      await rec.hold(const Duration(milliseconds: 1500));

      // Back to the level's tab: the viewport is on screen again.
      // (the menu bar also names the level, so the tab is found by its map icon)
      await tester.tap(find.ancestor(of: find.byIcon(LucideIcons.map), matching: find.byType(Tooltip)).first);
      await settle(tester);
      expect(find.byType(ViewportWidget).hitTestable(), findsOneWidget);
      await rec.hold(const Duration(seconds: 1));

      // Select the rock in the outliner, then Edit -> Duplicate.
      final rock = vm.actors.firstWhere((a) => a.name.startsWith('StaticMesh_Rock'));
      await tester.tap(find.byKey(ValueKey('row_gesture_${rock.id}')));
      await settle(tester);
      await rec.hold(const Duration(milliseconds: 800));
      final countBefore = vm.actors.length;
      await tester.tap(find.text('Edit'));
      await settle(tester);
      await rec.hold(const Duration(seconds: 1));
      await tester.tap(find.text('Duplicate').last);
      await settle(tester);
      expect(vm.actors.length, countBefore + 1, reason: 'Edit -> Duplicate copied the rock');
      final copy = vm.actors.last;
      await rec.hold(const Duration(milliseconds: 1200));

      // File -> Save Level, enabled now that the level changed, writes the copy.
      expect(vm.commands.byId('file.saveLevel')!.canExecute(), isTrue);
      await tester.tap(find.text('File'));
      await settle(tester);
      await rec.hold(const Duration(seconds: 1));
      await tester.tap(find.text('Save Level').last);
      await settle(tester, frames: 30);
      final levelFile = File('${pDir.path}/contents/levels/L_Main.lmas');
      expect(levelFile.readAsStringSync(), contains(copy.id), reason: 'the saved level lists the duplicate');
      expect(vm.commands.byId('file.saveLevel')!.canExecute(), isFalse, reason: 'nothing left to save');
      await rec.hold(const Duration(milliseconds: 1200));

      // View -> Wireframe, then back to Lit.
      await tester.tap(find.text('View'));
      await settle(tester);
      await rec.hold(const Duration(milliseconds: 800));
      await tester.tap(find.text('Wireframe').last);
      await settle(tester);
      await rec.hold(const Duration(milliseconds: 1200));
      await tester.tap(find.text('View'));
      await settle(tester);
      await rec.hold(const Duration(milliseconds: 600));
      await tester.tap(find.text('Lit').last);
      await settle(tester);
      await rec.hold(const Duration(seconds: 1));

      // Window -> Toggle Details
      await tester.tap(find.text('Window'));
      await settle(tester);
      await rec.hold(const Duration(seconds: 1));
      final detailsShown = vm.layoutState.detailsVisible;
      await tester.tap(find.text('Details').last);
      await settle(tester);
      expect(vm.layoutState.detailsVisible, !detailsShown);
      await rec.hold(const Duration(milliseconds: 1500));

      // Capture screenshot
      final pngEditor = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(repaintBoundaryKey));
      SmokeArtifacts.saveScreenshot('Editor Shell Smoke Scenario: Menu Dispatch & Layout Toggles executed', pngEditor);

      // Window -> Details again brings the panel back.
      await tester.tap(find.text('Window'));
      await settle(tester);
      await rec.hold(const Duration(seconds: 1));
      await tester.tap(find.text('Details').last);
      await settle(tester);
      expect(vm.layoutState.detailsVisible, detailsShown);
      await rec.hold(const Duration(milliseconds: 1500));
      rec.save('Editor Shell Smoke Scenario: Menu Dispatch & Layout Toggles');

      expect(pngEditor.length, greaterThan(0));
    } finally {
      if (tempProjectsDir.existsSync()) {
        tempProjectsDir.deleteSync(recursive: true);
      }
    }
  });

  testWidgets('Editor Shell Smoke Scenario: Keyboard Shortcuts & Quick Open', (tester) async {
    final tempProjectsDir = Directory.systemTemp.createTempSync('shortcuts_smoke_');
    final pDir = Directory('${tempProjectsDir.path}/SmokeProject2');
    pDir.createSync(recursive: true);

    // Seed some test assets
    final repo = AssetRepository();
    await repo.createAsset(projectPath: pDir.path, subFolder: 'meshes', fileName: 'StaticMesh_Apple.lmas', type: AssetType.filamesh);
    await repo.createAsset(projectPath: pDir.path, subFolder: 'materials', fileName: 'M_Apple.lmas', type: AssetType.filamat);

    try {
      final p = LuminaProject(projectName: 'SmokeProject2', activeLevel: 'contents/levels/L_Main.lmas', settings: EngineScalabilitySettings(targetFps: 60));
      final manifestFile = File('${pDir.path}/SmokeProject2.lmproject');
      manifestFile.writeAsStringSync('{}');

      // The view model takes the projects folder and opens <folder>/<name>:
      // pDir is the project itself, where the assets were seeded.
      final vm = EditorViewModel(initialProject: p, projectDirPath: tempProjectsDir.path);
      expect(vm.projectDirPath, pDir.path);
      await vm.ensureDefaultLevelAssets(); // Load the assets we just created

      final repaintBoundaryKey = GlobalKey();

      await tester.pumpWidget(
        RepaintBoundary(
          key: repaintBoundaryKey,
          child: ShadcnApp(
            theme: luminaEditorTheme(),
            home: MainEditorView(viewModel: vm),
          ),
        ),
      );
      await settle(tester);
      final rec = SmokeRecorder(tester, boundary: find.byKey(repaintBoundaryKey));
      await rec.hold(const Duration(milliseconds: 1500));

      // Tool switching
      await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
      await settle(tester);
      expect(vm.activeTool, 'translate', reason: 'W switches to the Move tool (global shortcuts)');
      await rec.hold(const Duration(seconds: 1));

      await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
      await settle(tester);
      expect(vm.activeTool, 'rotate');
      await rec.hold(const Duration(seconds: 1));

      // Open palette via Ctrl+P: it works from anywhere in the editor (the
      // Content Browser's own search is Ctrl+F).
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await settle(tester);
      await rec.hold(const Duration(milliseconds: 1500));

      expect(find.text('Search assets...'), findsOneWidget);

      // Type 'apple'
      await rec.typeText(find.byType(TextField).last, 'apple');
      await settle(tester);
      await rec.hold(const Duration(milliseconds: 1500));

      // Enter submits the field (the platform delivers it as the text input's
      // done action): the first match opens and the palette closes.
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);
      await rec.hold(const Duration(seconds: 1));

      expect(find.text('Search assets...'), findsNothing);
      expect(vm.openTabs.any((t) => t.title.contains('Apple')), isTrue);

      // Back to the level's tab, select an actor, Ctrl+D duplicates it.
      await tester.tap(find.ancestor(of: find.byIcon(LucideIcons.map), matching: find.byType(Tooltip)).first);
      await settle(tester);
      await rec.hold(const Duration(milliseconds: 800));
      // A static mesh from the outliner's Add dialog, selected by its row.
      await tester.tap(find.descendant(of: find.byType(OutlinerWidget), matching: find.text('Add')));
      await settle(tester);
      await rec.hold(const Duration(milliseconds: 600));
      await tester.tap(find.byKey(const ValueKey('spawn_actor_StaticMesh')));
      await settle(tester);
      final original = vm.actors.last;
      await tester.tap(find.byKey(ValueKey('row_gesture_${original.id}')));
      await settle(tester);
      expect(vm.selectedActor?.id, original.id);
      await rec.hold(const Duration(milliseconds: 600));
      final before = vm.actors.length;
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await settle(tester);
      expect(vm.actors.length, before + 1, reason: 'Ctrl+D duplicated the selected actor');
      await rec.hold(const Duration(seconds: 1));

      // Save Level via Ctrl+S: the level is clean again.
      expect(vm.commands.byId('file.saveLevel')!.canExecute(), isTrue);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await settle(tester, frames: 30);
      expect(vm.commands.byId('file.saveLevel')!.canExecute(), isFalse, reason: 'Ctrl+S saved the level');
      await rec.hold(const Duration(seconds: 1));

      final pngEditor = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(repaintBoundaryKey));
      SmokeArtifacts.saveScreenshot('Editor Shell Smoke Scenario: Keyboard Shortcuts executed', pngEditor);
      rec.save('Editor Shell Smoke Scenario: Keyboard Shortcuts & Quick Open');
    } finally {
      if (tempProjectsDir.existsSync()) {
        tempProjectsDir.deleteSync(recursive: true);
      }
    }
  });

  testWidgets('Editor Shell Smoke Scenario: Details under the Outliner & Content Drawer', (tester) async {
    // The Details inspector docked under the Outliner in the
    // left column, the bottom panel open and pinned, unpinned into a Content
    // Drawer opened from the status bar, and the splitters dragged and
    // persisted to the real editor_layout.json.
    final tempProjectsDir = Directory.systemTemp.createTempSync('editor_shell_dock_smoke_');
    final pDir = Directory('${tempProjectsDir.path}/SmokeProject3');
    pDir.createSync(recursive: true);
    Directory('${pDir.path}/contents/levels').createSync(recursive: true);

    try {
      final p = LuminaProject(projectName: 'SmokeProject3', activeLevel: 'contents/levels/L_Main.lmas', settings: EngineScalabilitySettings(targetFps: 60));
      File('${pDir.path}/SmokeProject3.lmproject').writeAsStringSync('{}');

      final vm = EditorViewModel(initialProject: p, projectDirPath: tempProjectsDir.path);
      final layoutFile = File('${vm.projectDirPath}/.lumina/editor_layout.json');
      Map<String, dynamic> layoutJson() => jsonDecode(layoutFile.readAsStringSync()) as Map<String, dynamic>;
      final repaintBoundaryKey = GlobalKey();

      await tester.pumpWidget(
        RepaintBoundary(
          key: repaintBoundaryKey,
          child: ShadcnApp(
            theme: luminaEditorTheme(),
            home: MainEditorView(viewModel: vm),
          ),
        ),
      );
      await settle(tester);
      final rec = SmokeRecorder(tester, boundary: find.byKey(repaintBoundaryKey));
      await rec.hold(const Duration(milliseconds: 1500));

      // The default arrangement: Details under the Outliner, left of the
      // viewport; the Content Browser open and pinned; no right column.
      final outliner = tester.getRect(find.byType(OutlinerWidget));
      final details = tester.getRect(find.byType(DetailsWidget));
      final viewport = tester.getRect(find.byType(ViewportWidget));
      expect(details.left, moreOrLessEquals(outliner.left, epsilon: 1));
      expect(details.top, greaterThanOrEqualTo(outliner.bottom));
      expect(details.right, lessThanOrEqualTo(viewport.left + 1));
      expect(find.byType(ContentBrowserWidget), findsOneWidget);
      expect(vm.layoutState.bottomPinned, isTrue);
      expect(find.byKey(const ValueKey('status_bar_content_drawer')), findsNothing);
      final pngDefault = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(repaintBoundaryKey));
      SmokeArtifacts.saveScreenshot('Editor Shell Smoke Scenario: Details under the Outliner (default layout)', pngDefault);

      // Unpin: the drawer closes and the folder button appears in the status bar.
      await tester.tap(find.byKey(const ValueKey('bottom_panel_pin')));
      await settle(tester);
      expect(vm.layoutState.bottomPinned, isFalse);
      expect(vm.layoutState.bottomVisible, isFalse);
      expect(find.byType(ContentBrowserWidget), findsNothing);
      final drawerButton = find.byKey(const ValueKey('status_bar_content_drawer'));
      expect(drawerButton, findsOneWidget);
      expect(layoutJson()['bottomPinned'], isFalse);
      await rec.hold(const Duration(milliseconds: 1500));

      // The folder button reopens the drawer.
      await tester.tap(drawerButton);
      await settle(tester);
      expect(vm.layoutState.bottomVisible, isTrue);
      expect(find.byType(ContentBrowserWidget), findsOneWidget);
      await rec.hold(const Duration(milliseconds: 1500));
      final pngDrawer = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(repaintBoundaryKey));
      SmokeArtifacts.saveScreenshot('Editor Shell Smoke Scenario: Content Drawer opened from the status bar', pngDrawer);

      // ...and closes it again; then pin it back into the layout.
      await tester.tap(drawerButton);
      await settle(tester);
      expect(find.byType(ContentBrowserWidget), findsNothing);
      await rec.hold(const Duration(seconds: 1));
      await tester.tap(drawerButton);
      await settle(tester);
      await rec.hold(const Duration(milliseconds: 800));
      await tester.tap(find.byKey(const ValueKey('bottom_panel_pin')));
      await settle(tester);
      expect(vm.layoutState.bottomPinned, isTrue);
      expect(find.byKey(const ValueKey('status_bar_content_drawer')), findsNothing);
      expect(layoutJson()['bottomPinned'], isTrue);
      await rec.hold(const Duration(seconds: 1));

      // Drag the Outliner / Details splitter up: Details grows, and the size
      // is on disk when the drag ends.
      final detailsBefore = tester.getRect(find.byType(DetailsWidget)).height;
      final outlinerRight = tester.getRect(find.byType(OutlinerWidget)).right;
      final leftSplitter = find
          .byType(VerticalResizableDragger)
          .evaluate()
          .map((e) => tester.getCenter(find.byElementPredicate((c) => identical(c, e))))
          .firstWhere((c) => c.dx <= outlinerRight + 1);
      await rec.drag(leftSplitter, leftSplitter + const Offset(0, -80));
      await settle(tester);
      expect(vm.layoutState.detailsHeight, closeTo(detailsBefore + 80, 25));
      expect((layoutJson()['detailsHeight'] as num).toDouble(), closeTo(detailsBefore + 80, 25));
      await rec.hold(const Duration(seconds: 1));

      // Drag the left column's splitter right: the column widens.
      final columnBefore = tester.getRect(find.byType(OutlinerWidget)).width;
      final columnSplitter = tester.getCenter(find.byElementPredicate((e) =>
        // The workspace splitter, not the Content Browser's own.
        e.widget is HorizontalResizableDragger && e.findAncestorWidgetOfExactType<ContentBrowserWidget>() == null));
      await rec.drag(columnSplitter, columnSplitter + const Offset(100, 0));
      await settle(tester);
      expect(vm.layoutState.outlinerWidth, closeTo(columnBefore + 100, 25));
      expect((layoutJson()['outlinerWidth'] as num).toDouble(), closeTo(columnBefore + 100, 25));
      await rec.hold(const Duration(milliseconds: 1500));

      final pngResized = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(repaintBoundaryKey));
      SmokeArtifacts.saveScreenshot('Editor Shell Smoke Scenario: Details under the Outliner & Content Drawer executed', pngResized);
      rec.save('Editor Shell Smoke Scenario: Details under the Outliner & Content Drawer');
      expect(pngResized.length, greaterThan(0));
    } finally {
      if (tempProjectsDir.existsSync()) {
        tempProjectsDir.deleteSync(recursive: true);
      }
    }
  });

  const splitScenario = 'Editor Shell Smoke Scenario: EditorViewModel domain files work together';
  testWidgets(splitScenario, (tester) async {
    // EditorViewModel is split into one part file per domain
    // (mixins on a shared state class). One real session crosses them: the
    // project opens and scaffolds its level, two real props from test-assets
    // go through the import pipeline and are placed, the Outliner folds them
    // into a folder, the selection moves with an undoable transaction, the
    // camera focuses, the World Partition section drives the grid, the
    // Content Browser makes a folder, and File → Save Level writes it all.
    const props = {
      'Props/Barrels/fuel_barrel_red.glb': [-200.0, 150.0, 0.0],
      'Props/AC_units/aircon_small.glb': [250.0, -100.0, 0.0],
    };
    for (final rel in props.keys) {
      if (!File('${SmokeArtifacts.testAssetsDir.path}/$rel').existsSync()) {
        markTestSkipped('test asset missing: $rel');
        return;
      }
    }
    final root = Directory.systemTemp.createTempSync('editor_shell_split_smoke_');
    final pDir = Directory('${root.path}/SplitSmoke')..createSync(recursive: true);
    const project = LuminaProject(projectName: 'SplitSmoke', activeLevel: 'contents/levels/L_Main.lmas');
    File('${pDir.path}/SplitSmoke.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
    EditorViewModel? vm;
    try {
      vm = EditorViewModel(initialProject: project, projectLocation: root.path, enableTimers: false);
      final editor = vm;
      // project_and_levels: the level is scaffolded on disk.
      await tester.runAsync(() => editor.ensureDefaultLevelAssets());
      expect(File('${pDir.path}/contents/levels/L_Main.lmas').existsSync(), isTrue);

      // import + actor_spawning: real GLBs through the real pipeline, placed.
      final placed = <EditorActorNode>[];
      for (final entry in props.entries) {
        await tester.runAsync(
            () => editor.processImportPipeline(sourceFilePath: '${SmokeArtifacts.testAssetsDir.path}/${entry.key}'));
        editor.refreshAssets();
        final stem = entry.key.split('/').last.replaceAll('.glb', '');
        final asset = editor.realAssets.firstWhere((a) => a.fileName == '$stem.lmas' && a.type == AssetType.filamesh);
        await tester.runAsync(() => editor.spawnActorFromAsset(asset, location: entry.value));
        placed.add(editor.actors.last);
        expect(placed.last.meshData, isNotNull, reason: '$stem renders its imported mesh');
      }

      final repaintBoundaryKey = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: repaintBoundaryKey,
          child: ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: editor)),
        ),
      );
      await settle(tester);
      final rec = SmokeRecorder(tester, boundary: find.byKey(repaintBoundaryKey));
      await rec.hold(const Duration(milliseconds: 1500));

      // outliner: both props folded into a folder, shown in the tree.
      final folderId = editor.createFolder(name: 'Props', wrapIds: placed.map((a) => a.id));
      await settle(tester);
      expect(editor.outlinerChildrenOf(folderId).map((a) => a.id), containsAll(placed.map((a) => a.id)));
      expect(find.text('Props'), findsWidgets);
      await rec.hold(const Duration(seconds: 1));

      // selection_and_transforms: select the barrel and move it; undo and
      // redo go through the transaction the move recorded.
      final barrel = placed.first;
      editor.selectActor(barrel);
      await settle(tester);
      final start = List<double>.from(barrel.location);
      editor.updateActorLocation([start[0] + 300, start[1], start[2]]);
      await settle(tester);
      expect(barrel.location[0], closeTo(start[0] + 300, 1e-6));
      await rec.hold(const Duration(seconds: 1));
      expect(editor.commands.execute('edit.undo'), isTrue);
      await settle(tester);
      expect(editor.actors.firstWhere((a) => a.id == barrel.id).location[0], closeTo(start[0], 1e-6));
      await rec.hold(const Duration(milliseconds: 800));
      expect(editor.commands.execute('edit.redo'), isTrue);
      await settle(tester);
      expect(editor.actors.firstWhere((a) => a.id == barrel.id).location[0], closeTo(start[0] + 300, 1e-6));
      await rec.hold(const Duration(milliseconds: 800));

      // camera_and_viewport: focus the air-con unit.
      final pan = [editor.cameraPanX, editor.cameraPanY, editor.cameraPanZ];
      editor.focusCameraOnActor(placed.last);
      await settle(tester, frames: 30);
      expect([editor.cameraPanX, editor.cameraPanY, editor.cameraPanZ], isNot(equals(pan)));
      await rec.hold(const Duration(milliseconds: 1500));

      // level_sections: an enabled World Partition draws its cells as the grid.
      editor.setWorldPartitionEnabled(true);
      await settle(tester);
      expect(editor.worldPartitionEnabled, isTrue);
      expect(editor.gridStep, editor.worldPartitionCellSize);
      await rec.hold(const Duration(seconds: 1));

      // assets_and_content_browser: a new folder on disk, listed as a tile.
      final folder = editor.createContentFolder('contents', 'SmokeFolder');
      editor.selectedFolder = 'contents';
      await settle(tester);
      expect(Directory('${pDir.path}/$folder').existsSync(), isTrue);
      expect(editor.visibleFolders, contains(folder));
      await rec.hold(const Duration(seconds: 1));

      final png = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(repaintBoundaryKey));
      SmokeArtifacts.saveScreenshot('$splitScenario executed', png);

      // commands + codegen_and_save: File → Save Level writes every change.
      expect(editor.commands.byId('file.saveLevel')!.canExecute(), isTrue);
      await tester.tap(find.text('File'));
      await settle(tester);
      await rec.hold(const Duration(seconds: 1));
      await tester.tap(find.text('Save Level').last);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
      await settle(tester, frames: 30);
      final saved = File('${pDir.path}/contents/levels/L_Main.lmas').readAsStringSync();
      for (final a in placed) {
        expect(saved, contains(a.id), reason: 'the saved level lists ${a.name}');
      }
      expect(saved, contains(folderId));
      expect(editor.commands.byId('file.saveLevel')!.canExecute(), isFalse, reason: 'nothing left to save');
      await rec.hold(const Duration(milliseconds: 1500));
      rec.save(splitScenario);
      expect(png.length, greaterThan(0));
    } finally {
      vm?.dispose();
      if (root.existsSync()) {
        root.deleteSync(recursive: true);
      }
    }
  });

  const newLevelScenario = 'Editor Shell Smoke Scenario: New Level refuses an existing level name';
  testWidgets(newLevelScenario, (tester) async {
    // File → New Level with the name of a populated level used to
    // overwrite it with the template, and its undo then deleted the file.
    const props = {
      'Props/Barrels/fuel_barrel_red.glb': [-150.0, 100.0, 0.0],
      'Props/Banana Bunch/banana_bunch_medium.glb': [150.0, -80.0, 0.0],
    };
    for (final rel in props.keys) {
      if (!File('${SmokeArtifacts.testAssetsDir.path}/$rel').existsSync()) {
        markTestSkipped('test asset missing: $rel');
        return;
      }
    }
    final root = Directory.systemTemp.createTempSync('editor_shell_new_level_smoke_');
    final pDir = Directory('${root.path}/NewLevelSmoke')..createSync(recursive: true);
    const project = LuminaProject(projectName: 'NewLevelSmoke', activeLevel: 'contents/levels/L_Main.lmas');
    File('${pDir.path}/NewLevelSmoke.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
    EditorViewModel? vm;
    try {
      vm = EditorViewModel(initialProject: project, projectLocation: root.path, enableTimers: false);
      final editor = vm;
      await tester.runAsync(() => editor.ensureDefaultLevelAssets());

      // A populated, saved L_Main: real GLBs through the real import pipeline.
      for (final entry in props.entries) {
        await tester.runAsync(
            () => editor.processImportPipeline(sourceFilePath: '${SmokeArtifacts.testAssetsDir.path}/${entry.key}'));
        editor.refreshAssets();
        final stem = entry.key.split('/').last.replaceAll('.glb', '');
        final asset = editor.realAssets.firstWhere((a) => a.fileName == '$stem.lmas' && a.type == AssetType.filamesh);
        await tester.runAsync(() => editor.spawnActorFromAsset(asset, location: entry.value));
        expect(editor.actors.last.meshData, isNotNull, reason: '$stem renders its imported mesh');
      }
      await tester.runAsync(() => editor.saveLevelAndGenerateCode());
      final main = File('${pDir.path}/contents/levels/L_Main.lmas');
      final bytesBefore = main.readAsBytesSync();
      final actorsBefore = editor.actors.map((a) => a.id).toList();

      final repaintBoundaryKey = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: repaintBoundaryKey,
          child: ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: editor)),
        ),
      );
      await settle(tester);
      final rec = SmokeRecorder(tester, boundary: find.byKey(repaintBoundaryKey));
      await rec.hold(const Duration(milliseconds: 1500));

      // File → New Level…, the way a user opens it.
      await tester.tap(find.text('File'));
      await settle(tester);
      await rec.hold(const Duration(seconds: 1));
      await tester.tap(find.text(editor.commands.byId('file.newLevel')!.label).last);
      await settle(tester);
      expect(find.byType(NewLevelDialog), findsOneWidget);
      await rec.hold(const Duration(seconds: 1));

      await tester.enterText(find.byKey(const ValueKey('new_level_name')), 'L_Main');
      await settle(tester);
      expect(find.text('A level named L_Main already exists.'), findsOneWidget);
      await rec.hold(const Duration(milliseconds: 1500));
      final png = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(repaintBoundaryKey));
      SmokeArtifacts.saveScreenshot('$newLevelScenario: the dialog refuses L_Main', png);

      // Create is disabled: tapping it neither closes the dialog nor writes.
      await tester.tap(find.byKey(const ValueKey('new_level_create')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await settle(tester);
      expect(find.byType(NewLevelDialog), findsOneWidget);
      expect(main.readAsBytesSync(), bytesBefore, reason: 'L_Main is byte-identical');
      expect(editor.actors.map((a) => a.id), actorsBefore, reason: 'the barrel and the bananas are still placed');
      await rec.hold(const Duration(seconds: 1));

      // A free name creates the level as before. The tap on Create took the
      // focus, so the field is focused again before typing.
      await tester.tap(find.byKey(const ValueKey('new_level_name')));
      await settle(tester);
      await tester.enterText(find.byKey(const ValueKey('new_level_name')), 'L_Second');
      await settle(tester);
      expect(find.text('A level named L_Main already exists.'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('new_level_create')));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
      await settle(tester, frames: 30);
      expect(File('${pDir.path}/contents/levels/L_Second.lmas').existsSync(), isTrue);
      expect(editor.project.activeLevel, 'contents/levels/L_Second.lmas');
      await rec.hold(const Duration(milliseconds: 1500));

      // Edit → Undo removes only the level this New Level created and goes
      // back to L_Main, whose barrel and bananas are still there.
      await tester.tap(find.text('Edit'));
      await settle(tester);
      await rec.hold(const Duration(seconds: 1));
      await tester.tap(find.text('Undo New Level L_Second').last);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await settle(tester, frames: 30);
      expect(File('${pDir.path}/contents/levels/L_Second.lmas').existsSync(), isFalse);
      expect(main.readAsBytesSync(), bytesBefore, reason: 'L_Main survives the undo byte-identical');
      expect(editor.project.activeLevel, 'contents/levels/L_Main.lmas');
      expect(editor.actors.map((a) => a.id), containsAll(actorsBefore));
      await rec.hold(const Duration(seconds: 2));
      final pngAfterUndo =
          await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(repaintBoundaryKey));
      SmokeArtifacts.saveScreenshot('$newLevelScenario: back on L_Main after undo', pngAfterUndo);
      rec.save(newLevelScenario);
      expect(png.length, greaterThan(0));
    } finally {
      vm?.dispose();
      if (root.existsSync()) {
        root.deleteSync(recursive: true);
      }
    }
  });

  const openLevelScenario = 'Editor Shell Smoke Scenario: opening a level asks about unsaved changes';
  testWidgets(openLevelScenario, (tester) async {
    // File → Open Level used to drop the open level's unsaved
    // actors without asking.
    const barrelRel = 'Props/Barrels/fuel_barrel_red.glb';
    const bananaRel = 'Props/Banana Bunch/banana_bunch_short.glb';
    for (final rel in [barrelRel, bananaRel]) {
      if (!File('${SmokeArtifacts.testAssetsDir.path}/$rel').existsSync()) {
        markTestSkipped('test asset missing: $rel');
        return;
      }
    }
    final root = Directory.systemTemp.createTempSync('editor_shell_open_level_smoke_');
    final pDir = Directory('${root.path}/OpenLevelSmoke')..createSync(recursive: true);
    const project = LuminaProject(projectName: 'OpenLevelSmoke', activeLevel: 'contents/levels/L_Main.lmas');
    File('${pDir.path}/OpenLevelSmoke.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
    EditorViewModel? vm;
    try {
      vm = EditorViewModel(initialProject: project, projectLocation: root.path, enableTimers: false);
      final editor = vm;
      await tester.runAsync(() => editor.ensureDefaultLevelAssets());
      // A second level, with a banana bunch in it, saved.
      await tester.runAsync(() => editor.createLevelFromTemplate('L_Other', 'default'));
      Future<EditorActorNode> place(String rel, List<double> at) async {
        await tester.runAsync(
            () => editor.processImportPipeline(sourceFilePath: '${SmokeArtifacts.testAssetsDir.path}/$rel'));
        editor.refreshAssets();
        final stem = rel.split('/').last.replaceAll('.glb', '');
        final asset = editor.realAssets.firstWhere((a) => a.fileName == '$stem.lmas' && a.type == AssetType.filamesh);
        await tester.runAsync(() => editor.spawnActorFromAsset(asset, location: at));
        return editor.actors.last;
      }

      await place(bananaRel, [120.0, 0.0, 0.0]);
      await tester.runAsync(() => editor.saveLevelAndGenerateCode());
      editor.switchLevel('contents/levels/L_Main.lmas');
      // L_Main gets a barrel that is NOT saved yet.
      final barrel = await place(barrelRel, [-120.0, 60.0, 0.0]);
      expect(editor.project.isDirty, isTrue);
      final mainFile = File('${pDir.path}/contents/levels/L_Main.lmas');
      expect(mainFile.readAsStringSync(), isNot(contains(barrel.id)));

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

      Future<void> openOtherFromMenu() async {
        await tester.tap(find.text('File'));
        await settle(tester);
        await rec.hold(const Duration(milliseconds: 800));
        await tester.tap(find.text(editor.commands.byId('file.openLevel')!.label).last);
        await settle(tester);
        await rec.hold(const Duration(milliseconds: 800));
        await tester.tap(find.text('L_Other.lmas'));
        await settle(tester);
      }

      // Open L_Other → the prompt; Cancel keeps L_Main and its barrel.
      await openOtherFromMenu();
      expect(find.byKey(const ValueKey('unsaved_level_prompt')), findsOneWidget);
      await rec.hold(const Duration(milliseconds: 1500));
      final pngPrompt = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundary));
      SmokeArtifacts.saveScreenshot('$openLevelScenario: the unsaved-changes prompt', pngPrompt);
      await tester.tap(find.byKey(const ValueKey('unsaved_level_prompt_cancel')));
      await settle(tester);
      expect(editor.project.activeLevel, 'contents/levels/L_Main.lmas');
      expect(editor.actors.any((a) => a.id == barrel.id), isTrue);
      await rec.hold(const Duration(seconds: 1));

      // Again → Save: L_Main is written with the barrel, then L_Other opens.
      await openOtherFromMenu();
      await tester.tap(find.byKey(const ValueKey('unsaved_level_prompt_save')));
      for (var i = 0; i < 100 && !editor.project.activeLevel.endsWith('L_Other.lmas'); i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await settle(tester, frames: 30);
      expect(editor.project.activeLevel, 'contents/levels/L_Other.lmas');
      expect(mainFile.readAsStringSync(), contains(barrel.id), reason: 'L_Main was saved before switching');
      await rec.hold(const Duration(milliseconds: 1500));
      final pngOther = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundary));
      SmokeArtifacts.saveScreenshot('$openLevelScenario: L_Other opened after saving L_Main', pngOther);

      // Back to L_Main (clean now: no prompt) — the barrel is there.
      await tester.tap(find.text('File'));
      await settle(tester);
      await tester.tap(find.text(editor.commands.byId('file.openLevel')!.label).last);
      await settle(tester);
      await tester.tap(find.text('L_Main.lmas'));
      await settle(tester, frames: 30);
      expect(find.byKey(const ValueKey('unsaved_level_prompt')), findsNothing);
      expect(editor.project.activeLevel, 'contents/levels/L_Main.lmas');
      expect(editor.actors.any((a) => a.id == barrel.id), isTrue);
      await rec.hold(const Duration(seconds: 2));
      final pngBack = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundary));
      SmokeArtifacts.saveScreenshot('$openLevelScenario: back on L_Main with the barrel', pngBack);
      rec.save(openLevelScenario);
    } finally {
      vm?.dispose();
      if (root.existsSync()) root.deleteSync(recursive: true);
    }
  });

  // The status bar and Help > About name the Filament the
  // editor is linked against, read at runtime (never hardcoded).
  testWidgets('filament version in about and status bar', (tester) async {
    const name = 'filament version in about and status bar';
    const barrel = 'Props/Barrels/fuel_barrel_red.glb';
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final gradle = File('${Directory.current.parent.path}/filament/android/gradle.properties').readAsStringSync();
    final version = RegExp(r'^VERSION_NAME=(.+)$', multiLine: true).firstMatch(gradle)!.group(1)!.trim();

    final root = Directory.systemTemp.createTempSync('editor_shell_filament_version_');
    final pDir = Directory('${root.path}/VersionSmoke')..createSync(recursive: true);
    const project = LuminaProject(projectName: 'VersionSmoke', activeLevel: 'contents/levels/L_Main.lmas');
    File('${pDir.path}/VersionSmoke.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
    final vm = EditorViewModel(initialProject: project, projectLocation: root.path, enableTimers: false);
    try {
      await tester.runAsync(() => vm.ensureDefaultLevelAssets());
      await tester.runAsync(() => vm.processImportPipeline(sourceFilePath: '${SmokeArtifacts.testAssetsDir.path}/$barrel'));
      vm.refreshAssets();
      final asset = vm.realAssets.firstWhere((a) => a.fileName == 'fuel_barrel_red.lmas' && a.type == AssetType.filamesh);
      await tester.runAsync(() => vm.spawnActorFromAsset(asset, location: const [0.0, 0.0, 0.0]));

      final boundaryKey = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: boundaryKey,
        child: ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)),
      ));
      await settle(tester, frames: 30);
      vm.frameLevelBounds();
      await settle(tester);
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      await rec.hold(const Duration(seconds: 3));

      // 1. The status bar strip.
      final segment = find.byKey(const ValueKey('status_filament_segment'));
      expect(find.descendant(of: segment, matching: find.text('Filament $version')), findsOneWidget);
      final full = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
      final engineAt = tester.getRect(find.byKey(const ValueKey('status_engine_version')));
      final countsAt = tester.getRect(find.byKey(const ValueKey('status_actor_counts')));
      final image = img.decodePng(full)!;
      final scale = image.width / tester.getSize(find.byKey(boundaryKey)).width;
      final strip = img.copyCrop(image,
          x: ((engineAt.left - 24) * scale).floor(),
          y: ((engineAt.top - 6) * scale).floor(),
          width: ((countsAt.right - engineAt.left + 48) * scale).ceil(),
          height: ((engineAt.height + 12) * scale).ceil());
      SmokeArtifacts.saveScreenshot('$name (status bar)',
          img.encodePng(img.copyResize(strip, width: strip.width * 2, interpolation: img.Interpolation.nearest)),
          usedAssets: const [barrel]);
      await rec.hold(const Duration(seconds: 2));

      // 2. Help > About.
      await tester.tap(find.text('Help'));
      await settle(tester);
      await tester.tap(find.text('About Lumina Studio'));
      await settle(tester);
      expect(find.text('Filament $version'), findsWidgets);
      expect(find.textContaining('Apache-2.0'), findsOneWidget);
      await rec.hold(const Duration(seconds: 3));
      final about = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
      SmokeArtifacts.saveScreenshot('$name (about)', about, usedAssets: const [barrel]);
      await tester.tap(find.byKey(const ValueKey('about_close')));
      await settle(tester);
      await rec.hold(const Duration(seconds: 3));
      rec.save(name, usedAssets: const [barrel]);
    } finally {
      vm.dispose();
      try {
        root.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  // Window checks the open panels and follows every toggle.
  testWidgets('Editor Shell Smoke: the Window menu checks the open panels and follows Outliner, Details, Bottom Panel and Output Log toggles', (tester) async {
    const name = 'Editor Shell Smoke: the Window menu checks the open panels and follows Outliner, Details, Bottom Panel and Output Log toggles';
    const barrel = 'Props/Barrels/fuel_barrel_red.glb';
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final root = Directory.systemTemp.createTempSync('editor_shell_window_checks_');
    final pDir = Directory('${root.path}/WindowChecks')..createSync(recursive: true);
    const project = LuminaProject(projectName: 'WindowChecks', activeLevel: 'contents/levels/L_Main.lmas');
    File('${pDir.path}/WindowChecks.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
    final vm = EditorViewModel(initialProject: project, projectLocation: root.path, enableTimers: false);
    try {
      await tester.runAsync(() => vm.ensureDefaultLevelAssets());
      await tester.runAsync(() => vm.processImportPipeline(sourceFilePath: '${SmokeArtifacts.testAssetsDir.path}/$barrel'));
      vm.refreshAssets();
      final asset = vm.realAssets.firstWhere((a) => a.fileName == 'fuel_barrel_red.lmas' && a.type == AssetType.filamesh);
      await tester.runAsync(() => vm.spawnActorFromAsset(asset, location: const [0.0, 0.0, 0.0]));

      final boundaryKey = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: boundaryKey,
        child: ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)),
      ));
      await settle(tester, frames: 30);
      vm.frameLevelBounds();
      await settle(tester);
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      await rec.hold(const Duration(seconds: 2));

      Finder row(String id) => find.byKey(ValueKey('menu_check_window.$id'));
      bool checked(String id) => tester.widget<MenuCheckbox>(row(id)).value;
      Future<void> openWindow() async {
        await tester.tap(find.descendant(of: find.byType(Menubar), matching: find.text('Window')));
        await settle(tester, frames: 30);
      }

      Future<void> click(String id, String label) async {
        await tester.tap(find.descendant(of: row(id), matching: find.text(label)));
        await settle(tester, frames: 30);
      }

      Future<void> shot(String caption) async {
        final png = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
        SmokeArtifacts.saveScreenshot('$name ($caption)', png, usedAssets: const [barrel]);
      }

      // 1. Default: three checks, Output Log unchecked.
      await openWindow();
      expect(checked('toggleOutliner'), isTrue);
      expect(checked('toggleDetails'), isTrue);
      expect(checked('toggleBottomPanel'), isTrue);
      expect(checked('showOutputLog'), isFalse);
      expect(row('resetLayout'), findsNothing);
      await rec.hold(const Duration(seconds: 2));
      await shot('default: three checks, Output Log unchecked');

      // 2. Details and the Bottom Panel hidden through the menu.
      await click('toggleDetails', 'Details');
      await rec.hold(const Duration(seconds: 1));
      await openWindow();
      await click('toggleBottomPanel', 'Bottom Panel');
      expect(find.byType(DetailsWidget), findsNothing);
      expect(vm.layoutState.bottomVisible, isFalse);
      await rec.hold(const Duration(seconds: 1));
      await openWindow();
      expect(checked('toggleDetails'), isFalse);
      expect(checked('toggleBottomPanel'), isFalse);
      expect(checked('toggleOutliner'), isTrue);
      await rec.hold(const Duration(seconds: 2));
      await shot('Details and Bottom Panel hidden and unchecked');

      // 3. Output Log: the bottom panel back on its Output Log tab.
      await click('showOutputLog', 'Output Log');
      await rec.hold(const Duration(seconds: 1));
      await openWindow();
      expect(checked('showOutputLog'), isTrue);
      expect(checked('toggleBottomPanel'), isTrue);
      expect(vm.layoutState.isOutputLogOpen, isTrue);
      await rec.hold(const Duration(seconds: 2));
      await shot('Output Log shown and checked with the Bottom Panel');

      // 4. Reset Layout.
      await tester.tap(find.widgetWithText(MenuButton, 'Reset Layout'));
      await settle(tester, frames: 30);
      await rec.hold(const Duration(seconds: 1));
      await openWindow();
      expect(checked('toggleOutliner'), isTrue);
      expect(checked('toggleDetails'), isTrue);
      expect(checked('toggleBottomPanel'), isTrue);
      expect(checked('showOutputLog'), isFalse);
      expect(find.byType(DetailsWidget), findsOneWidget);
      await rec.hold(const Duration(seconds: 2));
      await shot('after Reset Layout');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester, frames: 30);
      await rec.hold(const Duration(seconds: 2));
      rec.save(name, usedAssets: const [barrel]);
    } finally {
      vm.dispose();
      try {
        root.deleteSync(recursive: true);
      } catch (_) {}
    }
  });
}