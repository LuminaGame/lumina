#ifndef INSTANCE_BUFFER_C_H
#define INSTANCE_BUFFER_C_H

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

FFI_PLUGIN_EXPORT void* filament_instance_buffer_create(void* engine, uint32_t instance_count, const float* initial_transforms);
FFI_PLUGIN_EXPORT void filament_instance_buffer_set_local_transforms(void* instance_buffer, const float* transforms, uint32_t count, uint32_t offset);
FFI_PLUGIN_EXPORT void filament_instance_buffer_get_local_transform(void* instance_buffer, uint32_t index, float* out_matrix);
FFI_PLUGIN_EXPORT uint32_t filament_instance_buffer_get_instance_count(void* instance_buffer);

#ifdef __cplusplus
}
#endif

#endif // INSTANCE_BUFFER_C_H
