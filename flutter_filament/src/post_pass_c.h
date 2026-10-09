/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

#ifndef FLUTTER_FILAMENT_POST_PASS_C_H
#define FLUTTER_FILAMENT_POST_PASS_C_H

#include <stdbool.h>
#include <stdint.h>

#if _WIN32
#define FFI_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FFI_PLUGIN_EXPORT
#endif

#ifdef __cplusplus
extern "C" {
#endif

// A debug external post pass (Filament's View::setExternalPostPass, Vulkan only): a small
// compute shader that rewrites the HDR frame before bloom and colour grading, showing what
// the hook hands to a neural pass. Other backends and the web report "not available".

typedef enum filament_post_pass_debug_mode {
    FILAMENT_POST_PASS_DEBUG_PASSTHROUGH = 0,   // copies the colour unchanged
    FILAMENT_POST_PASS_DEBUG_MOTION = 1,        // |motion| in red/green over the dimmed colour
    FILAMENT_POST_PASS_DEBUG_HISTORY = 2,       // green where history is usable, red where not
    FILAMENT_POST_PASS_DEBUG_INVERT = 3         // max(0, 1 - colour)
} filament_post_pass_debug_mode;

// Registers the debug pass on the view. Returns NULL with filament_post_pass_last_error() set
// when the engine is not on the desktop Vulkan backend.
FFI_PLUGIN_EXPORT void* filament_post_pass_debug_create(void* engine, void* view, uint8_t mode);

// Changes the mode; takes effect at the next frame.
FFI_PLUGIN_EXPORT void filament_post_pass_debug_set_mode(void* pass, uint8_t mode);

// Frames the pass evaluated so far.
FFI_PLUGIN_EXPORT uint64_t filament_post_pass_debug_frame_count(void* pass);

// The size of the colour image the last evaluation received (0, 0 before the first one).
FFI_PLUGIN_EXPORT void filament_post_pass_debug_last_size(void* pass, uint32_t* out_w, uint32_t* out_h);

// Forgets the motion history (camera cuts): the next frame reports no usable history.
FFI_PLUGIN_EXPORT void filament_view_reset_external_post_pass_history(void* view);

// Unregisters the pass from its view and releases its Vulkan objects. Safe with NULL.
FFI_PLUGIN_EXPORT void filament_post_pass_debug_destroy(void* pass);

// The last error (process-wide), or NULL.
FFI_PLUGIN_EXPORT const char* filament_post_pass_last_error(void);

#ifdef __cplusplus
}
#endif

#endif // FLUTTER_FILAMENT_POST_PASS_C_H
