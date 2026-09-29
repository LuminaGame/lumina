import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:flutter_filament/flutter_filament.dart';

void main() {
  group('Viewport Tests', () {
    test('Flutter top-left to Filament bottom-left conversion', () {
      // surfaceHeight = 1080
      // Flutter rect: left 100, top 80, 400x300
      final vp = Viewport.fromFlutterRect(
        left: 100,
        top: 80,
        width: 400,
        height: 300,
        surfaceHeight: 1080,
      );

      expect(vp.left, equals(100));
      expect(vp.bottom, equals(700)); // 1080 - (80 + 300) = 700
      expect(vp.width, equals(400));
      expect(vp.height, equals(300));

      final flutterTl = vp.toFlutterTopLeft(surfaceHeight: 1080);
      expect(flutterTl.left, equals(100.0));
      expect(flutterTl.top, equals(80.0));
    });

    test('devicePixelRatio scaling', () {
      final vp = Viewport.fromFlutterRect(
        left: 100,
        top: 80,
        width: 400,
        height: 300,
        surfaceHeight: 1080,
        devicePixelRatio: 2.0,
      );

      expect(vp.left, equals(200));
      expect(vp.bottom, equals(1400)); // 2160 - (160 + 600) = 1400
      expect(vp.width, equals(800));
      expect(vp.height, equals(600));

      final flutterTl = vp.toFlutterTopLeft(surfaceHeight: 1080, devicePixelRatio: 2.0);
      expect(flutterTl.left, equals(100.0));
      expect(flutterTl.top, equals(80.0));
    });

    test('Top edge at top=0 maps to surfaceHeight - height', () {
      final vp = Viewport.fromFlutterRect(
        left: 0,
        top: 0,
        width: 1920,
        height: 1080,
        surfaceHeight: 1080,
      );

      expect(vp.left, equals(0));
      expect(vp.bottom, equals(0)); // 1080 - 1080 = 0
      expect(vp.width, equals(1920));
      expect(vp.height, equals(1080));
    });
  });

  group('norm.h Packing Tests', () {
    test('packSnorm16 and unpackSnorm16', () {
      expect(packSnorm16(1.0), equals(32767));
      expect(packSnorm16(-1.0), equals(-32767));
      expect(packSnorm16(0.0), equals(0));
      expect(packSnorm16(0.5), equals(16384));
      // Out of range clamps
      expect(packSnorm16(2.0), equals(32767));
      expect(packSnorm16(-2.0), equals(-32767));

      // Round trip accuracy within 1 / 32767
      expect(unpackSnorm16(packSnorm16(0.75)), closeTo(0.75, 1.0 / 32767.0));
      expect(unpackSnorm16(packSnorm16(-0.33)), closeTo(-0.33, 1.0 / 32767.0));
    });

    test('packUnorm8 and unpackUnorm8', () {
      expect(packUnorm8(1.0), equals(255));
      expect(packUnorm8(0.0), equals(0));
      expect(packUnorm8(0.5), equals(128));
      // Out of range clamps
      expect(packUnorm8(1.5), equals(255));
      expect(packUnorm8(-0.5), equals(0));

      expect(unpackUnorm8(packUnorm8(0.6)), closeTo(0.6, 1.0 / 255.0));
    });

    test('packSnorm16x4 quaternion packaging', () {
      final quat = Vector4(0.0, 0.70710678, 0.0, 0.70710678);
      final packed = packSnorm16x4(quat);
      expect(packed.length, equals(4));
      expect(packed[0], equals(0));
      expect(packed[1], equals(23170)); // round(0.70710678 * 32767) = 23170
      expect(packed[2], equals(0));
      expect(packed[3], equals(23170));
    });
  });

  group('gltfio Transform Util Tests', () {
    test('decomposeMatrix golden check', () {
      final t = Vector3(1.0, 2.0, 3.0);
      final r = Quaternion.axisAngle(Vector3(0, 1, 0), math.pi / 6); // 30 deg around Y
      final s = Vector3(2.0, 2.0, 2.0);

      final m = composeMatrix(t, r, s);
      final decomposed = decomposeMatrix(m);

      expect(decomposed.translation.x, closeTo(1.0, 1e-5));
      expect(decomposed.translation.y, closeTo(2.0, 1e-5));
      expect(decomposed.translation.z, closeTo(3.0, 1e-5));

      expect(decomposed.scale.x, closeTo(2.0, 1e-5));
      expect(decomposed.scale.y, closeTo(2.0, 1e-5));
      expect(decomposed.scale.z, closeTo(2.0, 1e-5));

      // Quaternion can have opposite sign representing same rotation
      final dot = decomposed.rotation.x * r.x +
          decomposed.rotation.y * r.y +
          decomposed.rotation.z * r.z +
          decomposed.rotation.w * r.w;
      expect(dot.abs(), closeTo(1.0, 1e-5));
    });

    test('decompose/compose 50 random TRS round trip', () {
      final rand = math.Random(54321);
      for (int i = 0; i < 50; i++) {
        final t = Vector3(
          (rand.nextDouble() * 2 - 1) * 100,
          (rand.nextDouble() * 2 - 1) * 100,
          (rand.nextDouble() * 2 - 1) * 100,
        );
        final axis = Vector3(
          rand.nextDouble() * 2 - 1,
          rand.nextDouble() * 2 - 1,
          rand.nextDouble() * 2 - 1,
        ).normalized();
        final angle = (rand.nextDouble() * 2 - 1) * math.pi;
        final r = Quaternion.axisAngle(axis, angle);
        final s = Vector3(
          rand.nextDouble() * 5 + 0.1,
          rand.nextDouble() * 5 + 0.1,
          rand.nextDouble() * 5 + 0.1,
        );

        final m1 = composeMatrix(t, r, s);
        final dec = decomposeMatrix(m1);
        final m2 = composeMatrix(dec.translation, dec.rotation, dec.scale);

        for (int c = 0; c < 4; c++) {
          for (int row = 0; row < 4; row++) {
            expect(m2.entry(row, c), closeTo(m1.entry(row, c), 1e-4));
          }
        }
      }
    });

    test('cubicSpline interpolation endpoints and midpoint', () {
      final v0 = Vector4(1, 0, 0, 0);
      final t0 = Vector4(0, 1, 0, 0);
      final v1 = Vector4(0, 1, 0, 0);
      final t1 = Vector4(0, -1, 0, 0);

      // t = 0 -> v0
      final at0 = cubicSpline(v0, t0, v1, t1, 0.0);
      expect(at0.x, closeTo(1.0, 1e-6));
      expect(at0.y, closeTo(0.0, 1e-6));

      // t = 1 -> v1
      final at1 = cubicSpline(v0, t0, v1, t1, 1.0);
      expect(at1.x, closeTo(0.0, 1e-6));
      expect(at1.y, closeTo(1.0, 1e-6));

      // Midpoint of symmetric spline
      final mid = cubicSpline(
        Vector4(0, 0, 0, 0),
        Vector4.zero(),
        Vector4(2, 4, 6, 8),
        Vector4.zero(),
        0.5,
      );
      expect(mid.x, closeTo(1.0, 1e-6));
      expect(mid.y, closeTo(2.0, 1e-6));
      expect(mid.z, closeTo(3.0, 1e-6));
      expect(mid.w, closeTo(4.0, 1e-6));
    });
  });
}
