#include "color_grading_c.h"

#include <filament/ColorGrading.h>
#include <filament/Engine.h>
#include <filament/ToneMapper.h>
#include <filament/View.h>
#include <math/vec3.h>
#include <math/vec4.h>

using namespace filament;
using namespace filament::math;

extern "C" {

void* filament_tone_mapper_create(int type) {
    switch (type) {
        case FILAMENT_TONE_MAPPER_LINEAR:
            return new LinearToneMapper();
        case FILAMENT_TONE_MAPPER_ACES:
            return new ACESToneMapper();
        case FILAMENT_TONE_MAPPER_ACES_LEGACY:
            return new ACESLegacyToneMapper();
        case FILAMENT_TONE_MAPPER_FILMIC:
            return new FilmicToneMapper();
        case FILAMENT_TONE_MAPPER_PBR_NEUTRAL:
            return new PBRNeutralToneMapper();
        case FILAMENT_TONE_MAPPER_GT7:
            return new GT7ToneMapper();
        case FILAMENT_TONE_MAPPER_AGX:
            return new AgxToneMapper(AgxToneMapper::AgxLook::NONE);
        case FILAMENT_TONE_MAPPER_GENERIC:
            return new GenericToneMapper();
        case FILAMENT_TONE_MAPPER_DISPLAY_RANGE:
            return new DisplayRangeToneMapper();
        default:
            return new ACESLegacyToneMapper();
    }
}

void* filament_tone_mapper_create_agx(int look) {
    AgxToneMapper::AgxLook agxLook = AgxToneMapper::AgxLook::NONE;
    if (look == FILAMENT_AGX_LOOK_PUNCHY) {
        agxLook = AgxToneMapper::AgxLook::PUNCHY;
    } else if (look == FILAMENT_AGX_LOOK_GOLDEN) {
        agxLook = AgxToneMapper::AgxLook::GOLDEN;
    }
    return new AgxToneMapper(agxLook);
}

void* filament_tone_mapper_create_generic(float contrast, float mid_gray_in, float mid_gray_out, float hdr_max) {
    return new GenericToneMapper(contrast, mid_gray_in, mid_gray_out, hdr_max);
}

void filament_tone_mapper_destroy(void* tone_mapper) {
    if (tone_mapper != nullptr) {
        delete static_cast<ToneMapper*>(tone_mapper);
    }
}

void* filament_color_grading_builder_create(void) {
    return new ColorGrading::Builder();
}

void filament_color_grading_builder_quality(void* builder, int quality) {
    if (builder == nullptr) return;
    auto* b = static_cast<ColorGrading::Builder*>(builder);
    ColorGrading::QualityLevel q = ColorGrading::QualityLevel::MEDIUM;
    switch (quality) {
        case FILAMENT_COLOR_GRADING_QUALITY_LOW:
            q = ColorGrading::QualityLevel::LOW;
            break;
        case FILAMENT_COLOR_GRADING_QUALITY_MEDIUM:
            q = ColorGrading::QualityLevel::MEDIUM;
            break;
        case FILAMENT_COLOR_GRADING_QUALITY_HIGH:
            q = ColorGrading::QualityLevel::HIGH;
            break;
        case FILAMENT_COLOR_GRADING_QUALITY_ULTRA:
            q = ColorGrading::QualityLevel::ULTRA;
            break;
    }
    b->quality(q);
}

void filament_color_grading_builder_format(void* builder, int lut_format) {
    if (builder == nullptr) return;
    auto* b = static_cast<ColorGrading::Builder*>(builder);
    ColorGrading::LutFormat fmt = (lut_format == FILAMENT_LUT_FORMAT_FLOAT)
            ? ColorGrading::LutFormat::FLOAT
            : ColorGrading::LutFormat::INTEGER;
    b->format(fmt);
}

void filament_color_grading_builder_dimensions(void* builder, uint8_t dim) {
    if (builder == nullptr) return;
    static_cast<ColorGrading::Builder*>(builder)->dimensions(dim);
}

void filament_color_grading_builder_tone_mapper(void* builder, void* tone_mapper) {
    if (builder == nullptr) return;
    static_cast<ColorGrading::Builder*>(builder)->toneMapper(static_cast<const ToneMapper*>(tone_mapper));
}

void filament_color_grading_builder_exposure(void* builder, float exposure) {
    if (builder == nullptr) return;
    static_cast<ColorGrading::Builder*>(builder)->exposure(exposure);
}

void filament_color_grading_builder_night_adaptation(void* builder, float adaptation) {
    if (builder == nullptr) return;
    static_cast<ColorGrading::Builder*>(builder)->nightAdaptation(adaptation);
}

void filament_color_grading_builder_white_balance(void* builder, float temperature, float tint) {
    if (builder == nullptr) return;
    static_cast<ColorGrading::Builder*>(builder)->whiteBalance(temperature, tint);
}

void filament_color_grading_builder_channel_mixer(void* builder, const float* out_red3, const float* out_green3, const float* out_blue3) {
    if (builder == nullptr || out_red3 == nullptr || out_green3 == nullptr || out_blue3 == nullptr) return;
    static_cast<ColorGrading::Builder*>(builder)->channelMixer(
        float3(out_red3[0], out_red3[1], out_red3[2]),
        float3(out_green3[0], out_green3[1], out_green3[2]),
        float3(out_blue3[0], out_blue3[1], out_blue3[2])
    );
}

void filament_color_grading_builder_shadows_midtones_highlights(void* builder, const float* shadows4, const float* midtones4, const float* highlights4, const float* ranges4) {
    if (builder == nullptr || shadows4 == nullptr || midtones4 == nullptr || highlights4 == nullptr || ranges4 == nullptr) return;
    static_cast<ColorGrading::Builder*>(builder)->shadowsMidtonesHighlights(
        float4(shadows4[0], shadows4[1], shadows4[2], shadows4[3]),
        float4(midtones4[0], midtones4[1], midtones4[2], midtones4[3]),
        float4(highlights4[0], highlights4[1], highlights4[2], highlights4[3]),
        float4(ranges4[0], ranges4[1], ranges4[2], ranges4[3])
    );
}

void filament_color_grading_builder_slope_offset_power(void* builder, const float* slope3, const float* offset3, const float* power3) {
    if (builder == nullptr || slope3 == nullptr || offset3 == nullptr || power3 == nullptr) return;
    static_cast<ColorGrading::Builder*>(builder)->slopeOffsetPower(
        float3(slope3[0], slope3[1], slope3[2]),
        float3(offset3[0], offset3[1], offset3[2]),
        float3(power3[0], power3[1], power3[2])
    );
}

void filament_color_grading_builder_contrast(void* builder, float contrast) {
    if (builder == nullptr) return;
    static_cast<ColorGrading::Builder*>(builder)->contrast(contrast);
}

void filament_color_grading_builder_vibrance(void* builder, float vibrance) {
    if (builder == nullptr) return;
    static_cast<ColorGrading::Builder*>(builder)->vibrance(vibrance);
}

void filament_color_grading_builder_saturation(void* builder, float saturation) {
    if (builder == nullptr) return;
    static_cast<ColorGrading::Builder*>(builder)->saturation(saturation);
}

void filament_color_grading_builder_curves(void* builder, const float* shadow_gamma3, const float* mid_point3, const float* highlight_scale3) {
    if (builder == nullptr || shadow_gamma3 == nullptr || mid_point3 == nullptr || highlight_scale3 == nullptr) return;
    static_cast<ColorGrading::Builder*>(builder)->curves(
        float3(shadow_gamma3[0], shadow_gamma3[1], shadow_gamma3[2]),
        float3(mid_point3[0], mid_point3[1], mid_point3[2]),
        float3(highlight_scale3[0], highlight_scale3[1], highlight_scale3[2])
    );
}

void filament_color_grading_builder_luminance_scaling(void* builder, bool enabled) {
    if (builder == nullptr) return;
    static_cast<ColorGrading::Builder*>(builder)->luminanceScaling(enabled);
}

void filament_color_grading_builder_gamut_mapping(void* builder, bool enabled) {
    if (builder == nullptr) return;
    static_cast<ColorGrading::Builder*>(builder)->gamutMapping(enabled);
}

void* filament_color_grading_builder_build(void* builder, void* engine) {
    if (builder == nullptr || engine == nullptr) return nullptr;
    auto* b = static_cast<ColorGrading::Builder*>(builder);
    auto* e = static_cast<Engine*>(engine);
    ColorGrading* cg = b->build(*e);
    delete b;
    return cg;
}

void filament_color_grading_builder_destroy(void* builder) {
    if (builder != nullptr) {
        delete static_cast<ColorGrading::Builder*>(builder);
    }
}

void filament_view_set_color_grading(void* view, void* color_grading) {
    if (view == nullptr) return;
    static_cast<View*>(view)->setColorGrading(static_cast<ColorGrading*>(color_grading));
}

void filament_engine_destroy_color_grading(void* engine, void* color_grading) {
    if (engine != nullptr && color_grading != nullptr) {
        static_cast<Engine*>(engine)->destroy(static_cast<ColorGrading*>(color_grading));
    }
}

}
