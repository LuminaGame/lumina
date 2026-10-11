import 'package:lumina/src/blueprint/widget_blueprint.dart';
import 'package:lumina/src/umg/viewport/viewport_budget.dart';
import 'package:lumina/src/umg/viewport/viewport_overlay_lines.dart';
import 'package:lumina/src/umg/viewport/viewport_runtime.dart';
import 'package:lumina/src/umg/viewport/viewport_scene.dart';
import 'package:lumina/src/umg/viewport/viewport_scene_diff.dart';
import 'package:vector_math/vector_math_64.dart';

/// Drives one Viewport: keeps its [runtime] in step with the element's
/// description, decides which frames render ([clock]), and turns the
/// player's input into the orbit, picks and gizmo drags handled inside the
/// widget, reaching the graph only as the Viewport's discrete events
/// ([fire]): `On Picked` per tap, `On Gizmo Preview` at most 30 times a
/// second during a drag, one `On Gizmo Commit` or `On Gizmo Cancel` per
/// drag, `On Camera Changed` on the release of an orbit, pan or zoom.
class LuminaViewportController {
  LuminaViewportController({required this.runtime, required this.fire, int maxFps = 60})
      : clock = LuminaViewportFrameClock(maxFps: maxFps) {
    runtime.onEvent = (event, args) {
      if (event == LuminaWidgetEvents.onSceneReady) clock.markDirty();
      fire(event, args);
    };
    runtime.onOverlaysChanged = clock.markDirty;
  }

  LuminaViewportOverlayLines? _overlay;

  /// Lines the widget adds to the overlay every rendered frame (the gizmo),
  /// runtime frame.
  List<LuminaViewportSegment> Function()? extraSegments;

  /// The overlay lines (skeletons, ghosts, markers, the gizmo) placed in the
  /// preview's scene for the last rendered frame.
  int get overlayLineCount => _overlay?.lineCount ?? 0;

  bool get _wantsOverlay {
    final s = _scene;
    return s != null && (s.skeletonOverlays.isNotEmpty || s.markers.isNotEmpty || s.gizmo != null);
  }

  void _updateOverlay() {
    final s = _scene;
    if (s == null || (!_wantsOverlay && _overlay == null)) return;
    final overlay = _overlay ??= LuminaViewportOverlayLines(runtime.engine, runtime.scene);
    overlay.update([...LuminaViewportOverlayLines.segmentsOf(runtime, s), ...?extraSegments?.call()]);
  }

  /// The longest pause between two `On Gizmo Preview` events, in seconds.
  static const double previewInterval = 1.0 / 30.0;

  /// Degrees the camera turns per pixel of an orbit drag.
  static const double orbitDegreesPerPixel = 0.4;

  final LuminaViewportSceneRuntime runtime;
  final LuminaViewportFrameClock clock;

  /// Delivers an event to the owning widget's graph.
  void Function(String event, Map<String, Object?> args) fire;

  LuminaViewportScene? _scene;

  /// The node the player picked last (what F frames).
  String? selectedNode;

  bool _cameraMoved = false;
  double _now = 0.0;
  double _pendingDt = 0.0;

  /// Events fired so far by kind, for diagnostics.
  final Map<String, int> eventCounts = {};

  void _fire(String event, Map<String, Object?> args) {
    eventCounts[event] = (eventCounts[event] ?? 0) + 1;
    fire(event, args);
  }

  /// The description shown (the element's live map).
  LuminaViewportScene? get scene => _scene;

  /// Applies [scene] (the element's description): only its difference
  /// reaches the preview; a change renders a frame.
  List<LuminaViewportSceneOp> sync(LuminaViewportScene scene) {
    _scene = scene;
    final ops = runtime.apply(scene);
    if (ops.isNotEmpty) clock.markDirty();
    return ops;
  }

  /// The layout changed: a new viewport size renders a frame.
  void resize(int width, int height) {
    runtime.setViewportSize(width, height);
    clock.markDirty();
  }

  /// Advances [dt] seconds; true when this frame renders (the runtime then
  /// advanced by the time since the last rendered frame).
  bool frame(double dt) {
    _now += dt;
    _pendingDt += dt;
    if (!clock.tick(dt, animating: runtime.animating)) return false;
    runtime.advance(_pendingDt);
    _pendingDt = 0.0;
    _updateOverlay();
    return true;
  }

  Map<String, Object?> get _interaction => _scene?.interaction ?? LuminaViewportScene.defaultInteraction();
  bool _allowed(String key) => _interaction[key] != false;

  // --- Camera ----------------------------------------------------------------

  /// A left-drag of ([dx], [dy]) pixels turns the camera.
  void orbitDrag(double dx, double dy) {
    if (!_allowed('orbit')) return;
    runtime.orbit.orbit(-dx * orbitDegreesPerPixel, dy * orbitDegreesPerPixel);
    _cameraMoved = true;
    clock.input();
  }

  /// A right- or middle-drag moves the target across the view.
  void panDrag(double dx, double dy) {
    if (!_allowed('pan')) return;
    runtime.orbit.pan(dx, dy);
    _cameraMoved = true;
    clock.input();
  }

  /// A wheel step or pinch: [factor] below 1 moves in.
  void zoom(double factor) {
    if (!_allowed('zoom')) return;
    runtime.orbit.zoom(factor);
    _cameraMoved = true;
    clock.input();
  }

  /// The orbit / pan / zoom gesture ended: the description takes the
  /// camera and `On Camera Changed` fires once.
  void endCameraGesture() {
    if (!_cameraMoved) return;
    _cameraMoved = false;
    final scene = _scene;
    if (scene != null) {
      runtime.orbit.writeTo(scene);
      runtime.apply(scene);
    }
    final o = runtime.orbit;
    _fire(LuminaWidgetEvents.onCameraChanged, {'yaw': o.yaw, 'pitch': o.pitch, 'distance': o.distance});
  }

  /// F: frames the picked node (every node when none is picked).
  void frameSelection() {
    runtime.frameNode(selectedNode ?? '*');
    _cameraMoved = true;
    clock.input();
    endCameraGesture();
  }

  // --- Picking ---------------------------------------------------------------

  /// A tap at ([x], [y]) pixels: `On Picked` when it hits a pickable node.
  LuminaViewportPick? tap(double x, double y) {
    clock.input();
    if (!_allowed('pick')) return null;
    final hit = runtime.pick(x, y);
    if (hit == null) return null;
    selectedNode = hit.nodeId;
    _fire(LuminaWidgetEvents.onPicked, hit.eventArgs);
    return hit;
  }

  // --- Gizmo -----------------------------------------------------------------

  String? _gizmoNode;
  String? _gizmoBone;
  Map<String, Object?>? _gizmoTransform;
  double _lastPreview = -1.0;

  /// Whether a gizmo drag is running.
  bool get isDraggingGizmo => _gizmoNode != null;

  /// The gizmo's target (node, bone), or null when the gizmo is hidden.
  ({String node, String? bone})? get gizmoTarget {
    final g = _scene?.gizmo;
    if (g == null || g['node'] is! String) return null;
    return (node: g['node']! as String, bone: g['bone'] as String?);
  }

  /// A drag on a gizmo handle starts.
  bool beginGizmoDrag() {
    final target = gizmoTarget;
    if (target == null || runtime.transformOf(target.node) == null) return false;
    _gizmoNode = target.node;
    _gizmoBone = target.bone;
    _gizmoTransform = runtime.transformOf(target.node);
    _lastPreview = -1.0;
    clock.input();
    return true;
  }

  /// The drag moved the target to [transform] (authoring): the node moves
  /// at once; `On Gizmo Preview` fires at most every [previewInterval].
  void updateGizmoDrag(Map<String, Object?> transform) {
    final node = _gizmoNode;
    if (node == null) return;
    _gizmoTransform = LuminaViewportScene.plainTransform(transform);
    if (_gizmoBone == null) runtime.setLocalTransform(node, _gizmoTransform);
    clock.input();
    if (_lastPreview < 0 || _now - _lastPreview >= previewInterval - 1e-9) {
      _lastPreview = _now;
      _fire(LuminaWidgetEvents.onGizmoPreview, _gizmoArgs());
    }
  }

  /// The drag ended: the description takes the transform and `On Gizmo
  /// Commit` fires once with it.
  void commitGizmoDrag() {
    final node = _gizmoNode;
    if (node == null) return;
    final args = _gizmoArgs();
    final scene = _scene;
    if (scene != null && _gizmoBone == null) {
      scene.setNodeTransform(node, _gizmoTransform);
      runtime.apply(scene);
    }
    _gizmoNode = null;
    _gizmoBone = null;
    _fire(LuminaWidgetEvents.onGizmoCommit, args);
  }

  /// Escape during a drag: the node goes back and `On Gizmo Cancel` fires.
  void cancelGizmoDrag() {
    final node = _gizmoNode;
    if (node == null) return;
    runtime.setLocalTransform(node, null);
    _gizmoNode = null;
    _gizmoBone = null;
    clock.markDirty();
    _fire(LuminaWidgetEvents.onGizmoCancel, const {});
  }

  Map<String, Object?> _gizmoArgs() => {
        'node_id': _gizmoNode ?? '',
        'bone': _gizmoBone ?? '',
        'transform': LuminaViewportScene.plainTransform(_gizmoTransform),
      };

  /// The authoring location of node [id] as drawn now.
  Vector3? locationOf(String id) {
    final t = runtime.transformOf(id);
    final l = t?['location'];
    if (l is! List || l.length < 3) return null;
    return Vector3((l[0] as num).toDouble(), (l[1] as num).toDouble(), (l[2] as num).toDouble());
  }

  void dispose() {
    _overlay?.dispose();
    _overlay = null;
    runtime.dispose();
  }
}
