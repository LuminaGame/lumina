/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

import 'dart:async';
import 'ffi_platform.dart' as ffi;
import 'dart:typed_data';

import 'package:flutter_filament/src/filament_bindings.dart' as c;

/// The result returned from an asynchronous Filament operation through the callback bridge.
class CallbackResult {
  /// The operation kind (e.g. pick, compile, async gltf, readback).
  final int kind;

  /// The status code (0 for success, non-zero for error or custom status).
  final int status;

  /// The raw payload bytes delivered from C++.
  final Uint8List payload;

  const CallbackResult({
    required this.kind,
    required this.status,
    required this.payload,
  });
}

/// Unified process-wide callback bridge for asynchronous C++ Filament events.
class CallbackBridge {
  CallbackBridge._();

  static final CallbackBridge instance = CallbackBridge._();

  ffi.NativeCallable<ffi.Void Function(ffi.Pointer<c.FilamentCallbackEnvelope>)>?
      _nativeCallable;
  int _nextRequestId = 1;
  final Map<int, Completer<CallbackResult>> _completers = {};
  bool _initialized = false;

  /// Initializes the callback bridge with the native C dispatcher.
  void init() {
    if (_initialized) return;
    _nativeCallable = ffi.NativeCallable<
        ffi.Void Function(ffi.Pointer<c.FilamentCallbackEnvelope>)>.listener(
      _onDispatch,
    );
    final res = c.filament_callback_bridge_init(
      _nativeCallable!.nativeFunction.cast<
          ffi.NativeFunction<c.filament_callback_dispatch_fnFunction>>(),
    );
    if (res != 0) {
      throw StateError(
        'Failed to initialize filament callback bridge (already initialized or error: $res)',
      );
    }
    _initialized = true;
  }

  static void _onDispatch(ffi.Pointer<c.FilamentCallbackEnvelope> env) {
    if (env == ffi.nullptr) return;
    try {
      final reqId = env.ref.request_id;
      final kind = env.ref.kind;
      final status = env.ref.status;
      final payloadPtr = env.ref.payload;
      final payloadSize = env.ref.payload_size;

      Uint8List payloadBytes;
      if (payloadPtr != ffi.nullptr && payloadSize > 0) {
        final srcList = payloadPtr.cast<ffi.Uint8>().asTypedList(payloadSize);
        payloadBytes = Uint8List.fromList(srcList);
      } else {
        payloadBytes = Uint8List(0);
      }

      instance._handleDispatch(reqId, kind, status, payloadBytes);
    } finally {
      c.filament_callback_envelope_free(env);
    }
  }

  void _handleDispatch(int reqId, int kind, int status, Uint8List payload) {
    final completer = _completers.remove(reqId);
    if (completer != null && !completer.isCompleted) {
      completer.complete(
        CallbackResult(kind: kind, status: status, payload: payload),
      );
    }
  }

  /// Registers a pending request with a given [kind] and returns its allocated [requestId]
  /// alongside a [Future] that completes when the native callback is delivered.
  (int requestId, Future<CallbackResult> future) register({required int kind}) {
    if (!_initialized) {
      init();
    }
    final reqId = _nextRequestId++;
    final completer = Completer<CallbackResult>();
    _completers[reqId] = completer;
    return (reqId, completer.future);
  }

  /// The number of pending requests currently registered.
  int get pendingCount => _completers.length;

  /// Test hook to simulate a synchronous native callback fire.
  static void testFire({
    required int requestId,
    required int kind,
    required int status,
    required ffi.Pointer<ffi.Void> payload,
    required int size,
  }) {
    c.filament_test_callback_fire(requestId, kind, status, payload, size);
  }

  /// Test hook to simulate an asynchronous native callback fire from a separate native thread.
  static void testFireAsync({
    required int requestId,
    required int kind,
    required int status,
    required ffi.Pointer<ffi.Void> payload,
    required int size,
  }) {
    c.filament_test_callback_fire_async(requestId, kind, status, payload, size);
  }

  /// Shuts down the bridge and fails any pending requests.
  void shutdown() {
    c.filament_callback_bridge_shutdown();
    _nativeCallable?.close();
    _nativeCallable = null;
    for (final completer in _completers.values) {
      if (!completer.isCompleted) {
        completer.completeError(StateError('CallbackBridge shutdown'));
      }
    }
    _completers.clear();
    _initialized = false;
  }
}
