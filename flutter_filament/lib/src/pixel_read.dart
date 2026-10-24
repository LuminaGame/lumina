import 'dart:async';

import 'package:flutter_filament/src/engine.dart';
import 'package:flutter_filament/src/ffi_platform.dart' as ffi;
import 'package:flutter_filament/src/filament_bindings.dart' as c;

/// Reads whose buffer the caller owns and awaits without blocking.
///
/// A read is done when Filament hands its buffer back (the read's callback),
/// not when the GPU is: on Vulkan a worker thread copies the pixels into the
/// buffer after the GPU fence, so a buffer read or freed once a later
/// [FilamentEngine.whenIdle] fence signals can still be written to.
abstract final class FilamentPixelReads {
  static int _nextToken = 1;
  static final Map<int, Completer<void>> _pending = {};

  /// One listener for every read, made in the root zone: it outlives the
  /// zone of whichever caller asked first.
  static ffi.NativeCallable<c.FilamentReadPixelsCallbackFunction>? _callable;

  /// After this long without the buffer coming back the engine waits for
  /// the GPU and its readbacks once ([FilamentEngine.flushAndWait]).
  static const Duration fallbackAfter = Duration(seconds: 5);

  /// The read's callback and its user data: pass both to the
  /// `filament_renderer_read_pixels*` call, then [wait] for the token.
  static (ffi.Pointer<ffi.NativeFunction<c.FilamentReadPixelsCallbackFunction>>, ffi.Pointer<ffi.Void>, int) begin() {
    final token = _nextToken++;
    _pending[token] = Completer<void>();
    final callable = _callable ??= Zone.root.run<ffi.NativeCallable<c.FilamentReadPixelsCallbackFunction>>(
      () => ffi.NativeCallable<c.FilamentReadPixelsCallbackFunction>.listener(_onRead),
    );
    return (callable.nativeFunction, ffi.Pointer<ffi.Void>.fromAddress(token), token);
  }

  static void _onRead(ffi.Pointer<ffi.Void> buffer, ffi.Pointer<ffi.Void> user) {
    _pending.remove(user.address)?.complete();
  }

  /// Completes once the read of [token] gave its buffer back. Filament runs
  /// the callbacks when its message queues are pumped, so this flushes and
  /// pumps [engine] until then. Past [fallbackAfter] (or when [engine] was
  /// disposed meanwhile) it waits for the GPU once instead.
  static Future<void> wait(FilamentEngine engine, int token) async {
    final done = _pending[token];
    if (done == null) return;
    final clock = Stopwatch()..start();
    while (!done.isCompleted) {
      if (engine.isDisposed) {
        _pending.remove(token);
        return;
      }
      if (clock.elapsed > fallbackAfter) {
        _pending.remove(token);
        engine.flushAndWait();
        engine.pumpMessageQueues();
        return;
      }
      engine.flush();
      engine.pumpMessageQueues();
      await Future.any([done.future, Future<void>.delayed(const Duration(milliseconds: 2))]);
    }
  }
}
