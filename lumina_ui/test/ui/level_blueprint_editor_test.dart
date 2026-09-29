import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart' hide BoxShape;
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/toolbar_widget.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_compile_status.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/level_blueprint_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/sub_editor_modal.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../helpers/blueprint_test_project.dart';
import '../helpers/scaffold_game_project.dart';
import '../helpers/temp_project.dart';

/// Blueprints ▸ Open Level Blueprint beside the
/// Perspective dropdown opens the active level's Blueprint in the Blueprint
/// editor configured for a level: Event Graph only, no Components / 3D
/// Viewport / Class Defaults; placed actors become typed references ("Create
/// a Reference to Door_01", the Level Actors palette group, a drag); an
/// outliner rename follows into the graph and a delete is a compile error;
/// Save writes the graph into the level `.lmas` and Save Level keeps it. A
/// real Third Person project on disk, a real BP_Door Blueprint placed in it.
void main() {
  late Directory root;
  late String dir;
  late String pristineLevel;
  const name = 'level_bp_game';
  const levelPath = 'contents/levels/L_DefaultLevel.lmas';
  const doorPath = 'contents/blueprints/BP_Door.lmas';

  setUpAll(() async {
    root = Directory.systemTemp.createTempSync('lumina_level_bp_');
    dir = await scaffoldGameProject(root, name: name, widgetLibrary: 'flutter');
    // BP_Door: its custom event Open prints "Door opened".
    final door = LuminaBlueprintDocument(parentClass: 'LuminaActor', components: [
      LuminaBlueprintComponent(id: 'root', name: 'DefaultSceneRoot', type: 'LuminaSceneComponent'),
    ]);
    final ctx = LuminaBlueprintTypeContext.forDocument(door, className: 'BP_Door');
    door.eventGraph.nodes.addAll([
      LuminaBlueprintNodeLibrary.place('custom_event', nodeId: 'open', literals: {'name': 'Open'}, context: ctx),
      LuminaBlueprintNodeLibrary.place('print_string', nodeId: 'opened', literals: {'in_string': 'Door opened'}, context: ctx),
    ]);
    door.eventGraph.wires.add(const LuminaBlueprintWire(id: 'd0', fromNodeId: 'open', fromPinId: 'exec_out', toNodeId: 'opened', toPinId: 'exec_in'));
    writeBlueprint(dir, 'BP_Door', door);
    // Door_01, a placed BP_Door, beside the template's actors.
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
    pristineLevel = File('$dir/$levelPath').readAsStringSync();
  });
  // A just-disposed editor may still hold the folder on Windows.
  tearDownAll(() => deleteTempProject(root));
  setUp(() => File('$dir/$levelPath').writeAsStringSync(pristineLevel));

  LuminaProject manifest() =>
      LuminaProject.fromMap(Map<String, dynamic>.from(jsonDecode(File('$dir/$name.lmproject').readAsStringSync()) as Map));

  Future<EditorViewModel> openEditor(WidgetTester tester) async {
    final vm = EditorViewModel(initialProject: manifest(), projectLocation: root.path, enableTimers: false, autoInitAssets: false);
    await tester.runAsync(vm.ensureDefaultLevelAssets);
    vm.refreshAssets();
    return vm;
  }

  Future<void> pumpTab(WidgetTester tester, EditorViewModel vm) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final tab = vm.currentTab;
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(
        child: SubEditorWorkspaceWidget(
          key: ValueKey(tab.id),
          assetType: tab.category,
          assetName: tab.title,
          editorViewModel: vm,
          tabId: tab.id,
        ),
      ),
    ));
    await tester.pump();
    await tester.pump();
  }

  /// Scrolls My Blueprint until the row keyed [key] is built and on screen.
  Future<void> scrollMyBlueprintTo(WidgetTester tester, Key key) async {
    final scrollable = find.descendant(of: find.byKey(const ValueKey('bp_my_blueprint')), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(find.byKey(key), 80, scrollable: scrollable);
    await tester.pump();
  }

  /// BeginPlay → Door_01 → Call Open (on BP_Door), wired.
  ({LuminaBlueprintNode begin, LuminaBlueprintNode door, LuminaBlueprintNode open}) authorDoorGraph(LevelBlueprintEditorViewModel bp) {
    final g = bp.eventGraph;
    final begin = g.addNode(LuminaBlueprintNodeLibrary.eventLevelBeginPlay, const Offset(0, 0))!;
    final door = g.placeLevelActor('Door_01', position: const Offset(0, 200))!;
    final entry = g.paletteEntries().singleWhere((e) => e.title == 'Call Open' && e.literals['class'] == 'Actor:BP_Door');
    final open = g.placeEntry(entry, const Offset(320, 0))!;
    expect(g.addWire(fromNodeId: begin.id, fromPinId: 'exec_out', toNodeId: open.id, toPinId: 'exec_in'), isNotNull);
    expect(g.addWire(fromNodeId: door.id, fromPinId: 'return_value', toNodeId: open.id, toPinId: 'target'), isNotNull);
    return (begin: begin, door: door, open: open);
  }

  testWidgets('Blueprints ▸ Open Level Blueprint opens L_DefaultLevel (Level Blueprint): Event Graph only; again focuses it',
      (tester) async {
    final vm = await openEditor(tester);
    addTearDown(vm.dispose);
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: Scaffold(child: ToolbarWidget(viewModel: vm))));

    // The button sits right of the Perspective dropdown.
    final button = find.byKey(const ValueKey('toolbar_blueprints'));
    expect(button, findsOneWidget);
    expect(tester.getTopLeft(button).dx, greaterThan(tester.getTopRight(find.text('Perspective')).dx));

    Future<void> openFromToolbar() async {
      await tester.tap(button);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('blueprints_open_level_blueprint')));
      await tester.pumpAndSettle();
    }

    await openFromToolbar();
    final tabs = vm.openTabs.where((t) => t.title == 'L_DefaultLevel (Level Blueprint)').toList();
    expect(tabs, hasLength(1));
    expect(vm.currentTab.id, EditorViewModel.levelBlueprintTabId(levelPath));
    final count = vm.openTabs.length;

    vm.selectTab(0);
    await openFromToolbar();
    expect(vm.openTabs.length, count, reason: 'one tab per level');
    expect(vm.currentTab.title, 'L_DefaultLevel (Level Blueprint)');
    // Edit ▸ Level Blueprint (Ctrl+Shift+B) is the same command.
    expect(vm.commands.byId('edit.levelBlueprint')?.shortcutLabel, 'Ctrl+Shift+B');
    vm.selectTab(0);
    vm.commands.execute('edit.levelBlueprint');
    expect(vm.openTabs.length, count);
    expect(vm.currentTab.title, 'L_DefaultLevel (Level Blueprint)');

    await pumpTab(tester, vm);
    expect(find.byType(BlueprintSubEditor), findsOneWidget);
    expect(find.text('LEVEL BLUEPRINT · L_DefaultLevel'), findsOneWidget);
    expect(find.byKey(const ValueKey('graph_tab_eventGraph:')), findsOneWidget);
    expect(find.text('Components'), findsNothing);
    expect(find.text('3D Viewport'), findsNothing);
    expect(find.text('Construction Script'), findsNothing);
    expect(find.text('CLASS DEFAULTS'), findsNothing);
    expect(find.byKey(const ValueKey('bp_level_details')), findsOneWidget);
    // My Blueprint lists the level's actors instead of components.
    await scrollMyBlueprintTo(tester, const ValueKey('level_actor_row_PlayerStart'));
    expect(find.byKey(const ValueKey('level_actor_row_PlayerStart')), findsOneWidget);
    await scrollMyBlueprintTo(tester, const ValueKey('level_actor_row_Door_01'));
    expect(find.byKey(const ValueKey('level_actor_row_Door_01')), findsOneWidget);
  });

  testWidgets('Door_01 selected: right-click → Create a Reference to Door_01 places Door_01 typed Actor:BP_Door; '
      'Level Actors lists every placed actor; a Level Actors drag drops a reference', (tester) async {
    final vm = await openEditor(tester);
    addTearDown(vm.dispose);
    final bp = vm.openLevelBlueprint();
    await pumpTab(tester, vm);

    // The palette's Level Actors group: every placed actor, typed.
    final refs = vm.levelActorRefs;
    expect(refs.map((r) => r.name), containsAll(['Door_01', 'PlayerStart']));
    final levelRows = bp.eventGraph
        .paletteEntries()
        .where((e) => e.category == 'Level Actors' && e.registryId == LuminaBlueprintNodeLibrary.getLevelActor)
        .toList();
    expect(levelRows.map((e) => e.title).toSet(), refs.map((r) => r.name).toSet());
    expect(levelRows.singleWhere((e) => e.title == 'Door_01').objectClass, 'Actor:BP_Door');
    // Level-only nodes are offered here, component nodes are not.
    final ids = bp.eventGraph.paletteEntries().map((e) => e.registryId).toSet();
    expect(ids, containsAll([LuminaBlueprintNodeLibrary.eventLevelBeginPlay, LuminaBlueprintNodeLibrary.getLevelActorsOfClass]));
    expect(ids, isNot(contains(LuminaBlueprintNodeLibrary.getComponent)));

    // Select Door_01 in the outliner, right-click the graph.
    vm.selectActorById('door_01');
    await tester.pump();
    final canvas = find.byType(BlueprintGraphCanvas);
    await tester.tapAt(tester.getCenter(canvas), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    final create = find.byKey(const ValueKey('palette_entry_create_reference_Door_01'));
    expect(create, findsOneWidget);
    expect(find.descendant(of: create, matching: find.text('Create a Reference to Door_01')), findsOneWidget);
    // At the top of the menu, above the graph actions.
    expect(tester.getTopLeft(create).dy, lessThan(tester.getTopLeft(find.byKey(const ValueKey('palette_entry_action_add_custom_event'))).dy));
    await tester.tap(create);
    await tester.pumpAndSettle();
    final node = bp.graphNodes.singleWhere((n) => n.registryId == LuminaBlueprintNodeLibrary.getLevelActor);
    expect(node.title, 'Door_01');
    expect(bp.eventGraph.pinsOf(node).outputs.single.objectClass, 'Actor:BP_Door');

    // A drag of PlayerStart (the outliner's actors, in My Blueprint) drops a reference.
    await scrollMyBlueprintTo(tester, const ValueKey('level_actor_row_PlayerStart'));
    final row = find.byKey(const ValueKey('level_actor_row_PlayerStart'));
    final gesture = await tester.startGesture(tester.getCenter(row));
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump();
    await gesture.moveTo(tester.getCenter(canvas) + const Offset(0, 120));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    final start = bp.graphNodes.singleWhere((n) => n.literals['actor'] == 'PlayerStart');
    expect(start.title, 'PlayerStart');
    expect(bp.eventGraph.pinsOf(start).outputs.single.objectClass, 'Actor:LuminaPlayerStart');
  });

  testWidgets('renaming Door_01 to FrontDoor retitles the node and keeps its wires; deleting it is a compile error', (tester) async {
    final vm = await openEditor(tester);
    addTearDown(vm.dispose);
    final bp = vm.openLevelBlueprint();
    final nodes = authorDoorGraph(bp);
    final wiresBefore = bp.graphWires.length;
    expect(await tester.runAsync(bp.compile), isTrue, reason: '${bp.diagnostics}');

    vm.renameActorWithTransaction('door_01', 'FrontDoor');
    final door = bp.document.eventGraph.node(nodes.door.id)!;
    expect(door.title, 'FrontDoor');
    expect(door.literals['actor'], 'FrontDoor');
    expect(bp.graphWires.length, wiresBefore);
    expect(bp.graphWires.where((w) => w.fromNodeId == door.id && w.toNodeId == nodes.open.id), hasLength(1));
    expect(await tester.runAsync(bp.compile), isTrue, reason: '${bp.diagnostics}');
    // Undo in the level editor renames the reference back.
    vm.transactions.undo();
    expect(bp.document.eventGraph.node(nodes.door.id)!.title, 'Door_01');
    vm.transactions.redo();
    expect(bp.document.eventGraph.node(nodes.door.id)!.title, 'FrontDoor');

    vm.removeActorNodes(['door_01']);
    expect(bp.eventGraph.problems(bp.document.eventGraph.node(nodes.door.id)!).map((p) => p.message),
        contains("No actor named 'FrontDoor' in this level"));
    expect(await tester.runAsync(bp.compile), isFalse);
    expect(bp.compileStatus, BlueprintCompileStatus.error);
    final error = bp.diagnostics.firstWhere((d) => d.isError && d.nodeId == nodes.door.id);
    expect(error.message, contains('FrontDoor'));
    expect(bp.diagnosticNodeTitle(error), 'FrontDoor');
  });

  testWidgets('BeginPlay → Door_01 → Call Open compiles, saves into the level .lmas and survives Save Level, a level '
      'switch and reopening the project', (tester) async {
    final vm = await openEditor(tester);
    final bp = vm.openLevelBlueprint();
    final nodes = authorDoorGraph(bp);
    expect(await tester.runAsync(bp.compile), isTrue, reason: '${bp.diagnostics}');
    expect(bp.compileStatus, BlueprintCompileStatus.upToDate);
    expect(bp.generatedDartCode, contains('class _LDefaultLevelScript'));
    expect(bp.isDirty, isTrue);
    expect(await tester.runAsync(bp.save), isTrue);
    expect(bp.isDirty, isFalse);

    Map<String, dynamic> stored() {
      final map = jsonDecode(File('$dir/$levelPath').readAsStringSync()) as Map;
      return Map<String, dynamic>.from((map['metadata'] as Map)['levelBlueprint'] as Map);
    }

    expect(stored()['kind'], 'level_blueprint');
    expect(LuminaBlueprintDocument.fromJson(stored()).eventGraph.node(nodes.open.id)?.literals['event'], 'Open');

    // Regression: Save Level rewrote the level
    // without metadata.levelBlueprint.
    vm.renameActorWithTransaction('door_01', 'FrontDoor');
    await tester.runAsync(vm.saveLevelAndGenerateCode);
    final afterSave = LuminaBlueprintDocument.fromJson(stored());
    expect(afterSave.eventGraph.node(nodes.door.id)?.literals['actor'], 'FrontDoor', reason: 'Save Level keeps and renames it');
    final levelDart = File('$dir/lib/levels/l_default_level.dart').readAsStringSync();
    expect(levelDart, contains('class _LDefaultLevelScript'));
    expect(levelDart, contains('frontDoor'), reason: 'the placed actor becomes a typed field of the level script');

    // A level switch closes the tab and keeps the Blueprint on disk.
    vm.switchLevel('contents/levels/L_DefaultLevel.lmas');
    expect(vm.openTabs.where((t) => t.category == EditorViewModel.levelBlueprintCategory), hasLength(1));
    await tester.runAsync(() => vm.createLevelFromTemplate('L_Other', 'empty'));
    expect(vm.openTabs.where((t) => t.category == EditorViewModel.levelBlueprintCategory), isEmpty);
    await tester.runAsync(vm.saveLevelAndGenerateCode);
    vm.switchLevel(levelPath);
    await tester.runAsync(vm.saveLevelAndGenerateCode);
    expect(LuminaBlueprintDocument.fromJson(stored()).eventGraph.nodes.map((n) => n.id), containsAll([nodes.begin.id, nodes.door.id, nodes.open.id]));
    vm.dispose();
    await tester.pump(const Duration(milliseconds: 20));

    // Reopening the project restores the graph.
    final reopened = await openEditor(tester);
    addTearDown(reopened.dispose);
    final again = reopened.openLevelBlueprint();
    expect(again.graphNodes.map((n) => n.id), containsAll([nodes.begin.id, nodes.door.id, nodes.open.id]));
    expect(again.graphNodes.singleWhere((n) => n.id == nodes.door.id).title, 'FrontDoor');
    expect(again.isDirty, isFalse);
    expect(await tester.runAsync(again.compile), isTrue, reason: '${again.diagnostics}');
  });

  testWidgets('switching levels with unsaved Level Blueprint changes asks, and Save writes them into the old level', (tester) async {
    final vm = await openEditor(tester);
    addTearDown(vm.dispose);
    final asked = <String>[];
    vm.onLevelBlueprintSavePrompt = (title) async {
      asked.add(title);
      return true;
    };
    final bp = vm.openLevelBlueprint();
    bp.eventGraph.addNode(LuminaBlueprintNodeLibrary.eventLevelLoaded, const Offset(0, 0));
    expect(bp.isDirty, isTrue);
    await tester.runAsync(() => vm.createLevelFromTemplate('L_Second', 'empty'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    expect(asked, ['L_DefaultLevel (Level Blueprint)']);
    expect(vm.openTabs.where((t) => t.category == EditorViewModel.levelBlueprintCategory), isEmpty);
    final saved = LuminaLevelRepository(dir).loadLevelBlueprint(levelPath);
    expect(saved.blueprint.eventGraph.nodes.map((n) => n.registryId), contains(LuminaBlueprintNodeLibrary.eventLevelLoaded));
  });
}
