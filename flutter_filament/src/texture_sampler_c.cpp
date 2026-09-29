/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

#include "texture_sampler_c.h"

#include <filament/TextureSampler.h>
#include <backend/DriverEnums.h>
#include <cstring>
#include <cmath>

using namespace filament;

uint32_t filament_test_sampler_params_pack(
    uint8_t min_filter,
    uint8_t mag_filter,
    uint8_t wrap_s,
    uint8_t wrap_t,
    uint8_t wrap_r,
    float anisotropy,
    uint8_t compare_mode,
    uint8_t compare_func
) {
    TextureSampler sampler(
        static_cast<backend::SamplerMinFilter>(min_filter),
        static_cast<backend::SamplerMagFilter>(mag_filter),
        static_cast<backend::SamplerWrapMode>(wrap_s),
        static_cast<backend::SamplerWrapMode>(wrap_t),
        static_cast<backend::SamplerWrapMode>(wrap_r)
    );
    sampler.setAnisotropy(anisotropy);
    sampler.setCompareMode(
        static_cast<backend::SamplerCompareMode>(compare_mode),
        static_cast<backend::SamplerCompareFunc>(compare_func)
    );

    auto params = sampler.getSamplerParams();
    static_assert(sizeof(backend::SamplerParams) == 4, "SamplerParams must be 4 bytes");
    uint32_t packed = 0;
    std::memcpy(&packed, &params, sizeof(uint32_t));
    return packed;
}

uint32_t filament_test_sampler_params_default(void) {
    TextureSampler sampler;
    auto params = sampler.getSamplerParams();
    static_assert(sizeof(backend::SamplerParams) == 4, "SamplerParams must be 4 bytes");
    uint32_t packed = 0;
    std::memcpy(&packed, &params, sizeof(uint32_t));
    return packed;
}
