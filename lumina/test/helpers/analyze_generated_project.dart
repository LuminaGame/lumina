import 'dart:io';

/// Runs `dart analyze --fatal-infos lib` in [projectDir] and returns its result.
///
/// The subprocess gets its own `HOME` holding a telemetry config with
/// `reporting=0`. Without it the analyzer tries to report to
/// `www.google-analytics.com`, and on a machine with no network it dies with an
/// unhandled `SocketException` and exit code 4 before printing its summary —
/// a failure that says nothing about the generated code and that no retry
/// fixes, because it happens on every run.
///
/// The temporary home is deleted afterwards and the developer's own telemetry
/// settings are never touched.
Future<ProcessResult> analyzeGeneratedProject(String projectDir) async {
  final home = Directory.systemTemp.createTempSync('lumina_analyze_home_');
  try {
    final dartTool = Directory('${home.path}/.dart-tool')..createSync(recursive: true);
    File('${dartTool.path}/dart-flutter-telemetry.config')
        .writeAsStringSync('reporting=0\n');

    return await Process.run(
      'dart',
      ['analyze', '--fatal-infos', 'lib'],
      workingDirectory: projectDir,
      runInShell: Platform.isWindows,
      environment: <String, String>{
        'HOME': home.path,
        'DART_SUPPRESS_ANALYTICS': 'true',
        'FLUTTER_SUPPRESS_ANALYTICS': 'true',
      },
    );
  } finally {
    if (home.existsSync()) {
      home.deleteSync(recursive: true);
    }
  }
}
