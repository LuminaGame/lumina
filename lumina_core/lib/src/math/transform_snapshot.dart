import 'package:vector_math/vector_math_64.dart';

/// A snapshot of a location and rotation.
class LuminaTransformSnapshot {
  /// The location vector.
  final Vector3 location;

  /// The rotation quaternion.
  final Quaternion rotation;

  /// Creates a new [LuminaTransformSnapshot].
  LuminaTransformSnapshot({
    required this.location,
    required this.rotation,
  });

  /// Creates a [LuminaTransformSnapshot] at the origin with zero rotation.
  factory LuminaTransformSnapshot.zero() {
    return LuminaTransformSnapshot(
      location: Vector3.zero(),
      rotation: Quaternion.identity(),
    );
  }
}
