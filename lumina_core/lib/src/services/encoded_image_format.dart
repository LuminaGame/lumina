import 'dart:typed_data';

import 'package:lumina/data/services/tga_decoder_service.dart';

/// The container an encoded image is stored in, told from its bytes.
///
/// Every format with a signature is recognised by it. TGA has none, so it is
/// only reported when no signature matched and the header passes
/// [TgaDecoderService.isTga]. A glTF `mimeType` or a file extension never
/// decides: exporters label images wrongly and texture folders hold PNGs saved
/// under `.tga` names, and a PNG read as a TGA header is an 18505x21060 image.
enum EncodedImageFormat {
  png('image/png'),
  jpeg('image/jpeg'),
  webp('image/webp'),
  gif('image/gif'),
  bmp('image/bmp'),
  ktx2('image/ktx2'),
  tga('image/x-tga'),

  /// No signature matched and the bytes are not a TGA header either.
  unknown(null);

  const EncodedImageFormat(this.mimeType);

  final String? mimeType;

  static const List<int> _pngSignature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  static const List<int> _ktx2Signature = [0xAB, 0x4B, 0x54, 0x58, 0x20, 0x32, 0x30, 0xBB, 0x0D, 0x0A, 0x1A, 0x0A];

  /// The format of [bytes]; [unknown] when nothing matches.
  static EncodedImageFormat sniff(Uint8List bytes) {
    if (_startsWith(bytes, _pngSignature)) return png;
    if (bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) return jpeg;
    if (_startsWith(bytes, 'RIFF'.codeUnits) && _startsWith(bytes, 'WEBP'.codeUnits, at: 8)) return webp;
    if (_startsWith(bytes, 'GIF87a'.codeUnits) || _startsWith(bytes, 'GIF89a'.codeUnits)) return gif;
    if (_startsWith(bytes, _ktx2Signature)) return ktx2;
    if (_isBmp(bytes)) return bmp;
    if (TgaDecoderService.isTga(bytes)) return tga;
    return unknown;
  }

  static bool _startsWith(Uint8List bytes, List<int> signature, {int at = 0}) {
    if (bytes.length < at + signature.length) return false;
    for (var i = 0; i < signature.length; i++) {
      if (bytes[at + i] != signature[i]) return false;
    }
    return true;
  }

  /// `BM` is only two bytes, so the DIB header size after the file header has
  /// to be one of the sizes the format defines as well.
  static bool _isBmp(Uint8List bytes) {
    if (bytes.length < 18 || bytes[0] != 0x42 || bytes[1] != 0x4D) return false;
    final dibHeaderSize = ByteData.sublistView(bytes, 14, 18).getUint32(0, Endian.little);
    return const {12, 16, 40, 52, 56, 64, 108, 124}.contains(dibHeaderSize);
  }
}
