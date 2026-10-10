part of '../blueprint_preview_scene.dart';

/// Picking a component under a viewport ray.
mixin _BlueprintPreviewScenePicking on _BlueprintPreviewSceneState {
  /// The scene component under [ray] (runtime frame): the nearest hit among
  /// the components' bounding boxes — a capsule's, boom's, camera's or
  /// arrow's drawn lines, a mesh's bounds — or null. Boxes thinner than
  /// [pickPadding] (a boom is a line) are padded so they can be hit.
  String? pick(ViewportRay ray) {
    final doc = _document;
    if (doc == null) return null;
    String? best;
    var bestT = double.infinity;
    var bestVolume = double.infinity;
    for (final c in doc.components) {
      final built = _built[c.id];
      if (built is! LuminaSceneComponent) continue;
      final box = _pickBox(c, built);
      if (box == null) continue;
      final t = _rayBox(ray, box.$1, box.$2);
      if (t == null) continue;
      final volume = (box.$2 - box.$1).x * (box.$2 - box.$1).y * (box.$2 - box.$1).z;
      // A smaller box wins a near tie: the mesh sits inside the capsule.
      final better = t < bestT - BlueprintPreviewScene.pickPadding || ((t - bestT).abs() <= BlueprintPreviewScene.pickPadding && volume < bestVolume);
      if (better) {
        best = c.id;
        bestT = t;
        bestVolume = volume;
      }
    }
    return best;
  }

  (Vector3, Vector3)? _pickBox(LuminaBlueprintComponent c, LuminaSceneComponent built) {
    final points = <Vector3>[];
    switch (c.type) {
      case 'LuminaCapsuleComponent':
        if (built is LuminaCapsuleComponent) points.addAll(built.buildCapsuleWireframe(segments: 12));
      case 'LuminaSpringArmComponent':
        if (built is LuminaSpringArmComponent) points.addAll(_springArm(built));
      case 'LuminaCameraComponent':
        if (built is LuminaCameraComponent) points.addAll(_cameraFrustum(built));
      case 'LuminaArrowComponent':
        final size = (c.properties['arrowSize'] as num?)?.toDouble() ?? 1.0;
        points.addAll(_arrow(built, 80.0 * size));
      case 'LuminaSpotLightComponent':
        if (built is LuminaSpotLightComponent) points.addAll(built.buildConeWireframe(segments: 12));
      case 'LuminaPointLightComponent':
        if (built is LuminaPointLightComponent) points.addAll(built.buildSphereWireframe(segments: 12));
      case 'LuminaDirectionalLightComponent':
        if (built is LuminaDirectionalLightComponent) points.addAll(built.buildArrowWireframe());
      case 'LuminaStaticMeshComponent':
      case 'LuminaSkeletalMeshComponent':
      case 'LuminaAnimatedMeshComponent':
        if (built is LuminaStaticMeshComponent) points.addAll(_bounds(built));
        if (points.isEmpty) points.addAll(_tripod(built, 40.0));
      default:
        if (BlueprintPreviewScene.shapeTypes.contains(c.type) && built is LuminaCollisionComponent) {
          points.addAll(built.buildWireframe(segments: 12));
        } else {
          points.addAll(_tripod(built, 30.0));
        }
    }
    if (points.isEmpty) return null;
    final lo = Vector3.copy(points.first);
    final hi = Vector3.copy(points.first);
    for (final p in points) {
      Vector3.min(lo, p, lo);
      Vector3.max(hi, p, hi);
    }
    for (var i = 0; i < 3; i++) {
      if (hi[i] - lo[i] < BlueprintPreviewScene.pickPadding * 2) {
        lo[i] -= BlueprintPreviewScene.pickPadding;
        hi[i] += BlueprintPreviewScene.pickPadding;
      }
    }
    return (lo, hi);
  }

  /// Slab test: the ray parameter where it enters the box, or null.
  static double? _rayBox(ViewportRay ray, Vector3 lo, Vector3 hi) {
    var tMin = 0.0;
    var tMax = double.infinity;
    for (var i = 0; i < 3; i++) {
      final o = ray.origin[i];
      final d = ray.direction[i];
      if (d.abs() < 1e-9) {
        if (o < lo[i] || o > hi[i]) return null;
        continue;
      }
      var t1 = (lo[i] - o) / d;
      var t2 = (hi[i] - o) / d;
      if (t1 > t2) {
        final tmp = t1;
        t1 = t2;
        t2 = tmp;
      }
      if (t1 > tMin) tMin = t1;
      if (t2 < tMax) tMax = t2;
      if (tMin > tMax) return null;
    }
    return tMin;
  }
}
