import 'dart:math' as math;
import 'dart:typed_data';

import 'package:lumina_core/lumina_core.dart';
import 'package:vector_math/vector_math_64.dart';

import 'package:lumina/src/animation/root_motion/motion_warping.dart';

/// A clip's root motion read from the mesh's GLB on the CPU: the root's
/// ground frame (position on the ground plane, height and facing yaw)
/// sampled at [sampleRate], in model space; deltas come out in the root's
/// own frame and in world units ([worldUnitsPerModelUnit]).
class LuminaRootMotionTrack {
  final LuminaPoseSearchRig rig;
  final int clip;
  final double worldUnitsPerModelUnit;
  final double sampleRate;

  late final double duration = rig.sampler.clips[clip].duration;
  late final int _count = math.max(2, (duration * sampleRate).ceil() + 1);
  late final Float64List _x = Float64List(_count), _y = Float64List(_count), _z = Float64List(_count), _yaw = Float64List(_count);

  LuminaRootMotionTrack(this.rig, this.clip, {this.worldUnitsPerModelUnit = 100.0, this.sampleRate = 60.0}) {
    final affine = Float64List(LuminaPoseMath.affineStride);
    double? previousYaw;
    for (var i = 0; i < _count; i++) {
      final t = math.min(duration, i / sampleRate);
      rig.sampler.nodeWorld(clip, rig.rootChain, t, affine, 0);
      final g = rig.groundOf(affine, 0);
      var yaw = g.yaw;
      if (previousYaw != null) yaw = previousYaw + LuminaPoseMath.wrapAngle(yaw - previousYaw);
      previousYaw = yaw;
      _x[i] = g.x;
      _y[i] = affine[10];
      _z[i] = g.z;
      _yaw[i] = yaw;
    }
  }

  LuminaGlbAnimationSampler get sampler => rig.sampler;

  /// The root frame at clip time [t] (model units, radians), clamped to the
  /// clip.
  ({double x, double y, double z, double yaw}) frameAt(double t) {
    final f = (t.clamp(0.0, duration) * sampleRate).toDouble();
    final i = math.min(f.floor(), _count - 2);
    final a = (f - i).clamp(0.0, 1.0);
    double lerp(Float64List v) => v[i] + (v[i + 1] - v[i]) * a;
    return (x: lerp(_x), y: lerp(_y), z: lerp(_z), yaw: lerp(_yaw));
  }

  /// The root's motion from clip time [a] to [b] in its frame at [a], world
  /// units.
  LuminaRootDelta delta(double a, double b) {
    final fa = frameAt(a), fb = frameAt(b);
    final (x, z) = LuminaPoseMath.rotateYaw(fb.x - fa.x, fb.z - fa.z, -fa.yaw);
    final s = worldUnitsPerModelUnit;
    return (x: x * s, y: (fb.y - fa.y) * s, z: z * s, yaw: fb.yaw - fa.yaw);
  }

  /// The root's velocity at [t] in its own frame (world units per second).
  Vector3 velocityAt(double t) {
    const h = 1 / 30;
    final a = math.max(0.0, math.min(t, duration) - h);
    final b = math.min(duration, a + h);
    if (b - a < 1e-6) return Vector3.zero();
    final d = delta(a, b);
    return Vector3(d.x, d.y, d.z) / (b - a);
  }

  final Float64List _boneAffine = Float64List(LuminaPoseMath.affineStride);

  /// [node]'s position relative to the root at clip time [t], in the root's
  /// frame (world units); null for a missing node.
  Vector3? boneOffset(int node, double t) {
    if (node < 0 || node >= sampler.nodeCount) return null;
    sampler.nodeWorld(clip, sampler.chainOf(node), t.clamp(0.0, duration).toDouble(), _boneAffine, 0);
    final f = frameAt(t);
    final (x, z) = LuminaPoseMath.rotateYaw(_boneAffine[9] - f.x, _boneAffine[11] - f.z, -f.yaw);
    final s = worldUnitsPerModelUnit;
    return Vector3(x * s, (_boneAffine[10] - f.y) * s, z * s);
  }
}
