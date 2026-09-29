#include "camera_c.h"

#include <filament/Camera.h>
#include <filament/Frustum.h>
#include <utils/Entity.h>
#include <math/mat4.h>
#include <math/vec2.h>
#include <math/vec3.h>
#include <math/vec4.h>

#include <algorithm>
#include <cmath>
#include <cstring>

using namespace filament;
using namespace filament::math;

extern "C" {

// Transform family
void filament_camera_set_model_matrix(void* camera, const double* matrix16) {
    if (camera == nullptr || matrix16 == nullptr) return;
    mat4 model;
    std::memcpy(&model[0][0], matrix16, sizeof(double) * 16);
    static_cast<Camera*>(camera)->setModelMatrix(model);
}

void filament_camera_set_model_matrix_f(void* camera, const float* matrix16) {
    if (camera == nullptr || matrix16 == nullptr) return;
    mat4f model;
    std::memcpy(&model[0][0], matrix16, sizeof(float) * 16);
    static_cast<Camera*>(camera)->setModelMatrix(model);
}

void filament_camera_get_model_matrix(void* camera, double* out_matrix16) {
    if (camera == nullptr || out_matrix16 == nullptr) return;
    mat4 model = static_cast<Camera*>(camera)->getModelMatrix();
    std::memcpy(out_matrix16, &model[0][0], sizeof(double) * 16);
}

void filament_camera_get_view_matrix(void* camera, double* out_matrix16) {
    if (camera == nullptr || out_matrix16 == nullptr) return;
    mat4 view = static_cast<Camera*>(camera)->getViewMatrix();
    std::memcpy(out_matrix16, &view[0][0], sizeof(double) * 16);
}

void filament_camera_get_position(void* camera, double* out_xyz) {
    if (camera == nullptr || out_xyz == nullptr) return;
    double3 pos = static_cast<Camera*>(camera)->getPosition();
    out_xyz[0] = pos.x;
    out_xyz[1] = pos.y;
    out_xyz[2] = pos.z;
}

void filament_camera_get_left_vector(void* camera, float* out_xyz) {
    if (camera == nullptr || out_xyz == nullptr) return;
    float3 v = static_cast<Camera*>(camera)->getLeftVector();
    out_xyz[0] = v.x;
    out_xyz[1] = v.y;
    out_xyz[2] = v.z;
}

void filament_camera_get_up_vector(void* camera, float* out_xyz) {
    if (camera == nullptr || out_xyz == nullptr) return;
    float3 v = static_cast<Camera*>(camera)->getUpVector();
    out_xyz[0] = v.x;
    out_xyz[1] = v.y;
    out_xyz[2] = v.z;
}

void filament_camera_get_forward_vector(void* camera, float* out_xyz) {
    if (camera == nullptr || out_xyz == nullptr) return;
    float3 v = static_cast<Camera*>(camera)->getForwardVector();
    out_xyz[0] = v.x;
    out_xyz[1] = v.y;
    out_xyz[2] = v.z;
}

void filament_camera_get_frustum_planes(void* camera, float* out_planes24) {
    if (camera == nullptr || out_planes24 == nullptr) return;
    Frustum f = static_cast<Camera*>(camera)->getFrustum();
    f.getNormalizedPlanes(reinterpret_cast<float4*>(out_planes24));
}

uint32_t filament_camera_get_entity(void* camera) {
    if (camera == nullptr) return 0;
    return static_cast<Camera*>(camera)->getEntity().getId();
}

// Projection expansion
void filament_camera_set_projection(void* camera, int projection_type, double left, double right, double bottom, double top, double near_plane, double far_plane) {
    if (camera == nullptr) return;
    Camera::Projection proj = (projection_type == 1) ? Camera::Projection::ORTHO : Camera::Projection::PERSPECTIVE;
    static_cast<Camera*>(camera)->setProjection(proj, left, right, bottom, top, near_plane, far_plane);
}

void filament_camera_set_projection_fov_direction(void* camera, double fov_degrees, double aspect, double near_plane, double far_plane, int direction) {
    if (camera == nullptr) return;
    Camera::Fov fovDir = (direction == 1) ? Camera::Fov::HORIZONTAL : Camera::Fov::VERTICAL;
    static_cast<Camera*>(camera)->setProjection(fov_degrees, aspect, near_plane, far_plane, fovDir);
}

void filament_camera_set_lens_projection(void* camera, double focal_length_mm, double aspect, double near_plane, double far_plane) {
    if (camera == nullptr) return;
    static_cast<Camera*>(camera)->setLensProjection(focal_length_mm, aspect, near_plane, far_plane);
}

void filament_camera_set_custom_projection(void* camera, const double* projection16, double near_plane, double far_plane) {
    if (camera == nullptr || projection16 == nullptr) return;
    mat4 proj;
    std::memcpy(&proj[0][0], projection16, sizeof(double) * 16);
    static_cast<Camera*>(camera)->setCustomProjection(proj, near_plane, far_plane);
}

void filament_camera_set_custom_projection_culling(void* camera, const double* projection16, const double* culling16, double near_plane, double far_plane) {
    if (camera == nullptr || projection16 == nullptr || culling16 == nullptr) return;
    mat4 proj;
    mat4 cull;
    std::memcpy(&proj[0][0], projection16, sizeof(double) * 16);
    std::memcpy(&cull[0][0], culling16, sizeof(double) * 16);
    static_cast<Camera*>(camera)->setCustomProjection(proj, cull, near_plane, far_plane);
}

void filament_camera_set_scaling(void* camera, double x, double y) {
    if (camera == nullptr) return;
    static_cast<Camera*>(camera)->setScaling(double2(x, y));
}

void filament_camera_get_scaling(void* camera, double* out_xyzw) {
    if (camera == nullptr || out_xyzw == nullptr) return;
    double4 s = static_cast<Camera*>(camera)->getScaling();
    out_xyzw[0] = s.x;
    out_xyzw[1] = s.y;
    out_xyzw[2] = s.z;
    out_xyzw[3] = s.w;
}

void filament_camera_set_shift(void* camera, double x, double y) {
    if (camera == nullptr) return;
    static_cast<Camera*>(camera)->setShift(double2(x, y));
}

void filament_camera_get_shift(void* camera, double* out_xy) {
    if (camera == nullptr || out_xy == nullptr) return;
    double2 s = static_cast<Camera*>(camera)->getShift();
    out_xy[0] = s.x;
    out_xy[1] = s.y;
}

void filament_camera_get_projection_matrix(void* camera, double* out_matrix16) {
    if (camera == nullptr || out_matrix16 == nullptr) return;
    mat4 p = static_cast<Camera*>(camera)->getProjectionMatrix();
    std::memcpy(out_matrix16, &p[0][0], sizeof(double) * 16);
}

void filament_camera_get_culling_projection_matrix(void* camera, double* out_matrix16) {
    if (camera == nullptr || out_matrix16 == nullptr) return;
    mat4 p = static_cast<Camera*>(camera)->getCullingProjectionMatrix();
    std::memcpy(out_matrix16, &p[0][0], sizeof(double) * 16);
}

double filament_camera_get_near(void* camera) {
    if (camera == nullptr) return 0.0;
    return static_cast<Camera*>(camera)->getNear();
}

double filament_camera_get_culling_far(void* camera) {
    if (camera == nullptr) return 0.0;
    return static_cast<Camera*>(camera)->getCullingFar();
}

void filament_camera_static_projection(int direction, double fov_degrees, double aspect, double near_plane, double far_plane, double* out_matrix16) {
    if (out_matrix16 == nullptr) return;
    Camera::Fov fovDir = (direction == 1) ? Camera::Fov::HORIZONTAL : Camera::Fov::VERTICAL;
    mat4 p = Camera::projection(fovDir, fov_degrees, aspect, near_plane, far_plane);
    std::memcpy(out_matrix16, &p[0][0], sizeof(double) * 16);
}

void filament_camera_static_inverse_projection(const double* projection16, double* out_matrix16) {
    if (projection16 == nullptr || out_matrix16 == nullptr) return;
    mat4 p;
    std::memcpy(&p[0][0], projection16, sizeof(double) * 16);
    mat4 inv = Camera::inverseProjection(p);
    std::memcpy(out_matrix16, &inv[0][0], sizeof(double) * 16);
}

// Exposure & Focus
void filament_camera_set_exposure_physical(void* camera, float aperture, float shutter_speed, float sensitivity) {
    if (camera == nullptr) return;
    static_cast<Camera*>(camera)->setExposure(aperture, shutter_speed, sensitivity);
}

void filament_camera_set_exposure_ev100(void* camera, float ev100) {
    if (camera == nullptr) return;
    // Camera::setExposure(float) takes an exposure *factor*, not an EV.
    // EV100 = log2(N²/t) + log2(100/S): pick settings a camera
    // could have, inside Filament's clamps (N 0.5–64, t 1/25000–60 s,
    // S 10–204800) — ISO 100 at 1/125 s first, then the shutter, then the
    // ISO — so the whole range from about −15 to +26 is met exactly.
    const float target = std::exp2(ev100);  // N²/t · 100/S
    const float n = std::clamp(std::sqrt(target / 125.0f), 1.0f, 32.0f);
    const float t = std::clamp(n * n / target, 1.0f / 8000.0f, 30.0f);
    const float s = std::clamp(100.0f * n * n / (t * target), 10.0f, 204800.0f);
    static_cast<Camera*>(camera)->setExposure(n, t, s);
}

float filament_camera_get_aperture(void* camera) {
    if (camera == nullptr) return 0.0f;
    return static_cast<Camera*>(camera)->getAperture();
}

float filament_camera_get_shutter_speed(void* camera) {
    if (camera == nullptr) return 0.0f;
    return static_cast<Camera*>(camera)->getShutterSpeed();
}

float filament_camera_get_sensitivity(void* camera) {
    if (camera == nullptr) return 0.0f;
    return static_cast<Camera*>(camera)->getSensitivity();
}

double filament_camera_get_focal_length(void* camera) {
    if (camera == nullptr) return 0.0;
    return static_cast<Camera*>(camera)->getFocalLength();
}

double filament_camera_get_field_of_view_in_degrees(void* camera, int direction) {
    if (camera == nullptr) return 0.0;
    Camera::Fov fovDir = (direction == 1) ? Camera::Fov::HORIZONTAL : Camera::Fov::VERTICAL;
    return static_cast<Camera*>(camera)->getFieldOfViewInDegrees(fovDir);
}

void filament_camera_set_focus_distance(void* camera, float distance) {
    if (camera == nullptr) return;
    static_cast<Camera*>(camera)->setFocusDistance(distance);
}

float filament_camera_get_focus_distance(void* camera) {
    if (camera == nullptr) return 0.0f;
    return static_cast<Camera*>(camera)->getFocusDistance();
}

}
