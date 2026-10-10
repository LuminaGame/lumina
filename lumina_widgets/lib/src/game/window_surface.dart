import 'package:flutter/foundation.dart';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:lumina/lumina_runtime.dart';

import 'package:lumina_widgets/src/utility/window_mode_channel.dart';

/// The generated runner's presentation window as a [FilamentNativeSurface]:
/// what a game presenting directly renders into (`createSurface` /
/// `destroySurface` / `surfaceChanged` on the `lumina/game_window` channel).
///
/// On Windows it is a child window of the Flutter view, covering it, that
/// takes no input (disabled and transparent to hit tests): the Flutter view
/// under it keeps the pointer and the keyboard, and its frames are what
/// Filament shows. Without that runner (the editor, a runner generated
/// before, Linux for now) [acquire] returns null with the reason.
class LuminaWindowSurface implements FilamentNativeSurface {
  LuminaWindowSurface(this._channel);

  /// The surface over the game's window channel, or null when the window
  /// backend is not the runner's channel (tests, the editor).
  static LuminaWindowSurface? forGame() {
    final backend = LuminaGameWindow.backend;
    return backend is LuminaWindowModeChannel ? LuminaWindowSurface(backend) : null;
  }

  final LuminaWindowModeChannel _channel;
  final ValueNotifier<FilamentNativeSurfaceHandle?> _current = ValueNotifier(null);
  String? _reason;

  @override
  ValueListenable<FilamentNativeSurfaceHandle?> get current => _current;

  @override
  String? get unavailableReason => _reason;

  static FilamentNativeSurfaceHandle? _handleOf(Map<Object?, Object?> map) {
    final handle = map['handle'];
    final width = map['width'];
    final height = map['height'];
    if (handle is! int || width is! int || height is! int || handle == 0) return null;
    return FilamentNativeSurfaceHandle(handle: handle, width: width, height: height);
  }

  @override
  Future<FilamentNativeSurfaceHandle?> acquire() async {
    final (map, reason) = await _channel.createSurface();
    final handle = map == null ? null : _handleOf(map);
    if (handle == null) {
      _reason = reason ?? 'the runner returned no presentation window';
      return null;
    }
    _reason = null;
    _channel.onSurfaceChanged = (map) {
      final next = _handleOf(map);
      if (next != null) _current.value = next;
    };
    return _current.value = handle;
  }

  @override
  Future<void> release() async {
    _channel.onSurfaceChanged = null;
    _current.value = null;
    await _channel.destroySurface();
  }
}
