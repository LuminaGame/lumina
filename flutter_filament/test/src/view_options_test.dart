import 'dart:ffi';
import 'package:test/test.dart';
import 'package:flutter_filament/src/view_options.dart';
import 'package:flutter_filament/src/third_party/filament_c.g.dart' as ffi_gen;

void main() {
  group('ViewOptions struct sizes', () {
    test('sizeof match C++ structs', () {
      // 0: DynamicResolutionOptions
      expect(sizeOf<ffi_gen.filament_dynamic_resolution_options>(), ffi_gen.filament_options_sizeof(0));
      // 1: BloomOptions
      expect(sizeOf<ffi_gen.filament_bloom_options>(), ffi_gen.filament_options_sizeof(1));
      // 2: FogOptions
      expect(sizeOf<ffi_gen.filament_fog_options>(), ffi_gen.filament_options_sizeof(2));
      // 3: DepthOfFieldOptions
      expect(sizeOf<ffi_gen.filament_depth_of_field_options>(), ffi_gen.filament_options_sizeof(3));
      // 4: VignetteOptions
      expect(sizeOf<ffi_gen.filament_vignette_options>(), ffi_gen.filament_options_sizeof(4));
      // 5: RenderQuality
      expect(sizeOf<ffi_gen.filament_render_quality>(), ffi_gen.filament_options_sizeof(5));
      // 6: AmbientOcclusionOptions
      expect(sizeOf<ffi_gen.filament_ambient_occlusion_options>(), ffi_gen.filament_options_sizeof(6));
      // 7: MultiSampleAntiAliasingOptions
      expect(sizeOf<ffi_gen.filament_multi_sample_anti_aliasing_options>(), ffi_gen.filament_options_sizeof(7));
      // 8: TemporalAntiAliasingOptions
      expect(sizeOf<ffi_gen.filament_temporal_anti_aliasing_options>(), ffi_gen.filament_options_sizeof(8));
      // 9: ScreenSpaceReflectionsOptions
      expect(sizeOf<ffi_gen.filament_screen_space_reflections_options>(), ffi_gen.filament_options_sizeof(9));
      // 10: GuardBandOptions
      expect(sizeOf<ffi_gen.filament_guard_band_options>(), ffi_gen.filament_options_sizeof(10));
      // 11: VsmShadowOptions
      expect(sizeOf<ffi_gen.filament_vsm_shadow_options>(), ffi_gen.filament_options_sizeof(11));
      // 12: SoftShadowOptions
      expect(sizeOf<ffi_gen.filament_soft_shadow_options>(), ffi_gen.filament_options_sizeof(12));
      // 13: StereoscopicOptions
      expect(sizeOf<ffi_gen.filament_stereoscopic_options>(), ffi_gen.filament_options_sizeof(13));
    });
  });

  group('ViewOptions API values', () {
    test('Default values', () {
      final bloom = BloomOptions();
      expect(bloom.strength, 0.10);
      expect(bloom.levels, 6);
      expect(bloom.blendMode, BloomBlendMode.add);
      expect(bloom.blendMode.toNative(), 0);

      final ao = AmbientOcclusionOptions();
      expect(ao.aoType, AmbientOcclusionType.sao);
      expect(ao.ssctLightDirectionY, -1.0);
    });
  });
}
