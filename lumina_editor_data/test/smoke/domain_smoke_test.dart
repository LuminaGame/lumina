import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina/testing.dart';

void main() {
  test('Domain Module Smoke Test: ImportAsset → SaveLevel → GenerateDartCode on a real project', () async {
    final tempDir = Directory.systemTemp.createTempSync('lumina_domain_smoke_');
    final assetsDir = SmokeArtifacts.testAssetsDir;
    const usedAssets = ['Props/Barrels/fuel_barrel_black.glb'];
    final glb = File('${assetsDir.path}/${usedAssets.first}');
    expect(glb.existsSync(), isTrue, reason: 'missing test asset ${glb.path}');

    try {
      // 1. Real project on disk (flutter create + contents/ tree + .lmproject).
      final projectRepo = ProjectRepository();
      await projectRepo
          .createProjectStream(projectName: 'domain_smoke_game', projectLocation: tempDir.path)
          .drain();
      final projectDir = '${tempDir.path}/domain_smoke_game';
      final project = await projectRepo.loadProject('$projectDir/domain_smoke_game.lmproject');
      expect(project, isNotNull);

      // 2. Import a real barrel through the use case.
      final imported = await ImportAssetUseCase()(projectDir: projectDir, sourceFilePath: glb.path);
      expect(imported.isSuccess, isTrue, reason: imported.error);
      final asset = imported.asset!;
      expect(File(asset.lmasPath!).existsSync(), isTrue);
      expect(asset.thumbnailBytes, isNotNull);

      // 3. Save a level whose actor references the imported mesh.
      final actors = <Map<String, dynamic>>[
        {
          'id': 'act_barrel',
          'name': 'FuelBarrel',
          'type': 'Mesh',
          'location': [0.0, 0.0, 0.0],
          'meshAssetPath': asset.relativePath,
        },
        {'id': 'act_sun', 'name': 'Sun', 'type': 'DirectionalLight', 'location': [0.0, 10.0, 0.0]},
      ];
      final saved = await SaveLevelUseCase()(projectDir: projectDir, levelName: 'L_Smoke', actors: actors);
      expect(saved.isSuccess, isTrue, reason: saved.error);
      expect(File(saved.levelFilePath!).existsSync(), isTrue);
      final levelJson = jsonDecode(File(saved.levelFilePath!).readAsStringSync()) as Map<String, dynamic>;
      expect(((levelJson['metadata'] as Map)['actors'] as List).first['meshAssetPath'], asset.relativePath);

      // 4. Generate the Dart code and clean the manifest.
      final generated = await GenerateDartCodeUseCase()(
        projectDir: projectDir,
        levelName: 'L_Smoke',
        actors: actors,
        project: project!.copyWith(isDirty: true, activeLevel: 'contents/levels/L_Smoke.lmas'),
      );
      expect(generated.isSuccess, isTrue, reason: generated.error);
      for (final path in generated.writtenFiles) {
        expect(File(path).existsSync(), isTrue, reason: '$path should exist');
      }
      expect(File(generated.levelDartPath!).readAsStringSync(), contains('class LSmoke'));
      final manifest = jsonDecode(File('$projectDir/domain_smoke_game.lmproject').readAsStringSync()) as Map<String, dynamic>;
      expect(manifest['is_dirty'], isFalse);
      expect(manifest['last_code_generated_timestamp'], isNotEmpty);

      // 5. Evidence: the imported asset's real embedded thumbnail.
      SmokeArtifacts.saveScreenshot(
        'domain_smoke_test: ImportAsset SaveLevel GenerateDartCode',
        asset.thumbnailBytes!,
        usedAssets: usedAssets,
      );
    } finally {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    }
  });
}
