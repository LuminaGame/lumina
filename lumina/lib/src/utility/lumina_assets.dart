import 'dart:io';
import 'dart:typed_data';

import 'package:lumina/data/models/lumina_asset.dart';

/// Loads an asset's bytes by path (a mesh GLB, a compiled material, an IBL).
typedef LuminaAssetProvider = Future<Uint8List> Function(String path);

/// Where the runtime reads assets that a component was not handed a provider
/// for. The editor and tests read project files from disk; a generated game
/// sets [defaultProvider] to its Flutter asset bundle, which is the only
/// store a web build has.
abstract final class LuminaAssets {
  /// Used by the mesh cache, the material cache and the sky whenever their
  /// own `assetProvider` is null. Null reads the file system.
  static LuminaAssetProvider? defaultProvider;

  /// The open project's folder, set by the editor: a disk read of a
  /// project-relative path (`contents/…`, what Blueprints store) resolves
  /// against it. Null reads every path as given.
  static String? projectDir;

  static Future<Uint8List> _readDisk(String path) {
    final dir = projectDir;
    final relative = dir != null && path.replaceAll(r'\', '/').startsWith('contents/');
    return File(relative ? '$dir/$path' : path).readAsBytes();
  }

  /// Resolves the provider for a load: [explicit], else [defaultProvider],
  /// else a disk read. Paths a level preload pinned ([pinResident]) are
  /// served from memory first.
  static LuminaAssetProvider resolve(LuminaAssetProvider? explicit) {
    final base = explicit ?? defaultProvider ?? _readDisk;
    if (_resident.isEmpty) return base;
    return (path) {
      for (final r in _resident.values) {
        final bytes = r.bytes[path];
        if (bytes != null) return Future<Uint8List>.value(bytes);
        final miss = r.misses[path];
        if (miss != null) return Future<Uint8List>.error(miss);
      }
      return base(path);
    };
  }

  static final Map<Object, ({Map<String, Uint8List> bytes, Map<String, Object> misses})> _resident = {};

  /// Serves [bytes] (and fails [misses] with their error) by path from
  /// [resolve] until [unpinResident] with the same [owner]: what a level
  /// preload read, handed to the level's components. The maps
  /// are live — entries the owner adds later are served too.
  static void pinResident(Object owner, Map<String, Uint8List> bytes, [Map<String, Object> misses = const {}]) =>
      _resident[owner] = (bytes: bytes, misses: misses);

  /// Stops serving what [owner] pinned.
  static void unpinResident(Object owner) => _resident.remove(owner);

  /// Whether a preload serves [path] from memory.
  static bool isResident(String path) => _resident.values.any((r) => r.bytes.containsKey(path));

  /// What generated game code needs from a project asset: the payload of the
  /// `.lmas` at [path] (a texture's image bytes, …), or a plain file's bytes,
  /// loaded through [resolve]. Null when the `.lmas` carries no payload.
  static Future<Uint8List?> loadPayload(String path, {LuminaAssetProvider? provider}) async {
    final bytes = await resolve(provider)(path);
    if (!path.toLowerCase().endsWith('.lmas')) return bytes;
    return LuminaAsset.fromBytes(bytes).rawPayload;
  }
}
