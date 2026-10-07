import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/data/services/blueprint_class_registry.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina/lumina.dart';

import '../blueprint/generated/project_registry/blueprint_registry.g.dart';
import '../blueprint/registry_project_fixture.dart';
import '../helpers/analyze_generated_project.dart';
import 'project_template_test.dart' show realFilesystemRunner;

/// The generated game registers every Blueprint registry.
///
/// The project registry and the sources it imports are committed under
/// `test/blueprint/generated/project_registry/` (a `lib/` subtree) so the
/// suite compiles and runs `registerProjectBlueprints()` in-process.
/// Regenerate after an intentional generator change with
/// `UPDATE_GOLDENS=1 flutter test test/data/code_generator_blueprint_registry_test.dart`.
const String _goldenDir = 'test/blueprint/generated/project_registry';

/// The generated files the golden tree mirrors, relative to `lib/`.
const List<String> _goldenFiles = [
  'blueprint_registry.g.dart',
  'actors/actors.g.dart',
  'actors/bp_door.dart',
  'enums/e_door_state.g.dart',
  'interfaces/bpi_interactable.g.dart',
];

void _clearRegistries() {
  LuminaBlueprintActorClasses.clear();
  LuminaBlueprintEnums.clear();
  LuminaBlueprintInterfaces.clear();
  LuminaBlueprintSaveGameClasses.clear();
  LuminaBlueprintMontages.clear();
  LuminaBlueprintParticleTemplates.clear();
}

void main() {
  final generator = DartCodeGeneratorService();
  tearDown(_clearRegistries);

  test('a project with an enum, interface, save class, montage, particle and BP_Door writes its registry sources', () async {
    final project = Directory.systemTemp.createTempSync('lumina_bp13_registry_');
    addTearDown(() => project.deleteSync(recursive: true));
    await writeRegistryProjectAssets(project.path);

    // compileAndWriteActor already refreshed it; a second write is stable.
    expect(generator.writeProjectBlueprintRegistry(project.path), isTrue);
    final lib = '${project.path}/lib';
    for (final f in _goldenFiles) {
      expect(File('$lib/$f').existsSync(), isTrue, reason: f);
    }
    final registry = File('$lib/blueprint_registry.g.dart').readAsStringSync();
    expect(registry, contains('void registerProjectBlueprints()'));
    expect(registry, contains("'BP_Door': () => luminaBlueprintFactories['contents/blueprints/BP_Door.lmas']!()"));
    expect(registry, contains('LuminaBlueprintEnums.registerAll(const ['));
    expect(registry, contains('EDoorState.document'));
    expect(registry, contains('BpiInteractable.document'));
    expect(registry, contains('LuminaBlueprintSaveGameClasses.registerAll(['));
    expect(registry, contains("path: 'contents/montages/AM_Wave.lmas'"));
    expect(registry, contains("LuminaBlueprintParticleTemplates.register('contents/particles/P_Sparks.lmas',"));
    expect(registry, isNot(contains('dart:io')), reason: 'plain registrations only');

    final update = Platform.environment['UPDATE_GOLDENS'] == '1';
    for (final f in _goldenFiles) {
      final generated = File('$lib/$f').readAsStringSync();
      final golden = File('$_goldenDir/$f');
      if (update) {
        golden
          ..parent.createSync(recursive: true)
          ..writeAsStringSync(generated);
      }
      expect(golden.existsSync(), isTrue, reason: 'run with UPDATE_GOLDENS=1 to create $f');
      expect(generated, golden.readAsStringSync(), reason: '$f changed; UPDATE_GOLDENS=1 regenerates it');
    }

    // Deleting the enum asset removes its source on the next write.
    File('${project.path}/contents/enums/E_DoorState.lmas').deleteSync();
    expect(generator.writeProjectBlueprintRegistry(project.path), isTrue);
    expect(File('$lib/enums/e_door_state.g.dart').existsSync(), isFalse);
    expect(File('$lib/blueprint_registry.g.dart').readAsStringSync(), isNot(contains('EDoorState')));
  });

  test('registerProjectBlueprints() fills every registry and resolves the compiled BP_Door', () {
    _clearRegistries();
    registerProjectBlueprints();
    expect(LuminaBlueprintEnums.lookup('E_DoorState')?.values, ['Closed', 'Opening', 'Open']);
    expect(LuminaBlueprintInterfaces.lookup('BPI_Interactable')?.function('Interact'), isNotNull);
    final save = LuminaBlueprintSaveGameClasses.lookup('SG_Player');
    expect(save?.fields.map((f) => f.name), ['Score', 'Door']);
    expect(LuminaBlueprintMontages.lookup('AM_Wave')?.clip, 'Walk_Fwd_Loop');
    expect(LuminaBlueprintMontages.lookup(registryWavePath)?.notifies.single.name, 'Step');
    final sparks = LuminaBlueprintParticleTemplates.lookup(registrySparksPath);
    expect(sparks?.spawnRate, 40.0, reason: 'the first enabled emitter');
    expect(sparks?.lifetimeMax, 1.0);
    expect(LuminaBlueprintActorClasses.has('Actor:BP_Door'), isTrue);
    final door = LuminaBlueprintActorClasses.create('BP_Door');
    expect(door, isA<LuminaBlueprintRuntime>());
    expect((door as LuminaBlueprintRuntime).blueprintClassName, 'BP_Door');
  });

  test("Play-In-Editor's path: the scanned assets and the class registry fill the same registries from the .lmas files", () async {
    final project = Directory.systemTemp.createTempSync('lumina_bp13_pie_');
    addTearDown(() => project.deleteSync(recursive: true));
    await writeRegistryProjectAssets(project.path);
    _clearRegistries();
    final assets = LuminaProjectBlueprintAssets.scan(project.path);
    expect(assets.classes.map((c) => c.name), ['BP_Door']);
    assets.registerRuntime();
    final registry = LuminaBlueprintClassRegistry(project.path, inputActions: const []);
    expect(registry.registerActorClasses(assets.actorClasses), ['BP_Door']);
    expect(LuminaBlueprintEnums.lookup('E_DoorState')?.values, ['Closed', 'Opening', 'Open']);
    expect(LuminaBlueprintInterfaces.lookup('BPI_Interactable'), isNotNull);
    expect(LuminaBlueprintSaveGameClasses.lookup('SG_Player'), isNotNull);
    expect(LuminaBlueprintMontages.lookup('AM_Wave'), isNotNull);
    expect(LuminaBlueprintParticleTemplates.lookup(registrySparksPath)?.spawnRate, 40.0);
    final door = LuminaBlueprintActorClasses.create('Actor:BP_Door');
    expect(door, isA<LuminaBlueprintInstance>(), reason: 'the VM class, compiled from the .lmas');
    expect((door as LuminaBlueprintRuntime).blueprintClassName, 'BP_Door');
  });

  test('a project without Blueprint assets gets no registry, and main() does not call it', () {
    final project = Directory.systemTemp.createTempSync('lumina_bp13_empty_');
    addTearDown(() => project.deleteSync(recursive: true));
    Directory('${project.path}/contents/levels').createSync(recursive: true);
    // A stale registry from an earlier generation is removed.
    File('${project.path}/lib/blueprint_registry.g.dart')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('// stale');
    expect(generator.writeProjectBlueprintRegistry(project.path), isFalse);
    expect(File('${project.path}/lib/blueprint_registry.g.dart').existsSync(), isFalse);

    final main = generator.generateMainDart(projectName: 'plain_game');
    expect(main, isNot(contains('blueprint_registry.g.dart')));
    expect(main, isNot(contains('registerProjectBlueprints')));
    // Open Level / Quit Game reach the host in every game.
    expect(main, contains('LuminaGame.onQuitRequested = '));
    expect(main, contains('LuminaGame.onOpenLevelRequested = '));

    final withRegistry = generator.generateMainDart(projectName: 'bp_game', blueprintRegistry: true, levelNames: ['L_Arena']);
    expect(withRegistry, contains("import 'blueprint_registry.g.dart';"));
    expect(withRegistry.indexOf('registerProjectBlueprints();'), lessThan(withRegistry.indexOf('runApp(')));
    expect(withRegistry, contains("'L_Arena': () => LArena(),"));
    expect(withRegistry, contains("import 'levels/l_arena.dart';"));
    expect(withRegistry, contains('LuminaSaveGameSubsystem.platformSaveDirectory('));
  });

  test('spawn_decal_at_location yields a "not supported" validator warning naming the node', () {
    final doc = LuminaBlueprintDocument();
    final context = LuminaBlueprintTypeContext.forDocument(doc, className: 'BP_Decals');
    doc.eventGraph.nodes.addAll([
      LuminaBlueprintNodeLibrary.place('event_beginplay', nodeId: 'begin', context: context),
      LuminaBlueprintNodeLibrary.place('spawn_decal_at_location', nodeId: 'decal', context: context),
    ]);
    doc.eventGraph.wires.add(const LuminaBlueprintWire(id: 'w', fromNodeId: 'begin', fromPinId: 'exec_out', toNodeId: 'decal', toPinId: 'exec_in'));
    final issues = validateBlueprint(doc, className: 'BP_Decals');
    final warning = issues.singleWhere((d) => d.nodeId == 'decal');
    expect(warning.isError, isFalse);
    expect(warning.message, contains('Spawn Decal at Location'));
    expect(warning.message, contains('not supported'));
    // It compiles and runs as a no-op in the VM.
    final cls = LuminaBlueprintClass.fromDocument(doc, name: 'BP_Decals');
    expect(cls.hasErrors, isFalse);
    final world = LuminaWorld();
    final actor = cls.instantiate();
    world.persistentLevel.registerActor(actor);
    world.beginPlay();
    world.tick(1 / 60);
  });

  test('platformSaveDirectory is the desktop app-support directory, null elsewhere', () {
    expect(LuminaSaveGameSubsystem.platformSaveDirectory('my_game', environment: {'HOME': '/home/u'}, operatingSystem: 'linux'),
        '/home/u/.local/share/my_game/SaveGames');
    expect(LuminaSaveGameSubsystem.platformSaveDirectory('my_game', environment: {'XDG_DATA_HOME': '/x'}, operatingSystem: 'linux'),
        '/x/my_game/SaveGames');
    expect(LuminaSaveGameSubsystem.platformSaveDirectory('my_game', environment: {'HOME': '/Users/u'}, operatingSystem: 'macos'),
        '/Users/u/Library/Application Support/my_game/SaveGames');
    expect(LuminaSaveGameSubsystem.platformSaveDirectory('my_game', environment: {'APPDATA': r'C:\Users\u\AppData\Roaming'}, operatingSystem: 'windows'),
        r'C:\Users\u\AppData\Roaming\my_game\SaveGames');
    expect(LuminaSaveGameSubsystem.platformSaveDirectory('my_game', environment: const {}, operatingSystem: 'android'), isNull);
    final previous = LuminaSaveGameSubsystem.defaultSaveDirectoryPath;
    addTearDown(() => LuminaSaveGameSubsystem.defaultSaveDirectoryPath = previous);
    LuminaSaveGameSubsystem.defaultSaveDirectoryPath = '/tmp/saves_here';
    expect(LuminaSaveGameSubsystem().saveDirectoryPath, '/tmp/saves_here');
  });

  test('a scaffolded Third Person project with the registry assets generates and analyzes clean', () async {
    final root = Directory.systemTemp.createTempSync('lumina_bp13_scaffold_');
    final configDir = Directory.systemTemp.createTempSync('lumina_bp13_scaffold_cfg_');
    addTearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
      if (configDir.existsSync()) configDir.deleteSync(recursive: true);
    });
    final repo = ProjectRepository(configDir: configDir, processRunner: realFilesystemRunner(offlinePubGet: true));
    const name = 'registry_game';
    final project = await repo.createProject(projectName: name, projectLocation: root.path, template: kThirdPersonTemplateId);
    final projectDir = '${root.path}/$name';
    // The scaffold's own Blueprints already need the registry.
    expect(File('$projectDir/lib/blueprint_registry.g.dart').readAsStringSync(), contains("'BP_ThirdPersonCharacter'"));
    expect(File('$projectDir/lib/main.dart').readAsStringSync(), contains('registerProjectBlueprints();'));

    await writeRegistryProjectAssets(projectDir);
    // A second level the first one can Open Level to.
    final levelFile = File('$projectDir/contents/levels/L_DefaultLevel.lmas');
    final actors = ((jsonDecode(levelFile.readAsStringSync()) as Map)['metadata']['actors'] as List)
        .map((a) => Map<String, dynamic>.from(a as Map))
        .toList();
    final use = GenerateDartCodeUseCase();
    expect((await use(projectDir: projectDir, levelName: 'L_Arena', actors: const [], project: project)).isSuccess, isTrue);
    final result = await use(projectDir: projectDir, levelName: 'L_DefaultLevel', actors: actors, project: project);
    expect(result.isSuccess, isTrue, reason: result.error);

    final lib = '$projectDir/lib';
    expect(File('$lib/enums/e_door_state.g.dart').existsSync(), isTrue);
    expect(File('$lib/interfaces/bpi_interactable.g.dart').existsSync(), isTrue);
    final registry = File('$lib/blueprint_registry.g.dart').readAsStringSync();
    expect(registry, contains("'BP_Door'"));
    expect(registry, contains("'BP_ThirdPersonCharacter'"));
    expect(registry, isNot(contains("'BP_ThirdPersonGameMode'")), reason: 'a GameMode is not spawnable');
    final main = File('$lib/main.dart').readAsStringSync();
    expect(main, contains("import 'blueprint_registry.g.dart';"));
    expect(main, contains('registerProjectBlueprints();'));
    expect(main, contains('LuminaGame.onOpenLevelRequested = '));
    expect(main, contains('LuminaGame.onQuitRequested = '));
    expect(main, contains("'L_Arena': () => LArena(),"));

    File('$projectDir/analysis_options.yaml').writeAsStringSync('');
    final analyze = await analyzeGeneratedProject(projectDir);
    expect(analyze.exitCode, 0, reason: '${analyze.stdout}\n${analyze.stderr}');
  }, timeout: const Timeout(Duration(minutes: 6)));
}
