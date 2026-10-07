import 'dart:typed_data';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:lumina/src/material/lumina_material.dart';

/// Wrapped instance of a [LuminaMaterial] assigned to mesh renderables.
class LuminaMaterialInstance {
  final FilamentMaterialInstance _nativeInstance;
  final LuminaMaterial material;
  final bool isDefaultInstance;
  bool _disposed = false;

  /// Internal constructor for [LuminaMaterial] and subclasses.
  LuminaMaterialInstance.internal(
    this._nativeInstance,
    this.material, {
    this.isDefaultInstance = false,
  });

  /// The underlying native Filament material instance.
  FilamentMaterialInstance get nativeInstance {
    _checkDisposed();
    return _nativeInstance;
  }

  /// The name of this material instance.
  String get name {
    _checkDisposed();
    return _nativeInstance.name;
  }

  /// Whether this instance has been disposed.
  bool get isDisposed => _disposed || _nativeInstance.isDisposed;

  void _checkDisposed() {
    if (isDisposed) {
      throw StateError('LuminaMaterialInstance has been disposed');
    }
  }

  void _validateParameterType(String name, UniformType expectedType) {
    if (!material.hasParameter(name)) {
      throw ArgumentError('Material "${material.name}" does not declare parameter "$name"');
    }
    final param = material.parameters.firstWhere((p) => p.name == name);
    if (param.isSampler || param.uniformType != expectedType) {
      throw ArgumentError(
        'Parameter "$name" has uniform type ${param.uniformType}, cannot read as $expectedType',
      );
    }
  }

  /// Reads a float parameter value with reflection type validation.
  double getFloat(String name) {
    _checkDisposed();
    _validateParameterType(name, UniformType.float_);
    return _nativeInstance.getFloat(name);
  }

  /// Reads a 4-component vector parameter value with reflection type validation.
  Vector4 getFloat4(String name) {
    _checkDisposed();
    _validateParameterType(name, UniformType.float4);
    final (x, y, z, w) = _nativeInstance.getFloat4(name);
    return Vector4(x, y, z, w);
  }

  /// Reads an integer parameter value with reflection type validation.
  int getInt(String name) {
    _checkDisposed();
    _validateParameterType(name, UniformType.int_);
    return _nativeInstance.getInt(name);
  }

  /// Reads a boolean parameter value with reflection type validation.
  bool getBool(String name) {
    _checkDisposed();
    _validateParameterType(name, UniformType.bool_);
    return _nativeInstance.getBool(name);
  }

  /// Reads a 4x4 matrix parameter value with reflection type validation.
  Float32List getMat4(String name) {
    _checkDisposed();
    _validateParameterType(name, UniformType.mat4);
    return _nativeInstance.getMat4(name);
  }

  /// Sets a float parameter value.
  void setFloat(String name, double value) {
    _checkDisposed();
    _validateParameterType(name, UniformType.float_);
    _nativeInstance.setFloat(name, value);
  }

  /// Sets a 4-component float parameter value.
  void setFloat4(String name, Vector4 value) {
    _checkDisposed();
    _validateParameterType(name, UniformType.float4);
    _nativeInstance.setFloat4(name, value.x, value.y, value.z, value.w);
  }

  /// Sets an integer parameter value.
  void setInt(String name, int value) {
    _checkDisposed();
    _validateParameterType(name, UniformType.int_);
    _nativeInstance.setInt(name, value);
  }

  /// Sets a boolean parameter value.
  void setBool(String name, bool value) {
    _checkDisposed();
    _validateParameterType(name, UniformType.bool_);
    _nativeInstance.setBool(name, value);
  }

  /// Destroys this material instance and notifies parent material.
  void dispose() {
    if (isDefaultInstance) {
      throw StateError('Cannot dispose default instance of LuminaMaterial');
    }
    if (_disposed) return;
    _disposed = true;
    material.onInstanceDisposed(this);
    _nativeInstance.dispose();
  }

  /// Internal destruction when parent material is destroyed.
  void internalDispose() {
    if (_disposed) return;
    _disposed = true;
    _nativeInstance.dispose();
  }
}
