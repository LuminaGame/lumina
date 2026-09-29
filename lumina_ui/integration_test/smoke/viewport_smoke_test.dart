import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/gestures.dart' show kSecondaryMouseButton, PointerDeviceKind;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/main_editor/views/toolbar_widget.dart';
import 'package:lumina_ui/ui/features/main_editor/views/viewport_widget.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/services/editor_preferences.dart';

import '../../test/helpers/scaffold_game_project.dart';

/// Pumps a bounded run of frames on the live clock: the editor viewport runs
/// tickers for as long as it is mounted, so `pumpAndSettle` never settles.
Future<void> _settle(WidgetTester tester, [int frames = 10]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
  }
}

/// A toolbar button by its icon (the transform tools come first, so `.first`
/// is the tool, not the snap toggle that reuses the icon).
Finder _toolbarIcon(IconData icon) =>
    find.descendant(of: find.byType(ToolbarWidget), matching: find.byIcon(icon)).first;

/// Picks [item] from the menu bar's [top] menu, on video.
Future<void> _menu(WidgetTester tester, SmokeRecorder rec, String top, String item) async {
  await tester.tap(find.text(top).first);
  await _settle(tester);
  await rec.hold(const Duration(milliseconds: 600));
  // Undo/Redo carry the transaction's name ("Undo Duplicate Subtree").
  await tester.tap(find.byWidgetPredicate((w) => w is Text && (w.data ?? '').startsWith(item)).last);
  await _settle(tester);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Viewport Smoke Scenario: Drag & Drop + Multi-Select', (tester) async {
    final tempProjectsDir = Directory.systemTemp.createTempSync('viewport_smoke_');
    final pDir = Directory('${tempProjectsDir.path}/SmokeProjectViewport');
    pDir.createSync(recursive: true);

    // Seed a test asset
    final repo = AssetRepository();
    await repo.createAsset(projectPath: pDir.path, subFolder: 'meshes', fileName: 'AC_Unit.lmas', type: AssetType.filamesh);
    final glbSource = File('${SmokeArtifacts.testAssetsDir.path}/Props/AC_units/ac_unit_a_300x300.glb');
    glbSource.copySync('${pDir.path}/contents/meshes/AC_Unit.glb');

    try {
      final p = LuminaProject(
        projectName: 'SmokeProjectViewport',
        activeLevel: 'contents/levels/L_Main.lmas',
        settings: EngineScalabilitySettings(targetFps: 60),
      );
      final manifestFile = File('${pDir.path}/SmokeProjectViewport.lmproject');
      manifestFile.writeAsStringSync('{}');

      final vm = EditorViewModel(initialProject: p, projectLocation: tempProjectsDir.path);
      await tester.runAsync(() => vm.ensureDefaultLevelAssets());

      // The boundary wraps the whole app: the drag feedback floats in the
      // app overlay, above the page.
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
      await _settle(tester, 60);
      final rec = SmokeRecorder(tester, boundary: find.byKey(repaintBoundaryKey));
      await rec.hold(const Duration(seconds: 1));

      // 1. Drag the AC unit from the Content Browser into the viewport, twice:
      // the drop preview follows the pointer and each drop spawns an actor.
      // The grid lists the selected folder only; open
      // contents/meshes by double-clicking its folder tile.
      final meshesFolder = find.byKey(const ValueKey('folder_tile_contents/meshes'));
      await tester.tap(meshesFolder);
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tap(meshesFolder);
      await rec.hold(const Duration(milliseconds: 800));
      expect(vm.selectedFolder, 'contents/meshes');
      final before = vm.actors.length;
      final tile = find.byWidgetPredicate((w) => w is Draggable<RealAssetInfo> && w.data?.fileName == 'AC_Unit.lmas');
      expect(tile, findsOneWidget, reason: 'the Content Browser shows the AC unit');
      final viewport = tester.getRect(find.byType(ViewportWidget));
      for (final target in [viewport.center - Offset(viewport.width * 0.15, 0), viewport.center + Offset(viewport.width * 0.15, 0)]) {
        await rec.drag(tester.getCenter(tile), target, steps: 36);
        await rec.hold(const Duration(seconds: 1));
      }
      expect(vm.actors.length, before + 2, reason: 'each drop spawned an actor');
      final spawned = vm.actors.sublist(before);

      // 2. Select the first in the outliner, then Ctrl+click the second.
      await tester.tap(find.byKey(ValueKey('row_gesture_${spawned[0].id}')));
      await _settle(tester);
      await rec.hold(const Duration(seconds: 1));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.tap(find.byKey(ValueKey('row_gesture_${spawned[1].id}')));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await _settle(tester);
      await rec.hold(const Duration(seconds: 1));

      expect(vm.selectedActorIds.contains(spawned[0].id), isTrue);
      expect(vm.selectedActorIds.contains(spawned[1].id), isTrue);

      final pngEditor = await SmokeArtifacts.captureIntegrationPng(
        binding,
        tester,
        boundary: find.byKey(repaintBoundaryKey),
      );
      SmokeArtifacts.saveScreenshot(
        'Viewport Smoke Scenario: Drag & Drop + Multi-Select executed',
        pngEditor,
        usedAssets: const ['Props/AC_units/ac_unit_a_300x300.glb'],
      );

      // 3. Edit -> Duplicate copies the primary selection; Edit -> Undo takes
      // the copy back.
      await _menu(tester, rec, 'Edit', 'Duplicate');
      expect(vm.actors.length, before + 3, reason: 'Edit -> Duplicate copied the selected actor');
      await rec.hold(const Duration(seconds: 1));
      await _menu(tester, rec, 'Edit', 'Undo');
      expect(vm.actors.length, before + 2);
      await rec.hold(const Duration(seconds: 1));
      rec.save(
        'Viewport Smoke Scenario: Drag & Drop + Multi-Select',
        usedAssets: const ['Props/AC_units/ac_unit_a_300x300.glb'],
      );

      expect(pngEditor.length, greaterThan(0));
    } finally {
      if (tempProjectsDir.existsSync()) {
        tempProjectsDir.deleteSync(recursive: true);
      }
    }
  });

  testWidgets('Viewport Smoke Scenario: Gizmo Transformations', (tester) async {
    final tempProjectsDir = Directory.systemTemp.createTempSync('viewport_gizmo_');
    final pDir = Directory('${tempProjectsDir.path}/SmokeProjectGizmo');
    pDir.createSync(recursive: true);

    // A real mesh on disk, imported the way a drop does.
    final repo = AssetRepository();
    await repo.createAsset(projectPath: pDir.path, subFolder: 'meshes', fileName: 'Banana_Bunch.lmas', type: AssetType.filamesh);
    File('${SmokeArtifacts.testAssetsDir.path}/Props/Banana Bunch/banana_bunch_long.glb')
        .copySync('${pDir.path}/contents/meshes/Banana_Bunch.glb');

    try {
      final p = LuminaProject(
        projectName: 'SmokeProjectGizmo',
        activeLevel: 'contents/levels/L_Main.lmas',
        settings: EngineScalabilitySettings(targetFps: 60),
      );
      final vm = EditorViewModel(initialProject: p, projectLocation: tempProjectsDir.path);

      // The view model kicks off `_ensureDefaultLevelAssets()` from its
      // constructor; that reads the level off disk and replaces `_actors`
      // wholesale, so an actor spawned before it lands is wiped along with
      // the selection. Let it finish first.
      await tester.runAsync(() => vm.ensureDefaultLevelAssets());
      vm.refreshAssets();
      await tester.runAsync(() => vm.spawnActorFromAsset(
            vm.realAssets.firstWhere((a) => a.fileName == 'Banana_Bunch.lmas'),
            location: [0.0, 0.0, 0.0],
          ));
      final actor = vm.actors.last;
      vm.clearSelection();

      final boundaryKey = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: boundaryKey,
        child: ShadcnApp(
          title: 'Smoke Gizmo',
          theme: luminaEditorTheme(),
          home: Scaffold(child: MainEditorView(viewModel: vm)),
        ),
      ));
      await _settle(tester, 60);
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      await rec.hold(const Duration(seconds: 1));

      // 1. Select the actor in the outliner and frame it (what F does in the
      // viewport), then the Move tool.
      await tester.tap(find.byKey(ValueKey('row_gesture_${actor.id}')));
      await _settle(tester);
      await rec.hold(const Duration(milliseconds: 500));
      vm.focusCameraOnActor(actor);
      await _settle(tester);
      await rec.hold(const Duration(milliseconds: 500));
      await tester.tap(_toolbarIcon(LucideIcons.move));
      await _settle(tester);
      expect(vm.activeTool, 'translate');
      await rec.hold(const Duration(seconds: 1));
      final png1 = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
      SmokeArtifacts.saveScreenshot('gizmo_translate_mode', png1);

      // 2. Rotate, then Scale, from the toolbar: the gizmo changes shape.
      await tester.tap(_toolbarIcon(LucideIcons.rotateCcw));
      await _settle(tester);
      expect(vm.activeTool, 'rotate');
      await rec.hold(const Duration(seconds: 1));
      final png2 = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
      SmokeArtifacts.saveScreenshot('gizmo_rotate_mode', png2);

      await tester.tap(_toolbarIcon(LucideIcons.maximize2));
      await _settle(tester);
      expect(vm.activeTool, 'scale');
      await rec.hold(const Duration(seconds: 1));

      // 3. Back to Move and drag along X through the gizmo's drag path.
      await tester.tap(_toolbarIcon(LucideIcons.move));
      await _settle(tester);
      expect(vm.activeTool, 'translate');
      await rec.hold(const Duration(milliseconds: 600));
      vm.beginTransformDrag();
      for (var i = 1; i <= 40; i++) {
        vm.updateActorLocation([4.0 * i, 0.0, 0.0]);
        await rec.hold(const Duration(milliseconds: 40));
      }
      vm.endTransformDrag();
      await _settle(tester);
      expect(actor.location[0], 160.0);
      await rec.hold(const Duration(seconds: 1));

      // 4. Edit -> Undo puts it back.
      await _menu(tester, rec, 'Edit', 'Undo');
      expect(actor.location[0], 0.0);
      await rec.hold(const Duration(seconds: 1));

      // 5. And the scale tool, dragged the same way, grows it.
      await tester.tap(_toolbarIcon(LucideIcons.maximize2));
      await _settle(tester);
      vm.beginTransformDrag();
      for (var i = 1; i <= 30; i++) {
        vm.updateActorScale([1.0 + 0.05 * i, 1.0 + 0.05 * i, 1.0 + 0.05 * i]);
        await rec.hold(const Duration(milliseconds: 40));
      }
      vm.endTransformDrag();
      await _settle(tester);
      expect(actor.scale[0], closeTo(2.5, 1e-9));
      await rec.hold(const Duration(seconds: 1));
      rec.save('Viewport Smoke Scenario: Gizmo Transformations', usedAssets: const ['Props/Banana Bunch/banana_bunch_long.glb']);
    } finally {
      tempProjectsDir.deleteSync(recursive: true);
    }
  });

  testWidgets('Viewport Smoke Scenario: Snapping and Grid', (tester) async {
    final tempDir = Directory.systemTemp.createTempSync('viewport_snap_');
    final pDir = Directory('${tempDir.path}/SnapProject')..createSync(recursive: true);
    final proj = LuminaProject(projectName: 'SnapProject', activeLevel: 'contents/levels/L_Main.lmas');
    final vm = EditorViewModel(initialProject: proj, projectLocation: pDir.path);
    await tester.runAsync(() => vm.ensureDefaultLevelAssets());

    try {
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: boundaryKey,
        child: ShadcnApp(
          theme: luminaEditorTheme(),
          home: Scaffold(
            child: MainEditorView(viewModel: vm),
          ),
        ),
      ));
      await _settle(tester, 60);
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      await rec.hold(const Duration(seconds: 1));

      final actor = vm.actors.first;
      await tester.tap(find.byKey(ValueKey('row_gesture_${actor.id}')));
      await _settle(tester);
      await rec.hold(const Duration(seconds: 1));

      // 1. The grid: off, then on again, from the toolbar.
      final gridCluster = find.byKey(const Key('toggle_grid_snap'));
      final gridToggle = find.descendant(of: gridCluster, matching: find.byIcon(LucideIcons.layoutGrid));
      await tester.tap(gridToggle);
      await _settle(tester);
      expect(vm.gridVisible, isFalse);
      await rec.hold(const Duration(seconds: 1));
      await tester.tap(gridToggle);
      await _settle(tester);
      expect(vm.gridVisible, isTrue);
      await rec.hold(const Duration(milliseconds: 800));

      // 2. Grid step: 1 m from the grid menu.
      await tester.tap(find.descendant(of: gridCluster, matching: find.byIcon(LucideIcons.chevronDown)));
      await _settle(tester);
      await rec.hold(const Duration(milliseconds: 800));
      await tester.tap(find.text('1 m').last);
      await _settle(tester);
      expect(vm.editorGridStep, 100.0);
      expect(find.byType(MainEditorView), findsOneWidget,
          reason: 'picking a grid step must close only the menu, not the editor page');
      await rec.hold(const Duration(seconds: 1));

      final pngGrid = await SmokeArtifacts.captureIntegrationPng(
        binding,
        tester,
        boundary: find.byKey(boundaryKey),
      );
      SmokeArtifacts.saveScreenshot(
        'viewport_smoke_03_grid',
        pngGrid,
      );

      // 3. Translate snap on, with a 50 cm step picked from its menu.
      final snapCluster = find.byKey(const Key('toggle_translate_snap'));
      final wasSnapping = vm.translateSnapEnabled;
      final snapToggle = find.descendant(of: snapCluster, matching: find.byType(GhostButton)).first;
      await tester.tap(snapToggle);
      await _settle(tester);
      expect(vm.translateSnapEnabled, !wasSnapping);
      if (!vm.translateSnapEnabled) {
        await tester.tap(snapToggle);
        await _settle(tester);
      }
      expect(vm.translateSnapEnabled, isTrue);
      await rec.hold(const Duration(milliseconds: 800));
      await tester.tap(find.descendant(of: snapCluster, matching: find.byType(GestureDetector)).last);
      await _settle(tester);
      await rec.hold(const Duration(milliseconds: 800));
      await tester.tap(find.text('50 cm').last);
      await _settle(tester);
      expect(vm.translateSnapStep, 50.0);
      await rec.hold(const Duration(seconds: 1));

      // 4. Play in the editor, then Stop.
      await tester.tap(find.byKey(const ValueKey('toolbar_play')));
      await _settle(tester, 20);
      expect(find.text('SIMULATE — PIE ACTIVE'), findsOneWidget);
      await rec.hold(const Duration(milliseconds: 1500));

      final pngPie = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
      SmokeArtifacts.saveScreenshot('viewport_scenario_05_pie', pngPie);

      await tester.tap(find.byKey(const ValueKey('toolbar_stop')));
      await _settle(tester, 20);
      expect(find.text('SIMULATE — PIE ACTIVE'), findsNothing);
      await rec.hold(const Duration(seconds: 1));
      rec.save('Viewport Smoke Scenario: Snapping and Grid');
    } finally {
      vm.dispose();
      tempDir.deleteSync(recursive: true);
    }
  });


  testWidgets('Viewport Smoke Scenario: WASD flight with the right button held, then Editor Preferences → Always',
      (tester) async {
    // On the launcher's Third Person project: the viewport flight
    // (hold RMB, W/A/S/D/Q/E; Shift faster), then Edit → Editor Preferences
    // → "Use WASD For Camera Controls Always" and a flight with no button.
    final root = Directory.systemTemp.createTempSync('viewport_smoke_wasd_');
    addTearDown(() => root.deleteSync(recursive: true));
    final projectDir = (await tester.runAsync(
        () => scaffoldGameProject(root, name: 'wasd_smoke', widgetLibrary: 'flutter')))!;
    final project = LuminaProject.fromMap(Map<String, dynamic>.from(
        jsonDecode(File('$projectDir/wasd_smoke.lmproject').readAsStringSync()) as Map));
    final vm = EditorViewModel(initialProject: project, projectLocation: root.path);
    await tester.runAsync(vm.ensureDefaultLevelAssets);
    addTearDown(() => vm.editorPreferences.setFlightCameraControl(FlightCameraControlType.rmbHeld));

    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final boundaryKey = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: boundaryKey,
      child: ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)),
    ));
    await _settle(tester, 60);
    final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
    Future<void> shot(String name) async => SmokeArtifacts.saveScreenshot(
        name, await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey)));
    List<double> pan() => [vm.cameraPanX, vm.cameraPanY, vm.cameraPanZ];
    double dist(List<double> a, List<double> b) =>
        math.sqrt([for (var i = 0; i < 3; i++) (a[i] - b[i]) * (a[i] - b[i])].reduce((x, y) => x + y));
    final viewport = find.byType(ViewportWidget);
    await rec.hold(const Duration(milliseconds: 800));
    await shot('viewport_wasd_before_flight');

    // --- the default: hold the right button and fly ------------------------
    expect(vm.editorPreferences.flightCameraControl, FlightCameraControlType.rmbHeld);
    final rmb = await tester.startGesture(tester.getCenter(viewport),
        kind: PointerDeviceKind.mouse, buttons: kSecondaryMouseButton);
    await rec.hold(const Duration(milliseconds: 300));
    final flown = <String, double>{};
    for (final key in [
      LogicalKeyboardKey.keyW,
      LogicalKeyboardKey.keyD,
      LogicalKeyboardKey.keyE,
      LogicalKeyboardKey.keyS,
      LogicalKeyboardKey.keyA,
      LogicalKeyboardKey.keyQ,
    ]) {
      final before = pan();
      await tester.sendKeyDownEvent(key);
      await rec.hold(const Duration(milliseconds: 700));
      await tester.sendKeyUpEvent(key);
      await rec.hold(const Duration(milliseconds: 200));
      flown[key.keyLabel] = dist(before, pan());
    }
    // Shift: faster.
    var before = pan();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyW);
    await rec.hold(const Duration(milliseconds: 700));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyW);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    final boosted = dist(before, pan());
    await rec.hold(const Duration(milliseconds: 200));
    await rmb.up();
    await _settle(tester, 4);
    debugPrint('[viewport_wasd_smoke] RMB flight cm per key: $flown, Shift+W ${boosted.toStringAsFixed(0)}');
    for (final entry in flown.entries) {
      expect(entry.value, greaterThan(20.0), reason: 'RMB + ${entry.key} must fly the camera');
    }
    expect(boosted, greaterThan(flown['W']! * 1.5), reason: 'Shift flies faster');
    expect(vm.activeTool, 'select', reason: 'the fly keys are not the tool shortcuts while flying');
    await shot('viewport_wasd_rmb_flight');

    // Without the button, W is the Move tool (the default).
    await tester.tapAt(tester.getCenter(viewport) + const Offset(0, 250), kind: PointerDeviceKind.mouse);
    await _settle(tester, 4);
    // The smoke's window lives on the real desktop session, and on this
    // machine HardwareKeyboard reports a modifier from that session as held
    // (Alt Left, on every run): simulated key events carry no modifier state
    // the embedder could resynchronise it from, as a real key event would.
    // Release strays before checking the plain-W shortcut (an Alt+W is not
    // the Move tool).
    for (final key in HardwareKeyboard.instance.logicalKeysPressed.toList()) {
      debugPrint('[viewport_wasd_smoke] releasing stray pressed key: ${key.debugName}');
      await tester.sendKeyUpEvent(key);
    }
    before = pan();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyW);
    await rec.hold(const Duration(milliseconds: 500));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyW);
    expect(dist(before, pan()), lessThan(1e-6));
    expect(vm.activeTool, 'translate');

    // --- Edit → Editor Preferences → "Always" ------------------------------
    await _menu(tester, rec, 'Edit', 'Editor Preferences');
    await rec.hold(const Duration(milliseconds: 800));
    expect(find.text('Flight Camera Control Type'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('editor_prefs_flight_camera_control')));
    await _settle(tester, 6);
    await rec.hold(const Duration(milliseconds: 600));
    await tester.tap(find.text(FlightCameraControlType.always.label).last);
    await _settle(tester, 6);
    await rec.hold(const Duration(milliseconds: 900));
    expect(vm.editorPreferences.flightCameraControl, FlightCameraControlType.always);
    await shot('viewport_wasd_editor_preferences_always');

    // Back to the level; a click gives the viewport the keyboard.
    vm.selectTab(0);
    await _settle(tester, 6);
    await tester.tapAt(tester.getCenter(viewport) + const Offset(0, 250), kind: PointerDeviceKind.mouse);
    await _settle(tester, 4);
    vm.setActiveTool('select');
    for (final key in [LogicalKeyboardKey.keyW, LogicalKeyboardKey.keyA, LogicalKeyboardKey.keyE]) {
      before = pan();
      await tester.sendKeyDownEvent(key);
      await rec.hold(const Duration(milliseconds: 700));
      await tester.sendKeyUpEvent(key);
      await rec.hold(const Duration(milliseconds: 200));
      expect(dist(before, pan()), greaterThan(20.0), reason: '"Always": ${key.keyLabel} flies with no button held');
    }
    expect(vm.activeTool, 'select');
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await rec.hold(const Duration(milliseconds: 400));
    expect(vm.activeTool, 'translate', reason: 'Space cycles the transform tools');
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await rec.hold(const Duration(milliseconds: 600));
    expect(vm.activeTool, 'rotate');
    await shot('viewport_wasd_always_flight');

    rec.save('Viewport Smoke Scenario: WASD flight with the right button held, then Editor Preferences → Always');
  });

  testWidgets('Viewport Smoke Scenario: view modes Lit → Wireframe → Unlit → Lit on the Third Person level',
      (tester) async {
    // Wireframe — every mesh actor as edge lines only, the
    // solid renderables out of the scene, the header label following the mode;
    // Unlit and Lit bring the solids back. Driven through the View menu (the
    // same field the toolbar select writes), on video with a PNG per state.
    final root = Directory.systemTemp.createTempSync('viewport_smoke_viewmodes_');
    addTearDown(() => root.deleteSync(recursive: true));
    final projectDir = (await tester.runAsync(
        () => scaffoldGameProject(root, name: 'viewmodes_smoke', widgetLibrary: 'flutter')))!;
    final project = LuminaProject.fromMap(Map<String, dynamic>.from(
        jsonDecode(File('$projectDir/viewmodes_smoke.lmproject').readAsStringSync()) as Map));
    final vm = EditorViewModel(initialProject: project, projectLocation: root.path);
    await tester.runAsync(vm.ensureDefaultLevelAssets);

    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final boundaryKey = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: boundaryKey,
      child: ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)),
    ));
    dynamic viewport() => tester.state(find.byType(ViewportWidget));
    final meshActors = vm.actors.where((a) => a.meshData != null && a.meshData!.indices.isNotEmpty).length;
    expect(meshActors, greaterThan(0), reason: 'the Third Person level places meshes');
    for (var i = 0; i < 400 && viewport().editorActorsInSceneForTest < meshActors; i++) {
      await _settle(tester, 1);
    }
    expect(viewport().editorActorsInSceneForTest, meshActors, reason: 'every mesh actor drawn solid in Lit');
    final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
    Future<void> shot(String name) async => SmokeArtifacts.saveScreenshot(
        name, await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey)));
    await rec.hold(const Duration(seconds: 2));
    expect(find.text('Perspective  |  Lit  |  Realtime'), findsOneWidget);
    await shot('viewport_view_mode_lit');

    // View → Wireframe.
    await _menu(tester, rec, 'View', 'Wireframe');
    expect(vm.viewMode, 'Wireframe');
    for (var i = 0; i < 120 && viewport().meshWiresForTest.length < meshActors; i++) {
      await _settle(tester, 1);
    }
    await rec.hold(const Duration(seconds: 3));
    expect(viewport().meshWiresForTest.length, meshActors, reason: 'one wireframe per mesh actor');
    expect(viewport().editorActorsInSceneForTest, 0, reason: 'no filled surface in Wireframe');
    expect(find.text('Perspective  |  Wireframe  |  Realtime'), findsOneWidget, reason: 'the header follows');
    // A selected actor takes the selection colour: rebuilt for it.
    final first = vm.actors.firstWhere((a) => a.meshData != null && a.meshData!.indices.isNotEmpty);
    vm.selectActorById(first.id);
    await _settle(tester, 6);
    await rec.hold(const Duration(seconds: 2));
    await shot('viewport_view_mode_wireframe');

    // View → Unlit: solids back, edges gone.
    await _menu(tester, rec, 'View', 'Unlit');
    expect(vm.viewMode, 'Unlit');
    for (var i = 0; i < 120 && viewport().editorActorsInSceneForTest < meshActors; i++) {
      await _settle(tester, 1);
    }
    await rec.hold(const Duration(seconds: 2));
    expect(viewport().meshWiresForTest, isEmpty);
    expect(viewport().editorActorsInSceneForTest, meshActors);
    expect(find.text('Perspective  |  Unlit  |  Realtime'), findsOneWidget);
    await shot('viewport_view_mode_unlit');

    // View → Lit: the round trip.
    await _menu(tester, rec, 'View', 'Lit');
    expect(vm.viewMode, 'Lit');
    await rec.hold(const Duration(seconds: 2));
    expect(viewport().meshWiresForTest, isEmpty);
    expect(viewport().editorActorsInSceneForTest, meshActors);
    expect(find.text('Perspective  |  Lit  |  Realtime'), findsOneWidget);
    await shot('viewport_view_mode_lit_again');

    rec.save('Viewport Smoke Scenario: view modes Lit → Wireframe → Unlit → Lit on the Third Person level');
  });
}
