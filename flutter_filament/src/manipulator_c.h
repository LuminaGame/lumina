/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

#ifndef FLUTTER_FILAMENT_MANIPULATOR_C_H
#define FLUTTER_FILAMENT_MANIPULATOR_C_H

#include <stdint.h>
#include <stdbool.h>

#if _WIN32
#define FFI_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FFI_PLUGIN_EXPORT
#endif

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
    FILAMENT_MANIPULATOR_ORBIT       = 0,
    FILAMENT_MANIPULATOR_MAP         = 1,
    FILAMENT_MANIPULATOR_FREE_FLIGHT = 2,
} FilamentManipulatorMode;

typedef enum {
    FILAMENT_FOV_VERTICAL = 0,
    FILAMENT_FOV_HORIZONTAL = 1,
} FilamentFovDirection;

typedef bool (*FilamentRaycastCallback)(const float* origin3, const float* dir3, float* out_t, void* userdata);

FFI_PLUGIN_EXPORT void* filament_manipulator_create(int mode, int viewport_width, int viewport_height);
FFI_PLUGIN_EXPORT void filament_manipulator_destroy(void* manipulator);
FFI_PLUGIN_EXPORT void filament_manipulator_set_viewport(void* manipulator, int width, int height);
FFI_PLUGIN_EXPORT void filament_manipulator_grab_begin(void* manipulator, int x, int y, bool strafe);
FFI_PLUGIN_EXPORT void filament_manipulator_grab_update(void* manipulator, int x, int y);
FFI_PLUGIN_EXPORT void filament_manipulator_grab_end(void* manipulator);
FFI_PLUGIN_EXPORT void filament_manipulator_scroll(void* manipulator, int x, int y, float scrolldelta);
FFI_PLUGIN_EXPORT void filament_manipulator_update(void* manipulator, float delta_time_seconds);
FFI_PLUGIN_EXPORT void filament_manipulator_key_down(void* manipulator, int key);
FFI_PLUGIN_EXPORT void filament_manipulator_key_up(void* manipulator, int key);
FFI_PLUGIN_EXPORT void filament_manipulator_get_look_at(void* manipulator, float* out_eye3, float* out_center3, float* out_up3);
FFI_PLUGIN_EXPORT bool filament_manipulator_raycast(void* manipulator, int x, int y, float* out_hit3);
FFI_PLUGIN_EXPORT void filament_manipulator_get_ray(void* manipulator, int x, int y, float* out_origin3, float* out_dir3);

FFI_PLUGIN_EXPORT void* filament_manipulator_get_current_bookmark(void* manipulator);
FFI_PLUGIN_EXPORT void* filament_manipulator_get_home_bookmark(void* manipulator);
FFI_PLUGIN_EXPORT void filament_manipulator_jump_to_bookmark(void* manipulator, void* bookmark);
FFI_PLUGIN_EXPORT void* filament_bookmark_interpolate(void* a, void* b, double t);
FFI_PLUGIN_EXPORT double filament_bookmark_duration(void* a, void* b);
FFI_PLUGIN_EXPORT void filament_bookmark_destroy(void* bookmark);

FFI_PLUGIN_EXPORT void* filament_manipulator_builder_create(void);
FFI_PLUGIN_EXPORT void filament_manipulator_builder_destroy(void* builder);
FFI_PLUGIN_EXPORT void filament_manipulator_builder_viewport(void* builder, int width, int height);
FFI_PLUGIN_EXPORT void filament_manipulator_builder_target_position(void* builder, float x, float y, float z);
FFI_PLUGIN_EXPORT void filament_manipulator_builder_up_vector(void* builder, float x, float y, float z);
FFI_PLUGIN_EXPORT void filament_manipulator_builder_zoom_speed(void* builder, float val);
FFI_PLUGIN_EXPORT void filament_manipulator_builder_orbit_home_position(void* builder, float x, float y, float z);
FFI_PLUGIN_EXPORT void filament_manipulator_builder_orbit_speed(void* builder, float x, float y);
FFI_PLUGIN_EXPORT void filament_manipulator_builder_fov_direction(void* builder, int fov_direction);
FFI_PLUGIN_EXPORT void filament_manipulator_builder_fov_degrees(void* builder, float degrees);
FFI_PLUGIN_EXPORT void filament_manipulator_builder_far_plane(void* builder, float distance);
FFI_PLUGIN_EXPORT void filament_manipulator_builder_map_extent(void* builder, float width, float height);
FFI_PLUGIN_EXPORT void filament_manipulator_builder_map_min_distance(void* builder, float dist);
FFI_PLUGIN_EXPORT void filament_manipulator_builder_flight_start_position(void* builder, float x, float y, float z);
FFI_PLUGIN_EXPORT void filament_manipulator_builder_flight_start_orientation(void* builder, float pitch, float yaw);
FFI_PLUGIN_EXPORT void filament_manipulator_builder_flight_max_move_speed(void* builder, float speed);
FFI_PLUGIN_EXPORT void filament_manipulator_builder_flight_speed_steps(void* builder, int steps);
FFI_PLUGIN_EXPORT void filament_manipulator_builder_flight_pan_speed(void* builder, float x, float y);
FFI_PLUGIN_EXPORT void filament_manipulator_builder_flight_move_damping(void* builder, float damping);
FFI_PLUGIN_EXPORT void filament_manipulator_builder_ground_plane(void* builder, float a, float b_val, float c, float d);
FFI_PLUGIN_EXPORT void filament_manipulator_builder_panning(void* builder, bool enabled);
FFI_PLUGIN_EXPORT void filament_manipulator_builder_raycast_callback(void* builder, FilamentRaycastCallback cb, void* userdata);
FFI_PLUGIN_EXPORT void* filament_manipulator_builder_build(void* builder, int mode);

#ifdef __cplusplus
}
#endif

#endif // FLUTTER_FILAMENT_MANIPULATOR_C_H
