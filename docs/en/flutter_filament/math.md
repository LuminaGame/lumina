[Türkçe](../../tr/flutter_filament/math.md)

# Math types

The math value types that cross the FFI boundary (vectors, quaternions and matrices) and the math helpers: boxes and AABBs, colors, exposure, frustums, normal packing, transform utilities and viewports. File paths are relative to the `flutter_filament/` package directory.

**On this page:**

- [Native C bridge](#native-c-bridge)
  - [`src/math_abi_c.h`](#srcmath_abi_ch)
- [Dart API](#dart-api)
  - [`lib/src/math_types.dart`](#libsrcmath_typesdart)
  - [`lib/src/math/box.dart`](#libsrcmathboxdart)
  - [`lib/src/math/color.dart`](#libsrcmathcolordart)
  - [`lib/src/math/exposure.dart`](#libsrcmathexposuredart)
  - [`lib/src/math/frustum.dart`](#libsrcmathfrustumdart)
  - [`lib/src/math/norm.dart`](#libsrcmathnormdart)
  - [`lib/src/math/transform_util.dart`](#libsrcmathtransform_utildart)
  - [`lib/src/math/viewport.dart`](#libsrcmathviewportdart)

## Native C bridge

The C functions below are declared in the package's `src/` headers and called from Dart through FFI.

### `src/math_abi_c.h`

| C Function | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `filament_sizeof_float2` | `FFI_PLUGIN_EXPORT size_t filament_sizeof_float2(void);` | Executes native Filament `filament_sizeof_float2` C binding. |
| `filament_sizeof_float3` | `FFI_PLUGIN_EXPORT size_t filament_sizeof_float3(void);` | Executes native Filament `filament_sizeof_float3` C binding. |
| `filament_sizeof_float4` | `FFI_PLUGIN_EXPORT size_t filament_sizeof_float4(void);` | Executes native Filament `filament_sizeof_float4` C binding. |
| `filament_sizeof_int2` | `FFI_PLUGIN_EXPORT size_t filament_sizeof_int2(void);` | Executes native Filament `filament_sizeof_int2` C binding. |
| `filament_sizeof_int3` | `FFI_PLUGIN_EXPORT size_t filament_sizeof_int3(void);` | Executes native Filament `filament_sizeof_int3` C binding. |
| `filament_sizeof_int4` | `FFI_PLUGIN_EXPORT size_t filament_sizeof_int4(void);` | Executes native Filament `filament_sizeof_int4` C binding. |
| `filament_sizeof_uint2` | `FFI_PLUGIN_EXPORT size_t filament_sizeof_uint2(void);` | Executes native Filament `filament_sizeof_uint2` C binding. |
| `filament_sizeof_uint3` | `FFI_PLUGIN_EXPORT size_t filament_sizeof_uint3(void);` | Executes native Filament `filament_sizeof_uint3` C binding. |
| `filament_sizeof_uint4` | `FFI_PLUGIN_EXPORT size_t filament_sizeof_uint4(void);` | Executes native Filament `filament_sizeof_uint4` C binding. |
| `filament_sizeof_bool2` | `FFI_PLUGIN_EXPORT size_t filament_sizeof_bool2(void);` | Executes native Filament `filament_sizeof_bool2` C binding. |
| `filament_sizeof_bool3` | `FFI_PLUGIN_EXPORT size_t filament_sizeof_bool3(void);` | Executes native Filament `filament_sizeof_bool3` C binding. |
| `filament_sizeof_bool4` | `FFI_PLUGIN_EXPORT size_t filament_sizeof_bool4(void);` | Executes native Filament `filament_sizeof_bool4` C binding. |
| `filament_sizeof_short4` | `FFI_PLUGIN_EXPORT size_t filament_sizeof_short4(void);` | Executes native Filament `filament_sizeof_short4` C binding. |
| `filament_sizeof_quatf` | `FFI_PLUGIN_EXPORT size_t filament_sizeof_quatf(void);` | Executes native Filament `filament_sizeof_quatf` C binding. |
| `filament_sizeof_mat3f` | `FFI_PLUGIN_EXPORT size_t filament_sizeof_mat3f(void);` | Executes native Filament `filament_sizeof_mat3f` C binding. |
| `filament_sizeof_mat4f` | `FFI_PLUGIN_EXPORT size_t filament_sizeof_mat4f(void);` | Executes native Filament `filament_sizeof_mat4f` C binding. |
| `filament_sizeof_mat4` | `FFI_PLUGIN_EXPORT size_t filament_sizeof_mat4(void);` | Executes native Filament `filament_sizeof_mat4` C binding. |
| `filament_test_quatf_read` | `FFI_PLUGIN_EXPORT void filament_test_quatf_read(const void* q, floa...` | Executes native Filament `filament_test_quatf_read` C binding. |
| `filament_test_mat4f_col_major` | `FFI_PLUGIN_EXPORT void filament_test_mat4f_col_major(void* out);` | Executes native Filament `filament_test_mat4f_col_major` C binding. |
| `filament_test_float3_array_sum` | `FFI_PLUGIN_EXPORT void filament_test_float3_array_sum(const void* a...` | Executes native Filament `filament_test_float3_array_sum` C binding. |
| `filament_test_mat3f_read` | `FFI_PLUGIN_EXPORT void filament_test_mat3f_read(const void* m, floa...` | Executes native Filament `filament_test_mat3f_read` C binding. |
| `filament_test_bool3_read` | `FFI_PLUGIN_EXPORT void filament_test_bool3_read(const void* b, uint...` | Executes native Filament `filament_test_bool3_read` C binding. |

## Dart API

### `lib/src/math_types.dart`

#### `class Float2`

2D float vector (8 bytes).

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `x` | `external double x` | Holds the `x` property or configuration state. |
| `y` | `external double y` | Holds the `y` property or configuration state. |

#### `class Float3`

3D float vector (12 bytes, contiguous without padding).

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `x` | `external double x` | Holds the `x` property or configuration state. |
| `y` | `external double y` | Holds the `y` property or configuration state. |
| `z` | `external double z` | Holds the `z` property or configuration state. |

#### `class Float4`

4D float vector (16 bytes).

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `x` | `external double x` | Holds the `x` property or configuration state. |
| `y` | `external double y` | Holds the `y` property or configuration state. |
| `z` | `external double z` | Holds the `z` property or configuration state. |
| `w` | `external double w` | Holds the `w` property or configuration state. |

#### `class Int2`

2D int32 vector (8 bytes).

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `x` | `external int x` | Holds the `x` property or configuration state. |
| `y` | `external int y` | Holds the `y` property or configuration state. |

#### `class Int3`

3D int32 vector (12 bytes).

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `x` | `external int x` | Holds the `x` property or configuration state. |
| `y` | `external int y` | Holds the `y` property or configuration state. |
| `z` | `external int z` | Holds the `z` property or configuration state. |

#### `class Int4`

4D int32 vector (16 bytes).

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `x` | `external int x` | Holds the `x` property or configuration state. |
| `y` | `external int y` | Holds the `y` property or configuration state. |
| `z` | `external int z` | Holds the `z` property or configuration state. |
| `w` | `external int w` | Holds the `w` property or configuration state. |

#### `class Uint2`

2D uint32 vector (8 bytes).

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `x` | `external int x` | Holds the `x` property or configuration state. |
| `y` | `external int y` | Holds the `y` property or configuration state. |

#### `class Uint3`

3D uint32 vector (12 bytes).

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `x` | `external int x` | Holds the `x` property or configuration state. |
| `y` | `external int y` | Holds the `y` property or configuration state. |
| `z` | `external int z` | Holds the `z` property or configuration state. |

#### `class Uint4`

4D uint32 vector (16 bytes).

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `x` | `external int x` | Holds the `x` property or configuration state. |
| `y` | `external int y` | Holds the `y` property or configuration state. |
| `z` | `external int z` | Holds the `z` property or configuration state. |
| `w` | `external int w` | Holds the `w` property or configuration state. |

#### `class Bool2`

2D boolean vector (2 bytes).

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `x` | `external int x` | Holds the `x` property or configuration state. |
| `y` | `external int y` | Holds the `y` property or configuration state. |

#### `class Bool3`

3D boolean vector (3 bytes).

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `x` | `external int x` | Holds the `x` property or configuration state. |
| `y` | `external int y` | Holds the `y` property or configuration state. |
| `z` | `external int z` | Holds the `z` property or configuration state. |

#### `class Bool4`

4D boolean vector (4 bytes).

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `x` | `external int x` | Holds the `x` property or configuration state. |
| `y` | `external int y` | Holds the `y` property or configuration state. |
| `z` | `external int z` | Holds the `z` property or configuration state. |
| `w` | `external int w` | Holds the `w` property or configuration state. |

#### `class Short4`

4D signed int16 vector (8 bytes).

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `x` | `external int x` | Holds the `x` property or configuration state. |
| `y` | `external int y` | Holds the `y` property or configuration state. |
| `z` | `external int z` | Holds the `z` property or configuration state. |
| `w` | `external int w` | Holds the `w` property or configuration state. |

#### `class Quatf`

Unit quaternion stored in {x, y, z, w} memory order (16 bytes).

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `x` | `external double x` | Holds the `x` property or configuration state. |
| `y` | `external double y` | Holds the `y` property or configuration state. |
| `z` | `external double z` | Holds the `z` property or configuration state. |
| `w` | `external double w` | Holds the `w` property or configuration state. |

#### `class Mat3f`

3x3 float column-major matrix (36 bytes).

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `toList` | `List<double> toList()` | Executes `toList` operation. |
| `setFromList` | `void setFromList(List<double> list)` | Updates the `FromList` parameter and applies changes to the system. |

#### `class Mat4f`

4x4 float column-major matrix (64 bytes).

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `toList` | `List<double> toList()` | Executes `toList` operation. |
| `setFromList` | `void setFromList(List<double> list)` | Updates the `FromList` parameter and applies changes to the system. |
| `asFloat32List` | `static Float32List asFloat32List(ffi.Pointer<Mat4f> ptr)` | Executes `asFloat32List` operation. |

#### `class Mat4d`

4x4 double precision column-major matrix (128 bytes).

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `toList` | `List<double> toList()` | Executes `toList` operation. |
| `setFromList` | `void setFromList(List<double> list)` | Updates the `FromList` parameter and applies changes to the system. |

### `lib/src/math/box.dart`

#### `class Box`

An axis-aligned 3D box represented by its [center] and [halfExtent].  Direct pure-Dart reimplementation of `filament::Box`.

**Constructors:**
- `Box.fromMinMax(Vector3 min, Vector3 max)`: Constructs a [Box] from minimum and maximum corner points.
- `Box.fromFloat32List(Float32List list)`: Deserializes a [Box] from a 6-float buffer.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `center` | `Vector3 center` | Center coordinates of the box. |
| `halfExtent` | `Vector3 halfExtent` | Half extent from the center along each of the 3 axes. |
| `isEmpty` | `bool get isEmpty` | Whether the box is empty (i.e. its extents are zero). |
| `min` | `Vector3 get min` | Computes the lowest coordinate corner of the box (`center - halfExtent`). |
| `max` | `Vector3 get max` | Computes the highest coordinate corner of the box (`center + halfExtent`). |
| `unionSelf` | `Box unionSelf(Box box)` | In-place computes the bounding box of the union of this box and [box]. |
| `translateTo` | `Box translateTo(Vector3 center)` | Translates the box to a given [center] position, preserving extents. |
| `getBoundingSphere` | `Vector4 getBoundingSphere()` | Computes the smallest bounding sphere of the box.  Returns a [Vector4] with (.xyz) as center and (.w) as radius. |
| `transform` | `static Box transform(Matrix3 m, Vector3 t, Box box)` | Transforms a [Box] by a linear 3x3 transform [m] and translation [t]. |
| `rigidTransform` | `static Box rigidTransform(Box box, Matrix4 m)` | Rigidly transforms a [box] by a 4x4 matrix [m]. |
| `toFloat32List` | `Float32List toFloat32List()` | Serializes center and halfExtent into a 6-float buffer for FFI marshalling. |
| `toString` | `String toString()` | Executes `toString` operation. |

#### `class Aabb`

An axis-aligned bounding box represented by its [min] and [max] coordinates.  Direct pure-Dart reimplementation of `filament::Aabb`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `min` | `Vector3 min` | Minimum coordinate corner. |
| `max` | `Vector3 max` | Maximum coordinate corner. |
| `center` | `Vector3 get center` | Computes the center of the box `(max + min) * 0.5`. |
| `extent` | `Vector3 get extent` | Computes the half-extent of the box `(max - min) * 0.5`. |
| `isEmpty` | `bool get isEmpty` | Whether the box is empty (i.e. its volume is null or negative). |
| `getCorners` | `List<Vector3> getCorners()` | Returns the 8 corner vertices of the AABB in Filament's exact order:  `[---, +--, -+-, ++-, --+, +-+, -++, +++]` |
| `contains` | `double contains(Vector3 p)` | Computes the maximum signed distance from [p] to the box.  Returns a negative value if [p] is strictly inside the box. |
| `transform` | `Aabb transform(Matrix3 m, Vector3 t)` | Transforms this [Aabb] by an affine transformation using Jim Arvo's method. |
| `transformMat4` | `Aabb transformMat4(Matrix4 m)` | Transforms this [Aabb] by a 4x4 matrix [m]. |
| `toString` | `String toString()` | Executes `toString` operation. |

### `lib/src/math/color.dart`

#### `enum ColorConversion`

Type of color conversion to use when converting to/from sRGB and linear spaces.

#### `class FilamentColor`

Color manipulation and colorimetry utilities.  Direct pure-Dart reimplementation of `filament::Color` and `ColorSpaceUtils.h`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `cct` | `static Vector3 cct(double kelvin)` | Converts a Correlated Color Temperature [kelvin] (1,000K to 15,000K) to a linear RGB color in sRGB space.  Output is normalized such that the maximum component equals 1.0. |
| `illuminantD` | `static Vector3 illuminantD(double kelvin)` | Converts a CIE standard illuminant series D temperature [kelvin] (4,000K to 25,000K) to a linear RGB color in sRGB space.  Output is normalized such that the maximum component equals 1.0. |
| `absorptionAtDistance` | `static Vector3 absorptionAtDistance(Vector3 transmittanceColor, double d...` | Computes Beer-Lambert absorption coefficients from [transmittanceColor] and [distance]. |

### `lib/src/math/exposure.dart`

#### `class Exposure`

Utilities to compute exposure value at ISO 100 (EV100), photometric exposure, luminance, and illuminance using a physically-based camera model.  Direct pure-Dart reimplementation of `filament::Exposure`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `ev100FromLuminance` | `static double ev100FromLuminance(double luminance)` | Computes the exposure value (EV at ISO 100) for the given average scene [luminance] (cd/m²).  Calibration constant K = 12.5. `EV100 = log2(luminance * 100 / 12.5)` |
| `ev100FromIlluminance` | `static double ev100FromIlluminance(double illuminance)` | Computes the exposure value (EV at ISO 100) for the given [illuminance] (lux).  Calibration constant C = 250. `EV100 = log2(illuminance * 100 / 250)` |
| `exposureFromEv100` | `static double exposureFromEv100(double ev100)` | Computes the photometric exposure for the given [ev100].  `exposure = 1 / (1.2 * 2^EV100)` |
| `luminanceFromEv100` | `static double luminanceFromEv100(double ev100)` | Converts [ev100] to luminance in cd/m².  `L = 2^(EV100 - 3)` |
| `illuminanceFromEv100` | `static double illuminanceFromEv100(double ev100)` | Converts [ev100] to illuminance in lux.  `E = 2.5 * 2^EV100` |

### `lib/src/math/frustum.dart`

#### `enum FrustumPlane`

Frustum plane indices in Filament's exact order: [left], [right], [bottom], [top], [far], [near].

#### `class Frustum`

A viewing frustum defined by six normalized planes.  Direct pure-Dart reimplementation of `filament::Frustum` and `filament::Culler`.  Filament convention: - Inside is the negative half-space (`dot(plane.xyz, p) + plane.w <= 0`). - Planes are extracted via the Gil Gribb & Klaus Hartmann algorithm.

**Constructors:**
- `Frustum(Matrix4 projViewMatrix)`: Creates a frustum from a composite projection * view matrix [projViewMatrix].

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `setProjection` | `void setProjection(Matrix4 projViewMatrix)` | Sets the frustum planes from the given [projViewMatrix]. |
| `getNormalizedPlane` | `Vector4 getNormalizedPlane(FrustumPlane plane)` | Returns the normalized plane equation for [plane]. |
| `getNormalizedPlanes` | `List<Vector4> getNormalizedPlanes() => List.unmodifiable(_planes)` | Returns all six normalized frustum planes in `left, right, bottom, top, far, near` order. |
| `intersects` | `bool intersects(Box box)` | Conservative intersection test of an axis-aligned [Box] against the frustum.  Uses Filament's branch-light p-vertex algorithm from `filament::Culler`. Never returns false negatives for visible objects. |
| `intersectsSphere` | `bool intersectsSphere(Vector4 sphere)` | Conservative intersection test of a bounding [sphere] (.xyz center, .w radius) against the frustum. |
| `contains` | `bool contains(Vector3 point)` | Tests whether [point] is inside or on all 6 frustum planes. |
| `containsDistance` | `double containsDistance(Vector3 point)` | Returns the maximum signed distance of [point] to the frustum (negative if inside). |

### `lib/src/math/norm.dart`

**Top-level Functions:**

- **`int packSnorm16(double v)`**: Packs a signed float in range [-1.0, 1.0] into a 16-bit signed integer [-32767, 32767].  Symmetric packaging matching `filament/libs/math/include/math/norm.h`.
- **`Int16List packSnorm16x4(Vector4 v)`**: Packs a 4D vector into an [Int16List] of length 4.
- **`double unpackSnorm16(int v)`**: Unpacks a 16-bit signed integer [-32767, 32767] into a signed float [-1.0, 1.0].
- **`int packUnorm8(double v)`**: Packs an unsigned float in range [0.0, 1.0] into an 8-bit unsigned integer [0, 255].
- **`double unpackUnorm8(int v)`**: Unpacks an 8-bit unsigned integer [0, 255] into an unsigned float [0.0, 1.0].
- **`int packUnorm16(double v)`**: Packs an unsigned float in range [0.0, 1.0] into a 16-bit unsigned integer [0, 65535].
- **`double unpackUnorm16(int v)`**: Unpacks a 16-bit unsigned integer [0, 65535] into an unsigned float [0.0, 1.0].
- **`int packSnorm8(double v)`**: Packs a signed float in range [-1.0, 1.0] into an 8-bit signed integer [-127, 127].
- **`double unpackSnorm8(int v)`**: Unpacks an 8-bit signed integer [-127, 127] into a signed float [-1.0, 1.0].

### `lib/src/math/transform_util.dart`

**Top-level Functions:**

- **`Matrix4 composeMatrix(Vector3 translation, Quaternion rotation, Vector3 scale)`**: Composes a 4x4 transformation matrix from translation, rotation, and scale.  Direct line-for-line port of `filament::gltfio::composeMatrix` from `libs/gltfio/include/gltfio/math.h`.
- **`Vector4 cubicSpline(Vector4 vert0, Vector4 tang0, Vector4 vert1, Vector4 tang1, double t)`**: Evaluates cubic spline interpolation for glTF animation channels.  Port of `filament::gltfio::cubicSpline` from `libs/gltfio/include/gltfio/math.h`.
- **`Vector3 cubicSpline3(Vector3 vert0, Vector3 tang0, Vector3 vert1, Vector3 tang1, double t)`**: Evaluates cubic spline interpolation for 3D vectors.

### `lib/src/math/viewport.dart`

#### `class Viewport`

An immutable 2D viewport definition using Filament / OpenGL's **bottom-left origin** coordinate system.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `left` | `int left` | The X-coordinate of the bottom-left corner (in physical pixels). |
| `bottom` | `int bottom` | The Y-coordinate of the bottom-left corner (in physical pixels). |
| `width` | `int width` | The width of the viewport (in physical pixels). |
| `height` | `int height` | The height of the viewport (in physical pixels). |
| `hashCode` | `int get hashCode` | Checks current state or capability and returns a boolean value. |
| `toString` | `String toString()` | Executes `toString` operation. |

---

[Previous: glTF loading and animation](gltfio.md) | [Up: flutter_filament](index.md) | [Next: Editor primitives, tools and testing](editor-tools-and-testing.md)
