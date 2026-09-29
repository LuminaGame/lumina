import 'ffi_platform.dart' as ffi;
import 'dart:typed_data';
import 'ffi_package_platform.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:flutter_filament/src/engine.dart';
import 'package:flutter_filament/src/filament_bindings.dart' as c;

/// Field-of-view direction.
enum FovDirection {
  vertical(0),
  horizontal(1);

  final int value;
  const FovDirection(this.value);
}

/// Camera projection type.
enum ProjectionType {
  perspective(0),
  ortho(1);

  final int value;
  const ProjectionType(this.value);
}

/// Camera represents the eye through which the scene is viewed.
///
/// A Camera has a position and orientation and controls the projection,
/// exposure, and focus parameters.
class FilamentCamera {
  final ffi.Pointer<ffi.Void> _ptr;
  final int _entity;
  final FilamentEngine _engine;
  bool _disposed = false;

  /// Internal constructor.
  FilamentCamera.internal(this._ptr, this._entity, this._engine);

  /// The raw native pointer to the Filament Camera.
  ffi.Pointer<ffi.Void> get nativePointer {
    _checkDisposed();
    return _ptr;
  }

  /// The entity this camera is attached to.
  int get entity => _entity;

  // ==========================================
  // Transform Family
  // ==========================================

  /// Gets the camera's model matrix in world space (rigid transform, double precision).
  Matrix4 get modelMatrix {
    _checkDisposed();
    final out = calloc<ffi.Double>(16);
    c.filament_camera_get_model_matrix(_ptr, out);
    final mat = Matrix4.fromFloat64List(Float64List.fromList([
      out[0], out[1], out[2], out[3],
      out[4], out[5], out[6], out[7],
      out[8], out[9], out[10], out[11],
      out[12], out[13], out[14], out[15],
    ]));
    calloc.free(out);
    return mat;
  }

  /// Sets the camera's model matrix (rigid transform, column-major).
  set modelMatrix(Matrix4 m) {
    _checkDisposed();
    final inPtr = calloc<ffi.Double>(16);
    final storage = m.storage;
    for (int i = 0; i < 16; i++) {
      inPtr[i] = storage[i];
    }
    c.filament_camera_set_model_matrix(_ptr, inPtr);
    calloc.free(inPtr);
  }

  /// Sets the camera's model matrix from a float (32-bit) list.
  void setModelMatrixF(Float32List fList) {
    _checkDisposed();
    if (fList.length != 16) {
      throw ArgumentError('Float32List matrix must contain 16 elements');
    }
    final inPtr = calloc<ffi.Float>(16);
    for (int i = 0; i < 16; i++) {
      inPtr[i] = fList[i];
    }
    c.filament_camera_set_model_matrix_f(_ptr, inPtr);
    calloc.free(inPtr);
  }

  /// Returns the camera's view matrix (inverse of the model matrix).
  Matrix4 get viewMatrix {
    _checkDisposed();
    final out = calloc<ffi.Double>(16);
    c.filament_camera_get_view_matrix(_ptr, out);
    final mat = Matrix4.fromFloat64List(Float64List.fromList([
      out[0], out[1], out[2], out[3],
      out[4], out[5], out[6], out[7],
      out[8], out[9], out[10], out[11],
      out[12], out[13], out[14], out[15],
    ]));
    calloc.free(out);
    return mat;
  }

  /// Returns the camera's position in world space.
  Vector3 get position {
    _checkDisposed();
    final out = calloc<ffi.Double>(3);
    c.filament_camera_get_position(_ptr, out);
    final v = Vector3(out[0], out[1], out[2]);
    calloc.free(out);
    return v;
  }

  /// Returns the camera's normalized left vector in world space (-X in view space).
  Vector3 get leftVector {
    _checkDisposed();
    final out = calloc<ffi.Float>(3);
    c.filament_camera_get_left_vector(_ptr, out);
    final v = Vector3(out[0], out[1], out[2]);
    calloc.free(out);
    return v;
  }

  /// Returns the camera's normalized up vector in world space (+Y in view space).
  Vector3 get upVector {
    _checkDisposed();
    final out = calloc<ffi.Float>(3);
    c.filament_camera_get_up_vector(_ptr, out);
    final v = Vector3(out[0], out[1], out[2]);
    calloc.free(out);
    return v;
  }

  /// Returns the camera's normalized forward vector in world space (-Z in view space).
  Vector3 get forwardVector {
    _checkDisposed();
    final out = calloc<ffi.Float>(3);
    c.filament_camera_get_forward_vector(_ptr, out);
    final v = Vector3(out[0], out[1], out[2]);
    calloc.free(out);
    return v;
  }

  /// Returns the 6 clipping frustum planes in normalized float4 (nx, ny, nz, d) form.
  ///
  /// Order: left (0), right (1), bottom (2), top (3), far (4), near (5).
  List<Vector4> get frustumPlanes {
    _checkDisposed();
    final out = calloc<ffi.Float>(24);
    c.filament_camera_get_frustum_planes(_ptr, out);
    final list = <Vector4>[];
    for (int i = 0; i < 6; i++) {
      list.add(Vector4(out[i * 4 + 0], out[i * 4 + 1], out[i * 4 + 2], out[i * 4 + 3]));
    }
    calloc.free(out);
    return list;
  }

  /// Sets the camera position and orientation using eye, center, and up vectors.
  void lookAt({
    required double eyeX,
    required double eyeY,
    required double eyeZ,
    required double centerX,
    required double centerY,
    required double centerZ,
    double upX = 0,
    double upY = 1,
    double upZ = 0,
  }) {
    _checkDisposed();
    c.filament_camera_look_at(
      _ptr,
      eyeX,
      eyeY,
      eyeZ,
      centerX,
      centerY,
      centerZ,
      upX,
      upY,
      upZ,
    );
  }

  // ==========================================
  // Projection Expansion
  // ==========================================

  /// Sets projection matrix from a 6-plane clipping volume.
  void setProjectionPlanes(
    ProjectionType projectionType, {
    required double left,
    required double right,
    required double bottom,
    required double top,
    required double near,
    required double far,
  }) {
    _checkDisposed();
    c.filament_camera_set_projection(
      _ptr,
      projectionType.value,
      left,
      right,
      bottom,
      top,
      near,
      far,
    );
  }

  /// Sets projection matrix from field-of-view or 6 planes.
  void setProjection({
    double? fovDegrees,
    double? aspect,
    double? near,
    double? far,
    FovDirection direction = FovDirection.vertical,
    ProjectionType? type,
    double? left,
    double? right,
    double? bottom,
    double? top,
  }) {
    if (type != null && left != null && right != null && bottom != null && top != null && near != null && far != null) {
      setProjectionPlanes(
        type,
        left: left,
        right: right,
        bottom: bottom,
        top: top,
        near: near,
        far: far,
      );
    } else {
      setProjectionFov(
        fovDegrees: fovDegrees ?? 45.0,
        aspect: aspect ?? 1.0,
        near: near ?? 0.1,
        far: far ?? 100.0,
        direction: direction,
      );
    }
  }

  /// Sets projection matrix from field-of-view angle, aspect ratio, and clipping planes.
  void setProjectionFov({
    required double fovDegrees,
    required double aspect,
    required double near,
    required double far,
    FovDirection direction = FovDirection.vertical,
  }) {
    _checkDisposed();
    c.filament_camera_set_projection_fov_direction(
      _ptr,
      fovDegrees,
      aspect,
      near,
      far,
      direction.value,
    );
  }

  /// Sets an orthographic projection.
  void setProjectionOrtho({
    required double left,
    required double right,
    required double bottom,
    required double top,
    required double near,
    required double far,
  }) {
    setProjectionPlanes(
      ProjectionType.ortho,
      left: left,
      right: right,
      bottom: bottom,
      top: top,
      near: near,
      far: far,
    );
  }

  /// Sets physical lens projection from 35mm focal length in millimeters.
  void setLensProjection({
    required double focalLengthMm,
    required double aspect,
    required double near,
    required double far,
  }) {
    _checkDisposed();
    c.filament_camera_set_lens_projection(_ptr, focalLengthMm, aspect, near, far);
  }

  /// Sets custom projection matrix (and optional separate culling projection).
  void setCustomProjection(
    Matrix4 projection, {
    Matrix4? culling,
    required double near,
    required double far,
  }) {
    _checkDisposed();
    final pPtr = calloc<ffi.Double>(16);
    for (int i = 0; i < 16; i++) {
      pPtr[i] = projection.storage[i];
    }

    if (culling != null) {
      final cPtr = calloc<ffi.Double>(16);
      for (int i = 0; i < 16; i++) {
        cPtr[i] = culling.storage[i];
      }
      c.filament_camera_set_custom_projection_culling(_ptr, pPtr, cPtr, near, far);
      calloc.free(cPtr);
    } else {
      c.filament_camera_set_custom_projection(_ptr, pPtr, near, far);
    }
    calloc.free(pPtr);
  }

  /// Sets 2D scaling on projection matrix.
  set scaling((double, double) s) {
    _checkDisposed();
    c.filament_camera_set_scaling(_ptr, s.$1, s.$2);
  }

  /// Gets 2D scaling applied after projection matrix (returned as Vector4 [x, y, 1, 1]).
  Vector4 get scaling {
    _checkDisposed();
    final out = calloc<ffi.Double>(4);
    c.filament_camera_get_scaling(_ptr, out);
    final v = Vector4(out[0], out[1], out[2], out[3]);
    calloc.free(out);
    return v;
  }

  /// Sets 2D shift on projection matrix in NDC.
  set shift((double, double) s) {
    _checkDisposed();
    c.filament_camera_set_shift(_ptr, s.$1, s.$2);
  }

  /// Gets 2D shift offsets on projection matrix.
  Vector2 get shift {
    _checkDisposed();
    final out = calloc<ffi.Double>(2);
    c.filament_camera_get_shift(_ptr, out);
    final v = Vector2(out[0], out[1]);
    calloc.free(out);
    return v;
  }

  /// Returns the projection matrix used for rendering (far plane at infinity).
  Matrix4 get projectionMatrix {
    _checkDisposed();
    final out = calloc<ffi.Double>(16);
    c.filament_camera_get_projection_matrix(_ptr, out);
    final mat = Matrix4.fromFloat64List(Float64List.fromList([
      out[0], out[1], out[2], out[3],
      out[4], out[5], out[6], out[7],
      out[8], out[9], out[10], out[11],
      out[12], out[13], out[14], out[15],
    ]));
    calloc.free(out);
    return mat;
  }

  /// Returns the culling projection matrix (finite far plane).
  Matrix4 get cullingProjectionMatrix {
    _checkDisposed();
    final out = calloc<ffi.Double>(16);
    c.filament_camera_get_culling_projection_matrix(_ptr, out);
    final mat = Matrix4.fromFloat64List(Float64List.fromList([
      out[0], out[1], out[2], out[3],
      out[4], out[5], out[6], out[7],
      out[8], out[9], out[10], out[11],
      out[12], out[13], out[14], out[15],
    ]));
    calloc.free(out);
    return mat;
  }

  /// Near plane distance in world units.
  double get near {
    _checkDisposed();
    return c.filament_camera_get_near(_ptr);
  }

  /// Far plane distance used for culling in world units.
  double get cullingFar {
    _checkDisposed();
    return c.filament_camera_get_culling_far(_ptr);
  }

  /// Static helper to compute projection matrix without an engine instance.
  static Matrix4 projection({
    required FovDirection direction,
    required double fovDegrees,
    required double aspect,
    required double near,
    required double far,
  }) {
    final out = calloc<ffi.Double>(16);
    c.filament_camera_static_projection(
      direction.value,
      fovDegrees,
      aspect,
      near,
      far,
      out,
    );
    final mat = Matrix4.fromFloat64List(Float64List.fromList([
      out[0], out[1], out[2], out[3],
      out[4], out[5], out[6], out[7],
      out[8], out[9], out[10], out[11],
      out[12], out[13], out[14], out[15],
    ]));
    calloc.free(out);
    return mat;
  }

  /// Static helper to compute inverse projection matrix without an engine instance.
  static Matrix4 inverseProjection(Matrix4 projection) {
    final inPtr = calloc<ffi.Double>(16);
    final outPtr = calloc<ffi.Double>(16);
    for (int i = 0; i < 16; i++) {
      inPtr[i] = projection.storage[i];
    }
    c.filament_camera_static_inverse_projection(inPtr, outPtr);
    final mat = Matrix4.fromFloat64List(Float64List.fromList([
      outPtr[0], outPtr[1], outPtr[2], outPtr[3],
      outPtr[4], outPtr[5], outPtr[6], outPtr[7],
      outPtr[8], outPtr[9], outPtr[10], outPtr[11],
      outPtr[12], outPtr[13], outPtr[14], outPtr[15],
    ]));
    calloc.free(inPtr);
    calloc.free(outPtr);
    return mat;
  }

  // ==========================================
  // Exposure & Focus
  // ==========================================

  /// Sets the camera's photometric exposure.
  ///
  /// [aperture] in f-stops (e.g. 2.8, 16), [shutterSpeed] in seconds (e.g. 1/125), [sensitivity] in ISO (e.g. 100).
  void setExposure({
    double aperture = 16.0,
    double shutterSpeed = 1.0 / 125.0,
    double sensitivity = 100.0,
  }) {
    _checkDisposed();
    c.filament_camera_set_exposure_physical(
      _ptr,
      aperture,
      shutterSpeed,
      sensitivity,
    );
  }

  /// Sets the exposure as an EV100 (e.g. 15 for a sunny day, 6 for a lit
  /// interior): the camera gets an aperture, shutter speed and ISO that
  /// give exactly that EV (ISO 100 at 1/125 s where possible), i.e.
  /// Filament's exposure factor 1 / (1.2 · 2^ev100). Reachable: about −15
  /// to +26.
  void setExposureEv100(double ev100) {
    _checkDisposed();
    c.filament_camera_set_exposure_ev100(_ptr, ev100);
  }

  /// Aperture in f-stops.
  double get aperture {
    _checkDisposed();
    return c.filament_camera_get_aperture(_ptr);
  }

  /// Shutter speed in seconds.
  double get shutterSpeed {
    _checkDisposed();
    return c.filament_camera_get_shutter_speed(_ptr);
  }

  /// Sensitivity in ISO.
  double get sensitivity {
    _checkDisposed();
    return c.filament_camera_get_sensitivity(_ptr);
  }

  /// Focal length in meters (for a 35mm camera).
  double get focalLength {
    _checkDisposed();
    return c.filament_camera_get_focal_length(_ptr);
  }

  /// Field of view in degrees along the given [direction].
  double getFieldOfViewInDegrees(FovDirection direction) {
    _checkDisposed();
    return c.filament_camera_get_field_of_view_in_degrees(_ptr, direction.value);
  }

  /// Focus distance in world units (measured from camera). Used by Depth-of-Field post-processing.
  double get focusDistance {
    _checkDisposed();
    return c.filament_camera_get_focus_distance(_ptr);
  }

  set focusDistance(double distance) {
    _checkDisposed();
    c.filament_camera_set_focus_distance(_ptr, distance);
  }

  /// Whether this camera has been disposed.
  bool get isDisposed => _disposed;

  /// Destroys this camera component in the Filament engine.
  void dispose() {
    if (!_disposed) {
      _disposed = true;
      c.filament_engine_destroy_camera_component(_engine.nativePointer, _entity);
    }
  }

  void _checkDisposed() {
    if (_disposed) {
      throw StateError('FilamentCamera has been disposed');
    }
  }
}
