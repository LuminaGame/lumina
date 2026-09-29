/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

#ifndef FLUTTER_FILAMENT_WEB_C_H
#define FLUTTER_FILAMENT_WEB_C_H

#include <stdint.h>

#if _WIN32
#define FFI_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FFI_PLUGIN_EXPORT
#endif

#ifdef __cplusplus
extern "C" {
#endif

// Web builds: an engine bound to an HTML canvas.
//
// Creates a WebGL2 context on the canvas matched by [canvas_selector]
// (a CSS selector such as "#game"), makes it current and creates an OpenGL
// engine on it — what filament-js's Engine._create does. The Emscripten
// context handle is written to [out_context] for
// filament_web_destroy_canvas_context. The engine's swap chain is
// filament_engine_create_swap_chain(engine, NULL, 0): WebGL presents to the
// canvas's default framebuffer.
//
// Native builds have no canvas: returns NULL and logs why.
FFI_PLUGIN_EXPORT void* filament_engine_create_for_canvas(const char* canvas_selector,
                                                          int32_t* out_context);

// Destroys a context from filament_engine_create_for_canvas, after its engine.
// A no-op in native builds.
FFI_PLUGIN_EXPORT void filament_web_destroy_canvas_context(int32_t context);

#ifdef __cplusplus
}
#endif

#endif  // FLUTTER_FILAMENT_WEB_C_H
