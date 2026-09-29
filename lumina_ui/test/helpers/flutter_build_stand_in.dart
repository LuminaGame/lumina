import 'dart:convert';
import 'dart:io';

import 'package:lumina_ui/ui/features/sub_editors/services/build_pipeline_service.dart';

/// A real child process standing in for `flutter build <target>` (the full
/// build is exercised by the smoke tests). It prints a couple of lines and
/// writes what the real build leaves behind:
/// - `web`: `build/web` with an `index.html` and the compiled `main.dart.js`;
/// - `linux`: the release bundle `build/linux/x64/release/bundle` with the
///   executable (named after the project folder), `data/` and `lib/`.
/// Every spawn records its argv in `<recordDir>/argv.json`, and appends it
/// as one line to `<recordDir>/argv.log`.
BuildProcessStarter flutterBuildStandIn(Directory recordDir, {int exitCode = 0}) {
  final script = File('${recordDir.path}/flutter_build_stand_in.dart');
  script.writeAsStringSync(r'''
import 'dart:io';

Future<void> main(List<String> args) async {
  final exitCodeWanted = int.parse(args[0]);
  final target = args[1];
  stdout.writeln('Compiling lib/main.dart for $target...');
  if (exitCodeWanted == 0 && target == 'web') {
    final web = Directory('build/web')..createSync(recursive: true);
    File('${web.path}/index.html').writeAsStringSync('<!DOCTYPE html><html><head><base href="/"></head>'
        '<body><script src="flutter_bootstrap.js" async></script></body></html>');
    File('${web.path}/main.dart.js').writeAsStringSync('// dart2js output\n');
    stdout.writeln('✓ Built build/web');
  }
  if (exitCodeWanted == 0 && target == 'linux') {
    final name = Directory.current.uri.pathSegments.where((s) => s.isNotEmpty).last;
    final bundle = Directory('build/linux/x64/release/bundle')..createSync(recursive: true);
    Directory('${bundle.path}/data/flutter_assets').createSync(recursive: true);
    Directory('${bundle.path}/lib').createSync(recursive: true);
    File('${bundle.path}/data/icudtl.dat').writeAsStringSync('icu');
    File('${bundle.path}/lib/libapp.so').writeAsStringSync('aot');
    final exe = File('${bundle.path}/$name')..writeAsStringSync('#!/bin/sh\necho $name\n');
    if (!Platform.isWindows) Process.runSync('chmod', ['+x', exe.path]);
    // What CMake's install step copies next to icudtl.dat once the runner
    // resources and the install rule exist.
    final icon = File('linux/runner/resources/app_icon.png');
    final cmake = File('linux/CMakeLists.txt');
    if (icon.existsSync() && cmake.existsSync() && cmake.readAsStringSync().contains('runner/resources/app_icon.png')) {
      icon.copySync('${bundle.path}/data/app_icon.png');
    }
    stdout.writeln('✓ Built build/linux/x64/release/bundle/$name');
  }
  if (exitCodeWanted != 0) stderr.writeln('stand-in failing on purpose');
  exit(exitCodeWanted);
}
''');
  return (String exe, List<String> args, {String? workingDirectory}) {
    File('${recordDir.path}/argv.json').writeAsStringSync(jsonEncode([exe, ...args]));
    File('${recordDir.path}/argv.log').writeAsStringSync('${[exe, ...args].join(' ')}\n', mode: FileMode.append);
    return Process.start(_dartExecutable(), [script.path, '$exitCode', args[1]], workingDirectory: workingDirectory);
  };
}

/// What `flutter create` writes for the web platform, trimmed to the tags
/// that matter.
void writeFlutterWebPlatform(String projectDir) {
  Directory('$projectDir/web').createSync(recursive: true);
  File('$projectDir/web/index.html').writeAsStringSync('<!DOCTYPE html>\n<html>\n<head>\n  <base href="\$FLUTTER_BASE_HREF">\n'
      '  <meta charset="UTF-8">\n  <title>game</title>\n</head>\n<body>\n  <script src="flutter_bootstrap.js" async></script>\n</body>\n</html>\n');
}

String _dartExecutable() {
  // The SDK's own binary: on Windows `bin/dart` is `dart.bat`, which
  // Process.start cannot run without a shell.
  final sdkDart = Platform.isWindows ? 'bin/cache/dart-sdk/bin/dart.exe' : 'bin/dart';
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null && File('$root/$sdkDart').existsSync()) return '$root/$sdkDart';
  final exe = Platform.resolvedExecutable.replaceAll(r'\', '/');
  final idx = exe.indexOf('/bin/cache/');
  if (idx > 0) {
    final candidate = '${exe.substring(0, idx)}/$sdkDart';
    if (File(candidate).existsSync()) return candidate;
  }
  return 'dart';
}

/// A real child process standing in for a long `flutter
/// build` — it prints a line, then sleeps [sleep] so a test can cancel it.
/// Each spawn's pid is appended to `<recordDir>/pids.log`.
BuildProcessStarter sleepingFlutterBuildStandIn(Directory recordDir, {Duration sleep = const Duration(seconds: 30)}) {
  final script = File('${recordDir.path}/flutter_build_sleeper.dart');
  script.writeAsStringSync('''
import 'dart:io';

Future<void> main(List<String> args) async {
  stdout.writeln('Compiling lib/main.dart for \${args.isEmpty ? '?' : args.first} (sleeping)...');
  await Future<void>.delayed(const Duration(milliseconds: ${sleep.inMilliseconds}));
  exit(0);
}
''');
  return (String exe, List<String> args, {String? workingDirectory}) async {
    final process = await Process.start(_dartExecutable(), [script.path, args.length > 1 ? args[1] : ''], workingDirectory: workingDirectory);
    File('${recordDir.path}/pids.log').writeAsStringSync('${process.pid}\n', mode: FileMode.append);
    return process;
  };
}

/// The pids [sleepingFlutterBuildStandIn] started, oldest first.
List<int> standInPids(Directory recordDir) {
  final log = File('${recordDir.path}/pids.log');
  if (!log.existsSync()) return const [];
  return log.readAsLinesSync().where((l) => l.trim().isNotEmpty).map((l) => int.parse(l.trim())).toList();
}

/// Whether process [pid] still runs (tasklist on Windows, kill -0 elsewhere).
bool processAlive(int pid) {
  if (Platform.isWindows) {
    final out = Process.runSync('tasklist', ['/FI', 'PID eq $pid', '/NH']).stdout.toString();
    return RegExp(r'\b' '$pid' r'\b').hasMatch(out);
  }
  return Process.runSync('kill', ['-0', '$pid']).exitCode == 0;
}

/// A stand-in `flutter` for Play Standalone, as an executable
/// script in [dir]: `flutter build <host> --debug` prints a line and leaves a
/// "game" in the bundle folder `StandaloneGameRunner.bundleExecutable`
/// looks in — a real process that stays up until it is killed (Windows: a
/// copy of sort.exe, which reads its stdin until it closes; elsewhere a `sleep 60` script).
/// [binaryName] must match `BINARY_NAME` of the project's runner CMakeLists.
String standaloneFlutterStandIn(Directory dir, {required String binaryName}) {
  if (Platform.isWindows) {
    final bat = File('${dir.path}/flutter_standalone_stand_in.bat');
    const debug = r'build\windows\x64\runner\Debug';
    bat.writeAsStringSync([
      '@echo off',
      'echo Building Windows application (stand-in)...',
      'if not exist "$debug" mkdir "$debug"',
      r'copy /Y "%SystemRoot%\System32\sort.exe" ' '"$debug\\$binaryName.exe" >nul',
      'echo Built $debug\\$binaryName.exe',
      'exit /b 0',
      '',
    ].join('\r\n'));
    return bat.path;
  }
  final sh = File('${dir.path}/flutter_standalone_stand_in.sh');
  sh.writeAsStringSync([
    '#!/bin/sh',
    'echo "Building Linux application (stand-in)..."',
    'mkdir -p build/linux/x64/debug/bundle',
    "printf '#!/bin/sh\\necho game running\\nexec sleep 60\\n' > build/linux/x64/debug/bundle/$binaryName",
    'chmod +x build/linux/x64/debug/bundle/$binaryName',
    'echo "Built build/linux/x64/debug/bundle/$binaryName"',
    '',
  ].join('\n'));
  Process.runSync('chmod', ['+x', sh.path]);
  return sh.path;
}
