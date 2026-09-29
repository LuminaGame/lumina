/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

#ifndef FLUTTER_FILAMENT_RENDERER_C_H
#define FLUTTER_FILAMENT_RENDERER_C_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

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

// ==========================================
// Clear Options
// ==========================================
typedef struct filament_clear_options_t {
    float   clear_color[4];   // ClearOptions::clearColor (linear)
    uint8_t clear_stencil;    // ClearOptions::clearStencil
    bool    clear;            // ClearOptions::clear
    bool    discard;          // ClearOptions::discard
} filament_clear_options_t;

FFI_PLUGIN_EXPORT void filament_renderer_set_clear_options_ex(void* renderer, const filament_clear_options_t* opts);
FFI_PLUGIN_EXPORT void filament_renderer_get_clear_options(void* renderer, filament_clear_options_t* out);
FFI_PLUGIN_EXPORT void filament_renderer_set_clear_options(
    void* renderer, float r, float g, float b, float a, bool clear, bool discard);

// ==========================================
// Frame Lifecycle & Execution
// ==========================================
FFI_PLUGIN_EXPORT bool filament_renderer_begin_frame(void* renderer, void* swap_chain, uint64_t vsync_ns);
FFI_PLUGIN_EXPORT void filament_renderer_render(void* renderer, void* view);
FFI_PLUGIN_EXPORT void filament_renderer_end_frame(void* renderer);

// ==========================================
// Display & Frame Rate Options
// ==========================================
FFI_PLUGIN_EXPORT void filament_renderer_set_display_info(void* renderer, float refresh_rate);
FFI_PLUGIN_EXPORT void filament_renderer_set_frame_rate_options(void* renderer,
    float head_room_ratio, float scale_rate, uint8_t history, uint8_t interval);

// ==========================================
// Frame Info & History
// ==========================================
typedef struct filament_frame_info_t {
    uint32_t frame_id;
    int64_t  gpu_frame_duration;
    int64_t  denoised_gpu_frame_duration;
    int64_t  begin_frame;
    int64_t  end_frame;
    int64_t  backend_begin_frame;
    int64_t  backend_end_frame;
    int64_t  gpu_frame_complete;
    int64_t  vsync;
    int64_t  display_present;
    int64_t  present_deadline;
    int64_t  display_present_interval;
    int64_t  composition_to_present_latency;
    int64_t  expected_present_latency;
    int64_t  frame_schedule_time;
} filament_frame_info_t;

FFI_PLUGIN_EXPORT uint32_t filament_renderer_get_frame_info_history(void* renderer,
    filament_frame_info_t* out, uint32_t capacity);
FFI_PLUGIN_EXPORT uint32_t filament_renderer_get_max_frame_history_size(void* renderer);
FFI_PLUGIN_EXPORT int64_t filament_frame_info_invalid_sentinel(void);
FFI_PLUGIN_EXPORT int64_t filament_frame_info_pending_sentinel(void);

// ==========================================
// Standalone View & Read Pixels
// ==========================================
typedef void (*FilamentReadPixelsCallback)(void* buffer, void* user_data);

FFI_PLUGIN_EXPORT void filament_renderer_render_standalone_view(void* renderer, void* view);
FFI_PLUGIN_EXPORT void filament_renderer_read_pixels(
    void *renderer, void *engine, uint32_t x, uint32_t y, uint32_t width,
    uint32_t height, uint8_t *out_buffer, FilamentReadPixelsCallback callback, void* user_data);
FFI_PLUGIN_EXPORT void filament_renderer_read_pixels_render_target(
    void* renderer, void* render_target, uint32_t x, uint32_t y, uint32_t width, uint32_t height,
    int pixel_format, int pixel_type, void* buffer, uint32_t buffer_size_bytes,
    FilamentReadPixelsCallback callback, void* user_data);

// ==========================================
// Presentation Time, Frame Skipping & Material Time
// ==========================================
FFI_PLUGIN_EXPORT void filament_renderer_set_vsync_time(void* renderer, uint64_t steady_clock_ns);
FFI_PLUGIN_EXPORT void filament_renderer_set_presentation_time(void* renderer, int64_t monotonic_clock_ns);
FFI_PLUGIN_EXPORT void filament_renderer_set_desired_presentation_time(void* renderer, int64_t ns);
FFI_PLUGIN_EXPORT void filament_renderer_set_rendering_deadline(void* renderer, int64_t deadline_ns);
FFI_PLUGIN_EXPORT void filament_renderer_set_frame_schedule_time(void* renderer, uint64_t ns);
FFI_PLUGIN_EXPORT void filament_renderer_skip_frame(void* renderer, uint64_t vsync_steady_clock_ns);
FFI_PLUGIN_EXPORT bool filament_renderer_should_render_frame(void* renderer);
FFI_PLUGIN_EXPORT bool filament_renderer_has_gpu_fallen_behind(void* renderer);
FFI_PLUGIN_EXPORT double filament_renderer_get_material_time(void* renderer);
FFI_PLUGIN_EXPORT void filament_renderer_set_material_time_epoch(void* renderer, int64_t epoch_steady_ns);
FFI_PLUGIN_EXPORT void filament_renderer_skip_next_frames(void* renderer, size_t frame_count);
FFI_PLUGIN_EXPORT size_t filament_renderer_get_frame_to_skip_count(void* renderer);
FFI_PLUGIN_EXPORT void filament_renderer_pause_render_thread(void* renderer, uint64_t duration_ns);

#ifdef __cplusplus
}
#endif

#endif // FLUTTER_FILAMENT_RENDERER_C_H
