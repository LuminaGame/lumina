import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../../main_editor/commands/editor_transaction.dart';
import '../../main_editor/services/project_trash.dart';

/// Who took a snapshot: the MCP session and client, and — for an in-process
/// call (a plugin such as MiniAI) — the `caller` string it passed to
/// `EditorMcp.callTool`, which carries MiniAI's turn id so a
/// whole turn's file changes can be listed and undone together.
class McpSnapshotContext {
  final String? sessionId;
  final String? client;
  final String? caller;

  const McpSnapshotContext({this.sessionId, this.client, this.caller});

  /// The attributed MCP call running now (`TransactionManager.currentOrigin`);
  /// an in-process call's session id is `in-process:<caller>`.
  factory McpSnapshotContext.current() {
    final origin = TransactionManager.currentOrigin;
    final session = origin?.sessionId;
    const prefix = 'in-process:';
    return McpSnapshotContext(
      sessionId: session,
      client: origin?.clientName,
      caller: origin?.caller ?? (session != null && session.startsWith(prefix) ? session.substring(prefix.length) : null),
    );
  }
}

/// One pre-write snapshot.
class McpFileSnapshot {
  final String id;
  final int seq;
  final String tool;

  /// Project-relative, `/`-separated.
  final String path;

  /// Whether the file existed; its previous bytes are in `before` when it did.
  final bool existed;
  final int bytes;
  final String? sha256;
  final DateTime created;
  final String? sessionId;
  final String? client;
  final String? caller;

  const McpFileSnapshot({
    required this.id,
    required this.seq,
    required this.tool,
    required this.path,
    required this.existed,
    required this.bytes,
    required this.sha256,
    required this.created,
    this.sessionId,
    this.client,
    this.caller,
  });

  Map<String, Object?> toJson() => {
        'id': id,
        'tool': tool,
        'path': path,
        'existed': existed,
        'bytes': bytes,
        'sha256': sha256,
        'created': created.toIso8601String(),
        'session_id': sessionId,
        'client': client,
        'caller': caller,
      };

  factory McpFileSnapshot.fromJson(Map<String, dynamic> j) {
    final id = j['id'] as String;
    return McpFileSnapshot(
      id: id,
      seq: int.tryParse(id.split('-').first) ?? 0,
      tool: j['tool'] as String? ?? '',
      path: j['path'] as String,
      existed: j['existed'] == true,
      bytes: (j['bytes'] as num?)?.toInt() ?? 0,
      sha256: j['sha256'] as String?,
      created: DateTime.tryParse(j['created'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
      sessionId: j['session_id'] as String?,
      client: j['client'] as String?,
      caller: j['caller'] as String?,
    );
  }
}

/// What [McpFileSnapshots.restore] did.
class McpRestoreResult {
  final McpFileSnapshot restored;

  /// The snapshot of the state the restore replaced (restore it to undo).
  final McpFileSnapshot replaced;
  final int restoredBytes;

  /// Set when the snapshot's file did not exist and the restore moved the
  /// current one to the project trash.
  final String? trashId;

  const McpRestoreResult({required this.restored, required this.replaced, required this.restoredBytes, this.trashId});
}

/// The file tools' undo: before every write, edit, delete,
/// restore and codegen overwrite the file's previous bytes go to
/// `<project>/.lumina/mcp/snapshots/<seq:06d>-<tool>/` (`manifest.json` +
/// `before`). Newest [maxCount] snapshots and at most [maxBytes] are kept.
class McpFileSnapshots {
  McpFileSnapshots(this.projectDir, {required this.trash, this.maxCount = 500, this.maxBytes = 200 * 1024 * 1024})
      : root = Directory(p.join(projectDir, '.lumina', 'mcp', 'snapshots'));

  final String projectDir;
  final ProjectTrash trash;
  final Directory root;
  final int maxCount;
  final int maxBytes;

  /// Oldest first; loaded from disk on first use.
  List<McpFileSnapshot>? _index;

  List<McpFileSnapshot> get _entries => _index ??= _load();

  List<McpFileSnapshot> _load() {
    if (!root.existsSync()) return [];
    final out = <McpFileSnapshot>[];
    for (final d in root.listSync().whereType<Directory>()) {
      final m = File(p.join(d.path, 'manifest.json'));
      if (!m.existsSync()) continue;
      try {
        out.add(McpFileSnapshot.fromJson(jsonDecode(m.readAsStringSync()) as Map<String, dynamic>));
      } on FormatException {
        continue;
      }
    }
    out.sort((a, b) => a.seq.compareTo(b.seq));
    return out;
  }

  File _file(String relative) => File(p.joinAll([projectDir, ...relative.split('/')]));

  /// Snapshots [relative]'s current bytes (or its absence) before [tool]
  /// changes it.
  McpFileSnapshot take(String relative, String tool, McpSnapshotContext context) {
    final entries = _entries;
    var seq = (entries.isEmpty ? 0 : entries.last.seq) + 1;
    String id() => '${seq.toString().padLeft(6, '0')}-$tool';
    while (Directory(p.join(root.path, id())).existsSync()) {
      seq++;
    }
    final dir = Directory(p.join(root.path, id()))..createSync(recursive: true);
    final file = _file(relative);
    final existed = file.existsSync();
    final bytes = existed ? file.readAsBytesSync() : null;
    if (bytes != null) File(p.join(dir.path, 'before')).writeAsBytesSync(bytes, flush: true);
    final snapshot = McpFileSnapshot(
      id: id(),
      seq: seq,
      tool: tool,
      path: relative,
      existed: existed,
      bytes: bytes?.length ?? 0,
      sha256: bytes == null ? null : sha256.convert(bytes).toString(),
      created: DateTime.now(),
      sessionId: context.sessionId,
      client: context.client,
      caller: context.caller,
    );
    File(p.join(dir.path, 'manifest.json')).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(snapshot.toJson()));
    entries.add(snapshot);
    _prune();
    return snapshot;
  }

  void _prune() {
    final entries = _entries;
    var total = entries.fold<int>(0, (sum, s) => sum + s.bytes);
    while (entries.length > 1 && (entries.length > maxCount || total > maxBytes)) {
      final oldest = entries.removeAt(0);
      total -= oldest.bytes;
      final dir = Directory(p.join(root.path, oldest.id));
      try {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      } on FileSystemException {
        // Pruned again after the next write.
      }
    }
  }

  McpFileSnapshot? byId(String id) => _entries.where((s) => s.id == id).firstOrNull;

  /// Newest first, filtered by project-relative [path], by the exact
  /// in-process [caller] or a [callerPrefix] of it, by [client] or
  /// [sessionId]; at most [limit].
  List<McpFileSnapshot> list({
    String? path,
    int limit = 20,
    String? caller,
    String? callerPrefix,
    String? client,
    String? sessionId,
  }) {
    final out = <McpFileSnapshot>[];
    for (final s in _entries.reversed) {
      if (path != null && s.path != path) continue;
      if (caller != null && s.caller != caller) continue;
      if (callerPrefix != null && !(s.caller?.startsWith(callerPrefix) ?? false)) continue;
      if (client != null && s.client != client) continue;
      if (sessionId != null && s.sessionId != sessionId) continue;
      out.add(s);
      if (out.length >= limit) break;
    }
    return out;
  }

  /// Puts snapshot [id]'s state back: snapshots the current state first (so
  /// the restore is itself reversible), then writes the old bytes or — when
  /// the file did not exist — moves the current file to the project trash.
  McpRestoreResult restore(String id, McpSnapshotContext context) {
    final s = byId(id);
    if (s == null) throw StateError('No snapshot "$id". Call fs_history for the snapshots.');
    final replaced = take(s.path, 'fs_restore', context);
    final file = _file(s.path);
    if (s.existed) {
      final before = File(p.join(root.path, s.id, 'before'));
      final bytes = before.existsSync() ? before.readAsBytesSync() : <int>[];
      writeAtomically(file, bytes);
      return McpRestoreResult(restored: s, replaced: replaced, restoredBytes: bytes.length);
    }
    String? trashId;
    if (file.existsSync()) {
      trashId = trash
          .moveToTrashSync([s.path], reason: 'fs_restore $id (the file did not exist)', origin: TransactionManager.currentOrigin)
          .id;
    }
    return McpRestoreResult(restored: s, replaced: replaced, restoredBytes: 0, trashId: trashId);
  }

  /// Writes [bytes] to `<file>.lumina-tmp`, then renames it over [file].
  static void writeAtomically(File file, List<int> bytes, {void Function()? beforeRename}) {
    file.parent.createSync(recursive: true);
    final tmp = File('${file.path}.lumina-tmp');
    tmp.writeAsBytesSync(bytes, flush: true);
    try {
      beforeRename?.call();
      tmp.renameSync(file.path);
    } catch (_) {
      if (tmp.existsSync()) tmp.deleteSync();
      rethrow;
    }
  }
}
