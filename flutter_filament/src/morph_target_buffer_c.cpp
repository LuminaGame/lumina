#include "morph_target_buffer_c.h"
#include <filament/Engine.h>
#include <filament/MorphTargetBuffer.h>
#include <math/vec3.h>
#include <math/vec4.h>

using namespace filament;
using namespace filament::math;

extern "C" {

void* filament_morph_target_buffer_create(void* engine, uint32_t vertex_count, uint32_t target_count, bool with_positions, bool with_tangents, bool custom_morphing) {
    auto* e = static_cast<Engine*>(engine);
    auto builder = MorphTargetBuffer::Builder()
                       .vertexCount(vertex_count)
                       .count(target_count)
                       .withPositions(with_positions)
                       .withTangents(with_tangents)
                       .enableCustomMorphing(custom_morphing);
    return builder.build(*e);
}

void filament_morph_target_buffer_set_positions_at_float3(void* engine, void* mtb, uint32_t target_index, const float* positions, uint32_t count, uint32_t offset) {
    auto* e = static_cast<Engine*>(engine);
    auto* b = static_cast<MorphTargetBuffer*>(mtb);
    b->setPositionsAt(*e, target_index, reinterpret_cast<const float3*>(positions), count, offset);
}

void filament_morph_target_buffer_set_positions_at_float4(void* engine, void* mtb, uint32_t target_index, const float* positions, uint32_t count, uint32_t offset) {
    auto* e = static_cast<Engine*>(engine);
    auto* b = static_cast<MorphTargetBuffer*>(mtb);
    b->setPositionsAt(*e, target_index, reinterpret_cast<const float4*>(positions), count, offset);
}

void filament_morph_target_buffer_set_tangents_at(void* engine, void* mtb, uint32_t target_index, const int16_t* tangents, uint32_t count, uint32_t offset) {
    auto* e = static_cast<Engine*>(engine);
    auto* b = static_cast<MorphTargetBuffer*>(mtb);
    b->setTangentsAt(*e, target_index, reinterpret_cast<const short4*>(tangents), count, offset);
}

uint32_t filament_morph_target_buffer_get_vertex_count(void* mtb) {
    auto* b = static_cast<MorphTargetBuffer*>(mtb);
    return static_cast<uint32_t>(b->getVertexCount());
}

uint32_t filament_morph_target_buffer_get_count(void* mtb) {
    auto* b = static_cast<MorphTargetBuffer*>(mtb);
    return static_cast<uint32_t>(b->getCount());
}

bool filament_morph_target_buffer_has_positions(void* mtb) {
    auto* b = static_cast<MorphTargetBuffer*>(mtb);
    return b->hasPositions();
}

bool filament_morph_target_buffer_has_tangents(void* mtb) {
    auto* b = static_cast<MorphTargetBuffer*>(mtb);
    return b->hasTangents();
}

bool filament_morph_target_buffer_is_custom_morphing_enabled(void* mtb) {
    auto* b = static_cast<MorphTargetBuffer*>(mtb);
    return b->isCustomMorphingEnabled();
}

}
