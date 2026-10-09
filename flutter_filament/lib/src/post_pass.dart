import 'package:flutter_filament/src/ffi_platform.dart' as ffi;
import 'package:flutter_filament/src/ffi_package_platform.dart';

import 'package:flutter_filament/src/engine.dart';
import 'package:flutter_filament/src/filament_bindings.dart' as c;
import 'package:flutter_filament/src/view.dart';

/// What [DebugPostPass] draws.
enum DebugPostPassMode {
  /// The colour unchanged: the hook runs, the frame looks as without it.
  passthrough,

  /// The motion image: |x motion| in red, |y motion| in green, over the dimmed
  /// frame (sky pixels get a blue tint).
  motion,

  /// History validity: green where the previous position of the pixel was on
  /// screen, red where it was not (newly revealed areas, camera cuts).
  history,

  /// `max(0, 1 - colour)` on the HDR frame, before colour grading.
  invert;

  int toNative() => index;
}

/// A debug pass on Filament's external post-pass hook: a compute shader
/// recorded into the frame after TAA / FSR3 (or an HDR-stage external
/// upscaler) and before depth of field, bloom and colour grading. It shows
/// what a neural pass registered on that hook would receive: the HDR colour,
/// the motion at the colour's resolution and the history-valid flag.
///
/// Desktop Vulkan only; [DebugPostPass.create] throws a [StateError] on other
/// backends and on the web.
class DebugPostPass {
  DebugPostPass._(this.engine, this.view, this._ptr, this._mode);

  final FilamentEngine engine;
  final FilamentView view;
  ffi.Pointer<ffi.Void> _ptr;
  DebugPostPassMode _mode;

  /// The last error (process-wide), or null.
  static String? get lastErrorMessage {
    final ptr = c.filament_post_pass_last_error();
    if (ptr == ffi.nullptr) return null;
    return ptr.cast<Utf8>().toDartString();
  }

  /// Registers the pass on [view].
  factory DebugPostPass.create({
    required FilamentEngine engine,
    required FilamentView view,
    DebugPostPassMode mode = DebugPostPassMode.passthrough,
  }) {
    final ptr = c.filament_post_pass_debug_create(
      engine.nativePointer,
      view.nativePointer,
      mode.toNative(),
    );
    if (ptr == ffi.nullptr) {
      throw StateError(
        'External post pass: ${lastErrorMessage ?? 'not available'}',
      );
    }
    return DebugPostPass._(engine, view, ptr, mode);
  }

  bool get isDestroyed => _ptr == ffi.nullptr;

  void _checkDestroyed() {
    if (_ptr == ffi.nullptr)
      throw StateError('DebugPostPass has been destroyed');
  }

  DebugPostPassMode get mode => _mode;

  /// Takes effect at the next frame.
  set mode(DebugPostPassMode mode) {
    _checkDestroyed();
    _mode = mode;
    c.filament_post_pass_debug_set_mode(_ptr, mode.toNative());
  }

  /// Frames the pass evaluated (on the backend thread) so far.
  int get frameCount {
    _checkDestroyed();
    return c.filament_post_pass_debug_frame_count(_ptr);
  }

  /// The size of the colour image of the last evaluated frame ((0, 0) before
  /// the first).
  (int, int) get lastSize {
    _checkDestroyed();
    final out = calloc<ffi.Uint32>(2);
    try {
      c.filament_post_pass_debug_last_size(_ptr, out, out + 1);
      return (out[0], out[1]);
    } finally {
      calloc.free(out);
    }
  }

  /// Unregisters the pass and releases its Vulkan objects (waits for the GPU).
  /// A second call is a no-op.
  void destroy() {
    if (_ptr == ffi.nullptr) return;
    c.filament_post_pass_debug_destroy(_ptr);
    _ptr = ffi.nullptr;
  }
}

/// External post-pass history on a [FilamentView].
extension ExternalPostPassHistory on FilamentView {
  /// Forgets the motion history the external post pass sees: the next frame
  /// reports every pixel's history as unusable (camera cuts, teleports).
  void resetExternalPostPassHistory() =>
      c.filament_view_reset_external_post_pass_history(nativePointer);
}
