import 'ffi_platform.dart' as ffi;
import 'ffi_package_platform.dart';

import 'package:flutter_filament/src/engine.dart';
import 'package:flutter_filament/src/texture.dart';
import 'package:flutter_filament/src/filament_bindings.dart' as c;

enum AttachmentPoint {
  color0(0),
  color1(1),
  color2(2),
  color3(3),
  color4(4),
  color5(5),
  color6(6),
  color7(7),
  depth(8);

  final int value;
  const AttachmentPoint(this.value);
}



class RenderTargetAttachment {
  final FilamentTexture texture;
  final int mipLevel;
  final CubemapFace? face;
  final int layer;

  const RenderTargetAttachment({
    required this.texture,
    this.mipLevel = 0,
    this.face,
    this.layer = 0,
  });
}

/// An offscreen render target (Frame Buffer Object / FBO) that can be associated with a View.
class FilamentRenderTarget {
  final ffi.Pointer<ffi.Void> _ptr;
  final FilamentEngine _engine;
  bool _disposed = false;

  FilamentRenderTarget._(this._ptr, this._engine);

  /// Returns the maximum number of color attachments supported by the engine.
  static int supportedColorAttachmentsCount(FilamentEngine engine) {
    return c.filament_render_target_get_supported_color_attachments_count(
      engine.nativePointer,
    );
  }

  /// Creates a new offscreen [FilamentRenderTarget] using the full builder.
  static FilamentRenderTarget build({
    required FilamentEngine engine,
    required List<RenderTargetAttachment?> colors,
    RenderTargetAttachment? depth,
    int samples = 1,
  }) {
    if (colors.length > 8) {
      throw ArgumentError.value(
        colors.length,
        'colors',
        'Maximum number of color attachments is 8',
      );
    }

    ffi.Pointer<c.filament_rt_attachment_t> colorPtr = ffi.nullptr;
    if (colors.isNotEmpty) {
      colorPtr = calloc<c.filament_rt_attachment_t>(colors.length);
      for (int i = 0; i < colors.length; i++) {
        final attachment = colors[i];
        if (attachment != null) {
          colorPtr[i].texture = attachment.texture.nativePointer;
          colorPtr[i].mip_level = attachment.mipLevel;
          colorPtr[i].face = attachment.face?.value ?? 0;
          colorPtr[i].layer = attachment.layer;
        } else {
          colorPtr[i].texture = ffi.nullptr;
        }
      }
    }

    ffi.Pointer<c.filament_rt_attachment_t> depthPtr = ffi.nullptr;
    if (depth != null) {
      depthPtr = calloc<c.filament_rt_attachment_t>();
      depthPtr.ref.texture = depth.texture.nativePointer;
      depthPtr.ref.mip_level = depth.mipLevel;
      depthPtr.ref.face = depth.face?.value ?? 0;
      depthPtr.ref.layer = depth.layer;
    }

    final ptr = c.filament_render_target_create_ex(
      engine.nativePointer,
      colorPtr,
      colors.length,
      depthPtr,
      samples,
    );

    if (colorPtr != ffi.nullptr) calloc.free(colorPtr);
    if (depthPtr != ffi.nullptr) calloc.free(depthPtr);

    return FilamentRenderTarget._(ptr, engine);
  }

  /// Creates a new offscreen [FilamentRenderTarget] with [colorTexture] and optional [depthTexture].
  static FilamentRenderTarget create({
    required FilamentEngine engine,
    required FilamentTexture colorTexture,
    FilamentTexture? depthTexture,
  }) {
    final ptr = c.filament_render_target_create(
      engine.nativePointer,
      colorTexture.nativePointer,
      depthTexture != null ? depthTexture.nativePointer : ffi.nullptr,
    );
    return FilamentRenderTarget._(ptr, engine);
  }

  /// Raw native pointer.
  ffi.Pointer<ffi.Void> get nativePointer {
    _checkDisposed();
    return _ptr;
  }

  /// Destroys this RenderTarget.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    c.filament_engine_destroy_render_target(_engine.nativePointer, _ptr);
  }

  bool get isDisposed => _disposed;

  void _checkDisposed() {
    if (_disposed) {
      throw StateError('FilamentRenderTarget has been disposed');
    }
  }
}
