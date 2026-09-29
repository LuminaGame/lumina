import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/data/repositories/project_repository.dart';

void main() {
  group('ProjectRepository.ensurePubspecAssets', () {
    late Directory tempProject;

    setUp(() {
      tempProject = Directory.systemTemp.createTempSync('lumina_ensure_assets_');
      final pubspec = File('${tempProject.path}/pubspec.yaml');
      pubspec.writeAsStringSync('''
name: test_project
description: Test
publish_to: 'none'
version: 1.0.0

environment:
  sdk: ^3.13.0

dependencies:
  flutter:
    sdk: flutter

flutter:
  assets:
    - contents/
    - contents/meshes/static/
''');
    });

    tearDown(() {
      if (tempProject.existsSync()) {
        tempProject.deleteSync(recursive: true);
      }
    });

    test('adds missing standard directories including landscapes, blueprints, widgets', () {
      ProjectRepository.ensurePubspecAssets(tempProject.path);

      final content = File('${tempProject.path}/pubspec.yaml').readAsStringSync();
      expect(content, contains('- contents/landscapes/'));
      expect(content, contains('- contents/blueprints/'));
      expect(content, contains('- contents/widgets/'));
      expect(content, contains('- contents/meshes/static/'));
      expect(content, contains('- contents/levels/'));
    });

    test('scans and adds custom subdirectories while ignoring .thumbnails', () {
      final contentsDir = Directory('${tempProject.path}/contents');
      Directory('${contentsDir.path}/materials/reception').createSync(recursive: true);
      Directory('${contentsDir.path}/animations/SKM_Quinn').createSync(recursive: true);
      Directory('${contentsDir.path}/materials/.thumbnails').createSync(recursive: true);

      ProjectRepository.ensurePubspecAssets(tempProject.path);

      final content = File('${tempProject.path}/pubspec.yaml').readAsStringSync();
      expect(content, contains('- contents/materials/reception/'));
      expect(content, contains('- contents/animations/SKM_Quinn/'));
      expect(content, isNot(contains('.thumbnails')));
    });

    test('is idempotent when run multiple times', () {
      ProjectRepository.ensurePubspecAssets(tempProject.path);
      final firstRun = File('${tempProject.path}/pubspec.yaml').readAsStringSync();

      ProjectRepository.ensurePubspecAssets(tempProject.path);
      final secondRun = File('${tempProject.path}/pubspec.yaml').readAsStringSync();

      expect(secondRun, equals(firstRun));
    });

    test('patches real user project my_lumina_game213 if present on disk', () {
      const userProjectPath = '/home/dev/Lumina Projects/my_game';
      if (Directory(userProjectPath).existsSync()) {
        ProjectRepository.ensurePubspecAssets(userProjectPath);
        final content = File('$userProjectPath/pubspec.yaml').readAsStringSync();
        expect(content, contains('- contents/landscapes/'));
        expect(content, contains('- contents/blueprints/'));
        expect(content, contains('- contents/widgets/'));
      }
    });
  });
}
