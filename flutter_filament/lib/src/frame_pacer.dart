import 'package:flutter_filament/src/ffi_platform.dart' as ffi;
import 'package:flutter_filament/src/ffi_package_platform.dart';

import 'package:flutter_filament/src/engine.dart';
import 'package:flutter_filament/src/renderer.dart';
import 'package:flutter_filament/src/filament_bindings.dart' as c;

/// Status code returned by [FilamentFramePacer.setupFrame] indicating whether the frame should render.
enum FrameStatus {
  /// Skipped to maintain target frame rate cadence (e.g. 30 FPS on 60Hz display).
  skippedSpurious(-2),

  /// Skipped to prevent out-of-order presentation (monotonic guard).
  skippedStale(-1),

  /// The frame is approved for rendering.
  accepted(0);

  final int value;
  const FrameStatus(this.value);

  static FrameStatus fromValue(int val) {
    switch (val) {
      case -2:
        return FrameStatus.skippedSpurious;
      case -1:
        return FrameStatus.skippedStale;
      case 0:
        return FrameStatus.accepted;
      default:
        return FrameStatus.skippedStale;
    }
  }

  /// Whether this status approves rendering the frame.
  bool get shouldRender => this == FrameStatus.accepted;
}

/// Pipeline flow control status for [FilamentFramePacer].
enum PacingStatus {
  /// Latency has shrunk; display is starving for buffers.
  displayStarving(-1),

  /// Operating at or near optimal configured latency.
  steady(0),

  /// Latency has bloated; display queue is stuffed.
  displayStuffed(1);

  final int value;
  const PacingStatus(this.value);

  static PacingStatus fromValue(int val) {
    switch (val) {
      case -1:
        return PacingStatus.displayStarving;
      case 1:
        return PacingStatus.displayStuffed;
      case 0:
      default:
        return PacingStatus.steady;
    }
  }
}

/// Hardware presentation timeline telemetry.
class HardwareTimeline {
  /// Anticipated physical presentation timestamp in nanoseconds on steady clock.
  final int expectedPresentationTimeNs;

  /// Submission completion deadline in nanoseconds on steady clock.
  final int deadlineNs;

  const HardwareTimeline({
    required this.expectedPresentationTimeNs,
    required this.deadlineNs,
  });
}

/// VSYNC timing telemetry passed to [FilamentFramePacer.setupFrame].
class VsyncTick {
  /// Base hardware VSYNC tick timestamp in nanoseconds on steady clock.
  final int baseTimeNs;

  /// Physical hardware VSYNC period in nanoseconds (defaults to ~16.66ms for 60Hz).
  final int vsyncPeriodNs;

  /// Time when frame scheduling callback was entered in nanoseconds on steady clock (0 = now).
  final int frameScheduleTimeNs;

  /// Candidate hardware presentation timelines.
  final List<HardwareTimeline> timelines;

  const VsyncTick({
    required this.baseTimeNs,
    this.vsyncPeriodNs = 16666666,
    this.frameScheduleTimeNs = 0,
    this.timelines = const [],
  });
}

/// Dynamic target configuration for [FilamentFramePacer].
class FramePacerConfiguration {
  /// Desired rendering frame rate in Hz.
  final double targetFrameRate;

  /// Target latency duration.
  final Duration latency;

  const FramePacerConfiguration({
    this.targetFrameRate = 60.0,
    this.latency = const Duration(microseconds: 33333),
  });

  FramePacerConfiguration copyWith({
    double? targetFrameRate,
    Duration? latency,
  }) {
    return FramePacerConfiguration(
      targetFrameRate: targetFrameRate ?? this.targetFrameRate,
      latency: latency ?? this.latency,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FramePacerConfiguration &&
          runtimeType == other.runtimeType &&
          targetFrameRate == other.targetFrameRate &&
          latency == other.latency;

  @override
  int get hashCode => Object.hash(targetFrameRate, latency);

  @override
  String toString() =>
      'FramePacerConfiguration(fps: $targetFrameRate, latency: ${latency.inMicroseconds}µs)';
}

/// Coordinates frame scheduling and presentation timestamps to eliminate micro-stutter.
///
/// Typical game loop pattern:
/// ```dart
/// final status = pacer.setupFrame(tick);
/// if (status.shouldRender) {
///   // Advance simulation to pacer.expectedPresentationTime
///   if (!pacer.hasGpuFallenBehind(renderer)) {
///     pacer.applyPresentationTime(renderer);
///     if (renderer.beginFrame(swapChain)) {
///       renderer.render(view);
///       renderer.endFrame();
///     }
///   }
/// }
/// ```
class FilamentFramePacer {
  final ffi.Pointer<ffi.Void> _ptr;
  final FilamentEngine _engine;
  bool _disposed = false;

  /// Internal constructor.
  FilamentFramePacer.internal(this._ptr, this._engine);

  /// Creates a new [FilamentFramePacer].
  factory FilamentFramePacer.create(
    FilamentEngine engine, {
    double targetFrameRate = 60.0,
    Duration? latency,
    int? latencyFrames,
  }) {
    final effectiveLatency = latency ??
        (latencyFrames != null
            ? Duration(microseconds: (latencyFrames * (1000000 / 60.0)).round())
            : const Duration(microseconds: 33333));

    final configPtr = calloc<c.filament_frame_pacer_config_t>();
    configPtr.ref.target_frame_rate = targetFrameRate;
    configPtr.ref.latency_ns = effectiveLatency.inMicroseconds * 1000;

    final ptr = c.filament_frame_pacer_create(engine.nativePointer, configPtr);
    calloc.free(configPtr);

    if (ptr == ffi.nullptr) {
      throw StateError('Failed to create FilamentFramePacer');
    }
    return FilamentFramePacer.internal(ptr, engine);
  }

  /// The raw native pointer to the Filament FramePacer.
  ffi.Pointer<ffi.Void> get nativePointer {
    _checkDisposed();
    return _ptr;
  }

  /// Updates the active pacing targets mid-flight.
  void configure(FramePacerConfiguration config) {
    _checkDisposed();
    final configPtr = calloc<c.filament_frame_pacer_config_t>();
    configPtr.ref.target_frame_rate = config.targetFrameRate;
    configPtr.ref.latency_ns = config.latency.inMicroseconds * 1000;

    c.filament_frame_pacer_configure(_ptr, configPtr);
    calloc.free(configPtr);
  }

  /// Retrieves the current configuration used by the FramePacer.
  FramePacerConfiguration get configuration {
    _checkDisposed();
    final configPtr = calloc<c.filament_frame_pacer_config_t>();
    c.filament_frame_pacer_get_configuration(_ptr, configPtr);

    final config = FramePacerConfiguration(
      targetFrameRate: configPtr.ref.target_frame_rate,
      latency: Duration(microseconds: configPtr.ref.latency_ns ~/ 1000),
    );
    calloc.free(configPtr);
    return config;
  }

  /// Prepares and evaluates the frame pacing state for an upcoming frame cycle.
  FrameStatus setupFrame(VsyncTick tick) {
    _checkDisposed();
    final tickPtr = calloc<c.filament_vsync_tick_t>();
    tickPtr.ref.base_time_ns = tick.baseTimeNs;
    tickPtr.ref.vsync_period_ns = tick.vsyncPeriodNs;
    tickPtr.ref.frame_schedule_time_ns = tick.frameScheduleTimeNs;

    ffi.Pointer<c.filament_hardware_timeline_t> timelinesPtr = ffi.nullptr;
    if (tick.timelines.isNotEmpty) {
      timelinesPtr = calloc<c.filament_hardware_timeline_t>(tick.timelines.length);
      for (int i = 0; i < tick.timelines.length; i++) {
        timelinesPtr[i].expected_presentation_time_ns =
            tick.timelines[i].expectedPresentationTimeNs;
        timelinesPtr[i].deadline_ns = tick.timelines[i].deadlineNs;
      }
      tickPtr.ref.timelines = timelinesPtr;
      tickPtr.ref.timeline_count = tick.timelines.length;
    } else {
      tickPtr.ref.timelines = ffi.nullptr;
      tickPtr.ref.timeline_count = 0;
    }

    final statusVal = c.filament_frame_pacer_setup_frame(_ptr, tickPtr);

    if (timelinesPtr != ffi.nullptr) calloc.free(timelinesPtr);
    calloc.free(tickPtr);

    return FrameStatus.fromValue(statusVal);
  }

  /// Advances the pacing pipeline to target an extra presentation frame for latency recovery.
  bool setupExtraFrame() {
    _checkDisposed();
    return c.filament_frame_pacer_setup_extra_frame(_ptr);
  }

  /// Checks if the GPU rendering pipeline has fallen behind CPU submissions.
  bool hasGpuFallenBehind(FilamentRenderer renderer) {
    _checkDisposed();
    return c.filament_frame_pacer_has_gpu_fallen_behind(_ptr, renderer.nativePointer);
  }

  /// Applies the computed Latency Offset presentation time directly onto the renderer.
  void applyPresentationTime(FilamentRenderer renderer) {
    _checkDisposed();
    c.filament_frame_pacer_apply_presentation_time(_ptr, renderer.nativePointer);
  }

  /// Forces FramePacer to abandon relative pacing state and re-anchor on next frame.
  void resetPacing() {
    _checkDisposed();
    c.filament_frame_pacer_reset_pacing(_ptr);
  }

  /// Expected presentation timestamp in nanoseconds on steady clock.
  int get expectedPresentationTime {
    _checkDisposed();
    return c.filament_frame_pacer_get_expected_presentation_time(_ptr);
  }

  /// Rendering deadline timestamp in nanoseconds on steady clock.
  int get renderingDeadline {
    _checkDisposed();
    return c.filament_frame_pacer_get_rendering_deadline(_ptr);
  }

  /// Effective target latency.
  Duration get effectiveLatency {
    _checkDisposed();
    final ns = c.filament_frame_pacer_get_effective_latency(_ptr);
    return Duration(microseconds: ns ~/ 1000);
  }

  /// Current flow control status of the pacing pipeline.
  PacingStatus get pacingStatus {
    _checkDisposed();
    final val = c.filament_frame_pacer_get_pacing_status(_ptr);
    return PacingStatus.fromValue(val);
  }

  /// Actual frame rate selected during active pacing cycle.
  double get selectedFrameRate {
    _checkDisposed();
    return c.filament_frame_pacer_get_selected_frame_rate(_ptr);
  }

  /// Whether selected pacing frame rate is achieved exactly by display hardware.
  bool get isExactFrameRateAchieved {
    _checkDisposed();
    return c.filament_frame_pacer_is_exact_frame_rate_achieved(_ptr);
  }

  /// Destroys this frame pacer and releases its resources.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    c.filament_engine_destroy_frame_pacer(_engine.nativePointer, _ptr);
  }

  bool get isDisposed => _disposed;

  void _checkDisposed() {
    if (_disposed) {
      throw StateError('FilamentFramePacer has been disposed');
    }
  }
}
