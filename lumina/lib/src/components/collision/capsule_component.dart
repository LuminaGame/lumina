import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart';
import 'collision_component.dart';

/// 3D Capsule collision component for character bounding geometry and sweep collision.
class LuminaCapsuleComponent extends LuminaCollisionComponent {
  LuminaCapsuleComponent({
    super.key,
    super.location,
    super.rotation,
    super.radius = 40.0,
    super.halfHeight,
  }) : super(
          shapeType: CollisionShapeType.capsule,
        );

  double get capsuleRadius => radius;
  set capsuleRadius(double r) {
    radius = r;
    markCollisionDirty();
  }

  double get capsuleHalfHeight => halfHeight;
  set capsuleHalfHeight(double h) {
    halfHeight = h;
    markCollisionDirty();
  }

  /// Start point of the inner core line segment in world space.
  Vector3 get segmentStart => getSegmentPoints()[0];

  /// End point of the inner core line segment in world space.
  Vector3 get segmentEnd => getSegmentPoints()[1];

  /// Returns segment start and end points in world space.
  List<Vector3> getSegmentPoints() {
    final center = worldLocation;
    final up = upVector;
    final segHalf = halfHeight > radius ? halfHeight - radius : 0.0;
    return [
      center - (up * segHalf),
      center + (up * segHalf),
    ];
  }

  /// Builds wireframe line segments (pairs of vertices) for debug drawing.
  List<Vector3> buildCapsuleWireframe({int segments = 16}) {
    final pts = <Vector3>[];
    final seg = getSegmentPoints();
    final p0 = seg[0]; // Bottom sphere center
    final p1 = seg[1]; // Top sphere center
    final u = upVector;
    final r = rightVector;
    final f = -forwardVector; // Local +Z

    // 1. Longitudinal cylinder lines
    pts.add(p0 + (r * radius)); pts.add(p1 + (r * radius));
    pts.add(p0 - (r * radius)); pts.add(p1 - (r * radius));
    pts.add(p0 + (f * radius)); pts.add(p1 + (f * radius));
    pts.add(p0 - (f * radius)); pts.add(p1 - (f * radius));

    // 2. Latitude rings at cylinder caps
    final step = (2.0 * math.pi) / segments;
    for (int i = 0; i < segments; i++) {
      final theta1 = i * step;
      final theta2 = (i + 1) * step;

      final cos1 = math.cos(theta1);
      final sin1 = math.sin(theta1);
      final cos2 = math.cos(theta2);
      final sin2 = math.sin(theta2);

      final v1 = (r * (cos1 * radius)) + (f * (sin1 * radius));
      final v2 = (r * (cos2 * radius)) + (f * (sin2 * radius));

      // Bottom cap ring
      pts.add(p0 + v1); pts.add(p0 + v2);
      // Top cap ring
      pts.add(p1 + v1); pts.add(p1 + v2);
    }

    // 3. Hemisphere arcs
    final halfStep = math.pi / segments;
    for (int i = 0; i < segments; i++) {
      final theta1 = i * halfStep;
      final theta2 = (i + 1) * halfStep;

      final cos1 = math.cos(theta1);
      final sin1 = math.sin(theta1);
      final cos2 = math.cos(theta2);
      final sin2 = math.sin(theta2);

      // Top hemisphere in right-up plane
      pts.add(p1 + (r * (cos1 * radius)) + (u * (sin1 * radius)));
      pts.add(p1 + (r * (cos2 * radius)) + (u * (sin2 * radius)));

      // Top hemisphere in forward-up plane
      pts.add(p1 + (f * (cos1 * radius)) + (u * (sin1 * radius)));
      pts.add(p1 + (f * (cos2 * radius)) + (u * (sin2 * radius)));

      // Bottom hemisphere in right-up plane
      pts.add(p0 + (r * (cos1 * radius)) - (u * (sin1 * radius)));
      pts.add(p0 + (r * (cos2 * radius)) - (u * (sin2 * radius)));

      // Bottom hemisphere in forward-up plane
      pts.add(p0 + (f * (cos1 * radius)) - (u * (sin1 * radius)));
      pts.add(p0 + (f * (cos2 * radius)) - (u * (sin2 * radius)));
    }

    return pts;
  }
}
