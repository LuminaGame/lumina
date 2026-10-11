import 'package:vector_math/vector_math_64.dart';

/// A ray a grabber points along (world units, runtime axes), for grabbing
/// at a distance.
class LuminaGrabRay {
  final Vector3 origin;

  /// Unit direction.
  final Vector3 direction;

  LuminaGrabRay(Vector3 origin, Vector3 direction)
      : origin = origin.clone(),
        direction = direction.normalized();
}

/// Anything that can grab a pose handle: a tracked XR controller, the mouse
/// in Play-In-Editor, a scripted test hand. The engine knows grabbers only
/// through this interface, so the grab interaction works the same with any
/// of them.
abstract interface class LuminaGrabber {
  /// Stable id (`left`, `right`, `mouse`, …), reported with the grab events.
  String get id;

  /// The grip pose in the world (cm, runtime axes; unit scale).
  Matrix4 get worldTransform;

  /// How far the grip is pressed, 0–1.
  double get grip;

  /// Whether the device is tracked now (an untracked grabber lets go).
  bool get isTracked;

  /// The ray for grabbing at a distance, or null for near grabs only.
  LuminaGrabRay? get ray;

  /// A haptic pulse; does nothing on a device without haptics.
  void pulse(double amplitude, double seconds);

  /// Told the world point a grab took ([point]): a grabber that holds things
  /// at a depth (the mouse) moves its depth there.
  void grabbedAt(Vector3 point);
}
