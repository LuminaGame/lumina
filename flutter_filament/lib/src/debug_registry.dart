import 'ffi_platform.dart' as ffi;
import 'ffi_package_platform.dart';

import 'package:flutter_filament/src/engine.dart';
import 'package:flutter_filament/src/filament_bindings.dart' as c;

/// Represents a read-only data source returned from [FilamentDebugRegistry.getDataSource].
class DebugDataSource {
  /// Raw pointer to the contiguous data buffer.
  final ffi.Pointer<ffi.Void> data;

  /// Number of elements in the buffer.
  final int count;

  const DebugDataSource({
    required this.data,
    required this.count,
  });
}

/// Mirror of Filament's `DebugRegistry::FrameHistory` struct layout.
class FilamentFrameHistory {
  final double target;
  final double targetWithHeadroom;
  final double frameTime;
  final double frameTimeDenoised;
  final double scale;
  final double pidE;
  final double pidI;
  final double pidD;

  const FilamentFrameHistory({
    required this.target,
    required this.targetWithHeadroom,
    required this.frameTime,
    required this.frameTimeDenoised,
    required this.scale,
    required this.pidE,
    required this.pidI,
    required this.pidD,
  });
}

/// Exposes Filament engine-internal debug switches and telemetry streams as named properties.
///
/// Typical discovered properties include:
/// - `d.shadowmap.focus_shadowcasters` (bool)
/// - `d.shadowmap.far_uses_shadowcasters` (bool)
/// - `d.renderer.doFrameCapture` (bool)
/// - `d.view.camera_at_origin` (bool)
/// - `d.view.pid.kp` (float)
/// - `d.renderer.disable_subpasses` (bool)
///
/// Note: Property names are internal to Filament and subject to change across engine versions.
class FilamentDebugRegistry {
  final ffi.Pointer<ffi.Void> _ptr;
  final FilamentEngine _engine;

  /// Internal constructor.
  FilamentDebugRegistry.internal(this._ptr, this._engine);

  void _checkValid() {
    if (_engine.isDisposed || _ptr == ffi.nullptr) {
      throw StateError('Associated FilamentEngine has been disposed');
    }
  }

  /// Checks if a debug property exists by [name].
  bool hasProperty(String name) {
    _checkValid();
    final namePtr = name.toNativeUtf8();
    try {
      return c.filament_debug_registry_has_property(_ptr, namePtr.cast());
    } finally {
      calloc.free(namePtr);
    }
  }

  /// Sets a boolean property value. Returns false if the property does not exist.
  bool setBool(String name, bool value) {
    _checkValid();
    final namePtr = name.toNativeUtf8();
    try {
      return c.filament_debug_registry_set_property_bool(_ptr, namePtr.cast(), value);
    } finally {
      calloc.free(namePtr);
    }
  }

  /// Gets a boolean property value. Returns null if the property does not exist.
  bool? getBool(String name) {
    _checkValid();
    final namePtr = name.toNativeUtf8();
    final outPtr = calloc<ffi.Bool>();
    try {
      final success = c.filament_debug_registry_get_property_bool(
        _ptr,
        namePtr.cast(),
        outPtr,
      );
      return success ? outPtr.value : null;
    } finally {
      calloc.free(outPtr);
      calloc.free(namePtr);
    }
  }

  /// Sets an integer property value. Returns false if the property does not exist.
  bool setInt(String name, int value) {
    _checkValid();
    final namePtr = name.toNativeUtf8();
    try {
      return c.filament_debug_registry_set_property_int(_ptr, namePtr.cast(), value);
    } finally {
      calloc.free(namePtr);
    }
  }

  /// Gets an integer property value. Returns null if the property does not exist.
  int? getInt(String name) {
    _checkValid();
    final namePtr = name.toNativeUtf8();
    final outPtr = calloc<ffi.Int32>();
    try {
      final success = c.filament_debug_registry_get_property_int(
        _ptr,
        namePtr.cast(),
        outPtr,
      );
      return success ? outPtr.value : null;
    } finally {
      calloc.free(outPtr);
      calloc.free(namePtr);
    }
  }

  /// Sets a float/double property value. Returns false if the property does not exist.
  bool setDouble(String name, double value) {
    _checkValid();
    final namePtr = name.toNativeUtf8();
    try {
      return c.filament_debug_registry_set_property_float(
        _ptr,
        namePtr.cast(),
        value,
      );
    } finally {
      calloc.free(namePtr);
    }
  }

  /// Gets a float/double property value. Returns null if the property does not exist.
  double? getDouble(String name) {
    _checkValid();
    final namePtr = name.toNativeUtf8();
    final outPtr = calloc<ffi.Float>();
    try {
      final success = c.filament_debug_registry_get_property_float(
        _ptr,
        namePtr.cast(),
        outPtr,
      );
      return success ? outPtr.value : null;
    } finally {
      calloc.free(outPtr);
      calloc.free(namePtr);
    }
  }

  /// Sets a 2D vector property value. Returns false if the property does not exist.
  bool setVec2(String name, double x, double y) {
    _checkValid();
    final namePtr = name.toNativeUtf8();
    try {
      return c.filament_debug_registry_set_property_float2(
        _ptr,
        namePtr.cast(),
        x,
        y,
      );
    } finally {
      calloc.free(namePtr);
    }
  }

  /// Gets a 2D vector property value. Returns null if the property does not exist.
  (double, double)? getVec2(String name) {
    _checkValid();
    final namePtr = name.toNativeUtf8();
    final outPtr = calloc<ffi.Float>(2);
    try {
      final success = c.filament_debug_registry_get_property_float2(
        _ptr,
        namePtr.cast(),
        outPtr,
      );
      return success ? (outPtr[0], outPtr[1]) : null;
    } finally {
      calloc.free(outPtr);
      calloc.free(namePtr);
    }
  }

  /// Sets a 3D vector property value. Returns false if the property does not exist.
  bool setVec3(String name, double x, double y, double z) {
    _checkValid();
    final namePtr = name.toNativeUtf8();
    try {
      return c.filament_debug_registry_set_property_float3(
        _ptr,
        namePtr.cast(),
        x,
        y,
        z,
      );
    } finally {
      calloc.free(namePtr);
    }
  }

  /// Gets a 3D vector property value. Returns null if the property does not exist.
  (double, double, double)? getVec3(String name) {
    _checkValid();
    final namePtr = name.toNativeUtf8();
    final outPtr = calloc<ffi.Float>(3);
    try {
      final success = c.filament_debug_registry_get_property_float3(
        _ptr,
        namePtr.cast(),
        outPtr,
      );
      return success ? (outPtr[0], outPtr[1], outPtr[2]) : null;
    } finally {
      calloc.free(outPtr);
      calloc.free(namePtr);
    }
  }

  /// Sets a 4D vector property value. Returns false if the property does not exist.
  bool setVec4(String name, double x, double y, double z, double w) {
    _checkValid();
    final namePtr = name.toNativeUtf8();
    try {
      return c.filament_debug_registry_set_property_float4(
        _ptr,
        namePtr.cast(),
        x,
        y,
        z,
        w,
      );
    } finally {
      calloc.free(namePtr);
    }
  }

  /// Gets a 4D vector property value. Returns null if the property does not exist.
  (double, double, double, double)? getVec4(String name) {
    _checkValid();
    final namePtr = name.toNativeUtf8();
    final outPtr = calloc<ffi.Float>(4);
    try {
      final success = c.filament_debug_registry_get_property_float4(
        _ptr,
        namePtr.cast(),
        outPtr,
      );
      return success ? (outPtr[0], outPtr[1], outPtr[2], outPtr[3]) : null;
    } finally {
      calloc.free(outPtr);
      calloc.free(namePtr);
    }
  }

  /// Queries a continuous debug data source buffer. Returns null if not registered.
  DebugDataSource? getDataSource(String name) {
    _checkValid();
    final namePtr = name.toNativeUtf8();
    final outData = calloc<ffi.Pointer<ffi.Void>>();
    final outCount = calloc<ffi.Uint32>();
    try {
      final success = c.filament_debug_registry_get_data_source(
        _ptr,
        namePtr.cast(),
        outData.cast(),
        outCount,
      );
      if (!success || outData.value == ffi.nullptr) {
        return null;
      }
      return DebugDataSource(data: outData.value, count: outCount.value);
    } finally {
      calloc.free(outCount);
      calloc.free(outData);
      calloc.free(namePtr);
    }
  }
}
