import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart' hide BoxShape;
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/blueprint_debugger.dart';

import '../helpers/blueprint_test_project.dart';
import '../helpers/scaffold_game_project.dart';

/// The Play-In-Editor half: Play registers the open
/// project's Blueprint assets (actor classes, enums, save-game classes…) and
/// honours Open Level / Quit Game — on a real Third Person project played
/// headless through the editor's PieController.
void main() {
  late Directory root;
  late String dir;
  const name = 'bp_registries';
  const doorPath = 'contents/blueprints/BP_Door.lmas';
  const spawnerPath = 'contents/blueprints/BP_Spawner.lmas';
  const arenaPath = 'contents/levels/L_Arena.lmas';

  void writeKindAsset(String path, Map<String, dynamic> payload) {
    final assetName = path.split('/').last.replaceAll('.lmas', '');
    File('$dir/$path')
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(LuminaAsset(
        assetId: 'test_$assetName',
        name: assetName,
        type: AssetType.actor,
        rawPayload: Uint8List.fromList(utf8.encode(jsonEncode(payload))),
      ).toProtoBufferBytes());
  }

  setUpAll(() async {
    root = Directory.systemTemp.createTempSync('lumina_bp13_pie_');
    dir = await scaffoldGameProject(root, name: name, widgetLibrary: 'flutter');
    writeKindAsset('contents/enums/E_DoorState.lmas',
        const LuminaBlueprintEnumDocument(name: 'E_DoorState', values: ['Closed', 'Opening', 'Open']).toJson());
    writeKindAsset(
        'contents/savegames/SG_Player.lmas',
        const LuminaBlueprintSaveGameDocument(name: 'SG_Player', fields: [
          LuminaBlueprintVariable(name: 'Score', typeName: 'Int', defaultValue: 7),
        ]).toJson());

    // BP_Door: nobody places it; BeginPlay says it is there.
    final door = LuminaBlueprintDocument(parentClass: 'LuminaActor', components: [
      LuminaBlueprintComponent(id: 'root', name: 'DefaultSceneRoot', type: 'LuminaSceneComponent'),
    ]);
    final doorContext = LuminaBlueprintTypeContext.forDocument(door, className: 'BP_Door');
    door.eventGraph.nodes.addAll([
      LuminaBlueprintNodeLibrary.place('event_beginplay', nodeId: 'begin', context: doorContext),
      LuminaBlueprintNodeLibrary.place('print_string', nodeId: 'say', literals: {'in_string': 'BP_Door ready'}, context: doorContext),
    ]);
    door.eventGraph.wires.add(const LuminaBlueprintWire(id: 'w0', fromNodeId: 'begin', fromPinId: 'exec_out', toNodeId: 'say', toPinId: 'exec_in'));
    writeBlueprint(dir, 'BP_Door', door);

    // BP_Spawner, placed in the level: Spawn Actor from Class BP_Door, Switch
    // on Enum E_DoorState, Create Save Game Object SG_Player + Save Game to
    // Slot, and Is Editor.
    LuminaBlueprintEnums.register(const LuminaBlueprintEnumDocument(name: 'E_DoorState', values: ['Closed', 'Opening', 'Open']));
    LuminaBlueprintSaveGameClasses.register(const LuminaBlueprintSaveGameDocument(name: 'SG_Player', fields: [
      LuminaBlueprintVariable(name: 'Score', typeName: 'Int', defaultValue: 7),
    ]));
    final spawner = LuminaBlueprintDocument(parentClass: 'LuminaActor', components: [
      LuminaBlueprintComponent(id: 'root', name: 'DefaultSceneRoot', type: 'LuminaSceneComponent'),
    ]);
    final context = LuminaBlueprintTypeContext.forDocument(spawner, className: 'BP_Spawner', actorParents: {'BP_Door': 'LuminaActor'});
    LuminaBlueprintNode p(String id, String nodeId, [Map<String, dynamic>? literals]) =>
        LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: context);
    var n = 0;
    LuminaBlueprintWire wire(String from, String fromPin, String to, String toPin) =>
        LuminaBlueprintWire(id: 'sw${n++}', fromNodeId: from, fromPinId: fromPin, toNodeId: to, toPinId: toPin);
    spawner.eventGraph.nodes.addAll([
      p('event_beginplay', 'begin'),
      p('spawn_actor_from_class', 'spawn', {
        'class': 'Actor:BP_Door',
        'spawn_transform': {'location': [0.0, 300.0, 0.0], 'rotation': [0.0, 0.0, 0.0], 'scale': [1.0, 1.0, 1.0]},
      }),
      p('get_display_name', 'who'),
      p('append', 'spawned_line', {'a': 'spawned '}),
      p('print_string', 'say_spawned'),
      p('enum_literal', 'opening', {'enum': 'E_DoorState', 'value': 'Opening'}),
      p('switch_on_enum', 'sw', {'enum': 'E_DoorState'}),
      p('print_string', 'say_closed', {'in_string': 'switch Closed'}),
      p('print_string', 'say_opening', {'in_string': 'switch Opening'}),
      p('create_save_game_object', 'create', {'class': 'SG_Player'}),
      p('save_game_to_slot', 'save', {'slot_name': 'PieSlot', 'user_index': 0}),
      p('bool_to_string', 'saved_text'),
      p('append', 'saved_line', {'a': 'saved '}),
      p('print_string', 'say_saved'),
      p('is_editor', 'editor'),
      p('bool_to_string', 'editor_text'),
      p('append', 'editor_line', {'a': 'editor '}),
      p('print_string', 'say_editor'),
    ]);
    spawner.eventGraph.wires.addAll([
      wire('begin', 'exec_out', 'spawn', 'exec_in'),
      wire('spawn', 'exec_out', 'say_spawned', 'exec_in'),
      wire('spawn', 'return_value', 'who', 'object'),
      wire('who', 'return_value', 'spawned_line', 'b'),
      wire('spawned_line', 'return_value', 'say_spawned', 'in_string'),
      wire('say_spawned', 'exec_out', 'sw', 'exec_in'),
      wire('opening', 'return_value', 'sw', 'selection'),
      wire('sw', 'case_0', 'say_closed', 'exec_in'),
      wire('sw', 'case_1', 'say_opening', 'exec_in'),
      wire('say_opening', 'exec_out', 'create', 'exec_in'),
      wire('create', 'exec_out', 'save', 'exec_in'),
      wire('create', 'return_value', 'save', 'save_game_object'),
      wire('save', 'exec_out', 'say_saved', 'exec_in'),
      wire('save', 'return_value', 'saved_text', 'in_bool'),
      wire('saved_text', 'return_value', 'saved_line', 'b'),
      wire('saved_line', 'return_value', 'say_saved', 'in_string'),
      wire('say_saved', 'exec_out', 'say_editor', 'exec_in'),
      wire('editor', 'return_value', 'editor_text', 'in_bool'),
      wire('editor_text', 'return_value', 'editor_line', 'b'),
      wire('editor_line', 'return_value', 'say_editor', 'in_string'),
    ]);
    writeBlueprint(dir, 'BP_Spawner', spawner);
    LuminaBlueprintEnums.clear();
    LuminaBlueprintSaveGameClasses.clear();
  });
  tearDownAll(() => root.deleteSync(recursive: true));
  tearDown(() {
    BlueprintPieDebugger.instance.clear();
    LuminaBlueprintActorClasses.clear();
    LuminaBlueprintEnums.clear();
    LuminaBlueprintSaveGameClasses.clear();
  });

  LuminaProject manifest() =>
      LuminaProject.fromMap(Map<String, dynamic>.from(jsonDecode(File('$dir/$name.lmproject').readAsStringSync()) as Map));

  Future<EditorViewModel> editorFor(WidgetTester tester) async {
    final vm = EditorViewModel(initialProject: manifest(), projectLocation: root.path, enableTimers: false, autoInitAssets: false);
    await tester.runAsync(vm.ensureDefaultLevelAssets);
    vm.refreshAssets();
    return vm;
  }

  List<String> messages(LuminaWorld world) => [for (final m in world.screenMessages.values) m.text];

  testWidgets('Play spawns BP_Door from class, switches on E_DoorState, saves SG_Player under Saved/SaveGames, reads Is Editor; '
      'Open Level plays L_Arena and Quit Game stops Play', (tester) async {
    final vm = await editorFor(tester);
    final spawnerAsset = vm.realAssets.firstWhere((a) => a.relativePath == spawnerPath);
    await tester.runAsync(() => vm.spawnActorFromAsset(spawnerAsset, location: [200.0, 0.0, 0.0]));
    final placed = vm.actors.firstWhere((a) => a.blueprintClass == spawnerPath);

    // A second level holding a placed BP_Door, saved as the editor saves levels.
    final level = jsonDecode(File('$dir/${vm.project.activeLevel}').readAsStringSync()) as Map<String, dynamic>;
    final doorNode = Map<String, dynamic>.from(placed.toMap())
      ..['id'] = 'arena_door'
      ..['name'] = 'Door_01'
      ..['blueprintClass'] = doorPath;
    final arenaActors = [
      for (final a in (level['metadata']['actors'] as List).whereType<Map>())
        if (a['type'] != 'Blueprint') Map<String, dynamic>.from(a),
      doorNode,
    ];
    File('$dir/$arenaPath').writeAsStringSync(jsonEncode({
      ...level,
      'metadata': {...(level['metadata'] as Map), 'actors': arenaActors},
    }));

    expect(await tester.runAsync(vm.requestPlay), isTrue, reason: '${vm.playBlockers}');
    final pie = vm.pieController;
    final world = LuminaWorld();
    pie.startHeadlessForTest(world);
    expect(LuminaBlueprintRuntime.isEditor, isTrue);
    expect(LuminaSaveGameSubsystem.defaultSaveDirectoryPath, '$dir/Saved/SaveGames');
    expect(LuminaBlueprintEnums.lookup('E_DoorState'), isNotNull, reason: 'registered from the .lmas');
    expect(LuminaBlueprintSaveGameClasses.lookup('SG_Player')?.fields.single.name, 'Score');
    expect(LuminaBlueprintActorClasses.has('Actor:BP_Door'), isTrue);
    expect(LuminaBlueprintActorClasses.has('Actor:BP_ThirdPersonGameMode'), isFalse, reason: 'a GameMode is not spawnable');
    expect(vm.logger.logs.map((l) => l.message), contains(startsWith('Registered Blueprint assets: ')));
    world.tick(1 / 60);

    final doors = world.actors.whereType<LuminaBlueprintInstance>().where((a) => a.blueprintClass.name == 'BP_Door').toList();
    expect(doors, hasLength(1), reason: 'Spawn Actor from Class BP_Door');
    expect(messages(world), containsAll(['spawned BP_Door', 'BP_Door ready', 'switch Opening', 'saved true', 'editor true']));
    expect(messages(world), isNot(contains('switch Closed')));
    expect(File('$dir/Saved/SaveGames/PieSlot_user_0.sav').existsSync(), isTrue, reason: 'Play saves under the project');

    // Open Level (the node's host call), after the tick that asked for it.
    final spawner = world.persistentLevel.actors.firstWhere((a) => a.key == LuminaObjectKey(placed.id));
    LuminaBlueprintFunctionLibrary.openLevel(spawner, 'L_Arena');
    expect(pie.playingLevelPath, vm.project.activeLevel, reason: 'nothing switches inside the tick');
    await tester.pump();
    expect(pie.playingLevelPath, arenaPath);
    final arena = pie.game!.gameInstance.world!;
    expect(arena, isNot(same(world)));
    expect(arena.persistentLevel.actors.where((a) => a.key == const LuminaObjectKey('arena_door')), hasLength(1));
    expect(arena.persistentLevel.actors.where((a) => a.key == LuminaObjectKey(placed.id)), isEmpty, reason: 'L_Arena has no spawner');
    expect(messages(arena), contains('BP_Door ready'));
    expect(pie.possessedPawn, isNotNull, reason: 'the player session starts again in the new level');
    expect(vm.actors.any((a) => a.id == placed.id), isTrue, reason: 'the editor keeps its own level');
    // An unknown level only warns.
    expect(pie.openLevel('L_Nowhere'), isFalse);
    expect(pie.playingLevelPath, arenaPath);

    // Quit Game stops Play.
    final door = arena.persistentLevel.actors.firstWhere((a) => a.key == const LuminaObjectKey('arena_door'));
    LuminaBlueprintFunctionLibrary.quitGame(door);
    await tester.pump();
    expect(pie.isPlaying, isFalse);
    expect(vm.isPlaying, isFalse);
    expect(LuminaBlueprintRuntime.isEditor, isFalse, reason: 'only while playing');
    expect(LuminaGame.onQuitRequested, isNull);
    expect(LuminaGame.onOpenLevelRequested, isNull);
    expect(LuminaSaveGameSubsystem.defaultSaveDirectoryPath, kLuminaLegacySaveDirectory);
  });
}
