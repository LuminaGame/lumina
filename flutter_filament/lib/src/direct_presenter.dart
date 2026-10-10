/*
 * Copyright 2026 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

import 'package:flutter/foundation.dart';

import 'package:flutter_filament/src/engine.dart';
import 'package:flutter_filament/src/ffi_platform.dart' as ffi;
import 'package:flutter_filament/src/native_surface.dart';
import 'package:flutter_filament/src/renderer.dart';
import 'package:flutter_filament/src/swap_chain.dart';
import 'package:flutter_filament/src/ui_overlay.dart';

/// Direct presentation of a [FilamentWidget]: a Vulkan SwapChain on the
/// host's native window and the [FilamentUiOverlay] the host's UI is blended
/// with. The widget renders its views and then [overlay] into [swapChain];
/// Filament presents (VSync: the swap chain's FIFO; no VSync:
/// [SwapChainConfig.disableVsync], whose presents the backend paces, frame
/// generation included).
class FilamentDirectPresenter {
  FilamentDirectPresenter._(this._engine, this._surface, this._handle, this._swapChain, this.overlay, this._vsync);

  final FilamentEngine _engine;
  final FilamentNativeSurface _surface;
  FilamentNativeSurfaceHandle _handle;
  FilamentSwapChain? _swapChain;
  bool _vsync;
  bool _disposed = false;

  /// The UI blended over the frame (the host uploads its pictures).
  final FilamentUiOverlay overlay;

  /// The renderer presenting into [swapChain] (set by the widget).
  FilamentRenderer? renderer;

  static FilamentDirectPresenter? _active;

  /// The presenter started last and still running: diagnostics (a game's
  /// presented frame rate).
  static FilamentDirectPresenter? get active => _active;

  /// The steady-clock times (ns) of the last [max] presents into the window
  /// (the backend's actual present times without VSync, the commits with).
  List<int> presentTimes([int max = 1024]) => renderer?.getPresentTimes(max) ?? const [];

  /// The SwapChain on the native window; null after a recreation failed
  /// ([failure] says why): the widget then goes back to the texture path.
  FilamentSwapChain? get swapChain => _swapChain;

  /// Why the SwapChain is gone, if it is.
  String? failure;

  /// The native window and its size in physical pixels.
  FilamentNativeSurfaceHandle get handle => _handle;

  /// The surface's handle and size changes.
  ValueListenable<FilamentNativeSurfaceHandle?> get surfaceListenable => _surface.current;

  /// Whether the swap chain waits for the display's vertical sync.
  bool get vsync => _vsync;

  /// Why direct presentation cannot run with [engine] here; null when it can
  /// be tried.
  static String? unsupportedReason(FilamentEngine engine) {
    if (kIsWeb) return 'unsupported on the web (the browser presents the canvas)';
    if (engine.backend != FilamentBackend.vulkan) return 'needs the Vulkan backend (running ${engine.backend.name})';
    return null;
  }

  /// Acquires [surface] and creates the swap chain and the overlay on it.
  /// Returns the presenter, or null with the reason.
  static Future<(FilamentDirectPresenter?, String?)> start(
    FilamentEngine engine,
    FilamentNativeSurface surface, {
    required bool vsync,
  }) async {
    final unsupported = unsupportedReason(engine);
    if (unsupported != null) return (null, unsupported);
    FilamentNativeSurfaceHandle? handle;
    try {
      handle = await surface.acquire();
    } catch (e) {
      return (null, 'the native window could not be created: $e');
    }
    if (handle == null || handle.handle == 0) {
      return (null, surface.unavailableReason ?? 'the host has no native window');
    }
    if (engine.isDisposed) {
      await surface.release();
      return (null, 'the engine is gone');
    }
    final swapChain = _createSwapChain(engine, handle, vsync);
    if (swapChain == null) {
      await surface.release();
      return (null, 'Filament could not create a swap chain on the native window');
    }
    final overlay = FilamentUiOverlay.create(engine);
    if (overlay == null) {
      swapChain.dispose();
      await surface.release();
      return (null, 'the UI overlay material could not be created');
    }
    overlay.setViewport(0, 0, handle.width, handle.height);
    final presenter = FilamentDirectPresenter._(engine, surface, handle, swapChain, overlay, vsync);
    _active = presenter;
    return (presenter, null);
  }

  static FilamentSwapChain? _createSwapChain(FilamentEngine engine, FilamentNativeSurfaceHandle handle, bool vsync) {
    try {
      final swapChain = engine.createSwapChain(ffi.Pointer<ffi.Void>.fromAddress(handle.handle),
          flags: vsync ? SwapChainConfig.none : SwapChainConfig.disableVsync);
      if (swapChain.nativePointer.address == 0) return null;
      return swapChain;
    } catch (_) {
      return null;
    }
  }

  /// Follows a new size (or window) of the surface; the overlay covers it.
  void updateHandle(FilamentNativeSurfaceHandle next) {
    if (_disposed || next == _handle) return;
    final windowChanged = next.handle != _handle.handle;
    _handle = next;
    if (windowChanged && next.handle != 0) _recreate();
    if (next.isVisible) overlay.setViewport(0, 0, next.width, next.height);
  }

  /// VSync on: FIFO presents; off: presents without waiting for the display
  /// (the frame-generation presents are paced by the backend). Recreates the
  /// swap chain when it changes.
  void setVsync(bool vsync) {
    if (_disposed || vsync == _vsync) return;
    _vsync = vsync;
    _recreate();
  }

  /// A window holds one swap chain at a time (a second one is
  /// VK_ERROR_NATIVE_WINDOW_IN_USE_KHR): the old one goes first.
  void _recreate() {
    _engine.flushAndWait();
    _swapChain?.dispose();
    _swapChain = _createSwapChain(_engine, _handle, _vsync);
    if (_swapChain == null) failure = 'the swap chain could not be created again on the native window';
  }

  /// The main view's viewport in the surface (origin bottom-left): the whole
  /// surface, or with a [renderResolution] the largest centred rectangle of
  /// its aspect ratio (letterboxed; the frame renders at that rectangle's
  /// pixels, Resolution Scale and upscalers apply inside it).
  ///
  /// The size is rounded down to even pixels: DLSS Frame Generation writes
  /// black generated frames for an odd width or height (a window whose
  /// client area is 1264 × 861 flickered); the edge left over is a pixel.
  static (int, int, int, int) viewportFor(int width, int height, {double? renderAspect}) {
    int even(int v) => v > 1 ? v & ~1 : v;
    if (width <= 0 || height <= 0) return (0, 0, width, height);
    final surfaceAspect = width / height;
    if (renderAspect == null || renderAspect <= 0 || (surfaceAspect - renderAspect).abs() < 1e-3) {
      return (0, 0, even(width), even(height));
    }
    if (renderAspect > surfaceAspect) {
      final h = even((width / renderAspect).round().clamp(1, height));
      return (0, (height - h) ~/ 2, even(width), h);
    }
    final w = even((height * renderAspect).round().clamp(1, width));
    return ((width - w) ~/ 2, 0, w, even(height));
  }

  /// Destroys the swap chain and the overlay and releases the window.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    if (identical(_active, this)) _active = null;
    renderer = null;
    try {
      if (!_engine.isDisposed) _engine.flushAndWait();
    } catch (_) {}
    if (!_engine.isDisposed) {
      overlay.dispose();
      _swapChain?.dispose();
      _swapChain = null;
    }
    await _surface.release();
  }
}
