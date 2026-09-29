import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:flutter_filament/flutter_filament.dart';

void main() {
  group('Color and Exposure Tests', () {
    test('sRGB toLinear and toSRGB ACCURATE and FAST curve differences', () {
      final srgbHalf = Vector3.all(0.5);

      final linearAcc = FilamentColor.toLinear(srgbHalf, ColorConversion.accurate);
      final linearFast = FilamentColor.toLinear(srgbHalf, ColorConversion.fast);

      // ACCURATE: ~0.21404
      expect(linearAcc.x, closeTo(0.21404, 1e-4));
      // FAST: 0.5^2.2 ~ 0.217637
      expect(linearFast.x, closeTo(math.pow(0.5, 2.2), 1e-4));
      // The two modes must differ measurably
      expect((linearAcc.x - linearFast.x).abs() > 1e-3, isTrue);

      // Toe region: 0.003 <= 0.04045
      final toeSrgb = Vector3.all(0.003);
      final toeLinear = FilamentColor.toLinear(toeSrgb, ColorConversion.accurate);
      expect(toeLinear.x, closeTo(0.003 / 12.92, 1e-6));

      // Inverse of 0.21404 is ~0.5
      final srgbRoundtrip = FilamentColor.toSRGB(Vector3.all(0.21404), ColorConversion.accurate);
      expect(srgbRoundtrip.x, closeTo(0.5, 1e-4));
    });

    test('Round trip 64 random sRGB triples with ACCURATE conversion', () {
      final rand = math.Random(1234);
      for (int i = 0; i < 64; i++) {
        final original = Vector3(rand.nextDouble(), rand.nextDouble(), rand.nextDouble());
        final linear = FilamentColor.toLinear(original, ColorConversion.accurate);
        final roundtrip = FilamentColor.toSRGB(linear, ColorConversion.accurate);

        expect(roundtrip.x, closeTo(original.x, 1e-5));
        expect(roundtrip.y, closeTo(original.y, 1e-5));
        expect(roundtrip.z, closeTo(original.z, 1e-5));
      }

      // Alpha passthrough
      final rgba = Vector4(0.5, 0.4, 0.3, 0.85);
      final linearRgba = FilamentColor.toLinearRgba(rgba, ColorConversion.accurate);
      expect(linearRgba.w, equals(0.85));
      final srgbRgba = FilamentColor.toSRGBRgba(linearRgba, ColorConversion.accurate);
      expect(srgbRgba.w, equals(0.85));
      expect(srgbRgba.x, closeTo(0.5, 1e-5));
    });

    test('cct behavior across color temperatures', () {
      // cct(6504) is near D65 standard white
      final white = FilamentColor.cct(6504);
      expect(white.x, inInclusiveRange(0.85, 1.15));
      expect(white.y, inInclusiveRange(0.85, 1.15));
      expect(white.z, inInclusiveRange(0.85, 1.15));

      // cct(2000) is strongly warm (r > g > b, b < 0.5 * r)
      final warm = FilamentColor.cct(2000);
      expect(warm.x > warm.y, isTrue);
      expect(warm.y > warm.z, isTrue);
      expect(warm.z < 0.5 * warm.x, isTrue);

      // cct(12000) is cool (b > r)
      final cool = FilamentColor.cct(12000);
      expect(cool.z > cool.x, isTrue);

      // Monotonicity: r/b ratio strictly decreases as K rises
      final temps = [2000.0, 4000.0, 6504.0, 10000.0, 15000.0];
      double prevRatio = double.infinity;
      for (final t in temps) {
        final c = FilamentColor.cct(t);
        final ratio = c.x / c.z;
        expect(ratio < prevRatio, isTrue, reason: 'r/b ratio should strictly decrease at $t K');
        prevRatio = ratio;
      }
    });

    test('illuminantD behavior across color temperatures', () {
      final whiteD = FilamentColor.illuminantD(6504);
      expect(whiteD.x, inInclusiveRange(0.85, 1.15));
      expect(whiteD.y, inInclusiveRange(0.85, 1.15));
      expect(whiteD.z, inInclusiveRange(0.85, 1.15));

      final warmD = FilamentColor.illuminantD(4000);
      final coolD = FilamentColor.illuminantD(25000);
      expect((warmD.x / warmD.z) > (coolD.x / coolD.z), isTrue);
    });

    test('absorptionAtDistance formula verification', () {
      final transmittance = Vector3(0.5, 0.5, 0.5);
      final abs1 = FilamentColor.absorptionAtDistance(transmittance, 1.0);
      expect(abs1.x, closeTo(-math.log(0.5), 1e-4));
      expect(abs1.y, closeTo(-math.log(0.5), 1e-4));
      expect(abs1.z, closeTo(-math.log(0.5), 1e-4));

      // Distance scaling is 1/d
      final abs2 = FilamentColor.absorptionAtDistance(transmittance, 2.0);
      expect(abs2.x, closeTo(abs1.x / 2.0, 1e-5));
    });

    test('Exposure ev100 and exposure formulas', () {
      // ev100(aperture: 16, shutterSpeed: 1/125, sensitivity: 100) = log2(16^2 * 125) = log2(32000) ~ 14.96578
      final ev = Exposure.ev100(aperture: 16.0, shutterSpeed: 1.0 / 125.0, sensitivity: 100.0);
      expect(ev, closeTo(14.96578, 1e-2));

      // exposureFromEv100(15) = 1 / (1.2 * 2^15)
      final exp15 = Exposure.exposureFromEv100(15.0);
      final expectedExp15 = 1.0 / (1.2 * math.pow(2.0, 15));
      expect(exp15, closeTo(expectedExp15, 1e-9));

      // direct exposure parameters vs exposureFromEv100
      final expDirect = Exposure.exposure(aperture: 16.0, shutterSpeed: 1.0 / 125.0, sensitivity: 100.0);
      expect(expDirect, closeTo(Exposure.exposureFromEv100(ev), 1e-7));
    });

    test('Inverse pairs for luminance and illuminance', () {
      final luminanceValues = [0.1, 1.0, 4000.0, 100000.0];
      for (final L in luminanceValues) {
        final ev = Exposure.ev100FromLuminance(L);
        final roundtripL = Exposure.luminanceFromEv100(ev);
        expect(roundtripL, closeTo(L, L * 1e-6));
      }

      // ev100FromLuminance(4000) = log2(4000 * 100 / 12.5) = log2(32000) ~ 14.96578
      expect(Exposure.ev100FromLuminance(4000.0), closeTo(14.96578, 1e-2));

      final illuminanceValues = [0.1, 1.0, 2500.0, 100000.0];
      for (final E in illuminanceValues) {
        final ev = Exposure.ev100FromIlluminance(E);
        final roundtripE = Exposure.illuminanceFromEv100(ev);
        expect(roundtripE, closeTo(E, E * 1e-6));
      }
    });

    test('Domain clamping for cct and illuminantD', () {
      final cctBelow = FilamentColor.cct(500);
      final cct1000 = FilamentColor.cct(1000);
      expect(cctBelow, equals(cct1000));

      final cctAbove = FilamentColor.cct(20000);
      final cct15000 = FilamentColor.cct(15000);
      expect(cctAbove, equals(cct15000));

      final dBelow = FilamentColor.illuminantD(2000);
      final d4000 = FilamentColor.illuminantD(4000);
      expect(dBelow, equals(d4000));

      final dAbove = FilamentColor.illuminantD(30000);
      final d25000 = FilamentColor.illuminantD(25000);
      expect(dAbove, equals(d25000));
    });
  });
}
