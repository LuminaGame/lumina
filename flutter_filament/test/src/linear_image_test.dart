import 'dart:typed_data';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:test/test.dart';

void main() {
  group('LinearImage Tests (Task 01)', () {
    test('Constructs zero-initialized image with correct dimensions', () {
      final img = LinearImage(4, 3, 3);
      expect(img.width, equals(4));
      expect(img.height, equals(3));
      expect(img.channels, equals(3));
      expect(img.data.length, equals(36));
      expect(img.data.every((v) => v == 0.0), isTrue);
      expect(img.isValid, isTrue);
      img.destroy();
      expect(img.isValid, isFalse);
    });

    test('Writing through Float32List view and getPixel/setPixel', () {
      final img = LinearImage(4, 3, 3);
      img.data[0] = 0.5;
      expect(img.getPixel(0, 0, 0), equals(0.5));

      img.setPixel(3, 2, 2, 1.25);
      final expectedIndex = (2 * 4 + 3) * 3 + 2;
      expect(img.data[expectedIndex], equals(1.25));
      expect(img.getPixel(3, 2, 2), equals(1.25));
      img.destroy();
    });

    test('LinearImage.fromData copies data accurately', () {
      final raw = Float32List.fromList([0.1, 0.2, 0.3, 0.4]);
      final img = LinearImage.fromData(2, 2, 1, raw);
      expect(img.width, equals(2));
      expect(img.height, equals(2));
      expect(img.channels, equals(1));
      expect(img.getPixel(0, 0, 0), closeTo(0.1, 1e-6));
      expect(img.getPixel(1, 0, 0), closeTo(0.2, 1e-6));
      expect(img.getPixel(0, 1, 0), closeTo(0.3, 1e-6));
      expect(img.getPixel(1, 1, 0), closeTo(0.4, 1e-6));
      img.destroy();
    });

    test('Shared copy semantics share underlying pixel buffer', () {
      final a = LinearImage(4, 4, 3);
      final b = a.share();

      b.data[5] = 7.0;
      expect(a.data[5], equals(7.0));

      b.destroy();
      expect(a.isDisposed, isFalse);
      expect(a.data[5], equals(7.0));

      a.destroy();
      expect(a.isDisposed, isTrue);
    });

    test('Channel counts 1, 2, 3, 4 all construct and report correctly', () {
      for (final ch in [1, 2, 3, 4]) {
        final img = LinearImage(8, 8, ch);
        expect(img.channels, equals(ch));
        expect(img.data.length, equals(8 * 8 * ch));
        img.destroy();
      }
    });

    test('Accessing data after destroy throws StateError', () {
      final img = LinearImage(2, 2, 1);
      img.destroy();
      expect(() => img.data, throwsStateError);
      expect(() => img.getPixel(0, 0, 0), throwsStateError);
    });

    test('Stress create and destroy loop', () {
      for (var i = 0; i < 10000; i++) {
        final img = LinearImage(2, 2, 1);
        img.data[0] = i.toDouble();
        img.destroy();
      }
    });
  });
}
