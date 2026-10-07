import 'package:flutter_filament/src/ffi_platform.dart' as ffi;
import 'package:flutter_filament/src/ffi_package_platform.dart';

import 'package:flutter_filament/src/engine.dart';
import 'package:flutter_filament/src/filament_bindings.dart' as c;
import 'package:flutter_filament/src/view.dart';
import 'package:flutter_filament/src/view_options.dart';

/// DLSS Super Resolution quality modes (NVIDIA NGX `PerfQuality` values).
enum DlssQuality {
  /// About 50% render scale per axis.
  maxPerformance,

  /// About 58% render scale per axis.
  balanced,

  /// About 67% render scale per axis.
  maxQuality,

  /// About 33% render scale per axis.
  ultraPerformance,

  /// Native resolution: DLSS as an anti-aliasing pass only.
  dlaa;

  int toNative() => index;
}

/// What a [Dlss] feature is created with.
class DlssOptions {
  const DlssOptions({
    this.quality = DlssQuality.balanced,
    required this.outputWidth,
    required this.outputHeight,
    this.hdr = false,
    this.autoExposure = true,
    this.sharpness = 0.0,
  });

  final DlssQuality quality;

  /// The view's viewport (output) size; DLSS renders smaller and reconstructs this.
  final int outputWidth;
  final int outputHeight;

  /// The colour input is HDR. Filament hands DLSS the frame after colour
  /// grading, which is LDR, so this stays false unless the pipeline changes.
  final bool hdr;

  /// Let DLSS measure exposure itself (recommended for LDR input).
  final bool autoExposure;

  /// 0 (off) to 1; current DLSS releases ignore it.
  final double sharpness;

  DlssOptions copyWith({
    DlssQuality? quality,
    int? outputWidth,
    int? outputHeight,
    bool? hdr,
    bool? autoExposure,
    double? sharpness,
  }) {
    return DlssOptions(
      quality: quality ?? this.quality,
      outputWidth: outputWidth ?? this.outputWidth,
      outputHeight: outputHeight ?? this.outputHeight,
      hdr: hdr ?? this.hdr,
      autoExposure: autoExposure ?? this.autoExposure,
      sharpness: sharpness ?? this.sharpness,
    );
  }
}

/// DLSS Super Resolution on a [FilamentView]: the view renders at the
/// resolution NGX picks for the quality mode and DLSS reconstructs the output
/// size through Filament's external upscaler pass.
///
/// Requirements, in order:
///
/// 1. The NGX SDK fetched by `tool/dlss/fetch_sdk.dart` (NVIDIA's licence,
///    never committed), so that [available] is true on an NVIDIA GPU.
/// 2. [requestExtensions] **before** the engine is created: NGX needs Vulkan
///    instance and device extensions that cannot be added afterwards.
/// 3. An engine on the Vulkan backend, a view with
///    `TemporalAntiAliasingOptions(enabled: true, motionVectors: true)` (the
///    jittered camera and the motion vectors feed DLSS; Filament's own TAA
///    resolve is skipped while DLSS is active).
///
/// ```dart
/// Dlss.requestExtensions();
/// final engine = FilamentEngine.create(backend: FilamentBackend.vulkan)!;
/// // ... view, scene, camera
/// view.temporalAntiAliasingOptions = const TemporalAntiAliasingOptions(enabled: true, motionVectors: true);
/// final dlss = Dlss.create(engine: engine, view: view,
///     options: const DlssOptions(quality: DlssQuality.balanced, outputWidth: 1920, outputHeight: 1080));
/// // render frames; dlss.renderResolution tells the internal size
/// dlss.destroy();
/// ```
///
/// A resized view needs a new [Dlss] with the new output size.
class Dlss {
  Dlss._(this.engine, this.view, this._ptr);

  final FilamentEngine engine;
  final FilamentView view;
  ffi.Pointer<ffi.Void> _ptr;

  /// The NGX runtime was found and an NVIDIA Vulkan device is present. False on
  /// the web, on other GPUs and on a checkout without the fetched SDK.
  static bool get available => c.filament_dlss_available();

  /// Asks engines created from now on for the Vulkan extensions NGX needs.
  /// Returns false, changing nothing, when DLSS is not [available].
  static bool requestExtensions() => c.filament_dlss_request_extensions();

  /// Forgets [requestExtensions]: later engines are created without the NGX
  /// extensions (and cannot host DLSS).
  static void clearExtensionRequest() => c.filament_dlss_clear_extension_request();

  /// Where the `nvngx_dlss` runtime is looked for first: an SDK root (the
  /// folder `tool/dlss/fetch_sdk.dart` fills) or the folder holding the library.
  /// Checked ahead of `LUMINA_DLSS_DIR`, the executable folder and the working
  /// directory; null forgets the hint. Set it before [available] is read.
  static set runtimeDirectory(String? dir) {
    if (dir == null || dir.isEmpty) {
      c.filament_dlss_set_runtime_dir(ffi.nullptr);
      return;
    }
    final ptr = dir.toNativeUtf8();
    try {
      c.filament_dlss_set_runtime_dir(ptr.cast());
    } finally {
      calloc.free(ptr);
    }
  }

  /// The last error NGX or the wrapper reported (process-wide), or null after a
  /// successful call; also readable per instance as [lastError].
  static String? get lastErrorMessage {
    final ptr = c.filament_dlss_last_error();
    if (ptr == ffi.nullptr) return null;
    return ptr.cast<Utf8>().toDartString();
  }

  /// Initialises NGX for [engine]'s device, picks the render resolution for
  /// [options] and switches [view] to the external upscaler. Throws a
  /// [StateError] carrying [lastError] when DLSS is unavailable, the engine was
  /// created without [requestExtensions], or NGX declines.
  factory Dlss.create({
    required FilamentEngine engine,
    required FilamentView view,
    required DlssOptions options,
  }) {
    final native = calloc<c.filament_dlss_options_t>();
    try {
      native.ref
        ..quality = options.quality.toNative()
        ..outputWidth = options.outputWidth
        ..outputHeight = options.outputHeight
        ..hdr = options.hdr
        ..autoExposure = options.autoExposure
        ..sharpness = options.sharpness;
      final ptr = c.filament_dlss_create(engine.nativePointer, view.nativePointer, native);
      if (ptr == ffi.nullptr) {
        throw StateError('DLSS: ${lastErrorMessage ?? 'DLSS runtime not available'}');
      }
      return Dlss._(engine, view, ptr);
    } finally {
      calloc.free(native);
    }
  }

  bool get isDestroyed => _ptr == ffi.nullptr;

  void _checkDestroyed() {
    if (_ptr == ffi.nullptr) throw StateError('Dlss has been destroyed');
  }

  /// The render resolution NGX chose for the current quality.
  (int, int) get renderResolution {
    _checkDestroyed();
    final out = calloc<ffi.Uint32>(2);
    try {
      c.filament_dlss_get_render_resolution(_ptr, out, out + 1);
      return (out[0], out[1]);
    } finally {
      calloc.free(out);
    }
  }

  /// Changes the quality mode: the feature is recreated on the next frame and
  /// the view's dynamic resolution scale follows [renderResolution].
  set quality(DlssQuality quality) {
    _checkDestroyed();
    c.filament_dlss_set_quality(_ptr, quality.toNative());
  }

  /// Resets the temporal history for the next frame (camera cuts, teleports).
  void resetHistory() {
    _checkDestroyed();
    c.filament_dlss_reset_history(_ptr);
  }

  /// The last error reported (process-wide), or null; see [Dlss.lastErrorMessage].
  String? get lastError => lastErrorMessage;

  /// Releases the feature and returns the view to [Upscaler.builtin] with
  /// dynamic resolution disabled. A second call is a no-op.
  void destroy() {
    if (_ptr == ffi.nullptr) return;
    c.filament_dlss_destroy(_ptr);
    _ptr = ffi.nullptr;
  }
}
