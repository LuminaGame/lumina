import 'package:flutter_filament/flutter_filament.dart';
import 'package:test/test.dart';

void main() {
  group('ImageOps Tests (Task 03)', () {
    test('ORM packing and extractChannel', () {
      final o = LinearImage(2, 2, 1);
      final r = LinearImage(2, 2, 1);
      final m = LinearImage(2, 2, 1);

      clearToValue(o, 0.1);
      clearToValue(r, 0.5);
      clearToValue(m, 0.9);

      final orm = packOrm(occlusion: o, roughness: r, metallic: m);
      expect(orm.width, equals(2));
      expect(orm.height, equals(2));
      expect(orm.channels, equals(3));

      expect(orm.getPixel(0, 0, 0), closeTo(0.1, 1e-5));
      expect(orm.getPixel(0, 0, 1), closeTo(0.5, 1e-5));
      expect(orm.getPixel(0, 0, 2), closeTo(0.9, 1e-5));

      final extractedRoughness = extractChannel(orm, 1);
      expect(extractedRoughness.channels, equals(1));
      expect(extractedRoughness.getPixel(0, 0, 0), closeTo(0.5, 1e-5));
      expect(extractedRoughness.getPixel(1, 1, 0), closeTo(0.5, 1e-5));

      o.destroy();
      r.destroy();
      m.destroy();
      orm.destroy();
      extractedRoughness.destroy();
    });

    test('cropRegion on 4x4 inner 2x2', () {
      final src = LinearImage(4, 4, 1);
      for (var y = 0; y < 4; y++) {
        for (var x = 0; x < 4; x++) {
          src.setPixel(x, y, 0, (y * 4 + x).toDouble());
        }
      }

      final cropped = cropRegion(src, left: 1, top: 1, right: 3, bottom: 3);
      expect(cropped.width, equals(2));
      expect(cropped.height, equals(2));
      expect(cropped.getPixel(0, 0, 0), equals(5.0)); // (x=1, y=1) -> 1*4+1 = 5
      expect(cropped.getPixel(1, 0, 0), equals(6.0)); // (x=2, y=1) -> 6
      expect(cropped.getPixel(0, 1, 0), equals(9.0)); // (x=1, y=2) -> 9
      expect(cropped.getPixel(1, 1, 0), equals(10.0)); // (x=2, y=2) -> 10

      src.destroy();
      cropped.destroy();
    });

    test('blitImage with offset', () {
      final dst = LinearImage(8, 8, 1);
      final src = LinearImage(2, 2, 1);
      clearToValue(src, 99.0);

      blitImage(dst, src, 3, 4);

      for (var y = 0; y < 8; y++) {
        for (var x = 0; x < 8; x++) {
          if (x >= 3 && x < 5 && y >= 4 && y < 6) {
            expect(dst.getPixel(x, y, 0), equals(99.0));
          } else {
            expect(dst.getPixel(x, y, 0), equals(0.0));
          }
        }
      }

      dst.destroy();
      src.destroy();
    });

    test('horizontalStack and verticalStack', () {
      final a = LinearImage(2, 3, 1);
      final b = LinearImage(2, 3, 1);
      clearToValue(a, 1.0);
      clearToValue(b, 2.0);

      final hStacked = horizontalStack([a, b]);
      expect(hStacked.width, equals(4));
      expect(hStacked.height, equals(3));
      expect(hStacked.getPixel(0, 0, 0), equals(1.0));
      expect(hStacked.getPixel(2, 0, 0), equals(2.0));

      final vStacked = verticalStack([a, b]);
      expect(vStacked.width, equals(2));
      expect(vStacked.height, equals(6));
      expect(vStacked.getPixel(0, 0, 0), equals(1.0));
      expect(vStacked.getPixel(0, 3, 0), equals(2.0));

      a.destroy();
      b.destroy();
      hStacked.destroy();
      vStacked.destroy();
    });

    test('Involutions: horizontalFlip, verticalFlip, transpose', () {
      final src = LinearImage(3, 2, 1);
      src.setPixel(0, 0, 0, 1.0);
      src.setPixel(1, 0, 0, 2.0);
      src.setPixel(2, 0, 0, 3.0);
      src.setPixel(0, 1, 0, 4.0);
      src.setPixel(1, 1, 0, 5.0);
      src.setPixel(2, 1, 0, 6.0);

      final hf2 = horizontalFlip(horizontalFlip(src));
      expect(compareImages(src, hf2), equals(0));

      final vf2 = verticalFlip(verticalFlip(src));
      expect(compareImages(src, vf2), equals(0));

      final t = transpose(src);
      expect(t.width, equals(2));
      expect(t.height, equals(3));
      final t2 = transpose(t);
      expect(compareImages(src, t2), equals(0));

      src.destroy();
      hf2.destroy();
      vf2.destroy();
      t.destroy();
      t2.destroy();
    });

    test('vectorsToColors and colorsToVectors round trip', () {
      final colors = LinearImage(2, 2, 3);
      clearToValue(colors, 0.5); // maps to 0 vector

      final vectors = colorsToVectors(colors);
      expect(vectors.getPixel(0, 0, 0), closeTo(0.0, 1e-5));
      expect(vectors.getPixel(0, 0, 1), closeTo(0.0, 1e-5));
      expect(vectors.getPixel(0, 0, 2), closeTo(0.0, 1e-5));

      final backToColors = vectorsToColors(vectors);
      expect(backToColors.getPixel(0, 0, 0), closeTo(0.5, 1e-5));

      colors.destroy();
      vectors.destroy();
      backToColors.destroy();
    });

    test('compareImages with tolerance epsilon', () {
      final a = LinearImage(2, 2, 1);
      final b = LinearImage(2, 2, 1);
      clearToValue(a, 0.5);
      clearToValue(b, 0.5);

      expect(compareImages(a, b), equals(0));

      b.setPixel(0, 0, 0, 0.502);
      expect(compareImages(a, b, epsilon: 0.001), isNot(equals(0)));
      expect(compareImages(a, b, epsilon: 0.01), equals(0));

      a.destroy();
      b.destroy();
    });

    test('clearToValue sets all values', () {
      final img = LinearImage(3, 3, 3);
      clearToValue(img, 0.25);
      expect(img.data.every((v) => (v - 0.25).abs() < 1e-6), isTrue);
      img.destroy();
    });
  });
}
