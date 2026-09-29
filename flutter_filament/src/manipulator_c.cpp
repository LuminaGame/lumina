/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

#include "manipulator_c.h"

#include <camutils/Manipulator.h>
#include <utils/Panic.h>
#include <cstdio>
#include <exception>

using CameraManipulator = filament::camutils::Manipulator<float>;
static inline CameraManipulator* toManipulator(void* p) { return reinterpret_cast<CameraManipulator*>(p); }

#define FFI_TRY try {
#define FFI_CATCH(return_value) \
} catch (const utils::Panic& e) { \
    fprintf(stderr, "[Manipulator C++ Panic (Handled Safely)]: %s\n", e.what()); \
    return return_value; \
} catch (const std::exception& e) { \
    fprintf(stderr, "[Manipulator C++ Exception (Handled Safely)]: %s\n", e.what()); \
    return return_value; \
} catch (...) { \
    fprintf(stderr, "[Manipulator C++ Unknown Exception (Handled Safely)]\n"); \
    return return_value; \
}

void* filament_manipulator_create(int mode, int viewport_width, int viewport_height) {
    FFI_TRY
    return CameraManipulator::Builder()
        .viewport(viewport_width, viewport_height)
        .build(static_cast<filament::camutils::Mode>(mode));
    FFI_CATCH(nullptr)
}

void filament_manipulator_destroy(void* manipulator) {
    FFI_TRY
    if (manipulator) {
        delete toManipulator(manipulator);
    }
    FFI_CATCH()
}

void filament_manipulator_set_viewport(void* manipulator, int width, int height) {
    FFI_TRY
    if (manipulator) toManipulator(manipulator)->setViewport(width, height);
    FFI_CATCH()
}

void filament_manipulator_grab_begin(void* manipulator, int x, int y, bool strafe) {
    FFI_TRY
    if (manipulator) toManipulator(manipulator)->grabBegin(x, y, strafe);
    FFI_CATCH()
}

void filament_manipulator_grab_update(void* manipulator, int x, int y) {
    FFI_TRY
    if (manipulator) toManipulator(manipulator)->grabUpdate(x, y);
    FFI_CATCH()
}

void filament_manipulator_grab_end(void* manipulator) {
    FFI_TRY
    if (manipulator) toManipulator(manipulator)->grabEnd();
    FFI_CATCH()
}

void filament_manipulator_scroll(void* manipulator, int x, int y, float scrolldelta) {
    FFI_TRY
    if (manipulator) toManipulator(manipulator)->scroll(x, y, scrolldelta);
    FFI_CATCH()
}

void filament_manipulator_update(void* manipulator, float delta_time_seconds) {
    FFI_TRY
    if (manipulator) toManipulator(manipulator)->update(delta_time_seconds);
    FFI_CATCH()
}

void filament_manipulator_key_down(void* manipulator, int key) {
    FFI_TRY
    if (manipulator && key >= 0 && key < static_cast<int>(CameraManipulator::Key::COUNT)) {
        toManipulator(manipulator)->keyDown(static_cast<CameraManipulator::Key>(key));
    }
    FFI_CATCH()
}

void filament_manipulator_key_up(void* manipulator, int key) {
    FFI_TRY
    if (manipulator && key >= 0 && key < static_cast<int>(CameraManipulator::Key::COUNT)) {
        toManipulator(manipulator)->keyUp(static_cast<CameraManipulator::Key>(key));
    }
    FFI_CATCH()
}

void filament_manipulator_get_look_at(void* manipulator, float* out_eye3, float* out_center3, float* out_up3) {
    FFI_TRY
    if (!manipulator || !out_eye3 || !out_center3 || !out_up3) return;
    filament::math::float3 eye, center, up;
    toManipulator(manipulator)->getLookAt(&eye, &center, &up);
    out_eye3[0] = eye.x; out_eye3[1] = eye.y; out_eye3[2] = eye.z;
    out_center3[0] = center.x; out_center3[1] = center.y; out_center3[2] = center.z;
    out_up3[0] = up.x; out_up3[1] = up.y; out_up3[2] = up.z;
    FFI_CATCH()
}

bool filament_manipulator_raycast(void* manipulator, int x, int y, float* out_hit3) {
    FFI_TRY
    if (!manipulator || !out_hit3) return false;
    filament::math::float3 hit;
    bool result = toManipulator(manipulator)->raycast(x, y, &hit);
    if (result) {
        out_hit3[0] = hit.x; out_hit3[1] = hit.y; out_hit3[2] = hit.z;
    }
    return result;
    FFI_CATCH(false)
}

void filament_manipulator_get_ray(void* manipulator, int x, int y, float* out_origin3, float* out_dir3) {
    FFI_TRY
    if (!manipulator || !out_origin3 || !out_dir3) return;
    filament::math::float3 origin, dir;
    toManipulator(manipulator)->getRay(x, y, &origin, &dir);
    out_origin3[0] = origin.x; out_origin3[1] = origin.y; out_origin3[2] = origin.z;
    out_dir3[0] = dir.x; out_dir3[1] = dir.y; out_dir3[2] = dir.z;
    FFI_CATCH()
}

using Builder = CameraManipulator::Builder;
static inline Builder* toBuilder(void* p) { return reinterpret_cast<Builder*>(p); }

void* filament_manipulator_builder_create(void) {
    FFI_TRY
    return new Builder();
    FFI_CATCH(nullptr)
}

void filament_manipulator_builder_destroy(void* builder) {
    FFI_TRY
    if (builder) delete toBuilder(builder);
    FFI_CATCH()
}

void filament_manipulator_builder_viewport(void* builder, int width, int height) {
    FFI_TRY
    if (builder) toBuilder(builder)->viewport(width, height);
    FFI_CATCH()
}

void filament_manipulator_builder_target_position(void* builder, float x, float y, float z) {
    FFI_TRY
    if (builder) toBuilder(builder)->targetPosition(x, y, z);
    FFI_CATCH()
}

void filament_manipulator_builder_up_vector(void* builder, float x, float y, float z) {
    FFI_TRY
    if (builder) toBuilder(builder)->upVector(x, y, z);
    FFI_CATCH()
}

void filament_manipulator_builder_zoom_speed(void* builder, float val) {
    FFI_TRY
    if (builder) toBuilder(builder)->zoomSpeed(val);
    FFI_CATCH()
}

void filament_manipulator_builder_orbit_home_position(void* builder, float x, float y, float z) {
    FFI_TRY
    if (builder) toBuilder(builder)->orbitHomePosition(x, y, z);
    FFI_CATCH()
}

void filament_manipulator_builder_orbit_speed(void* builder, float x, float y) {
    FFI_TRY
    if (builder) toBuilder(builder)->orbitSpeed(x, y);
    FFI_CATCH()
}

void filament_manipulator_builder_fov_direction(void* builder, int fov_direction) {
    FFI_TRY
    if (builder) toBuilder(builder)->fovDirection(static_cast<filament::camutils::Fov>(fov_direction));
    FFI_CATCH()
}

void filament_manipulator_builder_fov_degrees(void* builder, float degrees) {
    FFI_TRY
    if (builder) toBuilder(builder)->fovDegrees(degrees);
    FFI_CATCH()
}

void filament_manipulator_builder_far_plane(void* builder, float distance) {
    FFI_TRY
    if (builder) toBuilder(builder)->farPlane(distance);
    FFI_CATCH()
}

void filament_manipulator_builder_map_extent(void* builder, float width, float height) {
    FFI_TRY
    if (builder) toBuilder(builder)->mapExtent(width, height);
    FFI_CATCH()
}

void filament_manipulator_builder_map_min_distance(void* builder, float dist) {
    FFI_TRY
    if (builder) toBuilder(builder)->mapMinDistance(dist);
    FFI_CATCH()
}

void filament_manipulator_builder_flight_start_position(void* builder, float x, float y, float z) {
    FFI_TRY
    if (builder) toBuilder(builder)->flightStartPosition(x, y, z);
    FFI_CATCH()
}

void filament_manipulator_builder_flight_start_orientation(void* builder, float pitch, float yaw) {
    FFI_TRY
    if (builder) toBuilder(builder)->flightStartOrientation(pitch, yaw);
    FFI_CATCH()
}

void filament_manipulator_builder_flight_max_move_speed(void* builder, float speed) {
    FFI_TRY
    if (builder) toBuilder(builder)->flightMaxMoveSpeed(speed);
    FFI_CATCH()
}

void filament_manipulator_builder_flight_speed_steps(void* builder, int steps) {
    FFI_TRY
    if (builder) toBuilder(builder)->flightSpeedSteps(steps);
    FFI_CATCH()
}

void filament_manipulator_builder_flight_pan_speed(void* builder, float x, float y) {
    FFI_TRY
    if (builder) toBuilder(builder)->flightPanSpeed(x, y);
    FFI_CATCH()
}

void filament_manipulator_builder_flight_move_damping(void* builder, float damping) {
    FFI_TRY
    if (builder) toBuilder(builder)->flightMoveDamping(damping);
    FFI_CATCH()
}

void filament_manipulator_builder_ground_plane(void* builder, float a, float b_val, float c, float d) {
    FFI_TRY
    if (builder) toBuilder(builder)->groundPlane(a, b_val, c, d);
    FFI_CATCH()
}

void filament_manipulator_builder_panning(void* builder, bool enabled) {
    FFI_TRY
    if (builder) toBuilder(builder)->panning(enabled);
    FFI_CATCH()
}

void filament_manipulator_builder_raycast_callback(void* builder, FilamentRaycastCallback cb, void* userdata) {
    FFI_TRY
    if (builder) {
        toBuilder(builder)->raycastCallback(
            reinterpret_cast<filament::camutils::Manipulator<float>::RayCallback>(cb),
            userdata
        );
    }
    FFI_CATCH()
}

void* filament_manipulator_builder_build(void* builder, int mode) {
    FFI_TRY
    if (builder) {
        CameraManipulator* m = toBuilder(builder)->build(static_cast<filament::camutils::Mode>(mode));
        return m;
    }
    return nullptr;
    FFI_CATCH(nullptr)
}

using CameraBookmark = filament::camutils::Bookmark<float>;
static inline CameraBookmark* toBookmark(void* p) { return reinterpret_cast<CameraBookmark*>(p); }

void* filament_manipulator_get_current_bookmark(void* manipulator) {
    FFI_TRY
    if (!manipulator) return nullptr;
    return new CameraBookmark(toManipulator(manipulator)->getCurrentBookmark());
    FFI_CATCH(nullptr)
}

void* filament_manipulator_get_home_bookmark(void* manipulator) {
    FFI_TRY
    if (!manipulator) return nullptr;
    return new CameraBookmark(toManipulator(manipulator)->getHomeBookmark());
    FFI_CATCH(nullptr)
}

void filament_manipulator_jump_to_bookmark(void* manipulator, void* bookmark) {
    FFI_TRY
    if (!manipulator || !bookmark) return;
    toManipulator(manipulator)->jumpToBookmark(*toBookmark(bookmark));
    FFI_CATCH()
}

void* filament_bookmark_interpolate(void* a, void* b, double t) {
    FFI_TRY
    if (!a || !b) return nullptr;
    return new CameraBookmark(CameraBookmark::interpolate(*toBookmark(a), *toBookmark(b), t));
    FFI_CATCH(nullptr)
}

double filament_bookmark_duration(void* a, void* b) {
    FFI_TRY
    if (!a || !b) return 0.0;
    return CameraBookmark::duration(*toBookmark(a), *toBookmark(b));
    FFI_CATCH(0.0)
}

void filament_bookmark_destroy(void* bookmark) {
    FFI_TRY
    if (bookmark) delete toBookmark(bookmark);
    FFI_CATCH()
}
