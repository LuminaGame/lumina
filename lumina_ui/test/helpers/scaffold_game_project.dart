import 'dart:io';

import 'package:lumina_core/lumina_core.dart';
import 'package:lumina/lumina.dart';

/// A [ProcessRunner] for [ProjectRepository] that writes what `flutter create`
/// needs for analysis (pubspec, lib/) and runs the real `flutter pub get
/// --offline`, so a scaffolded game resolves its real dependencies (lumina,
/// and shadcn_flutter when the project uses it) without the network.
ProcessRunner offlineScaffoldRunner() {
  return (String exec, List<String> args, {String? workingDirectory, bool runInShell = false}) async {
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
  vector_math: ^2.1.4

flutter:
  uses-material-design: true
''');
      File('$target/lib/main.dart').writeAsStringSync('void main() {}\n');
      return ProcessResult(0, 0, '', '');
    }
    if (args.isNotEmpty && args.first == 'pub') {
      return Process.run('flutter', ['pub', 'get', '--offline'], workingDirectory: workingDirectory, runInShell: Platform.isWindows);
    }
    return ProcessResult(0, 0, '', '');
  };
}

/// Scaffolds [template] as [name] under [root] with the UMG [widgetLibrary].
Future<String> scaffoldGameProject(Directory root, {required String name, required String widgetLibrary, String template = kThirdPersonTemplateId}) async {
  final config = Directory('${root.path}/.config')..createSync(recursive: true);
  await ProjectRepository(configDir: config, processRunner: offlineScaffoldRunner())
      .createProject(projectName: name, projectLocation: root.path, template: template, widgetLibrary: widgetLibrary);
  return '${root.path}/$name';
}

/// `dart analyze --fatal-infos lib` in [projectDir], with telemetry off.
Future<ProcessResult> analyzeGameProject(String projectDir) async {
  final home = Directory.systemTemp.createTempSync('lumina_ui_analyze_home_');
  try {
    Directory('${home.path}/.dart-tool').createSync(recursive: true);
    File('${home.path}/.dart-tool/dart-flutter-telemetry.config').writeAsStringSync('reporting=0\n');
    File('$projectDir/analysis_options.yaml').writeAsStringSync('');
    return await Process.run('dart', ['analyze', '--fatal-infos', 'lib'], workingDirectory: projectDir, runInShell: Platform.isWindows, environment: {
      'HOME': home.path,
      'DART_SUPPRESS_ANALYTICS': 'true',
      'FLUTTER_SUPPRESS_ANALYTICS': 'true',
    });
  } finally {
    home.deleteSync(recursive: true);
  }
}
