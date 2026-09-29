import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// The Dart SDK a project's packages were resolved with, in
/// the order `BlueprintFunctionScanner._sdkFor` (lumina) uses: the
/// `flutterRoot` in `.dart_tool/package_config.json`, else `FLUTTER_ROOT`,
/// else the running `dart`. A mirror of that private method; switch to it
/// when lumina exposes it.
abstract final class ProjectDartSdk {
  static File packageConfig(String projectDir) => File(p.join(projectDir, '.dart_tool', 'package_config.json'));

  /// The SDK directory (with `bin/dart`), or null when none is found.
  static String? resolve(String projectDir) {
    String? dartSdk(String? flutterRoot) {
      if (flutterRoot == null || flutterRoot.isEmpty) return null;
      final sdk = p.join(flutterRoot, 'bin', 'cache', 'dart-sdk');
      return Directory(sdk).existsSync() ? sdk : null;
    }

    final config = packageConfig(projectDir);
    if (config.existsSync()) {
      try {
        final json = jsonDecode(config.readAsStringSync());
        final root = json is Map ? json['flutterRoot'] : null;
        if (root is String) {
          final found = dartSdk(Uri.parse(root).toFilePath());
          if (found != null) return found;
        }
      } on FormatException {
        // Fall through to the environment.
      }
    }
    final fromEnv = dartSdk(Platform.environment['FLUTTER_ROOT']);
    if (fromEnv != null) return fromEnv;
    final exe = Platform.resolvedExecutable;
    if (p.basenameWithoutExtension(exe) == 'dart') {
      final sdk = p.dirname(p.dirname(exe));
      if (File(p.join(sdk, 'version')).existsSync()) return sdk;
    }
    return null;
  }

  /// `<sdk>/bin/dart` (`dart.exe` on Windows).
  static String dartExecutable(String sdk) => p.join(sdk, 'bin', Platform.isWindows ? 'dart.exe' : 'dart');
}
