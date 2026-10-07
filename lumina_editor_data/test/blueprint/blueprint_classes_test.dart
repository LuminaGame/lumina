import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:vector_math/vector_math_64.dart';

import '../helpers/analyze_generated_project.dart';
import '../data/project_template_test.dart' show realFilesystemRunner;
import '../../../lumina/test/blueprint/third_person_blueprint.dart';

/// Blueprint classes as the default pawn (a GameMode Blueprint's
/// class defaults or the Maps & Modes override) and as placed level actors —
/// in the VM through [LuminaBlueprintClassRegistry] and in generated games
/// through `luminaBlueprintFactories`.
void main() {
  const pawnPath = 'contents/blueprints/BP_Hero.lmas';
  const otherPawnPath = 'contents/blueprints/BP_Other.lmas';
  const modePath = 'contents/blueprints/GM_Arena.lmas';
  const cratePath = 'contents/blueprints/BP_Crate.lmas';
  final actions = ProjectInputBinder.bind(GameTemplateCatalog.thirdPerson.input).actions.values.toList();

  LuminaBlueprintDocument gameMode(String pawn) => LuminaBlueprintDocument(
        parentClass: 'LuminaGameMode',
        classDefaults: {'defaultPawnClass': pawn, 'playerControllerClass': 'LuminaPlayerController'},
      );

  LuminaBlueprintDocument crate() => LuminaBlueprintDocument(
        parentClass: 'LuminaActor',
        components: [
          LuminaBlueprintComponent(id: 'root', name: 'DefaultSceneRoot', type: 'LuminaSceneComponent'),
        ],
      );

  void writeBlueprint(String projectDir, String path, LuminaBlueprintDocument doc) {
    final name = path.split('/').last.replaceAll('.lmas', '');
    final file = File('$projectDir/$path')..parent.createSync(recursive: true);
    file.writeAsBytesSync(LuminaAsset(
      assetId: name,
      name: name,
      type: AssetType.actor,
      rawPayload: utf8.encode(jsonEncode(doc.toJson())),
    ).toProtoBufferBytes());
  }

  Directory project() {
    final dir = Directory.systemTemp.createTempSync('lumina_bp_classes_');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/arena.lmproject').writeAsStringSync(jsonEncode(
        LuminaProject(projectName: 'arena', template: 'third_person', input: GameTemplateCatalog.thirdPerson.input).toMap()));
    writeBlueprint(dir.path, pawnPath, thirdPersonCharacterBlueprint(inputActions: actions));
    writeBlueprint(dir.path, otherPawnPath, thirdPersonCharacterBlueprint(inputActions: actions)..classDefaults['baseEyeHeight'] = 42.0);
    writeBlueprint(dir.path, modePath, gameMode(pawnPath));
    writeBlueprint(dir.path, cratePath, crate());
    return dir;
  }

  LuminaWorld arena() {
    final w = LuminaWorld(worldType: LuminaWorldType.game);
    w.registerSubsystem(LuminaCollisionSubsystem());
    w.registerSubsystem(LuminaInputSubsystem());
    w.persistentLevel.registerActor(
        LuminaPrimitiveActor(shape: LuminaPrimitiveShape.plane, size: Vector3(6000, 0, 6000), color: Vector3.all(0.5)));
    w.persistentLevel.registerActor(LuminaPlayerStart(location: Vector3(300, 100, -200)));
    return w;
  }

  group('manifest', () {
    test('Maps & Modes carries a default pawn class; an older manifest reads it as empty', () {
      const modes = ProjectMapsAndModes(defaultPawnClass: pawnPath, defaultGameMode: modePath);
      final back = ProjectMapsAndModes.fromMap(jsonDecode(jsonEncode(modes.toMap())) as Map<String, dynamic>);
      expect(back.defaultPawnClass, pawnPath);
      expect(back.defaultGameMode, modePath);
      expect(ProjectMapsAndModes.fromMap(const {'default_game_mode': 'LuminaGameMode'}).defaultPawnClass, '');
      expect(modes.copyWith(defaultPawnClass: '').defaultPawnClass, '');
    });
  });

  group('VM', () {
    test('a GameMode Blueprint spawns its Default Pawn Class at the PlayerStart, possessed by the player', () {
      final registry = LuminaBlueprintClassRegistry(project().path);
      final mode = registry.createGameMode(const ProjectMapsAndModes(defaultGameMode: modePath));
      expect(mode, isNotNull, reason: '${registry.diagnostics}');
      final w = arena()..gameMode = mode;
      w.beginPlay();
      final pc = mode!.login();
      final pawn = pc.pawn;
      expect(pawn, isA<LuminaBlueprintCharacter>());
      expect((pawn as LuminaBlueprintCharacter).blueprintClass.name, 'BP_Hero');
      expect(pawn.actorLocation, Vector3(300, 100, -200));
      expect(pawn.controller, same(pc));
    });

    test('the Maps & Modes Default Pawn Class overrides the game mode pawn', () {
      final registry = LuminaBlueprintClassRegistry(project().path);
      const modes = ProjectMapsAndModes(defaultGameMode: modePath, defaultPawnClass: otherPawnPath);
      final w = arena()..gameMode = registry.createGameMode(modes);
      w.beginPlay();
      final pawn = w.gameMode!.login().pawn as LuminaBlueprintCharacter;
      expect(pawn.blueprintClass.name, 'BP_Other');
      expect(pawn.baseEyeHeight, 42.0);
      // A Dart game mode keeps working: only the pawn factory comes from the registry.
      final factory = registry.resolvePawnFactory(const ProjectMapsAndModes(defaultPawnClass: otherPawnPath));
      expect(factory!(), isA<LuminaBlueprintCharacter>());
      expect(registry.resolvePawnFactory(const ProjectMapsAndModes()), isNull);
    });

    test('a GameMode Blueprint naming a missing or non-pawn class is a compile error', () {
      final dir = project();
      writeBlueprint(dir.path, 'contents/blueprints/GM_Broken.lmas', gameMode(cratePath));
      writeBlueprint(dir.path, 'contents/blueprints/GM_Missing.lmas', gameMode('contents/blueprints/BP_Nope.lmas'));
      final registry = LuminaBlueprintClassRegistry(dir.path);
      expect(registry.createGameMode(const ProjectMapsAndModes(defaultGameMode: 'contents/blueprints/GM_Broken.lmas')), isNull);
      expect(registry.diagnostics.map((d) => d.message), contains(contains("'$cratePath' is not a Pawn or Character")));
      expect(registry.createGameMode(const ProjectMapsAndModes(defaultGameMode: 'contents/blueprints/GM_Missing.lmas')), isNull);
      expect(registry.diagnostics.map((d) => d.message), contains(contains("'contents/blueprints/BP_Nope.lmas' cannot be loaded")));
    });

    test('the registry serves the cached class until the file changes, then reloads it', () async {
      final dir = project();
      final registry = LuminaBlueprintClassRegistry(dir.path);
      final first = registry.classFor(pawnPath);
      expect(first, isNotNull);
      expect(registry.classFor(pawnPath), same(first), reason: 'unchanged file: cached');
      final file = File('${dir.path}/$pawnPath');
      writeBlueprint(dir.path, pawnPath, thirdPersonCharacterBlueprint(inputActions: actions)..classDefaults['baseEyeHeight'] = 77.0);
      file.setLastModifiedSync(DateTime.now().add(const Duration(seconds: 5)));
      final second = registry.classFor(pawnPath);
      expect(second, isNot(same(first)));
      expect((second!.instantiate() as LuminaBlueprintCharacter).baseEyeHeight, 77.0);
    });

    test('a placed Blueprint actor resolves through the registry', () {
      final registry = LuminaBlueprintClassRegistry(project().path);
      final actor = registry.classFor(cratePath)!.instantiate(location: Vector3(1, 2, 3));
      expect(actor, isA<LuminaBlueprintActor>());
      expect(actor.actorLocation, Vector3(1, 2, 3));
    });

    test('a Blueprint mesh stored as a .lmas loads its .entity.glb companion', () {
      final actor = LuminaBlueprintClass.fromDocument(LuminaBlueprintDocument(components: [
        LuminaBlueprintComponent(
          id: 'mesh',
          name: 'Mesh',
          type: 'LuminaStaticMeshComponent',
          properties: {'staticMeshAsset': 'contents/meshes/SM_Box.lmas'},
        ),
      ])).instantiate();
      final mesh = (actor as LuminaBlueprintRuntime).blueprintComponents['mesh'] as LuminaStaticMeshComponent;
      expect(mesh.meshAssetPath, 'contents/meshes/SM_Box.entity.glb');
    });
  });

  group('generated game', () {
    final generator = DartCodeGeneratorService();

    test('a placed Blueprint emits its factory with the converted transform; main imports the factories', () {
      final level = generator.generateLevelDart(levelName: 'L_Arena', actors: const [], actorMaps: [
        {
          'id': 'crate_1',
          'name': 'BP_Crate',
          'type': 'Pawn',
          'blueprintClass': cratePath,
          'location': [100.0, 200.0, 50.0],
          'rotation': [0.0, 0.0, 90.0],
        },
      ]);
      expect(level, contains("import '../actors/actors.g.dart';"));
      expect(
          level,
          contains("luminaBlueprintFactories['$cratePath']!(key: const LuminaObjectKey('crate_1'), "
              'location: ${_vector3(LuminaAxes.location([100.0, 200.0, 50.0]))}, '
              'rotation: luminaAuthoringRotation(0.0000, 0.0000, 90.0000)),'));
      final main = generator.generateMainDart(
        projectName: 'arena',
        mapsAndModes: const ProjectMapsAndModes(defaultGameMode: modePath, defaultPawnClass: otherPawnPath),
        hasBlueprints: true,
      );
      expect(main, contains("import 'actors/actors.g.dart';"));
      expect(main, contains("luminaGameModeFactories['$modePath']!()"));
      expect(main, contains("luminaBlueprintFactories['$otherPawnPath']!() as LuminaPawn"));
    });

    test('compiling a GameMode Blueprint compiles its pawn and registers both by path', () async {
      final dir = project();
      final gm = LuminaAsset.fromBytes(File('${dir.path}/$modePath').readAsBytesSync());
      final doc = jsonDecode(utf8.decode(gm.rawPayload!)) as Map<String, dynamic>;
      expect(await generator.compileAndWriteActor(dir.path, 'GM_Arena', doc, assetPath: modePath), isTrue);
      final mode = File('${dir.path}/lib/actors/gm_arena.dart').readAsStringSync();
      expect(mode, contains('class GmArena extends LuminaGameMode'));
      expect(mode, contains('defaultPawnFactory: () => BpHero(),'));
      expect(mode, contains("import 'bp_hero.dart';"));
      expect(File('${dir.path}/lib/actors/bp_hero.dart').existsSync(), isTrue, reason: 'the pawn is compiled too');
      final registry = File('${dir.path}/lib/actors/actors.g.dart').readAsStringSync();
      expect(registry, contains("'$pawnPath': ({key, location, rotation}) => BpHero(key: key, location: location, rotation: rotation),"));
      expect(registry, contains("'$modePath': () => GmArena(),"));
      expect(registry, isNot(contains("'GmArena': () => GmArena()")), reason: 'a game mode is not an actor');
    });

    test('a scaffolded project with a Blueprint character, a GameMode Blueprint and a placed Blueprint analyzes clean', () async {
      final root = Directory.systemTemp.createTempSync('lumina_bp05_analyze_');
      final configDir = Directory.systemTemp.createTempSync('lumina_bp05_analyze_cfg_');
      addTearDown(() {
        if (root.existsSync()) root.deleteSync(recursive: true);
        if (configDir.existsSync()) configDir.deleteSync(recursive: true);
      });
      final repo = ProjectRepository(configDir: configDir, processRunner: realFilesystemRunner(offlinePubGet: true));
      await repo.createProject(projectName: 'bp_arena', projectLocation: root.path, template: kThirdPersonTemplateId);
      final dir = '${root.path}/bp_arena';
      File('$dir/analysis_options.yaml').writeAsStringSync('');
      writeBlueprint(dir, pawnPath, thirdPersonCharacterBlueprint(inputActions: actions));
      writeBlueprint(dir, modePath, gameMode(pawnPath));
      writeBlueprint(dir, cratePath, crate());
      Map<String, dynamic> payload(String path) =>
          jsonDecode(utf8.decode(LuminaAsset.fromBytes(File('$dir/$path').readAsBytesSync()).rawPayload!)) as Map<String, dynamic>;
      expect(await generator.compileAndWriteActor(dir, 'GM_Arena', payload(modePath), assetPath: modePath), isTrue);
      expect(await generator.compileAndWriteActor(dir, 'BP_Crate', payload(cratePath), assetPath: cratePath), isTrue);
      File('$dir/lib/levels/l_default_level.dart').writeAsStringSync(generator.generateLevelDart(
        levelName: 'L_DefaultLevel',
        actors: const [],
        actorMaps: [
          {'id': 'start', 'name': 'PlayerStart', 'type': 'PlayerStart', 'location': [0.0, 0.0, 100.0]},
          {
            'id': 'crate',
            'name': 'BP_Crate',
            'type': 'Pawn',
            'blueprintClass': cratePath,
            'location': [200.0, 0.0, 0.0],
            // A per-instance collision override compiles too.
            'components': [
              {
                'id': 'crate.collision.box',
                'type': 'LuminaBoxComponent',
                'name': 'Box',
                'properties': {
                  'blueprintComponentId': 'box',
                  'preset': 'overlapAll',
                  'responses': {'worldStatic': 'overlap', 'worldDynamic': 'overlap', 'pawn': 'overlap'},
                  'generateOverlapEvents': true,
                },
              },
            ],
          },
        ],
      ));
      File('$dir/lib/main.dart').writeAsStringSync(generator.generateMainDart(
        projectName: 'bp_arena',
        mapsAndModes: const ProjectMapsAndModes(defaultGameMode: modePath),
        hasBlueprints: true,
      ));
      final analyze = await analyzeGeneratedProject(dir);
      expect(analyze.exitCode, 0, reason: '${analyze.stdout}\n${analyze.stderr}');
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}

String _vector3(Vector3 v) {
  String f(double x) => (x == 0 ? 0.0 : x).toStringAsFixed(4);
  return 'Vector3(${f(v.x)}, ${f(v.y)}, ${f(v.z)})';
}
