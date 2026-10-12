import 'dart:async';
import 'package:flutter_filament/filament.dart';
import 'package:lumina/src/world/world.dart';

/// Immutable telemetry snapshot for a single rendered or processed frame.
class LuminaFrameStats {
  final int frameId;
  final double cpuFrameMs;
  final double? gpuFrameMs;
  final double frameIntervalMs;
  final double fps;
  final int missedFrames;
  final bool gpuBehind;

  const LuminaFrameStats({
    required this.frameId,
    required this.cpuFrameMs,
    this.gpuFrameMs,
    required this.frameIntervalMs,
    required this.fps,
    required this.missedFrames,
    required this.gpuBehind,
  });
}

/// The core game loop driver managing vsync timing, FramePacer integration, frame skipping, and stat streaming.
///
/// With a [swapChain] the driver renders [view] into it after each tick (a
/// loop that owns its presentation). Without one it only ticks and paces the
/// world: the host renders the view itself, as the game widget's
/// `FilamentWidget` does, so the view's temporal history (TAA, upscalers,
/// frame generation) advances once per shown frame. [frameStats] needs the
/// driver's own frames, so it stays empty without a swap chain.
class LuminaFrameDriver {
  final LuminaWorld world;
  final FilamentRenderer renderer;

  /// Where the driver renders [view]; null when the host renders it.
  final FilamentSwapChain? swapChain;
  final FilamentView view;
  final bool useFramePacer;
  final FilamentFramePacer? framePacer;

  double maxDeltaTime;
  int _hitchCount = 0;
  bool _paused = false;
  bool _wasWorldPaused = false;
  bool _isInsideVsync = false;
  bool _isDisposed = false;

  int _lastVsyncNanos = -1;
  int _lastExpectedPresentationNs = -1;
  int _lastEmittedFrameId = 0;
  int _cumulativeMissedFrames = 0;
  bool _lastGpuBehind = false;
  double _targetFps = 60.0;

  final StreamController<LuminaFrameStats> _statsController = StreamController.broadcast();

  LuminaFrameDriver(
    this.world, {
    required this.renderer,
    this.swapChain,
    required this.view,
    this.useFramePacer = true,
    FilamentFramePacer? framePacer,
    this.maxDeltaTime = 0.25,
  }) : framePacer = framePacer ??
            ((useFramePacer && world.filamentEngineOrNull != null)
                ? FilamentFramePacer.create(world.filamentEngineOrNull!)
                : null);

  /// Broadcast stream of per-frame performance statistics.
  Stream<LuminaFrameStats> get frameStats => _statsController.stream;

  /// Whether the game loop is paused (skips simulation and rendering, keeps message queues pumping).
  ///
  /// This is the "window minimized" knob. The PIE pause is [LuminaWorld.isPaused]: while the world
  /// is paused the driver keeps pumping message queues and presenting frames (so the viewport shows
  /// the frozen state) but skips [LuminaWorld.tick] (only [LuminaWorld.tickWhilePaused] runs, for the
  /// input actions that execute when paused), and resets its delta-time baseline so the first
  /// tick after resume is not clamped as a hitch.
  bool get paused => _paused;
  set paused(bool value) {
    _paused = value;
    if (!_paused) {
      _lastVsyncNanos = -1;
      _lastExpectedPresentationNs = -1;
    }
  }

  /// Target frame rate in FPS (0.0 means follow display refresh rate).
  double get targetFrameRate => _targetFps;
  set targetFrameRate(double fps) {
    _targetFps = fps;
    framePacer?.configure(FramePacerConfiguration(targetFrameRate: fps));
    swapChain?.setFrameRate(fps);
  }

  /// Updates the display refresh rate on [renderer], called on display config change.
  void setDisplayRefreshRate(double hz) {
    renderer.displayInfo = DisplayInfo(refreshRate: hz);
  }

  /// Cumulative count of frame time hitches clamped to [maxDeltaTime].
  int get hitchCount => _hitchCount;

  /// Whether the driver renders [view] itself ([swapChain] given).
  bool get rendersView => swapChain != null;

  /// Frames this driver rendered the view in itself (0 without a [swapChain]).
  int get renderedFrames => _renderedFrames;
  int _renderedFrames = 0;

  /// Per-frame entry point called on vsync with the engine's steady-clock timestamp in nanoseconds.
  void onVsync(int vsyncSteadyClockNanos) {
    if (_isDisposed) {
      throw StateError('LuminaFrameDriver has been disposed');
    }
    if (_isInsideVsync) {
      throw StateError('Re-entrant onVsync call is not permitted');
    }

    _isInsideVsync = true;
    try {
      // 1. Pump native message queues
      world.nativeEngine?.pumpMessageQueues();

      if (_paused) return;

      // World (PIE) pause: keep presenting, skip simulation, reset the dt baseline for resume.
      final worldPaused = world.isPaused;
      if (worldPaused) {
        // Input actions that execute when paused still run, on the vsync's real delta.
        final pausedDelta = _lastVsyncNanos > 0 ? ((vsyncSteadyClockNanos - _lastVsyncNanos) / 1e9).clamp(0.0, 0.25) : 0.0;
        world.tickWhilePaused(pausedDelta.toDouble());
        _lastVsyncNanos = vsyncSteadyClockNanos;
        _lastExpectedPresentationNs = -1;
        _wasWorldPaused = true;
        bool shouldRender = renderer.shouldRenderFrame;
        if (framePacer != null) {
          // Keep the pacer's frame bookkeeping in sync even though we do not simulate.
          final status = framePacer!.setupFrame(VsyncTick(baseTimeNs: vsyncSteadyClockNanos));
          shouldRender = status.shouldRender && shouldRender;
        }
        _presentFrame(vsyncSteadyClockNanos, shouldRender);
        _drainFrameHistory();
        return;
      }
      if (_wasWorldPaused) {
        _wasWorldPaused = false;
        _lastVsyncNanos = -1;
        _lastExpectedPresentationNs = -1;
      }

      // 2. Compute deltaTime and determine shouldRender
      double deltaTime;
      bool shouldRender = false;

      if (framePacer != null) {
        final status = framePacer!.setupFrame(VsyncTick(baseTimeNs: vsyncSteadyClockNanos));
        shouldRender = status.shouldRender && renderer.shouldRenderFrame;

        final expectedNs = framePacer!.expectedPresentationTime;
        if (_lastExpectedPresentationNs > 0) {
          deltaTime = (expectedNs - _lastExpectedPresentationNs) / 1e9;
        } else {
          deltaTime = 0.016666667;
        }
        _lastExpectedPresentationNs = expectedNs;

        if (framePacer!.hasGpuFallenBehind(renderer)) {
          if (!_lastGpuBehind) {
            framePacer!.resetPacing();
          }
          _lastGpuBehind = true;
        } else {
          _lastGpuBehind = false;
        }
      } else {
        shouldRender = renderer.shouldRenderFrame;
        if (_lastVsyncNanos > 0) {
          deltaTime = (vsyncSteadyClockNanos - _lastVsyncNanos) / 1e9;
        } else {
          deltaTime = 0.016666667;
        }
        _lastVsyncNanos = vsyncSteadyClockNanos;
      }

      if (deltaTime > maxDeltaTime) {
        deltaTime = maxDeltaTime;
        _hitchCount++;
      } else if (deltaTime <= 0.0) {
        deltaTime = 0.001;
      }

      // 3. Tick simulation
      world.tick(deltaTime);

      // 4. Render or skip
      _presentFrame(vsyncSteadyClockNanos, shouldRender);

      // 5. Drain frame info history
      _drainFrameHistory();
    } finally {
      _isInsideVsync = false;
    }
  }

  void _presentFrame(int vsyncSteadyClockNanos, bool shouldRender) {
    final target = swapChain;
    if (target == null) return; // the host renders the view
    if (shouldRender) {
      final began = renderer.beginFrame(
        target,
        vsyncSteadyClockTimeNano: vsyncSteadyClockNanos,
      );
      if (began) {
        framePacer?.applyPresentationTime(renderer);
        renderer.render(view);
        renderer.endFrame();
        _renderedFrames++;
      }
    } else {
      renderer.skipFrame(vsyncSteadyClockNanos: vsyncSteadyClockNanos);
    }
  }

  void _drainFrameHistory() {
    try {
      final history = renderer.getFrameInfoHistory();
      for (final info in history) {
        if (info.frameId <= _lastEmittedFrameId) continue;

        if (_lastEmittedFrameId > 0 && info.frameId > _lastEmittedFrameId + 1) {
          _cumulativeMissedFrames += (info.frameId - _lastEmittedFrameId - 1);
        }
        _lastEmittedFrameId = info.frameId;

        final cpuMs = (info.endFrame - info.beginFrame) > 0
            ? (info.endFrame - info.beginFrame) / 1e6
            : 0.0;

        double? gpuMs;
        if (!info.isGpuPending && info.gpuFrameDuration > 0) {
          gpuMs = info.gpuFrameDuration / 1e6;
        }

        final intervalMs = info.displayPresentInterval > 0 ? info.displayPresentInterval / 1e6 : 16.666667;
        final fps = intervalMs > 0.001 ? 1000.0 / intervalMs : 60.0;

        final stats = LuminaFrameStats(
          frameId: info.frameId,
          cpuFrameMs: cpuMs,
          gpuFrameMs: gpuMs,
          frameIntervalMs: intervalMs,
          fps: fps,
          missedFrames: _cumulativeMissedFrames,
          gpuBehind: _lastGpuBehind,
        );

        if (!_statsController.isClosed) {
          _statsController.add(stats);
        }
      }
    } catch (_) {
      // Ignore on mock or headless environments without full telemetry buffers
    }
  }

  /// Disposes resources, closes streams, and destroys the frame pacer.
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    framePacer?.dispose();
    _statsController.close();
  }
}
