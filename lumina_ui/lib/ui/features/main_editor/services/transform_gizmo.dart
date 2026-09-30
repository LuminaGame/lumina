import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:lumina/lumina.dart' show LuminaAxes;
import 'package:vector_math/vector_math_64.dart';

import 'gizmo_controller.dart';
import 'snap_service.dart';

/// The transform manipulator both viewports share: the
/// handle layout of the translate / rotate / scale tools, hover hit-testing
/// against the projected handles, and the drag solvers of
/// [GizmoController] wrapped in a drag that remembers where it started.
///
/// The model is frame-agnostic: [pivot], [rotation] and every ray are in the
/// caller's frame, and [project] maps that frame to viewport pixels. The
/// level viewport uses its Z-up editor space with its own camera matrix; the
/// Blueprint viewport converts its Y-up runtime camera to the authoring frame
/// in one place (`SubEditor3DViewport`).
class TransformGizmoModel {
  /// Handle ids.
  static const String center = 'CENTER';
  static const String axisX = 'X';
  static const String axisY = 'Y';
  static const String axisZ = 'Z';
  static const String planeXY = 'XY';
  static const String planeXZ = 'XZ';
  static const String planeYZ = 'YZ';
  static const String uniform = 'UNIFORM';

  static const List<String> axes = [axisX, axisY, axisZ];
  static const List<String> planes = [planeXY, planeXZ, planeYZ];

  final GizmoMode mode;
  final GizmoSpace space;
  final Vector3 pivot;

  /// The manipulated object's rotation, used for the local-space axes.
  final Quaternion rotation;

  /// Arrow / stem / ring length in world units.
  final double axisLength;

  /// Where a plane quad sits along its two axes, in world units.
  final double planeOffset;

  /// Whether the handles are drawn (and hit-tested) along the local axes in
  /// local space. The level viewport's native manipulator is never rotated,
  /// so it hit-tests along the world axes whatever the space (false).
  final bool orientHandles;

  /// Frame → viewport pixels; null when the point is behind the camera.
  final Offset? Function(Vector3 point) project;

  const TransformGizmoModel({
    required this.mode,
    required this.space,
    required this.pivot,
    required this.rotation,
    required this.axisLength,
    required this.planeOffset,
    required this.project,
    this.orientHandles = true,
  });

  /// The direction of [axis] the drag solves along: the world axis, or the
  /// object's own in local space.
  Vector3 axisDirection(String axis) => GizmoController.getAxisDirection(axis, space, rotation);

  /// The normal of plane [plane] (`XY` → Z), world or local like [axisDirection].
  Vector3 planeNormal(String plane) => GizmoController.getPlaneNormal(plane, space, rotation);

  /// The direction handle [axis] is laid out along (see [orientHandles]).
  Vector3 handleAxis(String axis) =>
      orientHandles ? axisDirection(axis) : GizmoController.getAxisDirection(axis, GizmoSpace.world);

  /// Where each handle is on screen, in viewport-local pixels, or null when
  /// the pivot is behind the camera. A handle behind the camera falls back
  /// to a fixed offset from the centre so hit-testing never sees a hole.
  Map<String, Offset>? handleScreenPositions() {
    final centre = project(pivot);
    if (centre == null) return null;
    final x = handleAxis(axisX);
    final y = handleAxis(axisY);
    final z = handleAxis(axisZ);
    Offset at(Vector3 offset, Offset fallback) => project(pivot + offset) ?? fallback;
    return {
      center: centre,
      axisX: at(x * axisLength, centre + const Offset(45, -8)),
      axisY: at(y * axisLength, centre + const Offset(18, 30)),
      axisZ: at(z * axisLength, centre + const Offset(0, -48)),
      planeXY: at((x + y) * planeOffset, centre),
      planeXZ: at((x + z) * planeOffset, centre),
      planeYZ: at((y + z) * planeOffset, centre),
    };
  }

  /// The rotate tool's ring around [axis] as projected points (null where a
  /// point is behind the camera), [segments] + 1 of them.
  List<Offset?> ringPoints(String axis, {int segments = 24, double? radius}) {
    final r = radius ?? axisLength;
    // Two perpendicular directions in the ring's plane: the other two axes.
    final u = handleAxis(axis == axisX ? axisY : axisX);
    final v = handleAxis(axis == axisZ ? axisY : axisZ);
    return [
      for (var i = 0; i <= segments; i++)
        project(pivot + u * (math.cos(i * 2.0 * math.pi / segments) * r) + v * (math.sin(i * 2.0 * math.pi / segments) * r)),
    ];
  }

  /// The handle under [localPos], or null. The tolerances are the level
  /// viewport's: 12–16 px for the centre and plane quads,
  /// 20 px along an arrow, stem or ring.
  String? hitTest(Offset localPos) {
    final handles = handleScreenPositions();
    if (handles == null) return null;
    final centre = handles[center]!;
    final posX = handles[axisX]!;
    final posY = handles[axisY]!;
    final posZ = handles[axisZ]!;

    String? nearestAxis(double tolerance) {
      final dX = distanceToSegment(localPos, centre, posX);
      final dY = distanceToSegment(localPos, centre, posY);
      final dZ = distanceToSegment(localPos, centre, posZ);
      final minAxisDist = math.min(dX, math.min(dY, dZ));
      if (minAxisDist >= tolerance) return null;
      if (minAxisDist == dX) return axisX;
      if (minAxisDist == dY) return axisY;
      return axisZ;
    }

    switch (mode) {
      case GizmoMode.translate:
        final dXY = (localPos - handles[planeXY]!).distance;
        final dXZ = (localPos - handles[planeXZ]!).distance;
        final dYZ = (localPos - handles[planeYZ]!).distance;
        final dCenter = (localPos - centre).distance;
        final minPlaneDist = math.min(dXY, math.min(dXZ, dYZ));
        if (dCenter < 12.0 && dCenter < minPlaneDist) return center;
        if (minPlaneDist < 16.0) {
          if (minPlaneDist == dXY) return planeXY;
          if (minPlaneDist == dXZ) return planeXZ;
          return planeYZ;
        }
        if (dCenter < 14.0) return center;
        return nearestAxis(20.0);
      case GizmoMode.rotate:
        double distToRing(String axis) {
          var minDist = double.infinity;
          Offset? prev;
          for (final p in ringPoints(axis)) {
            if (p != null && prev != null) {
              final d = distanceToSegment(localPos, prev, p);
              if (d < minDist) minDist = d;
            }
            prev = p;
          }
          return minDist;
        }

        final dX = distToRing(axisX);
        final dY = distToRing(axisY);
        final dZ = distToRing(axisZ);
        final minRingDist = math.min(dX, math.min(dY, dZ));
        if (minRingDist < 20.0) {
          if (minRingDist == dX) return axisX;
          if (minRingDist == dY) return axisY;
          return axisZ;
        }
        if ((localPos - posX).distance < 32.0) return axisX;
        if ((localPos - posY).distance < 32.0) return axisY;
        if ((localPos - posZ).distance < 32.0) return axisZ;
        return null;
      case GizmoMode.scale:
        if ((localPos - centre).distance < 14.0) return uniform;
        return nearestAxis(20.0);
    }
  }

  /// Starts a drag of [handle] with the pointer's [ray]. [cameraPosition] is
  /// needed for the translate tool's centre handle (it drags in the plane
  /// facing the camera).
  TransformGizmoDrag beginDrag(String handle, Ray ray, {Vector3? cameraPosition}) =>
      TransformGizmoDrag._(this, handle, ray, cameraPosition);

  /// 2D distance from [p] to the segment [a]–[b].
  static double distanceToSegment(Offset p, Offset a, Offset b) {
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    final lenSq = dx * dx + dy * dy;
    if (lenSq <= 0.0001) return (p - a).distance;
    final t = (((p.dx - a.dx) * dx + (p.dy - a.dy) * dy) / lenSq).clamp(0.0, 1.0);
    return (p - Offset(a.dx + t * dx, a.dy + t * dy)).distance;
  }

  /// The per-axis scale range.
  static const double minScale = 0.01;
  static const double maxScale = 100.0;

  static Vector3 clampScale(Vector3 s) => Vector3(
        s.x.clamp(minScale, maxScale),
        s.y.clamp(minScale, maxScale),
        s.z.clamp(minScale, maxScale),
      );
}

/// One drag of a handle: the solvers of [GizmoController] applied against the
/// pivot and ray captured when the drag started, so every update is a delta
/// from the grab point rather than from the previous pointer event.
class TransformGizmoDrag {
  final TransformGizmoModel model;
  final String handle;
  final Vector3 startPivot;
  final Vector3? cameraPosition;

  late final double _startParam;
  late final Vector3 _startHit;

  TransformGizmoDrag._(this.model, this.handle, Ray ray, this.cameraPosition)
      : startPivot = Vector3.copy(model.pivot) {
    switch (model.mode) {
      case GizmoMode.translate:
        if (TransformGizmoModel.axes.contains(handle)) {
          _startParam = GizmoController.solveAxisTranslation(
              ray: ray, axisOrigin: startPivot, axisDirection: model.axisDirection(handle));
          _startHit = Vector3.copy(startPivot);
        } else if (TransformGizmoModel.planes.contains(handle)) {
          _startParam = 0.0;
          _startHit = GizmoController.solvePlaneTranslation(
              ray: ray, planeOrigin: startPivot, planeNormal: model.planeNormal(handle));
        } else {
          _startParam = 0.0;
          _startHit = GizmoController.solvePlaneTranslation(
              ray: ray, planeOrigin: startPivot, planeNormal: _cameraPlaneNormal());
        }
      case GizmoMode.rotate:
        _startParam = 0.0;
        _startHit = GizmoController.solvePlaneTranslation(
            ray: ray, planeOrigin: startPivot, planeNormal: model.axisDirection(_ringAxis));
      case GizmoMode.scale:
        _startParam = GizmoController.solveAxisTranslation(
            ray: ray, axisOrigin: startPivot, axisDirection: _scaleAxis);
        _startHit = Vector3.copy(startPivot);
    }
  }

  String get _ringAxis => TransformGizmoModel.axes.contains(handle) ? handle : TransformGizmoModel.axisZ;

  Vector3 get _scaleAxis => handle == TransformGizmoModel.uniform
      ? Vector3(1, 1, 1).normalized()
      : model.axisDirection(TransformGizmoModel.axes.contains(handle) ? handle : TransformGizmoModel.axisX);

  Vector3 _cameraPlaneNormal() {
    final cam = cameraPosition;
    if (cam == null) return model.axisDirection(TransformGizmoModel.axisZ);
    final n = cam - startPivot;
    return n.length2 < 1e-12 ? model.axisDirection(TransformGizmoModel.axisZ) : n.normalized();
  }

  /// Translate: the world-space offset of the pivot since the grab.
  Vector3 translation(Ray ray) {
    if (TransformGizmoModel.axes.contains(handle)) {
      final dir = model.axisDirection(handle);
      final param = GizmoController.solveAxisTranslation(ray: ray, axisOrigin: startPivot, axisDirection: dir);
      return dir * (param - _startParam);
    }
    final normal = TransformGizmoModel.planes.contains(handle) ? model.planeNormal(handle) : _cameraPlaneNormal();
    final hit = GizmoController.solvePlaneTranslation(ray: ray, planeOrigin: startPivot, planeNormal: normal);
    return hit - _startHit;
  }

  /// The axis the rotate tool turns about (world or local).
  Vector3 get rotationAxis => model.axisDirection(_ringAxis);

  /// Rotate: the angle swept around [rotationAxis] since the grab, in degrees.
  double rotationAngle(Ray ray) => GizmoController.solveRotation(
        ray: ray,
        ringOrigin: startPivot,
        ringNormal: rotationAxis,
        grabPoint: _startHit,
      );

  /// Scale: how far the pointer moved along the stem since the grab, in
  /// world units (the caller decides how much scale a unit is worth).
  double scaleTravel(Ray ray) =>
      GizmoController.solveAxisTranslation(ray: ray, axisOrigin: startPivot, axisDirection: _scaleAxis) - _startParam;
}

/// The toolbar's snap settings as the gizmo applies them:
/// translate quantises the absolute result, rotate and scale the delta.
class TransformGizmoSnap {
  final bool translateEnabled;
  final bool rotateEnabled;
  final bool scaleEnabled;
  final double translateStep;
  final double rotateStep;
  final double scaleStep;

  const TransformGizmoSnap({
    this.translateEnabled = false,
    this.rotateEnabled = false,
    this.scaleEnabled = false,
    this.translateStep = 10.0,
    this.rotateStep = 10.0,
    this.scaleStep = 0.25,
  });

  static const TransformGizmoSnap none = TransformGizmoSnap();

  TransformGizmoSnap copyWith({
    bool? translateEnabled,
    bool? rotateEnabled,
    bool? scaleEnabled,
    double? translateStep,
    double? rotateStep,
    double? scaleStep,
  }) =>
      TransformGizmoSnap(
        translateEnabled: translateEnabled ?? this.translateEnabled,
        rotateEnabled: rotateEnabled ?? this.rotateEnabled,
        scaleEnabled: scaleEnabled ?? this.scaleEnabled,
        translateStep: translateStep ?? this.translateStep,
        rotateStep: rotateStep ?? this.rotateStep,
        scaleStep: scaleStep ?? this.scaleStep,
      );

  Vector3 location(Vector3 v) =>
      translateEnabled ? Vector3.array(SnapService.snapVector([v.x, v.y, v.z], translateStep)) : v;

  double angle(double degrees) => rotateEnabled ? SnapService.snapAngle(degrees, rotateStep) : degrees;

  double scale(double delta) => scaleEnabled ? SnapService.snapValue(delta, scaleStep) : delta;
}

/// Authoring-space (Z-up, degrees) rotation helpers for a gizmo that turns
/// a stored `[x, y, z]` rotation (`LuminaAxes.rotation`) about a world axis.
abstract final class AuthoringRotation {
  static const double _r2d = 180.0 / math.pi;
  static const double _d2r = math.pi / 180.0;

  /// Authoring `(x, y, z)` direction → runtime `(x, z, −y)`.
  static Vector3 toRuntime(Vector3 authoring) => Vector3(authoring.x, authoring.z, -authoring.y);

  /// Runtime `(x, y, z)` direction → authoring `(x, −z, y)`.
  static Vector3 toAuthoring(Vector3 runtime) => Vector3(runtime.x, -runtime.z, runtime.y);

  /// A runtime-frame rotation expressed in the authoring frame (the same
  /// rotation, seen with Z up), so gizmo axes can be built from it.
  static Quaternion quaternionToAuthoring(Quaternion runtime) {
    final m = runtime.asRotationMatrix();
    final cols = [
      for (final axis in [Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)]) toAuthoring(m.transformed(toRuntime(axis))),
    ];
    final out = Matrix3.columns(cols[0], cols[1], cols[2]);
    return Quaternion.fromRotation(out)..normalize();
  }

  /// The inverse of [LuminaAxes.rotation]: authoring degrees `[x, y, z]` of a
  /// runtime-frame [runtime] rotation. A rotation has two Euler solutions;
  /// the one nearer [near] (the values the user sees) is returned, each
  /// angle unwrapped to within 180° of it, so a yaw-ring drag from
  /// `[0, 0, 0]` reads `[0, 0, θ]` rather than `[180, 180, θ − 180]`.
  static List<double> eulerFromRuntime(Quaternion runtime, {List<double>? near}) {
    // LuminaAxes.rotation composes Ry(−z)·Rx(x)·Rz(y) in runtime axes; the
    // solutions below are the angles a, b, c of Ry(c)·Rx(a)·Rz(b), so
    // [x, y, z] = [a, b, −c].
    final m = runtime.asRotationMatrix();
    final sinA = (-m.entry(1, 2)).clamp(-1.0, 1.0);
    final a1 = math.asin(sinA);
    List<double> solve(double a) {
      final ca = math.cos(a);
      double b;
      double c;
      if (ca.abs() > 1e-6) {
        b = math.atan2(m.entry(1, 0), m.entry(1, 1));
        c = math.atan2(m.entry(0, 2), m.entry(2, 2));
        if (ca < 0) {
          // The second solution family: flip the outer angles.
          b = math.atan2(-m.entry(1, 0), -m.entry(1, 1));
          c = math.atan2(-m.entry(0, 2), -m.entry(2, 2));
        }
      } else {
        b = 0.0;
        c = math.atan2(math.sin(a) * m.entry(0, 1), m.entry(0, 0));
      }
      return [a * _r2d, b * _r2d, -c * _r2d];
    }

    final s1 = solve(a1);
    final s2 = solve(math.pi - a1);
    final ref = [for (var i = 0; i < 3; i++) near != null && near.length > i ? near[i] : 0.0];
    List<double> unwrap(List<double> s) => [for (var i = 0; i < 3; i++) s[i] + _nearest(s[i], ref[i])];
    double cost(List<double> s) => [for (var i = 0; i < 3; i++) (s[i] - ref[i]).abs()].reduce((x, y) => x + y);
    final u1 = unwrap(s1);
    final u2 = unwrap(s2);
    final best = cost(u1) <= cost(u2) ? u1 : u2;
    return [for (final v in best) _clean(v)];
  }

  /// The multiple of 360° that brings [angle] within 180° of [reference]
  /// (added to [angle], which is what [eulerFromRuntime] unwraps by).
  static double _nearest(double angle, double reference) => ((reference - angle) / 360.0).roundToDouble() * 360.0;

  static double _clean(double v) {
    final r = (v * 1e6).roundToDouble() / 1e6;
    return r == 0.0 ? 0.0 : r;
  }

  /// [euler] turned by [degrees] about the authoring-frame world [axis]:
  /// `R(axis, θ) · R(euler)`, back in authoring degrees (nearest solution).
  static List<double> rotatedAboutWorldAxis(List<double> euler, Vector3 axis, double degrees) {
    final start = LuminaAxes.rotation(euler);
    final delta = Quaternion.axisAngle(toRuntime(axis).normalized(), degrees * _d2r);
    final result = delta * start;
    return eulerFromRuntime(result..normalize(), near: euler);
  }
}
