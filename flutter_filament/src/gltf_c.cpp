/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

#include "gltf_c.h"

#include <filament/Engine.h>
#include <filament/Scene.h>

#include <gltfio/AssetLoader.h>
#include <gltfio/ResourceLoader.h>
#include <gltfio/FilamentAsset.h>
#include <gltfio/FilamentInstance.h>
#include <gltfio/Animator.h>
#include <gltfio/MaterialProvider.h>
#include <gltfio/NodeManager.h>
#include <gltfio/TrsTransformManager.h>
// gltfio's private asset class, reached through its public include folder
// (libs/gltfio/include) so it resolves in any Filament folder, prebuilt
// archive included.
#include "gltfio/../../src/FFilamentAsset.h"

#include <utils/NameComponentManager.h>
#include <utils/Panic.h>
#include <cstdio>
#include <exception>

using namespace filament;
using namespace filament::gltfio;

#define FFI_TRY try {
#define FFI_CATCH(return_value) \
} catch (const utils::Panic& e) { \
    fprintf(stderr, "[GLTF C++ Panic (Handled Safely)]: %s\n", e.what()); \
    return return_value; \
} catch (const std::exception& e) { \
    fprintf(stderr, "[GLTF C++ Exception (Handled Safely)]: %s\n", e.what()); \
    return return_value; \
} catch (...) { \
    fprintf(stderr, "[GLTF C++ Unknown Exception (Handled Safely)]\n"); \
    return return_value; \
}

static inline Engine* toEngine(void* p) { return reinterpret_cast<Engine*>(p); }
static inline Scene* toScene(void* p) { return reinterpret_cast<Scene*>(p); }
static inline AssetLoader* toAssetLoader(void* p) { return reinterpret_cast<AssetLoader*>(p); }
static inline ResourceLoader* toResourceLoader(void* p) { return reinterpret_cast<ResourceLoader*>(p); }
static inline FilamentAsset* toFilamentAsset(void* p) { return reinterpret_cast<FilamentAsset*>(p); }
static inline Animator* toAnimator(void* p) { return reinterpret_cast<Animator*>(p); }
static inline MaterialProvider* toMaterialProvider(void* p) { return reinterpret_cast<MaterialProvider*>(p); }

#include <gltfio/materials/uberarchive.h>
#include "materials/wireframe_filamat.h"

void* filament_gltfio_create_ubershader_provider(void* engine, const void* archive, uint32_t archive_size) {
    FFI_TRY
    if (archive == nullptr || archive_size == 0) {
        return createUbershaderProvider(toEngine(engine), UBERARCHIVE_DEFAULT_DATA, UBERARCHIVE_DEFAULT_SIZE);
    }
    return createUbershaderProvider(toEngine(engine), archive, archive_size);
    FFI_CATCH(nullptr)
}
#ifndef __EMSCRIPTEN__
void* filament_gltfio_create_jit_material_provider(void* engine) {
    FFI_TRY return createJitShaderProvider(toEngine(engine)); FFI_CATCH(nullptr)
}

void* filament_gltfio_create_jit_material_provider_ex(void* engine, bool optimize_shaders) {
    FFI_TRY return createJitShaderProvider(toEngine(engine), optimize_shaders); FFI_CATCH(nullptr)
}
#else
// The JIT shader provider compiles with filamat, which is not in Filament's
// WebAssembly build; web games use the ubershader provider.
void* filament_gltfio_create_jit_material_provider(void* engine) {
    (void) engine;
    fprintf(stderr, "[flutter_filament] the JIT material provider is not available in web builds; use the ubershader provider\n");
    return nullptr;
}

void* filament_gltfio_create_jit_material_provider_ex(void* engine, bool optimize_shaders) {
    (void) optimize_shaders;
    return filament_gltfio_create_jit_material_provider(engine);
}
#endif


void filament_gltfio_destroy_material_provider(void* provider) {
    if (!provider) return;
    MaterialProvider* mp = toMaterialProvider(provider);
    try {
        if (mp->getMaterialsCount() > 0) {
            mp->destroyMaterials();
        }
    } catch (const utils::Panic& e) {
        fprintf(stderr, "[GLTF C++ Panic (Handled Safely)]: destroyMaterials: %s\n", e.what());
    } catch (const std::exception& e) {
        fprintf(stderr, "[GLTF C++ Exception (Handled Safely)]: destroyMaterials: %s\n", e.what());
    } catch (...) {
        fprintf(stderr, "[GLTF C++ Unknown Exception (Handled Safely)]: destroyMaterials\n");
    }
    try {
        delete mp;
    } catch (const utils::Panic& e) {
        fprintf(stderr, "[GLTF C++ Panic (Handled Safely)]: delete MaterialProvider: %s\n", e.what());
    } catch (const std::exception& e) {
        fprintf(stderr, "[GLTF C++ Exception (Handled Safely)]: delete MaterialProvider: %s\n", e.what());
    } catch (...) {
        fprintf(stderr, "[GLTF C++ Unknown Exception (Handled Safely)]: delete MaterialProvider\n");
    }
}

size_t filament_gltfio_material_provider_get_materials_count(void* provider) {
    FFI_TRY
    if (provider) {
        return toMaterialProvider(provider)->getMaterialsCount();
    }
    return 0;
    FFI_CATCH(0)
}

void filament_gltfio_material_provider_destroy_materials(void* provider) {
    FFI_TRY
    if (provider) {
        MaterialProvider* mp = toMaterialProvider(provider);
        if (mp->getMaterialsCount() > 0) {
            mp->destroyMaterials();
        }
    }
    FFI_CATCH()
}

void* filament_gltfio_material_provider_create_material_instance(void* provider, filament_gltfio_material_key_t* config, uint8_t* out_uvmap8, const char* label, const char* extras) {
    FFI_TRY
    if (!provider || !config) return nullptr;
    
    filament::gltfio::MaterialKey k;
    memset(&k, 0, sizeof(filament::gltfio::MaterialKey));
    
    k.doubleSided = config->doubleSided;
    k.unlit = config->unlit;
    k.hasVertexColors = config->hasVertexColors;
    k.hasBaseColorTexture = config->hasBaseColorTexture;
    k.hasNormalTexture = config->hasNormalTexture;
    k.hasOcclusionTexture = config->hasOcclusionTexture;
    k.hasEmissiveTexture = config->hasEmissiveTexture;
    k.useSpecularGlossiness = config->useSpecularGlossiness;
    k.alphaMode = static_cast<filament::gltfio::AlphaMode>(config->alphaMode);
    k.enableDiagnostics = config->enableDiagnostics;
    
    if (config->useSpecularGlossiness) {
        k.hasSpecularGlossinessTexture = config->hasSpecularGlossinessTexture;
        k.specularGlossinessUV = config->specularGlossinessUV;
    } else {
        k.hasMetallicRoughnessTexture = config->hasMetallicRoughnessTexture;
        k.metallicRoughnessUV = config->metallicRoughnessUV;
    }
    
    k.baseColorUV = config->baseColorUV;
    k.hasClearCoatTexture = config->hasClearCoatTexture;
    k.clearCoatUV = config->clearCoatUV;
    k.hasClearCoatRoughnessTexture = config->hasClearCoatRoughnessTexture;
    k.clearCoatRoughnessUV = config->clearCoatRoughnessUV;
    k.hasClearCoatNormalTexture = config->hasClearCoatNormalTexture;
    k.clearCoatNormalUV = config->clearCoatNormalUV;
    k.hasClearCoat = config->hasClearCoat;
    k.hasTransmission = config->hasTransmission;
    k.hasTextureTransforms = config->hasTextureTransforms;
    k.emissiveUV = config->emissiveUV;
    k.aoUV = config->aoUV;
    k.normalUV = config->normalUV;
    k.hasTransmissionTexture = config->hasTransmissionTexture;
    k.transmissionUV = config->transmissionUV;
    k.hasSheenColorTexture = config->hasSheenColorTexture;
    k.sheenColorUV = config->sheenColorUV;
    k.hasSheenRoughnessTexture = config->hasSheenRoughnessTexture;
    k.sheenRoughnessUV = config->sheenRoughnessUV;
    k.hasVolumeThicknessTexture = config->hasVolumeThicknessTexture;
    k.volumeThicknessUV = config->volumeThicknessUV;
    k.hasSheen = config->hasSheen;
    k.hasIOR = config->hasIOR;
    k.hasVolume = config->hasVolume;
    k.hasDispersion = config->hasDispersion;
    k.hasSpecular = config->hasSpecular;
    k.hasSpecularTexture = config->hasSpecularTexture;
    k.hasSpecularColorTexture = config->hasSpecularColorTexture;
    k.specularTextureUV = config->specularTextureUV;
    k.specularColorTextureUV = config->specularColorTextureUV;
    
    filament::gltfio::UvMap uvmap;
    std::fill(uvmap.begin(), uvmap.end(), filament::gltfio::UvSet::UNUSED);
    
    filament::MaterialInstance* instance = toMaterialProvider(provider)->createMaterialInstance(&k, &uvmap, label ? label : "", extras ? extras : "");
    
    config->doubleSided = k.doubleSided;
    config->unlit = k.unlit;
    config->hasVertexColors = k.hasVertexColors;
    config->hasBaseColorTexture = k.hasBaseColorTexture;
    config->hasNormalTexture = k.hasNormalTexture;
    config->hasOcclusionTexture = k.hasOcclusionTexture;
    config->hasEmissiveTexture = k.hasEmissiveTexture;
    config->useSpecularGlossiness = k.useSpecularGlossiness;
    config->alphaMode = static_cast<uint8_t>(k.alphaMode);
    config->enableDiagnostics = k.enableDiagnostics;
    
    if (k.useSpecularGlossiness) {
        config->hasSpecularGlossinessTexture = k.hasSpecularGlossinessTexture;
        config->specularGlossinessUV = k.specularGlossinessUV;
        config->hasMetallicRoughnessTexture = 0;
        config->metallicRoughnessUV = 0;
    } else {
        config->hasMetallicRoughnessTexture = k.hasMetallicRoughnessTexture;
        config->metallicRoughnessUV = k.metallicRoughnessUV;
        config->hasSpecularGlossinessTexture = 0;
        config->specularGlossinessUV = 0;
    }
    
    config->baseColorUV = k.baseColorUV;
    config->hasClearCoatTexture = k.hasClearCoatTexture;
    config->clearCoatUV = k.clearCoatUV;
    config->hasClearCoatRoughnessTexture = k.hasClearCoatRoughnessTexture;
    config->clearCoatRoughnessUV = k.clearCoatRoughnessUV;
    config->hasClearCoatNormalTexture = k.hasClearCoatNormalTexture;
    config->clearCoatNormalUV = k.clearCoatNormalUV;
    config->hasClearCoat = k.hasClearCoat;
    config->hasTransmission = k.hasTransmission;
    config->hasTextureTransforms = k.hasTextureTransforms;
    config->emissiveUV = k.emissiveUV;
    config->aoUV = k.aoUV;
    config->normalUV = k.normalUV;
    config->hasTransmissionTexture = k.hasTransmissionTexture;
    config->transmissionUV = k.transmissionUV;
    config->hasSheenColorTexture = k.hasSheenColorTexture;
    config->sheenColorUV = k.sheenColorUV;
    config->hasSheenRoughnessTexture = k.hasSheenRoughnessTexture;
    config->sheenRoughnessUV = k.sheenRoughnessUV;
    config->hasVolumeThicknessTexture = k.hasVolumeThicknessTexture;
    config->volumeThicknessUV = k.volumeThicknessUV;
    config->hasSheen = k.hasSheen;
    config->hasIOR = k.hasIOR;
    config->hasVolume = k.hasVolume;
    config->hasDispersion = k.hasDispersion;
    config->hasSpecular = k.hasSpecular;
    config->hasSpecularTexture = k.hasSpecularTexture;
    config->hasSpecularColorTexture = k.hasSpecularColorTexture;
    config->specularTextureUV = k.specularTextureUV;
    config->specularColorTextureUV = k.specularColorTextureUV;
    
    if (out_uvmap8) {
        for (int i = 0; i < 8; i++) {
            out_uvmap8[i] = static_cast<uint8_t>(uvmap[i]);
        }
    }
    
    return instance;
    FFI_CATCH(nullptr)
}

size_t filament_gltfio_material_provider_get_materials(void* provider, void** out, size_t max) {
    FFI_TRY
    if (!provider || !out || max == 0) return 0;
    
    MaterialProvider* mp = toMaterialProvider(provider);
    size_t count = mp->getMaterialsCount();
    auto materials = mp->getMaterials();
    size_t written = 0;
    
    for (size_t i = 0; i < count && i < max; i++) {
        out[i] = (void*)materials[i];
        written++;
    }
    return written;
    FFI_CATCH(0)
}

bool filament_gltfio_material_provider_needs_dummy_data(void* provider, int vertex_attribute) {
    FFI_TRY
    if (!provider) return false;
    return toMaterialProvider(provider)->needsDummyData(static_cast<filament::VertexAttribute>(vertex_attribute));
    FFI_CATCH(false)
}

void* filament_gltfio_asset_loader_create(void* engine, void* material_provider) {
    FFI_TRY AssetConfiguration config; config.engine = toEngine(engine); config.materials = toMaterialProvider(material_provider);
    return AssetLoader::create(config); FFI_CATCH(nullptr)
}
void* filament_gltfio_asset_loader_create_with_names(void* engine, void* material_provider, void* names) {
    FFI_TRY
    AssetConfiguration config;
    config.engine = toEngine(engine);
    config.materials = toMaterialProvider(material_provider);
    config.names = reinterpret_cast<utils::NameComponentManager*>(names);
    return AssetLoader::create(config);
    FFI_CATCH(nullptr)
}
void filament_gltfio_asset_loader_destroy(void* loader) {
    FFI_TRY if (loader) { AssetLoader* l = toAssetLoader(loader); AssetLoader::destroy(&l); } FFI_CATCH()
}
void* filament_gltfio_asset_loader_create_asset(void* loader, const uint8_t* bytes, uint32_t size) {
    FFI_TRY return toAssetLoader(loader)->createAsset(bytes, size); FFI_CATCH(nullptr)
}
void filament_gltfio_asset_loader_destroy_asset(void* loader, void* asset) {
    FFI_TRY toAssetLoader(loader)->destroyAsset(toFilamentAsset(asset)); FFI_CATCH()
}

void* filament_gltfio_asset_loader_create_instanced_asset(void* loader, const uint8_t* bytes, uint32_t size, void** out_instances, size_t num_instances) {
    FFI_TRY return toAssetLoader(loader)->createInstancedAsset(bytes, size, reinterpret_cast<FilamentInstance**>(out_instances), num_instances); FFI_CATCH(nullptr)
}

void* filament_gltfio_asset_loader_create_instance(void* loader, void* asset) {
    FFI_TRY return toAssetLoader(loader)->createInstance(toFilamentAsset(asset)); FFI_CATCH(nullptr)
}

void filament_gltfio_asset_loader_gc(void* loader) {
    FFI_TRY toAssetLoader(loader)->gc(); FFI_CATCH()
}
#include <gltfio/TextureProvider.h>

void* filament_gltfio_resource_loader_create(void* engine, const char* default_path, bool normalize_skinning_weights) {
    FFI_TRY
    ResourceConfiguration config;
    config.engine = toEngine(engine);
    config.gltfPath = default_path;
    config.normalizeSkinningWeights = normalize_skinning_weights;
    auto loader = new ResourceLoader(config);

    Engine* e = toEngine(engine);
    if (auto stb = createStbProvider(e)) {
        loader->addTextureProvider("image/png", stb);
        loader->addTextureProvider("image/jpeg", stb);
    }
    if (isWebpSupported()) {
        if (auto webp = createWebpProvider(e)) {
            loader->addTextureProvider("image/webp", webp);
        }
    }
    if (auto ktx = createKtx2Provider(e)) {
        loader->addTextureProvider("image/ktx2", ktx);
    }

    return loader;
    FFI_CATCH(nullptr)
}
void filament_gltfio_resource_loader_destroy(void* resource_loader) {
    FFI_TRY if (resource_loader) delete toResourceLoader(resource_loader); FFI_CATCH()
}
bool filament_gltfio_resource_loader_load_resources(void* resource_loader, void* asset) {
    FFI_TRY return toResourceLoader(resource_loader)->loadResources(toFilamentAsset(asset)); FFI_CATCH(false)
}
void filament_gltfio_resource_loader_set_configuration(void* resource_loader, const char* default_path, bool normalize_skinning_weights) {
    FFI_TRY {
        filament::gltfio::ResourceConfiguration config;
        config.engine = nullptr; // Note: Engine is not retained or required for just path updates
        config.gltfPath = default_path;
        config.normalizeSkinningWeights = normalize_skinning_weights;
        toResourceLoader(resource_loader)->setConfiguration(config);
    } FFI_CATCH()
}
void filament_gltfio_resource_loader_add_texture_provider(void* resource_loader, const char* mime, void* provider) {
    FFI_TRY {
        toResourceLoader(resource_loader)->addTextureProvider(mime, reinterpret_cast<filament::gltfio::TextureProvider*>(provider));
    } FFI_CATCH()
}
void filament_gltfio_resource_loader_add_resource_data(void* resource_loader, const char* uri, const uint8_t* data, size_t size) {
    FFI_TRY {
        uint8_t* copied_data = (uint8_t*)malloc(size);
        memcpy(copied_data, data, size);
        filament::backend::BufferDescriptor bd(copied_data, size, [](void* buffer, size_t, void*) {
            free(buffer);
        });
        toResourceLoader(resource_loader)->addResourceData(uri, std::move(bd));
    } FFI_CATCH()
}
bool filament_gltfio_resource_loader_has_resource_data(void* resource_loader, const char* uri) {
    FFI_TRY {
        return toResourceLoader(resource_loader)->hasResourceData(uri);
    } FFI_CATCH(false)
}
void filament_gltfio_resource_loader_evict_resource_data(void* resource_loader) {
    FFI_TRY {
        toResourceLoader(resource_loader)->evictResourceData();
    } FFI_CATCH()
}
bool filament_gltfio_resource_loader_async_begin_load(void* resource_loader, void* asset) {
    FFI_TRY {
        return toResourceLoader(resource_loader)->asyncBeginLoad(toFilamentAsset(asset));
    } FFI_CATCH(false)
}
float filament_gltfio_resource_loader_async_get_load_progress(void* resource_loader) {
    FFI_TRY {
        return toResourceLoader(resource_loader)->asyncGetLoadProgress();
    } FFI_CATCH(0.0f)
}
void filament_gltfio_resource_loader_async_update_load(void* resource_loader) {
    FFI_TRY {
        toResourceLoader(resource_loader)->asyncUpdateLoad();
    } FFI_CATCH()
}
void filament_gltfio_resource_loader_async_cancel_load(void* resource_loader) {
    FFI_TRY {
        toResourceLoader(resource_loader)->asyncCancelLoad();
    } FFI_CATCH()
}
void filament_gltfio_asset_release_source_data(void* asset) {
    FFI_TRY toFilamentAsset(asset)->releaseSourceData(); FFI_CATCH()
}
uint32_t filament_gltfio_asset_get_root(void* asset) {
    FFI_TRY return static_cast<uint32_t>(toFilamentAsset(asset)->getRoot().getId()); FFI_CATCH(0)
}
uint32_t filament_gltfio_asset_get_entity_count(void* asset) {
    FFI_TRY return static_cast<uint32_t>(toFilamentAsset(asset)->getEntityCount()); FFI_CATCH(0)
}
const uint32_t* filament_gltfio_asset_get_entities(void* asset) {
    FFI_TRY return reinterpret_cast<const uint32_t*>(toFilamentAsset(asset)->getEntities()); FFI_CATCH(nullptr)
}

void filament_gltfio_asset_get_bounding_box(void* asset, float* out_min3, float* out_max3) {
    FFI_TRY
    auto box = toFilamentAsset(asset)->getBoundingBox();
    out_min3[0] = box.min.x; out_min3[1] = box.min.y; out_min3[2] = box.min.z;
    out_max3[0] = box.max.x; out_max3[1] = box.max.y; out_max3[2] = box.max.z;
    FFI_CATCH()
}
size_t filament_gltfio_asset_get_light_entity_count(void* asset) {
    FFI_TRY return toFilamentAsset(asset)->getLightEntityCount(); FFI_CATCH(0)
}
const uint32_t* filament_gltfio_asset_get_light_entities(void* asset) {
    FFI_TRY return reinterpret_cast<const uint32_t*>(toFilamentAsset(asset)->getLightEntities()); FFI_CATCH(nullptr)
}
size_t filament_gltfio_asset_get_renderable_entity_count(void* asset) {
    FFI_TRY return toFilamentAsset(asset)->getRenderableEntityCount(); FFI_CATCH(0)
}
const uint32_t* filament_gltfio_asset_get_renderable_entities(void* asset) {
    FFI_TRY return reinterpret_cast<const uint32_t*>(toFilamentAsset(asset)->getRenderableEntities()); FFI_CATCH(nullptr)
}
size_t filament_gltfio_asset_get_camera_entity_count(void* asset) {
    FFI_TRY return toFilamentAsset(asset)->getCameraEntityCount(); FFI_CATCH(0)
}
const uint32_t* filament_gltfio_asset_get_camera_entities(void* asset) {
    FFI_TRY return reinterpret_cast<const uint32_t*>(toFilamentAsset(asset)->getCameraEntities()); FFI_CATCH(nullptr)
}
size_t filament_gltfio_asset_get_resource_uri_count(void* asset) {
    FFI_TRY return toFilamentAsset(asset)->getResourceUriCount(); FFI_CATCH(0)
}
const char* filament_gltfio_asset_get_resource_uri_at(void* asset, size_t i) {
    FFI_TRY
    auto uris = toFilamentAsset(asset)->getResourceUris();
    if (i < toFilamentAsset(asset)->getResourceUriCount()) return uris[i];
    return nullptr;
    FFI_CATCH(nullptr)
}
const char* filament_gltfio_asset_get_extras(void* asset, uint32_t entity) {
    FFI_TRY return toFilamentAsset(asset)->getExtras(utils::Entity::import(entity)); FFI_CATCH(nullptr)
}
size_t filament_gltfio_asset_get_morph_target_count_at(void* asset, uint32_t entity) {
    FFI_TRY return toFilamentAsset(asset)->getMorphTargetCountAt(utils::Entity::import(entity)); FFI_CATCH(0)
}
const char* filament_gltfio_asset_get_morph_target_name_at(void* asset, uint32_t entity, size_t target) {
    FFI_TRY return toFilamentAsset(asset)->getMorphTargetNameAt(utils::Entity::import(entity), target); FFI_CATCH(nullptr)
}
size_t filament_gltfio_asset_get_scene_count(void* asset) {
    FFI_TRY return toFilamentAsset(asset)->getSceneCount(); FFI_CATCH(0)
}
const char* filament_gltfio_asset_get_scene_name(void* asset, size_t scene) {
    FFI_TRY return toFilamentAsset(asset)->getSceneName(scene); FFI_CATCH(nullptr)
}
void filament_gltfio_asset_add_entities_to_scene(void* asset, void* scene, const uint32_t* entities, size_t count, uint32_t scene_mask) {
    FFI_TRY 
    utils::bitset32 mask(scene_mask);
    toFilamentAsset(asset)->addEntitiesToScene(
        *static_cast<filament::Scene*>(scene), 
        reinterpret_cast<const utils::Entity*>(entities), 
        count, mask
    );
    FFI_CATCH()
}
uint32_t filament_gltfio_asset_pop_renderable(void* asset) {
    FFI_TRY return toFilamentAsset(asset)->popRenderable().getId(); FFI_CATCH(0)
}
size_t filament_gltfio_asset_pop_renderables(void* asset, uint32_t* out, size_t max) {
    FFI_TRY return toFilamentAsset(asset)->popRenderables(reinterpret_cast<utils::Entity*>(out), max); FFI_CATCH(0)
}
void filament_gltfio_asset_detach_filament_components(void* asset) {
    FFI_TRY toFilamentAsset(asset)->detachFilamentComponents(); FFI_CATCH()
}

void* filament_gltfio_asset_get_instance(void* asset) {
    FFI_TRY return toFilamentAsset(asset)->getInstance(); FFI_CATCH(nullptr)
}

inline filament::gltfio::FilamentInstance* toFilamentInstance(void* ptr) {
    return static_cast<filament::gltfio::FilamentInstance*>(ptr);
}

void* filament_gltfio_instance_get_asset(void* instance) {
    FFI_TRY return const_cast<filament::gltfio::FilamentAsset*>(toFilamentInstance(instance)->getAsset()); FFI_CATCH(nullptr)
}

const uint32_t* filament_gltfio_instance_get_entities(void* instance) {
    FFI_TRY return reinterpret_cast<const uint32_t*>(toFilamentInstance(instance)->getEntities()); FFI_CATCH(nullptr)
}

size_t filament_gltfio_instance_get_entity_count(void* instance) {
    FFI_TRY return toFilamentInstance(instance)->getEntityCount(); FFI_CATCH(0)
}

uint32_t filament_gltfio_instance_get_root(void* instance) {
    FFI_TRY return static_cast<uint32_t>(toFilamentInstance(instance)->getRoot().getId()); FFI_CATCH(0)
}

void* filament_gltfio_instance_get_animator(void* instance) {
    FFI_TRY return toFilamentInstance(instance)->getAnimator(); FFI_CATCH(nullptr)
}

size_t filament_gltfio_instance_get_skin_count(void* instance) {
    FFI_TRY return toFilamentInstance(instance)->getSkinCount(); FFI_CATCH(0)
}

const char* filament_gltfio_instance_get_skin_name_at(void* instance, size_t skin) {
    FFI_TRY return toFilamentInstance(instance)->getSkinNameAt(skin); FFI_CATCH(nullptr)
}

size_t filament_gltfio_instance_get_joint_count_at(void* instance, size_t skin) {
    FFI_TRY return toFilamentInstance(instance)->getJointCountAt(skin); FFI_CATCH(0)
}

const uint32_t* filament_gltfio_instance_get_joints_at(void* instance, size_t skin) {
    FFI_TRY {
        const utils::Entity* joints = toFilamentInstance(instance)->getJointsAt(skin);
        return reinterpret_cast<const uint32_t*>(joints);
    } FFI_CATCH(nullptr)
}

void filament_gltfio_instance_attach_skin(void* instance, size_t skin, uint32_t target_entity) {
    FFI_TRY {
        utils::Entity e = utils::Entity::import(target_entity);
        toFilamentInstance(instance)->attachSkin(skin, e);
    } FFI_CATCH()
}

void filament_gltfio_instance_detach_skin(void* instance, size_t skin, uint32_t target_entity) {
    FFI_TRY {
        utils::Entity e = utils::Entity::import(target_entity);
        toFilamentInstance(instance)->detachSkin(skin, e);
    } FFI_CATCH()
}

void filament_gltfio_instance_get_inverse_bind_matrices_at(void* instance, size_t skin, float* out_mat4_array) {
    FFI_TRY {
        const math::mat4f* mats = toFilamentInstance(instance)->getInverseBindMatricesAt(skin);
        size_t count = toFilamentInstance(instance)->getJointCountAt(skin);
        memcpy(out_mat4_array, mats, count * sizeof(math::mat4f));
    } FFI_CATCH()
}

size_t filament_gltfio_instance_get_material_instance_count(void* instance) {
    FFI_TRY return toFilamentInstance(instance)->getMaterialInstanceCount(); FFI_CATCH(0)
}

void filament_gltfio_instance_get_material_instances(void* instance, void** out, size_t max) {
    FFI_TRY {
        auto instances = toFilamentInstance(instance)->getMaterialInstances();
        size_t count = std::min(max, toFilamentInstance(instance)->getMaterialInstanceCount());
        for (size_t i = 0; i < count; i++) {
            out[i] = instances[i];
        }
    } FFI_CATCH()
}

void filament_gltfio_instance_detach_material_instances(void* instance) {
    FFI_TRY toFilamentInstance(instance)->detachMaterialInstances(); FFI_CATCH()
}

void filament_gltfio_instance_apply_material_variant(void* instance, size_t variant) {
    FFI_TRY toFilamentInstance(instance)->applyMaterialVariant(variant); FFI_CATCH()
}

size_t filament_gltfio_instance_get_material_variant_count(void* instance) {
    FFI_TRY return toFilamentInstance(instance)->getMaterialVariantCount(); FFI_CATCH(0)
}

const char* filament_gltfio_instance_get_material_variant_name(void* instance, size_t variant) {
    FFI_TRY return toFilamentInstance(instance)->getMaterialVariantName(variant); FFI_CATCH(nullptr)
}

void filament_gltfio_instance_recompute_bounding_boxes(void* instance) {
    FFI_TRY toFilamentInstance(instance)->recomputeBoundingBoxes(); FFI_CATCH()
}

void filament_gltfio_instance_get_bounding_box(void* instance, float* out_min3, float* out_max3) {
    FFI_TRY {
        auto aabb = toFilamentInstance(instance)->getBoundingBox();
        out_min3[0] = aabb.min.x; out_min3[1] = aabb.min.y; out_min3[2] = aabb.min.z;
        out_max3[0] = aabb.max.x; out_max3[1] = aabb.max.y; out_max3[2] = aabb.max.z;
    } FFI_CATCH()
}

void filament_scene_add_asset_entities(void* scene, void* asset) {
    FFI_TRY FilamentAsset* a = toFilamentAsset(asset); toScene(scene)->addEntities(a->getEntities(), a->getEntityCount()); FFI_CATCH()
}
void filament_scene_remove_asset_entities(void* scene, void* asset) {
    FFI_TRY FilamentAsset* a = toFilamentAsset(asset); toScene(scene)->removeEntities(a->getEntities(), a->getEntityCount()); FFI_CATCH()
}
void* filament_gltfio_asset_get_animator(void* asset) {
    FFI_TRY return toFilamentAsset(asset)->getInstance() ? toFilamentAsset(asset)->getInstance()->getAnimator() : nullptr; FFI_CATCH(nullptr)
}
void filament_gltfio_animator_apply_animation(void* animator, size_t anim_index, float time_seconds) {
    FFI_TRY toAnimator(animator)->applyAnimation(anim_index, time_seconds); FFI_CATCH()
}
void filament_gltfio_animator_apply_cross_fade(void* animator, size_t previous_anim_index, float previous_anim_time, float alpha) {
    FFI_TRY toAnimator(animator)->applyCrossFade(previous_anim_index, previous_anim_time, alpha); FFI_CATCH()
}
void filament_gltfio_animator_update_bone_matrices(void* animator) {
    FFI_TRY toAnimator(animator)->updateBoneMatrices(); FFI_CATCH()
}
void filament_gltfio_animator_reset_bone_matrices(void* animator) {
    FFI_TRY toAnimator(animator)->resetBoneMatrices(); FFI_CATCH()
}
size_t filament_gltfio_animator_get_animation_count(void* animator) {
    FFI_TRY return toAnimator(animator)->getAnimationCount(); FFI_CATCH(0)
}
float filament_gltfio_animator_get_animation_duration(void* animator, size_t anim_index) {
    FFI_TRY return toAnimator(animator)->getAnimationDuration(anim_index); FFI_CATCH(0.0f)
}
#include <draco/compression/decode.h>

const char* filament_gltfio_animator_get_animation_name(void* animator, size_t anim_index) {
    FFI_TRY return toAnimator(animator)->getAnimationName(anim_index); FFI_CATCH(nullptr)
}

bool filament_gltf_decode_draco(
    const uint8_t* compressed_bytes,
    uint32_t compressed_size,
    float* out_positions,
    float* out_uvs,
    uint32_t* out_indices,
    uint32_t* out_vertex_count,
    uint32_t* out_index_count
) {
    FFI_TRY
    if (!compressed_bytes || compressed_size == 0) return false;

    draco::DecoderBuffer buffer;
    buffer.Init(reinterpret_cast<const char*>(compressed_bytes), compressed_size);
    draco::Decoder decoder;

    auto geotype = decoder.GetEncodedGeometryType(&buffer);
    if (!geotype.ok() || geotype.value() != draco::EncodedGeometryType::TRIANGULAR_MESH) {
        return false;
    }

    auto statusOrMesh = decoder.DecodeMeshFromBuffer(&buffer);
    if (!statusOrMesh.ok()) {
        return false;
    }

    const auto& mesh = statusOrMesh.value();
    uint32_t num_verts = mesh->num_points();
    uint32_t num_faces = mesh->num_faces();

    if (out_vertex_count) *out_vertex_count = num_verts;
    if (out_index_count) *out_index_count = num_faces * 3;

    const draco::PointAttribute* posAttr = mesh->GetNamedAttribute(draco::GeometryAttribute::POSITION);
    if (posAttr && out_positions) {
        for (draco::PointIndex i(0); i < num_verts; ++i) {
            posAttr->GetValue(posAttr->mapped_index(i), &out_positions[i.value() * 3]);
        }
    }

    const draco::PointAttribute* uvAttr = mesh->GetNamedAttribute(draco::GeometryAttribute::TEX_COORD);
    if (uvAttr && out_uvs) {
        for (draco::PointIndex i(0); i < num_verts; ++i) {
            uvAttr->GetValue(uvAttr->mapped_index(i), &out_uvs[i.value() * 2]);
        }
    }

    if (out_indices) {
        for (uint32_t f = 0; f < num_faces; ++f) {
            const draco::Mesh::Face& face = mesh->face(draco::FaceIndex(f));
            out_indices[f * 3 + 0] = face[0].value();
            out_indices[f * 3 + 1] = face[1].value();
            out_indices[f * 3 + 2] = face[2].value();
        }
    }

    return true;
    FFI_CATCH(false)
}

uint32_t filament_gltfio_asset_get_wireframe(void* asset) {
    FFI_TRY return static_cast<uint32_t>(toFilamentAsset(asset)->getWireframe().getId()); FFI_CATCH(0)
}

#include <filament/VertexBuffer.h>
#include <filament/IndexBuffer.h>
#include <filament/Material.h>
#include <filament/MaterialInstance.h>
#include <filament/RenderableManager.h>
#include <filamat/MaterialBuilder.h>
#include <filamat/Package.h>
#include <utils/EntityManager.h>
#include <utils/JobSystem.h>
#include <math/vec3.h>
#include <cstring>
#include <cstdlib>

using namespace filament::math;

struct WireframeMeshHandle {
    uint32_t entityId;
    VertexBuffer* vertexBuffer;
    IndexBuffer* indexBuffer;
    Material* material;
    MaterialInstance* materialInstance;
};

#include <mutex>
#include <unordered_map>

// HACK: Filament's AssetLoader.cpp forgot to implement AssetLoader::getNodeManager()
// even though it is declared in the public header and implemented in the internal FAssetLoader.
// This causes a linker error. We provide a weak fallback here that uses pointer scanning
// based on the known memory layout of FAssetLoader.
// MSVC has no weak symbols; the Windows libgltfio lacks the definition too, so
// this one is simply the only one there.
#if defined(_MSC_VER)
#define FILAMENT_C_WEAK
#else
#define FILAMENT_C_WEAK __attribute__((weak))
#endif
namespace filament::gltfio {
    FILAMENT_C_WEAK NodeManager& AssetLoader::getNodeManager() noexcept {
        void* nameManager = this->getNames();
        void** ptr = (void**)this;
        for (int i = 0; i < 32; i++) {
            if (ptr[i] == nameManager) {
                // Layout of FAssetLoader after vtable:
                // mEntityManager, mRenderableManager, mNameManager (ptr[i])
                // mTransformManager (ptr[i+1]), mMaterials (ptr[i+2])
                // mEngine (ptr[i+3]), mNodeManager (ptr[i+4])
                return *reinterpret_cast<NodeManager*>(&ptr[i+4]);
            }
        }
        fprintf(stderr, "FATAL: Could not find NodeManager in AssetLoader layout.\\n");
        abort();
    }
}


namespace {
static std::mutex s_materialMutex;
static std::unordered_map<Engine*, Material*> s_engineMaterials;

// The editor's line material is compiled ahead of time by
// `tool/build_materials.sh` and embedded as bytes. Building it here at runtime
// with filamat::MaterialBuilder failed on this workspace with "api level can't
// be set below 1 or above unstable material level(2)", and a wireframe with no
// material instance is drawn by Filament's own default white material, which
// ignores every colour set on it: the transform gizmo, the grid and the
// selection boxes were all permanently white.

static Material* getEngineWireframeMaterial(Engine* engine) {
    std::lock_guard<std::mutex> lock(s_materialMutex);
    auto it = s_engineMaterials.find(engine);
    if (it != s_engineMaterials.end()) {
        return it->second;
    }
    Material* mat = Material::Builder()
        .package(flutter_filament::kWireframeMaterialPackage,
                 flutter_filament::kWireframeMaterialPackageSize)
        .build(*engine);
    s_engineMaterials[engine] = mat;
    return mat;
}
} // namespace

void* filament_gltf_create_mesh_wireframe(
    void* engine_ptr,
    const float* positions,
    uint32_t vertex_count,
    const uint32_t* indices,
    uint32_t index_count
) {
    FFI_TRY
    if (!engine_ptr || !positions || vertex_count == 0 || !indices || index_count == 0) {
        return nullptr;
    }
    Engine* engine = toEngine(engine_ptr);

    float3* verts = (float3*) malloc(sizeof(float3) * vertex_count);
    memcpy(verts, positions, sizeof(float3) * vertex_count);

    VertexBuffer* vb = VertexBuffer::Builder()
        .bufferCount(1)
        .vertexCount(vertex_count)
        .attribute(VertexAttribute::POSITION, 0, VertexBuffer::AttributeType::FLOAT3)
        .build(*engine);

    vb->setBufferAt(*engine, 0, VertexBuffer::BufferDescriptor(
        verts, sizeof(float3) * vertex_count, [](void* mem, size_t, void*) { free(mem); }));

    uint32_t line_index_count = (index_count / 3) * 6;
    uint32_t* line_inds = (uint32_t*) malloc(sizeof(uint32_t) * line_index_count);

    uint32_t line_idx = 0;
    for (uint32_t i = 0; i + 2 < index_count; i += 3) {
        uint32_t i0 = indices[i];
        uint32_t i1 = indices[i + 1];
        uint32_t i2 = indices[i + 2];

        line_inds[line_idx++] = i0;
        line_inds[line_idx++] = i1;
        line_inds[line_idx++] = i1;
        line_inds[line_idx++] = i2;
        line_inds[line_idx++] = i2;
        line_inds[line_idx++] = i0;
    }

    IndexBuffer* ib = IndexBuffer::Builder()
        .indexCount(line_index_count)
        .bufferType(IndexBuffer::IndexType::UINT)
        .build(*engine);

    ib->setBuffer(*engine, IndexBuffer::BufferDescriptor(
        line_inds, sizeof(uint32_t) * line_index_count, [](void* mem, size_t, void*) { free(mem); }));

    utils::Entity entity = utils::EntityManager::get().create();

    Material* mat = getEngineWireframeMaterial(engine);
    MaterialInstance* mi = mat ? mat->createInstance() : nullptr;
    if (mi) {
        mi->setParameter("baseColor", filament::math::float4{1.0f, 1.0f, 1.0f, 1.0f});
    }

    RenderableManager::Builder(1)
        .boundingBox({{ -100000.0f, -100000.0f, -100000.0f }, { 100000.0f, 100000.0f, 100000.0f }})
        .culling(false)
        .castShadows(false)
        .receiveShadows(false)
        .material(0, mi)
        .geometry(0, RenderableManager::PrimitiveType::LINES, vb, ib)
        .build(*engine, entity);

    auto handle = new WireframeMeshHandle();
    handle->entityId = entity.getId();
    handle->vertexBuffer = vb;
    handle->indexBuffer = ib;
    handle->material = mat;
    handle->materialInstance = mi;

    return handle;
    FFI_CATCH(nullptr)
}

void* filament_create_line_segments_mesh(
    void* engine_ptr,
    const float* positions,
    uint32_t vertex_count,
    const uint32_t* line_indices,
    uint32_t line_index_count
) {
    FFI_TRY
    if (!engine_ptr || !positions || vertex_count == 0 || !line_indices || line_index_count == 0) {
        return nullptr;
    }

    Engine* engine = toEngine(engine_ptr);

    VertexBuffer* vb = VertexBuffer::Builder()
        .vertexCount(vertex_count)
        .bufferCount(1)
        .attribute(VertexAttribute::POSITION, 0, VertexBuffer::AttributeType::FLOAT3, 0, sizeof(float) * 3)
        .build(*engine);

    if (!vb) return nullptr;

    float* pos_copy = (float*)malloc(sizeof(float) * 3 * vertex_count);
    memcpy(pos_copy, positions, sizeof(float) * 3 * vertex_count);

    vb->setBufferAt(*engine, 0, VertexBuffer::BufferDescriptor(
        pos_copy, sizeof(float) * 3 * vertex_count, [](void* mem, size_t, void*) { free(mem); }));

    IndexBuffer* ib = IndexBuffer::Builder()
        .indexCount(line_index_count)
        .bufferType(IndexBuffer::IndexType::UINT)
        .build(*engine);

    if (!ib) {
        engine->destroy(vb);
        return nullptr;
    }

    uint32_t* line_inds = (uint32_t*)malloc(sizeof(uint32_t) * line_index_count);
    memcpy(line_inds, line_indices, sizeof(uint32_t) * line_index_count);

    ib->setBuffer(*engine, IndexBuffer::BufferDescriptor(
        line_inds, sizeof(uint32_t) * line_index_count, [](void* mem, size_t, void*) { free(mem); }));

    utils::Entity entity = utils::EntityManager::get().create();

    Material* mat = getEngineWireframeMaterial(engine);
    MaterialInstance* mi = mat ? mat->createInstance() : nullptr;
    if (mi) {
        mi->setParameter("baseColor", filament::math::float4{1.0f, 1.0f, 1.0f, 1.0f});
    }

    RenderableManager::Builder(1)
        .boundingBox({{ -100000.0f, -100000.0f, -100000.0f }, { 100000.0f, 100000.0f, 100000.0f }})
        .culling(false)
        .castShadows(false)
        .receiveShadows(false)
        .material(0, mi)
        .geometry(0, RenderableManager::PrimitiveType::LINES, vb, ib)
        .build(*engine, entity);

    auto handle = new WireframeMeshHandle();
    handle->entityId = entity.getId();
    handle->vertexBuffer = vb;
    handle->indexBuffer = ib;
    handle->material = mat;
    handle->materialInstance = mi;

    return handle;
    FFI_CATCH(nullptr)
}

uint32_t filament_wireframe_handle_get_entity(void* handle_ptr) {
    if (!handle_ptr) return 0;
    return reinterpret_cast<WireframeMeshHandle*>(handle_ptr)->entityId;
}

void filament_wireframe_handle_destroy(void* engine_ptr, void* handle_ptr) {
    FFI_TRY
    if (!engine_ptr || !handle_ptr) return;
    Engine* engine = toEngine(engine_ptr);
    auto handle = reinterpret_cast<WireframeMeshHandle*>(handle_ptr);

    utils::Entity entity = utils::Entity::import(handle->entityId);
    engine->destroy(entity);
    utils::EntityManager::get().destroy(entity);

    if (handle->vertexBuffer) engine->destroy(handle->vertexBuffer);
    if (handle->indexBuffer) engine->destroy(handle->indexBuffer);
    if (handle->materialInstance) engine->destroy(handle->materialInstance);
    // Note: handle->material is cached per Engine and reused.

    delete handle;
    FFI_CATCH()
}

void filament_cleanup_engine_materials(void* engine) {
    if (!engine) return;
    std::lock_guard<std::mutex> lock(s_materialMutex);
    s_engineMaterials.erase(toEngine(engine));
}

const char* filament_gltfio_asset_get_entity_name(void* asset, uint32_t entity) {
    FFI_TRY return toFilamentAsset(asset)->getName(utils::Entity::import(entity)); FFI_CATCH(nullptr)
}

uint32_t filament_gltfio_asset_get_first_entity_by_name(void* asset, const char* name) {
    FFI_TRY return static_cast<uint32_t>(toFilamentAsset(asset)->getFirstEntityByName(name).getId()); FFI_CATCH(0)
}

void* filament_gltfio_create_stb_provider(void* engine) {
    FFI_TRY return createStbProvider(toEngine(engine)); FFI_CATCH(nullptr)
}

void* filament_gltfio_create_ktx2_provider(void* engine) {
    FFI_TRY return createKtx2Provider(toEngine(engine)); FFI_CATCH(nullptr)
}

void* filament_gltfio_create_webp_provider(void* engine) {
    FFI_TRY
    if (isWebpSupported()) {
        return createWebpProvider(toEngine(engine));
    }
    return nullptr;
    FFI_CATCH(nullptr)
}

// NodeManager
void* filament_gltfio_node_manager_get(void* loader) {
    FFI_TRY 
    return &(toAssetLoader(loader)->getNodeManager());
    FFI_CATCH(nullptr)
}

bool filament_gltfio_is_webp_supported(void) {
    return isWebpSupported();
}

void filament_gltfio_texture_provider_destroy(void* provider) {
    FFI_TRY if (provider) delete reinterpret_cast<TextureProvider*>(provider); FFI_CATCH()
}

void* filament_gltfio_texture_provider_push_texture(void* provider, const uint8_t* data, size_t size, const char* mime, uint64_t flags) {
    FFI_TRY return reinterpret_cast<TextureProvider*>(provider)->pushTexture(data, size, mime, static_cast<TextureProvider::TextureFlags>(flags)); FFI_CATCH(nullptr)
}

void* filament_gltfio_texture_provider_pop_texture(void* provider) {
    FFI_TRY return reinterpret_cast<TextureProvider*>(provider)->popTexture(); FFI_CATCH(nullptr)
}

void filament_gltfio_texture_provider_update_queue(void* provider) {
    FFI_TRY reinterpret_cast<TextureProvider*>(provider)->updateQueue(); FFI_CATCH()
}

void filament_gltfio_texture_provider_wait_for_completion(void* provider) {
    FFI_TRY reinterpret_cast<TextureProvider*>(provider)->waitForCompletion(); FFI_CATCH()
}

void filament_gltfio_texture_provider_cancel_decoding(void* provider) {
    FFI_TRY reinterpret_cast<TextureProvider*>(provider)->cancelDecoding(); FFI_CATCH()
}

size_t filament_gltfio_texture_provider_get_pushed_count(void* provider) {
    FFI_TRY return reinterpret_cast<TextureProvider*>(provider)->getPushedCount(); FFI_CATCH(0)
}

size_t filament_gltfio_texture_provider_get_popped_count(void* provider) {
    FFI_TRY return reinterpret_cast<TextureProvider*>(provider)->getPoppedCount(); FFI_CATCH(0)
}

size_t filament_gltfio_texture_provider_get_decoded_count(void* provider) {
    FFI_TRY return reinterpret_cast<TextureProvider*>(provider)->getDecodedCount(); FFI_CATCH(0)
}

const char* filament_gltfio_texture_provider_get_push_message(void* provider) {
    FFI_TRY return reinterpret_cast<TextureProvider*>(provider)->getPushMessage(); FFI_CATCH(nullptr)
}

const char* filament_gltfio_texture_provider_get_pop_message(void* provider) {
    FFI_TRY return reinterpret_cast<TextureProvider*>(provider)->getPopMessage(); FFI_CATCH(nullptr)
}

size_t filament_gltfio_asset_get_entities_by_name(void* asset, const char* name, uint32_t* out_entities, size_t max_count) {
    FFI_TRY
    if (!asset || !name) return 0;
    auto a = toFilamentAsset(asset);
    if (!out_entities || max_count == 0) {
        return a->getEntitiesByName(name, nullptr, 0);
    }
    std::vector<utils::Entity> temp(max_count);
    size_t count = a->getEntitiesByName(name, temp.data(), max_count);
    for (size_t i = 0; i < count; ++i) {
        out_entities[i] = static_cast<uint32_t>(temp[i].getId());
    }
    return count;
    FFI_CATCH(0)
}

// NodeManager
void* filament_gltfio_asset_loader_get_node_manager(void* loader) {
    FFI_TRY return &(reinterpret_cast<AssetLoader*>(loader)->getNodeManager()); FFI_CATCH(nullptr)
}

void* filament_gltfio_asset_loader_get_names(void* loader) {
    FFI_TRY return reinterpret_cast<AssetLoader*>(loader)->getNames(); FFI_CATCH(nullptr)
}

bool filament_gltfio_node_manager_has_component(void* nm, uint32_t entity) {
    FFI_TRY
    auto e = utils::Entity::import(entity);
    return reinterpret_cast<NodeManager*>(nm)->hasComponent(e);
    FFI_CATCH(false)
}

const char* filament_gltfio_node_manager_get_extras(void* nm, uint32_t entity) {
    FFI_TRY
    auto manager = reinterpret_cast<NodeManager*>(nm);
    auto e = utils::Entity::import(entity);
    auto instance = manager->getInstance(e);
    if (!instance) return nullptr;
    return manager->getExtras(instance).c_str();
    FFI_CATCH(nullptr)
}

void filament_gltfio_node_manager_set_extras(void* nm, uint32_t entity, const char* json) {
    FFI_TRY
    auto manager = reinterpret_cast<NodeManager*>(nm);
    auto e = utils::Entity::import(entity);
    auto instance = manager->getInstance(e);
    if (instance) manager->setExtras(instance, utils::CString(json ? json : ""));
    FFI_CATCH()
}

size_t filament_gltfio_node_manager_get_morph_target_name_count(void* nm, uint32_t entity) {
    FFI_TRY
    auto manager = reinterpret_cast<NodeManager*>(nm);
    auto e = utils::Entity::import(entity);
    auto instance = manager->getInstance(e);
    if (!instance) return 0;
    return manager->getMorphTargetNames(instance).size();
    FFI_CATCH(0)
}

const char* filament_gltfio_node_manager_get_morph_target_name_at(void* nm, uint32_t entity, size_t i) {
    FFI_TRY
    auto manager = reinterpret_cast<NodeManager*>(nm);
    auto e = utils::Entity::import(entity);
    auto instance = manager->getInstance(e);
    if (!instance) return nullptr;
    const auto& names = manager->getMorphTargetNames(instance);
    if (i >= names.size()) return nullptr;
    return names[i].c_str();
    FFI_CATCH(nullptr)
}

void filament_gltfio_node_manager_set_morph_target_names(void* nm, uint32_t entity, const char* const* names, size_t count) {
    FFI_TRY
    auto manager = reinterpret_cast<NodeManager*>(nm);
    auto e = utils::Entity::import(entity);
    auto instance = manager->getInstance(e);
    if (instance) {
        utils::FixedCapacityVector<utils::CString> vec(count);
        for (size_t i = 0; i < count; ++i) {
            vec.push_back(utils::CString(names[i]));
        }
        manager->setMorphTargetNames(instance, std::move(vec));
    }
    FFI_CATCH()
}

uint32_t filament_gltfio_node_manager_get_scene_membership(void* nm, uint32_t entity) {
    FFI_TRY
    auto manager = reinterpret_cast<NodeManager*>(nm);
    auto e = utils::Entity::import(entity);
    auto instance = manager->getInstance(e);
    if (!instance) return 0;
    return manager->getSceneMembership(instance).getValue();
    FFI_CATCH(0)
}

void filament_gltfio_node_manager_set_scene_membership(void* nm, uint32_t entity, uint32_t scene_mask) {
    FFI_TRY
    auto manager = reinterpret_cast<NodeManager*>(nm);
    auto e = utils::Entity::import(entity);
    auto instance = manager->getInstance(e);
    if (instance) manager->setSceneMembership(instance, utils::bitset32(scene_mask));
    FFI_CATCH()
}

// TrsTransformManager
void* filament_gltfio_trs_transform_manager_get(void* asset) {
    FFI_TRY 
    // FFilamentAsset.h is private, so we use a relative path to include it.
    auto f_asset = reinterpret_cast<filament::gltfio::FFilamentAsset*>(asset);
    return f_asset->getTrsTransformManager();
    FFI_CATCH(nullptr)
}

bool filament_gltfio_trs_transform_manager_has_component(void* tm, uint32_t entity) {
    FFI_TRY
    auto e = utils::Entity::import(entity);
    return reinterpret_cast<TrsTransformManager*>(tm)->hasComponent(e);
    FFI_CATCH(false)
}

void filament_trs_set_translation(void* tm, uint32_t entity, float x, float y, float z) {
    FFI_TRY
    auto manager = reinterpret_cast<TrsTransformManager*>(tm);
    auto instance = manager->getInstance(utils::Entity::import(entity));
    if (instance) manager->setTranslation(instance, filament::math::float3{x, y, z});
    FFI_CATCH()
}

void filament_trs_get_translation(void* tm, uint32_t entity, float* out3) {
    FFI_TRY
    auto manager = reinterpret_cast<TrsTransformManager*>(tm);
    auto instance = manager->getInstance(utils::Entity::import(entity));
    if (instance && out3) {
        auto t = manager->getTranslation(instance);
        out3[0] = t.x; out3[1] = t.y; out3[2] = t.z;
    }
    FFI_CATCH()
}

void filament_trs_set_rotation(void* tm, uint32_t entity, float qx, float qy, float qz, float qw) {
    FFI_TRY
    auto manager = reinterpret_cast<TrsTransformManager*>(tm);
    auto instance = manager->getInstance(utils::Entity::import(entity));
    if (instance) manager->setRotation(instance, filament::math::quatf{qw, qx, qy, qz}); // quatf constructor is w, x, y, z
    FFI_CATCH()
}

void filament_trs_get_rotation(void* tm, uint32_t entity, float* out_quat4) {
    FFI_TRY
    auto manager = reinterpret_cast<TrsTransformManager*>(tm);
    auto instance = manager->getInstance(utils::Entity::import(entity));
    if (instance && out_quat4) {
        auto q = manager->getRotation(instance);
        out_quat4[0] = q.x; out_quat4[1] = q.y; out_quat4[2] = q.z; out_quat4[3] = q.w;
    }
    FFI_CATCH()
}

void filament_trs_set_scale(void* tm, uint32_t entity, float x, float y, float z) {
    FFI_TRY
    auto manager = reinterpret_cast<TrsTransformManager*>(tm);
    auto instance = manager->getInstance(utils::Entity::import(entity));
    if (instance) manager->setScale(instance, filament::math::float3{x, y, z});
    FFI_CATCH()
}

void filament_trs_get_scale(void* tm, uint32_t entity, float* out3) {
    FFI_TRY
    auto manager = reinterpret_cast<TrsTransformManager*>(tm);
    auto instance = manager->getInstance(utils::Entity::import(entity));
    if (instance && out3) {
        auto s = manager->getScale(instance);
        out3[0] = s.x; out3[1] = s.y; out3[2] = s.z;
    }
    FFI_CATCH()
}

void filament_trs_set_trs(void* tm, uint32_t entity, const float* t3, const float* quat4, const float* s3) {
    FFI_TRY
    auto manager = reinterpret_cast<TrsTransformManager*>(tm);
    auto instance = manager->getInstance(utils::Entity::import(entity));
    if (instance && t3 && quat4 && s3) {
        manager->setTrs(instance, 
            filament::math::float3{t3[0], t3[1], t3[2]}, 
            filament::math::quatf{quat4[3], quat4[0], quat4[1], quat4[2]}, 
            filament::math::float3{s3[0], s3[1], s3[2]});
    }
    FFI_CATCH()
}

void filament_trs_get_transform(void* tm, uint32_t entity, float* out_mat4) {
    FFI_TRY
    auto manager = reinterpret_cast<TrsTransformManager*>(tm);
    auto instance = manager->getInstance(utils::Entity::import(entity));
    if (instance && out_mat4) {
        auto mat = manager->getTransform(instance);
        for (int i = 0; i < 16; ++i) {
            out_mat4[i] = mat[i / 4][i % 4];
        }
    }
    FFI_CATCH()
}
extern "C" int filament_wireframe_has_material(void* handle_ptr) {
    FFI_TRY
    if (!handle_ptr) return 0;
    auto handle = reinterpret_cast<WireframeMeshHandle*>(handle_ptr);
    return handle->materialInstance != nullptr ? 1 : 0;
    FFI_CATCH(0)
}

extern "C" void filament_wireframe_set_color(void* handle_ptr, float r, float g, float b, float a) {
    FFI_TRY
    if (!handle_ptr) return;
    auto handle = reinterpret_cast<WireframeMeshHandle*>(handle_ptr);
    if (handle->materialInstance) {
        handle->materialInstance->setParameter("baseColor", filament::math::float4{r, g, b, a});
    }
    FFI_CATCH()
}
