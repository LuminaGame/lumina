import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_filament/src/third_party/filament_c.g.dart' as c;
import 'package:test/test.dart';

void main() {
  group('Pure-Dart TextureSampler & Packed SamplerParams Bitfield Fidelity', () {
    test('Default TextureSampler packed value matches C++ TextureSampler() default exactly', () {
      final dartDefault = const TextureSampler();
      final cDefault = c.filament_test_sampler_params_default();
      expect(dartDefault.packed, equals(cDefault));
    });

    test('Cross-validation matrix over sampled combinations matches C++ packing bit-for-bit', () {
      for (final min in SamplerMinFilter.values) {
        for (final mag in SamplerMagFilter.values) {
          for (final wrap in SamplerWrapMode.values) {
            for (final compareMode in SamplerCompareMode.values) {
              for (final aniso in [1.0, 4.0, 16.0]) {
                final sampler = TextureSampler(
                  filterMin: min,
                  filterMag: mag,
                  wrapS: wrap,
                  wrapT: wrap,
                  wrapR: wrap,
                  anisotropy: aniso,
                  compareMode: compareMode,
                  compareFunc: SamplerCompareFunc.ge,
                );

                final cPacked = c.filament_test_sampler_params_pack(
                  min.value,
                  mag.value,
                  wrap.value,
                  wrap.value,
                  wrap.value,
                  aniso,
                  compareMode.value,
                  SamplerCompareFunc.ge.value,
                );

                expect(
                  sampler.packed,
                  equals(cPacked),
                  reason: 'Mismatch for min=$min, mag=$mag, wrap=$wrap, compare=$compareMode, aniso=$aniso',
                );
              }
            }
          }
        }
      }
    });

    test('Anisotropy quantization matches C++ ilogbf exponent levels', () {
      final cases = <double, int>{
        1.0: 0,
        2.0: 1,
        4.0: 2,
        7.0: 2,
        8.0: 3,
        16.0: 4,
        32.0: 5,
        64.0: 6,
        128.0: 7,
        200.0: 7,
      };

      for (final entry in cases.entries) {
        final aniso = entry.key;
        final expectedLog2 = entry.value;

        final s = TextureSampler(anisotropy: aniso);
        expect(s.anisotropyLog2, equals(expectedLog2));

        final cPacked = c.filament_test_sampler_params_pack(
          SamplerMinFilter.nearest.value,
          SamplerMagFilter.nearest.value,
          SamplerWrapMode.clampToEdge.value,
          SamplerWrapMode.clampToEdge.value,
          SamplerWrapMode.clampToEdge.value,
          aniso,
          SamplerCompareMode.none.value,
          SamplerCompareFunc.le.value,
        );

        expect(s.packed, equals(cPacked));
      }
    });

    test('TextureSampler.trilinear constructor packs linearMipmapLinear + linear + repeat', () {
      const trilinear = TextureSampler.trilinear();
      expect(trilinear.filterMin, equals(SamplerMinFilter.linearMipmapLinear));
      expect(trilinear.filterMag, equals(SamplerMagFilter.linear));
      expect(trilinear.wrapS, equals(SamplerWrapMode.repeat));
      expect(trilinear.wrapT, equals(SamplerWrapMode.repeat));

      final cPacked = c.filament_test_sampler_params_pack(
        SamplerMinFilter.linearMipmapLinear.value,
        SamplerMagFilter.linear.value,
        SamplerWrapMode.repeat.value,
        SamplerWrapMode.repeat.value,
        SamplerWrapMode.repeat.value,
        1.0,
        SamplerCompareMode.none.value,
        SamplerCompareFunc.le.value,
      );

      expect(trilinear.packed, equals(cPacked));
    });

    test('TextureSampler.compare constructor sets compareToTexture mode', () {
      const compareSampler = TextureSampler.compare(SamplerCompareFunc.ge);
      expect(compareSampler.compareMode, equals(SamplerCompareMode.compareToTexture));
      expect(compareSampler.compareFunc, equals(SamplerCompareFunc.ge));

      final cPacked = c.filament_test_sampler_params_pack(
        SamplerMinFilter.linear.value,
        SamplerMagFilter.linear.value,
        SamplerWrapMode.clampToEdge.value,
        SamplerWrapMode.clampToEdge.value,
        SamplerWrapMode.clampToEdge.value,
        1.0,
        SamplerCompareMode.compareToTexture.value,
        SamplerCompareFunc.ge.value,
      );

      expect(compareSampler.packed, equals(cPacked));
    });

    test('Value equality and hashCode caching', () {
      const s1 = TextureSampler.trilinear(wrap: SamplerWrapMode.repeat);
      const s2 = TextureSampler.trilinear(wrap: SamplerWrapMode.repeat);
      const s3 = TextureSampler.trilinear(wrap: SamplerWrapMode.clampToEdge);

      expect(s1, equals(s2));
      expect(s1.hashCode, equals(s2.hashCode));
      expect(s1 == s3, isFalse);
    });
  });
}
