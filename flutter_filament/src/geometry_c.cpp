/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

#include "geometry_c.h"

#include <filament/Engine.h>
#include <filament/VertexBuffer.h>
#include <filament/IndexBuffer.h>
#include <filament/Material.h>
#include <filament/MaterialInstance.h>
#include <filament/RenderableManager.h>
#include <filament/TransformManager.h>
#include <filament/Texture.h>
#include <filament/TextureSampler.h>
#include <filament/Scene.h>
#include <filament/View.h>
#include <filament/MorphTargetBuffer.h>
#include <filament/InstanceBuffer.h>
#include <filament/SkinningBuffer.h>
#include <filament/Box.h>
#include <utils/Entity.h>
#include <utils/Panic.h>
#include <math/mat4.h>
#include <filameshio/MeshReader.h>
#include <cstdio>
#include <exception>
#include <algorithm>

using namespace filament;
using namespace filament::math;
using namespace utils;

#define FFI_TRY try {
#define FFI_CATCH(return_value) \
} catch (const utils::Panic& e) { \
    fprintf(stderr, "[Geometry C++ Panic (Handled Safely)]: %s\n", e.what()); \
    return return_value; \
} catch (const std::exception& e) { \
    fprintf(stderr, "[Geometry C++ Exception (Handled Safely)]: %s\n", e.what()); \
    return return_value; \
} catch (...) { \
    fprintf(stderr, "[Geometry C++ Unknown Exception (Handled Safely)]\n"); \
    return return_value; \
}

static inline Engine* toEngine(void* p) { return reinterpret_cast<Engine*>(p); }
static inline VertexBuffer* toVertexBuffer(void* p) { return reinterpret_cast<VertexBuffer*>(p); }
static inline IndexBuffer* toIndexBuffer(void* p) { return reinterpret_cast<IndexBuffer*>(p); }
static inline Material* toMaterial(void* p) { return reinterpret_cast<Material*>(p); }
static inline MaterialInstance* toMaterialInstance(void* p) { return reinterpret_cast<MaterialInstance*>(p); }
static inline Texture* toTexture(void* p) { return reinterpret_cast<Texture*>(p); }
static inline Entity toEntity(uint32_t e) { return Entity::import(static_cast<int>(e)); }

#include "suzanne_mesh_data.h"

// The embedded Suzanne (a filamesh blob), loaded with the caller's material
// instance. Returns its renderable entity, or 0.
uint32_t filament_geometry_create_suzanne_monkey_mesh(void* engine, void* material_instance) {
    FFI_TRY
    filamesh::MeshReader::Mesh mesh = filamesh::MeshReader::loadMeshFromBuffer(
        toEngine(engine), SUZANNE_MESH_DATA, SUZANNE_MESH_SIZE, nullptr, nullptr,
        toMaterialInstance(material_instance));
    return static_cast<uint32_t>(mesh.renderable.getId());
    FFI_CATCH(0)
}

uint32_t filament_mesh_reader_load_mesh_from_buffer(
    void* engine, const void* data, uint32_t size, void* material_instance) {
    FFI_TRY
    filamesh::MeshReader::Mesh mesh = filamesh::MeshReader::loadMeshFromBuffer(
        toEngine(engine), data, size, nullptr, nullptr, toMaterialInstance(material_instance));
    return static_cast<uint32_t>(mesh.renderable.getId());
    FFI_CATCH(0)
}

#ifndef __EMSCRIPTEN__
#include <resources.h>
#include <monkey.h>
#endif
#include <ktxreader/Ktx2Reader.h>
#include <ktxreader/Ktx1Reader.h>
#include <filament/IndirectLight.h>
#include <filament/Skybox.h>
#include <stb_image.h>
#include <fstream>
#include <vector>

#ifndef __EMSCRIPTEN__
struct SuzanneSampleResources {
    utils::Entity renderable;
    Material* material = nullptr;
    MaterialInstance* materialInstance = nullptr;
    Texture* albedo = nullptr;
    Texture* normal = nullptr;
    Texture* roughness = nullptr;
    Texture* metallic = nullptr;
    Texture* ao = nullptr;
    IndirectLight* indirectLight = nullptr;
    Skybox* skybox = nullptr;
    Texture* iblTex = nullptr;
    Texture* skyTex = nullptr;
};

static SuzanneSampleResources g_suzanneResources;

static void setupSuzanneIBL(Engine* engine, Scene* scene) {
    const char* iblPath = "/Users/mustafaus/lumina/filament/out/cmake-release/samples/assets/ibl/lightroom_14b/lightroom_14b_ibl.ktx";
    const char* skyPath = "/Users/mustafaus/lumina/filament/out/cmake-release/samples/assets/ibl/lightroom_14b/lightroom_14b_skybox.ktx";

    auto loadKtxBundle = [](const char* path) -> image::Ktx1Bundle* {
        std::ifstream file(path, std::ios::binary);
        if (!file.is_open()) return nullptr;
        std::vector<uint8_t> contents((std::istreambuf_iterator<char>(file)), {});
        return new image::Ktx1Bundle(contents.data(), contents.size());
    };

    image::Ktx1Bundle* iblKtx = loadKtxBundle(iblPath);
    image::Ktx1Bundle* skyKtx = loadKtxBundle(skyPath);

    if (iblKtx && skyKtx) {
        Texture* iblTex = ktxreader::Ktx1Reader::createTexture(engine, iblKtx, false);
        Texture* skyTex = ktxreader::Ktx1Reader::createTexture(engine, skyKtx, false);
        g_suzanneResources.iblTex = iblTex;
        g_suzanneResources.skyTex = skyTex;

        math::float3 bands[9];
        if (iblKtx->getSphericalHarmonics(bands)) {
            IndirectLight* ibl = IndirectLight::Builder()
                .reflections(iblTex)
                .irradiance(3, bands)
                .intensity(100000.0f)
                .rotation(math::mat3f::rotation(0.5f, math::float3{ 0, 1, 0 }))
                .build(*engine);
            scene->setIndirectLight(ibl);
            g_suzanneResources.indirectLight = ibl;
        } else {
            IndirectLight* ibl = IndirectLight::Builder()
                .reflections(iblTex)
                .intensity(100000.0f)
                .rotation(math::mat3f::rotation(0.5f, math::float3{ 0, 1, 0 }))
                .build(*engine);
            scene->setIndirectLight(ibl);
            g_suzanneResources.indirectLight = ibl;
        }

        Skybox* skybox = Skybox::Builder()
            .environment(skyTex)
            .showSun(true)
            .build(*engine);
        scene->setSkybox(skybox);
        g_suzanneResources.skybox = skybox;
    }
}

static Texture* loadNormalMapLocal(Engine* engine, const uint8_t* normals, size_t nbytes) {
    int w, h, n;
    unsigned char* data = stbi_load_from_memory(normals, static_cast<int>(nbytes), &w, &h, &n, 3);
    if (!data) return nullptr;
    Texture* normalMap = Texture::Builder()
            .width(uint32_t(w))
            .height(uint32_t(h))
            .levels(0xff)
            .format(Texture::InternalFormat::RGB8)
            .usage(Texture::Usage::DEFAULT | Texture::Usage::GEN_MIPMAPPABLE)
            .build(*engine);
    Texture::PixelBufferDescriptor buffer(data, size_t(w * h * 3),
            Texture::Format::RGB, Texture::Type::UBYTE,
            (Texture::PixelBufferDescriptor::Callback) &stbi_image_free);
    normalMap->setImage(*engine, 0, std::move(buffer));
    normalMap->generateMipmaps(*engine);
    return normalMap;
}

void filament_suzanne_sample_destroy(void* engine_ptr, void* scene_ptr) {
    FFI_TRY
    if (!engine_ptr) return;
    Engine* engine = toEngine(engine_ptr);
    Scene* scene = reinterpret_cast<Scene*>(scene_ptr);

    if (!g_suzanneResources.renderable.isNull()) {
        if (scene) scene->remove(g_suzanneResources.renderable);
        engine->destroy(g_suzanneResources.renderable);
        g_suzanneResources.renderable = utils::Entity();
    }
    if (g_suzanneResources.materialInstance) {
        engine->destroy(g_suzanneResources.materialInstance);
        g_suzanneResources.materialInstance = nullptr;
    }
    if (g_suzanneResources.material) {
        engine->destroy(g_suzanneResources.material);
        g_suzanneResources.material = nullptr;
    }
    if (g_suzanneResources.albedo) { engine->destroy(g_suzanneResources.albedo); g_suzanneResources.albedo = nullptr; }
    if (g_suzanneResources.normal) { engine->destroy(g_suzanneResources.normal); g_suzanneResources.normal = nullptr; }
    if (g_suzanneResources.roughness) { engine->destroy(g_suzanneResources.roughness); g_suzanneResources.roughness = nullptr; }
    if (g_suzanneResources.metallic) { engine->destroy(g_suzanneResources.metallic); g_suzanneResources.metallic = nullptr; }
    if (g_suzanneResources.ao) { engine->destroy(g_suzanneResources.ao); g_suzanneResources.ao = nullptr; }
    if (g_suzanneResources.indirectLight) { engine->destroy(g_suzanneResources.indirectLight); g_suzanneResources.indirectLight = nullptr; }
    if (g_suzanneResources.skybox) { engine->destroy(g_suzanneResources.skybox); g_suzanneResources.skybox = nullptr; }
    if (g_suzanneResources.iblTex) { engine->destroy(g_suzanneResources.iblTex); g_suzanneResources.iblTex = nullptr; }
    if (g_suzanneResources.skyTex) { engine->destroy(g_suzanneResources.skyTex); g_suzanneResources.skyTex = nullptr; }
    FFI_CATCH()
}

uint32_t filament_suzanne_sample_create(void* engine_ptr, void* view_ptr, void* scene_ptr) {
    FFI_TRY
    Engine* engine = toEngine(engine_ptr);
    View* view = reinterpret_cast<View*>(view_ptr);
    Scene* scene = reinterpret_cast<Scene*>(scene_ptr);
    auto& tcm = engine->getTransformManager();
    auto& rcm = engine->getRenderableManager();

    filament_suzanne_sample_destroy(engine_ptr, scene_ptr);

    ktxreader::Ktx2Reader reader(*engine);
    reader.requestFormat(Texture::InternalFormat::DXT3_SRGBA);
    reader.requestFormat(Texture::InternalFormat::DXT3_RGBA);
    reader.requestFormat(Texture::InternalFormat::SRGB8_A8);
    reader.requestFormat(Texture::InternalFormat::RGBA8);

    constexpr auto sRGB = ktxreader::Ktx2Reader::TransferFunction::sRGB;
    constexpr auto LINEAR = ktxreader::Ktx2Reader::TransferFunction::LINEAR;

    g_suzanneResources.albedo = reader.load(MONKEY_ALBEDO_DATA, MONKEY_ALBEDO_SIZE, sRGB);
    g_suzanneResources.ao = reader.load(MONKEY_AO_DATA, MONKEY_AO_SIZE, LINEAR);
    g_suzanneResources.metallic = reader.load(MONKEY_METALLIC_DATA, MONKEY_METALLIC_SIZE, LINEAR);
    g_suzanneResources.roughness = reader.load(MONKEY_ROUGHNESS_DATA, MONKEY_ROUGHNESS_SIZE, LINEAR);
    g_suzanneResources.normal = loadNormalMapLocal(engine, MONKEY_NORMAL_DATA, MONKEY_NORMAL_SIZE);

    TextureSampler sampler(TextureSampler::MinFilter::LINEAR_MIPMAP_LINEAR, TextureSampler::MagFilter::LINEAR);

    g_suzanneResources.material = Material::Builder()
            .package(RESOURCES_TEXTUREDLIT_DATA, RESOURCES_TEXTUREDLIT_SIZE)
            .build(*engine);
    g_suzanneResources.materialInstance = g_suzanneResources.material->createInstance();
    if (g_suzanneResources.albedo) g_suzanneResources.materialInstance->setParameter("albedo", g_suzanneResources.albedo, sampler);
    if (g_suzanneResources.ao) g_suzanneResources.materialInstance->setParameter("ao", g_suzanneResources.ao, sampler);
    if (g_suzanneResources.metallic) g_suzanneResources.materialInstance->setParameter("metallic", g_suzanneResources.metallic, sampler);
    if (g_suzanneResources.normal) g_suzanneResources.materialInstance->setParameter("normal", g_suzanneResources.normal, sampler);
    if (g_suzanneResources.roughness) g_suzanneResources.materialInstance->setParameter("roughness", g_suzanneResources.roughness, sampler);

    filamesh::MeshReader::Mesh mesh = filamesh::MeshReader::loadMeshFromBuffer(
        engine, MONKEY_SUZANNE_DATA, MONKEY_SUZANNE_SIZE, nullptr, nullptr, g_suzanneResources.materialInstance);

    g_suzanneResources.renderable = mesh.renderable;

    auto ti = tcm.getInstance(mesh.renderable);
    mat4f transform = mat4f{ mat3f(1), float3(0, 0, -4) } * tcm.getWorldTransform(ti);
    tcm.setTransform(ti, transform);
    rcm.setCastShadows(rcm.getInstance(mesh.renderable), false);

    scene->addEntity(mesh.renderable);

    setupSuzanneIBL(engine, scene);

    return static_cast<uint32_t>(mesh.renderable.getId());
    FFI_CATCH(0)
}
#else  // __EMSCRIPTEN__
// The Suzanne sample's materials and textures are resources compiled for the
// desktop samples (out/cmake-release/samples); web builds do not carry them.
void filament_suzanne_sample_destroy(void* engine_ptr, void* scene_ptr) {
    (void) engine_ptr;
    (void) scene_ptr;
}

uint32_t filament_suzanne_sample_create(void* engine_ptr, void* view_ptr, void* scene_ptr) {
    (void) engine_ptr;
    (void) view_ptr;
    (void) scene_ptr;
    fprintf(stderr, "[flutter_filament] the Suzanne sample exists only in desktop builds\n");
    return 0;
}
#endif  // __EMSCRIPTEN__



void filament_engine_destroy_material_instance(void* engine, void* mi) {
    FFI_TRY
    toEngine(engine)->destroy(toMaterialInstance(mi));
    FFI_CATCH()
}

inline static RenderableManager::Builder* toRenderableBuilder(void* ptr) {
    return reinterpret_cast<RenderableManager::Builder*>(ptr);
}

void* filament_renderable_builder_create(uint32_t primitive_count) {
    FFI_TRY
    return new RenderableManager::Builder(primitive_count);
    FFI_CATCH(nullptr)
}

void filament_renderable_builder_geometry(void* builder, uint32_t index, int primitive_type, void* vb, void* ib, uint32_t offset, uint32_t count) {
    FFI_TRY
    toRenderableBuilder(builder)->geometry(index, static_cast<RenderableManager::PrimitiveType>(primitive_type), toVertexBuffer(vb), toIndexBuffer(ib), offset, count);
    FFI_CATCH()
}

void filament_renderable_builder_geometry_min_max(void* builder, uint32_t index, int primitive_type, void* vb, void* ib, uint32_t offset, uint32_t min_index, uint32_t max_index, uint32_t count) {
    FFI_TRY
    toRenderableBuilder(builder)->geometry(index, static_cast<RenderableManager::PrimitiveType>(primitive_type), toVertexBuffer(vb), toIndexBuffer(ib), offset, min_index, max_index, count);
    FFI_CATCH()
}

void filament_renderable_builder_geometry_full(void* builder, uint32_t index, int primitive_type, void* vb, void* ib) {
    FFI_TRY
    toRenderableBuilder(builder)->geometry(index, static_cast<RenderableManager::PrimitiveType>(primitive_type), toVertexBuffer(vb), toIndexBuffer(ib));
    FFI_CATCH()
}

void filament_renderable_builder_geometry_no_index(void* builder, uint32_t index, int primitive_type, void* vb) {
    FFI_TRY
    toRenderableBuilder(builder)->geometry(index, static_cast<RenderableManager::PrimitiveType>(primitive_type), toVertexBuffer(vb));
    FFI_CATCH()
}



void filament_renderable_builder_material(void* builder, uint32_t index, void* material_instance) {
    FFI_TRY
    toRenderableBuilder(builder)->material(index, toMaterialInstance(material_instance));
    FFI_CATCH()
}

void filament_renderable_builder_bounding_box(void* builder, float min_x, float min_y, float min_z, float max_x, float max_y, float max_z) {
    FFI_TRY
    toRenderableBuilder(builder)->boundingBox(Box().set({ min_x, min_y, min_z }, { max_x, max_y, max_z }));
    FFI_CATCH()
}

void filament_renderable_builder_culling(void* builder, bool enabled) {
    FFI_TRY
    toRenderableBuilder(builder)->culling(enabled);
    FFI_CATCH()
}

void filament_renderable_builder_cast_shadows(void* builder, bool enabled) {
    FFI_TRY
    toRenderableBuilder(builder)->castShadows(enabled);
    FFI_CATCH()
}

void filament_renderable_builder_receive_shadows(void* builder, bool enabled) {
    FFI_TRY
    toRenderableBuilder(builder)->receiveShadows(enabled);
    FFI_CATCH()
}

void filament_renderable_builder_priority(void* builder, uint8_t priority) {
    FFI_TRY
    toRenderableBuilder(builder)->priority(priority);
    FFI_CATCH()
}

void filament_renderable_builder_layer_mask(void* builder, uint8_t select, uint8_t values) {
    FFI_TRY
    toRenderableBuilder(builder)->layerMask(select, values);
    FFI_CATCH()
}

void filament_renderable_builder_skinning(void* builder, uint32_t bone_count) {
    FFI_TRY
    toRenderableBuilder(builder)->skinning(bone_count);
    FFI_CATCH()
}

void filament_renderable_builder_skinning_bones(void* builder, uint32_t bone_count, const FilamentBone* bones) {
    FFI_TRY
    toRenderableBuilder(builder)->skinning(bone_count, reinterpret_cast<RenderableManager::Bone const*>(bones));
    FFI_CATCH()
}

void filament_renderable_builder_skinning_matrices(void* builder, uint32_t bone_count, const float* transforms) {
    FFI_TRY
    toRenderableBuilder(builder)->skinning(bone_count, reinterpret_cast<math::mat4f const*>(transforms));
    FFI_CATCH()
}

void filament_renderable_builder_enable_skinning_buffers(void* builder, bool enabled) {
    FFI_TRY
    toRenderableBuilder(builder)->enableSkinningBuffers(enabled);
    FFI_CATCH()
}

void filament_renderable_builder_skinning_buffer(void* builder, void* skinning_buffer, uint32_t bone_count, uint32_t offset) {
    FFI_TRY
    toRenderableBuilder(builder)->skinning(reinterpret_cast<SkinningBuffer*>(skinning_buffer), bone_count, offset);
    FFI_CATCH()
}

void filament_renderable_builder_bone_indices_and_weights(void* builder, uint32_t primitive_index, const float* indices_and_weights, uint32_t count, uint32_t bones_per_vertex) {
    FFI_TRY
    toRenderableBuilder(builder)->boneIndicesAndWeights(primitive_index, reinterpret_cast<math::float2 const*>(indices_and_weights), count, bones_per_vertex);
    FFI_CATCH()
}

void filament_renderable_builder_geometry_type(void* builder, int geometry_type) {
    FFI_TRY
    toRenderableBuilder(builder)->geometryType(static_cast<RenderableManager::Builder::GeometryType>(geometry_type));
    FFI_CATCH()
}

void filament_renderable_builder_channel(void* builder, uint8_t channel) {
    FFI_TRY
    toRenderableBuilder(builder)->channel(channel);
    FFI_CATCH()
}

void filament_renderable_builder_light_channel(void* builder, unsigned int channel, bool enable) {
    FFI_TRY
    toRenderableBuilder(builder)->lightChannel(channel, enable);
    FFI_CATCH()
}

void filament_renderable_builder_blend_order(void* builder, uint32_t primitive_index, uint16_t order) {
    FFI_TRY
    toRenderableBuilder(builder)->blendOrder(primitive_index, order);
    FFI_CATCH()
}

void filament_renderable_builder_global_blend_order_enabled(void* builder, uint32_t primitive_index, bool enabled) {
    FFI_TRY
    toRenderableBuilder(builder)->globalBlendOrderEnabled(primitive_index, enabled);
    FFI_CATCH()
}

void filament_renderable_builder_screen_space_contact_shadows(void* builder, bool enabled) {
    FFI_TRY
    toRenderableBuilder(builder)->screenSpaceContactShadows(enabled);
    FFI_CATCH()
}

void filament_renderable_builder_fog(void* builder, bool enabled) {
    FFI_TRY
    toRenderableBuilder(builder)->fog(enabled);
    FFI_CATCH()
}

void filament_renderable_builder_morphing(void* builder, uint32_t target_count) {
    FFI_TRY
    toRenderableBuilder(builder)->morphing(target_count);
    FFI_CATCH()
}

void filament_renderable_builder_morphing_buffer(void* builder, void* morph_target_buffer) {
    FFI_TRY
    toRenderableBuilder(builder)->morphing(reinterpret_cast<MorphTargetBuffer*>(morph_target_buffer));
    FFI_CATCH()
}

void filament_renderable_builder_morphing_offset_at(void* builder, uint8_t level, uint32_t primitive_index, uint32_t offset) {
    FFI_TRY
    toRenderableBuilder(builder)->morphing(level, primitive_index, offset);
    FFI_CATCH()
}

void filament_renderable_builder_instances(void* builder, uint32_t instance_count) {
    FFI_TRY
    toRenderableBuilder(builder)->instances(instance_count);
    FFI_CATCH()
}

void filament_renderable_builder_instances_buffer(void* builder, uint32_t instance_count, void* instance_buffer) {
    FFI_TRY
    toRenderableBuilder(builder)->instances(instance_count, reinterpret_cast<InstanceBuffer*>(instance_buffer));
    FFI_CATCH()
}

int32_t filament_renderable_builder_build(void* builder, void* engine, uint32_t entity) {
    FFI_TRY
    auto b = toRenderableBuilder(builder);
    auto result = b->build(*toEngine(engine), toEntity(entity));
    delete b;
    return (result == RenderableManager::Builder::Result::Success) ? 0 : -1;
    FFI_CATCH(-1)
}

void filament_renderable_builder_destroy(void* builder) {
    FFI_TRY
    delete toRenderableBuilder(builder);
    FFI_CATCH()
}

void filament_renderable_create(void* engine, uint32_t entity, void* vb, void* ib, void* mi, uint32_t offset, uint32_t count, int primitive_type) {
    FFI_TRY
    RenderableManager::Builder(1)
        .boundingBox(Box().set({ -1, -1, -1 }, { 1, 1, 1 }))
        .material(0, toMaterialInstance(mi))
        .geometry(0, static_cast<RenderableManager::PrimitiveType>(primitive_type), toVertexBuffer(vb), toIndexBuffer(ib), offset, count)
        .culling(false)
        .receiveShadows(false)
        .castShadows(false)
        .build(*toEngine(engine), toEntity(entity));
    FFI_CATCH()
}

void filament_renderable_set_bounding_box(void* engine, uint32_t entity, float min_x, float min_y, float min_z, float max_x, float max_y, float max_z) {
    FFI_TRY
    auto& rm = toEngine(engine)->getRenderableManager();
    auto instance = rm.getInstance(toEntity(entity));
    rm.setAxisAlignedBoundingBox(instance, Box().set({ min_x, min_y, min_z }, { max_x, max_y, max_z }));
    FFI_CATCH()
}

void filament_renderable_set_priority(void* engine, uint32_t entity, uint8_t priority) {
    FFI_TRY
    auto& rm = toEngine(engine)->getRenderableManager();
    auto instance = rm.getInstance(toEntity(entity));
    rm.setPriority(instance, priority);
    FFI_CATCH()
}

void filament_renderable_set_culling(void* engine, uint32_t entity, bool enabled) {
    FFI_TRY
    auto& rm = toEngine(engine)->getRenderableManager();
    auto instance = rm.getInstance(toEntity(entity));
    rm.setCulling(instance, enabled);
    FFI_CATCH()
}

void filament_renderable_set_cast_shadows(void* engine, uint32_t entity, bool enabled) {
    FFI_TRY
    auto& rm = toEngine(engine)->getRenderableManager();
    auto instance = rm.getInstance(toEntity(entity));
    rm.setCastShadows(instance, enabled);
    FFI_CATCH()
}

void filament_renderable_set_receive_shadows(void* engine, uint32_t entity, bool enabled) {
    FFI_TRY
    auto& rm = toEngine(engine)->getRenderableManager();
    auto instance = rm.getInstance(toEntity(entity));
    rm.setReceiveShadows(instance, enabled);
    FFI_CATCH()
}

void filament_renderable_set_layer_mask(void* engine, uint32_t entity, uint8_t select, uint8_t mask) {
    FFI_TRY
    auto& rm = toEngine(engine)->getRenderableManager();
    auto instance = rm.getInstance(toEntity(entity));
    rm.setLayerMask(instance, select, mask);
    FFI_CATCH()
}

void filament_renderable_set_material_instance_at(void* engine, uint32_t entity, uint32_t primitive_index, void* material_instance) {
    FFI_TRY
    auto rm = &toEngine(engine)->getRenderableManager();
    rm->setMaterialInstanceAt(rm->getInstance(toEntity(entity)), primitive_index, toMaterialInstance(material_instance));
    FFI_CATCH()
}

void filament_renderable_set_geometry_at(void* engine, uint32_t entity, uint32_t primitive_index, int primitive_type, void* vb, void* ib, uint32_t offset, uint32_t count) {
    FFI_TRY
    auto rm = &toEngine(engine)->getRenderableManager();
    rm->setGeometryAt(rm->getInstance(toEntity(entity)), primitive_index, static_cast<RenderableManager::PrimitiveType>(primitive_type), toVertexBuffer(vb), toIndexBuffer(ib), offset, count);
    FFI_CATCH()
}

uint32_t filament_renderable_get_primitive_count(void* engine, uint32_t entity) {
    FFI_TRY
    auto rm = &toEngine(engine)->getRenderableManager();
    return rm->getPrimitiveCount(rm->getInstance(toEntity(entity)));
    FFI_CATCH(0)
}

void* filament_renderable_get_material_instance_at(void* engine, uint32_t entity, uint32_t primitive_index) {
    FFI_TRY
    auto rm = &toEngine(engine)->getRenderableManager();
    return rm->getMaterialInstanceAt(rm->getInstance(toEntity(entity)), primitive_index);
    FFI_CATCH(nullptr)
}

void filament_renderable_clear_material_instance_at(void* engine, uint32_t entity, uint32_t primitive_index) {
    FFI_TRY
    auto rm = &toEngine(engine)->getRenderableManager();
    rm->clearMaterialInstanceAt(rm->getInstance(toEntity(entity)), primitive_index);
    FFI_CATCH()
}

void filament_renderable_set_bones(void* engine, uint32_t entity, const FilamentBone* bones, uint32_t count, uint32_t offset) {
    FFI_TRY
    auto rm = &toEngine(engine)->getRenderableManager();
    rm->setBones(rm->getInstance(toEntity(entity)), reinterpret_cast<RenderableManager::Bone const*>(bones), count, offset);
    FFI_CATCH()
}

void filament_renderable_set_bones_matrices(void* engine, uint32_t entity, const float* transforms, uint32_t count, uint32_t offset) {
    FFI_TRY
    auto rm = &toEngine(engine)->getRenderableManager();
    rm->setBones(rm->getInstance(toEntity(entity)), reinterpret_cast<math::mat4f const*>(transforms), count, offset);
    FFI_CATCH()
}

void filament_renderable_set_skinning_buffer(void* engine, uint32_t entity, void* skinning_buffer, uint32_t count, uint32_t offset) {
    FFI_TRY
    auto rm = &toEngine(engine)->getRenderableManager();
    rm->setSkinningBuffer(rm->getInstance(toEntity(entity)), reinterpret_cast<SkinningBuffer*>(skinning_buffer), count, offset);
    FFI_CATCH()
}

void filament_renderable_set_channel(void* engine, uint32_t entity, uint8_t channel) {
    FFI_TRY
    if (!engine) return;
    auto& rm = toEngine(engine)->getRenderableManager();
    auto inst = rm.getInstance(toEntity(entity));
    if (inst) rm.setChannel(inst, channel);
    FFI_CATCH()
}

uint8_t filament_renderable_get_channel(void* engine, uint32_t entity) {
    FFI_TRY
    if (!engine) return 0;
    auto& rm = toEngine(engine)->getRenderableManager();
    auto inst = rm.getInstance(toEntity(entity));
    if (!inst) return 0;
    return rm.getChannel(inst);
    FFI_CATCH(0)
}

void filament_renderable_set_blend_order_at(void* engine, uint32_t entity, uint32_t primitive_index, uint16_t order) {
    FFI_TRY
    if (!engine) return;
    auto& rm = toEngine(engine)->getRenderableManager();
    auto inst = rm.getInstance(toEntity(entity));
    if (inst) rm.setBlendOrderAt(inst, primitive_index, order);
    FFI_CATCH()
}

uint16_t filament_renderable_get_blend_order_at(void* engine, uint32_t entity, uint32_t primitive_index) {
    FFI_TRY
    if (!engine) return 0;
    auto& rm = toEngine(engine)->getRenderableManager();
    auto inst = rm.getInstance(toEntity(entity));
    if (!inst) return 0;
    return rm.getBlendOrderAt(inst, primitive_index);
    FFI_CATCH(0)
}

void filament_renderable_set_global_blend_order_enabled_at(void* engine, uint32_t entity, uint32_t primitive_index, bool enabled) {
    FFI_TRY
    if (!engine) return;
    auto& rm = toEngine(engine)->getRenderableManager();
    auto inst = rm.getInstance(toEntity(entity));
    if (inst) rm.setGlobalBlendOrderEnabledAt(inst, primitive_index, enabled);
    FFI_CATCH()
}

bool filament_renderable_is_global_blend_order_enabled_at(void* engine, uint32_t entity, uint32_t primitive_index) {
    FFI_TRY
    if (!engine) return false;
    auto& rm = toEngine(engine)->getRenderableManager();
    auto inst = rm.getInstance(toEntity(entity));
    if (!inst) return false;
    return rm.isGlobalBlendOrderEnabledAt(inst, primitive_index);
    FFI_CATCH(false)
}

void filament_renderable_set_light_channel(void* engine, uint32_t entity, unsigned int channel, bool enable) {
    FFI_TRY
    if (!engine) return;
    auto& rm = toEngine(engine)->getRenderableManager();
    auto inst = rm.getInstance(toEntity(entity));
    if (inst) rm.setLightChannel(inst, channel, enable);
    FFI_CATCH()
}

bool filament_renderable_get_light_channel(void* engine, uint32_t entity, unsigned int channel) {
    FFI_TRY
    if (!engine) return channel == 0;
    auto& rm = toEngine(engine)->getRenderableManager();
    auto inst = rm.getInstance(toEntity(entity));
    if (!inst) return channel == 0;
    return rm.getLightChannel(inst, channel);
    FFI_CATCH(channel == 0)
}

void filament_renderable_set_screen_space_contact_shadows(void* engine, uint32_t entity, bool enabled) {
    FFI_TRY
    if (!engine) return;
    auto& rm = toEngine(engine)->getRenderableManager();
    auto inst = rm.getInstance(toEntity(entity));
    if (inst) rm.setScreenSpaceContactShadows(inst, enabled);
    FFI_CATCH()
}

bool filament_renderable_is_screen_space_contact_shadows_enabled(void* engine, uint32_t entity) {
    FFI_TRY
    if (!engine) return false;
    auto& rm = toEngine(engine)->getRenderableManager();
    auto inst = rm.getInstance(toEntity(entity));
    if (!inst) return false;
    return rm.isScreenSpaceContactShadowsEnabled(inst);
    FFI_CATCH(false)
}

void filament_renderable_set_fog_enabled(void* engine, uint32_t entity, bool enabled) {
    FFI_TRY
    if (!engine) return;
    auto& rm = toEngine(engine)->getRenderableManager();
    auto inst = rm.getInstance(toEntity(entity));
    if (inst) rm.setFogEnabled(inst, enabled);
    FFI_CATCH()
}

bool filament_renderable_get_fog_enabled(void* engine, uint32_t entity) {
    FFI_TRY
    if (!engine) return true;
    auto& rm = toEngine(engine)->getRenderableManager();
    auto inst = rm.getInstance(toEntity(entity));
    if (!inst) return true;
    return rm.getFogEnabled(inst);
    FFI_CATCH(true)
}

bool filament_renderable_has_component(void* engine, uint32_t entity) {
    FFI_TRY
    if (!engine) return false;
    auto& rm = toEngine(engine)->getRenderableManager();
    return rm.hasComponent(toEntity(entity));
    FFI_CATCH(false)
}

uint32_t filament_renderable_get_instance(void* engine, uint32_t entity) {
    FFI_TRY
    if (!engine) return 0;
    auto& rm = toEngine(engine)->getRenderableManager();
    return rm.getInstance(toEntity(entity)).asValue();
    FFI_CATCH(0)
}

uint32_t filament_renderable_get_component_count(void* engine) {
    FFI_TRY
    if (!engine) return 0;
    auto& rm = toEngine(engine)->getRenderableManager();
    return static_cast<uint32_t>(rm.getComponentCount());
    FFI_CATCH(0)
}

void filament_renderable_get_entities(void* engine, uint32_t* out_entities, uint32_t capacity) {
    FFI_TRY
    if (!engine || !out_entities || capacity == 0) return;
    auto& rm = toEngine(engine)->getRenderableManager();
    size_t count = rm.getComponentCount();
    size_t n = std::min(count, static_cast<size_t>(capacity));
    utils::Entity const* entities = rm.getEntities();
    for (size_t i = 0; i < n; ++i) {
        out_entities[i] = static_cast<uint32_t>(entities[i].getId());
    }
    FFI_CATCH()
}

void filament_renderable_get_axis_aligned_bounding_box(void* engine, uint32_t entity, float* out_center_halfextent) {
    FFI_TRY
    if (!engine || !out_center_halfextent) return;
    auto& rm = toEngine(engine)->getRenderableManager();
    auto inst = rm.getInstance(toEntity(entity));
    if (!inst) {
        memset(out_center_halfextent, 0, sizeof(float) * 6);
        return;
    }
    const Box& box = rm.getAxisAlignedBoundingBox(inst);
    out_center_halfextent[0] = box.center.x;
    out_center_halfextent[1] = box.center.y;
    out_center_halfextent[2] = box.center.z;
    out_center_halfextent[3] = box.halfExtent.x;
    out_center_halfextent[4] = box.halfExtent.y;
    out_center_halfextent[5] = box.halfExtent.z;
    FFI_CATCH()
}

bool filament_renderable_is_shadow_caster(void* engine, uint32_t entity) {
    FFI_TRY
    if (!engine) return false;
    auto& rm = toEngine(engine)->getRenderableManager();
    auto inst = rm.getInstance(toEntity(entity));
    if (!inst) return false;
    return rm.isShadowCaster(inst);
    FFI_CATCH(false)
}

bool filament_renderable_is_shadow_receiver(void* engine, uint32_t entity) {
    FFI_TRY
    if (!engine) return false;
    auto& rm = toEngine(engine)->getRenderableManager();
    auto inst = rm.getInstance(toEntity(entity));
    if (!inst) return false;
    return rm.isShadowReceiver(inst);
    FFI_CATCH(false)
}

uint32_t filament_renderable_get_enabled_attributes_at(void* engine, uint32_t entity, uint32_t primitive_index) {
    FFI_TRY
    if (!engine) return 0;
    auto& rm = toEngine(engine)->getRenderableManager();
    auto inst = rm.getInstance(toEntity(entity));
    if (!inst) return 0;
    return rm.getEnabledAttributesAt(inst, primitive_index).getValue();
    FFI_CATCH(0)
}

void filament_renderable_set_morph_weights(void* engine, uint32_t entity, const float* weights, uint32_t count, uint32_t offset) {
    FFI_TRY
    if (!engine || !weights) return;
    auto& rm = toEngine(engine)->getRenderableManager();
    auto inst = rm.getInstance(toEntity(entity));
    if (inst) rm.setMorphWeights(inst, weights, count, offset);
    FFI_CATCH()
}

void filament_renderable_set_morph_target_buffer_offset_at(void* engine, uint32_t entity, uint8_t level, uint32_t primitive_index, uint32_t offset) {
    FFI_TRY
    if (!engine) return;
    auto& rm = toEngine(engine)->getRenderableManager();
    auto inst = rm.getInstance(toEntity(entity));
    if (inst) rm.setMorphTargetBufferOffsetAt(inst, level, primitive_index, offset);
    FFI_CATCH()
}

uint32_t filament_renderable_get_morph_target_count(void* engine, uint32_t entity) {
    FFI_TRY
    if (!engine) return 0;
    auto& rm = toEngine(engine)->getRenderableManager();
    auto inst = rm.getInstance(toEntity(entity));
    if (!inst) return 0;
    return static_cast<uint32_t>(rm.getMorphTargetCount(inst));
    FFI_CATCH(0)
}

uint32_t filament_renderable_get_instance_count(void* engine, uint32_t entity) {
    FFI_TRY
    if (!engine) return 0;
    auto& rm = toEngine(engine)->getRenderableManager();
    auto inst = rm.getInstance(toEntity(entity));
    if (!inst) return 0;
    return static_cast<uint32_t>(rm.getInstanceCount(inst));
    FFI_CATCH(0)
}

void filament_renderable_destroy(void* engine, uint32_t entity) {
    FFI_TRY
    auto& rm = toEngine(engine)->getRenderableManager();
    rm.destroy(toEntity(entity));
    FFI_CATCH()
}

void filament_transform_create(void* engine, uint32_t entity) {
    FFI_TRY
    toEngine(engine)->getTransformManager().create(toEntity(entity));
    FFI_CATCH()
}

void filament_transform_create_with_parent(void* engine, uint32_t entity, uint32_t parent_entity, const float* local_transform) {
    FFI_TRY
    if (!engine) return;
    auto& tcm = toEngine(engine)->getTransformManager();
    auto e = toEntity(entity);
    TransformManager::Instance parentInstance{};
    if (parent_entity != 0) {
        auto pe = toEntity(parent_entity);
        if (tcm.hasComponent(pe)) {
            parentInstance = tcm.getInstance(pe);
        }
    }
    if (local_transform != nullptr) {
        mat4f m(
            float4{local_transform[0], local_transform[1], local_transform[2], local_transform[3]},
            float4{local_transform[4], local_transform[5], local_transform[6], local_transform[7]},
            float4{local_transform[8], local_transform[9], local_transform[10], local_transform[11]},
            float4{local_transform[12], local_transform[13], local_transform[14], local_transform[15]}
        );
        tcm.create(e, parentInstance, m);
    } else {
        tcm.create(e, parentInstance);
    }
    FFI_CATCH()
}

void filament_transform_open_local_transform_transaction(void* engine) {
    FFI_TRY
    if (!engine) return;
    toEngine(engine)->getTransformManager().openLocalTransformTransaction();
    FFI_CATCH()
}

void filament_transform_commit_local_transform_transaction(void* engine) {
    FFI_TRY
    if (!engine) return;
    toEngine(engine)->getTransformManager().commitLocalTransformTransaction();
    FFI_CATCH()
}

void filament_transform_set_transform(void* engine, uint32_t entity, const float* matrix) {
    FFI_TRY
    if (!engine || !matrix) return;
    auto e = toEntity(entity);
    auto& tcm = toEngine(engine)->getTransformManager();
    if (!tcm.hasComponent(e)) {
        tcm.create(e);
    }
    auto instance = tcm.getInstance(e);
    if (!instance) return;
    mat4f m(
        float4{matrix[0], matrix[1], matrix[2], matrix[3]},
        float4{matrix[4], matrix[5], matrix[6], matrix[7]},
        float4{matrix[8], matrix[9], matrix[10], matrix[11]},
        float4{matrix[12], matrix[13], matrix[14], matrix[15]}
    );
    tcm.setTransform(instance, m);
    FFI_CATCH()
}

void filament_transform_get_transform(void* engine, uint32_t entity, float* out_matrix) {
    FFI_TRY
    if (!engine || !out_matrix) return;
    auto e = toEntity(entity);
    auto& tcm = toEngine(engine)->getTransformManager();
    if (!tcm.hasComponent(e)) {
        memset(out_matrix, 0, sizeof(float) * 16);
        out_matrix[0] = out_matrix[5] = out_matrix[10] = out_matrix[15] = 1.0f;
        return;
    }
    auto instance = tcm.getInstance(e);
    mat4f m = tcm.getTransform(instance);
    const float* data = &m[0][0];
    for (int i = 0; i < 16; i++) out_matrix[i] = data[i];
    FFI_CATCH()
}

void filament_transform_get_world_transform(void* engine, uint32_t entity, float* out_matrix) {
    FFI_TRY
    if (!engine || !out_matrix) return;
    auto e = toEntity(entity);
    auto& tcm = toEngine(engine)->getTransformManager();
    if (!tcm.hasComponent(e)) {
        memset(out_matrix, 0, sizeof(float) * 16);
        out_matrix[0] = out_matrix[5] = out_matrix[10] = out_matrix[15] = 1.0f;
        return;
    }
    auto instance = tcm.getInstance(e);
    mat4f m = tcm.getWorldTransform(instance);
    const float* data = &m[0][0];
    for (int i = 0; i < 16; i++) out_matrix[i] = data[i];
    FFI_CATCH()
}

void filament_transform_destroy(void* engine, uint32_t entity) {
    FFI_TRY
    toEngine(engine)->getTransformManager().destroy(toEntity(entity));
    FFI_CATCH()
}

void filament_transform_set_parent(void* engine, uint32_t entity, uint32_t parent_entity) {
    FFI_TRY
    auto& tcm = toEngine(engine)->getTransformManager();
    auto instance = tcm.getInstance(toEntity(entity));
    auto parentInstance = parent_entity != 0 ? tcm.getInstance(toEntity(parent_entity)) : TransformManager::Instance{};
    tcm.setParent(instance, parentInstance);
    FFI_CATCH()
}

uint32_t filament_transform_get_parent(void* engine, uint32_t entity) {
    FFI_TRY
    auto& tcm = toEngine(engine)->getTransformManager();
    auto instance = tcm.getInstance(toEntity(entity));
    Entity parent = tcm.getParent(instance);
    return static_cast<uint32_t>(parent.getId());
    FFI_CATCH(0)
}

uint32_t filament_transform_get_child_count(void* engine, uint32_t entity) {
    FFI_TRY
    auto& tcm = toEngine(engine)->getTransformManager();
    auto instance = tcm.getInstance(toEntity(entity));
    return static_cast<uint32_t>(tcm.getChildCount(instance));
    FFI_CATCH(0)
}

void filament_transform_get_children(void* engine, uint32_t entity, uint32_t* out_children, uint32_t capacity) {
    FFI_TRY
    if (!engine || !out_children || capacity == 0) return;
    auto& tcm = toEngine(engine)->getTransformManager();
    auto instance = tcm.getInstance(toEntity(entity));
    
    std::vector<utils::Entity> children(capacity);
    size_t count = tcm.getChildren(instance, children.data(), capacity);
    for (size_t i = 0; i < count; i++) {
        out_children[i] = children[i].getId();
    }
    FFI_CATCH()
}

#include <geometry/Transcoder.h>

size_t filament_transcode(
    float* target,
    const void* source,
    size_t vertex_count,
    int component_type,
    bool normalized,
    uint32_t component_count,
    size_t input_stride_bytes
) {
    FFI_TRY
    if (vertex_count == 0) return 0;
    filament::geometry::Transcoder::Config config{
        .componentType = static_cast<filament::geometry::ComponentType>(component_type),
        .normalized = normalized,
        .componentCount = component_count,
        .inputStrideBytes = static_cast<uint32_t>(input_stride_bytes),
    };
    filament::geometry::Transcoder transcoder(config);
    return transcoder(target, source, vertex_count);
    FFI_CATCH(0)
}

size_t filament_transcode_output_size(
    size_t vertex_count,
    uint32_t component_count
) {
    return vertex_count * component_count * sizeof(float);
}
