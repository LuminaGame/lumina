import 'dart:typed_data';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:lumina/lumina.dart';

/// A sub-editor viewport's mesh: its own instance of the asset its engine
/// shares with every other viewport, behind
/// the part of `FilamentAsset`'s API the viewport uses — so a Skeletal Mesh
/// editor on a mesh the level already shows uploads nothing.
class ViewportMesh {
  ViewportMesh._(this.handle, this._engine);

  /// Loads [payload] through [engine]'s shared cache; [sourcePath] (the
  /// asset's `.lmas` or GLB) is recorded, content decides sharing.
  static Future<ViewportMesh?> acquire(FilamentEngine engine, Uint8List payload, {String? sourcePath}) async {
    final handle = await LuminaMeshAssetCache.forEngine(engine)
        .acquireBytes(payload, sourcePath: sourcePath ?? 'sub-editor payload');
    return handle == null ? null : ViewportMesh._(handle, engine);
  }

  /// The shared asset's handle (tests read the cache key and holders).
  final LuminaMeshHandle handle;
  final FilamentEngine _engine;
  bool _disposed = false;

  bool get isDisposed => _disposed || handle.isReleased;

  /// This viewport's entities (its instance's, not the other holders').
  List<int> get entities => handle.instance.entities;
  int get entityCount => handle.instance.entityCount;
  int get rootEntity => handle.instance.root;
  FilamentAnimator get animator => handle.instance.animator;

  /// This instance's entities that carry a renderable, in instance order.
  List<int> get renderableEntities {
    final rm = FilamentRenderableManager(_engine);
    return [for (final e in entities) if (rm.hasComponent(e)) e];
  }

  /// This instance's entities named [name] (the asset's name index spans
  /// every instance).
  List<int> getEntitiesByName(String name) {
    final mine = entities.toSet();
    return handle.asset.getEntitiesByName(name).where(mine.contains).toList();
  }

  String? getEntityName(int entity) => handle.asset.getEntityName(entity);
  int getMorphTargetCountAt(int entity) => handle.asset.getMorphTargetCountAt(entity);
  String? getMorphTargetNameAt(int entity, int target) => handle.asset.getMorphTargetNameAt(entity, target);

  void addToScene(FilamentScene scene) => scene.addEntities(entities);
  void removeFromScene(FilamentScene scene) => scene.removeEntities(entities);

  /// Gives the instance back (the asset lives on while others hold it).
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    handle.release();
  }
}
