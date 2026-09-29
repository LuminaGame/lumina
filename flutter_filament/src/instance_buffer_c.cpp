#include "instance_buffer_c.h"
#include <filament/Engine.h>
#include <filament/InstanceBuffer.h>
#include <math/mat4.h>
#include <cstring>

using namespace filament;
using namespace filament::math;

extern "C" {

void* filament_instance_buffer_create(void* engine, uint32_t instance_count, const float* initial_transforms) {
    auto* e = static_cast<Engine*>(engine);
    auto builder = InstanceBuffer::Builder(instance_count);
    if (initial_transforms != nullptr) {
        builder.localTransforms(reinterpret_cast<const mat4f*>(initial_transforms));
    }
    return builder.build(*e);
}

void filament_instance_buffer_set_local_transforms(void* instance_buffer, const float* transforms, uint32_t count, uint32_t offset) {
    auto* ib = static_cast<InstanceBuffer*>(instance_buffer);
    ib->setLocalTransforms(reinterpret_cast<const mat4f*>(transforms), count, offset);
}

void filament_instance_buffer_get_local_transform(void* instance_buffer, uint32_t index, float* out_matrix) {
    auto* ib = static_cast<InstanceBuffer*>(instance_buffer);
    const mat4f& m = ib->getLocalTransform(index);
    std::memcpy(out_matrix, &m, sizeof(mat4f));
}

uint32_t filament_instance_buffer_get_instance_count(void* instance_buffer) {
    auto* ib = static_cast<InstanceBuffer*>(instance_buffer);
    return static_cast<uint32_t>(ib->getInstanceCount());
}

}
