import 'package:vector_math/vector_math_64.dart';

/// Computes the slide displacement vector along a plane surface defined by [normal].
///
/// Projects the unconsumed movement remainder `delta * (1.0 - time)` onto the plane.
Vector3 computeSlideVector(
  Vector3 delta,
  double time,
  Vector3 normal,
  Vector3 out,
) {
  final remainder = delta * (1.0 - time.clamp(0.0, 1.0));
  final nNorm = normal.length2 > 1e-12 ? normal.normalized() : Vector3(0.0, 1.0, 0.0);
  final proj = remainder.dot(nNorm);
  out.setFrom(remainder - (nNorm * proj));
  return out;
}
