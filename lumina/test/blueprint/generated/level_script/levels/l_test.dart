// GENERATED CODE - DO NOT MODIFY BY HAND
// Lumina Engine 0.0.1 Auto-Generated Level Code
// ignore_for_file: unused_import, prefer_const_constructors, camel_case_types, non_constant_identifier_names, unnecessary_this, dead_code, unused_local_variable, dead_null_aware_expression

import 'package:flutter/foundation.dart' show ValueKey;
import 'package:lumina/lumina_runtime.dart';
import 'package:vector_math/vector_math_64.dart';
import '../actors/actors.g.dart';

/// Level `L_Test` as authored in Lumina Studio.
class LTest extends LuminaLevel {
  LTest({super.key})
      : super(name: 'L_Test', scriptActor: _LTestScript(), children: [
          // Door_01
          luminaBlueprintFactories['contents/blueprints/BP_Door.lmas']!(key: const ValueKey('door_01'), location: Vector3(0.0000, 0.0000, -400.0000), rotation: luminaAuthoringRotation(0.0000, 0.0000, 0.0000)),
          // Trigger_01
          LuminaTriggerVolume(key: const ValueKey('trigger_01'), location: Vector3(0.0000, 50.0000, -1500.0000), rotation: luminaAuthoringRotation(0.0000, 0.0000, 0.0000), extent: Vector3(100.0000, 100.0000, 100.0000)),
          // PlayerStart
          LuminaPlayerStart(key: const ValueKey('player_start'), location: Vector3(0.0000, 100.0000, 300.0000), rotation: luminaAuthoringRotation(0.0000, 0.0000, 0.0000)),
        ]);

  /// Every asset this level's actors load, for Load Level / Change Level.
  static const List<LuminaAssetRef> assetManifest = <LuminaAssetRef>[
    LuminaAssetRef('contents/blueprints/BP_Door.lmas', LuminaAssetKind.blueprint),
  ];
}

/// Level `L_Test`'s script: its Level Blueprint, compiled by Lumina.
class _LTestScript extends LuminaLevelScriptActor with LuminaBlueprintRuntime, LuminaBlueprintLevelActors {
  _LTestScript() : super(key: const ValueKey('L_Test_script')) {
    blueprintComponentTree = _components;
    blueprintComponents = LuminaBlueprintComponents.construct(this, _components);
  }

  @override
  String get blueprintClassName => 'L_Test';

  /// The component tree (the Blueprint's construction script).
  static final List<LuminaBlueprintComponent> _components = [
  ];

  /// The placed actors this script refers to, by name → the id the level mounts them with.
  @override
  final Map<String, String> levelActorIds = const {
    'Door_01': 'door_01',
    'Trigger_01': 'trigger_01',
    'PlayerStart': 'player_start',
  };

  // The placed actors, resolved once the level is loaded.
  LuminaActor? door01;
  LuminaTriggerVolume? trigger01;
  LuminaPlayerStart? playerStart;

  /// The controller created by the game mode at begin play.
  LuminaPlayerController? playerController;

  /// Applies the level environment (post-process) when play begins and,
  /// when the level authors a PlayerStart, logs the local player in.
  void _setUpLevel() {
    final w = world;
    if (w == null) return;
    if (w.getSubsystem<LuminaCollisionSubsystem>() == null) {
      w.registerSubsystem(LuminaCollisionSubsystem());
    }
    if (w.getSubsystem<LuminaInputSubsystem>() == null) {
      w.registerSubsystem(LuminaInputSubsystem());
    }
    var mode = w.gameMode;
    if (mode == null) {
      mode = LuminaGameMode();
      w.gameMode = mode;
      mode.initGame(w);
    }
    playerController = mode.login();
  }

  int ticks = 0;

  /// Custom events, functions and interface events by name.
  @override
  Map<String, Object?> callBlueprint(String name, Map<String, Object?> args) {
    switch (name) {
      case 'OnTriggerEnter':
        _onEntered(args['OverlappedActor'], args['OtherActor']); return const {};
      default:
        return super.callBlueprint(name, args);
    }
  }

  @override
  void onBeginPlay() {
    super.onBeginPlay();
    _setUpLevel();
    _onBegin();
  }

  @override
  void onTick(double deltaSeconds) {
    super.onTick(deltaSeconds);
    playerController?.onTick(deltaSeconds);
    advanceBlueprintLatent(deltaSeconds);
    _onTick(deltaSeconds);
  }

  @override
  void onEndPlay(LuminaEndPlayReason reason) {
    super.onEndPlay(reason);
    _onEnd(reason.displayName);
  }

  @override
  void onLevelLoaded() {
    super.onLevelLoaded();
    door01 = super.levelActor('Door_01');
    final trigger01Found = super.levelActor('Trigger_01');
    trigger01 = trigger01Found is LuminaTriggerVolume ? trigger01Found : null;
    final playerStartFound = super.levelActor('PlayerStart');
    playerStart = playerStartFound is LuminaPlayerStart ? playerStartFound : null;
    _onLoaded();
  }

  /// The placed actor [name]: its field while it is in play.
  @override
  LuminaActor? levelActor(String name) => switch (name) {
        'Door_01' => liveLevelActor(door01 ?? super.levelActor(name)),
        'Trigger_01' => liveLevelActor(trigger01 ?? super.levelActor(name)),
        'PlayerStart' => liveLevelActor(playerStart ?? super.levelActor(name)),
        _ => super.levelActor(name),
      };

  /// Event Level Loaded (node loaded).
  void _onLoaded() {
    LuminaBlueprintFunctionLibrary.printString(this, 'level loaded', true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('loaded', 'say_loaded', 'print_string', {'in_string': 'level loaded', 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: 'level loaded');
  }

  /// Event Level BeginPlay (node begin).
  void _onBegin() {
    final p0 = LuminaBlueprintFunctionLibrary.getLevelActor(this, 'Door_01');
    if (trace != null) blueprintTrace('begin', 'door', 'get_level_actor', {'return_value': p0});
    LuminaBlueprintFunctionLibrary.callCustomEvent(this, 'Open', <String, Object?>{}, p0);
    if (trace != null) blueprintTrace('begin', 'open_door', 'call_custom_event', {'target': p0});
    final p1 = LuminaBlueprintFunctionLibrary.getLevelActor(this, 'Trigger_01');
    if (trace != null) blueprintTrace('begin', 'trigger', 'get_level_actor', {'return_value': p1});
    LuminaBlueprintFunctionLibrary.bindEventToDispatcher(this, p1, 'OnActorBeginOverlap', LuminaBlueprintDelegate(this, 'OnTriggerEnter'));
    if (trace != null) blueprintTrace('begin', 'bind', 'bind_event_to_dispatcher', {'target': p1, 'event': LuminaBlueprintDelegate(this, 'OnTriggerEnter')});
    final p2 = LuminaBlueprintFunctionLibrary.getLevelActorsOfClass(this, 'Actor:LuminaPlayerStart');
    if (trace != null) blueprintTrace('begin', 'starts', 'get_level_actors_of_class', {'class': 'Actor:LuminaPlayerStart', 'return_value': p2});
    final p3 = LuminaBlueprintFunctionLibrary.arrayLength(p2);
    if (trace != null) blueprintTrace('begin', 'start_count', 'array_length', {'target_array': p2, 'return_value': p3});
    final p4 = LuminaBlueprintFunctionLibrary.intToString(p3);
    if (trace != null) blueprintTrace('begin', 'start_text', 'int_to_string', {'in_int': p3, 'return_value': p4});
    final p5 = LuminaBlueprintFunctionLibrary.append('player starts ', p4);
    if (trace != null) blueprintTrace('begin', 'start_line', 'append', {'a': 'player starts ', 'b': p4, 'return_value': p5});
    LuminaBlueprintFunctionLibrary.printString(this, p5, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_starts', 'print_string', {'in_string': p5, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p5);
    final p6 = LuminaBlueprintFunctionLibrary.getPlayerPawn(this, 0);
    if (trace != null) blueprintTrace('begin', 'pawn', 'get_player_pawn', {'player_index': 0, 'return_value': p6});
    final p7 = LuminaBlueprintFunctionLibrary.getDisplayName(p6);
    if (trace != null) blueprintTrace('begin', 'pawn_name', 'get_display_name', {'object': p6, 'return_value': p7});
    final p8 = LuminaBlueprintFunctionLibrary.append('player pawn ', p7);
    if (trace != null) blueprintTrace('begin', 'pawn_line', 'append', {'a': 'player pawn ', 'b': p7, 'return_value': p8});
    LuminaBlueprintFunctionLibrary.printString(this, p8, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_pawn', 'print_string', {'in_string': p8, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p8);
    _tlSwing.playFromStart();
    if (trace != null) blueprintTrace('begin', 'swing', 'timeline', {'pin': 'play_from_start'});
  }

  /// OnTriggerEnter (node entered).
  void _onEntered(Object? overlappedActor, Object? otherActor) {
    LuminaBlueprintFunctionLibrary.printString(this, 'trigger entered', true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('entered', 'say_entered', 'print_string', {'in_string': 'trigger entered', 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: 'trigger entered');
  }

  /// Event Level Tick (node tick).
  void _onTick(double deltaSeconds) {
    int? oticks_set_value;
    final p9 = ticks;
    if (trace != null) blueprintTrace('tick', 'ticks_get', 'variable_get', {'value': p9});
    final p10 = LuminaBlueprintFunctionLibrary.intAdd(p9, 1);
    if (trace != null) blueprintTrace('tick', 'ticks_plus', 'int_add', {'a': p9, 'b': 1, 'return_value': p10});
    ticks = p10;
    oticks_set_value = p10;
    if (trace != null) blueprintTrace('tick', 'ticks_set', 'variable_set', {'value': p10});
  }

  /// Event Level EndPlay (node end).
  void _onEnd(String endPlayReason) {
    LuminaBlueprintFunctionLibrary.printString(this, 'level end', true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('end', 'say_end', 'print_string', {'in_string': 'level end', 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: 'level end');
  }

  /// Timeline DoorSwing (node swing).
  LuminaTimeline get _tlSwing => blueprintTimelines['swing'] ??= (LuminaTimeline.fromLiterals(<String, dynamic>{'name': 'DoorSwing', 'length': 1.0, 'tracks': <dynamic>[<String, dynamic>{'name': 'Yaw', 'type': 'float', 'keys': <dynamic>[<String, dynamic>{'time': 0.0, 'value': 0.0}, <String, dynamic>{'time': 1.0, 'value': 90.0}]}]})
    ..onUpdate = _tlSwingUpdate
    ..onFinished = _tlSwingFinished);

  void _tlSwingUpdate() {
    final values = _tlSwing.values();
    final p11 = LuminaBlueprintFunctionLibrary.getLevelActor(this, 'Door_01');
    if (trace != null) blueprintTrace('swing', 'door', 'get_level_actor', {'return_value': p11});
    final p12 = LuminaBlueprintFunctionLibrary.makeRotator(0.0, 0.0, (values['Yaw'] as double));
    if (trace != null) blueprintTrace('swing', 'yaw_rot', 'make_rotator', {'x': 0.0, 'y': 0.0, 'z': (values['Yaw'] as double), 'return_value': p12});
    LuminaBlueprintFunctionLibrary.setActorRotation(this, p11, p12);
    if (trace != null) blueprintTrace('swing', 'turn', 'set_actor_rotation', {'target': p11, 'new_rotation': p12});
  }

  void _tlSwingFinished() {
    final values = _tlSwing.values();
  }
}
