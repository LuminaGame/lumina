import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart';
import 'animation_clip.dart';

/// Interpolation mode for animation keyframes.
enum KeyframeInterpolation {
  linear,
  step,
  cubic,
}

/// A timed keyframe holding a value and tangents.
class Keyframe<T> {
  final double timeSeconds;
  final T value;
  final KeyframeInterpolation interpolation;
  final double inTangent;
  final double outTangent;

  const Keyframe({
    required this.timeSeconds,
    required this.value,
    this.interpolation = KeyframeInterpolation.linear,
    this.inTangent = 0.0,
    this.outTangent = 0.0,
  });

  Keyframe<T> copyWith({
    double? timeSeconds,
    T? value,
    KeyframeInterpolation? interpolation,
    double? inTangent,
    double? outTangent,
  }) {
    return Keyframe<T>(
      timeSeconds: timeSeconds ?? this.timeSeconds,
      value: value ?? this.value,
      interpolation: interpolation ?? this.interpolation,
      inTangent: inTangent ?? this.inTangent,
      outTangent: outTangent ?? this.outTangent,
    );
  }
}

/// A mutable float animation curve track.
class FloatCurveTrack {
  final String curveName;
  final KeyframeInterpolation interpolation;
  final List<Keyframe<double>> _keys = [];

  FloatCurveTrack({
    required this.curveName,
    this.interpolation = KeyframeInterpolation.linear,
    List<Keyframe<double>>? initialKeys,
  }) {
    if (initialKeys != null) {
      _keys.addAll(initialKeys);
      _keys.sort((a, b) => a.timeSeconds.compareTo(b.timeSeconds));
    }
  }

  List<Keyframe<double>> get keys => List.unmodifiable(_keys);

  void setKey(
    double timeSeconds,
    double value, {
    KeyframeInterpolation? interp,
    double inTangent = 0.0,
    double outTangent = 0.0,
  }) {
    final existingIdx = _keys.indexWhere((k) => (k.timeSeconds - timeSeconds).abs() < 1e-4);
    final key = Keyframe<double>(
      timeSeconds: timeSeconds,
      value: value,
      interpolation: interp ?? interpolation,
      inTangent: inTangent,
      outTangent: outTangent,
    );

    if (existingIdx != -1) {
      _keys[existingIdx] = key;
    } else {
      _keys.add(key);
      _keys.sort((a, b) => a.timeSeconds.compareTo(b.timeSeconds));
    }
  }

  void removeKeyAt(double timeSeconds, {double tolerance = 1e-4}) {
    _keys.removeWhere((k) => (k.timeSeconds - timeSeconds).abs() < tolerance);
  }

  double evaluate(double t) {
    if (_keys.isEmpty) return 0.0;
    if (_keys.length == 1 || t <= _keys.first.timeSeconds) return _keys.first.value;
    if (t >= _keys.last.timeSeconds) return _keys.last.value;

    int idx = 0;
    while (idx < _keys.length - 1 && _keys[idx + 1].timeSeconds < t) {
      idx++;
    }

    final k0 = _keys[idx];
    final k1 = _keys[idx + 1];
    final dt = k1.timeSeconds - k0.timeSeconds;
    if (dt <= 1e-6) return k0.value;

    final alpha = ((t - k0.timeSeconds) / dt).clamp(0.0, 1.0);

    final effectiveInterp = k0.interpolation;
    if (effectiveInterp == KeyframeInterpolation.step) {
      return alpha >= 1.0 ? k1.value : k0.value;
    } else if (effectiveInterp == KeyframeInterpolation.cubic) {
      // Cubic Hermite spline interpolation
      final a2 = alpha * alpha;
      final a3 = a2 * alpha;
      final h00 = 2 * a3 - 3 * a2 + 1;
      final h10 = a3 - 2 * a2 + alpha;
      final h01 = -2 * a3 + 3 * a2;
      final h11 = a3 - a2;
      return (h00 * k0.value) + (h10 * dt * k0.outTangent) + (h01 * k1.value) + (h11 * dt * k1.inTangent);
    } else {
      // Linear
      return k0.value + (k1.value - k0.value) * alpha;
    }
  }
}

/// A mutable single-bone animation channel containing translation, rotation, and scale keyframe tracks.
class BoneTransformTrack {
  final int boneIndex;
  final String boneName;
  final List<Keyframe<Vector3>> translationKeys = [];
  final List<Keyframe<Quaternion>> rotationKeys = [];
  final List<Keyframe<Vector3>> scaleKeys = [];

  BoneTransformTrack({
    required this.boneIndex,
    required this.boneName,
  });

  void setTranslationKey(double timeSeconds, Vector3 val) {
    final idx = translationKeys.indexWhere((k) => (k.timeSeconds - timeSeconds).abs() < 1e-4);
    final key = Keyframe<Vector3>(timeSeconds: timeSeconds, value: Vector3.copy(val));
    if (idx != -1) {
      translationKeys[idx] = key;
    } else {
      translationKeys.add(key);
      translationKeys.sort((a, b) => a.timeSeconds.compareTo(b.timeSeconds));
    }
  }

  void setRotationKey(double timeSeconds, Quaternion val) {
    final idx = rotationKeys.indexWhere((k) => (k.timeSeconds - timeSeconds).abs() < 1e-4);
    final key = Keyframe<Quaternion>(timeSeconds: timeSeconds, value: Quaternion.copy(val)..normalize());
    if (idx != -1) {
      rotationKeys[idx] = key;
    } else {
      rotationKeys.add(key);
      rotationKeys.sort((a, b) => a.timeSeconds.compareTo(b.timeSeconds));
    }
  }

  void setScaleKey(double timeSeconds, Vector3 val) {
    final idx = scaleKeys.indexWhere((k) => (k.timeSeconds - timeSeconds).abs() < 1e-4);
    final key = Keyframe<Vector3>(timeSeconds: timeSeconds, value: Vector3.copy(val));
    if (idx != -1) {
      scaleKeys[idx] = key;
    } else {
      scaleKeys.add(key);
      scaleKeys.sort((a, b) => a.timeSeconds.compareTo(b.timeSeconds));
    }
  }

  Vector3 evaluateTranslation(double t) {
    if (translationKeys.isEmpty) return Vector3.zero();
    if (translationKeys.length == 1 || t <= translationKeys.first.timeSeconds) return translationKeys.first.value;
    if (t >= translationKeys.last.timeSeconds) return translationKeys.last.value;

    int idx = 0;
    while (idx < translationKeys.length - 1 && translationKeys[idx + 1].timeSeconds < t) {
      idx++;
    }

    final k0 = translationKeys[idx];
    final k1 = translationKeys[idx + 1];
    final dt = k1.timeSeconds - k0.timeSeconds;
    if (dt <= 1e-6) return k0.value;
    final alpha = (t - k0.timeSeconds) / dt;
    return k0.value + ((k1.value - k0.value) * alpha);
  }

  Quaternion evaluateRotation(double t) {
    if (rotationKeys.isEmpty) return Quaternion.identity();
    if (rotationKeys.length == 1 || t <= rotationKeys.first.timeSeconds) return rotationKeys.first.value;
    if (t >= rotationKeys.last.timeSeconds) return rotationKeys.last.value;

    int idx = 0;
    while (idx < rotationKeys.length - 1 && rotationKeys[idx + 1].timeSeconds < t) {
      idx++;
    }

    final k0 = rotationKeys[idx];
    final k1 = rotationKeys[idx + 1];
    final dt = k1.timeSeconds - k0.timeSeconds;
    if (dt <= 1e-6) return k0.value;
    final alpha = (t - k0.timeSeconds) / dt;

    final q = Quaternion.identity();
    _slerpShortestPath(k0.value, k1.value, alpha, q);
    return q..normalize();
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

  Vector3 evaluateScale(double t) {
    if (scaleKeys.isEmpty) return Vector3.all(1.0);
    if (scaleKeys.length == 1 || t <= scaleKeys.first.timeSeconds) return scaleKeys.first.value;
    if (t >= scaleKeys.last.timeSeconds) return scaleKeys.last.value;

    int idx = 0;
    while (idx < scaleKeys.length - 1 && scaleKeys[idx + 1].timeSeconds < t) {
      idx++;
    }

    final k0 = scaleKeys[idx];
    final k1 = scaleKeys[idx + 1];
    final dt = k1.timeSeconds - k0.timeSeconds;
    if (dt <= 1e-6) return k0.value;
    final alpha = (t - k0.timeSeconds) / dt;
    return k0.value + ((k1.value - k0.value) * alpha);
  }

  Matrix4 evaluateLocalTransform(double t) {
    final pos = evaluateTranslation(t);
    final rot = evaluateRotation(t);
    final scl = evaluateScale(t);
    final mat = Matrix4.identity();
    mat.setFromTranslationRotationScale(pos, rot, scl);
    return mat;
  }
}

/// A mutable animation sequence containing editable bone transform and float curve tracks.
class LuminaMutableAnimSequence {
  final String name;
  double duration;
  double frameRate;
  final Map<int, BoneTransformTrack> _boneTracks = {};
  final Map<String, FloatCurveTrack> _curveTracks = {};

  LuminaMutableAnimSequence({
    required this.name,
    required this.duration,
    this.frameRate = 30.0,
  });

  List<BoneTransformTrack> get boneTracks => _boneTracks.values.toList();
  List<FloatCurveTrack> get curveTracks => _curveTracks.values.toList();

  BoneTransformTrack getOrCreateBoneTrack(int boneIndex, String boneName) {
    return _boneTracks.putIfAbsent(
      boneIndex,
      () => BoneTransformTrack(boneIndex: boneIndex, boneName: boneName),
    );
  }

  FloatCurveTrack getOrCreateCurveTrack(String curveName) {
    return _curveTracks.putIfAbsent(
      curveName,
      () => FloatCurveTrack(curveName: curveName),
    );
  }

  void setKeyframe({
    required int boneIndex,
    required String boneName,
    required double time,
    Vector3? translation,
    Quaternion? rotation,
    Vector3? scale,
  }) {
    final track = getOrCreateBoneTrack(boneIndex, boneName);
    if (translation != null) track.setTranslationKey(time, translation);
    if (rotation != null) track.setRotationKey(time, rotation);
    if (scale != null) track.setScaleKey(time, scale);
  }

  void removeKeyframe({
    required int boneIndex,
    required double time,
    double tolerance = 1e-4,
  }) {
    final track = _boneTracks[boneIndex];
    if (track != null) {
      track.translationKeys.removeWhere((k) => (k.timeSeconds - time).abs() < tolerance);
      track.rotationKeys.removeWhere((k) => (k.timeSeconds - time).abs() < tolerance);
      track.scaleKeys.removeWhere((k) => (k.timeSeconds - time).abs() < tolerance);
    }
  }

  void evaluatePose(double time, List<Matrix4> outBoneMatrices, Map<String, double> outCurveValues) {
    _boneTracks.forEach((bIdx, track) {
      if (bIdx >= 0 && bIdx < outBoneMatrices.length) {
        outBoneMatrices[bIdx] = track.evaluateLocalTransform(time);
      }
    });

    _curveTracks.forEach((name, curve) {
      outCurveValues[name] = curve.evaluate(time);
    });
  }

  /// Bakes mutable tracks into an immutable [LuminaAnimationClip] buffer.
  LuminaAnimationClip toImmutableClip() {
    final List<BoneTrack> immutableTracks = [];

    for (final bTrack in _boneTracks.values) {
      // Gather all unique timestamps across T, R, S
      final Set<double> timesSet = {};
      for (final k in bTrack.translationKeys) {
        timesSet.add(k.timeSeconds);
      }
      for (final k in bTrack.rotationKeys) {
        timesSet.add(k.timeSeconds);
      }
      for (final k in bTrack.scaleKeys) {
        timesSet.add(k.timeSeconds);
      }

      final times = timesSet.toList()..sort();
      if (times.isEmpty) continue;

      final List<Vector3> pos = [];
      final List<Quaternion> rot = [];
      final List<Vector3> scl = [];

      for (final t in times) {
        pos.add(bTrack.evaluateTranslation(t));
        rot.add(bTrack.evaluateRotation(t));
        scl.add(bTrack.evaluateScale(t));
      }

      immutableTracks.add(BoneTrack(
        boneIndex: bTrack.boneIndex,
        times: times,
        positions: pos,
        rotations: rot,
        scales: scl,
      ));
    }

    return LuminaAnimationClip(
      name: name,
      duration: duration,
      tracks: immutableTracks,
    );
  }
}
