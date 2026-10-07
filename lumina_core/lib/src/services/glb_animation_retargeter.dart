import 'dart:math' as math;
import 'dart:typed_data';

import 'package:lumina_core/src/services/glb_animation_merger.dart';
import 'package:lumina_core/src/services/engine_logger_service.dart';

part 'glb_animation_retargeter/models.dart';
part 'glb_animation_retargeter/pose_sampling.dart';
part 'glb_animation_retargeter/soma_mapping.dart';
part 'glb_animation_retargeter/operation.dart';

/// Retargets skeletal animation across humanoid skeletons and appends it to
/// the target GLB, so one gltfio asset plays the mesh and its motion together.
///
/// Unlike [GlbAnimationMerger], which copies channels verbatim onto an
/// identical skeleton, this handles skeletons that differ in hierarchy and
/// proportions and reference axes:
///
/// - **Rotation only.** Every matched bone takes the clip bone's rotation in
///   model space (the clip's forward kinematics); its local rotation follows
///   from its target parent. Skeleton bones the clip lacks keep their rest
///   rotation relative to their parent. Both skeletons must share the bone
///   axis convention and model space — true for glTF exported by Unreal and
///   for FBX normalized by `FbxImportService` (both Y up, facing +Z).
/// - **Translations come from the target skeleton**, except the skeleton root
///   (copied: root motion and placement) and the pelvis (copied, scaled by the
///   target's leg length over the clip's).
///   Clip bone translations are otherwise ignored: an Unreal FBX carries the
///   authoring skeleton's proportions in them.
///
/// Every skeleton joint gets a rotation and a translation channel (constant
/// ones where nothing moves), so switching from another clip of the asset
/// cannot leave a bone where that clip put it.
///
/// GEM-X SOMA clips require a neutral reference pose. Their model-space motion
/// deltas drive the target bind axes, with explicit thigh/shin mapping and
/// root-relative translation added to the target pelvis placement. Existing
/// exports without that reference must be regenerated.
abstract final class GlbAnimationRetargeter {
  /// All node indices of a target skeleton: skin joints, ancestors up to the
  /// root, and any intermediate bone nodes.
  static Set<int> _skeletonNodeIndices(Map<String, dynamic> json) {
    final skins = (json['skins'] as List?) ?? const [];
    if (skins.isEmpty) return const {};
    final nodes = (json['nodes'] as List?) ?? const [];
    final parent = List<int>.filled(nodes.length, -1);
    for (var i = 0; i < nodes.length; i++) {
      for (final c in ((nodes[i] as Map)['children'] as List?) ?? const []) {
        if (c is int && c >= 0 && c < nodes.length) parent[c] = i;
      }
    }
    final skeletonNodes = <int>{};
    for (final s in skins) {
      if (s is! Map) continue;
      final skeletonRoot = s['skeleton'] as int?;
      if (skeletonRoot != null && skeletonRoot >= 0 && skeletonRoot < nodes.length) {
        skeletonNodes.add(skeletonRoot);
      }
      for (final j in (s['joints'] as List?) ?? const []) {
        if (j is! int || j < 0 || j >= nodes.length) continue;
        var curr = j;
        while (curr >= 0) {
          if (!skeletonNodes.add(curr)) break;
          curr = parent[curr];
        }
      }
    }
    for (final s in skins) {
      if (s is! Map) continue;
      final skeletonRoot = s['skeleton'] as int?;
      if (skeletonRoot != null && skeletonRoot >= 0 && skeletonRoot < nodes.length) {
        void visit(int n) {
          if ((nodes[n] as Map)['mesh'] == null) {
            skeletonNodes.add(n);
            for (final c in ((nodes[n] as Map)['children'] as List?) ?? const []) {
              if (c is int && c >= 0 && c < nodes.length) visit(c);
            }
          }
        }

        visit(skeletonRoot);
      }
    }
    return skeletonNodes;
  }

  /// Names of the joints of every skin in [glb], including intermediate
  /// skeleton hierarchy nodes.
  static Set<String> jointNames(Uint8List glb) {
    final json = GlbDocument.parse(glb).json;
    final nodes = (json['nodes'] as List?) ?? const [];
    final indices = _skeletonNodeIndices(json);
    return {
      for (final j in indices)
        if ((nodes[j] as Map)['name'] is String) (nodes[j] as Map)['name'] as String,
    };
  }

  /// Names of the nodes animation [animationIndex] of [clip] animates.
  static Set<String> animatedNodeNames(Uint8List clip, {int animationIndex = 0}) {
    final json = GlbDocument.parse(clip).json;
    final nodes = (json['nodes'] as List?) ?? const [];
    final animations = (json['animations'] as List?) ?? const [];
    if (animationIndex < 0 || animationIndex >= animations.length) return const {};
    return {
      for (final c in ((animations[animationIndex] as Map)['channels'] as List?) ?? const [])
        if (((c as Map)['target'] as Map)['node'] is int)
          if ((nodes[(c['target'] as Map)['node'] as int] as Map)['name'] is String)
            (nodes[(c['target'] as Map)['node'] as int] as Map)['name'] as String,
    };
  }

  /// How well [clip]'s animation matches [target]'s skeleton.
  static GlbSkeletonMatch match({
    required Uint8List target,
    required Uint8List clip,
    int animationIndex = 0,
  }) => matchNames(jointNames(target), animatedNodeNames(clip, animationIndex: animationIndex));

  static const Map<String, List<String>> _humanoidSynonyms = {
    'pelvis': ['hips', 'pelvis', 'root'],
    'hips': ['hips', 'pelvis', 'root'],
    'spine_01': ['spine1', 'spine_01', 'spine'],
    'spine1': ['spine1', 'spine_01', 'spine'],
    'spine': ['spine1', 'spine_01', 'spine'],
    'spine_02': ['spine2', 'spine_02'],
    'spine2': ['spine2', 'spine_02'],
    'spine_03': ['chest', 'spine3', 'spine_03'],
    'spine3': ['chest', 'spine3', 'spine_03'],
    'chest': ['chest', 'spine_03', 'spine3'],
    'neck_01': ['neck1', 'neck_01', 'neck'],
    'neck1': ['neck1', 'neck_01', 'neck'],
    'neck': ['neck1', 'neck_01', 'neck'],
    'head': ['head', 'head_01'],
    'clavicle_l': ['leftshoulder', 'clavicle_l', 'shoulder_l'],
    'leftshoulder': ['leftshoulder', 'clavicle_l', 'shoulder_l'],
    'upperarm_l': ['leftarm', 'upperarm_l', 'arm_l'],
    'leftarm': ['leftarm', 'upperarm_l', 'arm_l'],
    'lowerarm_l': ['leftforearm', 'lowerarm_l', 'forearm_l'],
    'leftforearm': ['leftforearm', 'lowerarm_l', 'forearm_l'],
    'hand_l': ['lefthand', 'hand_l'],
    'lefthand': ['lefthand', 'hand_l'],
    'clavicle_r': ['rightshoulder', 'clavicle_r', 'shoulder_r'],
    'rightshoulder': ['rightshoulder', 'clavicle_r', 'shoulder_r'],
    'upperarm_r': ['rightarm', 'upperarm_r', 'arm_r'],
    'rightarm': ['rightarm', 'upperarm_r', 'arm_r'],
    'lowerarm_r': ['rightforearm', 'lowerarm_r', 'forearm_r'],
    'rightforearm': ['rightforearm', 'lowerarm_r', 'forearm_r'],
    'hand_r': ['righthand', 'hand_r'],
    'righthand': ['righthand', 'hand_r'],
    'thigh_l': ['leftupleg', 'thigh_l', 'upleg_l'],
    'leftupleg': ['leftupleg', 'thigh_l', 'upleg_l'],
    'calf_l': ['leftleg', 'calf_l', 'lowerleg_l'],
    'leftleg': ['leftleg', 'calf_l', 'lowerleg_l'],
    'foot_l': ['leftfoot', 'foot_l'],
    'leftfoot': ['leftfoot', 'foot_l'],
    'thigh_r': ['rightupleg', 'thigh_r', 'upleg_r'],
    'rightupleg': ['rightupleg', 'thigh_r', 'upleg_r'],
    'calf_r': ['rightleg', 'calf_r', 'lowerleg_r'],
    'rightleg': ['rightleg', 'calf_r', 'lowerleg_r'],
    'foot_r': ['rightfoot', 'foot_r'],
    'rightfoot': ['rightfoot', 'foot_r'],
  };

  /// Checks whether a bone is a facial joint or corrective bone that should not
  /// be written as a static animation track into body animation clips.
  static bool isCorrectiveOrFace(String name) {
    final lower = name.toLowerCase();
    final clean = lower.startsWith('mixamorig:') ? lower.substring(10) : lower;
    return clean.startsWith('facial_') ||
        clean.startsWith('facialroot') ||
        clean.contains('corrective') ||
        clean.contains('twistcor') ||
        clean.contains('_bck') ||
        clean.contains('_fwd') ||
        clean.contains('_in_') ||
        clean.contains('_out_') ||
        clean.endsWith('_in') ||
        clean.endsWith('_out') ||
        clean.contains('_lwr_') ||
        clean.endsWith('_lwr') ||
        clean.contains('tricep') ||
        clean.contains('bicep') ||
        clean.contains('kneeback') ||
        clean.contains('eyeball') ||
        clean.contains('jaw') ||
        clean.contains('tongue');
  }

  /// Checks whether a bone belongs to the arm/hand chain that requires
  /// A-Pose <-> T-Pose alignment and orientation propagation.
  static bool _isArmBone(String? name) {
    if (name == null) return false;
    final lower = name.toLowerCase();
    final clean = lower.startsWith('mixamorig:') ? lower.substring(10) : lower;
    return clean == 'upperarm_l' ||
        clean == 'upperarm_r' ||
        clean == 'lowerarm_l' ||
        clean == 'lowerarm_r' ||
        clean == 'hand_l' ||
        clean == 'hand_r' ||
        clean == 'leftarm' ||
        clean == 'rightarm' ||
        clean == 'leftforearm' ||
        clean == 'rightforearm' ||
        clean == 'lefthand' ||
        clean == 'righthand';
  }

  static int? _resolveSourceBone(
    String targetName,
    Map<String, int> srcByName,
    Map<String, int> srcByNameLower,
  ) {
    if (isCorrectiveOrFace(targetName)) return null;

    final direct = srcByName[targetName] ?? srcByNameLower[targetName.toLowerCase()];
    if (direct != null) return direct;

    final lower = targetName.toLowerCase();
    final clean = lower.startsWith('mixamorig:') ? lower.substring(10) : lower;
    final directClean = srcByNameLower[clean];
    if (directClean != null) return directClean;

    final candidates = _humanoidSynonyms[clean];
    if (candidates != null) {
      for (final cand in candidates) {
        final match = srcByNameLower[cand];
        if (match != null) return match;
      }
    }
    return null;
  }

  static GlbSkeletonMatch matchNames(Set<String> targetJoints, Set<String> animated) {
    final targetLower = {for (final j in targetJoints) j.toLowerCase()};
    bool matches(String animBone) {
      if (targetJoints.contains(animBone)) return true;
      final lower = animBone.toLowerCase();
      if (targetLower.contains(lower)) return true;
      final clean = lower.startsWith('mixamorig:') ? lower.substring(10) : lower;
      if (targetLower.contains(clean)) return true;
      final synonyms = _humanoidSynonyms[clean];
      if (synonyms != null) {
        for (final s in synonyms) {
          if (targetLower.contains(s)) return true;
        }
      }
      return false;
    }

    final missing = [
      for (final n in animated)
        if (!matches(n)) n,
    ]..sort();
    return GlbSkeletonMatch(
      matched: animated.length - missing.length,
      animated: animated.length,
      missing: missing,
    );
  }

  /// Retargets animation [animationIndex] of [clip] onto [target]'s skeleton
  /// and returns [target] with it appended as [clipName] (replacing an
  /// animation of that name).
  ///
  /// Throws [FormatException] when either input is not a GLB, [target] has no
  /// skin, the animation index is out of range, or no bone matches.
  static GlbRetargetResult retargetInto({
    required Uint8List target,
    required Uint8List clip,
    required String clipName,
    int animationIndex = 0,
  }) => _RetargetOperation.run(
    target: target,
    clip: clip,
    clipName: clipName,
    animationIndex: animationIndex,
  );

  static double _length(List<double> v) => math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]);
}
