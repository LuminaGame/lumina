import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart' show rootBundle;

import 'package:lumina/lumina_runtime.dart';
import 'package:lumina_widgets/src/media/video/lumina_video_controller.dart';
import 'package:lumina_widgets/src/utility/web_display_backend.dart';
import 'package:lumina_widgets/src/utility/window_mode_channel.dart';

/// Connects the engine to Flutter at start-up. The engine (`lumina`) holds no
/// Flutter UI, so the services it needs from the app are handed to it here:
/// - [LuminaPlatform.override]: Flutter's target platform (what
///   `Get Platform Name` reports);
/// - [LuminaAssets.bundleProvider]: the app's asset bundle (the procedural
///   sky's shader and textures ship in the lumina package);
/// - [LuminaVideoPlayback.factory]: media_kit video ([LuminaVideoController]),
///   what the Blueprint video nodes open;
/// - [LuminaGameWindow.backend]: the generated runner's window mode
///   ([LuminaWindowModeChannel], Windows and Linux), what `Set Fullscreen
///   Mode` drives;
/// - [LuminaGameDisplay.backend]: the monitors and the window size for the
///   screen resolution nodes (the same channel; on the web
///   [LuminaWebDisplayBackend], the browser's screen).
///
/// A generated game calls [ensureInitialized] in `main()`; the game widget
/// calls it too, so Play-In-Editor and tests that only mount a
/// `LuminaGameWidget` get the same services. Values a host already set are
/// kept.
abstract final class LuminaWidgets {
  static bool _initialized = false;

  /// Whether [ensureInitialized] ran.
  static bool get isInitialized => _initialized;

  /// Idempotent; call after `WidgetsFlutterBinding.ensureInitialized()`.
  static void ensureInitialized() {
    if (_initialized) return;
    _initialized = true;
    LuminaPlatform.override ??= platformOf(defaultTargetPlatform);
    LuminaAssets.bundleProvider ??= (key) async {
      final data = await rootBundle.load(key);
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    };
    LuminaVideoPlayback.factory ??= ({required String source, bool autoPlay = false, bool loop = false, double initialVolume = 1.0}) =>
        LuminaVideoController(source: source, autoPlay: autoPlay, loop: loop, initialVolume: initialVolume);
    if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.linux)) {
      // One channel object answers both (it owns the channel's handler).
      if (LuminaGameWindow.backend == null || LuminaGameDisplay.backend == null) {
        final existing = LuminaGameWindow.backend ?? LuminaGameDisplay.backend;
        final channel = existing is LuminaWindowModeChannel ? existing : LuminaWindowModeChannel();
        LuminaGameWindow.backend ??= channel;
        LuminaGameDisplay.backend ??= channel;
      }
    } else if (kIsWeb) {
      LuminaGameDisplay.backend ??= LuminaWebDisplayBackend();
    }
  }

  /// The engine's platform for Flutter's [platform].
  static LuminaPlatform platformOf(TargetPlatform platform) => switch (platform) {
        TargetPlatform.android => LuminaPlatform.android,
        TargetPlatform.fuchsia => LuminaPlatform.fuchsia,
        TargetPlatform.iOS => LuminaPlatform.iOS,
        TargetPlatform.linux => LuminaPlatform.linux,
        TargetPlatform.macOS => LuminaPlatform.macOS,
        TargetPlatform.windows => LuminaPlatform.windows,
      };
}
