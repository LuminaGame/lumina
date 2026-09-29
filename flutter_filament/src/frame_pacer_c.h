/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

#ifndef FLUTTER_FILAMENT_FRAME_PACER_C_H
#define FLUTTER_FILAMENT_FRAME_PACER_C_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#ifndef FFI_PLUGIN_EXPORT
#if _WIN32
#define FFI_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FFI_PLUGIN_EXPORT
#endif
#endif

#ifdef __cplusplus
extern "C" {
#endif

typedef struct filament_frame_pacer_config_t {
    float    target_frame_rate;
    int64_t  latency_ns;
} filament_frame_pacer_config_t;

typedef struct filament_hardware_timeline_t {
    int64_t  expected_presentation_time_ns;
    int64_t  deadline_ns;
} filament_hardware_timeline_t;

typedef struct filament_vsync_tick_t {
    int64_t  base_time_ns;
    int64_t  vsync_period_ns;
    int64_t  frame_schedule_time_ns;
    const filament_hardware_timeline_t* timelines;
    uint32_t timeline_count;
} filament_vsync_tick_t;

FFI_PLUGIN_EXPORT void*    filament_frame_pacer_create(void* engine, const filament_frame_pacer_config_t* config);
FFI_PLUGIN_EXPORT void     filament_engine_destroy_frame_pacer(void* engine, void* pacer);
FFI_PLUGIN_EXPORT void     filament_frame_pacer_configure(void* pacer, const filament_frame_pacer_config_t* config);
FFI_PLUGIN_EXPORT void     filament_frame_pacer_get_configuration(void* pacer, filament_frame_pacer_config_t* out_config);
FFI_PLUGIN_EXPORT int8_t   filament_frame_pacer_setup_frame(void* pacer, const filament_vsync_tick_t* tick);
FFI_PLUGIN_EXPORT bool     filament_frame_pacer_setup_extra_frame(void* pacer);
FFI_PLUGIN_EXPORT bool     filament_frame_pacer_has_gpu_fallen_behind(void* pacer, void* renderer);
FFI_PLUGIN_EXPORT void     filament_frame_pacer_apply_presentation_time(void* pacer, void* renderer);
FFI_PLUGIN_EXPORT void     filament_frame_pacer_reset_pacing(void* pacer);
FFI_PLUGIN_EXPORT int64_t  filament_frame_pacer_get_expected_presentation_time(void* pacer);
FFI_PLUGIN_EXPORT int64_t  filament_frame_pacer_get_rendering_deadline(void* pacer);
FFI_PLUGIN_EXPORT int64_t  filament_frame_pacer_get_effective_latency(void* pacer);
FFI_PLUGIN_EXPORT int8_t   filament_frame_pacer_get_pacing_status(void* pacer);
FFI_PLUGIN_EXPORT float    filament_frame_pacer_get_selected_frame_rate(void* pacer);
FFI_PLUGIN_EXPORT bool     filament_frame_pacer_is_exact_frame_rate_achieved(void* pacer);

#ifdef __cplusplus
}
#endif

#endif // FLUTTER_FILAMENT_FRAME_PACER_C_H
