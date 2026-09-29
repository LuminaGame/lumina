import 'package:vector_math/vector_math_64.dart';
import 'collision_component.dart';
import 'shape_wireframes.dart';

/// A convex collider around an authored hull (e.g. `UCX_` hulls):
/// [points] are the hull's vertices in the component's local
/// frame (world units); [hullAsset] remembers the mesh asset the hull came
/// from (a project `.lmas` path) for the editor.
class LuminaConvexComponent extends LuminaCollisionComponent {
  /// The mesh asset whose simple collision this hull is, if any.
  final String? hullAsset;

  LuminaConvexComponent({
    super.key,
    super.location,
    super.rotation,
    super.scale,
    required List<Vector3> points,
    this.hullAsset,
  }) : super(shapeType: CollisionShapeType.convex, convexPoints: points);

  /// The hull's unique edges, world space.
  @override
  List<Vector3> buildWireframe({int segments = 16}) {
    final hull = convexHull!;
    final t = worldTransform;
    final seen = <int>{};
    final pts = <Vector3>[];
    for (var i = 0; i < hull.triangles.length; i += 3) {
      for (var k = 0; k < 3; k++) {
        final a = hull.triangles[i + k];
        final b = hull.triangles[i + (k + 1) % 3];
        final lo = a < b ? a : b;
        final hi = a < b ? b : a;
        if (!seen.add(lo * 1000003 + hi)) continue;
        LuminaShapeWireframes.line(pts, t.transform3(hull.vertices[a].clone()), t.transform3(hull.vertices[b].clone()));
      }
    }
    return pts;
  }
}
