import 'package:flutter_filament/src/ffi_platform.dart' as ffi;
import 'package:flutter_filament/src/ffi_package_platform.dart';

import 'package:flutter_filament/src/dlss.dart';
import 'package:flutter_filament/src/engine.dart';
import 'package:flutter_filament/src/filament_bindings.dart' as c;
import 'package:flutter_filament/src/view.dart';

/// DLSS Ray Reconstruction model presets (NGX
/// `RayReconstruction.Hint.Render.Preset`).
enum DlssRayReconstructionPreset {
  /// What the installed runtime picks by default.
  defaultPreset(0),

  /// Transformer model (preset D).
  d(4),

  /// Latest transformer model (preset E).
  e(5),

  /// The transformer model of SDK 310.9 (preset F, "RR2").
  f(6);

  const DlssRayReconstructionPreset(this.value);
  final int value;
}

/// What a [DlssRayReconstruction] is created with.
class DlssRayReconstructionOptions {
  const DlssRayReconstructionOptions({
    this.quality = DlssQuality.balanced,
    required this.outputWidth,
    required this.outputHeight,
    this.preset = DlssRayReconstructionPreset.f,
  });

  /// The same quality modes as DLSS Super Resolution (render scale per axis).
  final DlssQuality quality;

  /// The view's viewport (output) size.
  final int outputWidth;
  final int outputHeight;

  final DlssRayReconstructionPreset preset;
}

/// DLSS Ray Reconstruction on a [FilamentView]: one NVIDIA network that
/// denoises the ray-traced lighting (ReSTIR, ray-traced shadows) of the HDR
/// frame and upscales it, in place of Filament's TAA, before bloom and colour
/// grading. It reads the view's guide buffers (normal + roughness, diffuse and
/// specular albedo, specular hit distance), which [DlssRayReconstruction.create]
/// turns on together with the TAA jitter and motion vectors.
///
/// Requirements: [available] (the fetched SDK with `nvngx_dlssd`, an NVIDIA
/// GPU), [Dlss.requestExtensions] before the engine is created, the Vulkan
/// backend, a single-sampled view. The NGX runtime is NVIDIA's (never part of
/// Lumina's release); see `tool/dlss/fetch_sdk.dart`.
class DlssRayReconstruction {
  DlssRayReconstruction._(this.engine, this.view, this._ptr);

  final FilamentEngine engine;
  final FilamentView view;
  ffi.Pointer<ffi.Void> _ptr;

  /// The NGX runtime with `nvngx_dlssd` was found and an NVIDIA Vulkan device
  /// is present. False on the web, other GPUs and without the fetched SDK.
  static bool get available => c.filament_dlss_rr_available();

  /// Whether [engine]'s GPU and driver offer Ray Reconstruction.
  static bool supported(FilamentEngine engine) =>
      c.filament_dlss_rr_supported(engine.nativePointer);

  /// The last error (process-wide), or null after a successful call.
  static String? get lastErrorMessage {
    final ptr = c.filament_dlss_rr_last_error();
    if (ptr == ffi.nullptr) return null;
    return ptr.cast<Utf8>().toDartString();
  }

  /// Throws a [StateError] carrying [lastErrorMessage] when Ray Reconstruction
  /// is unavailable or NGX declines.
  factory DlssRayReconstruction.create({
    required FilamentEngine engine,
    required FilamentView view,
    required DlssRayReconstructionOptions options,
  }) {
    final native = calloc<c.filament_dlss_rr_options_t>();
    try {
      native.ref
        ..quality = options.quality.toNative()
        ..outputWidth = options.outputWidth
        ..outputHeight = options.outputHeight
        ..preset = options.preset.value;
      final ptr = c.filament_dlss_rr_create(
        engine.nativePointer,
        view.nativePointer,
        native,
      );
      if (ptr == ffi.nullptr) {
        throw StateError(
          'DLSS Ray Reconstruction: ${lastErrorMessage ?? 'nvngx_dlssd not available'}',
        );
      }
      return DlssRayReconstruction._(engine, view, ptr);
    } finally {
      calloc.free(native);
    }
  }

  bool get isDestroyed => _ptr == ffi.nullptr;

  void _checkDestroyed() {
    if (_ptr == ffi.nullptr) {
      throw StateError('DlssRayReconstruction has been destroyed');
    }
  }

  /// The render resolution NGX chose for the quality mode.
  (int, int) get renderResolution {
    _checkDestroyed();
    final out = calloc<ffi.Uint32>(2);
    try {
      c.filament_dlss_rr_get_render_resolution(_ptr, out, out + 1);
      return (out[0], out[1]);
    } finally {
      calloc.free(out);
    }
  }

  /// Changes the quality mode (the feature is recreated on the next frame).
  set quality(DlssQuality quality) {
    _checkDestroyed();
    c.filament_dlss_rr_set_quality(_ptr, quality.toNative());
  }

  /// Resets the temporal history for the next frame (camera cuts).
  void resetHistory() {
    _checkDestroyed();
    c.filament_dlss_rr_reset_history(_ptr);
  }

  /// GPU time of the last completed evaluation (timestamp queries around the
  /// NGX call), or [Duration.zero] before one completed.
  Duration get lastGpuTime {
    _checkDestroyed();
    return Duration(
      microseconds: c.filament_dlss_rr_last_gpu_time_ns(_ptr) ~/ 1000,
    );
  }

  /// The last GPU time in nanoseconds (finer than [lastGpuTime]).
  int get lastGpuTimeNanos {
    _checkDestroyed();
    return c.filament_dlss_rr_last_gpu_time_ns(_ptr);
  }

  /// Frames evaluated so far.
  int get frameCount {
    _checkDestroyed();
    return c.filament_dlss_rr_frame_count(_ptr);
  }

  /// The last error reported (process-wide), or null.
  String? get lastError => lastErrorMessage;

  /// Releases the feature and restores the view's guide buffer, TAA and
  /// dynamic resolution options. A second call is a no-op.
  void destroy() {
    if (_ptr == ffi.nullptr) return;
    c.filament_dlss_rr_destroy(_ptr);
    _ptr = ffi.nullptr;
  }
}
