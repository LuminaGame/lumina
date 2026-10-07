import 'package:flutter_filament/src/ffi_platform.dart' as ffi;
import 'dart:typed_data';
import 'package:flutter_filament/src/ffi_package_platform.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:flutter_filament/src/filament_bindings.dart' as c;
import 'package:flutter_filament/src/engine.dart';

/// Helper to pack a list of [Matrix4] objects into a contiguous column-major [Float32List] of length 16 * N.
Float32List packMatrices(List<Matrix4> matrices) {
  final list = Float32List(matrices.length * 16);
  for (var i = 0; i < matrices.length; i++) {
    matrices[i].copyIntoArray(list, i * 16);
  }
  return list;
}

/// Holds GPU draw instance transforms for GPU instancing.
class InstanceBuffer {
  ffi.Pointer<ffi.Void> _nativeBuffer;
  final FilamentEngine engine;
  final int _instanceCount;

  InstanceBuffer._(this._nativeBuffer, this.engine, this._instanceCount);

  /// Creates an InstanceBuffer.
  ///
  /// [instanceCount] must be between 1 and [FilamentEngine.maxAutomaticInstances].
  /// Optionally provide [localTransforms] as a contiguous column-major Float32List of length 16 * instanceCount.
  factory InstanceBuffer.create(
    FilamentEngine engine, {
    required int instanceCount,
    Float32List? localTransforms,
  }) {
    if (instanceCount < 1) {
      throw RangeError.range(instanceCount, 1, null, 'instanceCount');
    }
    final maxInstances = engine.maxAutomaticInstances;
    if (maxInstances > 0 && instanceCount > maxInstances) {
      throw RangeError('instanceCount ($instanceCount) exceeds engine.maxAutomaticInstances ($maxInstances)');
    }

    if (localTransforms != null && localTransforms.length < instanceCount * 16) {
      throw ArgumentError('localTransforms length (${localTransforms.length}) is less than instanceCount * 16 (${instanceCount * 16})');
    }

    return using((Arena arena) {
      ffi.Pointer<ffi.Float> initialPtr = ffi.nullptr;
      if (localTransforms != null) {
        initialPtr = arena<ffi.Float>(instanceCount * 16);
        initialPtr.asTypedList(instanceCount * 16).setAll(0, localTransforms.take(instanceCount * 16));
      }

      final nativeBuffer = c.filament_instance_buffer_create(
        engine.nativePointer,
        instanceCount,
        initialPtr,
      );

      if (nativeBuffer == ffi.nullptr) {
        throw StateError('Failed to create InstanceBuffer');
      }

      return InstanceBuffer._(nativeBuffer, engine, instanceCount);
    });
  }

  /// Sets local transforms starting at [offset] for [count] instances.
  ///
  /// [transforms] is a contiguous column-major [Float32List] with 16 floats per instance.
  void setLocalTransforms(
    Float32List transforms, {
    int? count,
    int offset = 0,
  }) {
    _checkDisposed();
    final actualCount = count ?? (transforms.length ~/ 16);
    if (offset < 0 || actualCount < 0 || offset + actualCount > _instanceCount) {
      throw RangeError('offset ($offset) + count ($actualCount) exceeds instanceCount ($_instanceCount)');
    }
    if (transforms.length < actualCount * 16) {
      throw ArgumentError('transforms length (${transforms.length}) is less than count * 16 (${actualCount * 16})');
    }

    using((Arena arena) {
      final ptr = arena<ffi.Float>(actualCount * 16);
      ptr.asTypedList(actualCount * 16).setAll(0, transforms.take(actualCount * 16));
      c.filament_instance_buffer_set_local_transforms(
        _nativeBuffer,
        ptr,
        actualCount,
        offset,
      );
    });
  }

  /// Returns the local transform for instance at [index].
  Matrix4 getLocalTransform(int index) {
    _checkDisposed();
    if (index < 0 || index >= _instanceCount) {
      throw RangeError.range(index, 0, _instanceCount - 1, 'index');
    }

    return using((Arena arena) {
      final ptr = arena<ffi.Float>(16);
      c.filament_instance_buffer_get_local_transform(_nativeBuffer, index, ptr);
      final floats = Float32List.fromList(ptr.asTypedList(16));
      return Matrix4.fromList(floats);
    });
  }

  /// Returns the instance capacity of this buffer.
  int get instanceCount => _instanceCount;

  /// The underlying native pointer for internal bindings.
  ffi.Pointer<ffi.Void> get nativePointer {
    _checkDisposed();
    return _nativeBuffer;
  }

  /// Alias for [nativePointer].
  ffi.Pointer<ffi.Void> get nativePtr => nativePointer;

  /// Whether this buffer has been disposed.
  bool get isDisposed => _nativeBuffer == ffi.nullptr;

  /// Destroys the InstanceBuffer.
  void destroy() => dispose();

  /// Destroys the InstanceBuffer.
  void dispose() {
    if (_nativeBuffer != ffi.nullptr) {
      c.filament_engine_destroy_instance_buffer(engine.nativePointer, _nativeBuffer);
      _nativeBuffer = ffi.nullptr;
    }
  }

  void _checkDisposed() {
    if (_nativeBuffer == ffi.nullptr) {
      throw StateError('InstanceBuffer has been disposed');
    }
  }
}
