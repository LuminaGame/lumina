import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart' hide BoxShape;
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/pie_blueprint_debug_panel.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/blueprint_debugger.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/level_blueprint_editor_view_model.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../helpers/blueprint_test_project.dart';
import '../helpers/scaffold_game_project.dart';

/// The Level Blueprint in Play-In-Editor: the Level Blueprint authored in the
/// Level Blueprint editor — compiled, not even saved — runs as the level's
/// script when Play starts (BeginPlay → Door_01 → Call Open opens the placed
/// BP_Door), the Blueprint debugger lists it beside the possessed pawn and
/// records its trace, and a breakpoint in it pauses Play on that node.
void main() {
  late Directory root;
  late String dir;
  const name = 'level_bp_pie';
  const levelPath = 'contents/levels/L_DefaultLevel.lmas';
  const doorPath = 'contents/blueprints/BP_Door.lmas';

  setUpAll(() async {
    root = Directory.systemTemp.createTempSync('lumina_level_bp_pie_');
    dir = await scaffoldGameProject(root, name: name, widgetLibrary: 'flutter');
    final door = LuminaBlueprintDocument(parentClass: 'LuminaActor', components: [
      LuminaBlueprintComponent(id: 'root', name: 'DefaultSceneRoot', type: 'LuminaSceneComponent'),
    ]);
    final ctx = LuminaBlueprintTypeContext.forDocument(door, className: 'BP_Door');
    door.eventGraph.nodes.addAll([
      LuminaBlueprintNodeLibrary.place('custom_event', nodeId: 'open', literals: {'name': 'Open'}, context: ctx),
      LuminaBlueprintNodeLibrary.place('print_string', nodeId: 'opened', literals: {'in_string': 'Door opened', 'key': 'door'}, context: ctx),
    ]);
    door.eventGraph.wires.add(const LuminaBlueprintWire(id: 'd0', fromNodeId: 'open', fromPinId: 'exec_out', toNodeId: 'opened', toPinId: 'exec_in'));
    writeBlueprint(dir, 'BP_Door', door);
    final level = LuminaLevelRepository(dir).load(levelPath)!;
    level.actors = [
      ...level.actors,
      {
        'id': 'door_01',
        'name': 'Door_01',
        'type': 'Blueprint',
        'blueprintClass': doorPath,
        'location': [0.0, 400.0, 0.0],
        'rotation': [0.0, 0.0, 0.0],
        'scale': [1.0, 1.0, 1.0],
      },
    ];
    LuminaLevelRepository(dir).save(level);
  });
  tearDownAll(() => root.deleteSync(recursive: true));
  tearDown(() {
    BlueprintPieDebugger.instance.clear();
    BlueprintBreakpoints.instance.clear();
    BlueprintNavigation.instance.take(levelPath);
    LuminaBlueprintActorClasses.clear();
  });

  LuminaProject manifest() =>
      LuminaProject.fromMap(Map<String, dynamic>.from(jsonDecode(File('$dir/$name.lmproject').readAsStringSync()) as Map));

  Future<EditorViewModel> openEditor(WidgetTester tester) async {
    final vm = EditorViewModel(initialProject: manifest(), projectLocation: root.path, enableTimers: false, autoInitAssets: false);
    await tester.runAsync(vm.ensureDefaultLevelAssets);
    vm.refreshAssets();
    return vm;
  }

  /// Level BeginPlay → Door_01 → Call Open; Level Tick → [tickNode] (a
  /// Print "level tick", or a breakpoint before it).
  void authorDoorGraph(LevelBlueprintEditorViewModel bp, {bool breakpoint = false}) {
    final g = bp.eventGraph;
    final begin = g.addNode(LuminaBlueprintNodeLibrary.eventLevelBeginPlay, const Offset(0, 0))!;
    final door = g.placeLevelActor('Door_01', position: const Offset(0, 200))!;
    final open = g.placeEntry(
        g.paletteEntries().singleWhere((e) => e.title == 'Call Open' && e.literals['class'] == 'Actor:BP_Door'), const Offset(320, 0))!;
    g.addWire(fromNodeId: begin.id, fromPinId: 'exec_out', toNodeId: open.id, toPinId: 'exec_in');
    g.addWire(fromNodeId: door.id, fromPinId: 'return_value', toNodeId: open.id, toPinId: 'target');
    final tick = g.addNode(LuminaBlueprintNodeLibrary.eventLevelTick, const Offset(0, 400))!;
    final say = g.addNode('print_string', const Offset(640, 400), literals: {'in_string': 'level tick', 'key': 'tick'})!;
    if (breakpoint) {
      final stop = g.addNode('breakpoint', const Offset(320, 400))!;
      g.addWire(fromNodeId: tick.id, fromPinId: 'exec_tick_out', toNodeId: stop.id, toPinId: 'exec_in');
      g.addWire(fromNodeId: stop.id, fromPinId: 'exec_out', toNodeId: say.id, toPinId: 'exec_in');
    } else {
      g.addWire(fromNodeId: tick.id, fromPinId: 'exec_tick_out', toNodeId: say.id, toPinId: 'exec_in');
    }
  }

  List<String> messages(LuminaWorld world) => [for (final m in world.screenMessages.values) m.text];

  testWidgets('Play runs the open Level Blueprint: the door opens, and the debugger lists and traces the level script',
      (tester) async {
    final vm = await openEditor(tester);
    addTearDown(vm.dispose);
    final bp = vm.openLevelBlueprint();
    authorDoorGraph(bp);
    expect(bp.isDirty, isTrue, reason: 'Play plays the editor\'s graph, saved or not');

    expect(await tester.runAsync(vm.requestPlay), isTrue, reason: '${vm.playBlockers}');
    final pie = vm.pieController;
    final world = LuminaWorld();
    pie.startHeadlessForTest(world);
    final script = world.persistentLevel.scriptActor;
    expect(script, isA<LuminaBlueprintLevelScript>());
    world.tick(1 / 60);
    expect(messages(world), contains('Door opened'), reason: 'Level BeginPlay called Open on Door_01');
    expect(messages(world), contains('level tick'));

    // The debugger follows the level script beside the possessed pawn.
    final targets = BlueprintPieDebugger.instance.targets;
    expect(targets.keys, contains(levelPath));
    expect(identical(targets[levelPath], script), isTrue);
    final recorder = BlueprintPieDebugger.instance.recorderFor(levelPath)!;
    final before = recorder.eventCount;
    world.tick(1 / 60);
    expect(recorder.eventCount, greaterThan(before), reason: 'Level Tick\'s nodes reach the trace');

    tester.view.physicalSize = const Size(1200, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: Scaffold(child: PieBlueprintDebugPanel(viewModel: vm))));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    final level = find.byKey(const ValueKey('pie_debug_target_$levelPath'));
    expect(targets.length, greaterThan(1), reason: 'the Third Person pawn is a Blueprint: $targets');
    expect(level, findsOneWidget, reason: 'the level script is listed beside the pawn');
    await tester.tap(level);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    final panel = tester.state<PieBlueprintDebugPanelState>(find.byType(PieBlueprintDebugPanel));
    expect(panel.debuggedPath, levelPath);
    expect(panel.graphViewModel, isA<LevelBlueprintEditorViewModel>());
    expect(find.text('Debugging L_DefaultLevel (Level Blueprint)'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    pie.stopHeadlessForTest();
    vm.stopSimulation();
  });

  testWidgets('a breakpoint in the Level Blueprint pauses Play on its node', (tester) async {
    final vm = await openEditor(tester);
    addTearDown(vm.dispose);
    final bp = vm.openLevelBlueprint();
    authorDoorGraph(bp, breakpoint: true);
    expect(await tester.runAsync(bp.save), isTrue);

    expect(await tester.runAsync(vm.requestPlay), isTrue, reason: '${vm.playBlockers}');
    final pie = vm.pieController;
    final world = LuminaWorld();
    pie.startHeadlessForTest(world);
    world.tick(1 / 60);
    final hit = BlueprintBreakpoints.instance.current;
    expect(hit, isNotNull);
    expect(hit!.blueprintPath, levelPath);
    expect(bp.document.eventGraph.node(hit.nodeId)?.registryId, 'breakpoint');
    expect(pie.isPaused, isTrue);
    expect(BlueprintNavigation.instance.take(levelPath), hit.nodeId, reason: 'the Level Blueprint editor frames the node');
    pie.stopHeadlessForTest();
    vm.stopSimulation();
  });
}
