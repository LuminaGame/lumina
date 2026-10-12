import 'dart:io';

import 'package:lumina_core/lumina_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// An editor started from the folder that holds the repositories side by side
/// (`<dir>/lumina` is the lumina repository, whose root pubspec is the pub
/// workspace `lumina_workspace`, not the `lumina` package) must not take that
/// folder for the engine checkout: Play Standalone would rewrite the
/// project's `pubspec_overrides.yaml` to point `lumina` at the workspace root.
void main() {
  late Directory temp;
  late String repos; // the folder holding lumina/, tools/, plugins/ ...
  late String repo; // repos/lumina: the lumina repository (pub workspace)
  late String project;

  void write(String path, String text) => File(path)
    ..createSync(recursive: true)
    ..writeAsStringSync(text);

  const projectPubspec = '''
name: starting
publish_to: 'none'
environment:
  sdk: ^3.12.0
dependencies:
  flutter:
    sdk: flutter
  lumina:
    git:
      url: https://github.com/LuminaGame/lumina.git
      path: lumina
  lumina_widgets:
    git:
      url: https://github.com/LuminaGame/lumina.git
      path: lumina_widgets
''';

  late String overridesBefore;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('engine_link_repos_');
    repos = p.join(temp.path, 'repos');
    repo = p.join(repos, 'lumina');
    project = p.join(temp.path, 'Projects', 'starting');
    write(p.join(repo, 'pubspec.yaml'), 'name: lumina_workspace\npublish_to: none\nenvironment:\n  sdk: ^3.12.0\nworkspace:\n  - lumina\n  - lumina_widgets\n  - flutter_filament\n');
    for (final name in ['lumina', 'lumina_widgets', 'flutter_filament']) {
      write(p.join(repo, name, 'pubspec.yaml'), 'name: $name\nresolution: workspace\n');
    }
    write(p.join(project, 'pubspec.yaml'), projectPubspec);
    final slash = repo.replaceAll(r'\', '/');
    overridesBefore = '# Local development (gitignored): the engine checkout at\n'
        '# $slash\n'
        'dependency_overrides:\n'
        '  flutter_filament:\n'
        "    path: '$slash/flutter_filament'\n"
        '  lumina:\n'
        "    path: '$slash/lumina'\n"
        '  lumina_widgets:\n'
        "    path: '$slash/lumina_widgets'\n"
        '${ProjectEngineLink.pluginOverridesBegin}\n'
        '  my_plugin:\n'
        "    path: 'C:/plugins/my_plugin'\n"
        '${ProjectEngineLink.pluginOverridesEnd}\n';
    write(p.join(project, ProjectEngineLink.overridesFileName), overridesBefore);
  });

  tearDown(() => temp.deleteSync(recursive: true));

  test('the folder holding the repositories is not a workspace root; the repository is', () {
    expect(LuminaWorkspace.findRootFrom(repos), isNull,
        reason: 'repos/lumina/pubspec.yaml is the pub workspace, not the lumina package');
    final deep = Directory(p.join(repo, 'lumina_ui', 'build'))..createSync(recursive: true);
    expect(p.equals(LuminaWorkspace.findRootFrom(deep.path)!, repo), isTrue);
  });

  test('a workspace root is not taken for the lumina package', () {
    expect(ProjectEngineLink.localEngineRoot(luminaPackageDir: repo), isNull);
    expect(p.equals(ProjectEngineLink.localEngineRoot(luminaPackageDir: p.join(repo, 'lumina'))!, repo), isTrue);
  });

  test('linking with the repository folder as the lumina package keeps pubspec_overrides.yaml byte for byte', () {
    final result = ProjectEngineLink.apply(project, luminaPackageDir: repo);
    expect(result.isLocal, isFalse);
    expect(File(p.join(project, ProjectEngineLink.overridesFileName)).readAsStringSync(), overridesBefore);
  });

  test('every override names a folder whose pubspec declares that package', () {
    final packages = ProjectEngineLink.localPackages(repos);
    expect(packages, isNot(contains('lumina_workspace')));
    for (final MapEntry(key: name, value: dir) in packages.entries) {
      final declared = RegExp(r'^name:\s*(\S+)', multiLine: true).firstMatch(File(p.join(dir, 'pubspec.yaml')).readAsStringSync())?.group(1);
      expect(declared, name, reason: dir);
    }
  });
}
