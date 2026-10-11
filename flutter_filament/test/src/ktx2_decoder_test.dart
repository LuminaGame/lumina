import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:test/test.dart';

/// An 8×8 KTX2 (Basis Universal) texture with its mip chain: the left half
/// red, the right half blue, encoded as sRGB colour.
Uint8List _halfRedHalfBlueKtx2({required bool uastc}) {
  final images = <LinearImage>[];
  final mips = <int>[8, 4, 2, 1];
  final builder = BasisEncoderBuilder(mipCount: mips.length)..useUastc(uastc);
  try {
    for (var level = 0; level < mips.length; level++) {
      final size = mips[level];
      final image = LinearImage(size, size, 3);
      for (var y = 0; y < size; y++) {
        for (var x = 0; x < size; x++) {
          final red = size == 1 || x < size / 2;
          image.setPixel(x, y, 0, red ? 1.0 : 0.0);
          image.setPixel(x, y, 1, 0.0);
          image.setPixel(x, y, 2, red ? 0.0 : 1.0);
        }
      }
      images.add(image);
      builder.mipLevel(level, image);
    }
    return builder.buildAndEncode();
  } finally {
    for (final i in images) {
      i.destroy();
    }
  }
}

List<int> _texel(Ktx2DecodedImage image, int x, int y) {
  final i = (y * image.width + x) * 4;
  return image.rgba.sublist(i, i + 4);
}

void main() {
  for (final uastc in [true, false]) {
    final codec = uastc ? 'UASTC' : 'ETC1S';
    group('a $codec KTX2 texture', () {
      final ktx2 = _halfRedHalfBlueKtx2(uastc: uastc);

      test('decodes to RGBA8 pixels of its top level on the CPU', () {
        final image = Ktx2Decoder.decodeRgba8(ktx2);
        expect(image, isNotNull);
        expect(image!.width, 8);
        expect(image.height, 8);
        expect(image.rgba.length, 8 * 8 * 4);
        final red = _texel(image, 1, 4);
        final blue = _texel(image, 6, 4);
        expect(red[0], greaterThan(200), reason: 'left texel $red');
        expect(red[2], lessThan(60), reason: 'left texel $red');
        expect(blue[2], greaterThan(200), reason: 'right texel $blue');
        expect(blue[0], lessThan(60), reason: 'right texel $blue');
        expect(red[3], 255);
      });

      test('decodes the largest mip level within a size limit', () {
        final image = Ktx2Decoder.decodeRgba8(ktx2, maxEdge: 4)!;
        expect((image.width, image.height), (4, 4));
        expect(Ktx2Decoder.decodeRgba8(ktx2, maxEdge: 3)!.width, 2);
        expect(Ktx2Decoder.decodeRgba8(ktx2, maxEdge: 1000)!.width, 8);
      });

      test('decodes on a background isolate', () async {
        final width = await Isolate.run(() => Ktx2Decoder.decodeRgba8(ktx2)?.width);
        expect(width, 8);
      });
    });
  }

  test('bytes that are not a KTX2 texture decode to nothing', () {
    expect(Ktx2Decoder.decodeRgba8(Uint8List(0)), isNull);
    expect(Ktx2Decoder.decodeRgba8(Uint8List.fromList(List.generate(64, (i) => i))), isNull);
    // A KTX2 identifier on a truncated file.
    final truncated = _halfRedHalfBlueKtx2(uastc: true).sublist(0, 80);
    expect(Ktx2Decoder.decodeRgba8(truncated), isNull);
  });
}
