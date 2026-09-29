import 'dart:io';
import 'dart:typed_data';

class TgaImage {
  final int width;
  final int height;
  final Uint8List rgbaBytes;

  const TgaImage({
    required this.width,
    required this.height,
    required this.rgbaBytes,
  });
}

class TgaDecoderService {
  /// Checks if given bytes match a valid TGA image header.
  ///
  /// TGA has no signature, so this only rules headers out; formats that do
  /// carry one are told apart first by `EncodedImageFormat.sniff`.
  static bool isTga(Uint8List bytes) {
    if (bytes.length < 18) return false;
    // 0 = no colour map, 1 = colour map present; nothing else is defined.
    if (bytes[1] > 1) return false;
    final imageType = bytes[2];
    // 1 = uncompressed color-mapped, 2 = uncompressed true-color, 3 = uncompressed black & white
    // 9 = RLE color-mapped, 10 = RLE true-color, 11 = RLE black & white
    if (![1, 2, 3, 9, 10, 11].contains(imageType)) return false;
    final pixelDepth = bytes[16];
    if (![8, 15, 16, 24, 32].contains(pixelDepth)) return false;
    final width = bytes[12] | bytes[13] << 8;
    final height = bytes[14] | bytes[15] << 8;
    return width > 0 && height > 0;
  }

  /// Decodes TGA binary bytes into raw RGBA8888 pixels.
  ///
  /// Returns null for anything [isTga] rejects and for a header declaring more
  /// pixels than its data can hold, before allocating the pixel buffer: the
  /// allocation is bounded by the input, never by a size field alone.
  static TgaImage? decode(Uint8List bytes) {
    if (!isTga(bytes)) return null;

    final idLength = bytes[0];
    final colorMapType = bytes[1];
    final imageType = bytes[2];

    final byteData = ByteData.sublistView(bytes);
    final width = byteData.getUint16(12, Endian.little);
    final height = byteData.getUint16(14, Endian.little);
    final pixelDepth = bytes[16];
    final descriptor = bytes[17];

    if (width <= 0 || height <= 0) return null;

    // Header size = 18 + idLength + (colorMapType != 0 ? colorMapLength : 0)
    int offset = 18 + idLength;
    if (colorMapType != 0) {
      final cmLength = byteData.getUint16(5, Endian.little);
      final cmEntrySize = (bytes[7] + 7) ~/ 8;
      offset += cmLength * cmEntrySize;
    }

    final totalPixels = width * height;
    final bytesPerPixel = pixelDepth ~/ 8;

    final isTopToBottom = (descriptor & 0x20) != 0;
    final isRLE = imageType == 9 || imageType == 10 || imageType == 11;

    final available = bytes.length - offset;
    if (available <= 0) return null;
    if (isRLE) {
      // Every packet is a header byte plus at least one pixel, and expands to
      // at most 128 pixels.
      final maxPixels = (available + bytesPerPixel) ~/ (1 + bytesPerPixel) * 128;
      if (totalPixels > maxPixels) return null;
    } else if (totalPixels * bytesPerPixel > available) {
      return null;
    }

    final rgba = Uint8List(totalPixels * 4);

    int pixelIndex = 0;

    if (!isRLE) {
      // Uncompressed TrueColor (2) or Grayscale (3)
      while (pixelIndex < totalPixels && offset + bytesPerPixel <= bytes.length) {
        _readPixelToRgba(bytes, offset, pixelDepth, rgba, pixelIndex * 4);
        offset += bytesPerPixel;
        pixelIndex++;
      }
    } else {
      // RLE Compressed (10 or 11)
      while (pixelIndex < totalPixels && offset < bytes.length) {
        final packetHeader = bytes[offset++];
        final count = (packetHeader & 0x7F) + 1;
        final isRunLength = (packetHeader & 0x80) != 0;

        if (isRunLength) {
          // Run length packet: single pixel repeated `count` times
          if (offset + bytesPerPixel > bytes.length) break;
          final runOffset = offset;
          offset += bytesPerPixel;

          for (int i = 0; i < count && pixelIndex < totalPixels; i++) {
            _readPixelToRgba(bytes, runOffset, pixelDepth, rgba, pixelIndex * 4);
            pixelIndex++;
          }
        } else {
          // Raw packet: `count` uncompressed pixels follow
          for (int i = 0; i < count && pixelIndex < totalPixels; i++) {
            if (offset + bytesPerPixel > bytes.length) break;
            _readPixelToRgba(bytes, offset, pixelDepth, rgba, pixelIndex * 4);
            offset += bytesPerPixel;
            pixelIndex++;
          }
        }
      }
    }

    // Flip vertical if standard bottom-to-top TGA orientation
    if (!isTopToBottom) {
      _flipVertical(rgba, width, height);
    }

    return TgaImage(
      width: width,
      height: height,
      rgbaBytes: rgba,
    );
  }

  static void _readPixelToRgba(Uint8List src, int srcOffset, int depth, Uint8List dst, int dstOffset) {
    if (depth == 32) {
      final b = src[srcOffset];
      final g = src[srcOffset + 1];
      final r = src[srcOffset + 2];
      final a = src[srcOffset + 3];
      dst[dstOffset] = r;
      dst[dstOffset + 1] = g;
      dst[dstOffset + 2] = b;
      dst[dstOffset + 3] = a;
    } else if (depth == 24) {
      final b = src[srcOffset];
      final g = src[srcOffset + 1];
      final r = src[srcOffset + 2];
      dst[dstOffset] = r;
      dst[dstOffset + 1] = g;
      dst[dstOffset + 2] = b;
      dst[dstOffset + 3] = 255;
    } else if (depth == 16) {
      final val = src[srcOffset] | (src[srcOffset + 1] << 8);
      final r = ((val >> 10) & 0x1F) * 255 ~/ 31;
      final g = ((val >> 5) & 0x1F) * 255 ~/ 31;
      final b = (val & 0x1F) * 255 ~/ 31;
      final a = (val & 0x8000) != 0 ? 255 : 0;
      dst[dstOffset] = r;
      dst[dstOffset + 1] = g;
      dst[dstOffset + 2] = b;
      dst[dstOffset + 3] = (depth == 15) ? 255 : a;
    } else if (depth == 8) {
      final gray = src[srcOffset];
      dst[dstOffset] = gray;
      dst[dstOffset + 1] = gray;
      dst[dstOffset + 2] = gray;
      dst[dstOffset + 3] = 255;
    }
  }

  static void _flipVertical(Uint8List rgba, int width, int height) {
    final rowBytes = width * 4;
    final tempRow = Uint8List(rowBytes);
    for (int y = 0; y < height ~/ 2; y++) {
      final topOffset = y * rowBytes;
      final bottomOffset = (height - 1 - y) * rowBytes;

      tempRow.setRange(0, rowBytes, rgba, topOffset);
      rgba.setRange(topOffset, topOffset + rowBytes, rgba, bottomOffset);
      rgba.setRange(bottomOffset, bottomOffset + rowBytes, tempRow);
    }
  }

  /// Converts TGA bytes directly to standard PNG bytes
  static Uint8List? tgaToPng(Uint8List tgaBytes) {
    final decoded = decode(tgaBytes);
    if (decoded == null) return null;
    return encodePng(decoded.rgbaBytes, decoded.width, decoded.height);
  }

  /// Pure Dart standard PNG encoder with zlib compression
  static Uint8List encodePng(Uint8List rgba, int width, int height) {
    final BytesBuilder bb = BytesBuilder();

    // 1. PNG Header Signature
    bb.add(const [137, 80, 78, 71, 13, 10, 26, 10]);

    // 2. IHDR Chunk
    final ihdrData = ByteData(13);
    ihdrData.setUint32(0, width, Endian.big);
    ihdrData.setUint32(4, height, Endian.big);
    ihdrData.setUint8(8, 8);  // Bit depth: 8
    ihdrData.setUint8(9, 6);  // Color type: RGBA (6)
    ihdrData.setUint8(10, 0); // Compression method (0)
    ihdrData.setUint8(11, 0); // Filter method (0)
    ihdrData.setUint8(12, 0); // Interlace method (0)
    _writeChunk(bb, 'IHDR', ihdrData.buffer.asUint8List());

    // 3. IDAT Chunk (Scanlines with filter type 0 followed by zlib deflation)
    final rowLength = width * 4;
    final rawScanlines = Uint8List((rowLength + 1) * height);
    for (int y = 0; y < height; y++) {
      final scanlineOffset = y * (rowLength + 1);
      rawScanlines[scanlineOffset] = 0; // Filter: None
      final rgbaOffset = y * rowLength;
      rawScanlines.setRange(scanlineOffset + 1, scanlineOffset + 1 + rowLength, rgba, rgbaOffset);
    }

    final compressed = zlib.encode(rawScanlines);
    _writeChunk(bb, 'IDAT', Uint8List.fromList(compressed));

    // 4. IEND Chunk
    _writeChunk(bb, 'IEND', Uint8List(0));

    return bb.toBytes();
  }

  static void _writeChunk(BytesBuilder bb, String chunkType, Uint8List chunkData) {
    final lengthBytes = ByteData(4)..setUint32(0, chunkData.length, Endian.big);
    bb.add(lengthBytes.buffer.asUint8List());

    final typeBytes = Uint8List.fromList(chunkType.codeUnits);
    bb.add(typeBytes);
    if (chunkData.isNotEmpty) {
      bb.add(chunkData);
    }

    // Compute CRC-32 over Type + Data
    final crc = _crc32(typeBytes, chunkData);
    final crcBytes = ByteData(4)..setUint32(0, crc, Endian.big);
    bb.add(crcBytes.buffer.asUint8List());
  }

  static final List<int> _crcTable = _makeCrcTable();

  static List<int> _makeCrcTable() {
    final table = List<int>.filled(256, 0);
    for (int n = 0; n < 256; n++) {
      int c = n;
      for (int k = 0; k < 8; k++) {
        if ((c & 1) != 0) {
          c = 0xEDB88320 ^ (c >>> 1);
        } else {
          c = c >>> 1;
        }
      }
      table[n] = c;
    }
    return table;
  }

  static int _crc32(Uint8List type, Uint8List data) {
    int c = 0xFFFFFFFF;
    for (int i = 0; i < type.length; i++) {
      c = _crcTable[(c ^ type[i]) & 0xFF] ^ (c >>> 8);
    }
    for (int i = 0; i < data.length; i++) {
      c = _crcTable[(c ^ data[i]) & 0xFF] ^ (c >>> 8);
    }
    return c ^ 0xFFFFFFFF;
  }
}
