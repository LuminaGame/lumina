import 'dart:math' as math;
import 'dart:typed_data';

import 'package:lumina_core/lumina_core.dart';
import 'package:vector_math/vector_math_64.dart';

import 'package:lumina/src/animation/motion_matching/inertializer.dart';
import 'package:lumina/src/animation/motion_matching/motion_matching_component.dart';
import 'package:lumina/src/animation/root_motion/anim_slot_player.dart';
import 'package:lumina/src/animation/root_motion/motion_warping.dart';
import 'package:lumina/src/animation/root_motion/root_motion_track.dart';
import 'package:lumina/src/object/actor.dart';

/// A one-shot clip played with root motion: which part of [clip] plays, how
/// fast, where it may blend out early, and the warp windows that bend its
/// root path onto measured targets.
class LuminaRootMotionMontage {
  final String clip;
  final double startTime;

  /// Where the montage ends (null: the clip's end).
  final double? endTime;

  /// From here on the montage ends early when its player is told the
  /// character wants to move on (null: never early).
  final double? blendOutTime;
  final double playRate;

  /// Inertialization blend into the montage and back out of it (seconds).
  final double blendTime;
  final List<LuminaWarpWindow> windows;

  const LuminaRootMotionMontage({
    required this.clip,
    this.startTime = 0.0,
    this.endTime,
    this.blendOutTime,
    this.playRate = 1.0,
    this.blendTime = 0.25,
    this.windows = const [],
  });

  LuminaRootMotionMontage copyWith({double? startTime}) => LuminaRootMotionMontage(
        clip: clip,
        startTime: startTime ?? this.startTime,
        endTime: endTime,
        blendOutTime: blendOutTime,
        playRate: playRate,
        blendTime: blendTime,
        windows: windows,
      );
}

/// Plays a [LuminaRootMotionMontage] on a skinned mesh from the mesh's GLB
/// on the CPU. The shown pose has all of the root's motion removed (ground
/// position, facing and height relative to the start); that motion, bent by
/// a [LuminaMotionWarper] onto [targets], moves the [owner] instead: every
/// advance places the actor (its feet [feetOffset] below its location) on
/// the warped root and turns it to the warped yaw. The pose blends in from
/// the pose shown before by inertialization.
class LuminaRootMotionMontagePlayer implements LuminaAnimSlotPlayer {
  final LuminaPoseSearchRig rig;
  final int clip;
  final LuminaRootMotionMontage montage;
  final LuminaRootMotionTrack track;
  final LuminaMotionWarper warper;
  final LuminaPoseSearchPoser poser;
  final LuminaInertializer inertializer;

  /// The actor the root motion moves (null: only [rootLocation] / [rootYaw]
  /// change).
  final LuminaActor? owner;

  /// Distance from the actor's location down to its feet (a character's
  /// capsule half height): the root sits there.
  final double feetOffset;

  /// Whether the character wants to leave the montage at its blend-out
  /// time (for example, the player steers).
  bool Function()? wantsBlendOut;

  final void Function(LuminaRootMotionMontagePlayer player, bool interrupted)? onEnded;

  late final double endTime = math.min(montage.endTime ?? track.duration, track.duration);
  double _time;
  bool _finished = false;
  bool _ended = false;
  late Vector3 _root;
  double _yaw = 0.0;
  late final double _startHeight = track.frameAt(montage.startTime).y;

  late final Float64List _target = Float64List(rig.sampler.nodeCount * LuminaPoseMath.trsStride);
  late final Float64List _ahead = Float64List(rig.sampler.nodeCount * LuminaPoseMath.trsStride);
  late final Float64List _shown = Float64List(rig.sampler.nodeCount * LuminaPoseMath.trsStride);
  late final Float64List _previous = Float64List(rig.sampler.nodeCount * LuminaPoseMath.trsStride);
  late final Float64List _velocity = Float64List(rig.sampler.nodeCount * 6);
  late final Float64List _targetVelocity = Float64List(rig.sampler.nodeCount * 6);

  /// The inverse of the root's parent's rest linear part (to move the root
  /// down in its parent's frame), null when the root has no parent.
  late final Float64List? _parentInverse = _parentInverseOf(rig);

  LuminaRootMotionMontagePlayer({
    required this.rig,
    required this.clip,
    required this.montage,
    double worldUnitsPerModelUnit = 100.0,
    Map<String, LuminaWarpTarget> targets = const {},
    this.owner,
    this.feetOffset = 0.0,
    this.wantsBlendOut,
    this.onEnded,
    Vector3? rootLocation,
    double? rootYaw,
  })  : track = LuminaRootMotionTrack(rig, clip, worldUnitsPerModelUnit: worldUnitsPerModelUnit),
        poser = LuminaPoseSearchPoser(rig),
        inertializer = LuminaInertializer(rig.sampler.nodeCount, halflife: math.max(1e-3, montage.blendTime / 4)),
        warper = LuminaMotionWarper(<LuminaWarpWindow>[], targets),
        _time = montage.startTime {
    warper.windows.addAll(_resolveWindows());
    _root = rootLocation?.clone() ?? Vector3.zero();
    _yaw = rootYaw ?? 0.0;
  }

  List<LuminaWarpWindow> _resolveWindows() => [
        for (final w in montage.windows)
          if (w.warpPointOffset == null && w.warpPointBone != null && rig.sampler.indexOfNode(w.warpPointBone!) >= 0)
            w.withOffset(track.boneOffset(rig.sampler.indexOfNode(w.warpPointBone!), w.end))
          else
            w,
      ];

  static Float64List? _parentInverseOf(LuminaPoseSearchRig rig) {
    final parent = rig.sampler.parents[rig.root];
    if (parent < 0) return null;
    final world = rig.sampler.restWorld();
    final inverse = Float64List(LuminaPoseMath.affineStride);
    LuminaPoseMath.invertAffine(world, parent * LuminaPoseMath.affineStride, inverse, 0);
    return inverse;
  }

  /// Clip seconds now.
  double get time => _time;

  /// The warped root's world location (the feet) and yaw now.
  Vector3 get rootLocation => _root;
  double get rootYaw => _yaw;

  /// The windows as played (warp-point bones resolved to offsets).
  List<LuminaWarpWindow> get windows => warper.windows;

  /// The root's world velocity at the current time, unwarped (world units
  /// per second): what the character keeps moving with after the montage.
  Vector3 get rootVelocity {
    final v = track.velocityAt(_time) * montage.playRate;
    final (x, z) = LuminaPoseMath.rotateYaw(v.x, v.z, _yaw);
    return Vector3(x, v.y, z);
  }

  @override
  bool get finished => _finished;

  @override
  List<String> get poseNodeNames => rig.sampler.nodeNames;

  @override
  Float64List get pose => _shown;

  @override
  Float64List get poseVelocity => _velocity;

  @override
  Float64List? evaluatePose(double deltaTime) => _shown;

  /// The pose of the clip at [t] with the root's motion removed, into [out].
  void sample(double t, Float64List out) {
    poser.pose(clip, t, false, out);
    final dy = track.frameAt(t).y - _startHeight;
    final o = rig.root * LuminaPoseMath.trsStride;
    final inv = _parentInverse;
    if (inv == null) {
      out[o + 1] -= dy;
    } else {
      // (0, −dy, 0) into the parent's frame: its inverse linear part's second column.
      out[o] -= inv[3] * dy;
      out[o + 1] -= inv[4] * dy;
      out[o + 2] -= inv[5] * dy;
    }
  }

  @override
  void begin({Float64List? fromPose, Float64List? fromVelocity, List<String>? fromNodes}) {
    final actor = owner;
    if (actor != null) {
      _root = actor.actorLocation - Vector3(0.0, feetOffset, 0.0);
      _yaw = LuminaMotionMatchingCharacter.facingYaw(actor);
    }
    sample(_time, _target);
    final names = rig.sampler.nodeNames;
    final compatible = fromPose != null &&
        fromVelocity != null &&
        fromPose.length == _target.length &&
        fromVelocity.length == _velocity.length &&
        (fromNodes == null || _sameNames(fromNodes, names));
    if (compatible) {
      const h = 1 / 60;
      sample(math.min(_time + h, endTime), _ahead);
      LuminaInertializer.velocities(_target, _ahead, h, rig.sampler.nodeCount, _targetVelocity);
      inertializer.transition(fromPose, fromVelocity, _target, _targetVelocity);
      _shown.setAll(0, fromPose);
      _velocity.setAll(0, fromVelocity);
    } else {
      inertializer.reset();
      _shown.setAll(0, _target);
    }
  }

  static bool _sameNames(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  bool advance(double deltaTime) {
    if (_finished) return false;
    final dt = math.max(0.0, deltaTime);
    final next = math.min(endTime, _time + dt * montage.playRate);
    final (root, yaw) = warper.advance(_time, next, _root, _yaw, track.delta);
    _root = root;
    _yaw = yaw;
    _time = next;
    _place();
    sample(_time, _target);
    _previous.setAll(0, _shown);
    inertializer.update(dt, _target, _shown);
    LuminaInertializer.velocities(_previous, _shown, dt, rig.sampler.nodeCount, _velocity);
    final blendOut = montage.blendOutTime;
    if (_time >= endTime - 1e-9 || (blendOut != null && _time >= blendOut && (wantsBlendOut?.call() ?? false))) {
      _finished = true;
    }
    return !_finished;
  }

  void _place() {
    final actor = owner;
    if (actor == null) return;
    actor.actorLocation = _root + Vector3(0.0, feetOffset, 0.0);
    LuminaMotionMatchingCharacter.setFacingYaw(actor, _yaw);
  }

  @override
  void end({required bool interrupted}) {
    if (_ended) return;
    _ended = true;
    _finished = true;
    onEnded?.call(this, interrupted);
  }
}
