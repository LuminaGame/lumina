import 'dart:typed_data';

import 'package:flutter_filament/src/ffi_platform.dart' as ffi;
import 'package:flutter_filament/src/ffi_package_platform.dart';

import 'package:flutter_filament/src/engine.dart';
import 'package:flutter_filament/src/enums.dart';
import 'package:flutter_filament/src/filament_bindings.dart' as c;
import 'package:flutter_filament/src/motion_vectors.dart';
import 'package:flutter_filament/src/render_target.dart';
import 'package:flutter_filament/src/renderer.dart';
import 'package:flutter_filament/src/texture.dart';
import 'package:flutter_filament/src/view.dart';

/// The per-pixel guides a neural denoiser or upscaler needs on top of colour,
/// depth and motion (Filament's `GuideBuffer`).
enum GuideBuffer {
  /// RGBA16F: world-space normal (xyz) and perceptual roughness (w).
  normalRoughness(TextureFormat.rgba16f),

  /// RGBA8: `baseColor * (1 - metallic)`, linear.
  diffuseAlbedo(TextureFormat.rgba8),

  /// RGBA8: the split-sum specular albedo `mix(dfg.x, dfg.y, F0)`, linear.
  specularAlbedo(TextureFormat.rgba8),

  /// R16F: the distance a mirror ray travels to its hit, in world units
  /// (metres); 0 without a surface, 65504 when the ray leaves the scene.
  /// Needs ray tracing on the scene.
  specularHitDistance(TextureFormat.r16f);

  const GuideBuffer(this.format);

  /// The texture format of this guide.
  final TextureFormat format;
}

/// Options for the guide buffers (Filament's `GuideBufferOptions`).
class GuideBufferOptions {
  const GuideBufferOptions({
    this.enabled = false,
    this.specularHitDistance = true,
  });

  /// Write the guide buffers in the colour pass (Vulkan, single-sampled views).
  final bool enabled;

  /// Trace the specular hit distance (needs ray tracing on the scene).
  final bool specularHitDistance;

  GuideBufferOptions copyWith({bool? enabled, bool? specularHitDistance}) =>
      GuideBufferOptions(
        enabled: enabled ?? this.enabled,
        specularHitDistance: specularHitDistance ?? this.specularHitDistance,
      );

  @override
  bool operator ==(Object other) =>
      other is GuideBufferOptions &&
      other.enabled == enabled &&
      other.specularHitDistance == specularHitDistance;

  @override
  int get hashCode => Object.hash(enabled, specularHitDistance);

  @override
  String toString() =>
      'GuideBufferOptions(enabled: $enabled, specularHitDistance: $specularHitDistance)';
}

/// Guide buffers on a [FilamentView].
extension GuideBuffers on FilamentView {
  /// The guide buffer options; Vulkan only, ignored elsewhere (the web keeps
  /// the value for round trips).
  GuideBufferOptions get guideBufferOptions {
    final out = calloc<c.filament_guide_buffer_options_t>();
    try {
      c.filament_view_get_guide_buffer_options(nativePointer, out);
      return GuideBufferOptions(
        enabled: out.ref.enabled,
        specularHitDistance: out.ref.specularHitDistance,
      );
    } finally {
      calloc.free(out);
    }
  }

  set guideBufferOptions(GuideBufferOptions options) {
    final native = calloc<c.filament_guide_buffer_options_t>();
    try {
      native.ref
        ..enabled = options.enabled
        ..specularHitDistance = options.specularHitDistance;
      c.filament_view_set_guide_buffer_options(nativePointer, native);
    } finally {
      calloc.free(native);
    }
  }

  /// Copies [which] into [texture] every frame the view renders guides; the
  /// texture needs the render resolution, [GuideBuffer.format] and
  /// [TextureUsage.blitDst]. Null stops the copy.
  void setGuideBufferTexture(GuideBuffer which, FilamentTexture? texture) {
    c.filament_view_set_guide_buffer_texture(
      nativePointer,
      which.index,
      texture?.nativePointer ?? ffi.nullptr,
    );
  }
}

/// One guide buffer of a [FilamentView] as a readable texture: the texture the
/// view copies the guide into, the render target that reads it back, and the
/// readback (for tests and debug views).
class GuideBufferReadback {
  GuideBufferReadback._(
    this.engine,
    this.view,
    this.which,
    this.texture,
    this.renderTarget,
    this.width,
    this.height,
  );

  final FilamentEngine engine;
  final FilamentView view;
  final GuideBuffer which;
  final FilamentTexture texture;
  final FilamentRenderTarget renderTarget;
  final int width;
  final int height;
  bool _disposed = false;

  /// Creates the texture ([width] x [height], the view's render resolution)
  /// and makes [view] copy [which] into it.
  factory GuideBufferReadback.attach({
    required FilamentEngine engine,
    required FilamentView view,
    required GuideBuffer which,
    required int width,
    required int height,
  }) {
    final texture = FilamentTexture.create2D(
      engine: engine,
      width: width,
      height: height,
      format: which.format,
      usage:
          TextureUsage.colorAttachment |
          TextureUsage.sampleable |
          TextureUsage.blitSrc |
          TextureUsage.blitDst,
    );
    final renderTarget = FilamentRenderTarget.create(
      engine: engine,
      colorTexture: texture,
    );
    view.setGuideBufferTexture(which, texture);
    return GuideBufferReadback._(
      engine,
      view,
      which,
      texture,
      renderTarget,
      width,
      height,
    );
  }

  /// The channels per texel of [read]'s result (4, or 1 for the hit distance).
  int get channels => which == GuideBuffer.specularHitDistance ? 1 : 4;

  /// Reads the guide of the last rendered frame: `width * height * channels`
  /// floats, rows from the top down (the order the C wrapper delivers on
  /// Vulkan); [at] indexes them. RGBA8 guides come back normalised to 0..1.
  Future<Float32List> read(FilamentRenderer renderer) async {
    if (_disposed) throw StateError('GuideBufferReadback has been disposed');
    final half = which.format != TextureFormat.rgba8;
    final count = width * height * channels;
    final bytes = count * (half ? 2 : 1);
    final buffer = calloc<ffi.Uint8>(bytes);
    try {
      c.filament_renderer_read_pixels_render_target(
        renderer.nativePointer,
        renderTarget.nativePointer,
        0,
        0,
        width,
        height,
        (channels == 1 ? PixelDataFormat.r : PixelDataFormat.rgba).value,
        (half ? PixelDataType.half : PixelDataType.ubyte).value,
        buffer.cast(),
        bytes,
        ffi.nullptr,
        ffi.nullptr,
      );
      engine.flushAndWait();
      final out = Float32List(count);
      if (half) {
        final halves = buffer.cast<ffi.Uint16>().asTypedList(count);
        for (var i = 0; i < count; i++) {
          out[i] = MotionVectorBuffer.halfToFloat(halves[i]);
        }
      } else {
        final raw = buffer.asTypedList(count);
        for (var i = 0; i < count; i++) {
          out[i] = raw[i] / 255.0;
        }
      }
      return out;
    } finally {
      calloc.free(buffer);
    }
  }

  /// The channels at pixel ([x], [y]) of a buffer returned by [read], with
  /// `y == 0` the top row.
  List<double> at(Float32List data, int x, int y) {
    final i = (y * width + x) * channels;
    return [for (var k = 0; k < channels; k++) data[i + k]];
  }

  /// Stops the copy and releases the texture and render target.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    view.setGuideBufferTexture(which, null);
    engine.flushAndWait();
    renderTarget.dispose();
    texture.dispose();
  }
}
