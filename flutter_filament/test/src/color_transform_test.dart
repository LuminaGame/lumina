import 'dart:typed_data';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:test/test.dart';

void main() {
  group('ColorTransform Tests (Task 04)', () {
    test('sRGB to Linear and Linear to sRGB transfer curve', () {
      final srgb = LinearImage(1, 3, 3);
      srgb.setPixel(0, 0, 0, 0.0);
      srgb.setPixel(0, 1, 0, 0.5);
      srgb.setPixel(0, 2, 0, 1.0);

      final linear = srgbToLinear(srgb);
      expect(linear.getPixel(0, 0, 0), closeTo(0.0, 1e-5));
      expect(linear.getPixel(0, 1, 0), closeTo(0.214041, 1e-3));
      expect(linear.getPixel(0, 2, 0), closeTo(1.0, 1e-5));

      final backToSrgb = linearToSrgb(linear);
      expect(backToSrgb.getPixel(0, 1, 0), closeTo(0.5, 1e-4));

      srgb.destroy();
      linear.destroy();
      backToSrgb.destroy();
    });

    test('toGrayscale applies Rec.709 coefficients', () {
      final img = LinearImage(3, 1, 3);
      // Red
      img.setPixel(0, 0, 0, 1.0);
      img.setPixel(0, 0, 1, 0.0);
      img.setPixel(0, 0, 2, 0.0);
      // Green
      img.setPixel(1, 0, 0, 0.0);
      img.setPixel(1, 0, 1, 1.0);
      img.setPixel(1, 0, 2, 0.0);
      // Blue
      img.setPixel(2, 0, 0, 0.0);
      img.setPixel(2, 0, 1, 0.0);
      img.setPixel(2, 0, 2, 1.0);

      final gray = toGrayscale(img);
      expect(gray.channels, equals(1));
      expect(gray.getPixel(0, 0, 0), closeTo(0.2126, 1e-4));
      expect(gray.getPixel(1, 0, 0), closeTo(0.7152, 1e-4));
      expect(gray.getPixel(2, 0, 0), closeTo(0.0722, 1e-4));

      img.destroy();
      gray.destroy();
    });

    test('srgbBytesToLinear and linearToSrgbBytes round trip', () {
      final inputBytes = Uint8List.fromList([0, 0, 0, 128, 128, 128, 255, 255, 255]);
      final linearImg = srgbBytesToLinear(3, 1, 3, inputBytes);

      expect(linearImg.getPixel(0, 0, 0), closeTo(0.0, 1e-5));
      expect(linearImg.getPixel(1, 0, 0), closeTo(0.2158, 1e-2));
      expect(linearImg.getPixel(2, 0, 0), closeTo(1.0, 1e-5));

      final outputBytes = linearToSrgbBytes(linearImg);
      expect(outputBytes[0], equals(0));
      expect((outputBytes[3] - 128).abs(), lessThanOrEqualTo(1));
      expect(outputBytes[6], equals(255));

      linearImg.destroy();
    });

    test('linearToRgbm and rgbmToLinear HDR round trip', () {
      final hdr = LinearImage(1, 1, 3);
      hdr.setPixel(0, 0, 0, 5.0);
      hdr.setPixel(0, 0, 1, 2.0);
      hdr.setPixel(0, 0, 2, 0.5);

      final rgbm = linearToRgbm(hdr);
      expect(rgbm.channels, equals(4));
      expect(rgbm.getPixel(0, 0, 0), lessThanOrEqualTo(1.0));
      expect(rgbm.getPixel(0, 0, 1), lessThanOrEqualTo(1.0));
      expect(rgbm.getPixel(0, 0, 2), lessThanOrEqualTo(1.0));
      expect(rgbm.getPixel(0, 0, 3), lessThanOrEqualTo(1.0));

      final recovered = rgbmToLinear(rgbm);
      expect(recovered.getPixel(0, 0, 0), closeTo(5.0, 0.1));
      expect(recovered.getPixel(0, 0, 1), closeTo(2.0, 0.1));
      expect(recovered.getPixel(0, 0, 2), closeTo(0.5, 0.1));

      hdr.destroy();
      rgbm.destroy();
      recovered.destroy();
    });

    test('linearToRgb101111Rev produces valid packed buffer', () {
      final img = LinearImage(2, 2, 3);
      clearToValue(img, 1.0);

      final packed = linearToRgb101111Rev(img);
      expect(packed.length, equals(4));
      expect(packed[0], isNonZero);

      img.destroy();
    });
  });
}
