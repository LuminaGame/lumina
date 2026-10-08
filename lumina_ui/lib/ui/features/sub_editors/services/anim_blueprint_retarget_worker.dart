import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:lumina_editor_data/lumina_editor.dart';

import 'package:lumina_ui/ui/features/sub_editors/services/anim_graph_asset_service.dart';

/// What [AnimBlueprintRetargetWorker.run] retargets: the clips an Animation
/// Blueprint uses (its states' clips and its Blend Spaces' samples) from
/// [sourceMeshRel] onto [targetMeshRel], inside [projectDir].
class AnimBlueprintRetargetJob {
  const AnimBlueprintRetargetJob({
    required this.projectDir,
    required this.sourceMeshRel,
    required this.targetMeshRel,
    required this.directClips,
    required this.blendSpacePaths,
    this.knownBlendSpaces = const {},
  });

  final String projectDir;
  final String sourceMeshRel;
  final String targetMeshRel;

  /// Clips the states play directly.
  final Set<String> directClips;

  /// Blend Spaces the states play (project-relative `.lmas` paths).
  final Set<String> blendSpacePaths;

  /// Blend Spaces the editor already has loaded, by path; the rest are read.
  final Map<String, LuminaBlendSpaceDocument> knownBlendSpaces;
}

/// What a retarget wrote.
class AnimBlueprintRetargetResult {
  const AnimBlueprintRetargetResult(
    this.retargetedClips,
    this.oldToNewBlendSpaces,
    this.messages,
  );

  /// Clip names written under `contents/animations/<target>/`.
  final List<String> retargetedClips;

  /// Each retargeted Blend Space's old path → its copy for the target mesh.
  final Map<String, String> oldToNewBlendSpaces;

  /// Clips that could not be found or retargeted.
  final List<String> messages;
}

/// Retargets an Animation Blueprint's clips on a background isolate.
///
/// Reading both meshes' GLBs (hundreds of megabytes for a MetaHuman),
/// retargeting every clip into the target GLB and writing the clip files,
/// the target mesh and the Blend Spaces is all file I/O and CPU work, so none
/// of it runs on the UI isolate: the editor stays responsive and shows its
/// progress state while this runs.
abstract final class AnimBlueprintRetargetWorker {
  /// Runs [job] on a background isolate.
  static Future<AnimBlueprintRetargetResult> run(
    AnimBlueprintRetargetJob job,
  ) => Isolate.run(() => execute(job));

  /// The retarget itself, on the calling isolate (a worker, or a test).
  static AnimBlueprintRetargetResult execute(AnimBlueprintRetargetJob job) {
    final dir = job.projectDir;
    final targetBase = AnimGraphAssetService.baseName(job.targetMeshRel);
    final sourceBase = AnimGraphAssetService.baseName(job.sourceMeshRel);
    final messages = <String>[];

    // 1. The clips: direct ones and every Blend Space sample.
    final blendSpaces = <String, LuminaBlendSpaceDocument>{};
    final clips = <String>{...job.directClips};
    for (final path in job.blendSpacePaths) {
      final doc =
          job.knownBlendSpaces[path] ??
          AnimGraphAssetService.readBlendSpace(dir, path);
      if (doc == null) continue;
      blendSpaces[path] = doc;
      for (final s in doc.samples) {
        if (s.clip.isNotEmpty) clips.add(s.clip);
      }
    }
    final allClips = clips.toList()..sort();

    // 2. Source and target GLBs.
    final sourceGlb = _meshGlb(dir, job.sourceMeshRel);
    final targetCompFile = File(
      '$dir/${job.targetMeshRel.replaceAll(RegExp(r'\.lmas$'), '.entity.glb')}',
    );
    final targetGlb = _meshGlb(dir, job.targetMeshRel);
    if (targetGlb == null) {
      throw Exception(
        'Target skeletal mesh GLB not found for ${job.targetMeshRel}',
      );
    }
    final sourceNames = sourceGlb == null
        ? const <String>[]
        : _names(sourceGlb);

    ({Uint8List glb, int index})? resolveClipSource(String clipName) {
      if (sourceGlb != null) {
        final idx = sourceNames.indexOf(clipName);
        if (idx >= 0) return (glb: sourceGlb, index: idx);
      }
      final candidates = [
        '$dir/contents/animations/$sourceBase/$clipName.entity.glb',
        '$dir/contents/animations/$sourceBase/$clipName.lmas',
        '$dir/contents/animations/$clipName.entity.glb',
        '$dir/contents/animations/$clipName.lmas',
      ];
      for (final c in candidates) {
        final f = File(c);
        if (!f.existsSync()) continue;
        try {
          final bytes = f.readAsBytesSync();
          final glb = c.endsWith('.entity.glb')
              ? bytes
              : LuminaAsset.fromBytes(bytes).rawPayload;
          if (glb == null || glb.isEmpty) continue;
          final idx = GlbAnimationMerger.animationNames(glb).indexOf(clipName);
          return (glb: glb, index: idx >= 0 ? idx : 0);
        } catch (_) {}
      }
      return null;
    }

    // 3. Every clip into the target GLB, one file pair per clip.
    var currentTargetGlb = targetGlb;
    final retargetedClips = <String>[];
    final targetAnimDir = Directory('$dir/contents/animations/$targetBase')
      ..createSync(recursive: true);
    for (final clipName in allClips) {
      final src = resolveClipSource(clipName);
      if (src == null) {
        messages.add('Source clip not found: $clipName');
        continue;
      }
      try {
        final res = GlbAnimationRetargeter.retargetInto(
          target: currentTargetGlb,
          clip: src.glb,
          clipName: clipName,
          animationIndex: src.index,
        );
        currentTargetGlb = res.glb;
        retargetedClips.add(clipName);
        File(
          '${targetAnimDir.path}/$clipName.entity.glb',
        ).writeAsBytesSync(res.glb);
        final animAsset = LuminaAsset(
          assetId:
              'retarget_${clipName}_${DateTime.now().millisecondsSinceEpoch}',
          name: clipName,
          type: AssetType.animation,
          rawPayload: Uint8List(0),
          metadata: {
            'source_mesh': job.targetMeshRel,
            'target_mesh': job.targetMeshRel,
            'preview_mesh_path': job.targetMeshRel,
            'clip_name': clipName,
            'clip_index': '${res.clipIndex}',
            'last_modified': DateTime.now().toIso8601String(),
          },
        );
        File(
          '${targetAnimDir.path}/$clipName.lmas',
        ).writeAsBytesSync(animAsset.toProtoBufferBytes());
      } catch (e) {
        messages.add('Error retargeting $clipName: $e');
      }
    }

    // 4. The target mesh's GLB and its clip list.
    if (retargetedClips.isNotEmpty) {
      targetCompFile.writeAsBytesSync(currentTargetGlb);
      final targetLmasFile = File('$dir/${job.targetMeshRel}');
      if (targetLmasFile.existsSync() && job.targetMeshRel.endsWith('.lmas')) {
        try {
          final lmas = LuminaAsset.fromBytes(targetLmasFile.readAsBytesSync());
          final meta = Map<String, String>.from(lmas.metadata);
          meta['animation_clips'] = _names(currentTargetGlb).join(',');
          final updated = LuminaAsset(
            assetId: lmas.assetId,
            name: lmas.name,
            type: lmas.type,
            rawPayload: lmas.rawPayload,
            rawMatSource: lmas.rawMatSource,
            thumbnailPng: lmas.thumbnailPng,
            hasThumbnail: lmas.hasThumbnail,
            references: lmas.references,
            metadata: meta,
          );
          targetLmasFile.writeAsBytesSync(updated.toProtoBufferBytes());
        } catch (_) {}
      }
    }

    // 5. A copy of each Blend Space for the target mesh.
    final oldToNew = <String, String>{};
    for (final entry in blendSpaces.entries) {
      final newRel =
          'contents/animations/$targetBase/${AnimGraphAssetService.baseName(entry.key)}.lmas';
      AnimGraphAssetService.writeBlendSpace(
        dir,
        newRel,
        LuminaBlendSpaceDocument(
          axes: entry.value.axes,
          samples: entry.value.samples,
        ),
        targetMesh: job.targetMeshRel,
      );
      oldToNew[entry.key] = newRel;
    }
    return AnimBlueprintRetargetResult(retargetedClips, oldToNew, messages);
  }

  /// A mesh's GLB: its `.entity.glb` companion, else the `.lmas` payload.
  static Uint8List? _meshGlb(String dir, String meshRel) {
    if (meshRel.isEmpty) return null;
    final companion = File(
      '$dir/${meshRel.replaceAll(RegExp(r'\.lmas$'), '.entity.glb')}',
    );
    if (companion.existsSync()) return companion.readAsBytesSync();
    final lmas = File('$dir/$meshRel');
    if (!lmas.existsSync()) return null;
    try {
      final payload = LuminaAsset.fromBytes(lmas.readAsBytesSync()).rawPayload;
      return payload == null || payload.isEmpty ? null : payload;
    } catch (_) {
      return null;
    }
  }

  static List<String> _names(Uint8List glb) {
    try {
      return GlbAnimationMerger.animationNames(glb);
    } catch (_) {
      return const [];
    }
  }
}
