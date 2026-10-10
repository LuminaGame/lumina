part of '../blueprint_preview_scene.dart';

// Line geometry of the component visualizers (runtime space, cm), shared
// by the overlays and picking.

/// The boom from its origin to the socket its children sit at, and a small
/// cross at each end.
List<Vector3> _springArm(LuminaSpringArmComponent arm) {
  final origin = arm.worldLocation;
  final socket = arm.socketWorldLocation;
  return [origin, socket, ..._cross(origin, 6.0), ..._cross(socket, 6.0)];
}

List<Vector3> _cross(Vector3 at, double size) => [
      at + Vector3(size, 0, 0), at - Vector3(size, 0, 0),
      at + Vector3(0, size, 0), at - Vector3(0, size, 0),
      at + Vector3(0, 0, size), at - Vector3(0, 0, size),
    ];

/// A camera: its frustum 50 cm deep (its vertical field of view, 16:9) and
/// a triangle on the top edge marking up.
List<Vector3> _cameraFrustum(LuminaCameraComponent camera) {
  const depth = 50.0;
  final eye = camera.worldLocation;
  final forward = camera.forwardVector;
  final up = camera.upVector;
  final right = camera.rightVector;
  final halfH = math.tan(camera.fieldOfViewInDegrees * math.pi / 360.0) * depth;
  final halfW = halfH * 16.0 / 9.0;
  final centre = eye + forward * depth;
  final corners = [
    centre + right * halfW + up * halfH,
    centre - right * halfW + up * halfH,
    centre - right * halfW - up * halfH,
    centre + right * halfW - up * halfH,
  ];
  return [
    for (final c in corners) ...[eye, c],
    for (var i = 0; i < 4; i++) ...[corners[i], corners[(i + 1) % 4]],
    corners[0] + up * (halfH * 0.15), centre + up * (halfH * 1.5),
    centre + up * (halfH * 1.5), corners[1] + up * (halfH * 0.15),
    corners[1] + up * (halfH * 0.15), corners[0] + up * (halfH * 0.15),
  ];
}

List<Vector3> _arrow(LuminaSceneComponent c, double length) {
  final from = c.worldLocation;
  final forward = c.forwardVector;
  final to = from + forward * length;
  final side = c.rightVector * (length * 0.12);
  final back = forward * (length * 0.2);
  return [from, to, to, to - back + side, to, to - back - side];
}

List<Vector3> _tripod(LuminaSceneComponent c, double length) {
  final at = c.worldLocation;
  return [at, at + c.rightVector * length, at, at + c.upVector * length, at, at - c.forwardVector * length];
}

/// A loaded mesh's bounds as a box, in the world.
List<Vector3> _bounds(LuminaStaticMeshComponent mesh) {
  final box = mesh.localBounds;
  if (box == null) return const [];
  final m = mesh.worldTransform;
  final c = [
    for (var i = 0; i < 8; i++)
      m.transformed3(Vector3(i & 1 == 0 ? box.min.x : box.max.x, i & 2 == 0 ? box.min.y : box.max.y,
          i & 4 == 0 ? box.min.z : box.max.z)),
  ];
  const edges = [0, 1, 2, 3, 4, 5, 6, 7, 0, 2, 1, 3, 4, 6, 5, 7, 0, 4, 1, 5, 2, 6, 3, 7];
  return [for (final e in edges) c[e]];
}

(double, double, double)? _hexColor(Object? hex) {
  if (hex is! String) return null;
  final h = hex.replaceFirst('#', '');
  if (h.length < 6) return null;
  final v = int.tryParse(h.substring(0, 6), radix: 16);
  if (v == null) return null;
  return (((v >> 16) & 0xFF) / 255.0, ((v >> 8) & 0xFF) / 255.0, (v & 0xFF) / 255.0);
}
