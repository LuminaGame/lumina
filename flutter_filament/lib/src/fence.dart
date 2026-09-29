import 'dart:async';
import 'ffi_platform.dart' as ffi;

import 'package:flutter_filament/src/engine.dart';
import 'package:flutter_filament/src/filament_bindings.dart' as c;

/// Status return codes for [FilamentFence] wait operations.
enum FenceStatus {
  /// Unrecoverable backend error.
  error(-1),

  /// The GPU has reached the fence marker.
  conditionSatisfied(0),

  /// The wait timeout expired before the GPU reached the fence marker.
  timeoutExpired(1);

  final int value;
  const FenceStatus(this.value);

  static FenceStatus fromValue(int val) {
    switch (val) {
      case 0:
        return FenceStatus.conditionSatisfied;
      case 1:
        return FenceStatus.timeoutExpired;
      default:
        return FenceStatus.error;
    }
  }
}

/// Command stream flush behavior for [FilamentFence] wait operations.
enum FenceMode {
  /// Flushes the command stream before waiting (recommended default).
  flush(0),

  /// Does not flush the command stream before waiting.
  dontFlush(1);

  final int value;
  const FenceMode(this.value);
}

/// A GPU-CPU synchronization fence primitive.
///
/// Fences allow tracking when the GPU has executed rendering commands up to
/// a specific point in the command buffer.
class FilamentFence {
  ffi.Pointer<ffi.Void> _ptr;
  final FilamentEngine _engine;
  bool _disposed = false;

  /// Internal constructor.
  FilamentFence.internal(this._ptr, this._engine);

  /// Creates a new fence at the current point in the engine command stream.
  factory FilamentFence.create(FilamentEngine engine) {
    final ptr = c.filament_engine_create_fence(engine.nativePointer);
    if (ptr == ffi.nullptr) {
      throw StateError('Failed to create FilamentFence');
    }
    return FilamentFence.internal(ptr, engine);
  }

  /// Special timeout value representing infinite wait.
  static int get fenceWaitForEver => c.filament_fence_wait_for_ever();

  /// The raw native pointer to the Filament Fence.
  ffi.Pointer<ffi.Void> get nativePointer {
    _checkDisposed();
    return _ptr;
  }

  /// Blocks the calling thread until the fence signals or [timeout] expires.
  ///
  /// If [timeout] is null, waits indefinitely ([fenceWaitForEver]).
  /// [mode] defaults to [FenceMode.flush] to ensure commands are submitted.
  FenceStatus wait({
    FenceMode mode = FenceMode.flush,
    Duration? timeout,
  }) {
    _checkDisposed();
    final timeoutNs = timeout == null ? fenceWaitForEver : timeout.inMicroseconds * 1000;
    final res = c.filament_fence_wait(_ptr, mode.value, timeoutNs);
    return FenceStatus.fromValue(res);
  }

  /// Non-blocking probe querying whether the GPU has reached the fence marker.
  FenceStatus poll({FenceMode mode = FenceMode.flush}) {
    return wait(mode: mode, timeout: Duration.zero);
  }

  /// Asynchronously waits until the fence signals without blocking the Dart isolate.
  ///
  /// Polls the fence at [pollInterval] intervals.
  Future<FenceStatus> whenSignaled({
    Duration pollInterval = const Duration(milliseconds: 2),
    FenceMode mode = FenceMode.flush,
  }) async {
    _checkDisposed();
    while (!_disposed) {
      final status = poll(mode: mode);
      if (status == FenceStatus.conditionSatisfied || status == FenceStatus.error) {
        return status;
      }
      await Future.delayed(pollInterval);
    }
    throw StateError('FilamentFence was disposed while waiting for signal');
  }

  /// Waits on the fence and destroys it, freeing GPU/native resources.
  ///
  /// After calling this method, the fence becomes unusable.
  FenceStatus waitAndDestroy({FenceMode mode = FenceMode.flush}) {
    _checkDisposed();
    final res = c.filament_fence_wait_and_destroy(_ptr, mode.value);
    _ptr = ffi.nullptr;
    _disposed = true;
    return FenceStatus.fromValue(res);
  }

  /// Destroys this fence and releases its resources.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    c.filament_engine_destroy_fence(_engine.nativePointer, _ptr);
    _ptr = ffi.nullptr;
  }

  bool get isDisposed => _disposed;

  void _checkDisposed() {
    if (_disposed || _ptr == ffi.nullptr) {
      throw StateError('FilamentFence has been disposed or consumed');
    }
  }
}
