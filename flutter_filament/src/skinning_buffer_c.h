#ifndef SKINNING_BUFFER_C_H
#define SKINNING_BUFFER_C_H

#include <stdint.h>
#include <stdbool.h>
#if _WIN32
#define FFI_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FFI_PLUGIN_EXPORT
#endif
#include "geometry_c.h"

#ifdef __cplusplus
extern "C" {
#endif

FFI_PLUGIN_EXPORT void* filament_skinning_buffer_create(void* engine, uint32_t bone_count, bool initialize);
FFI_PLUGIN_EXPORT void filament_skinning_buffer_set_bones(void* engine, void* skinning_buffer, const FilamentBone* bones, uint32_t count, uint32_t offset);
FFI_PLUGIN_EXPORT void filament_skinning_buffer_set_bones_matrices(void* engine, void* skinning_buffer, const float* transforms, uint32_t count, uint32_t offset);
FFI_PLUGIN_EXPORT uint32_t filament_skinning_buffer_get_bone_count(void* skinning_buffer);
FFI_PLUGIN_EXPORT void filament_engine_destroy_skinning_buffer(void* engine, void* skinning_buffer);

#ifdef __cplusplus
}
#endif

#endif // SKINNING_BUFFER_C_H
