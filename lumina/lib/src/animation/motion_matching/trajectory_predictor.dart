import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart';

import 'package:lumina/src/animation/motion_matching/spring_math.dart';

/// One trajectory sample in world space: a ground position (y kept from the
/// character) and a facing yaw (radians; world yaw of the facing direction,
/// 0 along +Z, positive toward +X).
typedef LuminaTrajectoryPoint = ({Vector3 position, double yaw});

/// The world yaw of horizontal direction [d] (0 along +Z, positive toward +X).
double luminaWorldYaw(Vector3 d) => math.atan2(d.x, d.z);

/// The horizontal unit direction of world [yaw].
Vector3 luminaYawDirection(double yaw) => Vector3(math.sin(yaw), 0.0, math.cos(yaw));

/// Records where a character has been and predicts where it will be: future
/// positions from a critically damped spring of its velocity toward the
/// desired velocity ([velocityHalflife]), future facings from a spring of
/// its yaw toward the desired yaw ([facingHalflife]); past samples come from
/// the recorded history (extrapolated backwards from the current velocity
/// until enough history exists).
class LuminaTrajectoryPredictor {
  double velocityHalflife;
  double facingHalflife;

  LuminaTrajectoryPredictor({this.velocityHalflife = 0.2, this.facingHalflife = 0.25});

  final List<(double time, Vector3 position, double yaw)> _history = [];
  double _clock = 0.0;
  Vector3? _lastVelocity;
  final Vector3 _acceleration = Vector3.zero();
  double? _lastYaw;
  double _yawVelocity = 0.0;
  bool _facingDriven = false;

  /// The acceleration estimated from the recorded velocities (cm/s²).
  Vector3 get acceleration => _acceleration;

  /// The facing's yaw velocity (rad/s): the facing spring's own velocity
  /// while [turnFacing] turns the character, else estimated from the
  /// recorded facings.
  double get yawVelocity => _yawVelocity;

  /// Turns a character facing [yaw] toward [goal] for [dt] seconds with the
  /// facing spring ([facingHalflife]) and returns the new yaw. The spring
  /// keeps its velocity for the next frame and the prediction: a velocity
  /// estimated back from the recorded facings would divide the last turn by
  /// this frame's time instead of the time it was made in, and with frame
  /// times that vary the spring would overshoot and swing back and forth.
  double turnFacing(double yaw, double goal, double dt) {
    final (next, velocity) = LuminaSpringMath.springAngle(yaw, _yawVelocity, goal, facingHalflife, dt);
    _yawVelocity = velocity;
    _facingDriven = true;
    return next;
  }

  /// Seconds of history kept.
  double historySeconds = 1.5;

  /// Records the character's state after a frame of [dt] seconds.
  void record(Vector3 position, double yaw, Vector3 velocity, double dt) {
    _clock += dt;
    _history.add((_clock, position.clone(), yaw));
    while (_history.length > 2 && _clock - _history[1].$1 > historySeconds) {
      _history.removeAt(0);
    }
    final last = _lastVelocity;
    if (last != null && dt > 1e-6) {
      final a = (velocity - last) / dt;
      a.y = 0.0;
      // Light smoothing: a frame's finite difference is noisy.
      _acceleration.setFrom(_acceleration * 0.5 + a * 0.5);
    }
    _lastVelocity = velocity.clone();
    final lastYaw = _lastYaw;
    if (_facingDriven) {
      // The facing spring knows its velocity (see [turnFacing]).
      _facingDriven = false;
    } else if (lastYaw != null && dt > 1e-6) {
      _yawVelocity = LuminaSpringMath.wrap(yaw - lastYaw) / dt;
    }
    _lastYaw = yaw;
  }

  /// Forgets the history (a teleport or a new character).
  void reset() {
    _history.clear();
    _lastVelocity = null;
    _lastYaw = null;
    _acceleration.setZero();
    _yawVelocity = 0.0;
    _facingDriven = false;
  }

  /// The trajectory at [times] (seconds; negative = past) from the
  /// character at [position] facing [yaw] moving at [velocity] toward
  /// [desiredVelocity] and [desiredYaw].
  List<LuminaTrajectoryPoint> predict({
    required Vector3 position,
    required double yaw,
    required Vector3 velocity,
    required Vector3 desiredVelocity,
    required double desiredYaw,
    required List<double> times,
  }) {
    final out = <LuminaTrajectoryPoint>[];
    for (final t in times) {
      if (t <= 0) {
        out.add(_past(position, yaw, velocity, t));
        continue;
      }
      final (x, _, _) = LuminaSpringMath.springCharacter(
          position.x, velocity.x, _acceleration.x, desiredVelocity.x, velocityHalflife, t);
      final (z, _, _) = LuminaSpringMath.springCharacter(
          position.z, velocity.z, _acceleration.z, desiredVelocity.z, velocityHalflife, t);
      final (a, _) = LuminaSpringMath.springAngle(yaw, _yawVelocity, desiredYaw, facingHalflife, t);
      out.add((position: Vector3(x, position.y, z), yaw: a));
    }
    return out;
  }

  LuminaTrajectoryPoint _past(Vector3 position, double yaw, Vector3 velocity, double t) {
    final target = _clock + t;
    if (_history.length >= 2 && _history.first.$1 <= target) {
      for (var i = _history.length - 1; i > 0; i--) {
        final a = _history[i - 1], b = _history[i];
        if (a.$1 <= target && target <= b.$1) {
          final span = b.$1 - a.$1;
          final k = span > 1e-9 ? (target - a.$1) / span : 0.0;
          final p = a.$2 + (b.$2 - a.$2) * k;
          final y = a.$3 + LuminaSpringMath.wrap(b.$3 - a.$3) * k;
          return (position: p, yaw: y);
        }
      }
    }
    final v = Vector3(velocity.x, 0.0, velocity.z);
    return (position: position + v * t, yaw: yaw);
  }
}
