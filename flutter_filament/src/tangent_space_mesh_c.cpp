#include "tangent_space_mesh_c.h"
#include <geometry/TangentSpaceMesh.h>

using namespace filament::math;
using namespace filament::geometry;

struct FilTsmBuilder {
    TangentSpaceMesh::Builder builder;
};

struct FilTangentSpaceMesh {
    TangentSpaceMesh* mesh;
};

extern "C" {

FilTsmBuilder* filament_tsm_builder_create(void) {
    return new FilTsmBuilder();
}

void filament_tsm_builder_destroy(FilTsmBuilder* b) {
    delete b;
}

void filament_tsm_builder_vertex_count(FilTsmBuilder* b, uint32_t count) {
    b->builder.vertexCount(count);
}

void filament_tsm_builder_normals(FilTsmBuilder* b, const float* normals, size_t stride_bytes) {
    b->builder.normals(reinterpret_cast<const float3*>(normals), stride_bytes);
}

void filament_tsm_builder_tangents(FilTsmBuilder* b, const float* tangents, size_t stride_bytes) {
    b->builder.tangents(reinterpret_cast<const float4*>(tangents), stride_bytes);
}

void filament_tsm_builder_uvs(FilTsmBuilder* b, const float* uvs, size_t stride_bytes) {
    b->builder.uvs(reinterpret_cast<const float2*>(uvs), stride_bytes);
}

void filament_tsm_builder_positions(FilTsmBuilder* b, const float* positions, size_t stride_bytes) {
    b->builder.positions(reinterpret_cast<const float3*>(positions), stride_bytes);
}

void filament_tsm_builder_triangle_count(FilTsmBuilder* b, uint32_t count) {
    b->builder.triangleCount(count);
}

void filament_tsm_builder_triangles_uint3(FilTsmBuilder* b, const uint32_t* tris) {
    b->builder.triangles(reinterpret_cast<const uint3*>(tris));
}

void filament_tsm_builder_triangles_ushort3(FilTsmBuilder* b, const uint16_t* tris) {
    b->builder.triangles(reinterpret_cast<const ushort3*>(tris));
}

void filament_tsm_builder_aux(FilTsmBuilder* b, int attribute, const void* data, int type, size_t stride_bytes) {
    TangentSpaceMesh::AuxAttribute attr = static_cast<TangentSpaceMesh::AuxAttribute>(attribute);
    
    switch (type) {
        case 0: // float2
            b->builder.aux(attr, reinterpret_cast<const float2*>(data), stride_bytes);
            break;
        case 1: // float3
            b->builder.aux(attr, reinterpret_cast<const float3*>(data), stride_bytes);
            break;
        case 2: // float4
            b->builder.aux(attr, reinterpret_cast<const float4*>(data), stride_bytes);
            break;
        case 3: // ushort3
            b->builder.aux(attr, reinterpret_cast<const ushort3*>(data), stride_bytes);
            break;
        case 4: // ushort4
            b->builder.aux(attr, reinterpret_cast<const ushort4*>(data), stride_bytes);
            break;
    }
}

void filament_tsm_builder_algorithm(FilTsmBuilder* b, int algorithm) {
    b->builder.algorithm(static_cast<TangentSpaceMesh::Algorithm>(algorithm));
}

FilTangentSpaceMesh* filament_tsm_builder_build(FilTsmBuilder* b) {
    TangentSpaceMesh* mesh = b->builder.build();
    if (!mesh) return nullptr;
    
    FilTangentSpaceMesh* wrapper = new FilTangentSpaceMesh();
    wrapper->mesh = mesh;
    return wrapper;
}

uint32_t filament_tsm_get_vertex_count(const FilTangentSpaceMesh* m) {
    return m->mesh->getVertexCount();
}

uint32_t filament_tsm_get_triangle_count(const FilTangentSpaceMesh* m) {
    return m->mesh->getTriangleCount();
}

bool filament_tsm_remeshed(const FilTangentSpaceMesh* m) {
    return m->mesh->remeshed();
}

void filament_tsm_get_positions(const FilTangentSpaceMesh* m, float* out, size_t stride_bytes) {
    m->mesh->getPositions(reinterpret_cast<float3*>(out), stride_bytes);
}

void filament_tsm_get_uvs(const FilTangentSpaceMesh* m, float* out, size_t stride_bytes) {
    m->mesh->getUVs(reinterpret_cast<float2*>(out), stride_bytes);
}

void filament_tsm_get_quats_float4(const FilTangentSpaceMesh* m, float* out, size_t stride_bytes) {
    m->mesh->getQuats(reinterpret_cast<quatf*>(out), stride_bytes);
}

void filament_tsm_get_quats_short4(const FilTangentSpaceMesh* m, int16_t* out, size_t stride_bytes) {
    m->mesh->getQuats(reinterpret_cast<short4*>(out), stride_bytes);
}

void filament_tsm_get_quats_half4(const FilTangentSpaceMesh* m, uint16_t* out, size_t stride_bytes) {
    m->mesh->getQuats(reinterpret_cast<quath*>(out), stride_bytes);
}

void filament_tsm_get_triangles_uint3(const FilTangentSpaceMesh* m, uint32_t* out) {
    m->mesh->getTriangles(reinterpret_cast<uint3*>(out));
}

void filament_tsm_get_aux(const FilTangentSpaceMesh* m, int attribute, void* out, int type, size_t stride_bytes) {
    TangentSpaceMesh::AuxAttribute attr = static_cast<TangentSpaceMesh::AuxAttribute>(attribute);
    
    switch (type) {
        case 0: // float2
            m->mesh->getAux(attr, reinterpret_cast<float2*>(out), stride_bytes);
            break;
        case 1: // float3
            m->mesh->getAux(attr, reinterpret_cast<float3*>(out), stride_bytes);
            break;
        case 2: // float4
            m->mesh->getAux(attr, reinterpret_cast<float4*>(out), stride_bytes);
            break;
        case 3: // ushort3
            m->mesh->getAux(attr, reinterpret_cast<ushort3*>(out), stride_bytes);
            break;
        case 4: // ushort4
            m->mesh->getAux(attr, reinterpret_cast<ushort4*>(out), stride_bytes);
            break;
    }
}

void filament_tsm_destroy(FilTangentSpaceMesh* m) {
    if (m) {
        if (m->mesh) {
            TangentSpaceMesh::destroy(m->mesh);
        }
        delete m;
    }
}

} // extern "C"
