#ifndef FLUTTER_FILAMENT_TANGENT_SPACE_MESH_C_H
#define FLUTTER_FILAMENT_TANGENT_SPACE_MESH_C_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#if _WIN32
#define FFI_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FFI_PLUGIN_EXPORT
#endif

#ifdef __cplusplus
extern "C" {
#endif

typedef struct FilTsmBuilder FilTsmBuilder;
typedef struct FilTangentSpaceMesh FilTangentSpaceMesh;

FFI_PLUGIN_EXPORT FilTsmBuilder* filament_tsm_builder_create(void);
FFI_PLUGIN_EXPORT void filament_tsm_builder_destroy(FilTsmBuilder* b);

FFI_PLUGIN_EXPORT void filament_tsm_builder_vertex_count(FilTsmBuilder* b, uint32_t count);
FFI_PLUGIN_EXPORT void filament_tsm_builder_normals(FilTsmBuilder* b, const float* normals, size_t stride_bytes);
FFI_PLUGIN_EXPORT void filament_tsm_builder_tangents(FilTsmBuilder* b, const float* tangents, size_t stride_bytes);
FFI_PLUGIN_EXPORT void filament_tsm_builder_uvs(FilTsmBuilder* b, const float* uvs, size_t stride_bytes);
FFI_PLUGIN_EXPORT void filament_tsm_builder_positions(FilTsmBuilder* b, const float* positions, size_t stride_bytes);

FFI_PLUGIN_EXPORT void filament_tsm_builder_triangle_count(FilTsmBuilder* b, uint32_t count);
FFI_PLUGIN_EXPORT void filament_tsm_builder_triangles_uint3(FilTsmBuilder* b, const uint32_t* tris);
FFI_PLUGIN_EXPORT void filament_tsm_builder_triangles_ushort3(FilTsmBuilder* b, const uint16_t* tris);

FFI_PLUGIN_EXPORT void filament_tsm_builder_aux(FilTsmBuilder* b, int attribute, const void* data, int type, size_t stride_bytes);
FFI_PLUGIN_EXPORT void filament_tsm_builder_algorithm(FilTsmBuilder* b, int algorithm);

FFI_PLUGIN_EXPORT FilTangentSpaceMesh* filament_tsm_builder_build(FilTsmBuilder* b);

FFI_PLUGIN_EXPORT uint32_t filament_tsm_get_vertex_count(const FilTangentSpaceMesh* m);
FFI_PLUGIN_EXPORT uint32_t filament_tsm_get_triangle_count(const FilTangentSpaceMesh* m);
FFI_PLUGIN_EXPORT bool filament_tsm_remeshed(const FilTangentSpaceMesh* m);

FFI_PLUGIN_EXPORT void filament_tsm_get_positions(const FilTangentSpaceMesh* m, float* out, size_t stride_bytes);
FFI_PLUGIN_EXPORT void filament_tsm_get_uvs(const FilTangentSpaceMesh* m, float* out, size_t stride_bytes);
FFI_PLUGIN_EXPORT void filament_tsm_get_quats_float4(const FilTangentSpaceMesh* m, float* out, size_t stride_bytes);
FFI_PLUGIN_EXPORT void filament_tsm_get_quats_short4(const FilTangentSpaceMesh* m, int16_t* out, size_t stride_bytes);
FFI_PLUGIN_EXPORT void filament_tsm_get_quats_half4(const FilTangentSpaceMesh* m, uint16_t* out, size_t stride_bytes);
FFI_PLUGIN_EXPORT void filament_tsm_get_triangles_uint3(const FilTangentSpaceMesh* m, uint32_t* out);

// type: 0 = float2, 1 = float3, 2 = float4, 3 = ushort3, 4 = ushort4
FFI_PLUGIN_EXPORT void filament_tsm_get_aux(const FilTangentSpaceMesh* m, int attribute, void* out, int type, size_t stride_bytes);

FFI_PLUGIN_EXPORT void filament_tsm_destroy(FilTangentSpaceMesh* m);

#ifdef __cplusplus
}
#endif

#endif // FLUTTER_FILAMENT_TANGENT_SPACE_MESH_C_H
