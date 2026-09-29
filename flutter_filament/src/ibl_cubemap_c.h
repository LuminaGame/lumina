#ifndef FILAMENT_IBL_CUBEMAP_C_H
#define FILAMENT_IBL_CUBEMAP_C_H

#include "linear_image_c.h"
#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#ifndef FFI_PLUGIN_EXPORT
#if defined(_WIN32)
#define FFI_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FFI_PLUGIN_EXPORT
#endif
#endif

#ifdef __cplusplus
extern "C" {
#endif

typedef struct FilIblImage FilIblImage;
typedef struct FilIblCubemap FilIblCubemap;

enum FilCubemapFace {
    FIL_CUBEMAP_FACE_PX = 0,
    FIL_CUBEMAP_FACE_NX = 1,
    FIL_CUBEMAP_FACE_PY = 2,
    FIL_CUBEMAP_FACE_NY = 3,
    FIL_CUBEMAP_FACE_PZ = 4,
    FIL_CUBEMAP_FACE_NZ = 5,
};

// IblImage
FFI_PLUGIN_EXPORT FilIblImage* filament_ibl_image_create(size_t w, size_t h);
FFI_PLUGIN_EXPORT void filament_ibl_image_destroy(FilIblImage* img);
FFI_PLUGIN_EXPORT size_t filament_ibl_image_get_width(const FilIblImage* img);
FFI_PLUGIN_EXPORT size_t filament_ibl_image_get_height(const FilIblImage* img);
FFI_PLUGIN_EXPORT float* filament_ibl_image_get_data(FilIblImage* img);
/// Row stride in bytes; larger than width*3*sizeof(float) for cubemap face sub-images.
FFI_PLUGIN_EXPORT size_t filament_ibl_image_get_bytes_per_row(const FilIblImage* img);
FFI_PLUGIN_EXPORT FilIblImage* filament_ibl_image_from_linear_image(const FilLinearImage* img);
FFI_PLUGIN_EXPORT FilLinearImage* filament_ibl_image_to_linear_image(const FilIblImage* img);

// IblCubemap
FFI_PLUGIN_EXPORT FilIblCubemap* filament_cubemap_create(size_t dim);
FFI_PLUGIN_EXPORT void filament_cubemap_destroy(FilIblCubemap* cm);
FFI_PLUGIN_EXPORT size_t filament_cubemap_get_dimensions(const FilIblCubemap* cm);
FFI_PLUGIN_EXPORT FilIblImage* filament_cubemap_get_face_image(FilIblCubemap* cm, int face);

// CubemapUtils
FFI_PLUGIN_EXPORT void filament_cubemap_utils_equirect_to_cubemap(FilIblCubemap* dst, const FilIblImage* src);
FFI_PLUGIN_EXPORT void filament_cubemap_utils_cubemap_to_equirect(FilIblImage* dst, const FilIblCubemap* src);
FFI_PLUGIN_EXPORT void filament_cubemap_utils_set_all_faces_from_cross(FilIblCubemap* c, const FilIblImage* cross);
FFI_PLUGIN_EXPORT FilIblCubemap* filament_cubemap_utils_cross_to_cubemap(const FilIblImage* cross);
FFI_PLUGIN_EXPORT void filament_cubemap_utils_cubemap_to_octahedron(FilIblImage* dst, const FilIblCubemap* src);
FFI_PLUGIN_EXPORT void filament_cubemap_utils_mirror_cubemap(FilIblCubemap* dst, const FilIblCubemap* src);
FFI_PLUGIN_EXPORT void filament_cubemap_utils_downsample_boxfilter(FilIblCubemap* dst, const FilIblCubemap* src);
FFI_PLUGIN_EXPORT void filament_cubemap_utils_make_seamless(FilIblCubemap* c);

#ifdef __cplusplus
}
#endif

#endif // FILAMENT_IBL_CUBEMAP_C_H
