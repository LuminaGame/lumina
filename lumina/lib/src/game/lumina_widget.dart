import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_filament/flutter_filament.dart';
import '../world/frame_pacing.dart';
import 'lumina_game.dart';
import 'hud_overlay.dart';

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
/// Swap chain:
/// - With [useHeadlessSwapChain] (default `true`, today's behaviour) the widget creates a
///   1×1 headless swap chain plus a [LuminaFrameDriver], so the world is ticked with a
///   vsync-derived, frame-paced delta time and [LuminaFrameDriver.frameStats] is available
///   to the HUD overlay.
/// - With `false` no extra swap chain or driver is created: the ticker calls
///   [LuminaGame.tickGame] with a fixed 1/60 s delta and `FilamentWidget` presents through
///   its own swap chain. Use this for hosts that must not allocate a second swap chain;
///   note that no frame stats are produced in that mode.
class LuminaGameWidget extends StatefulWidget {
  final LuminaGame game;
  final LuminaHudBuilder? hudBuilder;

  /// Declarative pause flag forwarded to [LuminaGame.pause] / [LuminaGame.resume].
  final bool paused;

  /// Called on every play-state transition of [game].
  final void Function(LuminaPlayState state)? onPlayStateChanged;

  /// Whether an extra headless swap chain and frame driver should be created.
  final bool useHeadlessSwapChain;

  /// Target frame rate in FPS (0 = unlimited / display refresh rate).
  final int targetFps;

  /// Whether VSync is enabled.
  final bool vsyncEnabled;

  const LuminaGameWidget({
    super.key,
    required this.game,
    this.hudBuilder,
    this.paused = false,
    this.onPlayStateChanged,
    this.useHeadlessSwapChain = true,
    this.targetFps = 0,
    this.vsyncEnabled = false,
  });

  @override
  State<LuminaGameWidget> createState() => _LuminaGameWidgetState();
}

class _LuminaGameWidgetState extends State<LuminaGameWidget>
    with SingleTickerProviderStateMixin {
  Ticker? _ticker;
  LuminaFrameDriver? _frameDriver;
  FilamentSwapChain? _headlessSwapChain;
  StreamSubscription<LuminaPlayState>? _playStateSub;
  int _clockOffsetNanos = 0;
  bool _calibrated = false;

  @override
  void initState() {
    super.initState();
    _subscribePlayState();
  }

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
    // The widget is the game's host: begin play so the ticker may drive the world.
    world?.beginPlay();
    if (world != null &&
        widget.useHeadlessSwapChain &&
        LuminaGameHostConfiguration.allowsHeadlessFrameDriver(context)) {
      final renderer = engine.createRenderer();
      final swapChain = engine.createHeadlessSwapChain(1, 1);
      _headlessSwapChain = swapChain;
      _frameDriver = LuminaFrameDriver(
        world,
        renderer: renderer,
        swapChain: swapChain,
        view: view,
      );
      if (widget.targetFps > 0) {
        _frameDriver!.targetFrameRate = widget.targetFps.toDouble();
      }
    }

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
      final vsyncNanos = flutterNowNanos + _clockOffsetNanos;
      if (_frameDriver != null) {
        _frameDriver!.onVsync(vsyncNanos);
      } else {
        final dt = widget.targetFps > 0
            ? (1.0 / widget.targetFps)
            : 0.016666667;
        widget.game.tickGame(dt);
      }
    });
    _ticker?.start();
  }

  void _onDispose() {
    _ticker?.stop();
    _ticker?.dispose();
    _ticker = null;
    _frameDriver?.dispose();
    _frameDriver = null;
    _headlessSwapChain?.dispose();
    _headlessSwapChain = null;
    if (widget.game.playState != LuminaPlayState.stopped) {
      widget.game.disposeGame();
    }
  }

  @override
  void dispose() {
    _onDispose();
    _playStateSub?.cancel();
    _playStateSub = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget filamentWidget = FilamentWidget(
      onSceneCreated: _onSceneCreated,
      onDispose: _onDispose,
      targetFps: widget.targetFps > 0 ? widget.targetFps : null,
    );

    if (widget.hudBuilder != null) {
      return Stack(
        children: [
          filamentWidget,
          Positioned.fill(
            child: LuminaHudOverlay(
              game: widget.game,
              hudBuilder: widget.hudBuilder!,
            ),
          ),
        ],
      );
    }

    return filamentWidget;
  }
}
