import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:lumina_core/lumina_core.dart';

import 'package:lumina/src/components/mesh/mesh_asset_cache.dart';
import 'package:lumina/src/utility/lumina_assets.dart';

/// A pose search database ready to play: its document, the mesh GLB's clips
/// on the CPU, the poser that shows a frame and the searchable index.
class LuminaPoseSearchDatabaseRuntime {
  /// The database asset (`.lmas`) it was loaded from, or '' when built from
  /// bytes.
  final String path;
  final LuminaPoseSearchDatabaseDocument document;
  final LuminaGlbAnimationSampler sampler;
  final LuminaPoseSearchRig rig;
  final LuminaPoseSearchPoser poser;
  final LuminaPoseSearchIndex index;

  /// Whether the index was built now (the cache was missing or stale).
  final bool built;

  /// Per database clip: its clip in the GLB (null when the GLB lacks it).
  final List<int?> samplerClips;

  /// Per database clip and mirror flag: the first row and the row count.
  final Map<(int, bool), (int, int)> _rowRanges;

  LuminaPoseSearchDatabaseRuntime._(this.path, this.document, this.sampler, this.index, this.built)
      : rig = LuminaPoseSearchRig(sampler, document.schema),
        poser = LuminaPoseSearchPoser(LuminaPoseSearchRig(sampler, document.schema)),
        samplerClips = [for (final c in document.clips) sampler.clipIndex(c.clip)],
        _rowRanges = _ranges(index);

  static Map<(int, bool), (int, int)> _ranges(LuminaPoseSearchIndex index) {
    final out = <(int, bool), (int, int)>{};
    for (var r = 0; r < index.rowCount; r++) {
      final key = (index.rowClip[r], index.isMirrored(r));
      final range = out[key];
      out[key] = range == null ? (r, 1) : (range.$1, range.$2 + 1);
    }
    return out;
  }

  /// The row of database clip [clip] (mirrored or not) nearest [time], or −1.
  int rowFor(int clip, double time, bool mirrored) {
    final range = _rowRanges[(clip, mirrored)];
    if (range == null) return -1;
    final (start, count) = range;
    var lo = start, hi = start + count - 1;
    while (hi - lo > 1) {
      final mid = (lo + hi) >> 1;
      if (index.rowTime[mid] <= time) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return (index.rowTime[hi] - time).abs() < (time - index.rowTime[lo]).abs() ? hi : lo;
  }

  /// Seconds of database clip [clip] (0 when the GLB lacks it).
  double durationOf(int clip) {
    final s = samplerClips[clip];
    return s == null ? 0.0 : sampler.clips[s].duration;
  }

  /// Builds (or reads from [cache] when its fingerprint matches) the
  /// runtime for [document] over the mesh [glb], parsing and building on a
  /// background isolate.
  static Future<LuminaPoseSearchDatabaseRuntime> fromGlb(
    Uint8List glb,
    LuminaPoseSearchDatabaseDocument document, {
    Uint8List? cache,
    String path = '',
  }) async {
    final docJson = jsonEncode(document.toJson());
    (LuminaGlbAnimationSampler, Uint8List, bool) work() {
      final doc = LuminaPoseSearchDatabaseDocument.fromJson(jsonDecode(docJson) as Map<String, dynamic>);
      final sampler = LuminaGlbAnimationSampler.fromGlb(glb);
      final fingerprint = LuminaPoseSearchBuilder.fingerprint(glb, doc);
      if (cache != null && LuminaPoseSearchIndex.fingerprintOf(cache) == fingerprint) return (sampler, cache, false);
      final index = LuminaPoseSearchBuilder.buildWithStats(glb, doc, sampler: sampler).index;
      return (sampler, index.encode(), true);
    }

    (LuminaGlbAnimationSampler, Uint8List, bool) result;
    try {
      result = await Isolate.run(work, debugName: 'pose search load');
    } on UnsupportedError {
      result = work();
    }
    return LuminaPoseSearchDatabaseRuntime._(
        path, document, result.$1, LuminaPoseSearchIndex.decode(result.$2), result.$3);
  }

  static final Map<String, Future<LuminaPoseSearchDatabaseRuntime>> _shared = {};

  /// Per target mesh: its clips on the CPU and its GLB hash, shared by every
  /// database of the mesh [load] reads (a MetaHuman with hundreds of clips
  /// is parsed and hashed once, not once per database).
  static final Map<String, Future<(LuminaGlbAnimationSampler, String)>> _meshes = {};

  /// The clips of the mesh at [meshAssetPath] on the CPU, parsed once on a
  /// background isolate and shared with every database [load] reads for the
  /// same mesh (so a root-motion montage samples the very poses motion
  /// matching shows).
  static Future<LuminaGlbAnimationSampler> meshSampler(String meshAssetPath, {LuminaAssetProvider? provider}) async {
    final (sampler, _) = await _mesh(meshAssetPath, LuminaAssets.resolve(provider));
    return sampler;
  }

  static Future<(LuminaGlbAnimationSampler, String)> _mesh(String meshAssetPath, LuminaAssetProvider read, {Uint8List? bytes}) =>
      _meshes.putIfAbsent(meshAssetPath, () => _parseMesh(meshAssetPath, read, bytes));

  /// Reads and parses the mesh once; a failure forgets the entry (the next
  /// call retries) and is rethrown to every waiting caller.
  static Future<(LuminaGlbAnimationSampler, String)> _parseMesh(
      String meshAssetPath, LuminaAssetProvider read, Uint8List? bytes) async {
    try {
      final glb = bytes ?? await LuminaMeshAssetCache.meshBytes(read, meshAssetPath);
      (LuminaGlbAnimationSampler, String) work() =>
          (LuminaGlbAnimationSampler.fromGlb(glb), LuminaPoseSearchBuilder.glbHash(glb));
      try {
        return await Isolate.run(work, debugName: 'pose search mesh');
      } on UnsupportedError {
        return work();
      }
    } catch (_) {
      _meshes.remove(meshAssetPath);
      rethrow;
    }
  }

  /// Forgets the shared runtimes ([load] reloads them).
  static void clearShared() {
    _shared.clear();
    _meshes.clear();
  }

  /// The `.posedb` cache path of a database `.lmas`.
  static String cachePathOf(String databasePath) =>
      databasePath.toLowerCase().endsWith('.lmas') ? '${databasePath.substring(0, databasePath.length - 5)}.posedb' : '$databasePath.posedb';

  /// Loads the database at [databasePath] once per path: the document from
  /// its `.lmas` (or [document]), the target mesh's GLB and the `.posedb`
  /// cache through [provider] (the default asset provider when null). A
  /// stale or missing cache is rebuilt in the background and, when reading
  /// from disk, written next to the asset.
  static Future<LuminaPoseSearchDatabaseRuntime> load(
    String databasePath, {
    LuminaAssetProvider? provider,
    LuminaPoseSearchDatabaseDocument? document,
  }) {
    return _shared.putIfAbsent(databasePath, () async {
      try {
        return await _load(databasePath, provider, document);
      } catch (_) {
        _shared.remove(databasePath);
        rethrow;
      }
    });
  }

  static Future<LuminaPoseSearchDatabaseRuntime> _load(
      String databasePath, LuminaAssetProvider? provider, LuminaPoseSearchDatabaseDocument? document) async {
    final read = LuminaAssets.resolve(provider);
    final doc = document ?? _documentOf(await read(databasePath));
    final glb = await LuminaMeshAssetCache.meshBytes(read, doc.targetMesh);
    final cachePath = cachePathOf(databasePath);
    Uint8List? cache;
    try {
      cache = await read(cachePath);
    } catch (_) {}
    final (sampler, glbHash) = await _mesh(doc.targetMesh, read, bytes: glb);
    // A current cache needs no rebuild: the index is decoded next to the
    // mesh's shared clips.
    final runtime = cache != null &&
            LuminaPoseSearchIndex.fingerprintOf(cache) == LuminaPoseSearchBuilder.fingerprintOfHash(glbHash, doc)
        ? LuminaPoseSearchDatabaseRuntime._(databasePath, doc, sampler, LuminaPoseSearchIndex.decode(cache), false)
        : await fromGlb(glb, doc, path: databasePath);
    final onDisk = provider == null && LuminaAssets.defaultProvider == null;
    if (runtime.built && onDisk) {
      try {
        final dir = LuminaAssets.projectDir;
        final relative = dir != null && cachePath.replaceAll(r'\', '/').startsWith('contents/');
        await File(relative ? '$dir/$cachePath' : cachePath).writeAsBytes(runtime.index.encode());
      } catch (_) {
        // A read-only location keeps rebuilding in memory.
      }
    }
    return runtime;
  }

  static LuminaPoseSearchDatabaseDocument _documentOf(Uint8List lmas) {
    final payload = LuminaAsset.fromBytes(lmas).rawPayload;
    if (payload == null || payload.isEmpty) throw const FormatException('the pose search database has no payload');
    return LuminaPoseSearchDatabaseDocument.fromJson(
        Map<String, dynamic>.from(jsonDecode(utf8.decode(payload)) as Map));
  }

  /// The matched root speed of database clip [clip] at [time] in model
  /// units per second.
  double rootSpeed(int clip, double time) {
    final s = samplerClips[clip];
    if (s == null) return 0.0;
    final d = sampler.clips[s].duration;
    final h = 1.0 / document.schema.sampleRate;
    final t0 = math.max(0.0, math.min(time, d - h));
    final a = rig.groundAt(s, t0), b = rig.groundAt(s, math.min(d, t0 + h));
    return math.sqrt((b.x - a.x) * (b.x - a.x) + (b.z - a.z) * (b.z - a.z)) / h;
  }
}
