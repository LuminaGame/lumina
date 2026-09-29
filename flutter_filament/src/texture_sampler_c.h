/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

#ifndef FLUTTER_FILAMENT_TEXTURE_SAMPLER_C_H
#define FLUTTER_FILAMENT_TEXTURE_SAMPLER_C_H

#include <stdint.h>
#include <stddef.h>

#if _WIN32
#define FFI_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FFI_PLUGIN_EXPORT
#endif

#ifdef __cplusplus
extern "C" {
#endif

FFI_PLUGIN_EXPORT uint32_t filament_test_sampler_params_pack(
    uint8_t min_filter,
    uint8_t mag_filter,
    uint8_t wrap_s,
    uint8_t wrap_t,
    uint8_t wrap_r,
    float anisotropy,
    uint8_t compare_mode,
    uint8_t compare_func
);

FFI_PLUGIN_EXPORT uint32_t filament_test_sampler_params_default(void);

#ifdef __cplusplus
}
#endif

#endif // FLUTTER_FILAMENT_TEXTURE_SAMPLER_C_H
