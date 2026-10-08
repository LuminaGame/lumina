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

  GlbRetargetResult _withGlb(Uint8List glb) => GlbRetargetResult(
    glb: glb,
    clipName: clipName,
    clipIndex: clipIndex,
    duration: duration,
    mappedBones: mappedBones,
    restBones: restBones,
    ignoredSourceBones: ignoredSourceBones,
    pelvisTranslationScale: pelvisTranslationScale,
    sourceArmPose: sourceArmPose,
    targetArmPose: targetArmPose,
  );
}

/// Many clips retargeted into one skeletal mesh GLB: the target is parsed
/// once, each [add] appends a clip, and [finish] encodes the GLB once.
///
/// Rest channels are compact: a bone gets a constant rest channel in a clip
/// only when another animation of the asset moves it (so switching clips
/// still resets it), and those constant values are shared between clips.
/// For a set of clips that all animate the same bones this keeps the GLB
/// close to the size of the keyed motion alone.
class GlbRetargetBatch {
  GlbRetargetBatch(Uint8List target) : _target = _RetargetTarget.parse(target, compact: true);

  final _RetargetTarget _target;
  final _results = <GlbRetargetResult>[];
  bool _finished = false;

  /// Clips added so far.
  int get length => _results.length;

  /// Retargets animation [animationIndex] of [clip] as [clipName] (replacing
  /// an animation of that name). The result's `glb` is empty: the GLB comes
  /// from [finish]. Throws like [GlbAnimationRetargeter.retargetInto].
  GlbRetargetResult add({required Uint8List clip, required String clipName, int animationIndex = 0}) {
    if (_finished) throw StateError('GlbRetargetBatch.add after finish');
    final r = _RetargetOperation.retarget(_target, clip: clip, clipName: clipName, animationIndex: animationIndex);
    _results.add(r);
    return r;
  }

  /// The target GLB with every added clip, and the per-clip results (each
  /// carrying that GLB).
  ({Uint8List glb, List<GlbRetargetResult> clips}) finish() {
    if (_finished) throw StateError('GlbRetargetBatch.finish called twice');
    _finished = true;
    final glb = _target.encode();
    return (glb: glb, clips: [for (final r in _results) r._withGlb(glb)]);
  }
}
