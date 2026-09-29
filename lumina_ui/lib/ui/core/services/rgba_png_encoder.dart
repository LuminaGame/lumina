import 'dart:io';
import 'dart:typed_data';

/// A dependency-free RGBA8/BGRA8 → PNG encoder. The editor's own code uses it
/// (the texture editor's thumbnails), so it lives outside `lib/testing/`,
/// whose flutter_test / integration_test imports a project editor host
/// (where lumina_ui is a dependency) cannot compile.
abstract final class RgbaPngEncoder {
  /// Encodes raw RGBA8/BGRA8 pixel buffer into a valid PNG byte stream.
  static Uint8List encode(
    int w,
    int h,
    Uint8List rgba, {
    bool flipY = false,
    bool bgra = false,
  }) {
    final raw = BytesBuilder();
    for (var row = 0; row < h; row++) {
      final srcRow = flipY ? h - 1 - row : row;
      raw.addByte(0); // filter: none
      final rowStart = srcRow * w * 4;
      final rowEnd = (srcRow + 1) * w * 4;
      if (bgra) {
        final rowBytes = Uint8List.fromList(rgba.sublist(rowStart, rowEnd));
        for (var i = 0; i < rowBytes.length; i += 4) {
          final b = rowBytes[i];
          final r = rowBytes[i + 2];
          rowBytes[i] = r;
          rowBytes[i + 2] = b;
        }
        raw.add(rowBytes);
      } else {
        raw.add(Uint8List.sublistView(rgba, rowStart, rowEnd));
      }
    }
    final idat = ZLibEncoder(level: 6).convert(raw.takeBytes());

    final out = BytesBuilder()
      ..add(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);

    void chunk(String type, List<int> data) {
      final len = ByteData(4)..setUint32(0, data.length);
      out.add(len.buffer.asUint8List());
      final body = [...type.codeUnits, ...data];
      out.add(body);
      final crc = ByteData(4)..setUint32(0, _crc32(body));
      out.add(crc.buffer.asUint8List());
    }

    final ihdr = ByteData(13)
      ..setUint32(0, w)
      ..setUint32(4, h)
      ..setUint8(8, 8) // bit depth
      ..setUint8(9, 6); // color type RGBA
    chunk('IHDR', ihdr.buffer.asUint8List());
    chunk('IDAT', idat);
    chunk('IEND', const []);
    return out.takeBytes();
  }

  static int _crc32(List<int> data) {
    var crc = 0xFFFFFFFF;
    for (final b in data) {
      crc ^= b;
      for (var i = 0; i < 8; i++) {
        crc = (crc & 1) != 0 ? (crc >>> 1) ^ 0xEDB88320 : crc >>> 1;
      }
    }
    return crc ^ 0xFFFFFFFF;
  }
}
