import 'package:flutter/scheduler.dart';
import 'package:flutter_filament/flutter_filament.dart' show FilamentCamera, FilamentEngine, FilamentScene, FilamentView, FilamentWidget;
import 'package:lumina/lumina.dart' show LuminaUnits;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/features/main_editor/services/editor_level_scene.dart';
import 'package:lumina_ui/ui/features/main_editor/services/editor_view_layers.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';

/// Aims a [LevelSceneView]'s camera: called when its scene is created, when
/// the level's scene comes or goes, on a resize and on every rendered frame,
/// so a pose that moves (a gizmo drag, a Details edit, a playing sequence)
/// never lags.
typedef LevelSceneAim = void Function(LevelSceneViewState view);

/// A second view of the level: a FilamentWidget on the shared engine whose
/// view draws the level viewport's own scene (`EditorViewModel.levelScene`),
/// not a copy of it, through a camera its owner aims. While the level's scene
/// is not available it draws its own empty scene.
///
/// The Sequencer's viewport and the level viewport's camera preview are
/// built on it. Its Filament view exists only while it is mounted: a hidden
/// view costs nothing.
class LevelSceneView extends StatefulWidget {
  const LevelSceneView({
    super.key,
    required this.editorViewModel,
    required this.debugLabel,
    required this.onAim,
    this.visibleLayers = EditorViewLayers.levelViewport,
    this.isPaused = false,
    this.placeholder,
    this.filamentKey,
  });

  final EditorViewModel editorViewModel;
  final String debugLabel;
  final LevelSceneAim onAim;

  /// The [EditorViewLayers] this view draws.
  final int visibleLayers;

  /// Stops rendering (the level viewport's tab is not showing).
  final bool isPaused;

  /// Shown over the view while it cannot draw the level's scene.
  final Widget? placeholder;

  /// Key of the inner FilamentWidget.
  final Key? filamentKey;

  @override
  State<LevelSceneView> createState() => LevelSceneViewState();
}

class LevelSceneViewState extends State<LevelSceneView> {
  FilamentEngine? _engine;
  FilamentView? _view;
  FilamentCamera? _camera;

  /// The FilamentWidget's own (empty) scene, drawn while the level's is not
  /// available.
  FilamentScene? _ownScene;
  EditorLevelScene? _drawn;
  Size _size = Size.zero;
  int _appliedQualityRevision = -1;
  int? _appliedLayers;

  EditorViewModel get _evm => widget.editorViewModel;

  /// Whether this view draws the level viewport's scene right now.
  bool get drawsLevelScene => _drawn != null;

  /// The level scene drawn, or null.
  EditorLevelScene? get drawn => _drawn;

  FilamentView? get view => _view;
  FilamentCamera? get camera => _camera;

  /// The widget's size in logical pixels.
  Size get size => _size;

  /// Width / height of the view; 16:9 before the first layout.
  double get aspect => _size.width > 0 && _size.height > 0 ? _size.width / _size.height : 16 / 9;

  /// Aims the camera now (the owner's pose changed).
  void aim() {
    final camera = _camera;
    if (camera == null || camera.isDisposed) return;
    widget.onAim(this);
  }

  @override
  void initState() {
    super.initState();
    _evm.levelScene.addListener(_attachLevelScene);
    _evm.addListener(_onEditorChanged);
  }

  @override
  void didUpdateWidget(covariant LevelSceneView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.editorViewModel != widget.editorViewModel) {
      oldWidget.editorViewModel.levelScene.removeListener(_attachLevelScene);
      oldWidget.editorViewModel.removeListener(_onEditorChanged);
      widget.editorViewModel.levelScene.addListener(_attachLevelScene);
      widget.editorViewModel.addListener(_onEditorChanged);
      _attachLevelScene();
    }
    _applyLayers();
  }

  @override
  void dispose() {
    _evm.levelScene.removeListener(_attachLevelScene);
    _evm.removeListener(_onEditorChanged);
    _releaseNative();
    super.dispose();
  }

  /// Points the view back at its own scene before the FilamentWidget frees
  /// the view; the level's scene stays the level viewport's.
  void _releaseNative() {
    final view = _view, own = _ownScene;
    if (view != null && own != null && _drawn != null) {
      try {
        view.scene = own;
      } catch (_) {}
    }
    _drawn = null;
    _view = null;
    _camera = null;
    _ownScene = null;
    _engine = null;
    _appliedLayers = null;
  }

  void _onSceneCreated(FilamentEngine engine, FilamentScene scene, FilamentCamera camera, FilamentView view) {
    _engine = engine;
    _ownScene = scene;
    _camera = camera;
    _view = view;
    view.setDynamicLightingOptions(LuminaUnits.dynamicLightingNear, LuminaUnits.dynamicLightingFar);
    _applyQuality(force: true);
    _applyLayers();
    _attachLevelScene();
    _rebuild();
  }

  void _applyLayers() {
    final view = _view;
    if (view == null || _appliedLayers == widget.visibleLayers) return;
    _appliedLayers = widget.visibleLayers;
    EditorViewLayers.show(view, widget.visibleLayers);
  }

  /// Draws the level viewport's scene when it is published on this view's
  /// engine, else this view's own empty scene.
  void _attachLevelScene() {
    final view = _view, own = _ownScene;
    if (view == null || own == null) return;
    final shared = _evm.levelScene.value;
    final usable = shared != null && identical(shared.engine, _engine) && !shared.scene.isDisposed;
    final was = _drawn;
    if (usable) {
      if (!identical(_drawn, shared)) view.scene = shared.scene;
      _drawn = shared;
    } else {
      if (_drawn != null) view.scene = own;
      _drawn = null;
    }
    aim();
    if ((was == null) != (_drawn == null)) _rebuild();
  }

  void _onEditorChanged() {
    _applyQuality();
    aim();
  }

  /// Rebuilds now, or after the frame when the notification came while the
  /// tree is being built or torn down (the level viewport retracts its scene
  /// from its own dispose).
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

  void _applyQuality({bool force = false}) {
    final view = _view;
    if (view == null) return;
    if (!force && _evm.qualityRevision == _appliedQualityRevision) return;
    _appliedQualityRevision = _evm.qualityRevision;
    _evm.quality.applyToView(view);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final size = constraints.biggest;
      if (size != _size && size.isFinite) {
        _size = size;
        // After the FilamentWidget resized its own camera projection.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) aim();
        });
      }
      final placeholder = widget.placeholder;
      return Stack(
        children: [
          Positioned.fill(
            child: FilamentWidget(
              key: widget.filamentKey,
              debugLabel: widget.debugLabel,
              isPaused: widget.isPaused,
              onSceneCreated: _onSceneCreated,
              onDispose: _releaseNative,
              // A resize resets the projection; the camera is re-aimed every
              // frame (a few calls), so it never lags a resize or a moving pose.
              onFrame: (_, _) => aim(),
            ),
          ),
          if (placeholder != null && _view != null && !drawsLevelScene) Center(child: placeholder),
        ],
      );
    });
  }
}
