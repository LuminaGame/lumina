import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:lumina_editor_data/lumina_editor.dart';

import 'package:lumina_ui/ui/features/sub_editors/services/anim_graph_asset_service.dart';

/// Whether a database's `.posedb` feature cache matches its document and its
/// mesh's clips.
enum PoseSearchCacheState { missing, stale, upToDate }

/// What a build of a pose search database reports.
class PoseSearchBuildReport {
  final LuminaPoseSearchBuildStats stats;
  final int cacheBytes;

  /// Mean / max time of 200 sample searches on the built index (µs).
  final double meanSearchMicroseconds;
  final int maxSearchMicroseconds;

  const PoseSearchBuildReport(this.stats, this.cacheBytes, this.meanSearchMicroseconds, this.maxSearchMicroseconds);
}

/// The Pose Search Database editor's file work, every bit of it off the UI
/// isolate: reading the document and the target mesh's clip list, building
/// the feature cache and checking whether it is current.
abstract final class PoseSearchDatabaseService {
  /// The `.posedb` path next to [relPath].
  static String cachePathOf(String relPath) => LuminaPoseSearchDatabaseRuntime.cachePathOf(relPath);

  static Future<LuminaPoseSearchDatabaseDocument?> read(String projectDir, String relPath) =>
      Isolate.run(() => AnimGraphAssetService.readPoseSearchDatabase(projectDir, relPath));

  static Future<void> write(String projectDir, String relPath, LuminaPoseSearchDatabaseDocument doc) {
    final json = doc.toJson();
    return Isolate.run(() => AnimGraphAssetService.writePoseSearchDatabase(
        projectDir, relPath, LuminaPoseSearchDatabaseDocument.fromJson(json)));
  }

  /// The clips stored in [meshRelPath]'s GLB.
  static Future<List<String>> clipNames(String projectDir, String meshRelPath) =>
      Isolate.run(() => AnimGraphAssetService.clipNames(projectDir, meshRelPath));

  /// The project's skeletal meshes (project relative paths).
  static Future<List<String>> skeletalMeshes(String projectDir) =>
      Isolate.run(() => [for (final a in AnimGraphAssetService.skeletalMeshes(projectDir)) a.relativePath]);

  /// The GLB the database's target mesh draws.
  static Future<Uint8List?> meshGlb(String projectDir, String meshRelPath) async {
    if (meshRelPath.isEmpty) return null;
    final companion = File('$projectDir/${meshRelPath.replaceAll(RegExp(r'\.lmas$'), '.entity.glb')}');
    if (meshRelPath.endsWith('.lmas') && await companion.exists()) return companion.readAsBytes();
    final file = File('$projectDir/$meshRelPath');
    if (!await file.exists()) return null;
    final bytes = await file.readAsBytes();
    if (!meshRelPath.endsWith('.lmas')) return bytes;
    return Isolate.run(() => LuminaAsset.fromBytes(bytes).rawPayload);
  }

  /// Whether the cache next to [relPath] fits [doc] and the mesh as it is.
  static Future<PoseSearchCacheState> cacheState(String projectDir, String relPath, LuminaPoseSearchDatabaseDocument doc) async {
    final cache = File('$projectDir/${cachePathOf(relPath)}');
    if (!await cache.exists()) return PoseSearchCacheState.missing;
    final glb = await meshGlb(projectDir, doc.targetMesh);
    if (glb == null) return PoseSearchCacheState.stale;
    final bytes = await cache.readAsBytes();
    final json = doc.toJson();
    final ok = await Isolate.run(() =>
        LuminaPoseSearchIndex.fingerprintOf(bytes) ==
        LuminaPoseSearchBuilder.fingerprint(glb, LuminaPoseSearchDatabaseDocument.fromJson(json)));
    return ok ? PoseSearchCacheState.upToDate : PoseSearchCacheState.stale;
  }

  /// Builds the feature cache of [doc] on a background isolate, writes it
  /// next to [relPath] and times sample searches on it.
  static Future<PoseSearchBuildReport> build(String projectDir, String relPath, LuminaPoseSearchDatabaseDocument doc) async {
    final glb = await meshGlb(projectDir, doc.targetMesh);
    if (glb == null) throw StateError('The target mesh ${doc.targetMesh} has no GLB to read clips from.');
    final result = await LuminaPoseSearchBuilder.buildInBackground(glb, doc);
    final cache = File('$projectDir/${cachePathOf(relPath)}');
    await cache.parent.create(recursive: true);
    await cache.writeAsBytes(result.cache);
    final bytes = result.cache;
    final timing = await Isolate.run(() {
      final index = LuminaPoseSearchIndex.decode(bytes);
      if (index.rowCount == 0) return (0.0, 0);
      final random = math.Random(1);
      var total = 0, max = 0;
      for (var i = 0; i < 200; i++) {
        final source = random.nextInt(index.rowCount);
        final q = Float32List.fromList([
          for (var d = 0; d < index.dimensions; d++) index.feature(source, d) + (random.nextDouble() - 0.5) * 0.2,
        ]);
        final w = Stopwatch()..start();
        index.search(q);
        w.stop();
        total += w.elapsedMicroseconds;
        max = math.max(max, w.elapsedMicroseconds);
      }
      return (total / 200.0, max);
    });
    LuminaPoseSearchDatabaseRuntime.clearShared();
    return PoseSearchBuildReport(result.stats, bytes.length, timing.$1, timing.$2);
  }
}
