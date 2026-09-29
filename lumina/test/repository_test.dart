import 'package:lumina/data/repositories/project_repository.dart';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

void main() {
  late Directory tempDir;
  late ProjectRepository projectRepo;
  late AssetRepository assetRepo;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('lumina_test_');
    projectRepo = ProjectRepository();
    assetRepo = AssetRepository();
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('Real ProjectRepository Tests', () {
    test('Should create project on disk with real contents/ structure and .lmproject manifest', () async {
      final stream = projectRepo.createProjectStream(
        projectName: 'test_game_project',
        projectLocation: tempDir.path,
      );
      await stream.drain();
      final lmpath = '${tempDir.path}/test_game_project/test_game_project.lmproject';
      final project = (await projectRepo.loadProject(lmpath))!;

      expect(project.projectName, equals('test_game_project'));
      expect(project.engineVersion, equals('0.0.1'));

      final projDir = Directory('${tempDir.path}/test_game_project');
      expect(projDir.existsSync(), isTrue);

      final lmprojectFile = File('${projDir.path}/test_game_project.lmproject');
      expect(lmprojectFile.existsSync(), isTrue);

      final contentsDir = Directory('${projDir.path}/contents');
      expect(contentsDir.existsSync(), isTrue);
      expect(Directory('${contentsDir.path}/meshes').existsSync(), isTrue);
      expect(Directory('${contentsDir.path}/levels').existsSync(), isTrue);

      final pubspecFile = File('${projDir.path}/pubspec.yaml');
      expect(pubspecFile.existsSync(), isTrue);
      expect(pubspecFile.readAsStringSync(), contains('contents/'));

      // The project's derived-data cache never reaches git.
      final gitignore = File('${projDir.path}/.gitignore').readAsLinesSync();
      expect(gitignore.where((l) => l.trim() == 'DerivedDataCache/'), hasLength(1));
      expect(gitignore, contains('/build/'), reason: "flutter create's own rules are kept");
    });

    test('Should load created project manifest from disk', () async {
      final stream = projectRepo.createProjectStream(
        projectName: 'load_test_game',
        projectLocation: tempDir.path,
      );
      await stream.drain();
      final lmpath = '${tempDir.path}/load_test_game/load_test_game.lmproject';
      final created = (await projectRepo.loadProject(lmpath))!;
      final loaded = await projectRepo.loadProject(lmpath);

      expect(loaded, isNotNull);
      expect(loaded!.projectName, equals('load_test_game'));
      expect(loaded.engineVersion, equals(created.engineVersion));
    });
  });

  group('Real AssetRepository Tests', () {
    test('Should scan real contents/ filesystem tree and return asset metadata', () async {
      final projectPath = '${tempDir.path}/asset_scan_test';
      final stream = projectRepo.createProjectStream(
        projectName: 'asset_scan_test',
        projectLocation: tempDir.path,
      );
      await stream.drain();

      await assetRepo.createAsset(
        projectPath: projectPath,
        subFolder: 'meshes',
        fileName: 'SM_Hero_Sword.lmas',
        type: AssetType.filamesh,
      );

      final assets = assetRepo.scanProjectContents(projectPath);
      expect(assets.isNotEmpty, isTrue);

      final swordAsset = assets.firstWhere((a) => a.fileName == 'SM_Hero_Sword.lmas');
      expect(swordAsset.type, equals(AssetType.filamesh));
      expect(swordAsset.bytes, greaterThan(0));
    });

    test('Should import FBX model successfully via assimp', () async {
      final fbxFile = File('${Directory.current.parent.path}/test-assets/fixtures/blackjack_blender2.FBX');
      if (fbxFile.existsSync()) {
        final projectPath = '${tempDir.path}/fbx_import_project';
        final stream = projectRepo.createProjectStream(
          projectName: 'fbx_import_project',
          projectLocation: tempDir.path,
        );
        await stream.drain();

        final result = await assetRepo.importExternalFile(
          projectPath: projectPath,
          sourceFilePath: fbxFile.path,
        );
        expect(result.fileName, equals('blackjack_blender2.lmas'));
        expect(result.thumbnailBytes, isNotNull);
      }
    });

    test('Should import GLB model, generate upright GLB and embedded PNG thumbnail', () async {
      final glbFile = File('${Directory.current.parent.path}/test-assets/fixtures/attackhelicopter.entity.glb');
      if (glbFile.existsSync()) {
        final projectPath = '${tempDir.path}/glb_import_project';
        final stream = projectRepo.createProjectStream(
          projectName: 'glb_import_project',
          projectLocation: tempDir.path,
        );
        await stream.drain();

        final result = await assetRepo.importExternalFile(
          projectPath: projectPath,
          sourceFilePath: glbFile.path,
        );
        expect(result.fileName, equals('attackhelicopter.entity.lmas'));
        expect(result.thumbnailBytes, isNotNull);

        final lmasFile = File('$projectPath/contents/meshes/static/attackhelicopter.entity.lmas');
        expect(lmasFile.existsSync(), isTrue);

        final lmasAsset = LuminaAsset.fromBytes(lmasFile.readAsBytesSync());
        expect(lmasAsset.rawPayload, isNotNull);
        expect(lmasAsset.rawPayload![0], equals(0x67)); // 'g'
        expect(lmasAsset.rawPayload![1], equals(0x6C)); // 'l'
        expect(lmasAsset.rawPayload![2], equals(0x54)); // 'T'
        expect(lmasAsset.rawPayload![3], equals(0x46)); // 'F'
      }
    });
  });

  group('Real EngineLoggerService Tests', () {
    test('Should log entry and emit to stream', () async {
      final logger = EngineLoggerService();
      logger.clear();

      late EngineLogEntry received;
      final sub = logger.logStream.listen((entry) => received = entry);

      logger.log('Engine subsystem initialized', level: 'info', source: 'Core');

      await Future.delayed(const Duration(milliseconds: 20));
      expect(received.message, equals('Engine subsystem initialized'));
      expect(logger.logs.length, equals(1));

      await sub.cancel();
    });
  });
}
