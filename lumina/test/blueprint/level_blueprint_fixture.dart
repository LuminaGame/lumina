import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:lumina/lumina.dart';

/// A level `L_Test` whose Level Blueprint scripts a placed door
/// (`Door_01`, a `BP_Door` Blueprint), a trigger (`Trigger_01`) and a player
/// start, written as Lumina Studio writes them.

const String levelTestPath = 'contents/levels/L_Test.lmas';
const String levelDoorPath = 'contents/blueprints/BP_Door.lmas';
const String levelDoorMeshPath = 'contents/meshes/door_mesh.glb';

/// The level's placed actors (`metadata.actors`, stored Z-up cm).
List<Map<String, dynamic>> levelTestActors() => [
      {
        'id': 'door_01',
        'name': 'Door_01',
        'type': 'Blueprint',
        'blueprintClass': levelDoorPath,
        'location': [0.0, 400.0, 0.0],
        'rotation': [0.0, 0.0, 0.0],
        'scale': [1.0, 1.0, 1.0],
      },
      {
        'id': 'trigger_01',
        'name': 'Trigger_01',
        'type': 'TriggerVolume',
        'location': [0.0, 1500.0, 50.0],
        'rotation': [0.0, 0.0, 0.0],
        'scale': [2.0, 2.0, 2.0],
      },
      {
        'id': 'player_start',
        'name': 'PlayerStart',
        'type': 'PlayerStart',
        'location': [0.0, -300.0, 100.0],
        'rotation': [0.0, 0.0, 0.0],
        'scale': [1.0, 1.0, 1.0],
      },
    ];

/// BP_Door: a mesh (the smoke's AC unit) on a scene root; BeginPlay prints "Door ready", its
/// custom event `Open` prints "Door opened" and turns the door 90°.
LuminaBlueprintDocument levelDoorBlueprint({String? meshPath}) {
  final doc = LuminaBlueprintDocument(parentClass: 'LuminaActor', components: [
    LuminaBlueprintComponent(id: 'root', name: 'DefaultSceneRoot', type: 'LuminaSceneComponent'),
    if (meshPath != null)
      LuminaBlueprintComponent(id: 'mesh', name: 'Barrel', type: 'LuminaStaticMeshComponent', parentId: 'root', properties: {
        'staticMeshAsset': meshPath,
      }),
  ]);
  final context = LuminaBlueprintTypeContext.forDocument(doc, className: 'BP_Door');
  LuminaBlueprintNode p(String id, String nodeId, [Map<String, dynamic>? literals]) =>
      LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: context);
  doc.eventGraph.nodes.addAll([
    p('event_beginplay', 'begin'),
    p('print_string', 'ready', {'in_string': 'Door ready'}),
    p('custom_event', 'open', {'name': 'Open'}),
    p('print_string', 'opened', {'in_string': 'Door opened'}),
  ]);
  doc.eventGraph.wires.addAll(const [
    LuminaBlueprintWire(id: 'd0', fromNodeId: 'begin', fromPinId: 'exec_out', toNodeId: 'ready', toPinId: 'exec_in'),
    LuminaBlueprintWire(id: 'd1', fromNodeId: 'open', fromPinId: 'exec_out', toNodeId: 'opened', toPinId: 'exec_in'),
  ]);
  return doc;
}

/// The Level Blueprint of L_Test:
/// - Level Loaded prints "level loaded" (before any actor's BeginPlay);
/// - Level BeginPlay calls `Open` on Door_01, binds `OnTriggerEnter` to
///   Trigger_01's OnActorBeginOverlap, counts the level's player starts and
///   starts the `DoorSwing` timeline (0 → 90° over one second) whose Update
///   turns Door_01;
/// - Level Tick counts ticks in `Ticks`; Level EndPlay prints "level end".
LuminaLevelBlueprintDocument levelTestBlueprint({List<LuminaBlueprintLevelActorRef>? actors}) {
  final level = LuminaLevelBlueprintDocument(
    levelPath: levelTestPath,
    blueprint: LuminaBlueprintDocument(variables: [const LuminaBlueprintVariable(name: 'Ticks', typeName: 'Int', defaultValue: 0)]),
  );
  final context = LuminaBlueprintTypeContext.forLevel(level,
      levelActors: actors ?? LuminaBlueprintLevelActorRef.fromActorMaps(levelTestActors()),
      actorParents: const {'BP_Door': 'LuminaActor'},
      customEventOwners: {
        'BP_Door': [const LuminaBlueprintCustomEvent(name: 'Open', nodeId: 'open')],
      });
  LuminaBlueprintNode p(String id, String nodeId, [Map<String, dynamic>? literals]) =>
      LuminaBlueprintNodeLibrary.place(id, nodeId: nodeId, literals: literals, context: context);
  var n = 0;
  LuminaBlueprintWire w(String from, String fromPin, String to, String toPin) =>
      LuminaBlueprintWire(id: 'lw${n++}', fromNodeId: from, fromPinId: fromPin, toNodeId: to, toPinId: toPin);
  final graph = level.blueprint.eventGraph;
  graph.nodes.addAll([
    p('event_level_loaded', 'loaded'),
    p('print_string', 'say_loaded', {'in_string': 'level loaded'}),
    p('event_level_begin_play', 'begin'),
    p('get_level_actor', 'door', {'actor': 'Door_01'}),
    p('call_custom_event', 'open_door', {'event': 'Open', 'class': 'Actor:BP_Door'}),
    p('get_level_actor', 'trigger', {'actor': 'Trigger_01'}),
    p('custom_event', 'entered', {
      'name': 'OnTriggerEnter',
      'parameters': [
        {'name': 'OverlappedActor', 'type': 'Actor'},
        {'name': 'OtherActor', 'type': 'Actor'},
      ],
    }),
    p('bind_event_to_dispatcher', 'bind', {'dispatcher': 'OnActorBeginOverlap'}),
    p('get_level_actors_of_class', 'starts', {'class': 'Actor:LuminaPlayerStart'}),
    p('array_length', 'start_count'),
    p('int_to_string', 'start_text'),
    p('append', 'start_line', {'a': 'player starts '}),
    p('print_string', 'say_starts'),
    // The local player has logged in by BeginPlay, in Play as in
    // the built game.
    p('get_player_pawn', 'pawn'),
    p('get_display_name', 'pawn_name'),
    p('append', 'pawn_line', {'a': 'player pawn '}),
    p('print_string', 'say_pawn'),
    p('timeline', 'swing', {
      'name': 'DoorSwing',
      'length': 1.0,
      'tracks': [
        {
          'name': 'Yaw',
          'type': 'float',
          'keys': [
            {'time': 0.0, 'value': 0.0},
            {'time': 1.0, 'value': 90.0},
          ],
        },
      ],
    }),
    p('make_rotator', 'yaw_rot'),
    p('set_actor_rotation', 'turn'),
    p('print_string', 'say_entered', {'in_string': 'trigger entered'}),
    p('event_level_tick', 'tick'),
    p(LuminaBlueprintNodeLibrary.variableGet, 'ticks_get', {'variable': 'Ticks'}),
    p('int_add', 'ticks_plus', {'b': 1}),
    p(LuminaBlueprintNodeLibrary.variableSet, 'ticks_set', {'variable': 'Ticks'}),
    p('event_level_end_play', 'end'),
    p('print_string', 'say_end', {'in_string': 'level end'}),
  ]);
  graph.wires.addAll([
    w('loaded', 'exec_out', 'say_loaded', 'exec_in'),
    w('begin', 'exec_out', 'open_door', 'exec_in'),
    w('door', 'return_value', 'open_door', 'target'),
    w('open_door', 'exec_out', 'bind', 'exec_in'),
    w('trigger', 'return_value', 'bind', 'target'),
    w('entered', 'delegate', 'bind', 'event'),
    w('bind', 'exec_out', 'say_starts', 'exec_in'),
    w('starts', 'return_value', 'start_count', 'target_array'),
    w('start_count', 'return_value', 'start_text', 'in_int'),
    w('start_text', 'return_value', 'start_line', 'b'),
    w('start_line', 'return_value', 'say_starts', 'in_string'),
    w('say_starts', 'exec_out', 'say_pawn', 'exec_in'),
    w('pawn', 'return_value', 'pawn_name', 'object'),
    w('pawn_name', 'return_value', 'pawn_line', 'b'),
    w('pawn_line', 'return_value', 'say_pawn', 'in_string'),
    w('say_pawn', 'exec_out', 'swing', 'play_from_start'),
    w('swing', 'update', 'turn', 'exec_in'),
    w('door', 'return_value', 'turn', 'target'),
    w('swing', 'Yaw', 'yaw_rot', 'z'),
    w('yaw_rot', 'return_value', 'turn', 'new_rotation'),
    w('entered', 'exec_out', 'say_entered', 'exec_in'),
    w('tick', 'exec_tick_out', 'ticks_set', 'exec_in'),
    w('ticks_get', 'value', 'ticks_plus', 'a'),
    w('ticks_plus', 'return_value', 'ticks_set', 'value'),
    w('end', 'exec_out', 'say_end', 'exec_in'),
  ]);
  return level;
}

/// Writes BP_Door, the level (actors + its Blueprint) and — with [meshGlb]
/// — the door's mesh into [projectDir].
void writeLevelTestProject(String projectDir, {String? meshGlb}) {
  final door = levelDoorBlueprint(meshPath: meshGlb == null ? null : levelDoorMeshPath);
  final json = jsonEncode(door.toJson());
  File('$projectDir/$levelDoorPath')
    ..parent.createSync(recursive: true)
    ..writeAsBytesSync(LuminaAsset(
      assetId: 'bp_BP_Door',
      name: 'BP_Door',
      type: AssetType.actor,
      rawPayload: Uint8List.fromList(utf8.encode(json)),
      metadata: {'parent_class': 'LuminaActor'},
    ).toProtoBufferBytes());
  if (meshGlb != null) {
    File('$projectDir/$levelDoorMeshPath')
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(File(meshGlb).readAsBytesSync());
  }
  final level = LuminaLevelDocument(relativePath: levelTestPath)..actors = levelTestActors();
  level.levelBlueprint = levelTestBlueprint();
  LuminaLevelRepository(projectDir).save(level);
}
