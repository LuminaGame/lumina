import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

/// The game framework, level, save game and input / screen
/// nodes on real subsystems.
void main() {
  var wireCount = 0;
  LuminaBlueprintWire wire(String from, String fromPin, String to, String toPin) =>
      LuminaBlueprintWire(id: 'w${wireCount++}', fromNodeId: from, fromPinId: fromPin, toNodeId: to, toPinId: toPin);
  List<String> printed(List<LuminaBlueprintTraceEvent> trace) => [for (final t in trace) if (t.printed != null) t.printed!];

  ({LuminaBlueprintCharacter me, LuminaPlayerController pc, List<LuminaBlueprintTraceEvent> trace}) play(
      LuminaWorld w, LuminaBlueprintDocument doc, String name) {
    final cls = LuminaBlueprintClass.fromDocument(doc, name: name);
    expect(cls.diagnostics, isEmpty, reason: '${cls.diagnostics}');
    final me = cls.instantiate() as LuminaBlueprintCharacter;
    final trace = <LuminaBlueprintTraceEvent>[];
    me.trace = trace.add;
    final pc = LuminaPlayerController();
    w.persistentLevel.registerActor(me);
    pc.possess(me);
    return (me: me, pc: pc, trace: trace);
  }

  tearDown(() {
    LuminaBlueprintActorClasses.clear();
    LuminaBlueprintSaveGameClasses.clear();
    LuminaGame.onOpenLevelRequested = null;
    LuminaGame.onQuitRequested = null;
    LuminaConsole.clearRegistered();
  });

  test('Get Game Mode is typed by the GameMode Blueprint; Set Game Paused stops ticks; slomo sets the dilation', () {
    final w = LuminaWorld(worldType: LuminaWorldType.game);
    final modeDoc = LuminaBlueprintDocument(parentClass: 'LuminaGameMode');
    final modeClass = LuminaBlueprintClass.fromDocument(modeDoc, name: 'BP_ThirdPersonGameMode');
    w.gameMode = modeClass.createGameMode(pawnOverride: LuminaPawn.new);
    final doc = LuminaBlueprintDocument(parentClass: 'LuminaCharacter');
    final context = LuminaBlueprintTypeContext.forDocument(doc, className: 'BP_Player', gameModeClass: 'BP_ThirdPersonGameMode');
    LuminaBlueprintNode p(String id, String nodeId, [Map<String, dynamic>? literals]) =>
        LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: context);
    final getMode = p('get_game_mode', 'mode');
    expect(getMode.pin('return_value')!.objectClass, 'Actor:BP_ThirdPersonGameMode');
    doc.eventGraph.nodes.addAll([
      p('event_beginplay', 'begin'),
      getMode,
      p('get_class_name', 'mode_name'),
      p('print_string', 'say_mode'),
      p('get_game_instance', 'gi'),
      p('get_game_state', 'gs'),
      p('get_player_state', 'ps'),
      p('is_valid', 'gs_valid'),
      p('bool_to_string', 'gs_text'),
      p('print_string', 'say_gs'),
      p('execute_console_command', 'slomo', {'command': 'slomo 0.5'}),
      p('get_current_level_name', 'level'),
      p('print_string', 'say_level'),
      p('get_game_time_since_creation', 'age'),
      p('event_tick', 'tick'),
      p('print_string', 'say_tick', {'in_string': 'tick'}),
      p('set_game_paused', 'pause', {'paused': true}),
      p('is_game_paused', 'paused'),
      p('bool_to_string', 'paused_text'),
      p('print_string', 'say_paused'),
    ]);
    doc.eventGraph.wires.addAll([
      wire('begin', 'exec_out', 'say_mode', 'exec_in'),
      wire('mode', 'return_value', 'mode_name', 'object'),
      wire('mode_name', 'return_value', 'say_mode', 'in_string'),
      wire('say_mode', 'exec_out', 'say_gs', 'exec_in'),
      wire('gs', 'return_value', 'gs_valid', 'input_object'),
      wire('gs_valid', 'return_value', 'gs_text', 'in_bool'),
      wire('gs_text', 'return_value', 'say_gs', 'in_string'),
      wire('say_gs', 'exec_out', 'slomo', 'exec_in'),
      wire('slomo', 'exec_out', 'say_level', 'exec_in'),
      wire('level', 'return_value', 'say_level', 'in_string'),
      wire('tick', 'exec_tick_out', 'say_tick', 'exec_in'),
      wire('say_tick', 'exec_out', 'pause', 'exec_in'),
      wire('pause', 'exec_out', 'say_paused', 'exec_in'),
      wire('paused', 'return_value', 'paused_text', 'in_bool'),
      wire('paused_text', 'return_value', 'say_paused', 'in_string'),
    ]);
    final run = play(w, doc, 'BP_Player');
    w.persistentLevel.levelName = 'L_Yard';
    w.beginPlay();
    expect(printed(run.trace), ['LuminaGameMode', 'true', 'L_Yard']);
    expect(LuminaBlueprintFunctionLibrary.getGameMode(run.me), same(w.gameMode));
    expect(LuminaBlueprintFunctionLibrary.getGameState(run.me), same(w.gameState));
    expect(LuminaBlueprintFunctionLibrary.getPlayerState(run.me), same(run.pc.playerState));
    expect(w.timeDilation, 0.5);
    w.tick(0.1);
    expect(printed(run.trace).skip(3), ['tick', 'true']);
    expect(w.isPaused, isTrue);
    w.tick(0.1);
    w.tick(0.1);
    expect(printed(run.trace).length, 5, reason: 'a paused world does not tick actors');
    expect(LuminaBlueprintFunctionLibrary.isGamePaused(run.me), isTrue);
    LuminaBlueprintFunctionLibrary.setGamePaused(run.me, false);
    w.tick(0.1);
    expect(printed(run.trace).length, 7);
    // The game instance is reachable when a game mounts one; here there is none.
    expect(LuminaBlueprintFunctionLibrary.getGameInstance(run.me), isNull);
    expect(LuminaBlueprintFunctionLibrary.getGameTimeSinceCreation(run.me), greaterThan(0.0));
  });

  test('console commands: stat fps, quit, slomo, open, and a project command registered by name', () {
    final w = LuminaWorld(worldType: LuminaWorldType.game)..beginPlay();
    final actor = LuminaActor();
    w.persistentLevel.registerActor(actor);
    var quit = 0;
    LuminaGame.onQuitRequested = () => quit++;
    final opened = <String>[];
    LuminaGame.onOpenLevelRequested = (level, options) => opened.add('$level?$options');
    final custom = <String>[];
    LuminaConsole.register('spawnbarrel', (args, world) => custom.add(args.join(' ')));
    expect(LuminaConsole.execute(w, 'stat fps'), isTrue);
    expect(w.screenMessages.keys, contains('stat fps'));
    expect(LuminaConsole.showFps, isTrue);
    expect(LuminaConsole.execute(w, 'slomo 0.25'), isTrue);
    expect(w.timeDilation, 0.25);
    expect(LuminaConsole.execute(w, 'open L_Second?game=arena'), isTrue);
    expect(opened, ['L_Second?game=arena']);
    expect(LuminaConsole.execute(w, 'spawnbarrel 3 red'), isTrue);
    expect(custom, ['3 red']);
    expect(LuminaConsole.execute(w, 'nonsense'), isFalse);
    expect(LuminaConsole.execute(w, 'quit'), isTrue);
    expect(quit, 1);
    expect(LuminaConsole.commandNames, containsAll(['stat', 'quit', 'slomo', 'open', 'spawnbarrel']));
    LuminaBlueprintFunctionLibrary.executeConsoleCommand(actor, 'slomo 1');
    expect(w.timeDilation, 1.0);
  });

  test('Open Level asks the host; Load Stream Level completes its latent pin once the level streamed in', () async {
    final w = LuminaWorld(worldType: LuminaWorldType.game);
    final streaming = w.registerSubsystem(LuminaLevelStreamingManager());
    final sub = LuminaLevelStreaming(
      levelPath: 'contents/levels/L_Cave.lmas',
      levelInstance: LuminaLevel(),
      bShouldBeLoaded: false,
      bShouldBeVisible: false,
      bDisableDistanceStreaming: true,
    );
    streaming.registerStreamingLevel(sub);
    final requested = <String>[];
    LuminaGame.onOpenLevelRequested = (level, options) => requested.add('$level|$options');
    final doc = LuminaBlueprintDocument(parentClass: 'LuminaCharacter');
    final context = LuminaBlueprintTypeContext.forDocument(doc, className: 'BP_Loader');
    LuminaBlueprintNode p(String id, String nodeId, [Map<String, dynamic>? literals]) =>
        LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: context);
    doc.eventGraph.nodes.addAll([
      p('event_beginplay', 'begin'),
      p('load_stream_level', 'load', {'level_name': 'contents/levels/L_Cave.lmas', 'make_visible_after_load': true}),
      p('print_string', 'say_started', {'in_string': 'loading'}),
      p('print_string', 'say_loaded', {'in_string': 'loaded'}),
      p('is_stream_level_loaded', 'loaded', {'level_name': 'contents/levels/L_Cave.lmas'}),
      p('bool_to_string', 'loaded_text'),
      p('print_string', 'say_is_loaded'),
      p('open_level', 'open', {'level_name': 'L_Second', 'options': 'game=arena'}),
    ]);
    doc.eventGraph.wires.addAll([
      wire('begin', 'exec_out', 'load', 'exec_in'),
      wire('load', 'exec_out', 'say_started', 'exec_in'),
      wire('load', 'completed', 'say_loaded', 'exec_in'),
      wire('say_loaded', 'exec_out', 'say_is_loaded', 'exec_in'),
      wire('loaded', 'return_value', 'loaded_text', 'in_bool'),
      wire('loaded_text', 'return_value', 'say_is_loaded', 'in_string'),
      wire('say_is_loaded', 'exec_out', 'open', 'exec_in'),
    ]);
    final run = play(w, doc, 'BP_Loader');
    w.beginPlay();
    expect(printed(run.trace), ['loading']);
    expect(requested, isEmpty);
    // The streaming load is asynchronous; the latent Completed pin fires on the tick after it resolves.
    for (var i = 0; i < 5 && printed(run.trace).length < 4; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      w.tick(0.1);
    }
    expect(printed(run.trace), ['loading', 'loaded', 'true']);
    expect(sub.state, LevelState.visible);
    expect(requested, ['L_Second|game=arena']);
    expect(LuminaGame.lastOpenLevelRequest, (levelName: 'L_Second', options: 'game=arena'));
    LuminaBlueprintFunctionLibrary.unloadStreamLevel(run.me, 'contents/levels/L_Cave.lmas');
    for (var i = 0; i < 5 && sub.state != LevelState.unloaded; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      w.tick(0.1);
    }
    expect(LuminaBlueprintFunctionLibrary.isStreamLevelLoaded(run.me, 'contents/levels/L_Cave.lmas'), isFalse);
  });

  test('a SG_Player save class: set field, save to slot on disk, load it back, exists, delete', () async {
    final dir = Directory.systemTemp.createTempSync('lumina_bp12_save_');
    addTearDown(() => dir.deleteSync(recursive: true));
    const saveClass = LuminaBlueprintSaveGameDocument(name: 'SG_Player', fields: [
      LuminaBlueprintVariable(name: 'Score', typeName: 'Int', defaultValue: 0),
      LuminaBlueprintVariable(name: 'Position', typeName: 'Vector', defaultValue: [0.0, 0.0, 0.0]),
    ]);
    final back = LuminaBlueprintSaveGameDocument.fromJson(jsonDecode(jsonEncode(saveClass.toJson())) as Map<String, dynamic>);
    expect(back.toJson()['kind'], 'savegame');
    expect(back.fields.map((f) => f.name), ['Score', 'Position']);
    LuminaBlueprintSaveGameClasses.register(back);
    final w = LuminaWorld(worldType: LuminaWorldType.game);
    w.registerSubsystem(LuminaSaveGameSubsystem(saveDirectoryPath: dir.path));
    final doc = LuminaBlueprintDocument(parentClass: 'LuminaCharacter', variables: [const LuminaBlueprintVariable(name: 'Save', typeName: 'SaveGame:SG_Player')]);
    final context = LuminaBlueprintTypeContext.forDocument(doc, className: 'BP_Saver');
    LuminaBlueprintNode p(String id, String nodeId, [Map<String, dynamic>? literals]) =>
        LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: context);
    final create = p('create_save_game_object', 'create', {'class': 'SG_Player'});
    expect(create.pin('return_value')!.objectClass, 'SaveGame:SG_Player');
    final setScore = p('set_save_field', 'set_score', {'class': 'SG_Player', 'field': 'Score', 'value': 42});
    expect(setScore.pin('value')!.type, LuminaPinType.integer);
    final getScore = p('get_save_field', 'get_score', {'class': 'SG_Player', 'field': 'Score'});
    expect(getScore.pin('return_value')!.type, LuminaPinType.integer);
    doc.eventGraph.nodes.addAll([
      p('event_beginplay', 'begin'),
      create,
      p(LuminaBlueprintNodeLibrary.variableSet, 'set_save', {'variable': 'Save'}),
      setScore,
      p('set_save_field', 'set_pos', {'class': 'SG_Player', 'field': 'Position', 'value': [1.0, 2.0, 3.0]}),
      p('save_game_to_slot', 'save', {'slot_name': 'Slot1', 'user_index': 0}),
      p('bool_to_string', 'saved_text'),
      p('print_string', 'say_saved'),
      p('load_game_from_slot', 'load', {'slot_name': 'Slot1', 'user_index': 0, 'class': 'SG_Player'}),
      getScore,
      p('int_to_string', 'score_text'),
      p('print_string', 'say_score'),
      p('does_save_game_exist', 'exists', {'slot_name': 'Slot1'}),
      p('bool_to_string', 'exists_text'),
      p('print_string', 'say_exists'),
    ]);
    doc.eventGraph.wires.addAll([
      wire('begin', 'exec_out', 'create', 'exec_in'),
      wire('create', 'exec_out', 'set_save', 'exec_in'),
      wire('create', 'return_value', 'set_save', 'value'),
      wire('set_save', 'exec_out', 'set_score', 'exec_in'),
      wire('set_save', 'value', 'set_score', 'target'),
      wire('set_score', 'exec_out', 'set_pos', 'exec_in'),
      wire('set_save', 'value', 'set_pos', 'target'),
      wire('set_pos', 'exec_out', 'save', 'exec_in'),
      wire('set_save', 'value', 'save', 'save_game_object'),
      wire('save', 'exec_out', 'say_saved', 'exec_in'),
      wire('save', 'return_value', 'saved_text', 'in_bool'),
      wire('saved_text', 'return_value', 'say_saved', 'in_string'),
      wire('say_saved', 'exec_out', 'load', 'exec_in'),
      wire('load', 'exec_out', 'say_score', 'exec_in'),
      wire('load', 'return_value', 'get_score', 'target'),
      wire('get_score', 'return_value', 'score_text', 'in_int'),
      wire('score_text', 'return_value', 'say_score', 'in_string'),
      wire('say_score', 'exec_out', 'say_exists', 'exec_in'),
      wire('exists', 'return_value', 'exists_text', 'in_bool'),
      wire('exists_text', 'return_value', 'say_exists', 'in_string'),
    ]);
    final run = play(w, doc, 'BP_Saver');
    w.beginPlay();
    expect(printed(run.trace), ['true', '42', 'true']);
    final file = File('${dir.path}/Slot1_user_0.sav');
    expect(file.existsSync(), isTrue);
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    expect(json['saveGameClassName'], 'SG_Player');
    expect((json['customSaveData'] as Map)['Score'], 42);
    expect((json['customSaveData'] as Map)['Position'], [1.0, 2.0, 3.0]);
    final loaded = run.trace.lastWhere((t) => t.nodeId == 'load').values['return_value'] as LuminaBlueprintSaveGame;
    expect(loaded.className, 'SG_Player');
    expect(LuminaBlueprintFunctionLibrary.getSaveField(loaded, 'Position'), Vector3(1, 2, 3));
    // Async save completes its latent pin; delete removes the file.
    LuminaBlueprintFunctionLibrary.deleteGameInSlot(run.me, 'Slot1', 0);
    expect(file.existsSync(), isFalse);
    expect(LuminaBlueprintFunctionLibrary.doesSaveGameExist(run.me, 'Slot1', 0), isFalse);
    var completed = false;
    LuminaBlueprintFunctionLibrary.asyncSaveGameToSlot(run.me, loaded, 'Slot2', 0, (success) => completed = success);
    for (var i = 0; i < 20 && !completed; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      w.tick(0.1); // the Completed pin fires on the next latent advance
    }
    expect(completed, isTrue);
    expect(File('${dir.path}/Slot2_user_0.sav').existsSync(), isTrue);
  });

  test('input keys follow the injected state; world → screen projection lands inside the viewport', () {
    final w = LuminaWorld(worldType: LuminaWorldType.game);
    final input = w.registerSubsystem(LuminaInputSubsystem());
    w.viewportSize = (1280, 720);
    final doc = LuminaBlueprintDocument(parentClass: 'LuminaCharacter', components: [
      LuminaBlueprintComponent(id: 'capsule', name: 'CapsuleComponent', type: 'LuminaCapsuleComponent'),
      LuminaBlueprintComponent(id: 'camera', name: 'Camera', type: 'LuminaCameraComponent', parentId: 'capsule', properties: {
        'location': [0.0, -300.0, 100.0],
      }),
    ]);
    final context = LuminaBlueprintTypeContext.forDocument(doc, className: 'BP_Input');
    LuminaBlueprintNode p(String id, String nodeId, [Map<String, dynamic>? literals]) =>
        LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: context);
    doc.eventGraph.nodes.addAll([
      p('event_tick', 'tick'),
      p('is_input_key_down', 'w_down', {'key': 'W'}),
      p('bool_to_string', 'w_text'),
      p('print_string', 'say_w'),
      p('was_input_key_just_pressed', 'w_just', {'key': 'W'}),
      p('bool_to_string', 'just_text'),
      p('print_string', 'say_just'),
      p('get_input_key_time_down', 'w_time', {'key': 'W'}),
      p('get_mouse_position', 'mouse'),
      p('get_viewport_size', 'viewport'),
      p('project_world_to_screen', 'project', {'world_location': [0.0, 500.0, 100.0]}),
      p('bool_to_string', 'on_screen_text'),
      p('print_string', 'say_on_screen'),
      p('deproject_screen_to_world', 'deproject', {'screen_position': [640.0, 360.0]}),
      p('get_input_axis_value', 'axis', {'axis_name': 'MouseX'}),
      p('get_last_input_device', 'device'),
      p('print_string', 'say_device'),
    ]);
    doc.eventGraph.wires.addAll([
      wire('tick', 'exec_tick_out', 'say_w', 'exec_in'),
      wire('w_down', 'return_value', 'w_text', 'in_bool'),
      wire('w_text', 'return_value', 'say_w', 'in_string'),
      wire('say_w', 'exec_out', 'say_just', 'exec_in'),
      wire('w_just', 'return_value', 'just_text', 'in_bool'),
      wire('just_text', 'return_value', 'say_just', 'in_string'),
      wire('say_just', 'exec_out', 'say_on_screen', 'exec_in'),
      wire('project', 'return_value', 'on_screen_text', 'in_bool'),
      wire('on_screen_text', 'return_value', 'say_on_screen', 'in_string'),
      wire('say_on_screen', 'exec_out', 'say_device', 'exec_in'),
      wire('device', 'return_value', 'say_device', 'in_string'),
    ]);
    final run = play(w, doc, 'BP_Input');
    w.beginPlay();
    w.tick(0.1);
    expect(printed(run.trace), ['false', 'false', 'true', 'Keyboard']);
    input.injectKeyDown(LuminaKey.keyW);
    input.injectAnalog(LuminaKey.mouseX, 4.0);
    input.injectMousePosition(Vector2(300, 200));
    w.tick(0.1);
    expect(printed(run.trace).skip(4), ['true', 'true', 'true', 'Mouse']);
    w.tick(0.1);
    expect(printed(run.trace).skip(8), ['true', 'false', 'true', 'Mouse'], reason: 'just-pressed lasts one tick; the last device stays');
    expect(LuminaBlueprintFunctionLibrary.getInputKeyTimeDown(run.me, 'W'), closeTo(0.2, 1e-9));
    expect(LuminaBlueprintFunctionLibrary.getMousePosition(run.me), Vector2(300, 200));
    expect(LuminaBlueprintFunctionLibrary.getViewportSize(run.me), Vector2(1280, 720));
    final ahead = LuminaBlueprintFunctionLibrary.projectWorldToScreen(run.me, Vector3(0, 500, 100));
    expect(ahead.returnValue, isTrue);
    expect(ahead.screenPosition.x, closeTo(640, 1.0), reason: 'straight ahead of the camera: centred');
    expect(ahead.screenPosition.y, inInclusiveRange(0.0, 720.0));
    final behind = LuminaBlueprintFunctionLibrary.projectWorldToScreen(run.me, Vector3(0, -900, 100));
    expect(behind.returnValue, isFalse);
    final ray = LuminaBlueprintFunctionLibrary.deprojectScreenToWorld(run.me, Vector2(640, 360));
    expect(ray.worldDirection.y, closeTo(1.0, 1e-3), reason: 'the centre pixel looks along +Y');
    expect(ray.worldLocation.y, closeTo(-300.0, 1e-6));
    input.injectKeyUp(LuminaKey.keyW);
    w.tick(0.1);
    expect(LuminaBlueprintFunctionLibrary.isInputKeyDown(run.me, 'W'), isFalse);
    expect(LuminaBlueprintFunctionLibrary.getInputKeyTimeDown(run.me, 'W'), 0.0);
    LuminaBlueprintFunctionLibrary.setMousePosition(run.me, Vector2(10, 20));
    expect(input.mousePosition, Vector2(10, 20));
    expect(LuminaKey.fromName('space'), LuminaKey.keySpace);
    expect(LuminaKey.fromName('LeftMouseButton'), LuminaKey.mouseLeft);
  });
}
