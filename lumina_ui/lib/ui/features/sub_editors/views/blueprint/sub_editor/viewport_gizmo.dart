part of '../blueprint_sub_editor.dart';

/// Components viewport: the preview viewport and the transform gizmo drag
/// that writes component location/rotation/scale.
mixin _BlueprintSubEditorViewportGizmo on _BlueprintSubEditorStateBase {

  @override
  void _onGizmoDragBegin(String id) {
    final c = _viewModel.getComponent(id);
    final t = _viewModel.preview.sceneTransformFor(id);
    if (c == null || t == null) return;
    _gizmoDragStart = (
      location: BlueprintSubEditorState._vec(c.properties['location'], 0.0),
      rotation: BlueprintSubEditorState._vec(c.properties['rotation'], 0.0),
      scale: BlueprintSubEditorState._vec(c.properties['scale'], 1.0),
      parentRotation: t.parentRotation,
      worldRotation: t.worldRotation,
    );
    _viewModel.beginComponentTransformDrag(id);
  }

  /// A world-space delta (authoring frame) becomes a change of the
  /// component's **relative** transform: solved in the world, converted into
  /// the parent's space, then written as the Details panel shows it.
  @override
  void _onGizmoDragUpdate(String id, SubEditorGizmoDelta delta) {
    final start = _gizmoDragStart;
    if (start == null) return;
    final snap = _gizmo.snap;
    if (delta.translation != null) {
      final worldRuntime = AuthoringRotation.toRuntime(delta.translation!);
      final relRuntime = start.parentRotation.unrotateVector(worldRuntime);
      final rel = AuthoringRotation.toAuthoring(relRuntime);
      final raw = Vector3(start.location[0] + rel.x, start.location[1] + rel.y, start.location[2] + rel.z);
      final snapped = snap.location(raw);
      _viewModel.updateComponentTransform(id, location: [snapped.x, snapped.y, snapped.z]);
    } else if (delta.rotationAxis != null) {
      // R_world' = Δ · R_world, R_rel' = R_parent⁻¹ · R_world'.
      final deltaQ = Quaternion.axisAngle(
        AuthoringRotation.toRuntime(delta.rotationAxis!).normalized(),
        (delta.rotationDegrees ?? 0.0) * math.pi / 180.0,
      );
      final newWorld = deltaQ * start.worldRotation;
      final newRel = start.parentRotation.conjugated() * newWorld;
      final euler = AuthoringRotation.eulerFromRuntime(newRel..normalize(), near: start.rotation);
      _viewModel.updateComponentTransform(id, rotation: euler);
    } else if (delta.scaleHandle != null) {
      final amount = delta.scaleDelta ?? 0.0;
      final s = Vector3.array(start.scale);
      final handle = delta.scaleHandle!;
      if (handle == TransformGizmoModel.uniform || handle == TransformGizmoModel.axisX) s.x += amount;
      if (handle == TransformGizmoModel.uniform || handle == TransformGizmoModel.axisY) s.y += amount;
      if (handle == TransformGizmoModel.uniform || handle == TransformGizmoModel.axisZ) s.z += amount;
      final clamped = TransformGizmoModel.clampScale(s);
      _viewModel.updateComponentTransform(id, scale: [clamped.x, clamped.y, clamped.z]);
    }
  }

  /// The gizmo's target for the selected scene component: its world
  /// transform from the preview's built actor, in the authoring frame.
  SubEditorGizmoTarget? _gizmoTargetFor(String? id) {
    if (id == null) return null;
    final c = _viewModel.getComponent(id);
    if (c == null || !c.isSceneComponent) return null;
    final t = _viewModel.preview.sceneTransformFor(id);
    if (t == null) return null;
    final loc = LuminaAxes.toAuthoringLocation(t.worldLocation);
    return SubEditorGizmoTarget(
      id: id,
      pivot: Vector3(loc[0], loc[1], loc[2]),
      rotation: AuthoringRotation.quaternionToAuthoring(t.worldRotation),
      locked: !_viewModel.canTransformComponent(id),
      lockedHint: 'Root component transform is fixed',
    );
  }

  /// The 3D Viewport: the Blueprint's actor as Play builds it —
  /// its meshes, capsule, spring arm and camera, the selected component
  /// highlighted — framed from in front, the actor facing the camera.
  @override
  Widget _buildPreviewViewport() {
    final preview = _viewModel.preview;
    if (!widget.showPreviewViewport) {
      if (!preview.isAttached) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !preview.isAttached) _viewModel.startHeadlessPreview();
        });
      }
      return Container(
        key: const ValueKey('bp_preview_text'),
        color: EditorColors.graphCanvas,
        alignment: Alignment.center,
        child: Text('Preview (no renderer): ${preview.summary}',
            style: const TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
      );
    }
    final framing = preview.framing;
    // Set from the build that shows it: the viewport is rebuilt with it in
    // the same frame (it never calls setState from this notification during
    // a build).
    _gizmo.setTarget(_gizmoTargetFor(_viewModel.selectedComponentId));
    return SubEditor3DViewport(
      key: const ValueKey('bp_preview_viewport'),
      transformGizmo: _gizmo,
      title: 'Blueprint Actor 3D Preview Viewport',
      showShapeSelector: false,
      yUpCamera: true,
      // In front of the actor (it faces −Z), a little to its right.
      initialCameraYaw: 145.0,
      initialCameraDistance: framing.distance,
      initialCameraTarget: framing.target,
      gridExtent: 1000.0,
      gridStep: 50.0,
      overlayLines: preview.overlays,
      statsLabel: preview.summary,
      hasSceneLights: preview.hasSceneLights,
      renderSceneLights: preview.renderSceneLights,
      onToggleSceneLights: (v) => _viewModel.setRenderSceneLights(v),
      onPreviewWorldReady: _viewModel.attachPreviewWorld,
      onPreviewWorldDisposing: _viewModel.detachPreviewWorld,
    );
  }
}
