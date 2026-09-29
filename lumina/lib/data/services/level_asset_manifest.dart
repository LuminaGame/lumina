import 'dart:convert';
import 'dart:io';

import '../../src/world/level_preloader.dart';
import '../models/lumina_asset.dart';
import '../repositories/level_repository.dart';
import 'asset_index.dart';

/// What a level loads: the assets its placed actors name —
/// meshes, landscapes, sky environments, textures, materials, sounds,
/// animation assets and the Blueprint classes placed in it with the assets
/// their components name. The level code generator emits it as the level
/// class's `assetManifest`; Play-In-Editor builds it from the level `.lmas`
/// found through the project's asset index. Either way a
/// [LuminaLevelPreloader] preloads it.
abstract final class LuminaLevelAssetManifest {
  static const Set<String> _meshExtensions = {'glb', 'gltf', 'filamesh'};
  static const Set<String> _textureExtensions = {'png', 'jpg', 'jpeg', 'ktx', 'ktx2', 'hdr', 'tga', 'webp', 'exr'};
  static const Set<String> _materialExtensions = {'filamat', 'mat'};
  static const Set<String> _soundExtensions = {'wav', 'ogg', 'mp3', 'flac'};

  /// The assets [actorMaps] (`metadata.actors`) name, in first-seen order and
  /// without duplicates, as bundle paths (`contents/…`). A placed Blueprint
  /// adds its class `.lmas` and — with [projectDir] to read the class from —
  /// the assets its components name.
  static List<LuminaAssetRef> fromActorMaps(List<Map<String, dynamic>> actorMaps, {String? projectDir}) {
    final out = <String, LuminaAssetRef>{};
    final classesSeen = <String>{};
    void add(String path, LuminaAssetKind kind) {
      final p = bundlePath(path);
      if (p.isEmpty) return;
      out.putIfAbsent(p, () => LuminaAssetRef(p, kind));
    }

    for (final a in actorMaps) {
      final cls = a['blueprintClass'];
      if (cls is String && cls.isNotEmpty) {
        add(cls, LuminaAssetKind.blueprint);
        if (projectDir != null && classesSeen.add(bundlePath(cls))) {
          final components = _blueprintComponents(projectDir, bundlePath(cls));
          _scan(components, null, add);
        }
      }
      final mesh = a['meshAssetPath'];
      final type = (a['type'] ?? '').toString();
      final landscape = a['landscapeAssetPath'] ?? (type == 'Landscape' ? mesh : null);
      if (landscape is String && landscape.isNotEmpty) add(landscape, LuminaAssetKind.landscape);
      if (type != 'Landscape' && mesh is String && mesh.isNotEmpty) add(mesh, LuminaAssetKind.mesh);
      for (final e in a.entries) {
        if (e.key == 'blueprintClass' || e.key == 'meshAssetPath' || e.key == 'landscapeAssetPath') continue;
        _scan(e.value, e.key, add);
      }
    }
    return out.values.toList();
  }

  /// Every string under [value] that names a project asset (`contents/…`,
  /// or an absolute path with an asset extension), typed by its key or
  /// extension.
  static void _scan(Object? value, String? key, void Function(String path, LuminaAssetKind kind) add) {
    if (value is Map) {
      for (final e in value.entries) {
        _scan(e.value, e.key is String ? e.key as String : key, add);
      }
    } else if (value is List) {
      for (final v in value) {
        _scan(v, key, add);
      }
    } else if (value is String && _looksLikeAsset(value)) {
      add(value, kindOf(value, key: key));
    }
  }

  static String _extension(String path) {
    final file = path.replaceAll(r'\', '/').split('/').last;
    final dot = file.lastIndexOf('.');
    return dot <= 0 ? '' : file.substring(dot + 1).toLowerCase();
  }

  static bool _looksLikeAsset(String v) {
    if (v.contains('\n') || v.length > 1024) return false;
    final p = v.replaceAll(r'\', '/');
    final ext = _extension(p);
    if (ext.isEmpty) return false;
    if (p.startsWith('contents/') || p.contains('/contents/')) return true;
    return p.startsWith('/') &&
        (ext == 'lmas' ||
            _meshExtensions.contains(ext) ||
            _textureExtensions.contains(ext) ||
            _materialExtensions.contains(ext) ||
            _soundExtensions.contains(ext));
  }

  /// The kind of [path], from the key that named it (`staticMeshAsset`,
  /// `soundAsset`…) or its extension.
  static LuminaAssetKind kindOf(String path, {String? key}) {
    final ext = _extension(path);
    if (_meshExtensions.contains(ext)) return LuminaAssetKind.mesh;
    if (_textureExtensions.contains(ext)) return LuminaAssetKind.texture;
    if (_materialExtensions.contains(ext)) return LuminaAssetKind.material;
    if (_soundExtensions.contains(ext)) return LuminaAssetKind.sound;
    final k = (key ?? '').toLowerCase();
    final p = path.toLowerCase();
    if (k.contains('landscape') || p.contains('/landscapes/')) return LuminaAssetKind.landscape;
    if (k.contains('mesh') || p.contains('/meshes/')) return LuminaAssetKind.mesh;
    if (k.contains('material') || p.contains('/materials/')) return LuminaAssetKind.material;
    if (k.contains('environment') || k.contains('ibl') || k.contains('sky')) return LuminaAssetKind.environment;
    if (k.contains('texture') || p.contains('/textures/')) return LuminaAssetKind.texture;
    if (k.contains('sound') || k.contains('audio') || k.contains('cue') || p.contains('/audio/')) return LuminaAssetKind.sound;
    if (k.contains('anim') || k.contains('montage') || p.contains('/animations/')) return LuminaAssetKind.animation;
    if (k.contains('class') || k.contains('blueprint') || p.contains('/blueprints/')) return LuminaAssetKind.blueprint;
    return LuminaAssetKind.other;
  }

  /// [path] as the game bundle names it: `contents/…` (a path through the
  /// project's `contents/` is cut there); any other path as it is.
  static String bundlePath(String path) {
    final p = path.replaceAll(r'\', '/');
    if (p.startsWith('contents/')) return p;
    final i = p.indexOf('/contents/');
    return i < 0 ? path : p.substring(i + 1);
  }

  /// The component list of the Blueprint class at [relativePath], read from
  /// its `.lmas` payload; empty when unreadable.
  static List<Object?> _blueprintComponents(String projectDir, String relativePath) {
    try {
      final file = File(relativePath.startsWith('/') ? relativePath : '$projectDir/$relativePath');
      if (!file.existsSync()) return const [];
      final payload = LuminaAsset.fromBytes(file.readAsBytesSync()).rawPayload;
      if (payload == null || payload.isEmpty) return const [];
      final json = jsonDecode(utf8.decode(payload));
      if (json is! Map || json['components'] is! List) return const [];
      return [
        for (final c in json['components'] as List)
          if (c is Map) c['properties'],
      ];
    } catch (_) {
      return const [];
    }
  }

  // ---------------------------------------------------------------------------
  // Play-In-Editor: the level through the asset index
  // ---------------------------------------------------------------------------

  /// The project-relative `.lmas` of level [levelName] (`L_Arena`,
  /// `L_Arena.lmas` or `contents/…/L_Arena.lmas`), found through [index]
  /// (up to date): `contents/levels/<name>.lmas`, else the level asset of
  /// that name anywhere under `contents/`. Null when there is none.
  static String? levelPath(LuminaAssetIndex index, String levelName) {
    final trimmed = levelName.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith('contents/')) {
      final path = trimmed.endsWith('.lmas') ? trimmed : '$trimmed.lmas';
      if (index.byPath(path)?.type == AssetType.level) return path;
    }
    final base = trimmed.split('/').last.replaceAll('.lmas', '');
    final standard = 'contents/levels/$base.lmas';
    if (index.byPath(standard)?.type == AssetType.level) return standard;
    for (final e in index.byType(AssetType.level)) {
      if (e.baseName == base) return e.path;
    }
    return null;
  }

  /// The names of the project's levels, from [index] (up to date).
  static List<String> levelNames(LuminaAssetIndex index) => [for (final e in index.byType(AssetType.level)) e.baseName];

  /// Level [levelName] of [projectDir]'s asset list for Play-In-Editor:
  /// found and read through the asset index (refreshed first), paths
  /// absolute (the editor reads the disk). Null when there is no such level.
  static Future<List<LuminaAssetRef>?> forProjectLevel(String projectDir, String levelName) async {
    final index = LuminaAssetIndex.open(projectDir);
    await index.refresh();
    final path = levelPath(index, levelName);
    if (path == null) return null;
    final level = LuminaLevelRepository(index.projectDir).load(path);
    if (level == null) return null;
    return [
      for (final r in fromActorMaps(level.actors, projectDir: index.projectDir))
        LuminaAssetRef(r.path.startsWith('/') ? r.path : '${index.projectDir}/${r.path}', r.kind),
    ];
  }

  // ---------------------------------------------------------------------------
  // Code generation
  // ---------------------------------------------------------------------------

  /// [refs] as the `const` list literal a generated level's `assetManifest`
  /// holds.
  static String toDartLiteral(List<LuminaAssetRef> refs, {String indent = '    '}) {
    if (refs.isEmpty) return '<LuminaAssetRef>[]';
    final b = StringBuffer('<LuminaAssetRef>[\n');
    for (final r in refs) {
      final escaped = r.path.replaceAll(r'\', r'\\').replaceAll("'", r"\'").replaceAll(r'$', r'\$');
      b.writeln("$indent  LuminaAssetRef('$escaped', LuminaAssetKind.${r.kind.name}),");
    }
    b.write('$indent]');
    return b.toString();
  }
}
