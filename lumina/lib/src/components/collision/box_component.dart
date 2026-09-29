import 'package:vector_math/vector_math_64.dart';
import '../../math/euler.dart';
import 'collision_component.dart';
import 'shape_wireframes.dart';

/// A box collider: [boxExtent] is
/// its half size in world units, oriented by the component's transform.
class LuminaBoxComponent extends LuminaCollisionComponent {
  LuminaBoxComponent({
    super.key,
    super.location,
    super.rotation,
    super.scale,
    Vector3? boxExtent,
  }) : super(shapeType: CollisionShapeType.box) {
    if (boxExtent != null) this.boxExtent = boxExtent.clone();
  }

  /// Sets the half extents and refreshes the bounds.
  void setBoxExtent(Vector3 extent) {
    boxExtent = extent.clone();
    markCollisionDirty();
  }

  /// The 12 edges of the box as 24 points (segment pairs), world space.
  @override
  List<Vector3> buildWireframe({int segments = 16}) {
    final c = worldLocation;
    final r = rightVector * boxExtent.x;
    final u = upVector * boxExtent.y;
    final f = worldRotation.rotateVector(Vector3(0, 0, 1)) * boxExtent.z;
    Vector3 corner(int i) => c + r * (i & 1 == 0 ? -1.0 : 1.0) + u * (i & 2 == 0 ? -1.0 : 1.0) + f * (i & 4 == 0 ? -1.0 : 1.0);
    final pts = <Vector3>[];
    for (var i = 0; i < 8; i++) {
      for (final bit in const [1, 2, 4]) {
        if (i & bit == 0) LuminaShapeWireframes.line(pts, corner(i), corner(i | bit));
      }
    }
    return pts;
  }
}
