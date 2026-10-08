import 'dart:math' as math;
import 'dart:typed_data';

import 'package:lumina_core/lumina_core.dart';

import 'package:lumina/src/animation/root_motion/motion_warping.dart';
import 'package:lumina/src/animation/root_motion/root_motion_montage_player.dart';
import 'package:lumina/src/components/movement/traversal/traversal_check.dart';

/// One row of a traversal chooser: the clip an action plays for an
/// obstacle height, depth and speed range, how it plays and its warp
/// windows (targets `FrontLedge`, `BackLedge`, `BackFloor`).
class LuminaTraversalAnimation {
  final LuminaTraversalActionType action;
  final String clip;
  final double minHeight;
  final double maxHeight;
  final double minDepth;
  final double maxDepth;
  final double minSpeed;
  final double maxSpeed;

  /// Where the clip may end early when the player steers (null: plays to
  /// [endTime] / its end).
  final double? blendOutTime;
  final double? endTime;
  final double playRate;
  final double blendTime;

  /// The latest clip time a start may be matched to the pose shown.
  final double maxStartTime;
  final List<LuminaWarpWindow> windows;

  const LuminaTraversalAnimation({
    required this.action,
    required this.clip,
    this.minHeight = 0.0,
    this.maxHeight = double.infinity,
    this.minDepth = 0.0,
    this.maxDepth = double.infinity,
    this.minSpeed = 0.0,
    this.maxSpeed = double.infinity,
    this.blendOutTime,
    this.endTime,
    this.playRate = 1.0,
    this.blendTime = 0.25,
    this.maxStartTime = 0.0,
    this.windows = const [],
  });

  /// Whether this row fits [check].
  bool matches(LuminaTraversalCheckResult check) =>
      check.actionType == action &&
      check.obstacleHeight >= minHeight &&
      check.obstacleHeight <= maxHeight &&
      check.obstacleDepth >= minDepth &&
      check.obstacleDepth <= maxDepth &&
      check.speed >= minSpeed &&
      check.speed < maxSpeed;

  LuminaRootMotionMontage montage({double startTime = 0.0}) => LuminaRootMotionMontage(
        clip: clip,
        startTime: startTime,
        endTime: endTime,
        blendOutTime: blendOutTime,
        playRate: playRate,
        blendTime: blendTime,
        windows: windows,
      );

  static double? _n(Object? v) => v is num ? v.toDouble() : null;

  Map<String, dynamic> toJson() => {
        'action': action.name,
        'clip': clip,
        if (minHeight > 0) 'minHeight': minHeight,
        if (maxHeight.isFinite) 'maxHeight': maxHeight,
        if (minDepth > 0) 'minDepth': minDepth,
        if (maxDepth.isFinite) 'maxDepth': maxDepth,
        if (minSpeed > 0) 'minSpeed': minSpeed,
        if (maxSpeed.isFinite) 'maxSpeed': maxSpeed,
        'blendOutTime': ?blendOutTime,
        'endTime': ?endTime,
        if (playRate != 1.0) 'playRate': playRate,
        if (blendTime != 0.25) 'blendTime': blendTime,
        if (maxStartTime > 0) 'maxStartTime': maxStartTime,
        'windows': [for (final w in windows) w.toJson()],
      };

  factory LuminaTraversalAnimation.fromJson(Map<String, dynamic> j) => LuminaTraversalAnimation(
        action: LuminaTraversalActionType.parse(j['action'] as String?),
        clip: j['clip'] as String? ?? '',
        minHeight: _n(j['minHeight']) ?? 0.0,
        maxHeight: _n(j['maxHeight']) ?? double.infinity,
        minDepth: _n(j['minDepth']) ?? 0.0,
        maxDepth: _n(j['maxDepth']) ?? double.infinity,
        minSpeed: _n(j['minSpeed']) ?? 0.0,
        maxSpeed: _n(j['maxSpeed']) ?? double.infinity,
        blendOutTime: _n(j['blendOutTime']),
        endTime: _n(j['endTime']),
        playRate: _n(j['playRate']) ?? 1.0,
        blendTime: _n(j['blendTime']) ?? 0.25,
        maxStartTime: _n(j['maxStartTime']) ?? 0.0,
        windows: [
          for (final w in (j['windows'] as List?) ?? const []) LuminaWarpWindow.fromJson(Map<String, dynamic>.from(w as Map)),
        ],
      );
}

/// What [LuminaTraversalChooser.choose] picked: the row, the clip index in
/// the sampler and the start time.
typedef LuminaTraversalChoice = ({LuminaTraversalAnimation animation, int clip, double startTime, double cost});

/// Picks the traversal clip for a checked obstacle: the rows that fit it
/// (and whose clip the mesh has), then among them — left / right foot
/// variants — the clip and start time whose feet best match the pose shown
/// now (both with the root's motion removed).
abstract final class LuminaTraversalChooser {
  /// The rows of [rows] that fit [check], in order.
  static List<LuminaTraversalAnimation> candidates(List<LuminaTraversalAnimation> rows, LuminaTraversalCheckResult check) =>
      [for (final r in rows) if (r.matches(check)) r];

  /// The best of the fitting rows for [check] whose clips [rig]'s sampler
  /// has; null when none. With [currentPose] (local TRS per node, root
  /// motion removed) the feet ([bones]) decide between candidates and start
  /// times, sampled every [step] seconds up to each row's
  /// [LuminaTraversalAnimation.maxStartTime]; without it the first row
  /// plays from its start.
  static LuminaTraversalChoice? choose(
    List<LuminaTraversalAnimation> rows,
    LuminaTraversalCheckResult check,
    LuminaPoseSearchRig rig, {
    Float64List? currentPose,
    List<String> bones = const ['foot_l', 'foot_r'],
    double step = 1 / 30,
  }) {
    final sampler = rig.sampler;
    final fitting = [
      for (final r in candidates(rows, check))
        if (sampler.clipIndex(r.clip) != null) r,
    ];
    if (fitting.isEmpty) return null;
    final nodes = [for (final b in bones) sampler.indexOfNode(b)].where((n) => n >= 0).toList();
    if (currentPose == null || nodes.isEmpty || currentPose.length != sampler.nodeCount * LuminaPoseMath.trsStride) {
      final first = fitting.first;
      return (animation: first, clip: sampler.clipIndex(first.clip)!, startTime: 0.0, cost: 0.0);
    }
    final world = Float64List(sampler.nodeCount * LuminaPoseMath.affineStride);
    sampler.world(currentPose, world);
    final reference = [for (final n in nodes) for (var k = 0; k < 3; k++) world[n * LuminaPoseMath.affineStride + 9 + k]];
    final poser = LuminaPoseSearchPoser(rig);
    final local = Float64List(currentPose.length);
    LuminaTraversalChoice? best;
    for (final row in fitting) {
      final clip = sampler.clipIndex(row.clip)!;
      final limit = math.min(row.maxStartTime, sampler.clips[clip].duration);
      for (var t = 0.0; t <= limit + 1e-9; t += step) {
        poser.pose(clip, t, false, local);
        sampler.world(local, world);
        var cost = 0.0;
        for (var i = 0; i < nodes.length; i++) {
          for (var k = 0; k < 3; k++) {
            final d = world[nodes[i] * LuminaPoseMath.affineStride + 9 + k] - reference[i * 3 + k];
            cost += d * d;
          }
        }
        if (best == null || cost < best.cost - 1e-12) best = (animation: row, clip: clip, startTime: t, cost: cost);
      }
    }
    return best;
  }
}
