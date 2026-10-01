import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_filament/flutter_filament.dart' show FilamentCamera, FilamentView;
import 'package:lumina/lumina.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/services/editor_view_layers.dart';
import 'package:lumina_ui/ui/features/main_editor/services/viewport_picker.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/level_scene_view.dart';
import 'package:lumina_ui/ui/features/main_editor/views/viewport_widget.dart' show kViewportFovDegrees;
import '../../models/sequencer_viewport_camera.dart';
import '../../view_models/sequencer_view_model.dart';

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
    var fov = pose.fovDegrees;
    final locked = _lockedCamera != null;
    if (locked) {
      final gate = _filmGate(size);
      if (gate.height > 0 && gate.height < size.height) {
        final half = math.atan(math.tan(fov * math.pi / 360) * size.height / gate.height);
        fov = half * 360 / math.pi;
      }
    }
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
          },
          onPointerMove: (e) {
            _setButtons(e.buttons);
            _onPointerMove(e);
          },
          onPointerUp: (e) => _setButtons(e.buttons),
          onPointerCancel: (_) => _setButtons(0),
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
                  visibleLayers: locked != null ? EditorViewLayers.cameraView : EditorViewLayers.levelViewport,
                  placeholder: const Text('The level viewport is not running: open the level tab once to start it.',
                      style: TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
                ),
              ),
              if (locked != null && !gate.isEmpty) ..._letterbox(gate),
              Positioned(left: 8, top: 8, child: _buildHud(locked)),
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
