/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

#include "web_c.h"

#include <filament/Engine.h>
#include <utils/Panic.h>

#include <cstdio>
#include <exception>

#ifdef __EMSCRIPTEN__
#include <emscripten/html5.h>
#endif

using namespace filament;

void* filament_engine_create_for_canvas(const char* canvas_selector, int32_t* out_context) {
  if (out_context) *out_context = 0;
#ifdef __EMSCRIPTEN__
  try {
    EmscriptenWebGLContextAttributes attrs;
    emscripten_webgl_init_context_attributes(&attrs);
    attrs.majorVersion = 2;
    attrs.minorVersion = 0;
    attrs.alpha = false;
    attrs.antialias = false;
    attrs.depth = true;
    attrs.stencil = true;
    attrs.premultipliedAlpha = false;
    // Filament reads back and presents from the default framebuffer.
    attrs.preserveDrawingBuffer = false;
    const EMSCRIPTEN_WEBGL_CONTEXT_HANDLE context =
        emscripten_webgl_create_context(canvas_selector, &attrs);
    if (context <= 0) {
      fprintf(stderr, "[flutter_filament] no WebGL2 context on canvas '%s' (error %d)\n",
              canvas_selector ? canvas_selector : "(null)", static_cast<int>(context));
      return nullptr;
    }
    if (emscripten_webgl_make_context_current(context) != EMSCRIPTEN_RESULT_SUCCESS) {
      emscripten_webgl_destroy_context(context);
      fprintf(stderr, "[flutter_filament] could not make the WebGL2 context current\n");
      return nullptr;
    }
    Engine* engine = Engine::create(Engine::Backend::OPENGL);
    if (!engine) {
      emscripten_webgl_destroy_context(context);
      return nullptr;
    }
    if (out_context) *out_context = static_cast<int32_t>(context);
    return engine;
  } catch (const utils::Panic& e) {
    fprintf(stderr, "[Filament C++ Panic (Handled Safely)]: %s\n", e.what());
    return nullptr;
  } catch (const std::exception& e) {
    fprintf(stderr, "[Filament C++ Exception (Handled Safely)]: %s\n", e.what());
    return nullptr;
  }
#else
  (void) canvas_selector;
  fprintf(stderr, "[flutter_filament] filament_engine_create_for_canvas exists only in web builds\n");
  return nullptr;
#endif
}

void filament_web_destroy_canvas_context(int32_t context) {
#ifdef __EMSCRIPTEN__
  if (context > 0) emscripten_webgl_destroy_context(static_cast<EMSCRIPTEN_WEBGL_CONTEXT_HANDLE>(context));
#else
  (void) context;
#endif
}
