part of '../sub_editor_3d_viewport.dart';

/// Transform gizmo: Y-up eye/target and authoring-ray
/// math, hover, drag, click and key handling, the drag banner and the gizmo
/// tool cluster.
mixin _SubEditor3DViewportGizmo on _SubEditor3DViewportStateBase {
  SubEditorTransformGizmo? _internalGizmo;

  SubEditorTransformGizmo? get _effectiveGizmo {
    if (widget.transformGizmo != null) return widget.transformGizmo;
    final show = widget.showTransformGizmo ?? (!widget.showShapeSelector && (widget.glbMesh != null || widget.meshComponents != null || widget.onPreviewWorldReady != null));
    if (show) {
      return _internalGizmo ??= SubEditorTransformGizmo();
    }
    return null;
  }

  void _initGizmo() {
    _effectiveGizmo?.addListener(_onGizmoChanged);
  }

  void _updateGizmo(SubEditor3DViewport oldWidget) {
    final oldGizmo = oldWidget.transformGizmo ?? _internalGizmo;
    final newGizmo = _effectiveGizmo;
    if (newGizmo != oldGizmo) {
      oldGizmo?.removeListener(_onGizmoChanged);
      newGizmo?.addListener(_onGizmoChanged);
    }
  }

  void _disposeGizmo() {
    _effectiveGizmo?.removeListener(_onGizmoChanged);
    _internalGizmo?.dispose();
    _internalGizmo = null;
  }

  void _onGizmoChanged() {
    if (!mounted) return;
    // A target set from the owner's build arrives while this widget is being
    // rebuilt with it anyway; setState is only for changes made between
    // frames (a tool button, a key).
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) return;
    setState(_syncGizmoState);
  }

  /// Drops a drag whose target went away (deleted, deselected) and the hover
  /// without a target.
  void _syncGizmoState() {
    final target = _effectiveGizmo?.target;
    if (_gizmoDragging && (target == null || target.id != _gizmoDragTarget?.id)) {
      _gizmoDrag = null;
      _gizmoDragHandle = null;
      _gizmoDragTarget = null;
      _gizmoDragLocked = false;
      _gizmoBanner = null;
    }
    if (target == null) _gizmoHover = null;
  }

  /// The Y-up orbit camera's eye, runtime frame (see [viewportRay]).
  Vector3 _yUpEye() {
    final yaw = _cameraYaw * math.pi / 180.0;
    final pitch = _cameraPitch.clamp(-89.0, 89.0) * math.pi / 180.0;
    final target = _yUpTarget();
    return Vector3(
      target.x + _cameraDistance * math.cos(pitch) * math.sin(yaw),
      target.y + _cameraDistance * math.sin(pitch),
      target.z + _cameraDistance * math.cos(pitch) * math.cos(yaw),
    );
  }

  @override
  Vector3 _yUpTarget() => Vector3(
        _cameraPan.dx + _targetCenterX,
        _cameraPan.dy + _targetCenterY,
        _targetCenterZ,
      );

  /// The pointer's camera ray in the authoring frame (Z up), the frame the
  /// gizmo model works in; the Z-up → Y-up swizzle stays in [_gizmoProject]
  /// and here.
  Ray? _authoringRay(Offset local) {
    final r = _brushRay(local);
    if (r == null) return null;
    return Ray.originDirection(
      AuthoringRotation.toAuthoring(r.origin),
      AuthoringRotation.toAuthoring(r.direction),
    );
  }

  Offset? _gizmoProject(Vector3 authoringPoint) => projectWorldToViewport(
        worldPos: LuminaAxes.location([authoringPoint.x, authoringPoint.y, authoringPoint.z]),
        size: _viewportSize,
        yawDeg: _cameraYaw,
        pitchDeg: _cameraPitch,
        distance: _cameraDistance,
        target: _yUpTarget(),
      );

  /// The gizmo as drawn and hit-tested this frame, or null without a target.
  TransformGizmoModel? _transformGizmoModel() {
    final gizmo = _effectiveGizmo;
    final target = gizmo?.target;
    if (gizmo == null || target == null) return null;
    if (_viewportSize.width <= 0 || _viewportSize.height <= 0) return null;
    // Screen-constant size: the world length that spans [_gizmoScreenPixels]
    // at the pivot's depth, for the camera's 45° vertical field of view.
    final eye = _yUpEye();
    final depth = (LuminaAxes.location([target.pivot.x, target.pivot.y, target.pivot.z]) - eye).length;
    final worldPerPixel = depth * 2.0 * math.tan(45.0 * math.pi / 360.0) / _viewportSize.height;
    final axisLength = math.max(worldPerPixel * _SubEditor3DViewportState._gizmoScreenPixels, 1e-3);
    return TransformGizmoModel(
      mode: gizmo.mode,
      space: gizmo.space,
      pivot: target.pivot,
      rotation: target.rotation,
      axisLength: axisLength,
      planeOffset: axisLength * 0.34,
      project: _gizmoProject,
    );
  }

  /// Where each gizmo handle is on screen, so a test points at a handle the
  /// way a user does.
  @visibleForTesting
  Map<String, Offset>? gizmoHandleScreenPositionsForTest(Size viewportSize) {
    _viewportSize = viewportSize;
    return _transformGizmoModel()?.handleScreenPositions();
  }

  /// The gizmo as hit-tested for [viewportSize], so a test can find a ring
  /// point the way the painter draws it.
  @visibleForTesting
  TransformGizmoModel? transformGizmoModelForTest(Size viewportSize) {
    _viewportSize = viewportSize;
    return _transformGizmoModel();
  }

  /// The gizmo handle under the pointer, or null.
  @visibleForTesting
  String? get hoveredGizmoHandleForTest => _gizmoHover;

  /// The live delta banner's text, or null when idle.
  @visibleForTesting
  String? get gizmoBannerForTest => _gizmoBanner;

  bool get _gizmoDragging => _gizmoDrag != null || _gizmoDragLocked;

  void _handleGizmoHover(Offset local) {
    if (_gizmoDragging) return;
    final model = _transformGizmoModel();
    final hover = model?.hitTest(local);
    if (hover != _gizmoHover) setState(() => _gizmoHover = hover);
  }

  /// A primary press on a handle starts a drag; returns false when the press
  /// hit no handle (the camera or a pick gets it).
  bool _beginGizmoDrag(Offset local) {
    final gizmo = _effectiveGizmo;
    final target = gizmo?.target;
    if (gizmo == null || target == null) return false;
    final model = _transformGizmoModel();
    if (model == null) return false;
    final handle = _gizmoHover ?? model.hitTest(local);
    if (handle == null) return false;
    if (target.locked) {
      setState(() {
        _gizmoDragLocked = true;
        _gizmoDragTarget = target;
        _gizmoHover = handle;
        _gizmoBanner = target.lockedHint;
      });
      return true;
    }
    final ray = _authoringRay(local);
    if (ray == null) return false;
    final eye = AuthoringRotation.toAuthoring(_yUpEye());
    setState(() {
      _gizmoDrag = model.beginDrag(handle, ray, cameraPosition: eye);
      _gizmoDragHandle = handle;
      _gizmoDragTarget = target;
      _gizmoHover = handle;
      _gizmoBanner = _bannerFor(gizmo.mode, handle, translation: Vector3.zero(), degrees: 0.0, scaleDelta: 0.0);
    });
    gizmo.onDragBegin?.call(target.id);
    return true;
  }

  void _updateGizmoDrag(Offset local) {
    final gizmo = _effectiveGizmo;
    final drag = _gizmoDrag;
    final target = _gizmoDragTarget;
    if (gizmo == null || drag == null || target == null) return;
    final ray = _authoringRay(local);
    if (ray == null) return;
    final handle = _gizmoDragHandle!;
    final SubEditorGizmoDelta delta;
    final String banner;
    switch (gizmo.mode) {
      case GizmoMode.translate:
        final t = drag.translation(ray);
        delta = SubEditorGizmoDelta.translate(t);
        banner = _bannerFor(gizmo.mode, handle, translation: t);
      case GizmoMode.rotate:
        final degrees = gizmo.snap.angle(drag.rotationAngle(ray));
        delta = SubEditorGizmoDelta.rotate(drag.rotationAxis, degrees);
        banner = _bannerFor(gizmo.mode, handle, degrees: degrees);
      case GizmoMode.scale:
        // One arrow length of travel is one unit of scale.
        final amount = gizmo.snap.scale(drag.scaleTravel(ray) / drag.model.axisLength);
        delta = SubEditorGizmoDelta.scale(handle, amount);
        banner = _bannerFor(gizmo.mode, handle, scaleDelta: amount);
    }
    setState(() => _gizmoBanner = banner);
    gizmo.onDragUpdate?.call(target.id, delta);
  }

  void _endGizmoDrag() {
    final gizmo = _effectiveGizmo;
    final target = _gizmoDragTarget;
    final wasDrag = _gizmoDrag != null;
    setState(() {
      _gizmoDrag = null;
      _gizmoDragHandle = null;
      _gizmoDragTarget = null;
      _gizmoDragLocked = false;
      _gizmoBanner = null;
    });
    if (wasDrag && target != null) gizmo?.onDragEnd?.call(target.id);
  }

  void _cancelGizmoDrag() {
    final gizmo = _effectiveGizmo;
    final target = _gizmoDragTarget;
    final wasDrag = _gizmoDrag != null;
    setState(() {
      _gizmoDrag = null;
      _gizmoDragHandle = null;
      _gizmoDragTarget = null;
      _gizmoDragLocked = false;
      _gizmoBanner = null;
    });
    if (wasDrag && target != null) gizmo?.onDragCancel?.call(target.id);
  }

  /// Hit-tests projected screen positions of bone joints within [maxDistance] pixels.
  String? _hitTestBone(Offset localPos, {double maxDistance = 22.0}) {
    final mesh = widget.glbMesh;
    if (mesh == null || !widget.showBones) return null;
    final positions = computeSkeletonBonePositions(
      glbMesh: mesh,
      jointLocalPose: widget.jointLocalPose,
      jointDeltas: widget.jointDeltas,
    );
    final minX = mesh.minBounds[0];
    final minY = mesh.minBounds[1];
    final minZ = mesh.minBounds[2];
    final maxX = mesh.maxBounds[0];
    final maxY = mesh.maxBounds[1];
    final maxZ = mesh.maxBounds[2];
    final cx = (minX + maxX) / 2.0;
    final cy = (minY + maxY) / 2.0;
    final cz = (minZ + maxZ) / 2.0;
    final spanY = (maxY - minY).abs();
    final spanZ = (maxZ - minZ).abs();
    final bool isZUp = (spanZ >= spanY);

    final visibleLower = widget.visibleBoneNames?.map((n) => n.toLowerCase()).toSet();
    String? bestBone;
    double bestDist = maxDistance;

    for (final entry in positions.entries) {
      if (visibleLower != null && !visibleLower.contains(entry.key.toLowerCase())) {
        continue;
      }
      final p = entry.value;
      final target = Vector3(cx + _cameraPan.dx, cy + _cameraPan.dy, cz);
      final proj = projectWorldToViewport(
        worldPos: p,
        size: _viewportSize,
        yawDeg: _cameraYaw,
        pitchDeg: _cameraPitch,
        distance: _cameraDistance,
        target: target,
        isZUp: isZUp,
      );
      if (proj != null) {
        final dist = (proj - localPos).distance;
        if (dist < bestDist) {
          bestDist = dist;
          bestBone = entry.key;
        }
      }
    }
    return bestBone;
  }

  /// A click that hit no handle: pick through the gizmo's owner.
  void _handleGizmoClick(Offset local) {
    if (widget.showBones) {
      final hitBone = _hitTestBone(local);
      if (hitBone != null) {
        widget.onBoneSelected?.call(hitBone);
        return;
      }
    }
    final gizmo = _effectiveGizmo;
    if (gizmo == null || gizmo.pick == null) return;
    final ray = _brushRay(local);
    if (ray == null) return;
    gizmo.onPick?.call(gizmo.pick!(ray));
  }

  String _bannerFor(GizmoMode mode, String handle, {Vector3? translation, double? degrees, double? scaleDelta}) {
    String signed(double v, int digits) => '${v >= 0 ? '+' : '−'}${v.abs().toStringAsFixed(digits)}';
    switch (mode) {
      case GizmoMode.translate:
        final t = translation ?? Vector3.zero();
        if (TransformGizmoModel.axes.contains(handle)) {
          final v = handle == TransformGizmoModel.axisX ? t.x : (handle == TransformGizmoModel.axisY ? t.y : t.z);
          return 'Δ$handle ${signed(v, 1)} cm';
        }
        return 'ΔX ${signed(t.x, 1)}  ΔY ${signed(t.y, 1)}  ΔZ ${signed(t.z, 1)} cm';
      case GizmoMode.rotate:
        final name = switch (handle) {
          TransformGizmoModel.axisX => 'Pitch',
          TransformGizmoModel.axisY => 'Roll',
          _ => 'Yaw',
        };
        return 'Δ $name ${signed(degrees ?? 0.0, 1)}°';
      case GizmoMode.scale:
        final label = handle == TransformGizmoModel.uniform ? '' : '$handle ';
        return '$label×${(1.0 + (scaleDelta ?? 0.0)).toStringAsFixed(2)}';
    }
  }

  /// Q/W/E/R for the gizmo's tools, Esc to cancel a drag; false when the
  /// key is not the gizmo's.
  bool _handleGizmoKey(KeyEvent event) {
    final gizmo = _effectiveGizmo;
    if (gizmo == null) return false;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (!_gizmoDragging) return false;
      _cancelGizmoDrag();
      return true;
    }
    // WASD flies the camera while the right button is held.
    if (_isDragging && (_tapDownButtons & kSecondaryMouseButton) != 0) return false;
    final mode = switch (event.logicalKey) {
      LogicalKeyboardKey.keyQ || LogicalKeyboardKey.keyW => GizmoMode.translate,
      LogicalKeyboardKey.keyE => GizmoMode.rotate,
      LogicalKeyboardKey.keyR => GizmoMode.scale,
      _ => null,
    };
    if (mode == null) return false;
    gizmo.setMode(mode);
    return true;
  }

  Widget _gizmoToolCluster(SubEditorTransformGizmo gizmo) =>
      TransformGizmoToolbar(gizmo: gizmo);
}
