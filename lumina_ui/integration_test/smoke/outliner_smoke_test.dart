import 'dart:convert';
import 'dart:io';
import 'package:flutter/gestures.dart' show PointerDeviceKind, kSecondaryButton;
import 'package:flutter/material.dart' hide ThemeData, Colors, Icon, Icons, DropdownMenu, TextField, Scaffold;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:lumina/data/services/game_template_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/main_editor/views/outliner_widget.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Outliner Smoke Test: Render and interact with hierarchy', (WidgetTester tester) async {
    final tempProjectsDir = Directory.systemTemp.createTempSync('lumina_smoke_outliner_');
    final p = LuminaProject(projectName: 'OutlinerSmoke');
    final vm = EditorViewModel(initialProject: p, projectLocation: tempProjectsDir.path);
    
    await tester.runAsync(() => vm.ensureDefaultLevelAssets());

    // The boundary wraps the whole app: the spawn dialog and the row menu are
    // overlays above the page.
    final hierarchyKey = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: hierarchyKey,
      child: ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(child: MainEditorView(viewModel: vm)),
      ),
    ));
    Future<void> settle([int frames = 10]) async {
      for (var i = 0; i < frames; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
      }
    }

    await settle(30);
    final rec = SmokeRecorder(tester, boundary: find.byKey(hierarchyKey));
    await rec.hold(const Duration(seconds: 1));

    /// Renames [id] through its row's context menu, typing the new name.
    Future<void> renameThroughMenu(String id, String name) async {
      await tester.tap(find.byKey(ValueKey('row_gesture_$id')), buttons: kSecondaryButton, kind: PointerDeviceKind.mouse);
      await settle();
      await rec.hold(const Duration(milliseconds: 600));
      await tester.tap(find.text('Rename').last);
      await settle();
      final field = find.byKey(const ValueKey('outliner_rename_field'));
      expect(field, findsOneWidget);
      await rec.typeText(field, name);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle();
      expect(vm.actors.firstWhere((a) => a.id == id).name, name);
      await rec.hold(const Duration(milliseconds: 700));
    }

    // Spawn the parent from the outliner's Add dialog.
    await tester.tap(find.descendant(of: find.byType(OutlinerWidget), matching: find.text('Add')));
    await settle();
    await rec.hold(const Duration(milliseconds: 800));
    final before = vm.actors.length;
    await tester.tap(find.byKey(const ValueKey('spawn_actor_StaticMesh')));
    await settle();
    expect(vm.actors.length, before + 1);
    final parentId = vm.actors.last.id;
    await rec.hold(const Duration(milliseconds: 700));
    await renameThroughMenu(parentId, 'ParentBox');

    // A child under it: open the parent with its chevron to see it, then
    // rename it the same way.
    vm.spawnNewActor('StaticMesh', parentId: parentId);
    await settle();
    final childId = vm.actors.last.id;
    await rec.hold(const Duration(milliseconds: 600));
    if (find.byKey(ValueKey('row_gesture_$childId')).evaluate().isEmpty) {
      await tester.tap(find.byKey(ValueKey('outliner_chevron_$parentId')));
      await settle();
      await rec.hold(const Duration(milliseconds: 600));
    }
    expect(find.byKey(ValueKey('row_gesture_$childId')), findsOneWidget, reason: 'the child row shows under its parent');
    await renameThroughMenu(childId, 'ChildBox');

    SmokeArtifacts.saveScreenshot('outliner_hierarchy_initial', await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(hierarchyKey)));

    // Select the child by clicking its row.
    await tester.tap(find.byKey(ValueKey('row_gesture_$childId')));
    await settle();
    expect(vm.selectedActor?.id, childId);
    await rec.hold(const Duration(milliseconds: 800));
    SmokeArtifacts.saveScreenshot('outliner_hierarchy_expanded', await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(hierarchyKey)));

    // Delete the parent's subtree, take it back with Edit -> Undo, and redo it.
    vm.deleteActorSubtreeWithTransaction(parentId);
    await settle();
    expect(vm.actors.any((a) => a.id == parentId), isFalse);
    await rec.hold(const Duration(milliseconds: 800));
    await tester.tap(find.text('Edit').first);
    await settle();
    await rec.hold(const Duration(milliseconds: 600));
    await tester.tap(find.byWidgetPredicate((w) => w is Text && (w.data ?? '').startsWith('Undo')).last);
    await settle();
    expect(vm.actors.any((a) => a.id == parentId), isTrue, reason: 'Undo brings the subtree back');
    expect(vm.actors.any((a) => a.id == childId), isTrue);
    await rec.hold(const Duration(milliseconds: 800));
    vm.transactions.redo();
    await settle();
    SmokeArtifacts.saveScreenshot('outliner_hierarchy_deleted', await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(hierarchyKey)));
    await rec.hold(const Duration(seconds: 1));
    rec.save('Outliner Smoke Test: Render and interact with hierarchy');

    debugPrint('Actors left: ${vm.actors.map((a) => a.id).join(', ')}'); expect(vm.actors.any((a) => a.id == parentId), false);
    expect(vm.actors.any((a) => a.id == childId), false);

    vm.dispose();
    if (tempProjectsDir.existsSync()) tempProjectsDir.deleteSync(recursive: true);
  });

  // Folder authoring through real clicks, typing and mouse
  // drags in the full editor, on a real Third Person project.
  testWidgets('Outliner Smoke: folders are created, filled by drag and drop, and open and close as a tree', (tester) async {
    const title = 'Outliner Smoke: folders are created, filled by drag and drop, and open and close as a tree';
    final root = Directory.systemTemp.createTempSync('lumina_smoke_outliner_folders_');
    final configDir = Directory.systemTemp.createTempSync('lumina_smoke_outliner_folders_cfg_');
    addTearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
      if (configDir.existsSync()) configDir.deleteSync(recursive: true);
    });

    // The real scaffolding pipeline; only `flutter create` and `pub get` are
    // replaced by their filesystem effects.
    Future<ProcessResult> runner(String exec, List<String> args, {String? workingDirectory, bool runInShell = false}) async {
      if (args.isNotEmpty && args.first == 'create') {
        final target = args.last;
        final name = args[args.indexOf('--project-name') + 1];
        Directory('$target/lib').createSync(recursive: true);
        File('$target/pubspec.yaml').writeAsStringSync(
          'name: $name\nenvironment:\n  sdk: ^3.12.0\ndependencies:\n  flutter:\n    sdk: flutter\nflutter:\n  uses-material-design: true\n',
        );
        File('$target/lib/main.dart').writeAsStringSync('void main() {}\n');
      }
      return ProcessResult(0, 0, '', '');
    }

    late EditorViewModel vm;
    late String manifest;
    await tester.runAsync(() async {
      await ProjectRepository(configDir: configDir, processRunner: runner)
          .createProject(projectName: 'folder_smoke', projectLocation: root.path, template: kThirdPersonTemplateId);
      manifest = '${root.path}/folder_smoke/folder_smoke.lmproject';
      final project = (await ProjectRepository(configDir: configDir).loadProject(manifest))!;
      vm = EditorViewModel(initialProject: project, projectLocation: root.path, enableTimers: false);
      await vm.ensureDefaultLevelAssets();
    });

    // The boundary wraps the whole app: a dragged row's feedback and the row
    // menus float in the app overlay, above the page.
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: boundaryKey,
      child: ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(child: MainEditorView(viewModel: vm)),
      ),
    ));
    Future<void> settle([int frames = 10]) async {
      for (var i = 0; i < frames; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    await settle(30);

    EditorActorNode named(String name) => vm.actors.firstWhere((a) => a.name == name);
    Finder row(String id) => find.byKey(ValueKey('outliner_row_$id'));
    Finder rowTap(String id) => find.byKey(ValueKey('row_gesture_$id'));
    // The outliner's rows are built lazily: scroll its own list to reach one.
    final outlinerList = find.descendant(
      of: find.descendant(of: find.byType(OutlinerWidget), matching: find.byType(CustomScrollView)),
      matching: find.byType(Scrollable),
    ).first;
    // Rows are drag sources, so the list scrolls the way a desktop user
    // scrolls it: with the mouse wheel.
    final wheel = TestPointer(7, PointerDeviceKind.mouse);
    Future<void> reveal(Finder finder) async {
      final center = tester.getCenter(outlinerList);
      await tester.sendEventToBinding(wheel.hover(center));
      for (var i = 0; i < 60 && finder.evaluate().isEmpty; i++) {
        await tester.sendEventToBinding(wheel.scroll(const Offset(0, 72)));
        await settle(2);
      }
      for (var i = 0; i < 60 && finder.evaluate().isEmpty; i++) {
        await tester.sendEventToBinding(wheel.scroll(const Offset(0, -72)));
        await settle(2);
      }
      await tester.ensureVisible(finder);
      await settle();
    }

    // The whole flow on video: every step is followed by 1.5 s of the
    // running editor, and drags are recorded as they move.
    final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
    Future<void> shot(String phase) async {
      final png = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
      SmokeArtifacts.saveScreenshot('$title $phase', png);
      await rec.hold(const Duration(milliseconds: 1500));
    }

    Future<void> mouseDrag(Finder from, Finder to) async {
      final start = tester.getCenter(from);
      final end = tester.getCenter(to);
      final gesture = await tester.startGesture(start, kind: PointerDeviceKind.mouse);
      await tester.pump();
      for (var i = 1; i <= 15; i++) {
        await gesture.moveTo(Offset.lerp(start, end, i / 15)!);
        await tester.pump(const Duration(milliseconds: 16));
        await rec.capture();
      }
      await gesture.up();
      await settle();
    }

    Future<void> renameTo(String name) async {
      final field = find.byKey(const ValueKey('outliner_rename_field'));
      expect(field, findsOneWidget, reason: 'a new folder opens in inline rename');
      await tester.enterText(find.descendant(of: field, matching: find.byType(EditableText)), name);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle();
    }

    expect(find.text('Wall_North'), findsWidgets, reason: 'the Third Person map is in the outliner');
    await shot('01 template map');

    // --- New Folder from the header, named by typing -----------------------
    vm.clearSelection();
    await settle();
    await tester.tap(find.byKey(const ValueKey('outliner_new_folder')));
    await settle();
    await renameTo('Walls');
    final walls = named('Walls');
    expect(walls.type, 'Folder');
    await shot('02 folder created');

    // --- Ctrl-select two walls and drag them in with the mouse -------------
    final north = named('Wall_North').id;
    final south = named('Wall_South').id;
    await tester.tap(rowTap(north));
    await settle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.tap(rowTap(south));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settle();
    expect(vm.selectedActorIds, containsAll(<String>[north, south]));
    final northLocation = List<double>.of(named('Wall_North').location);
    await mouseDrag(row(north), row(walls.id));
    expect(named('Wall_North').parentId, walls.id);
    expect(named('Wall_South').parentId, walls.id, reason: 'the selection travels together');
    expect(named('Wall_North').location, northLocation, reason: 'moving into a folder never moves the actor');
    await shot('03 walls dragged in');

    // --- Wrap two selected crates in a folder straight from the header -----
    final crate1 = named('Crate_01').id;
    final crate2 = named('Crate_02').id;
    await reveal(rowTap(crate1));
    await tester.tap(rowTap(crate1));
    await settle();
    await reveal(rowTap(crate2));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.tap(rowTap(crate2));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settle();
    await tester.tap(find.byKey(const ValueKey('outliner_new_folder')));
    await settle();
    await renameTo('Props');
    final props = named('Props');
    expect(named('Crate_01').parentId, props.id);
    expect(named('Crate_02').parentId, props.id);
    await reveal(row(props.id));
    await shot('04 crates wrapped');

    // --- Folders close and open as a tree ----------------------------------
    await reveal(find.byKey(ValueKey('outliner_chevron_${walls.id}')));
    await tester.tap(find.byKey(ValueKey('outliner_chevron_${walls.id}')));
    await settle();
    expect(vm.isOutlinerExpanded(walls.id), isFalse);
    expect(row(north), findsNothing);
    await shot('05 walls collapsed');

    await tester.tap(find.byKey(ValueKey('outliner_chevron_${walls.id}')));
    await settle();
    expect(row(north), findsOneWidget);
    await shot('06 walls expanded');

    // --- The tree is level data: save, reload, same tree -------------------
    await tester.runAsync(() => vm.saveLevelAndGenerateCode());
    late EditorViewModel reloaded;
    await tester.runAsync(() async {
      final project = (await ProjectRepository(configDir: configDir).loadProject(manifest))!;
      reloaded = EditorViewModel(initialProject: project, projectLocation: root.path, enableTimers: false);
      await reloaded.ensureDefaultLevelAssets();
    });
    EditorActorNode reloadedNamed(String name) => reloaded.actors.firstWhere((a) => a.name == name);
    expect(reloadedNamed('Walls').type, 'Folder');
    expect(reloadedNamed('Wall_South').parentId, reloadedNamed('Walls').id);
    expect(reloadedNamed('Crate_02').parentId, reloadedNamed('Props').id);
    reloaded.dispose();

    await rec.hold(const Duration(seconds: 1));
    rec.save(title);
    expect(File('${SmokeArtifacts.dir.path}/${SmokeArtifacts.sanitizeTestName(title)}.webm').existsSync(), isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await settle();
    vm.dispose();
  }, timeout: const Timeout(Duration(minutes: 10)));

  const soloScenario = 'Outliner Smoke: Solo and Clear Solo undo and redo the exact visibility';
  testWidgets(soloScenario, (tester) async {
    // Solo / Clear Solo recorded undo entries that did nothing.
    const props = {
      'Props/Barrels/fuel_barrel_red.glb': [-200.0, 0.0, 0.0],
      'Props/AC_units/aircon_small.glb': [0.0, 150.0, 0.0],
      'Props/Banana Bunch/banana_bunch_medium.glb': [200.0, 0.0, 0.0],
    };
    for (final rel in props.keys) {
      if (!File('${SmokeArtifacts.testAssetsDir.path}/$rel').existsSync()) {
        markTestSkipped('test asset missing: $rel');
        return;
      }
    }
    final root = Directory.systemTemp.createTempSync('lumina_smoke_outliner_solo_');
    addTearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });
    final pDir = Directory('${root.path}/SoloSmoke')..createSync(recursive: true);
    const project = LuminaProject(projectName: 'SoloSmoke', activeLevel: 'contents/levels/L_Main.lmas');
    File('${pDir.path}/SoloSmoke.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
    final vm = EditorViewModel(initialProject: project, projectLocation: root.path, enableTimers: false);
    addTearDown(vm.dispose);
    await tester.runAsync(() => vm.ensureDefaultLevelAssets());
    final placed = <EditorActorNode>[];
    for (final entry in props.entries) {
      await tester.runAsync(
          () => vm.processImportPipeline(sourceFilePath: '${SmokeArtifacts.testAssetsDir.path}/${entry.key}'));
      vm.refreshAssets();
      final stem = entry.key.split('/').last.replaceAll('.glb', '');
      final asset = vm.realAssets.firstWhere((a) => a.fileName == '$stem.lmas' && a.type == AssetType.filamesh);
      await tester.runAsync(() => vm.spawnActorFromAsset(asset, location: entry.value));
      placed.add(vm.actors.last);
    }
    // The banana starts hidden: undo must bring it back hidden, not visible.
    vm.setActorVisibilityWithTransaction(placed[2].id, false);
    final barrel = placed.first;

    final boundaryKey = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: boundaryKey,
      child: ShadcnApp(theme: luminaEditorTheme(), home: Scaffold(child: MainEditorView(viewModel: vm))),
    ));
    Future<void> settle([int frames = 20]) async {
      for (var i = 0; i < frames; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
      }
    }

    Future<void> menu(String top, String itemPrefix) async {
      await tester.tap(find.text(top).first);
      await settle();
      await tester.tap(find.byWidgetPredicate((w) => w is Text && (w.data ?? '').startsWith(itemPrefix)).last);
      await settle();
    }

    await settle(30);
    final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
    await rec.hold(const Duration(milliseconds: 1500));
    Map<String, bool> visibility() => {for (final a in vm.actors) a.id: a.isVisible};
    final initial = visibility();

    // Alt+click the barrel's eye: Solo.
    final rowY = tester.getCenter(find.byKey(ValueKey('row_gesture_${barrel.id}'))).dy;
    final eyes = find.descendant(of: find.byType(OutlinerWidget), matching: find.byIcon(LucideIcons.eye)).evaluate();
    final eye = eyes.map((e) => e.renderObject as RenderBox).reduce((a, b) =>
        ((a.localToGlobal(a.size.center(Offset.zero)).dy - rowY).abs() <=
                (b.localToGlobal(b.size.center(Offset.zero)).dy - rowY).abs())
            ? a
            : b);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.tapAt(eye.localToGlobal(eye.size.center(Offset.zero)));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await settle();
    final soloed = visibility();
    expect(soloed[barrel.id], isTrue);
    expect(soloed.entries.where((e) => e.key != barrel.id).every((e) => !e.value), isTrue);
    expect(vm.transactions.undoLabel, 'Undo Solo Actor');
    await rec.hold(const Duration(milliseconds: 1500));
    SmokeArtifacts.saveScreenshot('$soloScenario: the barrel soloed',
        await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey)));

    // Edit → Undo: every actor back as it was, the banana still hidden.
    await menu('Edit', 'Undo');
    expect(visibility(), initial);
    expect(vm.actors.firstWhere((a) => a.id == placed[2].id).isVisible, isFalse);
    await rec.hold(const Duration(milliseconds: 1500));
    SmokeArtifacts.saveScreenshot('$soloScenario: Undo restores the visibility',
        await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey)));

    // Edit → Redo: soloed again; Alt+click again clears it; Undo re-solos.
    await menu('Edit', 'Redo');
    expect(visibility(), soloed);
    await rec.hold(const Duration(seconds: 1));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.tapAt(eye.localToGlobal(eye.size.center(Offset.zero)));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await settle();
    expect(visibility(), initial, reason: 'Clear Solo');
    expect(vm.transactions.undoLabel, 'Undo Clear Solo');
    await rec.hold(const Duration(milliseconds: 1500));
    await menu('Edit', 'Undo');
    expect(visibility(), soloed, reason: 'undoing Clear Solo puts the solo back');
    await rec.hold(const Duration(milliseconds: 1500));
    SmokeArtifacts.saveScreenshot('$soloScenario: Undo of Clear Solo re-solos',
        await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey)));

    // One more Undo unwinds the solo itself: back to the start.
    await menu('Edit', 'Undo');
    expect(visibility(), initial);
    await rec.hold(const Duration(seconds: 2));
    rec.save(soloScenario);
  });
}
