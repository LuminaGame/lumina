import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

void main() {
  late Directory tempDir;
  final logger = EngineLoggerService();

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('lumina_use_case_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  List<Map<String, dynamic>> sampleActors() => [
        {
          'id': 'act_1',
          'name': 'PlayerPawn',
          'type': 'Pawn',
          'location': [1.0, 2.0, 3.0],
          'rotation': [0.0, 0.0, 0.0],
          'scale': [1.0, 1.0, 1.0],
        },
        {
          'id': 'act_2',
          'name': 'Sun',
          'type': 'DirectionalLight',
          'location': [0.0, 10.0, 0.0],
        },
      ];

  group('SaveLevelUseCase', () {
    test('writes contents/levels/<name>.lmas with metadata.actors and returns the path', () async {
      final useCase = SaveLevelUseCase();
      final result = await useCase(
        projectDir: tempDir.path,
        levelName: 'L_Main',
        actors: sampleActors(),
      );

      expect(result.isSuccess, isTrue, reason: result.error);
      expect(result.levelName, 'L_Main');
      expect(result.actorCount, 2);
      expect(result.levelFilePath, '${tempDir.path}/contents/levels/L_Main.lmas');

      final file = File(result.levelFilePath!);
      expect(file.existsSync(), isTrue);
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      expect(json['assetId'], 'level_L_Main');
      expect(json['name'], 'L_Main');
      expect(json['type'], 'level');
      expect(json['relativePath'], 'contents/levels/L_Main.lmas');
      expect(json['rawPayload'], isNull);
      final actors = (json['metadata'] as Map<String, dynamic>)['actors'] as List;
      expect(actors, hasLength(2));
      expect((actors.first as Map)['name'], 'PlayerPawn');
      expect((actors.first as Map)['location'], [1.0, 2.0, 3.0]);
    });

    test('fails without writing on a missing project dir or an invalid level name', () async {
      final useCase = SaveLevelUseCase();
      final missing = '${tempDir.path}/does_not_exist';

      final r1 = await useCase(projectDir: missing, levelName: 'L_Main', actors: const []);
      expect(r1.isSuccess, isFalse);
      expect(r1.levelFilePath, isNull);
      expect(Directory(missing).existsSync(), isFalse);
      expect(logger.logs.last.level, 'error');
      expect(logger.logs.last.source, 'SaveLevel');

      for (final bad in ['', '../evil', 'a/b', r'a\b']) {
        final r = await useCase(projectDir: tempDir.path, levelName: bad, actors: const []);
        expect(r.isSuccess, isFalse, reason: 'levelName "$bad" must be rejected');
        expect(r.error, isNotNull);
      }
      expect(Directory('${tempDir.path}/contents').existsSync(), isFalse);
      expect(File('${tempDir.path}/evil.lmas').existsSync(), isFalse);
    });

    test('saving the same level twice overwrites the file', () async {
      final useCase = SaveLevelUseCase();
      await useCase(projectDir: tempDir.path, levelName: 'L_Main', actors: sampleActors());
      final second = await useCase(
        projectDir: tempDir.path,
        levelName: 'L_Main',
        actors: [sampleActors().first],
      );
      expect(second.isSuccess, isTrue);
      expect(second.actorCount, 1);

      final levelsDir = Directory('${tempDir.path}/contents/levels');
      expect(levelsDir.listSync().whereType<File>().length, 1);
      final json = jsonDecode(File(second.levelFilePath!).readAsStringSync()) as Map<String, dynamic>;
      expect(((json['metadata'] as Map)['actors'] as List), hasLength(1));
    });
  });

  group('GenerateDartCodeUseCase', () {
    test('writes lib/main.dart + lib/levels/<level>.dart and cleans the manifest', () async {
      final project = LuminaProject(
        projectName: 'codegen_game',
        isDirty: true,
        activeLevel: 'contents/levels/L_Main.lmas',
      );
      final useCase = GenerateDartCodeUseCase();
      final actors = [
        ...sampleActors(),
        {'id': 'f_1', 'name': 'Lights', 'type': 'Folder'},
      ];

      final result = await useCase(
        projectDir: tempDir.path,
        levelName: 'L_Main',
        actors: actors,
        project: project,
      );

      expect(result.isSuccess, isTrue, reason: result.error);
      expect(result.mainDartPath, '${tempDir.path}/lib/main.dart');
      expect(result.levelDartPath, '${tempDir.path}/lib/levels/l_main.dart');
      expect(result.writtenFiles, containsAll([result.mainDartPath, result.levelDartPath]));

      final main = File(result.mainDartPath!).readAsStringSync();
      expect(main, contains('runApp'));
      final level = File(result.levelDartPath!).readAsStringSync();
      expect(level, contains('class LMain'));
      // One typed runtime object per non-folder actor (pawns emit LuminaPawn, meshes/lights LuminaActor).
      expect('key: const LuminaObjectKey('.allMatches(level).length, 2 + 1 /* level script actor */); // the Folder row is skipped

      expect(result.updatedProject, isNotNull);
      expect(result.updatedProject!.isDirty, isFalse);
      expect(result.updatedProject!.lastCodeGeneratedTimestamp, isNotEmpty);

      final manifest = File('${tempDir.path}/codegen_game.lmproject');
      expect(manifest.existsSync(), isTrue);
      final map = jsonDecode(manifest.readAsStringSync()) as Map<String, dynamic>;
      expect(map['is_dirty'], isFalse);
      expect(map['last_code_generated_timestamp'], result.updatedProject!.lastCodeGeneratedTimestamp);
    });

    test('without a project only the Dart files are written', () async {
      final result = await GenerateDartCodeUseCase()(
        projectDir: tempDir.path,
        levelName: 'L_Main',
        actors: sampleActors(),
      );
      expect(result.isSuccess, isTrue, reason: result.error);
      expect(result.updatedProject, isNull);
      expect(File(result.mainDartPath!).existsSync(), isTrue);
      expect(File(result.levelDartPath!).existsSync(), isTrue);
      expect(tempDir.listSync().where((e) => e.path.endsWith('.lmproject')), isEmpty);
    });

    test('fails without writing on a missing project dir', () async {
      final missing = '${tempDir.path}/nope';
      final result = await GenerateDartCodeUseCase()(
        projectDir: missing,
        levelName: 'L_Main',
        actors: const [],
      );
      expect(result.isSuccess, isFalse);
      expect(result.writtenFiles, isEmpty);
      expect(Directory(missing).existsSync(), isFalse);
    });
  });

  group('ImportAssetUseCase', () {
    test('rejects a corrupt FBX and missing sources without writing assets', () async {
      final useCase = ImportAssetUseCase();
      final fbx = File('${tempDir.path}/model.fbx')..writeAsBytesSync([0, 1, 2]);

      final r1 = await useCase(projectDir: tempDir.path, sourceFilePath: fbx.path);
      expect(r1.isSuccess, isFalse);
      expect(r1.error, contains('FBX'));
      expect(r1.asset, isNull);
      expect(Directory('${tempDir.path}/contents').existsSync(), isFalse);

      final r2 = await useCase(projectDir: tempDir.path, sourceFilePath: '${tempDir.path}/missing.glb');
      expect(r2.isSuccess, isFalse);
      expect(r2.sourceFilePath, '${tempDir.path}/missing.glb');

      final r3 = await useCase(projectDir: '${tempDir.path}/nope', sourceFilePath: fbx.path);
      expect(r3.isSuccess, isFalse);
    });

    test('imports a real GLB into a real project through AssetRepository', () async {
      final glb = File('${Directory.current.parent.path}/test-assets/fixtures/attackhelicopter.entity.glb');
      if (!glb.existsSync()) {
        markTestSkipped('fixture attackhelicopter.entity.glb missing');
        return;
      }
      final projectRepo = ProjectRepository();
      await projectRepo
          .createProjectStream(projectName: 'import_uc_project', projectLocation: tempDir.path)
          .drain();
      final projectDir = '${tempDir.path}/import_uc_project';

      final result = await ImportAssetUseCase()(projectDir: projectDir, sourceFilePath: glb.path);
      expect(result.isSuccess, isTrue, reason: result.error);
      expect(result.asset, isNotNull);
      expect(result.asset!.fileName, 'attackhelicopter.entity.lmas');
      expect(File(result.asset!.lmasPath!).existsSync(), isTrue);
    });
  });
}
