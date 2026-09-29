import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/data/services/lumina_config_dir.dart';

/// Wraps every test file under test/: the editor's config directory
/// (recent projects, launcher and quality settings) is a fresh temp directory
/// for the file's whole run, so no test reads or writes the user's own
/// `~/.config/lumina`. Tests that exercise those files still pass their own
/// `configDir`.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final configDir = Directory.systemTemp.createTempSync('lumina_test_config_');
  LuminaConfigDir.override = configDir;
  tearDownAll(() {
    try {
      configDir.deleteSync(recursive: true);
    } on FileSystemException catch (_) {}
  });
  await testMain();
}
