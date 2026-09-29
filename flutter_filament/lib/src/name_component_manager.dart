import 'ffi_platform.dart' as ffi;
import 'ffi_package_platform.dart';

import 'package:flutter_filament/src/entity.dart';
import 'package:flutter_filament/src/filament_bindings.dart' as c;

/// Component manager for associating string labels/names with entities.
///
/// In Filament, entities are raw integer IDs. [NameComponentManager] allows
/// assigning human-readable names to entities (e.g. lights, procedural meshes,
/// camera nodes) for scene hierarchy inspection and editor display.
class NameComponentManager {
  final ffi.Pointer<ffi.Void> _ptr;
  bool _disposed = false;

  /// Creates a new [NameComponentManager] attached to the global [EntityManager].
  NameComponentManager() : _ptr = c.filament_name_component_manager_create();

  /// Creates a wrapper around an existing native pointer.
  NameComponentManager.fromPointer(this._ptr);

  /// Raw native pointer.
  ffi.Pointer<ffi.Void> get nativePointer {
    _checkDisposed();
    return _ptr;
  }

  int _toId(dynamic entity) => entity is FilamentEntity ? entity.id : entity as int;

  /// Adds a name component to [entity] if it doesn't already have one.
  void addComponent(dynamic entity) {
    _checkDisposed();
    c.filament_name_component_manager_add_component(_ptr, _toId(entity));
  }

  /// Removes the name component from [entity].
  void removeComponent(dynamic entity) {
    _checkDisposed();
    c.filament_name_component_manager_remove_component(_ptr, _toId(entity));
  }

  /// Checks if [entity] has an associated name component.
  bool hasComponent(dynamic entity) {
    _checkDisposed();
    return c.filament_name_component_manager_get_instance(_ptr, _toId(entity)) != 0;
  }

  /// Sets or updates the name associated with [entity].
  ///
  /// Automatically calls [addComponent] if [entity] does not yet have a name component.
  void setName(dynamic entity, String name) {
    _checkDisposed();
    final id = _toId(entity);
    if (!hasComponent(id)) {
      addComponent(id);
    }
    final namePtr = name.toNativeUtf8();
    try {
      c.filament_name_component_manager_set_name(_ptr, id, namePtr.cast());
    } finally {
      calloc.free(namePtr);
    }
  }

  /// Retrieves the name associated with [entity], or `null` if no name component exists.
  String? getName(dynamic entity) {
    _checkDisposed();
    final namePtr = c.filament_name_component_manager_get_name(_ptr, _toId(entity));
    if (namePtr == ffi.nullptr) {
      return null;
    }
    return namePtr.cast<Utf8>().toDartString();
  }

  /// Cleans up internal component storage by removing name components for dead/destroyed entities.
  void gc() {
    _checkDisposed();
    c.filament_name_component_manager_gc(_ptr);
  }

  /// Destroys this [NameComponentManager] and frees its native memory.
  void destroy() {
    if (_disposed) return;
    _disposed = true;
    c.filament_name_component_manager_destroy(_ptr);
  }

  /// Alias for [destroy].
  void dispose() => destroy();

  bool get isDisposed => _disposed;

  void _checkDisposed() {
    if (_disposed) {
      throw StateError('NameComponentManager has been disposed');
    }
  }
}
