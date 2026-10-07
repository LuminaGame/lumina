/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

import 'package:flutter_filament/src/ffi_platform.dart' as ffi;
import 'dart:typed_data';

import 'package:flutter_filament/src/buffer_descriptor.dart';
import 'package:flutter_filament/src/engine.dart';
import 'package:flutter_filament/src/filament_bindings.dart' as c;

/// Distinguishes between buffer object bindings (e.g., vertex, uniform, SSBO).
enum BufferObjectBindingType {
  vertex(0),
  uniform(1),
  shaderStorage(2);

  final int value;
  const BufferObjectBindingType(this.value);
}

/// A generic GPU buffer containing data for sharing between multiple VertexBuffer instances.
class FilamentBufferObject {
  final ffi.Pointer<ffi.Void> _ptr;
  final FilamentEngine _engine;
  final int _byteCount;
  final BufferObjectBindingType _bindingType;
  bool _disposed = false;

  /// Internal constructor.
  FilamentBufferObject.internal(
    this._ptr,
    this._engine, {
    required this._byteCount,
    required this._bindingType,
  });

  /// Creates a new [FilamentBufferObject] capable of holding [byteCount] bytes.
  static FilamentBufferObject create({
    required FilamentEngine engine,
    required int byteCount,
    BufferObjectBindingType bindingType = BufferObjectBindingType.vertex,
  }) {
    if (byteCount <= 0) {
      throw ArgumentError.value(byteCount, 'byteCount', 'Must be greater than 0');
    }

    final ptr = c.filament_buffer_object_create(
      engine.nativePointer,
      byteCount,
      bindingType.value,
    );

    if (ptr == ffi.nullptr) {
      throw StateError('Failed to create Filament BufferObject');
    }

    return FilamentBufferObject.internal(
      ptr,
      engine,
      byteCount: byteCount,
      bindingType: bindingType,
    );
  }

  /// Maximum number of bytes this BufferObject can hold.
  int get byteCount {
    _checkDisposed();
    final count = c.filament_buffer_object_get_byte_count(_ptr);
    return count > 0 ? count : _byteCount;
  }

  /// The binding type of this BufferObject.
  BufferObjectBindingType get bindingType => _bindingType;

  /// The raw native pointer.
  ffi.Pointer<ffi.Void> get nativePointer {
    _checkDisposed();
    return _ptr;
  }

  /// Updates buffer contents with [data] at [byteOffset].
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
    if (byteOffset + data.sizeInBytes > byteCount) {
      throw RangeError('Data range ($byteOffset..${byteOffset + data.sizeInBytes}) exceeds buffer capacity ($byteCount)');
    }

    final (user, callback, _) = BufferOwnershipRegistry.instance.register(
      data,
      onFree: autoFree ? () => data.free() : null,
    );

    c.filament_buffer_object_set_buffer(
      engine.nativePointer,
      _ptr,
      data.pointer.cast(),
      data.sizeInBytes,
      byteOffset,
      callback,
      user,
    );
  }

  /// Convenience method to upload [TypedData] at [byteOffset].
  void setData(TypedData data, {int byteOffset = 0}) {
    _checkDisposed();
    final bytes = Uint8List.view(
      data.buffer,
      data.offsetInBytes,
      data.lengthInBytes,
    );
    final nativeBuf = NativeBuffer.copy(bytes);
    setBuffer(
      _engine,
      nativeBuf,
      byteOffset: byteOffset,
      autoFree: true,
    );
  }

  /// Destroys this BufferObject.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    c.filament_engine_destroy_buffer_object(_engine.nativePointer, _ptr);
  }

  bool get isDisposed => _disposed;

  void _checkDisposed() {
    if (_disposed) {
      throw StateError('FilamentBufferObject has been disposed');
    }
  }
}

/// Convenience alias for [FilamentBufferObject].
typedef BufferObject = FilamentBufferObject;
