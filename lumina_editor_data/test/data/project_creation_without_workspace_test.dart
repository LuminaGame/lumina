import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:path/path.dart' as p;

/// An installed Lumina Studio with no engine checkout on the machine (no
/// workspace, no downloaded engine) still creates a Third Person project
/// that builds: the engine is a git dependency of the project, and the
/// template's character is read from the engine package the project's own
/// `pub get` resolved.
void main() {
  late Directory temp;
  late Directory noEngine;
  late Directory gitCheckout;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('lumina_no_ws_');
    noEngine = Directory(p.join(temp.path, 'no_engine'))..createSync();
    // Where pub puts the engine's git checkout (the pub cache): the lumina
    // package with its committed template content.
    gitCheckout = Directory(p.join(temp.path, 'pub_cache', 'git', 'lumina-0123abcd', 'lumina'))..createSync(recursive: true);
    final bundle = File(p.join(LuminaWorkspace.package('lumina'), LuminaThirdPersonContent.bundledMeshPath));
    final copy = File(p.join(gitCheckout.path, LuminaThirdPersonContent.bundledMeshPath))..parent.createSync(recursive: true);
    bundle.copySync(copy.path);
    File(p.join(gitCheckout.path, 'pubspec.yaml')).writeAsStringSync('name: lumina\n');
  });
  tearDown(() {
    for (var i = 0; i < 20; i++) {
      try {
        if (temp.existsSync()) temp.deleteSync(recursive: true);
        return;
      } on FileSystemException {
        sleep(const Duration(milliseconds: 100));
      }
    }
  });

  /// `flutter create` writes a minimal app; `flutter pub get` resolves the
  /// pubspec's git dependency into [gitCheckout] and records it in the
  /// project's package config, as pub does.
  ProcessRunner runner(List<String> log) => (String exec, List<String> args, {String? workingDirectory, bool runInShell = false}) async {
        log.add('$exec ${args.join(' ')}');
        if (args.isNotEmpty && args.first == 'create') {
          final target = args.last;
          final name = args[args.indexOf('--project-name') + 1];
          Directory('$target/lib').createSync(recursive: true);
          File('$target/pubspec.yaml').writeAsStringSync('''
name: $name
publish_to: 'none'
version: 0.1.0

environment:
  sdk: ^3.12.0

dependencies:
  flutter:
    sdk: flutter

flutter:
  uses-material-design: true
''');
          File('$target/lib/main.dart').writeAsStringSync('void main() {}\n');
        } else if (args.isNotEmpty && args.first == 'pub') {
          final pubspec = File('$workingDirectory/pubspec.yaml').readAsStringSync();
          if (!pubspec.contains('git:')) return ProcessResult(0, 1, '', 'lumina: no such path');
          File('$workingDirectory/.dart_tool/package_config.json')
            ..parent.createSync(recursive: true)
            ..writeAsStringSync(jsonEncode({
              'configVersion': 2,
              'packages': [
                {'name': 'lumina', 'rootUri': Uri.directory(gitCheckout.path).toString(), 'packageUri': 'lib/'},
              ],
            }));
        }
        return ProcessResult(0, 0, '', '');
      };

  test('a Third Person project is created against the git engine, its character read from the resolved engine package',
      () async {
    final log = <String>[];
    final repo = ProjectRepository(
      configDir: Directory(p.join(temp.path, 'config'))..createSync(),
      processRunner: runner(log),
      enginePackageDir: noEngine.path,
    );
    await repo.createProject(projectName: 'tp_installed', projectLocation: temp.path, template: kThirdPersonTemplateId);
    final dir = p.join(temp.path, 'tp_installed');

    final pubspec = File(p.join(dir, 'pubspec.yaml')).readAsStringSync();
    expect(pubspec, contains('git:'), reason: 'the engine is a committable git dependency');
    expect(pubspec, isNot(contains(noEngine.path.replaceAll(r'\', '/'))));
    expect(File(p.join(dir, ProjectEngineLink.overridesFileName)).existsSync(), isFalse,
        reason: 'no local engine to link to');
    expect(log, contains('flutter pub get'));

    final glb = File(p.join(dir, LuminaThirdPersonContent.projectMeshGlbPath));
    expect(glb.existsSync(), isTrue, reason: 'the template character comes from the resolved engine package');
    expect(glb.lengthSync(), greaterThan(1000000));
    expect(File(p.join(dir, LuminaThirdPersonContent.projectMeshAssetPath)).existsSync(), isTrue);
  });
}
