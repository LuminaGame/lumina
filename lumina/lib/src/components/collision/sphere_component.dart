import 'package:vector_math/vector_math_64.dart';
import 'package:lumina/src/math/euler.dart';
import 'package:lumina/src/components/collision/collision_component.dart';
import 'package:lumina/src/components/collision/shape_wireframes.dart';

/// A sphere collider.
class LuminaSphereComponent extends LuminaCollisionComponent {
  LuminaSphereComponent({
    super.key,
    super.location,
    super.rotation,
    super.scale,
    super.radius = 50.0,
  }) : super(shapeType: CollisionShapeType.sphere);

  double get sphereRadius => radius;
  set sphereRadius(double r) {
    radius = r;
    markCollisionDirty();
  }

  /// Three great circles (right-up, forward-up, right-forward), world space.
  @override
  List<Vector3> buildWireframe({int segments = 16}) {
    final c = worldLocation;
    final r = rightVector;
    final u = upVector;
    final f = worldRotation.rotateVector(Vector3(0, 0, 1));
    final pts = <Vector3>[];
    LuminaShapeWireframes.ring(pts, c, r, u, radius, segments);
    LuminaShapeWireframes.ring(pts, c, f, u, radius, segments);
    LuminaShapeWireframes.ring(pts, c, r, f, radius, segments);
    return pts;
  }
}
