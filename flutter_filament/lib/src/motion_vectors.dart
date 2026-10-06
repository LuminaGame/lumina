import 'dart:typed_data';

import 'ffi_platform.dart' as ffi;
import 'ffi_package_platform.dart';

import 'package:flutter_filament/src/engine.dart';
import 'package:flutter_filament/src/enums.dart';
import 'package:flutter_filament/src/filament_bindings.dart' as c;
import 'package:flutter_filament/src/render_target.dart';
import 'package:flutter_filament/src/renderer.dart';
import 'package:flutter_filament/src/texture.dart';
import 'package:flutter_filament/src/view.dart';

/// The motion vectors of a [FilamentView] as a readable buffer: an RGBA16F
/// texture the view exports into while
/// [TemporalAntiAliasingOptions.motionVectors] is on, the render target that
/// reads it back, and the readback itself.
///
/// Each texel holds the screen-space offset of the surface seen there since
/// the previous frame, in texels of the view's render resolution, x to the
/// right and y up; the background is zero. The texture must have exactly the
/// size of the view's render target (its viewport), or the view ignores it.
///
/// ```dart
/// final motion = MotionVectorBuffer.attach(engine: engine, view: view, width: 256, height: 256);
/// view.temporalAntiAliasingOptions = view.temporalAntiAliasingOptions.copyWith(enabled: true, motionVectors: true);
/// // render frames...
/// final velocity = await motion.read(renderer);  // width * height * 2 floats
/// motion.dispose();
/// ```
class MotionVectorBuffer {
  MotionVectorBuffer._(this.engine, this.view, this.texture, this.renderTarget, this.width, this.height);

  final FilamentEngine engine;
  final FilamentView view;
  final FilamentTexture texture;
  final FilamentRenderTarget renderTarget;
  final int width;
  final int height;
  bool _disposed = false;

  /// Creates the texture and render target and makes [view] export its motion
  /// vectors into them. Throws when the engine cannot render motion vectors
  /// ([FilamentView.motionVectorsSupported]).
  factory MotionVectorBuffer.attach({
    required FilamentEngine engine,
    required FilamentView view,
    required int width,
    required int height,
  }) {
    if (!view.motionVectorsSupported) {
      throw StateError('motion vectors are not supported by this engine (noop backend or feature level 0)');
    }
    if (width <= 0 || height <= 0) {
      throw ArgumentError('the motion vector buffer needs a positive size, got ${width}x$height');
    }
    final texture = FilamentTexture.create2D(
      engine: engine,
      width: width,
      height: height,
      format: TextureFormat.rgba16f,
      usage: TextureUsage.colorAttachment | TextureUsage.sampleable | TextureUsage.blitSrc,
    );
    final renderTarget = FilamentRenderTarget.create(engine: engine, colorTexture: texture);
    view.motionVectorTexture = texture;
    return MotionVectorBuffer._(engine, view, texture, renderTarget, width, height);
  }

  /// Reads the motion vectors of the last rendered frame: `width * height * 2`
  /// floats, two per texel (x, y), rows from the bottom of the image up
  /// (Filament's read-back origin). [velocityAt] indexes them with a top-down
  /// pixel coordinate.
  Future<Float32List> read(FilamentRenderer renderer) async {
    _checkDisposed();
    // The texture is RGBA16F; the readback asks for the texture's own
    // component type (half floats), which every backend hands back verbatim,
    // and widens to float here.
    const channels = 4;
    final halves = width * height * channels;
    final buffer = calloc<ffi.Uint16>(halves);
    try {
      c.filament_renderer_read_pixels_render_target(
        renderer.nativePointer,
        renderTarget.nativePointer,
        0,
        0,
        width,
        height,
        PixelDataFormat.rgba.value,
        PixelDataType.half.value,
        buffer.cast(),
        halves * 2,
        ffi.nullptr,
        ffi.nullptr,
      );
      engine.flushAndWait();
      final rgba = buffer.asTypedList(halves);
      final out = Float32List(width * height * 2);
      for (var i = 0, o = 0; i < halves; i += channels, o += 2) {
        out[o] = halfToFloat(rgba[i]);
        out[o + 1] = halfToFloat(rgba[i + 1]);
      }
      return out;
    } finally {
      calloc.free(buffer);
    }
  }

  /// IEEE 754 binary16 → binary32.
  static double halfToFloat(int h) {
    final sign = (h & 0x8000) != 0 ? -1.0 : 1.0;
    final exponent = (h >> 10) & 0x1F;
    final mantissa = h & 0x3FF;
    if (exponent == 0) {
      return sign * mantissa * 5.960464477539063e-8; // 2^-24
    }
    if (exponent == 0x1F) {
      return mantissa == 0 ? sign * double.infinity : double.nan;
    }
    return sign * (1 + mantissa / 1024.0) * _pow2(exponent - 15);
  }

  static double _pow2(int e) {
    var v = 1.0;
    if (e >= 0) {
      for (var i = 0; i < e; i++) {
        v *= 2;
      }
    } else {
      for (var i = 0; i < -e; i++) {
        v /= 2;
      }
    }
    return v;
  }

  /// The (x, y) motion at pixel ([x], [y]) of a buffer returned by [read],
  /// with `y == 0` the top row of the image.
  (double, double) velocityAt(Float32List velocity, int x, int y) {
    final row = height - 1 - y;
    final i = (row * width + x) * 2;
    return (velocity[i], velocity[i + 1]);
  }

  /// Stops the export and destroys the render target and the texture.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (!view.isDisposed && identical(view.motionVectorTexture, texture)) {
      view.motionVectorTexture = null;
    }
    renderTarget.dispose();
    texture.dispose();
  }

  bool get isDisposed => _disposed;

  void _checkDisposed() {
    if (_disposed) throw StateError('MotionVectorBuffer has been disposed');
  }
}
