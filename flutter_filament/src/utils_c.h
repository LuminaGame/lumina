#pragma once

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// Defined in macros_c.h or filament_c.h
#ifndef FFI_PLUGIN_EXPORT
#if defined(_WIN32)
#define FFI_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FFI_PLUGIN_EXPORT __attribute__((visibility("default"))) __attribute__((used))
#endif
#endif

typedef void (*FilamentPanicHandler)(const char* function, const char* file, int line, const char* message, void* user_data);
typedef void (*FilamentLogHandler)(int priority, const char* tag, const char* message, void* user_data);

FFI_PLUGIN_EXPORT void filament_set_panic_handler(FilamentPanicHandler handler, void* user_data);
FFI_PLUGIN_EXPORT void filament_clear_panic_handler(void);
FFI_PLUGIN_EXPORT bool filament_get_last_panic(char* out_message, size_t max_len);

FFI_PLUGIN_EXPORT void filament_set_log_callback(FilamentLogHandler handler, void* user_data);
FFI_PLUGIN_EXPORT void filament_clear_log_callback(void);

// Test Triggers
FFI_PLUGIN_EXPORT void filament_test_trigger_panic(void);
FFI_PLUGIN_EXPORT void filament_test_log(const char* msg);

// Memory management for async callbacks
FFI_PLUGIN_EXPORT void filament_free_string(char* str);

// NameComponentManager
FFI_PLUGIN_EXPORT void* filament_name_component_manager_create(void);
FFI_PLUGIN_EXPORT void filament_name_component_manager_destroy(void* ncm);
FFI_PLUGIN_EXPORT void filament_name_component_manager_add_component(void* ncm, uint32_t entity);
FFI_PLUGIN_EXPORT void filament_name_component_manager_remove_component(void* ncm, uint32_t entity);
FFI_PLUGIN_EXPORT int32_t filament_name_component_manager_get_instance(void* ncm, uint32_t entity);
FFI_PLUGIN_EXPORT void filament_name_component_manager_set_name(void* ncm, uint32_t entity, const char* name);
FFI_PLUGIN_EXPORT const char* filament_name_component_manager_get_name(void* ncm, uint32_t entity);
FFI_PLUGIN_EXPORT void filament_name_component_manager_gc(void* ncm);

// EntityManager destruction listener
typedef void (*FilamentEntityDestructionCallback)(const uint32_t* entities, size_t count, void* user_data);

FFI_PLUGIN_EXPORT void* filament_entity_manager_register_destruction_callback(FilamentEntityDestructionCallback callback, void* user_data);
FFI_PLUGIN_EXPORT void filament_entity_manager_unregister_destruction_callback(void* registration);

#ifdef __cplusplus
}
#endif
