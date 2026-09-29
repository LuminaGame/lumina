#ifndef FLUTTER_FILAMENT_CAMERA_C_H
#define FLUTTER_FILAMENT_CAMERA_C_H

#include <stdint.h>
#include <stdbool.h>

#ifndef FFI_PLUGIN_EXPORT
#if defined(_WIN32)
#define FFI_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FFI_PLUGIN_EXPORT __attribute__((visibility("default"))) __attribute__((used))
#endif
#endif

#ifdef __cplusplus
extern "C" {
#endif

// Transform family
FFI_PLUGIN_EXPORT void filament_camera_set_model_matrix(void* camera, const double* matrix16);
FFI_PLUGIN_EXPORT void filament_camera_set_model_matrix_f(void* camera, const float* matrix16);
FFI_PLUGIN_EXPORT void filament_camera_get_model_matrix(void* camera, double* out_matrix16);
FFI_PLUGIN_EXPORT void filament_camera_get_view_matrix(void* camera, double* out_matrix16);
FFI_PLUGIN_EXPORT void filament_camera_get_position(void* camera, double* out_xyz);
FFI_PLUGIN_EXPORT void filament_camera_get_left_vector(void* camera, float* out_xyz);
FFI_PLUGIN_EXPORT void filament_camera_get_up_vector(void* camera, float* out_xyz);
FFI_PLUGIN_EXPORT void filament_camera_get_forward_vector(void* camera, float* out_xyz);
FFI_PLUGIN_EXPORT void filament_camera_get_frustum_planes(void* camera, float* out_planes24);
FFI_PLUGIN_EXPORT uint32_t filament_camera_get_entity(void* camera);

// Projection expansion
FFI_PLUGIN_EXPORT void filament_camera_set_projection(void* camera, int projection_type, double left, double right, double bottom, double top, double near_plane, double far_plane);
FFI_PLUGIN_EXPORT void filament_camera_set_projection_fov_direction(void* camera, double fov_degrees, double aspect, double near_plane, double far_plane, int direction);
FFI_PLUGIN_EXPORT void filament_camera_set_lens_projection(void* camera, double focal_length_mm, double aspect, double near_plane, double far_plane);
FFI_PLUGIN_EXPORT void filament_camera_set_custom_projection(void* camera, const double* projection16, double near_plane, double far_plane);
FFI_PLUGIN_EXPORT void filament_camera_set_custom_projection_culling(void* camera, const double* projection16, const double* culling16, double near_plane, double far_plane);
FFI_PLUGIN_EXPORT void filament_camera_set_scaling(void* camera, double x, double y);
FFI_PLUGIN_EXPORT void filament_camera_get_scaling(void* camera, double* out_xyzw);
FFI_PLUGIN_EXPORT void filament_camera_set_shift(void* camera, double x, double y);
FFI_PLUGIN_EXPORT void filament_camera_get_shift(void* camera, double* out_xy);
FFI_PLUGIN_EXPORT void filament_camera_get_projection_matrix(void* camera, double* out_matrix16);
FFI_PLUGIN_EXPORT void filament_camera_get_culling_projection_matrix(void* camera, double* out_matrix16);
FFI_PLUGIN_EXPORT double filament_camera_get_near(void* camera);
FFI_PLUGIN_EXPORT double filament_camera_get_culling_far(void* camera);
FFI_PLUGIN_EXPORT void filament_camera_static_projection(int direction, double fov_degrees, double aspect, double near_plane, double far_plane, double* out_matrix16);
FFI_PLUGIN_EXPORT void filament_camera_static_inverse_projection(const double* projection16, double* out_matrix16);

// Exposure & Focus
FFI_PLUGIN_EXPORT void filament_camera_set_exposure_physical(void* camera, float aperture, float shutter_speed, float sensitivity);
FFI_PLUGIN_EXPORT void filament_camera_set_exposure_ev100(void* camera, float ev100);
FFI_PLUGIN_EXPORT float filament_camera_get_aperture(void* camera);
FFI_PLUGIN_EXPORT float filament_camera_get_shutter_speed(void* camera);
FFI_PLUGIN_EXPORT float filament_camera_get_sensitivity(void* camera);
FFI_PLUGIN_EXPORT double filament_camera_get_focal_length(void* camera);
FFI_PLUGIN_EXPORT double filament_camera_get_field_of_view_in_degrees(void* camera, int direction);
FFI_PLUGIN_EXPORT void filament_camera_set_focus_distance(void* camera, float distance);
FFI_PLUGIN_EXPORT float filament_camera_get_focus_distance(void* camera);

#ifdef __cplusplus
}
#endif

#endif // FLUTTER_FILAMENT_CAMERA_C_H
