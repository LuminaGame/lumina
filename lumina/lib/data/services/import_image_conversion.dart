import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:lumina/data/services/tga_decoder_service.dart';

/// The conversion an image import runs on its source file: TGA and WebP are
/// stored as PNG, every other format as it is. The
/// Texture editor's Reimport runs the same one, so a reimported payload is
/// what an import would store.
abstract final class ImportImageConversion {
  /// Whether an image named [fileName] is stored as PNG rather than as it is.
  static bool convertsToPng(String fileName) {
    final lower = fileName.toLowerCase();
    return lower.endsWith('.tga') || lower.endsWith('.webp');
  }

  /// The bytes an import stores for the image [source].
  ///
  /// Throws a [FormatException] for a `.tga` the TGA reader cannot decode.
  static Future<Uint8List> importBytes(File source) async {
    final bytes = await source.readAsBytes();
    final lower = source.path.toLowerCase();
    if (lower.endsWith('.tga')) {
      final png = TgaDecoderService.tgaToPng(bytes);
      if (png == null) throw FormatException('${source.uri.pathSegments.last} is not a TGA image this importer reads');
      return png;
    }
    if (lower.endsWith('.webp')) {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final pngData = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      // No PNG encoder result: the source is stored as it is.
      return pngData == null ? bytes : pngData.buffer.asUint8List();
    }
    return bytes;
  }
}
