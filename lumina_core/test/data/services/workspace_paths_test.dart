import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/data/services/workspace_paths.dart';
import 'package:path/path.dart' as p;

void main() {
  group('LuminaWorkspace', () {
    late Directory temp;

    setUp(() => temp = Directory.systemTemp.createTempSync('lumina_workspace_'));
    tearDown(() => temp.deleteSync(recursive: true));

    test('findRootFrom walks up to the folder holding lumina/pubspec.yaml', () {
      File(p.join(temp.path, 'lumina', 'pubspec.yaml')).createSync(recursive: true);
      final deep = Directory(p.join(temp.path, 'lumina_ui', 'build', 'windows'))..createSync(recursive: true);

      expect(p.equals(LuminaWorkspace.findRootFrom(deep.path)!, temp.path), isTrue);
      expect(p.equals(LuminaWorkspace.findRootFrom(temp.path)!, temp.path), isTrue);
    });

    test('findRootFrom returns null outside any workspace', () {
      expect(LuminaWorkspace.findRootFrom(temp.path), isNull);
    });

    test('root resolves to this real workspace when run from a package', () {
      // flutter test runs with the package as the working directory.
      final root = LuminaWorkspace.root;
      expect(File(p.join(root, 'lumina', 'pubspec.yaml')).existsSync(), isTrue);
      expect(p.equals(LuminaWorkspace.package('lumina'), p.join(root, 'lumina')), isTrue);
      expect(p.equals(LuminaWorkspace.testAssets, p.join(root, 'test-assets')), isTrue);
    });

    test('packageIn prefers <root>/<name>, then the resolved package config', () {
      final other = Directory(p.join(temp.path, 'elsewhere', 'flutter_assimp'))..createSync(recursive: true);
      final dartTool = Directory(p.join(temp.path, 'ws', '.dart_tool'))..createSync(recursive: true);
      File(p.join(temp.path, 'ws', 'lumina', 'pubspec.yaml')).createSync(recursive: true);
      File(p.join(dartTool.path, 'package_config.json')).writeAsStringSync('''
{"configVersion": 2, "packages": [
  {"name": "flutter_assimp", "rootUri": "../../elsewhere/flutter_assimp", "packageUri": "lib/"},
  {"name": "gitdep", "rootUri": "${Uri.directory(other.path)}", "packageUri": "lib/"}
]}''');
      final ws = p.join(temp.path, 'ws');

      expect(p.equals(LuminaWorkspace.packageIn(ws, 'lumina'), p.join(ws, 'lumina')), isTrue);
      expect(p.equals(LuminaWorkspace.packageIn(ws, 'flutter_assimp'), other.path), isTrue);
      expect(p.equals(LuminaWorkspace.resolvedPackageDir(ws, 'gitdep')!, other.path), isTrue);
      expect(LuminaWorkspace.resolvedPackageDir(ws, 'missing'), isNull);
      expect(p.equals(LuminaWorkspace.packageIn(ws, 'missing'), p.join(ws, 'missing')), isTrue);
    });

    test('the real workspace finds the tools packages through its package config', () {
      final riglogic = LuminaWorkspace.package('flutter_riglogic');
      expect(File(p.join(riglogic, 'pubspec.yaml')).existsSync(), isTrue, reason: riglogic);
    });

    test('home is HOME or USERPROFILE', () {
      final expected = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
      if (expected != null) expect(LuminaWorkspace.home, expected);
      expect(Directory(LuminaWorkspace.home).existsSync(), isTrue);
    });
  });
}
