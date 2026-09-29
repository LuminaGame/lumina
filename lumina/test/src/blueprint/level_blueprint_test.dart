import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show ValueKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/data/services/blueprint_class_registry.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

import '../../blueprint/level_blueprint_fixture.dart';

/// Level Blueprints: a graph per level stored in its `.lmas`,
/// typed references to the level's placed actors, level events, and the
/// VM's level script on a real world built from the level.
void main() {
  late Directory project;

  setUp(() {
    project = Directory.systemTemp.createTempSync('lumina_bp14_');
    writeLevelTestProject(project.path);
  });
  tearDown(() {
    if (project.existsSync()) project.deleteSync(recursive: true);
    LuminaBlueprintActorClasses.clear();
  });

  test('a level .lmas with metadata.levelBlueprint round-trips through the level repository; none loads empty', () {
    final repo = LuminaLevelRepository(project.path);
    final level = repo.load(levelTestPath)!;
    expect(level.hasLevelBlueprint, isTrue);
    final stored = level.metadata['levelBlueprint'] as Map;
    expect(stored['kind'], 'level_blueprint');
    expect(stored['levelPath'], levelTestPath);
    final back = repo.loadLevelBlueprint(levelTestPath);
    expect(back.levelName, 'L_Test');
    expect(back.blueprint.parentClass, 'LuminaLevelScriptActor');
    expect(jsonEncode(back.toJson()), jsonEncode(levelTestBlueprint().toJson()));
    expect(back.blueprint.eventGraph.nodes.map((n) => n.id), contains('door'));
    expect(level.actors.map((a) => a['name']), ['Door_01', 'Trigger_01', 'PlayerStart']);

    // A level saved by Save Level (actors only) keeps its Blueprint.
    final save = SaveLevelUseCase();
    return save(projectDir: project.path, levelName: 'L_Test', actors: level.actors).then((result) {
      expect(result.isSuccess, isTrue);
      expect(repo.load(levelTestPath)!.hasLevelBlueprint, isTrue);

      // A level without one loads an empty graph; saving it stores one.
      File('${project.path}/contents/levels/L_Plain.lmas')
          .writeAsStringSync(jsonEncode({'name': 'L_Plain', 'type': 'level', 'metadata': {'actors': []}}));
      final plain = repo.loadLevelBlueprint('contents/levels/L_Plain.lmas');
      expect(plain.isEmpty, isTrue);
      expect(plain.levelPath, 'contents/levels/L_Plain.lmas');
      expect(repo.loadLevelBlueprint('contents/levels/L_Missing.lmas').isEmpty, isTrue);
      final doc = levelTestBlueprint();
      repo.saveLevelBlueprint(LuminaLevelBlueprintDocument(levelPath: 'contents/levels/L_Plain.lmas', blueprint: doc.blueprint));
      final reloaded = repo.load('contents/levels/L_Plain.lmas')!;
      expect(reloaded.levelBlueprint.blueprint.eventGraph.nodes.length, doc.blueprint.eventGraph.nodes.length);
      expect(reloaded.container['name'], 'L_Plain', reason: 'other keys are kept');
      reloaded.levelBlueprint = null;
      expect(reloaded.hasLevelBlueprint, isFalse);
    });
  });

  test('forLevel types Get Door_01 as Actor:BP_Door, refuses it for an Actor:BP_Chair target, and a rename breaks the node', () {
    final refs = LuminaBlueprintLevelActorRef.fromActorMaps(levelTestActors());
    expect(refs.map((r) => r.actorClass), ['Actor:BP_Door', 'Actor:LuminaTriggerVolume', 'Actor:LuminaPlayerStart']);
    final level = levelTestBlueprint();
    final context = LuminaBlueprintTypeContext.forLevel(level,
        levelActors: refs, actorParents: const {'BP_Door': 'LuminaActor', 'BP_Chair': 'LuminaActor'});
    expect(context.selfClass, 'Actor:LuminaLevelScriptActor');
    final door = LuminaBlueprintNodeLibrary.place('get_level_actor', nodeId: 'd', literals: {'actor': 'Door_01'}, context: context);
    expect(door.title, 'Door_01');
    expect(door.category, 'Level Actors');
    final doorOut = LuminaBlueprintNodeLibrary.pinsOf(door, context)!.outputs.single;
    expect(doorOut.objectClass, 'Actor:BP_Door');
    final trigger = LuminaBlueprintNodeLibrary.place('get_level_actor', nodeId: 't', literals: {'actor': 'Trigger_01'}, context: context);
    expect(LuminaBlueprintNodeLibrary.pinsOf(trigger, context)!.outputs.single.objectClass, 'Actor:LuminaTriggerVolume');

    // Into a BP_Chair target: refused; into an Actor target: fine.
    final sit = LuminaBlueprintNodeLibrary.place('call_custom_event', nodeId: 'sit', literals: {'event': 'Sit', 'class': 'Actor:BP_Chair'}, context: context);
    final chairTarget = LuminaBlueprintNodeLibrary.pinsOf(sit, context)!.inputs.firstWhere((p) => p.id == 'target');
    expect(chairTarget.objectClass, 'Actor:BP_Chair');
    expect(LuminaBlueprintNodeLibrary.connectionError(doorOut, chairTarget, context: context), isNotNull);
    final turn = LuminaBlueprintNodeLibrary.place('set_actor_rotation', nodeId: 'r', context: context);
    final actorTarget = LuminaBlueprintNodeLibrary.pinsOf(turn, context)!.inputs.firstWhere((p) => p.id == 'target');
    expect(LuminaBlueprintNodeLibrary.connectionError(doorOut, actorTarget, context: context), isNull);

    // The fixture validates clean; wired into BP_Chair it does not.
    expect(validateBlueprint(level.blueprint, typeContext: context).where((d) => d.isError), isEmpty);
    level.blueprint.eventGraph.nodes.add(sit);
    level.blueprint.eventGraph.wires.addAll(const [
      LuminaBlueprintWire(id: 'x0', fromNodeId: 'say_end', fromPinId: 'exec_out', toNodeId: 'sit', toPinId: 'exec_in'),
      LuminaBlueprintWire(id: 'x1', fromNodeId: 'door', fromPinId: 'return_value', toNodeId: 'sit', toPinId: 'target'),
    ]);
    final wrong = validateBlueprint(level.blueprint, typeContext: context).where((d) => d.isError).toList();
    expect(wrong.map((d) => d.nodeId), contains('sit'));
    expect(wrong.firstWhere((d) => d.nodeId == 'sit').message, contains('BP_Chair'));

    // Door_01 renamed to Door_02 in the level: the reference is reported.
    final renamed = [
      for (final a in levelTestActors()) a['name'] == 'Door_01' ? {...a, 'name': 'Door_02'} : a,
    ];
    final fresh = levelTestBlueprint();
    final renamedContext = LuminaBlueprintTypeContext.forLevel(fresh,
        levelActors: LuminaBlueprintLevelActorRef.fromActorMaps(renamed), actorParents: const {'BP_Door': 'LuminaActor'});
    final errors = validateBlueprint(fresh.blueprint, typeContext: renamedContext).where((d) => d.isError).toList();
    final broken = errors.firstWhere((d) => d.nodeId == 'door');
    expect(broken.message, contains("no actor named 'Door_01'"));

    // Two actors with one name are ambiguous.
    final twins = LuminaBlueprintLevelActorRef.fromActorMaps([
      ...levelTestActors(),
      {'id': 'door_02', 'name': 'Door_01', 'type': 'StaticMesh'},
    ]);
    final twinErrors = validateBlueprint(fresh.blueprint,
        typeContext: LuminaBlueprintTypeContext.forLevel(fresh, levelActors: twins, actorParents: const {'BP_Door': 'LuminaActor'}));
    expect(twinErrors.any((d) => d.isError && d.message.contains("Two actors in this level are named 'Door_01'")), isTrue);
  });

  test('a component node in a level graph, or a level node in a class Blueprint, is an error', () {
    final level = LuminaLevelBlueprintDocument(levelPath: levelTestPath);
    final context = LuminaBlueprintTypeContext.forLevel(level, levelActors: LuminaBlueprintLevelActorRef.fromActorMaps(levelTestActors()));
    level.blueprint.eventGraph.nodes.addAll([
      LuminaBlueprintNodeLibrary.place('get_component', nodeId: 'comp', literals: {'component': 'Mesh'}, context: context),
      LuminaBlueprintNodeLibrary.place('get_component_by_class', nodeId: 'by_class',
          literals: {'class': 'Component:LuminaStaticMeshComponent'}, context: context),
    ]);
    final errors = validateBlueprint(level.blueprint, typeContext: context).where((d) => d.isError).toList();
    expect(errors.where((d) => d.nodeId == 'comp').map((d) => d.message), contains(contains('Level Blueprints have no components')));
    expect(errors.where((d) => d.nodeId == 'by_class').map((d) => d.message), contains(contains('Level Blueprints have no components')));
    level.blueprint.components.add(LuminaBlueprintComponent(id: 'mesh', name: 'Mesh', type: 'LuminaStaticMeshComponent'));
    expect(validateBlueprint(level.blueprint, typeContext: context).any((d) => d.isError && d.nodeId == null && d.message.contains('no components')),
        isTrue);

    // Level-only nodes outside a level, and the palette filter.
    final doc = LuminaBlueprintDocument();
    doc.eventGraph.nodes.add(LuminaBlueprintNodeLibrary.place('event_level_tick', nodeId: 'lt'));
    expect(validateBlueprint(doc).firstWhere((d) => d.nodeId == 'lt').message, contains('only be placed in a Level Blueprint'));
    final levelSpec = LuminaBlueprintNodeLibrary.spec('get_level_actor')!;
    final compSpec = LuminaBlueprintNodeLibrary.spec('get_component')!;
    expect(LuminaBlueprintNodeLibrary.availableIn(levelSpec, context), isTrue);
    expect(LuminaBlueprintNodeLibrary.availableIn(compSpec, context), isFalse);
    expect(LuminaBlueprintNodeLibrary.availableIn(levelSpec, const LuminaBlueprintTypeContext()), isFalse);

    // Level BeginPlay is BeginPlay: both is the event twice.
    final twice = LuminaLevelBlueprintDocument(levelPath: levelTestPath);
    twice.blueprint.eventGraph.nodes.addAll([
      LuminaBlueprintNodeLibrary.place('event_beginplay', nodeId: 'a', context: context),
      LuminaBlueprintNodeLibrary.place('event_level_begin_play', nodeId: 'b', context: context),
    ]);
    expect(validateBlueprint(twice.blueprint, typeContext: context).any((d) => d.isError && d.nodeId == 'b' && d.message.contains('placed twice')),
        isTrue);
  });

  /// The VM world of L_Test: every placed actor as Play-In-Editor makes it
  /// (keyed by id), the level script from the class registry as the
  /// persistent level's script actor, and a trace shared by all Blueprints.
  ({LuminaWorld world, LuminaBlueprintLevelScript script, List<String> log, LuminaActor door, LuminaTriggerVolume trigger}) playLevel() {
    final registry = LuminaBlueprintClassRegistry(project.path, inputActions: const []);
    final world = LuminaWorld(worldType: LuminaWorldType.game);
    world.registerSubsystem<LuminaCollisionSubsystem>(LuminaCollisionSubsystem());
    final log = <String>[];
    final door = registry.classFor(levelDoorPath)!.instantiate(key: const ValueKey('door_01'), location: LuminaAxes.location([0.0, 400.0, 0.0]));
    (door as LuminaBlueprintRuntime).trace = (e) {
      if (e.printed != null) log.add(e.printed!);
    };
    final trigger = LuminaTriggerVolume(key: const ValueKey('trigger_01'), extent: Vector3(100, 100, 100), location: LuminaAxes.location([0.0, 1500.0, 50.0]));
    final start = LuminaPlayerStart(key: const ValueKey('player_start'), location: LuminaAxes.location([0.0, -300.0, 100.0]));
    for (final a in [door, trigger, start]) {
      world.persistentLevel.registerActor(a);
    }
    final script = registry.levelScriptFor(levelTestPath);
    expect(script, isNotNull, reason: '${registry.diagnostics}');
    script!.trace = (e) {
      if (e.printed != null) log.add(e.printed!);
    };
    world.persistentLevel.scriptActor = script;
    return (world: world, script: script, log: log, door: door, trigger: trigger);
  }

  test('VM: Level Loaded runs before any BeginPlay, BeginPlay opens Door_01 through its custom event, Tick ticks, EndPlay on unload', () {
    final run = playLevel();
    expect(run.script.blueprintClassName, 'L_Test');
    expect(run.script.levelActorIds, {'Door_01': 'door_01', 'Trigger_01': 'trigger_01', 'PlayerStart': 'player_start'});
    expect(LuminaBlueprintActorClasses.has('Actor:L_Test'), isFalse, reason: 'a level script is never spawnable');
    run.world.beginPlay();
    expect(run.log.first, 'level loaded', reason: 'Level Loaded before other actors\' BeginPlay');
    expect(run.log.indexOf('level loaded'), lessThan(run.log.indexOf('Door ready')));
    expect(run.log, containsAllInOrder(['Door opened', 'player starts 1']));
    expect(LuminaBlueprintFunctionLibrary.getLevelActor(run.script, 'Door_01'), same(run.door));
    expect(LuminaBlueprintFunctionLibrary.getLevelActor(run.script, 'Nobody'), isNull);
    expect(LuminaBlueprintFunctionLibrary.getLevelActor(run.door, 'Door_01'), isNull, reason: 'only a level script has level actors');
    for (var i = 0; i < 90; i++) {
      run.world.tick(1 / 60);
    }
    expect(run.script.variables['Ticks'], 90);
    // The DoorSwing timeline turned the door 90° in one second.
    final yaw = LuminaBlueprintFunctionLibrary.getActorRotation(run.door).z;
    expect(yaw.abs(), closeTo(90.0, 0.5));

    // Destroyed: Get Door_01 is None and Is Valid false.
    run.world.destroyActor(run.door);
    run.world.tick(1 / 60);
    expect(LuminaBlueprintFunctionLibrary.getLevelActor(run.script, 'Door_01'), isNull);
    expect(LuminaBlueprintFunctionLibrary.isValid(LuminaBlueprintFunctionLibrary.getLevelActor(run.script, 'Door_01')), isFalse);

    run.world.persistentLevel.unloadActors();
    expect(run.log.last, 'level end');
  });

  test('the level\'s OnTriggerEnter, bound to Trigger_01\'s OnActorBeginOverlap, fires when the pawn enters the trigger', () {
    final run = playLevel();
    final pawn = LuminaPawn(
      key: const ValueKey('pawn'),
      location: LuminaAxes.location([0.0, 0.0, 50.0]),
      root: LuminaCollisionComponent(shapeType: CollisionShapeType.box)..boxExtent.setFrom(Vector3(30, 30, 30)),
    );
    run.world.persistentLevel.registerActor(pawn);
    run.world.beginPlay();
    run.world.tick(1 / 60);
    expect(run.log, isNot(contains('trigger entered')));
    expect(run.trigger.isActorEventBound(LuminaActor.actorBeginOverlapEvent), isTrue);
    pawn.actorLocation = LuminaAxes.location([0.0, 1500.0, 50.0]);
    run.world.tick(1 / 60);
    expect(run.log.where((l) => l == 'trigger entered'), hasLength(1));
    run.world.tick(1 / 60);
    expect(run.log.where((l) => l == 'trigger entered'), hasLength(1), reason: 'begin overlap fires once');
  });

  test('a level without a Blueprint has no level script', () {
    final registry = LuminaBlueprintClassRegistry(project.path, inputActions: const []);
    File('${project.path}/contents/levels/L_Plain.lmas')
        .writeAsStringSync(jsonEncode({'name': 'L_Plain', 'type': 'level', 'metadata': {'actors': []}}));
    expect(registry.levelClassFor('contents/levels/L_Plain.lmas'), isNull);
    expect(registry.levelScriptFor('contents/levels/L_Plain.lmas'), isNull);
    // An editor's unsaved graph wins over the file.
    final unsaved = levelTestBlueprint();
    final cls = registry.levelClassFor('contents/levels/L_Plain.lmas', actorMaps: levelTestActors(), document: unsaved);
    expect(cls?.isLevelScript, isTrue);
    expect(cls?.hasErrors, isFalse, reason: '${cls?.diagnostics}');
  });
}
