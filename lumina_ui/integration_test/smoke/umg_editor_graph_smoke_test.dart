import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
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
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/umg_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/graph_canvas.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/umg/widget_sub_editor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// UMG graph smoke — the Widget Blueprint graph, end to end, split from
/// `umg_editor_smoke_test.dart` (that file is near the 1100-line cap). A
/// launcher Third Person project; WBP_Clicker gets a Button and a Text from
/// the palette, both Is Variable; Details ▸ Widget Events `+ OnClicked`
/// opens the Graph with `On Clicked (StartButton)`; `Get Title` dragged out
/// of My Blueprint ▸ Widgets and `Set Text (Text) "Clicked!"` from the
/// palette are wired; Compile writes the widget with its graph; the Third
/// Person character's BeginPlay creates it and adds it to the viewport;
/// Play (GPU 1), a click on the button, and the text changes — the VM
/// running the graph.
const _scenario = 'UMG Smoke: widget blueprint graph';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(_scenario, (tester) async {
    final root = Directory.systemTemp.createTempSync('lumina_smoke_umg05_');
    addTearDown(() => root.deleteSync(recursive: true));
    const name = 'umg_graph_smoke';
    final repo = ProjectRepository();
    await tester.runAsync(() async {
      await for (final p in repo.createProjectStream(
          projectName: name, projectLocation: root.path, template: kThirdPersonTemplateId, widgetLibrary: kUmgWidgetLibraryFlutter)) {
        debugPrint('[create] ${p.message}');
      }
    });
    final projectDir = '${root.path}/$name';
    const characterPath = 'contents/blueprints/BP_ThirdPersonCharacter.lmas';
    expect(File('$projectDir/$characterPath').existsSync(), isTrue);

    final project = (await tester.runAsync(() => repo.loadProject('$projectDir/$name.lmproject')))!;
    final vm = EditorViewModel(initialProject: project, projectLocation: root.path);
    await tester.runAsync(vm.ensureDefaultLevelAssets);
    final wbpPath = await vm.createWidgetBlueprint(name: 'WBP_Clicker');
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
    Future<File> shot(String file) async =>
        SmokeArtifacts.saveScreenshot(file, await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey)));
    await rec.hold(const Duration(milliseconds: 800));

    // --- Designer: a Button and a Text from the palette ---------------------
    vm.openSubEditorTab('WIDGET', asset: widgetAsset);
    await settle(20);
    expect(find.byType(UMGWidgetSubEditor), findsOneWidget);
    final umg = (tester.state(find.byType(UMGWidgetSubEditor)) as dynamic).viewModelForTest as UmgEditorViewModel;
    umg.snapToGrid = false;

    Future<UmgNode> dropFromPalette(UmgWidgetType type, Offset fraction) async {
      final item = find.byKey(ValueKey('umg_palette_${type.name}'));
      final rect = tester.getRect(find.byKey(const ValueKey('umg_canvas_surface')));
      final target = rect.topLeft + Offset(rect.width * fraction.dx, rect.height * fraction.dy);
      final start = tester.getCenter(item);
      final gesture = await tester.startGesture(start);
      await settle(4);
      for (var i = 1; i <= 12; i++) {
        await gesture.moveTo(Offset.lerp(start, target, i / 12)!);
        await settle(1);
        await rec.capture();
      }
      await gesture.moveTo(target + const Offset(1, 0));
      await settle(4);
      await gesture.up();
      await settle(8);
      await rec.hold(const Duration(milliseconds: 500));
      return umg.document.root.children.last;
    }

    final button = await dropFromPalette(UmgWidgetType.button, const Offset(0.4, 0.45));
    final title = await dropFromPalette(UmgWidgetType.text, const Offset(0.4, 0.3));
    expect(umg.rename(button.id, 'StartButton'), isTrue);
    expect(umg.rename(title.id, 'Title'), isTrue);
    umg.setProp(button.id, 'label', 'Start');
    umg.setProp(title.id, 'text', 'Press Start');
    umg.setProp(title.id, 'fontSize', 40.0);
    umg.setCanvasSize(button.id, const Size(220, 64));
    umg.setCanvasSize(title.id, const Size(420, 64));
    umg.select(button.id);
    await settle(8);
    expect(umg.document.findNode(button.id)!.isVariable, isTrue, reason: 'a Button is a variable by default');
    expect(umg.document.findNode(title.id)!.isVariable, isTrue, reason: 'a Text is a variable by default');
    expect(find.byKey(ValueKey('umg_is_variable_${button.id}')), findsOneWidget);
    await rec.hold(const Duration(milliseconds: 900));
    await shot('umg_graph_designer');

    // --- Details ▸ Widget Events: + OnClicked opens the Graph ---------------
    final plus = find.byKey(ValueKey('umg_event_add_OnClicked_${button.id}'));
    await tester.ensureVisible(plus);
    await settle(8);
    await rec.hold(const Duration(milliseconds: 600));
    await tester.tap(plus);
    await settle(20);
    expect(umg.mode, UmgEditorMode.graph);
    expect(find.byKey(const ValueKey('blueprint_event_graph_canvas')), findsOneWidget);
    final graph = umg.graphEditor;
    final clicked = graph.boundEventNode('StartButton', 'OnClicked')!;
    expect(graph.eventGraph.selectedNodeIds, {clicked.id});
    await rec.hold(const Duration(milliseconds: 900));

    final canvas = find.byType(BlueprintGraphCanvas);
    BlueprintGraphCanvasState state() => tester.state<BlueprintGraphCanvasState>(canvas);
    Offset topLeft() => tester.getTopLeft(canvas);
    Offset screen(double x, double y) => topLeft() + Offset(x, y) * state().zoom + state().panOffset;
    Offset pin(String nodeId, String pinId, {required bool output}) => topLeft() + state().pinScreenPosition(nodeId, pinId, output: output)!;
    state().frameCanvasPoint(Offset(clicked.x + 300, clicked.y + 120));
    await settle(6);

    // Get Title: dragged out of My Blueprint ▸ Widgets.
    final titleRow = find.byKey(const ValueKey('widget_variable_row_Title'));
    final myBlueprint = find.descendant(of: find.byKey(const ValueKey('bp_my_blueprint')), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(titleRow, 80, scrollable: myBlueprint);
    state().frameCanvasPoint(Offset(clicked.x + 300, clicked.y + 120));
    await settle(10);
    var before = graph.eventGraph.nodes.map((n) => n.id).toSet();
    // Sideways first, so the drag wins over My Blueprint's vertical scroll.
    final from = tester.getCenter(titleRow);
    final to = screen(clicked.x + 40, clicked.y + 200);
    final drag = await tester.startGesture(from);
    await rec.hold(const Duration(milliseconds: 100));
    for (var i = 1; i <= 6; i++) {
      await drag.moveTo(from + Offset(12.0 * i, 0));
      await settle(1);
    }
    final side = from + const Offset(72, 0);
    for (var i = 1; i <= 16; i++) {
      await drag.moveTo(Offset.lerp(side, to, i / 16)!);
      await settle(1);
      await rec.capture();
    }
    await drag.up();
    await settle(8);
    final getTitle = graph.eventGraph.nodes.firstWhere((n) => !before.contains(n.id));
    expect(getTitle.registryId, LuminaBlueprintNodeLibrary.getWidgetVariable);
    expect(graph.eventGraph.pin(getTitle.id, 'return_value', output: true)!.objectClass, 'WidgetElement:text');

    // Set Text (Text) from the right-click palette.
    await tester.tapAt(screen(clicked.x + 380, clicked.y), buttons: kSecondaryButton);
    await settle();
    await rec.typeText(find.byKey(const ValueKey('palette_search')), 'set text', perCharacter: const Duration(milliseconds: 40));
    await settle();
    await rec.hold(const Duration(milliseconds: 500));
    before = graph.eventGraph.nodes.map((n) => n.id).toSet();
    await tester.tap(find.byKey(const ValueKey('palette_entry_set_element_text')));
    await settle(8);
    final setText = graph.eventGraph.nodes.firstWhere((n) => !before.contains(n.id));
    expect(setText.registryId, 'set_element_text');

    await rec.drag(pin(clicked.id, 'exec_out', output: true), pin(setText.id, 'exec_in', output: false), steps: 12);
    await settle(6);
    await rec.drag(pin(getTitle.id, 'return_value', output: true), pin(setText.id, 'target', output: false), steps: 12);
    await settle(6);
    expect(graph.eventGraph.graph.wires.where((w) => w.fromNodeId == clicked.id && w.toNodeId == setText.id), hasLength(1));
    expect(graph.eventGraph.graph.wires.where((w) => w.fromNodeId == getTitle.id && w.toNodeId == setText.id), hasLength(1));
    expect(graph.eventGraph.setLiteral(setText.id, 'in_text', 'Clicked!'), isTrue);
    await settle(6);
    await rec.hold(const Duration(milliseconds: 900));
    await shot('umg_graph_event_graph');

    // --- Compile: the widget file with its graph ----------------------------
    await tester.tap(find.byKey(const ValueKey('umg_compile')));
    for (var i = 0; i < 100 && umg.lastCompile == null && umg.compileError == null; i++) {
      await settle(2);
    }
    expect(umg.compileError, isNull);
    expect(umg.isDirty, isFalse);
    final generated = File('$projectDir/lib/widgets/wbp_clicker.dart').readAsStringSync();
    expect(generated, contains('class WbpClickerGraph extends LuminaUserWidget'));
    expect(generated, contains("LuminaUserWidgets.fire(widget.instance, 'StartButton', 'OnClicked');"));
    await tester.tap(find.byKey(const ValueKey('umg_view_generated_code')));
    await settle(8);
    await rec.hold(const Duration(milliseconds: 900));
    await tester.tap(find.byKey(const ValueKey('umg_view_generated_code')));
    await settle(8);

    // --- The character's BeginPlay creates the widget -----------------------
    final character = BlueprintEditorViewModel(assetPath: '$projectDir/$characterPath');
    addTearDown(character.dispose);
    await tester.runAsync(character.load);
    final g = character.eventGraph;
    // The template's Event BeginPlay when it has one, else a new one below its graph.
    final bottom = character.document.eventGraph.nodes.fold<double>(0, (m, n) => n.y > m ? n.y : m);
    final begin = character.document.eventGraph.nodes.where((n) => n.registryId == 'event_beginplay').firstOrNull ??
        g.addNode('event_beginplay', Offset(0, bottom + 400))!;
    // The end of BeginPlay's chain: the widget is shown after the template's setup.
    var tail = begin;
    for (var guard = 0; guard < 64; guard++) {
      final next = character.document.eventGraph.wires
          .where((w) => w.fromNodeId == tail.id && character.document.eventGraph.node(w.toNodeId) != null)
          .where((w) => g.pin(tail.id, w.fromPinId, output: true)?.type == LuminaPinType.exec)
          .firstOrNull;
      if (next == null) break;
      tail = character.document.eventGraph.node(next.toNodeId)!;
    }
    final tailExec = g.pinsOf(tail).outputs.firstWhere((p) => p.type == LuminaPinType.exec).id;
    final create = g.addNode('create_widget', Offset(tail.x + 360, tail.y), literals: {'class': 'WBP_Clicker'})!;
    final add = g.addNode('add_to_viewport', Offset(tail.x + 700, tail.y))!;
    expect(g.addWire(fromNodeId: tail.id, fromPinId: tailExec, toNodeId: create.id, toPinId: 'exec_in'), isNotNull);
    expect(g.addWire(fromNodeId: create.id, fromPinId: 'exec_out', toNodeId: add.id, toPinId: 'exec_in'), isNotNull);
    expect(g.addWire(fromNodeId: create.id, fromPinId: 'return_value', toNodeId: add.id, toPinId: 'target'), isNotNull);
    expect(await tester.runAsync(character.save), isTrue);

    // --- Play: click the button, the text changes (VM) ----------------------
    vm.selectTab(0);
    await settle(10);
    await tester.tap(find.byKey(const ValueKey('toolbar_play')));
    for (var i = 0; i < 150 && !vm.pieController.isPlaying; i++) {
      await settle(2);
    }
    final pie = vm.pieController;
    expect(pie.isPlaying, isTrue, reason: 'blocked: ${vm.playBlockers} error: ${pie.lastError}');
    for (var i = 0; i < 90 && find.descendant(of: find.byType(PieWidgetLayer), matching: find.text('Start')).evaluate().isEmpty; i++) {
      await settle(2);
      await rec.capture();
    }
    final startButton = find.descendant(of: find.byType(PieWidgetLayer), matching: find.text('Start'));
    expect(startButton, findsOneWidget, reason: 'BeginPlay added WBP_Clicker to the viewport');
    final world = pie.game!.gameInstance.world!;
    final instance = world.getSubsystem<LuminaWidgetSubsystem>()!.widgets.single;
    expect(LuminaUserWidgets.of(instance), isA<LuminaBlueprintUserWidget>(), reason: 'the VM runs the widget graph in Play');
    // F4 gives the mouse back so the click reaches the widget.
    await tester.sendKeyEvent(LogicalKeyboardKey.f4);
    pie.mouseCapture.release();
    for (var i = 0; i < 30; i++) {
      await settle(2);
      await rec.capture();
    }
    expect(find.descendant(of: find.byType(PieWidgetLayer), matching: find.text('Press Start')), findsOneWidget);
    await shot('umg_graph_pie_before_click');
    await tester.tap(startButton);
    for (var i = 0; i < 20; i++) {
      await settle(2);
      await rec.capture();
    }
    expect(find.descendant(of: find.byType(PieWidgetLayer), matching: find.text('Clicked!')), findsOneWidget,
        reason: 'On Clicked (StartButton) → Set Text (Title) ran in the VM');
    final titleState = (instance['elements']! as Map)['Title'] as Map;
    expect(titleState['text'], 'Clicked!');
    await rec.hold(const Duration(milliseconds: 1500));
    await shot('umg_graph_pie_after_click');
    await tester.tap(find.byKey(const ValueKey('toolbar_stop')));
    await settle(30);
    expect(pie.isPlaying, isFalse);
    await rec.hold(const Duration(milliseconds: 600));

    final video = rec.save(_scenario);
    expect(SmokeArtifacts.videoDurationSeconds(video)!, greaterThanOrEqualTo(10.0));
    debugPrint('[umg05_smoke] ${jsonEncode({'widget': wbpPath, 'generatedBytes': generated.length})}');
  }, timeout: const Timeout(Duration(minutes: 25)));
}
