import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_filament/flutter_filament.dart';
import '../../data/models/lumina_asset.dart';
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
    final nativeMat = createNative(engine, assetPath, bytes, constants: constants);

    return LuminaMaterial.internal(
      nativeMat,
      assetPath: assetPath,
      constants: constants,
      cache: this,
    );
  }

  /// A native material from [bytes], the content of [assetPath]: a material
  /// `.lmas` (its compiled package, with the parameter values the Material
  /// Editor saved as the defaults every instance starts with) or a `.filamat`
  /// package. Throws a [StateError] when they hold no compiled material.
  static FilamentMaterial createNative(
    FilamentEngine engine,
    String assetPath,
    Uint8List bytes, {
    List<MaterialConstant> constants = const [],
  }) {
    var package = bytes;
    var values = const <String, Object?>{};
    // A material asset: the compiled package is its payload, the values the
    // Material Editor saved are its instances' starting parameters.
    if (assetPath.toLowerCase().endsWith('.lmas')) {
      final asset = LuminaAsset.fromBytes(bytes);
      final payload = asset.rawPayload;
      if (payload == null || !isCompiledPackage(payload)) {
        throw StateError('$assetPath carries no compiled material');
      }
      package = payload;
      values = _savedParameters(asset);
    } else if (!isCompiledPackage(bytes)) {
      throw StateError('$assetPath is not a compiled material');
    }
    final material = FilamentMaterial.fromBuffer(engine: engine, filamatBuffer: package, constants: constants);
    _setDefaults(material, values);
    return material;
  }

  /// Whether [bytes] is a compiled `.filamat` package (a `MAT_VERS` chunk of
  /// size 4): Filament aborts the process on anything else.
  static bool isCompiledPackage(Uint8List bytes) {
    const magic = [0x53, 0x52, 0x45, 0x56, 0x5F, 0x54, 0x41, 0x4D];
    if (bytes.length < 16) return false;
    for (var i = 0; i < magic.length; i++) {
      if (bytes[i] != magic[i]) return false;
    }
    return ByteData.view(bytes.buffer, bytes.offsetInBytes + 8, 4).getUint32(0, Endian.little) == 4;
  }

  /// The parameter values the Material Editor saved on [asset]
  /// (`metadata.parameter_defaults`).
  static Map<String, Object?> _savedParameters(LuminaAsset asset) {
    final saved = asset.metadata['parameter_defaults'];
    if (saved == null || saved.isEmpty) return const {};
    try {
      final decoded = jsonDecode(saved);
      if (decoded is Map) return {for (final e in decoded.entries) e.key.toString(): e.value};
    } catch (_) {}
    return const {};
  }

  /// Makes [values] the defaults every instance of [material] starts with
  /// (instances are copies of the default instance). Values that match no
  /// declared scalar or vector parameter are ignored.
  static void _setDefaults(FilamentMaterial material, Map<String, Object?> values) {
    if (values.isEmpty) return;
    final declared = {for (final p in material.parameters) p.name: p};
    values.forEach((name, value) {
      final p = declared[name];
      if (p == null || p.isSampler || p.count > 1) return;
      final n = value is num
          ? [value.toDouble()]
          : value is List
              ? [for (final v in value) if (v is num) v.toDouble()]
              : const <double>[];
      switch (p.uniformType) {
        case UniformType.floatType when n.isNotEmpty:
          material.setDefaultParameterFloat(name, n[0]);
        case UniformType.float2 when n.length >= 2:
          material.setDefaultParameterFloat2(name, n[0], n[1]);
        case UniformType.float3 when n.length >= 3:
          material.setDefaultParameterFloat3(name, n[0], n[1], n[2]);
        case UniformType.float4 when n.length >= 3:
          material.setDefaultParameterFloat4(name, n[0], n[1], n[2], n.length > 3 ? n[3] : 1.0);
        case UniformType.intType when n.isNotEmpty:
          material.setDefaultParameterInt(name, n[0].toInt());
        case UniformType.boolType when value is bool:
          material.setDefaultParameterBool(name, value);
        default:
          break;
      }
    });
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
