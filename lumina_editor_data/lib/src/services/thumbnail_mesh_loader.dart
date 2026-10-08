import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:lumina/lumina.dart';
import 'package:lumina_editor_data/src/services/derived_data_cache.dart';

/// The GLB a thumbnail draws for a mesh file, prepared off the UI isolate and
/// kept for the next thumbnail of the same mesh.
///
/// A mesh file is a `.glb`/`.gltf`, or a `.lmas` with an embedded GLB payload
/// or an `.entity.glb` companion. Its GLB goes through the import sanitizer
/// (TGA → PNG, texture budget, four skin influences) so gltfio can load it.
///
/// A file of [workerThreshold] bytes or more (a MetaHuman skeletal mesh with
/// hundreds of clips is over 300 MB) is read, decoded and sanitized on a
/// background isolate; the result comes back without a copy. Smaller files
/// are prepared inline, where an isolate would cost more than the work.
///
/// The last mesh loaded is kept, keyed by the path and the size and
/// modification time of the files it was read from: an animation library
/// draws hundreds of thumbnails on one mesh, and each of them gets the same
/// bytes (the same [Uint8List] instance) without touching the disk. Saving
/// the mesh changes the key, so a stale mesh is never served. [clear] drops
/// it (the thumbnail queue does when it runs dry).
abstract final class ThumbnailMeshLoader {
  /// Files of at least this many bytes are prepared on a background isolate.
  static int workerThreshold = 8 * 1024 * 1024;

  static _LoadedMesh? _last;

  /// How many loads read and prepared a file (cache misses), for tests.
  static int preparedCount = 0;

  /// How many of those ran on a background isolate, for tests.
  static int workerCount = 0;

  /// The sanitized GLB [path] draws, or null when it has none.
  static Future<Uint8List?> load(String path) async {
    final key = await _MeshKey.of(path);
    if (key == null) return null;
    final last = _last;
    if (last != null && last.key == key) return last.glb;
    preparedCount++;
    final _Prepared prepared;
    if (key.largestFile >= workerThreshold) {
      workerCount++;
      prepared = await Isolate.run(() => _prepareInWorker(path));
      EngineLoggerService().replay(prepared.logs);
    } else {
      prepared = await _prepare(path);
    }
    final glb = prepared.glb;
    _last = glb == null
        ? null
        : _LoadedMesh(key, glb, prepared.animatesMorphWeights);
    return glb;
  }

  /// Whether [glb] (as returned by [load]) has animation channels that drive
  /// morph-target weights; null when it is not the kept mesh.
  static bool? animatesMorphWeights(Uint8List glb) {
    final last = _last;
    return last != null && identical(last.glb, glb)
        ? last.animatesMorphWeights
        : null;
  }

  /// Forgets the kept mesh.
  static void clear() => _last = null;

  /// Runs in the background isolate: the work of [_prepare], with the log
  /// lines it wrote carried back for the editor's Output Log.
  static Future<_Prepared> _prepareInWorker(String path) async {
    final logger = EngineLoggerService();
    final before = logger.logs.length;
    // The editor replays these lines; the worker does not print them twice.
    final result = await runZoned(
      () => _prepare(path),
      zoneSpecification: ZoneSpecification(print: (_, _, _, _) {}),
    );
    return _Prepared(
      result.glb,
      result.animatesMorphWeights,
      logger.logs.sublist(before),
    );
  }

  static Future<_Prepared> _prepare(String path) async {
    final file = File(path);
    Uint8List? glb;
    if (path.endsWith('.lmas')) {
      try {
        final payload = LuminaAsset.fromBytes(
          await file.readAsBytes(),
        ).rawPayload;
        if (isGltf(payload)) glb = payload;
      } catch (_) {}
      final companion = File(companionOf(path));
      if (glb == null && await companion.exists()) {
        glb = await companion.readAsBytes();
      }
    } else {
      final bytes = await file.readAsBytes();
      if (isGltf(bytes)) glb = bytes;
    }
    if (glb == null) return const _Prepared(null, false, []);
    Uint8List sanitized;
    try {
      final parent = file.parent.path;
      // Oversized source art is budgeted once per project, not per session.
      sanitized = await DerivedDataCache.sanitizeGlbForAsset(
        path,
        glb,
        searchDirs: [parent, '$parent/../../textures'],
      );
    } catch (_) {
      sanitized = glb;
    }
    return _Prepared(sanitized, glbAnimatesMorphWeights(sanitized), const []);
  }

  /// The `.entity.glb` companion of a `.lmas`.
  static String companionOf(String lmasPath) =>
      lmasPath.replaceAll(RegExp(r'\.lmas$'), '.entity.glb');

  /// A binary glTF (`glTF` magic) or a JSON glTF.
  static bool isGltf(Uint8List? b) =>
      b != null &&
      b.length > 20 &&
      ((b[0] == 0x67 && b[1] == 0x6C && b[2] == 0x54 && b[3] == 0x46) ||
          b[0] == 0x7B);

  /// Whether an animation channel of [glb] targets morph weights
  /// (`"path": "weights"`). Reads only the JSON chunk.
  static bool glbAnimatesMorphWeights(Uint8List glb) {
    try {
      String json;
      if (glb[0] == 0x7B) {
        json = utf8.decode(glb, allowMalformed: true);
      } else {
        final length = ByteData.sublistView(glb).getUint32(12, Endian.little);
        if (20 + length > glb.length) return false;
        json = utf8.decode(
          Uint8List.sublistView(glb, 20, 20 + length),
          allowMalformed: true,
        );
      }
      return RegExp(r'"path"\s*:\s*"weights"').hasMatch(json);
    } catch (_) {
      return false;
    }
  }
}

class _Prepared {
  const _Prepared(this.glb, this.animatesMorphWeights, this.logs);
  final Uint8List? glb;
  final bool animatesMorphWeights;
  final List<EngineLogEntry> logs;
}

class _LoadedMesh {
  _LoadedMesh(this.key, this.glb, this.animatesMorphWeights);
  final _MeshKey key;
  final Uint8List glb;
  final bool animatesMorphWeights;
}

/// A mesh file's identity: its path and the size and modification time of
/// the file and its `.entity.glb` companion.
class _MeshKey {
  _MeshKey(this.path, this.stamps, this.largestFile);
  final String path;
  final String stamps;
  final int largestFile;

  static Future<_MeshKey?> of(String path) async {
    final stat = await FileStat.stat(path);
    if (stat.type != FileSystemEntityType.file) return null;
    var stamps = '${stat.size}@${stat.modified.microsecondsSinceEpoch}';
    var largest = stat.size;
    if (path.endsWith('.lmas')) {
      final companion = await FileStat.stat(
        ThumbnailMeshLoader.companionOf(path),
      );
      if (companion.type == FileSystemEntityType.file) {
        stamps +=
            '|${companion.size}@${companion.modified.microsecondsSinceEpoch}';
        if (companion.size > largest) largest = companion.size;
      }
    }
    return _MeshKey(path, stamps, largest);
  }

  @override
  bool operator ==(Object other) =>
      other is _MeshKey && other.path == path && other.stamps == stamps;

  @override
  int get hashCode => Object.hash(path, stamps);
}
