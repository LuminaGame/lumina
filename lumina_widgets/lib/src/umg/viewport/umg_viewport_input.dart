part of 'umg_viewport.dart';

/// What a pointer drag on the Viewport is doing.
enum _DragKind { none, orbitOrTap, pan, gizmo }

/// The Viewport's gestures: left drag orbits (a short press picks), right
/// or middle drag pans, the wheel and a pinch zoom, a drag on a gizmo
/// handle moves the target; F frames the picked node and Escape cancels a
/// gizmo drag. The cursor follows the hovered gizmo axis.
class _ViewportInput {
  _ViewportInput(this.state);

  final LuminaUmgViewportState state;

  /// Pixels a press may travel and still count as a tap.
  static const double tapSlop = 4.0;

  _DragKind _kind = _DragKind.none;
  double _travel = 0.0;
  String? activeHandle;
  TransformGizmoDrag? _drag;
  Map<String, Object?>? _start;
  Timer? _wheelEnd;
  MouseCursor _cursor = MouseCursor.defer;

  bool get draggingGizmo => _kind == _DragKind.gizmo;

  LuminaViewportController? get _c => state._controller;

  Widget wrap(Widget child) => Focus(
        focusNode: state._focus,
        onKeyEvent: _key,
        child: MouseRegion(
          cursor: _cursor,
          onHover: _hover,
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: _down,
            onPointerMove: _move,
            onPointerUp: _up,
            onPointerCancel: (_) => _cancel(),
            onPointerSignal: _signal,
            onPointerPanZoomUpdate: (e) {
              if (e.scale != 1.0) _c?.zoom(1 / e.scale.clamp(0.5, 2.0));
            },
            onPointerPanZoomEnd: (_) => _c?.endCameraGesture(),
            child: child,
          ),
        ),
      );

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final c = _c;
    if (c == null) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.keyF) {
      c.frameSelection();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape && c.isDraggingGizmo) {
      _cancel();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _hover(PointerHoverEvent e) {
    final handle = luminaViewportGizmoModel(_c)?.hitTest(e.localPosition);
    final cursor = switch (handle) {
      TransformGizmoModel.axisX => SystemMouseCursors.resizeLeftRight,
      TransformGizmoModel.axisY => SystemMouseCursors.resizeUpLeftDownRight,
      TransformGizmoModel.axisZ => SystemMouseCursors.resizeUpDown,
      null => MouseCursor.defer,
      _ => SystemMouseCursors.move,
    };
    if (handle != activeHandle || cursor != _cursor) {
      // ignore: invalid_use_of_protected_member
      state.setState(() {
        activeHandle = handle;
        _cursor = cursor;
      });
    }
  }

  /// The ray under [p] in the authoring frame (what the gizmo solves in).
  Ray _ray(Offset p) {
    final r = _c!.runtime.orbit.rayAt(p.dx, p.dy);
    final o = LuminaAxes.toAuthoringLocation(r.origin);
    final d = LuminaAxes.toAuthoringLocation(r.direction);
    return Ray.originDirection(Vector3(o[0], o[1], o[2]), Vector3(d[0], d[1], d[2]));
  }

  Vector3 _eye() {
    final e = LuminaAxes.toAuthoringLocation(_c!.runtime.orbit.eye);
    return Vector3(e[0], e[1], e[2]);
  }

  void _down(PointerDownEvent e) {
    state._focus.requestFocus();
    final c = _c;
    if (c == null) return;
    _travel = 0.0;
    if (e.buttons & kPrimaryButton != 0) {
      final model = luminaViewportGizmoModel(c);
      final handle = model?.hitTest(e.localPosition);
      if (model != null && handle != null && c.beginGizmoDrag()) {
        _kind = _DragKind.gizmo;
        activeHandle = handle;
        _drag = model.beginDrag(handle, _ray(e.localPosition), cameraPosition: _eye());
        final target = c.gizmoTarget!;
        _start = target.bone == null
            ? c.runtime.transformOf(target.node)
            : {
                'location': [model.pivot.x, model.pivot.y, model.pivot.z],
                'rotation': [0.0, 0.0, 0.0],
                'scale': [1.0, 1.0, 1.0],
              };
        return;
      }
      _kind = _DragKind.orbitOrTap;
    } else {
      _kind = _DragKind.pan;
    }
  }

  void _move(PointerMoveEvent e) {
    final c = _c;
    if (c == null) return;
    _travel += e.delta.distance;
    switch (_kind) {
      case _DragKind.orbitOrTap:
        if (_travel > tapSlop) c.orbitDrag(e.delta.dx, e.delta.dy);
      case _DragKind.pan:
        c.panDrag(e.delta.dx, e.delta.dy);
      case _DragKind.gizmo:
        final t = _gizmoTransform(e.localPosition);
        if (t != null) c.updateGizmoDrag(t);
      case _DragKind.none:
        break;
    }
  }

  /// The target's transform for the pointer at [p] during a gizmo drag.
  Map<String, Object?>? _gizmoTransform(Offset p) {
    final drag = _drag;
    final start = _start;
    if (drag == null || start == null) return null;
    final ray = _ray(p);
    List<double> v(Object? o, double d) => o is List ? [for (var i = 0; i < 3; i++) i < o.length ? (o[i] as num).toDouble() : d] : [d, d, d];
    var location = v(start['location'], 0);
    var rotation = v(start['rotation'], 0);
    var scale = v(start['scale'], 1);
    final snap = (_c?.scene?.gizmo?['snap'] as num?)?.toDouble() ?? 0.0;
    double snapped(double x) => snap > 0 ? (x / snap).roundToDouble() * snap : x;
    switch (drag.model.mode) {
      case GizmoMode.translate:
        final d = drag.translation(ray);
        location = [snapped(location[0] + d.x), snapped(location[1] + d.y), snapped(location[2] + d.z)];
      case GizmoMode.rotate:
        rotation = AuthoringRotation.rotatedAboutWorldAxis(rotation, drag.rotationAxis, snapped(drag.rotationAngle(ray)));
      case GizmoMode.scale:
        final k = 1.0 + drag.scaleTravel(ray) / math.max(1.0, drag.model.axisLength);
        final axis = drag.handle;
        scale = [
          for (var i = 0; i < 3; i++)
            (axis == TransformGizmoModel.uniform || axis == TransformGizmoModel.center || axis == TransformGizmoModel.axes[i])
                ? (scale[i] * k).clamp(TransformGizmoModel.minScale, TransformGizmoModel.maxScale)
                : scale[i],
        ];
    }
    return {'location': location, 'rotation': rotation, 'scale': scale};
  }

  void _up(PointerUpEvent e) {
    final c = _c;
    final kind = _kind;
    _kind = _DragKind.none;
    if (c == null) return;
    switch (kind) {
      case _DragKind.orbitOrTap:
        if (_travel <= tapSlop) {
          c.tap(e.localPosition.dx, e.localPosition.dy);
        } else {
          c.endCameraGesture();
        }
      case _DragKind.pan:
        c.endCameraGesture();
      case _DragKind.gizmo:
        c.commitGizmoDrag();
        _drag = null;
      case _DragKind.none:
        break;
    }
  }

  void _cancel() {
    final c = _c;
    if (_kind == _DragKind.gizmo || (c?.isDraggingGizmo ?? false)) c?.cancelGizmoDrag();
    if (_kind == _DragKind.orbitOrTap || _kind == _DragKind.pan) c?.endCameraGesture();
    _kind = _DragKind.none;
    _drag = null;
  }

  void _signal(PointerSignalEvent e) {
    final c = _c;
    if (c == null || e is! PointerScrollEvent) return;
    c.zoom(math.pow(1.0015, e.scrollDelta.dy).toDouble());
    // The wheel has no release: the zoom ends when it rests.
    _wheelEnd?.cancel();
    _wheelEnd = Timer(const Duration(milliseconds: 250), () => _c?.endCameraGesture());
  }
}
