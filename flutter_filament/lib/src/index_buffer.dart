/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

import 'ffi_platform.dart' as ffi;
import 'dart:typed_data';

import 'package:flutter_filament/src/buffer_descriptor.dart';
import 'package:flutter_filament/src/engine.dart';
import 'package:flutter_filament/src/enums.dart';
import 'package:flutter_filament/src/filament_bindings.dart' as c;

export 'package:flutter_filament/src/enums.dart' show IndexType;

/// A buffer holding index data defining triangle or line primitives.
class FilamentIndexBuffer {
  final ffi.Pointer<ffi.Void> _ptr;
  final FilamentEngine _engine;
  final int _indexCount;
  final IndexType _type;
  bool _disposed = false;

  /// Internal constructor.
  FilamentIndexBuffer.internal(
    this._ptr,
    this._engine, {
    required this._indexCount,
    required this._type,
  });

  /// Creates a new [FilamentIndexBuffer].
  static FilamentIndexBuffer create({
    required FilamentEngine engine,
    required int indexCount,
    IndexType type = IndexType.ushort,
  }) {
    if (indexCount <= 0) {
      throw ArgumentError.value(indexCount, 'indexCount', 'Must be greater than 0');
    }

    final ptr = c.filament_index_buffer_create(
      engine.nativePointer,
      indexCount,
      type.value,
    );

    if (ptr == ffi.nullptr) {
      throw StateError('Failed to create Filament IndexBuffer');
    }

    return FilamentIndexBuffer.internal(
      ptr,
      engine,
      indexCount: indexCount,
      type: type,
    );
  }

  /// Number of indices this buffer can hold.
  int get indexCount {
    _checkDisposed();
    final count = c.filament_index_buffer_get_index_count(_ptr);
    return count > 0 ? count : _indexCount;
  }

  /// The element type of the indices (ushort or uint).
  IndexType get type => _type;

  /// Total capacity in bytes for this IndexBuffer.
  int get byteCapacity => _indexCount * (_type == IndexType.ushort ? 2 : 4);

  /// The raw native pointer.
  ffi.Pointer<ffi.Void> get nativePointer {
    _checkDisposed();
    return _ptr;
  }

  /// Sets index data using a [NativeBuffer] with [byteOffset].
  ///
  /// Note: Filament requires [byteOffset] to be a multiple of 4.
  void setBuffer(
    FilamentEngine engine,
    NativeBuffer data, {
    int byteOffset = 0,
    bool autoFree = false,
  }) {
    _checkDisposed();
    if (byteOffset < 0) {
      throw ArgumentError.value(byteOffset, 'byteOffset', 'Must be non-negative');
    }
    if (byteOffset % 4 != 0) {
      throw ArgumentError.value(
        byteOffset,
        'byteOffset',
        'Filament requires byteOffset to be a multiple of 4',
      );
    }
    if (byteOffset + data.sizeInBytes > byteCapacity) {
      throw RangeError(
        'Data range ($byteOffset..${byteOffset + data.sizeInBytes}) exceeds buffer capacity ($byteCapacity)',
      );
    }

    final (user, callback, _) = BufferOwnershipRegistry.instance.register(
      data,
      onFree: autoFree ? () => data.free() : null,
    );

    c.filament_index_buffer_set_buffer(
      engine.nativePointer,
      _ptr,
      data.pointer.cast(),
      data.sizeInBytes,
      byteOffset,
      callback,
      user,
    );
  }

  /// Sets 16-bit unsigned short indices.
  ///
  /// Throws [ArgumentError] if this [FilamentIndexBuffer] is configured for [IndexType.uint].
  void setIndicesU16(Uint16List indices, {int byteOffset = 0}) {
    _checkDisposed();
    if (_type != IndexType.ushort) {
      throw ArgumentError(
        'Cannot upload Uint16List indices to an IndexBuffer configured with IndexType.uint',
      );
    }
    final bytes = Uint8List.view(
      indices.buffer,
      indices.offsetInBytes,
      indices.lengthInBytes,
    );
    final nativeBuf = NativeBuffer.copy(bytes);
    setBuffer(
      _engine,
      nativeBuf,
      byteOffset: byteOffset,
      autoFree: true,
    );
  }

  /// Sets 32-bit unsigned int indices.
  ///
  /// Throws [ArgumentError] if this [FilamentIndexBuffer] is configured for [IndexType.ushort].
  void setIndicesU32(Uint32List indices, {int byteOffset = 0}) {
    _checkDisposed();
    if (_type != IndexType.uint) {
      throw ArgumentError(
        'Cannot upload Uint32List indices to an IndexBuffer configured with IndexType.ushort',
      );
    }
    final bytes = Uint8List.view(
      indices.buffer,
      indices.offsetInBytes,
      indices.lengthInBytes,
    );
    final nativeBuf = NativeBuffer.copy(bytes);
    setBuffer(
      _engine,
      nativeBuf,
      byteOffset: byteOffset,
      autoFree: true,
    );
  }

  /// Sets 16-bit short index data (backward-compatible convenience).
  void setUint16Data(Uint16List data) {
    setIndicesU16(data);
  }

  /// Sets 32-bit int index data (backward-compatible convenience).
  void setUint32Data(Uint32List data) {
    setIndicesU32(data);
  }

  /// Destroys this IndexBuffer.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    c.filament_engine_destroy_index_buffer(_engine.nativePointer, _ptr);
  }

  bool get isDisposed => _disposed;

  void _checkDisposed() {
    if (_disposed) {
      throw StateError('FilamentIndexBuffer has been disposed');
    }
  }
}

/// Convenience alias for [FilamentIndexBuffer].
typedef IndexBuffer = FilamentIndexBuffer;
