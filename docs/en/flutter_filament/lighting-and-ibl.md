[Türkçe](../../tr/flutter_filament/lighting-and-ibl.md)

# Lighting and image-based lighting

Direct lights and their shadow options, indirect (image-based) light and spherical harmonics, skyboxes, and the IBL toolchain: cubemap utilities, spherical-harmonics projection, cubemap baking and the GPU prefilter for specular and irradiance maps. File paths are relative to the `flutter_filament/` package directory.

**On this page:**

- [Native C bridge](#native-c-bridge)
  - [`src/ibl_bake_c.h`](#srcibl_bake_ch)
  - [`src/ibl_cubemap_c.h`](#srcibl_cubemap_ch)
  - [`src/ibl_sh_c.h`](#srcibl_sh_ch)
  - [`src/iblprefilter_c.h`](#srciblprefilter_ch)
  - [`src/lighting_c.h`](#srclighting_ch)
- [Dart API](#dart-api)
  - [`lib/src/ibl_bake.dart`](#libsrcibl_bakedart)
  - [`lib/src/ibl_cubemap.dart`](#libsrcibl_cubemapdart)
  - [`lib/src/ibl_sh.dart`](#libsrcibl_shdart)
  - [`lib/src/iblprefilter.dart`](#libsrciblprefilterdart)
  - [`lib/src/indirect_light.dart`](#libsrcindirect_lightdart)
  - [`lib/src/light.dart`](#libsrclightdart)
  - [`lib/src/skybox.dart`](#libsrcskyboxdart)

## Native C bridge

The C functions below are declared in the package's `src/` headers and called from Dart through FFI.

### `src/ibl_bake_c.h`

| C Function | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `filament_cubemap_ibl_roughness_filter` | `FFI_PLUGIN_EXPORT void filament_cubemap_ibl_roughness_filter( FilIb...` | Executes native Filament `filament_cubemap_ibl_roughness_filter` C binding. |
| `filament_cubemap_ibl_diffuse_irradiance` | `FFI_PLUGIN_EXPORT void filament_cubemap_ibl_diffuse_irradiance( Fil...` | Executes native Filament `filament_cubemap_ibl_diffuse_irradiance` C binding. |
| `filament_cubemap_ibl_dfg` | `FFI_PLUGIN_EXPORT void filament_cubemap_ibl_dfg( FilIblImage* dst, ...` | Executes native Filament `filament_cubemap_ibl_dfg` C binding. |

### `src/ibl_cubemap_c.h`

| C Function | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `filament_ibl_image_create` | `FFI_PLUGIN_EXPORT FilIblImage* filament_ibl_image_create(size_t w, ...` | Allocates and initializes the native Filament `filament_ibl_image_create` resource on the engine/GPU. |
| `filament_ibl_image_destroy` | `FFI_PLUGIN_EXPORT void filament_ibl_image_destroy(FilIblImage* img);` | Destroys the native Filament `filament_ibl_image_destroy` resource and releases GPU/host memory. |
| `filament_ibl_image_get_width` | `FFI_PLUGIN_EXPORT size_t filament_ibl_image_get_width(const FilIblI...` | Queries the `filament_ibl_image_get_width` state, property, or counter from the native C layer. |
| `filament_ibl_image_get_height` | `FFI_PLUGIN_EXPORT size_t filament_ibl_image_get_height(const FilIbl...` | Queries the `filament_ibl_image_get_height` state, property, or counter from the native C layer. |
| `filament_ibl_image_get_data` | `FFI_PLUGIN_EXPORT float* filament_ibl_image_get_data(FilIblImage* i...` | Queries the `filament_ibl_image_get_data` state, property, or counter from the native C layer. |
| `filament_ibl_image_get_bytes_per_row` | `FFI_PLUGIN_EXPORT size_t filament_ibl_image_get_bytes_per_row(const...` | Queries the `filament_ibl_image_get_bytes_per_row` state, property, or counter from the native C layer. |
| `filament_ibl_image_from_linear_image` | `FFI_PLUGIN_EXPORT FilIblImage* filament_ibl_image_from_linear_image...` | Executes native Filament `filament_ibl_image_from_linear_image` C binding. |
| `filament_ibl_image_to_linear_image` | `FFI_PLUGIN_EXPORT FilLinearImage* filament_ibl_image_to_linear_imag...` | Executes native Filament `filament_ibl_image_to_linear_image` C binding. |
| `filament_cubemap_create` | `FFI_PLUGIN_EXPORT FilIblCubemap* filament_cubemap_create(size_t dim);` | Allocates and initializes the native Filament `filament_cubemap_create` resource on the engine/GPU. |
| `filament_cubemap_destroy` | `FFI_PLUGIN_EXPORT void filament_cubemap_destroy(FilIblCubemap* cm);` | Destroys the native Filament `filament_cubemap_destroy` resource and releases GPU/host memory. |
| `filament_cubemap_get_dimensions` | `FFI_PLUGIN_EXPORT size_t filament_cubemap_get_dimensions(const FilI...` | Queries the `filament_cubemap_get_dimensions` state, property, or counter from the native C layer. |
| `filament_cubemap_get_face_image` | `FFI_PLUGIN_EXPORT FilIblImage* filament_cubemap_get_face_image(FilI...` | Queries the `filament_cubemap_get_face_image` state, property, or counter from the native C layer. |
| `filament_cubemap_utils_equirect_to_cubemap` | `FFI_PLUGIN_EXPORT void filament_cubemap_utils_equirect_to_cubemap(F...` | Executes native Filament `filament_cubemap_utils_equirect_to_cubemap` C binding. |
| `filament_cubemap_utils_cubemap_to_equirect` | `FFI_PLUGIN_EXPORT void filament_cubemap_utils_cubemap_to_equirect(F...` | Executes native Filament `filament_cubemap_utils_cubemap_to_equirect` C binding. |
| `filament_cubemap_utils_set_all_faces_from_cross` | `FFI_PLUGIN_EXPORT void filament_cubemap_utils_set_all_faces_from_cr...` | Updates the `filament_cubemap_utils_set_all_faces_from_cross` parameter or state in the native C layer. |
| `filament_cubemap_utils_cross_to_cubemap` | `FFI_PLUGIN_EXPORT FilIblCubemap* filament_cubemap_utils_cross_to_cu...` | Executes native Filament `filament_cubemap_utils_cross_to_cubemap` C binding. |
| `filament_cubemap_utils_cubemap_to_octahedron` | `FFI_PLUGIN_EXPORT void filament_cubemap_utils_cubemap_to_octahedron...` | Executes native Filament `filament_cubemap_utils_cubemap_to_octahedron` C binding. |
| `filament_cubemap_utils_mirror_cubemap` | `FFI_PLUGIN_EXPORT void filament_cubemap_utils_mirror_cubemap(FilIbl...` | Executes native Filament `filament_cubemap_utils_mirror_cubemap` C binding. |
| `filament_cubemap_utils_downsample_boxfilter` | `FFI_PLUGIN_EXPORT void filament_cubemap_utils_downsample_boxfilter(...` | Executes native Filament `filament_cubemap_utils_downsample_boxfilter` C binding. |
| `filament_cubemap_utils_make_seamless` | `FFI_PLUGIN_EXPORT void filament_cubemap_utils_make_seamless(FilIblC...` | Executes native Filament `filament_cubemap_utils_make_seamless` C binding. |

### `src/ibl_sh_c.h`

| C Function | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `filament_cubemap_sh_compute` | `FFI_PLUGIN_EXPORT bool filament_cubemap_sh_compute( const FilIblCub...` | Executes native Filament `filament_cubemap_sh_compute` C binding. |
| `filament_cubemap_sh_window` | `FFI_PLUGIN_EXPORT void filament_cubemap_sh_window( float* sh, uint8...` | Executes native Filament `filament_cubemap_sh_window` C binding. |
| `filament_cubemap_sh_preprocess_for_shader` | `FFI_PLUGIN_EXPORT void filament_cubemap_sh_preprocess_for_shader( f...` | Executes native Filament `filament_cubemap_sh_preprocess_for_shader` C binding. |
| `filament_cubemap_sh_render` | `FFI_PLUGIN_EXPORT void filament_cubemap_sh_render( FilIblCubemap* o...` | Dispatches drawing commands for the view and scene to the GPU. |

### `src/iblprefilter_c.h`

| C Function | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `filament_iblprefilter_context_create` | `FFI_PLUGIN_EXPORT FilIblPrefilterContext* filament_iblprefilter_con...` | Allocates and initializes the native Filament `filament_iblprefilter_context_create` resource on the engine/GPU. |
| `filament_iblprefilter_context_destroy` | `FFI_PLUGIN_EXPORT void filament_iblprefilter_context_destroy(FilIbl...` | Destroys the native Filament `filament_iblprefilter_context_destroy` resource and releases GPU/host memory. |
| `filament_equirect_to_cubemap_create` | `FFI_PLUGIN_EXPORT FilEquirectToCubemap* filament_equirect_to_cubema...` | Allocates and initializes the native Filament `filament_equirect_to_cubemap_create` resource on the engine/GPU. |
| `filament_equirect_to_cubemap_destroy` | `FFI_PLUGIN_EXPORT void filament_equirect_to_cubemap_destroy(FilEqui...` | Destroys the native Filament `filament_equirect_to_cubemap_destroy` resource and releases GPU/host memory. |
| `filament_equirect_to_cubemap_run` | `FFI_PLUGIN_EXPORT void* filament_equirect_to_cubemap_run(FilEquirec...` | Executes native Filament `filament_equirect_to_cubemap_run` C binding. |
| `filament_specular_filter_create` | `FFI_PLUGIN_EXPORT FilSpecularFilter* filament_specular_filter_creat...` | Allocates and initializes the native Filament `filament_specular_filter_create` resource on the engine/GPU. |
| `filament_specular_filter_create_config` | `FFI_PLUGIN_EXPORT FilSpecularFilter* filament_specular_filter_creat...` | Allocates and initializes the native Filament `filament_specular_filter_create_config` resource on the engine/GPU. |
| `filament_specular_filter_destroy` | `FFI_PLUGIN_EXPORT void filament_specular_filter_destroy(FilSpecular...` | Destroys the native Filament `filament_specular_filter_destroy` resource and releases GPU/host memory. |
| `filament_specular_filter_run` | `FFI_PLUGIN_EXPORT void* filament_specular_filter_run(FilSpecularFil...` | Executes native Filament `filament_specular_filter_run` C binding. |
| `filament_irradiance_filter_create` | `FFI_PLUGIN_EXPORT FilIrradianceFilter* filament_irradiance_filter_c...` | Allocates and initializes the native Filament `filament_irradiance_filter_create` resource on the engine/GPU. |
| `filament_irradiance_filter_create_config` | `FFI_PLUGIN_EXPORT FilIrradianceFilter* filament_irradiance_filter_c...` | Allocates and initializes the native Filament `filament_irradiance_filter_create_config` resource on the engine/GPU. |
| `filament_irradiance_filter_destroy` | `FFI_PLUGIN_EXPORT void filament_irradiance_filter_destroy(FilIrradi...` | Destroys the native Filament `filament_irradiance_filter_destroy` resource and releases GPU/host memory. |
| `filament_irradiance_filter_run` | `FFI_PLUGIN_EXPORT void* filament_irradiance_filter_run(FilIrradianc...` | Executes native Filament `filament_irradiance_filter_run` C binding. |

### `src/lighting_c.h`

| C Function | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `filament_light_create` | `FFI_PLUGIN_EXPORT void filament_light_create(void* engine, uint32_t...` | Allocates and initializes the native Filament `filament_light_create` resource on the engine/GPU. |
| `filament_light_destroy` | `FFI_PLUGIN_EXPORT void filament_light_destroy(void* engine, uint32_...` | Destroys the native Filament `filament_light_destroy` resource and releases GPU/host memory. |
| `filament_light_builder_create` | `FFI_PLUGIN_EXPORT void* filament_light_builder_create(int type);` | Allocates and initializes the native Filament `filament_light_builder_create` resource on the engine/GPU. |
| `filament_light_builder_position` | `FFI_PLUGIN_EXPORT void filament_light_builder_position(void* builde...` | Executes native Filament `filament_light_builder_position` C binding. |
| `filament_light_builder_direction` | `FFI_PLUGIN_EXPORT void filament_light_builder_direction(void* build...` | Executes native Filament `filament_light_builder_direction` C binding. |
| `filament_light_builder_color` | `FFI_PLUGIN_EXPORT void filament_light_builder_color(void* builder, ...` | Executes native Filament `filament_light_builder_color` C binding. |
| `filament_light_builder_intensity` | `FFI_PLUGIN_EXPORT void filament_light_builder_intensity(void* build...` | Executes native Filament `filament_light_builder_intensity` C binding. |
| `filament_light_builder_intensity_candela` | `FFI_PLUGIN_EXPORT void filament_light_builder_intensity_candela(voi...` | Executes native Filament `filament_light_builder_intensity_candela` C binding. |
| `filament_light_builder_intensity_watts` | `FFI_PLUGIN_EXPORT void filament_light_builder_intensity_watts(void*...` | Executes native Filament `filament_light_builder_intensity_watts` C binding. |
| `filament_light_builder_falloff` | `FFI_PLUGIN_EXPORT void filament_light_builder_falloff(void* builder...` | Executes native Filament `filament_light_builder_falloff` C binding. |
| `filament_light_builder_spot_light_cone` | `FFI_PLUGIN_EXPORT void filament_light_builder_spot_light_cone(void*...` | Executes native Filament `filament_light_builder_spot_light_cone` C binding. |
| `filament_light_builder_sun_angular_radius` | `FFI_PLUGIN_EXPORT void filament_light_builder_sun_angular_radius(vo...` | Executes native Filament `filament_light_builder_sun_angular_radius` C binding. |
| `filament_light_builder_sun_halo_size` | `FFI_PLUGIN_EXPORT void filament_light_builder_sun_halo_size(void* b...` | Executes native Filament `filament_light_builder_sun_halo_size` C binding. |
| `filament_light_builder_sun_halo_falloff` | `FFI_PLUGIN_EXPORT void filament_light_builder_sun_halo_falloff(void...` | Executes native Filament `filament_light_builder_sun_halo_falloff` C binding. |
| `filament_light_builder_cast_shadows` | `FFI_PLUGIN_EXPORT void filament_light_builder_cast_shadows(void* bu...` | Executes native Filament `filament_light_builder_cast_shadows` C binding. |
| `filament_light_builder_cast_light` | `FFI_PLUGIN_EXPORT void filament_light_builder_cast_light(void* buil...` | Executes native Filament `filament_light_builder_cast_light` C binding. |
| `filament_light_builder_light_channel` | `FFI_PLUGIN_EXPORT void filament_light_builder_light_channel(void* b...` | Executes native Filament `filament_light_builder_light_channel` C binding. |
| `filament_light_builder_build` | `FFI_PLUGIN_EXPORT int32_t filament_light_builder_build(void* builde...` | Executes native Filament `filament_light_builder_build` C binding. |
| `filament_light_builder_destroy` | `FFI_PLUGIN_EXPORT void filament_light_builder_destroy(void* builder);` | Destroys the native Filament `filament_light_builder_destroy` resource and releases GPU/host memory. |
| `filament_light_set_color` | `FFI_PLUGIN_EXPORT void filament_light_set_color(void* engine, uint3...` | Updates the `filament_light_set_color` parameter or state in the native C layer. |
| `filament_light_get_color` | `FFI_PLUGIN_EXPORT void filament_light_get_color(void* engine, uint3...` | Queries the `filament_light_get_color` state, property, or counter from the native C layer. |
| `filament_light_set_intensity` | `FFI_PLUGIN_EXPORT void filament_light_set_intensity(void* engine, u...` | Updates the `filament_light_set_intensity` parameter or state in the native C layer. |
| `filament_light_set_intensity_candela` | `FFI_PLUGIN_EXPORT void filament_light_set_intensity_candela(void* e...` | Updates the `filament_light_set_intensity_candela` parameter or state in the native C layer. |
| `filament_light_set_intensity_watts` | `FFI_PLUGIN_EXPORT void filament_light_set_intensity_watts(void* eng...` | Updates the `filament_light_set_intensity_watts` parameter or state in the native C layer. |
| `filament_light_get_intensity` | `FFI_PLUGIN_EXPORT float filament_light_get_intensity(void* engine, ...` | Queries the `filament_light_get_intensity` state, property, or counter from the native C layer. |
| `filament_light_set_direction` | `FFI_PLUGIN_EXPORT void filament_light_set_direction(void* engine, u...` | Updates the `filament_light_set_direction` parameter or state in the native C layer. |
| `filament_light_get_direction` | `FFI_PLUGIN_EXPORT void filament_light_get_direction(void* engine, u...` | Queries the `filament_light_get_direction` state, property, or counter from the native C layer. |
| `filament_light_set_position` | `FFI_PLUGIN_EXPORT void filament_light_set_position(void* engine, ui...` | Updates the `filament_light_set_position` parameter or state in the native C layer. |
| `filament_light_get_position` | `FFI_PLUGIN_EXPORT void filament_light_get_position(void* engine, ui...` | Queries the `filament_light_get_position` state, property, or counter from the native C layer. |
| `filament_light_set_falloff` | `FFI_PLUGIN_EXPORT void filament_light_set_falloff(void* engine, uin...` | Updates the `filament_light_set_falloff` parameter or state in the native C layer. |
| `filament_light_get_falloff` | `FFI_PLUGIN_EXPORT float filament_light_get_falloff(void* engine, ui...` | Queries the `filament_light_get_falloff` state, property, or counter from the native C layer. |
| `filament_light_set_spot_light_cone` | `FFI_PLUGIN_EXPORT void filament_light_set_spot_light_cone(void* eng...` | Updates the `filament_light_set_spot_light_cone` parameter or state in the native C layer. |
| `filament_light_get_spot_light_inner_cone` | `FFI_PLUGIN_EXPORT float filament_light_get_spot_light_inner_cone(vo...` | Queries the `filament_light_get_spot_light_inner_cone` state, property, or counter from the native C layer. |
| `filament_light_get_spot_light_outer_cone` | `FFI_PLUGIN_EXPORT float filament_light_get_spot_light_outer_cone(vo...` | Queries the `filament_light_get_spot_light_outer_cone` state, property, or counter from the native C layer. |
| `filament_light_set_shadow_caster` | `FFI_PLUGIN_EXPORT void filament_light_set_shadow_caster(void* engin...` | Updates the `filament_light_set_shadow_caster` parameter or state in the native C layer. |
| `filament_light_is_shadow_caster` | `FFI_PLUGIN_EXPORT bool filament_light_is_shadow_caster(void* engine...` | Validates or queries the `filament_light_is_shadow_caster` state/capability. |
| `filament_light_set_light_channel` | `FFI_PLUGIN_EXPORT void filament_light_set_light_channel(void* engin...` | Updates the `filament_light_set_light_channel` parameter or state in the native C layer. |
| `filament_light_get_light_channel` | `FFI_PLUGIN_EXPORT bool filament_light_get_light_channel(void* engin...` | Queries the `filament_light_get_light_channel` state, property, or counter from the native C layer. |
| `filament_light_has_component` | `FFI_PLUGIN_EXPORT bool filament_light_has_component(void* engine, u...` | Validates or queries the `filament_light_has_component` state/capability. |
| `filament_light_get_instance` | `FFI_PLUGIN_EXPORT uint32_t filament_light_get_instance(void* engine...` | Queries the `filament_light_get_instance` state, property, or counter from the native C layer. |
| *... and 33 additional native C functions* | - | Library FFI bindings. |

## Dart API

### `lib/src/ibl_bake.dart`

#### `class CubemapIBL`

Offline IBL baking operations: roughness filtering, diffuse irradiance, and DFG LUT generation.

### `lib/src/ibl_cubemap.dart`

#### `enum IblCubemapFace`

The 6 faces of a cubemap in standard Filament/OpenGL order.

**Constructors:**
- `IblCubemapFace(this._cEnum)`: Initializes `IblCubemapFace(this._cEnum)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `nz` | `nz(c.FilCubemapFace.FIL_CUBEMAP_FACE_NZ)` | Executes `nz` operation. |
| `value` | `int get value` | Getter accessor returning the current value of `value`. |

#### `class IblImage`

A 3-channel (RGB float) CPU image used in the IBL pipeline.

**Constructors:**
- `IblImage(this.width, this.height)`: Initializes `IblImage(this.width, this.height)`.
- `IblImage._fromHandle(ffi.Pointer<c.FilIblImage> handle)`: Initializes `IblImage._fromHandle(ffi.Pointer<c.FilIblImage> handle)`.
- `IblImage.fromLinearImage(LinearImage img)`: Initializes `IblImage.fromLinearImage(LinearImage img)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `width` | `int width` | Holds the `width` property or configuration state. |
| `height` | `int height` | Holds the `height` property or configuration state. |
| `bytesPerRow` | `int get bytesPerRow` | Row stride in bytes as stored natively. |
| `isContiguous` | `bool get isContiguous` | True when rows are packed (`bytesPerRow == width * 3 * 4`) and [data] is a live view; false for cubemap face sub-images where [data] is a copy. |
| `fill` | `void fill(double r, double g, double b)` | Fills every pixel with the given RGB value (stride-aware). |
| `writeData` | `void writeData(Float32List tight)` | Writes tightly packed RGB floats (`width * height * 3`) into the image, honouring the native row stride. |
| `getPixel` | `List<double> getPixel(int x, int y)` | Reads one RGB pixel honouring the native stride. |
| `setPixel` | `void setPixel(int x, int y, double r, double g, double b)` | Writes one RGB pixel honouring the native stride (works for face sub-images too); keeps [data] in sync for strided images. |
| `fromNativeHandle` | `static IblImage? fromNativeHandle(ffi.Pointer<c.FilIblImage> handle)` | Executes `fromNativeHandle` operation. |
| `toLinearImage` | `LinearImage toLinearImage()` | Executes `toLinearImage` operation. |
| `data` | `Float32List get data` | RGB float pixels, row-major, tightly packed. For contiguous images this is a live view of native memory (writes take effect immediately); for strided sub-images (see [isContiguous]) it is a snapshot — use [setPixel] to write. |
| `destroy` | `void destroy()` | Releases and safely disposes the specified `` resource. |

#### `class IblCubemap`

A CPU cubemap consisting of 6 square [IblImage] faces with dimensions [dimensions] x [dimensions].

**Constructors:**
- `IblCubemap(this.dimensions)`: Initializes `IblCubemap(this.dimensions)`.
- `IblCubemap._fromHandle(ffi.Pointer<c.FilIblCubemap> handle)`: Initializes `IblCubemap._fromHandle(ffi.Pointer<c.FilIblCubemap> handle)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `dimensions` | `int dimensions` | Holds the `dimensions` property or configuration state. |
| `fromNativeHandle` | `static IblCubemap? fromNativeHandle(ffi.Pointer<c.FilIblCubemap> handle)` | Executes `fromNativeHandle` operation. |
| `faceImage` | `IblImage faceImage(IblCubemapFace face)` | Executes `faceImage` operation. |
| `destroy` | `void destroy()` | Releases and safely disposes the specified `` resource. |

#### `class CubemapUtils`

Utility conversions for CPU cubemaps and equirectangular environments.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `equirectangularToCubemap` | `static void equirectangularToCubemap(IblCubemap dst, IblImage src)` | Executes `equirectangularToCubemap` operation. |
| `cubemapToEquirectangular` | `static void cubemapToEquirectangular(IblImage dst, IblCubemap src)` | Executes `cubemapToEquirectangular` operation. |
| `setAllFacesFromCross` | `static void setAllFacesFromCross(IblCubemap cMap, IblImage cross)` | Updates the `AllFacesFromCross` parameter and applies changes to the system. |
| `crossToCubemap` | `static IblCubemap crossToCubemap(IblImage cross)` | Executes `crossToCubemap` operation. |
| `cubemapToOctahedron` | `static void cubemapToOctahedron(IblImage dst, IblCubemap src)` | Executes `cubemapToOctahedron` operation. |
| `mirrorCubemap` | `static void mirrorCubemap(IblCubemap dst, IblCubemap src)` | Executes `mirrorCubemap` operation. |
| `downsampleCubemapLevelBoxFilter` | `static void downsampleCubemapLevelBoxFilter(IblCubemap dst, IblCubemap src)` | Executes `downsampleCubemapLevelBoxFilter` operation. |
| `makeSeamless` | `static void makeSeamless(IblCubemap cMap)` | Executes `makeSeamless` operation. |

### `lib/src/ibl_sh.dart`

#### `class CubemapSH`

Spherical Harmonics decomposition and manipulation for IBL.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `preprocessSHForShader` | `static void preprocessSHForShader(Float32List sh)` | Pre-scales 3-band SH coefficients into the format expected by `IndirectLight::irradiance`. |
| `getShIndex` | `static int getShIndex(int m, int l)` | Pure Dart spherical harmonics index calculation: $l(l+1) + m$. |

### `lib/src/iblprefilter.dart`

#### `enum SpecularFilterKernel`

Filter kernel distribution used by specular and irradiance prefiltering.

**Constructors:**
- `SpecularFilterKernel(this.value)`: Initializes `SpecularFilterKernel(this.value)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `dGgx` | `dGgx(0)` | Executes `dGgx` operation. |
| `value` | `int value` | Holds the `value` property or configuration state. |

#### `class SpecularFilterConfig`

Configuration settings for [SpecularFilter].

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `sampleCount` | `int sampleCount` | Number of integration samples per pixel (max 2048). |
| `levelCount` | `int levelCount` | Number of roughness mipmap levels to generate. |
| `kernel` | `SpecularFilterKernel kernel` | Distribution kernel to evaluate. |

#### `class SpecularFilterOptions`

Dynamic HDR filtering options for [SpecularFilter].

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `hdrLinear` | `double hdrLinear` | Holds the `hdrLinear` property or configuration state. |
| `hdrMax` | `double hdrMax` | Holds the `hdrMax` property or configuration state. |
| `lodOffset` | `double lodOffset` | Holds the `lodOffset` property or configuration state. |
| `generateMipmap` | `bool generateMipmap` | Holds the `generateMipmap` property or configuration state. |

#### `class IrradianceFilterConfig`

Configuration settings for [IrradianceFilter].

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `sampleCount` | `int sampleCount` | Number of integration samples per pixel (max 2048). |
| `kernel` | `SpecularFilterKernel kernel` | Distribution kernel to evaluate. |

#### `class IrradianceFilterOptions`

Dynamic HDR filtering options for [IrradianceFilter].

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `hdrLinear` | `double hdrLinear` | Holds the `hdrLinear` property or configuration state. |
| `hdrMax` | `double hdrMax` | Holds the `hdrMax` property or configuration state. |
| `lodOffset` | `double lodOffset` | Holds the `lodOffset` property or configuration state. |
| `generateMipmap` | `bool generateMipmap` | Holds the `generateMipmap` property or configuration state. |

#### `class IblPrefilterContext`

Manages shared GPU state and shaders used by IBL prefiltering operations.

**Constructors:**
- `IblPrefilterContext(this.engine)`: Initializes `IblPrefilterContext(this.engine)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `engine` | `FilamentEngine engine` | Holds the `engine` property or configuration state. |
| `destroy` | `void destroy()` | Destroys GPU state held by this context. |

#### `class EquirectangularToCubemap`

Converts a 2D equirectangular panorama texture into a 6-faced cubemap on the GPU.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `context` | `IblPrefilterContext context` | Holds the `context` property or configuration state. |
| `destroy` | `void destroy()` | Destroys this converter. |

#### `class SpecularFilter`

Prefilters an environment cubemap into specular reflection mipmaps according to roughness.

**Constructors:**
- `SpecularFilter(this.context, [SpecularFilterConfig? config])`: Initializes `SpecularFilter(this.context, [SpecularFilterConfig? config])`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `context` | `IblPrefilterContext context` | Holds the `context` property or configuration state. |
| `config` | `SpecularFilterConfig config` | Holds the `config` property or configuration state. |
| `destroy` | `void destroy()` | Destroys this filter instance. |

#### `class IrradianceFilter`

Generates a diffuse irradiance cubemap from an environment cubemap on the GPU.

**Constructors:**
- `IrradianceFilter(this.context, [IrradianceFilterConfig? config])`: Initializes `IrradianceFilter(this.context, [IrradianceFilterConfig? config])`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `context` | `IblPrefilterContext context` | Holds the `context` property or configuration state. |
| `config` | `IrradianceFilterConfig config` | Holds the `config` property or configuration state. |
| `destroy` | `void destroy()` | Destroys this filter instance. |

### `lib/src/indirect_light.dart`

#### `class SphericalHarmonics`

Represents spherical harmonics (SH) coefficients of 1, 2, or 3 bands.  SH coefficients are stored as 3 floats (RGB) per coefficient. The number of coefficients is `bands * bands` (1, 4, or 9 coefficients, or 3, 12, or 27 float values). The index formula is: `index(l, m) = l * (l + 1) + m`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `bands` | `int bands` | Number of spherical harmonics bands (1, 2, or 3). |
| `coefficients` | `Float32List coefficients` | Packed float3 coefficients (length must be `bands * bands * 3`). |
| `shIndex` | `static int shIndex(int l, int m)` | Calculates the index of the spherical harmonic coefficient for band [l] and degree [m].  Formula: `index(l, m) = l * (l + 1) + m`. |

#### `class FilamentIndirectLight`

Represents an Image-Based Lighting (IBL) IndirectLight source in Filament.  Simulates global illumination from a distant environment, supporting reflections cubemaps and spherical harmonics irradiance / radiance.

**Constructors:**
- `FilamentIndirectLight._(this._ptr, this._engine, [this._reflectionsTexture])`: Initializes `FilamentIndirectLight._(this._ptr, this._engine, [this._reflectionsTexture])`.
- `FilamentIndirectLight.internal(this._ptr, this._engine, [this._reflectionsTexture])`: Internal constructor.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `setIntensity` | `void setIntensity(double intensity)` | Sets the light intensity of this indirect light source in lux (lumen/m²). |
| `intensity` | `double get intensity` | Gets the light intensity of this indirect light source in lux (lumen/m²). |
| `rotation` | `rotation(Matrix3 m)` | Sets the 3x3 rigid-body rotation matrix applied to this IBL. |
| `rotation` | `Matrix3 get rotation` | Gets the 3x3 rigid-body rotation matrix applied to this IBL. |
| `reflectionsTexture` | `FilamentTexture? get reflectionsTexture` | Returns the associated reflections texture, or null if none. |
| `irradianceTexture` | `FilamentTexture? get irradianceTexture` | Returns the associated irradiance texture, or null if none. |
| `getDirectionEstimate` | `Vector3 getDirectionEstimate()` | Estimates the direction of the dominant light from this IBL's spherical harmonics.  Points *toward* the dominant light. |
| `directionEstimateFromSh` | `static Vector3 directionEstimateFromSh(SphericalHarmonics sh)` | Derives dominant light direction from a 3-band [SphericalHarmonics] set. |
| `dispose` | `void dispose()` | Destroys this IndirectLight. |
| `isDisposed` | `bool get isDisposed` | Checks current state or capability and returns a boolean value. |

### `lib/src/light.dart`

#### `enum LightType`

Types of lights supported by Filament.

**Constructors:**
- `LightType(this.value)`: Initializes `LightType(this.value)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `spot` | `spot(4)` | Executes `spot` operation. |
| `value` | `int value` | Holds the `value` property or configuration state. |

#### `class LightBuilder`

Fluent builder for constructing and configuring a Filament light component.

**Constructors:**
- `LightBuilder(LightType type)`: Creates a builder for the specified [type].

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `position` | `LightBuilder position(double x, double y, double z)` | Sets the initial position of the light in world space. |
| `direction` | `LightBuilder direction(double x, double y, double z)` | Sets the initial direction of the light in world space. |
| `color` | `LightBuilder color(double r, double g, double b)` | Sets the initial linear sRGB color of the light. |
| `intensity` | `LightBuilder intensity(double intensity)` | Sets the initial intensity in lux (directional/sun) or lumen (point/spot). |
| `intensityCandela` | `LightBuilder intensityCandela(double intensity)` | Sets the luminous intensity in candela (cd). |
| `intensityWatts` | `LightBuilder intensityWatts(double watts, double efficiency)` | Sets the intensity in watts using bulb energy consumption and efficiency. |
| `falloff` | `LightBuilder falloff(double radius)` | Sets the falloff distance (sphere of influence radius) for point/spot lights. |
| `spotLightCone` | `LightBuilder spotLightCone(double inner, double outer)` | Sets the inner and outer cone angles in radians for spot lights. |
| `sunAngularRadius` | `LightBuilder sunAngularRadius(double radiusDeg)` | Defines the angular radius of the sun in degrees (between 0.25° and 20.0°). |
| `sunHaloSize` | `LightBuilder sunHaloSize(double size)` | Defines the sun's halo size (multiplier of sun angular radius, >= 1.0). |
| `sunHaloFalloff` | `LightBuilder sunHaloFalloff(double falloff)` | Defines the sun's halo falloff exponent (>= 1.0). |
| `shadowOptions` | `LightBuilder shadowOptions(ShadowOptions options)` | Sets the shadow options for this light. |
| `castShadows` | `LightBuilder castShadows(bool enabled)` | Enables or disables shadow casting. |
| `castLight` | `LightBuilder castLight(bool enabled)` | Enables or disables illumination from this light (can cast shadows without emitting light). |
| `build` | `void build(FilamentEngine engine, int entity)` | Adds the Light component to [entity] in [engine].  Consumes and frees this builder. Throws [FilamentException] on failure. |
| `destroy` | `void destroy()` | Cancels and destroys this builder without attaching to an entity. |

#### `class FilamentLightManager`

Helper for managing and querying light components on entities.

**Constructors:**
- `FilamentLightManager(this.engine)`: Creates a light manager wrapper.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `engine` | `FilamentEngine engine` | Holds the `engine` property or configuration state. |
| `getInstance` | `LightInstance getInstance(int entity)` | Resolves an entity ID to its cached [LightInstance] handle. |
| `hasComponent` | `bool hasComponent(int entity)` | Whether [entity] has a light component. |
| `getType` | `LightType? getType(int entity)` | Gets the [LightType] of [entity]'s light component, or null if no component exists. |
| `componentCount` | `int get componentCount` | The total number of active light components managed by the engine. |
| `entities` | `List<int> get entities` | The list of entity IDs that currently have a light component. |
| `isDirectional` | `bool isDirectional(int entity)` | Whether [entity]'s light is directional (directional or sun). |
| `isPoint` | `bool isPoint(int entity)` | Whether [entity]'s light is an omnidirectional point light. |
| `isSpot` | `bool isSpot(int entity)` | Whether [entity]'s light is a spot light (spot or focusedSpot). |
| `destroy` | `void destroy(int entity)` | Destroys the light component on [entity]. |
| `setColor` | `void setColor(int entity, double r, double g, double b)` | Sets the linear sRGB color of [entity]'s light component. |
| `getColor` | `List<double> getColor(int entity)` | Gets the linear sRGB color of [entity]'s light component as [r, g, b]. |
| `setIntensity` | `void setIntensity(int entity, double intensity)` | Sets the light intensity in lux (directional/sun) or lumen (point/spot). |
| `setIntensityCandela` | `void setIntensityCandela(int entity, double intensity)` | Sets the luminous intensity in candela (cd). |
| `setIntensityWatts` | `void setIntensityWatts(int entity, double watts, double efficiency)` | Sets the light intensity in watts with luminous efficacy. |
| `getIntensity` | `double getIntensity(int entity)` | Gets the luminous intensity in candela (cd). |
| `setDirection` | `void setDirection(int entity, double x, double y, double z)` | Sets the direction in world space. |
| `getDirection` | `List<double> getDirection(int entity)` | Gets the direction in world space as [x, y, z]. |
| `setPosition` | `void setPosition(int entity, double x, double y, double z)` | Sets the position in world space. |
| `getPosition` | `List<double> getPosition(int entity)` | Gets the position in world space as [x, y, z]. |
| `setFalloff` | `void setFalloff(int entity, double radius)` | Sets the falloff distance (sphere of influence radius) for point/spot lights. |
| `getFalloff` | `double getFalloff(int entity)` | Gets the falloff distance of this light. |
| `setSpotLightCone` | `void setSpotLightCone(int entity, double inner, double outer)` | Sets the inner and outer cone angles in radians for spot lights. |
| `getSpotLightInnerCone` | `double getSpotLightInnerCone(int entity)` | Gets the inner cone angle in radians. |
| `getSpotLightOuterCone` | `double getSpotLightOuterCone(int entity)` | Gets the outer cone angle in radians. |
| `setShadowCaster` | `void setShadowCaster(int entity, bool enabled)` | Enables or disables shadow casting. |
| `isShadowCaster` | `bool isShadowCaster(int entity)` | Whether this light is configured to cast shadows. |
| `getLightChannel` | `bool getLightChannel(int entity, int channel)` | Whether a specific light channel (0 to 7) is enabled. |
| `setShadowOptions` | `void setShadowOptions(int entity, ShadowOptions options)` | Sets the shadow options for [entity]. |
| `getShadowOptions` | `ShadowOptions getShadowOptions(int entity)` | Gets the shadow options for [entity]. |

#### `class ShadowOptions`

Configuration options for shadow-map generation and cascaded shadow maps (CSM).

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `mapSize` | `int mapSize` | Holds the `mapSize` property or configuration state. |
| `shadowCascades` | `int shadowCascades` | Holds the `shadowCascades` property or configuration state. |
| `cascadeSplitPositions` | `List<double> cascadeSplitPositions` | Holds the `cascadeSplitPositions` property or configuration state. |
| `constantBias` | `double constantBias` | Holds the `constantBias` property or configuration state. |
| `normalBias` | `double normalBias` | Holds the `normalBias` property or configuration state. |
| `shadowFar` | `double shadowFar` | Holds the `shadowFar` property or configuration state. |
| `shadowNearHint` | `double shadowNearHint` | Holds the `shadowNearHint` property or configuration state. |
| `shadowFarHint` | `double shadowFarHint` | Holds the `shadowFarHint` property or configuration state. |
| `stable` | `bool stable` | Holds the `stable` property or configuration state. |
| `rayTraced` | `bool rayTraced` | Trace hard shadows against the scene's ray tracing acceleration structures instead of the cascaded shadow maps; directional lights only, falls back to the maps without ray query support (see [Ray tracing](ray-tracing.md)). Default false. |
| `lispsm` | `bool lispsm` | Holds the `lispsm` property or configuration state. |
| `polygonOffsetConstant` | `double polygonOffsetConstant` | Holds the `polygonOffsetConstant` property or configuration state. |
| `polygonOffsetSlope` | `double polygonOffsetSlope` | Holds the `polygonOffsetSlope` property or configuration state. |
| `screenSpaceContactShadows` | `bool screenSpaceContactShadows` | Holds the `screenSpaceContactShadows` property or configuration state. |
| `stepCount` | `int stepCount` | Holds the `stepCount` property or configuration state. |
| `maxShadowDistance` | `double maxShadowDistance` | Holds the `maxShadowDistance` property or configuration state. |
| `elvsm` | `bool elvsm` | Holds the `elvsm` property or configuration state. |
| `blurWidth` | `double blurWidth` | Holds the `blurWidth` property or configuration state. |
| `shadowBulbRadius` | `double shadowBulbRadius` | Holds the `shadowBulbRadius` property or configuration state. |
| `transform` | `List<double> transform` | Holds the `transform` property or configuration state. |
| `penumbraScale` | `double penumbraScale` | Holds the `penumbraScale` property or configuration state. |
| `penumbraRatioScale` | `double penumbraRatioScale` | Holds the `penumbraRatioScale` property or configuration state. |
| `maxPenumbraRatio` | `double maxPenumbraRatio` | Holds the `maxPenumbraRatio` property or configuration state. |

#### `class ShadowCascades`

Utility methods for computing cascaded shadow map (CSM) split schemes.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `computeUniformSplits` | `static List<double> computeUniformSplits(int cascades)` | Computes split positions for [cascades] using a uniform split scheme. |

#### `class LightEfficiency`

Standard luminous efficacy constants matching Filament's `EFFICIENCY_*` values.

### `lib/src/skybox.dart`

#### `class FilamentSkybox`

A Skybox fills all untouched background pixels in a scene.  Can be configured with an environment cubemap texture or a solid color, with optional sun disk rendering and rendering priority.

**Constructors:**
- `FilamentSkybox._(this._ptr, this._engine, [this._environmentTexture])`: Initializes `FilamentSkybox._(this._ptr, this._engine, [this._environmentTexture])`.
- `FilamentSkybox.internal(this._ptr, this._engine, [this._environmentTexture])`: Internal constructor.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `color` | `color(Vector4 col)` | Sets the solid color of this Skybox at runtime (fades/transitions). |
| `layerMask` | `int get layerMask` | Gets the layer mask visibility bits. |
| `intensity` | `double get intensity` | Gets the skybox intensity in lux / cd/m². |
| `texture` | `FilamentTexture? get texture` | Gets the associated environment texture, or null if this is a solid color skybox. |
| `dispose` | `void dispose()` | Destroys this Skybox. |
| `isDisposed` | `bool get isDisposed` | Checks current state or capability and returns a boolean value. |

---

[Previous: Camera and manipulator](camera-and-manipulator.md) | [Up: flutter_filament](index.md) | [Next: Materials](materials.md)
