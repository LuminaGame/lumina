import 'package:vector_math/vector_math_64.dart';

export 'convex_hull.dart';
export 'heightfield.dart' show HeightfieldShape;

/// Base class for geometric collision shape descriptors decoupled from the scene graph.
abstract class CollisionShape {
  const CollisionShape();
}

/// Sphere collision shape defined by its [radius].
class SphereShape extends CollisionShape {
  final double radius;
  const SphereShape(this.radius);
}

/// Box collision shape defined by [halfExtents].
class BoxShape extends CollisionShape {
  final Vector3 halfExtents;
  const BoxShape(this.halfExtents);
}

/// Capsule collision shape defined by [radius] and [halfHeight] of the full capsule.
class CapsuleShape extends CollisionShape {
  final double radius;
  final double halfHeight;
  const CapsuleShape(this.radius, this.halfHeight);
}

/// Cone collision shape defined by base [radius] and [height].
class ConeShape extends CollisionShape {
  final double radius;
  final double height;
  const ConeShape(this.radius, this.height);
}

/// Cylinder collision shape defined by [radius] and [height].
class CylinderShape extends CollisionShape {
  final double radius;
  final double height;
  const CylinderShape(this.radius, this.height);
}
