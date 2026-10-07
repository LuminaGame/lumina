/// Test support of Lumina Studio: the shared smoke-test system
/// (`package:lumina_smoke/flutter.dart`: the smoke-video rules and probe,
/// `SmokeRecorder`, `SmokeCapture`) and Studio's `SmokeArtifacts`
/// (lumina_smoke's plus the widget and integration-test captures).
library;

export 'package:lumina_smoke/flutter.dart' hide SmokeArtifacts;

export 'package:lumina_ui/testing/smoke_artifacts.dart';
