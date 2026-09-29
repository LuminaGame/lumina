/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

import 'dart:async';
import 'ffi_platform.dart' as ffi;
import 'dart:typed_data';
import 'ffi_package_platform.dart';
import 'package:vector_math/vector_math_64.dart';

import 'package:flutter_filament/src/engine.dart';
import 'package:flutter_filament/src/gltf_loader.dart' show FilamentAssetLoader;
import 'package:flutter_filament/src/render_target.dart';
import 'package:flutter_filament/src/swap_chain.dart';
import 'package:flutter_filament/src/texture.dart';
import 'package:flutter_filament/src/filament_bindings.dart' as c;
import 'package:flutter_filament/src/view.dart';

/// ClearOptions are used at the beginning of a frame to clear or retain SwapChain content.
class ClearOptions {
  /// Color used to clear the RenderTarget (in linear RGBA space, each component typically 0.0 .. 1.0).
  final Vector4 clearColor;

  /// Value to clear the stencil buffer (0..255).
  final int clearStencil;

  /// Whether the SwapChain should be cleared using the [clearColor].
  final bool clear;

  /// Whether the SwapChain content should be discarded.
  final bool discard;

  ClearOptions({
    Vector4? clearColor,
    this.clearStencil = 0,
    this.clear = false,
    this.discard = true,
  })  : clearColor = clearColor ?? Vector4.zero(),
        assert(clearStencil >= 0 && clearStencil <= 255, 'clearStencil must be in 0..255 range');

  ClearOptions copyWith({
    Vector4? clearColor,
    int? clearStencil,
    bool? clear,
    bool? discard,
  }) {
    return ClearOptions(
      clearColor: clearColor ?? this.clearColor,
      clearStencil: clearStencil ?? this.clearStencil,
      clear: clear ?? this.clear,
      discard: discard ?? this.discard,
    );
  }
}

/// Display properties used by the engine for frame-pacing and dynamic resolution scaling.
class DisplayInfo {
  /// Refresh rate of the display in Hz (e.g. 60.0, 120.0). Must be > 0.
  final double refreshRate;

  const DisplayInfo({
    this.refreshRate = 60.0,
  }) : assert(refreshRate > 0, 'refreshRate must be greater than 0');
}

/// Options controlling the desired frame rate and dynamic resolution responsiveness.
class FrameRateOptions {
  /// Additional headroom for the GPU as a ratio of the target frame time (0.0 .. 1.0).
  final double headRoomRatio;

  /// Rate at which the GPU load is adjusted (e.g. 1/8 = 0.125).
  final double scaleRate;

  /// History size for smoothing (1 .. 31, default 15).
  final int history;

  /// Desired frame interval in units of 1 / refreshRate (1 = 60fps on 60Hz, 2 = 30fps on 60Hz). Must be >= 1.
  final int interval;

  const FrameRateOptions({
    this.headRoomRatio = 0.0,
    this.scaleRate = 1.0 / 8.0,
    this.history = 15,
    this.interval = 1,
  })  : assert(headRoomRatio >= 0.0 && headRoomRatio <= 1.0, 'headRoomRatio must be between 0.0 and 1.0'),
        assert(history >= 1 && history <= 31, 'history must be between 1 and 31'),
        assert(interval >= 1, 'interval must be >= 1');
}

/// Timing and latency metrics for a rendered frame.
class FrameInfo {
  static const int invalid = -1;
  static const int pending = -2;

  final int frameId;
  final int gpuFrameDuration;
  final int denoisedGpuFrameDuration;
  final int beginFrame;
  final int endFrame;
  final int backendBeginFrame;
  final int backendEndFrame;
  final int gpuFrameComplete;
  final int vsync;
  final int displayPresent;
  final int presentDeadline;
  final int displayPresentInterval;
  final int compositionToPresentLatency;
  final int expectedPresentLatency;
  final int frameScheduleTime;

  const FrameInfo({
    required this.frameId,
    required this.gpuFrameDuration,
    required this.denoisedGpuFrameDuration,
    required this.beginFrame,
    required this.endFrame,
    required this.backendBeginFrame,
    required this.backendEndFrame,
    required this.gpuFrameComplete,
    required this.vsync,
    required this.displayPresent,
    required this.presentDeadline,
    required this.displayPresentInterval,
    required this.compositionToPresentLatency,
    required this.expectedPresentLatency,
    required this.frameScheduleTime,
  });

  bool get isGpuPending => gpuFrameDuration == pending;
  static bool isValidField(int value) => value != invalid && value != pending;
}

/// A Renderer generates drawing commands for the render thread and manages
/// frame latency.
///
/// Typically one Renderer is created per window.
class FilamentRenderer {
  final ffi.Pointer<ffi.Void> _ptr;
  final FilamentEngine _engine;
  bool _disposed = false;

  /// Internal constructor for creating a [FilamentRenderer] from a native pointer.
  FilamentRenderer.internal(this._ptr, this._engine);

  /// The raw native pointer to the Filament Renderer.
  ffi.Pointer<ffi.Void> get nativePointer {
    _checkDisposed();
    return _ptr;
  }

  /// Sets ClearOptions which are used at the beginning of a frame to clear or retain SwapChain content.
  set clearOptions(ClearOptions options) {
    _checkDisposed();
    final ptr = calloc<c.filament_clear_options_t>();
    try {
      ptr.ref.clear_color[0] = options.clearColor.x;
      ptr.ref.clear_color[1] = options.clearColor.y;
      ptr.ref.clear_color[2] = options.clearColor.z;
      ptr.ref.clear_color[3] = options.clearColor.w;
      ptr.ref.clear_stencil = options.clearStencil;
      ptr.ref.clear = options.clear;
      ptr.ref.discard = options.discard;
      c.filament_renderer_set_clear_options_ex(_ptr, ptr);
    } finally {
      calloc.free(ptr);
    }
  }

  /// Returns the ClearOptions currently set.
  ClearOptions get clearOptions {
    _checkDisposed();
    final ptr = calloc<c.filament_clear_options_t>();
    try {
      c.filament_renderer_get_clear_options(_ptr, ptr);
      return ClearOptions(
        clearColor: Vector4(
          ptr.ref.clear_color[0],
          ptr.ref.clear_color[1],
          ptr.ref.clear_color[2],
          ptr.ref.clear_color[3],
        ),
        clearStencil: ptr.ref.clear_stencil,
        clear: ptr.ref.clear,
        discard: ptr.ref.discard,
      );
    } finally {
      calloc.free(ptr);
    }
  }

  /// Sets the clear color and options for the renderer (convenience legacy method).
  void setClearOptions({
    double r = 0,
    double g = 0,
    double b = 0,
    double a = 1,
    bool clear = true,
    bool discard = true,
  }) {
    _checkDisposed();
    c.filament_renderer_set_clear_options(_ptr, r, g, b, a, clear, discard);
  }

  /// Set up a frame for rendering.
  ///
  /// Returns `true` if the frame should be drawn, `false` to skip.
  /// When `true` is returned, [render] and [endFrame] must be called.
  ///
  /// [vsyncSteadyClockTimeNano] is the timestamp of the last h/w vsync expressed
  /// in nanoseconds on the steady clock (via [FilamentEngine.steadyClockTimeNano]).
  bool beginFrame(FilamentSwapChain swapChain, {int vsyncSteadyClockTimeNano = 0, int vsyncNs = 0}) {
    _checkDisposed();
    final vsync = vsyncSteadyClockTimeNano != 0 ? vsyncSteadyClockTimeNano : vsyncNs;
    final draw = c.filament_renderer_begin_frame(
      _ptr,
      swapChain.nativePointer,
      vsync,
    );
    // A skipped frame still ran the engine's gc (and advanced the epoch)
    // inside beginFrame; keep gltfio's managers in step either way.
    FilamentAssetLoader.collectGarbage(_engine);
    return draw;
  }

  /// Render a [view] into this renderer's window.
  ///
  /// Must be called after [beginFrame] and before [endFrame].
  void render(FilamentView view) {
    _checkDisposed();
    c.filament_renderer_render(_ptr, view.nativePointer);
  }

  /// Finishes the current frame and schedules it for display.
  void endFrame() {
    _checkDisposed();
    c.filament_renderer_end_frame(_ptr);
    // endFrame is where the engine advances its reclamation epoch; sync the
    // gltfio component managers to it, as Filament's apps do by hand.
    FilamentAssetLoader.collectGarbage(_engine);
  }

  /// Sets display properties (such as refresh rate) needed for frame pacing and dynamic resolution.
  set displayInfo(DisplayInfo info) {
    _checkDisposed();
    c.filament_renderer_set_display_info(_ptr, info.refreshRate);
  }

  /// Sets frame rate options controlling target frame interval and dynamic resolution responsiveness.
  set frameRateOptions(FrameRateOptions options) {
    _checkDisposed();
    c.filament_renderer_set_frame_rate_options(
      _ptr,
      options.headRoomRatio,
      options.scaleRate,
      options.history,
      options.interval,
    );
  }

  /// Retrieves past frame timing information.
  List<FrameInfo> getFrameInfoHistory([int count = 1]) {
    _checkDisposed();
    if (count <= 0) return const [];
    final ptr = calloc<c.filament_frame_info_t>(count);
    try {
      final written = c.filament_renderer_get_frame_info_history(_ptr, ptr, count);
      final list = <FrameInfo>[];
      for (int i = 0; i < written; i++) {
        final ref = (ptr + i).ref;
        list.add(FrameInfo(
          frameId: ref.frame_id,
          gpuFrameDuration: ref.gpu_frame_duration,
          denoisedGpuFrameDuration: ref.denoised_gpu_frame_duration,
          beginFrame: ref.begin_frame,
          endFrame: ref.end_frame,
          backendBeginFrame: ref.backend_begin_frame,
          backendEndFrame: ref.backend_end_frame,
          gpuFrameComplete: ref.gpu_frame_complete,
          vsync: ref.vsync,
          displayPresent: ref.display_present,
          presentDeadline: ref.present_deadline,
          displayPresentInterval: ref.display_present_interval,
          compositionToPresentLatency: ref.composition_to_present_latency,
          expectedPresentLatency: ref.expected_present_latency,
          frameScheduleTime: ref.frame_schedule_time,
        ));
      }
      return list;
    } finally {
      calloc.free(ptr);
    }
  }

  /// Maximum frame timing history capacity supported by this renderer.
  int get maxFrameHistorySize {
    _checkDisposed();
    return c.filament_renderer_get_max_frame_history_size(_ptr);
  }

  /// Renders a standalone view into its associated RenderTarget.
  ///
  /// Must be called outside of [beginFrame] / [endFrame].
  /// The [view] must have a [FilamentRenderTarget] assigned.
  void renderStandaloneView(FilamentView view) {
    _checkDisposed();
    if (view.renderTarget == null) {
      throw ArgumentError('renderStandaloneView requires a view with a non-null renderTarget');
    }
    c.filament_renderer_render_standalone_view(_ptr, view.nativePointer);
  }

  /// Reads back the rendered pixel buffer from the current viewport (swap chain).
  void readPixels({
    required int x,
    required int y,
    required int width,
    required int height,
    required Uint8List outPixels,
  }) {
    _checkDisposed();
    final ptr = calloc<ffi.Uint8>(outPixels.length);
    try {
      c.filament_renderer_read_pixels(
          _ptr, _engine.nativePointer, x, y, width, height, ptr.cast(), ffi.nullptr, ffi.nullptr);
      _engine.flushAndWait();
      outPixels.setAll(0, ptr.asTypedList(outPixels.length));
    } finally {
      calloc.free(ptr);
    }
  }

  /// Queues a readback of the current viewport (swap chain) into [buffer],
  /// `width * height` RGBA8 pixels, without waiting for it: call between
  /// [beginFrame] and [endFrame]; the pixels are in [buffer], which must stay
  /// allocated until then, once the engine has been flushed (for example by
  /// [FilamentEngine.flushAndWait] after [endFrame]).
  void readPixelsInto(
    ffi.Pointer<ffi.Uint8> buffer, {
    required int x,
    required int y,
    required int width,
    required int height,
  }) {
    _checkDisposed();
    c.filament_renderer_read_pixels(
        _ptr, _engine.nativePointer, x, y, width, height, buffer.cast(), ffi.nullptr, ffi.nullptr);
  }

  /// Reads back pixels from the specified [renderTarget].
  ///
  /// Origin (0,0) is at the bottom-left of the render target.
  Future<Uint8List> readPixelsFromRenderTarget(
    FilamentRenderTarget renderTarget, {
    required int x,
    required int y,
    required int width,
    required int height,
    PixelDataFormat format = PixelDataFormat.rgba,
    PixelDataType type = PixelDataType.ubyte,
  }) async {
    _checkDisposed();
    final bytesPerPixel = 4; // Standard RGBA UBYTE
    final totalBytes = width * height * bytesPerPixel;
    final bufferPtr = calloc<ffi.Uint8>(totalBytes);
    final completer = Completer<Uint8List>();

    try {
      c.filament_renderer_read_pixels_render_target(
        _ptr,
        renderTarget.nativePointer,
        x,
        y,
        width,
        height,
        format.value,
        type.value,
        bufferPtr.cast(),
        totalBytes,
        ffi.nullptr,
        ffi.nullptr,
      );

      _engine.flushAndWait();
      final result = Uint8List.fromList(bufferPtr.asTypedList(totalBytes));
      completer.complete(result);
    } catch (e, st) {
      completer.completeError(e, st);
    } finally {
      calloc.free(bufferPtr);
    }

    return completer.future;
  }

  /// Sets VSYNC time in nanoseconds since epoch of steady_clock.
  set vsyncTime(int steadyClockNs) {
    _checkDisposed();
    if (steadyClockNs < 0) throw ArgumentError('steadyClockNs must be non-negative');
    c.filament_renderer_set_vsync_time(_ptr, steadyClockNs);
  }

  /// Sets hardware presentation timestamp in nanoseconds on the steady clock.
  set presentationTime(int monotonicClockNs) {
    _checkDisposed();
    if (monotonicClockNs < 0) throw ArgumentError('monotonicClockNs must be non-negative');
    c.filament_renderer_set_presentation_time(_ptr, monotonicClockNs);
  }

  /// Sets targeted presentation timestamp in nanoseconds on the steady clock.
  set desiredPresentationTime(int ns) {
    _checkDisposed();
    if (ns < 0) throw ArgumentError('desiredPresentationTime must be non-negative');
    c.filament_renderer_set_desired_presentation_time(_ptr, ns);
  }

  /// Sets deadline time point in nanoseconds by which rendering must complete.
  set renderingDeadline(int deadlineNs) {
    _checkDisposed();
    if (deadlineNs < 0) throw ArgumentError('deadlineNs must be non-negative');
    c.filament_renderer_set_rendering_deadline(_ptr, deadlineNs);
  }

  /// Sets physical clock time when the frame scheduling callback was entered.
  set frameScheduleTime(int ns) {
    _checkDisposed();
    if (ns < 0) throw ArgumentError('frameScheduleTime must be non-negative');
    c.filament_renderer_set_frame_schedule_time(_ptr, ns);
  }

  /// Skips the current frame's rendering while performing internal bookkeeping.
  void skipFrame({int vsyncSteadyClockNanos = 0}) {
    _checkDisposed();
    if (vsyncSteadyClockNanos < 0) throw ArgumentError('vsyncSteadyClockNanos must be non-negative');
    c.filament_renderer_skip_frame(_ptr, vsyncSteadyClockNanos);
  }

  /// Returns `true` if the current frame should be rendered.
  bool get shouldRenderFrame {
    _checkDisposed();
    return c.filament_renderer_should_render_frame(_ptr);
  }

  /// Returns `true` if GPU execution has fallen behind CPU rendering execution.
  bool get hasGpuFallenBehind {
    _checkDisposed();
    return c.filament_renderer_has_gpu_fallen_behind(_ptr);
  }

  /// Returns the current material time in seconds.
  double get materialTime {
    _checkDisposed();
    return c.filament_renderer_get_material_time(_ptr);
  }

  /// Resets the material time epoch to the specified steady clock timestamp (or current time if null).
  void resetMaterialTimeEpoch({int? epochSteadyNanos}) {
    _checkDisposed();
    final epoch = epochSteadyNanos ?? _engine.steadyClockTimeNano;
    if (epoch < 0) throw ArgumentError('epochSteadyNanos must be non-negative');
    c.filament_renderer_set_material_time_epoch(_ptr, epoch);
  }

  /// Requests the next [count] frames to be skipped.
  void skipNextFrames(int count) {
    _checkDisposed();
    if (count < 0) throw ArgumentError('count must be non-negative');
    c.filament_renderer_skip_next_frames(_ptr, count);
  }

  /// Remainder count of frames to be skipped.
  int get frameToSkipCount {
    _checkDisposed();
    return c.filament_renderer_get_frame_to_skip_count(_ptr);
  }

  /// Stalls the render thread for the given duration (useful for pacing testing).
  void pauseRenderThread(Duration duration) {
    _checkDisposed();
    final ns = duration.inMicroseconds * 1000;
    c.filament_renderer_pause_render_thread(_ptr, ns);
  }

  /// Destroys this renderer and releases its resources.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    c.filament_engine_destroy_renderer(_engine.nativePointer, _ptr);
  }

  bool get isDisposed => _disposed;

  void _checkDisposed() {
    if (_disposed) {
      throw StateError('FilamentRenderer has been disposed');
    }
  }
}
