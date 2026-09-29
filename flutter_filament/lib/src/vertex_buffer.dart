/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

import 'ffi_platform.dart' as ffi;
import 'dart:typed_data';
import 'ffi_package_platform.dart';

import 'package:flutter_filament/src/buffer_descriptor.dart';
import 'package:flutter_filament/src/buffer_object.dart';
import 'package:flutter_filament/src/engine.dart';
import 'package:flutter_filament/src/enums.dart';
import 'package:flutter_filament/src/filament_bindings.dart' as c;

/// Description of a vertex attribute within a [FilamentVertexBuffer].
class VertexAttributeDesc {
  final VertexAttribute attribute;
  final int bufferIndex;
  final AttributeType type;
  final int byteOffset;
  final int byteStride;
  final bool normalized;

  const VertexAttributeDesc({
    required this.attribute,
    this.bufferIndex = 0,
    required this.type,
    this.byteOffset = 0,
    this.byteStride = 0,
    this.normalized = false,
  });
}

/// A buffer holding vertex data (positions, normals, UVs, colors, etc.).
class FilamentVertexBuffer {
  final ffi.Pointer<ffi.Void> _ptr;
  final FilamentEngine _engine;
  final int _vertexCount;
  final int _bufferCount;
  final List<VertexAttributeDesc> _attributes;
  final List<int> _bufferByteSizes;
  final bool _enableBufferObjects;
  bool _disposed = false;

  /// Internal constructor.
  FilamentVertexBuffer.internal(
    this._ptr,
    this._engine, {
    required this._vertexCount,
    required this._bufferCount,
    required List<VertexAttributeDesc> attributes,
    required List<int> bufferByteSizes,
    this._enableBufferObjects = false,
  })  : _attributes = List.unmodifiable(attributes),
        _bufferByteSizes = List.unmodifiable(bufferByteSizes);

  /// Creates a new generic [FilamentVertexBuffer] with arbitrary attribute layouts.
  static FilamentVertexBuffer create({
    required FilamentEngine engine,
    required int vertexCount,
    int bufferCount = 1,
    List<VertexAttributeDesc>? attributes,
    bool withColor = false,
    bool withUv = false,
    bool enableBufferObjects = false,
    bool advancedSkinning = false,
  }) {
    if (vertexCount <= 0) {
      throw ArgumentError.value(vertexCount, 'vertexCount', 'Must be greater than 0');
    }
    if (bufferCount <= 0 || bufferCount > 8) {
      throw ArgumentError.value(bufferCount, 'bufferCount', 'Must be between 1 and 8');
    }

    final resolvedAttributes = attributes ??
        (withColor
            ? const [
                VertexAttributeDesc(
                  attribute: VertexAttribute.position,
                  bufferIndex: 0,
                  type: AttributeType.float3,
                  byteOffset: 0,
                  byteStride: 16,
                ),
                VertexAttributeDesc(
                  attribute: VertexAttribute.color,
                  bufferIndex: 0,
                  type: AttributeType.ubyte4,
                  byteOffset: 12,
                  byteStride: 16,
                  normalized: true,
                ),
              ]
            : withUv
                ? const [
                    VertexAttributeDesc(
                      attribute: VertexAttribute.position,
                      bufferIndex: 0,
                      type: AttributeType.float2,
                      byteOffset: 0,
                      byteStride: 16,
                    ),
                    VertexAttributeDesc(
                      attribute: VertexAttribute.uv0,
                      bufferIndex: 0,
                      type: AttributeType.float2,
                      byteOffset: 8,
                      byteStride: 16,
                    ),
                  ]
                : const [
                    VertexAttributeDesc(
                      attribute: VertexAttribute.position,
                      bufferIndex: 0,
                      type: AttributeType.float3,
                      byteOffset: 0,
                      byteStride: 12,
                    ),
                  ]);

    final attrArray = calloc<c.FilamentVertexAttributeDesc>(resolvedAttributes.length);
    try {
      for (int i = 0; i < resolvedAttributes.length; i++) {
        final a = resolvedAttributes[i];
        if (a.byteStride > 255) {
          throw ArgumentError.value(
            a.byteStride,
            'byteStride',
            'Filament supports a maximum stride of 255 bytes',
          );
        }
        attrArray[i].attribute = a.attribute.value;
        attrArray[i].buffer_index = a.bufferIndex;
        attrArray[i].type = a.type.value;
        attrArray[i].byte_offset = a.byteOffset;
        attrArray[i].byte_stride = a.byteStride;
        attrArray[i].normalized = a.normalized;
      }

      final ptr = c.filament_vertex_buffer_create(
        engine.nativePointer,
        bufferCount,
        vertexCount,
        resolvedAttributes.length,
        attrArray,
        enableBufferObjects,
        advancedSkinning,
      );

      if (ptr == ffi.nullptr) {
        throw StateError('Failed to create Filament VertexBuffer');
      }

      final List<int> bufferByteSizes = List.filled(bufferCount, 0);
      for (final a in resolvedAttributes) {
        final stride = a.byteStride > 0 ? a.byteStride : a.type.byteSize;
        final size = a.byteOffset + stride * vertexCount;
        if (size > bufferByteSizes[a.bufferIndex]) {
          bufferByteSizes[a.bufferIndex] = size;
        }
      }

      return FilamentVertexBuffer.internal(
        ptr,
        engine,
        vertexCount: vertexCount,
        bufferCount: bufferCount,
        attributes: resolvedAttributes,
        bufferByteSizes: bufferByteSizes,
        enableBufferObjects: enableBufferObjects,
      );
    } finally {
      calloc.free(attrArray);
    }
  }

  /// Preset for a vertex buffer with only 3D positions (float3).
  static FilamentVertexBuffer positions({
    required FilamentEngine engine,
    required int vertexCount,
    int bufferCount = 1,
    bool enableBufferObjects = false,
  }) {
    return create(
      engine: engine,
      vertexCount: vertexCount,
      bufferCount: bufferCount,
      enableBufferObjects: enableBufferObjects,
      attributes: const [
        VertexAttributeDesc(
          attribute: VertexAttribute.position,
          type: AttributeType.float3,
          byteOffset: 0,
          byteStride: 12,
        ),
      ],
    );
  }

  /// Preset for a vertex buffer with positions (float3) and vertex colors (ubyte4, normalized).
  static FilamentVertexBuffer positionsAndColors({
    required FilamentEngine engine,
    required int vertexCount,
    int bufferCount = 1,
    bool enableBufferObjects = false,
  }) {
    return create(
      engine: engine,
      vertexCount: vertexCount,
      bufferCount: bufferCount,
      enableBufferObjects: enableBufferObjects,
      attributes: const [
        VertexAttributeDesc(
          attribute: VertexAttribute.position,
          type: AttributeType.float3,
          byteOffset: 0,
          byteStride: 16,
        ),
        VertexAttributeDesc(
          attribute: VertexAttribute.color,
          type: AttributeType.ubyte4,
          byteOffset: 12,
          byteStride: 16,
          normalized: true,
        ),
      ],
    );
  }

  /// Preset for a vertex buffer with positions (float2) and texture coordinates (float2).
  static FilamentVertexBuffer positionsAndUvs({
    required FilamentEngine engine,
    required int vertexCount,
    int bufferCount = 1,
    bool enableBufferObjects = false,
  }) {
    return create(
      engine: engine,
      vertexCount: vertexCount,
      bufferCount: bufferCount,
      enableBufferObjects: enableBufferObjects,
      attributes: const [
        VertexAttributeDesc(
          attribute: VertexAttribute.position,
          type: AttributeType.float2,
          byteOffset: 0,
          byteStride: 16,
        ),
        VertexAttributeDesc(
          attribute: VertexAttribute.uv0,
          type: AttributeType.float2,
          byteOffset: 8,
          byteStride: 16,
        ),
      ],
    );
  }

  /// Number of vertices in each buffer slot.
  int get vertexCount {
    _checkDisposed();
    final count = c.filament_vertex_buffer_get_vertex_count(_ptr);
    return count > 0 ? count : _vertexCount;
  }

  /// Number of buffer slots.
  int get bufferCount => _bufferCount;

  /// Whether buffer object mode is enabled.
  bool get enableBufferObjects => _enableBufferObjects;

  /// The attribute descriptions for this vertex buffer.
  List<VertexAttributeDesc> get attributes => _attributes;

  /// The raw native pointer.
  ffi.Pointer<ffi.Void> get nativePointer {
    _checkDisposed();
    return _ptr;
  }

  /// Sets vertex data for a buffer slot using a [NativeBuffer] with optional [byteOffset].
  void setBufferAt(
    FilamentEngine engine,
    int bufferIndex,
    NativeBuffer data, {
    int byteOffset = 0,
    bool autoFree = false,
  }) {
    _checkDisposed();
    if (_enableBufferObjects) {
      throw StateError(
        'Cannot call setBufferAt when enableBufferObjects is true. Use setBufferObjectAt instead.',
      );
    }
    if (bufferIndex < 0 || bufferIndex >= _bufferCount) {
      throw RangeError.range(bufferIndex, 0, _bufferCount - 1, 'bufferIndex');
    }
    if (byteOffset < 0) {
      throw ArgumentError.value(byteOffset, 'byteOffset', 'Must be non-negative');
    }
    final int capacity = _bufferByteSizes[bufferIndex];
    if (byteOffset + data.sizeInBytes > capacity) {
      throw RangeError(
        'Upload size (${data.sizeInBytes} bytes) at offset $byteOffset exceeds buffer capacity ($capacity bytes).',
      );
    }

    final (user, callback, _) = BufferOwnershipRegistry.instance.register(
      data,
      onFree: autoFree ? () => data.free() : null,
    );

    c.filament_vertex_buffer_set_buffer_at(
      engine.nativePointer,
      _ptr,
      bufferIndex,
      data.pointer.cast(),
      data.sizeInBytes,
      byteOffset,
      callback,
      user,
    );
  }

  /// Sets a shared [BufferObject] at [bufferIndex].
  ///
  /// Throws [StateError] if this [FilamentVertexBuffer] was not created with `enableBufferObjects: true`.
  void setBufferObjectAt(
    FilamentEngine engine,
    int bufferIndex,
    FilamentBufferObject bufferObject,
  ) {
    _checkDisposed();
    if (!_enableBufferObjects) {
      throw StateError(
        'Cannot call setBufferObjectAt when enableBufferObjects is false. Set enableBufferObjects: true when creating the VertexBuffer.',
      );
    }
    if (bufferIndex < 0 || bufferIndex >= _bufferCount) {
      throw RangeError.range(bufferIndex, 0, _bufferCount - 1, 'bufferIndex');
    }

    c.filament_vertex_buffer_set_buffer_object_at(
      engine.nativePointer,
      _ptr,
      bufferIndex,
      bufferObject.nativePointer,
    );
  }

  /// Sets vertex data for a buffer slot from a [Float32List] or [TypedData].
  void setData(TypedData data, {int bufferIndex = 0, int byteOffset = 0}) {
    _checkDisposed();
    final bytes = Uint8List.view(
      data.buffer,
      data.offsetInBytes,
      data.lengthInBytes,
    );
    final nativeBuf = NativeBuffer.copy(bytes);
    setBufferAt(
      _engine,
      bufferIndex,
      nativeBuf,
      byteOffset: byteOffset,
      autoFree: true,
    );
  }

  /// Destroys this VertexBuffer.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    c.filament_engine_destroy_vertex_buffer(_engine.nativePointer, _ptr);
  }

  bool get isDisposed => _disposed;

  void _checkDisposed() {
    if (_disposed) {
      throw StateError('FilamentVertexBuffer has been disposed');
    }
  }
}

/// Convenience alias for [FilamentVertexBuffer].
typedef VertexBuffer = FilamentVertexBuffer;
