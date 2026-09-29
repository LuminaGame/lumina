/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

import 'dart:async';
import 'ffi_platform.dart' as ffi;
import 'dart:typed_data';

import 'ffi_package_platform.dart';
import 'package:flutter_filament/src/engine.dart';
import 'package:flutter_filament/src/filament_bindings.dart' as c;

/// A contiguous native memory buffer allocated on the C heap for zero-copy transfers to Filament.
class NativeBuffer {
  final ffi.Pointer<ffi.Uint8> pointer;
  final int sizeInBytes;
  final Uint8List _view;
  bool _isReleased = false;

  NativeBuffer._(this.pointer, this.sizeInBytes, this._view);

  /// Allocates [byteCount] bytes of native memory using `calloc`.
  factory NativeBuffer.allocate(int byteCount) {
    if (byteCount <= 0) {
      throw ArgumentError.value(byteCount, 'byteCount', 'Must be greater than 0');
    }
    final ptr = calloc<ffi.Uint8>(byteCount);
    return NativeBuffer._(ptr, byteCount, ptr.asTypedList(byteCount));
  }

  /// Allocates native memory and copies [source] bytes into it.
  factory NativeBuffer.copy(Uint8List source) {
    final buffer = NativeBuffer.allocate(source.lengthInBytes);
    buffer.asTypedList.setAll(0, source);
    return buffer;
  }

  /// Allocates native memory and copies any [TypedData] into it.
  factory NativeBuffer.fromTypedData(TypedData source) {
    final bytes = source.buffer.asUint8List(source.offsetInBytes, source.lengthInBytes);
    return NativeBuffer.copy(bytes);
  }

  /// Returns a Dart [Uint8List] view pointing directly to the allocated native memory.
  ///
  /// Throws a [StateError] if this buffer has already been released or freed.
  Uint8List get asTypedList {
    if (_isReleased) {
      throw StateError('NativeBuffer has already been released or freed.');
    }
    return _view;
  }

  /// The raw native address of this buffer.
  int get address => pointer.address;

  /// Whether this buffer has been released / freed.
  bool get isReleased => _isReleased;

  /// Frees the allocated native memory. Safe to call multiple times (idempotent).
  void free() {
    if (!_isReleased) {
      _isReleased = true;
      calloc.free(pointer);
    }
  }
}

class _BufferEntry {
  final Object keepAlive;
  final Completer<void> completer;
  final void Function()? onFree;

  _BufferEntry({
    required this.keepAlive,
    required this.completer,
    this.onFree,
  });
}

/// Central registry managing buffer ownership and release callbacks from Filament's backend.
class BufferOwnershipRegistry {
  BufferOwnershipRegistry._() {
    _nativeCallback = ffi.NativeCallable<
        ffi.Void Function(ffi.Pointer<ffi.Void>, ffi.Size, ffi.Pointer<ffi.Void>)>.listener(
      _onBufferFree,
    );
  }

  static final BufferOwnershipRegistry instance = BufferOwnershipRegistry._();

  late final ffi.NativeCallable<
      ffi.Void Function(ffi.Pointer<ffi.Void>, ffi.Size, ffi.Pointer<ffi.Void>)> _nativeCallback;

  int _nextToken = 1;
  final Map<int, _BufferEntry> _entries = {};

  static void _onBufferFree(
    ffi.Pointer<ffi.Void> buffer,
    int size,
    ffi.Pointer<ffi.Void> user,
  ) {
    final token = user.address;
    instance._handleRelease(token, buffer, size);
  }

  void _handleRelease(int token, ffi.Pointer<ffi.Void> buffer, int size) {
    final entry = _entries.remove(token);
    if (entry != null) {
      try {
        entry.onFree?.call();
      } finally {
        if (!entry.completer.isCompleted) {
          entry.completer.complete();
        }
      }
    }
  }

  /// Registers an object to keep alive until the GPU backend invokes the release callback.
  ///
  /// Returns a tuple containing:
  /// - `user`: The opaque user pointer (carrying the registration token).
  /// - `callback`: The native function pointer matching `filament_buffer_free_fn`.
  /// - `token`: The internal tracking token.
  (ffi.Pointer<ffi.Void> user, c.filament_buffer_free_fn callback, int token)
      register(
    Object keepAlive, {
    void Function()? onFree,
  }) {
    final token = _nextToken++;
    final completer = Completer<void>();
    _entries[token] = _BufferEntry(
      keepAlive: keepAlive,
      completer: completer,
      onFree: onFree,
    );
    return (
      ffi.Pointer<ffi.Void>.fromAddress(token),
      _nativeCallback.nativeFunction.cast<ffi.NativeFunction<c.filament_buffer_free_fnFunction>>(),
      token,
    );
  }

  /// Returns a [Future] that completes when the GPU backend has finished processing
  /// the buffer associated with [token] and released it.
  Future<void> whenReleased(int token) {
    final entry = _entries[token];
    if (entry != null) {
      return entry.completer.future;
    }
    return Future.value();
  }

  /// The number of buffers currently awaiting GPU release.
  int get pendingCount => _entries.length;

  /// Helper for zero-copy address verification.
  static ffi.Pointer<ffi.Void> peekAddress(ffi.Pointer<ffi.Void> data) {
    return c.filament_test_buffer_descriptor_peek(data);
  }

  /// Test hook to push a BufferDescriptor through the engine command stream.
  static void consumeTestBuffer({
    required FilamentEngine engine,
    required ffi.Pointer<ffi.Void> data,
    required int size,
    required c.filament_buffer_free_fn callback,
    required ffi.Pointer<ffi.Void> user,
  }) {
    c.filament_test_consume_buffer_descriptor(
      engine.nativePointer,
      data,
      size,
      callback,
      user,
    );
  }

  /// Test hook to push a PixelBufferDescriptor through the engine command stream.
  static void consumeTestPixelBuffer({
    required FilamentEngine engine,
    required ffi.Pointer<ffi.Void> data,
    required int size,
    required int pixelFormat,
    required int pixelType,
    required int stride,
    required int alignment,
    required c.filament_buffer_free_fn callback,
    required ffi.Pointer<ffi.Void> user,
  }) {
    c.filament_test_consume_pixel_buffer_descriptor(
      engine.nativePointer,
      data,
      size,
      pixelFormat,
      pixelType,
      stride,
      alignment,
      callback,
      user,
    );
  }

  /// Disposes the native callback listener.
  void dispose() {
    _nativeCallback.close();
    for (final entry in _entries.values) {
      if (!entry.completer.isCompleted) {
        entry.completer.completeError(StateError('BufferOwnershipRegistry disposed'));
      }
    }
    _entries.clear();
  }
}
