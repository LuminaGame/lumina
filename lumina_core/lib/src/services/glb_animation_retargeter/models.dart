part of '../glb_animation_retargeter.dart';

/// How well a clip's animated bones match a skeleton, by name.
class GlbSkeletonMatch {
  /// Animated clip bones the skeleton has.
  final int matched;

  /// Bones the clip animates.
  final int animated;

  /// Animated clip bones the skeleton lacks.
  final List<String> missing;

  const GlbSkeletonMatch({required this.matched, required this.animated, required this.missing});

  /// Share of the clip's animated bones found in the skeleton, 0–1.
  double get score => animated == 0 ? 0 : matched / animated;
}

/// Detected humanoid arm rest pose layout.
enum SkeletonArmPose {
  /// Arms extended roughly horizontally (within ~20° of horizontal plane).
  tPose,

  /// Arms angled downward towards the ground (~35° to ~55° below horizontal).
  aPose,
}

/// A clip retargeted into a skeletal mesh GLB.
class GlbRetargetResult {
  /// The mesh GLB with the clip appended (or replaced, when one of the same
  /// name was there).
  final Uint8List glb;

  final String clipName;

  /// Index of the clip among the result's animations (the gltfio animator
  /// index).
  final int clipIndex;

  /// Clip length in seconds.
  final double duration;

  /// Skeleton bones that follow a clip bone through direct or semantic mapping.
  final List<String> mappedBones;

  /// Skeleton bones the clip has no bone for; they hold their rest rotation
  /// relative to their parent.
  final List<String> restBones;

  /// Clip bones the skeleton does not have (ignored).
  final List<String> ignoredSourceBones;

  /// Factor applied to the pelvis translation (target leg length over the
  /// clip's leg length).
  final double pelvisTranslationScale;

  /// Arm rest pose detected on the source animation clip.
  final SkeletonArmPose sourceArmPose;

  /// Arm rest pose detected on the target skeletal mesh.
  final SkeletonArmPose targetArmPose;

  const GlbRetargetResult({
    required this.glb,
    required this.clipName,
    required this.clipIndex,
    required this.duration,
    required this.mappedBones,
    required this.restBones,
    required this.ignoredSourceBones,
    required this.pelvisTranslationScale,
    this.sourceArmPose = SkeletonArmPose.tPose,
    this.targetArmPose = SkeletonArmPose.tPose,
  });
}
