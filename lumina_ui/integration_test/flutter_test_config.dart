import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina_mouse_capture/lumina_mouse_capture.dart';

/// Wraps every integration test and smoke under integration_test/:
/// the editor's config directory (recent projects, launcher, quality and
/// plugin-wizard settings) is a fresh temp directory for the file's whole run,
/// so no flow reads or writes the user's own `~/.config/lumina`.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final configDir = Directory.systemTemp.createTempSync('lumina_ui_it_config_');
  LuminaConfigDir.override = configDir;
  // Play captures the mouse. No test may lock, grab or warp the
  // pointer of the person working at this machine, so every integration test
  // and smoke records capture requests instead.
  LuminaMouseCapture.backend = RecordingMouseCaptureBackend();
  tearDownAll(() {
    try {
      configDir.deleteSync(recursive: true);
    } on FileSystemException catch (_) {}
  });
  await testMain();
}
