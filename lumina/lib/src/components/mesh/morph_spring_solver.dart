import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart';

/// A damped spring for secondary motion: the offset (centimetres, in the
/// mesh's frame) of a soft mass carried by the body. The body's acceleration
/// pushes the mass the other way (inertia), a change in the direction of
/// gravity moves its rest (lying down, bending over), and the spring pulls it
/// back with the given frequency and damping ratio.
///
/// Pure Dart: it runs the same in a game, in PIE and in an editor preview.
class LuminaMorphSpringSolver {
  /// The simulation step, seconds.
  static const double step = 1 / 240;

  /// Natural frequency, Hz.
  double frequency;

  /// Damping ratio: 1 settles without overshoot, lower bounces.
  double damping;

  /// How much of the body's acceleration moves the mass (1: all of it).
  double inertia;

  /// How much a change in the direction of gravity moves the rest (1: all).
  double gravity;

  /// The largest offset, centimetres.
  double limit;

  final Vector3 offset = Vector3.zero();
  final Vector3 velocity = Vector3.zero();
  Vector3? _gravityRest;
  double _accumulator = 0;

  LuminaMorphSpringSolver({
    this.frequency = 2.5,
    this.damping = 0.25,
    this.inertia = 1,
    this.gravity = 1,
    this.limit = 6,
  });

  /// Back to rest; the next [advance] takes its gravity as the rest one.
  void reset() {
    offset.setZero();
    velocity.setZero();
    _gravityRest = null;
    _accumulator = 0;
  }

  /// Advances by [deltaTime] seconds with the body's [acceleration] and
  /// [gravityLocal] (both cm/s², in the mesh's frame). The first call takes
  /// [gravityLocal] as the rest direction.
  void advance(double deltaTime, Vector3 acceleration, Vector3 gravityLocal) {
    final rest = _gravityRest ??= gravityLocal.clone();
    final omega = 2 * math.pi * frequency;
    final external = (gravityLocal - rest)..scale(gravity);
    external.addScaled(acceleration, -inertia);
    _accumulator += math.min(deltaTime, 0.25);
    while (_accumulator >= step) {
      _accumulator -= step;
      final force = offset.scaled(-omega * omega)
        ..addScaled(velocity, -2 * damping * omega)
        ..add(external);
      velocity.addScaled(force, step);
      offset.addScaled(velocity, step);
      final length = offset.length;
      if (length > limit) {
        offset.scale(limit / length);
        // Moving further out along the limit is stopped.
        final direction = offset.normalized();
        final outward = velocity.dot(direction);
        if (outward > 0) velocity.addScaled(direction, -outward);
      }
    }
  }
}
