import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart';

/// The eight 45° sectors a strafing character can walk in, relative to the
/// way it faces. Declared clockwise seen from above, starting straight ahead.
enum LuminaLocomotionDirection {
  forward,
  forwardRight,
  right,
  backwardRight,
  backward,
  backwardLeft,
  left,
  forwardLeft,
}

/// The clips a directional locomotion driver chooses between: one idle and one
/// walk cycle per [LuminaLocomotionDirection], plus an optional
/// jog cycle per direction for speeds nearer [jogReferenceSpeed].
class LuminaLocomotionClipSet {
  final String idle;
  final Map<LuminaLocomotionDirection, String> walk;

  /// The jog cycle per direction, empty when the set has none.
  final Map<LuminaLocomotionDirection, String> jog;

  /// Ground speed, in cm/s, at which the jog clips play at rate 1 without the
  /// feet sliding; 0 without jog clips.
  final double jogReferenceSpeed;

  /// Ground speed, in m/s, at which the walk clips play at rate 1 without the
  /// feet sliding.
  final double walkReferenceSpeed;

  /// Horizontal speed, in m/s, below which the character idles.
  final double idleSpeedThreshold;

  /// Play-rate bounds, so a crawl does not freeze the cycle and a sprint does
  /// not turn it into a blur.
  final double minWalkRate;
  final double maxWalkRate;

  const LuminaLocomotionClipSet({
    required this.idle,
    required this.walk,
    required this.walkReferenceSpeed,
    this.jog = const {},
    this.jogReferenceSpeed = 0.0,
    this.idleSpeedThreshold = 15.0, // cm/s
    this.minWalkRate = 0.5,
    this.maxWalkRate = 2.0,
  });

  /// Like the default constructor, but checks that every direction has a clip.
  factory LuminaLocomotionClipSet.validated({
    required String idle,
    required Map<LuminaLocomotionDirection, String> walk,
    required double walkReferenceSpeed,
    double idleSpeedThreshold = 15.0,
  }) {
    final missing = LuminaLocomotionDirection.values.where((d) => !walk.containsKey(d)).toList();
    if (missing.isNotEmpty) {
      throw ArgumentError('walk clips missing for: ${missing.map((d) => d.name).join(', ')}');
    }
    if (walkReferenceSpeed <= 0) {
      throw ArgumentError.value(walkReferenceSpeed, 'walkReferenceSpeed', 'must be positive');
    }
    return LuminaLocomotionClipSet(
      idle: idle,
      walk: walk,
      walkReferenceSpeed: walkReferenceSpeed,
      idleSpeedThreshold: idleSpeedThreshold,
    );
  }

  /// Every clip the set names: idle first, then the walks and the jogs in
  /// direction order.
  List<String> get allClips => [
        idle,
        for (final d in LuminaLocomotionDirection.values)
          if (walk[d] != null) walk[d]!,
        for (final d in LuminaLocomotionDirection.values)
          if (jog[d] != null) jog[d]!,
      ];

  /// Whether [clip] is one of this set's walk cycles.
  bool isWalkClip(String? clip) => clip != null && walk.containsValue(clip);

  /// Whether [clip] is one of this set's walk or jog cycles (their footfalls
  /// line up, so switching between them keeps the phase).
  bool isCycleClip(String? clip) => clip != null && (walk.containsValue(clip) || jog.containsValue(clip));

  /// Whether the set jogs: eight jog clips and a positive reference speed.
  bool get hasJog => jog.isNotEmpty && jogReferenceSpeed > walkReferenceSpeed;
}

/// What a locomotion driver should play this frame.
class LuminaLocomotionPose {
  /// The clip to play, or null when [holdCurrent] is set.
  final String? clip;
  final double playRate;

  /// Keep whatever is playing (at [playRate]) instead of switching.
  final bool holdCurrent;

  const LuminaLocomotionPose(this.clip, this.playRate) : holdCurrent = false;

  const LuminaLocomotionPose.hold({this.playRate = 0.0})
      : clip = null,
        holdCurrent = true;

  @override
  String toString() => holdCurrent ? 'hold@$playRate' : '$clip@$playRate';
}

/// Chooses idle or one of the eight walk cycles for a character moving with
/// [velocity] while facing [facing] (both world space, Y up).
///
/// Only the horizontal part of either vector counts. The walk direction is the
/// 45° sector the velocity falls in, measured clockwise from [facing] seen from
/// above (so right of `(0, 0, -1)` is `+X`), and the play rate is the ground
/// speed over [LuminaLocomotionClipSet.walkReferenceSpeed]. A set that jogs
/// plays the jog cycle instead once the speed passes midway
/// between the walk and jog reference speeds, at the speed over
/// [LuminaLocomotionClipSet.jogReferenceSpeed] — the same row the template's
/// `BS_Locomotion` blend space makes dominant. A falling character
/// holds its current clip at rate 0: a frozen mid-stride pose reads as a jump,
/// where a walk cycle pedalling in the air does not.
LuminaLocomotionPose selectLocomotionPose({
  required LuminaLocomotionClipSet clips,
  required Vector3 velocity,
  required Vector3 facing,
  required bool isFalling,
}) {
  if (isFalling) return const LuminaLocomotionPose.hold();

  final vx = velocity.x;
  final vz = velocity.z;
  final speed = math.sqrt(vx * vx + vz * vz);
  if (speed < clips.idleSpeedThreshold) {
    return LuminaLocomotionPose(clips.idle, 1.0);
  }

  var fx = facing.x;
  var fz = facing.z;
  final fLen = math.sqrt(fx * fx + fz * fz);
  if (fLen < 1e-9) {
    fx = 0.0;
    fz = -1.0;
  } else {
    fx /= fLen;
    fz /= fLen;
  }
  // Right of the facing, turned 90° clockwise seen from above.
  final rx = -fz;
  final rz = fx;

  final ahead = vx * fx + vz * fz;
  final aside = vx * rx + vz * rz;
  final degrees = math.atan2(aside, ahead) * 180.0 / math.pi;
  final sector = (degrees / 45.0).round() % LuminaLocomotionDirection.values.length;
  final direction = LuminaLocomotionDirection.values[sector];

  final jogs = clips.hasJog && speed > (clips.walkReferenceSpeed + clips.jogReferenceSpeed) / 2.0;
  final clip = (jogs ? clips.jog[direction] : clips.walk[direction]) ?? clips.idle;
  final reference = jogs ? clips.jogReferenceSpeed : clips.walkReferenceSpeed;
  final rate = (speed / reference).clamp(clips.minWalkRate, clips.maxWalkRate);
  return LuminaLocomotionPose(clip, rate.toDouble());
}
