import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_filament/flutter_filament.dart' show Ktx2Decoder;
import 'package:image/image.dart' as img;
import 'package:lumina_core/lumina_core.dart';

/// Decodes a texture's encoded bytes to pixels for the editor's CPU paths
/// (thumbnails, material previews, the Texture editor): KTX2 / Basis
/// Universal images (`KHR_texture_basisu`) through flutter_filament's
/// [Ktx2Decoder], everything else through `package:image`.
abstract final class EditorImageDecoding {
  /// [bytes] as an RGBA8 image whose longer edge is at most [maxEdge]
  /// (0: full size). A KTX2 texture gives its largest mip level within
  /// [maxEdge]; other images are box-filtered down. Null when the bytes do
  /// not decode.
  ///
  /// Synchronous CPU work: call it on a background isolate (see [decodeAsync])
  /// wherever the calling isolate draws a UI.
  static img.Image? decode(Uint8List bytes, {int maxEdge = 0}) {
    img.Image? image;
    if (EncodedImageFormat.sniff(bytes) == EncodedImageFormat.ktx2) {
      final ktx2 = Ktx2Decoder.decodeRgba8(bytes, maxEdge: maxEdge);
      if (ktx2 == null) return null;
      image = img.Image.fromBytes(
        width: ktx2.width,
        height: ktx2.height,
        bytes: ktx2.rgba.buffer,
        numChannels: 4,
        order: img.ChannelOrder.rgba,
      );
    } else {
      try {
        image = img.decodeImage(bytes);
      } catch (_) {
        return null;
      }
      if (image == null) return null;
    }
    if (maxEdge > 0 && math.max(image.width, image.height) > maxEdge) {
      final scale = maxEdge / math.max(image.width, image.height);
      image = img.copyResize(
        image,
        width: math.max(1, (image.width * scale).round()),
        height: math.max(1, (image.height * scale).round()),
        interpolation: img.Interpolation.average,
      );
    }
    return image.numChannels == 4 && image.format == img.Format.uint8
        ? image
        : image.convert(numChannels: 4, format: img.Format.uint8);
  }

  /// [decode] on a background isolate, as straight (not premultiplied) RGBA8
  /// texels.
  static Future<({Uint8List rgba, int width, int height})?> decodeAsync(Uint8List bytes, {int maxEdge = 0}) =>
      Isolate.run(() {
        final image = decode(bytes, maxEdge: maxEdge);
        if (image == null) return null;
        return (rgba: Uint8List.fromList(image.getBytes(order: img.ChannelOrder.rgba)), width: image.width, height: image.height);
      }, debugName: 'editor image decode');

  /// [bytes] re-encoded as a PNG at most [maxEdge] on its longer side, on a
  /// background isolate: what `dart:ui`'s codec cannot read (a KTX2 texture)
  /// shown as an image. Null when the bytes do not decode.
  static Future<Uint8List?> previewPng(Uint8List bytes, {int maxEdge = 256}) => Isolate.run(() {
        final image = decode(bytes, maxEdge: maxEdge);
        return image == null ? null : img.encodePng(image);
      }, debugName: 'editor image preview');
}
