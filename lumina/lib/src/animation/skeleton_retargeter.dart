import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart';
import '../components/mesh/skeletal_mesh_component.dart';
import 'animation_clip.dart';

/// Translation scaling mode used when transferring motion between skeletons.
enum RetargetTranslationMode {
  /// Scales root and limb translation proportionally by skeleton height / bone length ratios.
  globallyScaled,

  /// Copies absolute translation in world/parent space.
  absolute,

  /// Ignores translation and preserves target skeleton's rest translation.
  none,
}

/// A mapping definition linking a bone or chain from source skeleton to target skeleton.
class BoneChainMapping {
  final String chainName;
  final String sourceStartBone;
  final String sourceEndBone;
  final String targetStartBone;
  final String targetEndBone;
  final RetargetTranslationMode translationMode;

  const BoneChainMapping({
    required this.chainName,
    required this.sourceStartBone,
    required this.sourceEndBone,
    required this.targetStartBone,
    required this.targetEndBone,
    this.translationMode = RetargetTranslationMode.globallyScaled,
  });
}

/// Processor that transfers animation tracks and poses from a source skeleton to a target skeleton.
class LuminaSkeletonRetargeter {
  final Skeleton sourceSkeleton;
  final Skeleton targetSkeleton;
  final List<BoneChainMapping> chainMappings;
  final Map<String, Quaternion> sourceRestPoseOffsets;
  final Map<String, Quaternion> targetRestPoseOffsets;

  // Internal lookup maps for bone index conversions
  final Map<int, int> _sourceBoneToTargetBone = {};
  final Map<int, RetargetTranslationMode> _targetBoneTranslationModes = {};
  double _heightRatio = 1.0;

  LuminaSkeletonRetargeter({
    required this.sourceSkeleton,
    required this.targetSkeleton,
    required this.chainMappings,
    Map<String, Quaternion>? sourceRestPoseOffsets,
    Map<String, Quaternion>? targetRestPoseOffsets,
  })  : sourceRestPoseOffsets = sourceRestPoseOffsets ?? const {},
        targetRestPoseOffsets = targetRestPoseOffsets ?? const {} {
    _initializeMappings();
  }

  void _initializeMappings() {
    for (final chain in chainMappings) {
      final sIdx = sourceSkeleton.indexOfBone(chain.sourceStartBone);
      final tIdx = targetSkeleton.indexOfBone(chain.targetStartBone);
      if (sIdx != -1 && tIdx != -1) {
        _sourceBoneToTargetBone[sIdx] = tIdx;
        _targetBoneTranslationModes[tIdx] = chain.translationMode;
      }
      if (chain.sourceEndBone != chain.sourceStartBone && chain.targetEndBone != chain.targetStartBone) {
        final sEnd = sourceSkeleton.indexOfBone(chain.sourceEndBone);
        final tEnd = targetSkeleton.indexOfBone(chain.targetEndBone);
        if (sEnd != -1 && tEnd != -1) {
          _sourceBoneToTargetBone[sEnd] = tEnd;
          _targetBoneTranslationModes[tEnd] = chain.translationMode;
        }
      }
    }

    // Compute height / scale ratio from Pelvis/Root height if available
    final sPelvis = _findPelvisBone(sourceSkeleton);
    final tPelvis = _findPelvisBone(targetSkeleton);
    if (sPelvis != null && tPelvis != null && sPelvis.bindTranslation.z > 0.001) {
      _heightRatio = tPelvis.bindTranslation.z / sPelvis.bindTranslation.z;
    } else if (sPelvis != null && tPelvis != null && sPelvis.bindTranslation.y > 0.001) {
      _heightRatio = tPelvis.bindTranslation.y / sPelvis.bindTranslation.y;
    } else {
      _heightRatio = 1.0;
    }
  }

  BoneNode? _findPelvisBone(Skeleton skeleton) {
    for (int i = 0; i < skeleton.boneCount; i++) {
      final name = skeleton[i].name.toLowerCase();
      if (name.contains('pelvis') || name.contains('hips') || name.contains('hip')) {
        return skeleton[i];
      }
    }
    return skeleton.boneCount > 1 ? skeleton[1] : null;
  }

  /// Automatically matches standard humanoid bone naming conventions between two skeletons.
  static List<BoneChainMapping> autoMapHumanoidChains(Skeleton source, Skeleton target) {
    final List<BoneChainMapping> result = [];

    final standardChains = <String, List<List<String>>>{
      'Root': [
        ['root', 'origin'],
        ['root', 'origin', 'armature']
      ],
      'Pelvis': [
        ['pelvis', 'hips', 'hip', 'root_motion'],
        ['pelvis', 'hips', 'hip', 'b_pelvis']
      ],
      'Spine': [
        ['spine_01', 'spine1', 'spine'],
        ['spine_01', 'spine1', 'spine', 'spine_02', 'spine2']
      ],
      'Head': [
        ['head', 'head_01', 'b_head'],
        ['head', 'head_01', 'b_head']
      ],
      'LeftClavicle': [
        ['clavicle_l', 'leftshoulder', 'shoulder_l', 'l_shoulder', 'l_clavicle'],
        ['clavicle_l', 'leftshoulder', 'shoulder_l', 'l_shoulder', 'l_clavicle']
      ],
      'RightClavicle': [
        ['clavicle_r', 'rightshoulder', 'shoulder_r', 'r_shoulder', 'r_clavicle'],
        ['clavicle_r', 'rightshoulder', 'shoulder_r', 'r_shoulder', 'r_clavicle']
      ],
      'LeftArm': [
        ['upperarm_l', 'leftarm', 'l_upperarm', 'arm_l', 'left_arm'],
        ['lowerarm_l', 'leftforearm', 'l_forearm', 'forearm_l', 'left_forearm']
      ],
      'RightArm': [
        ['upperarm_r', 'rightarm', 'r_upperarm', 'arm_r', 'right_arm'],
        ['lowerarm_r', 'rightforearm', 'r_forearm', 'forearm_r', 'right_forearm']
      ],
      'LeftHand': [
        ['hand_l', 'lefthand', 'l_hand', 'left_hand'],
        ['hand_l', 'lefthand', 'l_hand', 'left_hand']
      ],
      'RightHand': [
        ['hand_r', 'righthand', 'r_hand', 'right_hand'],
        ['hand_r', 'righthand', 'r_hand', 'right_hand']
      ],
      'LeftLeg': [
        ['thigh_l', 'leftupleg', 'l_thigh', 'leg_l', 'left_leg'],
        ['calf_l', 'leftleg', 'l_calf', 'shin_l', 'left_shin']
      ],
      'RightLeg': [
        ['thigh_r', 'rightupleg', 'r_thigh', 'leg_r', 'right_leg'],
        ['calf_r', 'rightleg', 'r_calf', 'shin_r', 'right_shin']
      ],
      'LeftFoot': [
        ['foot_l', 'leftfoot', 'l_foot', 'left_foot'],
        ['foot_l', 'leftfoot', 'l_foot', 'left_foot']
      ],
      'RightFoot': [
        ['foot_r', 'rightfoot', 'r_foot', 'right_foot'],
        ['foot_r', 'rightfoot', 'r_foot', 'right_foot']
      ],
    };

    standardChains.forEach((chainName, patterns) {
      final sStart = _matchBone(source, patterns[0]);
      final sEnd = _matchBone(source, patterns[1]);
      final tStart = _matchBone(target, patterns[0]);
      final tEnd = _matchBone(target, patterns[1]);

      if (sStart != null && tStart != null) {
        result.add(BoneChainMapping(
          chainName: chainName,
          sourceStartBone: sStart,
          sourceEndBone: sEnd ?? sStart,
          targetStartBone: tStart,
          targetEndBone: tEnd ?? tStart,
          translationMode: (chainName == 'Pelvis' || chainName == 'Root')
              ? RetargetTranslationMode.globallyScaled
              : RetargetTranslationMode.none,
        ));
      }
    });

    return result;
  }

  static String? _matchBone(Skeleton skeleton, List<String> patterns) {
    for (int i = 0; i < skeleton.boneCount; i++) {
      final boneName = skeleton[i].name;
      final clean = boneName.toLowerCase().replaceAll('mixamorig:', '').replaceAll('b_', '').replaceAll('val_', '');
      for (final p in patterns) {
        if (clean == p || clean.contains(p) || boneName.toLowerCase().contains(p)) {
          return boneName;
        }
      }
    }
    return null;
  }

  /// Retargets an immutable animation clip to target skeleton tracks.
  LuminaAnimationClip retargetClip(LuminaAnimationClip sourceClip, {String? targetClipName}) {
    final List<BoneTrack> newTracks = [];

    for (final sTrack in sourceClip.tracks) {
      final tIdx = _sourceBoneToTargetBone[sTrack.boneIndex];
      if (tIdx == null || tIdx < 0 || tIdx >= targetSkeleton.boneCount) continue;

      final sBone = sourceSkeleton[sTrack.boneIndex];
      final tBone = targetSkeleton[tIdx];

      final sRestOffset = sourceRestPoseOffsets[sBone.name] ?? Quaternion.identity();
      final tRestOffset = targetRestPoseOffsets[tBone.name] ?? Quaternion.identity();
      // Delta transform: R_target = Q_target_offset * R_source * Q_source_offset^-1
      final sRestInv = Quaternion(sRestOffset.x, sRestOffset.y, sRestOffset.z, sRestOffset.w);
      sRestInv.conjugate();

      final mode = _targetBoneTranslationModes[tIdx] ?? RetargetTranslationMode.none;

      final List<Vector3> newPositions = [];
      for (final p in sTrack.positions) {
        if (mode == RetargetTranslationMode.globallyScaled) {
          final diff = p - sBone.bindTranslation;
          newPositions.add(tBone.bindTranslation + (diff * _heightRatio));
        } else if (mode == RetargetTranslationMode.absolute) {
          newPositions.add(Vector3.copy(p));
        } else {
          newPositions.add(Vector3.copy(tBone.bindTranslation));
        }
      }

      final List<Quaternion> newRotations = [];
      for (final r in sTrack.rotations) {
        final compensated = tRestOffset * (r * sRestInv);
        newRotations.add(compensated..normalize());
      }

      final List<Vector3> newScales = [];
      for (final s in sTrack.scales) {
        newScales.add(Vector3.copy(s));
      }

      newTracks.add(BoneTrack(
        boneIndex: tIdx,
        times: List<double>.from(sTrack.times),
        positions: newPositions,
        rotations: newRotations,
        scales: newScales,
      ));
    }

    return LuminaAnimationClip(
      name: targetClipName ?? '${sourceClip.name}_Retargeted',
      duration: sourceClip.duration,
      tracks: newTracks,
    );
  }

  /// Retargets a live evaluated local pose buffer to the target skeleton local pose buffer.
  void retargetPose(List<Matrix4> sourceLocalPose, List<Matrix4> outTargetLocalPose) {
    for (int tIdx = 0; tIdx < targetSkeleton.boneCount && tIdx < outTargetLocalPose.length; tIdx++) {
      final tBone = targetSkeleton[tIdx];
      // Reset to bind pose default
      outTargetLocalPose[tIdx].setFromTranslationRotationScale(
        tBone.bindTranslation,
        tBone.bindRotation,
        tBone.bindScale,
      );
    }

    _sourceBoneToTargetBone.forEach((sIdx, tIdx) {
      if (sIdx < sourceLocalPose.length && tIdx < outTargetLocalPose.length) {
        final sMat = sourceLocalPose[sIdx];
        final sPos = sMat.getTranslation();
        final sRot = Quaternion.fromRotation(sMat.getRotation());
        final sScale = sMat.getMaxScaleOnAxis();

        final sBone = sourceSkeleton[sIdx];
        final tBone = targetSkeleton[tIdx];

        final sRestOffset = sourceRestPoseOffsets[sBone.name] ?? Quaternion.identity();
        final tRestOffset = targetRestPoseOffsets[tBone.name] ?? Quaternion.identity();
        final sRestInv = Quaternion(sRestOffset.x, sRestOffset.y, sRestOffset.z, sRestOffset.w)..conjugate();

        final compensatedRot = tRestOffset * (sRot * sRestInv)..normalize();

        final mode = _targetBoneTranslationModes[tIdx] ?? RetargetTranslationMode.none;
        final Vector3 outPos;
        if (mode == RetargetTranslationMode.globallyScaled) {
          final diff = sPos - sBone.bindTranslation;
          outPos = tBone.bindTranslation + (diff * _heightRatio);
        } else if (mode == RetargetTranslationMode.absolute) {
          outPos = sPos;
        } else {
          outPos = tBone.bindTranslation;
        }

        outTargetLocalPose[tIdx].setFromTranslationRotationScale(
          outPos,
          compensatedRot,
          Vector3.all(sScale),
        );
      }
    });
  }
}
