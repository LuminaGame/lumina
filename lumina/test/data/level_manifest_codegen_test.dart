import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/data/services/game_template_service.dart';
import 'package:lumina/lumina.dart';

import '../blueprint/level_load_blueprint.dart';
import '../blueprint/level_load_fixture.dart';
import '../helpers/analyze_generated_project.dart';
import 'project_template_test.dart' show realFilesystemRunner;

/// The built-game half: every generated level class carries
/// the asset manifest Load Level preloads, and the generated main() resolves
/// levels from those manifests and switches levels through Change Level.
void main() {
  final generator = DartCodeGeneratorService();

  test('a generated level lists what its actors load as a const assetManifest of bundle paths', () {
    final project = Directory.systemTemp.createTempSync('lvl_manifest_');
    addTearDown(() => project.deleteSync(recursive: true));
    writeLevelLoadProject(project.path);
    final code = generator.generateLevelDart(
        levelName: 'L_Second', actors: const [], actorMaps: levelSecondActors(), projectDir: project.path);
    expect(code, contains('  static const List<LuminaAssetRef> assetManifest = <LuminaAssetRef>['));
    for (final (path, kind) in [
      (acUnitPath, 'mesh'),
      (dentedBarrelPath, 'mesh'),
      (crateClassPath, 'blueprint'),
      (redBarrelPath, 'mesh'),
      (chimePath, 'sound'),
      (skyPath, 'texture'),
    ]) {
      expect(code, contains("    LuminaAssetRef('$path', LuminaAssetKind.$kind),"));
    }
    expect(RegExp('LuminaAssetRef\\(').allMatches(code).length, 6, reason: 'each asset once');

    // Absolute editor paths become bundle paths.
    final absolute = [
      for (final a in levelFirstActors()) {...a, if (a['meshAssetPath'] != null) 'meshAssetPath': '${project.path}/${a['meshAssetPath']}'},
    ];
    expect(LuminaLevelAssetManifest.fromActorMaps(absolute), const [LuminaAssetRef(redBarrelPath, LuminaAssetKind.mesh)]);
    // A level without assets has an empty manifest.
    final empty = generator.generateLevelDart(levelName: 'L_Empty', actors: const []);
    expect(empty, contains('static const List<LuminaAssetRef> assetManifest = <LuminaAssetRef>[];'));
  });

  test('the generated main resolves levels from their manifests and switches through Change Level', () {
    final main = generator.generateMainDart(projectName: 'loading_game', levelName: 'L_First', levelNames: const ['L_Second']);
    expect(main, contains("LuminaLevelPreloader.instance.manifestResolver = (levelName) => _projectLevelManifests[levelName];"));
    expect(main, contains("  'L_First': LFirst.assetManifest,"));
    expect(main, contains("  'L_Second': LSecond.assetManifest,"));
    expect(main, contains('LuminaGame.onChangeLevelRequested = _changeLevel;'));
    expect(main, contains('await LuminaLevelPreloader.instance.changeLevel(levelName, () async {'));
    expect(main, contains('LuminaGame.onOpenLevelRequested = (levelName, options) => scheduleMicrotask(() => _openLevel(levelName));'));
    expect(main, contains('LuminaGame.onChangeLevelRequested = null;'), reason: 'unhooked on dispose');
  });

  test('a scaffolded project with the level-loading Blueprint and two levels generates and analyzes clean', () async {
    final root = Directory.systemTemp.createTempSync('lvl_scaffold_');
    final configDir = Directory.systemTemp.createTempSync('lvl_scaffold_cfg_');
    addTearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
      if (configDir.existsSync()) configDir.deleteSync(recursive: true);
    });
    final repo = ProjectRepository(configDir: configDir, processRunner: realFilesystemRunner(offlinePubGet: true));
    const name = 'loading_game';
    final project = await repo.createProject(projectName: name, projectLocation: root.path, template: kThirdPersonTemplateId);
    final projectDir = '${root.path}/$name';
    writeLevelLoadProject(projectDir);
    // BP_LevelLoader placed in the first level, compiled into lib/actors.
    const loaderPath = 'contents/blueprints/BP_LevelLoader.lmas';
    File('$projectDir/$loaderPath').writeAsBytesSync(LuminaAsset(
      assetId: 'bp_BP_LevelLoader',
      name: 'BP_LevelLoader',
      type: AssetType.actor,
      rawPayload: utf8.encode(jsonEncode(levelLoadBlueprint().toJson())),
      metadata: {'parent_class': 'LuminaActor'},
    ).toProtoBufferBytes());
    expect(await generator.compileAndWriteActor(projectDir, 'BP_LevelLoader', levelLoadBlueprint().toJson(), assetPath: loaderPath), isTrue);
    expect(await generator.compileAndWriteActor(projectDir, 'BP_Crate', crateBlueprint().toJson(), assetPath: crateClassPath), isTrue);

    final use = GenerateDartCodeUseCase();
    final second = await use(projectDir: projectDir, levelName: 'L_Second', actors: levelSecondActors(), project: project);
    expect(second.isSuccess, isTrue, reason: second.error);
    final first = await use(projectDir: projectDir, levelName: 'L_First', actors: [
      ...levelFirstActors(),
      {'id': 'Loader', 'name': 'Loader', 'type': 'Blueprint', 'blueprintClass': loaderPath, 'location': [0.0, 0.0, 0.0]},
    ], project: project);
    expect(first.isSuccess, isTrue, reason: first.error);

    final lib = '$projectDir/lib';
    expect(File('$lib/levels/l_second.dart').readAsStringSync(), contains("LuminaAssetRef('$chimePath', LuminaAssetKind.sound),"));
    expect(File('$lib/actors/bp_level_loader.dart').readAsStringSync(), contains('LuminaBlueprintFunctionLibrary.loadLevel(this, '));
    final main = File('$lib/main.dart').readAsStringSync();
    expect(main, contains("  'L_Second': LSecond.assetManifest,"));

    File('$projectDir/analysis_options.yaml').writeAsStringSync('');
    final analyze = await analyzeGeneratedProject(projectDir);
    expect(analyze.exitCode, 0, reason: '${analyze.stdout}\n${analyze.stderr}');
  }, timeout: const Timeout(Duration(minutes: 6)));
}
