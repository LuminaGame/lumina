[English](../../en/flutter_filament/math.md)

# Matematik tipleri

FFI sınırından geçen matematik değer tipleri (vektörler, quaternion'lar ve matrisler) ve matematik yardımcıları: box'lar ve AABB'ler, renkler, exposure, frustum'lar, normal paketleme, transform yardımcıları ve viewport'lar. Dosya yolları `flutter_filament/` paket dizinine görelidir.

**Bu sayfada:**

- [Native C köprüsü](#native-c-köprüsü)
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

## Native C köprüsü

Aşağıdaki C fonksiyonları paketin `src/` header'larında tanımlanır ve Dart'tan FFI ile çağrılır.

### `src/math_abi_c.h`

| C Fonksiyonu | İmzası | Açıklama ve Ne İşe Yaradığı |
| :--- | :--- | :--- |
| `filament_sizeof_float2` | `FFI_PLUGIN_EXPORT size_t filament_sizeof_float2(void);` | Filament yerel `filament_sizeof_float2` C fonksiyonunu çalıştırır. |
| `filament_sizeof_float3` | `FFI_PLUGIN_EXPORT size_t filament_sizeof_float3(void);` | Filament yerel `filament_sizeof_float3` C fonksiyonunu çalıştırır. |
| `filament_sizeof_float4` | `FFI_PLUGIN_EXPORT size_t filament_sizeof_float4(void);` | Filament yerel `filament_sizeof_float4` C fonksiyonunu çalıştırır. |
| `filament_sizeof_int2` | `FFI_PLUGIN_EXPORT size_t filament_sizeof_int2(void);` | Filament yerel `filament_sizeof_int2` C fonksiyonunu çalıştırır. |
| `filament_sizeof_int3` | `FFI_PLUGIN_EXPORT size_t filament_sizeof_int3(void);` | Filament yerel `filament_sizeof_int3` C fonksiyonunu çalıştırır. |
| `filament_sizeof_int4` | `FFI_PLUGIN_EXPORT size_t filament_sizeof_int4(void);` | Filament yerel `filament_sizeof_int4` C fonksiyonunu çalıştırır. |
| `filament_sizeof_uint2` | `FFI_PLUGIN_EXPORT size_t filament_sizeof_uint2(void);` | Filament yerel `filament_sizeof_uint2` C fonksiyonunu çalıştırır. |
| `filament_sizeof_uint3` | `FFI_PLUGIN_EXPORT size_t filament_sizeof_uint3(void);` | Filament yerel `filament_sizeof_uint3` C fonksiyonunu çalıştırır. |
| `filament_sizeof_uint4` | `FFI_PLUGIN_EXPORT size_t filament_sizeof_uint4(void);` | Filament yerel `filament_sizeof_uint4` C fonksiyonunu çalıştırır. |
| `filament_sizeof_bool2` | `FFI_PLUGIN_EXPORT size_t filament_sizeof_bool2(void);` | Filament yerel `filament_sizeof_bool2` C fonksiyonunu çalıştırır. |
| `filament_sizeof_bool3` | `FFI_PLUGIN_EXPORT size_t filament_sizeof_bool3(void);` | Filament yerel `filament_sizeof_bool3` C fonksiyonunu çalıştırır. |
| `filament_sizeof_bool4` | `FFI_PLUGIN_EXPORT size_t filament_sizeof_bool4(void);` | Filament yerel `filament_sizeof_bool4` C fonksiyonunu çalıştırır. |
| `filament_sizeof_short4` | `FFI_PLUGIN_EXPORT size_t filament_sizeof_short4(void);` | Filament yerel `filament_sizeof_short4` C fonksiyonunu çalıştırır. |
| `filament_sizeof_quatf` | `FFI_PLUGIN_EXPORT size_t filament_sizeof_quatf(void);` | Filament yerel `filament_sizeof_quatf` C fonksiyonunu çalıştırır. |
| `filament_sizeof_mat3f` | `FFI_PLUGIN_EXPORT size_t filament_sizeof_mat3f(void);` | Filament yerel `filament_sizeof_mat3f` C fonksiyonunu çalıştırır. |
| `filament_sizeof_mat4f` | `FFI_PLUGIN_EXPORT size_t filament_sizeof_mat4f(void);` | Filament yerel `filament_sizeof_mat4f` C fonksiyonunu çalıştırır. |
| `filament_sizeof_mat4` | `FFI_PLUGIN_EXPORT size_t filament_sizeof_mat4(void);` | Filament yerel `filament_sizeof_mat4` C fonksiyonunu çalıştırır. |
| `filament_test_quatf_read` | `FFI_PLUGIN_EXPORT void filament_test_quatf_read(const void* q, floa...` | Filament yerel `filament_test_quatf_read` C fonksiyonunu çalıştırır. |
| `filament_test_mat4f_col_major` | `FFI_PLUGIN_EXPORT void filament_test_mat4f_col_major(void* out);` | Filament yerel `filament_test_mat4f_col_major` C fonksiyonunu çalıştırır. |
| `filament_test_float3_array_sum` | `FFI_PLUGIN_EXPORT void filament_test_float3_array_sum(const void* a...` | Filament yerel `filament_test_float3_array_sum` C fonksiyonunu çalıştırır. |
| `filament_test_mat3f_read` | `FFI_PLUGIN_EXPORT void filament_test_mat3f_read(const void* m, floa...` | Filament yerel `filament_test_mat3f_read` C fonksiyonunu çalıştırır. |
| `filament_test_bool3_read` | `FFI_PLUGIN_EXPORT void filament_test_bool3_read(const void* b, uint...` | Filament yerel `filament_test_bool3_read` C fonksiyonunu çalıştırır. |

## Dart API

### `lib/src/math_types.dart`

#### `class Float2`

2D float vector (8 bytes).

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `x` | `external double x` | `x` alanını (field/property) ve ilişkili veriyi saklar. |
| `y` | `external double y` | `y` alanını (field/property) ve ilişkili veriyi saklar. |

#### `class Float3`

3D float vector (12 bytes, contiguous without padding).

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `x` | `external double x` | `x` alanını (field/property) ve ilişkili veriyi saklar. |
| `y` | `external double y` | `y` alanını (field/property) ve ilişkili veriyi saklar. |
| `z` | `external double z` | `z` alanını (field/property) ve ilişkili veriyi saklar. |

#### `class Float4`

4D float vector (16 bytes).

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `x` | `external double x` | `x` alanını (field/property) ve ilişkili veriyi saklar. |
| `y` | `external double y` | `y` alanını (field/property) ve ilişkili veriyi saklar. |
| `z` | `external double z` | `z` alanını (field/property) ve ilişkili veriyi saklar. |
| `w` | `external double w` | `w` alanını (field/property) ve ilişkili veriyi saklar. |

#### `class Int2`

2D int32 vector (8 bytes).

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `x` | `external int x` | `x` alanını (field/property) ve ilişkili veriyi saklar. |
| `y` | `external int y` | `y` alanını (field/property) ve ilişkili veriyi saklar. |

#### `class Int3`

3D int32 vector (12 bytes).

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `x` | `external int x` | `x` alanını (field/property) ve ilişkili veriyi saklar. |
| `y` | `external int y` | `y` alanını (field/property) ve ilişkili veriyi saklar. |
| `z` | `external int z` | `z` alanını (field/property) ve ilişkili veriyi saklar. |

#### `class Int4`

4D int32 vector (16 bytes).

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `x` | `external int x` | `x` alanını (field/property) ve ilişkili veriyi saklar. |
| `y` | `external int y` | `y` alanını (field/property) ve ilişkili veriyi saklar. |
| `z` | `external int z` | `z` alanını (field/property) ve ilişkili veriyi saklar. |
| `w` | `external int w` | `w` alanını (field/property) ve ilişkili veriyi saklar. |

#### `class Uint2`

2D uint32 vector (8 bytes).

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `x` | `external int x` | `x` alanını (field/property) ve ilişkili veriyi saklar. |
| `y` | `external int y` | `y` alanını (field/property) ve ilişkili veriyi saklar. |

#### `class Uint3`

3D uint32 vector (12 bytes).

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `x` | `external int x` | `x` alanını (field/property) ve ilişkili veriyi saklar. |
| `y` | `external int y` | `y` alanını (field/property) ve ilişkili veriyi saklar. |
| `z` | `external int z` | `z` alanını (field/property) ve ilişkili veriyi saklar. |

#### `class Uint4`

4D uint32 vector (16 bytes).

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `x` | `external int x` | `x` alanını (field/property) ve ilişkili veriyi saklar. |
| `y` | `external int y` | `y` alanını (field/property) ve ilişkili veriyi saklar. |
| `z` | `external int z` | `z` alanını (field/property) ve ilişkili veriyi saklar. |
| `w` | `external int w` | `w` alanını (field/property) ve ilişkili veriyi saklar. |

#### `class Bool2`

2D boolean vector (2 bytes).

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `x` | `external int x` | `x` alanını (field/property) ve ilişkili veriyi saklar. |
| `y` | `external int y` | `y` alanını (field/property) ve ilişkili veriyi saklar. |

#### `class Bool3`

3D boolean vector (3 bytes).

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `x` | `external int x` | `x` alanını (field/property) ve ilişkili veriyi saklar. |
| `y` | `external int y` | `y` alanını (field/property) ve ilişkili veriyi saklar. |
| `z` | `external int z` | `z` alanını (field/property) ve ilişkili veriyi saklar. |

#### `class Bool4`

4D boolean vector (4 bytes).

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `x` | `external int x` | `x` alanını (field/property) ve ilişkili veriyi saklar. |
| `y` | `external int y` | `y` alanını (field/property) ve ilişkili veriyi saklar. |
| `z` | `external int z` | `z` alanını (field/property) ve ilişkili veriyi saklar. |
| `w` | `external int w` | `w` alanını (field/property) ve ilişkili veriyi saklar. |

#### `class Short4`

4D signed int16 vector (8 bytes).

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `x` | `external int x` | `x` alanını (field/property) ve ilişkili veriyi saklar. |
| `y` | `external int y` | `y` alanını (field/property) ve ilişkili veriyi saklar. |
| `z` | `external int z` | `z` alanını (field/property) ve ilişkili veriyi saklar. |
| `w` | `external int w` | `w` alanını (field/property) ve ilişkili veriyi saklar. |

#### `class Quatf`

Unit quaternion stored in {x, y, z, w} memory order (16 bytes).

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `x` | `external double x` | `x` alanını (field/property) ve ilişkili veriyi saklar. |
| `y` | `external double y` | `y` alanını (field/property) ve ilişkili veriyi saklar. |
| `z` | `external double z` | `z` alanını (field/property) ve ilişkili veriyi saklar. |
| `w` | `external double w` | `w` alanını (field/property) ve ilişkili veriyi saklar. |

#### `class Mat3f`

3x3 float column-major matrix (36 bytes).

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `toList` | `List<double> toList()` | `toList` işlemini gerçekleştirir. |
| `setFromList` | `void setFromList(List<double> list)` | `FromList` parametresini günceller ve sisteme uygular. |

#### `class Mat4f`

4x4 float column-major matrix (64 bytes).

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `toList` | `List<double> toList()` | `toList` işlemini gerçekleştirir. |
| `setFromList` | `void setFromList(List<double> list)` | `FromList` parametresini günceller ve sisteme uygular. |
| `asFloat32List` | `static Float32List asFloat32List(ffi.Pointer<Mat4f> ptr)` | `asFloat32List` işlemini gerçekleştirir. |

#### `class Mat4d`

4x4 double precision column-major matrix (128 bytes).

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `toList` | `List<double> toList()` | `toList` işlemini gerçekleştirir. |
| `setFromList` | `void setFromList(List<double> list)` | `FromList` parametresini günceller ve sisteme uygular. |

### `lib/src/math/box.dart`

#### `class Box`

An axis-aligned 3D box represented by its [center] and [halfExtent].  Direct pure-Dart reimplementation of `filament::Box`.

**Yapıcı Metotlar (Constructors):**
- `Box.fromMinMax(Vector3 min, Vector3 max)`: Constructs a [Box] from minimum and maximum corner points.
- `Box.fromFloat32List(Float32List list)`: Deserializes a [Box] from a 6-float buffer.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
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
| `toString` | `String toString()` | `toString` işlemini gerçekleştirir. |

#### `class Aabb`

An axis-aligned bounding box represented by its [min] and [max] coordinates.  Direct pure-Dart reimplementation of `filament::Aabb`.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
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
| `toString` | `String toString()` | `toString` işlemini gerçekleştirir. |

### `lib/src/math/color.dart`

#### `enum ColorConversion`

Type of color conversion to use when converting to/from sRGB and linear spaces.

#### `class FilamentColor`

Color manipulation and colorimetry utilities.  Direct pure-Dart reimplementation of `filament::Color` and `ColorSpaceUtils.h`.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `cct` | `static Vector3 cct(double kelvin)` | Converts a Correlated Color Temperature [kelvin] (1,000K to 15,000K) to a linear RGB color in sRGB space.  Output is normalized such that the maximum component equals 1.0. |
| `illuminantD` | `static Vector3 illuminantD(double kelvin)` | Converts a CIE standard illuminant series D temperature [kelvin] (4,000K to 25,000K) to a linear RGB color in sRGB space.  Output is normalized such that the maximum component equals 1.0. |
| `absorptionAtDistance` | `static Vector3 absorptionAtDistance(Vector3 transmittanceColor, double d...` | Computes Beer-Lambert absorption coefficients from [transmittanceColor] and [distance]. |

### `lib/src/math/exposure.dart`

#### `class Exposure`

Utilities to compute exposure value at ISO 100 (EV100), photometric exposure, luminance, and illuminance using a physically-based camera model.  Direct pure-Dart reimplementation of `filament::Exposure`.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
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

**Yapıcı Metotlar (Constructors):**
- `Frustum(Matrix4 projViewMatrix)`: Creates a frustum from a composite projection * view matrix [projViewMatrix].

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `setProjection` | `void setProjection(Matrix4 projViewMatrix)` | Sets the frustum planes from the given [projViewMatrix]. |
| `getNormalizedPlane` | `Vector4 getNormalizedPlane(FrustumPlane plane)` | Returns the normalized plane equation for [plane]. |
| `getNormalizedPlanes` | `List<Vector4> getNormalizedPlanes() => List.unmodifiable(_planes)` | Returns all six normalized frustum planes in `left, right, bottom, top, far, near` order. |
| `intersects` | `bool intersects(Box box)` | Conservative intersection test of an axis-aligned [Box] against the frustum.  Uses Filament's branch-light p-vertex algorithm from `filament::Culler`. Never returns false negatives for visible objects. |
| `intersectsSphere` | `bool intersectsSphere(Vector4 sphere)` | Conservative intersection test of a bounding [sphere] (.xyz center, .w radius) against the frustum. |
| `contains` | `bool contains(Vector3 point)` | Tests whether [point] is inside or on all 6 frustum planes. |
| `containsDistance` | `double containsDistance(Vector3 point)` | Returns the maximum signed distance of [point] to the frustum (negative if inside). |

### `lib/src/math/norm.dart`

**Üst Düzey Fonksiyonlar (Top-level Functions):**

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

**Üst Düzey Fonksiyonlar (Top-level Functions):**

- **`Matrix4 composeMatrix(Vector3 translation, Quaternion rotation, Vector3 scale)`**: Composes a 4x4 transformation matrix from translation, rotation, and scale.  Direct line-for-line port of `filament::gltfio::composeMatrix` from `libs/gltfio/include/gltfio/math.h`.
- **`Vector4 cubicSpline(Vector4 vert0, Vector4 tang0, Vector4 vert1, Vector4 tang1, double t)`**: Evaluates cubic spline interpolation for glTF animation channels.  Port of `filament::gltfio::cubicSpline` from `libs/gltfio/include/gltfio/math.h`.
- **`Vector3 cubicSpline3(Vector3 vert0, Vector3 tang0, Vector3 vert1, Vector3 tang1, double t)`**: Evaluates cubic spline interpolation for 3D vectors.

### `lib/src/math/viewport.dart`

#### `class Viewport`

An immutable 2D viewport definition using Filament / OpenGL's **bottom-left origin** coordinate system.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `left` | `int left` | The X-coordinate of the bottom-left corner (in physical pixels). |
| `bottom` | `int bottom` | The Y-coordinate of the bottom-left corner (in physical pixels). |
| `width` | `int width` | The width of the viewport (in physical pixels). |
| `height` | `int height` | The height of the viewport (in physical pixels). |
| `hashCode` | `int get hashCode` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `toString` | `String toString()` | `toString` işlemini gerçekleştirir. |

---

[Önceki: glTF yükleme ve animasyon](gltfio.md) | [Üst: flutter_filament](index.md) | [Sonraki: Editör primitifleri, araçlar ve test](editor-tools-and-testing.md)
