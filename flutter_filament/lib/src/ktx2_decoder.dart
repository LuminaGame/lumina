import 'dart:typed_data';

import 'package:flutter_filament/src/ffi_package_platform.dart';
import 'package:flutter_filament/src/ffi_platform.dart' as ffi;
import 'package:flutter_filament/src/filament_bindings.dart' as c;

/// One mip level of a KTX2 texture as RGBA8 pixels.
class Ktx2DecodedImage {
  final int width;
  final int height;

  /// `width * height` texels, 4 bytes each (R, G, B, A), row-major, straight
  /// (not premultiplied) alpha. The values are the texture's own: an sRGB
  /// colour texture stays sRGB-encoded, as a decoded PNG would be.
  final Uint8List rgba;

  const Ktx2DecodedImage(this.width, this.height, this.rgba);
}

/// Decodes KTX2 / Basis Universal (`KHR_texture_basisu`) images to pixels on
/// the CPU, without an engine: what an importer, a thumbnail or a CPU preview
/// needs, where [Ktx2Reader] transcodes to a GPU texture instead.
///
/// Transcoding costs CPU time in proportion to the pixels decoded (tens of
/// milliseconds for a 2048² texture), so call it from a background isolate
/// (`Isolate.run`) wherever the calling isolate draws a UI; it is safe on any
/// isolate.
abstract final class Ktx2Decoder {
  /// The largest mip level of [bytes] whose longer edge is at most [maxEdge]
  /// (0: the top level; the smallest level when none is that small), as RGBA8.
  /// Null when [bytes] is not a KTX2 file, holds an HDR texture, or does not
  /// transcode.
  static Ktx2DecodedImage? decodeRgba8(Uint8List bytes, {int maxEdge = 0}) {
    if (bytes.isEmpty) return null;
    final data = calloc<ffi.Uint8>(bytes.length);
    final width = calloc<ffi.Uint32>();
    final height = calloc<ffi.Uint32>();
    try {
      data.asTypedList(bytes.length).setAll(0, bytes);
      final pixels = c.filament_ktx2_decode_rgba8(data, bytes.length, maxEdge < 0 ? 0 : maxEdge, width, height);
      if (pixels == ffi.nullptr) return null;
      try {
        final w = width.value, h = height.value;
        return Ktx2DecodedImage(w, h, Uint8List.fromList(pixels.asTypedList(w * h * 4)));
      } finally {
        c.filament_ktx2_decode_free(pixels);
      }
    } finally {
      calloc.free(data);
      calloc.free(width);
      calloc.free(height);
    }
  }
}
