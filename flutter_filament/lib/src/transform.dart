import 'ffi_platform.dart' as ffi;
import 'ffi_package_platform.dart';

import 'dart:typed_data';
import 'package:vector_math/vector_math_64.dart';
import 'package:flutter_filament/src/engine.dart';
import 'package:flutter_filament/src/instance.dart';
import 'package:flutter_filament/src/filament_bindings.dart' as c;

export 'package:flutter_filament/src/instance.dart' show TransformInstance;

/// Manages transform components for entities.
///
/// Transform components give entities a position and orientation in space.
class FilamentTransformManager {
  final FilamentEngine engine;
  static bool _inTransaction = false;

  /// Creates a transform manager wrapper for [engine].
  const FilamentTransformManager(this.engine);

  /// Executes [body] synchronously inside an open local-transform transaction.
  ///
  /// During the transaction, local transform updates are batched without recomputing
  /// world transforms on every call, avoiding $O(\text{depth})$ cost per update.
  /// When [body] finishes (or throws), the transaction is automatically committed.
  ///
  /// Nested calls to [transaction] are rejected with a [StateError].
  void transaction(void Function() body) {
    if (_inTransaction) {
      throw StateError('TransformManager transaction is not re-entrant');
    }
    _inTransaction = true;
    c.filament_transform_open_local_transform_transaction(engine.nativePointer);
    try {
      body();
    } finally {
      _inTransaction = false;
      c.filament_transform_commit_local_transform_transaction(engine.nativePointer);
    }
  }

  /// Resolves an entity ID to its cached [TransformInstance] handle.
  ///
  /// Returns an invalid instance ([TransformInstance.isValid] == false) if the entity
  /// has no transform component.
  TransformInstance getInstance(int entity) {
    final handle = c.filament_transform_manager_get_instance(
      engine.nativePointer,
      entity,
    );
    return TransformInstance(handle);
  }

  /// Whether [entity] has a transform component.
  bool hasComponent(int entity) {
    return c.filament_transform_manager_has_component(
      engine.nativePointer,
      entity,
    );
  }

  /// Creates a transform component for [entity], optionally attaching it to [parent]
  /// and initializing it with [localTransform].
  ///
  /// [localTransform] can be a 16-element column-major `List<double>`, `Float32List`, or `Matrix4`.
  /// If [parent] is null or 0, the entity is created as a root transform.
  void create(int entity, {int? parent, dynamic localTransform}) {
    if (localTransform == null && (parent == null || parent == 0)) {
      c.filament_transform_create(engine.nativePointer, entity);
      return;
    }

    using((Arena arena) {
      ffi.Pointer<ffi.Float> matrixPtr = ffi.nullptr;
      if (localTransform != null) {
        matrixPtr = arena<ffi.Float>(16);
        if (localTransform is Matrix4) {
          for (var i = 0; i < 16; i++) {
            matrixPtr[i] = localTransform.storage[i];
          }
        } else if (localTransform is List<double>) {
          if (localTransform.length != 16) {
            throw ArgumentError('Transform matrix must contain exactly 16 elements');
          }
          for (var i = 0; i < 16; i++) {
            matrixPtr[i] = localTransform[i];
          }
        } else if (localTransform is Float32List) {
          if (localTransform.length != 16) {
            throw ArgumentError('Transform matrix must contain exactly 16 elements');
          }
          for (var i = 0; i < 16; i++) {
            matrixPtr[i] = localTransform[i];
          }
        } else {
          throw ArgumentError('localTransform must be Matrix4, List<double>, or Float32List');
        }
      }

      c.filament_transform_create_with_parent(
        engine.nativePointer,
        entity,
        parent ?? 0,
        matrixPtr,
      );
    });
  }

  /// Sets the local transform matrix of [entity] using a 16-element
  /// column-major matrix array.
  void setTransform(int entity, List<double> matrix16) {
    if (matrix16.length != 16) {
      throw ArgumentError('Transform matrix must contain exactly 16 elements');
    }
    final ptr = calloc<ffi.Float>(16);
    for (var i = 0; i < 16; i++) {
      ptr[i] = matrix16[i];
    }
    c.filament_transform_set_transform(engine.nativePointer, entity, ptr);
    calloc.free(ptr);
  }

  /// Sets the local transform matrix directly via a fast cached [TransformInstance] handle.
  void setTransformAt(TransformInstance instance, List<double> matrix16) {
    if (!instance.isValid) {
      throw ArgumentError.value(instance, 'instance', 'Cannot set transform on invalid handle');
    }
    if (matrix16.length != 16) {
      throw ArgumentError('Transform matrix must contain exactly 16 elements');
    }
    final ptr = calloc<ffi.Float>(16);
    for (var i = 0; i < 16; i++) {
      ptr[i] = matrix16[i];
    }
    c.filament_transform_manager_set_transform_i(
      engine.nativePointer,
      instance.handle,
      ptr,
    );
    calloc.free(ptr);
  }

  /// Gets the local transform matrix directly via a fast cached [TransformInstance] handle.
  List<double> getTransformAt(TransformInstance instance) {
    if (!instance.isValid) {
      throw ArgumentError.value(instance, 'instance', 'Cannot get local transform on invalid handle');
    }
    final ptr = calloc<ffi.Float>(16);
    c.filament_transform_manager_get_transform_i(
      engine.nativePointer,
      instance.handle,
      ptr,
    );
    final result = List<double>.generate(16, (i) => ptr[i]);
    calloc.free(ptr);
    return result;
  }

  /// Gets the local transform matrix of [entity] as a 16-element
  /// column-major matrix array.
  List<double> getTransform(int entity) {
    final ptr = calloc<ffi.Float>(16);
    c.filament_transform_get_transform(engine.nativePointer, entity, ptr);
    final result = List<double>.generate(16, (i) => ptr[i]);
    calloc.free(ptr);
    return result;
  }

  /// Gets the world transform matrix of [entity] as a 16-element
  /// column-major matrix array.
  List<double> getWorldTransform(int entity) {
    final ptr = calloc<ffi.Float>(16);
    c.filament_transform_get_world_transform(engine.nativePointer, entity, ptr);
    final result = List<double>.generate(16, (i) => ptr[i]);
    calloc.free(ptr);
    return result;
  }

  /// Gets the world transform matrix directly via a fast cached [TransformInstance] handle.
  List<double> worldTransformAt(TransformInstance instance) {
    if (!instance.isValid) {
      throw ArgumentError.value(instance, 'instance', 'Cannot get world transform on invalid handle');
    }
    final ptr = calloc<ffi.Float>(16);
    c.filament_transform_manager_get_world_transform_i(
      engine.nativePointer,
      instance.handle,
      ptr,
    );
    final result = List<double>.generate(16, (i) => ptr[i]);
    calloc.free(ptr);
    return result;
  }

  /// Destroys the transform component for [entity].
  void destroy(int entity) {
    c.filament_transform_destroy(engine.nativePointer, entity);
  }

  /// Sets the parent entity of [entity]'s transform component.
  /// Pass [parentEntity] as 0 to unparent (make a root).
  void setParent(int entity, int parentEntity) {
    c.filament_transform_set_parent(
      engine.nativePointer,
      entity,
      parentEntity,
    );
  }

  /// Gets the parent entity ID of [entity]'s transform, or 0 if it has no parent.
  int getParent(int entity) {
    return c.filament_transform_get_parent(engine.nativePointer, entity);
  }

  /// Gets the number of children attached to [entity]'s transform.
  int childCount(int entity) {
    return c.filament_transform_get_child_count(engine.nativePointer, entity);
  }

  /// Gets a list of children entities attached to [entity]'s transform.
  /// The list will be clamped to [capacity] elements.
  List<int> getChildren(int entity, int capacity) {
    if (capacity <= 0) return [];
    final ptr = calloc<ffi.Uint32>(capacity);
    c.filament_transform_get_children(
      engine.nativePointer,
      entity,
      ptr,
      capacity,
    );
    final result = List<int>.generate(capacity, (i) => ptr[i]);
    calloc.free(ptr);
    return result;
  }
}

