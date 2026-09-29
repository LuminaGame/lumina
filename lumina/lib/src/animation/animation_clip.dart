import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart';

/// Abstract pose generator driving bone transforms for skeletal animation.
abstract class AnimPoseSource {
  double get phaseDuration;
  double get duration => phaseDuration;

  void advance(double deltaTime);

  void samplePhase(
    double normalizedPhase,
    List<Matrix4> outLocalPose, {
    double weight = 1.0,
  });

  void samplePose(
    double time,
    List<Matrix4> outLocalPose, {
    bool looping = true,
    double weight = 1.0,
  });
}

/// Single bone animation channel containing timed keyframes for translation, rotation, and scale.
class BoneTrack {
  final int boneIndex;
  final List<double> times;
  final List<Vector3> positions;
  final List<Quaternion> rotations;
  final List<Vector3> scales;

  BoneTrack({
    required this.boneIndex,
    required this.times,
    this.positions = const [],
    this.rotations = const [],
    this.scales = const [],
  });
}

/// An immutable animation sequence holding keyframe tracks for skeleton bones.
class LuminaAnimationClip implements AnimPoseSource {
  final String name;
  @override
  final double duration;
  final List<BoneTrack> tracks;

  LuminaAnimationClip({
    required this.name,
    required this.duration,
    required this.tracks,
  });

  @override
  double get phaseDuration => duration;

  @override
  void advance(double deltaTime) {}

  @override
  void samplePhase(
    double normalizedPhase,
    List<Matrix4> outLocalPose, {
    double weight = 1.0,
  }) {
    samplePose(normalizedPhase * duration, outLocalPose, looping: true, weight: weight);
  }

  /// Samples the keyframe curves at [time] and writes local transform matrices to [outLocalPose].
  ///
  /// If [weight] is less than 1.0, the sampled pose is blended with the existing matrices in [outLocalPose].
  @override
  void samplePose(
    double time,
    List<Matrix4> outLocalPose, {
    bool looping = true,
    double weight = 1.0,
  }) {
    if (duration <= 0.0 || tracks.isEmpty) return;

    double t = time;
    if (looping) {
      t = time % duration;
      if (t < 0.0) t += duration;
    } else {
      t = time.clamp(0.0, duration);
    }

    final scratchPos = Vector3.zero();
    final scratchRot = Quaternion.identity();
    final scratchScale = Vector3.all(1.0);

    for (final track in tracks) {
      if (track.boneIndex < 0 || track.boneIndex >= outLocalPose.length) continue;
      if (track.times.isEmpty) continue;

      // Extract existing TRS from target matrix in case of empty channels or weight blending
      final existingMat = outLocalPose[track.boneIndex];
      final existingPos = existingMat.getTranslation();
      final existingRot = Quaternion.fromRotation(existingMat.getRotation());
      final sx = Vector3(existingMat.entry(0, 0), existingMat.entry(1, 0), existingMat.entry(2, 0)).length;
      final sy = Vector3(existingMat.entry(0, 1), existingMat.entry(1, 1), existingMat.entry(2, 1)).length;
      final sz = Vector3(existingMat.entry(0, 2), existingMat.entry(1, 2), existingMat.entry(2, 2)).length;
      final existingScale = Vector3(
        sx > 1e-8 ? sx : 1.0,
        sy > 1e-8 ? sy : 1.0,
        sz > 1e-8 ? sz : 1.0,
      );

      // Sample keyframe pair
      _sampleTrack(
        track,
        t,
        existingPos,
        existingRot,
        existingScale,
        scratchPos,
        scratchRot,
        scratchScale,
      );

      // Blend with existing TRS if weight < 1.0
      if (weight < 1.0) {
        scratchPos.setValues(
          existingPos.x + (scratchPos.x - existingPos.x) * weight,
          existingPos.y + (scratchPos.y - existingPos.y) * weight,
          existingPos.z + (scratchPos.z - existingPos.z) * weight,
        );

        scratchScale.setValues(
          existingScale.x + (scratchScale.x - existingScale.x) * weight,
          existingScale.y + (scratchScale.y - existingScale.y) * weight,
          existingScale.z + (scratchScale.z - existingScale.z) * weight,
        );

        _slerpShortestPath(existingRot, scratchRot, weight, scratchRot);
      }

      existingMat.setFromTranslationRotationScale(scratchPos, scratchRot, scratchScale);
    }
  }

  void _sampleTrack(
    BoneTrack track,
    double t,
    Vector3 bindPos,
    Quaternion bindRot,
    Vector3 bindScale,
    Vector3 outPos,
    Quaternion outRot,
    Vector3 outScale,
  ) {
    final times = track.times;
    int index0 = 0;
    int index1 = 0;
    double alpha = 0.0;

    if (t <= times.first) {
      index0 = 0;
      index1 = 0;
      alpha = 0.0;
    } else if (t >= times.last) {
      index0 = times.length - 1;
      index1 = times.length - 1;
      alpha = 0.0;
    } else {
      int low = 0;
      int high = times.length - 1;
      while (low <= high) {
        final mid = (low + high) >> 1;
        if (times[mid] < t) {
          low = mid + 1;
        } else if (times[mid] > t) {
          high = mid - 1;
        } else {
          low = mid;
          break;
        }
      }
      index0 = high >= 0 ? high : 0;
      index1 = low < times.length ? low : times.length - 1;

      if (index0 != index1) {
        final t0 = times[index0];
        final t1 = times[index1];
        final span = t1 - t0;
        alpha = span > 1e-8 ? (t - t0) / span : 0.0;
      }
    }

    // Position
    if (track.positions.isEmpty) {
      outPos.setFrom(bindPos);
    } else if (index0 == index1 || index0 >= track.positions.length) {
      final safeIdx = math.min(index0, track.positions.length - 1);
      outPos.setFrom(track.positions[safeIdx]);
    } else {
      final p0 = track.positions[index0];
      final p1 = track.positions[math.min(index1, track.positions.length - 1)];
      outPos.setValues(
        p0.x + (p1.x - p0.x) * alpha,
        p0.y + (p1.y - p0.y) * alpha,
        p0.z + (p1.z - p0.z) * alpha,
      );
    }

    // Scale
    if (track.scales.isEmpty) {
      outScale.setFrom(bindScale);
    } else if (index0 == index1 || index0 >= track.scales.length) {
      final safeIdx = math.min(index0, track.scales.length - 1);
      outScale.setFrom(track.scales[safeIdx]);
    } else {
      final s0 = track.scales[index0];
      final s1 = track.scales[math.min(index1, track.scales.length - 1)];
      outScale.setValues(
        s0.x + (s1.x - s0.x) * alpha,
        s0.y + (s1.y - s0.y) * alpha,
        s0.z + (s1.z - s0.z) * alpha,
      );
    }

    // Rotation (shortest-path slerp)
    if (track.rotations.isEmpty) {
      outRot.setFrom(bindRot);
    } else if (index0 == index1 || index0 >= track.rotations.length) {
      final safeIdx = math.min(index0, track.rotations.length - 1);
      outRot.setFrom(track.rotations[safeIdx]);
    } else {
      final q0 = track.rotations[index0];
      final q1 = track.rotations[math.min(index1, track.rotations.length - 1)];
      _slerpShortestPath(q0, q1, alpha, outRot);
    }
  }

  static void _slerpShortestPath(Quaternion q0, Quaternion q1, double alpha, Quaternion out) {
    double dot = q0.x * q1.x + q0.y * q1.y + q0.z * q1.z + q0.w * q1.w;
    double sign = 1.0;
    if (dot < 0.0) {
      dot = -dot;
      sign = -1.0;
    }

    double k0, k1;
    if (dot > 0.9999) {
      k0 = 1.0 - alpha;
      k1 = alpha * sign;
      out.setValues(
        q0.x * k0 + q1.x * k1,
        q0.y * k0 + q1.y * k1,
        q0.z * k0 + q1.z * k1,
        q0.w * k0 + q1.w * k1,
      );
      out.normalize();
    } else {
      final sinOmega = math.sqrt(math.max(0.0, 1.0 - dot * dot));
      final omega = math.atan2(sinOmega, dot);
      final invSinOmega = sinOmega > 1e-8 ? 1.0 / sinOmega : 1.0;
      k0 = math.sin((1.0 - alpha) * omega) * invSinOmega;
      k1 = math.sin(alpha * omega) * invSinOmega * sign;
      out.setValues(
        q0.x * k0 + q1.x * k1,
        q0.y * k0 + q1.y * k1,
        q0.z * k0 + q1.z * k1,
        q0.w * k0 + q1.w * k1,
      );
    }
  }
}
