import 'package:flutter_filament/src/ffi_platform.dart' as ffi;
import 'package:flutter_filament/src/ffi_package_platform.dart';

import 'package:flutter_filament/src/engine.dart';
import 'package:flutter_filament/src/filament_bindings.dart' as c;
import 'package:flutter_filament/src/view.dart';

const int _messageBytes = 1024;

String _read(ffi.Pointer<ffi.Char> buffer) => buffer.cast<Utf8>().toDartString();

/// Why an engine can or cannot run the OpenDLSS-NR pass.
enum OpenDlssNrCapabilityCode {
  capable,

  /// Not the desktop Vulkan backend (or the web, another platform).
  notVulkan,

  /// Not an NVIDIA GPU.
  notNvidia,

  /// The driver lacks an extension the kernels need.
  missingExtension,

  /// An NVIDIA GPU older than Ada (no FP8 tensor cores).
  olderGpu,

  /// The GPU supports it, but the engine was created before
  /// [OpenDlssNr.requestDeviceFeatures].
  notEnabled;

  static OpenDlssNrCapabilityCode fromNative(int code) =>
      code >= 0 && code < values.length ? values[code] : notVulkan;
}

/// The capability check of one engine.
class OpenDlssNrCapability {
  const OpenDlssNrCapability(this.code, this.reason);

  final OpenDlssNrCapabilityCode code;

  /// The reason it cannot run, or `supported on <GPU>`.
  final String reason;

  bool get supported => code == OpenDlssNrCapabilityCode.capable;

  @override
  String toString() => 'OpenDlssNrCapability(${code.name}: $reason)';
}

/// The outcome of [OpenDlssNr.validateModel].
enum OpenDlssNrModelCode {
  ok,

  /// No folder, or no `manifest.json` in it.
  missing,

  /// Not JSON, too large or deep, missing keys, a block count other than 71.
  invalidManifest,

  /// A stage file missing, of the wrong size, or with an unsafe name.
  stageMismatch,

  /// A tensor the network reads missing, too small, or outside its stage.
  layoutMismatch,

  /// A stage file whose SHA-256 differs from the manifest.
  hashMismatch,
  ioError,

  /// Not available on this platform.
  unavailable;

  static OpenDlssNrModelCode fromNative(int code) =>
      code >= 0 && code < values.length ? values[code] : ioError;
}

/// A checked model folder.
class OpenDlssNrModelCheck {
  const OpenDlssNrModelCheck({
    required this.code,
    required this.message,
    this.blockCount = 0,
    this.stageCount = 0,
    this.tensorCount = 0,
    this.totalBytes = 0,
  });

  final OpenDlssNrModelCode code;
  final String message;
  final int blockCount;
  final int stageCount;
  final int tensorCount;
  final int totalBytes;

  bool get ok => code == OpenDlssNrModelCode.ok;

  @override
  String toString() =>
      'OpenDlssNrModelCheck(${code.name}: $message, $blockCount blocks, $stageCount stages, $tensorCount tensors, $totalBytes bytes)';
}

/// The style id the network sees (and the composite's preset).
enum OpenDlssNrStyle { none, natural, cinematic }

/// The pass's controls: the network's conditioning scalars and the composite.
class OpenDlssNrControls {
  const OpenDlssNrControls({
    this.enabled = true,
    this.intensity = 1.0,
    this.localTone = 1.0,
    this.localStructure = 1.0,
    this.skinStructure = -1.0,
    this.autoMask = true,
    this.style = OpenDlssNrStyle.none,
    this.paperWhite = 1.0,
    this.colorStrength = 1.0,
  });

  /// False: the frame passes through unchanged (the history stays primed).
  final bool enabled;

  /// 0..1: blend back towards the frame.
  final double intensity;
  final double localTone;
  final double localStructure;

  /// -1 follows [localStructure].
  final double skinStructure;
  final bool autoMask;
  final OpenDlssNrStyle style;

  /// The scene value the network's display proxy shows as paper white.
  final double paperWhite;

  /// 0 keeps the frame's colours (luminance only), 1 takes the network's.
  final double colorStrength;

  @override
  bool operator ==(Object other) =>
      other is OpenDlssNrControls &&
      other.enabled == enabled &&
      other.intensity == intensity &&
      other.localTone == localTone &&
      other.localStructure == localStructure &&
      other.skinStructure == skinStructure &&
      other.autoMask == autoMask &&
      other.style == style &&
      other.paperWhite == paperWhite &&
      other.colorStrength == colorStrength;

  @override
  int get hashCode =>
      Object.hash(enabled, intensity, localTone, localStructure, skinStructure, autoMask, style, paperWhite, colorStrength);
}

/// The state of a running pass.
class OpenDlssNrStatus {
  const OpenDlssNrStatus({
    required this.frames,
    required this.width,
    required this.height,
    required this.failed,
    required this.failure,
    required this.gpuMs,
    required this.gpuMsAverage,
    required this.dispatches,
    required this.deviceBytes,
  });

  final int frames;
  final int width;
  final int height;

  /// The pass turned itself off; [failure] says why.
  final bool failed;
  final String failure;

  /// GPU time of the last measured frame (features + network + composite).
  final double gpuMs;
  final double gpuMsAverage;
  final int dispatches;

  /// Device memory the model and the pass hold.
  final int deviceBytes;
}

/// OpenDLSS-NR (experimental, third-party): the network of
/// github.com/maanHimself/OpenDLSS-NR (MIT; its GLSL cooperative-matrix route is
/// vendored in `third_party/opendlss_nr`) as an external post pass on the HDR
/// frame, after TAA / FSR3 and before bloom and colour grading.
///
/// It runs only on model weights the user supplies; flutter_filament ships,
/// fetches and derives none. Desktop Vulkan on NVIDIA Ada or newer only; on
/// the web and elsewhere every call reports "not available".
abstract final class OpenDlssNr {
  /// The upstream project page (its own requirements are documented there).
  static const String upstreamUrl = 'https://github.com/maanHimself/OpenDLSS-NR';

  /// The upstream commit the vendored sources come from.
  static const String upstreamCommit = '9d08f41';

  /// Asks the engines created from now on for the device extensions and
  /// features the kernels need.
  static void requestDeviceFeatures() => c.filament_opendlss_nr_request_device_features();

  static OpenDlssNrCapability capability(FilamentEngine engine) {
    final reason = calloc<ffi.Char>(_messageBytes);
    try {
      final code = c.filament_opendlss_nr_capability(engine.nativePointer, reason, _messageBytes);
      return OpenDlssNrCapability(OpenDlssNrCapabilityCode.fromNative(code), _read(reason));
    } finally {
      calloc.free(reason);
    }
  }

  /// Checks a model folder (`manifest.json` + `model/<stage files>`) against
  /// what the network reads. Blocking (reads the folder, and every stage file
  /// with [verifyHashes]): call it from a background isolate.
  static OpenDlssNrModelCheck validateModel(String directory, {bool verifyHashes = false}) {
    final dir = directory.toNativeUtf8();
    final info = calloc<c.filament_opendlss_nr_model_info>();
    final message = calloc<ffi.Char>(_messageBytes);
    try {
      final code = c.filament_opendlss_nr_validate_model(dir.cast(), verifyHashes, info, message, _messageBytes);
      return OpenDlssNrModelCheck(
        code: OpenDlssNrModelCode.fromNative(code),
        message: _read(message),
        blockCount: info.ref.block_count,
        stageCount: info.ref.stage_count,
        tensorCount: info.ref.tensor_count,
        totalBytes: info.ref.total_bytes,
      );
    } finally {
      calloc.free(dir);
      calloc.free(info);
      calloc.free(message);
    }
  }

  /// Writes a synthetic model of the network's layout into [directory]
  /// (zeros, or small random values from [seed] with [random]). It holds no
  /// trained weights: tests and timing only. Throws [StateError] on failure.
  static void writeSyntheticModel(String directory, {int seed = 1, bool random = false}) {
    final dir = directory.toNativeUtf8();
    final message = calloc<ffi.Char>(_messageBytes);
    try {
      final code = c.filament_opendlss_nr_write_synthetic_model(dir.cast(), seed, random ? 1 : 0, message, _messageBytes);
      if (code != 0) throw StateError('OpenDLSS-NR synthetic model: ${_read(message)}');
    } finally {
      calloc.free(dir);
      calloc.free(message);
    }
  }

  /// Loads a validated model onto the engine at [engineAddress]
  /// ([FilamentEngine.nativePointer]'s address) and returns the model's
  /// address. Blocking, no Filament calls: meant for a background isolate.
  /// Throws [StateError] with the reason.
  static int loadModelAddress(int engineAddress, String directory) {
    final dir = directory.toNativeUtf8();
    final message = calloc<ffi.Char>(_messageBytes);
    try {
      final ptr = c.filament_opendlss_nr_model_load(ffi.Pointer.fromAddress(engineAddress), dir.cast(), message, _messageBytes);
      if (ptr == ffi.nullptr) throw StateError(_read(message));
      return ptr.address;
    } finally {
      calloc.free(dir);
      calloc.free(message);
    }
  }

  /// [loadModelAddress] on this isolate.
  static OpenDlssNrModel loadModel(FilamentEngine engine, String directory) =>
      OpenDlssNrModel.fromAddress(engine, loadModelAddress(engine.nativePointer.address, directory));
}

/// Model weights on an engine's device, shared by the passes of that engine.
class OpenDlssNrModel {
  OpenDlssNrModel.fromAddress(this.engine, int address) : _ptr = ffi.Pointer<ffi.Void>.fromAddress(address);

  final FilamentEngine engine;
  ffi.Pointer<ffi.Void> _ptr;

  bool get isDestroyed => _ptr == ffi.nullptr;

  ffi.Pointer<ffi.Void> get nativePointer {
    if (_ptr == ffi.nullptr) throw StateError('OpenDlssNrModel has been destroyed');
    return _ptr;
  }

  /// Frees the weights (waits for the engine). Destroy every pass first. A
  /// second call is a no-op.
  void destroy() {
    if (_ptr == ffi.nullptr) return;
    c.filament_opendlss_nr_model_destroy(_ptr);
    _ptr = ffi.nullptr;
  }
}

/// The OpenDLSS-NR pass on one view.
class OpenDlssNrPass {
  OpenDlssNrPass._(this.engine, this.view, this.model, this._ptr);

  final FilamentEngine engine;
  final FilamentView view;
  final OpenDlssNrModel model;
  ffi.Pointer<ffi.Void> _ptr;
  OpenDlssNrControls _controls = const OpenDlssNrControls();

  /// Registers the pass on [view]. Throws [StateError] with the reason when it
  /// cannot run there (capability, a model of another engine).
  factory OpenDlssNrPass.create({
    required FilamentEngine engine,
    required FilamentView view,
    required OpenDlssNrModel model,
    OpenDlssNrControls controls = const OpenDlssNrControls(),
  }) {
    final message = calloc<ffi.Char>(_messageBytes);
    try {
      final ptr = c.filament_opendlss_nr_create(
        engine.nativePointer,
        view.nativePointer,
        model.nativePointer,
        message,
        _messageBytes,
      );
      if (ptr == ffi.nullptr) throw StateError('OpenDLSS-NR: ${_read(message)}');
      return OpenDlssNrPass._(engine, view, model, ptr)..controls = controls;
    } finally {
      calloc.free(message);
    }
  }

  bool get isDestroyed => _ptr == ffi.nullptr;

  OpenDlssNrControls get controls => _controls;

  /// Takes effect at the next frame.
  set controls(OpenDlssNrControls value) {
    if (_ptr == ffi.nullptr) throw StateError('OpenDlssNrPass has been destroyed');
    _controls = value;
    final native = calloc<c.filament_opendlss_nr_controls>();
    try {
      native.ref
        ..enabled = value.enabled
        ..intensity = value.intensity
        ..local_tone = value.localTone
        ..local_structure = value.localStructure
        ..skin_structure = value.skinStructure
        ..auto_mask = value.autoMask
        ..style = value.style.index
        ..paper_white = value.paperWhite
        ..color_strength = value.colorStrength;
      c.filament_opendlss_nr_set_controls(_ptr, native);
    } finally {
      calloc.free(native);
    }
  }

  OpenDlssNrStatus get status {
    if (_ptr == ffi.nullptr) throw StateError('OpenDlssNrPass has been destroyed');
    final native = calloc<c.filament_opendlss_nr_status>();
    final failure = calloc<ffi.Char>(_messageBytes);
    try {
      c.filament_opendlss_nr_get_status(_ptr, native, failure, _messageBytes);
      final s = native.ref;
      return OpenDlssNrStatus(
        frames: s.frames,
        width: s.width,
        height: s.height,
        failed: s.failed,
        failure: _read(failure),
        gpuMs: s.gpu_ms,
        gpuMsAverage: s.gpu_ms_average,
        dispatches: s.dispatches,
        deviceBytes: s.device_bytes,
      );
    } finally {
      calloc.free(native);
      calloc.free(failure);
    }
  }

  /// Unregisters the pass and frees it (waits for the engine). A second call
  /// is a no-op.
  void destroy() {
    if (_ptr == ffi.nullptr) return;
    c.filament_opendlss_nr_destroy(_ptr);
    _ptr = ffi.nullptr;
  }
}
