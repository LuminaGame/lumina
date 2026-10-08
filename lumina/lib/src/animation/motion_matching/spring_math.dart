import 'dart:math' as math;

/// Exact critically damped springs (closed forms, no integration error): the
/// decay of inertialization offsets and the trajectory prediction of a
/// character moving toward a desired velocity.
abstract final class LuminaSpringMath {
  static const double _ln2 = 0.69314718056;

  /// The damping of a critically damped spring that halves its distance to
  /// the goal in [halflife] seconds.
  static double halflifeToDamping(double halflife) => (4.0 * _ln2) / (halflife + 1e-5);

  /// A spring at [x] with velocity [v] decaying toward 0 for [dt] seconds.
  static (double x, double v) decaySpringDamper(double x, double v, double halflife, double dt) {
    final y = halflifeToDamping(halflife) / 2.0;
    final j1 = v + x * y;
    final eydt = math.exp(-y * dt);
    return (eydt * (x + j1 * dt), eydt * (v - j1 * y * dt));
  }

  /// A character at [x] with velocity [v] and acceleration [a] whose
  /// velocity springs toward [goalVelocity] with [halflife]: position,
  /// velocity and acceleration [t] seconds on.
  static (double x, double v, double a) springCharacter(
      double x, double v, double a, double goalVelocity, double halflife, double t) {
    final y = halflifeToDamping(halflife) / 2.0;
    final j0 = v - goalVelocity;
    final j1 = a + j0 * y;
    final eydt = math.exp(-y * t);
    final nx = eydt * ((-j1) / (y * y) + (-j0 - j1 * t) / y) + j1 / (y * y) + j0 / y + goalVelocity * t + x;
    final nv = eydt * (j0 + j1 * t) + goalVelocity;
    final na = eydt * (a - j1 * y * t);
    return (nx, nv, na);
  }

  /// An angle (radians) springing toward [goal] the short way round:
  /// angle and angular velocity [t] seconds on.
  static (double angle, double velocity) springAngle(double angle, double velocity, double goal, double halflife, double t) {
    final diff = wrap(angle - goal);
    final (x, v) = decaySpringDamper(diff, velocity, halflife, t);
    return (wrap(goal + x), v);
  }

  /// [a] wrapped to (−π, π].
  static double wrap(double a) {
    var r = a % (2 * math.pi);
    if (r > math.pi) r -= 2 * math.pi;
    return r;
  }
}
