import 'package:lumina_core/lumina_core.dart';
import 'package:vector_math/vector_math_64.dart';

/// Where a warp window should bring the root: a world location (runtime
/// axes, world units) and, for windows that warp rotation, a world yaw (0
/// faces +Z, positive turns toward +X, as `luminaWorldYaw`).
class LuminaWarpTarget {
  final Vector3 location;
  final double yaw;

  LuminaWarpTarget(Vector3 location, this.yaw) : location = location.clone();

  @override
  String toString() => 'LuminaWarpTarget(${location.x.toStringAsFixed(1)}, ${location.y.toStringAsFixed(1)}, '
      '${location.z.toStringAsFixed(1)}, yaw ${yaw.toStringAsFixed(3)})';
}

/// A stretch of a root-motion clip whose root path is bent so that, at
/// [end], the root (or the warp point [warpPointOffset] away from it)
/// reaches the target named [target].
class LuminaWarpWindow {
  final String target;

  /// Clip seconds.
  final double start;
  final double end;
  final bool warpTranslation;
  final bool warpRotation;

  /// Keep the clip's vertical motion (warp only the horizontal path).
  final bool ignoreVertical;

  /// The warp point's offset from the root at [end], in the root's frame
  /// (x lateral as `LuminaPoseMath.rotateYaw` turns it, y up, z forward),
  /// world units; null warps the root itself.
  final Vector3? warpPointOffset;

  /// A bone of the clip whose offset from the root at [end] is the warp
  /// point, when [warpPointOffset] is not given and the mesh has the bone.
  final String? warpPointBone;

  const LuminaWarpWindow({
    required this.target,
    required this.start,
    required this.end,
    this.warpTranslation = true,
    this.warpRotation = false,
    this.ignoreVertical = false,
    this.warpPointOffset,
    this.warpPointBone,
  });

  LuminaWarpWindow withOffset(Vector3? offset) => LuminaWarpWindow(
        target: target,
        start: start,
        end: end,
        warpTranslation: warpTranslation,
        warpRotation: warpRotation,
        ignoreVertical: ignoreVertical,
        warpPointOffset: offset,
        warpPointBone: warpPointBone,
      );

  Map<String, dynamic> toJson() => {
        'target': target,
        'start': start,
        'end': end,
        if (!warpTranslation) 'translation': false,
        if (warpRotation) 'rotation': true,
        if (ignoreVertical) 'ignoreVertical': true,
        if (warpPointOffset != null) 'offset': [warpPointOffset!.x, warpPointOffset!.y, warpPointOffset!.z],
        if (warpPointBone != null) 'bone': warpPointBone,
      };

  factory LuminaWarpWindow.fromJson(Map<String, dynamic> j) {
    final o = (j['offset'] as List?)?.cast<num>();
    return LuminaWarpWindow(
      target: j['target'] as String? ?? '',
      start: (j['start'] as num?)?.toDouble() ?? 0.0,
      end: (j['end'] as num?)?.toDouble() ?? 0.0,
      warpTranslation: j['translation'] as bool? ?? true,
      warpRotation: j['rotation'] as bool? ?? false,
      ignoreVertical: j['ignoreVertical'] as bool? ?? false,
      warpPointOffset: o == null || o.length < 3 ? null : Vector3(o[0].toDouble(), o[1].toDouble(), o[2].toDouble()),
      warpPointBone: j['bone'] as String?,
    );
  }
}

/// The clip's root motion between two clip times, in the root's frame at
/// the first (x lateral, y up, z forward; world units) and its yaw change.
typedef LuminaRootDelta = ({double x, double y, double z, double yaw});

/// Bends a root-motion clip's path through warp windows (scale warping):
/// inside a window the root's remaining clip displacement to the window's
/// end is scaled, axis by axis in the target's frame, to the remaining
/// distance to the target, so the root keeps the clip's shape and arrives
/// exactly at the window's end; the yaw turns to the target's the same way.
/// Outside windows the root follows the clip. Steps are split at window
/// boundaries.
class LuminaMotionWarper {
  final List<LuminaWarpWindow> windows;

  /// Targets by name; a window whose target is missing plays unwarped.
  final Map<String, LuminaWarpTarget> targets;

  /// Below this remaining clip displacement on an axis (world units) the
  /// axis reaches its target linearly in time instead of by scaling.
  double axisEpsilon = 1.0;

  /// Below this remaining clip yaw (radians) the yaw turns linearly in time.
  double yawEpsilon = 0.02;

  LuminaMotionWarper(this.windows, this.targets);

  /// The root's world position and yaw after [rootMotion]-driven steps from
  /// clip time [from] to [to], starting at [position] / [yaw]. [rootMotion]
  /// gives the clip's root delta between two clip times.
  (Vector3, double) advance(
    double from,
    double to,
    Vector3 position,
    double yaw,
    LuminaRootDelta Function(double a, double b) rootMotion,
  ) {
    var p = position.clone();
    var y = yaw;
    var t = from;
    while (to - t > 1e-9) {
      var next = to;
      for (final w in windows) {
        if (w.start > t + 1e-9 && w.start < next) next = w.start;
        if (w.end > t + 1e-9 && w.end < next) next = w.end;
      }
      (p, y) = _step(t, next, p, y, rootMotion);
      t = next;
    }
    return (p, y);
  }

  LuminaWarpWindow? _active(double t, bool Function(LuminaWarpWindow w) wants) {
    for (final w in windows) {
      if (t >= w.start - 1e-9 && t < w.end - 1e-9 && wants(w) && targets.containsKey(w.target)) return w;
    }
    return null;
  }

  /// The world location the root must reach at [w]'s end for its warp
  /// point to land on the target, the root then facing [yaw].
  Vector3 rootTargetOf(LuminaWarpWindow w, double yaw) {
    final target = targets[w.target]!;
    final offset = w.warpPointOffset;
    if (offset == null) return target.location.clone();
    final (ox, oz) = LuminaPoseMath.rotateYaw(offset.x, offset.z, yaw);
    return Vector3(target.location.x - ox, target.location.y - offset.y, target.location.z - oz);
  }

  (Vector3, double) _step(double t, double t1, Vector3 p, double yaw, LuminaRootDelta Function(double a, double b) rm) {
    final d = rm(t, t1);
    final translation = _active(t, (w) => w.warpTranslation);
    final rotation = _active(t, (w) => w.warpRotation);

    // Yaw.
    var dyaw = d.yaw;
    if (rotation != null) {
      final remainingClip = rm(t, rotation.end).yaw;
      final remaining = LuminaPoseMath.wrapAngle(targets[rotation.target]!.yaw - yaw);
      final span = rotation.end - t;
      dyaw = remainingClip.abs() > yawEpsilon
          ? d.yaw * remaining / remainingClip
          : (span > 1e-9 ? remaining * (t1 - t) / span : remaining);
    }

    // Translation: the clip's step in world.
    final (wx, wz) = LuminaPoseMath.rotateYaw(d.x, d.z, yaw);
    final step = Vector3(wx, d.y, wz);
    if (translation != null) {
      final target = targets[translation.target]!;
      final frameYaw = translation.warpRotation ? target.yaw : yaw;
      final goal = rootTargetOf(translation, frameYaw);
      final rc = rm(t, translation.end);
      final (rcx, rcz) = LuminaPoseMath.rotateYaw(rc.x, rc.z, yaw);
      // Into the target's frame.
      final (cx, cz) = LuminaPoseMath.rotateYaw(rcx, rcz, -frameYaw);
      final (ax, az) = LuminaPoseMath.rotateYaw(goal.x - p.x, goal.z - p.z, -frameYaw);
      final (sx, sz) = LuminaPoseMath.rotateYaw(step.x, step.z, -frameYaw);
      final span = translation.end - t;
      final f = span > 1e-9 ? (t1 - t) / span : 1.0;
      double axis(double s, double c, double a) => c.abs() > axisEpsilon ? s * a / c : a * f;
      final ox = axis(sx, cx, ax);
      final oz = axis(sz, cz, az);
      final oy = translation.ignoreVertical ? step.y : axis(step.y, rc.y, goal.y - p.y);
      final (bx, bz) = LuminaPoseMath.rotateYaw(ox, oz, frameYaw);
      step.setValues(bx, oy, bz);
    }
    return (p + step, yaw + dyaw);
  }
}
