part of '../material.dart';

/// An instance of a [FilamentMaterial] with its own parameter values.
class FilamentMaterialInstance with _MaterialInstanceRenderState {
  @override
  final ffi.Pointer<ffi.Void> _ptr;
  final FilamentEngine _engine;
  final FilamentMaterial? _parentMaterial;
  final bool _borrowed;
  bool _disposed = false;

  /// Internal constructor.
  FilamentMaterialInstance.internal(this._ptr, this._engine, [this._parentMaterial, this._borrowed = false]);

  /// The raw native pointer.
  ffi.Pointer<ffi.Void> get nativePointer {
    _checkDisposed();
    return _ptr;
  }

  /// Duplicates this instance, creating an independent instance sharing the same parent Material.
  FilamentMaterialInstance duplicate({String? name}) {
    _checkDisposed();
    final ffi.Pointer<ffi.Void> newPtr;
    if (name != null) {
      final nativeName = name.toNativeUtf8();
      newPtr = c.filament_material_instance_duplicate(_ptr, nativeName.cast());
      calloc.free(nativeName);
    } else {
      newPtr = c.filament_material_instance_duplicate(_ptr, ffi.nullptr);
    }
    if (newPtr == ffi.nullptr) {
      throw StateError('Failed to duplicate MaterialInstance');
    }
    final instance = FilamentMaterialInstance.internal(newPtr, _engine, _parentMaterial);
    _parentMaterial?._instances.add(instance);
    return instance;
  }


  /// Sets a boolean parameter value.
  void setBool(String name, bool value) {
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    c.filament_material_instance_set_bool(_ptr, nativeName.cast(), value);
    calloc.free(nativeName);
  }

  /// Sets a 2-component boolean vector parameter value.
  void setBool2(String name, bool x, bool y) {
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    final ptr = calloc<ffi.Bool>(2);
    ptr[0] = x; ptr[1] = y;
    c.filament_material_instance_set_bool2(_ptr, nativeName.cast(), ptr);
    calloc.free(ptr);
    calloc.free(nativeName);
  }

  /// Sets a 3-component boolean vector parameter value.
  void setBool3(String name, bool x, bool y, bool z) {
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    final ptr = calloc<ffi.Bool>(3);
    ptr[0] = x; ptr[1] = y; ptr[2] = z;
    c.filament_material_instance_set_bool3(_ptr, nativeName.cast(), ptr);
    calloc.free(ptr);
    calloc.free(nativeName);
  }

  /// Sets a 4-component boolean vector parameter value.
  void setBool4(String name, bool x, bool y, bool z, bool w) {
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    final ptr = calloc<ffi.Bool>(4);
    ptr[0] = x; ptr[1] = y; ptr[2] = z; ptr[3] = w;
    c.filament_material_instance_set_bool4(_ptr, nativeName.cast(), ptr);
    calloc.free(ptr);
    calloc.free(nativeName);
  }

  /// Sets an integer parameter value.
  void setInt(String name, int value) {
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    c.filament_material_instance_set_int(_ptr, nativeName.cast(), value);
    calloc.free(nativeName);
  }

  /// Sets a 2-component integer vector parameter value.
  void setInt2(String name, int x, int y) {
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    c.filament_material_instance_set_int2(_ptr, nativeName.cast(), x, y);
    calloc.free(nativeName);
  }

  /// Sets a 3-component integer vector parameter value.
  void setInt3(String name, int x, int y, int z) {
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    c.filament_material_instance_set_int3(_ptr, nativeName.cast(), x, y, z);
    calloc.free(nativeName);
  }

  /// Sets a 4-component integer vector parameter value.
  void setInt4(String name, int x, int y, int z, int w) {
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    c.filament_material_instance_set_int4(_ptr, nativeName.cast(), x, y, z, w);
    calloc.free(nativeName);
  }

  /// Sets a unsigned integer parameter value.
  void setUint(String name, int value) {
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    c.filament_material_instance_set_uint(_ptr, nativeName.cast(), value);
    calloc.free(nativeName);
  }

  /// Sets a 2-component unsigned integer vector parameter value.
  void setUint2(String name, int x, int y) {
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    final ptr = calloc<ffi.Uint32>(2);
    ptr[0] = x; ptr[1] = y;
    c.filament_material_instance_set_uint2(_ptr, nativeName.cast(), ptr);
    calloc.free(ptr);
    calloc.free(nativeName);
  }

  /// Sets a 3-component unsigned integer vector parameter value.
  void setUint3(String name, int x, int y, int z) {
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    final ptr = calloc<ffi.Uint32>(3);
    ptr[0] = x; ptr[1] = y; ptr[2] = z;
    c.filament_material_instance_set_uint3(_ptr, nativeName.cast(), ptr);
    calloc.free(ptr);
    calloc.free(nativeName);
  }

  /// Sets a 4-component unsigned integer vector parameter value.
  void setUint4(String name, int x, int y, int z, int w) {
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    final ptr = calloc<ffi.Uint32>(4);
    ptr[0] = x; ptr[1] = y; ptr[2] = z; ptr[3] = w;
    c.filament_material_instance_set_uint4(_ptr, nativeName.cast(), ptr);
    calloc.free(ptr);
    calloc.free(nativeName);
  }

  /// Sets a scalar float parameter value.
  void setFloat(String name, double value) {
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    c.filament_material_instance_set_float(_ptr, nativeName.cast(), value);
    calloc.free(nativeName);
  }

  /// Sets a 2-component vector parameter value.
  void setFloat2(String name, double x, double y) {
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    c.filament_material_instance_set_float2(_ptr, nativeName.cast(), x, y);
    calloc.free(nativeName);
  }

  /// Sets a 3-component vector parameter value.
  void setFloat3(String name, double x, double y, double z) {
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    c.filament_material_instance_set_float3(_ptr, nativeName.cast(), x, y, z);
    calloc.free(nativeName);
  }

  /// Sets a 4-component vector / color parameter value.
  void setFloat4(String name, double x, double y, double z, double w) {
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    c.filament_material_instance_set_float4(
      _ptr,
      nativeName.cast(),
      x,
      y,
      z,
      w,
    );
    calloc.free(nativeName);
  }

  /// Sets an array of float parameters.
  void setFloatArray(String name, Float32List values) {
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    final ptr = calloc<ffi.Float>(values.length);
    ptr.asTypedList(values.length).setAll(0, values);
    c.filament_material_instance_set_float_array(_ptr, nativeName.cast(), ptr, values.length);
    calloc.free(ptr);
    calloc.free(nativeName);
  }

  /// Sets an array of float2 parameters.
  void setFloat2Array(String name, Float32List values) {
    if (values.length % 2 != 0) throw ArgumentError('values length must be a multiple of 2');
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    final ptr = calloc<ffi.Float>(values.length);
    ptr.asTypedList(values.length).setAll(0, values);
    c.filament_material_instance_set_float2_array(_ptr, nativeName.cast(), ptr, values.length ~/ 2);
    calloc.free(ptr);
    calloc.free(nativeName);
  }

  /// Sets an array of float3 parameters. Note: expected 3 floats (12 bytes) per element.
  void setFloat3Array(String name, Float32List values) {
    if (values.length % 3 != 0) throw ArgumentError('values length must be a multiple of 3');
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    final ptr = calloc<ffi.Float>(values.length);
    ptr.asTypedList(values.length).setAll(0, values);
    c.filament_material_instance_set_float3_array(_ptr, nativeName.cast(), ptr, values.length ~/ 3);
    calloc.free(ptr);
    calloc.free(nativeName);
  }

  /// Sets an array of float4 parameters.
  void setFloat4Array(String name, Float32List values) {
    if (values.length % 4 != 0) throw ArgumentError('values length must be a multiple of 4');
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    final ptr = calloc<ffi.Float>(values.length);
    ptr.asTypedList(values.length).setAll(0, values);
    c.filament_material_instance_set_float4_array(_ptr, nativeName.cast(), ptr, values.length ~/ 4);
    calloc.free(ptr);
    calloc.free(nativeName);
  }

  /// Sets an array of int parameters.
  void setIntArray(String name, Int32List values) {
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    final ptr = calloc<ffi.Int32>(values.length);
    ptr.asTypedList(values.length).setAll(0, values);
    c.filament_material_instance_set_int_array(_ptr, nativeName.cast(), ptr, values.length);
    calloc.free(ptr);
    calloc.free(nativeName);
  }

  /// Sets a 3x3 matrix parameter value (9 floats column-major).
  void setMat3(String name, List<double> matrix9) {
    if (matrix9.length != 9) {
      throw ArgumentError('matrix9 must contain exactly 9 elements');
    }
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    final ptr = calloc<ffi.Float>(9);
    for (var i = 0; i < 9; i++) {
      ptr[i] = matrix9[i];
    }
    c.filament_material_instance_set_mat3(_ptr, nativeName.cast(), ptr);
    calloc.free(ptr);
    calloc.free(nativeName);
  }

  /// Sets a 4x4 matrix parameter value (16 floats column-major).
  void setMat4(String name, List<double> matrix16) {
    if (matrix16.length != 16) {
      throw ArgumentError('Matrix must contain 16 elements');
    }
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    final ptr = calloc<ffi.Float>(16);
    for (var i = 0; i < 16; i++) {
      ptr[i] = matrix16[i];
    }
    c.filament_material_instance_set_mat4(
      _ptr,
      nativeName.cast(),
      ptr,
    );
    calloc.free(ptr);
    calloc.free(nativeName);
  }

  /// Sets an array of mat3 parameters (9 floats per matrix).
  void setMat3Array(String name, Float32List values) {
    if (values.length % 9 != 0) throw ArgumentError('values length must be a multiple of 9');
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    final ptr = calloc<ffi.Float>(values.length);
    ptr.asTypedList(values.length).setAll(0, values);
    c.filament_material_instance_set_mat3_array(_ptr, nativeName.cast(), ptr, values.length ~/ 9);
    calloc.free(ptr);
    calloc.free(nativeName);
  }

  /// Sets an array of mat4 parameters (16 floats per matrix, e.g. for bone palettes).
  void setMat4Array(String name, Float32List values) {
    if (values.length % 16 != 0) throw ArgumentError('values length must be a multiple of 16');
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    final ptr = calloc<ffi.Float>(values.length);
    ptr.asTypedList(values.length).setAll(0, values);
    c.filament_material_instance_set_mat4_array(_ptr, nativeName.cast(), ptr, values.length ~/ 16);
    calloc.free(ptr);
    calloc.free(nativeName);
  }

  /// Sets a color parameter using a specific RGB color space.
  void setColor(String name, RgbType type, double r, double g, double b) {
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    c.filament_material_instance_set_rgb(_ptr, nativeName.cast(), type.index, r, g, b);
    calloc.free(nativeName);
  }

  /// Sets a color parameter using a specific RGBA color space.
  void setColorRgba(String name, RgbaType type, double r, double g, double b, double a) {
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    c.filament_material_instance_set_rgba(_ptr, nativeName.cast(), type.index, r, g, b, a);
    calloc.free(nativeName);
  }

  /// Sets a Texture sampler parameter with optional [sampler] filter and wrap settings.
  void setTexture(
    String name,
    dynamic texture, {
    TextureSampler sampler = const TextureSampler(),
  }) {
    _checkDisposed();
    final ffi.Pointer<ffi.Void> texPtr;
    if (texture is FilamentTexture) {
      texPtr = texture.nativePointer;
    } else if (texture is ffi.Pointer<ffi.Void>) {
      texPtr = texture;
    } else {
      throw ArgumentError.value(
        texture,
        'texture',
        'Expected FilamentTexture or Pointer<Void>',
      );
    }

    final nativeName = name.toNativeUtf8();
    c.filament_material_instance_set_texture_ex(
      _ptr,
      nativeName.cast(),
      texPtr,
      sampler.packed,
    );
    calloc.free(nativeName);
  }

  /// Sets a specialization constant of integer type.
  void setConstantInt(String name, int value) {
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    try {
      c.filament_material_instance_set_constant_int(_ptr, nativeName.cast(), value);
    } finally {
      calloc.free(nativeName);
    }
  }

  /// Sets a specialization constant of float type.
  void setConstantFloat(String name, double value) {
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    try {
      c.filament_material_instance_set_constant_float(_ptr, nativeName.cast(), value);
    } finally {
      calloc.free(nativeName);
    }
  }

  /// Sets a specialization constant of boolean type.
  void setConstantBool(String name, bool value) {
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    try {
      c.filament_material_instance_set_constant_bool(_ptr, nativeName.cast(), value);
    } finally {
      calloc.free(nativeName);
    }
  }

  /// Reads a float parameter value.
  double getFloat(String name) {
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    try {
      return c.filament_material_instance_get_parameter_float(_ptr, nativeName.cast());
    } finally {
      calloc.free(nativeName);
    }
  }

  /// Reads a 2-component float parameter value.
  (double, double) getFloat2(String name) {
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    final ptr = calloc<ffi.Float>(2);
    try {
      c.filament_material_instance_get_parameter_float2(_ptr, nativeName.cast(), ptr);
      return (ptr[0], ptr[1]);
    } finally {
      calloc.free(ptr);
      calloc.free(nativeName);
    }
  }

  /// Reads a 3-component float parameter value.
  (double, double, double) getFloat3(String name) {
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    final ptr = calloc<ffi.Float>(3);
    try {
      c.filament_material_instance_get_parameter_float3(_ptr, nativeName.cast(), ptr);
      return (ptr[0], ptr[1], ptr[2]);
    } finally {
      calloc.free(ptr);
      calloc.free(nativeName);
    }
  }

  /// Reads a 4-component float parameter value.
  (double, double, double, double) getFloat4(String name) {
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    final ptr = calloc<ffi.Float>(4);
    try {
      c.filament_material_instance_get_parameter_float4(_ptr, nativeName.cast(), ptr);
      return (ptr[0], ptr[1], ptr[2], ptr[3]);
    } finally {
      calloc.free(ptr);
      calloc.free(nativeName);
    }
  }

  /// Reads an integer parameter value.
  int getInt(String name) {
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    try {
      return c.filament_material_instance_get_parameter_int(_ptr, nativeName.cast());
    } finally {
      calloc.free(nativeName);
    }
  }

  /// Reads a 2-component integer parameter value.
  (int, int) getInt2(String name) {
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    final ptr = calloc<ffi.Int32>(2);
    try {
      c.filament_material_instance_get_parameter_int2(_ptr, nativeName.cast(), ptr);
      return (ptr[0], ptr[1]);
    } finally {
      calloc.free(ptr);
      calloc.free(nativeName);
    }
  }

  /// Reads a 3-component integer parameter value.
  (int, int, int) getInt3(String name) {
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    final ptr = calloc<ffi.Int32>(3);
    try {
      c.filament_material_instance_get_parameter_int3(_ptr, nativeName.cast(), ptr);
      return (ptr[0], ptr[1], ptr[2]);
    } finally {
      calloc.free(ptr);
      calloc.free(nativeName);
    }
  }

  /// Reads a 4-component integer parameter value.
  (int, int, int, int) getInt4(String name) {
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    final ptr = calloc<ffi.Int32>(4);
    try {
      c.filament_material_instance_get_parameter_int4(_ptr, nativeName.cast(), ptr);
      return (ptr[0], ptr[1], ptr[2], ptr[3]);
    } finally {
      calloc.free(ptr);
      calloc.free(nativeName);
    }
  }

  /// Reads an unsigned integer parameter value.
  int getUint(String name) {
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    try {
      return c.filament_material_instance_get_parameter_uint(_ptr, nativeName.cast());
    } finally {
      calloc.free(nativeName);
    }
  }

  /// Reads a boolean parameter value.
  bool getBool(String name) {
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    try {
      return c.filament_material_instance_get_parameter_bool(_ptr, nativeName.cast());
    } finally {
      calloc.free(nativeName);
    }
  }

  /// Reads a 4x4 float matrix parameter value.
  Float32List getMat4(String name) {
    _checkDisposed();
    final nativeName = name.toNativeUtf8();
    final ptr = calloc<ffi.Float>(16);
    try {
      c.filament_material_instance_get_parameter_mat4(_ptr, nativeName.cast(), ptr);
      final list = Float32List(16);
      for (int i = 0; i < 16; i++) {
        list[i] = ptr[i];
      }
      return list;
    } finally {
      calloc.free(ptr);
      calloc.free(nativeName);
    }
  }

  /// The parent [FilamentMaterial] of this instance.
  FilamentMaterial get material {
    _checkDisposed();
    if (_parentMaterial != null) return _parentMaterial;
    final matPtr = c.filament_material_instance_get_material(_ptr);
    return FilamentMaterial.internal(matPtr, _engine);
  }

  /// The name of this material instance.
  String get name {
    _checkDisposed();
    final ptr = c.filament_material_instance_get_name(_ptr);
    if (ptr == ffi.nullptr) return '';
    return ptr.cast<Utf8>().toDartString();
  }

  /// Sets the specular anti-aliasing variance.
  void setSpecularAntiAliasingVariance(double variance) {
    _checkDisposed();
    c.filament_material_instance_set_specular_antialiasing_variance(_ptr, variance);
  }

  /// Gets the specular anti-aliasing variance.
  double get specularAntiAliasingVariance {
    _checkDisposed();
    return c.filament_material_instance_get_specular_antialiasing_variance(_ptr);
  }

  /// Sets the specular anti-aliasing threshold.
  void setSpecularAntiAliasingThreshold(double threshold) {
    _checkDisposed();
    c.filament_material_instance_set_specular_antialiasing_threshold(_ptr, threshold);
  }

  /// Gets the specular anti-aliasing threshold.
  double get specularAntiAliasingThreshold {
    _checkDisposed();
    return c.filament_material_instance_get_specular_antialiasing_threshold(_ptr);
  }

  /// Destroys this MaterialInstance.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _parentMaterial?._instances.remove(this);
    if (!_borrowed) {
      c.filament_engine_destroy_material_instance(_engine.nativePointer, _ptr);
    }
  }

  bool get isDisposed => _disposed;

  @override
  void _checkDisposed() {
    if (_disposed) {
      throw StateError('FilamentMaterialInstance has been disposed');
    }
  }
}
