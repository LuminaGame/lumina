[Türkçe](../../tr/flutter_filament/textures-and-images.md)

# Textures and images

GPU textures and samplers, the texture provider used by glTF loading, linear images and image operations, image encoding and decoding, KTX1 bundles, the KTX2 reader and the Basis Universal transcoder. File paths are relative to the `flutter_filament/` package directory.

**On this page:**

- [Native C bridge](#native-c-bridge)
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

## Native C bridge

The C functions below are declared in the package's `src/` headers and called from Dart through FFI.

### `src/image_ops_c.h`

| C Function | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `filament_image_extract_channel` | `FFI_PLUGIN_EXPORT FilLinearImage* filament_image_extract_channel(co...` | Executes native Filament `filament_image_extract_channel` C binding. |
| `filament_image_combine_channels` | `FFI_PLUGIN_EXPORT FilLinearImage* filament_image_combine_channels(c...` | Executes native Filament `filament_image_combine_channels` C binding. |
| `filament_image_crop_region` | `FFI_PLUGIN_EXPORT FilLinearImage* filament_image_crop_region(const ...` | Executes native Filament `filament_image_crop_region` C binding. |
| `filament_image_blit` | `FFI_PLUGIN_EXPORT void filament_image_blit(FilLinearImage* dst, con...` | Executes native Filament `filament_image_blit` C binding. |
| `filament_image_horizontal_stack` | `FFI_PLUGIN_EXPORT FilLinearImage* filament_image_horizontal_stack(c...` | Executes native Filament `filament_image_horizontal_stack` C binding. |
| `filament_image_vertical_stack` | `FFI_PLUGIN_EXPORT FilLinearImage* filament_image_vertical_stack(con...` | Executes native Filament `filament_image_vertical_stack` C binding. |
| `filament_image_horizontal_flip` | `FFI_PLUGIN_EXPORT FilLinearImage* filament_image_horizontal_flip(co...` | Executes native Filament `filament_image_horizontal_flip` C binding. |
| `filament_image_vertical_flip` | `FFI_PLUGIN_EXPORT FilLinearImage* filament_image_vertical_flip(cons...` | Executes native Filament `filament_image_vertical_flip` C binding. |
| `filament_image_transpose` | `FFI_PLUGIN_EXPORT FilLinearImage* filament_image_transpose(const Fi...` | Executes native Filament `filament_image_transpose` C binding. |
| `filament_image_vectors_to_colors` | `FFI_PLUGIN_EXPORT FilLinearImage* filament_image_vectors_to_colors(...` | Executes native Filament `filament_image_vectors_to_colors` C binding. |
| `filament_image_colors_to_vectors` | `FFI_PLUGIN_EXPORT FilLinearImage* filament_image_colors_to_vectors(...` | Executes native Filament `filament_image_colors_to_vectors` C binding. |
| `filament_image_compare` | `FFI_PLUGIN_EXPORT int filament_image_compare(const FilLinearImage* ...` | Executes native Filament `filament_image_compare` C binding. |
| `filament_image_clear_to_value` | `FFI_PLUGIN_EXPORT void filament_image_clear_to_value(FilLinearImage...` | Executes native Filament `filament_image_clear_to_value` C binding. |

### `src/image_sampler_c.h`

| C Function | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `filament_image_resample` | `FFI_PLUGIN_EXPORT FilLinearImage* filament_image_resample( const Fi...` | Executes native Filament `filament_image_resample` C binding. |
| `filament_image_resample_region` | `FFI_PLUGIN_EXPORT FilLinearImage* filament_image_resample_region( c...` | Executes native Filament `filament_image_resample_region` C binding. |
| `filament_image_get_mipmap_count` | `FFI_PLUGIN_EXPORT uint32_t filament_image_get_mipmap_count(const Fi...` | Queries the `filament_image_get_mipmap_count` state, property, or counter from the native C layer. |
| `filament_image_generate_mipmaps` | `FFI_PLUGIN_EXPORT void filament_image_generate_mipmaps( const FilLi...` | Executes native Filament `filament_image_generate_mipmaps` C binding. |

### `src/image_sdf_c.h`

| C Function | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `filament_image_compute_coord_field` | `FFI_PLUGIN_EXPORT FilLinearImage* filament_image_compute_coord_fiel...` | Executes native Filament `filament_image_compute_coord_field` C binding. |
| `filament_image_edt_from_coord_field` | `FFI_PLUGIN_EXPORT FilLinearImage* filament_image_edt_from_coord_fie...` | Executes native Filament `filament_image_edt_from_coord_field` C binding. |
| `filament_image_voronoi_from_coord_field` | `FFI_PLUGIN_EXPORT FilLinearImage* filament_image_voronoi_from_coord...` | Executes native Filament `filament_image_voronoi_from_coord_field` C binding. |

### `src/imageio_c.h`

| C Function | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `filament_image_decode` | `FFI_PLUGIN_EXPORT FilLinearImage* filament_image_decode( const uint...` | Executes native Filament `filament_image_decode` C binding. |
| `filament_image_encode` | `FFI_PLUGIN_EXPORT bool filament_image_encode( int format, const Fil...` | Executes native Filament `filament_image_encode` C binding. |
| `filament_image_encode_free` | `FFI_PLUGIN_EXPORT void filament_image_encode_free(uint8_t* data);` | Executes native Filament `filament_image_encode_free` C binding. |
| `filament_basis_encoder_builder_create` | `FFI_PLUGIN_EXPORT FilBasisEncoderBuilder* filament_basis_encoder_bu...` | Allocates and initializes the native Filament `filament_basis_encoder_builder_create` resource on the engine/GPU. |
| `filament_basis_encoder_builder_miplevel` | `FFI_PLUGIN_EXPORT void filament_basis_encoder_builder_miplevel( Fil...` | Validates or queries the `filament_basis_encoder_builder_miplevel` state/capability. |
| `filament_basis_encoder_builder_intermediate_format` | `FFI_PLUGIN_EXPORT void filament_basis_encoder_builder_intermediate_...` | Validates or queries the `filament_basis_encoder_builder_intermediate_format` state/capability. |
| `filament_basis_encoder_builder_build` | `FFI_PLUGIN_EXPORT FilBasisEncoder* filament_basis_encoder_builder_b...` | Validates or queries the `filament_basis_encoder_builder_build` state/capability. |
| `filament_basis_encoder_builder_destroy` | `FFI_PLUGIN_EXPORT void filament_basis_encoder_builder_destroy( FilB...` | Destroys the native Filament `filament_basis_encoder_builder_destroy` resource and releases GPU/host memory. |
| `filament_basis_encoder_encode` | `FFI_PLUGIN_EXPORT bool filament_basis_encoder_encode(FilBasisEncode...` | Validates or queries the `filament_basis_encoder_encode` state/capability. |
| `filament_basis_encoder_get_ktx2_byte_count` | `FFI_PLUGIN_EXPORT size_t filament_basis_encoder_get_ktx2_byte_count...` | Queries the `filament_basis_encoder_get_ktx2_byte_count` state, property, or counter from the native C layer. |
| `filament_basis_encoder_get_ktx2_data` | `FFI_PLUGIN_EXPORT const uint8_t* filament_basis_encoder_get_ktx2_da...` | Queries the `filament_basis_encoder_get_ktx2_data` state, property, or counter from the native C layer. |
| `filament_basis_encoder_destroy` | `FFI_PLUGIN_EXPORT void filament_basis_encoder_destroy(FilBasisEncod...` | Destroys the native Filament `filament_basis_encoder_destroy` resource and releases GPU/host memory. |

### `src/ktx1_c.h`

| C Function | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `filament_ktx1_bundle_create` | `FFI_PLUGIN_EXPORT FilKtx1Bundle* filament_ktx1_bundle_create(const ...` | Allocates and initializes the native Filament `filament_ktx1_bundle_create` resource on the engine/GPU. |
| `filament_ktx1_bundle_create_empty` | `FFI_PLUGIN_EXPORT FilKtx1Bundle* filament_ktx1_bundle_create_empty(...` | Allocates and initializes the native Filament `filament_ktx1_bundle_create_empty` resource on the engine/GPU. |
| `filament_ktx1_bundle_destroy` | `FFI_PLUGIN_EXPORT void filament_ktx1_bundle_destroy(FilKtx1Bundle* b);` | Destroys the native Filament `filament_ktx1_bundle_destroy` resource and releases GPU/host memory. |
| `filament_ktx1_bundle_get_num_mip_levels` | `FFI_PLUGIN_EXPORT uint32_t filament_ktx1_bundle_get_num_mip_levels(...` | Queries the `filament_ktx1_bundle_get_num_mip_levels` state, property, or counter from the native C layer. |
| `filament_ktx1_bundle_get_array_length` | `FFI_PLUGIN_EXPORT uint32_t filament_ktx1_bundle_get_array_length(co...` | Queries the `filament_ktx1_bundle_get_array_length` state, property, or counter from the native C layer. |
| `filament_ktx1_bundle_is_cubemap` | `FFI_PLUGIN_EXPORT bool filament_ktx1_bundle_is_cubemap(const FilKtx...` | Validates or queries the `filament_ktx1_bundle_is_cubemap` state/capability. |
| `filament_ktx1_bundle_get_spherical_harmonics` | `FFI_PLUGIN_EXPORT bool filament_ktx1_bundle_get_spherical_harmonics...` | Queries the `filament_ktx1_bundle_get_spherical_harmonics` state, property, or counter from the native C layer. |
| `filament_ktx1_bundle_get_metadata` | `FFI_PLUGIN_EXPORT const char* filament_ktx1_bundle_get_metadata(con...` | Queries the `filament_ktx1_bundle_get_metadata` state, property, or counter from the native C layer. |
| `filament_ktx1_bundle_set_metadata` | `FFI_PLUGIN_EXPORT void filament_ktx1_bundle_set_metadata(FilKtx1Bun...` | Updates the `filament_ktx1_bundle_set_metadata` parameter or state in the native C layer. |
| `filament_ktx1_bundle_get_blob` | `FFI_PLUGIN_EXPORT bool filament_ktx1_bundle_get_blob(const FilKtx1B...` | Queries the `filament_ktx1_bundle_get_blob` state, property, or counter from the native C layer. |
| `filament_ktx1_bundle_set_blob` | `FFI_PLUGIN_EXPORT bool filament_ktx1_bundle_set_blob(FilKtx1Bundle*...` | Updates the `filament_ktx1_bundle_set_blob` parameter or state in the native C layer. |
| `filament_ktx1_bundle_get_serialized_length` | `FFI_PLUGIN_EXPORT uint32_t filament_ktx1_bundle_get_serialized_leng...` | Queries the `filament_ktx1_bundle_get_serialized_length` state, property, or counter from the native C layer. |
| `filament_ktx1_bundle_serialize` | `FFI_PLUGIN_EXPORT bool filament_ktx1_bundle_serialize(const FilKtx1...` | Executes native Filament `filament_ktx1_bundle_serialize` C binding. |
| `filament_ktx1_reader_create_texture` | `FFI_PLUGIN_EXPORT void* filament_ktx1_reader_create_texture(void* e...` | Allocates and initializes the native Filament `filament_ktx1_reader_create_texture` resource on the engine/GPU. |

### `src/ktx2_reader_c.h`

| C Function | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `filament_ktx2_reader_create` | `FFI_PLUGIN_EXPORT FilKtx2Reader* filament_ktx2_reader_create(void* ...` | Allocates and initializes the native Filament `filament_ktx2_reader_create` resource on the engine/GPU. |
| `filament_ktx2_reader_destroy` | `FFI_PLUGIN_EXPORT void filament_ktx2_reader_destroy(FilKtx2Reader* r);` | Destroys the native Filament `filament_ktx2_reader_destroy` resource and releases GPU/host memory. |
| `filament_ktx2_reader_request_format` | `FFI_PLUGIN_EXPORT int filament_ktx2_reader_request_format(FilKtx2Re...` | Executes native Filament `filament_ktx2_reader_request_format` C binding. |
| `filament_ktx2_reader_unrequest_format` | `FFI_PLUGIN_EXPORT void filament_ktx2_reader_unrequest_format(FilKtx...` | Executes native Filament `filament_ktx2_reader_unrequest_format` C binding. |
| `filament_ktx2_reader_load` | `FFI_PLUGIN_EXPORT void* filament_ktx2_reader_load(FilKtx2Reader* r,...` | Executes native Filament `filament_ktx2_reader_load` C binding. |
| `filament_ktx2_reader_async_create` | `FFI_PLUGIN_EXPORT FilKtx2Async* filament_ktx2_reader_async_create(F...` | Allocates and initializes the native Filament `filament_ktx2_reader_async_create` resource on the engine/GPU. |
| `filament_ktx2_async_get_texture` | `FFI_PLUGIN_EXPORT void* filament_ktx2_async_get_texture(const FilKt...` | Queries the `filament_ktx2_async_get_texture` state, property, or counter from the native C layer. |
| `filament_ktx2_async_do_transcoding` | `FFI_PLUGIN_EXPORT int filament_ktx2_async_do_transcoding(FilKtx2Asy...` | Executes native Filament `filament_ktx2_async_do_transcoding` C binding. |
| `filament_ktx2_async_upload_images` | `FFI_PLUGIN_EXPORT void filament_ktx2_async_upload_images(FilKtx2Asy...` | Executes native Filament `filament_ktx2_async_upload_images` C binding. |
| `filament_ktx2_reader_async_destroy` | `FFI_PLUGIN_EXPORT void filament_ktx2_reader_async_destroy(FilKtx2Re...` | Destroys the native Filament `filament_ktx2_reader_async_destroy` resource and releases GPU/host memory. |

### `src/linear_image_c.h`

| C Function | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `filament_linear_image_create` | `FFI_PLUGIN_EXPORT FilLinearImage* filament_linear_image_create(uint...` | Allocates and initializes the native Filament `filament_linear_image_create` resource on the engine/GPU. |
| `filament_linear_image_share` | `FFI_PLUGIN_EXPORT FilLinearImage* filament_linear_image_share(const...` | Executes native Filament `filament_linear_image_share` C binding. |
| `filament_linear_image_destroy` | `FFI_PLUGIN_EXPORT void filament_linear_image_destroy(FilLinearImage...` | Destroys the native Filament `filament_linear_image_destroy` resource and releases GPU/host memory. |
| `filament_linear_image_get_width` | `FFI_PLUGIN_EXPORT uint32_t filament_linear_image_get_width(const Fi...` | Queries the `filament_linear_image_get_width` state, property, or counter from the native C layer. |
| `filament_linear_image_get_height` | `FFI_PLUGIN_EXPORT uint32_t filament_linear_image_get_height(const F...` | Queries the `filament_linear_image_get_height` state, property, or counter from the native C layer. |
| `filament_linear_image_get_channels` | `FFI_PLUGIN_EXPORT uint32_t filament_linear_image_get_channels(const...` | Queries the `filament_linear_image_get_channels` state, property, or counter from the native C layer. |
| `filament_linear_image_get_pixel_data` | `FFI_PLUGIN_EXPORT float* filament_linear_image_get_pixel_data(FilLi...` | Queries the `filament_linear_image_get_pixel_data` state, property, or counter from the native C layer. |
| `filament_linear_image_is_valid` | `FFI_PLUGIN_EXPORT bool filament_linear_image_is_valid(const FilLine...` | Validates or queries the `filament_linear_image_is_valid` state/capability. |

### `src/texture_c.h`

| C Function | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `filament_texture_create` | `FFI_PLUGIN_EXPORT void* filament_texture_create(void* engine, const...` | Allocates and initializes the native Filament `filament_texture_create` resource on the engine/GPU. |
| `filament_texture_create_2d` | `FFI_PLUGIN_EXPORT void* filament_texture_create_2d(void* engine, ui...` | Allocates and initializes the native Filament `filament_texture_create_2d` resource on the engine/GPU. |
| `filament_texture_set_image` | `FFI_PLUGIN_EXPORT void filament_texture_set_image(void* engine, voi...` | Updates the `filament_texture_set_image` parameter or state in the native C layer. |
| `filament_texture_set_image_ex` | `FFI_PLUGIN_EXPORT void filament_texture_set_image_ex( void* engine,...` | Updates the `filament_texture_set_image_ex` parameter or state in the native C layer. |
| `filament_engine_destroy_texture` | `FFI_PLUGIN_EXPORT void filament_engine_destroy_texture(void* engine...` | Destroys the native Filament `filament_engine_destroy_texture` resource and releases GPU/host memory. |
| `filament_texture_generate_mipmaps` | `FFI_PLUGIN_EXPORT void filament_texture_generate_mipmaps(void* engi...` | Executes native Filament `filament_texture_generate_mipmaps` C binding. |
| `filament_texture_get_width` | `FFI_PLUGIN_EXPORT uint32_t filament_texture_get_width(void* texture...` | Queries the `filament_texture_get_width` state, property, or counter from the native C layer. |
| `filament_texture_get_height` | `FFI_PLUGIN_EXPORT uint32_t filament_texture_get_height(void* textur...` | Queries the `filament_texture_get_height` state, property, or counter from the native C layer. |
| `filament_texture_get_depth` | `FFI_PLUGIN_EXPORT uint32_t filament_texture_get_depth(void* texture...` | Queries the `filament_texture_get_depth` state, property, or counter from the native C layer. |
| `filament_texture_get_levels` | `FFI_PLUGIN_EXPORT uint8_t filament_texture_get_levels(void* texture);` | Queries the `filament_texture_get_levels` state, property, or counter from the native C layer. |
| `filament_texture_get_target` | `FFI_PLUGIN_EXPORT int32_t filament_texture_get_target(void* texture);` | Queries the `filament_texture_get_target` state, property, or counter from the native C layer. |
| `filament_texture_get_format` | `FFI_PLUGIN_EXPORT int32_t filament_texture_get_format(void* texture);` | Queries the `filament_texture_get_format` state, property, or counter from the native C layer. |
| `filament_texture_is_format_supported` | `FFI_PLUGIN_EXPORT bool filament_texture_is_format_supported(void* e...` | Validates or queries the `filament_texture_is_format_supported` state/capability. |
| `filament_texture_is_format_mipmappable` | `FFI_PLUGIN_EXPORT bool filament_texture_is_format_mipmappable(void*...` | Validates or queries the `filament_texture_is_format_mipmappable` state/capability. |
| `filament_texture_is_format_compressed` | `FFI_PLUGIN_EXPORT bool filament_texture_is_format_compressed(int32_...` | Validates or queries the `filament_texture_is_format_compressed` state/capability. |
| `filament_texture_compute_data_size` | `FFI_PLUGIN_EXPORT size_t filament_texture_compute_data_size(int32_t...` | Executes native Filament `filament_texture_compute_data_size` C binding. |
| `filament_texture_get_max_size` | `FFI_PLUGIN_EXPORT uint32_t filament_texture_get_max_size(void* engi...` | Queries the `filament_texture_get_max_size` state, property, or counter from the native C layer. |
| `filament_texture_get_max_array_layers` | `FFI_PLUGIN_EXPORT uint32_t filament_texture_get_max_array_layers(vo...` | Queries the `filament_texture_get_max_array_layers` state, property, or counter from the native C layer. |

### `src/texture_sampler_c.h`

| C Function | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `filament_test_sampler_params_pack` | `FFI_PLUGIN_EXPORT uint32_t filament_test_sampler_params_pack( uint8...` | Executes native Filament `filament_test_sampler_params_pack` C binding. |
| `filament_test_sampler_params_default` | `FFI_PLUGIN_EXPORT uint32_t filament_test_sampler_params_default(void);` | Executes native Filament `filament_test_sampler_params_default` C binding. |

## Dart API

### `lib/src/image_ops.dart`

**Top-level Functions:**

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

**Top-level Functions:**

- **`int getMipmapCount(LinearImage img)`**: Returns the number of mipmap levels required to downsample [img] to 1x1 (excluding base).

#### `enum ImageFilter`

Filter methods used for sampling / resampling images.

**Constructors:**
- `ImageFilter(this._cEnum)`: Initializes `ImageFilter(this._cEnum)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `minimum` | `minimum(c.FilImageFilter.FIL_IMAGE_FILTER_MINIMUM)` | Executes `minimum` operation. |
| `value` | `int get value` | Getter accessor returning the current value of `value`. |

#### `enum ImageBoundary`

Boundary behavior when sampling outside image borders.

**Constructors:**
- `ImageBoundary(this._cEnum)`: Initializes `ImageBoundary(this._cEnum)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `neighbor` | `neighbor(c.FilImageBoundary.FIL_IMAGE_BOUNDARY_NEIGHBOR)` | Executes `neighbor` operation. |
| `value` | `int get value` | Getter accessor returning the current value of `value`. |

### `lib/src/imageio.dart`

#### `enum ImageColorSpace`

`ImageColorSpace`: Enumeration listing system options and state constants.

**Constructors:**
- `ImageColorSpace(this._cEnum)`: Initializes `ImageColorSpace(this._cEnum)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `srgb` | `srgb(c.FilImageDecoderColorSpace.FIL_IMAGE_DECODER_COLOR_SPACE_SRGB)` | Executes `srgb` operation. |
| `value` | `int get value` | Getter accessor returning the current value of `value`. |

#### `enum ImageEncoderFormat`

`ImageEncoderFormat`: Enumeration listing system options and state constants.

**Constructors:**
- `ImageEncoderFormat(this._cEnum)`: Initializes `ImageEncoderFormat(this._cEnum)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `rgb101111Rev` | `rgb101111Rev(c.FilImageEncoderFormat.FIL_IMAGE_ENCODER_FORMAT_RGB_10_11_...` | Executes `rgb101111Rev` operation. |
| `value` | `int get value` | Getter accessor returning the current value of `value`. |

#### `class BasisEncoderBuilder`

Builder for compressing texture mipmaps into a Basis-Universal KTX2 container.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `mipCount` | `int mipCount` | Holds the `mipCount` property or configuration state. |
| `grayscale` | `bool grayscale` | Holds the `grayscale` property or configuration state. |
| `normals` | `bool normals` | Holds the `normals` property or configuration state. |
| `linear` | `bool linear` | Holds the `linear` property or configuration state. |
| `mipLevel` | `void mipLevel(int index, LinearImage img)` | Executes `mipLevel` operation. |
| `useUastc` | `void useUastc(bool uastc)` | Executes `useUastc` operation. |
| `buildAndEncode` | `Uint8List buildAndEncode()` | Builds the encoder, compresses the texture levels, and returns the output KTX2 bytes. |

### `lib/src/ktx1.dart`

#### `class Ktx1Bundle`

Structured representation of an in-memory KTX1 texture bundle.  Contains one or more mipmap levels, cubemap faces, or array slices, along with key-value metadata.

**Constructors:**
- `Ktx1Bundle(Uint8List bytes)`: Creates a [Ktx1Bundle] by parsing raw binary KTX1 [bytes].  Throws [ArgumentError] if the bytes are invalid, corrupted, or not in KTX1 format.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
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

**Constructors:**
- `Ktx2TransferFunction(this.value)`: Initializes `Ktx2TransferFunction(this.value)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `sRGB` | `sRGB(1)` | Executes `sRGB` operation. |
| `value` | `int value` | Holds the `value` property or configuration state. |

#### `enum Ktx2Result`

Result code from requesting a texture internal format in [Ktx2Reader].

**Constructors:**
- `Ktx2Result(this.value)`: Initializes `Ktx2Result(this.value)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `formatAlreadyRequested` | `formatAlreadyRequested(4)` | Executes `formatAlreadyRequested` operation. |
| `value` | `int value` | Holds the `value` property or configuration state. |
| `fromValue` | `static Ktx2Result fromValue(int v)` | Executes `fromValue` operation. |

#### `class Ktx2AsyncLoad`

Handles an in-flight asynchronous KTX2 transcoding operation.  The underlying [FilamentTexture] is created immediately and can be assigned to materials, while transcoding of mipmap levels runs in the background (e.g. via an isolate). Once transcoding completes, call [uploadImages] on the engine thread to push mips to GPU.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `texture` | `FilamentTexture get texture` | The [FilamentTexture] being populated. |
| `doTranscoding` | `Ktx2Result doTranscoding()` | Synchronously transcodes all mipmaps on the current thread.  Safe to call from any thread/isolate. |
| `transcode` | `Future<Ktx2Result> transcode()` | Transcodes all mipmaps asynchronously in a background Dart [Isolate]. |
| `uploadImages` | `void uploadImages()` | Uploads pending transcoded mipmaps to the GPU.  MUST be called from the main / engine thread. |
| `destroy` | `void destroy()` | Destroys the async transcoding context.  Does NOT destroy the associated [texture]. |

#### `class Ktx2Reader`

Reads and transcodes KTX2 / Basis-Universal textures into native GPU texture formats.  Priority order recommendation: - Mobile: `[TextureFormat.rgbaAstc4x4, TextureFormat.etc2EacSrgba8, TextureFormat.srgb8A8, TextureFormat.rgba8]` - Desktop: `[TextureFormat.dxt5Srgba, TextureFormat.rgbaBptcUnorm, TextureFormat.srgb8A8, TextureFormat.rgba8]`

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `engine` | `FilamentEngine engine` | Holds the `engine` property or configuration state. |
| `requestFormat` | `Ktx2Result requestFormat(TextureFormat format)` | Requests that the reader constructs textures with the given [format].  Multiple formats can be requested; formats requested earlier have higher priority. |
| `requestFormats` | `void requestFormats(List<TextureFormat> formats)` | Requests a priority-ordered list of formats. |
| `unrequestFormat` | `void unrequestFormat(TextureFormat format)` | Removes [format] from the requested formats list. |
| `load` | `FilamentTexture? load(Uint8List data, Ktx2TransferFunction transfer)` | Transcodes and constructs a [FilamentTexture] synchronously from binary KTX2 [data].  Returns null if none of the requested formats could be transcoded or if data is invalid. |
| `loadAsync` | `Ktx2AsyncLoad? loadAsync(Uint8List data, Ktx2TransferFunction transfer)` | Creates an asynchronous transcoding operation for non-blocking texture streaming.  The returned [Ktx2AsyncLoad] provides a valid [FilamentTexture] immediately, allowing background transcoding and mipmap uploading. |
| `destroy` | `void destroy()` | Destroys the native reader instance. |

### `lib/src/linear_image.dart`

#### `class LinearImage`

A high-performance floating-point image holding packed 32-bit float channels arranged into a row-major grid.  The underlying pixel buffer has shared ownership semantics. Dart gets a zero-copy [Float32List] view over the underlying pixel buffer.

**Constructors:**
- `LinearImage(this.width, this.height, this.channels)`: Allocates a zeroed-out image with dimensions [width] x [height] and [channels] components.
- `LinearImage.fromData(this.width, this.height, this.channels, Float32List data)`: Creates a [LinearImage] initialized with copies of [data].
- `LinearImage._fromHandle(ffi.Pointer<c.FilLinearImage> handle)`: Initializes `LinearImage._fromHandle(ffi.Pointer<c.FilLinearImage> handle)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `width` | `int width` | Holds the `width` property or configuration state. |
| `height` | `int height` | Holds the `height` property or configuration state. |
| `channels` | `int channels` | Holds the `channels` property or configuration state. |
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

**Constructors:**
- `TextureFormat(this.value)`: Initializes `TextureFormat(this.value)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `srgbAlphaBptcUnorm` | `srgbAlphaBptcUnorm(108)` | Executes `srgbAlphaBptcUnorm` operation. |
| `value` | `int value` | Holds the `value` property or configuration state. |

#### `enum TextureSamplerType`

Target type of texture sampler matching backend::SamplerType.

**Constructors:**
- `TextureSamplerType(this.value)`: Initializes `TextureSamplerType(this.value)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `samplerCubemapArray` | `samplerCubemapArray(5)` | Executes `samplerCubemapArray` operation. |
| `value` | `int value` | Holds the `value` property or configuration state. |

#### `enum TextureSwizzle`

Swizzle options for texture channels matching backend::TextureSwizzle.

**Constructors:**
- `TextureSwizzle(this.value)`: Initializes `TextureSwizzle(this.value)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `channel3` | `channel3(5)` | Executes `channel3` operation. |
| `value` | `int value` | Holds the `value` property or configuration state. |

#### `enum PixelFormat`

Pixel format of image buffer matching backend::PixelDataFormat.

**Constructors:**
- `PixelFormat(this.value)`: Initializes `PixelFormat(this.value)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `alpha` | `alpha(11)` | Executes `alpha` operation. |
| `value` | `int value` | Holds the `value` property or configuration state. |

#### `enum PixelType`

Pixel data type of image buffer matching backend::PixelDataType.

**Constructors:**
- `PixelType(this.value)`: Initializes `PixelType(this.value)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `uint2101010Rev` | `uint2101010Rev(11)` | Executes `uint2101010Rev` operation. |
| `value` | `int value` | Holds the `value` property or configuration state. |

#### `enum CubemapFace`

Cubemap face target matching backend::TextureCubemapFace.

**Constructors:**
- `CubemapFace(this.value)`: Initializes `CubemapFace(this.value)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `negativeZ` | `negativeZ(5)` | Executes `negativeZ` operation. |
| `value` | `int value` | Holds the `value` property or configuration state. |

#### `class PixelBuffer`

Encapsulates pixel buffer data and its layout for uploading to textures.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `data` | `NativeBuffer data` | Holds the `data` property or configuration state. |
| `format` | `PixelFormat format` | Holds the `format` property or configuration state. |
| `type` | `PixelType type` | Holds the `type` property or configuration state. |
| `strideInPixels` | `int strideInPixels` | Holds the `strideInPixels` property or configuration state. |
| `alignment` | `int alignment` | Holds the `alignment` property or configuration state. |
| `autoFree` | `bool autoFree` | Holds the `autoFree` property or configuration state. |

#### `class TextureDescriptor`

Parameters for creating a texture.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `width` | `int width` | Holds the `width` property or configuration state. |
| `height` | `int height` | Holds the `height` property or configuration state. |
| `depth` | `int depth` | Holds the `depth` property or configuration state. |
| `levels` | `int levels` | Holds the `levels` property or configuration state. |
| `samplerType` | `TextureSamplerType samplerType` | Holds the `samplerType` property or configuration state. |
| `format` | `TextureFormat format` | Holds the `format` property or configuration state. |
| `usage` | `int usage` | Holds the `usage` property or configuration state. |
| `samples` | `int samples` | Holds the `samples` property or configuration state. |
| `swizzle` | `List<TextureSwizzle>? swizzle` | Holds the `swizzle` property or configuration state. |
| `importHandle` | `int importHandle` | Holds the `importHandle` property or configuration state. |

#### `class FilamentTexture`

A 2D, 3D, cubemap, or array texture.

**Constructors:**
- `FilamentTexture.internal(this._ptr, this._engine)`: Internal constructor.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
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
| `isDisposed` | `bool get isDisposed` | Checks current state or capability and returns a boolean value. |

### `lib/src/texture_provider.dart`

#### `enum TextureProviderFlags`

Flags for texture decoding. Matches filament::gltfio::TextureProvider::TextureFlags.

**Constructors:**
- `TextureProviderFlags(this.value)`: Initializes `TextureProviderFlags(this.value)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `srgb` | `srgb(1 << 0)` | Executes `srgb` operation. |
| `value` | `int value` | Holds the `value` property or configuration state. |

#### `class TextureProvider`

A provider that decodes image data into Filament textures.

**Constructors:**
- `TextureProvider._(this._ptr, this._engine)`: Initializes `TextureProvider._(this._ptr, this._engine)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
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
| `dispose` | `void dispose() => destroy()` | Releases native FFI pointers, event subscriptions, and allocated memory. |
| `isDisposed` | `bool get isDisposed` | Checks current state or capability and returns a boolean value. |

### `lib/src/texture_sampler.dart`

#### `enum SamplerMinFilter`

Sampler minification filter matching backend::SamplerMinFilter.

**Constructors:**
- `SamplerMinFilter(this.value)`: Initializes `SamplerMinFilter(this.value)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `linearMipmapLinear` | `linearMipmapLinear(5)` | Executes `linearMipmapLinear` operation. |
| `value` | `int value` | Holds the `value` property or configuration state. |

#### `enum SamplerMagFilter`

Sampler magnification filter matching backend::SamplerMagFilter.

**Constructors:**
- `SamplerMagFilter(this.value)`: Initializes `SamplerMagFilter(this.value)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `linear` | `linear(1)` | Executes `linear` operation. |
| `value` | `int value` | Holds the `value` property or configuration state. |

#### `enum SamplerWrapMode`

Sampler wrap mode matching backend::SamplerWrapMode.

**Constructors:**
- `SamplerWrapMode(this.value)`: Initializes `SamplerWrapMode(this.value)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `mirroredRepeat` | `mirroredRepeat(2)` | Executes `mirroredRepeat` operation. |
| `value` | `int value` | Holds the `value` property or configuration state. |

#### `enum SamplerCompareMode`

Sampler compare mode matching backend::SamplerCompareMode.

**Constructors:**
- `SamplerCompareMode(this.value)`: Initializes `SamplerCompareMode(this.value)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `compareToTexture` | `compareToTexture(1)` | Executes `compareToTexture` operation. |
| `value` | `int value` | Holds the `value` property or configuration state. |

#### `enum SamplerCompareFunc`

Sampler compare function matching backend::SamplerCompareFunc.

**Constructors:**
- `SamplerCompareFunc(this.value)`: Initializes `SamplerCompareFunc(this.value)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `n` | `n(7)` | Executes `n` operation. |
| `value` | `int value` | Holds the `value` property or configuration state. |

#### `class TextureSampler`

Defines how a texture is accessed, filtered, wrapped, and compared.  An immutable, pure-Dart value type that packs directly to Filament's 32-bit `SamplerParams`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `filterMin` | `SamplerMinFilter filterMin` | Holds the `filterMin` property or configuration state. |
| `filterMag` | `SamplerMagFilter filterMag` | Holds the `filterMag` property or configuration state. |
| `wrapS` | `SamplerWrapMode wrapS` | Holds the `wrapS` property or configuration state. |
| `wrapT` | `SamplerWrapMode wrapT` | Holds the `wrapT` property or configuration state. |
| `wrapR` | `SamplerWrapMode wrapR` | Holds the `wrapR` property or configuration state. |
| `anisotropy` | `double anisotropy` | Holds the `anisotropy` property or configuration state. |
| `compareMode` | `SamplerCompareMode compareMode` | Holds the `compareMode` property or configuration state. |
| `compareFunc` | `SamplerCompareFunc compareFunc` | Holds the `compareFunc` property or configuration state. |
| `anisotropyLog2` | `int get anisotropyLog2` | The log2 quantized anisotropy value in the range [0, 7]. |
| `packed` | `int get packed` | The packed 32-bit `SamplerParams` representation matching Filament's memory layout. |
| `hashCode` | `int get hashCode` | Checks current state or capability and returns a boolean value. |
| `toString` | `String toString()` | Executes `toString` operation. |

### `lib/src/transcoder.dart`

#### `enum ComponentType`

Component type for vertex attribute input transcoding.

**Constructors:**
- `ComponentType(this.value)`: Initializes `ComponentType(this.value)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `float` | `float(5)` | Executes `float` operation. |
| `value` | `int value` | Holds the `value` property or configuration state. |

#### `class TranscoderConfig`

Configuration describing the input format for [Transcoder].

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `componentType` | `ComponentType componentType` | The input element component type (BYTE, UBYTE, SHORT, USHORT, HALF, FLOAT). |
| `normalized` | `bool normalized` | Whether integer input components should be mapped to the normalized [0, 1] or [-1, +1] range. |
| `componentCount` | `int componentCount` | The number of components per vertex (e.g. 1 for float, 2 for float2/uv, 3 for float3/normal, 4 for float4/color). |
| `inputStrideBytes` | `int inputStrideBytes` | Input stride in bytes. If 0, the transcoder assumes tightly packed data. |

#### `class Transcoder`

Converts arbitrary packed/normalized vertex attribute data into tightly packed 32-bit floating point values.  This is especially useful for 3-component formats (e.g. `short3`, `half3`) which are not supported on backends with strict minspecs (like Vulkan), allowing CPU expansion to `float3`.

**Constructors:**
- `Transcoder(this.config)`: Initializes `Transcoder(this.config)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `config` | `TranscoderConfig config` | Holds the `config` property or configuration state. |
| `run` | `Float32List run(TypedData source, int vertexCount)` | Transcodes [source] attribute data of [vertexCount] items into tightly packed [Float32List].  [source] can be any [TypedData] (such as [Int8List], [Uint8List], [Int16List], [Uint16List], [Float32List]). |

### `lib/src/image_sdf.dart`

**Top-level functions and variables:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `computeCoordField` | `LinearImage computeCoordField(LinearImage src, {double threshold = 0.5, int channel = 0,})` | Generates a 2-channel field of unnormalized coordinates pointing to the nearest pixel where [src] component at [channel] > [threshold]. |
| `edtFromCoordField` | `LinearImage edtFromCoordField(LinearImage coordField, {bool sqrt = true,})` | Generates a 1-channel Euclidean distance field from [coordField]. |
| `voronoiFromCoordField` | `LinearImage voronoiFromCoordField(LinearImage coordField, LinearImage src,)` | Dereferences the given coordinate field to propagate nearest feature pixel colors from [src]. |
| `signedDistanceField` | `LinearImage signedDistanceField(LinearImage mask, {double threshold = 0.5, int channel = 0,})` | Generates a signed distance field (SDF) from a binary/coverage [mask]. |
| `dilateUvIslands` | `LinearImage dilateUvIslands(LinearImage baked, LinearImage coverageMask, {double threshold = 0.5, int channel...` | Dilates UV island boundaries into gutters using Voronoi nearest neighbor coloring. |

---

[Previous: Materials](materials.md) | [Up: flutter_filament](index.md) | [Next: glTF loading and animation](gltfio.md)
