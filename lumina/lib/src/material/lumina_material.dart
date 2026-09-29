import 'dart:typed_data';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:vector_math/vector_math_64.dart';
import '../world/world.dart';
import 'lumina_material_instance.dart';
import 'material_cache.dart';

/// Asset-level wrapper around a compiled Filament material (.filamat) package.
class LuminaMaterial {
  final FilamentMaterial _nativeMaterial;
  final String assetPath;
  final List<MaterialConstant> constants;
  final LuminaMaterialCache _cache;

  int _refCount = 1;
  int _instanceCounter = 1;
  final Set<LuminaMaterialInstance> _mintedInstances = {};
  LuminaMaterialInstance? _defaultInstance;
  List<MaterialParameter>? _cachedParams;
  bool _released = false;
  bool _disposed = false;

  LuminaMaterial._(
    this._nativeMaterial,
    this._cache, {
    required this.assetPath,
    required this.constants,
  });

  /// Internal constructor.
  factory LuminaMaterial.internal(
    FilamentMaterial nativeMaterial, {
    required String assetPath,
    required List<MaterialConstant> constants,
    required LuminaMaterialCache cache,
  }) =>
      LuminaMaterial._(
        nativeMaterial,
        cache,
        assetPath: assetPath,
        constants: constants,
      );

  /// Loads a [LuminaMaterial] via [world.materialCache].
  static Future<LuminaMaterial> load(
    LuminaWorld world,
    String assetPath, {
    List<MaterialConstant> constants = const [],
    Future<Uint8List> Function(String path)? assetProvider,
  }) {
    return world.materialCache.load(
      world,
      assetPath,
      constants: constants,
      assetProvider: assetProvider,
    );
  }

  /// The underlying native [FilamentMaterial].
  FilamentMaterial get nativeMaterial {
    _checkDisposed();
    return _nativeMaterial;
  }

  /// The owning [LuminaWorld].
  LuminaWorld get world => _cache.world;

  /// Whether this material asset has been disposed.
  bool get isDisposed => _disposed;

  void _checkDisposed() {
    if (_disposed) {
      throw StateError('LuminaMaterial has been disposed');
    }
  }

  /// Total number of parameters declared on this material.
  int get parameterCount {
    _checkDisposed();
    return _nativeMaterial.parameterCount;
  }

  /// Cached list of reflected material parameters.
  List<MaterialParameter> get parameters {
    _checkDisposed();
    return _cachedParams ??= _nativeMaterial.parameters;
  }

  /// Checks whether this material declares parameter [name].
  bool hasParameter(String name) {
    _checkDisposed();
    return _nativeMaterial.hasParameter(name);
  }

  /// Checks whether parameter [name] is a sampler texture parameter.
  bool isSampler(String name) {
    _checkDisposed();
    return _nativeMaterial.isSampler(name);
  }

  /// Name embedded in the material package.
  String? get name {
    _checkDisposed();
    return _nativeMaterial.name;
  }

  /// Shading model of this material.
  FilamatShading get shading {
    _checkDisposed();
    return _nativeMaterial.shading;
  }

  /// Blending mode of this material.
  BlendingMode get blendingMode {
    _checkDisposed();
    return _nativeMaterial.blendingMode;
  }

  /// Default culling mode of this material.
  CullingMode get cullingMode {
    _checkDisposed();
    return _nativeMaterial.cullingMode;
  }

  /// Whether this material is double-sided.
  bool get isDoubleSided {
    _checkDisposed();
    return _nativeMaterial.isDoubleSided;
  }

  /// Mask threshold alpha cutoff value.
  double get maskThreshold {
    _checkDisposed();
    return _nativeMaterial.maskThreshold;
  }

  /// Material domain of this material.
  MaterialDomain get materialDomain {
    _checkDisposed();
    return _nativeMaterial.materialDomain;
  }

  /// Creates a new named [LuminaMaterialInstance].
  LuminaMaterialInstance createInstance({String? name}) {
    _checkDisposed();
    final instanceName = name ?? '$assetPath#${_instanceCounter++}';
    final nativeInst = _nativeMaterial.createInstance(instanceName);
    final instance = LuminaMaterialInstance.internal(nativeInst, this);
    _mintedInstances.add(instance);
    return instance;
  }

  /// Returns the cached, non-destroyable default instance of this material.
  LuminaMaterialInstance get defaultInstance {
    _checkDisposed();
    return _defaultInstance ??= LuminaMaterialInstance.internal(
      _nativeMaterial.defaultInstance,
      this,
      isDefaultInstance: true,
    );
  }

  void _validateParameter(String paramName, UniformType expectedType) {
    if (!hasParameter(paramName)) {
      throw ArgumentError('Material does not declare parameter "$paramName"');
    }
    final param = parameters.firstWhere((p) => p.name == paramName);
    if (param.isSampler || param.uniformType != expectedType) {
      throw ArgumentError(
        'Parameter "$paramName" has uniform type ${param.uniformType}, cannot set as $expectedType',
      );
    }
  }

  /// Sets default float parameter value on this material.
  void setDefaultParameterFloat(String name, double value) {
    _checkDisposed();
    _validateParameter(name, UniformType.float_);
    _nativeMaterial.setDefaultParameterFloat(name, value);
  }

  /// Sets default 4-component float parameter value on this material.
  void setDefaultParameterFloat4(String name, Vector4 value) {
    _checkDisposed();
    _validateParameter(name, UniformType.float4);
    _nativeMaterial.setDefaultParameterFloat4(name, value.x, value.y, value.z, value.w);
  }

  /// Sets default RGB color on this material.
  void setDefaultColor(String name, RgbType type, (double, double, double) color) {
    _checkDisposed();
    _validateParameter(name, UniformType.float3);
    _nativeMaterial.setDefaultColor(name, type, color);
  }

  /// Asynchronously compiles shader variants.
  Future<void> preWarm({
    CompilerPriorityQueue priority = CompilerPriorityQueue.low,
  }) {
    _checkDisposed();
    return _nativeMaterial.compile(priority: priority);
  }

  /// Increments the reference count.
  void addRef() {
    _refCount++;
  }

  /// Internal callback when an instance is disposed.
  void onInstanceDisposed(LuminaMaterialInstance instance) {
    _mintedInstances.remove(instance);
    if (_released && _refCount <= 0 && _mintedInstances.isEmpty) {
      _destroyNative();
    }
  }

  /// Decrements reference count and frees material when all references and instances are released.
  void release() {
    if (_released) return;
    _refCount--;
    if (_refCount <= 0) {
      _released = true;
      _cache.onMaterialReleased(this);
      if (_mintedInstances.isEmpty) {
        _destroyNative();
      }
    }
  }

  /// Force-destroys this material and all instances during cache teardown.
  void forceDestroy() {
    _destroyNative();
  }

  void _destroyNative() {
    if (_disposed) return;
    _disposed = true;
    _mintedInstances.clear();
    _defaultInstance = null;
    _nativeMaterial.dispose();
  }
}
