/*
 * Copyright 2026 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

import 'dart:typed_data';

import 'package:flutter_filament/src/engine.dart';
import 'package:flutter_filament/src/ffi_platform.dart' as ffi;
import 'package:flutter_filament/src/filament_bindings.dart' as c;
import 'package:flutter_filament/src/renderer.dart';

/// A picture of a UI blended over the frame inside Filament: a translucent
/// View (post-processing off) with one quad covering its viewport, sampling a
/// premultiplied RGBA8 texture.
///
/// Render it with [render] after the Views it covers, in the same frame and
/// into the same SwapChain: it is then composited after tone mapping and the
/// upscaler, at the SwapChain's resolution, and Filament draws it again over
/// every frame-generation present (DLSS Frame Generation, FSR3 frame
/// generation), so the UI is never interpolated.
///
/// The pixels are Flutter's `ImageByteFormat.rawRgba` (premultiplied, rows top
/// to bottom); they are blended unchanged into a UNORM SwapChain, the way
/// Flutter blends them.
class FilamentUiOverlay {
  FilamentUiOverlay._(this._ptr, this._engine);

  final ffi.Pointer<ffi.Void> _ptr;
  final FilamentEngine _engine;
  bool _disposed = false;
  int _width = 0;
  int _height = 0;

  /// Creates an overlay on [engine]; null where it is unavailable (the web).
  static FilamentUiOverlay? create(FilamentEngine engine) {
    final ptr = c.filament_ui_overlay_create(engine.nativePointer);
    if (ptr.address == 0) return null;
    return FilamentUiOverlay._(ptr, engine);
  }

  /// The engine the overlay belongs to.
  FilamentEngine get engine => _engine;

  /// The overlay's area of the SwapChain in pixels, origin bottom-left.
  void setViewport(int left, int bottom, int width, int height) {
    _checkDisposed();
    c.filament_ui_overlay_set_viewport(_ptr, left, bottom, width, height);
  }

  /// Uploads [rgba] (premultiplied RGBA8, `width * height * 4` bytes, rows top
  /// to bottom) as the overlay's picture. False when the size does not match.
  bool upload(Uint8List rgba, int width, int height) {
    _checkDisposed();
    if (width <= 0 || height <= 0 || rgba.length < width * height * 4) return false;
    final buffer = c.filament_ui_overlay_begin_upload(_ptr, width, height);
    if (buffer.address == 0) return false;
    buffer.asTypedList(width * height * 4).setRange(0, width * height * 4, rgba);
    final ok = c.filament_ui_overlay_end_upload(_ptr);
    if (ok) {
      _width = width;
      _height = height;
    }
    return ok;
  }

  /// The size of the last uploaded picture (0 × 0 before one).
  (int, int) get pictureSize => (_width, _height);

  /// Forgets the picture: [render] draws nothing until the next [upload].
  void clear() {
    _checkDisposed();
    c.filament_ui_overlay_clear(_ptr);
  }

  /// Whether a picture is uploaded and [render] draws it.
  bool get hasContent => !_disposed && c.filament_ui_overlay_has_content(_ptr);

  /// Renders the overlay's View with [renderer] when it has a picture (between
  /// `beginFrame` and `endFrame`, after the Views it covers); whether it drew.
  bool render(FilamentRenderer renderer) {
    _checkDisposed();
    return c.filament_ui_overlay_render(renderer.nativePointer, _ptr);
  }

  /// The overlay's View, owned by the overlay (its viewport is [setViewport]'s).
  ffi.Pointer<ffi.Void> get viewPointer {
    _checkDisposed();
    return c.filament_ui_overlay_get_view(_ptr);
  }

  /// Microseconds the last [upload] took on the calling thread (copying the
  /// pixels into the engine's buffer and queuing the texture update).
  int get lastUploadMicros => _disposed ? 0 : c.filament_ui_overlay_last_upload_micros(_ptr);

  /// Pictures uploaded so far.
  int get uploadCount => _disposed ? 0 : c.filament_ui_overlay_upload_count(_ptr);

  /// Destroys the overlay's View, scene, quad, material and texture.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    c.filament_ui_overlay_destroy(_ptr);
  }

  void _checkDisposed() {
    if (_disposed) throw StateError('FilamentUiOverlay is disposed');
  }
}
