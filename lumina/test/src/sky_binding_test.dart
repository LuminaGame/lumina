import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  group('LuminaSkyDescription', () {
    test('defaults are a visible daylight sky with real ambient intensity', () {
      final d = LuminaSkyDescription.defaults;
      expect(d.useEnvironmentMap, isFalse);
      expect(d.skyVisible, isTrue);
      expect(d.skyIntensity, greaterThan(0));
      expect(d.iblIntensity, greaterThan(0));
      // #5C7FB8 is a blue: blue channel dominates.
      expect(d.color.z, greaterThan(d.color.x));
    });

    test('colorFromHex converts sRGB hex to linear RGB', () {
      final white = LuminaSkyDescription.colorFromHex('#FFFFFF');
      expect(white.x, closeTo(1.0, 1e-6));
      expect(white.y, closeTo(1.0, 1e-6));
      expect(white.z, closeTo(1.0, 1e-6));

      final black = LuminaSkyDescription.colorFromHex('#000000');
      expect(black.x, closeTo(0.0, 1e-6));

      // Mid grey must decode darker in linear space than in sRGB space.
      final grey = LuminaSkyDescription.colorFromHex('#808080');
      expect(grey.x, lessThan(0.5));
      expect(grey.x, greaterThan(0.1));

      // Alpha-prefixed and malformed inputs stay usable.
      expect(LuminaSkyDescription.colorFromHex('#FF5C7FB8').z,
          closeTo(LuminaSkyDescription.colorFromHex('#5C7FB8').z, 1e-9));
      expect(LuminaSkyDescription.colorFromHex('nonsense').w, 1.0);
    });

    test('fromProperties reads the LuminaSkyComponent property map the editor writes', () {
      final d = LuminaSkyDescription.fromProperties(const {
        'mode': 'color',
        'colorHex': '#5C7FB8',
        'sky_environment': null,
        'skyIntensity': 42000.0,
        'iblIntensity': 21000.0,
        'rotationDegrees': 35.0,
        'showSun': true,
        'followTimeOfDay': false,
      });
      expect(d.useEnvironmentMap, isFalse);
      expect(d.skyIntensity, 42000.0);
      expect(d.iblIntensity, 21000.0);
      expect(d.rotationDegrees, 35.0);
      expect(d.showSun, isTrue);
      expect(d.color, LuminaSkyDescription.colorFromHex('#5C7FB8'));
    });

    test('fromProperties picks up an HDRI environment reference', () {
      final d = LuminaSkyDescription.fromProperties(const {
        'mode': 'environment',
        'sky_environment': {
          'slot_name': 'sky_environment',
          'asset_id': '',
          'asset_path': 'contents/textures/venetian.ktx',
        },
      });
      expect(d.useEnvironmentMap, isTrue);
      expect(d.environmentAssetPath, 'contents/textures/venetian.ktx');
    });

    test('environment mode without an asset path degrades to colour mode', () {
      final d = LuminaSkyDescription.fromProperties(const {'mode': 'environment'});
      expect(d.useEnvironmentMap, isFalse);
    });

    test('fromProperties falls back to defaults for empty or malformed maps', () {
      expect(LuminaSkyDescription.fromProperties(null), LuminaSkyDescription.defaults);
      expect(LuminaSkyDescription.fromProperties(const {}), LuminaSkyDescription.defaults);
      final partial = LuminaSkyDescription.fromProperties(const {'skyIntensity': 'not a number'});
      expect(partial.skyIntensity, LuminaSkyDescription.defaults.skyIntensity);
    });

    test('needsRebuildFrom only demands a rebuild for structural changes', () {
      final base = LuminaSkyDescription(color: Vector4(0.1, 0.2, 0.3, 1.0));
      expect(base.needsRebuildFrom(base), isFalse);
      // Colour / ambient intensity / rotation / visibility are live-tunable.
      expect(base.copyWith(color: Vector4(0.9, 0.1, 0.1, 1.0)).needsRebuildFrom(base), isFalse);
      expect(base.copyWith(iblIntensity: 1000.0).needsRebuildFrom(base), isFalse);
      expect(base.copyWith(rotationDegrees: 90.0).needsRebuildFrom(base), isFalse);
      expect(base.copyWith(skyVisible: false).needsRebuildFrom(base), isFalse);
      // Source, sun disc and sky intensity are baked into the native Skybox.
      expect(base.copyWith(useEnvironmentMap: true).needsRebuildFrom(base), isTrue);
      expect(base.copyWith(showSun: true).needsRebuildFrom(base), isTrue);
      expect(base.copyWith(skyIntensity: 1.0).needsRebuildFrom(base), isTrue);
    });

    test('effectiveSkyColor scales color channels by skyIntensity', () {
      final base = LuminaSkyDescription(color: Vector4(0.5, 0.4, 0.3, 1.0), skyIntensity: 30000.0);
      expect(base.effectiveSkyColor.x, closeTo(0.5, 1e-4));
      expect(base.effectiveSkyColor.y, closeTo(0.4, 1e-4));

      final dimmed = base.copyWith(skyIntensity: 15000.0);
      expect(dimmed.effectiveSkyColor.x, closeTo(0.25, 1e-4));
      expect(dimmed.effectiveSkyColor.y, closeTo(0.2, 1e-4));

      final zero = base.copyWith(skyIntensity: 0.0);
      expect(zero.effectiveSkyColor.x, 0.0);
      expect(zero.effectiveSkyColor.y, 0.0);
      expect(zero.effectiveSkyColor.z, 0.0);
    });

    test('effectiveIblIntensity scales with skyIntensity in color mode', () {
      final base = LuminaSkyDescription(color: Vector4(1, 1, 1, 1), skyIntensity: 30000.0, iblIntensity: 30000.0);
      expect(base.effectiveIblIntensity, 30000.0);

      final dimmed = base.copyWith(skyIntensity: 15000.0);
      expect(dimmed.effectiveIblIntensity, 15000.0);

      final zeroIbl = base.copyWith(iblIntensity: 0.0);
      expect(zeroIbl.effectiveIblIntensity, 0.0);

      final zeroSky = base.copyWith(skyIntensity: 0.0);
      expect(zeroSky.effectiveIblIntensity, 0.0);
    });

    test('equality and copyWith round-trip', () {
      final a = LuminaSkyDescription.defaults;
      expect(a.copyWith(), a);
      expect(a.copyWith().hashCode, a.hashCode);
      expect(a.copyWith(iblIntensity: 1.0) == a, isFalse);
    });
  });
}
