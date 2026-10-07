import 'dart:math' as math;
import 'package:flutter_filament/flutter_filament.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:lumina/src/components/base/scene_component.dart';
import 'package:lumina_core/lumina_core.dart';

export 'camera_math.dart';
export 'camera_settings.dart';

enum CameraProjectionMode { perspective, orthographic }

/// Abstract native interface for camera synchronization and FFI operations.
abstract class CameraNative {
  void setProjection({
    double? fovDegrees,
    double? aspect,
    double? near,
    double? far,
  });

  void setProjectionOrtho({
    required double left,
    required double right,
    required double bottom,
    required double top,
    required double near,
    required double far,
  });

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
  });

  void setExposure({
    double aperture = 16.0,
    double shutterSpeed = 1.0 / 125.0,
    double sensitivity = 100.0,
  });

  void dispose();
}

class _FilamentCameraNative implements CameraNative {
  final FilamentCamera camera;
  _FilamentCameraNative(this.camera);

  @override
  void setProjection({double? fovDegrees, double? aspect, double? near, double? far}) {
    camera.setProjection(fovDegrees: fovDegrees, aspect: aspect, near: near, far: far);
  }

  @override
  void setProjectionOrtho({
    required double left,
    required double right,
    required double bottom,
    required double top,
    required double near,
    required double far,
  }) {
    camera.setProjectionOrtho(left: left, right: right, bottom: bottom, top: top, near: near, far: far);
  }

  @override
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
    camera.lookAt(
      eyeX: eyeX,
      eyeY: eyeY,
      eyeZ: eyeZ,
      centerX: centerX,
      centerY: centerY,
      centerZ: centerZ,
      upX: upX,
      upY: upY,
      upZ: upZ,
    );
  }

  @override
  void setExposure({
    double aperture = 16.0,
    double shutterSpeed = 1.0 / 125.0,
    double sensitivity = 100.0,
  }) {
    camera.setExposure(aperture: aperture, shutterSpeed: shutterSpeed, sensitivity: sensitivity);
  }

  @override
  void dispose() {
    camera.dispose();
  }
}

/// Configuration defining a camera shake effect.
class CameraShake {
  final Vector3 locationAmplitude;
  final Vector3 rotationAmplitudeDegrees;
  final double frequency;
  final double duration;
  final double decay;

  CameraShake({
    Vector3? locationAmplitude,
    Vector3? rotationAmplitudeDegrees,
    this.frequency = 10.0,
    this.duration = 0.5,
    this.decay = 1.0,
  })  : locationAmplitude = locationAmplitude ?? Vector3.zero(),
        rotationAmplitudeDegrees = rotationAmplitudeDegrees ?? Vector3.zero();
}

/// A 3D ray emitted from the camera.
class CameraRay {
  final Vector3 origin;
  final Vector3 direction;

  const CameraRay(this.origin, this.direction);
}

/// Six bounding planes representing the view frustum.
class FrustumPlanes {
  final List<Plane> planes;

  FrustumPlanes(this.planes);

  /// Tests whether a sphere intersects or is inside the frustum.
  bool intersectsSphere(Vector3 center, double radius) {
    for (final plane in planes) {
      final dist = plane.distanceToVector3(center);
      if (dist < -radius) {
        return false;
      }
    }
    return true;
  }

  /// Tests whether an AABB intersects or is inside the frustum.
  bool intersectsAabb(Aabb3 box) {
    final min = box.min;
    final max = box.max;

    for (final plane in planes) {
      final normal = plane.normal;
      final px = normal.x >= 0.0 ? max.x : min.x;
      final py = normal.y >= 0.0 ? max.y : min.y;
      final pz = normal.z >= 0.0 ? max.z : min.z;

      final dist = normal.x * px + normal.y * py + normal.z * pz + plane.constant;
      if (dist < 0.0) {
        return false;
      }
    }
    return true;
  }
}

/// Component wrapping camera projection, view matrix, shake, activation, and raycasting.
class LuminaCameraComponent extends LuminaSceneComponent {
  CameraProjectionMode projectionMode = CameraProjectionMode.perspective;
  double fieldOfViewInDegrees = 60.0;
  double aspectRatio = 16.0 / 9.0;
  // World units (cm): 10 cm to 1 km.
  double nearClipPlane = 10.0;
  double farClipPlane = 100000.0;
  double orthographicWidth = 1000.0;
  bool isActive = false;

  // Photometric exposure parameters
  /// Whether the world meters this camera's exposure from the level's lights
  /// ([LuminaAutoExposure]) while it renders the bound
  /// view. Turn it off to set [aperture] / [shutterSpeed] / [sensitivity]
  /// by hand.
  bool autoExposure = true;
  double aperture = 16.0;
  double shutterSpeed = 1.0 / 125.0;
  double sensitivity = 100.0;

  CameraNative? _nativeCamera;
  FilamentView? _boundView;
  bool _wasBound = false;

  // Dirty tracking caches
  CameraProjectionMode? _lastSyncedProjectionMode;
  double? _lastSyncedFov;
  double? _lastSyncedAspect;
  double? _lastSyncedNear;
  double? _lastSyncedFar;
  double? _lastSyncedOrthoWidth;
  double? _lastSyncedAperture;
  double? _lastSyncedShutterSpeed;
  double? _lastSyncedSensitivity;

  double? _targetFov;
  double _fovInterpSpeed = 0.0;

  CameraShake? _currentShake;
  double _shakeElapsed = 0.0;
  final Vector3 _shakeLocationOffset = Vector3.zero();

  static const double _deg2rad = math.pi / 180.0;

  LuminaCameraComponent({
    super.key,
    super.location,
    super.rotation,
    this.fieldOfViewInDegrees = 60.0,
    this.aspectRatio = 16.0 / 9.0,
  });

  /// The underlying [FilamentCamera] instance if bound to Filament, or `null`.
  FilamentCamera? get nativeFilamentCamera =>
      (_nativeCamera is _FilamentCameraNative) ? (_nativeCamera as _FilamentCameraNative).camera : null;

  /// Binds directly to a [CameraNative] implementation (used in tests or custom adapters).
  void bindNative(CameraNative native) {
    _nativeCamera = native;
    _wasBound = true;
    _invalidateDirtyFlags();
  }

  /// Binds this component to a native [FilamentEngine] and [FilamentView].
  void bindToFilament(FilamentEngine engine, FilamentView view) {
    _boundView = view;
    _wasBound = true;
    final entity = engine.createEntity();
    final cam = engine.createCamera(entity);
    _nativeCamera = _FilamentCameraNative(cam);
    if (isActive) {
      view.camera = cam;
    }
    _invalidateDirtyFlags();
    if (isActive) {
      syncWithFilamentCamera();
    }
  }

  /// Unbinds and disposes the native camera handle.
  void unbindFromFilament() {
    if (_nativeCamera != null) {
      _nativeCamera!.dispose();
      _nativeCamera = null;
    }
    _boundView = null;
  }

  /// Forces the next [syncWithFilamentCamera] to push projection and exposure
  /// again, for a target camera something else may have changed since.
  void invalidateNativeSync() => _invalidateDirtyFlags();

  void _invalidateDirtyFlags() {
    _lastSyncedProjectionMode = null;
    _lastSyncedFov = null;
    _lastSyncedAspect = null;
    _lastSyncedNear = null;
    _lastSyncedFar = null;
    _lastSyncedOrthoWidth = null;
    _lastSyncedAperture = null;
    _lastSyncedShutterSpeed = null;
    _lastSyncedSensitivity = null;
  }

  /// Activates this camera and deactivates any other camera on the owning actor.
  void activate() {
    if (owner != null) {
      for (final comp in owner!.components) {
        if (comp is LuminaCameraComponent && comp != this) {
          comp.deactivate();
        }
      }
    }
    isActive = true;
    if (_boundView != null && nativeFilamentCamera != null) {
      _boundView!.camera = nativeFilamentCamera!;
    }
  }

  /// Deactivates this camera.
  void deactivate() {
    isActive = false;
  }

  /// Sets field of view with optional smooth interpolation.
  void setFieldOfView(double targetFov, {double interpSpeed = 0.0}) {
    if (interpSpeed <= 0.0) {
      fieldOfViewInDegrees = targetFov;
      _targetFov = null;
    } else {
      _targetFov = targetFov;
      _fovInterpSpeed = interpSpeed;
    }
  }

  /// Starts playing a camera shake effect.
  void startCameraShake(CameraShake shake) {
    _currentShake = shake;
    _shakeElapsed = 0.0;
  }

  /// Stops the current camera shake effect.
  void stopCameraShake({bool immediately = false}) {
    _currentShake = null;
    _shakeElapsed = 0.0;
    _shakeLocationOffset.setZero();
  }

  @override
  void onTick(double deltaTime) {
    super.onTick(deltaTime);

    // Smooth FOV interpolation
    if (_targetFov != null) {
      fieldOfViewInDegrees = fInterpTo(
        fieldOfViewInDegrees,
        _targetFov!,
        deltaTime,
        _fovInterpSpeed,
      );
      if ((fieldOfViewInDegrees - _targetFov!).abs() < 1e-6) {
        fieldOfViewInDegrees = _targetFov!;
        _targetFov = null;
      }
    }

    // Camera shake update
    if (_currentShake != null) {
      _shakeElapsed += deltaTime;
      final shake = _currentShake!;
      if (_shakeElapsed >= shake.duration) {
        stopCameraShake();
      } else {
        final progress = _shakeElapsed / shake.duration;
        final dampen = math.pow(1.0 - progress, shake.decay).toDouble();
        final sinVal = math.sin(_shakeElapsed * shake.frequency * 2.0 * math.pi);

        _shakeLocationOffset.x = shake.locationAmplitude.x * sinVal * dampen;
        _shakeLocationOffset.y = shake.locationAmplitude.y * sinVal * dampen;
        _shakeLocationOffset.z = shake.locationAmplitude.z * sinVal * dampen;
      }
    }
  }

  /// Computes view matrix into [out] (or allocates if null).
  Matrix4 getViewMatrix({Matrix4? out}) {
    final eye = worldLocation + _shakeLocationOffset;
    final target = eye + forwardVector;
    final up = upVector;

    final m = out ?? Matrix4.zero();
    setViewMatrix(m, eye, target, up);
    return m;
  }

  /// Computes projection matrix into [out] (or allocates if null).
  Matrix4 getProjectionMatrix({Matrix4? out}) {
    final m = out ?? Matrix4.zero();
    if (projectionMode == CameraProjectionMode.perspective) {
      setPerspectiveMatrix(
        m,
        fieldOfViewInDegrees * _deg2rad,
        aspectRatio,
        nearClipPlane,
        farClipPlane,
      );
    } else {
      final halfWidth = orthographicWidth * 0.5;
      final halfHeight = halfWidth / aspectRatio;
      setOrthographicMatrix(
        m,
        -halfWidth,
        halfWidth,
        -halfHeight,
        halfHeight,
        nearClipPlane,
        farClipPlane,
      );
    }
    return m;
  }

  /// Computes view-projection matrix (projection × view).
  Matrix4 getViewProjectionMatrix({Matrix4? out}) {
    final m = out ?? Matrix4.zero();
    final proj = getProjectionMatrix();
    final view = getViewMatrix();
    m.setFrom(proj * view);
    return m;
  }

  /// Extracts the 6 normalized frustum planes from the view-projection matrix.
  FrustumPlanes getFrustumPlanes() {
    final vp = getViewProjectionMatrix();
    final s = vp.storage;

    // Rows of column-major matrix
    final r0 = Vector4(s[0], s[4], s[8], s[12]);
    final r1 = Vector4(s[1], s[5], s[9], s[13]);
    final r2 = Vector4(s[2], s[6], s[10], s[14]);
    final r3 = Vector4(s[3], s[7], s[11], s[15]);

    Plane makePlane(Vector4 vec) {
      final len = math.sqrt(vec.x * vec.x + vec.y * vec.y + vec.z * vec.z);
      if (len > 0.0) {
        return Plane.components(
          vec.x / len,
          vec.y / len,
          vec.z / len,
          vec.w / len,
        );
      }
      return Plane.components(0.0, 0.0, 0.0, 0.0);
    }

    return FrustumPlanes([
      makePlane(r3 + r0), // Left
      makePlane(r3 - r0), // Right
      makePlane(r3 + r1), // Bottom
      makePlane(r3 - r1), // Top
      makePlane(r3 + r2), // Near
      makePlane(r3 - r2), // Far
    ]);
  }

  /// Deprojects a 2D screen coordinate into a 3D world ray.
  CameraRay deprojectScreenToWorld(Vector2 screenPosition, Vector2 viewportSize) {
    final nx = (2.0 * screenPosition.x / viewportSize.x) - 1.0;
    final ny = 1.0 - (2.0 * screenPosition.y / viewportSize.y);

    final invVP = Matrix4.inverted(getViewProjectionMatrix());

    final nearClip = Vector4(nx, ny, -1.0, 1.0);
    final farClip = Vector4(nx, ny, 1.0, 1.0);

    final nearWorld = invVP * nearClip;
    final farWorld = invVP * farClip;

    final n = Vector3(nearWorld.x / nearWorld.w, nearWorld.y / nearWorld.w, nearWorld.z / nearWorld.w);
    final f = Vector3(farWorld.x / farWorld.w, farWorld.y / farWorld.w, farWorld.z / farWorld.w);

    final dir = (f - n).normalized();
    final origin = (projectionMode == CameraProjectionMode.perspective) ? worldLocation : n;

    return CameraRay(origin, dir);
  }

  /// Projects a 3D world point to 2D screen pixel coordinates (px, py, clip.w).
  Vector3? projectWorldToScreen(Vector3 worldPosition, Vector2 viewportSize) {
    final view = getViewMatrix();
    final viewPoint = view * Vector4(worldPosition.x, worldPosition.y, worldPosition.z, 1.0);

    if (viewPoint.z > -nearClipPlane) {
      return null;
    }

    final proj = getProjectionMatrix();
    final clip = proj * viewPoint;

    if (clip.w <= 0.0) {
      return null;
    }

    final ndcX = clip.x / clip.w;
    final ndcY = clip.y / clip.w;

    final px = (ndcX + 1.0) * 0.5 * viewportSize.x;
    final py = (1.0 - ndcY) * 0.5 * viewportSize.y;

    return Vector3(px, py, clip.w);
  }

  /// Synchronizes projection, lookAt, and exposure parameters with the native Filament camera.
  void syncWithFilamentCamera([dynamic camera]) {
    CameraNative? targetNative;
    if (camera is CameraNative) {
      targetNative = camera;
    } else if (camera is FilamentCamera) {
      targetNative = _FilamentCameraNative(camera);
    } else if (camera == null) {
      targetNative = _nativeCamera;
    }

    if (camera == null && targetNative == null && _wasBound) {
      throw StateError('Camera is unmounted, unassigned, or already disposed');
    }

    if (targetNative == null) {
      return;
    }

    if (!isActive && camera == null) {
      return;
    }

    // Projection dirty check
    if (projectionMode == CameraProjectionMode.perspective) {
      if (_lastSyncedProjectionMode != CameraProjectionMode.perspective ||
          _lastSyncedFov != fieldOfViewInDegrees ||
          _lastSyncedAspect != aspectRatio ||
          _lastSyncedNear != nearClipPlane ||
          _lastSyncedFar != farClipPlane) {
        targetNative.setProjection(
          fovDegrees: fieldOfViewInDegrees,
          aspect: aspectRatio,
          near: nearClipPlane,
          far: farClipPlane,
        );
        _lastSyncedProjectionMode = CameraProjectionMode.perspective;
        _lastSyncedFov = fieldOfViewInDegrees;
        _lastSyncedAspect = aspectRatio;
        _lastSyncedNear = nearClipPlane;
        _lastSyncedFar = farClipPlane;
      }
    } else {
      if (_lastSyncedProjectionMode != CameraProjectionMode.orthographic ||
          _lastSyncedOrthoWidth != orthographicWidth ||
          _lastSyncedAspect != aspectRatio ||
          _lastSyncedNear != nearClipPlane ||
          _lastSyncedFar != farClipPlane) {
        final halfWidth = orthographicWidth * 0.5;
        final halfHeight = halfWidth / aspectRatio;
        targetNative.setProjectionOrtho(
          left: -halfWidth,
          right: halfWidth,
          bottom: -halfHeight,
          top: halfHeight,
          near: nearClipPlane,
          far: farClipPlane,
        );
        _lastSyncedProjectionMode = CameraProjectionMode.orthographic;
        _lastSyncedOrthoWidth = orthographicWidth;
        _lastSyncedAspect = aspectRatio;
        _lastSyncedNear = nearClipPlane;
        _lastSyncedFar = farClipPlane;
      }
    }

    // LookAt per frame
    final eye = worldLocation + _shakeLocationOffset;
    final center = eye + forwardVector;
    final up = upVector;
    targetNative.lookAt(
      eyeX: eye.x,
      eyeY: eye.y,
      eyeZ: eye.z,
      centerX: center.x,
      centerY: center.y,
      centerZ: center.z,
      upX: up.x,
      upY: up.y,
      upZ: up.z,
    );

    // Exposure dirty check
    if (_lastSyncedAperture != aperture ||
        _lastSyncedShutterSpeed != shutterSpeed ||
        _lastSyncedSensitivity != sensitivity) {
      targetNative.setExposure(
        aperture: aperture,
        shutterSpeed: shutterSpeed,
        sensitivity: sensitivity,
      );
      _lastSyncedAperture = aperture;
      _lastSyncedShutterSpeed = shutterSpeed;
      _lastSyncedSensitivity = sensitivity;
    }
  }

  @override
  void onUnregister() {
    unbindFromFilament();
    super.onUnregister();
  }
}
