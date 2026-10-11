import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_filament/flutter_filament.dart' hide BlendMode, GizmoMode;
import 'package:lumina/lumina_runtime.dart';
import 'package:vector_math/vector_math_64.dart' show Ray, Vector3;

import 'package:lumina_widgets/src/umg/element_binding.dart';
import 'package:lumina_widgets/src/umg/viewport/gizmo/gizmo_controller.dart';
import 'package:lumina_widgets/src/umg/viewport/gizmo/transform_gizmo.dart';
import 'package:lumina_widgets/src/umg/viewport/viewport_host.dart';
import 'package:lumina_widgets/src/umg/viewport/viewport_overlay_painter.dart';

part 'umg_viewport_input.dart';

/// How a Viewport presents its 3D image now.
enum LuminaUmgViewportPath {
  /// Not rendering (hidden, collapsed, zero-sized, over the limit, or no
  /// engine yet).
  none,

  /// Its own `FilamentWidget` on the shared engine (the editor, PIE, games
  /// presenting through Flutter, the web).
  flutter,

  /// An extra view in the game's own frame, under a cleared hole in the UI.
  direct,
}

/// The UMG **Viewport** element: a real Filament preview scene inside the
/// widget tree, on the shared engine.
///
/// It shows the element's scene description ([LuminaViewportScene], at
/// `elements[name].scene` of [instance]) and follows it: a Blueprint call
/// edits the description, the widget layer refreshes, and only the
/// difference reaches the preview. Orbit (left drag), pan (right or middle
/// drag), zoom (wheel, pinch), pick (tap), the transform gizmo, F (frame
/// the picked node) and Escape (cancel a gizmo drag) run here; the graph
/// receives the Viewport's events (`On Picked`, `On Gizmo Preview` / `Commit`
/// / `Cancel`, `On Camera Changed`, `On Scene Ready`, `On Asset Load Failed`).
///
/// Within a game that presents directly ([LuminaViewportHostScope]), the
/// preview renders as an extra view in the game's frame and the element
/// paints a clear hole in the captured UI (anything under the element is
/// hidden there, and ancestor opacity is not applied to the 3D image).
/// Otherwise it owns a `FilamentWidget`. The [LuminaViewportBudget] caps
/// its render size, how many Viewports render at once (the extra ones show
/// a placeholder) and its frames: an idle Viewport renders nothing.
class LuminaUmgViewport extends StatefulWidget {
  const LuminaUmgViewport({
    super.key,
    this.instance,
    required this.name,
    this.designScene,
    this.background = LuminaViewportEnvironmentMode.sky,
    this.grid = true,
    this.cameraPreset = LuminaViewportCameraPreset.perspective,
    this.orbit = true,
    this.pan = true,
    this.zoom = true,
    this.pick = true,
    this.autoRotate = 0.0,
    this.renderScale = 1.0,
    this.maxFps,
    this.allowFiles = false,
    this.assetProvider,
    this.budget,
    this.onEvent,
    this.onController,
    this.backend = FilamentBackend.defaultBackend,
  });

  /// The Filament backend of the Flutter path's `FilamentWidget` (tests
  /// pass the noop backend).
  final FilamentBackend backend;

  /// The widget instance the element belongs to; null in a preview (the
  /// designer), where [designScene] is shown.
  final Map<String, Object?>? instance;

  /// The element's designer name.
  final String name;

  /// The design-time preview description (shown when the element has no
  /// scene yet: the designer canvas, or a fresh instance).
  final Map<String, Object?>? designScene;

  /// The element's Details: background mode, grid, camera preset and
  /// interaction toggles, seeded into a new description.
  final String background;
  final bool grid;
  final String cameraPreset;
  final bool orbit;
  final bool pan;
  final bool zoom;
  final bool pick;
  final double autoRotate;

  /// Fraction of the layout size × device pixel ratio rendered (0.25–1).
  final double renderScale;

  /// The frame rate cap (null: 60).
  final int? maxFps;

  /// Whether `Play Animation File` may read files (editor panels).
  final bool allowFiles;

  /// Where meshes are read (null: [LuminaAssets]).
  final LuminaAssetProvider? assetProvider;

  /// The budget this Viewport counts against (null: the game's
  /// [LuminaViewportHost], else [LuminaViewportBudget.shared]).
  final LuminaViewportBudget? budget;

  /// Every event the Viewport fires, as it reaches the graph.
  final void Function(String event, Map<String, Object?> args)? onEvent;

  /// The controller once the preview exists, null when it is torn down
  /// (tests, the editor's adapters).
  final ValueChanged<LuminaViewportController?>? onController;

  @override
  State<LuminaUmgViewport> createState() => LuminaUmgViewportState();
}

/// The state of a [LuminaUmgViewport] (public for tests and adapters).
class LuminaUmgViewportState extends State<LuminaUmgViewport> {
  final Map<String, Object?> _localElement = <String, Object?>{'type': 'viewport', 'visibility': 'Visible'};
  LuminaUmgInstanceBinding? _binding;
  LuminaViewportHost? _host;
  LuminaViewportController? _controller;
  LuminaViewportDirectView? _directView;
  final FocusNode _focus = FocusNode(debugLabel: 'UMG Viewport');
  final ValueNotifier<int> _frames = ValueNotifier<int>(0);
  late final _ViewportFrameLimiter _limiter = _ViewportFrameLimiter(this);
  late final _ViewportInput _input = _ViewportInput(this);

  Size _layout = Size.zero;
  (int, int) _render = (0, 0);
  bool _hasSlot = false;
  bool _refused = false;

  /// Diff ops applied by binding refreshes (none for an unrelated element).
  int refreshOps = 0;

  /// The preview's controller, once it exists.
  LuminaViewportController? get controller => _controller;

  /// How the 3D image is presented now.
  LuminaUmgViewportPath get path => _controller == null
      ? LuminaUmgViewportPath.none
      : (_directView != null ? LuminaUmgViewportPath.direct : LuminaUmgViewportPath.flutter);

  /// The render size in pixels.
  (int, int) get renderSize => _render;

  /// Whether the "Viewport limit reached" placeholder shows.
  bool get showsLimitPlaceholder => _refused;

  Map<String, Object?> get _element => LuminaUmgElementBinding.element(widget.instance, widget.name) ?? _localElement;

  LuminaViewportBudget get _budget => widget.budget ?? _host?.budget ?? LuminaViewportBudget.shared;

  @override
  void initState() {
    super.initState();
    _seedScene();
  }

  /// A new description gets the Details and the design-time content.
  void _seedScene() {
    final element = _element;
    if (element[LuminaViewportScene.sceneKey] is Map) return;
    final design = widget.designScene;
    final scene = LuminaViewportScene(
      design == null ? null : LuminaViewportScene.plain(design) as Map<String, Object?>,
    );
    if (design == null) {
      scene
        ..setEnvironment(widget.background)
        ..gridVisible = widget.grid
        ..setInteraction(
          orbit: widget.orbit,
          pan: widget.pan,
          zoom: widget.zoom,
          pick: widget.pick,
          autoRotate: widget.autoRotate,
        )
        ..setCameraPreset(widget.cameraPreset);
    }
    element[LuminaViewportScene.sceneKey] = scene.json;
  }

  LuminaViewportScene get _scene => LuminaViewportScene.of(_element);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final binding = LuminaUmgElementBinding.maybeOf(context);
    if (!identical(binding, _binding)) {
      _binding?.removeListener(_onRefresh);
      _binding = binding;
      _binding?.addListener(_onRefresh);
    }
    final host = LuminaViewportHostScope.maybeOf(context);
    if (!identical(host, _host)) {
      _host = host;
      _releaseSlot();
    }
    // The game switched path (Flutter ↔ Direct): rebuild the preview.
    final wantsDirect = _wantsDirect;
    if (_controller != null && wantsDirect != (_directView != null)) _teardown();
  }

  @override
  void didUpdateWidget(LuminaUmgViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.instance, widget.instance) || oldWidget.name != widget.name) {
      _seedScene();
      _onRefresh();
    } else if (widget.designScene != oldWidget.designScene && widget.instance == null && widget.designScene != null) {
      _localElement.remove(LuminaViewportScene.sceneKey);
      _seedScene();
      _onRefresh();
    }
    if (oldWidget.maxFps != widget.maxFps) _limiter.maxFps = widget.maxFps ?? LuminaViewportBudget.editorMaxFps;
  }

  @override
  void dispose() {
    _binding?.removeListener(_onRefresh);
    _teardown();
    _releaseSlot();
    _focus.dispose();
    _frames.dispose();
    super.dispose();
  }

  /// The widget layer refreshed: apply the description's difference (none
  /// when another element changed).
  void _onRefresh() {
    final c = _controller;
    if (c == null || !mounted) return;
    refreshOps += c.sync(_scene).length;
    final visible = LuminaUmgElementBinding.isVisible(_element);
    if ((visible != _hasSlot && !_refused) || _hasOverlays != _overlaysShown) setState(() {});
  }

  /// Whether the description shows a skeleton, a marker or the gizmo (the
  /// overlay layer repaints every rendered frame only then).
  bool get _hasOverlays {
    final scene = _scene;
    return scene.skeletonOverlays.isNotEmpty || scene.markers.isNotEmpty || scene.gizmo != null;
  }

  bool _overlaysShown = false;

  bool get _wantsDirect => _host?.presentingDirectly == true && _host?.engine != null;

  // --- Budget ----------------------------------------------------------------

  bool _onScreen() {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return false;
    final r = box.localToGlobal(Offset.zero) & box.size;
    final view = View.maybeOf(context);
    if (view == null) return true;
    final screen = Offset.zero & (view.physicalSize / view.devicePixelRatio);
    return r.overlaps(screen);
  }

  void _updateSlot() {
    if (!mounted) return;
    final counts = LuminaViewportBudget.counts(
      visibility: LuminaUmgElementBinding.visibility(_element),
      width: _layout.width,
      height: _layout.height,
      onScreen: _onScreen(),
      tabActive: TickerMode.valuesOf(context).enabled,
    );
    final budget = _budget;
    bool has;
    bool refused;
    if (!counts) {
      budget.release(this);
      has = false;
      refused = false;
    } else {
      has = budget.acquire(this);
      refused = !has;
    }
    if (has != _hasSlot || refused != _refused) {
      if (!has) _teardown();
      setState(() {
        _hasSlot = has;
        _refused = refused;
      });
    }
  }

  void _releaseSlot() {
    _budget.release(this);
    _hasSlot = false;
  }

  // --- Preview lifetime ------------------------------------------------------

  void _attach(LuminaViewportSceneRuntime runtime) {
    final controller = LuminaViewportController(
      runtime: runtime,
      maxFps: widget.maxFps ?? LuminaViewportBudget.editorMaxFps,
      fire: _fire,
    );
    _controller = controller;
    controller.resize(math.max(1, _layout.width.round()), math.max(1, _layout.height.round()));
    controller.sync(_scene);
    widget.onController?.call(controller);
    _frames.value++;
  }

  void _fire(String event, Map<String, Object?> args) {
    final instance = widget.instance;
    if (instance != null) LuminaUserWidgets.fire(instance, widget.name, event, args);
    widget.onEvent?.call(event, args);
  }

  void _teardown() {
    final direct = _directView;
    if (direct != null) _host?.unregister(direct);
    _directView = null;
    final c = _controller;
    _controller = null;
    if (c != null) {
      widget.onController?.call(null);
      c.dispose();
    }
  }

  /// The Direct path: a preview on the game's engine, drawn by the game.
  void _attachDirect() {
    final host = _host;
    final engine = host?.engine;
    if (host == null || engine == null || _controller != null) return;
    final runtime = LuminaViewportSceneRuntime(
      engine: engine,
      assetProvider: widget.assetProvider,
      allowFiles: widget.allowFiles,
    );
    _attach(runtime);
    final view = LuminaViewportDirectView(
      view: runtime.view,
      rect: _physicalRect,
      frame: (dt) {
        final c = _controller;
        if (c == null) return;
        if (c.frame(dt)) _frames.value++;
      },
    );
    _directView = view;
    host.register(view);
  }

  Rect? _physicalRect() {
    if (!mounted) return null;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    final dpr = View.maybeOf(context)?.devicePixelRatio ?? 1.0;
    final topLeft = box.localToGlobal(Offset.zero);
    final bottomRight = box.localToGlobal(box.size.bottomRight(Offset.zero));
    _host?.windowHeight = (View.maybeOf(context)?.physicalSize.height ?? 0.0);
    return Rect.fromPoints(topLeft * dpr, bottomRight * dpr);
  }

  void _onLayout(Size size) {
    if (size == _layout) return;
    _layout = size;
    final dpr = View.maybeOf(context)?.devicePixelRatio ?? 1.0;
    _render = LuminaViewportBudget.renderSize(
      size.width,
      size.height,
      devicePixelRatio: dpr,
      renderScale: widget.renderScale,
    );
    final c = _controller;
    if (c != null) {
      c.resize(math.max(1, size.width.round()), math.max(1, size.height.round()));
      // The FilamentWidget resizes its view after this frame; render again then.
      SchedulerBinding.instance.addPostFrameCallback(
        (_) => SchedulerBinding.instance.addPostFrameCallback((_) => c.clock.markDirty()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(
          constraints.maxWidth.isFinite ? constraints.maxWidth : 320.0,
          constraints.maxHeight.isFinite ? constraints.maxHeight : 240.0,
        );
        _onLayout(size);
        SchedulerBinding.instance.addPostFrameCallback((_) => _updateSlot());
        if (_refused) return _LuminaUmgViewportPlaceholder(text: 'Viewport limit reached (${_budget.maxViewports})');
        if (!_hasSlot || !LuminaUmgElementBinding.isVisible(_element)) {
          return SizedBox(width: size.width, height: size.height);
        }
        _overlaysShown = _hasOverlays;
        final Widget image;
        if (_wantsDirect) {
          if (_controller == null) {
            SchedulerBinding.instance.addPostFrameCallback((_) => mounted ? setState(_attachDirect) : null);
          }
          image = const CustomPaint(painter: _HolePainter(), child: SizedBox.expand());
        } else {
          image = FilamentWidget(
            key: const ValueKey('lumina-umg-viewport-filament'),
            debugLabel: 'UMG Viewport ${widget.name}',
            backend: widget.backend,
            decorated: false,
            renderResolution: Size(math.max(1, _render.$1).toDouble(), math.max(1, _render.$2).toDouble()),
            frameLimiter: _limiter,
            onSceneCreated: (engine, scene, camera, view) => _attach(
              LuminaViewportSceneRuntime(
                engine: engine,
                scene: scene,
                view: view,
                camera: camera,
                assetProvider: widget.assetProvider,
                allowFiles: widget.allowFiles,
              ),
            ),
            onDispose: _teardown,
          );
        }
        return _input.wrap(
          SizedBox(
            width: size.width,
            height: size.height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                image,
                if (_hasOverlays)
                  IgnorePointer(
                    child: CustomPaint(
                      painter: LuminaViewportOverlayPainter(
                        controller: _controller,
                        gizmo: () => luminaViewportGizmoModel(_controller),
                        activeHandle: _input.activeHandle,
                        dragging: _input.draggingGizmo,
                        repaint: _frames,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Renders only the frames the Viewport's controller asks for.
class _ViewportFrameLimiter extends FilamentFrameLimiter {
  _ViewportFrameLimiter(this.state);

  final LuminaUmgViewportState state;
  int maxFps = LuminaViewportBudget.editorMaxFps;
  Duration? _last;

  @override
  void configure({required int targetFps, required bool vsync}) {}

  @override
  void reset() => _last = null;

  @override
  bool shouldRender(Duration timestamp) {
    final last = _last;
    _last = timestamp;
    final c = state._controller;
    if (c == null || !state.mounted) return false;
    final dt = last == null ? 1 / 60 : math.min(0.25, (timestamp - last).inMicroseconds / 1e6);
    if (dt <= 0) return false;
    if (!state._onScreen()) return false;
    final render = c.frame(dt);
    if (render) state._frames.value++;
    return render;
  }
}

/// The Direct path: the element clears its rectangle in the captured UI so
/// the game's frame shows the Viewport's view there.
class _HolePainter extends CustomPainter {
  const _HolePainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..blendMode = BlendMode.clear);
  }

  @override
  bool shouldRepaint(covariant _HolePainter oldDelegate) => false;
}

class _LuminaUmgViewportPlaceholder extends StatelessWidget {
  const _LuminaUmgViewportPlaceholder({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xFF15171C),
      border: Border.all(color: const Color(0xFF3A3F4B)),
    ),
    child: Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Color(0xFFB0B6C2), fontSize: 12),
      ),
    ),
  );
}
