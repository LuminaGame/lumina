// lumina's configuration of the shared smoke report (tool/smoke_report.dart)
// and its own smoke helpers. The runner, the report and the artifact API are
// tested in lumina_smoke.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/testing.dart';
import 'package:lumina_smoke/lumina_smoke.dart' as smoke;
import 'package:lumina_smoke/report.dart' show SmokeReportGenerator;

import '../../../tool/smoke_report.dart';

void main() {
  group('Tests are grouped by engine module', () {
    String cat(String path, [String name = '']) => luminaSmokeConfig.categoryOf('/home/x/lumina/$path', name);

    test('a test file lands in its module: folder first, then the file name, then the test name', () {
      expect(cat('test/smoke/world_partition_smoke_test.dart'), 'Landscape & World Partition');
      expect(cat('test/smoke/world_smoke_test.dart'), 'World');
      expect(cat('test/src/world/level_streaming_test.dart'), 'Level');
      expect(cat('test/src/world/data_layer_test.dart'), 'Landscape & World Partition');
      expect(cat('test/world/spawn_actor_registration_test.dart'), 'World',
          reason: 'the world folder decides when the name does not; "spawn" is not "pawn"');
      expect(cat('test/src/pawn_possession_test.dart'), 'Pawn & Player');
      expect(cat('test/smoke/char_movement_smoke_test.dart'), 'Character Movement');
      expect(cat('test/smoke/physics_smoke_test.dart'), 'Physics');
      expect(cat('test/src/physics/character_push_test.dart'), 'Physics');
      expect(cat('test/src/player_camera_manager_test.dart'), 'Game Framework');
      expect(cat('test/src/spring_arm_probe_test.dart'), 'Camera & Spring Arm');
      expect(cat('test/smoke/ai_smoke_test.dart'), 'AI & Navigation');
      expect(cat('test/smoke/post_process_smoke_test.dart'), 'Light, Environment & Post Process');
      expect(cat('test/data/imported_material_source_test.dart'), 'Data Layer & Codegen');
      expect(cat('test/blueprint/blueprint_vm_test.dart'), 'Blueprint');
      expect(cat('test/src/testing/smoke_report_test.dart'), 'Test Harness');
      expect(cat('test/smoke/00_test_report_smoke_test.dart'), 'Test Harness');
      expect(cat('test/misc/odd_one_test.dart', 'totally unrelated'), 'Other');
      expect(luminaSmokeConfig.categoryOf('', 'input modifiers: negate'), 'Input', reason: 'no file: the test name decides');
      expect(luminaSmokeConfig.categoryOrder('World'), lessThan(luminaSmokeConfig.categoryOrder('Blueprint')));
      expect(luminaSmokeConfig.categoryOrder('Other'), luminaTestCategories.categories.length);
    });

    test('Windows suite paths land in the same module', () {
      expect(luminaSmokeConfig.categoryOf(r'D:\w\lumina\test\src\world\level_streaming_test.dart', ''), 'Level');
      expect(luminaSmokeConfig.categoryOf(r'D:\w\lumina\test\blueprint\blueprint_vm_test.dart', ''), 'Blueprint');
      expect(luminaSmokeConfig.categoryOf(r'D:\w\lumina\test\world\spawn_actor_registration_test.dart', ''), 'World');
    });

    test('every test file of this package has a module', () {
      final files = Directory('test')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('_test.dart'))
          .map((f) => f.absolute.path)
          .toList();
      expect(files, isNotEmpty);
      final unplaced = [for (final f in files) if (luminaSmokeConfig.categoryOf(f, '') == 'Other') f];
      expect(unplaced, isEmpty, reason: 'add their module to luminaTestCategories in tool/smoke_report.dart');
    });

    test('a Scenario NN artifact goes to the Scenario NN test of the module both mention', () {
      final dir = Directory.systemTemp.createTempSync('lumina_scenario_match_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final png = SmokeArtifacts.encodePng(2, 2, Uint8List(16));
      SmokeArtifacts.saveScreenshotToDir('static mesh scenario 02: barrel lit', png, dir);
      SmokeArtifacts.saveScreenshotToDir('camera scenario 02: orbit', png, dir);
      final model = SmokeReportGenerator(luminaSmokeConfig).processEvents([
        {'type': 'suite', 'suite': {'id': 0, 'path': '/p/test/smoke/static_mesh_smoke_test.dart'}, 'time': 0},
        {'type': 'suite', 'suite': {'id': 1, 'path': '/p/test/smoke/camera_smoke_test.dart'}, 'time': 0},
        {'type': 'testStart', 'test': {'id': 1, 'name': 'Scenario 02: loads a mesh', 'suiteID': 0}, 'time': 0},
        {'type': 'testDone', 'testID': 1, 'result': 'success', 'time': 1},
        {'type': 'testStart', 'test': {'id': 2, 'name': 'Scenario 02: follows the pawn', 'suiteID': 1}, 'time': 0},
        {'type': 'testDone', 'testID': 2, 'result': 'success', 'time': 1},
      ], artifactsDir: dir);
      expect(model.orphanedArtifacts, isEmpty);
      String shotOf(String suite) => model.tests.firstWhere((t) => t.suite.contains(suite)).screenshots.single.fileName;
      expect(shotOf('static_mesh'), 'static_mesh_scenario_02_barrel_lit.png');
      expect(shotOf('camera'), 'camera_scenario_02_orbit.png');
    });
  });

  group("lumina's SmokeArtifacts", () {
    test('shares its state with lumina_smoke: one artifact directory, one set of recorded assets', () {
      final dir = Directory.systemTemp.createTempSync('lumina_smoke_facade_');
      addTearDown(() {
        SmokeArtifacts.overrideDirForTesting(null);
        SmokeArtifacts.resetRecordedAssets();
        dir.deleteSync(recursive: true);
      });
      SmokeArtifacts.overrideDirForTesting(dir);
      expect(smoke.SmokeArtifacts.dir.path, dir.path);
      SmokeArtifacts.recordAsset('Props/Barrels/empty_barrel.glb');
      expect(smoke.SmokeArtifacts.recordedAssets, ['Props/Barrels/empty_barrel.glb']);
      final file = SmokeArtifacts.saveScreenshot('facade: shot', SmokeArtifacts.encodePng(2, 2, Uint8List(16)));
      expect(file.parent.path, dir.path);
      expect(SmokeArtifacts.minimumVideoSeconds, SmokeVideo.minimumSeconds);
      expect(SmokeArtifacts.vp8QualitySettings, smoke.SmokeWebm.vp8QualitySettings);
    });

    test('renderRealAssetMedia refuses a missing test asset instead of filming an empty scene', () async {
      await expectLater(
        SmokeArtifacts.renderRealAssetMedia(testTitle: 'ghost prop', usedAssets: const ['Props/Nope/not_there.glb']),
        throwsA(isA<StateError>().having((e) => e.message, 'message', allOf(contains('ghost prop'), contains('Props/Nope/not_there.glb')))),
      );
    });

    test('renderRealAssetMedia refuses a duration under 10 s before it renders anything', () async {
      await expectLater(
        SmokeRender.renderRealAssetMedia(testTitle: 'six seconds', usedAssets: const [], durationSeconds: 6.0),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('six seconds'))),
      );
    });
  });
}
