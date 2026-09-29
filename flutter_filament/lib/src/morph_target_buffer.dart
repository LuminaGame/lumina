import 'ffi_platform.dart' as ffi;
import 'dart:typed_data';
import 'ffi_package_platform.dart';
import 'package:vector_math/vector_math_64.dart';
import 'filament_bindings.dart' as c;
import 'engine.dart';
import 'math/norm.dart';

/// Packs a quaternion (or 4D tangent frame) into an [Int16List] of 4 snorm16 values.
///
/// Symmetric packaging matching Filament's `norm.h`.
Int16List packTangentFrame(dynamic q) {
  final list = Int16List(4);
  double x = 0, y = 0, z = 0, w = 1;
  if (q is Quaternion) {
    x = q.x;
    y = q.y;
    z = q.z;
    w = q.w;
  } else if (q is Vector4) {
    x = q.x;
    y = q.y;
    z = q.z;
    w = q.w;
  } else if (q is List<num>) {
    x = q[0].toDouble();
    y = q[1].toDouble();
    z = q[2].toDouble();
    w = q[3].toDouble();
  }
  list[0] = packSnorm16(x);
  list[1] = packSnorm16(y);
  list[2] = packSnorm16(z);
  list[3] = packSnorm16(w);
  return list;
}

/// A container for vertex morphing data that supports both automatic and manual morphing.
class MorphTargetBuffer {
  ffi.Pointer<ffi.Void> _nativeBuffer;
  final FilamentEngine engine;
  final int _vertexCount;
  final int _count;
  final bool _hasPositions;
  final bool _hasTangents;
  final bool _isCustomMorphingEnabled;

  MorphTargetBuffer._(
    this._nativeBuffer,
    this.engine,
    this._vertexCount,
    this._count,
    this._hasPositions,
    this._hasTangents,
    this._isCustomMorphingEnabled,
  );

  /// Creates a MorphTargetBuffer.
  factory MorphTargetBuffer.create(
    FilamentEngine engine, {
    required int vertexCount,
    required int count,
    bool withPositions = true,
    bool withTangents = true,
    bool customMorphing = false,
  }) {
    if (vertexCount <= 0) {
      throw RangeError.range(vertexCount, 1, null, 'vertexCount');
    }
    if (count <= 0) {
      throw RangeError.range(count, 1, null, 'count');
    }

    final nativeBuffer = c.filament_morph_target_buffer_create(
      engine.nativePointer,
      vertexCount,
      count,
      withPositions,
      withTangents,
      customMorphing,
    );

    if (nativeBuffer == ffi.nullptr) {
      throw StateError('Failed to create MorphTargetBuffer');
    }

    return MorphTargetBuffer._(
      nativeBuffer,
      engine,
      vertexCount,
      count,
      withPositions,
      withTangents,
      customMorphing,
    );
  }

  /// Sets position morph deltas for the target at [targetIndex].
  ///
  /// If [asFloat4] is false, [positions] contains 3 floats per vertex (x, y, z).
  /// If [asFloat4] is true, [positions] contains 4 floats per vertex (x, y, z, w).
  void setPositionsAt(
    int targetIndex,
    Float32List positions, {
    bool asFloat4 = false,
    int offset = 0,
    int? count,
  }) {
    _checkDisposed();
    if (targetIndex < 0 || targetIndex >= _count) {
      throw RangeError.range(targetIndex, 0, _count - 1, 'targetIndex');
    }
    if (!_hasPositions) {
      throw StateError('MorphTargetBuffer was created with withPositions: false');
    }

    final stride = asFloat4 ? 4 : 3;
    final actualCount = count ?? (positions.length ~/ stride);

    if (offset < 0 || actualCount < 0 || offset + actualCount > _vertexCount) {
      throw RangeError('offset ($offset) + count ($actualCount) exceeds vertexCount ($_vertexCount)');
    }
    if (positions.length < (offset + actualCount) * stride && count != null) {
      throw ArgumentError('positions list is too small for count $actualCount and offset $offset');
    }

    using((Arena arena) {
      final totalFloats = actualCount * stride;
      final ptr = arena<ffi.Float>(totalFloats);
      ptr.asTypedList(totalFloats).setAll(0, positions.sublist(0, totalFloats));

      if (asFloat4) {
        c.filament_morph_target_buffer_set_positions_at_float4(
          engine.nativePointer,
          _nativeBuffer,
          targetIndex,
          ptr,
          actualCount,
          offset,
        );
      } else {
        c.filament_morph_target_buffer_set_positions_at_float3(
          engine.nativePointer,
          _nativeBuffer,
          targetIndex,
          ptr,
          actualCount,
          offset,
        );
      }
    });
  }

  /// Sets tangent morph deltas for the target at [targetIndex].
  ///
  /// [tangents] contains 4 signed 16-bit integers per vertex (snorm16 quantized quaternion).
  void setTangentsAt(
    int targetIndex,
    Int16List tangents, {
    int offset = 0,
    int? count,
  }) {
    _checkDisposed();
    if (targetIndex < 0 || targetIndex >= _count) {
      throw RangeError.range(targetIndex, 0, _count - 1, 'targetIndex');
    }
    if (!_hasTangents) {
      throw StateError('MorphTargetBuffer was created with withTangents: false');
    }

    final actualCount = count ?? (tangents.length ~/ 4);
    if (offset < 0 || actualCount < 0 || offset + actualCount > _vertexCount) {
      throw RangeError('offset ($offset) + count ($actualCount) exceeds vertexCount ($_vertexCount)');
    }
    if (tangents.length < (offset + actualCount) * 4 && count != null) {
      throw ArgumentError('tangents list is too small for count $actualCount and offset $offset');
    }

    using((Arena arena) {
      final totalShorts = actualCount * 4;
      final ptr = arena<ffi.Int16>(totalShorts);
      ptr.asTypedList(totalShorts).setAll(0, tangents.sublist(0, totalShorts));

      c.filament_morph_target_buffer_set_tangents_at(
        engine.nativePointer,
        _nativeBuffer,
        targetIndex,
        ptr,
        actualCount,
        offset,
      );
    });
  }

  /// Returns the vertex count of this buffer.
  int get vertexCount => _vertexCount;

  /// Returns the target count of this buffer.
  int get count => _count;

  /// Whether position morphing is enabled on this buffer.
  bool get hasPositions => _hasPositions;

  /// Whether tangent morphing is enabled on this buffer.
  bool get hasTangents => _hasTangents;

  /// Whether custom morphing is enabled on this buffer.
  bool get isCustomMorphingEnabled => _isCustomMorphingEnabled;

  /// The underlying native pointer for internal bindings.
  ffi.Pointer<ffi.Void> get nativePointer {
    _checkDisposed();
    return _nativeBuffer;
  }

  /// Alias for [nativePointer].
  ffi.Pointer<ffi.Void> get nativePtr => nativePointer;

  /// Whether this buffer has been disposed.
  bool get isDisposed => _nativeBuffer == ffi.nullptr;

  /// Destroys the MorphTargetBuffer.
  void destroy() => dispose();

  /// Destroys the MorphTargetBuffer.
  void dispose() {
    if (_nativeBuffer != ffi.nullptr) {
      c.filament_engine_destroy_morph_target_buffer(engine.nativePointer, _nativeBuffer);
      _nativeBuffer = ffi.nullptr;
    }
  }

  void _checkDisposed() {
    if (_nativeBuffer == ffi.nullptr) {
      throw StateError('MorphTargetBuffer has been disposed');
    }
  }
}
