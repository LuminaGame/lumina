import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lumina_core/lumina_core.dart' show kThirdPersonTemplateId;
import 'package:lumina/lumina.dart' hide BoxShape;
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/main_editor/views/pie_widget_layer.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/umg_document.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/umg_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/umg/widget_sub_editor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../test/helpers/scaffold_game_project.dart';

/// Smoke — the user's report, end to end on GPU 1: a level
/// whose Level Blueprint runs `Event BeginPlay → Create Widget (WBP_Menu) →
/// Add to Viewport → Set Show Mouse Cursor (true)` with Target unwired, and
/// a widget whose button's On Clicked runs `Open Level (L_Target)`. In Play
/// the pointer is free without F4 (the game asked for the cursor), a click
/// on the button reaches the widget, and L_Target loads. A real barrel from
/// test-assets stands in the level.
const _scenario = 'PIE Smoke: Set Show Mouse Cursor frees the pointer and a click on the widget opens the next level';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(_scenario, (tester) async {
    final barrel = File('${SmokeArtifacts.testAssetsDir.path}/Props/Barrels/fuel_barrel_red.glb');
    expect(barrel.existsSync(), isTrue, reason: 'test-assets must hold the barrel');
    final root = Directory.systemTemp.createTempSync('lumina_smoke_bugs61_');
    addTearDown(() {
      try {
        root.deleteSync(recursive: true);
      } catch (_) {}
    });
    const name = 'cursor_smoke';
    final dir = (await tester.runAsync(
        () => scaffoldGameProject(root, name: name, widgetLibrary: 'flutter', template: kThirdPersonTemplateId)))!;
    final project = (await tester.runAsync(() => ProjectRepository().loadProject('$dir/$name.lmproject')))!;

    // L_Target: a second level to open, and the start level's Level Blueprint.
    final levels = LuminaLevelRepository(dir);
    final start = levels.load(project.activeLevel)!;
    const targetPath = 'contents/levels/L_Target.lmas';
    levels.save(LuminaLevelDocument(relativePath: targetPath)..actors = start.actors);
    final script = LuminaLevelBlueprintDocument(levelPath: start.relativePath);
    final context = LuminaBlueprintTypeContext.forLevel(script, levelActors: start.levelActorRefs);
    LuminaBlueprintNode p(String id, String nodeId, [Map<String, dynamic>? literals]) =>
        LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: context);
    script.blueprint.eventGraph.nodes.addAll([
      p('event_level_begin_play', 'begin'),
      p('create_widget', 'create', {'class': 'WBP_Menu'}),
      p('add_to_viewport', 'add'),
      p('set_show_mouse_cursor', 'cursor', {'show_mouse_cursor': true}),
    ]);
    script.blueprint.eventGraph.wires.addAll(const [
      LuminaBlueprintWire(id: 'w0', fromNodeId: 'begin', fromPinId: 'exec_out', toNodeId: 'create', toPinId: 'exec_in'),
      LuminaBlueprintWire(id: 'w1', fromNodeId: 'create', fromPinId: 'exec_out', toNodeId: 'add', toPinId: 'exec_in'),
      LuminaBlueprintWire(id: 'w2', fromNodeId: 'create', fromPinId: 'return_value', toNodeId: 'add', toPinId: 'target'),
      LuminaBlueprintWire(id: 'w3', fromNodeId: 'add', fromPinId: 'exec_out', toNodeId: 'cursor', toPinId: 'exec_in'),
    ]);
    levels.saveLevelBlueprint(script);

    final vm = EditorViewModel(initialProject: project, projectLocation: root.path);
    await tester.runAsync(vm.ensureDefaultLevelAssets);
    await tester.runAsync(() => vm.processImportPipeline(sourceFilePath: barrel.path));
    vm.refreshAssets();
    final barrelMesh = vm.realAssets.firstWhere((a) => a.type == AssetType.filamesh && a.fileName.contains('fuel_barrel_red'));
    await tester.runAsync(() => vm.spawnActorFromAsset(barrelMesh, location: [150.0, 0.0, 0.0]));
    final wbpPath = await vm.createWidgetBlueprint(name: 'WBP_Menu');
    vm.refreshAssets();
    final widgetAsset = vm.realAssets.firstWhere((a) => a.relativePath == wbpPath);

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
    await settle(30);
    final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
    final usedAssets = [barrel.path];
    Future<void> shot(String file) async {
      SmokeArtifacts.saveScreenshot(file, await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey)),
          usedAssets: usedAssets);
      await rec.hold(const Duration(milliseconds: 900));
    }

    await rec.hold(const Duration(milliseconds: 800));

    // --- WBP_Menu: a button whose On Clicked opens L_Target -----------------
    vm.openSubEditorTab('WIDGET', asset: widgetAsset);
    await settle(20);
    final umg = (tester.state(find.byType(UMGWidgetSubEditor)) as dynamic).viewModelForTest as UmgEditorViewModel;
    final button = umg.addWidget(UmgWidgetType.button, parentId: umg.document.root.id, canvasPosition: const Offset(120, 120))!;
    expect(umg.rename(button.id, 'OpenButton'), isTrue);
    umg.setProp(button.id, 'label', 'Open Level');
    umg.setCanvasSize(button.id, const Size(260, 72));
    final clicked = umg.bindWidgetEvent(button.id, 'OnClicked')!;
    final graph = umg.graphEditor.eventGraph;
    final open = graph.addNode('open_level', Offset(clicked.x + 360, clicked.y), literals: {'level_name': 'L_Target'})!;
    expect(graph.addWire(fromNodeId: clicked.id, fromPinId: 'exec_out', toNodeId: open.id, toPinId: 'exec_in'), isNotNull);
    await settle(10);
    await rec.hold(const Duration(milliseconds: 900));
    final compiled = (await tester.runAsync(umg.compile))!;
    expect(umg.compileError, isNull, reason: '$compiled');
    await rec.hold(const Duration(milliseconds: 1500));
    await shot('bugs61_widget_open_level_graph');

    // --- Play: the game asked for the cursor; no F4 ---------------------------
    vm.selectTab(0);
    await settle(10);
    await tester.tap(find.byKey(const ValueKey('toolbar_play')));
    for (var i = 0; i < 150 && !vm.pieController.isPlaying; i++) {
      await settle(2);
    }
    final pie = vm.pieController;
    expect(pie.isPlaying, isTrue, reason: 'blocked: ${vm.playBlockers} error: ${pie.lastError}');
    final openButton = find.descendant(of: find.byType(PieWidgetLayer), matching: find.text('Open Level'));
    for (var i = 0; i < 90 && openButton.evaluate().isEmpty; i++) {
      await settle(2);
      await rec.capture();
    }
    expect(openButton, findsOneWidget, reason: 'BeginPlay added WBP_Menu to the viewport');
    for (var i = 0; i < 20; i++) {
      await settle(2);
      await rec.capture();
    }
    final pc = pie.game!.playerController!;
    expect(pc.bShowMouseCursor, isTrue, reason: 'Set Show Mouse Cursor (Target unwired) reached player 0');
    expect(pie.mouseCapture.isSessionActive, isTrue);
    expect(pie.mouseCapture.isCaptured, isFalse, reason: 'the game freed the pointer — no F4');
    expect(pie.mouseCapture.hidesCursor, isFalse, reason: 'the cursor shows over the game view');
    expect(pie.playingLevelPath, start.relativePath);
    await rec.hold(const Duration(seconds: 2));
    await shot('bugs61_pie_cursor_free_widget_shown');

    // --- A click on the button opens L_Target ---------------------------------
    await tester.tap(openButton);
    for (var i = 0; i < 120 && pie.playingLevelPath != targetPath; i++) {
      await settle(2);
      await rec.capture();
    }
    expect(pie.playingLevelPath, targetPath, reason: 'On Clicked → Open Level (L_Target) ran');
    for (var i = 0; i < 30; i++) {
      await settle(2);
      await rec.capture();
    }
    await rec.hold(const Duration(seconds: 2));
    await shot('bugs61_pie_target_level_opened');

    await tester.tap(find.byKey(const ValueKey('toolbar_stop')));
    await settle(30);
    expect(pie.isPlaying, isFalse);
    await rec.hold(const Duration(milliseconds: 600));
    final video = rec.save(_scenario, usedAssets: usedAssets);
    expect(SmokeArtifacts.videoDurationSeconds(video)!, greaterThanOrEqualTo(10.0));
    vm.dispose();
  }, timeout: const Timeout(Duration(minutes: 20)));
}
