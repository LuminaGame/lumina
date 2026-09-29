[Türkçe](../../tr/flutter_filament/camera-and-manipulator.md)

# Camera and manipulator

The Filament camera (projection, exposure, model and view matrices) and the camera manipulator that turns pointer and key input into orbit, map and free-flight camera motion. File paths are relative to the `flutter_filament/` package directory.

**On this page:**

- [Native C bridge](#native-c-bridge)
  - [`src/camera_c.h`](#srccamera_ch)
  - [`src/manipulator_c.h`](#srcmanipulator_ch)
- [Dart API](#dart-api)
  - [`lib/src/camera.dart`](#libsrccameradart)
  - [`lib/src/manipulator.dart`](#libsrcmanipulatordart)

## Native C bridge

The C functions below are declared in the package's `src/` headers and called from Dart through FFI.

### `src/camera_c.h`

| C Function | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `filament_camera_set_model_matrix` | `void filament_camera_set_model_matrix(void* camera, const double* m...` | Updates the `filament_camera_set_model_matrix` parameter or state in the native C layer. |
| `filament_camera_set_model_matrix_f` | `void filament_camera_set_model_matrix_f(void* camera, const float* ...` | Updates the `filament_camera_set_model_matrix_f` parameter or state in the native C layer. |
| `filament_camera_get_model_matrix` | `void filament_camera_get_model_matrix(void* camera, double* out_mat...` | Queries the `filament_camera_get_model_matrix` state, property, or counter from the native C layer. |
| `filament_camera_get_view_matrix` | `void filament_camera_get_view_matrix(void* camera, double* out_matr...` | Queries the `filament_camera_get_view_matrix` state, property, or counter from the native C layer. |
| `filament_camera_get_position` | `void filament_camera_get_position(void* camera, double* out_xyz);` | Queries the `filament_camera_get_position` state, property, or counter from the native C layer. |
| `filament_camera_get_left_vector` | `void filament_camera_get_left_vector(void* camera, float* out_xyz);` | Queries the `filament_camera_get_left_vector` state, property, or counter from the native C layer. |
| `filament_camera_get_up_vector` | `void filament_camera_get_up_vector(void* camera, float* out_xyz);` | Queries the `filament_camera_get_up_vector` state, property, or counter from the native C layer. |
| `filament_camera_get_forward_vector` | `void filament_camera_get_forward_vector(void* camera, float* out_xyz);` | Queries the `filament_camera_get_forward_vector` state, property, or counter from the native C layer. |
| `filament_camera_get_frustum_planes` | `void filament_camera_get_frustum_planes(void* camera, float* out_pl...` | Queries the `filament_camera_get_frustum_planes` state, property, or counter from the native C layer. |
| `filament_camera_get_entity` | `uint32_t filament_camera_get_entity(void* camera);` | Queries the `filament_camera_get_entity` state, property, or counter from the native C layer. |
| `filament_camera_set_projection` | `void filament_camera_set_projection(void* camera, int projection_ty...` | Updates the `filament_camera_set_projection` parameter or state in the native C layer. |
| `filament_camera_set_projection_fov_direction` | `void filament_camera_set_projection_fov_direction(void* camera, dou...` | Updates the `filament_camera_set_projection_fov_direction` parameter or state in the native C layer. |
| `filament_camera_set_lens_projection` | `void filament_camera_set_lens_projection(void* camera, double focal...` | Updates the `filament_camera_set_lens_projection` parameter or state in the native C layer. |
| `filament_camera_set_custom_projection` | `void filament_camera_set_custom_projection(void* camera, const doub...` | Updates the `filament_camera_set_custom_projection` parameter or state in the native C layer. |
| `filament_camera_set_custom_projection_culling` | `void filament_camera_set_custom_projection_culling(void* camera, co...` | Updates the `filament_camera_set_custom_projection_culling` parameter or state in the native C layer. |
| `filament_camera_set_scaling` | `void filament_camera_set_scaling(void* camera, double x, double y);` | Updates the `filament_camera_set_scaling` parameter or state in the native C layer. |
| `filament_camera_get_scaling` | `void filament_camera_get_scaling(void* camera, double* out_xyzw);` | Queries the `filament_camera_get_scaling` state, property, or counter from the native C layer. |
| `filament_camera_set_shift` | `void filament_camera_set_shift(void* camera, double x, double y);` | Updates the `filament_camera_set_shift` parameter or state in the native C layer. |
| `filament_camera_get_shift` | `void filament_camera_get_shift(void* camera, double* out_xy);` | Queries the `filament_camera_get_shift` state, property, or counter from the native C layer. |
| `filament_camera_get_projection_matrix` | `void filament_camera_get_projection_matrix(void* camera, double* ou...` | Queries the `filament_camera_get_projection_matrix` state, property, or counter from the native C layer. |
| `filament_camera_get_culling_projection_matrix` | `void filament_camera_get_culling_projection_matrix(void* camera, do...` | Queries the `filament_camera_get_culling_projection_matrix` state, property, or counter from the native C layer. |
| `filament_camera_get_near` | `double filament_camera_get_near(void* camera);` | Queries the `filament_camera_get_near` state, property, or counter from the native C layer. |
| `filament_camera_get_culling_far` | `double filament_camera_get_culling_far(void* camera);` | Queries the `filament_camera_get_culling_far` state, property, or counter from the native C layer. |
| `filament_camera_static_projection` | `void filament_camera_static_projection(int direction, double fov_de...` | Executes native Filament `filament_camera_static_projection` C binding. |
| `filament_camera_static_inverse_projection` | `void filament_camera_static_inverse_projection(const double* projec...` | Executes native Filament `filament_camera_static_inverse_projection` C binding. |
| `filament_camera_set_exposure_physical` | `void filament_camera_set_exposure_physical(void* camera, float aper...` | Updates the `filament_camera_set_exposure_physical` parameter or state in the native C layer. |
| `filament_camera_set_exposure_ev100` | `void filament_camera_set_exposure_ev100(void* camera, float ev100);` | Updates the `filament_camera_set_exposure_ev100` parameter or state in the native C layer. |
| `filament_camera_get_aperture` | `float filament_camera_get_aperture(void* camera);` | Queries the `filament_camera_get_aperture` state, property, or counter from the native C layer. |
| `filament_camera_get_shutter_speed` | `float filament_camera_get_shutter_speed(void* camera);` | Queries the `filament_camera_get_shutter_speed` state, property, or counter from the native C layer. |
| `filament_camera_get_sensitivity` | `float filament_camera_get_sensitivity(void* camera);` | Queries the `filament_camera_get_sensitivity` state, property, or counter from the native C layer. |
| `filament_camera_get_focal_length` | `double filament_camera_get_focal_length(void* camera);` | Queries the `filament_camera_get_focal_length` state, property, or counter from the native C layer. |
| `filament_camera_get_field_of_view_in_degrees` | `double filament_camera_get_field_of_view_in_degrees(void* camera, i...` | Queries the `filament_camera_get_field_of_view_in_degrees` state, property, or counter from the native C layer. |
| `filament_camera_set_focus_distance` | `void filament_camera_set_focus_distance(void* camera, float distance);` | Updates the `filament_camera_set_focus_distance` parameter or state in the native C layer. |
| `filament_camera_get_focus_distance` | `float filament_camera_get_focus_distance(void* camera);` | Queries the `filament_camera_get_focus_distance` state, property, or counter from the native C layer. |

### `src/manipulator_c.h`

| C Function | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `filament_manipulator_create` | `FFI_PLUGIN_EXPORT void* filament_manipulator_create(int mode, int v...` | Allocates and initializes the native Filament `filament_manipulator_create` resource on the engine/GPU. |
| `filament_manipulator_destroy` | `FFI_PLUGIN_EXPORT void filament_manipulator_destroy(void* manipulat...` | Destroys the native Filament `filament_manipulator_destroy` resource and releases GPU/host memory. |
| `filament_manipulator_set_viewport` | `FFI_PLUGIN_EXPORT void filament_manipulator_set_viewport(void* mani...` | Updates the `filament_manipulator_set_viewport` parameter or state in the native C layer. |
| `filament_manipulator_grab_begin` | `FFI_PLUGIN_EXPORT void filament_manipulator_grab_begin(void* manipu...` | Executes native Filament `filament_manipulator_grab_begin` C binding. |
| `filament_manipulator_grab_update` | `FFI_PLUGIN_EXPORT void filament_manipulator_grab_update(void* manip...` | Executes native Filament `filament_manipulator_grab_update` C binding. |
| `filament_manipulator_grab_end` | `FFI_PLUGIN_EXPORT void filament_manipulator_grab_end(void* manipula...` | Executes native Filament `filament_manipulator_grab_end` C binding. |
| `filament_manipulator_scroll` | `FFI_PLUGIN_EXPORT void filament_manipulator_scroll(void* manipulato...` | Executes native Filament `filament_manipulator_scroll` C binding. |
| `filament_manipulator_update` | `FFI_PLUGIN_EXPORT void filament_manipulator_update(void* manipulato...` | Executes native Filament `filament_manipulator_update` C binding. |
| `filament_manipulator_key_down` | `FFI_PLUGIN_EXPORT void filament_manipulator_key_down(void* manipula...` | Executes native Filament `filament_manipulator_key_down` C binding. |
| `filament_manipulator_key_up` | `FFI_PLUGIN_EXPORT void filament_manipulator_key_up(void* manipulato...` | Executes native Filament `filament_manipulator_key_up` C binding. |
| `filament_manipulator_get_look_at` | `FFI_PLUGIN_EXPORT void filament_manipulator_get_look_at(void* manip...` | Queries the `filament_manipulator_get_look_at` state, property, or counter from the native C layer. |
| `filament_manipulator_raycast` | `FFI_PLUGIN_EXPORT bool filament_manipulator_raycast(void* manipulat...` | Executes native Filament `filament_manipulator_raycast` C binding. |
| `filament_manipulator_get_ray` | `FFI_PLUGIN_EXPORT void filament_manipulator_get_ray(void* manipulat...` | Queries the `filament_manipulator_get_ray` state, property, or counter from the native C layer. |
| `filament_manipulator_get_current_bookmark` | `FFI_PLUGIN_EXPORT void* filament_manipulator_get_current_bookmark(v...` | Queries the `filament_manipulator_get_current_bookmark` state, property, or counter from the native C layer. |
| `filament_manipulator_get_home_bookmark` | `FFI_PLUGIN_EXPORT void* filament_manipulator_get_home_bookmark(void...` | Queries the `filament_manipulator_get_home_bookmark` state, property, or counter from the native C layer. |
| `filament_manipulator_jump_to_bookmark` | `FFI_PLUGIN_EXPORT void filament_manipulator_jump_to_bookmark(void* ...` | Executes native Filament `filament_manipulator_jump_to_bookmark` C binding. |
| `filament_bookmark_interpolate` | `FFI_PLUGIN_EXPORT void* filament_bookmark_interpolate(void* a, void...` | Executes native Filament `filament_bookmark_interpolate` C binding. |
| `filament_bookmark_duration` | `FFI_PLUGIN_EXPORT double filament_bookmark_duration(void* a, void* b);` | Executes native Filament `filament_bookmark_duration` C binding. |
| `filament_bookmark_destroy` | `FFI_PLUGIN_EXPORT void filament_bookmark_destroy(void* bookmark);` | Destroys the native Filament `filament_bookmark_destroy` resource and releases GPU/host memory. |
| `filament_manipulator_builder_create` | `FFI_PLUGIN_EXPORT void* filament_manipulator_builder_create(void);` | Allocates and initializes the native Filament `filament_manipulator_builder_create` resource on the engine/GPU. |
| `filament_manipulator_builder_destroy` | `FFI_PLUGIN_EXPORT void filament_manipulator_builder_destroy(void* b...` | Destroys the native Filament `filament_manipulator_builder_destroy` resource and releases GPU/host memory. |
| `filament_manipulator_builder_viewport` | `FFI_PLUGIN_EXPORT void filament_manipulator_builder_viewport(void* ...` | Executes native Filament `filament_manipulator_builder_viewport` C binding. |
| `filament_manipulator_builder_target_position` | `FFI_PLUGIN_EXPORT void filament_manipulator_builder_target_position...` | Queries the `filament_manipulator_builder_target_position` state, property, or counter from the native C layer. |
| `filament_manipulator_builder_up_vector` | `FFI_PLUGIN_EXPORT void filament_manipulator_builder_up_vector(void*...` | Executes native Filament `filament_manipulator_builder_up_vector` C binding. |
| `filament_manipulator_builder_zoom_speed` | `FFI_PLUGIN_EXPORT void filament_manipulator_builder_zoom_speed(void...` | Executes native Filament `filament_manipulator_builder_zoom_speed` C binding. |
| `filament_manipulator_builder_orbit_home_position` | `FFI_PLUGIN_EXPORT void filament_manipulator_builder_orbit_home_posi...` | Executes native Filament `filament_manipulator_builder_orbit_home_position` C binding. |
| `filament_manipulator_builder_orbit_speed` | `FFI_PLUGIN_EXPORT void filament_manipulator_builder_orbit_speed(voi...` | Executes native Filament `filament_manipulator_builder_orbit_speed` C binding. |
| `filament_manipulator_builder_fov_direction` | `FFI_PLUGIN_EXPORT void filament_manipulator_builder_fov_direction(v...` | Executes native Filament `filament_manipulator_builder_fov_direction` C binding. |
| `filament_manipulator_builder_fov_degrees` | `FFI_PLUGIN_EXPORT void filament_manipulator_builder_fov_degrees(voi...` | Executes native Filament `filament_manipulator_builder_fov_degrees` C binding. |
| `filament_manipulator_builder_far_plane` | `FFI_PLUGIN_EXPORT void filament_manipulator_builder_far_plane(void*...` | Executes native Filament `filament_manipulator_builder_far_plane` C binding. |
| `filament_manipulator_builder_map_extent` | `FFI_PLUGIN_EXPORT void filament_manipulator_builder_map_extent(void...` | Executes native Filament `filament_manipulator_builder_map_extent` C binding. |
| `filament_manipulator_builder_map_min_distance` | `FFI_PLUGIN_EXPORT void filament_manipulator_builder_map_min_distanc...` | Executes native Filament `filament_manipulator_builder_map_min_distance` C binding. |
| `filament_manipulator_builder_flight_start_position` | `FFI_PLUGIN_EXPORT void filament_manipulator_builder_flight_start_po...` | Executes native Filament `filament_manipulator_builder_flight_start_position` C binding. |
| `filament_manipulator_builder_flight_start_orientation` | `FFI_PLUGIN_EXPORT void filament_manipulator_builder_flight_start_or...` | Executes native Filament `filament_manipulator_builder_flight_start_orientation` C binding. |
| `filament_manipulator_builder_flight_max_move_speed` | `FFI_PLUGIN_EXPORT void filament_manipulator_builder_flight_max_move...` | Executes native Filament `filament_manipulator_builder_flight_max_move_speed` C binding. |
| `filament_manipulator_builder_flight_speed_steps` | `FFI_PLUGIN_EXPORT void filament_manipulator_builder_flight_speed_st...` | Executes native Filament `filament_manipulator_builder_flight_speed_steps` C binding. |
| `filament_manipulator_builder_flight_pan_speed` | `FFI_PLUGIN_EXPORT void filament_manipulator_builder_flight_pan_spee...` | Executes native Filament `filament_manipulator_builder_flight_pan_speed` C binding. |
| `filament_manipulator_builder_flight_move_damping` | `FFI_PLUGIN_EXPORT void filament_manipulator_builder_flight_move_dam...` | Executes native Filament `filament_manipulator_builder_flight_move_damping` C binding. |
| `filament_manipulator_builder_ground_plane` | `FFI_PLUGIN_EXPORT void filament_manipulator_builder_ground_plane(vo...` | Executes native Filament `filament_manipulator_builder_ground_plane` C binding. |
| `filament_manipulator_builder_panning` | `FFI_PLUGIN_EXPORT void filament_manipulator_builder_panning(void* b...` | Executes native Filament `filament_manipulator_builder_panning` C binding. |
| *... and 2 additional native C functions* | - | Library FFI bindings. |

## Dart API

### `lib/src/camera.dart`

#### `enum FovDirection`

Field-of-view direction.

**Constructors:**
- `FovDirection(this.value)`: Initializes `FovDirection(this.value)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `horizontal` | `horizontal(1)` | Executes `horizontal` operation. |
| `value` | `int value` | Holds the `value` property or configuration state. |

#### `enum ProjectionType`

Camera projection type.

**Constructors:**
- `ProjectionType(this.value)`: Initializes `ProjectionType(this.value)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `ortho` | `ortho(1)` | Executes `ortho` operation. |
| `value` | `int value` | Holds the `value` property or configuration state. |

#### `class FilamentCamera`

Camera represents the eye through which the scene is viewed.  A Camera has a position and orientation and controls the projection, exposure, and focus parameters.

**Constructors:**
- `FilamentCamera.internal(this._ptr, this._entity, this._engine)`: Internal constructor.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `entity` | `int get entity` | The entity this camera is attached to. |
| `modelMatrix` | `Matrix4 get modelMatrix` | Gets the camera's model matrix in world space (rigid transform, double precision). |
| `modelMatrix` | `modelMatrix(Matrix4 m)` | Sets the camera's model matrix (rigid transform, column-major). |
| `setModelMatrixF` | `void setModelMatrixF(Float32List fList)` | Sets the camera's model matrix from a float (32-bit) list. |
| `viewMatrix` | `Matrix4 get viewMatrix` | Returns the camera's view matrix (inverse of the model matrix). |
| `position` | `Vector3 get position` | Returns the camera's position in world space. |
| `leftVector` | `Vector3 get leftVector` | Returns the camera's normalized left vector in world space (-X in view space). |
| `upVector` | `Vector3 get upVector` | Returns the camera's normalized up vector in world space (+Y in view space). |
| `forwardVector` | `Vector3 get forwardVector` | Returns the camera's normalized forward vector in world space (-Z in view space). |
| `frustumPlanes` | `List<Vector4> get frustumPlanes` | Returns the 6 clipping frustum planes in normalized float4 (nx, ny, nz, d) form.  Order: left (0), right (1), bottom (2), top (3), far (4), near (5). |
| `scaling` | `scaling((double, double) s)` | Sets 2D scaling on projection matrix. |
| `scaling` | `Vector4 get scaling` | Gets 2D scaling applied after projection matrix (returned as Vector4 [x, y, 1, 1]). |
| `shift` | `shift((double, double) s)` | Sets 2D shift on projection matrix in NDC. |
| `shift` | `Vector2 get shift` | Gets 2D shift offsets on projection matrix. |
| `projectionMatrix` | `Matrix4 get projectionMatrix` | Returns the projection matrix used for rendering (far plane at infinity). |
| `cullingProjectionMatrix` | `Matrix4 get cullingProjectionMatrix` | Returns the culling projection matrix (finite far plane). |
| `near` | `double get near` | Near plane distance in world units. |
| `cullingFar` | `double get cullingFar` | Far plane distance used for culling in world units. |
| `inverseProjection` | `static Matrix4 inverseProjection(Matrix4 projection)` | Static helper to compute inverse projection matrix without an engine instance. |
| `setExposureEv100` | `void setExposureEv100(double ev100)` | Sets unit-less exposure directly. |
| `aperture` | `double get aperture` | Aperture in f-stops. |
| `shutterSpeed` | `double get shutterSpeed` | Shutter speed in seconds. |
| `sensitivity` | `double get sensitivity` | Sensitivity in ISO. |
| `focalLength` | `double get focalLength` | Focal length in meters (for a 35mm camera). |
| `getFieldOfViewInDegrees` | `double getFieldOfViewInDegrees(FovDirection direction)` | Field of view in degrees along the given [direction]. |
| `focusDistance` | `double get focusDistance` | Focus distance in world units (measured from camera). Used by Depth-of-Field post-processing. |
| `focusDistance` | `focusDistance(double distance)` | Executes `focusDistance` operation. |
| `isDisposed` | `bool get isDisposed` | Whether this camera has been disposed. |
| `dispose` | `void dispose()` | Destroys this camera component in the Filament engine. |

### `lib/src/manipulator.dart`

#### `enum ManipulatorMode`

Camera interaction mode.

**Constructors:**
- `ManipulatorMode(this.value)`: Initializes `ManipulatorMode(this.value)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `freeFlight` | `freeFlight(2)` | Executes `freeFlight` operation. |
| `value` | `int value` | Holds the `value` property or configuration state. |

#### `enum ManipulatorKey`

Key types for flight manipulator movement.

**Constructors:**
- `ManipulatorKey(this.value)`: Initializes `ManipulatorKey(this.value)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `down` | `down(5)` | Executes `down` operation. |
| `value` | `int value` | Holds the `value` property or configuration state. |

#### `class LookAtResult`

A container for camera vectors (eye, center, up).

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `eye` | `List<double> eye` | Holds the `eye` property or configuration state. |
| `center` | `List<double> center` | Holds the `center` property or configuration state. |
| `up` | `List<double> up` | Holds the `up` property or configuration state. |
| `target` | `List<double> get target` | Alias for [center] (target point of interest). |

#### `class Bookmark`

Represents a saved camera position/viewpoint (memento) created by a [FilamentManipulator].

**Constructors:**
- `Bookmark._(this._ptr, this.mode)`: Initializes `Bookmark._(this._ptr, this.mode)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `mode` | `ManipulatorMode mode` | Holds the `mode` property or configuration state. |
| `interpolate` | `static Bookmark interpolate(Bookmark a, Bookmark b, double t)` | Interpolates between two bookmarks.  [t] is clamped to [0.0, 1.0]. Both bookmarks must have been captured in the same [ManipulatorMode]. |
| `duration` | `static double duration(Bookmark a, Bookmark b)` | Calculates a recommended flight/animation duration (in reference seconds) between two bookmarks. |
| `dispose` | `void dispose()` | Destroys this bookmark handle. |
| `isDisposed` | `bool get isDisposed` | Checks current state or capability and returns a boolean value. |

#### `class FilamentCameraManipulator`

Helper for interactive camera controls (Orbit, Map, FreeFlight) driven by touch or mouse events.  **Important**: In [ManipulatorMode.freeFlight] mode, you MUST call [update] once every frame with the frame delta time in seconds (e.g. `1.0 / 60.0`). The flight camera's inertia and key-driven translation will not move without calling [update].

**Constructors:**
- `FilamentCameraManipulator._(this._ptr, [this.mode = ManipulatorMode.orbit])`: Initializes `FilamentCameraManipulator._(this._ptr, [this.mode = ManipulatorMode.orbit])`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `mode` | `ManipulatorMode mode` | Holds the `mode` property or configuration state. |
| `setViewport` | `void setViewport(int width, int height)` | Updates viewport dimensions. |
| `grabUpdate` | `void grabUpdate(int x, int y)` | Updates current drag position ([x], [y]). |
| `grabEnd` | `void grabEnd()` | Ends current drag gesture. |
| `scroll` | `void scroll(int x, int y, double scrollDelta)` | Handles mouse wheel or pinch zoom at ([x], [y]) with [scrollDelta]. |
| `update` | `void update(double deltaTimeSeconds)` | Processes input and updates camera physics, damping, and inertia.  Must be called once every frame with the delta time in seconds (e.g. `1.0 / 60.0`). |
| `keyDown` | `void keyDown(ManipulatorKey key)` | Signals that a navigation key is pressed down. |
| `keyUp` | `void keyUp(ManipulatorKey key)` | Signals that a navigation key is released. |
| `getLookAt` | `LookAtResult getLookAt()` | Queries calculated eye, center, and up vectors. |
| `updateCamera` | `void updateCamera(FilamentCamera camera)` | Helper to apply current manipulator vectors directly to [camera]. |
| `raycast` | `List<double>? raycast(int x, int y)` | Casts a ray from the given viewport coordinates ([x], [y]). Returns the hit point on the manipulator's target/ground plane, or null if no hit. Note: The viewport origin is bottom-left. |
| `raycastFlutter` | `List<double>? raycastFlutter(double dx, double dy, double viewportHeight)` | Casts a ray from the given viewport coordinates ([dx], [dy]) assuming a top-left origin. This is a convenience method for Flutter which uses top-left coordinates. |
| `currentBookmark` | `Bookmark get currentBookmark` | Gets a bookmark representing the current camera viewpoint state. |
| `homeBookmark` | `Bookmark get homeBookmark` | Gets a bookmark representing the initial/home camera viewpoint state. |
| `jumpToBookmark` | `void jumpToBookmark(Bookmark bookmark)` | Resets the manipulator viewpoint to a previously saved [bookmark]. |
| `dispose` | `void dispose()` | Destroys this manipulator. |
| `isDisposed` | `bool get isDisposed` | Checks current state or capability and returns a boolean value. |

#### `class ManipulatorBuilder`

A builder for [FilamentCameraManipulator].

**Constructors:**
- `ManipulatorBuilder() : _ptr = c.filament_manipulator_builder_create()`: Initializes `ManipulatorBuilder() : _ptr = c.filament_manipulator_builder_create()`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `viewport` | `ManipulatorBuilder viewport(int width, int height)` | Sets the viewport dimensions. |
| `targetPosition` | `ManipulatorBuilder targetPosition(double x, double y, double z)` | Sets the target position (center of interest). |
| `upVector` | `ManipulatorBuilder upVector(double x, double y, double z)` | Sets the up vector. |
| `zoomSpeed` | `ManipulatorBuilder zoomSpeed(double val)` | Sets the zoom speed. |
| `orbitHomePosition` | `ManipulatorBuilder orbitHomePosition(double x, double y, double z)` | Sets the initial eye position in orbit mode. |
| `orbitSpeed` | `ManipulatorBuilder orbitSpeed(double x, double y)` | Sets the orbit speed multiplier. |
| `fovDirection` | `ManipulatorBuilder fovDirection(FovDirection direction)` | Sets the FOV direction. |
| `fovDegrees` | `ManipulatorBuilder fovDegrees(double degrees)` | Sets the FOV degrees. |
| `farPlane` | `ManipulatorBuilder farPlane(double distance)` | Sets the far plane distance. |
| `mapExtent` | `ManipulatorBuilder mapExtent(double width, double height)` | Sets the map mode extent. |
| `mapMinDistance` | `ManipulatorBuilder mapMinDistance(double dist)` | Sets the map mode minimum distance. |
| `flightStartPosition` | `ManipulatorBuilder flightStartPosition(double x, double y, double z)` | Sets the flight mode start position. |
| `flightStartOrientation` | `ManipulatorBuilder flightStartOrientation(double pitch, double yaw)` | Sets the flight mode start orientation (in radians). |
| `flightMaxMoveSpeed` | `ManipulatorBuilder flightMaxMoveSpeed(double speed)` | Sets the flight mode maximum move speed. |
| `flightSpeedSteps` | `ManipulatorBuilder flightSpeedSteps(int steps)` | Sets the flight mode speed steps. |
| `flightPanSpeed` | `ManipulatorBuilder flightPanSpeed(double x, double y)` | Sets the flight mode pan speed. |
| `flightMoveDamping` | `ManipulatorBuilder flightMoveDamping(double damping)` | Sets the flight mode movement damping. |
| `groundPlane` | `ManipulatorBuilder groundPlane(double a, double b, double valC, double d)` | Sets the ground plane. |
| `panning` | `ManipulatorBuilder panning(bool enabled)` | Enables or disables panning. |
| `raycastCallback` | `ManipulatorBuilder raycastCallback(double Function(List<double> origin, ...` | Sets an optional raycast callback. The callback takes origin and dir vectors, and returns a t value. |
| `build` | `FilamentCameraManipulator build(ManipulatorMode mode)` | Builds a [FilamentCameraManipulator] instance in the given [mode]. The builder can be reused to create multiple instances, but their configurations are copied at build time. |
| `dispose` | `void dispose()` | Disposes this builder. |

---

[Previous: Scene and geometry](scene-and-geometry.md) | [Up: flutter_filament](index.md) | [Next: Lighting and image-based lighting](lighting-and-ibl.md)
