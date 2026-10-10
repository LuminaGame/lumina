part of '../blueprint_preview_scene.dart';

/// The component line overlays and the framing they give the orbit camera.
mixin _BlueprintPreviewSceneOverlays on _BlueprintPreviewSceneState {
  /// The line overlays, in runtime space (Y up, cm).
  List<SubEditorLineSet> get overlays => _overlays ??= _buildOverlays();

  List<SubEditorLineSet> _buildOverlays() {
    final doc = _document;
    if (doc == null) return const [];
    final out = <SubEditorLineSet>[];
    for (final c in doc.components) {
      final built = _built[c.id];
      if (built is! LuminaSceneComponent) continue;
      final selected = c.id == _selected;
      final points = <Vector3>[];
      var color = BlueprintPreviewScene.selectionColor;
      switch (c.type) {
        case 'LuminaCapsuleComponent':
          if (built is LuminaCapsuleComponent) points.addAll(built.buildCapsuleWireframe(segments: 24));
          color = BlueprintPreviewScene.capsuleColor;
        case 'LuminaSpringArmComponent':
          if (built is LuminaSpringArmComponent) points.addAll(_springArm(built));
          color = BlueprintPreviewScene.springArmColor;
        case 'LuminaCameraComponent':
          if (built is LuminaCameraComponent) points.addAll(_cameraFrustum(built));
          color = BlueprintPreviewScene.cameraColor;
        case 'LuminaArrowComponent':
          final size = (c.properties['arrowSize'] as num?)?.toDouble() ?? 1.0;
          points.addAll(_arrow(built, 80.0 * size));
          color = _hexColor(c.properties['arrowColor']) ?? (0.0, 0.53, 1.0);
        case 'LuminaSpotLightComponent':
          if (built is LuminaSpotLightComponent) points.addAll(built.buildConeWireframe(segments: 24));
          color = BlueprintPreviewScene.spotLightColor;
        case 'LuminaPointLightComponent':
          if (built is LuminaPointLightComponent) points.addAll(built.buildSphereWireframe(segments: 24));
          color = BlueprintPreviewScene.pointLightColor;
        case 'LuminaDirectionalLightComponent':
          if (built is LuminaDirectionalLightComponent) points.addAll(built.buildArrowWireframe());
          color = BlueprintPreviewScene.spotLightColor;
        case 'LuminaStaticMeshComponent':
        case 'LuminaSkeletalMeshComponent':
        case 'LuminaAnimatedMeshComponent':
          // Selection only: the mesh itself is what is drawn.
          if (selected && built is LuminaStaticMeshComponent) points.addAll(_bounds(built));
        default:
          if (BlueprintPreviewScene.shapeTypes.contains(c.type) && built is LuminaCollisionComponent) {
            // Box, sphere, cylinder, cone and convex hull
            // wireframes from lumina's shapes (scaled by the transform).
            points.addAll(built.buildWireframe(segments: 24));
            color = BlueprintPreviewScene.capsuleColor;
          } else if (selected) {
            points.addAll(_tripod(built, 30.0));
          }
      }
      // The selected simulating component's centre of mass.
      if (selected && built is LuminaPrimitivePhysics && built.simulatePhysics) {
        final com = BlueprintPreviewScene.centerOfMassOf(built);
        final (r, g, b) = BlueprintPreviewScene.centerOfMassColor;
        out.add(SubEditorLineSet(
          id: '${c.id}.com',
          positions: [for (final p in _cross(com, 12.0)) ...[p.x, p.y, p.z]],
          indices: List<int>.generate(6, (i) => i),
          r: r,
          g: g,
          b: b,
          selected: false,
          xray: true,
          signature: '${c.id}.com|$_revision|${com.x},${com.y},${com.z}',
        ));
      }
      if (points.isEmpty) continue;
      final (r, g, b) = selected ? BlueprintPreviewScene.selectionColor : color;
      out.add(SubEditorLineSet(
        id: c.id,
        positions: [for (final p in points) ...[p.x, p.y, p.z]],
        indices: List<int>.generate(points.length - points.length % 2, (i) => i),
        r: r,
        g: g,
        b: b,
        selected: selected,
        xray: selected,
        signature: '${c.id}|$selected|$_revision',
      ));
    }
    return out;
  }

  /// Where the viewport's orbit camera starts (runtime space, cm): centred
  /// on the actor's body — its capsule and meshes, framing a Blueprint by
  /// its primitives — from twice the distance that fits them in
  /// the 45° view, which leaves the boom and the camera behind it in frame.
  ({Vector3 target, double distance}) get framing {
    List<Vector3> pointsOf(Iterable<SubEditorLineSet> sets) => [
          for (final set in sets)
            for (var i = 0; i + 2 < set.positions.length; i += 3)
              Vector3(set.positions[i], set.positions[i + 1], set.positions[i + 2]),
        ];
    final capsules = {
      for (final c in _document?.components ?? const <LuminaBlueprintComponent>[])
        if (c.type == 'LuminaCapsuleComponent' || BlueprintPreviewScene.shapeTypes.contains(c.type)) c.id,
    };
    final points = [
      ...pointsOf(overlays.where((s) => capsules.contains(s.id))),
      for (final mesh in _built.values.whereType<LuminaStaticMeshComponent>()) ..._bounds(mesh),
    ];
    if (points.isEmpty) points.addAll(pointsOf(overlays));
    if (points.isEmpty) return (target: Vector3.zero(), distance: 400.0);
    final lo = Vector3.copy(points.first);
    final hi = Vector3.copy(points.first);
    for (final p in points) {
      Vector3.min(lo, p, lo);
      Vector3.max(hi, p, hi);
    }
    final radius = math.max((hi - lo).length / 2, 60.0);
    return (target: (lo + hi) * 0.5, distance: radius / math.sin(22.5 * math.pi / 180.0) * 2.0);
  }
}
