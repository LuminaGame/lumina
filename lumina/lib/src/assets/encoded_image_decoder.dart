import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image/image.dart' as imglib;

import 'package:lumina_core/lumina_core.dart';

/// Decoded pixels: `width * height` RGBA8 texels, row-major, alpha
/// premultiplied (what `dart:ui`'s `ImageByteFormat.rawRgba` hands back).
class DecodedRgbaImage {
  final int width;
  final int height;
  final Uint8List rgba;

  const DecodedRgbaImage(this.width, this.height, this.rgba);
}

/// Decodes an encoded image with the decoder for its [EncodedImageFormat], the
/// same way on every isolate.
///
/// `dart:ui`'s image codec only exists on a root isolate (the editor's UI
/// isolate, a test's main isolate, the web's only isolate). There it decodes
/// PNG, JPEG, WebP, GIF and BMP; on any other isolate — an `Isolate.run`
/// worker, a save or streaming worker — `package:image` decodes the same
/// formats. TGA always goes through [TgaDecoderService]. KTX2 (Basis) and
/// unrecognised bytes are not decoded to pixels here.
abstract final class EncodedImageDecoder {
  /// Whether this isolate can use `dart:ui`'s image codec.
  static bool get platformCodecAvailable {
    try {
      return ui.RootIsolateToken.instance != null;
    } on UnsupportedError {
      // The web has one isolate, and its codec is always there.
      return true;
    }
  }

  /// Decodes with the UI isolate's platform codec on behalf of an isolate
  /// that has none: the import worker sets this to a
  /// round trip to the UI isolate, so what it decodes — the texels a mesh
  /// thumbnail samples — matches a UI-isolate decode bit for bit (JPEG
  /// decoders disagree in the last bits). Used only where
  /// [platformCodecAvailable] is false.
  static Future<DecodedRgbaImage> Function(Uint8List bytes)? platformCodecProxy;

  /// [bytes] decoded to premultiplied RGBA8, or `null` when its format is not
  /// one this decoder turns into pixels (KTX2, unknown). Throws a
  /// [FormatException] for bytes that carry a recognised signature but do not
  /// decode.
  static Future<DecodedRgbaImage?> decodeRgba(Uint8List bytes) async {
    final format = EncodedImageFormat.sniff(bytes);
    switch (format) {
      case EncodedImageFormat.ktx2:
      case EncodedImageFormat.unknown:
        return null;
      case EncodedImageFormat.tga:
        final tga = TgaDecoderService.decode(bytes);
        if (tga == null) throw const FormatException('TGA header does not match its pixel data');
        return DecodedRgbaImage(tga.width, tga.height, _premultiply(tga.rgbaBytes));
      case EncodedImageFormat.png:
      case EncodedImageFormat.jpeg:
      case EncodedImageFormat.webp:
      case EncodedImageFormat.gif:
      case EncodedImageFormat.bmp:
        if (platformCodecAvailable) return _decodeWithPlatformCodec(bytes, format);
        final proxy = platformCodecProxy;
        return proxy != null ? proxy(bytes) : _decodeWithPackageImage(bytes, format);
    }
  }

  static Future<DecodedRgbaImage> _decodeWithPlatformCodec(Uint8List bytes, EncodedImageFormat format) async {
    final ui.Codec codec;
    try {
      codec = await ui.instantiateImageCodec(bytes);
    } catch (e) {
      throw FormatException('${format.name} data does not decode: $e');
    }
    try {
      final frame = await codec.getNextFrame();
      final image = frame.image;
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        if (data == null) throw const FormatException('the image codec returned no pixels');
        return DecodedRgbaImage(image.width, image.height, data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
      } finally {
        image.dispose();
      }
    } finally {
      codec.dispose();
    }
  }

  static DecodedRgbaImage _decodeWithPackageImage(Uint8List bytes, EncodedImageFormat format) {
    imglib.Image? decoded;
    try {
      decoded = switch (format) {
        EncodedImageFormat.png => imglib.decodePng(bytes),
        EncodedImageFormat.jpeg => imglib.decodeJpg(bytes),
        EncodedImageFormat.webp => imglib.decodeWebP(bytes),
        EncodedImageFormat.gif => imglib.decodeGif(bytes),
        EncodedImageFormat.bmp => imglib.decodeBmp(bytes),
        _ => null,
      };
    } catch (e) {
      throw FormatException('${format.name} data does not decode: $e');
    }
    if (decoded == null) throw FormatException('${format.name} data does not decode');
    // No explicit `alpha`: `convert` fills a missing alpha channel with the
    // format's maximum, but since package:image 4.9 an explicit value also
    // overwrites an existing one.
    final rgba = decoded.convert(format: imglib.Format.uint8, numChannels: 4);
    return DecodedRgbaImage(rgba.width, rgba.height, _premultiply(rgba.getBytes(order: imglib.ChannelOrder.rgba)));
  }

  /// Premultiplies straight RGBA in place, rounding like `dart:ui` does
  /// (`round(c * a / 255)`), so both codecs hand back the same texels.
  static Uint8List _premultiply(Uint8List rgba) {
    for (var i = 3; i < rgba.length; i += 4) {
      final a = rgba[i];
      if (a == 255) continue;
      rgba[i - 3] = (rgba[i - 3] * a + 127) ~/ 255;
      rgba[i - 2] = (rgba[i - 2] * a + 127) ~/ 255;
      rgba[i - 1] = (rgba[i - 1] * a + 127) ~/ 255;
    }
    return rgba;
  }
}
