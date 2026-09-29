/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

#include <atomic>
#include <cstring>
#include "filamesh_c.h"

#include <filament/Engine.h>
#include <filament/VertexBuffer.h>
#include <filament/IndexBuffer.h>
#include <filament/MaterialInstance.h>
#include <filament/RenderableManager.h>
#include <filameshio/MeshReader.h>
#include <utils/Entity.h>
#include <utils/EntityManager.h>
#include <utils/CString.h>
#include <utils/Panic.h>
#include <cstdio>
#include <exception>
#include <vector>
#include <string>

using namespace filament;
using namespace filamesh;
using namespace utils;

#define FFI_TRY try {
#define FFI_CATCH(return_value) \
} catch (const utils::Panic& e) { \
    fprintf(stderr, "[Filamesh C++ Panic (Handled Safely)]: %s\n", e.what()); \
    return return_value; \
} catch (const std::exception& e) { \
    fprintf(stderr, "[Filamesh C++ Exception (Handled Safely)]: %s\n", e.what()); \
    return return_value; \
} catch (...) { \
    fprintf(stderr, "[Filamesh C++ Unknown Exception (Handled Safely)]\n"); \
    return return_value; \
}

static inline Engine* toEngine(void* p) { return reinterpret_cast<Engine*>(p); }
static inline MaterialInstance* toMaterialInstance(void* p) { return reinterpret_cast<MaterialInstance*>(p); }

struct FilMaterialRegistry {
    MeshReader::MaterialRegistry registry;
    std::vector<std::string> cachedNames;
};

FilMaterialRegistry* filament_material_registry_create(void) {
    FFI_TRY
    return new FilMaterialRegistry();
    FFI_CATCH(nullptr)
}

void filament_material_registry_destroy(FilMaterialRegistry* r) {
    FFI_TRY
    if (r) {
        delete r;
    }
    FFI_CATCH()
}

void filament_material_registry_register(FilMaterialRegistry* r, const char* name, void* mi) {
    FFI_TRY
    if (!r || !name || !mi) return;
    r->registry.registerMaterialInstance(CString(name), toMaterialInstance(mi));
    FFI_CATCH()
}

void* filament_material_registry_get(const FilMaterialRegistry* r, const char* name) {
    FFI_TRY
    if (!r || !name) return nullptr;
    return const_cast<FilMaterialRegistry*>(r)->registry.getMaterialInstance(CString(name));
    FFI_CATCH(nullptr)
}

void filament_material_registry_unregister(FilMaterialRegistry* r, const char* name) {
    FFI_TRY
    if (!r || !name) return;
    r->registry.unregisterMaterialInstance(CString(name));
    FFI_CATCH()
}

size_t filament_material_registry_num_registered(const FilMaterialRegistry* r) {
    FFI_TRY
    if (!r) return 0;
    return r->registry.numRegistered();
    FFI_CATCH(0)
}

const char* filament_material_registry_get_name_at(const FilMaterialRegistry* r, size_t index) {
    FFI_TRY
    if (!r) return nullptr;
    auto* nonConst = const_cast<FilMaterialRegistry*>(r);
    size_t count = nonConst->registry.numRegistered();
    if (index >= count) return nullptr;
    
    std::vector<CString> names(count);
    nonConst->registry.getRegisteredMaterialNames(names.data());
    
    nonConst->cachedNames.resize(count);
    for (size_t i = 0; i < count; ++i) {
        nonConst->cachedNames[i] = names[i].c_str();
    }
    return nonConst->cachedNames[index].c_str();
    FFI_CATCH(nullptr)
}

bool filament_filamesh_load_with_registry(
    void* engine,
    const uint8_t* data,
    size_t size,
    FilMaterialRegistry* registry,
    FilFilamesh* out
) {
    FFI_TRY
    if (!engine || !data || size == 0 || !out) return false;
    
    // MeshReader builds BufferDescriptors that point INTO the buffer and only
    // releases them (via the destructor) once the driver thread has uploaded
    // the data. The caller frees `data` as soon as we return, so hand Filament
    // its own heap copy and let the destructor delete it.
    // MeshReader hands the same user pointer to two descriptors (indices and
    // vertices) and invokes the destructor once for each, so the copy is
    // reference counted and freed after the second call.
    struct OwnedMeshBuffer {
        uint8_t* bytes;
        std::atomic<int> pending;
    };
    auto* owned = new OwnedMeshBuffer{new uint8_t[size], 2};
    std::memcpy(owned->bytes, data, size);
    auto destructor = [](void* /*buffer*/, size_t /*bytes*/, void* user) {
        auto* o = static_cast<OwnedMeshBuffer*>(user);
        if (o->pending.fetch_sub(1) == 1) {
            delete[] o->bytes;
            delete o;
        }
    };

    MeshReader::Mesh mesh;
    if (registry) {
        mesh = MeshReader::loadMeshFromBuffer(
            toEngine(engine),
            owned->bytes,
            size,
            destructor,
            owned,
            registry->registry
        );
    } else {
        mesh = MeshReader::loadMeshFromBuffer(
            toEngine(engine),
            owned->bytes,
            size,
            destructor,
            owned,
            static_cast<MaterialInstance*>(nullptr)
        );
    }
    
    if (!mesh.renderable.getId() || !mesh.vertexBuffer || !mesh.indexBuffer) {
        return false;
    }
    
    out->entity = static_cast<uint32_t>(mesh.renderable.getId());
    out->vertex_buffer = mesh.vertexBuffer;
    out->index_buffer = mesh.indexBuffer;
    return true;
    FFI_CATCH(false)
}

void filament_filamesh_destroy(void* engine, FilFilamesh* mesh) {
    FFI_TRY
    if (!engine || !mesh) return;
    auto* e = toEngine(engine);
    if (mesh->entity != 0) {
        auto entity = Entity::import(static_cast<int>(mesh->entity));
        auto& rm = e->getRenderableManager();
        if (rm.hasComponent(entity)) {
            rm.destroy(entity);
        }
        EntityManager::get().destroy(entity);
        mesh->entity = 0;
    }
    if (mesh->vertex_buffer) {
        e->destroy(reinterpret_cast<VertexBuffer*>(mesh->vertex_buffer));
        mesh->vertex_buffer = nullptr;
    }
    if (mesh->index_buffer) {
        e->destroy(reinterpret_cast<IndexBuffer*>(mesh->index_buffer));
        mesh->index_buffer = nullptr;
    }
    FFI_CATCH()
}
