import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:lumina_editor_data/lumina_editor.dart';

/// Reads and parses the mesh a plugin 3D viewport shows, off the UI isolate.
///
/// A plugin names its mesh by path (`Plugin3DViewportOptions.meshPath`): a
/// `.glb`, or a skeletal mesh `.lmas` whose GLB is its `.entity.glb`
/// companion or embedded payload — 324 MB for a MetaHuman. A file of
/// [workerThreshold] bytes or more is read and parsed on a background
/// isolate and its [GlbMeshData] comes back without a copy; smaller files
/// are read asynchronously and parsed inline, where an isolate would cost
/// more than the work.
///
/// The last mesh loaded is kept, keyed by its path and the size and
/// modification time of the file it was read from, so reopening the same
/// mesh (a tab switch, a rebuilt viewport) does not read it again.
abstract final class Plugin3DViewportMeshLoader {
  /// Files of at least this many bytes are read and parsed on a background
  /// isolate.
  static int workerThreshold = 8 * 1024 * 1024;

  /// How many loads read and parsed a file (cache misses), for tests.
  static int parsedCount = 0;

  /// How many of those ran on a background isolate, for tests.
  static int workerCount = 0;

  static ({String key, GlbMeshData mesh})? _last;

  /// Forgets the kept mesh.
  static void clear() => _last = null;

  /// The file [meshPath] names: as given when it exists, else relative to
  /// [projectDir]. Null when neither exists.
  static Future<String?> resolve(String meshPath, {String? projectDir}) async {
    if (await File(meshPath).exists()) return meshPath;
    final isAbsolute = meshPath.startsWith('/') || meshPath.contains(r':\') || meshPath.contains(':/');
    if (isAbsolute || projectDir == null) return null;
    final joined = '$projectDir/$meshPath'.replaceAll(r'\', '/');
    return await File(joined).exists() ? joined : null;
  }

  /// The file holding the GLB of [path]: the path itself for a `.glb`, the
  /// `.entity.glb` companion of a `.lmas` when it has one, else the `.lmas`.
  static Future<File> sourceOf(String path) async {
    if (path.toLowerCase().endsWith('.lmas')) {
      final companion = File(path.replaceAll(RegExp(r'\.lmas$'), '.entity.glb'));
      if (await companion.exists()) return companion;
    }
    return File(path);
  }

  /// The mesh at [meshPath] (absolute, or relative to [projectDir]); null
  /// when the file is missing or holds no GLB.
  static Future<GlbMeshData?> load(String meshPath, {String? projectDir}) async {
    final path = await resolve(meshPath, projectDir: projectDir);
    if (path == null) return null;
    final source = await sourceOf(path);
    final FileStat stat;
    try {
      stat = await source.stat();
    } on FileSystemException {
      return null;
    }
    if (stat.type == FileSystemEntityType.notFound) return null;
    final key = '${source.path}|${stat.size}|${stat.modified.microsecondsSinceEpoch}';
    final last = _last;
    if (last != null && last.key == key) return last.mesh;

    parsedCount++;
    GlbMeshData? mesh;
    if (stat.size >= workerThreshold) {
      workerCount++;
      final result = await Isolate.run(() => _parseInWorker(path));
      EngineLoggerService().replay(result.logs);
      mesh = result.mesh;
    } else {
      mesh = await _parse(path);
    }
    _last = mesh == null ? null : (key: key, mesh: mesh);
    return mesh;
  }

  /// The mesh in [bytes] (a GLB a plugin built in memory), parsed on a
  /// background isolate when it is [workerThreshold] bytes or more.
  static Future<GlbMeshData?> parseBytes(Uint8List bytes) async {
    if (bytes.length < workerThreshold) return GlbParserService.parseGlb(bytes);
    workerCount++;
    final result = await Isolate.run(() => _captureLogs(() => GlbParserService.parseGlb(bytes)));
    EngineLoggerService().replay(result.logs);
    return result.mesh;
  }

  static Future<({GlbMeshData? mesh, List<EngineLogEntry> logs})> _parseInWorker(String path) =>
      _captureLogs(() => _parse(path));

  /// Runs [parse] in a worker isolate and carries its log lines back for the
  /// editor's Output Log; the worker does not print them twice.
  static Future<({GlbMeshData? mesh, List<EngineLogEntry> logs})> _captureLogs(
    Future<GlbMeshData?> Function() parse,
  ) async {
    final logger = EngineLoggerService();
    final before = logger.logs.length;
    final mesh = await runZoned(parse, zoneSpecification: ZoneSpecification(print: (_, _, _, _) {}));
    return (mesh: mesh, logs: logger.logs.sublist(before));
  }

  static Future<GlbMeshData?> _parse(String path) async {
    final source = await sourceOf(path);
    Uint8List? bytes;
    if (source.path.toLowerCase().endsWith('.lmas')) {
      try {
        final payload = LuminaAsset.fromBytes(await source.readAsBytes()).rawPayload;
        if (payload != null && payload.length > 20 && payload[0] == 0x67) bytes = payload;
      } catch (_) {}
    } else {
      bytes = await source.readAsBytes();
    }
    if (bytes == null || bytes.isEmpty) return null;
    return GlbParserService.parseGlb(bytes);
  }
}
