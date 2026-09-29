import 'ffi_platform.dart' as ffi;

import 'package:flutter_filament/src/engine.dart';
import 'package:flutter_filament/src/filament_bindings.dart' as c;

/// Configuration flags for swap chain creation.
class SwapChainConfig {
  /// Raw bitfield value.
  final int value;

  const SwapChainConfig(this.value);

  const SwapChainConfig._(this.value);

  /// Default configuration with no special flags (0x0).
  static const SwapChainConfig none = SwapChainConfig._(0);

  /// Requests a SwapChain with an alpha channel for Flutter compositing.
  static const SwapChainConfig transparent = SwapChainConfig._(0x1);

  /// Allows the SwapChain to be used as a source for blit/readback operations.
  static const SwapChainConfig readable = SwapChainConfig._(0x2);

  /// Indicates that the native X11 window is an XCB window rather than XLIB.
  static const SwapChainConfig enableXcb = SwapChainConfig._(0x4);

  /// Indicates that the native window is a CVPixelBufferRef (Metal backend only).
  static const SwapChainConfig appleCvPixelBuffer = SwapChainConfig._(0x8);

  /// Enables automatic linear to sRGB encoding (if supported by backend).
  static const SwapChainConfig srgbColorspace = SwapChainConfig._(0x10);

  /// Allocates a stencil buffer in addition to a depth buffer.
  static const SwapChainConfig hasStencilBuffer = SwapChainConfig._(0x20);

  /// Indicates protected content (e.g. DRM-protected playback).
  static const SwapChainConfig protectedContent = SwapChainConfig._(0x40);

  /// Configures Multi-Sample Anti-Aliasing (4 samples) on the swap chain.
  static const SwapChainConfig msaa4Samples = SwapChainConfig._(0x80);

  /// Bitwise OR to combine swap chain config flags.
  SwapChainConfig operator |(SwapChainConfig other) =>
      SwapChainConfig._(value | other.value);

  /// Bitwise AND to check or mask config flags.
  SwapChainConfig operator &(SwapChainConfig other) =>
      SwapChainConfig._(value & other.value);

  /// Checks if this configuration contains all flags in [flag].
  bool contains(SwapChainConfig flag) => (value & flag.value) == flag.value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SwapChainConfig && runtimeType == other.runtimeType && value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'SwapChainConfig(0x${value.toRadixString(16)})';
}

/// Three-state result for frame rate change support query.
enum FrameRateChangeSupport {
  /// Dynamic frame rate change is definitely not supported.
  unsupported,

  /// Dynamic frame rate change is supported.
  supported,

  /// Support state is not yet sealed by the underlying OS/platform surface.
  indeterminate,
}

/// Frame rate compatibility mode for [FilamentSwapChain.setFrameRate].
enum FrameRateCompatibility {
  /// Default mode where OS may harmonize rate with other windows.
  defaultMode(0),

  /// Strongly prioritizes running at the exact requested rate (e.g. video playback).
  fixedSource(1);

  final int value;
  const FrameRateCompatibility(this.value);
}

/// Change strategy for non-seamless display frame rate transitions.
enum ChangeFrameRateStrategy {
  /// Frame rate transition is applied only if it can be done seamlessly without visual glitches.
  onlyIfSeamless(0),

  /// Transition is applied immediately, even if a non-seamless display mode switch occurs.
  always(1);

  final int value;
  const ChangeFrameRateStrategy(this.value);
}

/// A SwapChain represents the rendering target (typically a window surface).
///
/// Use [FilamentEngine.createSwapChain] for windowed rendering or
/// [FilamentEngine.createHeadlessSwapChain] for offscreen rendering.
class FilamentSwapChain {
  final ffi.Pointer<ffi.Void> _ptr;
  final FilamentEngine _engine;
  bool _disposed = false;

  ffi.NativeCallable<c.FilamentSwapChainCallbackFunction>? _scheduledCallable;
  ffi.NativeCallable<c.FilamentSwapChainCallbackFunction>? _completedCallable;

  void Function()? _onFrameScheduled;
  void Function()? _onFrameCompleted;

  /// Internal constructor.
  FilamentSwapChain.internal(this._ptr, this._engine);

  /// The raw native pointer to the Filament SwapChain.
  ffi.Pointer<ffi.Void> get nativePointer {
    _checkDisposed();
    return _ptr;
  }

  /// Returns whether the engine supports the [SwapChainConfig.srgbColorspace] flag.
  static bool isSRGBSupported(FilamentEngine engine) {
    return c.filament_swap_chain_is_srgb_supported(engine.nativePointer);
  }

  /// Returns whether the engine supports MSAA swap chains with [samples] count.
  static bool isMSAASupported(FilamentEngine engine, [int samples = 4]) {
    return c.filament_swap_chain_is_msaa_supported(engine.nativePointer, samples);
  }

  /// Returns whether the engine supports protected content swap chains.
  static bool isProtectedContentSupported(FilamentEngine engine) {
    return c.filament_swap_chain_is_protected_content_supported(engine.nativePointer);
  }

  /// Sets the intended display frame rate for this SwapChain (primarily effective on Android).
  void setFrameRate(
    double frameRate, {
    FrameRateCompatibility compatibility = FrameRateCompatibility.defaultMode,
    ChangeFrameRateStrategy strategy = ChangeFrameRateStrategy.onlyIfSeamless,
  }) {
    _checkDisposed();
    c.filament_swap_chain_set_frame_rate(
      _ptr,
      frameRate,
      compatibility.value,
      strategy.value,
    );
  }

  /// Returns whether this SwapChain supports dynamic frame rate changes.
  FrameRateChangeSupport get isFrameRateChangeSupported {
    _checkDisposed();
    final res = c.filament_swap_chain_is_frame_rate_change_supported(_ptr);
    switch (res) {
      case 0:
        return FrameRateChangeSupport.unsupported;
      case 1:
        return FrameRateChangeSupport.supported;
      default:
        return FrameRateChangeSupport.indeterminate;
    }
  }

  /// The raw native window address (0 for headless swap chains).
  int get nativeWindowAddress {
    _checkDisposed();
    return c.filament_swap_chain_get_native_window(_ptr).address;
  }

  /// Whether a frame scheduled callback is currently configured.
  bool get isFrameScheduledCallbackSet {
    _checkDisposed();
    return c.filament_swap_chain_is_frame_scheduled_callback_set(_ptr);
  }

  /// Sets or clears the callback invoked when a frame has finished CPU processing.
  set onFrameScheduled(void Function()? callback) {
    _checkDisposed();
    _onFrameScheduled = callback;
    _scheduledCallable?.close();
    _scheduledCallable = null;

    if (callback == null) {
      c.filament_swap_chain_set_frame_scheduled_callback(
        _ptr,
        ffi.nullptr,
        ffi.nullptr,
        0,
      );
    } else {
      _scheduledCallable = ffi.NativeCallable<c.FilamentSwapChainCallbackFunction>.listener(
        (ffi.Pointer<ffi.Void> swapChain, ffi.Pointer<ffi.Void> userData) {
          _onFrameScheduled?.call();
        },
      );
      c.filament_swap_chain_set_frame_scheduled_callback(
        _ptr,
        _scheduledCallable!.nativeFunction,
        ffi.nullptr,
        0,
      );
    }
  }

  /// Sets or clears the callback invoked when a frame has finished GPU rendering.
  set onFrameCompleted(void Function()? callback) {
    _checkDisposed();
    _onFrameCompleted = callback;
    _completedCallable?.close();
    _completedCallable = null;

    if (callback == null) {
      c.filament_swap_chain_set_frame_completed_callback(
        _ptr,
        ffi.nullptr,
        ffi.nullptr,
      );
    } else {
      _completedCallable = ffi.NativeCallable<c.FilamentSwapChainCallbackFunction>.listener(
        (ffi.Pointer<ffi.Void> swapChain, ffi.Pointer<ffi.Void> userData) {
          _onFrameCompleted?.call();
        },
      );
      c.filament_swap_chain_set_frame_completed_callback(
        _ptr,
        _completedCallable!.nativeFunction,
        ffi.nullptr,
      );
    }
  }

  /// Destroys this swap chain and releases its resources.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _scheduledCallable?.close();
    _scheduledCallable = null;
    _completedCallable?.close();
    _completedCallable = null;
    c.filament_engine_destroy_swap_chain(_engine.nativePointer, _ptr);
  }

  bool get isDisposed => _disposed;

  void _checkDisposed() {
    if (_disposed) {
      throw StateError('FilamentSwapChain has been disposed');
    }
  }
}
