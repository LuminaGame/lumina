import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart' hide BoxShape;
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
import 'package:vector_math/vector_math_64.dart' show Vector2;

/// UMG smoke — a settings menu whose Combo Box options carry a label and a
/// Vector 2D value. A launcher Third Person project; WBP_Settings gets a
/// Combo Box `Resolution` and a Text `Status`; the Details panel's option
/// rows get `Native` (0 × 0), `1280×720` and a typed-in `1920×1080` Vector
/// 2D; the graph's Construct adds an option per Get Supported Resolutions
/// entry (label `W×H`, value the Vector 2D, the wildcard Value typed by its
/// wire) and selects the last one (a Direct selection change); On
/// Selection Changed hands Set Screen Resolution the picked Value and shows
/// Selected Item / Index / Select Type.
/// The character's BeginPlay shows the widget; Play (GPU 1), pick
/// `1920×1080`, and the staged resolution is the option's value.
const _scenario = 'UMG Smoke: combo box options with label and value';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(_scenario, (tester) async {
    final root = Directory.systemTemp.createTempSync('lumina_smoke_combo_');
    addTearDown(() => root.deleteSync(recursive: true));
    const name = 'combo_smoke';
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
    final wbpPath = await vm.createWidgetBlueprint(name: 'WBP_Settings');
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
    Future<void> submit(Key key, String text) async {
      await tester.ensureVisible(find.byKey(key));
      await settle(4);
      await tester.tap(find.byKey(key));
      await settle(2);
      await rec.typeText(find.byKey(key), text, perCharacter: const Duration(milliseconds: 60));
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(6);
      await rec.hold(const Duration(milliseconds: 300));
    }

    await rec.hold(const Duration(milliseconds: 800));

    // --- Designer: a Combo Box and a Text -----------------------------------
    vm.openSubEditorTab('WIDGET', asset: widgetAsset);
    await settle(20);
    final umg = (tester.state(find.byType(UMGWidgetSubEditor)) as dynamic).viewModelForTest as UmgEditorViewModel;
    umg.snapToGrid = false;
    final rootId = umg.document.root.id;
    final status = umg.addWidget(UmgWidgetType.text, parentId: rootId, canvasPosition: const Offset(160, 120))!;
    final combo = umg.addWidget(UmgWidgetType.comboBox, parentId: rootId, canvasPosition: const Offset(160, 220))!;
    expect(umg.rename(status.id, 'Status'), isTrue);
    expect(umg.rename(combo.id, 'Resolution'), isTrue);
    umg.setProp(status.id, 'text', 'Pick a resolution');
    umg.setProp(status.id, 'fontSize', 30.0);
    umg.setCanvasSize(status.id, const Size(760, 56));
    umg.setCanvasSize(combo.id, const Size(320, 44));
    umg.setProp(combo.id, 'fontSize', 18.0);
    umg.setProp(combo.id, 'options', [
      LuminaComboBoxOptions.designerEntry('Native', value: [0.0, 0.0], type: 'vector2D'),
      LuminaComboBoxOptions.designerEntry('1280×720', value: [1280.0, 720.0], type: 'vector2D'),
    ]);
    umg.setProp(combo.id, 'selected', 'Native');
    umg.select(combo.id);
    await settle(10);
    await rec.hold(const Duration(milliseconds: 700));

    // Details ▸ Options: a third row typed in as a Vector 2D.
    final addOption = find.byKey(ValueKey('umg_combo_option_add_${combo.id}'));
    await tester.ensureVisible(addOption);
    await settle(6);
    await rec.hold(const Duration(milliseconds: 500));
    await tester.tap(addOption);
    await settle(8);
    await submit(ValueKey('umg_combo_option_label_${combo.id}_2_Option 3'), '1920×1080');
    final typeSelect = find.byKey(ValueKey('umg_combo_option_type_${combo.id}_2'));
    await tester.ensureVisible(typeSelect);
    await settle(4);
    await tester.tap(typeSelect);
    await settle(10);
    await rec.hold(const Duration(milliseconds: 600));
    await tester.tap(find.byKey(ValueKey('umg_combo_option_type_item_${combo.id}_2_vector2D')));
    await settle(10);
    await submit(ValueKey('umg_combo_option_value_${combo.id}_2_0_0.0'), '1920');
    await submit(ValueKey('umg_combo_option_value_${combo.id}_2_1_0.0'), '1080');
    expect(umg.document.findNode(combo.id)!.props['options'], [
      {'label': 'Native', 'value': [0.0, 0.0], 'type': 'vector2D'},
      {'label': '1280×720', 'value': [1280.0, 720.0], 'type': 'vector2D'},
      {'label': '1920×1080', 'value': [1920.0, 1080.0], 'type': 'vector2D'},
    ]);
    await rec.hold(const Duration(milliseconds: 1000));
    await shot('umg_combo_box_options_editor');

    // --- Details ▸ Widget Events: + OnSelectionChanged opens the Graph ------
    final plus = find.byKey(ValueKey('umg_event_add_OnSelectionChanged_${combo.id}'));
    await tester.ensureVisible(plus);
    await settle(6);
    await rec.hold(const Duration(milliseconds: 500));
    await tester.tap(plus);
    await settle(20);
    expect(umg.mode, UmgEditorMode.graph);
    final graph = umg.graphEditor;
    final g = graph.eventGraph;
    final changed = graph.boundEventNode('Resolution', 'OnSelectionChanged')!;
    await rec.hold(const Duration(milliseconds: 600));

    // The rest of the graph, laid out left to right in two rows.
    final x0 = changed.x;
    final top = changed.y - 520;
    LuminaBlueprintNode add(String id, double dx, double dy, [Map<String, dynamic>? literals]) =>
        g.addNode(id, Offset(x0 + dx, top + dy), literals: literals)!;
    void link(LuminaBlueprintNode from, String fromPin, LuminaBlueprintNode to, String toPin) =>
        expect(g.addWire(fromNodeId: from.id, fromPinId: fromPin, toNodeId: to.id, toPinId: toPin), isNotNull,
            reason: '${from.registryId}.$fromPin → ${to.registryId}.$toPin');
    final construct = add(LuminaBlueprintNodeLibrary.eventWidgetConstruct, 0, 0);
    final res = add(LuminaBlueprintNodeLibrary.getWidgetVariable, 0, 200, {'element': 'Resolution'});
    final supported = add('get_supported_resolutions', 0, 320);
    final loop = add('for_each_loop', 300, 0);
    final size = add('break_vector2d', 300, 260);
    final w = add('round', 560, 220);
    final h = add('round', 560, 320);
    final wText = add('int_to_string', 760, 220);
    final hText = add('int_to_string', 760, 320);
    final label = add('format_string', 960, 220, {'format': '{0}×{1}'});
    final addOptionNode = add('add_element_option', 1240, 0);
    final pick = add('set_element_selected_index', 1240, 260);
    final count = add('get_element_option_count', 960, 380);
    final last = add('int_subtract', 1120, 380, {'b': 1});
    await settle(4);
    link(construct, 'exec_out', loop, 'exec_in');
    link(supported, 'return_value', loop, 'array');
    link(loop, 'loop_body', addOptionNode, 'exec_in');
    link(res, 'return_value', addOptionNode, 'target');
    link(loop, 'array_element', size, 'in_vec');
    link(size, 'x', w, 'a');
    link(size, 'y', h, 'a');
    link(w, 'return_value', wText, 'in_int');
    link(h, 'return_value', hText, 'in_int');
    link(wText, 'return_value', label, 'arg_0');
    link(hText, 'return_value', label, 'arg_1');
    link(label, 'return_value', addOptionNode, 'option');
    link(loop, 'array_element', addOptionNode, 'value');
    link(loop, 'completed', pick, 'exec_in');
    link(res, 'return_value', pick, 'target');
    link(res, 'return_value', count, 'target');
    link(count, 'return_value', last, 'a');
    link(last, 'return_value', pick, 'index');
    expect(addOptionNode.literals['type'], 'vector2D', reason: 'the wildcard Value took the loop element\'s type');

    final chosen = add('break_vector2d', 300, 760);
    final cw = add('round', 560, 720);
    final ch = add('round', 560, 820);
    final apply = add('set_screen_resolution', 760, 520);
    final statusGet = add(LuminaBlueprintNodeLibrary.getWidgetVariable, 760, 760, {'element': 'Status'});
    final indexText = add('int_to_string', 760, 880);
    final how = add('enum_to_string', 760, 980);
    final summary = add('format_string', 1000, 840, {'format': '{0}   ·   index {1}   ·   {2}'});
    final show = add('set_element_text', 1240, 520);
    await settle(4);
    link(changed, 'exec_out', apply, 'exec_in');
    link(changed, 'value', chosen, 'in_vec');
    expect(changed.literals['type'], 'vector2D', reason: 'On Selection Changed\'s Value took Break Vector 2D\'s type');
    link(chosen, 'x', cw, 'a');
    link(chosen, 'y', ch, 'a');
    link(cw, 'return_value', apply, 'width');
    link(ch, 'return_value', apply, 'height');
    link(apply, 'exec_out', show, 'exec_in');
    link(statusGet, 'return_value', show, 'target');
    link(changed, 'selected_item', summary, 'arg_0');
    link(changed, 'index', indexText, 'in_int');
    link(indexText, 'return_value', summary, 'arg_1');
    link(changed, 'select_type', how, 'value');
    link(how, 'return_value', summary, 'arg_2');
    link(summary, 'return_value', show, 'in_text');

    // Frame the whole graph: zoom out on the canvas, centre it.
    final canvas = find.byType(BlueprintGraphCanvas);
    final mouse = TestPointer(7, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(mouse.hover(tester.getCenter(canvas)));
    for (var i = 0; i < 5; i++) {
      await tester.sendEventToBinding(mouse.scroll(const Offset(0, 40)));
      await settle(3);
      await rec.capture();
    }
    tester.state<BlueprintGraphCanvasState>(canvas).frameCanvasPoint(Offset(x0 + 700, top + 480));
    await settle(10);
    await rec.hold(const Duration(milliseconds: 1500));
    await shot('umg_combo_box_graph');

    // --- Compile: the widget file with its graph ----------------------------
    await tester.tap(find.byKey(const ValueKey('umg_compile')));
    for (var i = 0; i < 100 && umg.lastCompile == null && umg.compileError == null; i++) {
      await settle(2);
    }
    expect(umg.compileError, isNull);
    final generated = File('$projectDir/lib/widgets/wbp_settings.dart').readAsStringSync();
    expect(generated, contains('void _onSelectionChangedResolution(LuminaComboBoxSelection selection) {'));
    expect(generated, contains('LuminaBlueprintFunctionLibrary.addElementOption(this, '));
    expect(generated, contains("case ('Resolution', 'OnSelectionChanged'):"));

    // --- The character's BeginPlay shows the widget -------------------------
    final character = BlueprintEditorViewModel(assetPath: '$projectDir/$characterPath');
    addTearDown(character.dispose);
    await tester.runAsync(character.load);
    final cg = character.eventGraph;
    final bottom = character.document.eventGraph.nodes.fold<double>(0, (m, n) => n.y > m ? n.y : m);
    final begin = character.document.eventGraph.nodes.where((n) => n.registryId == 'event_beginplay').firstOrNull ??
        cg.addNode('event_beginplay', Offset(0, bottom + 400))!;
    var tail = begin;
    for (var guard = 0; guard < 64; guard++) {
      final next = character.document.eventGraph.wires
          .where((w) => w.fromNodeId == tail.id && character.document.eventGraph.node(w.toNodeId) != null)
          .where((w) => cg.pin(tail.id, w.fromPinId, output: true)?.type == LuminaPinType.exec)
          .firstOrNull;
      if (next == null) break;
      tail = character.document.eventGraph.node(next.toNodeId)!;
    }
    final tailExec = cg.pinsOf(tail).outputs.firstWhere((p) => p.type == LuminaPinType.exec).id;
    final create = cg.addNode('create_widget', Offset(tail.x + 360, tail.y), literals: {'class': 'WBP_Settings'})!;
    final show2 = cg.addNode('add_to_viewport', Offset(tail.x + 700, tail.y))!;
    expect(cg.addWire(fromNodeId: tail.id, fromPinId: tailExec, toNodeId: create.id, toPinId: 'exec_in'), isNotNull);
    expect(cg.addWire(fromNodeId: create.id, fromPinId: 'exec_out', toNodeId: show2.id, toPinId: 'exec_in'), isNotNull);
    expect(cg.addWire(fromNodeId: create.id, fromPinId: 'return_value', toNodeId: show2.id, toPinId: 'target'), isNotNull);
    expect(await tester.runAsync(character.save), isTrue);

    // --- Play: pick 1920×1080 (VM) ------------------------------------------
    vm.selectTab(0);
    await settle(10);
    await tester.tap(find.byKey(const ValueKey('toolbar_play')));
    for (var i = 0; i < 150 && !vm.pieController.isPlaying; i++) {
      await settle(2);
    }
    final pie = vm.pieController;
    expect(pie.isPlaying, isTrue, reason: 'blocked: ${vm.playBlockers} error: ${pie.lastError}');
    Finder inPie(Finder f) => find.descendant(of: find.byType(PieWidgetLayer), matching: f);
    for (var i = 0; i < 90 && inPie(find.byType(Select<String>)).evaluate().isEmpty; i++) {
      await settle(2);
      await rec.capture();
    }
    expect(inPie(find.byType(Select<String>)), findsOneWidget, reason: 'BeginPlay added WBP_Settings to the viewport');
    final world = pie.game!.gameInstance.world!;
    final instance = world.getSubsystem<LuminaWidgetSubsystem>()!.widgets.single;
    final resState = (instance['elements']! as Map)['Resolution'] as Map<String, Object?>;
    final labels = LuminaComboBoxOptions.labels(resState['options']);
    expect(labels.take(3), ['Native', '1280×720', '1920×1080']);
    expect(labels.length, greaterThan(3), reason: 'Construct added the supported resolutions: $labels');
    expect(LuminaBlueprintFunctionLibrary.getElementOptionValue(resState, labels.length - 1), isA<Vector2>());
    await tester.sendKeyEvent(LogicalKeyboardKey.f4);
    pie.mouseCapture.release();
    for (var i = 0; i < 30; i++) {
      await settle(2);
      await rec.capture();
    }
    expect(inPie(find.textContaining('${labels.last}   ·   index ${labels.length - 1}   ·   Direct')), findsOneWidget,
        reason: 'Set Selected Index (the last option) ran On Selection Changed (Direct)');
    await tester.tap(inPie(find.byType(Select<String>)));
    for (var i = 0; i < 20; i++) {
      await settle(2);
      await rec.capture();
    }
    await shot('umg_combo_box_pie_open');
    await tester.tap(find.widgetWithText(SelectItemButton<String>, '1920×1080').last);
    for (var i = 0; i < 20; i++) {
      await settle(2);
      await rec.capture();
    }
    expect(inPie(find.textContaining('1920×1080   ·   index 2   ·   OnMouseClick')), findsOneWidget);
    expect(LuminaBlueprintFunctionLibrary.getElementSelection(resState), (returnValue: '1920×1080', value: Vector2(1920, 1080), index: 2));
    expect(world.getSubsystem<LuminaUserSettingsSubsystem>()!.screenResolutionSetting, (1920, 1080),
        reason: 'Set Screen Resolution got the option\'s Vector 2D');
    await rec.hold(const Duration(milliseconds: 1500));
    await shot('umg_combo_box_pie_picked');
    await tester.tap(find.byKey(const ValueKey('toolbar_stop')));
    await settle(30);
    await rec.hold(const Duration(milliseconds: 600));

    final video = rec.save(_scenario);
    expect(SmokeArtifacts.videoDurationSeconds(video)!, greaterThanOrEqualTo(10.0));
    debugPrint('[combo_smoke] ${jsonEncode({'widget': wbpPath, 'options': labels})}');
  }, timeout: const Timeout(Duration(minutes: 25)));
}
