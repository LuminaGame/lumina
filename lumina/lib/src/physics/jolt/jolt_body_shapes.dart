import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_jolt/flutter_jolt.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:vector_math/vector_math_64.dart';

import 'package:lumina/src/components/collision/collision_component.dart';
import 'package:lumina/src/physics/rigid_body.dart';

/// Lumina lengths (cm) to Jolt's (m), and back.
const double kJoltScale = 1.0 / LuminaUnits.unitsPerMetre;
const double kLuminaScale = LuminaUnits.unitsPerMetre;

Vector3 toJolt(Vector3 cm) => cm * kJoltScale;

/// Lumina collision shapes as Jolt shapes (metres). The runtime frame is
/// already Y-up, so only lengths change; capsules, cylinders and cones keep
/// their local Y axis.
abstract final class LuminaJoltShapes {
  /// Rounded edges of boxes and cylinders: at most 1 cm and a quarter of
  /// the smallest half extent (Jolt keeps sharp corners within it).
  static double _convexRadius(double smallestHalfExtentM) => math.min(0.01, 0.25 * smallestHalfExtentM);

  /// One Lumina shape as a Jolt leaf in its own frame; [scale] is applied to
  /// a convex hull's points (boxes arrive with their scale already in the
  /// extents). Null for a shape Jolt bodies do not take (a heightfield).
  static JoltShape? leaf(CollisionShape shape, {Vector3? scale}) {
    if (shape is BoxShape) {
      final h = shape.halfExtents * kJoltScale;
      final e = Vector3(math.max(h.x, 1e-4), math.max(h.y, 1e-4), math.max(h.z, 1e-4));
      return JoltShape.box(e, convexRadius: _convexRadius(math.min(e.x, math.min(e.y, e.z))));
    }
    if (shape is SphereShape) return JoltShape.sphere(math.max(shape.radius * kJoltScale, 1e-4));
    if (shape is CapsuleShape) {
      final r = math.max(shape.radius * kJoltScale, 1e-4);
      return JoltShape.capsule(math.max(shape.halfHeight * kJoltScale - r, 0.0), r);
    }
    if (shape is CylinderShape) {
      final hh = math.max(shape.height * 0.5 * kJoltScale, 1e-4);
      final r = math.max(shape.radius * kJoltScale, 1e-4);
      return JoltShape.cylinder(hh, r, convexRadius: _convexRadius(math.min(hh, r)));
    }
    if (shape is ConeShape) return JoltShape.convexHull(conePoints(shape), maxConvexRadius: 0);
    if (shape is ConvexHullShape) {
      final s = scale ?? Vector3(1, 1, 1);
      final pts = [for (final v in shape.vertices) (v.clone()..multiply(s)) * kJoltScale];
      if (shape.isDegenerate || pts.length < 4) {
        // A flat hull: a thin box around its points.
        final lo = Vector3.all(double.infinity), hi = Vector3.all(-double.infinity);
        for (final p in pts) {
          Vector3.min(lo, p, lo);
          Vector3.max(hi, p, hi);
        }
        final half = ((hi - lo)..scale(0.5));
        final box = JoltShape.box(Vector3(math.max(half.x, 1e-3), math.max(half.y, 1e-3), math.max(half.z, 1e-3)),
            convexRadius: 0);
        final placed = JoltShape.rotatedTranslated(box, (lo + hi)..scale(0.5), Quaternion.identity());
        box.release();
        return placed;
      }
      return JoltShape.convexHull(pts, maxConvexRadius: 0.005);
    }
    return null;
  }

  /// A cone (apex at +Y half its height, base at −Y) as hull points (m).
  static List<Vector3> conePoints(ConeShape cone, {int segments = 24}) {
    final r = math.max(cone.radius * kJoltScale, 1e-4);
    final hh = math.max(cone.height * 0.5 * kJoltScale, 1e-4);
    return [
      Vector3(0, hh, 0),
      for (var i = 0; i < segments; i++)
        Vector3(r * math.cos(2 * math.pi * i / segments), -hh, r * math.sin(2 * math.pi * i / segments)),
    ];
  }

  /// [body]'s shape for Jolt: every piece in the body frame (each leaf's
  /// user data is its index in [LuminaRigidBody.shapes]), its centre of mass
  /// moved to [LuminaRigidBody.localCenterOfMass].
  static JoltShape forBody(LuminaRigidBody body) {
    final parts = <({JoltShape shape, Vector3 position, Quaternion rotation})>[];
    for (var i = 0; i < body.shapes.length; i++) {
      final s = body.shapes[i];
      final leafShape = leaf(s.shape, scale: s.scale) ?? JoltShape.box(Vector3.all(0.1), convexRadius: 0);
      leafShape.userData = i;
      parts.add((shape: leafShape, position: s.position * kJoltScale, rotation: s.rotation.normalized()));
    }
    JoltShape shape;
    final single = parts.length == 1 &&
        parts.first.position.length2 < 1e-12 &&
        (parts.first.rotation.w.abs() - 1).abs() < 1e-9;
    if (single) {
      shape = parts.first.shape;
    } else {
      shape = JoltShape.compound(parts);
      for (final p in parts) {
        p.shape.release();
      }
    }
    final offset = body.localCenterOfMass * kJoltScale - shape.centerOfMass;
    if (offset.length2 < 1e-14) return shape;
    final moved = JoltShape.offsetCenterOfMass(shape, offset);
    shape.release();
    return moved;
  }

  /// [body]'s inertia in Jolt units (kg·m²).
  static Matrix3 inertiaOf(LuminaRigidBody body) => body.localInertia.scaled(kJoltScale * kJoltScale);

  /// A static collider's shape (m) in the component's frame, with the
  /// component's own scale applied. Null for a shape Jolt cannot take.
  static JoltShape? forCollider(LuminaCollisionComponent c) {
    final s = c.relativeScale;
    final abs = Vector3(s.x.abs(), s.y.abs(), s.z.abs());
    final shape = c.worldShape;
    if (shape is HeightfieldShape) return heightField(shape, s);
    if (shape is BoxShape) return leaf(BoxShape(shape.halfExtents.clone()..multiply(abs)));
    if (shape is ConvexHullShape) return leaf(shape, scale: s);
    final uniform = math.max(abs.x, math.max(abs.y, abs.z));
    if (shape is SphereShape) return leaf(SphereShape(shape.radius * uniform));
    if ((uniform - 1).abs() < 1e-9) return leaf(shape);
    final inner = leaf(shape);
    if (inner == null) return null;
    final scaled = JoltShape.scaled(inner, abs);
    inner.release();
    return scaled;
  }

  /// A landscape heightfield: the samples [shape] draws, scaled by the
  /// component's [scale] (local X/Z spacing, Y heights), in metres.
  static JoltShape heightField(HeightfieldShape shape, Vector3 scale) {
    final data = shape.data;
    final n = data.gridResolution;
    final u = shape.unitsPerMetre * kJoltScale;
    final samples = Float32List(n * n);
    for (var row = 0; row < n; row++) {
      for (var col = 0; col < n; col++) {
        samples[row * n + col] = data.heightAt(col, row) * u * scale.y;
      }
    }
    final half = data.worldSize / 2 * u;
    return JoltShape.heightField(
      samples,
      n,
      offset: Vector3(-half * scale.x, 0, -half * scale.z),
      scale: Vector3(data.cellSize * u * scale.x, 1, data.cellSize * u * scale.z),
    );
  }
}
