import 'ffi_platform.dart' as ffi;
import 'dart:typed_data';
import 'ffi_package_platform.dart';
import 'package:flutter_filament/src/engine.dart';
import 'package:flutter_filament/src/material.dart';
import 'package:flutter_filament/src/filament_bindings.dart' as c;

/// Registry of named [FilamentMaterialInstance]s used when loading .filamesh models.
class MaterialRegistry {
  ffi.Pointer<c.FilMaterialRegistry> _handle;
  final Map<String, FilamentMaterialInstance> _dartInstances = {};
  bool _isDisposed = false;

  MaterialRegistry() : _handle = c.filament_material_registry_create();

  ffi.Pointer<c.FilMaterialRegistry> get nativeHandle {
    if (_isDisposed) {
      throw StateError('MaterialRegistry has been destroyed');
    }
    return _handle;
  }

  /// Registers a [FilamentMaterialInstance] with a given submesh [name].
  void register(String name, FilamentMaterialInstance materialInstance) {
    if (_isDisposed) {
      throw StateError('MaterialRegistry has been destroyed');
    }
    final nameUtf8 = name.toNativeUtf8();
    try {
      c.filament_material_registry_register(
        _handle,
        nameUtf8.cast(),
        materialInstance.nativePointer,
      );
      _dartInstances[name] = materialInstance;
    } finally {
      calloc.free(nameUtf8);
    }
  }

  /// Gets the registered [FilamentMaterialInstance] for [name], or null if not registered.
  FilamentMaterialInstance? getMaterialInstance(String name) {
    if (_isDisposed) {
      throw StateError('MaterialRegistry has been destroyed');
    }
    return _dartInstances[name];
  }

  /// Unregisters the material instance associated with [name].
  void unregister(String name) {
    if (_isDisposed) {
      throw StateError('MaterialRegistry has been destroyed');
    }
    final nameUtf8 = name.toNativeUtf8();
    try {
      c.filament_material_registry_unregister(_handle, nameUtf8.cast());
      _dartInstances.remove(name);
    } finally {
      calloc.free(nameUtf8);
    }
  }

  /// Number of registered materials in this registry.
  int get numRegistered {
    if (_isDisposed) {
      throw StateError('MaterialRegistry has been destroyed');
    }
    return c.filament_material_registry_num_registered(_handle);
  }

  /// Returns the list of all registered material names.
  List<String> get names {
    if (_isDisposed) {
      throw StateError('MaterialRegistry has been destroyed');
    }
    final count = numRegistered;
    final list = <String>[];
    for (int i = 0; i < count; i++) {
      final namePtr = c.filament_material_registry_get_name_at(_handle, i);
      if (namePtr != ffi.nullptr) {
        list.add(namePtr.cast<Utf8>().toDartString());
      }
    }
    return list;
  }

  /// Destroys the native registry handle.
  ///
  /// Note: The registry does NOT own the underlying [FilamentMaterialInstance]s;
  /// destroying the registry leaves the material instances intact.
  void destroy() {
    if (_isDisposed) return;
    c.filament_material_registry_destroy(_handle);
    _handle = ffi.nullptr;
    _dartInstances.clear();
    _isDisposed = true;
  }
}

/// Represents a loaded .filamesh mesh containing a renderable entity,
/// vertex buffer, and index buffer.
class FilameshMesh {
  final FilamentEngine _engine;
  int _renderable;
  int _vertexBuffer;
  int _indexBuffer;
  bool _isDisposed = false;

  FilameshMesh._({
    required FilamentEngine engine,
    required int renderable,
    required int vertexBuffer,
    required int indexBuffer,
  })  : _engine = engine,
        _renderable = renderable,
        _vertexBuffer = vertexBuffer,
        _indexBuffer = indexBuffer;

  /// The renderable entity ID.
  int get renderable {
    _checkDisposed();
    return _renderable;
  }

  /// The native handle pointer value of the underlying [VertexBuffer].
  int get vertexBuffer {
    _checkDisposed();
    return _vertexBuffer;
  }

  /// The native handle pointer value of the underlying [IndexBuffer].
  int get indexBuffer {
    _checkDisposed();
    return _indexBuffer;
  }

  void _checkDisposed() {
    if (_isDisposed) {
      throw StateError('FilameshMesh has already been destroyed');
    }
  }

  /// Destroys the renderable entity, vertex buffer, and index buffer in proper engine order.
  void destroy() {
    if (_isDisposed) {
      throw StateError('FilameshMesh has already been destroyed');
    }
    final meshStruct = calloc<c.FilFilamesh>();
    meshStruct.ref.entity = _renderable;
    meshStruct.ref.vertex_buffer = ffi.Pointer.fromAddress(_vertexBuffer);
    meshStruct.ref.index_buffer = ffi.Pointer.fromAddress(_indexBuffer);

    try {
      c.filament_filamesh_destroy(
        _engine.nativePointer,
        meshStruct,
      );
    } finally {
      calloc.free(meshStruct);
    }

    _renderable = 0;
    _vertexBuffer = 0;
    _indexBuffer = 0;
    _isDisposed = true;
  }
}

/// Loads a filamesh model from raw binary [data].
///
/// If [materials] is provided, each submesh will look up its material instance from the registry.
/// Unmatched submeshes fall back to the registry's default material or standard engine fallback.
FilameshMesh? loadMeshFromBuffer(
  FilamentEngine engine,
  Uint8List data, {
  MaterialRegistry? materials,
}) {
  final outStruct = calloc<c.FilFilamesh>();
  final dataPtr = calloc<ffi.Uint8>(data.length);
  dataPtr.asTypedList(data.length).setAll(0, data);

  try {
    final success = c.filament_filamesh_load_with_registry(
      engine.nativePointer,
      dataPtr,
      data.length,
      materials != null ? materials.nativeHandle : ffi.nullptr,
      outStruct,
    );

    if (!success) {
      return null;
    }

    return FilameshMesh._(
      engine: engine,
      renderable: outStruct.ref.entity,
      vertexBuffer: outStruct.ref.vertex_buffer.address,
      indexBuffer: outStruct.ref.index_buffer.address,
    );
  } finally {
    calloc.free(outStruct);
    calloc.free(dataPtr);
  }
}
