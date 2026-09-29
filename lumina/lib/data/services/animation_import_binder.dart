import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../models/lumina_asset.dart';
import 'glb_animation_merger.dart';
import 'glb_animation_retargeter.dart';

/// A project skeletal mesh an imported animation could play on.
class SkeletonCandidate {
  /// `contents/...lmas`, relative to the project.
  final String lmasPath;
  final GlbSkeletonMatch match;

  const SkeletonCandidate(this.lmasPath, this.match);
}

/// Where an imported animation ended up on its skeletal mesh.
class AnimationBinding {
  final String meshLmasPath;
  final String meshAssetId;

  /// Retargeting details per clip, in clip order.
  final List<GlbRetargetResult> clips;

  const AnimationBinding({required this.meshLmasPath, required this.meshAssetId, required this.clips});
}

/// Binds imported animation clips to a project skeletal mesh.
///
/// gltfio only plays animations stored in the asset whose nodes they move, so
/// an animation-only import (an Unreal `AS_*.FBX`: skeleton + keys, no mesh)
/// is retargeted onto a skeletal mesh and appended to that mesh's GLB — the
/// `.entity.glb` companion and, when the mesh `.lmas` embeds one, its payload —
/// the way the Third Person template bundles its clips
/// (`tool/build_third_person_content.dart`).
abstract final class AnimationImportBinder {
  /// Least share of the clip's animated bones a skeleton must have to be
  /// picked automatically.
  static const double minimumAutoScore = 0.5;

  /// The GLB a skeletal mesh asset draws: its `.entity.glb` companion, else
  /// the `.lmas` payload.
  static Uint8List? meshGlb(String lmasAbsolutePath) {
    final companion = File(lmasAbsolutePath.replaceAll(RegExp(r'\.lmas$'), '.entity.glb'));
    if (companion.existsSync()) return companion.readAsBytesSync();
    final lmas = File(lmasAbsolutePath);
    if (!lmas.existsSync()) return null;
    try {
      final payload = LuminaAsset.fromBytes(lmas.readAsBytesSync()).rawPayload;
      if (payload != null && payload.length > 20 && payload[0] == 0x67) return payload;
    } catch (_) {}
    return null;
  }

  /// Scores every skeletal mesh in [skeletalMeshLmasPaths] (project-relative)
  /// against [clipGlb]'s first animation, best first. Meshes whose GLB cannot
  /// be read are left out.
  static List<SkeletonCandidate> rankTargets({
    required String projectPath,
    required List<String> skeletalMeshLmasPaths,
    required Uint8List clipGlb,
  }) {
    final animated = GlbAnimationRetargeter.animatedNodeNames(clipGlb);
    final ranked = <SkeletonCandidate>[];
    for (final rel in skeletalMeshLmasPaths) {
      final glb = meshGlb('$projectPath/$rel');
      if (glb == null) continue;
      try {
        final joints = GlbAnimationRetargeter.jointNames(glb);
        if (joints.isEmpty) continue;
        ranked.add(SkeletonCandidate(rel, GlbAnimationRetargeter.matchNames(joints, animated)));
      } catch (_) {}
    }
    ranked.sort((a, b) {
      final byScore = b.match.score.compareTo(a.match.score);
      return byScore != 0 ? byScore : b.match.matched.compareTo(a.match.matched);
    });
    return ranked;
  }

  /// The best of [rankTargets] when it clears [minimumAutoScore] with at
  /// least three matched bones.
  static SkeletonCandidate? pickTarget({
    required String projectPath,
    required List<String> skeletalMeshLmasPaths,
    required Uint8List clipGlb,
  }) {
    final ranked = rankTargets(projectPath: projectPath, skeletalMeshLmasPaths: skeletalMeshLmasPaths, clipGlb: clipGlb);
    if (ranked.isEmpty) return null;
    final best = ranked.first;
    return best.match.score >= minimumAutoScore && best.match.matched >= 3 ? best : null;
  }

  /// Retargets every animation of [clipGlb] onto the skeletal mesh at
  /// [meshLmasPath] (project-relative) as [clipNames] (one per animation),
  /// writes the mesh's GLB back (companion and embedded payload) and lists the
  /// clips in the mesh's `animation_clips` metadata.
  static AnimationBinding bind({
    required String projectPath,
    required String meshLmasPath,
    required Uint8List clipGlb,
    required List<String> clipNames,
  }) {
    final lmasFile = File('$projectPath/$meshLmasPath');
    if (!lmasFile.existsSync()) throw FileSystemException('Skeletal mesh asset not found', lmasFile.path);
    final meshAsset = LuminaAsset.fromBytes(lmasFile.readAsBytesSync());
    var glb = meshGlb(lmasFile.path);
    if (glb == null) throw FileSystemException('Skeletal mesh has no GLB to add the clip to', lmasFile.path);

    final available = GlbAnimationMerger.animationNames(clipGlb).length;
    final results = <GlbRetargetResult>[];
    for (var i = 0; i < clipNames.length && i < available; i++) {
      final result = GlbAnimationRetargeter.retargetInto(
        target: glb!,
        clip: clipGlb,
        clipName: clipNames[i],
        animationIndex: i,
      );
      results.add(result);
      glb = result.glb;
    }

    final companion = File(lmasFile.path.replaceAll(RegExp(r'\.lmas$'), '.entity.glb'));
    companion.writeAsBytesSync(glb!);

    final clips = GlbAnimationMerger.animationNames(glb);
    final metadata = Map<String, String>.from(meshAsset.metadata)..['animation_clips'] = clips.join(',');
    final hasPayload = meshAsset.rawPayload != null && meshAsset.rawPayload!.isNotEmpty;
    final updated = LuminaAsset(
      assetId: meshAsset.assetId,
      name: meshAsset.name,
      type: meshAsset.type,
      hasThumbnail: meshAsset.hasThumbnail,
      thumbnailPng: meshAsset.thumbnailPng,
      rawPayload: hasPayload ? glb : meshAsset.rawPayload,
      rawMatSource: meshAsset.rawMatSource,
      metadata: metadata,
      references: meshAsset.references,
    );
    lmasFile.writeAsBytesSync(updated.toProtoBufferBytes());
    return AnimationBinding(meshLmasPath: meshLmasPath, meshAssetId: meshAsset.assetId, clips: results);
  }

  /// Metadata of an animation asset bound to [meshLmasPath] as clip
  /// [result] — the same keys the Third Person template's clip assets carry,
  /// so the Animation editor and Animation Blueprints resolve it the same way.
  static Map<String, String> clipMetadata(String meshLmasPath, GlbRetargetResult result) => {
        'source_mesh': meshLmasPath,
        'clip_name': result.clipName,
        'clip_index': '${result.clipIndex}',
        'anim_properties': jsonEncode({
          'rate_scale': 1.0,
          'interpolation': 'Linear',
          'additive_type': 'No Additive',
          'frame_rate': 30.0,
          'default_clip': result.clipIndex,
          'preview_mesh_path': meshLmasPath,
        }),
        'retarget_mode': 'rotation_only',
        'retarget_mapped_bones': '${result.mappedBones.length}',
        'retarget_rest_bones': result.restBones.join(','),
        'retarget_ignored_bones': result.ignoredSourceBones.join(','),
        'retarget_pelvis_scale': result.pelvisTranslationScale.toStringAsFixed(4),
        'duration_seconds': result.duration.toStringAsFixed(3),
      };
}
