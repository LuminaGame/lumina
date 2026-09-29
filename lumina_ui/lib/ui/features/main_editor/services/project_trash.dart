import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../commands/editor_transaction.dart';

/// One file in a trash entry.
class TrashedFile {
  /// Project-relative, `/`-separated.
  final String original;

  /// Relative to the entry's folder.
  final String stored;
  final int bytes;
  final String sha256;

  const TrashedFile({required this.original, required this.stored, required this.bytes, required this.sha256});

  Map<String, Object?> toJson() => {'original': original, 'stored': stored, 'bytes': bytes, 'sha256': sha256};

  factory TrashedFile.fromJson(Map<String, dynamic> j) => TrashedFile(
        original: j['original'] as String,
        stored: j['stored'] as String,
        bytes: (j['bytes'] as num).toInt(),
        sha256: j['sha256'] as String,
      );
}

/// One trashed deletion: its files and the level actors it
/// removed, under `<project>/.lumina/trash/<id>/` with a `manifest.json`.
class TrashEntry {
  final String id;
  final DateTime created;
  final String reason;
  final Map<String, Object?>? origin;
  final List<TrashedFile> files;
  final List<Map<String, dynamic>> actors;

  const TrashEntry({
    required this.id,
    required this.created,
    required this.reason,
    this.origin,
    required this.files,
    this.actors = const [],
  });

  int get bytes => files.fold(0, (sum, f) => sum + f.bytes);

  Map<String, Object?> toJson() => {
        'id': id,
        'created': created.toIso8601String(),
        'reason': reason,
        'origin': origin,
        'files': [for (final f in files) f.toJson()],
        'actors': actors,
      };

  factory TrashEntry.fromJson(Map<String, dynamic> j) => TrashEntry(
        id: j['id'] as String,
        created: DateTime.parse(j['created'] as String),
        reason: j['reason'] as String? ?? '',
        origin: (j['origin'] as Map?)?.cast<String, Object?>(),
        files: [for (final f in (j['files'] as List? ?? const [])) TrashedFile.fromJson((f as Map).cast<String, dynamic>())],
        actors: [for (final a in (j['actors'] as List? ?? const [])) (a as Map).cast<String, dynamic>()],
      );
}

/// A restore that would overwrite files that exist again.
class TrashConflict implements Exception {
  final List<String> paths;
  const TrashConflict(this.paths);

  @override
  String toString() => 'Cannot restore: these paths exist again: ${paths.join(', ')}';
}

/// The project's recycle bin: deleted assets are moved here,
/// never erased, so undo and `restore_asset` bring them back byte-identical.
/// It lives in the project (next to `editor_layout.json`), so a restore needs
/// no global state; nothing purges it but the user's "Empty trash…".
class ProjectTrash {
  final String projectDir;
  final Directory root;

  /// Copy + delete instead of rename (what happens across file systems);
  /// tests force it to exercise that path.
  @visibleForTesting
  bool forceCopy = false;

  ProjectTrash(this.projectDir, {Directory? root})
      : root = root ?? Directory(p.join(projectDir, '.lumina', 'trash'));

  static String _stamp(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year}${two(t.month)}${two(t.day)}-${two(t.hour)}${two(t.minute)}${two(t.second)}';
  }

  String _newId() {
    final base = _stamp(DateTime.now());
    var n = 1;
    while (Directory(p.join(root.path, '$base-$n')).existsSync()) {
      n++;
    }
    return '$base-$n';
  }

  static String _slash(String s) => s.replaceAll(r'\', '/');

  /// Moves [relativePaths] (project-relative; missing ones are skipped) into
  /// a new entry, with [actors] (the level actors the deletion removed, as
  /// maps) in its manifest.
  Future<TrashEntry> moveToTrash(
    List<String> relativePaths, {
    required String reason,
    TransactionOrigin? origin,
    List<Map<String, dynamic>> actors = const [],
  }) async =>
      moveToTrashSync(relativePaths, reason: reason, origin: origin, actors: actors);

  /// [moveToTrash] without awaiting (an undo / redo step runs synchronously);
  /// [id] reuses an entry id (redo puts files back under the id undo took
  /// them from).
  TrashEntry moveToTrashSync(
    List<String> relativePaths, {
    required String reason,
    TransactionOrigin? origin,
    List<Map<String, dynamic>> actors = const [],
    String? id,
  }) {
    id ??= _newId();
    final dir = Directory(p.join(root.path, id));
    dir.createSync(recursive: true);
    final files = <TrashedFile>[];
    for (final rel in {for (final r in relativePaths) _slash(r)}) {
      final src = File(p.join(projectDir, rel));
      if (!src.existsSync()) continue;
      final bytes = src.readAsBytesSync();
      final stored = 'files/$rel';
      final dest = File(p.join(dir.path, stored));
      dest.parent.createSync(recursive: true);
      _move(src, dest);
      files.add(TrashedFile(original: rel, stored: stored, bytes: bytes.length, sha256: sha256.convert(bytes).toString()));
    }
    final entry = TrashEntry(
      id: id,
      created: DateTime.now(),
      reason: reason,
      origin: origin?.toJson(),
      files: files,
      actors: actors,
    );
    File(p.join(dir.path, 'manifest.json')).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(entry.toJson()));
    return entry;
  }

  void _move(File from, File to) {
    if (!forceCopy) {
      try {
        from.renameSync(to.path);
        return;
      } on FileSystemException {
        // Another file system: copy, then delete.
      }
    }
    from.copySync(to.path);
    from.deleteSync();
  }

  TrashEntry? entry(String id) {
    final f = File(p.join(root.path, id, 'manifest.json'));
    if (!f.existsSync()) return null;
    try {
      return TrashEntry.fromJson(jsonDecode(f.readAsStringSync()) as Map<String, dynamic>);
    } on FormatException {
      return null;
    }
  }

  /// Puts entry [id]'s files back and removes the entry; returns it (its
  /// actors are for the caller to re-insert). Throws [TrashConflict] naming
  /// the paths that exist again, changing nothing.
  Future<TrashEntry> restore(String id) async => restoreSync(id);

  /// [restore] without awaiting.
  TrashEntry restoreSync(String id) {
    final e = entry(id);
    if (e == null) throw StateError('No trash entry "$id". Call list_trash for the entries.');
    final conflicts = [for (final f in e.files) if (File(p.join(projectDir, f.original)).existsSync()) f.original];
    if (conflicts.isNotEmpty) throw TrashConflict(conflicts);
    final dir = Directory(p.join(root.path, id));
    for (final f in e.files) {
      final dest = File(p.join(projectDir, f.original));
      dest.parent.createSync(recursive: true);
      _move(File(p.join(dir.path, f.stored)), dest);
    }
    dir.deleteSync(recursive: true);
    return e;
  }

  /// Every entry, newest first.
  List<TrashEntry> list() {
    if (!root.existsSync()) return const [];
    final entries = [
      for (final d in root.listSync().whereType<Directory>()) ?entry(p.basename(d.path)),
    ]..sort((a, b) => b.id.compareTo(a.id));
    return entries;
  }

  int get sizeBytes {
    if (!root.existsSync()) return 0;
    var total = 0;
    for (final f in root.listSync(recursive: true).whereType<File>()) {
      total += f.lengthSync();
    }
    return total;
  }

  /// Erases everything in the trash. The panel's "Empty trash…" only — no
  /// MCP tool may call it (`McpExposure.neverExpose`).
  Future<void> empty() async {
    if (root.existsSync()) await root.delete(recursive: true);
  }
}
