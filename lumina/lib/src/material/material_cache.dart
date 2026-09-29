import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_filament/flutter_filament.dart';
import '../utility/lumina_assets.dart';
import '../world/world.dart';
import 'lumina_material.dart';

class _MaterialCacheKey {
  final String assetPath;
  final List<MaterialConstant> constants;

  _MaterialCacheKey(this.assetPath, this.constants);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! _MaterialCacheKey || other.assetPath != assetPath) return false;
    if (other.constants.length != constants.length) return false;
    for (int i = 0; i < constants.length; i++) {
      if (other.constants[i].name != constants[i].name) return false;
    }
    return true;
  }

  @override
  int get hashCode {
    var h = assetPath.hashCode;
    for (final c in constants) {
      h ^= c.name.hashCode;
    }
    return h;
  }
}

/// Refcounted cache of compiled [LuminaMaterial] assets for a world.
class LuminaMaterialCache {
  final LuminaWorld world;
  final FilamentEngine engine;
  final Map<_MaterialCacheKey, LuminaMaterial> _entries = {};
  final Map<_MaterialCacheKey, Future<LuminaMaterial>> _inFlight = {};
  bool _disposed = false;

  LuminaMaterialCache({required this.world, required this.engine});

  /// Loads or retrieves a cached [LuminaMaterial].
  Future<LuminaMaterial> load(
    LuminaWorld world,
    String assetPath, {
    List<MaterialConstant> constants = const [],
    Future<Uint8List> Function(String path)? assetProvider,
  }) async {
    if (_disposed) {
      throw StateError('LuminaMaterialCache has been disposed');
    }

    final key = _MaterialCacheKey(assetPath, constants);
    final existing = _entries[key];
    if (existing != null) {
      existing.addRef();
      return existing;
    }

    if (_inFlight.containsKey(key)) {
      final mat = await _inFlight[key]!;
      mat.addRef();
      return mat;
    }

    final future = _loadInternal(key, assetPath, constants, assetProvider);
    _inFlight[key] = future;
    try {
      final mat = await future;
      _entries[key] = mat;
      return mat;
    } finally {
      _inFlight.remove(key);
    }
  }

  Future<LuminaMaterial> _loadInternal(
    _MaterialCacheKey key,
    String assetPath,
    List<MaterialConstant> constants,
    Future<Uint8List> Function(String path)? assetProvider,
  ) async {
    final bytes = await LuminaAssets.resolve(assetProvider)(assetPath);

    final nativeMat = FilamentMaterial.fromBuffer(
      engine: engine,
      filamatBuffer: bytes,
      constants: constants,
    );

    return LuminaMaterial.internal(
      nativeMat,
      assetPath: assetPath,
      constants: constants,
      cache: this,
    );
  }

  /// Internal callback when material refcount drops to zero.
  void onMaterialReleased(LuminaMaterial material) {
    _entries.removeWhere((_, v) => identical(v, material));
  }

  /// Disposes all cached materials.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    final mats = _entries.values.toList();
    for (final mat in mats) {
      mat.forceDestroy();
    }
    _entries.clear();
    _inFlight.clear();
  }
}
