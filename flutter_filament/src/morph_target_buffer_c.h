#ifndef MORPH_TARGET_BUFFER_C_H
#define MORPH_TARGET_BUFFER_C_H

#include <stdint.h>
#include <stdbool.h>
#if _WIN32
#define FFI_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FFI_PLUGIN_EXPORT
#endif

#ifdef __cplusplus
extern "C" {
#endif

FFI_PLUGIN_EXPORT void* filament_morph_target_buffer_create(void* engine, uint32_t vertex_count, uint32_t target_count, bool with_positions, bool with_tangents, bool custom_morphing);
FFI_PLUGIN_EXPORT void filament_morph_target_buffer_set_positions_at_float3(void* engine, void* mtb, uint32_t target_index, const float* positions, uint32_t count, uint32_t offset);
FFI_PLUGIN_EXPORT void filament_morph_target_buffer_set_positions_at_float4(void* engine, void* mtb, uint32_t target_index, const float* positions, uint32_t count, uint32_t offset);
FFI_PLUGIN_EXPORT void filament_morph_target_buffer_set_tangents_at(void* engine, void* mtb, uint32_t target_index, const int16_t* tangents, uint32_t count, uint32_t offset);
FFI_PLUGIN_EXPORT uint32_t filament_morph_target_buffer_get_vertex_count(void* mtb);
FFI_PLUGIN_EXPORT uint32_t filament_morph_target_buffer_get_count(void* mtb);
FFI_PLUGIN_EXPORT bool filament_morph_target_buffer_has_positions(void* mtb);
FFI_PLUGIN_EXPORT bool filament_morph_target_buffer_has_tangents(void* mtb);
FFI_PLUGIN_EXPORT bool filament_morph_target_buffer_is_custom_morphing_enabled(void* mtb);

#ifdef __cplusplus
}
#endif

#endif // MORPH_TARGET_BUFFER_C_H
