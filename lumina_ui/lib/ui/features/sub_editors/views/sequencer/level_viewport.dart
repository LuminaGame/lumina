import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_filament/flutter_filament.dart' show FilamentCamera, FilamentView;
import 'package:lumina/lumina.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/services/editor_view_layers.dart';
import 'package:lumina_ui/ui/features/main_editor/services/gizmo_controller.dart';
import 'package:lumina_ui/ui/features/main_editor/services/snap_service.dart';
import 'package:lumina_ui/ui/features/main_editor/services/transform_gizmo.dart';
import 'package:lumina_ui/ui/features/main_editor/services/viewport_picker.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/level_scene_view.dart';
import 'package:lumina_ui/ui/features/main_editor/views/viewport_widget.dart' show kViewportFovDegrees;
import 'package:vector_math/vector_math_64.dart' show Ray, Vector3;
import '../../models/sequencer_viewport_camera.dart';
import '../../view_models/sequencer_view_model.dart';
import '../sub_editor_transform_gizmo_painter.dart';

/// The Sequencer's viewport: the level the sequence drives, drawn from the
/// level viewport's own Filament scene by a second view, so every scrub and
/// playback frame the Sequencer writes onto the level's actors shows here
/// the same frame.
///
/// It looks through an editor camera of its own (starting where the level
/// viewport's camera is; drag to orbit, middle-drag to pan, wheel to dolly,
/// right button + W/A/S/D/Q/E to fly, F to frame the animated actors) or,
/// locked, through a camera actor bound in the sequence, inside a 16:9 film
/// gate, without the editor's helpers (grid, gizmo, light wires).
///
/// A click selects the actor under the pointer (in the level, so Details
/// shows it too); the selected actor gets the level viewport's transform
/// gizmo (its tool, W/E/R, World/Local space and snapping) drawn for this
/// view's camera. A gizmo gesture goes through the Sequencer's edit path:
/// on release Auto Key keys the changed channels at the playhead.
class SequencerLevelViewport extends StatefulWidget {
  const SequencerLevelViewport({super.key, required this.editorViewModel, required this.sequencer});

  final EditorViewModel editorViewModel;
  final SequencerViewModel sequencer;

  /// The film gate a locked camera frames.
  static const double filmAspect = 16 / 9;

  @override
  State<SequencerLevelViewport> createState() => SequencerLevelViewportState();
}

class SequencerLevelViewportState extends State<SequencerLevelViewport> with SingleTickerProviderStateMixin {
  /// The second view of the level this viewport draws through.
  final GlobalKey<LevelSceneViewState> _sceneView = GlobalKey<LevelSceneViewState>();

  late SequencerViewportCamera _editorCamera;
  String? _lockedCameraId;
  Size _size = Size.zero;

  final FocusNode _focus = FocusNode(debugLabel: 'Sequencer viewport');
  final Set<LogicalKeyboardKey> _keys = {};
  bool _lmb = false, _rmb = false, _mmb = false;
  late final Ticker _flyTicker;
  Duration _lastFly = Duration.zero;

  // Selection and the transform gizmo.
  /// The gizmo's on-screen arm length, logical pixels.
  static const double _gizmoScreenPixels = 110.0;
  String? _hoverHandle;
  TransformGizmoDrag? _drag;
  String? _dragHandle;
  String? _dragActorId;
  Vector3 _dragStartLoc = Vector3.zero();
  Vector3 _dragStartRot = Vector3.zero();
  Vector3 _dragStartScale = Vector3(1, 1, 1);
  Offset? _downPos;
  bool _downMoved = false;

  EditorViewModel get _evm => widget.editorViewModel;

  /// The sequence this view previews.
  SequencerViewModel get sequencer => widget.sequencer;

  /// Whether this view draws the level viewport's scene right now.
  bool get drawsLevelScene => _sceneView.currentState?.drawsLevelScene ?? false;

  /// The editor camera (navigation state), for tests.
  SequencerViewportCamera get editorCamera => _editorCamera;

  /// The camera actor the view looks through, or null for the editor camera.
  String? get lockedCameraId => _lockedCameraId;

  FilamentView? get viewForTest => _sceneView.currentState?.view;
  FilamentCamera? get cameraForTest => _sceneView.currentState?.camera;

  /// The level's camera actors the sequence animates: what the view can be
  /// locked to.
  List<EditorActorNode> get cameraCandidates {
    final bound = {for (final t in sequencer.tracks) t.actorId};
    return [
      for (final a in _evm.actors)
        if (bound.contains(a.id) && SequencerViewportCamera.isCamera(a)) a,
    ];
  }

  EditorActorNode? get _lockedCamera {
    final id = _lockedCameraId;
    if (id == null) return null;
    for (final a in _evm.actors) {
      if (a.id == id) return a;
    }
    return null;
  }

  /// Looks through [actorId] (a camera actor bound in the sequence), or
  /// through the editor camera again when null.
  void lockToCamera(String? actorId) {
    setState(() => _lockedCameraId = actorId);
    _applyCamera();
  }

  @override
  void initState() {
    super.initState();
    _editorCamera = SequencerViewportCamera.fromEditor(_evm);
    _evm.addListener(_onLevelChanged);
    sequencer.addListener(_onLevelChanged);
    _flyTicker = createTicker(_onFlyTick)..start();
  }

  @override
  void didUpdateWidget(covariant SequencerLevelViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.editorViewModel != widget.editorViewModel) {
      oldWidget.editorViewModel.removeListener(_onLevelChanged);
      widget.editorViewModel.addListener(_onLevelChanged);
    }
    if (oldWidget.sequencer != widget.sequencer) {
      oldWidget.sequencer.removeListener(_onLevelChanged);
      widget.sequencer.addListener(_onLevelChanged);
    }
  }

  @override
  void dispose() {
    _evm.removeListener(_onLevelChanged);
    sequencer.removeListener(_onLevelChanged);
    _flyTicker.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onLevelChanged() {
    if (_lockedCameraId != null && _lockedCamera == null) _lockedCameraId = null;
    _applyCamera();
    _rebuild();
  }

  /// Rebuilds now, or after the frame when the notification came while the
  /// tree is being built.
  void _rebuild() {
    if (!mounted) return;
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } else {
      setState(() {});
    }
  }

  /// The pose the view looks through now.
  SequencerViewPose get _pose {
    final locked = _lockedCamera;
    return locked != null
        ? SequencerViewportCamera.lockedPose(locked)
        : _editorCamera.editorPose(fovDegrees: kViewportFovDegrees);
  }

  /// Points the Filament camera through [_pose] (now, when the view exists).
  void _applyCamera() => _sceneView.currentState?.aim();

  /// Points [view]'s camera through [_pose]: a locked camera's field of view
  /// spans the film gate's height, the rest of the widget is masked.
  void _aim(LevelSceneViewState view) {
    final camera = view.camera;
    if (camera == null || camera.isDisposed) return;
    final pose = _pose;
    final size = view.size;
    final aspect = size.width > 0 && size.height > 0 ? size.width / size.height : 16 / 9;
    final fov = _fovFor(pose, size);
    final locked = _lockedCamera != null;
    final far = locked ? 100000.0 : math.max(5000.0, _editorCamera.distance * 4.0);
    camera.setProjection(fovDegrees: fov, aspect: aspect, near: locked ? 1.0 : 0.1, far: far);
    view.view?.setDynamicLightingOptions(LuminaUnits.dynamicLightingNear, math.max(LuminaUnits.dynamicLightingFar, far));
    final e = pose.eye, f = pose.forward, u = pose.up;
    camera.lookAt(
      eyeX: e.x,
      eyeY: e.y,
      eyeZ: e.z,
      centerX: e.x + f.x,
      centerY: e.y + f.y,
      centerZ: e.z + f.z,
      upX: u.x,
      upY: u.y,
      upZ: u.z,
    );
    // The level viewport meters exposure from the level's lights.
    final source = view.drawn?.camera;
    if (source != null && !source.isDisposed) {
      camera.setExposure(aperture: source.aperture, shutterSpeed: source.shutterSpeed, sensitivity: source.sensitivity);
    }
  }

  /// The vertical field of view the view renders [pose] with in [size]: a
  /// locked camera's spans the film gate's height.
  double _fovFor(SequencerViewPose pose, Size size) {
    var fov = pose.fovDegrees;
    if (_lockedCamera != null) {
      final gate = _filmGate(size);
      if (gate.height > 0 && gate.height < size.height) {
        final half = math.atan(math.tan(fov * math.pi / 360) * size.height / gate.height);
        fov = half * 360 / math.pi;
      }
    }
    return fov;
  }

  /// The camera's basis in runtime axes (Y up) and its tan(fov/2).
  ({Vector3 eye, Vector3 forward, Vector3 right, Vector3 up, double tanHalf}) _cameraFrame(Size size) {
    final pose = _pose;
    final forward = pose.forward.normalized();
    var right = forward.cross(pose.up);
    if (right.length2 < 1e-12) right = Vector3(1, 0, 0);
    right.normalize();
    final up = right.cross(forward)..normalize();
    return (eye: pose.eye, forward: forward, right: right, up: up, tanHalf: math.tan(_fovFor(pose, size) * math.pi / 360));
  }

  /// Where the stored-axes (Z up) point [p] is drawn in this view, in
  /// widget-local pixels; null behind the camera.
  Offset? projectStored(Vector3 p, [Size? size]) {
    final s = size ?? _size;
    if (s.isEmpty) return null;
    final f = _cameraFrame(s);
    final v = LuminaAxes.location([p.x, p.y, p.z]) - f.eye;
    final z = v.dot(f.forward);
    if (z <= 1e-3) return null;
    final k = (s.height / 2) / (z * f.tanHalf);
    return Offset(s.width / 2 + v.dot(f.right) * k, s.height / 2 - v.dot(f.up) * k);
  }

  /// The pointer's ray through [local], in stored axes (Z up).
  Ray rayAt(Offset local, [Size? size]) {
    final s = size ?? _size;
    final f = _cameraFrame(s);
    final nx = (local.dx - s.width / 2) / (s.height / 2) * f.tanHalf;
    final ny = -(local.dy - s.height / 2) / (s.height / 2) * f.tanHalf;
    final dir = (f.forward + f.right * nx + f.up * ny)..normalize();
    return Ray.originDirection(AuthoringRotation.toAuthoring(f.eye), AuthoringRotation.toAuthoring(dir));
  }

  /// The eye in stored axes.
  Vector3 get _eyeStored => AuthoringRotation.toAuthoring(_pose.eye);

  /// The actor the gizmo manipulates: the level's selected actor.
  EditorActorNode? get _gizmoActor {
    final a = _evm.selectedActor;
    if (a == null || _evm.showFlags['Transform Gizmo'] == false) return null;
    if (!_evm.actors.contains(a) || !_evm.isEffectivelyVisible(a.id)) return null;
    return a;
  }

  GizmoMode get _gizmoMode => switch (_evm.activeTool) {
        'rotate' => GizmoMode.rotate,
        'scale' => GizmoMode.scale,
        _ => GizmoMode.translate,
      };

  /// The gizmo as drawn and hit-tested now (for [size], default the view's),
  /// or null without a selected actor in front of the camera.
  TransformGizmoModel? gizmoModel([Size? size]) {
    final actor = _gizmoActor;
    final s = size ?? _size;
    if (actor == null || s.isEmpty) return null;
    final f = _cameraFrame(s);
    final depth = (LuminaAxes.location(actor.location) - f.eye).dot(f.forward);
    if (depth <= 1e-3) return null;
    final axisLength = math.max(depth * 2.0 * f.tanHalf / s.height * _gizmoScreenPixels, 1e-3);
    return TransformGizmoModel(
      mode: _gizmoMode,
      space: _evm.gizmoSpace == 'local' ? GizmoSpace.local : GizmoSpace.world,
      pivot: Vector3.array(actor.location),
      rotation: AuthoringRotation.quaternionToAuthoring(LuminaAxes.rotation(actor.rotation)),
      axisLength: axisLength,
      planeOffset: axisLength * 0.34,
      project: (p) => projectStored(p, s),
    );
  }

  /// The handle under the pointer (or being dragged).
  String? get hoveredGizmoHandle => _dragHandle ?? _hoverHandle;

  /// Whether a gizmo drag is in progress.
  bool get isDraggingGizmo => _drag != null;

  void _updateHover(Offset local) {
    if (_drag != null) return;
    final hover = gizmoModel()?.hitTest(local);
    if (hover != _hoverHandle) setState(() => _hoverHandle = hover);
  }

  /// A primary press: starts a drag when it hits a handle of the selected
  /// actor's gizmo. Returns whether the press was the gizmo's.
  bool _beginGizmoDrag(Offset local) {
    final actor = _gizmoActor;
    final model = gizmoModel();
    if (actor == null || model == null) return false;
    final handle = model.hitTest(local);
    if (handle == null) return false;
    if (_evm.isEffectivelyLocked(actor.id)) return true; // a locked actor swallows the press
    sequencer.beginActorTransform(actor.id);
    setState(() {
      _drag = model.beginDrag(handle, rayAt(local), cameraPosition: _eyeStored);
      _dragHandle = handle;
      _dragActorId = actor.id;
      _hoverHandle = handle;
      _dragStartLoc = Vector3.array(actor.location);
      _dragStartRot = Vector3.array(actor.rotation);
      _dragStartScale = Vector3.array(actor.scale);
    });
    return true;
  }

  void _updateGizmoDrag(Offset local) {
    final drag = _drag;
    final id = _dragActorId;
    final handle = _dragHandle;
    if (drag == null || id == null || handle == null) return;
    final ray = rayAt(local);
    switch (drag.model.mode) {
      case GizmoMode.translate:
        var loc = _dragStartLoc + drag.translation(ray);
        if (_evm.translateSnapEnabled) {
          loc = Vector3.array(SnapService.snapVector([loc.x, loc.y, loc.z], _evm.translateSnapStep));
        }
        sequencer.previewActorTransform(id, location: [loc.x, loc.y, loc.z]);
      case GizmoMode.rotate:
        // The level viewport's rule: the ring angle is right-handed about its
        // axis; stored roll and yaw turn the other way.
        var angle = drag.rotationAngle(ray);
        if (_evm.rotateSnapEnabled) angle = SnapService.snapAngle(angle, _evm.rotateSnapStep);
        final rot = _dragStartRot.clone();
        if (handle == TransformGizmoModel.axisX) rot.x += angle;
        if (handle == TransformGizmoModel.axisY) rot.y -= angle;
        if (handle == TransformGizmoModel.axisZ) rot.z -= angle;
        sequencer.previewActorTransform(id, rotation: [rot.x, rot.y, rot.z]);
      case GizmoMode.scale:
        // One arm length of travel is one unit of scale.
        var amount = drag.scaleTravel(ray) / drag.model.axisLength;
        if (_evm.scaleSnapEnabled) amount = SnapService.snapValue(amount, _evm.scaleSnapStep);
        final scale = _dragStartScale.clone();
        if (handle == TransformGizmoModel.uniform || handle == TransformGizmoModel.axisX) scale.x += amount;
        if (handle == TransformGizmoModel.uniform || handle == TransformGizmoModel.axisY) scale.y += amount;
        if (handle == TransformGizmoModel.uniform || handle == TransformGizmoModel.axisZ) scale.z += amount;
        final clamped = TransformGizmoModel.clampScale(scale);
        sequencer.previewActorTransform(id, scale: [clamped.x, clamped.y, clamped.z]);
    }
  }

  void _endGizmoDrag({bool cancel = false}) {
    final id = _dragActorId;
    setState(() {
      _drag = null;
      _dragHandle = null;
      _dragActorId = null;
      _hoverHandle = null; // the next pointer move hit-tests again
    });
    if (id == null) return;
    if (cancel) {
      sequencer.cancelActorTransform(id);
    } else {
      sequencer.endActorTransform(id);
    }
  }

  /// A click that hit no handle: selects the actor under the pointer (in the
  /// level, and its track in the sequence), or clears the selection.
  void _pick(Offset local) {
    final hits = ViewportPicker().pickActors(_evm.actors, rayAt(local), null);
    if (hits.isEmpty) {
      _evm.clearSelection();
      return;
    }
    final actor = hits.first.actor;
    _evm.selectActor(actor);
    sequencer.selectTrackForActor(actor.id);
  }

  /// The 16:9 rectangle a locked camera frames inside [size].
  static Rect _filmGate(Size size) {
    if (size.isEmpty) return Rect.zero;
    const a = SequencerLevelViewport.filmAspect;
    if (size.width / size.height >= a) {
      final w = size.height * a;
      return Rect.fromLTWH((size.width - w) / 2, 0, w, size.height);
    }
    final h = size.width / a;
    return Rect.fromLTWH(0, (size.height - h) / 2, size.width, h);
  }

  /// Frames what the sequence animates (every bound actor that is not a
  /// camera; the whole level when it binds none).
  void focusAnimatedActors() {
    final bound = {for (final t in sequencer.tracks) t.actorId};
    var actors = _evm.actors.where((a) => bound.contains(a.id) && !SequencerViewportCamera.isCamera(a)).toList();
    if (actors.isEmpty) actors = _evm.actors.where((a) => a.type != 'Folder').toList();
    if (actors.isEmpty) return;
    var lo = [double.infinity, double.infinity, double.infinity];
    var hi = [-double.infinity, -double.infinity, -double.infinity];
    for (final a in actors) {
      final box = ViewportPicker.editorSpaceBounds(a);
      final min = box == null ? a.location : [box.min.x, box.min.y, box.min.z];
      final max = box == null ? a.location : [box.max.x, box.max.y, box.max.z];
      for (var i = 0; i < 3; i++) {
        lo[i] = math.min(lo[i], min[i]);
        hi[i] = math.max(hi[i], max[i]);
      }
    }
    final center = [for (var i = 0; i < 3; i++) (lo[i] + hi[i]) / 2];
    final radius = math.sqrt([for (var i = 0; i < 3; i++) math.pow(hi[i] - lo[i], 2)].reduce((a, b) => a + b)) / 2;
    setState(() => _editorCamera.focus(center: center, radius: math.max(radius, 25.0)));
    _applyCamera();
  }

  void _onFlyTick(Duration elapsed) {
    final dt = _lastFly == Duration.zero ? 0.016 : ((elapsed - _lastFly).inMicroseconds / 1e6).clamp(0.001, 0.05);
    _lastFly = elapsed;
    if (!_rmb || _keys.isEmpty || _lockedCamera != null) return;
    int axis(LogicalKeyboardKey plus, LogicalKeyboardKey minus) => (_keys.contains(plus) ? 1 : 0) - (_keys.contains(minus) ? 1 : 0);
    final forward = axis(LogicalKeyboardKey.keyW, LogicalKeyboardKey.keyS);
    final right = axis(LogicalKeyboardKey.keyD, LogicalKeyboardKey.keyA);
    final up = axis(LogicalKeyboardKey.keyE, LogicalKeyboardKey.keyQ);
    if (forward == 0 && right == 0 && up == 0) return;
    final boost = HardwareKeyboard.instance.isShiftPressed ? 2.5 : 1.0;
    _editorCamera.fly(forward: forward, right: right, up: up, dt: dt, speed: 400.0 * boost);
    _applyCamera();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      final keyboard = HardwareKeyboard.instance;
      if (keyboard.isControlPressed || keyboard.isMetaPressed || keyboard.isAltPressed) return KeyEventResult.ignored;
      if (event.logicalKey == LogicalKeyboardKey.keyF && _lockedCamera == null) {
        focusAnimatedActors();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.escape && _drag != null) {
        _endGizmoDrag(cancel: true);
        return KeyEventResult.handled;
      }
      // W/E/R pick the gizmo's tool unless the right button is flying.
      if (!_rmb && event is KeyDownEvent) {
        final tool = switch (event.logicalKey) {
          LogicalKeyboardKey.keyW => 'translate',
          LogicalKeyboardKey.keyE => 'rotate',
          LogicalKeyboardKey.keyR => 'scale',
          _ => null,
        };
        if (tool != null) {
          _evm.setActiveTool(tool);
          return KeyEventResult.handled;
        }
      }
      const fly = {'w', 'a', 's', 'd', 'q', 'e'};
      if (fly.contains(event.logicalKey.keyLabel.toLowerCase())) {
        _keys.add(event.logicalKey);
        return _rmb ? KeyEventResult.handled : KeyEventResult.ignored;
      }
    } else if (event is KeyUpEvent) {
      _keys.remove(event.logicalKey);
    }
    return KeyEventResult.ignored;
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_lockedCamera != null) return;
    final d = event.delta;
    if (_mmb || (_lmb && HardwareKeyboard.instance.isShiftPressed)) {
      _editorCamera.pan(d.dx, d.dy);
    } else if (_lmb || _rmb) {
      _editorCamera.orbit(d.dx, d.dy);
    } else {
      return;
    }
    _applyCamera();
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || _lockedCamera != null) return;
    _editorCamera.dolly(event.scrollDelta.dy);
    _applyCamera();
  }

  void _setButtons(int buttons) {
    _lmb = buttons & kPrimaryMouseButton != 0;
    _rmb = buttons & kSecondaryMouseButton != 0;
    _mmb = buttons & kMiddleMouseButton != 0;
  }

  @override
  Widget build(BuildContext context) {
    final locked = _lockedCamera;
    return LayoutBuilder(builder: (context, constraints) {
      final size = constraints.biggest;
      if (size.isFinite) _size = size;
      final gate = _filmGate(_size);
      return Focus(
        focusNode: _focus,
        onKeyEvent: _onKey,
        child: Listener(
          onPointerDown: (e) {
            _setButtons(e.buttons);
            if (!_focus.hasPrimaryFocus) _focus.requestFocus();
            _downPos = null;
            if (e.buttons == kPrimaryMouseButton && !HardwareKeyboard.instance.isShiftPressed) {
              if (!_beginGizmoDrag(e.localPosition)) {
                _downPos = e.localPosition;
                _downMoved = false;
              }
            }
          },
          onPointerHover: (e) => _updateHover(e.localPosition),
          onPointerMove: (e) {
            _setButtons(e.buttons);
            if (_drag != null) {
              _updateGizmoDrag(e.localPosition);
              return;
            }
            if (_downPos != null && (e.localPosition - _downPos!).distance > 4) _downMoved = true;
            _onPointerMove(e);
          },
          onPointerUp: (e) {
            _setButtons(e.buttons);
            if (_drag != null) {
              _endGizmoDrag();
            } else if (_downPos != null && !_downMoved) {
              _pick(e.localPosition);
            }
            _downPos = null;
          },
          onPointerCancel: (_) {
            _setButtons(0);
            if (_drag != null) _endGizmoDrag(cancel: true);
            _downPos = null;
          },
          onPointerSignal: _onPointerSignal,
          child: Stack(
            children: [
              Positioned.fill(
                child: LevelSceneView(
                  key: _sceneView,
                  filamentKey: const ValueKey('seq_level_viewport_filament'),
                  editorViewModel: _evm,
                  debugLabel: 'Sequencer viewport',
                  onAim: _aim,
                  // Through a camera: what it sees, without the editor's helpers.
                  visibleLayers: locked != null ? EditorViewLayers.cameraView : EditorViewLayers.editorView,
                  placeholder: const Text('The level viewport is not running: open the level tab once to start it.',
                      style: TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
                ),
              ),
              if (locked != null && !gate.isEmpty) ..._letterbox(gate),
              if (gizmoModel() case final model?)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      key: const ValueKey('seq_viewport_gizmo'),
                      painter: SubEditorTransformGizmoPainter(
                        model: model,
                        activeHandle: _dragHandle ?? _hoverHandle,
                        dragging: _drag != null,
                        locked: _evm.isEffectivelyLocked(_gizmoActor!.id),
                      ),
                    ),
                  ),
                ),
              Positioned(left: 8, top: 8, child: _buildHud(locked)),
              Positioned(right: 8, top: 8, child: _buildGizmoTools()),
            ],
          ),
        ),
      );
    });
  }

  /// Black bars outside the film gate.
  List<Widget> _letterbox(Rect gate) {
    const bar = ColoredBox(color: Colors.black);
    return [
      if (gate.top > 0) ...[
        Positioned(left: 0, right: 0, top: 0, height: gate.top, child: bar),
        Positioned(left: 0, right: 0, bottom: 0, height: _size.height - gate.bottom, child: bar),
      ],
      if (gate.left > 0) ...[
        Positioned(left: 0, top: 0, bottom: 0, width: gate.left, child: bar),
        Positioned(right: 0, top: 0, bottom: 0, width: _size.width - gate.right, child: bar),
      ],
    ];
  }

  /// Move / Rotate / Scale (W/E/R), World/Local and the three snap toggles:
  /// the level viewport's own settings.
  Widget _buildGizmoTools() {
    Widget button({
      required Key key,
      required IconData icon,
      required bool active,
      required String tip,
      required VoidCallback onPressed,
      String? label,
    }) {
      final color = active ? EditorColors.primary : EditorColors.foreground;
      return Tooltip(
        tooltip: (_) => TooltipContainer(child: Text(tip, style: const TextStyle(fontSize: 9))),
        child: GestureDetector(
          key: key,
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
            margin: const EdgeInsets.only(right: 2),
            decoration: BoxDecoration(
              color: active ? EditorColors.primary.withValues(alpha: 0.3) : Colors.transparent,
              borderRadius: BorderRadius.circular(3),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 11, color: color),
              if (label != null) ...[
                const SizedBox(width: 3),
                Text(label, style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: color)),
              ],
            ]),
          ),
        ),
      );
    }

    final mode = _gizmoMode;
    final local = _evm.gizmoSpace == 'local';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      decoration: BoxDecoration(
        color: EditorColors.hudSurface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: EditorColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(
              key: const ValueKey('seq_gizmo_translate'),
              icon: LucideIcons.move,
              active: mode == GizmoMode.translate,
              tip: 'Move (W)',
              onPressed: () => _evm.setActiveTool('translate')),
          button(
              key: const ValueKey('seq_gizmo_rotate'),
              icon: LucideIcons.rotateCcw,
              active: mode == GizmoMode.rotate,
              tip: 'Rotate (E)',
              onPressed: () => _evm.setActiveTool('rotate')),
          button(
              key: const ValueKey('seq_gizmo_scale'),
              icon: LucideIcons.maximize2,
              active: mode == GizmoMode.scale,
              tip: 'Scale (R)',
              onPressed: () => _evm.setActiveTool('scale')),
          const SizedBox(width: 4),
          button(
              key: const ValueKey('seq_gizmo_space'),
              icon: local ? LucideIcons.box : LucideIcons.globe,
              active: local,
              label: local ? 'LOCAL' : 'WORLD',
              tip: local ? 'Local space (click for World)' : 'World space (click for Local)',
              onPressed: _evm.toggleGizmoSpace),
          const SizedBox(width: 4),
          button(
              key: const ValueKey('seq_gizmo_snap_translate'),
              icon: LucideIcons.magnet,
              active: _evm.translateSnapEnabled,
              tip: 'Grid snap (${_evm.translateSnapStep} cm)',
              onPressed: () => _evm.updateTranslateSnapEnabled(!_evm.translateSnapEnabled)),
          button(
              key: const ValueKey('seq_gizmo_snap_rotate'),
              icon: LucideIcons.rotateCw,
              active: _evm.rotateSnapEnabled,
              tip: 'Rotation snap (${_evm.rotateSnapStep}°)',
              onPressed: () => _evm.updateRotateSnapEnabled(!_evm.rotateSnapEnabled)),
          button(
              key: const ValueKey('seq_gizmo_snap_scale'),
              icon: LucideIcons.scaling,
              active: _evm.scaleSnapEnabled,
              tip: 'Scale snap (${_evm.scaleSnapStep})',
              onPressed: () => _evm.updateScaleSnapEnabled(!_evm.scaleSnapEnabled)),
        ],
      ),
    );
  }

  Widget _buildHud(EditorActorNode? locked) {
    final cameras = cameraCandidates;
    const editorValue = '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: EditorColors.hudSurface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: EditorColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(locked != null ? LucideIcons.video : LucideIcons.move3d, size: 12, color: locked != null ? Colors.amber : EditorColors.foreground),
          const SizedBox(width: 6),
          SizedBox(
            width: 170,
            child: Select<String>(
              key: const ValueKey('seq_viewport_camera'),
              value: _lockedCameraId ?? editorValue,
              onChanged: (v) => lockToCamera(v == null || v.isEmpty ? null : v),
              itemBuilder: (context, id) => Text(
                id.isEmpty ? 'Editor Camera' : 'Lock: ${cameras.where((c) => c.id == id).firstOrNull?.name ?? id}',
                style: const TextStyle(fontSize: 9.5),
              ),
              popup: SelectPopup(
                items: SelectItemList(
                  children: [
                    const SelectItemButton(value: editorValue, child: Text('Editor Camera', style: TextStyle(fontSize: 9.5))),
                    for (final c in cameras)
                      SelectItemButton(value: c.id, child: Text('Lock: ${c.name}', style: const TextStyle(fontSize: 9.5))),
                  ],
                ),
              ).call,
            ),
          ),
          if (locked == null) ...[
            const SizedBox(width: 4),
            Tooltip(
              tooltip: (_) => const TooltipContainer(
                child: Text('Frame the animated actors (F)\nDrag: orbit · Middle-drag / Shift+drag: pan\nWheel: dolly · Right button + WASD/QE: fly',
                    style: TextStyle(fontSize: 9)),
              ),
              child: GhostButton(
                key: const ValueKey('seq_viewport_focus'),
                size: ButtonSize.small,
                onPressed: focusAnimatedActors,
                child: const Icon(LucideIcons.scan, size: 12),
              ),
            ),
          ] else ...[
            const SizedBox(width: 8),
            Text('PILOTING ${locked.name}',
                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.amber)),
          ],
        ],
      ),
    );
  }
}
