import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_filament/filament.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:vector_math/vector_math_64.dart';

import 'package:lumina/src/material/lumina_material.dart';
import 'package:lumina/src/material/lumina_material_instance.dart';
import 'package:lumina/src/material/material_textures.dart';
import 'package:lumina/src/utility/lumina_assets.dart';
import 'package:lumina/src/world/world.dart';

/// What a cloth is drawn with: the lit, double-sided built-in material in
/// its colour, textured by [baseColorTexture] (a texture asset or image,
/// tinted by the colour) once loaded, or a project material asset
/// ([materialAsset], a material `.lmas` or `.filamat` with the parameters
/// and textures the Material Editor saved) in its place.
class LuminaClothMaterial {
  LuminaClothMaterial({this.materialAsset, this.baseColorTexture, this.assetProvider});

  final String? materialAsset;
  final String? baseColorTexture;
  final LuminaAssetProvider? assetProvider;

  FilamentMaterialProvider? _provider;
  final List<FilamentMaterialInstance> _builtIn = [];
  LuminaMaterialTextures? _textures;
  LuminaMaterial? _asset;
  LuminaMaterialInstance? _assetInstance;
  FilamentMaterialInstance? _current;
  bool _disposed = false;

  /// The instance drawn now (null before the world can draw).
  FilamentMaterialInstance? get current => _current;

  /// Whether a texture or a material asset is drawn (once loaded).
  bool get isLoaded => _textures != null || _assetInstance != null;

  /// The built-in instance a new section starts with, in [color] (linear).
  FilamentMaterialInstance? create(LuminaWorld world, Vector3 color) {
    if (!world.hasNativeContext || _disposed) return null;
    if (_assetInstance != null) return _current = _assetInstance!.nativeInstance;
    final textures = _textures;
    final mi = _instance(world, color, textured: textures != null);
    if (mi != null && textures != null) textures.bindTo(mi);
    return _current = mi ?? _current;
  }

  FilamentMaterialInstance? _instance(LuminaWorld world, Vector3 color, {required bool textured}) {
    try {
      final provider = _provider ??= FilamentMaterialProvider.ubershader(world.filamentEngine);
      final key = MaterialKey(doubleSided: true, hasBaseColorTexture: textured, baseColorUV: 0);
      final mi = provider.createMaterialInstance(key, label: 'lumina_cloth').instance;
      if (mi == null) return null;
      mi.setFloat4('baseColorFactor', color.x, color.y, color.z, 1.0);
      mi.setFloat('roughnessFactor', 0.9);
      mi.setFloat('metallicFactor', 0.0);
      mi.setCullingMode(CullingMode.none);
      _builtIn.add(mi);
      return mi;
    } catch (_) {
      return null;
    }
  }

  /// Sets the built-in material's colour (a material asset keeps its own).
  void setColor(Vector3 color) {
    final mi = _current;
    if (mi == null || _assetInstance != null) return;
    try {
      mi.setFloat4('baseColorFactor', color.x, color.y, color.z, 1.0);
    } catch (_) {}
  }

  /// Loads [materialAsset] or [baseColorTexture] and calls [apply] with the
  /// instance that draws it. Completes when loaded (or failed: the cloth
  /// keeps its colour and the reason is logged).
  Future<void> load(LuminaWorld world, Vector3 color, void Function(FilamentMaterialInstance mi) apply) async {
    if (!world.hasNativeContext || _disposed) return;
    final assetPath = materialAsset ?? '';
    final texturePath = baseColorTexture ?? '';
    try {
      if (assetPath.isNotEmpty) {
        final material = await world.materialCache.load(world, assetPath, assetProvider: assetProvider);
        if (_disposed) {
          material.release();
          return;
        }
        _asset = material;
        final instance = _assetInstance = material.createInstance();
        apply(_current = instance.nativeInstance);
      } else if (texturePath.isNotEmpty) {
        final mi = _instance(world, color, textured: true);
        if (mi == null) return;
        final textures = await LuminaMaterialTextures.load(
          world.filamentEngine,
          mi.material,
          [AssetReference(slotName: 'baseColorMap', assetId: '', assetPath: texturePath)],
          materialPath: 'cloth',
          assetProvider: assetProvider,
        );
        if (_disposed) {
          textures.release();
          return;
        }
        if (textures.bound.isEmpty) throw StateError(textures.missing.values.join('; '));
        _textures = textures;
        textures.bindTo(mi);
        apply(_current = mi);
      }
    } catch (e) {
      developer.log('Cloth: cannot draw ${assetPath.isNotEmpty ? assetPath : texturePath}: $e', name: 'Cloth', level: 900);
    }
  }

  /// Destroys the instances and lets go of the material and textures (after
  /// the cloth's section is gone).
  void dispose() {
    _disposed = true;
    for (final mi in _builtIn) {
      try {
        mi.dispose();
      } catch (_) {}
    }
    _builtIn.clear();
    try {
      _assetInstance?.dispose();
    } catch (_) {}
    _assetInstance = null;
    _asset?.release();
    _asset = null;
    _textures?.release();
    _textures = null;
    try {
      _provider?.dispose();
    } catch (_) {}
    _provider = null;
    _current = null;
  }
}
