import 'dart:convert';
import 'dart:io';

import '../../src/physics/mass_properties.dart';
import '../models/lumina_asset.dart';

/// A static mesh asset's physics as the Static Mesh editor stores it
/// (`metadata.physics = {massKg, centerOfMassOffset}`):
/// what a simulating component inherits unless it overrides its mass.
///
/// Editor-side only (it reads `.lmas` files): Play-In-Editor sets
/// `LuminaBlueprintComponents.meshPhysicsResolver` to [forMeshAsset]; a
/// generated game uses the values the editor baked into the component.
abstract final class MeshPhysicsService {
  /// The mesh asset metadata key the Static Mesh editor writes.
  static const String metadataKey = 'physics';

  static final Map<String, ({int size, DateTime modified, LuminaMeshPhysics? physics})> _cache = {};

  /// The physics of the mesh asset at [meshAssetPath] (absolute, or a
  /// project path resolved under [projectDir]); null for a file that is not a
  /// readable `.lmas` or has no `physics` metadata. Cached per file until its
  /// size or modification time changes.
  static LuminaMeshPhysics? forMeshAsset(String meshAssetPath, {String? projectDir}) {
    if (!meshAssetPath.toLowerCase().endsWith('.lmas')) return null;
    var file = File(meshAssetPath);
    if (!file.isAbsolute || !file.existsSync()) {
      if (projectDir == null || file.isAbsolute) return null;
      file = File('$projectDir/$meshAssetPath');
      if (!file.existsSync()) return null;
    }
    try {
      final stat = file.statSync();
      final cached = _cache[file.path];
      if (cached != null && cached.size == stat.size && cached.modified == stat.modified) return cached.physics;
      final physics = fromMetadata(LuminaAsset.fromBytes(file.readAsBytesSync()).metadata);
      _cache[file.path] = (size: stat.size, modified: stat.modified, physics: physics);
      return physics;
    } catch (_) {
      return null;
    }
  }

  /// The physics in a mesh asset's [metadata]; null without any.
  static LuminaMeshPhysics? fromMetadata(Map<String, String> metadata) {
    final raw = metadata[metadataKey];
    if (raw == null || raw.isEmpty) return null;
    try {
      return LuminaMeshPhysics.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }
}
