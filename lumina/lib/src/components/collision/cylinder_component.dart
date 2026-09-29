import 'package:vector_math/vector_math_64.dart';
import '../../math/euler.dart';
import 'collision_component.dart';
import 'shape_wireframes.dart';

/// A cylinder collider: [radius] and [halfHeight] along the
/// component's local +Y ([LuminaCollisionComponent.height] stays twice the
/// half height).
class LuminaCylinderComponent extends LuminaCollisionComponent {
  LuminaCylinderComponent({
    super.key,
    super.location,
    super.rotation,
    super.scale,
    super.radius = 50.0,
    super.halfHeight = 80.0,
  }) : super(shapeType: CollisionShapeType.cylinder) {
    height = halfHeight * 2.0;
  }

  double get cylinderRadius => radius;
  set cylinderRadius(double r) {
    radius = r;
    markCollisionDirty();
  }

  double get cylinderHalfHeight => halfHeight;
  set cylinderHalfHeight(double h) {
    halfHeight = h;
    height = h * 2.0;
    markCollisionDirty();
  }

  /// Two cap rings and four side lines, world space.
  @override
  List<Vector3> buildWireframe({int segments = 16}) {
    final c = worldLocation;
    final r = rightVector;
    final u = upVector;
    final f = worldRotation.rotateVector(Vector3(0, 0, 1));
    final top = c + u * halfHeight;
    final bottom = c - u * halfHeight;
    final pts = <Vector3>[];
    LuminaShapeWireframes.ring(pts, top, r, f, radius, segments);
    LuminaShapeWireframes.ring(pts, bottom, r, f, radius, segments);
    for (final d in [r, -r, f, -f]) {
      LuminaShapeWireframes.line(pts, bottom + d * radius, top + d * radius);
    }
    return pts;
  }
}
