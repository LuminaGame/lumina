import 'package:media_kit/media_kit.dart';

/// Central initialization and lifecycle coordinator for Lumina media playback.
abstract final class LuminaMedia {
  static bool _initialized = false;
  static bool _nativeAvailable = false;

  /// Whether the underlying media_kit native libraries (such as libmpv)
  /// were successfully initialized and available in the current runtime environment.
  static bool get isNativeAvailable => _nativeAvailable;

  /// Ensures media_kit is initialized. Idempotent and safe to invoke multiple times.
  static void ensureInitialized() {
    if (_initialized) return;
    _initialized = true;
    try {
      MediaKit.ensureInitialized();
      _nativeAvailable = true;
    } catch (_) {
      _nativeAvailable = false;
    }
  }

  /// For testing: allows overriding the native availability flag.
  static void setNativeAvailableForTesting(bool available) {
    _nativeAvailable = available;
    _initialized = true;
  }
}
