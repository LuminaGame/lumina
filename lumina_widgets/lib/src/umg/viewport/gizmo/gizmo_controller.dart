import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart';

enum GizmoMode { translate, rotate, scale }
enum GizmoSpace { world, local }

class GizmoController {
  
  static double solveAxisTranslation({
    required Ray ray,
    required Vector3 axisOrigin,
    required Vector3 axisDirection,
  }) {
    final w0 = axisOrigin - ray.origin;
    final a = axisDirection.dot(axisDirection);
    final b = axisDirection.dot(ray.direction);
    final c = ray.direction.dot(ray.direction);
    final d = axisDirection.dot(w0);
    final e = ray.direction.dot(w0);
    
    final den = a * c - b * b;
    if (den.abs() < 1e-6) {
      return 0.0; 
    }
    
    final sAxis = (b * e - c * d) / den;
    return sAxis;
  }

  static Vector3 solvePlaneTranslation({
    required Ray ray,
    required Vector3 planeOrigin,
    required Vector3 planeNormal,
  }) {
    final denom = planeNormal.dot(ray.direction);
    if (denom.abs() < 1e-6) return planeOrigin;
    
    final t = (planeOrigin - ray.origin).dot(planeNormal) / denom;
    return ray.origin + (ray.direction * t);
  }
  
  static double solveRotation({
    required Ray ray,
    required Vector3 ringOrigin,
    required Vector3 ringNormal,
    required Vector3 grabPoint,
  }) {
    final hit = solvePlaneTranslation(ray: ray, planeOrigin: ringOrigin, planeNormal: ringNormal);
    
    final vGrab = (grabPoint - ringOrigin).normalized();
    final vHit = (hit - ringOrigin).normalized();
    
    final dot = vGrab.dot(vHit).clamp(-1.0, 1.0);
    final cross = vGrab.cross(vHit);
    
    double angle = math.acos(dot) * 180.0 / math.pi;
    if (cross.dot(ringNormal) < 0) {
      angle = -angle;
    }
    return angle;
  }
  
  static Vector3 getAxisDirection(String axis, GizmoSpace space, [Quaternion? rotation]) {
    Vector3 dir = Vector3(1,0,0);
    if (axis.contains('Y')) dir = Vector3(0,1,0);
    if (axis.contains('Z')) dir = Vector3(0,0,1);
    
    if (space == GizmoSpace.local && rotation != null) {
      return rotation.rotated(dir);
    }
    return dir;
  }
  
  static Vector3 getPlaneNormal(String planeId, GizmoSpace space, [Quaternion? rotation]) {
    Vector3 normal = Vector3(0,0,1); // XY plane
    if (planeId == 'XZ') normal = Vector3(0,1,0);
    if (planeId == 'YZ') normal = Vector3(1,0,0);
    
    if (space == GizmoSpace.local && rotation != null) {
      return rotation.rotated(normal);
    }
    return normal;
  }
}
