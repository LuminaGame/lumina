import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart' hide BoxShape;
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/blueprint_debugger.dart';

import '../helpers/scaffold_game_project.dart';
import '../helpers/temp_project.dart';

/// Level Blueprints in Play-In-Editor: the open level's Level Blueprint
/// runs as the world's level script — Level Loaded before any BeginPlay,
/// `Get <Actor>` finding the placed actors — and Open Level runs the new
/// level's own Blueprint. A real Third Person project, played headless.
void main() {
  late Directory root;
  late String dir;
  const name = 'bp_level_play';
  const arenaPath = 'contents/levels/L_Arena.lmas';

  setUpAll(() async {
    root = Directory.systemTemp.createTempSync('lumina_bp14_pie_');
    dir = await scaffoldGameProject(root, name: name, widgetLibrary: 'flutter');
  });
  // The folder a just-disposed editor held is deleted with retries.
  tearDownAll(() => deleteTempProject(root));
  tearDown(() {
    BlueprintPieDebugger.instance.clear();
    LuminaBlueprintActorClasses.clear();
  });

  LuminaProject manifest() =>
      LuminaProject.fromMap(Map<String, dynamic>.from(jsonDecode(File('$dir/$name.lmproject').readAsStringSync()) as Map));

  /// A Level Blueprint for [level]: Level Loaded prints "<tag> loaded", Level
  /// BeginPlay prints "<tag> sees <n> player start(s)" from the level's placed
  /// actors, and "<tag> start <display name>" from Get PlayerStart.
  LuminaLevelBlueprintDocument scriptFor(LuminaLevelDocument level, String tag) {
    final doc = LuminaLevelBlueprintDocument(levelPath: level.relativePath);
    final refs = level.levelActorRefs;
    final start = refs.firstWhere((r) => r.actorClass == 'Actor:LuminaPlayerStart');
    final context = LuminaBlueprintTypeContext.forLevel(doc, levelActors: refs);
    LuminaBlueprintNode p(String id, String nodeId, [Map<String, dynamic>? literals]) =>
        LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: context);
    var n = 0;
    LuminaBlueprintWire w(String a, String ap, String b, String bp) =>
        LuminaBlueprintWire(id: 'w${n++}', fromNodeId: a, fromPinId: ap, toNodeId: b, toPinId: bp);
    doc.blueprint.eventGraph.nodes.addAll([
      p('event_level_loaded', 'loaded'),
      p('print_string', 'say_loaded', {'in_string': '$tag loaded', 'key': 'loaded'}),
      p('event_level_begin_play', 'begin'),
      p('get_level_actors_of_class', 'starts', {'class': 'Actor:LuminaPlayerStart'}),
      p('array_length', 'count'),
      p('int_to_string', 'count_text'),
      p('append', 'count_line', {'a': '$tag sees '}),
      p('print_string', 'say_count', {'key': 'count'}),
      p('get_level_actor', 'start', {'actor': start.name}),
      p('is_valid', 'valid'),
      p('bool_to_string', 'valid_text'),
      p('append', 'valid_line', {'a': '$tag start valid '}),
      p('print_string', 'say_valid', {'key': 'valid'}),
    ]);
    doc.blueprint.eventGraph.wires.addAll([
      w('loaded', 'exec_out', 'say_loaded', 'exec_in'),
      w('begin', 'exec_out', 'say_count', 'exec_in'),
      w('starts', 'return_value', 'count', 'target_array'),
      w('count', 'return_value', 'count_text', 'in_int'),
      w('count_text', 'return_value', 'count_line', 'b'),
      w('count_line', 'return_value', 'say_count', 'in_string'),
      w('say_count', 'exec_out', 'say_valid', 'exec_in'),
      w('start', 'return_value', 'valid', 'input_object'),
      w('valid', 'return_value', 'valid_text', 'in_bool'),
      w('valid_text', 'return_value', 'valid_line', 'b'),
      w('valid_line', 'return_value', 'say_valid', 'in_string'),
    ]);
    expect(validateBlueprint(doc.blueprint, typeContext: context).where((d) => d.isError), isEmpty);
    return doc;
  }

  List<String> messages(LuminaWorld world) => [for (final m in world.screenMessages.values) m.text];

  /// A Level Blueprint whose Level BeginPlay prints "pawn <display name>" of
  /// Get Player Pawn.
  LuminaLevelBlueprintDocument pawnScriptFor(LuminaLevelDocument level) {
    final doc = LuminaLevelBlueprintDocument(levelPath: level.relativePath);
    final context = LuminaBlueprintTypeContext.forLevel(doc, levelActors: level.levelActorRefs);
    LuminaBlueprintNode p(String id, String nodeId, [Map<String, dynamic>? literals]) =>
        LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: context);
    var n = 0;
    LuminaBlueprintWire w(String a, String ap, String b, String bp) =>
        LuminaBlueprintWire(id: 'w${n++}', fromNodeId: a, fromPinId: ap, toNodeId: b, toPinId: bp);
    doc.blueprint.eventGraph.nodes.addAll([
      p('event_level_begin_play', 'begin'),
      p('get_player_pawn', 'pawn'),
      p('get_display_name', 'name'),
      p('append', 'line', {'a': 'pawn '}),
      p('print_string', 'say', {'key': 'pawn'}),
    ]);
    doc.blueprint.eventGraph.wires.addAll([
      w('begin', 'exec_out', 'say', 'exec_in'),
      w('pawn', 'return_value', 'name', 'object'),
      w('name', 'return_value', 'line', 'b'),
      w('line', 'return_value', 'say', 'in_string'),
    ]);
    expect(validateBlueprint(doc.blueprint, typeContext: context).where((d) => d.isError), isEmpty);
    return doc;
  }

  // Play logs the player in after beginPlay; the Level
  // Blueprint's BeginPlay waits for it, as a built game's does.
  testWidgets('the Level Blueprint\'s BeginPlay sees the player\'s pawn in Play', (tester) async {
    final project = manifest();
    final repo = LuminaLevelRepository(dir);
    final level = repo.load(project.activeLevel)!;
    repo.saveLevelBlueprint(pawnScriptFor(level));

    final vm = EditorViewModel(initialProject: project, projectLocation: root.path, enableTimers: false, autoInitAssets: false);
    await tester.runAsync(vm.ensureDefaultLevelAssets);
    vm.refreshAssets();
    expect(await tester.runAsync(vm.requestPlay), isTrue, reason: '${vm.playBlockers}');
    final pie = vm.pieController;
    final world = LuminaWorld();
    pie.startHeadlessForTest(world);
    final pawn = pie.game!.possessedPawn;
    expect(pawn, isNotNull, reason: 'the Third Person project spawns the player');
    final said = messages(world).where((m) => m.startsWith('pawn ')).toList();
    expect(said, ['pawn ${LuminaBlueprintFunctionLibrary.getDisplayName(pawn)}'], reason: 'Get Player Pawn on BeginPlay');
    expect(said.single, isNot('pawn None'));
    pie.stopHeadlessForTest();
    vm.stopSimulation();
  });

  testWidgets('Play runs the level\'s Blueprint as its level script; Open Level runs L_Arena\'s', (tester) async {
    final project = manifest();
    final repo = LuminaLevelRepository(dir);
    final level = repo.load(project.activeLevel)!;
    repo.saveLevelBlueprint(scriptFor(level, 'Default'));
    final arena = LuminaLevelDocument(relativePath: arenaPath)..actors = level.actors;
    repo.save(arena);
    repo.saveLevelBlueprint(scriptFor(arena, 'Arena'));

    final vm = EditorViewModel(initialProject: project, projectLocation: root.path, enableTimers: false, autoInitAssets: false);
    await tester.runAsync(vm.ensureDefaultLevelAssets);
    vm.refreshAssets();
    expect(await tester.runAsync(vm.requestPlay), isTrue, reason: '${vm.playBlockers}');
    final pie = vm.pieController;
    final world = LuminaWorld();
    pie.startHeadlessForTest(world);
    final script = world.persistentLevel.scriptActor;
    expect(script, isA<LuminaBlueprintLevelScript>());
    expect((script! as LuminaBlueprintLevelScript).blueprintClassName, level.name);
    expect(vm.logger.logs.map((l) => l.message), contains('Level Blueprint of ${level.name} runs in Play'));
    world.tick(1 / 60);
    expect(messages(world), containsAll(['Default loaded', 'Default sees 1', 'Default start valid true']));

    LuminaBlueprintFunctionLibrary.openLevel(script, 'L_Arena');
    await tester.pump();
    final arenaWorld = pie.game!.gameInstance.world!;
    final arenaScript = arenaWorld.persistentLevel.scriptActor;
    expect(arenaScript, isA<LuminaBlueprintLevelScript>());
    expect((arenaScript! as LuminaBlueprintLevelScript).blueprintClassName, 'L_Arena');
    expect(messages(arenaWorld), containsAll(['Arena loaded', 'Arena sees 1', 'Arena start valid true']));
    pie.stopHeadlessForTest();
    vm.stopSimulation();
  });
}
