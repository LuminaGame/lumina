import 'dart:io';
import 'dart:typed_data';

import 'package:lumina/src/material/material_cache.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina/data/services/level_asset_manifest.dart';

/// The material a placed level mesh draws on every section in place of the
/// mesh's own: the actor's `materialPath` (the level Details panel's Material
/// field, `set_actor_property material`). The editor's level viewport,
/// Play-In-Editor and the level code generator all read it here, so the three
/// draw the same thing.
abstract final class LuminaLevelActorMaterial {
  /// The actor types that draw an assigned material: imported meshes and the
  /// basic shapes.
  static const Set<String> actorTypes = {'Mesh', 'StaticMesh', 'SkeletalMesh', 'Primitive'};

  /// The material asset [actor] (a `metadata.actors` entry) assigns, as a
  /// bundle path (`contents/…`, `/`-separated); null when it assigns none.
  /// A value that names no material asset file — the placeholder names older
  /// editors wrote on every spawned mesh — assigns none.
  static String? pathOf(Map<String, dynamic> actor) {
    if (!actorTypes.contains(actor['type'])) return null;
    final cls = actor['blueprintClass'];
    if (cls is String && cls.isNotEmpty) return null;
    final raw = actor['materialPath'];
    if (raw is! String) return null;
    final path = raw.trim().replaceAll(r'\', '/');
    final lower = path.toLowerCase();
    if (!lower.endsWith('.lmas') && !lower.endsWith('.filamat')) return null;
    return LuminaLevelAssetManifest.bundlePath(path);
  }

  /// What the viewport draws for the material at [path] (from [pathOf]):
  /// changes when the material file or one of the [textures] its samplers
  /// name (`LuminaInstanceMaterialOverride.texturePaths`) is saved again,
  /// recompiled or reimported. `contents/…` paths are read under
  /// [projectDir].
  static String revision(String path, {String? projectDir, Iterable<String> textures = const []}) {
    String stamp(String p) {
      final absolute = p.startsWith('/') || RegExp(r'^[A-Za-z]:[\\/]').hasMatch(p);
      try {
        final stat = File(absolute || projectDir == null ? p : '$projectDir/$p').statSync();
        return '${stat.modified.microsecondsSinceEpoch}:${stat.size}';
      } catch (_) {
        return '-';
      }
    }

    return [path, stamp(path), for (final t in textures) '$t@${stamp(t)}'].join('|');
  }

  /// Why the material at [path] (from [pathOf]) cannot be drawn — not found,
  /// or no compiled material in it — or null when it can. A `contents/…` path
  /// is read under [projectDir]; without one only absolute paths are checked.
  static String? problem(String path, {String? projectDir}) {
    final absolute = path.startsWith('/') || RegExp(r'^[A-Za-z]:[\\/]').hasMatch(path);
    if (!absolute && projectDir == null) return null;
    final file = File(absolute ? path : '$projectDir/$path');
    if (!file.existsSync()) return '$path was not found';
    final Uint8List bytes;
    try {
      bytes = file.readAsBytesSync();
    } on FileSystemException catch (e) {
      return '$path cannot be read: ${e.message}';
    }
    if (path.toLowerCase().endsWith('.filamat')) {
      return LuminaMaterialCache.isCompiledPackage(bytes) ? null : '$path is not a compiled material';
    }
    try {
      final payload = LuminaAsset.fromBytes(bytes).rawPayload;
      if (payload != null && LuminaMaterialCache.isCompiledPackage(payload)) return null;
    } catch (_) {
      return '$path is not a material asset';
    }
    return '$path carries no compiled material (compile and save it in the Material Editor)';
  }
}
