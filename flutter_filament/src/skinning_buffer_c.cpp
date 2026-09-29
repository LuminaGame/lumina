#include "skinning_buffer_c.h"
#include <filament/Engine.h>
#include <filament/SkinningBuffer.h>
#include <math/mat4.h>

using namespace filament;
using namespace filament::math;

extern "C" {

void* filament_skinning_buffer_create(void* engine, uint32_t bone_count, bool initialize) {
    auto* e = static_cast<Engine*>(engine);
    auto builder = SkinningBuffer::Builder()
                       .boneCount(bone_count)
                       .initialize(initialize);
    return builder.build(*e);
}

void filament_skinning_buffer_set_bones(void* engine, void* skinning_buffer, const FilamentBone* bones, uint32_t count, uint32_t offset) {
    auto* e = static_cast<Engine*>(engine);
    auto* sb = static_cast<SkinningBuffer*>(skinning_buffer);
    
    // FilamentBone matches math::mat4f + quatf (or math::details::TMat44<float> etc.),
    // but the filament SkinningBuffer accepts a pointer to an internal struct which is identical to FilamentBone.
    // Wait, SkinningBuffer::setBones accepts:
    // setBones(Engine& engine, RenderableManager::Bone const* transforms, size_t count, size_t offset)
    // RenderableManager::Bone is equivalent to our FilamentBone.
    sb->setBones(*e, reinterpret_cast<const RenderableManager::Bone*>(bones), count, offset);
}

void filament_skinning_buffer_set_bones_matrices(void* engine, void* skinning_buffer, const float* transforms, uint32_t count, uint32_t offset) {
    auto* e = static_cast<Engine*>(engine);
    auto* sb = static_cast<SkinningBuffer*>(skinning_buffer);
    
    sb->setBones(*e, reinterpret_cast<const mat4f*>(transforms), count, offset);
}

uint32_t filament_skinning_buffer_get_bone_count(void* skinning_buffer) {
    auto* sb = static_cast<SkinningBuffer*>(skinning_buffer);
    return sb->getBoneCount();
}

void filament_engine_destroy_skinning_buffer(void* engine, void* skinning_buffer) {
    auto* e = static_cast<Engine*>(engine);
    auto* sb = static_cast<SkinningBuffer*>(skinning_buffer);
    e->destroy(sb);
}

}
