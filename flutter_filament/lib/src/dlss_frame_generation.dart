import 'package:flutter_filament/src/ffi_platform.dart' as ffi;
import 'package:flutter_filament/src/ffi_package_platform.dart';

import 'package:flutter_filament/src/engine.dart';
import 'package:flutter_filament/src/filament_bindings.dart' as c;
import 'package:flutter_filament/src/view.dart';

/// What NGX reports about DLSS Frame Generation for an engine's GPU.
class DlssFrameGenerationProbe {
  const DlssFrameGenerationProbe({
    required this.available,
    required this.needsUpdatedDriver,
    required this.minDriverVersion,
    required this.featureInitResult,
    required this.multiFrameCountMax,
    required this.supportFlags,
    required this.minHwArchitecture,
    required this.deviceExtensions,
  });

  /// `FrameGeneration.Available`.
  final bool available;
  final bool needsUpdatedDriver;

  /// `major.minor` of the oldest driver the feature runs on.
  final String minDriverVersion;

  /// `FrameGeneration.FeatureInitResult` (an NGX result; 1 is success).
  final int featureInitResult;

  /// Generated frames per rendered frame the GPU allows (1 = 2x, 3 = up to 4x,
  /// 5 = up to 6x). Multi Frame Generation needs an RTX 50 class GPU.
  final int multiFrameCountMax;

  /// `NVSDK_NGX_Feature_Support_Result` bits: 0 is supported, 2 driver, 4
  /// adapter, 8 OS.
  final int supportFlags;

  /// The `NV_GPU_ARCHITECTURE_ID` the feature needs.
  final int minHwArchitecture;

  /// The Vulkan device extensions NGX asks for.
  final List<String> deviceExtensions;

  @override
  String toString() =>
      'DlssFrameGenerationProbe(available: $available, needsUpdatedDriver: $needsUpdatedDriver, '
      'minDriver: $minDriverVersion, initResult: 0x${featureInitResult.toRadixString(16)}, '
      'multiFrameCountMax: $multiFrameCountMax, supportFlags: $supportFlags, minHwArchitecture: 0x${minHwArchitecture.toRadixString(16)}, '
      'deviceExtensions: $deviceExtensions)';
}

/// DLSS Frame Generation (NVIDIA NGX `dlssg`, Vulkan) as far as NGX offers it
/// directly: the availability probe, and an interpolator that runs the network
/// inside Filament's frame and shows the frame it generates between the
/// previous and the current one (instead of the current one). The
/// interpolator makes the output measurable; it does not present additional
/// frames.
abstract final class DlssFrameGeneration {
  /// The runtime with `nvngx_dlssg` was found and an NVIDIA Vulkan device is
  /// present.
  static bool get available => c.filament_dlss_fg_available();

  /// Asks engines created from now on for the Vulkan extensions and features
  /// Frame Generation uses (optical flow, synchronization2, timeline
  /// semaphores), on top of [Dlss.requestExtensions].
  static bool requestExtensions() => c.filament_dlss_fg_request_extensions();

  /// Forgets [requestExtensions].
  static void clearExtensionRequest() =>
      c.filament_dlss_fg_clear_extension_request();

  /// The last error (process-wide), or null.
  static String? get lastErrorMessage {
    final ptr = c.filament_dlss_fg_last_error();
    if (ptr == ffi.nullptr) return null;
    return ptr.cast<Utf8>().toDartString();
  }

  /// Initialises NGX for [engine] and reads what it reports; null (with
  /// [lastErrorMessage]) when NGX cannot start.
  static DlssFrameGenerationProbe? probe(FilamentEngine engine) {
    final out = calloc<c.filament_dlss_fg_probe_t>();
    try {
      if (!c.filament_dlss_fg_probe(engine.nativePointer, out)) return null;
      final r = out.ref;
      final chars = <int>[];
      for (var i = 0; i < 1024; i++) {
        final ch = r.deviceExtensions[i];
        if (ch == 0) break;
        chars.add(ch);
      }
      final extensions = String.fromCharCodes(
        chars,
      ).split(' ').where((e) => e.isNotEmpty).toList();
      return DlssFrameGenerationProbe(
        available: r.available,
        needsUpdatedDriver: r.needsUpdatedDriver,
        minDriverVersion: '${r.minDriverMajor}.${r.minDriverMinor}',
        featureInitResult: r.featureInitResult,
        multiFrameCountMax: r.multiFrameCountMax,
        supportFlags: r.supportFlags,
        minHwArchitecture: r.minHwArchitecture,
        deviceExtensions: extensions,
      );
    } finally {
      calloc.free(out);
    }
  }
}

/// DLSS Frame Generation presenting through Filament: every rendered frame of
/// [view] (drawn into a SwapChain) is preceded by [generatedFrames] generated
/// ones, which `Renderer.endFrame` presents evenly spaced when the SwapChain
/// has no vsync ([SwapChainConfig.disableVsync]). 1 is 2x presentation; 2 to
/// 5 (3x to 6x, Multi Frame Generation) need an RTX 50 class GPU
/// ([DlssFrameGenerationProbe.multiFrameCountMax]). Views rendered into a
/// texture (a Flutter widget) do not get extra presents.
class DlssFrameGenerator {
  DlssFrameGenerator._(
    this.engine,
    this.view,
    this._ptr,
    this._generatedFrames,
  );

  final FilamentEngine engine;
  final FilamentView view;
  ffi.Pointer<ffi.Void> _ptr;
  int _generatedFrames;

  /// Throws a [StateError] with [DlssFrameGeneration.lastErrorMessage] when
  /// unavailable or when the GPU allows fewer generated frames.
  factory DlssFrameGenerator.create({
    required FilamentEngine engine,
    required FilamentView view,
    int generatedFrames = 1,
  }) {
    final ptr = c.filament_dlss_fg_create(
      engine.nativePointer,
      view.nativePointer,
      generatedFrames,
    );
    if (ptr == ffi.nullptr) {
      throw StateError(
        'DLSS Frame Generation: ${DlssFrameGeneration.lastErrorMessage ?? 'not available'}',
      );
    }
    return DlssFrameGenerator._(engine, view, ptr, generatedFrames);
  }

  bool get isDestroyed => _ptr == ffi.nullptr;

  /// Generated frames per rendered frame.
  int get generatedFrames => _generatedFrames;

  set generatedFrames(int value) {
    if (isDestroyed) return;
    _generatedFrames = value;
    c.filament_dlss_fg_set_generated_frames(_ptr, value);
  }

  /// Rendered frames for which frames were generated.
  int get frameCount => isDestroyed ? 0 : c.filament_dlss_fg_frame_count(_ptr);

  /// The NGX result of the last creation or evaluation (1 is success).
  int get lastResult => isDestroyed ? 0 : c.filament_dlss_fg_last_result(_ptr);

  /// GPU time of the last set of evaluations (all frames generated for one
  /// rendered frame) in nanoseconds.
  int get lastGpuTimeNanos =>
      isDestroyed ? 0 : c.filament_dlss_fg_last_gpu_time_ns(_ptr);

  void destroy() {
    if (_ptr == ffi.nullptr) return;
    c.filament_dlss_fg_destroy(_ptr);
    _ptr = ffi.nullptr;
  }
}

/// Runs DLSS Frame Generation on a view each frame and shows generated frame
/// [index] of [multiFrameCount] (between the previous and the current frame)
/// in place of the current one; see [DlssFrameGeneration].
class DlssFrameInterpolator {
  DlssFrameInterpolator._(this.engine, this.view, this._ptr);

  final FilamentEngine engine;
  final FilamentView view;
  ffi.Pointer<ffi.Void> _ptr;

  /// Throws a [StateError] with [DlssFrameGeneration.lastErrorMessage] when
  /// unavailable.
  factory DlssFrameInterpolator.create({
    required FilamentEngine engine,
    required FilamentView view,
    int multiFrameCount = 1,
    int index = 1,
  }) {
    final ptr = c.filament_dlss_fg_interpolator_create(
      engine.nativePointer,
      view.nativePointer,
      multiFrameCount,
      index,
    );
    if (ptr == ffi.nullptr) {
      throw StateError(
        'DLSS Frame Generation: ${DlssFrameGeneration.lastErrorMessage ?? 'not available'}',
      );
    }
    return DlssFrameInterpolator._(engine, view, ptr);
  }

  bool get isDestroyed => _ptr == ffi.nullptr;

  /// Frames NGX generated an image for.
  int get frameCount =>
      isDestroyed ? 0 : c.filament_dlss_fg_interpolator_frame_count(_ptr);

  /// The NGX result of the last creation or evaluation (1 is success).
  int get lastResult =>
      isDestroyed ? 0 : c.filament_dlss_fg_interpolator_last_result(_ptr);

  /// GPU time of the last completed evaluation in nanoseconds.
  int get lastGpuTimeNanos =>
      isDestroyed ? 0 : c.filament_dlss_fg_interpolator_last_gpu_time_ns(_ptr);

  void destroy() {
    if (_ptr == ffi.nullptr) return;
    c.filament_dlss_fg_interpolator_destroy(_ptr);
    _ptr = ffi.nullptr;
  }
}
