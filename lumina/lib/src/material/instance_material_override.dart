import 'dart:typed_data';

import 'package:flutter_filament/flutter_filament.dart';

import 'material_cache.dart';

/// One material asset drawn on every section of a gltfio instance that no
/// world owns — the editor's level viewport, where a placed mesh shows the
/// material assigned to it as Play and the built game draw it
/// (`LuminaStaticMeshComponent.materialOverrideAsset`).
///
/// [applyTo] remembers what each section drew, [restore] puts it back, and
/// [dispose] restores and destroys the material.
class LuminaInstanceMaterialOverride {
  LuminaInstanceMaterialOverride._(this.engine, this.assetPath, this._material)
      : _instance = _material.createInstance(_instanceName(assetPath));

  /// Builds the material from [bytes], the content of [assetPath] (a material
  /// `.lmas` or a `.filamat`), with the parameter values the Material Editor
  /// saved. Throws a [StateError] when they hold no compiled material.
  factory LuminaInstanceMaterialOverride.fromBytes(FilamentEngine engine, String assetPath, Uint8List bytes) =>
      LuminaInstanceMaterialOverride._(engine, assetPath, LuminaMaterialCache.createNative(engine, assetPath, bytes));

  final FilamentEngine engine;

  /// The material asset drawn.
  final String assetPath;

  final FilamentMaterial _material;
  final FilamentMaterialInstance _instance;

  FilamentAssetInstance? _target;

  /// What each overridden section drew before, by (entity, primitive).
  final Map<(int, int), FilamentMaterialInstance?> _own = {};

  /// The material instance drawn on the sections.
  FilamentMaterialInstance get materialInstance => _instance;

  /// Draws the material on every primitive of every renderable of [instance],
  /// moving off the instance it was drawn on before.
  void applyTo(FilamentAssetInstance instance) {
    if (!identical(_target, instance)) restore();
    _target = instance;
    final rm = FilamentRenderableManager(engine);
    for (final entity in {instance.root, ...instance.entities}) {
      if (!rm.hasComponent(entity)) continue;
      for (var p = 0; p < rm.getPrimitiveCount(entity); p++) {
        _own.putIfAbsent((entity, p), () => rm.getMaterialInstanceAt(entity, p));
        rm.setMaterialInstanceAt(entity, p, _instance);
      }
    }
  }

  /// Gives the sections [applyTo] overrode their own materials back.
  void restore() {
    if (_target == null) return;
    final rm = FilamentRenderableManager(engine);
    for (final e in _own.entries) {
      final (entity, primitive) = e.key;
      if (!rm.hasComponent(entity)) continue;
      final own = e.value;
      if (own != null) {
        rm.setMaterialInstanceAt(entity, primitive, own);
      } else {
        rm.clearMaterialInstanceAt(entity, primitive);
      }
    }
    _own.clear();
    _target = null;
  }

  /// Restores the sections and destroys the material.
  void dispose() {
    restore();
    _instance.dispose();
    _material.dispose();
  }

  static String _instanceName(String path) {
    final file = path.replaceAll(r'\', '/').split('/').last;
    final dot = file.lastIndexOf('.');
    return dot > 0 ? file.substring(0, dot) : file;
  }
}
