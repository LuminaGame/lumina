/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

#ifndef FLUTTER_FILAMENT_FILAMESH_C_H
#define FLUTTER_FILAMENT_FILAMESH_C_H

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

typedef struct FilMaterialRegistry FilMaterialRegistry;

typedef struct {
    uint32_t entity;
    void* vertex_buffer;
    void* index_buffer;
} FilFilamesh;

// MaterialRegistry
FFI_PLUGIN_EXPORT FilMaterialRegistry* filament_material_registry_create(void);
FFI_PLUGIN_EXPORT void filament_material_registry_destroy(FilMaterialRegistry* r);
FFI_PLUGIN_EXPORT void filament_material_registry_register(FilMaterialRegistry* r, const char* name, void* mi);
FFI_PLUGIN_EXPORT void* filament_material_registry_get(const FilMaterialRegistry* r, const char* name);
FFI_PLUGIN_EXPORT void filament_material_registry_unregister(FilMaterialRegistry* r, const char* name);
FFI_PLUGIN_EXPORT size_t filament_material_registry_num_registered(const FilMaterialRegistry* r);
FFI_PLUGIN_EXPORT const char* filament_material_registry_get_name_at(const FilMaterialRegistry* r, size_t index);

// Filamesh loader and lifecycle
FFI_PLUGIN_EXPORT bool filament_filamesh_load_with_registry(
    void* engine,
    const uint8_t* data,
    size_t size,
    FilMaterialRegistry* registry,
    FilFilamesh* out
);

FFI_PLUGIN_EXPORT void filament_filamesh_destroy(void* engine, FilFilamesh* mesh);

#ifdef __cplusplus
}
#endif

#endif // FLUTTER_FILAMENT_FILAMESH_C_H
