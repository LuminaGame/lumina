[English](../../en/flutter_filament/textures-and-images.md)

# Texture'lar ve görseller

GPU texture'ları ve sampler'lar, glTF yüklemenin kullandığı texture provider, linear image'lar ve görsel işlemleri, görsel encode/decode, KTX1 bundle'ları, KTX2 reader ve Basis Universal transcoder. Dosya yolları `flutter_filament/` paket dizinine görelidir.

**Bu sayfada:**

- [Native C köprüsü](#native-c-köprüsü)
  - [`src/image_ops_c.h`](#srcimage_ops_ch)
  - [`src/image_sampler_c.h`](#srcimage_sampler_ch)
  - [`src/image_sdf_c.h`](#srcimage_sdf_ch)
  - [`src/imageio_c.h`](#srcimageio_ch)
  - [`src/ktx1_c.h`](#srcktx1_ch)
  - [`src/ktx2_reader_c.h`](#srcktx2_reader_ch)
  - [`src/linear_image_c.h`](#srclinear_image_ch)
  - [`src/texture_c.h`](#srctexture_ch)
  - [`src/texture_sampler_c.h`](#srctexture_sampler_ch)
- [Dart API](#dart-api)
  - [`lib/src/image_ops.dart`](#libsrcimage_opsdart)
  - [`lib/src/image_sampler.dart`](#libsrcimage_samplerdart)
  - [`lib/src/imageio.dart`](#libsrcimageiodart)
  - [`lib/src/ktx1.dart`](#libsrcktx1dart)
  - [`lib/src/ktx2_reader.dart`](#libsrcktx2_readerdart)
  - [`lib/src/linear_image.dart`](#libsrclinear_imagedart)
  - [`lib/src/texture.dart`](#libsrctexturedart)
  - [`lib/src/texture_provider.dart`](#libsrctexture_providerdart)
  - [`lib/src/texture_sampler.dart`](#libsrctexture_samplerdart)
  - [`lib/src/transcoder.dart`](#libsrctranscoderdart)
  - [`lib/src/image_sdf.dart`](#libsrcimage_sdfdart)

## Native C köprüsü

Aşağıdaki C fonksiyonları paketin `src/` header'larında tanımlanır ve Dart'tan FFI ile çağrılır.

### `src/image_ops_c.h`

| C Fonksiyonu | İmzası | Açıklama ve Ne İşe Yaradığı |
| :--- | :--- | :--- |
| `filament_image_extract_channel` | `FFI_PLUGIN_EXPORT FilLinearImage* filament_image_extract_channel(co...` | Filament yerel `filament_image_extract_channel` C fonksiyonunu çalıştırır. |
| `filament_image_combine_channels` | `FFI_PLUGIN_EXPORT FilLinearImage* filament_image_combine_channels(c...` | Filament yerel `filament_image_combine_channels` C fonksiyonunu çalıştırır. |
| `filament_image_crop_region` | `FFI_PLUGIN_EXPORT FilLinearImage* filament_image_crop_region(const ...` | Filament yerel `filament_image_crop_region` C fonksiyonunu çalıştırır. |
| `filament_image_blit` | `FFI_PLUGIN_EXPORT void filament_image_blit(FilLinearImage* dst, con...` | Filament yerel `filament_image_blit` C fonksiyonunu çalıştırır. |
| `filament_image_horizontal_stack` | `FFI_PLUGIN_EXPORT FilLinearImage* filament_image_horizontal_stack(c...` | Filament yerel `filament_image_horizontal_stack` C fonksiyonunu çalıştırır. |
| `filament_image_vertical_stack` | `FFI_PLUGIN_EXPORT FilLinearImage* filament_image_vertical_stack(con...` | Filament yerel `filament_image_vertical_stack` C fonksiyonunu çalıştırır. |
| `filament_image_horizontal_flip` | `FFI_PLUGIN_EXPORT FilLinearImage* filament_image_horizontal_flip(co...` | Filament yerel `filament_image_horizontal_flip` C fonksiyonunu çalıştırır. |
| `filament_image_vertical_flip` | `FFI_PLUGIN_EXPORT FilLinearImage* filament_image_vertical_flip(cons...` | Filament yerel `filament_image_vertical_flip` C fonksiyonunu çalıştırır. |
| `filament_image_transpose` | `FFI_PLUGIN_EXPORT FilLinearImage* filament_image_transpose(const Fi...` | Filament yerel `filament_image_transpose` C fonksiyonunu çalıştırır. |
| `filament_image_vectors_to_colors` | `FFI_PLUGIN_EXPORT FilLinearImage* filament_image_vectors_to_colors(...` | Filament yerel `filament_image_vectors_to_colors` C fonksiyonunu çalıştırır. |
| `filament_image_colors_to_vectors` | `FFI_PLUGIN_EXPORT FilLinearImage* filament_image_colors_to_vectors(...` | Filament yerel `filament_image_colors_to_vectors` C fonksiyonunu çalıştırır. |
| `filament_image_compare` | `FFI_PLUGIN_EXPORT int filament_image_compare(const FilLinearImage* ...` | Filament yerel `filament_image_compare` C fonksiyonunu çalıştırır. |
| `filament_image_clear_to_value` | `FFI_PLUGIN_EXPORT void filament_image_clear_to_value(FilLinearImage...` | Filament yerel `filament_image_clear_to_value` C fonksiyonunu çalıştırır. |

### `src/image_sampler_c.h`

| C Fonksiyonu | İmzası | Açıklama ve Ne İşe Yaradığı |
| :--- | :--- | :--- |
| `filament_image_resample` | `FFI_PLUGIN_EXPORT FilLinearImage* filament_image_resample( const Fi...` | Filament yerel `filament_image_resample` C fonksiyonunu çalıştırır. |
| `filament_image_resample_region` | `FFI_PLUGIN_EXPORT FilLinearImage* filament_image_resample_region( c...` | Filament yerel `filament_image_resample_region` C fonksiyonunu çalıştırır. |
| `filament_image_get_mipmap_count` | `FFI_PLUGIN_EXPORT uint32_t filament_image_get_mipmap_count(const Fi...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_image_generate_mipmaps` | `FFI_PLUGIN_EXPORT void filament_image_generate_mipmaps( const FilLi...` | Filament yerel `filament_image_generate_mipmaps` C fonksiyonunu çalıştırır. |

### `src/image_sdf_c.h`

| C Fonksiyonu | İmzası | Açıklama ve Ne İşe Yaradığı |
| :--- | :--- | :--- |
| `filament_image_compute_coord_field` | `FFI_PLUGIN_EXPORT FilLinearImage* filament_image_compute_coord_fiel...` | Filament yerel `filament_image_compute_coord_field` C fonksiyonunu çalıştırır. |
| `filament_image_edt_from_coord_field` | `FFI_PLUGIN_EXPORT FilLinearImage* filament_image_edt_from_coord_fie...` | Filament yerel `filament_image_edt_from_coord_field` C fonksiyonunu çalıştırır. |
| `filament_image_voronoi_from_coord_field` | `FFI_PLUGIN_EXPORT FilLinearImage* filament_image_voronoi_from_coord...` | Filament yerel `filament_image_voronoi_from_coord_field` C fonksiyonunu çalıştırır. |

### `src/imageio_c.h`

| C Fonksiyonu | İmzası | Açıklama ve Ne İşe Yaradığı |
| :--- | :--- | :--- |
| `filament_image_decode` | `FFI_PLUGIN_EXPORT FilLinearImage* filament_image_decode( const uint...` | Filament yerel `filament_image_decode` C fonksiyonunu çalıştırır. |
| `filament_image_encode` | `FFI_PLUGIN_EXPORT bool filament_image_encode( int format, const Fil...` | Filament yerel `filament_image_encode` C fonksiyonunu çalıştırır. |
| `filament_image_encode_free` | `FFI_PLUGIN_EXPORT void filament_image_encode_free(uint8_t* data);` | Filament yerel `filament_image_encode_free` C fonksiyonunu çalıştırır. |
| `filament_basis_encoder_builder_create` | `FFI_PLUGIN_EXPORT FilBasisEncoderBuilder* filament_basis_encoder_bu...` | İlgili Filament C API kaynağını GPU/motor üzerinde tahsis eder ve ilklendirir. |
| `filament_basis_encoder_builder_miplevel` | `FFI_PLUGIN_EXPORT void filament_basis_encoder_builder_miplevel( Fil...` | Filament C motor durum veya yetenek doğrulamasını yapar. |
| `filament_basis_encoder_builder_intermediate_format` | `FFI_PLUGIN_EXPORT void filament_basis_encoder_builder_intermediate_...` | Filament C motor durum veya yetenek doğrulamasını yapar. |
| `filament_basis_encoder_builder_build` | `FFI_PLUGIN_EXPORT FilBasisEncoder* filament_basis_encoder_builder_b...` | Filament C motor durum veya yetenek doğrulamasını yapar. |
| `filament_basis_encoder_builder_destroy` | `FFI_PLUGIN_EXPORT void filament_basis_encoder_builder_destroy( FilB...` | İlgili Filament C API nesnesini yok eder ve GPU belleğini serbest bırakır. |
| `filament_basis_encoder_encode` | `FFI_PLUGIN_EXPORT bool filament_basis_encoder_encode(FilBasisEncode...` | Filament C motor durum veya yetenek doğrulamasını yapar. |
| `filament_basis_encoder_get_ktx2_byte_count` | `FFI_PLUGIN_EXPORT size_t filament_basis_encoder_get_ktx2_byte_count...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_basis_encoder_get_ktx2_data` | `FFI_PLUGIN_EXPORT const uint8_t* filament_basis_encoder_get_ktx2_da...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_basis_encoder_destroy` | `FFI_PLUGIN_EXPORT void filament_basis_encoder_destroy(FilBasisEncod...` | İlgili Filament C API nesnesini yok eder ve GPU belleğini serbest bırakır. |

### `src/ktx1_c.h`

| C Fonksiyonu | İmzası | Açıklama ve Ne İşe Yaradığı |
| :--- | :--- | :--- |
| `filament_ktx1_bundle_create` | `FFI_PLUGIN_EXPORT FilKtx1Bundle* filament_ktx1_bundle_create(const ...` | İlgili Filament C API kaynağını GPU/motor üzerinde tahsis eder ve ilklendirir. |
| `filament_ktx1_bundle_create_empty` | `FFI_PLUGIN_EXPORT FilKtx1Bundle* filament_ktx1_bundle_create_empty(...` | İlgili Filament C API kaynağını GPU/motor üzerinde tahsis eder ve ilklendirir. |
| `filament_ktx1_bundle_destroy` | `FFI_PLUGIN_EXPORT void filament_ktx1_bundle_destroy(FilKtx1Bundle* b);` | İlgili Filament C API nesnesini yok eder ve GPU belleğini serbest bırakır. |
| `filament_ktx1_bundle_get_num_mip_levels` | `FFI_PLUGIN_EXPORT uint32_t filament_ktx1_bundle_get_num_mip_levels(...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_ktx1_bundle_get_array_length` | `FFI_PLUGIN_EXPORT uint32_t filament_ktx1_bundle_get_array_length(co...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_ktx1_bundle_is_cubemap` | `FFI_PLUGIN_EXPORT bool filament_ktx1_bundle_is_cubemap(const FilKtx...` | Filament C motor durum veya yetenek doğrulamasını yapar. |
| `filament_ktx1_bundle_get_spherical_harmonics` | `FFI_PLUGIN_EXPORT bool filament_ktx1_bundle_get_spherical_harmonics...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_ktx1_bundle_get_metadata` | `FFI_PLUGIN_EXPORT const char* filament_ktx1_bundle_get_metadata(con...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_ktx1_bundle_set_metadata` | `FFI_PLUGIN_EXPORT void filament_ktx1_bundle_set_metadata(FilKtx1Bun...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_ktx1_bundle_get_blob` | `FFI_PLUGIN_EXPORT bool filament_ktx1_bundle_get_blob(const FilKtx1B...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_ktx1_bundle_set_blob` | `FFI_PLUGIN_EXPORT bool filament_ktx1_bundle_set_blob(FilKtx1Bundle*...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_ktx1_bundle_get_serialized_length` | `FFI_PLUGIN_EXPORT uint32_t filament_ktx1_bundle_get_serialized_leng...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_ktx1_bundle_serialize` | `FFI_PLUGIN_EXPORT bool filament_ktx1_bundle_serialize(const FilKtx1...` | Filament yerel `filament_ktx1_bundle_serialize` C fonksiyonunu çalıştırır. |
| `filament_ktx1_reader_create_texture` | `FFI_PLUGIN_EXPORT void* filament_ktx1_reader_create_texture(void* e...` | İlgili Filament C API kaynağını GPU/motor üzerinde tahsis eder ve ilklendirir. |

### `src/ktx2_reader_c.h`

| C Fonksiyonu | İmzası | Açıklama ve Ne İşe Yaradığı |
| :--- | :--- | :--- |
| `filament_ktx2_reader_create` | `FFI_PLUGIN_EXPORT FilKtx2Reader* filament_ktx2_reader_create(void* ...` | İlgili Filament C API kaynağını GPU/motor üzerinde tahsis eder ve ilklendirir. |
| `filament_ktx2_reader_destroy` | `FFI_PLUGIN_EXPORT void filament_ktx2_reader_destroy(FilKtx2Reader* r);` | İlgili Filament C API nesnesini yok eder ve GPU belleğini serbest bırakır. |
| `filament_ktx2_reader_request_format` | `FFI_PLUGIN_EXPORT int filament_ktx2_reader_request_format(FilKtx2Re...` | Filament yerel `filament_ktx2_reader_request_format` C fonksiyonunu çalıştırır. |
| `filament_ktx2_reader_unrequest_format` | `FFI_PLUGIN_EXPORT void filament_ktx2_reader_unrequest_format(FilKtx...` | Filament yerel `filament_ktx2_reader_unrequest_format` C fonksiyonunu çalıştırır. |
| `filament_ktx2_reader_load` | `FFI_PLUGIN_EXPORT void* filament_ktx2_reader_load(FilKtx2Reader* r,...` | Filament yerel `filament_ktx2_reader_load` C fonksiyonunu çalıştırır. |
| `filament_ktx2_reader_async_create` | `FFI_PLUGIN_EXPORT FilKtx2Async* filament_ktx2_reader_async_create(F...` | İlgili Filament C API kaynağını GPU/motor üzerinde tahsis eder ve ilklendirir. |
| `filament_ktx2_async_get_texture` | `FFI_PLUGIN_EXPORT void* filament_ktx2_async_get_texture(const FilKt...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_ktx2_async_do_transcoding` | `FFI_PLUGIN_EXPORT int filament_ktx2_async_do_transcoding(FilKtx2Asy...` | Filament yerel `filament_ktx2_async_do_transcoding` C fonksiyonunu çalıştırır. |
| `filament_ktx2_async_upload_images` | `FFI_PLUGIN_EXPORT void filament_ktx2_async_upload_images(FilKtx2Asy...` | Filament yerel `filament_ktx2_async_upload_images` C fonksiyonunu çalıştırır. |
| `filament_ktx2_reader_async_destroy` | `FFI_PLUGIN_EXPORT void filament_ktx2_reader_async_destroy(FilKtx2Re...` | İlgili Filament C API nesnesini yok eder ve GPU belleğini serbest bırakır. |

### `src/linear_image_c.h`

| C Fonksiyonu | İmzası | Açıklama ve Ne İşe Yaradığı |
| :--- | :--- | :--- |
| `filament_linear_image_create` | `FFI_PLUGIN_EXPORT FilLinearImage* filament_linear_image_create(uint...` | İlgili Filament C API kaynağını GPU/motor üzerinde tahsis eder ve ilklendirir. |
| `filament_linear_image_share` | `FFI_PLUGIN_EXPORT FilLinearImage* filament_linear_image_share(const...` | Filament yerel `filament_linear_image_share` C fonksiyonunu çalıştırır. |
| `filament_linear_image_destroy` | `FFI_PLUGIN_EXPORT void filament_linear_image_destroy(FilLinearImage...` | İlgili Filament C API nesnesini yok eder ve GPU belleğini serbest bırakır. |
| `filament_linear_image_get_width` | `FFI_PLUGIN_EXPORT uint32_t filament_linear_image_get_width(const Fi...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_linear_image_get_height` | `FFI_PLUGIN_EXPORT uint32_t filament_linear_image_get_height(const F...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_linear_image_get_channels` | `FFI_PLUGIN_EXPORT uint32_t filament_linear_image_get_channels(const...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_linear_image_get_pixel_data` | `FFI_PLUGIN_EXPORT float* filament_linear_image_get_pixel_data(FilLi...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_linear_image_is_valid` | `FFI_PLUGIN_EXPORT bool filament_linear_image_is_valid(const FilLine...` | Filament C motor durum veya yetenek doğrulamasını yapar. |

### `src/texture_c.h`

| C Fonksiyonu | İmzası | Açıklama ve Ne İşe Yaradığı |
| :--- | :--- | :--- |
| `filament_texture_create` | `FFI_PLUGIN_EXPORT void* filament_texture_create(void* engine, const...` | İlgili Filament C API kaynağını GPU/motor üzerinde tahsis eder ve ilklendirir. |
| `filament_texture_create_2d` | `FFI_PLUGIN_EXPORT void* filament_texture_create_2d(void* engine, ui...` | İlgili Filament C API kaynağını GPU/motor üzerinde tahsis eder ve ilklendirir. |
| `filament_texture_set_image` | `FFI_PLUGIN_EXPORT void filament_texture_set_image(void* engine, voi...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_texture_set_image_ex` | `FFI_PLUGIN_EXPORT void filament_texture_set_image_ex( void* engine,...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_engine_destroy_texture` | `FFI_PLUGIN_EXPORT void filament_engine_destroy_texture(void* engine...` | İlgili Filament C API nesnesini yok eder ve GPU belleğini serbest bırakır. |
| `filament_texture_generate_mipmaps` | `FFI_PLUGIN_EXPORT void filament_texture_generate_mipmaps(void* engi...` | Filament yerel `filament_texture_generate_mipmaps` C fonksiyonunu çalıştırır. |
| `filament_texture_get_width` | `FFI_PLUGIN_EXPORT uint32_t filament_texture_get_width(void* texture...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_texture_get_height` | `FFI_PLUGIN_EXPORT uint32_t filament_texture_get_height(void* textur...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_texture_get_depth` | `FFI_PLUGIN_EXPORT uint32_t filament_texture_get_depth(void* texture...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_texture_get_levels` | `FFI_PLUGIN_EXPORT uint8_t filament_texture_get_levels(void* texture);` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_texture_get_target` | `FFI_PLUGIN_EXPORT int32_t filament_texture_get_target(void* texture);` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_texture_get_format` | `FFI_PLUGIN_EXPORT int32_t filament_texture_get_format(void* texture);` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_texture_is_format_supported` | `FFI_PLUGIN_EXPORT bool filament_texture_is_format_supported(void* e...` | Filament C motor durum veya yetenek doğrulamasını yapar. |
| `filament_texture_is_format_mipmappable` | `FFI_PLUGIN_EXPORT bool filament_texture_is_format_mipmappable(void*...` | Filament C motor durum veya yetenek doğrulamasını yapar. |
| `filament_texture_is_format_compressed` | `FFI_PLUGIN_EXPORT bool filament_texture_is_format_compressed(int32_...` | Filament C motor durum veya yetenek doğrulamasını yapar. |
| `filament_texture_compute_data_size` | `FFI_PLUGIN_EXPORT size_t filament_texture_compute_data_size(int32_t...` | Filament yerel `filament_texture_compute_data_size` C fonksiyonunu çalıştırır. |
| `filament_texture_get_max_size` | `FFI_PLUGIN_EXPORT uint32_t filament_texture_get_max_size(void* engi...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |
| `filament_texture_get_max_array_layers` | `FFI_PLUGIN_EXPORT uint32_t filament_texture_get_max_array_layers(vo...` | İlgili Filament durum veya sayaç bilgisini C katmanından sorgular. |

### `src/texture_sampler_c.h`

| C Fonksiyonu | İmzası | Açıklama ve Ne İşe Yaradığı |
| :--- | :--- | :--- |
| `filament_test_sampler_params_pack` | `FFI_PLUGIN_EXPORT uint32_t filament_test_sampler_params_pack( uint8...` | Filament yerel `filament_test_sampler_params_pack` C fonksiyonunu çalıştırır. |
| `filament_test_sampler_params_default` | `FFI_PLUGIN_EXPORT uint32_t filament_test_sampler_params_default(void);` | Filament yerel `filament_test_sampler_params_default` C fonksiyonunu çalıştırır. |

## Dart API

### `lib/src/image_ops.dart`

**Üst Düzey Fonksiyonlar (Top-level Functions):**

- **`LinearImage extractChannel(LinearImage src, int channelIndex)`**: Extracts a single channel at [channelIndex] from [src] as a 1-channel [LinearImage].
- **`LinearImage combineChannels(List<LinearImage> images)`**: Combines a list of single-channel [images] into a single multi-channel [LinearImage].
- **`void blitImage(LinearImage dst, LinearImage src, [int x = 0, int y = 0])`**: Copies the content of [src] into [dst] at destination offset ([x], [y]).
- **`LinearImage horizontalStack(List<LinearImage> images)`**: Concatenates [images] horizontally.
- **`LinearImage verticalStack(List<LinearImage> images)`**: Concatenates [images] vertically.
- **`LinearImage horizontalFlip(LinearImage src)`**: Horizontally mirrors [src].
- **`LinearImage verticalFlip(LinearImage src)`**: Vertically mirrors [src].
- **`LinearImage transpose(LinearImage src)`**: Transposes [src] by swapping rows and columns.
- **`LinearImage vectorsToColors(LinearImage src)`**: Maps vectors in [-1, +1] to color representation in [0, +1].
- **`LinearImage colorsToVectors(LinearImage src)`**: Maps color representation in [0, +1] to vector coordinates in [-1, +1].
- **`void clearToValue(LinearImage img, double value)`**: Sets all pixels in all channels to [value].

### `lib/src/image_sampler.dart`

**Üst Düzey Fonksiyonlar (Top-level Functions):**

- **`int getMipmapCount(LinearImage img)`**: Returns the number of mipmap levels required to downsample [img] to 1x1 (excluding base).

#### `enum ImageFilter`

Filter methods used for sampling / resampling images.

**Yapıcı Metotlar (Constructors):**
- `ImageFilter(this._cEnum)`: `ImageFilter(this._cEnum)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `minimum` | `minimum(c.FilImageFilter.FIL_IMAGE_FILTER_MINIMUM)` | `minimum` işlemini gerçekleştirir. |
| `value` | `int get value` | `value` özelliğinin anlık değerini okuyan getter erişimcisi. |

#### `enum ImageBoundary`

Boundary behavior when sampling outside image borders.

**Yapıcı Metotlar (Constructors):**
- `ImageBoundary(this._cEnum)`: `ImageBoundary(this._cEnum)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `neighbor` | `neighbor(c.FilImageBoundary.FIL_IMAGE_BOUNDARY_NEIGHBOR)` | `neighbor` işlemini gerçekleştirir. |
| `value` | `int get value` | `value` özelliğinin anlık değerini okuyan getter erişimcisi. |

### `lib/src/imageio.dart`

#### `enum ImageColorSpace`

`ImageColorSpace`: Sistemde kullanılan seçenekleri ve durumları listeleyen numaralandırma türüdür.

**Yapıcı Metotlar (Constructors):**
- `ImageColorSpace(this._cEnum)`: `ImageColorSpace(this._cEnum)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `srgb` | `srgb(c.FilImageDecoderColorSpace.FIL_IMAGE_DECODER_COLOR_SPACE_SRGB)` | `srgb` işlemini gerçekleştirir. |
| `value` | `int get value` | `value` özelliğinin anlık değerini okuyan getter erişimcisi. |

#### `enum ImageEncoderFormat`

`ImageEncoderFormat`: Sistemde kullanılan seçenekleri ve durumları listeleyen numaralandırma türüdür.

**Yapıcı Metotlar (Constructors):**
- `ImageEncoderFormat(this._cEnum)`: `ImageEncoderFormat(this._cEnum)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `rgb101111Rev` | `rgb101111Rev(c.FilImageEncoderFormat.FIL_IMAGE_ENCODER_FORMAT_RGB_10_11_...` | `rgb101111Rev` işlemini gerçekleştirir. |
| `value` | `int get value` | `value` özelliğinin anlık değerini okuyan getter erişimcisi. |

#### `class BasisEncoderBuilder`

Builder for compressing texture mipmaps into a Basis-Universal KTX2 container.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `mipCount` | `int mipCount` | `mipCount` alanını (field/property) ve ilişkili veriyi saklar. |
| `grayscale` | `bool grayscale` | `grayscale` alanını (field/property) ve ilişkili veriyi saklar. |
| `normals` | `bool normals` | `normals` alanını (field/property) ve ilişkili veriyi saklar. |
| `linear` | `bool linear` | `linear` alanını (field/property) ve ilişkili veriyi saklar. |
| `mipLevel` | `void mipLevel(int index, LinearImage img)` | `mipLevel` işlemini gerçekleştirir. |
| `useUastc` | `void useUastc(bool uastc)` | `useUastc` işlemini gerçekleştirir. |
| `buildAndEncode` | `Uint8List buildAndEncode()` | Builds the encoder, compresses the texture levels, and returns the output KTX2 bytes. |

### `lib/src/ktx1.dart`

#### `class Ktx1Bundle`

Structured representation of an in-memory KTX1 texture bundle.  Contains one or more mipmap levels, cubemap faces, or array slices, along with key-value metadata.

**Yapıcı Metotlar (Constructors):**
- `Ktx1Bundle(Uint8List bytes)`: Creates a [Ktx1Bundle] by parsing raw binary KTX1 [bytes].  Throws [ArgumentError] if the bytes are invalid, corrupted, or not in KTX1 format.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `numMipLevels` | `int get numMipLevels` | Number of mip levels stored in this bundle. |
| `arrayLength` | `int get arrayLength` | Array length of textures in this bundle. |
| `isCubemap` | `bool get isCubemap` | Whether this bundle represents a 6-faced cubemap. |
| `serializedLength` | `int get serializedLength` | Size in bytes when serialized to KTX1 format. |
| `isDestroyed` | `bool get isDestroyed` | Whether this bundle has been destroyed or consumed by [Ktx1Reader.createTexture]. |
| `getSphericalHarmonics` | `Float32List? getSphericalHarmonics()` | Returns 3 bands of spherical harmonics (9 RGB coefficients = 27 floats) parsed from `key="sh"` metadata.  Returns null if no valid SH metadata is found. |
| `getMetadata` | `String? getMetadata(String key)` | Retrieves metadata string for the given [key], or null if absent. |
| `setMetadata` | `void setMetadata(String key, String value)` | Sets metadata [key] to [value]. |
| `serialize` | `Uint8List serialize()` | Serializes the entire bundle into a KTX1 binary byte buffer. |
| `destroy` | `void destroy()` | Destroys this bundle manually. |

#### `class Ktx1Reader`

Utility to construct Filament textures from KTX1 bundles.

### `lib/src/ktx2_reader.dart`

#### `enum Ktx2TransferFunction`

Color space transfer function used when loading KTX2 textures.

**Yapıcı Metotlar (Constructors):**
- `Ktx2TransferFunction(this.value)`: `Ktx2TransferFunction(this.value)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `sRGB` | `sRGB(1)` | `sRGB` işlemini gerçekleştirir. |
| `value` | `int value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |

#### `enum Ktx2Result`

Result code from requesting a texture internal format in [Ktx2Reader].

**Yapıcı Metotlar (Constructors):**
- `Ktx2Result(this.value)`: `Ktx2Result(this.value)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `formatAlreadyRequested` | `formatAlreadyRequested(4)` | `formatAlreadyRequested` işlemini gerçekleştirir. |
| `value` | `int value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |
| `fromValue` | `static Ktx2Result fromValue(int v)` | `fromValue` işlemini gerçekleştirir. |

#### `class Ktx2AsyncLoad`

Handles an in-flight asynchronous KTX2 transcoding operation.  The underlying [FilamentTexture] is created immediately and can be assigned to materials, while transcoding of mipmap levels runs in the background (e.g. via an isolate). Once transcoding completes, call [uploadImages] on the engine thread to push mips to GPU.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `texture` | `FilamentTexture get texture` | The [FilamentTexture] being populated. |
| `doTranscoding` | `Ktx2Result doTranscoding()` | Synchronously transcodes all mipmaps on the current thread.  Safe to call from any thread/isolate. |
| `transcode` | `Future<Ktx2Result> transcode()` | Transcodes all mipmaps asynchronously in a background Dart [Isolate]. |
| `uploadImages` | `void uploadImages()` | Uploads pending transcoded mipmaps to the GPU.  MUST be called from the main / engine thread. |
| `destroy` | `void destroy()` | Destroys the async transcoding context.  Does NOT destroy the associated [texture]. |

#### `class Ktx2Reader`

Reads and transcodes KTX2 / Basis-Universal textures into native GPU texture formats.  Priority order recommendation: - Mobile: `[TextureFormat.rgbaAstc4x4, TextureFormat.etc2EacSrgba8, TextureFormat.srgb8A8, TextureFormat.rgba8]` - Desktop: `[TextureFormat.dxt5Srgba, TextureFormat.rgbaBptcUnorm, TextureFormat.srgb8A8, TextureFormat.rgba8]`

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `engine` | `FilamentEngine engine` | `engine` alanını (field/property) ve ilişkili veriyi saklar. |
| `requestFormat` | `Ktx2Result requestFormat(TextureFormat format)` | Requests that the reader constructs textures with the given [format].  Multiple formats can be requested; formats requested earlier have higher priority. |
| `requestFormats` | `void requestFormats(List<TextureFormat> formats)` | Requests a priority-ordered list of formats. |
| `unrequestFormat` | `void unrequestFormat(TextureFormat format)` | Removes [format] from the requested formats list. |
| `load` | `FilamentTexture? load(Uint8List data, Ktx2TransferFunction transfer)` | Transcodes and constructs a [FilamentTexture] synchronously from binary KTX2 [data].  Returns null if none of the requested formats could be transcoded or if data is invalid. |
| `loadAsync` | `Ktx2AsyncLoad? loadAsync(Uint8List data, Ktx2TransferFunction transfer)` | Creates an asynchronous transcoding operation for non-blocking texture streaming.  The returned [Ktx2AsyncLoad] provides a valid [FilamentTexture] immediately, allowing background transcoding and mipmap uploading. |
| `destroy` | `void destroy()` | Destroys the native reader instance. |

### `lib/src/linear_image.dart`

#### `class LinearImage`

A high-performance floating-point image holding packed 32-bit float channels arranged into a row-major grid.  The underlying pixel buffer has shared ownership semantics. Dart gets a zero-copy [Float32List] view over the underlying pixel buffer.

**Yapıcı Metotlar (Constructors):**
- `LinearImage(this.width, this.height, this.channels)`: Allocates a zeroed-out image with dimensions [width] x [height] and [channels] components.
- `LinearImage.fromData(this.width, this.height, this.channels, Float32List data)`: Creates a [LinearImage] initialized with copies of [data].
- `LinearImage._fromHandle(ffi.Pointer<c.FilLinearImage> handle)`: `LinearImage._fromHandle(ffi.Pointer<c.FilLinearImage> handle)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `width` | `int width` | `width` alanını (field/property) ve ilişkili veriyi saklar. |
| `height` | `int height` | `height` alanını (field/property) ve ilişkili veriyi saklar. |
| `channels` | `int channels` | `channels` alanını (field/property) ve ilişkili veriyi saklar. |
| `fromNativeHandle` | `static LinearImage? fromNativeHandle(ffi.Pointer<c.FilLinearImage> handle)` | Wraps a native handle or returns `null` if the pointer is null. |
| `isValid` | `bool get isValid` | Whether the underlying native image holds valid pixel storage. Returns false once the image is destroyed. |
| `isDisposed` | `bool get isDisposed` | Whether this image has been disposed or destroyed. |
| `data` | `Float32List get data` | A zero-copy [Float32List] view over the underlying pixel buffer. |
| `getPixel` | `double getPixel(int x, int y, int channel)` | Convenience getter for reading a single channel component of pixel at (x, y). |
| `setPixel` | `void setPixel(int x, int y, int channel, double value)` | Convenience setter for modifying a single channel component of pixel at (x, y). |
| `share` | `LinearImage share()` | Creates a shallow copy of this image sharing the same underlying pixel block. |
| `destroy` | `void destroy()` | Explicitly destroys this image handle. |

### `lib/src/texture.dart`

#### `enum TextureFormat`

Texture internal format matching backend::TextureFormat.

**Yapıcı Metotlar (Constructors):**
- `TextureFormat(this.value)`: `TextureFormat(this.value)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `srgbAlphaBptcUnorm` | `srgbAlphaBptcUnorm(108)` | `srgbAlphaBptcUnorm` işlemini gerçekleştirir. |
| `value` | `int value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |

#### `enum TextureSamplerType`

Target type of texture sampler matching backend::SamplerType.

**Yapıcı Metotlar (Constructors):**
- `TextureSamplerType(this.value)`: `TextureSamplerType(this.value)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `samplerCubemapArray` | `samplerCubemapArray(5)` | `samplerCubemapArray` işlemini gerçekleştirir. |
| `value` | `int value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |

#### `enum TextureSwizzle`

Swizzle options for texture channels matching backend::TextureSwizzle.

**Yapıcı Metotlar (Constructors):**
- `TextureSwizzle(this.value)`: `TextureSwizzle(this.value)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `channel3` | `channel3(5)` | `channel3` işlemini gerçekleştirir. |
| `value` | `int value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |

#### `enum PixelFormat`

Pixel format of image buffer matching backend::PixelDataFormat.

**Yapıcı Metotlar (Constructors):**
- `PixelFormat(this.value)`: `PixelFormat(this.value)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `alpha` | `alpha(11)` | `alpha` işlemini gerçekleştirir. |
| `value` | `int value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |

#### `enum PixelType`

Pixel data type of image buffer matching backend::PixelDataType.

**Yapıcı Metotlar (Constructors):**
- `PixelType(this.value)`: `PixelType(this.value)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `uint2101010Rev` | `uint2101010Rev(11)` | `uint2101010Rev` işlemini gerçekleştirir. |
| `value` | `int value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |

#### `enum CubemapFace`

Cubemap face target matching backend::TextureCubemapFace.

**Yapıcı Metotlar (Constructors):**
- `CubemapFace(this.value)`: `CubemapFace(this.value)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `negativeZ` | `negativeZ(5)` | `negativeZ` işlemini gerçekleştirir. |
| `value` | `int value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |

#### `class PixelBuffer`

Encapsulates pixel buffer data and its layout for uploading to textures.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `data` | `NativeBuffer data` | `data` alanını (field/property) ve ilişkili veriyi saklar. |
| `format` | `PixelFormat format` | `format` alanını (field/property) ve ilişkili veriyi saklar. |
| `type` | `PixelType type` | `type` alanını (field/property) ve ilişkili veriyi saklar. |
| `strideInPixels` | `int strideInPixels` | `strideInPixels` alanını (field/property) ve ilişkili veriyi saklar. |
| `alignment` | `int alignment` | `alignment` alanını (field/property) ve ilişkili veriyi saklar. |
| `autoFree` | `bool autoFree` | `autoFree` alanını (field/property) ve ilişkili veriyi saklar. |

#### `class TextureDescriptor`

Parameters for creating a texture.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `width` | `int width` | `width` alanını (field/property) ve ilişkili veriyi saklar. |
| `height` | `int height` | `height` alanını (field/property) ve ilişkili veriyi saklar. |
| `depth` | `int depth` | `depth` alanını (field/property) ve ilişkili veriyi saklar. |
| `levels` | `int levels` | `levels` alanını (field/property) ve ilişkili veriyi saklar. |
| `samplerType` | `TextureSamplerType samplerType` | `samplerType` alanını (field/property) ve ilişkili veriyi saklar. |
| `format` | `TextureFormat format` | `format` alanını (field/property) ve ilişkili veriyi saklar. |
| `usage` | `int usage` | `usage` alanını (field/property) ve ilişkili veriyi saklar. |
| `samples` | `int samples` | `samples` alanını (field/property) ve ilişkili veriyi saklar. |
| `swizzle` | `List<TextureSwizzle>? swizzle` | `swizzle` alanını (field/property) ve ilişkili veriyi saklar. |
| `importHandle` | `int importHandle` | `importHandle` alanını (field/property) ve ilişkili veriyi saklar. |

#### `class FilamentTexture`

A 2D, 3D, cubemap, or array texture.

**Yapıcı Metotlar (Constructors):**
- `FilamentTexture.internal(this._ptr, this._engine)`: Internal constructor.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `generateMipmaps` | `void generateMipmaps(FilamentEngine engine)` | Generates the mipmap chain for this texture using the GPU. |
| `levels` | `int get levels` | Total number of mip levels. |
| `target` | `TextureSamplerType get target` | Target sampler type of this texture. |
| `format` | `TextureFormat get format` | Internal format of this texture. |
| `isFormatSupported` | `static bool isFormatSupported(FilamentEngine engine, TextureFormat format)` | Checks whether [format] is supported by [engine]. |
| `isFormatMipmappable` | `static bool isFormatMipmappable(FilamentEngine engine, TextureFormat for...` | Checks whether [format] can generate mipmaps on [engine]. |
| `isFormatCompressed` | `static bool isFormatCompressed(TextureFormat format)` | Checks whether [format] is a compressed format. |
| `maxSize` | `static int maxSize(FilamentEngine engine, TextureSamplerType samplerType)` | Returns the maximum texture dimension in texels for [samplerType]. |
| `maxArrayLayers` | `static int maxArrayLayers(FilamentEngine engine)` | Returns the maximum number of array layers supported on [engine]. |
| `dispose` | `void dispose()` | Destroys this Texture. |
| `isDisposed` | `bool get isDisposed` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |

### `lib/src/texture_provider.dart`

#### `enum TextureProviderFlags`

Flags for texture decoding. Matches filament::gltfio::TextureProvider::TextureFlags.

**Yapıcı Metotlar (Constructors):**
- `TextureProviderFlags(this.value)`: `TextureProviderFlags(this.value)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `srgb` | `srgb(1 << 0)` | `srgb` işlemini gerçekleştirir. |
| `value` | `int value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |

#### `class TextureProvider`

A provider that decodes image data into Filament textures.

**Yapıcı Metotlar (Constructors):**
- `TextureProvider._(this._ptr, this._engine)`: `TextureProvider._(this._ptr, this._engine)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `isWebpSupported` | `static bool isWebpSupported()` | Returns true if the Filament library was built with WebP support. |
| `popTexture` | `FilamentTexture? popTexture()` | Retrieves the next decoded texture from the queue. |
| `updateQueue` | `void updateQueue()` | Pumps the decoding queue. Must be called repeatedly (usually once per frame). |
| `waitForCompletion` | `void waitForCompletion()` | Blocks until all queued textures have finished decoding. |
| `cancelDecoding` | `void cancelDecoding()` | Cancels any pending decode tasks. |
| `pushedCount` | `int get pushedCount` | Gets the number of textures pushed to the queue. |
| `poppedCount` | `int get poppedCount` | Gets the number of textures popped from the queue. |
| `decodedCount` | `int get decodedCount` | Gets the number of textures successfully decoded. |
| `pushMessage` | `String? get pushMessage` | Gets the last push message (diagnostic). |
| `popMessage` | `String? get popMessage` | Gets the last pop message (diagnostic). |
| `destroy` | `void destroy()` | Cancels remaining work, drains the queue, and destroys the provider. |
| `dispose` | `void dispose() => destroy()` | Yerel FFI göstericilerini, dinleyicileri ve bellek bloklarını serbest bırakır. |
| `isDisposed` | `bool get isDisposed` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |

### `lib/src/texture_sampler.dart`

#### `enum SamplerMinFilter`

Sampler minification filter matching backend::SamplerMinFilter.

**Yapıcı Metotlar (Constructors):**
- `SamplerMinFilter(this.value)`: `SamplerMinFilter(this.value)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `linearMipmapLinear` | `linearMipmapLinear(5)` | `linearMipmapLinear` işlemini gerçekleştirir. |
| `value` | `int value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |

#### `enum SamplerMagFilter`

Sampler magnification filter matching backend::SamplerMagFilter.

**Yapıcı Metotlar (Constructors):**
- `SamplerMagFilter(this.value)`: `SamplerMagFilter(this.value)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `linear` | `linear(1)` | `linear` işlemini gerçekleştirir. |
| `value` | `int value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |

#### `enum SamplerWrapMode`

Sampler wrap mode matching backend::SamplerWrapMode.

**Yapıcı Metotlar (Constructors):**
- `SamplerWrapMode(this.value)`: `SamplerWrapMode(this.value)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `mirroredRepeat` | `mirroredRepeat(2)` | `mirroredRepeat` işlemini gerçekleştirir. |
| `value` | `int value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |

#### `enum SamplerCompareMode`

Sampler compare mode matching backend::SamplerCompareMode.

**Yapıcı Metotlar (Constructors):**
- `SamplerCompareMode(this.value)`: `SamplerCompareMode(this.value)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `compareToTexture` | `compareToTexture(1)` | `compareToTexture` işlemini gerçekleştirir. |
| `value` | `int value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |

#### `enum SamplerCompareFunc`

Sampler compare function matching backend::SamplerCompareFunc.

**Yapıcı Metotlar (Constructors):**
- `SamplerCompareFunc(this.value)`: `SamplerCompareFunc(this.value)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `n` | `n(7)` | `n` işlemini gerçekleştirir. |
| `value` | `int value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |

#### `class TextureSampler`

Defines how a texture is accessed, filtered, wrapped, and compared.  An immutable, pure-Dart value type that packs directly to Filament's 32-bit `SamplerParams`.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `filterMin` | `SamplerMinFilter filterMin` | `filterMin` alanını (field/property) ve ilişkili veriyi saklar. |
| `filterMag` | `SamplerMagFilter filterMag` | `filterMag` alanını (field/property) ve ilişkili veriyi saklar. |
| `wrapS` | `SamplerWrapMode wrapS` | `wrapS` alanını (field/property) ve ilişkili veriyi saklar. |
| `wrapT` | `SamplerWrapMode wrapT` | `wrapT` alanını (field/property) ve ilişkili veriyi saklar. |
| `wrapR` | `SamplerWrapMode wrapR` | `wrapR` alanını (field/property) ve ilişkili veriyi saklar. |
| `anisotropy` | `double anisotropy` | `anisotropy` alanını (field/property) ve ilişkili veriyi saklar. |
| `compareMode` | `SamplerCompareMode compareMode` | `compareMode` alanını (field/property) ve ilişkili veriyi saklar. |
| `compareFunc` | `SamplerCompareFunc compareFunc` | `compareFunc` alanını (field/property) ve ilişkili veriyi saklar. |
| `anisotropyLog2` | `int get anisotropyLog2` | The log2 quantized anisotropy value in the range [0, 7]. |
| `packed` | `int get packed` | The packed 32-bit `SamplerParams` representation matching Filament's memory layout. |
| `hashCode` | `int get hashCode` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `toString` | `String toString()` | `toString` işlemini gerçekleştirir. |

### `lib/src/transcoder.dart`

#### `enum ComponentType`

Component type for vertex attribute input transcoding.

**Yapıcı Metotlar (Constructors):**
- `ComponentType(this.value)`: `ComponentType(this.value)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `float` | `float(5)` | `float` işlemini gerçekleştirir. |
| `value` | `int value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |

#### `class TranscoderConfig`

Configuration describing the input format for [Transcoder].

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `componentType` | `ComponentType componentType` | The input element component type (BYTE, UBYTE, SHORT, USHORT, HALF, FLOAT). |
| `normalized` | `bool normalized` | Whether integer input components should be mapped to the normalized [0, 1] or [-1, +1] range. |
| `componentCount` | `int componentCount` | The number of components per vertex (e.g. 1 for float, 2 for float2/uv, 3 for float3/normal, 4 for float4/color). |
| `inputStrideBytes` | `int inputStrideBytes` | Input stride in bytes. If 0, the transcoder assumes tightly packed data. |

#### `class Transcoder`

Converts arbitrary packed/normalized vertex attribute data into tightly packed 32-bit floating point values.  This is especially useful for 3-component formats (e.g. `short3`, `half3`) which are not supported on backends with strict minspecs (like Vulkan), allowing CPU expansion to `float3`.

**Yapıcı Metotlar (Constructors):**
- `Transcoder(this.config)`: `Transcoder(this.config)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `config` | `TranscoderConfig config` | `config` alanını (field/property) ve ilişkili veriyi saklar. |
| `run` | `Float32List run(TypedData source, int vertexCount)` | Transcodes [source] attribute data of [vertexCount] items into tightly packed [Float32List].  [source] can be any [TypedData] (such as [Int8List], [Uint8List], [Int16List], [Uint16List], [Float32List]). |

### `lib/src/image_sdf.dart`

**Üst düzey fonksiyonlar ve değişkenler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `computeCoordField` | `LinearImage computeCoordField(LinearImage src, {double threshold = 0.5, int channel = 0,})` | Generates a 2-channel field of unnormalized coordinates pointing to the nearest pixel where [src] component at [channel] > [threshold]. |
| `edtFromCoordField` | `LinearImage edtFromCoordField(LinearImage coordField, {bool sqrt = true,})` | Generates a 1-channel Euclidean distance field from [coordField]. |
| `voronoiFromCoordField` | `LinearImage voronoiFromCoordField(LinearImage coordField, LinearImage src,)` | Dereferences the given coordinate field to propagate nearest feature pixel colors from [src]. |
| `signedDistanceField` | `LinearImage signedDistanceField(LinearImage mask, {double threshold = 0.5, int channel = 0,})` | Generates a signed distance field (SDF) from a binary/coverage [mask]. |
| `dilateUvIslands` | `LinearImage dilateUvIslands(LinearImage baked, LinearImage coverageMask, {double threshold = 0.5, int channel...` | Dilates UV island boundaries into gutters using Voronoi nearest neighbor coloring. |

---

[Önceki: Materyaller](materials.md) | [Üst: flutter_filament](index.md) | [Sonraki: glTF yükleme ve animasyon](gltfio.md)
