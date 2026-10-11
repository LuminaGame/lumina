import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:lumina_ui/ui/features/mcp_server/services/mcp_server_service.dart';

/// The Dart VM kernel plugins run on: the Dart SDK inside the Flutter SDK
/// Lumina already requires for project builds (`<flutter>/bin/cache/dart-sdk`).
abstract final class KernelDartSdk {
  /// Set by tests and tools to use another `dart` executable.
  static String? override;

  /// `<dart-sdk>/bin/dart(.exe)`: `FLUTTER_ROOT`'s SDK, else the Flutter SDK
  /// this editor's package config names, else the one beside the `flutter`
  /// on PATH, else the running `dart`; null when there is none.
  static String? dartExecutable() {
    if (override != null) return override;
    final known = McpServerService.dartExecutable;
    if (p.isAbsolute(known) && File(known).existsSync()) return known;
    final exe = Platform.isWindows ? 'dart.exe' : 'dart';
    for (final dir in (Platform.environment['PATH'] ?? '').split(Platform.isWindows ? ';' : ':')) {
      if (dir.isEmpty) continue;
      for (final flutter in Platform.isWindows ? const ['flutter.bat', 'flutter'] : const ['flutter']) {
        if (!File(p.join(dir, flutter)).existsSync()) continue;
        final dart = File(p.join(dir, 'cache', 'dart-sdk', 'bin', exe));
        if (dart.existsSync()) return dart.path;
      }
    }
    return null;
  }
}
