part of '../viewport_widget.dart';

/// Pointer input: click and marquee selection, gizmo hover/drag,
/// asset drops and the projection helpers they use.
mixin _ViewportPointerInteraction on _ViewportWidgetStateBase {

  /// The live transform gizmo, so smoke tests can assert which mode is on
  /// screen and which handle is highlighted.
  FilamentTransformGizmo? get nativeGizmoForTest => _nativeGizmo;

  /// The gizmo handle the pointer is currently over, or null.
  String? get hoveredGizmoAxisForTest => _hoveredGizmoAxis;

  void _applyMarqueeSelection(Size viewportSize) {
    if (_marqueeStart == null || _marqueeCurrent == null) return;

    final rect = Rect.fromPoints(_marqueeStart!, _marqueeCurrent!);

    final camera = _CameraMatrix(
      viewportSize: viewportSize,
      yawDeg: widget.viewModel.cameraYaw,
      pitchDeg: widget.viewModel.cameraPitch,
      dist: widget.viewModel.cameraDistance,
      panX: widget.viewModel.cameraPanX,
      panY: widget.viewModel.cameraPanY,
      panZ: widget.viewModel.cameraPanZ,
    );

    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    final isShift =
        keys.contains(LogicalKeyboardKey.shiftLeft) ||
        keys.contains(LogicalKeyboardKey.shiftRight);

    final selectedInRect = <String>[];

    for (final actor in widget.viewModel.actors) {
      if (!widget.viewModel.isViewportRepresented(actor.id) ||
          !widget.viewModel.isEffectivelyVisible(actor.id) ||
          widget.viewModel.isEffectivelyLocked(actor.id)) {
        continue;
      }

      // Compute 2D projected AABB
      final box = ViewportPicker.editorSpaceBounds(actor);
      if (box != null) {
        final lo = box.min;
        final hi = box.max;

        final corners = [
          [lo.x, lo.y, lo.z],
          [hi.x, lo.y, lo.z],
          [lo.x, hi.y, lo.z],
          [hi.x, hi.y, lo.z],
          [lo.x, lo.y, hi.z],
          [hi.x, lo.y, hi.z],
          [lo.x, hi.y, hi.z],
          [hi.x, hi.y, hi.z],
        ];

        double? minX, minY, maxX, maxY;
        bool anyValid = false;

        for (final corner in corners) {
          final p2d = camera.project(corner[0], corner[1], corner[2]);
          if (p2d != null) {
            anyValid = true;
            if (minX == null || p2d.dx < minX) minX = p2d.dx;
            if (minY == null || p2d.dy < minY) minY = p2d.dy;
            if (maxX == null || p2d.dx > maxX) maxX = p2d.dx;
            if (maxY == null || p2d.dy > maxY) maxY = p2d.dy;
          }
        }

        if (anyValid &&
            minX != null &&
            minY != null &&
            maxX != null &&
            maxY != null) {
          final actorRect = Rect.fromLTRB(minX, minY, maxX, maxY);
          if (rect.overlaps(actorRect)) {
            selectedInRect.add(actor.id);
          }
        }
      } else {
        final p2d = camera.project(
          actor.location[0],
          actor.location[1],
          actor.location[2],
        );
        if (p2d != null) {
          final actorRect = Rect.fromCircle(center: p2d, radius: 40);
          if (rect.overlaps(actorRect)) {
            selectedInRect.add(actor.id);
          }
        }
      }
    }

    if (isShift) {
      widget.viewModel.selectActors(selectedInRect);
    } else {
      widget.viewModel.clearSelection();
      widget.viewModel.selectActors(selectedInRect);
    }
  }

  void _handleViewportClick(Offset clickPos, Size viewportSize) {
    final camera = _CameraMatrix(
      viewportSize: viewportSize,
      yawDeg: widget.viewModel.cameraYaw,
      pitchDeg: widget.viewModel.cameraPitch,
      dist: widget.viewModel.cameraDistance,
      panX: widget.viewModel.cameraPanX,
      panY: widget.viewModel.cameraPanY,
      panZ: widget.viewModel.cameraPanZ,
    );

    final origin = [camera.camX, camera.camY, camera.camZ];
    final direction = camera.getWorldRayDirection(clickPos);

    final ray = Ray.originDirection(
      Vector3.array(origin),
      Vector3.array(direction),
    );
    final picker = ViewportPicker();
    final hits = picker.pickActors(widget.viewModel.actors, ray, null);

    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    final isMulti =
        keys.contains(LogicalKeyboardKey.controlLeft) ||
        keys.contains(LogicalKeyboardKey.controlRight) ||
        keys.contains(LogicalKeyboardKey.metaLeft) ||
        keys.contains(LogicalKeyboardKey.metaRight);

    if (hits.isNotEmpty) {
      final clickedId = hits.first.actor.id;
      if (isMulti) {
        widget.viewModel.toggleActorSelection(clickedId);
      } else {
        widget.viewModel.clearSelection();
        widget.viewModel.selectActors([clickedId]);
      }
    } else {
      if (!isMulti) {
        widget.viewModel.clearSelection();
      }
    }
  }

  /// Where each gizmo handle is drawn on screen, in viewport-local pixels, or
  /// null when there is no gizmo to hit.
  ///
  /// Hover hit-testing and the tests both read this, so what the user points
  /// at and what the editor thinks they pointed at cannot drift apart. The
  /// positions follow the gizmo's live scale, which changes with the camera.
  Map<String, Offset>? _gizmoHandleScreenPositions(Size viewportSize) =>
      _levelGizmoModel(viewportSize)?.handleScreenPositions();

  @override
  _CameraMatrix _overlayCamera(Size viewportSize) => _CameraMatrix(
        viewportSize: viewportSize,
        yawDeg: widget.viewModel.cameraYaw,
        pitchDeg: widget.viewModel.cameraPitch,
        dist: widget.viewModel.cameraDistance,
        panX: widget.viewModel.cameraPanX,
        panY: widget.viewModel.cameraPanY,
        panZ: widget.viewModel.cameraPanZ,
      );

  /// The selected actor's manipulator as the shared [TransformGizmoModel]
  /// (the Blueprint viewport draws the same model): the tool's mode, the
  /// Local/World space, the actor's pivot and rotation, and the native
  /// gizmo's live size. The native manipulator is never rotated, so its
  /// handles stay along the world axes whatever the space.
  TransformGizmoModel? _levelGizmoModel(Size viewportSize) {
    final selected = widget.viewModel.selectedActor;
    if (selected == null) return null;
    final camera = _overlayCamera(viewportSize);
    final rot = selected.rotation;
    return TransformGizmoModel(
      mode: switch (widget.viewModel.activeTool) {
        'rotate' => GizmoMode.rotate,
        'scale' => GizmoMode.scale,
        _ => GizmoMode.translate,
      },
      space: widget.viewModel.gizmoSpace == 'local' ? GizmoSpace.local : GizmoSpace.world,
      pivot: Vector3.array(selected.location),
      rotation: Quaternion.euler(rot[2] * math.pi / 180, rot[1] * math.pi / 180, rot[0] * math.pi / 180),
      axisLength: _ViewportWidgetState._gizmoAxisLen * _gizmoScale,
      planeOffset: _ViewportWidgetState._gizmoPlaneDist * _gizmoScale,
      orientHandles: false,
      project: (p) => camera.project(p.x, p.y, p.z),
    );
  }

  /// Projects an editor-space point through the **native camera's own**
  /// matrices, which is by definition where Filament draws it. Used to check
  /// the overlay projection against the renderer.
  @visibleForTesting
  Offset? nativeProjectForTest(
    double wx,
    double wy,
    double wz,
    Size viewportSize,
  ) {
    final cam = _nativeCamera;
    if (cam == null) return null;
    final vp = cam.projectionMatrix * cam.viewMatrix;
    // Editor space is Z-up; Filament is Y-up: (x, y, z) -> (x, z, -y).
    final v = vp.transform(Vector4(wx, wz, -wy, 1.0));
    if (v.w <= 0) return null;
    final ndcX = v.x / v.w;
    final ndcY = v.y / v.w;
    return Offset(
      viewportSize.width / 2 + ndcX * viewportSize.width / 2,
      viewportSize.height / 2 - ndcY * viewportSize.height / 2,
    );
  }

  /// Where the overlay (actor labels and icons, picking, the gizmo) puts an
  /// editor-space point: the same [_CameraMatrix] the painter builds.
  @visibleForTesting
  Offset? overlayProjectForTest(double wx, double wy, double wz, Size viewportSize) => _CameraMatrix(
        viewportSize: viewportSize,
        yawDeg: widget.viewModel.cameraYaw,
        pitchDeg: widget.viewModel.cameraPitch,
        dist: widget.viewModel.cameraDistance,
        panX: widget.viewModel.cameraPanX,
        panY: widget.viewModel.cameraPanY,
        panZ: widget.viewModel.cameraPanZ,
      ).project(wx, wy, wz);

  /// Handle screen positions for tests, so a test can point at a handle the
  /// same way a user does instead of guessing pixels.
  @visibleForTesting
  Map<String, Offset>? gizmoHandleScreenPositionsForTest(Size viewportSize) =>
      _gizmoHandleScreenPositions(viewportSize);

  void _handleMouseHover(Offset localPos, Size viewportSize) {
    if (_draggingGizmoAxis != null) return;
    final selectedActor = widget.viewModel.showFlags["Transform Gizmo"] == true
        ? widget.viewModel.selectedActor
        : null;
    if (selectedActor == null ||
        _nativeGizmo == null ||
        ![
          'translate',
          'rotate',
          'scale',
        ].contains(widget.viewModel.activeTool)) {
      if (_hoveredGizmoAxis != null) {
        setState(() {
          _hoveredGizmoAxis = null;
          _nativeGizmo?.setAllHandlesDimmed(null);
        });
      }
      return;
    }

    final newHover = _levelGizmoModel(viewportSize)?.hitTest(localPos);
    if (newHover != _hoveredGizmoAxis) {
      setState(() {
        _hoveredGizmoAxis = newHover;
        _nativeGizmo?.setAllHandlesDimmed(newHover);
      });
    }
  }

  bool _checkActorHitForMarqueeStart(Offset clickPos, Size viewportSize) {
    final camera = _CameraMatrix(
      viewportSize: viewportSize,
      yawDeg: widget.viewModel.cameraYaw,
      pitchDeg: widget.viewModel.cameraPitch,
      dist: widget.viewModel.cameraDistance,
      panX: widget.viewModel.cameraPanX,
      panY: widget.viewModel.cameraPanY,
      panZ: widget.viewModel.cameraPanZ,
    );
    final origin = [camera.camX, camera.camY, camera.camZ];
    final direction = camera.getWorldRayDirection(clickPos);
    final hits = ViewportPicker().pickActors(
      widget.viewModel.actors,
      Ray.originDirection(Vector3.array(origin), Vector3.array(direction)),
      null,
    );
    return hits.isNotEmpty;
  }

  void _handlePanStart(Offset localPos, Size viewportSize) {
    if (_hoveredGizmoAxis != null) {
      _draggingGizmoAxis = _hoveredGizmoAxis;
      widget.viewModel.beginTransformDrag();

      final selectedActor =
          widget.viewModel.showFlags["Transform Gizmo"] == true
          ? widget.viewModel.selectedActor
          : null;
      final model = _levelGizmoModel(viewportSize);
      if (selectedActor == null || model == null) return;

      _dragStartActorLoc = Vector3.array(selectedActor.location);
      _dragStartActorRot = Vector3.array(selectedActor.rotation);
      _dragStartActorScale = Vector3.array(selectedActor.scale);
      final camera = _overlayCamera(viewportSize);
      final ray = Ray.originDirection(
        Vector3(camera.camX, camera.camY, camera.camZ),
        Vector3.array(camera.getWorldRayDirection(localPos)),
      );
      _gizmoDragOp = model.beginDrag(
        _hoveredGizmoAxis!,
        ray,
        cameraPosition: Vector3(camera.camX, camera.camY, camera.camZ),
      );
    }
  }

  void _handleEndDrop() {
    final selectedActor = widget.viewModel.selectedActor;
    if (selectedActor == null) return;

    double bottomOffset = 0.0;

    // Attempt to get the lowest Z point of the actor in local space
    // Normally we'd compute the oriented bounding box min Z in world space,
    // but for simple Z drop without complex collision, local min Z * scale Z is a good approximation
    // for mostly upright meshes.
    try {
      // The lowest point of the actor on the editor's up axis, converted from
      // the asset's Y-up bounds. Reading index 2 here used to drop the actor by
      // its depth instead of its height.
      final box = ViewportPicker.editorSpaceBounds(selectedActor);
      final glb = (selectedActor as dynamic).meshData;
      if (box != null) {
        bottomOffset = box.min.z - selectedActor.location[2];
      } else if (glb != null && glb.minBounds.length >= 3) {
        bottomOffset = glb.minBounds[1] * selectedActor.scale[2];
      } else {
        bottomOffset =
            -25.0 *
            selectedActor
                .scale[2]; // Default proxy bounds min Z is 0 or -25. Let's assume 0 is center, so -25 for proxy. Wait, proxy was min -25, max 25 for X/Y, Z was 0 to 50!
        // Actually earlier it was min=[..., 0.0]. So bottomOffset = 0.0.
        bottomOffset = 0.0;
      }
    } catch (e) {
      bottomOffset = 0.0;
    }

    final currentLoc = List<double>.from(selectedActor.location);
    final targetZ =
        -bottomOffset; // Floor is at Z=0. So location Z should be -bottomOffset so bottom reaches 0.

    widget.viewModel.updateActorLocation([
      currentLoc[0],
      currentLoc[1],
      targetZ,
    ]);
  }

  void _handleGizmoDrag(Offset localPos) {
    final renderBox =
        _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final selectedActor = widget.viewModel.selectedActor;
    final drag = _gizmoDragOp;
    if (selectedActor == null || _draggingGizmoAxis == null || drag == null) return;

    final camera = _overlayCamera(renderBox.size);
    final ray = Ray.originDirection(
      Vector3(camera.camX, camera.camY, camera.camZ),
      Vector3.array(camera.getWorldRayDirection(localPos)),
    );
    final vm = widget.viewModel;

    switch (drag.model.mode) {
      case GizmoMode.translate:
        var rawNewLoc = _dragStartActorLoc + drag.translation(ray);
        if (vm.translateSnapEnabled) {
          rawNewLoc = Vector3.array(SnapService.snapVector([rawNewLoc.x, rawNewLoc.y, rawNewLoc.z], vm.translateSnapStep));
        }
        vm.updateActorLocation([rawNewLoc.x, rawNewLoc.y, rawNewLoc.z]);
      case GizmoMode.rotate:
        // The angle swept since the grab, on the dragged axis only
        // (not yaw-only rotation).
        var deltaAngle = drag.rotationAngle(ray);
        if (vm.rotateSnapEnabled) {
          deltaAngle = SnapService.snapAngle(deltaAngle, vm.rotateSnapStep);
        }
        final rot = _dragStartActorRot.clone();
        if (_draggingGizmoAxis == 'X') rot.x += deltaAngle;
        if (_draggingGizmoAxis == 'Y') rot.y += deltaAngle;
        if (_draggingGizmoAxis == 'Z') rot.z += deltaAngle;
        if ((rot - Vector3.array(selectedActor.rotation)).length2 > 1e-12) {
          vm.updateActorRotation([rot.x, rot.y, rot.z]);
        }
      case GizmoMode.scale:
        // 0.05 scale per world unit of travel, as before the extraction.
        var snappedDelta = drag.scaleTravel(ray) * 0.05;
        if (vm.scaleSnapEnabled) {
          snappedDelta = SnapService.snapValue(snappedDelta, vm.scaleSnapStep);
        }
        final rawNewScale = _dragStartActorScale.clone();
        final handle = _draggingGizmoAxis!;
        if (handle == 'UNIFORM' || handle == 'X') rawNewScale.x += snappedDelta;
        if (handle == 'UNIFORM' || handle == 'Y') rawNewScale.y += snappedDelta;
        if (handle == 'UNIFORM' || handle == 'Z') rawNewScale.z += snappedDelta;
        final clamped = TransformGizmoModel.clampScale(rawNewScale);
        vm.updateActorScale([clamped.x, clamped.y, clamped.z]);
    }
  }

  Offset _unprojectRayToFloor(
    Offset screenPos,
    Size viewportSize,
    double yawDeg,
    double pitchDeg,
    double dist,
    double panX,
    double panY,
    double panZ,
  ) {
    final camera = _CameraMatrix(
      viewportSize: viewportSize,
      yawDeg: yawDeg,
      pitchDeg: pitchDeg,
      dist: dist,
      panX: panX,
      panY: panY,
      panZ: panZ,
    );
    return camera.unprojectToFloor(screenPos);
  }
}
