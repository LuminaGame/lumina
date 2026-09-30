/*
 * Copyright 2026 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

#ifndef FLUTTER_FILAMENT_MATC_C_H
#define FLUTTER_FILAMENT_MATC_C_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#if _WIN32
#define FFI_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FFI_PLUGIN_EXPORT
#endif

#ifdef __cplusplus
extern "C" {
#endif

/// Compiles a whole Filament material definition (`.mat`: a `material { … }` header, `vertex { … }`,
/// `fragment { … }` / `compute { … }` blocks) the way Filament's `matc` does: `#include` resolution, Filament's
/// own .mat parser (matp) driving `filamat::MaterialBuilder`, then `build()`.
///
/// `source`/`length`: the .mat text (need not be NUL-terminated).
/// `file_name`: the name `#line` directives use for the material itself (NULL: none).
/// `include_dir`: the directory `#include "…"` resolves against (NULL: an `#include` is an error).
/// `default_name`: the material's name when its header has no `name` (NULL: none).
/// `platform` (MaterialBuilder::Platform), `target_api` (TargetApi bit mask), `optimization`
/// (MaterialBuilder::Optimization): a negative value keeps matc's default (ALL, OpenGL, PERFORMANCE).
/// `debug`: keep debug information in the shaders (matc -g). `variant_filter`: UserVariantFilterMask bits.
///
/// Returns a malloc'ed package (NULL when the material does not compile) and its size in `out_size`, and always
/// sets `*out_diagnostics` (when non-NULL) to a malloc'ed, NUL-terminated copy of everything matc would have
/// printed for this compile, in order. Free both with `filament_matc_free`. Desktop only: the web build returns
/// NULL.
FFI_PLUGIN_EXPORT void* filament_matc_compile(const char* source, size_t length, const char* file_name,
        const char* include_dir, const char* default_name, int platform, int target_api, int optimization,
        bool debug, uint32_t variant_filter, size_t* out_size, char** out_diagnostics);

/// Frees a package or diagnostics string returned by `filament_matc_compile`.
FFI_PLUGIN_EXPORT void filament_matc_free(void* pointer);

#ifdef __cplusplus
}
#endif

#endif // FLUTTER_FILAMENT_MATC_C_H
