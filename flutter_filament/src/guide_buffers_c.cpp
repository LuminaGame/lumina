/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

#include "guide_buffers_c.h"

#if !defined(__EMSCRIPTEN__)

#include <filament/Options.h>
#include <filament/Texture.h>
#include <filament/View.h>

using namespace filament;

void filament_view_set_guide_buffer_options(void* view, const filament_guide_buffer_options_t* options) {
    if (!view || !options) return;
    GuideBufferOptions o;
    o.enabled = options->enabled;
    o.specularHitDistance = options->specularHitDistance;
    static_cast<View*>(view)->setGuideBufferOptions(o);
}

void filament_view_get_guide_buffer_options(void* view, filament_guide_buffer_options_t* out) {
    if (!out) return;
    *out = filament_guide_buffer_options_t{ false, true };
    if (!view) return;
    GuideBufferOptions const& o = static_cast<View*>(view)->getGuideBufferOptions();
    out->enabled = o.enabled;
    out->specularHitDistance = o.specularHitDistance;
}

void filament_view_set_guide_buffer_texture(void* view, uint8_t which, void* texture) {
    if (!view || which > FILAMENT_GUIDE_SPECULAR_HIT_DISTANCE) return;
    static_cast<View*>(view)->setGuideBufferTexture(GuideBuffer(which), static_cast<Texture*>(texture));
}

#else // __EMSCRIPTEN__: the WebGL build has no guide buffers; keep the options for round trips.

#include <unordered_map>

namespace {
std::unordered_map<void*, filament_guide_buffer_options_t> gWebOptions;
}

void filament_view_set_guide_buffer_options(void* view, const filament_guide_buffer_options_t* options) {
    if (view && options) gWebOptions[view] = *options;
}

void filament_view_get_guide_buffer_options(void* view, filament_guide_buffer_options_t* out) {
    if (!out) return;
    auto it = gWebOptions.find(view);
    *out = it != gWebOptions.end() ? it->second : filament_guide_buffer_options_t{ false, true };
}

void filament_view_set_guide_buffer_texture(void* view, uint8_t which, void* texture) {
    (void) view;
    (void) which;
    (void) texture;
}

#endif
