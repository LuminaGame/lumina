import 'dart:io';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:test/test.dart';

/// A packaged game carries the NGX runtime next to its executable (Lumina
/// Studio's Bundle NVIDIA DLSS runtime option copies `nvngx_dlss*.dll` /
/// `libnvidia-ngx-dlss*.so.*` there). This compiles a small host executable
/// that loads the native library built for these tests, puts it in a folder
/// shaped like a package and asks `filament_dlss_available`: without the
/// runtime files beside it the answer is false, with them it is true. The
/// host runs with that folder as its working directory and no
/// `LUMINA_DLSS_DIR`, so only the executable-folder lookup can find them.
///
/// Needs the fetched SDK, a native build with DLSS and an NVIDIA RTX GPU;
/// skips with the reason otherwise.
void main() {
  final package = Directory.current.path;
  final sep = Platform.pathSeparator;
  final libName = Platform.isWindows ? 'flutter_filament.dll' : 'libflutter_filament.so';
  final nativeLib = File('$package${sep}build${sep}native_assets$sep${Platform.isWindows ? 'windows' : 'linux'}$sep$libName');
  final runtimeDir = Directory(
      '$package${sep}build${sep}dlss-sdk${sep}lib$sep${Platform.isWindows ? 'Windows_x86_64' : 'Linux_x86_64'}${sep}rel');

  String? whyNot() {
    if (!Platform.isWindows && !Platform.isLinux) return 'DLSS runs on Windows and Linux only';
    if (!runtimeDir.existsSync()) return 'the DLSS SDK is not fetched (dart run tool/dlss/fetch_sdk.dart)';
    if (!nativeLib.existsSync()) return '${nativeLib.path} is not built yet (run any flutter test of this package first)';
    if (!Dlss.available) return 'DLSS is not available in this test process (no NVIDIA RTX GPU or a native build without DLSS)';
    if (_dartExecutable() == null) return 'no dart executable next to the Flutter SDK running this test';
    return null;
  }

  test('a packaged executable finds the runtime in its own folder, and only when it is there', () async {
    final skip = whyNot();
    if (skip != null) return markTestSkipped(skip);
    final temp = Directory.systemTemp.createTempSync('dlss_exe_');
    addTearDown(() => temp.deleteSync(recursive: true));
    final pkg = Directory('${temp.path}${sep}package')..createSync();
    final src = File('${temp.path}${sep}host.dart')..writeAsStringSync(_hostSource(libName));
    final exe = '${pkg.path}$sep${Platform.isWindows ? 'game.exe' : 'game'}';
    final compiled = await Process.run(_dartExecutable()!, ['compile', 'exe', src.path, '-o', exe]);
    expect(compiled.exitCode, 0, reason: '${compiled.stdout}\n${compiled.stderr}');
    nativeLib.copySync('${pkg.path}$sep$libName');

    // No LUMINA_DLSS_DIR, and a working directory without build/dlss-sdk.
    final env = Map<String, String>.of(Platform.environment)..remove('LUMINA_DLSS_DIR');
    Future<String> run() async {
      final r = await Process.run(exe, const [], workingDirectory: pkg.path, environment: env, includeParentEnvironment: false);
      expect(r.exitCode, 0, reason: '${r.stdout}\n${r.stderr}');
      return (r.stdout as String).trim();
    }

    expect(await run(), 'unavailable', reason: 'nothing beside the executable yet');

    // What the packaging step copies: the runtime libraries, flat, next to the executable.
    for (final f in runtimeDir.listSync().whereType<File>()) {
      f.copySync('${pkg.path}$sep${f.uri.pathSegments.last}');
    }
    expect(await run(), 'available');
  }, timeout: const Timeout(Duration(minutes: 3)));
}

/// The Dart SDK of the Flutter SDK running this test (`<flutter>/bin/cache/dart-sdk/bin/dart`).
String? _dartExecutable() {
  final name = Platform.isWindows ? 'dart.exe' : 'dart';
  final root = Platform.environment['FLUTTER_ROOT'];
  final candidates = <String>[
    if (root != null) '$root/bin/cache/dart-sdk/bin/$name',
  ];
  var dir = File(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 8; i++) {
    candidates.add('${dir.path}/dart-sdk/bin/$name');
    candidates.add('${dir.path}/cache/dart-sdk/bin/$name');
    candidates.add('${dir.path}/bin/cache/dart-sdk/bin/$name');
    if (dir.parent.path == dir.path) break;
    dir = dir.parent;
  }
  if (Platform.resolvedExecutable.endsWith(name)) candidates.insert(0, Platform.resolvedExecutable);
  for (final c in candidates) {
    if (File(c).existsSync()) return c;
  }
  return null;
}

/// A host that loads the native library from its own folder and prints
/// whether DLSS is available.
String _hostSource(String libName) => '''
import 'dart:ffi';
import 'dart:io';

void main() {
  final dir = File(Platform.resolvedExecutable).parent.path;
  final lib = DynamicLibrary.open('\$dir\${Platform.pathSeparator}$libName');
  final available = lib.lookupFunction<Bool Function(), bool Function()>('filament_dlss_available');
  stdout.writeln(available() ? 'available' : 'unavailable');
}
''';
