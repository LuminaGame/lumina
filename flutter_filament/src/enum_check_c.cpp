/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

#include "enum_check_c.h"

#include <backend/DriverEnums.h>
#include <filament/Engine.h>
#include <filament/IndexBuffer.h>
#include <filament/LightManager.h>
#include <filament/RenderableManager.h>
#include <filament/Texture.h>
#include <filamat/MaterialBuilder.h>
#include <camutils/Manipulator.h>

using namespace filament;
using namespace filament::backend;

int32_t filament_enum_primitive_type(int32_t ordinal) {
    switch (ordinal) {
        case 0: return static_cast<int32_t>(PrimitiveType::POINTS);
        case 1: return static_cast<int32_t>(PrimitiveType::LINES);
        case 2: return static_cast<int32_t>(PrimitiveType::LINE_STRIP);
        case 3: return static_cast<int32_t>(PrimitiveType::TRIANGLES);
        case 4: return static_cast<int32_t>(PrimitiveType::TRIANGLE_STRIP);
        default: return -1;
    }
}

int32_t filament_enum_index_type(int32_t ordinal) {
    switch (ordinal) {
        case 0: return static_cast<int32_t>(ElementType::USHORT);
        case 1: return static_cast<int32_t>(ElementType::UINT);
        default: return -1;
    }
}

uint32_t filament_enum_texture_usage(int32_t ordinal) {
    switch (ordinal) {
        case 0: return static_cast<uint32_t>(TextureUsage::NONE);
        case 1: return static_cast<uint32_t>(TextureUsage::COLOR_ATTACHMENT);
        case 2: return static_cast<uint32_t>(TextureUsage::DEPTH_ATTACHMENT);
        case 3: return static_cast<uint32_t>(TextureUsage::STENCIL_ATTACHMENT);
        case 4: return static_cast<uint32_t>(TextureUsage::UPLOADABLE);
        case 5: return static_cast<uint32_t>(TextureUsage::SAMPLEABLE);
        case 6: return static_cast<uint32_t>(TextureUsage::SUBPASS_INPUT);
        case 7: return static_cast<uint32_t>(TextureUsage::BLIT_SRC);
        case 8: return static_cast<uint32_t>(TextureUsage::BLIT_DST);
        case 9: return static_cast<uint32_t>(TextureUsage::PROTECTED);
        case 10: return static_cast<uint32_t>(TextureUsage::GEN_MIPMAPPABLE);
        case 11: return static_cast<uint32_t>(TextureUsage::DEFAULT);
        default: return 0;
    }
}

int32_t filament_enum_builder_result(int32_t ordinal) {
    switch (ordinal) {
        case 0: return static_cast<int32_t>(RenderableManager::Builder::Result::Error);
        case 1: return static_cast<int32_t>(RenderableManager::Builder::Result::Success);
        default: return -999;
    }
}

uint32_t filament_enum_morph_type(int32_t ordinal) {
    switch (ordinal) {
        case 0: return static_cast<uint32_t>(RenderableManager::Builder::MorphType::NONE);
        case 1: return static_cast<uint32_t>(RenderableManager::Builder::MorphType::POSITION);
        case 2: return static_cast<uint32_t>(RenderableManager::Builder::MorphType::TANGENT);
        case 3: return static_cast<uint32_t>(RenderableManager::Builder::MorphType::CUSTOM);
        default: return 0;
    }
}

int32_t filament_enum_backend(int32_t ordinal) {
    return ordinal;
}

int32_t filament_enum_light_type(int32_t ordinal) {
    switch (ordinal) {
        case 0: return static_cast<int32_t>(LightManager::Type::SUN);
        case 1: return static_cast<int32_t>(LightManager::Type::DIRECTIONAL);
        case 2: return static_cast<int32_t>(LightManager::Type::POINT);
        case 3: return static_cast<int32_t>(LightManager::Type::FOCUSED_SPOT);
        case 4: return static_cast<int32_t>(LightManager::Type::SPOT);
        default: return -1;
    }
}

int32_t filament_enum_manipulator_mode(int32_t ordinal) {
    switch (ordinal) {
        case 0: return static_cast<int32_t>(camutils::Mode::ORBIT);
        case 1: return static_cast<int32_t>(camutils::Mode::MAP);
        case 2: return static_cast<int32_t>(camutils::Mode::FREE_FLIGHT);
        default: return -1;
    }
}

int32_t filament_enum_filamat_shading(int32_t ordinal) {
    switch (ordinal) {
        case 0: return static_cast<int32_t>(filamat::MaterialBuilder::Shading::UNLIT);
        case 1: return static_cast<int32_t>(filamat::MaterialBuilder::Shading::LIT);
        case 2: return static_cast<int32_t>(filamat::MaterialBuilder::Shading::SUBSURFACE);
        case 3: return static_cast<int32_t>(filamat::MaterialBuilder::Shading::CLOTH);
        case 4: return static_cast<int32_t>(filamat::MaterialBuilder::Shading::SPECULAR_GLOSSINESS);
        default: return -1;
    }
}

int32_t filament_enum_texture_format(int32_t ordinal) {
    switch (ordinal) {
        case 0: return static_cast<int32_t>(Texture::InternalFormat::RGB8);
        case 1: return static_cast<int32_t>(Texture::InternalFormat::RGBA8);
        case 2: return static_cast<int32_t>(Texture::InternalFormat::RGBA16F);
        case 3: return static_cast<int32_t>(Texture::InternalFormat::RGBA32F);
        case 4: return static_cast<int32_t>(Texture::InternalFormat::DEPTH24);
        default: return -1;
    }
}

int32_t filament_enum_internal_format(int32_t ordinal) {
    if (ordinal < 0 || ordinal > 108) return -1;
    return static_cast<int32_t>(static_cast<backend::TextureFormat>(ordinal));
}

int32_t filament_enum_sampler_type(int32_t ordinal) {
    switch (ordinal) {
        case 0: return static_cast<int32_t>(backend::SamplerType::SAMPLER_2D);
        case 1: return static_cast<int32_t>(backend::SamplerType::SAMPLER_2D_ARRAY);
        case 2: return static_cast<int32_t>(backend::SamplerType::SAMPLER_CUBEMAP);
        case 3: return static_cast<int32_t>(backend::SamplerType::SAMPLER_EXTERNAL);
        case 4: return static_cast<int32_t>(backend::SamplerType::SAMPLER_3D);
        case 5: return static_cast<int32_t>(backend::SamplerType::SAMPLER_CUBEMAP_ARRAY);
        default: return -1;
    }
}

int32_t filament_enum_texture_swizzle(int32_t ordinal) {
    switch (ordinal) {
        case 0: return static_cast<int32_t>(backend::TextureSwizzle::SUBSTITUTE_ZERO);
        case 1: return static_cast<int32_t>(backend::TextureSwizzle::SUBSTITUTE_ONE);
        case 2: return static_cast<int32_t>(backend::TextureSwizzle::CHANNEL_0);
        case 3: return static_cast<int32_t>(backend::TextureSwizzle::CHANNEL_1);
        case 4: return static_cast<int32_t>(backend::TextureSwizzle::CHANNEL_2);
        case 5: return static_cast<int32_t>(backend::TextureSwizzle::CHANNEL_3);
        default: return -1;
    }
}

int32_t filament_enum_pixel_format(int32_t ordinal) {
    if (ordinal < 0 || ordinal > 11) return -1;
    return static_cast<int32_t>(static_cast<backend::PixelDataFormat>(ordinal));
}

int32_t filament_enum_pixel_type(int32_t ordinal) {
    if (ordinal < 0 || ordinal > 11) return -1;
    return static_cast<int32_t>(static_cast<backend::PixelDataType>(ordinal));
}

int32_t filament_enum_attribute_type(int32_t ordinal) {
    if (ordinal < 0 || ordinal > 25) return -1;
    return static_cast<int32_t>(static_cast<backend::ElementType>(ordinal));
}

int32_t filament_enum_vertex_attribute(int32_t ordinal) {
    if (ordinal < 0 || ordinal > 15 || ordinal == 7) return -1;
    return static_cast<int32_t>(static_cast<VertexAttribute>(ordinal));
}

int32_t filament_enum_uniform_type(int32_t ordinal) {
    if (ordinal < 0 || ordinal > 18) return -1;
    return static_cast<int32_t>(static_cast<backend::UniformType>(ordinal));
}

int32_t filament_enum_precision(int32_t ordinal) {
    if (ordinal < 0 || ordinal > 3) return -1;
    return static_cast<int32_t>(static_cast<backend::Precision>(ordinal));
}

int32_t filament_enum_culling_mode(int32_t ordinal) {
    if (ordinal < 0 || ordinal > 3) return -1;
    return static_cast<int32_t>(static_cast<backend::CullingMode>(ordinal));
}

int32_t filament_enum_depth_func(int32_t ordinal) {
    if (ordinal < 0 || ordinal > 7) return -1;
    return static_cast<int32_t>(static_cast<backend::SamplerCompareFunc>(ordinal));
}

int32_t filament_enum_transparency_mode(int32_t ordinal) {
    if (ordinal < 0 || ordinal > 2) return -1;
    return static_cast<int32_t>(static_cast<TransparencyMode>(ordinal));
}
