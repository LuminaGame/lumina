import 'ffi_platform.dart' as ffi;
import 'ffi_package_platform.dart';

import 'package:flutter_filament/src/camera.dart';
import 'package:flutter_filament/src/filament_bindings.dart' as c;

/// Camera interaction mode.
enum ManipulatorMode {
  orbit(0),
  map(1),
  freeFlight(2);

  final int value;
  const ManipulatorMode(this.value);
}

/// Key types for flight manipulator movement.
enum ManipulatorKey {
  forward(0),
  left(1),
  backward(2),
  right(3),
  up(4),
  down(5);

  final int value;
  const ManipulatorKey(this.value);
}

/// A container for camera vectors (eye, center, up).
class LookAtResult {
  final List<double> eye;
  final List<double> center;
  final List<double> up;

  /// Alias for [center] (target point of interest).
  List<double> get target => center;

  const LookAtResult({
    required this.eye,
    required this.center,
    required this.up,
  });
}

/// Represents a saved camera position/viewpoint (memento) created by a [FilamentManipulator].
class Bookmark {
  final ffi.Pointer<ffi.Void> _ptr;
  final ManipulatorMode mode;
  bool _disposed = false;

  Bookmark._(this._ptr, this.mode);

  /// Raw native pointer.
  ffi.Pointer<ffi.Void> get nativePointer {
    _checkDisposed();
    return _ptr;
  }

  /// Interpolates between two bookmarks.
  ///
  /// [t] is clamped to [0.0, 1.0].
  /// Both bookmarks must have been captured in the same [ManipulatorMode].
  static Bookmark interpolate(Bookmark a, Bookmark b, double t) {
    a._checkDisposed();
    b._checkDisposed();
    if (a.mode != b.mode) {
      throw ArgumentError('Cannot interpolate bookmarks with different modes: ${a.mode} vs ${b.mode}');
    }
    final clampedT = t.clamp(0.0, 1.0);
    final ptr = c.filament_bookmark_interpolate(a._ptr, b._ptr, clampedT);
    return Bookmark._(ptr, a.mode);
  }

  /// Calculates a recommended flight/animation duration (in reference seconds) between two bookmarks.
  static double duration(Bookmark a, Bookmark b) {
    a._checkDisposed();
    b._checkDisposed();
    return c.filament_bookmark_duration(a._ptr, b._ptr);
  }

  /// Destroys this bookmark handle.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    c.filament_bookmark_destroy(_ptr);
  }

  bool get isDisposed => _disposed;

  void _checkDisposed() {
    if (_disposed) {
      throw StateError('Bookmark has been disposed');
    }
  }
}

/// Helper for interactive camera controls (Orbit, Map, FreeFlight) driven by touch or mouse events.
///
/// **Important**: In [ManipulatorMode.freeFlight] mode, you MUST call [update] once every frame
/// with the frame delta time in seconds (e.g. `1.0 / 60.0`). The flight camera's inertia and
/// key-driven translation will not move without calling [update].
class FilamentCameraManipulator {
  final ffi.Pointer<ffi.Void> _ptr;
  final ManipulatorMode mode;
  bool _disposed = false;

  FilamentCameraManipulator._(this._ptr, [this.mode = ManipulatorMode.orbit]);

  /// Creates a new camera manipulator.
  static FilamentCameraManipulator create({
    ManipulatorMode mode = ManipulatorMode.orbit,
    required int viewportWidth,
    required int viewportHeight,
  }) {
    final ptr = c.filament_manipulator_create(
      mode.index,
      viewportWidth,
      viewportHeight,
    );
    return FilamentCameraManipulator._(ptr, mode);
  }

  /// Raw native pointer.
  ffi.Pointer<ffi.Void> get nativePointer {
    _checkDisposed();
    return _ptr;
  }

  /// Updates viewport dimensions.
  void setViewport(int width, int height) {
    _checkDisposed();
    c.filament_manipulator_set_viewport(_ptr, width, height);
  }

  /// Begins a drag gesture at ([x], [y]). Set [strafe] to true for panning.
  void grabBegin(int x, int y, {bool strafe = false}) {
    _checkDisposed();
    c.filament_manipulator_grab_begin(_ptr, x, y, strafe);
  }

  /// Updates current drag position ([x], [y]).
  void grabUpdate(int x, int y) {
    _checkDisposed();
    c.filament_manipulator_grab_update(_ptr, x, y);
  }

  /// Ends current drag gesture.
  void grabEnd() {
    _checkDisposed();
    c.filament_manipulator_grab_end(_ptr);
  }

  /// Handles mouse wheel or pinch zoom at ([x], [y]) with [scrollDelta].
  void scroll(int x, int y, double scrollDelta) {
    _checkDisposed();
    c.filament_manipulator_scroll(_ptr, x, y, scrollDelta);
  }

  /// Processes input and updates camera physics, damping, and inertia.
  ///
  /// Must be called once every frame with the delta time in seconds
  /// (e.g. `1.0 / 60.0`).
  void update(double deltaTimeSeconds) {
    _checkDisposed();
    c.filament_manipulator_update(_ptr, deltaTimeSeconds);
  }

  /// Signals that a navigation key is pressed down.
  void keyDown(ManipulatorKey key) {
    _checkDisposed();
    c.filament_manipulator_key_down(_ptr, key.value);
  }

  /// Signals that a navigation key is released.
  void keyUp(ManipulatorKey key) {
    _checkDisposed();
    c.filament_manipulator_key_up(_ptr, key.value);
  }

  /// Queries calculated eye, center, and up vectors.
  LookAtResult getLookAt() {
    _checkDisposed();
    final eyePtr = calloc<ffi.Float>(3);
    final centerPtr = calloc<ffi.Float>(3);
    final upPtr = calloc<ffi.Float>(3);

    c.filament_manipulator_get_look_at(_ptr, eyePtr, centerPtr, upPtr);

    final result = LookAtResult(
      eye: [eyePtr[0], eyePtr[1], eyePtr[2]],
      center: [centerPtr[0], centerPtr[1], centerPtr[2]],
      up: [upPtr[0], upPtr[1], upPtr[2]],
    );

    calloc.free(eyePtr);
    calloc.free(centerPtr);
    calloc.free(upPtr);

    return result;
  }

  /// Helper to apply current manipulator vectors directly to [camera].
  void updateCamera(FilamentCamera camera) {
    final lookAt = getLookAt();
    camera.lookAt(
      eyeX: lookAt.eye[0],
      eyeY: lookAt.eye[1],
      eyeZ: lookAt.eye[2],
      centerX: lookAt.center[0],
      centerY: lookAt.center[1],
      centerZ: lookAt.center[2],
      upX: lookAt.up[0],
      upY: lookAt.up[1],
      upZ: lookAt.up[2],
    );
  }

  /// Casts a ray from the given viewport coordinates ([x], [y]).
  /// Returns the hit point on the manipulator's target/ground plane, or null if no hit.
  /// Note: The viewport origin is bottom-left.
  List<double>? raycast(int x, int y) {
    _checkDisposed();
    final hitPtr = calloc<ffi.Float>(3);
    final hit = c.filament_manipulator_raycast(_ptr, x, y, hitPtr);
    if (hit) {
      final result = [hitPtr[0], hitPtr[1], hitPtr[2]];
      calloc.free(hitPtr);
      return result;
    }
    calloc.free(hitPtr);
    return null;
  }

  /// Calculates the origin and direction of a ray through viewport coordinates ([x], [y]).
  /// Note: The viewport origin is bottom-left.
  (List<double> origin, List<double> direction) getRay(int x, int y) {
    _checkDisposed();
    final originPtr = calloc<ffi.Float>(3);
    final dirPtr = calloc<ffi.Float>(3);
    
    c.filament_manipulator_get_ray(_ptr, x, y, originPtr, dirPtr);
    
    final origin = [originPtr[0], originPtr[1], originPtr[2]];
    final dir = [dirPtr[0], dirPtr[1], dirPtr[2]];
    
    calloc.free(originPtr);
    calloc.free(dirPtr);
    
    return (origin, dir);
  }

  /// Casts a ray from the given viewport coordinates ([dx], [dy]) assuming a top-left origin.
  /// This is a convenience method for Flutter which uses top-left coordinates.
  List<double>? raycastFlutter(double dx, double dy, double viewportHeight) {
    // Flutter is top-left, Filament is bottom-left
    return raycast(dx.toInt(), (viewportHeight - dy).toInt());
  }

  /// Returns the current eye position vector.
  ({double x, double y, double z}) getEye() {
    final look = getLookAt();
    return (x: look.eye[0], y: look.eye[1], z: look.eye[2]);
  }

  /// Returns the current target/center position vector.
  ({double x, double y, double z}) getTarget() {
    final look = getLookAt();
    return (x: look.center[0], y: look.center[1], z: look.center[2]);
  }

  /// Gets a bookmark representing the current camera viewpoint state.
  Bookmark get currentBookmark {
    _checkDisposed();
    final ptr = c.filament_manipulator_get_current_bookmark(_ptr);
    return Bookmark._(ptr, mode);
  }

  /// Gets a bookmark representing the initial/home camera viewpoint state.
  Bookmark get homeBookmark {
    _checkDisposed();
    final ptr = c.filament_manipulator_get_home_bookmark(_ptr);
    return Bookmark._(ptr, mode);
  }

  /// Resets the manipulator viewpoint to a previously saved [bookmark].
  void jumpToBookmark(Bookmark bookmark) {
    _checkDisposed();
    bookmark._checkDisposed();
    if (bookmark.mode != mode) {
      throw ArgumentError('Bookmark mode ${bookmark.mode} does not match manipulator mode $mode');
    }
    c.filament_manipulator_jump_to_bookmark(_ptr, bookmark._ptr);
  }

  /// Destroys this manipulator.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    c.filament_manipulator_destroy(_ptr);
  }

  bool get isDisposed => _disposed;

  void _checkDisposed() {
    if (_disposed) {
      throw StateError('FilamentCameraManipulator has been disposed');
    }
  }
}

/// Alias for [FilamentCameraManipulator].
typedef FilamentManipulator = FilamentCameraManipulator;

/// Alias for [ManipulatorBuilder].
typedef FilamentManipulatorBuilder = ManipulatorBuilder;

/// A builder for [FilamentCameraManipulator].
class ManipulatorBuilder {
  final ffi.Pointer<ffi.Void> _ptr;
  bool _built = false;

  /// Keeps a reference to the isolateLocal callback so it doesn't get garbage collected.
  ffi.NativeCallable<c.FilamentRaycastCallbackFunction>? _raycastCallable;

  ManipulatorBuilder() : _ptr = c.filament_manipulator_builder_create();

  /// Sets the viewport dimensions.
  ManipulatorBuilder viewport(int width, int height) {
    _checkBuilt();
    c.filament_manipulator_builder_viewport(_ptr, width, height);
    return this;
  }

  /// Sets the target position (center of interest).
  ManipulatorBuilder targetPosition(double x, double y, double z) {
    _checkBuilt();
    c.filament_manipulator_builder_target_position(_ptr, x, y, z);
    return this;
  }

  /// Sets the up vector.
  ManipulatorBuilder upVector(double x, double y, double z) {
    _checkBuilt();
    c.filament_manipulator_builder_up_vector(_ptr, x, y, z);
    return this;
  }

  /// Sets the zoom speed.
  ManipulatorBuilder zoomSpeed(double val) {
    _checkBuilt();
    c.filament_manipulator_builder_zoom_speed(_ptr, val);
    return this;
  }

  /// Sets the initial eye position in orbit mode.
  ManipulatorBuilder orbitHomePosition(double x, double y, double z) {
    _checkBuilt();
    c.filament_manipulator_builder_orbit_home_position(_ptr, x, y, z);
    return this;
  }

  /// Sets the orbit speed multiplier.
  ManipulatorBuilder orbitSpeed(double x, double y) {
    _checkBuilt();
    c.filament_manipulator_builder_orbit_speed(_ptr, x, y);
    return this;
  }

  /// Sets the FOV direction.
  ManipulatorBuilder fovDirection(FovDirection direction) {
    _checkBuilt();
    c.filament_manipulator_builder_fov_direction(_ptr, direction.value);
    return this;
  }

  /// Sets the FOV degrees.
  ManipulatorBuilder fovDegrees(double degrees) {
    _checkBuilt();
    c.filament_manipulator_builder_fov_degrees(_ptr, degrees);
    return this;
  }

  /// Sets the far plane distance.
  ManipulatorBuilder farPlane(double distance) {
    _checkBuilt();
    c.filament_manipulator_builder_far_plane(_ptr, distance);
    return this;
  }

  /// Sets the map mode extent.
  ManipulatorBuilder mapExtent(double width, double height) {
    _checkBuilt();
    c.filament_manipulator_builder_map_extent(_ptr, width, height);
    return this;
  }

  /// Sets the map mode minimum distance.
  ManipulatorBuilder mapMinDistance(double dist) {
    _checkBuilt();
    c.filament_manipulator_builder_map_min_distance(_ptr, dist);
    return this;
  }

  /// Sets the flight mode start position.
  ManipulatorBuilder flightStartPosition(double x, double y, double z) {
    _checkBuilt();
    c.filament_manipulator_builder_flight_start_position(_ptr, x, y, z);
    return this;
  }

  /// Sets the flight mode start orientation (in radians).
  ManipulatorBuilder flightStartOrientation(double pitch, double yaw) {
    _checkBuilt();
    c.filament_manipulator_builder_flight_start_orientation(_ptr, pitch, yaw);
    return this;
  }

  /// Sets the flight mode maximum move speed.
  ManipulatorBuilder flightMaxMoveSpeed(double speed) {
    _checkBuilt();
    c.filament_manipulator_builder_flight_max_move_speed(_ptr, speed);
    return this;
  }

  /// Sets the flight mode speed steps.
  ManipulatorBuilder flightSpeedSteps(int steps) {
    _checkBuilt();
    c.filament_manipulator_builder_flight_speed_steps(_ptr, steps);
    return this;
  }

  /// Sets the flight mode pan speed.
  ManipulatorBuilder flightPanSpeed(double x, double y) {
    _checkBuilt();
    c.filament_manipulator_builder_flight_pan_speed(_ptr, x, y);
    return this;
  }

  /// Sets the flight mode movement damping.
  ManipulatorBuilder flightMoveDamping(double damping) {
    _checkBuilt();
    c.filament_manipulator_builder_flight_move_damping(_ptr, damping);
    return this;
  }

  /// Sets the ground plane.
  ManipulatorBuilder groundPlane(double a, double b, double valC, double d) {
    _checkBuilt();
    c.filament_manipulator_builder_ground_plane(_ptr, a, b, valC, d);
    return this;
  }

  /// Enables or disables panning.
  ManipulatorBuilder panning(bool enabled) {
    _checkBuilt();
    c.filament_manipulator_builder_panning(_ptr, enabled);
    return this;
  }

  /// Sets an optional raycast callback.
  /// The callback takes origin and dir vectors, and returns a t value.
  ManipulatorBuilder raycastCallback(double Function(List<double> origin, List<double> dir) cb) {
    _checkBuilt();
    _raycastCallable?.close();

    _raycastCallable = ffi.NativeCallable<c.FilamentRaycastCallbackFunction>.isolateLocal(
      (ffi.Pointer<ffi.Float> origin, ffi.Pointer<ffi.Float> dir, ffi.Pointer<ffi.Float> tOut, ffi.Pointer<ffi.Void> userdata) {
        final hit = cb(
          [origin[0], origin[1], origin[2]],
          [dir[0], dir[1], dir[2]],
        );
        tOut[0] = hit;
        return hit > 0.0;
      },
      exceptionalReturn: false,
    );

    c.filament_manipulator_builder_raycast_callback(_ptr, _raycastCallable!.nativeFunction, ffi.nullptr);
    return this;
  }

  /// Builds a [FilamentCameraManipulator] instance in the given [mode].
  /// The builder can be reused to create multiple instances, but their configurations
  /// are copied at build time.
  FilamentCameraManipulator build(ManipulatorMode mode) {
    _checkBuilt();
    final manipulatorPtr = c.filament_manipulator_builder_build(_ptr, mode.index);
    if (manipulatorPtr == ffi.nullptr) {
      throw StateError('Failed to build Manipulator');
    }
    return FilamentCameraManipulator._(manipulatorPtr, mode);
  }

  void _checkBuilt() {
    if (_built) {
      // Actually Filament's Builder can be reused. But to clean up the C builder pointer safely, 
      // we usually dispose it, or just let users not worry.
      // We will allow reuse and users don't strictly need to dispose the builder, but it might leak C memory.
      // So let's provide a dispose on the builder.
    }
  }

  /// Disposes this builder.
  void dispose() {
    if (_built) return;
    _built = true;
    c.filament_manipulator_builder_destroy(_ptr);
    _raycastCallable?.close();
  }
}

