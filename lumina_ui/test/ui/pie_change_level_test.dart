import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart' hide BoxShape;
import 'package:lumina/testing.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/blueprint_debugger.dart';

import '../helpers/blueprint_test_project.dart';
import '../helpers/scaffold_game_project.dart';

/// The Play-In-Editor half: Load Level preloads another
/// project level (found through the asset index) with one On Progress per
/// asset, and Change Level plays it in place of the running level — the
/// editor keeping its own — firing On Success after the new level's
/// BeginPlay; an unknown level fires On Error. Played headless through the
/// editor's PieController on a real Third Person project.
void main() {
  late Directory root;
  late String dir;
  const name = 'bp_change_level';
  const loaderPath = 'contents/blueprints/BP_Loader.lmas';
  const doorPath = 'contents/blueprints/BP_Door.lmas';
  const arenaPath = 'contents/levels/L_Arena.lmas';
  const barrelPath = 'contents/meshes/fuel_barrel_red.glb';

  setUpAll(() async {
    root = Directory.systemTemp.createTempSync('lvl_pie_');
    dir = await scaffoldGameProject(root, name: name, widgetLibrary: 'flutter');
    File('$dir/$barrelPath')
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(File('${SmokeArtifacts.testAssetsDir.absolute.path}/Props/Barrels/fuel_barrel_red.glb').readAsBytesSync());

    // BP_Door, placed in L_Arena: BeginPlay prints "Door ready".
    final door = LuminaBlueprintDocument(parentClass: 'LuminaActor', components: [
      LuminaBlueprintComponent(id: 'root', name: 'DefaultSceneRoot', type: 'LuminaSceneComponent'),
    ]);
    final doorContext = LuminaBlueprintTypeContext.forDocument(door, className: 'BP_Door');
    door.eventGraph.nodes.addAll([
      LuminaBlueprintNodeLibrary.place('event_beginplay', nodeId: 'begin', context: doorContext),
      LuminaBlueprintNodeLibrary.place('print_string', nodeId: 'say', literals: {'in_string': 'Door ready'}, context: doorContext),
    ]);
    door.eventGraph.wires.add(const LuminaBlueprintWire(id: 'w0', fromNodeId: 'begin', fromPinId: 'exec_out', toNodeId: 'say', toPinId: 'exec_in'));
    writeBlueprint(dir, 'BP_Door', door);

    // BP_Loader, placed in the editor's level: BeginPlay → Load Level L_Arena;
    // On Progress prints "progress <content> <loaded>/<total>"; On Success →
    // Change Level L_Arena → On Success prints "changed". Custom event
    // TryBadLevel → Change Level L_Nowhere → On Error prints the error.
    final loader = LuminaBlueprintDocument(parentClass: 'LuminaActor', components: [
      LuminaBlueprintComponent(id: 'root', name: 'DefaultSceneRoot', type: 'LuminaSceneComponent'),
    ]);
    final context = LuminaBlueprintTypeContext.forDocument(loader, className: 'BP_Loader');
    LuminaBlueprintNode p(String id, String nodeId, [Map<String, dynamic>? literals]) =>
        LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: context);
    var n = 0;
    LuminaBlueprintWire wire(String from, String fromPin, String to, String toPin) =>
        LuminaBlueprintWire(id: 'lw${n++}', fromNodeId: from, fromPinId: fromPin, toNodeId: to, toPinId: toPin);
    loader.eventGraph.nodes.addAll([
      p('event_beginplay', 'begin'),
      p('load_level', 'load', {'level_name': 'L_Arena'}),
      p('int_to_string', 'loaded_text'),
      p('int_to_string', 'total_text'),
      p('format_string', 'line', {'format': 'progress {0} {1}/{2}'}),
      p('print_string', 'say_progress'),
      p('change_level', 'change', {'level_name': 'L_Arena'}),
      p('print_string', 'say_changed', {'in_string': 'changed'}),
      p('custom_event', 'bad', {'name': 'TryBadLevel'}),
      p('change_level', 'bad_change', {'level_name': 'L_Nowhere'}),
      p('append', 'bad_line', {'a': 'bad: '}),
      p('print_string', 'say_bad'),
    ]);
    loader.eventGraph.wires.addAll([
      wire('begin', 'exec_out', 'load', 'exec_in'),
      wire('load', 'on_progress', 'say_progress', 'exec_in'),
      wire('load', 'current_content', 'line', 'arg_0'),
      wire('load', 'loaded_count', 'loaded_text', 'in_int'),
      wire('load', 'total_count', 'total_text', 'in_int'),
      wire('loaded_text', 'return_value', 'line', 'arg_1'),
      wire('total_text', 'return_value', 'line', 'arg_2'),
      wire('line', 'return_value', 'say_progress', 'in_string'),
      wire('load', 'on_success', 'change', 'exec_in'),
      wire('change', 'on_success', 'say_changed', 'exec_in'),
      wire('bad', 'exec_out', 'bad_change', 'exec_in'),
      wire('bad_change', 'on_error', 'say_bad', 'exec_in'),
      wire('bad_change', 'error', 'bad_line', 'b'),
      wire('bad_line', 'return_value', 'say_bad', 'in_string'),
    ]);
    writeBlueprint(dir, 'BP_Loader', loader);
  });
  tearDownAll(() => root.deleteSync(recursive: true));
  tearDown(() {
    BlueprintPieDebugger.instance.clear();
    LuminaBlueprintActorClasses.clear();
  });

  LuminaProject manifest() =>
      LuminaProject.fromMap(Map<String, dynamic>.from(jsonDecode(File('$dir/$name.lmproject').readAsStringSync()) as Map));

  List<String> messages(LuminaWorld world) => [for (final m in world.screenMessages.values) m.text];

  testWidgets('Load Level preloads L_Arena with progress, Change Level plays it and fires On Success after its BeginPlay; '
      'an unknown level fires On Error; the editor keeps its own level', (tester) async {
    final vm = EditorViewModel(initialProject: manifest(), projectLocation: root.path, enableTimers: false, autoInitAssets: false);
    await tester.runAsync(vm.ensureDefaultLevelAssets);
    vm.refreshAssets();
    final loaderAsset = vm.realAssets.firstWhere((a) => a.relativePath == loaderPath);
    await tester.runAsync(() => vm.spawnActorFromAsset(loaderAsset, location: [0.0, 0.0, 0.0]));
    final placed = vm.actors.firstWhere((a) => a.blueprintClass == loaderPath);

    // L_Arena: a barrel mesh and a placed BP_Door, saved as the editor saves levels.
    final level = jsonDecode(File('$dir/${vm.project.activeLevel}').readAsStringSync()) as Map<String, dynamic>;
    final arenaActors = [
      for (final a in (level['metadata']['actors'] as List).whereType<Map>())
        if (a['type'] != 'Blueprint') Map<String, dynamic>.from(a),
      {'id': 'arena_barrel', 'name': 'Barrel', 'type': 'StaticMesh', 'meshAssetPath': '$dir/$barrelPath', 'location': [0.0, 300.0, 0.0]},
      {...placed.toMap(), 'id': 'arena_door', 'name': 'Door_01', 'blueprintClass': doorPath},
    ];
    File('$dir/$arenaPath').writeAsStringSync(jsonEncode({
      ...level,
      'metadata': {...(level['metadata'] as Map), 'actors': arenaActors},
    }));

    expect(await tester.runAsync(vm.requestPlay), isTrue, reason: '${vm.playBlockers}');
    final pie = vm.pieController;
    final world = LuminaWorld();
    // Play (and the loads its BeginPlay starts) runs in the real zone: file
    // reads and the preload's turns of the event loop need real time.
    await tester.runAsync(() async => pie.startHeadlessForTest(world));
    expect(LuminaGame.onChangeLevelRequested, isNotNull, reason: 'Play hosts Change Level');
    expect(LuminaLevelPreloader.instance.manifestResolver, isNotNull);

    Future<void> until(bool Function() done) async {
      for (var i = 0; i < 200 && !done(); i++) {
        await tester.runAsync(() async {
          pie.tick(1 / 30);
          await Future<void>.delayed(const Duration(milliseconds: 5));
        });
      }
    }

    await until(() => messages(world).contains('changed'));
    final progress = [for (final m in messages(world)) if (m.startsWith('progress ')) m];
    // L_Arena's assets: the template's GameMode Blueprint (its placed game
    // mode actor), the barrel mesh and BP_Door.
    expect(progress, hasLength(3), reason: 'one On Progress per asset of L_Arena: ${messages(world)}');
    expect(progress.map((m) => m.split(' ')[1]).toSet(), {'BP_ThirdPersonGameMode', 'fuel_barrel_red', 'BP_Door'});
    expect(progress.map((m) => m.split(' ').last).toList(), ['1/3', '2/3', '3/3']);
    expect(messages(world), contains('changed'));
    expect(pie.playingLevelPath, arenaPath);
    final arena = pie.game!.gameInstance.world!;
    expect(arena, isNot(same(world)));
    expect(messages(arena), contains('Door ready'), reason: "the new level's BeginPlay ran before On Success");
    expect(arena.persistentLevel.actors.where((a) => a.key == const LuminaObjectKey('arena_barrel')), hasLength(1));
    expect(vm.actors.any((a) => a.id == placed.id), isTrue, reason: 'the editor keeps its own level');
    expect(LuminaLevelPreloader.instance.isLoaded('L_Arena'), isFalse, reason: 'handed to the level that plays');

    // Change Level to a level the project does not have: On Error.
    final loaderActor = world.persistentLevel.actors.firstWhere((a) => a.key == LuminaObjectKey(placed.id));
    await tester.runAsync(() async => (loaderActor as LuminaBlueprintCallable).callBlueprint('TryBadLevel', const {}));
    await until(() => messages(world).any((m) => m.startsWith('bad: ')));
    expect(messages(world).firstWhere((m) => m.startsWith('bad: ')), contains("no level named 'L_Nowhere'"));
    expect(pie.playingLevelPath, arenaPath);

    pie.stopHeadlessForTest();
    expect(LuminaGame.onChangeLevelRequested, isNull);
    expect(LuminaLevelPreloader.instance.manifestResolver, isNull, reason: 'Play leaves the preloader as it found it');
  });
}
