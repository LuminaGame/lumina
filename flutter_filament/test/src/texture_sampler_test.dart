import 'package:flutter_filament/src/texture_sampler.dart';
import 'package:flutter_filament/src/third_party/filament_c.g.dart' as c;
import 'package:test/test.dart';

void main() {
  group('TextureSampler Tests', () {
    test('Default constructor matches C default', () {
      final defaultSampler = TextureSampler();
      final cDefault = c.filament_test_sampler_params_default();
      expect(defaultSampler.packed, equals(cDefault));
    });

    test('Anisotropy quantization matches ilogbf', () {
      // Dart TextureSampler internal quantization
      expect(TextureSampler(anisotropy: 1.0).anisotropyLog2, 0);
      expect(TextureSampler(anisotropy: 2.0).anisotropyLog2, 1);
      expect(TextureSampler(anisotropy: 3.9).anisotropyLog2, 1);
      expect(TextureSampler(anisotropy: 4.0).anisotropyLog2, 2);
      expect(TextureSampler(anisotropy: 7.0).anisotropyLog2, 2);
      expect(TextureSampler(anisotropy: 8.0).anisotropyLog2, 3);
      expect(TextureSampler(anisotropy: 16.0).anisotropyLog2, 4);
      expect(TextureSampler(anisotropy: 128.0).anisotropyLog2, 7);
      expect(TextureSampler(anisotropy: 256.0).anisotropyLog2, 7); // Clamped
      expect(TextureSampler(anisotropy: 0.0).anisotropyLog2, 0);
      expect(TextureSampler(anisotropy: 0.5).anisotropyLog2, 0);
      expect(TextureSampler(anisotropy: -4.0).anisotropyLog2, 2);

      // Verify C-side quantization
      expect(
        TextureSampler(anisotropy: 16.0).packed,
        c.filament_test_sampler_params_pack(0, 0, 0, 0, 0, 16.0, 0, 0)
      );
    });

    test('TextureSampler.trilinear() matches C', () {
      final trilinear = TextureSampler.trilinear();
      expect(trilinear.filterMin, equals(SamplerMinFilter.linearMipmapLinear));
      expect(trilinear.filterMag, equals(SamplerMagFilter.linear));
      expect(trilinear.wrapS, equals(SamplerWrapMode.repeat));
      expect(trilinear.wrapT, equals(SamplerWrapMode.repeat));
      expect(trilinear.wrapR, equals(SamplerWrapMode.repeat));

      final cTrilinear = c.filament_test_sampler_params_pack(
        SamplerMinFilter.linearMipmapLinear.value,
        SamplerMagFilter.linear.value,
        SamplerWrapMode.repeat.value,
        SamplerWrapMode.repeat.value,
        SamplerWrapMode.repeat.value,
        1.0,
        SamplerCompareMode.none.value,
        SamplerCompareFunc.le.value,
      );

      expect(trilinear.packed, equals(cTrilinear));
    });

    test('TextureSampler.compare() matches C', () {
      final compare = TextureSampler.compare(SamplerCompareFunc.ge);
      expect(compare.compareMode, equals(SamplerCompareMode.compareToTexture));
      expect(compare.compareFunc, equals(SamplerCompareFunc.ge));

      final cCompare = c.filament_test_sampler_params_pack(
        SamplerMinFilter.linear.value,
        SamplerMagFilter.linear.value,
        SamplerWrapMode.clampToEdge.value,
        SamplerWrapMode.clampToEdge.value,
        SamplerWrapMode.clampToEdge.value,
        1.0,
        SamplerCompareMode.compareToTexture.value,
        SamplerCompareFunc.ge.value,
      );

      expect(compare.packed, equals(cCompare));
    });

    test('Cross-validation matrix over combinations', () {
      final minFilters = SamplerMinFilter.values;
      final magFilters = SamplerMagFilter.values;
      final wraps = SamplerWrapMode.values;
      final compareModes = SamplerCompareMode.values;
      final anisotropies = [1.0, 4.0, 16.0];

      for (var min in minFilters) {
        for (var mag in magFilters) {
          for (var wrap in wraps) {
            for (var mode in compareModes) {
              for (var aniso in anisotropies) {
                final sampler = TextureSampler(
                  filterMin: min,
                  filterMag: mag,
                  wrapS: wrap,
                  wrapT: wrap,
                  wrapR: wrap,
                  anisotropy: aniso,
                  compareMode: mode,
                  compareFunc: SamplerCompareFunc.le,
                );

                final cPacked = c.filament_test_sampler_params_pack(
                  min.value,
                  mag.value,
                  wrap.value,
                  wrap.value,
                  wrap.value,
                  aniso,
                  mode.value,
                  SamplerCompareFunc.le.value,
                );

                expect(sampler.packed, equals(cPacked), reason: 'Failed for sampler: $sampler');
              }
            }
          }
        }
      }
    });

    test('Equality and hashCode', () {
      final s1 = TextureSampler();
      final s2 = TextureSampler();
      final s3 = TextureSampler(filterMag: SamplerMagFilter.linear);

      expect(s1, equals(s2));
      expect(s1.hashCode, equals(s2.hashCode));
      expect(s1, isNot(equals(s3)));
      expect(s1.hashCode, isNot(equals(s3.hashCode)));
    });
  });
}
