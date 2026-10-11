/*
 * Copyright 2026 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

#include "ui_overlay_c.h"

#include <chrono>
#include <cstdlib>
#include <cstring>

#include <filament/Camera.h>
#include <filament/Engine.h>
#include <filament/IndexBuffer.h>
#include <filament/Material.h>
#include <filament/MaterialInstance.h>
#include <filament/RenderableManager.h>
#include <filament/Renderer.h>
#include <filament/Scene.h>
#include <filament/Texture.h>
#include <filament/TextureSampler.h>
#include <filament/VertexBuffer.h>
#include <filament/View.h>
#include <filament/Viewport.h>
#include <utils/EntityManager.h>

#ifndef __EMSCRIPTEN__
#include "materials/ui_overlay_filamat.h"
#include "materials/ui_overlay_multiview_filamat.h"
#endif

using namespace filament;

namespace {

struct UiOverlay {
    Engine* engine = nullptr;
    Material* material = nullptr;
    MaterialInstance* instance = nullptr;
    VertexBuffer* vertices = nullptr;
    IndexBuffer* indices = nullptr;
    utils::Entity quad;
    utils::Entity cameraEntity;
    Camera* camera = nullptr;
    Scene* scene = nullptr;
    View* view = nullptr;
    Texture* texture = nullptr;
    uint32_t textureWidth = 0;
    uint32_t textureHeight = 0;
    bool hasContent = false;
    uint64_t lastUploadMicros = 0;
    uint64_t uploads = 0;
    uint8_t* pending = nullptr;
    uint32_t pendingWidth = 0;
    uint32_t pendingHeight = 0;
    std::chrono::steady_clock::time_point pendingStart;
};

// Two triangles covering the viewport, in device (clip) coordinates.
constexpr float kQuad[] = {
    -1.0f, -1.0f, 0.0f, 1.0f,
     1.0f, -1.0f, 0.0f, 1.0f,
    -1.0f,  1.0f, 0.0f, 1.0f,
     1.0f,  1.0f, 0.0f, 1.0f,
};
constexpr uint16_t kQuadIndices[] = { 0, 1, 2, 2, 1, 3 };

void dropPending(UiOverlay* o);

void destroyTexture(UiOverlay* o) {
    if (o->texture) {
        o->engine->destroy(o->texture);
        o->texture = nullptr;
    }
    o->textureWidth = 0;
    o->textureHeight = 0;
}

} // namespace

void* filament_ui_overlay_create(void* engine_ptr) {
#ifdef __EMSCRIPTEN__
    // Direct presentation needs a native window: the web canvas is presented
    // by the browser.
    (void) engine_ptr;
    return nullptr;
#else
    if (!engine_ptr) return nullptr;
    auto* engine = reinterpret_cast<Engine*>(engine_ptr);
    auto* o = new UiOverlay();
    o->engine = engine;
    try {
        // One package per stereoscopic type: the engine's type picks it, as a
        // package of the other type draws nothing in a stereo view.
        const bool multiview =
                engine->getConfig().stereoscopicType == backend::StereoscopicType::MULTIVIEW;
        o->material = Material::Builder()
                .package(multiview ? flutter_filament::kUiOverlayMultiviewMaterialPackage
                                   : flutter_filament::kUiOverlayMaterialPackage,
                         multiview ? flutter_filament::kUiOverlayMultiviewMaterialPackageSize
                                   : flutter_filament::kUiOverlayMaterialPackageSize)
                .build(*engine);
        if (!o->material) {
            delete o;
            return nullptr;
        }
        o->instance = o->material->createInstance();

        o->vertices = VertexBuffer::Builder()
                .vertexCount(4)
                .bufferCount(1)
                .attribute(VertexAttribute::POSITION, 0, VertexBuffer::AttributeType::FLOAT4, 0, 16)
                .build(*engine);
        o->vertices->setBufferAt(*engine, 0, VertexBuffer::BufferDescriptor(kQuad, sizeof(kQuad), nullptr));
        o->indices = IndexBuffer::Builder()
                .indexCount(6)
                .bufferType(IndexBuffer::IndexType::USHORT)
                .build(*engine);
        o->indices->setBuffer(*engine, IndexBuffer::BufferDescriptor(kQuadIndices, sizeof(kQuadIndices), nullptr));

        auto& em = utils::EntityManager::get();
        o->quad = em.create();
        RenderableManager::Builder(1)
                .boundingBox({ { -1, -1, -1 }, { 1, 1, 1 } })
                .material(0, o->instance)
                .geometry(0, RenderableManager::PrimitiveType::TRIANGLES, o->vertices, o->indices, 0, 6)
                .culling(false)
                .castShadows(false)
                .receiveShadows(false)
                .build(*engine, o->quad);

        o->scene = engine->createScene();
        o->scene->addEntity(o->quad);
        o->cameraEntity = em.create();
        o->camera = engine->createCamera(o->cameraEntity);
        o->camera->setProjection(Camera::Projection::ORTHO, -1, 1, -1, 1, 0, 1);

        o->view = engine->createView();
        o->view->setName("UiOverlay");
        o->view->setScene(o->scene);
        o->view->setCamera(o->camera);
        // Blended over the SwapChain's content, written as sampled: no tone
        // mapping, anti-aliasing, dithering or shadows.
        o->view->setBlendMode(View::BlendMode::TRANSLUCENT);
        o->view->setPostProcessingEnabled(false);
        o->view->setShadowingEnabled(false);
        o->view->setAntiAliasing(View::AntiAliasing::NONE);
        o->view->setDithering(View::Dithering::NONE);
        o->view->setScreenSpaceRefractionEnabled(false);
        o->view->setFrustumCullingEnabled(false);
    } catch (...) {
        filament_ui_overlay_destroy(o);
        return nullptr;
    }
    return o;
#endif
}

void filament_ui_overlay_destroy(void* overlay) {
    if (!overlay) return;
    auto* o = reinterpret_cast<UiOverlay*>(overlay);
    Engine* engine = o->engine;
    try {
        if (o->view) engine->destroy(o->view);
        if (o->scene) engine->destroy(o->scene);
        if (o->camera) engine->destroyCameraComponent(o->cameraEntity);
        if (!o->quad.isNull()) {
            engine->destroy(o->quad);
            utils::EntityManager::get().destroy(o->quad);
        }
        if (!o->cameraEntity.isNull()) utils::EntityManager::get().destroy(o->cameraEntity);
        if (o->vertices) engine->destroy(o->vertices);
        if (o->indices) engine->destroy(o->indices);
        if (o->instance) engine->destroy(o->instance);
        if (o->material) engine->destroy(o->material);
        destroyTexture(o);
    } catch (...) {
    }
    dropPending(o);
    delete o;
}

void filament_ui_overlay_set_viewport(
        void* overlay, int32_t left, int32_t bottom, uint32_t width, uint32_t height) {
    if (!overlay) return;
    auto* o = reinterpret_cast<UiOverlay*>(overlay);
    o->view->setViewport(Viewport(left, bottom, width, height));
}

namespace {

// Gives [buffer] (malloc'd, width * height * 4 bytes) to the overlay's texture,
// recreating it on a size change; frees it on failure.
bool submit(UiOverlay* o, uint8_t* buffer, uint32_t width, uint32_t height,
        std::chrono::steady_clock::time_point start) {
    try {
        if (!o->texture || o->textureWidth != width || o->textureHeight != height) {
            destroyTexture(o);
            o->texture = Texture::Builder()
                    .width(width)
                    .height(height)
                    .levels(1)
                    .format(Texture::InternalFormat::RGBA8)
                    .sampler(Texture::Sampler::SAMPLER_2D)
                    .usage(Texture::Usage::DEFAULT)
                    .build(*o->engine);
            if (!o->texture) {
                std::free(buffer);
                return false;
            }
            o->textureWidth = width;
            o->textureHeight = height;
            TextureSampler sampler(TextureSampler::MinFilter::LINEAR, TextureSampler::MagFilter::LINEAR,
                    TextureSampler::WrapMode::CLAMP_TO_EDGE);
            o->instance->setParameter("ui", o->texture, sampler);
        }
        size_t const size = size_t(width) * height * 4;
        // The driver reads the pixels later and frees them then.
        Texture::PixelBufferDescriptor pixels(buffer, size, Texture::Format::RGBA, Texture::Type::UBYTE,
                [](void* b, size_t, void*) { std::free(b); });
        o->texture->setImage(*o->engine, 0, std::move(pixels));
        o->hasContent = true;
    } catch (...) {
        return false;
    }
    o->uploads++;
    o->lastUploadMicros = uint64_t(std::chrono::duration_cast<std::chrono::microseconds>(
            std::chrono::steady_clock::now() - start).count());
    return true;
}

void dropPending(UiOverlay* o) {
    std::free(o->pending);
    o->pending = nullptr;
    o->pendingWidth = 0;
    o->pendingHeight = 0;
}

} // namespace

bool filament_ui_overlay_upload(
        void* overlay, const uint8_t* rgba, uint32_t width, uint32_t height, uint32_t stride) {
    if (!overlay || !rgba || width == 0 || height == 0) return false;
    auto* o = reinterpret_cast<UiOverlay*>(overlay);
    auto const start = std::chrono::steady_clock::now();
    uint32_t const row = width * 4;
    if (stride == 0) stride = row;
    if (stride < row) return false;
    size_t const size = size_t(row) * height;
    auto* copy = static_cast<uint8_t*>(std::malloc(size));
    if (!copy) return false;
    if (stride == row) {
        std::memcpy(copy, rgba, size);
    } else {
        for (uint32_t y = 0; y < height; y++) {
            std::memcpy(copy + size_t(y) * row, rgba + size_t(y) * stride, row);
        }
    }
    return submit(o, copy, width, height, start);
}

uint8_t* filament_ui_overlay_begin_upload(void* overlay, uint32_t width, uint32_t height) {
    if (!overlay || width == 0 || height == 0) return nullptr;
    auto* o = reinterpret_cast<UiOverlay*>(overlay);
    dropPending(o);
    o->pendingStart = std::chrono::steady_clock::now();
    o->pending = static_cast<uint8_t*>(std::malloc(size_t(width) * height * 4));
    if (!o->pending) return nullptr;
    o->pendingWidth = width;
    o->pendingHeight = height;
    return o->pending;
}

bool filament_ui_overlay_end_upload(void* overlay) {
    if (!overlay) return false;
    auto* o = reinterpret_cast<UiOverlay*>(overlay);
    if (!o->pending) return false;
    uint8_t* buffer = o->pending;
    o->pending = nullptr;
    return submit(o, buffer, o->pendingWidth, o->pendingHeight, o->pendingStart);
}

void filament_ui_overlay_clear(void* overlay) {
    if (!overlay) return;
    reinterpret_cast<UiOverlay*>(overlay)->hasContent = false;
}

bool filament_ui_overlay_has_content(void* overlay) {
    return overlay && reinterpret_cast<UiOverlay*>(overlay)->hasContent;
}

bool filament_ui_overlay_render(void* renderer, void* overlay) {
    if (!renderer || !overlay) return false;
    auto* o = reinterpret_cast<UiOverlay*>(overlay);
    if (!o->hasContent || !o->texture) return false;
    try {
        reinterpret_cast<Renderer*>(renderer)->render(o->view);
    } catch (...) {
        return false;
    }
    return true;
}

void* filament_ui_overlay_get_view(void* overlay) {
    return overlay ? reinterpret_cast<UiOverlay*>(overlay)->view : nullptr;
}

uint64_t filament_ui_overlay_last_upload_micros(void* overlay) {
    return overlay ? reinterpret_cast<UiOverlay*>(overlay)->lastUploadMicros : 0;
}

uint64_t filament_ui_overlay_upload_count(void* overlay) {
    return overlay ? reinterpret_cast<UiOverlay*>(overlay)->uploads : 0;
}
