import 'dart:io';

import 'package:flutter/foundation.dart' show ValueKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/data/services/blueprint_class_registry.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

import 'generated/level_script/levels/l_test.dart';
import 'level_blueprint_fixture.dart';

/// A Level Blueprint compiles into its level's `_<Level>Script`
/// class. The generated level and the sources it imports are committed under
/// `test/blueprint/generated/level_script/` (a `lib/` subtree) and played
/// in-process against the VM, trace for trace. Regenerate after an
/// intentional generator change with
/// `UPDATE_GOLDENS=1 flutter test test/blueprint/level_script_codegen_test.dart`.
const String _goldenDir = 'test/blueprint/generated/level_script';
const List<String> _goldenFiles = ['levels/l_test.dart', 'actors/actors.g.dart', 'actors/bp_door.dart'];

void main() {
  tearDown(LuminaBlueprintActorClasses.clear);

  test('L_Test generates _LTestScript from its Level Blueprint, with a field per placed actor', () async {
    final project = Directory.systemTemp.createTempSync('lumina_bp14_codegen_');
    addTearDown(() => project.deleteSync(recursive: true));
    writeLevelTestProject(project.path);
    final generator = DartCodeGeneratorService();
    final door = LuminaLevelRepository(project.path).load(levelTestPath)!;
    expect(await generator.compileAndWriteActor(project.path, 'BP_Door', levelDoorBlueprint().toJson(), assetPath: levelDoorPath), isTrue);
    final code = generator.generateLevelDart(levelName: 'L_Test', actors: const [], actorMaps: door.actors, projectDir: project.path);
    File('${project.path}/lib/levels/l_test.dart')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(code);

    expect(code, contains('class _LTestScript extends LuminaLevelScriptActor with LuminaBlueprintRuntime, LuminaBlueprintLevelActors {'));
    expect(code, contains("_LTestScript() : super(key: const ValueKey('L_Test_script'))"));
    expect(code, contains("'Door_01': 'door_01',"));
    expect(code, contains('LuminaActor? door01;'));
    expect(code, contains('LuminaTriggerVolume? trigger01;'));
    expect(code, contains("door01 = super.levelActor('Door_01');"));
    expect(code, contains('LuminaTriggerVolume(key: const ValueKey(\'trigger_01\')'));
    expect(code, contains('void _setUpLevel() {'), reason: 'the level\'s own setup still runs');
    expect(code, contains('playerController = mode.login();'));
    expect(code, isNot(contains('void onLevelUnloaded()')), reason: 'written only when the graph has the event');

    // A level without a Blueprint keeps the plain script, byte for byte as before.
    final plain = generator.generateLevelDart(levelName: 'L_Plain', actors: const [], actorMaps: door.actors, projectDir: project.path);
    expect(plain, contains('class _LPlainScript extends LuminaLevelScriptActor {'));
    expect(plain, isNot(contains('LuminaBlueprintLevelActors')));

    final update = Platform.environment['UPDATE_GOLDENS'] == '1';
    for (final f in _goldenFiles) {
      final generated = File('${project.path}/lib/$f').readAsStringSync();
      final golden = File('$_goldenDir/$f');
      if (update) {
        golden
          ..parent.createSync(recursive: true)
          ..writeAsStringSync(generated);
      }
      expect(golden.existsSync(), isTrue, reason: 'run with UPDATE_GOLDENS=1 to create $f');
      expect(generated, golden.readAsStringSync(), reason: '$f changed; UPDATE_GOLDENS=1 regenerates it');
    }
  });

  test('the generated _LTestScript resolves door01 after load and matches the VM trace', () {
    // VM: the level as Play-In-Editor builds it.
    final project = Directory.systemTemp.createTempSync('lumina_bp14_parity_');
    addTearDown(() => project.deleteSync(recursive: true));
    writeLevelTestProject(project.path);
    final registry = LuminaBlueprintClassRegistry(project.path, inputActions: const []);
    final vmWorld = LuminaWorld(worldType: LuminaWorldType.game);
    vmWorld.registerSubsystem<LuminaCollisionSubsystem>(LuminaCollisionSubsystem());
    vmWorld.persistentLevel.registerActor(
        registry.classFor(levelDoorPath)!.instantiate(key: const ValueKey('door_01'), location: LuminaAxes.location([0.0, 400.0, 0.0])));
    vmWorld.persistentLevel.registerActor(
        LuminaTriggerVolume(key: const ValueKey('trigger_01'), extent: Vector3(100, 100, 100), location: LuminaAxes.location([0.0, 1500.0, 50.0])));
    vmWorld.persistentLevel.registerActor(LuminaPlayerStart(key: const ValueKey('player_start'), location: LuminaAxes.location([0.0, -300.0, 100.0])));
    final vmScript = registry.levelScriptFor(levelTestPath)!;
    final vmTrace = <LuminaBlueprintTraceEvent>[];
    vmScript.trace = vmTrace.add;
    vmWorld.persistentLevel.scriptActor = vmScript;
    // Play-In-Editor's order: the game mode before beginPlay (which runs
    // initGame), the player's login right after it.
    vmWorld.gameMode = LuminaGameMode();

    // Generated: the committed level, mounted as a built game mounts it.
    final level = LTest();
    // The level is the world's persistent level, owned by it as in a built
    // game, so its script registers and logs the player in.
    final genWorld = LuminaWorld(worldType: LuminaWorldType.game, initialLevel: level);
    LuminaElement(level).mount(LuminaElementContext(node: level, world: genWorld));
    final genScript = level.scriptActor! as LuminaBlueprintRuntime;
    final genTrace = <LuminaBlueprintTraceEvent>[];
    genScript.trace = genTrace.add;

    for (final w in [vmWorld, genWorld]) {
      w.beginPlay();
      if (w == vmWorld) w.gameMode!.login();
      for (var i = 0; i < 90; i++) {
        w.tick(1 / 60);
      }
    }
    final door01 = (genScript as dynamic).door01 as LuminaActor?;
    expect(door01, isNotNull, reason: 'resolved once the level loaded');
    expect(door01!.key, const ValueKey('door_01'));
    expect(genScript.blueprintClassName, vmScript.blueprintClassName);

    String step(LuminaBlueprintTraceEvent e) => '${e.eventNodeId}/${e.nodeId}/${e.registryId}${e.printed == null ? '' : ' "${e.printed}"'}';
    expect(genTrace.map(step).toList(), vmTrace.map(step).toList());
    expect(vmTrace.where((e) => e.printed != null).map((e) => e.printed), containsAllInOrder(['level loaded', 'player starts 1']));
    // BeginPlay saw the logged-in player's pawn in both.
    final pawnLines = [for (final e in vmTrace) if (e.printed?.startsWith('player pawn ') ?? false) e.printed!];
    expect(pawnLines, hasLength(1));
    expect(pawnLines.single, isNot('player pawn None'), reason: 'Get Player Pawn is null on BeginPlay');
    // The door turned in both.
    for (final w in [vmWorld, genWorld]) {
      final door = w.actors.firstWhere((a) => a.key == const ValueKey('door_01'));
      expect(LuminaBlueprintFunctionLibrary.getActorRotation(door).z.abs(), closeTo(90.0, 0.5));
    }
    level.unloadActors();
    vmWorld.persistentLevel.unloadActors();
    expect(genTrace.last.printed, 'level end');
    expect(vmTrace.last.printed, 'level end');
  });
}
