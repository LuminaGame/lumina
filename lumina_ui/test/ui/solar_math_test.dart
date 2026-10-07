import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart' show LuminaAxes, LuminaDirectionalLightComponent;
import 'package:lumina_ui/ui/features/sub_editors/models/solar_math.dart';
import 'package:vector_math/vector_math_64.dart';

/// Pure solar/Kelvin helpers (deterministic,
/// editor conveniences: the generated game receives final direction/colour).
void main() {
  group('SolarMath.anglesForTime', () {
    test('06:00 is sunrise (elevation ~0), 12:00 is the maximum, 18:00 sets again', () {
      final sunrise = SolarMath.anglesForTime(6.0);
      final noon = SolarMath.anglesForTime(12.0);
      final sunset = SolarMath.anglesForTime(18.0);
      expect(sunrise.elevation, closeTo(0.0, 1e-6));
      expect(noon.elevation, closeTo(SolarMath.maxElevationDeg, 1e-6));
      expect(sunset.elevation, closeTo(0.0, 1e-6));
      // Ascending before noon, descending after.
      expect(SolarMath.anglesForTime(9.0).elevation, greaterThan(sunrise.elevation));
      expect(SolarMath.anglesForTime(9.0).elevation, lessThan(noon.elevation));
      expect(SolarMath.anglesForTime(15.0).elevation, lessThan(noon.elevation));
      expect(SolarMath.anglesForTime(15.0).elevation, greaterThan(sunset.elevation));
      // Every daytime sample sits above the horizon.
      for (var h = 6.5; h < 18.0; h += 0.5) {
        expect(SolarMath.anglesForTime(h).elevation, greaterThan(0.0), reason: 'hour $h');
      }
    });

    test('00:00 (and every night hour) is below the horizon', () {
      expect(SolarMath.anglesForTime(0.0).elevation, lessThan(0.0));
      expect(SolarMath.anglesForTime(3.0).elevation, lessThan(0.0));
      expect(SolarMath.anglesForTime(22.0).elevation, lessThan(0.0));
      expect(SolarMath.anglesForTime(24.0).elevation, lessThan(0.0), reason: '24:00 wraps to midnight');
    });

    test('azimuth increases monotonically through the day and is invertible to time', () {
      var last = -1.0;
      for (var h = 0.0; h < 24.0; h += 0.25) {
        final az = SolarMath.anglesForTime(h).azimuth;
        expect(az, greaterThan(last), reason: 'hour $h');
        expect(az, inInclusiveRange(0.0, 360.0));
        expect(SolarMath.timeForAzimuth(az), closeTo(h, 1e-9));
        last = az;
      }
      // Cardinal checkpoints: east at sunrise, south at noon, west at sunset.
      expect(SolarMath.anglesForTime(6.0).azimuth, closeTo(90.0, 1e-9));
      expect(SolarMath.anglesForTime(12.0).azimuth, closeTo(180.0, 1e-9));
      expect(SolarMath.anglesForTime(18.0).azimuth, closeTo(270.0, 1e-9));
    });
  });

  group('SolarMath.lightDirection', () {
    test('is unit length and Y-up: noon points straight down, sunrise light travels west', () {
      final noon = SolarMath.lightDirection(90.0, 180.0);
      expect(noon.length, closeTo(1.0, 1e-9));
      expect(noon.y, closeTo(-1.0, 1e-9));

      final sunrise = SolarMath.lightDirection(0.0, 90.0);
      expect(sunrise.length, closeTo(1.0, 1e-9));
      expect(sunrise.y, closeTo(0.0, 1e-9), reason: 'sun on the horizon');
      expect(sunrise.x, lessThan(0.0), reason: 'sun in the east (+X) lights toward -X');

      for (var h = 0.0; h < 24.0; h += 0.5) {
        final a = SolarMath.anglesForTime(h);
        expect(SolarMath.lightDirection(a.elevation, a.azimuth).length, closeTo(1.0, 1e-9));
      }
      // Above the horizon the light always travels downward (Y-up).
      final afternoon = SolarMath.anglesForTime(15.0);
      expect(SolarMath.lightDirection(afternoon.elevation, afternoon.azimuth).y, lessThan(0.0));
    });

    test('eulerForAngles is the stored (Z-up) rotation whose light travels along the sun direction', () {
      for (final sample in [(45.0, 217.5), (10.0, 95.0), (70.0, 300.0), (-20.0, 30.0)]) {
        final (el, az) = sample;
        final euler = SolarMath.eulerForAngles(el, az);
        // Exactly what PIE and the generated level build from the stored actor.
        final forward = LuminaDirectionalLightComponent(rotation: LuminaAxes.rotation(euler)).lightDirection;
        final expected = SolarMath.lightDirection(el, az);
        expect(forward.x, closeTo(expected.x, 1e-6), reason: 'x for $sample');
        expect(forward.y, closeTo(expected.y, 1e-6), reason: 'y for $sample');
        expect(forward.z, closeTo(expected.z, 1e-6), reason: 'z for $sample');
      }
    });
  });

  group('SolarMath.kelvinToRgb', () {
    test('6500 K is white within 5%', () {
      final c = SolarMath.kelvinToRgb(6500);
      expect(c.x, closeTo(1.0, 0.05));
      expect(c.y, closeTo(1.0, 0.05));
      expect(c.z, closeTo(1.0, 0.05));
    });

    test('2000 K is red-shifted and 12000 K is blue-shifted', () {
      final warm = SolarMath.kelvinToRgb(2000);
      expect(warm.x, greaterThan(warm.z));
      expect(warm.x, closeTo(1.0, 1e-6));
      final cool = SolarMath.kelvinToRgb(12000);
      expect(cool.z, greaterThan(cool.x));
      expect(cool.z, closeTo(1.0, 1e-6));
    });

    test('channels stay within 0..1 across the slider range and hex round-trips', () {
      for (var k = 1500.0; k <= 15000.0; k += 250.0) {
        final c = SolarMath.kelvinToRgb(k);
        for (final ch in [c.x, c.y, c.z]) {
          expect(ch, inInclusiveRange(0.0, 1.0), reason: '$k K');
        }
      }
      expect(SolarMath.rgbToHex(Vector3(1.0, 0.0, 0.0)), '#FF0000');
      expect(SolarMath.hexToRgb('#00FF00'), Vector3(0.0, 1.0, 0.0));
      expect(SolarMath.hexToRgb('#0000FF'), Vector3(0.0, 0.0, 1.0));
    });
  });

  group('SolarMath labels', () {
    test('formats HH:MM and names the day phase', () {
      expect(SolarMath.formatTime(14.5), '14:30');
      expect(SolarMath.formatTime(6.0), '06:00');
      expect(SolarMath.formatTime(23.99), '23:59');
      expect(SolarMath.dayPhase(14.5), 'Afternoon');
      expect(SolarMath.dayPhase(9.0), 'Morning');
      expect(SolarMath.dayPhase(0.0), 'Night');
      expect(SolarMath.dayPhase(6.5), 'Dawn');
      expect(SolarMath.dayPhase(18.5), 'Dusk');
    });
  });
}
