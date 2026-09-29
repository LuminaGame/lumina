import 'package:vector_math/vector_math_64.dart';
import '../../math/euler.dart';
import 'collision_component.dart';
import 'shape_wireframes.dart';

/// A cone collider: base radius [radius] at local −Y
/// [halfHeight], apex at +Y [halfHeight].
class LuminaConeComponent extends LuminaCollisionComponent {
  LuminaConeComponent({
    super.key,
    super.location,
    super.rotation,
    super.scale,
    super.radius = 50.0,
    super.halfHeight = 80.0,
  }) : super(shapeType: CollisionShapeType.cone) {
    height = halfHeight * 2.0;
  }

  double get coneRadius => radius;
  set coneRadius(double r) {
    radius = r;
    markCollisionDirty();
  }

  double get coneHalfHeight => halfHeight;
  set coneHalfHeight(double h) {
    halfHeight = h;
    height = h * 2.0;
    markCollisionDirty();
  }

  /// The base ring and four lines to the apex, world space.
  @override
  List<Vector3> buildWireframe({int segments = 16}) {
    final c = worldLocation;
    final r = rightVector;
    final u = upVector;
    final f = worldRotation.rotateVector(Vector3(0, 0, 1));
    final base = c - u * halfHeight;
    final tip = apex;
    final pts = <Vector3>[];
    LuminaShapeWireframes.ring(pts, base, r, f, radius, segments);
    for (final d in [r, -r, f, -f]) {
      LuminaShapeWireframes.line(pts, base + d * radius, tip);
    }
    return pts;
  }
}
