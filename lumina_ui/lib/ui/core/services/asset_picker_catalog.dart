import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lumina_editor_data/lumina_editor.dart';

/// The pure half of the shared asset picker: how an asset is
/// named and where it lives, which assets a query matches and in what order,
/// and which parts of a name to highlight.
abstract final class AssetPickerCatalog {
  /// An asset's display name: its file name without `.lmas`.
  static String defaultLabel(RealAssetInfo asset) =>
      asset.fileName.endsWith('.lmas') ? asset.fileName.substring(0, asset.fileName.length - 5) : asset.fileName;

  /// The folder an asset sits in (`contents/materials/a.lmas` →
  /// `contents/materials`).
  static String folderOf(RealAssetInfo asset) {
    final p = asset.relativePath.replaceAll(r'\', '/');
    final i = p.lastIndexOf('/');
    return i < 0 ? '' : p.substring(0, i);
  }

  /// Whether [asset] is the one a picker's stored [path] names: stores keep
  /// the absolute `.lmas` path, the project-relative path, or just the name.
  static bool matchesPath(RealAssetInfo asset, String? path) {
    if (path == null || path.isEmpty) return false;
    final p = path.replaceAll(r'\', '/');
    return asset.lmasPath == path || asset.relativePath == p || p.endsWith('/${asset.relativePath}');
  }

  /// The asset [path] names among [assets], or null.
  static RealAssetInfo? find(Iterable<RealAssetInfo> assets, String? path) {
    for (final a in assets) {
      if (matchesPath(a, path)) return a;
    }
    return null;
  }

  /// [assets] matching [query] (case-insensitive), best first: a name that
  /// starts with the query, then a name that contains it, then the folder,
  /// then the asset type; a several-word query matches when every word is
  /// found in the name, folder or type. Ties keep name order. An empty query
  /// keeps every asset, sorted by name.
  static List<RealAssetInfo> filter(
    Iterable<RealAssetInfo> assets,
    String query, {
    String Function(RealAssetInfo asset)? labelOf,
  }) {
    final label = labelOf ?? defaultLabel;
    final q = query.trim().toLowerCase();
    final scored = <(int, String, RealAssetInfo)>[];
    for (final a in assets) {
      final name = label(a).toLowerCase();
      final score = q.isEmpty ? 0 : rank(name, folderOf(a).toLowerCase(), a.type.name.toLowerCase(), q);
      if (score != null) scored.add((score, name, a));
    }
    scored.sort((x, y) {
      final byScore = x.$1.compareTo(y.$1);
      return byScore != 0 ? byScore : x.$2.compareTo(y.$2);
    });
    return [for (final s in scored) s.$3];
  }

  /// The rank of one asset for lower-case query [q] (0 is best), or null when
  /// it does not match.
  @visibleForTesting
  static int? rank(String name, String folder, String type, String q) {
    if (name.startsWith(q)) return 0;
    if (name.contains(q)) return 1;
    if (folder.contains(q)) return 2;
    if (type.contains(q)) return 3;
    final words = q.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.length > 1) {
      final haystack = '$name $folder $type';
      if (words.every(haystack.contains)) return 4;
    }
    return null;
  }

  /// The `[start, end)` ranges of [text] that match [query]'s words,
  /// case-insensitive and merged, for highlighting a row's name.
  static List<(int, int)> matchRanges(String text, String query) {
    final lower = text.toLowerCase();
    final ranges = <(int, int)>[];
    for (final word in query.toLowerCase().split(RegExp(r'\s+'))) {
      if (word.isEmpty) continue;
      var from = 0;
      while (true) {
        final i = lower.indexOf(word, from);
        if (i < 0) break;
        ranges.add((i, i + word.length));
        from = i + word.length;
      }
    }
    ranges.sort((a, b) => a.$1.compareTo(b.$1));
    final merged = <(int, int)>[];
    for (final r in ranges) {
      if (merged.isNotEmpty && r.$1 <= merged.last.$2) {
        final last = merged.removeLast();
        merged.add((last.$1, r.$2 > last.$2 ? r.$2 : last.$2));
      } else {
        merged.add(r);
      }
    }
    return merged;
  }
}

/// The picker's "Recently used" group: the last [limit] assets picked per
/// asset type, kept in the editor preferences file (`editor_preferences.json`
/// in [LuminaConfigDir], next to the flight-camera setting) so they survive a
/// restart.
class AssetPickerRecents {
  AssetPickerRecents({File? file}) : file = file ?? LuminaConfigDir.file(fileName);

  /// The editor preferences file (`EditorPreferences.fileName`).
  static const String fileName = 'editor_preferences.json';

  /// The key the recents live under in [file].
  static const String key = 'assetPickerRecents';

  /// How many assets each type remembers.
  static const int limit = 5;

  final File file;

  Map<String, List<String>> _read() {
    try {
      final decoded = ConfigJsonFile(file).read();
      final raw = decoded is Map ? decoded[key] : null;
      if (raw is! Map) return {};
      return {
        for (final e in raw.entries)
          if (e.value is List) '${e.key}': [for (final p in e.value as List) '$p'],
      };
    } catch (e) {
      debugPrint('[AssetPickerRecents] ${file.path} is unreadable: $e');
      return {};
    }
  }

  /// The project-relative paths picked last for [types], most recent first
  /// (types in the order given), at most [limit].
  List<String> recentPaths(Iterable<AssetType> types) {
    final all = _read();
    final out = <String>[];
    for (final t in types) {
      for (final p in all[t.name] ?? const <String>[]) {
        if (!out.contains(p)) out.add(p);
      }
    }
    return out.take(limit).toList();
  }

  /// Remembers [asset] as the most recent pick of its type.
  void record(RealAssetInfo asset) {
    try {
      ConfigJsonFile(file).update(
        (current) {
          final map = <String, dynamic>{...?(current is Map<String, dynamic> ? current : null)};
          final recents = <String, dynamic>{...?(map[key] is Map ? Map<String, dynamic>.from(map[key] as Map) : null)};
          final list = [for (final p in (recents[asset.type.name] as List?) ?? const []) '$p']
            ..remove(asset.relativePath)
            ..insert(0, asset.relativePath);
          recents[asset.type.name] = list.take(limit).toList();
          map[key] = recents;
          return map;
        },
        isValid: (value) => value is Map<String, dynamic>,
        pretty: true,
      );
    } catch (e) {
      debugPrint('[AssetPickerRecents] could not save ${file.path}: $e');
    }
  }
}
