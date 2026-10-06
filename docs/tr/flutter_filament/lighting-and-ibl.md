[English](../../en/flutter_filament/lighting-and-ibl.md)

# Işıklandırma ve image-based lighting

Doğrudan ışıklar ve gölge seçenekleri, indirect (image-based) light ve spherical harmonics, skybox'lar ve IBL araç zinciri: cubemap yardımcıları, spherical-harmonics projeksiyonu, cubemap bake ve specular ile irradiance haritaları için GPU prefilter. Dosya yolları `flutter_filament/` paket dizinine görelidir.

**Bu sayfada:**

- [Native C köprüsü](#native-c-köprüsü)
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

## Native C köprüsü

Aşağıdaki C fonksiyonları paketin `src/` header'larında tanımlanır ve Dart'tan FFI ile çağrılır.

### `src/ibl_bake_c.h`

| C Fonksiyonu | İmzası | Açıklama ve Ne İşe Yaradığı |
| :--- | :--- | :--- |
| `filament_cubemap_ibl_roughness_filter` | `FFI_PLUGIN_EXPORT void filament_cubemap_ibl_roughness_filter( FilIb...` | Filament yerel `filament_cubemap_ibl_roughness_filter` C fonksiyonunu çalıştırır. |
| `filament_cubemap_ibl_diffuse_irradiance` | `FFI_PLUGIN_EXPORT void filament_cubemap_ibl_diffuse_irradiance( Fil...` | Filament yerel `filament_cubemap_ibl_diffuse_irradiance` C fonksiyonunu çalıştırır. |
| `filament_cubemap_ibl_dfg` | `FFI_PLUGIN_EXPORT void filament_cubemap_ibl_dfg( FilIblImage* dst, ...` | Filament yerel `filament_cubemap_ibl_dfg` C fonksiyonunu çalıştırır. |

### `src/ibl_cubemap_c.h`

| C Fonksiyonu | İmzası | Açıklama ve Ne İşe Yaradığı |
| :--- | :--- | :--- |
| `filament_ibl_image_create` | `FFI_PLUGIN_EXPORT FilIblImage* filament_ibl_image_create(size_t w, ...` | İlgili Filament C API kaynağını GPU/motor üzerinde tahsis eder ve ilklendirir. |
| `filament_ibl_image_destroy` | `FFI_PLUGIN_EXPORT void filament_ibl_image_destroy(FilIblImage* img);` | İlgili Filament C API nesnesini yok eder ve GPU belleğini serbest bırakır. |
| `filament_ibl_image_get_width` | `FFI_PLUGIN_EXPORT size_t filament_ibl_image_get_width(const FilIblI...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_ibl_image_get_height` | `FFI_PLUGIN_EXPORT size_t filament_ibl_image_get_height(const FilIbl...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_ibl_image_get_data` | `FFI_PLUGIN_EXPORT float* filament_ibl_image_get_data(FilIblImage* i...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_ibl_image_get_bytes_per_row` | `FFI_PLUGIN_EXPORT size_t filament_ibl_image_get_bytes_per_row(const...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_ibl_image_from_linear_image` | `FFI_PLUGIN_EXPORT FilIblImage* filament_ibl_image_from_linear_image...` | Filament yerel `filament_ibl_image_from_linear_image` C fonksiyonunu çalıştırır. |
| `filament_ibl_image_to_linear_image` | `FFI_PLUGIN_EXPORT FilLinearImage* filament_ibl_image_to_linear_imag...` | Filament yerel `filament_ibl_image_to_linear_image` C fonksiyonunu çalıştırır. |
| `filament_cubemap_create` | `FFI_PLUGIN_EXPORT FilIblCubemap* filament_cubemap_create(size_t dim);` | İlgili Filament C API kaynağını GPU/motor üzerinde tahsis eder ve ilklendirir. |
| `filament_cubemap_destroy` | `FFI_PLUGIN_EXPORT void filament_cubemap_destroy(FilIblCubemap* cm);` | İlgili Filament C API nesnesini yok eder ve GPU belleğini serbest bırakır. |
| `filament_cubemap_get_dimensions` | `FFI_PLUGIN_EXPORT size_t filament_cubemap_get_dimensions(const FilI...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_cubemap_get_face_image` | `FFI_PLUGIN_EXPORT FilIblImage* filament_cubemap_get_face_image(FilI...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_cubemap_utils_equirect_to_cubemap` | `FFI_PLUGIN_EXPORT void filament_cubemap_utils_equirect_to_cubemap(F...` | Filament yerel `filament_cubemap_utils_equirect_to_cubemap` C fonksiyonunu çalıştırır. |
| `filament_cubemap_utils_cubemap_to_equirect` | `FFI_PLUGIN_EXPORT void filament_cubemap_utils_cubemap_to_equirect(F...` | Filament yerel `filament_cubemap_utils_cubemap_to_equirect` C fonksiyonunu çalıştırır. |
| `filament_cubemap_utils_set_all_faces_from_cross` | `FFI_PLUGIN_EXPORT void filament_cubemap_utils_set_all_faces_from_cr...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_cubemap_utils_cross_to_cubemap` | `FFI_PLUGIN_EXPORT FilIblCubemap* filament_cubemap_utils_cross_to_cu...` | Filament yerel `filament_cubemap_utils_cross_to_cubemap` C fonksiyonunu çalıştırır. |
| `filament_cubemap_utils_cubemap_to_octahedron` | `FFI_PLUGIN_EXPORT void filament_cubemap_utils_cubemap_to_octahedron...` | Filament yerel `filament_cubemap_utils_cubemap_to_octahedron` C fonksiyonunu çalıştırır. |
| `filament_cubemap_utils_mirror_cubemap` | `FFI_PLUGIN_EXPORT void filament_cubemap_utils_mirror_cubemap(FilIbl...` | Filament yerel `filament_cubemap_utils_mirror_cubemap` C fonksiyonunu çalıştırır. |
| `filament_cubemap_utils_downsample_boxfilter` | `FFI_PLUGIN_EXPORT void filament_cubemap_utils_downsample_boxfilter(...` | Filament yerel `filament_cubemap_utils_downsample_boxfilter` C fonksiyonunu çalıştırır. |
| `filament_cubemap_utils_make_seamless` | `FFI_PLUGIN_EXPORT void filament_cubemap_utils_make_seamless(FilIblC...` | Filament yerel `filament_cubemap_utils_make_seamless` C fonksiyonunu çalıştırır. |

### `src/ibl_sh_c.h`

| C Fonksiyonu | İmzası | Açıklama ve Ne İşe Yaradığı |
| :--- | :--- | :--- |
| `filament_cubemap_sh_compute` | `FFI_PLUGIN_EXPORT bool filament_cubemap_sh_compute( const FilIblCub...` | Filament yerel `filament_cubemap_sh_compute` C fonksiyonunu çalıştırır. |
| `filament_cubemap_sh_window` | `FFI_PLUGIN_EXPORT void filament_cubemap_sh_window( float* sh, uint8...` | Filament yerel `filament_cubemap_sh_window` C fonksiyonunu çalıştırır. |
| `filament_cubemap_sh_preprocess_for_shader` | `FFI_PLUGIN_EXPORT void filament_cubemap_sh_preprocess_for_shader( f...` | Filament yerel `filament_cubemap_sh_preprocess_for_shader` C fonksiyonunu çalıştırır. |
| `filament_cubemap_sh_render` | `FFI_PLUGIN_EXPORT void filament_cubemap_sh_render( FilIblCubemap* o...` | Filament görünümünü ve sahnesini GPU üzerinde çizer. |

### `src/iblprefilter_c.h`

| C Fonksiyonu | İmzası | Açıklama ve Ne İşe Yaradığı |
| :--- | :--- | :--- |
| `filament_iblprefilter_context_create` | `FFI_PLUGIN_EXPORT FilIblPrefilterContext* filament_iblprefilter_con...` | İlgili Filament C API kaynağını GPU/motor üzerinde tahsis eder ve ilklendirir. |
| `filament_iblprefilter_context_destroy` | `FFI_PLUGIN_EXPORT void filament_iblprefilter_context_destroy(FilIbl...` | İlgili Filament C API nesnesini yok eder ve GPU belleğini serbest bırakır. |
| `filament_equirect_to_cubemap_create` | `FFI_PLUGIN_EXPORT FilEquirectToCubemap* filament_equirect_to_cubema...` | İlgili Filament C API kaynağını GPU/motor üzerinde tahsis eder ve ilklendirir. |
| `filament_equirect_to_cubemap_destroy` | `FFI_PLUGIN_EXPORT void filament_equirect_to_cubemap_destroy(FilEqui...` | İlgili Filament C API nesnesini yok eder ve GPU belleğini serbest bırakır. |
| `filament_equirect_to_cubemap_run` | `FFI_PLUGIN_EXPORT void* filament_equirect_to_cubemap_run(FilEquirec...` | Filament yerel `filament_equirect_to_cubemap_run` C fonksiyonunu çalıştırır. |
| `filament_specular_filter_create` | `FFI_PLUGIN_EXPORT FilSpecularFilter* filament_specular_filter_creat...` | İlgili Filament C API kaynağını GPU/motor üzerinde tahsis eder ve ilklendirir. |
| `filament_specular_filter_create_config` | `FFI_PLUGIN_EXPORT FilSpecularFilter* filament_specular_filter_creat...` | İlgili Filament C API kaynağını GPU/motor üzerinde tahsis eder ve ilklendirir. |
| `filament_specular_filter_destroy` | `FFI_PLUGIN_EXPORT void filament_specular_filter_destroy(FilSpecular...` | İlgili Filament C API nesnesini yok eder ve GPU belleğini serbest bırakır. |
| `filament_specular_filter_run` | `FFI_PLUGIN_EXPORT void* filament_specular_filter_run(FilSpecularFil...` | Filament yerel `filament_specular_filter_run` C fonksiyonunu çalıştırır. |
| `filament_irradiance_filter_create` | `FFI_PLUGIN_EXPORT FilIrradianceFilter* filament_irradiance_filter_c...` | İlgili Filament C API kaynağını GPU/motor üzerinde tahsis eder ve ilklendirir. |
| `filament_irradiance_filter_create_config` | `FFI_PLUGIN_EXPORT FilIrradianceFilter* filament_irradiance_filter_c...` | İlgili Filament C API kaynağını GPU/motor üzerinde tahsis eder ve ilklendirir. |
| `filament_irradiance_filter_destroy` | `FFI_PLUGIN_EXPORT void filament_irradiance_filter_destroy(FilIrradi...` | İlgili Filament C API nesnesini yok eder ve GPU belleğini serbest bırakır. |
| `filament_irradiance_filter_run` | `FFI_PLUGIN_EXPORT void* filament_irradiance_filter_run(FilIrradianc...` | Filament yerel `filament_irradiance_filter_run` C fonksiyonunu çalıştırır. |

### `src/lighting_c.h`

| C Fonksiyonu | İmzası | Açıklama ve Ne İşe Yaradığı |
| :--- | :--- | :--- |
| `filament_light_create` | `FFI_PLUGIN_EXPORT void filament_light_create(void* engine, uint32_t...` | İlgili Filament C API kaynağını GPU/motor üzerinde tahsis eder ve ilklendirir. |
| `filament_light_destroy` | `FFI_PLUGIN_EXPORT void filament_light_destroy(void* engine, uint32_...` | İlgili Filament C API nesnesini yok eder ve GPU belleğini serbest bırakır. |
| `filament_light_builder_create` | `FFI_PLUGIN_EXPORT void* filament_light_builder_create(int type);` | İlgili Filament C API kaynağını GPU/motor üzerinde tahsis eder ve ilklendirir. |
| `filament_light_builder_position` | `FFI_PLUGIN_EXPORT void filament_light_builder_position(void* builde...` | Filament yerel `filament_light_builder_position` C fonksiyonunu çalıştırır. |
| `filament_light_builder_direction` | `FFI_PLUGIN_EXPORT void filament_light_builder_direction(void* build...` | Filament yerel `filament_light_builder_direction` C fonksiyonunu çalıştırır. |
| `filament_light_builder_color` | `FFI_PLUGIN_EXPORT void filament_light_builder_color(void* builder, ...` | Filament yerel `filament_light_builder_color` C fonksiyonunu çalıştırır. |
| `filament_light_builder_intensity` | `FFI_PLUGIN_EXPORT void filament_light_builder_intensity(void* build...` | Filament yerel `filament_light_builder_intensity` C fonksiyonunu çalıştırır. |
| `filament_light_builder_intensity_candela` | `FFI_PLUGIN_EXPORT void filament_light_builder_intensity_candela(voi...` | Filament yerel `filament_light_builder_intensity_candela` C fonksiyonunu çalıştırır. |
| `filament_light_builder_intensity_watts` | `FFI_PLUGIN_EXPORT void filament_light_builder_intensity_watts(void*...` | Filament yerel `filament_light_builder_intensity_watts` C fonksiyonunu çalıştırır. |
| `filament_light_builder_falloff` | `FFI_PLUGIN_EXPORT void filament_light_builder_falloff(void* builder...` | Filament yerel `filament_light_builder_falloff` C fonksiyonunu çalıştırır. |
| `filament_light_builder_spot_light_cone` | `FFI_PLUGIN_EXPORT void filament_light_builder_spot_light_cone(void*...` | Filament yerel `filament_light_builder_spot_light_cone` C fonksiyonunu çalıştırır. |
| `filament_light_builder_sun_angular_radius` | `FFI_PLUGIN_EXPORT void filament_light_builder_sun_angular_radius(vo...` | Filament yerel `filament_light_builder_sun_angular_radius` C fonksiyonunu çalıştırır. |
| `filament_light_builder_sun_halo_size` | `FFI_PLUGIN_EXPORT void filament_light_builder_sun_halo_size(void* b...` | Filament yerel `filament_light_builder_sun_halo_size` C fonksiyonunu çalıştırır. |
| `filament_light_builder_sun_halo_falloff` | `FFI_PLUGIN_EXPORT void filament_light_builder_sun_halo_falloff(void...` | Filament yerel `filament_light_builder_sun_halo_falloff` C fonksiyonunu çalıştırır. |
| `filament_light_builder_cast_shadows` | `FFI_PLUGIN_EXPORT void filament_light_builder_cast_shadows(void* bu...` | Filament yerel `filament_light_builder_cast_shadows` C fonksiyonunu çalıştırır. |
| `filament_light_builder_cast_light` | `FFI_PLUGIN_EXPORT void filament_light_builder_cast_light(void* buil...` | Filament yerel `filament_light_builder_cast_light` C fonksiyonunu çalıştırır. |
| `filament_light_builder_light_channel` | `FFI_PLUGIN_EXPORT void filament_light_builder_light_channel(void* b...` | Filament yerel `filament_light_builder_light_channel` C fonksiyonunu çalıştırır. |
| `filament_light_builder_build` | `FFI_PLUGIN_EXPORT int32_t filament_light_builder_build(void* builde...` | Filament yerel `filament_light_builder_build` C fonksiyonunu çalıştırır. |
| `filament_light_builder_destroy` | `FFI_PLUGIN_EXPORT void filament_light_builder_destroy(void* builder);` | İlgili Filament C API nesnesini yok eder ve GPU belleğini serbest bırakır. |
| `filament_light_set_color` | `FFI_PLUGIN_EXPORT void filament_light_set_color(void* engine, uint3...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_light_get_color` | `FFI_PLUGIN_EXPORT void filament_light_get_color(void* engine, uint3...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_light_set_intensity` | `FFI_PLUGIN_EXPORT void filament_light_set_intensity(void* engine, u...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_light_set_intensity_candela` | `FFI_PLUGIN_EXPORT void filament_light_set_intensity_candela(void* e...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_light_set_intensity_watts` | `FFI_PLUGIN_EXPORT void filament_light_set_intensity_watts(void* eng...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_light_get_intensity` | `FFI_PLUGIN_EXPORT float filament_light_get_intensity(void* engine, ...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_light_set_direction` | `FFI_PLUGIN_EXPORT void filament_light_set_direction(void* engine, u...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_light_get_direction` | `FFI_PLUGIN_EXPORT void filament_light_get_direction(void* engine, u...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_light_set_position` | `FFI_PLUGIN_EXPORT void filament_light_set_position(void* engine, ui...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_light_get_position` | `FFI_PLUGIN_EXPORT void filament_light_get_position(void* engine, ui...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_light_set_falloff` | `FFI_PLUGIN_EXPORT void filament_light_set_falloff(void* engine, uin...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_light_get_falloff` | `FFI_PLUGIN_EXPORT float filament_light_get_falloff(void* engine, ui...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_light_set_spot_light_cone` | `FFI_PLUGIN_EXPORT void filament_light_set_spot_light_cone(void* eng...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_light_get_spot_light_inner_cone` | `FFI_PLUGIN_EXPORT float filament_light_get_spot_light_inner_cone(vo...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_light_get_spot_light_outer_cone` | `FFI_PLUGIN_EXPORT float filament_light_get_spot_light_outer_cone(vo...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_light_set_shadow_caster` | `FFI_PLUGIN_EXPORT void filament_light_set_shadow_caster(void* engin...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_light_is_shadow_caster` | `FFI_PLUGIN_EXPORT bool filament_light_is_shadow_caster(void* engine...` | Filament C motor durum veya yetenek doğrulamasını yapar. |
| `filament_light_set_light_channel` | `FFI_PLUGIN_EXPORT void filament_light_set_light_channel(void* engin...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_light_get_light_channel` | `FFI_PLUGIN_EXPORT bool filament_light_get_light_channel(void* engin...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_light_has_component` | `FFI_PLUGIN_EXPORT bool filament_light_has_component(void* engine, u...` | Filament C motor durum veya yetenek doğrulamasını yapar. |
| `filament_light_get_instance` | `FFI_PLUGIN_EXPORT uint32_t filament_light_get_instance(void* engine...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| *... ve 33 ek C fonksiyonu* | - | İlgili C kütüphane bağlayıcıları. |

## Dart API

### `lib/src/ibl_bake.dart`

#### `class CubemapIBL`

Offline IBL baking operations: roughness filtering, diffuse irradiance, and DFG LUT generation.

### `lib/src/ibl_cubemap.dart`

#### `enum IblCubemapFace`

The 6 faces of a cubemap in standard Filament/OpenGL order.

**Yapıcı Metotlar (Constructors):**
- `IblCubemapFace(this._cEnum)`: `IblCubemapFace(this._cEnum)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `nz` | `nz(c.FilCubemapFace.FIL_CUBEMAP_FACE_NZ)` | `nz` işlemini gerçekleştirir. |
| `value` | `int get value` | `value` özelliğinin anlık değerini okuyan getter erişimcisi. |

#### `class IblImage`

A 3-channel (RGB float) CPU image used in the IBL pipeline.

**Yapıcı Metotlar (Constructors):**
- `IblImage(this.width, this.height)`: `IblImage(this.width, this.height)` nesnesini ilklendirir.
- `IblImage._fromHandle(ffi.Pointer<c.FilIblImage> handle)`: `IblImage._fromHandle(ffi.Pointer<c.FilIblImage> handle)` nesnesini ilklendirir.
- `IblImage.fromLinearImage(LinearImage img)`: `IblImage.fromLinearImage(LinearImage img)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `width` | `int width` | `width` alanını (field/property) ve ilişkili veriyi saklar. |
| `height` | `int height` | `height` alanını (field/property) ve ilişkili veriyi saklar. |
| `bytesPerRow` | `int get bytesPerRow` | Row stride in bytes as stored natively. |
| `isContiguous` | `bool get isContiguous` | True when rows are packed (`bytesPerRow == width * 3 * 4`) and [data] is a live view; false for cubemap face sub-images where [data] is a copy. |
| `fill` | `void fill(double r, double g, double b)` | Fills every pixel with the given RGB value (stride-aware). |
| `writeData` | `void writeData(Float32List tight)` | Writes tightly packed RGB floats (`width * height * 3`) into the image, honouring the native row stride. |
| `getPixel` | `List<double> getPixel(int x, int y)` | Reads one RGB pixel honouring the native stride. |
| `setPixel` | `void setPixel(int x, int y, double r, double g, double b)` | Writes one RGB pixel honouring the native stride (works for face sub-images too); keeps [data] in sync for strided images. |
| `fromNativeHandle` | `static IblImage? fromNativeHandle(ffi.Pointer<c.FilIblImage> handle)` | `fromNativeHandle` işlemini gerçekleştirir. |
| `toLinearImage` | `LinearImage toLinearImage()` | `toLinearImage` işlemini gerçekleştirir. |
| `data` | `Float32List get data` | RGB float pixels, row-major, tightly packed. For contiguous images this is a live view of native memory (writes take effect immediately); for strided sub-images (see [isContiguous]) it is a snapshot — use [setPixel] to write. |
| `destroy` | `void destroy()` | Belirtilen `` nesnesini/bileşenini serbest bırakır ve güvenle temizler. |

#### `class IblCubemap`

A CPU cubemap consisting of 6 square [IblImage] faces with dimensions [dimensions] x [dimensions].

**Yapıcı Metotlar (Constructors):**
- `IblCubemap(this.dimensions)`: `IblCubemap(this.dimensions)` nesnesini ilklendirir.
- `IblCubemap._fromHandle(ffi.Pointer<c.FilIblCubemap> handle)`: `IblCubemap._fromHandle(ffi.Pointer<c.FilIblCubemap> handle)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `dimensions` | `int dimensions` | `dimensions` alanını (field/property) ve ilişkili veriyi saklar. |
| `fromNativeHandle` | `static IblCubemap? fromNativeHandle(ffi.Pointer<c.FilIblCubemap> handle)` | `fromNativeHandle` işlemini gerçekleştirir. |
| `faceImage` | `IblImage faceImage(IblCubemapFace face)` | `faceImage` işlemini gerçekleştirir. |
| `destroy` | `void destroy()` | Belirtilen `` nesnesini/bileşenini serbest bırakır ve güvenle temizler. |

#### `class CubemapUtils`

Utility conversions for CPU cubemaps and equirectangular environments.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `equirectangularToCubemap` | `static void equirectangularToCubemap(IblCubemap dst, IblImage src)` | `equirectangularToCubemap` işlemini gerçekleştirir. |
| `cubemapToEquirectangular` | `static void cubemapToEquirectangular(IblImage dst, IblCubemap src)` | `cubemapToEquirectangular` işlemini gerçekleştirir. |
| `setAllFacesFromCross` | `static void setAllFacesFromCross(IblCubemap cMap, IblImage cross)` | `AllFacesFromCross` parametresini günceller ve sisteme uygular. |
| `crossToCubemap` | `static IblCubemap crossToCubemap(IblImage cross)` | `crossToCubemap` işlemini gerçekleştirir. |
| `cubemapToOctahedron` | `static void cubemapToOctahedron(IblImage dst, IblCubemap src)` | `cubemapToOctahedron` işlemini gerçekleştirir. |
| `mirrorCubemap` | `static void mirrorCubemap(IblCubemap dst, IblCubemap src)` | `mirrorCubemap` işlemini gerçekleştirir. |
| `downsampleCubemapLevelBoxFilter` | `static void downsampleCubemapLevelBoxFilter(IblCubemap dst, IblCubemap src)` | `downsampleCubemapLevelBoxFilter` işlemini gerçekleştirir. |
| `makeSeamless` | `static void makeSeamless(IblCubemap cMap)` | `makeSeamless` işlemini gerçekleştirir. |

### `lib/src/ibl_sh.dart`

#### `class CubemapSH`

Spherical Harmonics decomposition and manipulation for IBL.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `preprocessSHForShader` | `static void preprocessSHForShader(Float32List sh)` | Pre-scales 3-band SH coefficients into the format expected by `IndirectLight::irradiance`. |
| `getShIndex` | `static int getShIndex(int m, int l)` | Pure Dart spherical harmonics index calculation: $l(l+1) + m$. |

### `lib/src/iblprefilter.dart`

#### `enum SpecularFilterKernel`

Filter kernel distribution used by specular and irradiance prefiltering.

**Yapıcı Metotlar (Constructors):**
- `SpecularFilterKernel(this.value)`: `SpecularFilterKernel(this.value)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `dGgx` | `dGgx(0)` | `dGgx` işlemini gerçekleştirir. |
| `value` | `int value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |

#### `class SpecularFilterConfig`

Configuration settings for [SpecularFilter].

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `sampleCount` | `int sampleCount` | Number of integration samples per pixel (max 2048). |
| `levelCount` | `int levelCount` | Number of roughness mipmap levels to generate. |
| `kernel` | `SpecularFilterKernel kernel` | Distribution kernel to evaluate. |

#### `class SpecularFilterOptions`

Dynamic HDR filtering options for [SpecularFilter].

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `hdrLinear` | `double hdrLinear` | `hdrLinear` alanını (field/property) ve ilişkili veriyi saklar. |
| `hdrMax` | `double hdrMax` | `hdrMax` alanını (field/property) ve ilişkili veriyi saklar. |
| `lodOffset` | `double lodOffset` | `lodOffset` alanını (field/property) ve ilişkili veriyi saklar. |
| `generateMipmap` | `bool generateMipmap` | `generateMipmap` alanını (field/property) ve ilişkili veriyi saklar. |

#### `class IrradianceFilterConfig`

Configuration settings for [IrradianceFilter].

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `sampleCount` | `int sampleCount` | Number of integration samples per pixel (max 2048). |
| `kernel` | `SpecularFilterKernel kernel` | Distribution kernel to evaluate. |

#### `class IrradianceFilterOptions`

Dynamic HDR filtering options for [IrradianceFilter].

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `hdrLinear` | `double hdrLinear` | `hdrLinear` alanını (field/property) ve ilişkili veriyi saklar. |
| `hdrMax` | `double hdrMax` | `hdrMax` alanını (field/property) ve ilişkili veriyi saklar. |
| `lodOffset` | `double lodOffset` | `lodOffset` alanını (field/property) ve ilişkili veriyi saklar. |
| `generateMipmap` | `bool generateMipmap` | `generateMipmap` alanını (field/property) ve ilişkili veriyi saklar. |

#### `class IblPrefilterContext`

Manages shared GPU state and shaders used by IBL prefiltering operations.

**Yapıcı Metotlar (Constructors):**
- `IblPrefilterContext(this.engine)`: `IblPrefilterContext(this.engine)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `engine` | `FilamentEngine engine` | `engine` alanını (field/property) ve ilişkili veriyi saklar. |
| `destroy` | `void destroy()` | Destroys GPU state held by this context. |

#### `class EquirectangularToCubemap`

Converts a 2D equirectangular panorama texture into a 6-faced cubemap on the GPU.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `context` | `IblPrefilterContext context` | `context` alanını (field/property) ve ilişkili veriyi saklar. |
| `destroy` | `void destroy()` | Destroys this converter. |

#### `class SpecularFilter`

Prefilters an environment cubemap into specular reflection mipmaps according to roughness.

**Yapıcı Metotlar (Constructors):**
- `SpecularFilter(this.context, [SpecularFilterConfig? config])`: `SpecularFilter(this.context, [SpecularFilterConfig? config])` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `context` | `IblPrefilterContext context` | `context` alanını (field/property) ve ilişkili veriyi saklar. |
| `config` | `SpecularFilterConfig config` | `config` alanını (field/property) ve ilişkili veriyi saklar. |
| `destroy` | `void destroy()` | Destroys this filter instance. |

#### `class IrradianceFilter`

Generates a diffuse irradiance cubemap from an environment cubemap on the GPU.

**Yapıcı Metotlar (Constructors):**
- `IrradianceFilter(this.context, [IrradianceFilterConfig? config])`: `IrradianceFilter(this.context, [IrradianceFilterConfig? config])` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `context` | `IblPrefilterContext context` | `context` alanını (field/property) ve ilişkili veriyi saklar. |
| `config` | `IrradianceFilterConfig config` | `config` alanını (field/property) ve ilişkili veriyi saklar. |
| `destroy` | `void destroy()` | Destroys this filter instance. |

### `lib/src/indirect_light.dart`

#### `class SphericalHarmonics`

Represents spherical harmonics (SH) coefficients of 1, 2, or 3 bands.  SH coefficients are stored as 3 floats (RGB) per coefficient. The number of coefficients is `bands * bands` (1, 4, or 9 coefficients, or 3, 12, or 27 float values). The index formula is: `index(l, m) = l * (l + 1) + m`.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `bands` | `int bands` | Number of spherical harmonics bands (1, 2, or 3). |
| `coefficients` | `Float32List coefficients` | Packed float3 coefficients (length must be `bands * bands * 3`). |
| `shIndex` | `static int shIndex(int l, int m)` | Calculates the index of the spherical harmonic coefficient for band [l] and degree [m].  Formula: `index(l, m) = l * (l + 1) + m`. |

#### `class FilamentIndirectLight`

Represents an Image-Based Lighting (IBL) IndirectLight source in Filament.  Simulates global illumination from a distant environment, supporting reflections cubemaps and spherical harmonics irradiance / radiance.

**Yapıcı Metotlar (Constructors):**
- `FilamentIndirectLight._(this._ptr, this._engine, [this._reflectionsTexture])`: `FilamentIndirectLight._(this._ptr, this._engine, [this._reflectionsTexture])` nesnesini ilklendirir.
- `FilamentIndirectLight.internal(this._ptr, this._engine, [this._reflectionsTexture])`: Internal constructor.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
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
| `isDisposed` | `bool get isDisposed` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |

### `lib/src/light.dart`

#### `enum LightType`

Types of lights supported by Filament.

**Yapıcı Metotlar (Constructors):**
- `LightType(this.value)`: `LightType(this.value)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `spot` | `spot(4)` | `spot` işlemini gerçekleştirir. |
| `value` | `int value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |

#### `class LightBuilder`

Fluent builder for constructing and configuring a Filament light component.

**Yapıcı Metotlar (Constructors):**
- `LightBuilder(LightType type)`: Creates a builder for the specified [type].

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
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

**Yapıcı Metotlar (Constructors):**
- `FilamentLightManager(this.engine)`: Creates a light manager wrapper.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `engine` | `FilamentEngine engine` | `engine` alanını (field/property) ve ilişkili veriyi saklar. |
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

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `mapSize` | `int mapSize` | `mapSize` alanını (field/property) ve ilişkili veriyi saklar. |
| `shadowCascades` | `int shadowCascades` | `shadowCascades` alanını (field/property) ve ilişkili veriyi saklar. |
| `cascadeSplitPositions` | `List<double> cascadeSplitPositions` | `cascadeSplitPositions` alanını (field/property) ve ilişkili veriyi saklar. |
| `constantBias` | `double constantBias` | `constantBias` alanını (field/property) ve ilişkili veriyi saklar. |
| `normalBias` | `double normalBias` | `normalBias` alanını (field/property) ve ilişkili veriyi saklar. |
| `shadowFar` | `double shadowFar` | `shadowFar` alanını (field/property) ve ilişkili veriyi saklar. |
| `shadowNearHint` | `double shadowNearHint` | `shadowNearHint` alanını (field/property) ve ilişkili veriyi saklar. |
| `shadowFarHint` | `double shadowFarHint` | `shadowFarHint` alanını (field/property) ve ilişkili veriyi saklar. |
| `stable` | `bool stable` | `stable` alanını (field/property) ve ilişkili veriyi saklar. |
| `rayTraced` | `bool rayTraced` | Sert gölgeleri kademeli gölge haritaları yerine sahnenin ışın izleme hızlandırma yapılarına karşı izler; yalnızca yönlü ışıklar, ray query desteği yoksa haritalara döner (bkz. [Işın izleme](ray-tracing.md)). Varsayılan false. |
| `lispsm` | `bool lispsm` | `lispsm` alanını (field/property) ve ilişkili veriyi saklar. |
| `polygonOffsetConstant` | `double polygonOffsetConstant` | `polygonOffsetConstant` alanını (field/property) ve ilişkili veriyi saklar. |
| `polygonOffsetSlope` | `double polygonOffsetSlope` | `polygonOffsetSlope` alanını (field/property) ve ilişkili veriyi saklar. |
| `screenSpaceContactShadows` | `bool screenSpaceContactShadows` | `screenSpaceContactShadows` alanını (field/property) ve ilişkili veriyi saklar. |
| `stepCount` | `int stepCount` | `stepCount` alanını (field/property) ve ilişkili veriyi saklar. |
| `maxShadowDistance` | `double maxShadowDistance` | `maxShadowDistance` alanını (field/property) ve ilişkili veriyi saklar. |
| `elvsm` | `bool elvsm` | `elvsm` alanını (field/property) ve ilişkili veriyi saklar. |
| `blurWidth` | `double blurWidth` | `blurWidth` alanını (field/property) ve ilişkili veriyi saklar. |
| `shadowBulbRadius` | `double shadowBulbRadius` | `shadowBulbRadius` alanını (field/property) ve ilişkili veriyi saklar. |
| `transform` | `List<double> transform` | `transform` alanını (field/property) ve ilişkili veriyi saklar. |
| `penumbraScale` | `double penumbraScale` | `penumbraScale` alanını (field/property) ve ilişkili veriyi saklar. |
| `penumbraRatioScale` | `double penumbraRatioScale` | `penumbraRatioScale` alanını (field/property) ve ilişkili veriyi saklar. |
| `maxPenumbraRatio` | `double maxPenumbraRatio` | `maxPenumbraRatio` alanını (field/property) ve ilişkili veriyi saklar. |

#### `class ShadowCascades`

Utility methods for computing cascaded shadow map (CSM) split schemes.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `computeUniformSplits` | `static List<double> computeUniformSplits(int cascades)` | Computes split positions for [cascades] using a uniform split scheme. |

#### `class LightEfficiency`

Standard luminous efficacy constants matching Filament's `EFFICIENCY_*` values.

### `lib/src/skybox.dart`

#### `class FilamentSkybox`

A Skybox fills all untouched background pixels in a scene.  Can be configured with an environment cubemap texture or a solid color, with optional sun disk rendering and rendering priority.

**Yapıcı Metotlar (Constructors):**
- `FilamentSkybox._(this._ptr, this._engine, [this._environmentTexture])`: `FilamentSkybox._(this._ptr, this._engine, [this._environmentTexture])` nesnesini ilklendirir.
- `FilamentSkybox.internal(this._ptr, this._engine, [this._environmentTexture])`: Internal constructor.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `color` | `color(Vector4 col)` | Sets the solid color of this Skybox at runtime (fades/transitions). |
| `layerMask` | `int get layerMask` | Gets the layer mask visibility bits. |
| `intensity` | `double get intensity` | Gets the skybox intensity in lux / cd/m². |
| `texture` | `FilamentTexture? get texture` | Gets the associated environment texture, or null if this is a solid color skybox. |
| `dispose` | `void dispose()` | Destroys this Skybox. |
| `isDisposed` | `bool get isDisposed` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |

---

[Önceki: Kamera ve manipulator](camera-and-manipulator.md) | [Üst: flutter_filament](index.md) | [Sonraki: Materyaller](materials.md)
