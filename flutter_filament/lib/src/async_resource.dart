import 'dart:async';

import 'package:flutter_filament/src/callback_bridge.dart';
import 'package:flutter_filament/src/ffi_platform.dart' as ffi;
import 'package:flutter_filament/src/filament_bindings.dart' as c;

/// The callback bridge kind of every asynchronous resource completion.
const int asyncResourceCallbackKind = 2;

/// The id a call that ran synchronously (no asynchronous mode) reports; it
/// cannot be cancelled.
const int asyncCallSync = 0xFFFFFFFF;

/// How an asynchronous creation or upload ended.
enum FilamentAsyncStatus {
  /// The operation ran to completion.
  completed(0),

  /// The operation never ran: it was cancelled, or dropped because the engine
  /// is shutting down. The resource (or the upload) must not be relied on.
  canceled(1);

  const FilamentAsyncStatus(this.value);
  final int value;

  static FilamentAsyncStatus fromValue(int v) => v == 0 ? completed : canceled;
}

/// One asynchronous creation or upload in flight: its Filament call id, the
/// future of its outcome and a way to cancel it.
///
/// Completion arrives through the callback bridge as the engine runs: on
/// Vulkan the asynchronous work is amortized, a few jobs per rendered frame
/// (`Renderer.beginFrame` / `endFrame` tick the driver), so [done] resolves
/// only while frames are rendered; with a worker thread (Metal) a flush and
/// `pumpMessageQueues` suffice. Without an asynchronous mode the call ran
/// synchronously and [done] is already complete.
class FilamentAsyncUpload {
  FilamentAsyncUpload._(this._engine, this._requestId, this._result);

  /// Registers a bridge request and runs [start] with its request id. [start]
  /// returns the Filament call id (or [asyncCallSync]).
  factory FilamentAsyncUpload.start(
    FilamentEngineHandle engine,
    int Function(int requestId) start,
  ) {
    final (requestId, future) = CallbackBridge.instance.register(kind: asyncResourceCallbackKind);
    final upload = FilamentAsyncUpload._(engine, requestId, future);
    upload._callId = start(requestId);
    return upload;
  }

  final FilamentEngineHandle _engine;
  final int _requestId;
  final Future<CallbackResult> _result;
  int _callId = asyncCallSync;

  /// Filament's id of this call; [asyncCallSync] when it ran synchronously.
  int get id => _callId;

  /// The bridge request id (for diagnostics).
  int get requestId => _requestId;

  /// Whether this call was queued asynchronously (and can be cancelled).
  bool get isAsync => _callId != asyncCallSync;

  /// The outcome, once the engine reports it.
  Future<FilamentAsyncStatus> get done => _result.then((r) => FilamentAsyncStatus.fromValue(r.status));

  /// Cancels the call if it has not run yet. Returns whether Filament
  /// accepted the cancellation; [done] then resolves to
  /// [FilamentAsyncStatus.canceled].
  bool cancel() {
    if (!isAsync) return false;
    return c.filament_engine_cancel_async_call(_engine.nativePointer, _callId);
  }

  /// A future that completes with every upload's status once all of them
  /// ended, in order: the pattern that adds a renderable only when its
  /// buffers and textures are on the GPU.
  static Future<List<FilamentAsyncStatus>> group(Iterable<FilamentAsyncUpload> uploads) =>
      Future.wait(uploads.map((u) => u.done));

  /// Like [group], but true only when every upload completed (none cancelled).
  static Future<bool> allCompleted(Iterable<FilamentAsyncUpload> uploads) async =>
      (await group(uploads)).every((s) => s == FilamentAsyncStatus.completed);
}

/// The one engine property the upload needs: its native pointer. Implemented
/// by `FilamentEngine`; kept as an interface so this file does not import the
/// engine (which imports the resources that import this).
abstract interface class FilamentEngineHandle {
  ffi.Pointer<ffi.Void> get nativePointer;
}
