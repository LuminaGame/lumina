import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:lumina/lumina_runtime.dart';
import 'package:lumina_core/lumina_core.dart' show EngineLoggerService;
import 'package:lumina_widgets/src/lumina_widgets_binding.dart';
import 'package:lumina_widgets/src/game/hud_overlay.dart';
import 'package:lumina_widgets/src/game/render_space.dart';
import 'package:lumina_widgets/src/game/screen_resolution_box.dart';
import 'package:lumina_widgets/src/game/ui_capture.dart';
import 'package:lumina_widgets/src/game/window_surface.dart';

/// Controls whether embedded game previews allocate an additional frame driver.
/// Configure this before mounting previews; changing it does not remount games.
class LuminaGameHostConfiguration extends InheritedWidget {
  const LuminaGameHostConfiguration({
    super.key,
    required super.child,
    this.allowHeadlessFrameDriver = true,
  });

  final bool allowHeadlessFrameDriver;

  static bool allowsHeadlessFrameDriver(BuildContext context) =>
      context
          .getInheritedWidgetOfExactType<LuminaGameHostConfiguration>()
          ?.allowHeadlessFrameDriver ??
      true;

  @override
  bool updateShouldNotify(LuminaGameHostConfiguration oldWidget) =>
      allowHeadlessFrameDriver != oldWidget.allowHeadlessFrameDriver;
}

/// Flutter widget that embeds the `FilamentWidget` viewport and drives the [LuminaGame] loop via [LuminaFrameDriver].
///
/// The widget is the game host: it calls [LuminaGame.mountGame] and `beginPlay()` on
/// the mounted world once `FilamentWidget` has created the scene.
///
/// Play control:
/// - [paused] is declarative: flipping it calls [LuminaGame.pause] / [LuminaGame.resume]
///   once the scene exists (and on scene creation if it starts `true`).
/// - [onPlayStateChanged] receives every [LuminaPlayState] transition of [game]
///   for the widget's lifetime — bind an editor toolbar to it.
///
/// Frame driver:
/// - The `FilamentWidget` is the only renderer of the game's view, on both
///   presentation paths, so the view's temporal history (TAA, upscalers,
///   frame generation) advances once per shown frame.
/// - With [useHeadlessSwapChain] (default `true`; the name is historical, no
///   swap chain is created) the world is ticked by a [LuminaFrameDriver]
///   without a swap chain: a vsync-derived, frame-paced delta time
///   ([onFrameDriver] receives the driver).
/// - With `false` the ticker calls [LuminaGame.tickGame] with the real
///   interval between ticked refreshes.
///
/// Frame rate:
/// Presentation ([allowDirectPresentation], a game screen):
/// - Flutter (the default): the frame is read back and shown by Flutter.
/// - Direct, when [LuminaGamePresentation] asks for it (the project's or
///   the player's setting, or frame generation in force): the frame is
///   rendered into a swap chain on the runner's presentation window
///   ([LuminaWindowSurface]) and presented by Filament; the HUD and
///   [viewportOverlay] stay Flutter widgets (layout, input) whose pixels
///   are captured when they change ([LuminaUiCapture]) and blended by
///   Filament over every presented frame, generated frames included. VSync
///   is the swap chain's present mode, Target FPS the limiter. Where it
///   cannot run (the web, no Vulkan, no presentation window) the widget
///   stays on Flutter and reports why ([LuminaGamePresentation.reportFallback]).
/// - Frame generation the player chose asks for Direct by itself. While the
///   game is shown through Flutter (the player chose Flutter, Direct fell
///   back or is starting, a host without Direct) the widget says so
///   ([LuminaGamePresentation.setFlutterPresentation]) and frame generation
///   is not applied: the game user settings record it as a rendering
///   fallback (`Frame generation is off: the game presents through Flutter
///   (reason).`, logged once) and apply it again when Direct runs.
///
/// Frame rate:
/// - [targetFps] and [vsyncEnabled] are the project's settings: the defaults of
///   [LuminaGameFramePacing], which the player's choice (Set Target FPS / Set
///   VSync Enabled + Apply Scalability Settings, or the one restored from
///   `GameUserSettings.json`) overrides. The widget follows what is in force
///   at once: the world ticks and the view renders on the same display
///   refreshes ([FilamentFrameLimiter]); the frame is presented by Flutter on
///   the display's vsync, so no target goes above the refresh rate.
class LuminaGameWidget extends StatefulWidget {
  final LuminaGame game;
  final LuminaHudBuilder? hudBuilder;

  /// Declarative pause flag forwarded to [LuminaGame.pause] / [LuminaGame.resume].
  final bool paused;

  /// Called on every play-state transition of [game].
  final void Function(LuminaPlayState state)? onPlayStateChanged;

  /// Whether the world is ticked by a [LuminaFrameDriver] (frame-paced
  /// delta time). The name is historical: no swap chain is created and the
  /// driver never renders the view.
  final bool useHeadlessSwapChain;

  /// The project's target frame rate in FPS (0 = unlimited / display
  /// refresh rate), in force until the player chooses one
  /// ([LuminaGameFramePacing]).
  final int targetFps;

  /// The project's VSync, in force until the player chooses
  /// ([LuminaGameFramePacing]).
  final bool vsyncEnabled;

  /// Camera views sharing this widget's frame, swap chain and presentation.
  /// The callback configures each view's viewport in physical pixels.
  final FilamentFrameViewsCallback? frameViews;

  /// Whether the frame sits in the bordered viewport panel
  /// (`FilamentWidget.decorated`); a game screen fills edge to edge.
  final bool decorated;

  /// Whether the frame renders at the display's physical pixels
  /// (`FilamentWidget.physicalResolution`), what a game screen does.
  final bool physicalResolution;

  /// Whether the view follows the player's screen resolution
  /// (`LuminaGameDisplay.renderResolution`, set by `Set Screen Resolution`):
  /// rendered at that size and scaled to fill the widget with its aspect
  /// ratio kept. What a game screen does; tools render at their own size.
  final bool followScreenResolution;

  /// Laid out over the view (and the HUD) in the game's render space: with
  /// a screen resolution, inside the letterboxed picture at that resolution's
  /// logical size ([LuminaRenderSpace.layoutSize]); else over the whole view.
  /// The game host puts the game's UI and its pointer surface here.
  final Widget? viewportOverlay;

  const LuminaGameWidget({
    super.key,
    required this.game,
    this.hudBuilder,
    this.paused = false,
    this.onPlayStateChanged,
    this.useHeadlessSwapChain = true,
    this.targetFps = 0,
    this.vsyncEnabled = false,
    this.frameViews,
    this.decorated = true,
    this.physicalResolution = false,
    this.followScreenResolution = false,
    this.viewportOverlay,
    this.allowDirectPresentation = false,
    this.presentation = LuminaPresentationMode.flutter,
    this.onFrameDriver,
  });

  /// Receives the frame driver ticking the world once the scene exists
  /// ([LuminaFrameDriver.hitchCount]); not called without one
  /// ([useHeadlessSwapChain] false or
  /// [LuminaGameHostConfiguration.allowHeadlessFrameDriver] false).
  final ValueChanged<LuminaFrameDriver>? onFrameDriver;

  /// Whether this game may present directly into the runner's window (a
  /// built game's screen; never the editor's viewport or Play-In-Editor,
  /// whose Flutter UI must stay on top of the frame).
  final bool allowDirectPresentation;

  /// The project's presentation (Project Settings > Presentation), the
  /// default of [LuminaGamePresentation] where the player chose none.
  final LuminaPresentationMode presentation;

  @override
  State<LuminaGameWidget> createState() => _LuminaGameWidgetState();
}

class _LuminaGameWidgetState extends State<LuminaGameWidget>
    with SingleTickerProviderStateMixin {
  Ticker? _ticker;
  LuminaFrameDriver? _frameDriver;
  StreamSubscription<LuminaPlayState>? _playStateSub;
  int _clockOffsetNanos = 0;
  bool _calibrated = false;

  /// Shared with the FilamentWidget: the world ticks on the refreshes the
  /// view renders on.
  final FilamentFrameLimiter _limiter = FilamentFrameLimiter();
  LuminaFramePacingSettings _pacing = LuminaGameFramePacing.settings.value;
  int _lastTickMicros = -1;

  /// Direct presentation: what the game asks for, the runner's window, the
  /// overlay the UI pictures go to, and whether frames go there now.
  LuminaPresentationDecision _presentation = LuminaGamePresentation.requested.value;
  LuminaWindowSurface? _surface;
  FilamentUiOverlay? _uiOverlay;
  bool _presentingDirectly = false;

  /// Whether this process asked for the ray tracing / DLSS extensions.
  static bool _renderingExtensionsRequested = false;

  @override
  void initState() {
    super.initState();
    LuminaWidgets.ensureInitialized();
    // Ray tracing and DLSS (the game user settings) need Vulkan extensions
    // asked for before the shared engine exists; the FilamentWidget built
    // below creates it.
    if (!kIsWeb && !_renderingExtensionsRequested) {
      _renderingExtensionsRequested = true;
      // OpenDLSS-NR's device features only for a project that opted in.
      LuminaRtxController.requestExtensions(neuralRendering: LuminaNeuralRendering.projectOptIn?.active ?? false);
    }
    _subscribePlayState();
    LuminaGameFramePacing.setProjectDefaults(targetFps: widget.targetFps, vsyncEnabled: widget.vsyncEnabled);
    _pacing = LuminaGameFramePacing.settings.value;
    LuminaGameFramePacing.settings.addListener(_onPacingChanged);
    if (widget.allowDirectPresentation) {
      LuminaGamePresentation.setProjectDefault(widget.presentation);
      LuminaGamePresentation.requested.addListener(_onPresentationRequested);
      // After `requested`, the decision is updated: the reason Flutter shows
      // the game is read from it.
      LuminaGamePresentation.decision.addListener(_publishFlutterPresentation);
      _onPresentationRequested();
    }
  }

  /// Why this game is shown through Flutter now (null: presented directly,
  /// or no scene yet).
  String? get _flutterPresentationReason {
    if (!_sceneReady || _presentingDirectly) return null;
    if (!widget.allowDirectPresentation) return 'the host presents through Flutter';
    final decision = LuminaGamePresentation.decision.value;
    if (LuminaGamePresentation.requested.value.mode == LuminaPresentationMode.direct) {
      return decision.mode == LuminaPresentationMode.flutter
          ? (decision.reason ?? 'Direct presentation unavailable')
          : 'Direct presentation starting';
    }
    return decision.reason ?? 'project setting';
  }

  /// Tells the game user settings whether (and why) Flutter shows the game:
  /// frame generation is not applied while it does.
  void _publishFlutterPresentation() {
    final reason = _flutterPresentationReason;
    // Never clear what another game host published.
    if (reason == null && LuminaGamePresentation.flutterPresentation.value != _publishedReason) {
      _publishedReason = null;
      return;
    }
    LuminaGamePresentation.setFlutterPresentation(reason);
    _publishedReason = reason;
  }

  bool _sceneReady = false;
  String? _publishedReason;

  /// Direct or Flutter asked for (setting, player choice, frame generation).
  void _onPresentationRequested() {
    final next = LuminaGamePresentation.requested.value;
    final wantsDirect = next.mode == LuminaPresentationMode.direct;
    if (wantsDirect && kIsWeb) {
      LuminaGamePresentation.reportFallback('unsupported on the web (the browser presents the canvas)');
    }
    final surface = wantsDirect && !kIsWeb ? (_surface ?? LuminaWindowSurface.forGame()) : null;
    if (wantsDirect && !kIsWeb && surface == null) {
      LuminaGamePresentation.reportFallback('no game window channel (not a generated game runner)');
    }
    if (!mounted) return;
    setState(() {
      _presentation = next;
      _surface = surface;
    });
    _publishFlutterPresentation();
  }

  /// The FilamentWidget presents directly, or fell back with a reason.
  void _onPresentationChanged(FilamentPresentationStatus status) {
    final direct = status.kind == FilamentPresentationKind.direct;
    // Without a window the reason was reported when Direct was asked for.
    if (_presentation.mode == LuminaPresentationMode.direct && _surface != null) {
      LuminaGamePresentation.reportFallback(direct ? null : status.reason);
    }
    EngineLoggerService().log(
        direct
            ? 'Presentation: Direct (${_presentation.reason ?? 'requested'})'
            : 'Presentation: Flutter${status.reason == null ? '' : ' (Direct unavailable: ${status.reason})'}',
        level: direct || status.reason == null ? 'info' : 'warning',
        source: 'LuminaGameWidget');
    if (direct != _presentingDirectly && mounted) setState(() => _presentingDirectly = direct);
    _publishOverlay();
    _publishFlutterPresentation();
  }

  /// The app-wide capture ([LuminaUiCaptureRoot]) follows this game's
  /// overlay while it presents directly.
  void _publishOverlay() {
    final overlay = _presentingDirectly ? _uiOverlay : null;
    if (overlay != null || identical(LuminaUiCapture.directOverlay.value, _publishedOverlay)) {
      LuminaUiCapture.directOverlay.value = overlay;
      _publishedOverlay = overlay;
    }
  }

  FilamentUiOverlay? _publishedOverlay;

  /// A new target frame rate or VSync is in force (Apply Scalability
  /// Settings, the project's settings changed).
  void _onPacingChanged() {
    final next = LuminaGameFramePacing.settings.value;
    if (next == _pacing || !mounted) return;
    setState(() => _pacing = next);
    _configureLimiter();
  }

  void _configureLimiter() => _limiter.configure(targetFps: _pacing.targetFps, vsync: _pacing.vsyncEnabled);

  void _subscribePlayState() {
    _playStateSub?.cancel();
    _playStateSub = widget.game.playStateStream.listen((state) {
      widget.onPlayStateChanged?.call(state);
    });
  }

  @override
  void didUpdateWidget(LuminaGameWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.game, widget.game)) {
      _subscribePlayState();
    }
    if (oldWidget.paused != widget.paused) {
      _applyPaused();
    }
    if (oldWidget.targetFps != widget.targetFps || oldWidget.vsyncEnabled != widget.vsyncEnabled) {
      LuminaGameFramePacing.setProjectDefaults(targetFps: widget.targetFps, vsyncEnabled: widget.vsyncEnabled);
    }
  }

  void _applyPaused() {
    if (widget.game.playState == LuminaPlayState.stopped) return;
    if (widget.paused) {
      widget.game.pause();
    } else {
      widget.game.resume();
    }
  }

  void _onSceneCreated(
    FilamentEngine engine,
    FilamentScene scene,
    FilamentCamera camera,
    FilamentView view,
  ) {
    // A game mounted by another scene keeps running there.
    if (!widget.game.mountGame(engine, scene, view: view)) return;

    final world = widget.game.world;
    // Before BeginPlay applies the user settings: frame generation is not
    // applied while Flutter shows the game.
    _sceneReady = true;
    _publishFlutterPresentation();
    // The widget is the game's host: begin play so the ticker may drive the world.
    world?.beginPlay();
    if (world != null &&
        widget.useHeadlessSwapChain &&
        LuminaGameHostConfiguration.allowsHeadlessFrameDriver(context)) {
      // No swap chain: the FilamentWidget renders the view. A second render
      // here advanced the view's temporal history twice per shown frame and,
      // with frame generation, stalled the readback of the shown frame.
      _frameDriver = LuminaFrameDriver(world, renderer: engine.createRenderer(), view: view);
      // The driver's pacer for the world's delta time; the presented rate
      // is the limiter's.
      if (_pacing.targetFps > 0) _frameDriver!.targetFrameRate = _pacing.targetFps.toDouble();
      widget.onFrameDriver?.call(_frameDriver!);
    }
    _configureLimiter();

    if (widget.paused) {
      _applyPaused();
    }

    _ticker = createTicker((elapsed) {
      if (!mounted) return;
      final flutterNowNanos = elapsed.inMicroseconds * 1000;
      if (!_calibrated) {
        final steadyNow = engine.steadyClockTimeNano;
        _clockOffsetNanos = steadyNow - flutterNowNanos;
        _calibrated = true;
      }
      // Only on the refreshes the view renders on (the target frame rate).
      final frameTime = SchedulerBinding.instance.currentFrameTimeStamp;
      if (!_limiter.shouldRender(frameTime)) return;
      final vsyncNanos = flutterNowNanos + _clockOffsetNanos;
      if (_frameDriver != null) {
        _frameDriver!.onVsync(vsyncNanos);
      } else {
        final now = frameTime.inMicroseconds;
        final dt = _lastTickMicros < 0 ? 1.0 / 60 : ((now - _lastTickMicros) / 1e6).clamp(0.001, 0.25);
        _lastTickMicros = now;
        widget.game.tickGame(dt);
      }
    });
    _ticker?.start();
  }

  void _onDispose() {
    _ticker?.stop();
    _ticker?.dispose();
    _ticker = null;
    _frameDriver?.renderer.dispose();
    _frameDriver?.dispose();
    _frameDriver = null;
    _sceneReady = false;
    _publishFlutterPresentation();
    if (widget.game.playState != LuminaPlayState.stopped) {
      widget.game.disposeGame();
    }
  }

  @override
  void dispose() {
    LuminaGameFramePacing.settings.removeListener(_onPacingChanged);
    if (identical(LuminaUiCapture.directOverlay.value, _publishedOverlay) && _publishedOverlay != null) {
      LuminaUiCapture.directOverlay.value = null;
    }
    if (widget.allowDirectPresentation) {
      LuminaGamePresentation.requested.removeListener(_onPresentationRequested);
      LuminaGamePresentation.decision.removeListener(_publishFlutterPresentation);
    }
    _onDispose();
    _playStateSub?.cancel();
    _playStateSub = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget view(Size? renderResolution) => FilamentWidget(
          onSceneCreated: _onSceneCreated,
          onDispose: _onDispose,
          targetFps: _pacing.targetFps > 0 ? _pacing.targetFps : null,
          vsyncEnabled: _pacing.vsyncEnabled,
          frameLimiter: _limiter,
          frameViews: widget.frameViews,
          decorated: widget.decorated,
          physicalResolution: widget.physicalResolution,
          renderResolution: renderResolution,
          nativeSurface: _surface,
          onPresentationChanged: _onPresentationChanged,
          onUiOverlay: (overlay) {
            if (mounted) setState(() => _uiOverlay = overlay);
            _publishOverlay();
          },
        );
    // The HUD and the overlay are the game's UI: in render space with the view.
    final hud = widget.hudBuilder == null ? null : LuminaHudOverlay(game: widget.game, hudBuilder: widget.hudBuilder!);
    final overlay = widget.viewportOverlay;
    final ui = hud == null && overlay == null
        ? null
        : Stack(fit: StackFit.expand, children: [if (hud != null) Positioned.fill(child: hud), ?overlay]);
    // Always the same tree: switching presentation keeps the view and the
    // UI mounted. Presenting directly, the UI's pixels (and the black bars)
    // are captured for Filament; otherwise this is a plain repaint boundary.
    // With an app-wide capture (a generated game's LuminaUiCaptureRoot) the
    // whole window is captured there instead.
    final overlayTarget = _presentingDirectly && !LuminaUiCaptureRoot.isMounted ? _uiOverlay : null;
    if (widget.followScreenResolution) {
      return LuminaUiCapture(
        overlay: overlayTarget,
        child: LuminaScreenResolutionBox(
          builder: (context, renderResolution) => view(renderResolution),
          overlay: ui,
          barsOnly: _presentingDirectly,
        ),
      );
    }
    final filamentWidget = view(null);
    return LuminaUiCapture(
      overlay: overlayTarget,
      child: ui == null ? filamentWidget : Stack(children: [filamentWidget, Positioned.fill(child: ui)]),
    );
  }
}
