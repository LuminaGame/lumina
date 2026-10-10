/*
 * Copyright 2026 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

#ifndef FLUTTER_FILAMENT_UI_OVERLAY_C_H
#define FLUTTER_FILAMENT_UI_OVERLAY_C_H

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

// A UI overlay for direct presentation: a translucent View (post-processing
// off) with one screen-covering quad that blends a premultiplied RGBA8
// picture over what the SwapChain already holds. Rendered after the main
// View in the same frame, it is drawn after tone mapping and the upscaler,
// and redrawn on every frame-generation present.

// Creates the overlay's material, quad, scene, camera and View. Null on failure.
FFI_PLUGIN_EXPORT void* filament_ui_overlay_create(void* engine);
FFI_PLUGIN_EXPORT void filament_ui_overlay_destroy(void* overlay);

// The overlay's area of the SwapChain, in pixels (origin bottom-left).
FFI_PLUGIN_EXPORT void filament_ui_overlay_set_viewport(
    void* overlay, int32_t left, int32_t bottom, uint32_t width, uint32_t height);

// Copies premultiplied RGBA8 pixels (rows top to bottom, [stride] bytes per
// row, 0 = width * 4) into the overlay's texture, recreating it on a size
// change. False on bad arguments.
FFI_PLUGIN_EXPORT bool filament_ui_overlay_upload(
    void* overlay, const uint8_t* rgba, uint32_t width, uint32_t height, uint32_t stride);

// The same without the extra copy: begin returns a buffer of width * height * 4
// bytes the caller fills (premultiplied RGBA8, rows top to bottom), end hands
// it to the texture (and frees it once the GPU has it). Null / false on bad
// arguments; a begin without an end is freed by the next begin or destroy.
FFI_PLUGIN_EXPORT uint8_t* filament_ui_overlay_begin_upload(void* overlay, uint32_t width, uint32_t height);
FFI_PLUGIN_EXPORT bool filament_ui_overlay_end_upload(void* overlay);

// Forgets the picture: render() draws nothing until the next upload.
FFI_PLUGIN_EXPORT void filament_ui_overlay_clear(void* overlay);
FFI_PLUGIN_EXPORT bool filament_ui_overlay_has_content(void* overlay);

// Renderer::render(the overlay's View) when it has a picture; whether it drew.
// Call between beginFrame and endFrame, after the Views it covers.
FFI_PLUGIN_EXPORT bool filament_ui_overlay_render(void* renderer, void* overlay);

// The overlay's View (owned by the overlay).
FFI_PLUGIN_EXPORT void* filament_ui_overlay_get_view(void* overlay);

// Microseconds the last upload took on the calling thread (the copy and the
// texture command), and the uploads so far.
FFI_PLUGIN_EXPORT uint64_t filament_ui_overlay_last_upload_micros(void* overlay);
FFI_PLUGIN_EXPORT uint64_t filament_ui_overlay_upload_count(void* overlay);

#ifdef __cplusplus
}
#endif

#endif // FLUTTER_FILAMENT_UI_OVERLAY_C_H
