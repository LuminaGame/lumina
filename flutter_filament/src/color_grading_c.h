#ifndef FLUTTER_FILAMENT_COLOR_GRADING_C_H
#define FLUTTER_FILAMENT_COLOR_GRADING_C_H

#include <stdint.h>
#include <stdbool.h>

#ifndef FFI_PLUGIN_EXPORT
#if defined(_WIN32)
#define FFI_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FFI_PLUGIN_EXPORT __attribute__((visibility("default"))) __attribute__((used))
#endif
#endif

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
    FILAMENT_TONE_MAPPER_LINEAR = 0,
    FILAMENT_TONE_MAPPER_ACES = 1,
    FILAMENT_TONE_MAPPER_ACES_LEGACY = 2,
    FILAMENT_TONE_MAPPER_FILMIC = 3,
    FILAMENT_TONE_MAPPER_PBR_NEUTRAL = 4,
    FILAMENT_TONE_MAPPER_GT7 = 5,
    FILAMENT_TONE_MAPPER_AGX = 6,
    FILAMENT_TONE_MAPPER_GENERIC = 7,
    FILAMENT_TONE_MAPPER_DISPLAY_RANGE = 8
} FilamentToneMapperType;

typedef enum {
    FILAMENT_AGX_LOOK_NONE = 0,
    FILAMENT_AGX_LOOK_PUNCHY = 1,
    FILAMENT_AGX_LOOK_GOLDEN = 2
} FilamentAgxLook;

typedef enum {
    FILAMENT_COLOR_GRADING_QUALITY_LOW = 0,
    FILAMENT_COLOR_GRADING_QUALITY_MEDIUM = 1,
    FILAMENT_COLOR_GRADING_QUALITY_HIGH = 2,
    FILAMENT_COLOR_GRADING_QUALITY_ULTRA = 3
} FilamentColorGradingQuality;

typedef enum {
    FILAMENT_LUT_FORMAT_INTEGER = 0,
    FILAMENT_LUT_FORMAT_FLOAT = 1
} FilamentLutFormat;

// ToneMapper
FFI_PLUGIN_EXPORT void* filament_tone_mapper_create(int type);
FFI_PLUGIN_EXPORT void* filament_tone_mapper_create_agx(int look);
FFI_PLUGIN_EXPORT void* filament_tone_mapper_create_generic(float contrast, float mid_gray_in, float mid_gray_out, float hdr_max);
FFI_PLUGIN_EXPORT void filament_tone_mapper_destroy(void* tone_mapper);

// ColorGrading Builder
FFI_PLUGIN_EXPORT void* filament_color_grading_builder_create(void);
FFI_PLUGIN_EXPORT void filament_color_grading_builder_quality(void* builder, int quality);
FFI_PLUGIN_EXPORT void filament_color_grading_builder_format(void* builder, int lut_format);
FFI_PLUGIN_EXPORT void filament_color_grading_builder_dimensions(void* builder, uint8_t dim);
FFI_PLUGIN_EXPORT void filament_color_grading_builder_tone_mapper(void* builder, void* tone_mapper);
FFI_PLUGIN_EXPORT void filament_color_grading_builder_exposure(void* builder, float exposure);
FFI_PLUGIN_EXPORT void filament_color_grading_builder_night_adaptation(void* builder, float adaptation);
FFI_PLUGIN_EXPORT void filament_color_grading_builder_white_balance(void* builder, float temperature, float tint);
FFI_PLUGIN_EXPORT void filament_color_grading_builder_channel_mixer(void* builder, const float* out_red3, const float* out_green3, const float* out_blue3);
FFI_PLUGIN_EXPORT void filament_color_grading_builder_shadows_midtones_highlights(void* builder, const float* shadows4, const float* midtones4, const float* highlights4, const float* ranges4);
FFI_PLUGIN_EXPORT void filament_color_grading_builder_slope_offset_power(void* builder, const float* slope3, const float* offset3, const float* power3);
FFI_PLUGIN_EXPORT void filament_color_grading_builder_contrast(void* builder, float contrast);
FFI_PLUGIN_EXPORT void filament_color_grading_builder_vibrance(void* builder, float vibrance);
FFI_PLUGIN_EXPORT void filament_color_grading_builder_saturation(void* builder, float saturation);
FFI_PLUGIN_EXPORT void filament_color_grading_builder_curves(void* builder, const float* shadow_gamma3, const float* mid_point3, const float* highlight_scale3);
FFI_PLUGIN_EXPORT void filament_color_grading_builder_luminance_scaling(void* builder, bool enabled);
FFI_PLUGIN_EXPORT void filament_color_grading_builder_gamut_mapping(void* builder, bool enabled);
FFI_PLUGIN_EXPORT void* filament_color_grading_builder_build(void* builder, void* engine);
FFI_PLUGIN_EXPORT void filament_color_grading_builder_destroy(void* builder);

// View and Engine lifecycle
FFI_PLUGIN_EXPORT void filament_view_set_color_grading(void* view, void* color_grading);
FFI_PLUGIN_EXPORT void filament_engine_destroy_color_grading(void* engine, void* color_grading);

#ifdef __cplusplus
}
#endif

#endif // FLUTTER_FILAMENT_COLOR_GRADING_C_H
