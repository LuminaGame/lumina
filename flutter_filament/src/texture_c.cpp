/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

#include "texture_c.h"
#include <filament/Texture.h>
#include <filament/Engine.h>
#include <backend/DriverEnums.h>
#include <backend/PixelBufferDescriptor.h>
#include <utils/Panic.h>
#include <algorithm>
#include <cstring>
#include <cstdlib>
#include <cstdio>
#include <exception>

using namespace filament;

#define FFI_TRY try {
#define FFI_CATCH(return_value)                                                \
  }                                                                            \
  catch (const utils::Panic &e) {                                              \
    fprintf(stderr, "[Filament C++ Panic (Handled Safely)]: %s\n", e.what());  \
    return return_value;                                                       \
  }                                                                            \
  catch (const std::exception &e) {                                            \
    fprintf(stderr, "[Filament C++ Exception (Handled Safely)]: %s\n",         \
            e.what());                                                         \
    return return_value;                                                       \
  }                                                                            \
  catch (...) {                                                                \
    fprintf(stderr, "[Filament C++ Unknown Exception (Handled Safely)]\n");    \
    return return_value;                                                       \
  }

#define FFI_CATCH_VOID()                                                       \
  }                                                                            \
  catch (const utils::Panic &e) {                                              \
    fprintf(stderr, "[Filament C++ Panic (Handled Safely)]: %s\n", e.what());  \
    return;                                                                    \
  }                                                                            \
  catch (const std::exception &e) {                                            \
    fprintf(stderr, "[Filament C++ Exception (Handled Safely)]: %s\n",         \
            e.what());                                                         \
    return;                                                                    \
  }                                                                            \
  catch (...) {                                                                \
    fprintf(stderr, "[Filament C++ Unknown Exception (Handled Safely)]\n");    \
    return;                                                                    \
  }

static inline Engine* toEngine(void* ptr) {
    return reinterpret_cast<Engine*>(ptr);
}

static inline Texture* toTexture(void* ptr) {
    return reinterpret_cast<Texture*>(ptr);
}

void* filament_texture_create(void* engine, const FilamentTextureDesc* desc) {
    FFI_TRY
    if (!engine || !desc) return nullptr;
    Texture::Builder builder;
    builder.width(desc->width > 0 ? desc->width : 1)
           .height(desc->height > 0 ? desc->height : 1)
           .depth(desc->depth > 0 ? desc->depth : 1)
           .levels(desc->levels > 0 ? desc->levels : 1)
           .sampler(static_cast<backend::SamplerType>(desc->sampler_type))
           .format(static_cast<backend::TextureFormat>(desc->internal_format));

    if (desc->samples > 1) {
        builder.samples(desc->samples);
    }
    if (desc->usage != 0) {
        builder.usage(static_cast<backend::TextureUsage>(desc->usage));
    }
    if (desc->has_swizzle) {
        builder.swizzle(
            static_cast<backend::TextureSwizzle>(desc->swizzle[0]),
            static_cast<backend::TextureSwizzle>(desc->swizzle[1]),
            static_cast<backend::TextureSwizzle>(desc->swizzle[2]),
            static_cast<backend::TextureSwizzle>(desc->swizzle[3])
        );
    }
    if (desc->import_handle != 0) {
        builder.import(desc->import_handle);
    }
    return builder.build(*toEngine(engine));
    FFI_CATCH(nullptr)
}

void* filament_texture_create_2d(void* engine, uint32_t width, uint32_t height, int format, uint8_t levels) {
    FilamentTextureDesc desc = {};
    desc.width = width;
    desc.height = height;
    desc.depth = 1;
    desc.levels = levels;
    desc.sampler_type = 0; // SAMPLER_2D
    desc.internal_format = format;
    desc.usage = 0;
    desc.samples = 1;
    desc.has_swizzle = false;
    desc.import_handle = 0;
    return filament_texture_create(engine, &desc);
}

#include "buffer_descriptor_c.h"

void filament_texture_set_image_ex(
    void* engine,
    void* texture,
    uint8_t level,
    uint32_t xoffset,
    uint32_t yoffset,
    uint32_t zoffset,
    uint32_t width,
    uint32_t height,
    uint32_t depth,
    int32_t pixel_format,
    int32_t pixel_type,
    uint32_t stride,
    uint8_t alignment,
    void* data,
    size_t size,
    filament_buffer_free_fn cb,
    void* user
) {
    FFI_TRY
    if (!engine || !texture || !data || size == 0) return;
    auto* t = toTexture(texture);
    auto* e = toEngine(engine);

    auto pb = makePixelBufferDescriptor(data, size, pixel_format, pixel_type, stride, alignment, cb, user);
    t->setImage(*e, level, xoffset, yoffset, zoffset, width, height, depth, std::move(pb));
    FFI_CATCH_VOID()
}

void filament_texture_set_image(
    void* engine,
    void* texture,
    uint32_t level,
    const void* data,
    uint32_t size_in_bytes,
    uint32_t width,
    uint32_t height,
    int pixel_format,
    int pixel_type
) {
    if (!data || size_in_bytes == 0) return;
    void* copy = malloc(size_in_bytes);
    if (!copy) return;
    memcpy(copy, data, size_in_bytes);
    filament_texture_set_image_ex(
        engine, texture, level, 0, 0, 0, width, height, 1,
        pixel_format, pixel_type, 0, 1,
        copy, size_in_bytes,
        [](void* buffer, size_t, void*) { free(buffer); },
        nullptr
    );
}

void filament_engine_destroy_texture(void* engine, void* texture) {
    FFI_TRY
    if (!engine || !texture) return;
    toEngine(engine)->destroy(toTexture(texture));
    FFI_CATCH_VOID()
}

void filament_texture_generate_mipmaps(void* engine, void* texture) {
    FFI_TRY
    if (!engine || !texture) return;
    toTexture(texture)->generateMipmaps(*toEngine(engine));
    FFI_CATCH_VOID()
}

uint32_t filament_texture_get_width(void* texture, uint8_t level) {
    FFI_TRY
    if (!texture) return 0;
    return static_cast<uint32_t>(toTexture(texture)->getWidth(level));
    FFI_CATCH(0)
}

uint32_t filament_texture_get_height(void* texture, uint8_t level) {
    FFI_TRY
    if (!texture) return 0;
    return static_cast<uint32_t>(toTexture(texture)->getHeight(level));
    FFI_CATCH(0)
}

uint32_t filament_texture_get_depth(void* texture, uint8_t level) {
    FFI_TRY
    if (!texture) return 0;
    return static_cast<uint32_t>(toTexture(texture)->getDepth(level));
    FFI_CATCH(0)
}

uint8_t filament_texture_get_levels(void* texture) {
    FFI_TRY
    if (!texture) return 0;
    return static_cast<uint8_t>(toTexture(texture)->getLevels());
    FFI_CATCH(0)
}

int32_t filament_texture_get_target(void* texture) {
    FFI_TRY
    if (!texture) return 0;
    return static_cast<int32_t>(toTexture(texture)->getTarget());
    FFI_CATCH(0)
}

int32_t filament_texture_get_format(void* texture) {
    FFI_TRY
    if (!texture) return 0;
    return static_cast<int32_t>(toTexture(texture)->getFormat());
    FFI_CATCH(0)
}

bool filament_texture_is_format_supported(void* engine, int32_t internal_format) {
    FFI_TRY
    if (!engine) return false;
    return Texture::isTextureFormatSupported(
        *toEngine(engine),
        static_cast<backend::TextureFormat>(internal_format)
    );
    FFI_CATCH(false)
}

bool filament_texture_is_format_mipmappable(void* engine, int32_t internal_format) {
    FFI_TRY
    if (!engine) return false;
    return Texture::isTextureFormatMipmappable(
        *toEngine(engine),
        static_cast<backend::TextureFormat>(internal_format)
    );
    FFI_CATCH(false)
}

bool filament_texture_is_format_compressed(int32_t internal_format) {
    FFI_TRY
    return Texture::isTextureFormatCompressed(
        static_cast<backend::TextureFormat>(internal_format)
    );
    FFI_CATCH(false)
}

size_t filament_texture_compute_data_size(
    int32_t pixel_format,
    int32_t pixel_type,
    uint32_t stride,
    uint32_t height,
    uint8_t alignment
) {
    FFI_TRY
    return Texture::computeTextureDataSize(
        static_cast<backend::PixelDataFormat>(pixel_format),
        static_cast<backend::PixelDataType>(pixel_type),
        stride,
        height,
        alignment > 0 ? alignment : 1
    );
    FFI_CATCH(0)
}

uint32_t filament_texture_get_max_size(void* engine, int32_t sampler_type) {
    FFI_TRY
    if (!engine) return 0;
    return static_cast<uint32_t>(Texture::getMaxTextureSize(
        *toEngine(engine),
        static_cast<backend::SamplerType>(sampler_type)
    ));
    FFI_CATCH(0)
}

uint32_t filament_texture_get_max_array_layers(void* engine) {
    FFI_TRY
    if (!engine) return 0;
    return static_cast<uint32_t>(Texture::getMaxArrayTextureLayers(*toEngine(engine)));
    FFI_CATCH(0)
}
