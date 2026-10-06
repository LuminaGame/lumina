[Türkçe](../../tr/flutter_filament/view-options.md)

# View options and color grading

The per-view rendering options (dynamic resolution, bloom, fog, depth of field, vignette, ambient occlusion, anti-aliasing, screen-space reflections, shadows and more) together with tone mappers, color grading and color transforms. File paths are relative to the `flutter_filament/` package directory.

**On this page:**

- [Native C bridge](#native-c-bridge)
  - [`src/color_grading_c.h`](#srccolor_grading_ch)
  - [`src/color_transform_c.h`](#srccolor_transform_ch)
- [Dart API](#dart-api)
  - [`lib/src/color_grading.dart`](#libsrccolor_gradingdart)
  - [`lib/src/color_transform.dart`](#libsrccolor_transformdart)
  - [`lib/src/view_options.dart`](#libsrcview_optionsdart)

## Native C bridge

The C functions below are declared in the package's `src/` headers and called from Dart through FFI.

### `src/color_grading_c.h`

| C Function | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `filament_tone_mapper_create` | `void* filament_tone_mapper_create(int type);` | Allocates and initializes the native Filament `filament_tone_mapper_create` resource on the engine/GPU. |
| `filament_tone_mapper_create_agx` | `void* filament_tone_mapper_create_agx(int look);` | Allocates and initializes the native Filament `filament_tone_mapper_create_agx` resource on the engine/GPU. |
| `filament_tone_mapper_create_generic` | `void* filament_tone_mapper_create_generic(float contrast, float mid...` | Allocates and initializes the native Filament `filament_tone_mapper_create_generic` resource on the engine/GPU. |
| `filament_tone_mapper_destroy` | `void filament_tone_mapper_destroy(void* tone_mapper);` | Destroys the native Filament `filament_tone_mapper_destroy` resource and releases GPU/host memory. |
| `filament_color_grading_builder_create` | `void* filament_color_grading_builder_create(void);` | Allocates and initializes the native Filament `filament_color_grading_builder_create` resource on the engine/GPU. |
| `filament_color_grading_builder_quality` | `void filament_color_grading_builder_quality(void* builder, int qual...` | Executes native Filament `filament_color_grading_builder_quality` C binding. |
| `filament_color_grading_builder_format` | `void filament_color_grading_builder_format(void* builder, int lut_f...` | Executes native Filament `filament_color_grading_builder_format` C binding. |
| `filament_color_grading_builder_dimensions` | `void filament_color_grading_builder_dimensions(void* builder, uint8...` | Executes native Filament `filament_color_grading_builder_dimensions` C binding. |
| `filament_color_grading_builder_tone_mapper` | `void filament_color_grading_builder_tone_mapper(void* builder, void...` | Executes native Filament `filament_color_grading_builder_tone_mapper` C binding. |
| `filament_color_grading_builder_exposure` | `void filament_color_grading_builder_exposure(void* builder, float e...` | Executes native Filament `filament_color_grading_builder_exposure` C binding. |
| `filament_color_grading_builder_night_adaptation` | `void filament_color_grading_builder_night_adaptation(void* builder,...` | Executes native Filament `filament_color_grading_builder_night_adaptation` C binding. |
| `filament_color_grading_builder_white_balance` | `void filament_color_grading_builder_white_balance(void* builder, fl...` | Executes native Filament `filament_color_grading_builder_white_balance` C binding. |
| `filament_color_grading_builder_channel_mixer` | `void filament_color_grading_builder_channel_mixer(void* builder, co...` | Executes native Filament `filament_color_grading_builder_channel_mixer` C binding. |
| `filament_color_grading_builder_shadows_midtones_highlights` | `void filament_color_grading_builder_shadows_midtones_highlights(voi...` | Executes native Filament `filament_color_grading_builder_shadows_midtones_highlights` C binding. |
| `filament_color_grading_builder_slope_offset_power` | `void filament_color_grading_builder_slope_offset_power(void* builde...` | Updates the `filament_color_grading_builder_slope_offset_power` parameter or state in the native C layer. |
| `filament_color_grading_builder_contrast` | `void filament_color_grading_builder_contrast(void* builder, float c...` | Executes native Filament `filament_color_grading_builder_contrast` C binding. |
| `filament_color_grading_builder_vibrance` | `void filament_color_grading_builder_vibrance(void* builder, float v...` | Executes native Filament `filament_color_grading_builder_vibrance` C binding. |
| `filament_color_grading_builder_saturation` | `void filament_color_grading_builder_saturation(void* builder, float...` | Executes native Filament `filament_color_grading_builder_saturation` C binding. |
| `filament_color_grading_builder_curves` | `void filament_color_grading_builder_curves(void* builder, const flo...` | Executes native Filament `filament_color_grading_builder_curves` C binding. |
| `filament_color_grading_builder_luminance_scaling` | `void filament_color_grading_builder_luminance_scaling(void* builder...` | Executes native Filament `filament_color_grading_builder_luminance_scaling` C binding. |
| `filament_color_grading_builder_gamut_mapping` | `void filament_color_grading_builder_gamut_mapping(void* builder, bo...` | Executes native Filament `filament_color_grading_builder_gamut_mapping` C binding. |
| `filament_color_grading_builder_build` | `void* filament_color_grading_builder_build(void* builder, void* eng...` | Executes native Filament `filament_color_grading_builder_build` C binding. |
| `filament_color_grading_builder_destroy` | `void filament_color_grading_builder_destroy(void* builder);` | Destroys the native Filament `filament_color_grading_builder_destroy` resource and releases GPU/host memory. |
| `filament_view_set_color_grading` | `void filament_view_set_color_grading(void* view, void* color_grading);` | Updates the `filament_view_set_color_grading` parameter or state in the native C layer. |
| `filament_engine_destroy_color_grading` | `void filament_engine_destroy_color_grading(void* engine, void* colo...` | Destroys the native Filament `filament_engine_destroy_color_grading` resource and releases GPU/host memory. |

### `src/color_transform_c.h`

| C Function | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `filament_color_srgb_to_linear` | `FFI_PLUGIN_EXPORT FilLinearImage* filament_color_srgb_to_linear(con...` | Executes native Filament `filament_color_srgb_to_linear` C binding. |
| `filament_color_linear_to_srgb` | `FFI_PLUGIN_EXPORT FilLinearImage* filament_color_linear_to_srgb(con...` | Executes native Filament `filament_color_linear_to_srgb` C binding. |
| `filament_color_to_grayscale` | `FFI_PLUGIN_EXPORT FilLinearImage* filament_color_to_grayscale(const...` | Executes native Filament `filament_color_to_grayscale` C binding. |
| `filament_color_srgb_bytes_to_linear` | `FFI_PLUGIN_EXPORT FilLinearImage* filament_color_srgb_bytes_to_line...` | Executes native Filament `filament_color_srgb_bytes_to_linear` C binding. |
| `filament_color_linear_to_srgb_bytes` | `FFI_PLUGIN_EXPORT void filament_color_linear_to_srgb_bytes( const F...` | Executes native Filament `filament_color_linear_to_srgb_bytes` C binding. |
| `filament_color_linear_to_rgbm` | `FFI_PLUGIN_EXPORT FilLinearImage* filament_color_linear_to_rgbm(con...` | Executes native Filament `filament_color_linear_to_rgbm` C binding. |
| `filament_color_rgbm_to_linear` | `FFI_PLUGIN_EXPORT FilLinearImage* filament_color_rgbm_to_linear(con...` | Executes native Filament `filament_color_rgbm_to_linear` C binding. |
| `filament_color_linear_to_rgb_10_11_11_rev` | `FFI_PLUGIN_EXPORT void filament_color_linear_to_rgb_10_11_11_rev( c...` | Executes native Filament `filament_color_linear_to_rgb_10_11_11_rev` C binding. |

## Dart API

### `lib/src/color_grading.dart`

#### `enum ToneMapperType`

Available tone-mapping operator types in Filament.

**Constructors:**
- `ToneMapperType(this.value)`: Initializes `ToneMapperType(this.value)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `displayRange` | `displayRange(8)` | Executes `displayRange` operation. |
| `value` | `int value` | Holds the `value` property or configuration state. |

#### `enum AgxLook`

Creative adjustment look for AgX tone mapper.

**Constructors:**
- `AgxLook(this.value)`: Initializes `AgxLook(this.value)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `golden` | `golden(2)` | Executes `golden` operation. |
| `value` | `int value` | Holds the `value` property or configuration state. |

#### `class ToneMapper`

A tone mapping operator in Filament.  ToneMapper instances are plain heap objects used during [ColorGradingBuilder.build] to bake the 3D LUT. They are NOT engine-owned and must be kept alive until [ColorGradingBuilder.build] completes.

**Constructors:**
- `ToneMapper(ToneMapperType type)`: Creates a standard tone mapper of the specified [type].
- `ToneMapper.linear() => ToneMapper(ToneMapperType.linear)`: Creates a linear tone mapper.
- `ToneMapper.aces() => ToneMapper(ToneMapperType.aces)`: Creates an ACES tone mapper.
- `ToneMapper.acesLegacy() => ToneMapper(ToneMapperType.acesLegacy)`: Creates an ACES Legacy tone mapper.
- `ToneMapper.filmic() => ToneMapper(ToneMapperType.filmic)`: Creates a filmic tone mapper.
- `ToneMapper.pbrNeutral() => ToneMapper(ToneMapperType.pbrNeutral)`: Creates a PBR Neutral tone mapper.
- `ToneMapper.gt7() => ToneMapper(ToneMapperType.gt7)`: Creates a Gran Turismo 7 tone mapper.
- `ToneMapper._(this._ptr)`: Initializes `ToneMapper._(this._ptr)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `isDisposed` | `bool get isDisposed` | Checks current state or capability and returns a boolean value. |
| `destroy` | `void destroy()` | Frees the ToneMapper instance. |

#### `enum ColorGradingQuality`

Quality level of the ColorGrading 3D LUT.  Distinct from View QualityLevel.

**Constructors:**
- `ColorGradingQuality(this.value)`: Initializes `ColorGradingQuality(this.value)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `ultra` | `ultra(3)` | Executes `ultra` operation. |
| `value` | `int value` | Holds the `value` property or configuration state. |

#### `enum LutFormat`

Storage format for the 3D LUT backing texture.

**Constructors:**
- `LutFormat(this.value)`: Initializes `LutFormat(this.value)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `float` | `float(1)` | Executes `float` operation. |
| `value` | `int value` | Holds the `value` property or configuration state. |

#### `class ColorGrading`

ColorGrading transforms the colors of the HDR buffer rendered by Filament.  Created via [ColorGradingBuilder] and destroyed via [destroy].

**Constructors:**
- `ColorGrading._(this._ptr, this._engine)`: Initializes `ColorGrading._(this._ptr, this._engine)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `isDisposed` | `bool get isDisposed` | Checks current state or capability and returns a boolean value. |
| `destroy` | `void destroy()` | Destroys this ColorGrading resource in the Filament engine. |

#### `class ColorGradingBuilder`

Fluent builder for creating a [ColorGrading] object.

**Constructors:**
- `ColorGradingBuilder() : _ptr = c.filament_color_grading_builder_create()`: Initializes `ColorGradingBuilder() : _ptr = c.filament_color_grading_builder_create()`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `quality` | `ColorGradingBuilder quality(ColorGradingQuality quality)` | Sets the quality level of the color grading LUT. |
| `format` | `ColorGradingBuilder format(LutFormat lutFormat)` | Sets the format of the 3D LUT texture. |
| `dimensions` | `ColorGradingBuilder dimensions(int dim)` | Sets the dimension of the 3D LUT (valid range: 16..64). |
| `toneMapper` | `ColorGradingBuilder toneMapper(ToneMapper toneMapper)` | Selects the tone mapping operator to apply. |
| `exposure` | `ColorGradingBuilder exposure(double exposure)` | Adjusts the exposure of the image in EV stops. |
| `nightAdaptation` | `ColorGradingBuilder nightAdaptation(double adaptation)` | Controls night adaptation amount (0.0 to 1.0). |
| `whiteBalance` | `ColorGradingBuilder whiteBalance(double temperature, double tint)` | Adjusts white balance with temperature [-1.0..+1.0] and tint [-1.0..+1.0]. |
| `contrast` | `ColorGradingBuilder contrast(double contrast)` | Adjusts image contrast [0.0..2.0]. |
| `vibrance` | `ColorGradingBuilder vibrance(double vibrance)` | Adjusts color vibrance [0.0..2.0]. |
| `saturation` | `ColorGradingBuilder saturation(double saturation)` | Adjusts color saturation [0.0..2.0]. |
| `luminanceScaling` | `ColorGradingBuilder luminanceScaling(bool enabled)` | Enables or disables EVILS luminance scaling. |
| `gamutMapping` | `ColorGradingBuilder gamutMapping(bool enabled)` | Enables or disables gamut mapping to the destination color space. |
| `build` | `ColorGrading build(FilamentEngine engine)` | Builds the [ColorGrading] object for the given [engine]. |
| `destroy` | `void destroy()` | Destroys this builder without building. |

### `lib/src/color_transform.dart`

**Top-level Functions:**

- **`LinearImage srgbToLinear(LinearImage src)`**: Converts an sRGB [LinearImage] to linear color space using the exact piecewise sRGB transfer function.
- **`LinearImage linearToSrgb(LinearImage src)`**: Converts a linear [LinearImage] to sRGB color space.
- **`LinearImage toGrayscale(LinearImage src)`**: Converts a [LinearImage] to 1-channel grayscale using Rec.709 luminance weights (0.2126R + 0.7152G + 0.0722B).
- **`LinearImage linearToRgbm(LinearImage src)`**: Converts a linear HDR [LinearImage] to a 4-channel RGBM representation.
- **`LinearImage rgbmToLinear(LinearImage src)`**: Converts an RGBM [LinearImage] back to a 3-channel linear HDR image.
- **`Uint32List linearToRgb101111Rev(LinearImage src)`**: Encodes a linear [LinearImage] to a packed RGB_10_11_11_REV (R11G11B10F) uint32 buffer.

### `lib/src/view_options.dart`

#### `enum QualityLevel`

`QualityLevel`: Enumeration listing system options and state constants.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `ultra` | `ultra` | Holds the `ultra` property or configuration state. |
| `toNative` | `int toNative()` | Executes `toNative` operation. |
| `fromNative` | `static QualityLevel fromNative(int val)` | Executes `fromNative` operation. |

#### `enum BlendMode`

`BlendMode`: Enumeration listing system options and state constants.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `translucent` | `translucent` | Holds the `translucent` property or configuration state. |
| `toNative` | `int toNative()` | Executes `toNative` operation. |
| `fromNative` | `static BlendMode fromNative(int val)` | Executes `fromNative` operation. |

#### `class DynamicResolutionOptions`

`DynamicResolutionOptions`: `class` representing the data model or functionality of the module.

**Constructors:**
- `DynamicResolutionOptions.fromNative(ffi_gen.filament_dynamic_resolution_options out)`: Initializes `DynamicResolutionOptions.fromNative(ffi_gen.filament_dynamic_resolution_options out)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `minScaleX` | `double minScaleX` | Holds the `minScaleX` property or configuration state. |
| `minScaleY` | `double minScaleY` | Holds the `minScaleY` property or configuration state. |
| `maxScaleX` | `double maxScaleX` | Holds the `maxScaleX` property or configuration state. |
| `maxScaleY` | `double maxScaleY` | Holds the `maxScaleY` property or configuration state. |
| `sharpness` | `double sharpness` | Holds the `sharpness` property or configuration state. |
| `enabled` | `bool enabled` | Holds the `enabled` property or configuration state. |
| `homogeneousScaling` | `bool homogeneousScaling` | Holds the `homogeneousScaling` property or configuration state. |
| `quality` | `QualityLevel quality` | Holds the `quality` property or configuration state. |
| `upscaler` | `Upscaler upscaler` | Which upscaler reconstructs the output: `Upscaler.builtin` (bilinear / SGSR1 / FSR1 by `quality`) or `Upscaler.external` (the view's external upscaler, see [DLSS Super Resolution](dlss.md); falls back to FSR1 when none is registered). Default `builtin`. |
| `hashCode` | `int get hashCode` | Checks current state or capability and returns a boolean value. |
| `copyToNative` | `void copyToNative(ffi_gen.filament_dynamic_resolution_options out)` | Executes `copyToNative` operation. |

#### `enum BloomBlendMode`

`BloomBlendMode`: Enumeration listing system options and state constants.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `interpolate` | `interpolate` | Holds the `interpolate` property or configuration state. |
| `toNative` | `int toNative()` | Executes `toNative` operation. |
| `fromNative` | `static BloomBlendMode fromNative(int val)` | Executes `fromNative` operation. |

#### `class BloomOptions`

`BloomOptions`: `class` representing the data model or functionality of the module.

**Constructors:**
- `BloomOptions.fromNative(ffi_gen.filament_bloom_options out)`: Initializes `BloomOptions.fromNative(ffi_gen.filament_bloom_options out)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `dirtStrength` | `double dirtStrength` | Holds the `dirtStrength` property or configuration state. |
| `strength` | `double strength` | Holds the `strength` property or configuration state. |
| `resolution` | `int resolution` | Holds the `resolution` property or configuration state. |
| `levels` | `int levels` | Holds the `levels` property or configuration state. |
| `blendMode` | `BloomBlendMode blendMode` | Holds the `blendMode` property or configuration state. |
| `threshold` | `bool threshold` | Holds the `threshold` property or configuration state. |
| `enabled` | `bool enabled` | Holds the `enabled` property or configuration state. |
| `highlight` | `double highlight` | Holds the `highlight` property or configuration state. |
| `quality` | `QualityLevel quality` | Holds the `quality` property or configuration state. |
| `lensFlare` | `bool lensFlare` | Holds the `lensFlare` property or configuration state. |
| `starburst` | `bool starburst` | Holds the `starburst` property or configuration state. |
| `chromaticAberration` | `double chromaticAberration` | Holds the `chromaticAberration` property or configuration state. |
| `ghostCount` | `int ghostCount` | Holds the `ghostCount` property or configuration state. |
| `ghostSpacing` | `double ghostSpacing` | Holds the `ghostSpacing` property or configuration state. |
| `ghostThreshold` | `double ghostThreshold` | Holds the `ghostThreshold` property or configuration state. |
| `haloThickness` | `double haloThickness` | Holds the `haloThickness` property or configuration state. |
| `haloRadius` | `double haloRadius` | Holds the `haloRadius` property or configuration state. |
| `haloThreshold` | `double haloThreshold` | Holds the `haloThreshold` property or configuration state. |
| `hashCode` | `int get hashCode` | Checks current state or capability and returns a boolean value. |
| `copyToNative` | `void copyToNative(ffi_gen.filament_bloom_options out)` | Executes `copyToNative` operation. |

#### `class FogOptions`

`FogOptions`: `class` representing the data model or functionality of the module.

**Constructors:**
- `FogOptions.fromNative(ffi_gen.filament_fog_options out)`: Initializes `FogOptions.fromNative(ffi_gen.filament_fog_options out)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `distance` | `double distance` | Holds the `distance` property or configuration state. |
| `cutOffDistance` | `double cutOffDistance` | Holds the `cutOffDistance` property or configuration state. |
| `maximumOpacity` | `double maximumOpacity` | Holds the `maximumOpacity` property or configuration state. |
| `height` | `double height` | Holds the `height` property or configuration state. |
| `heightFalloff` | `double heightFalloff` | Holds the `heightFalloff` property or configuration state. |
| `colorR` | `double colorR` | Holds the `colorR` property or configuration state. |
| `colorG` | `double colorG` | Holds the `colorG` property or configuration state. |
| `colorB` | `double colorB` | Holds the `colorB` property or configuration state. |
| `density` | `double density` | Holds the `density` property or configuration state. |
| `inScatteringStart` | `double inScatteringStart` | Holds the `inScatteringStart` property or configuration state. |
| `inScatteringSize` | `double inScatteringSize` | Holds the `inScatteringSize` property or configuration state. |
| `fogColorFromIbl` | `bool fogColorFromIbl` | Holds the `fogColorFromIbl` property or configuration state. |
| `enabled` | `bool enabled` | Holds the `enabled` property or configuration state. |
| `hashCode` | `int get hashCode` | Checks current state or capability and returns a boolean value. |
| `copyToNative` | `void copyToNative(ffi_gen.filament_fog_options out)` | Executes `copyToNative` operation. |

#### `enum DofFilter`

`DofFilter`: Enumeration listing system options and state constants.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `median` | `median` | Holds the `median` property or configuration state. |
| `toNative` | `int toNative()` | Executes `toNative` operation. |
| `fromNative` | `static DofFilter fromNative(int val)` | Executes `fromNative` operation. |

#### `class DepthOfFieldOptions`

`DepthOfFieldOptions`: `class` representing the data model or functionality of the module.

**Constructors:**
- `DepthOfFieldOptions.fromNative(ffi_gen.filament_depth_of_field_options out)`: Initializes `DepthOfFieldOptions.fromNative(ffi_gen.filament_depth_of_field_options out)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `cocScale` | `double cocScale` | Holds the `cocScale` property or configuration state. |
| `cocAspectRatio` | `double cocAspectRatio` | Holds the `cocAspectRatio` property or configuration state. |
| `maxApertureDiameter` | `double maxApertureDiameter` | Holds the `maxApertureDiameter` property or configuration state. |
| `enabled` | `bool enabled` | Holds the `enabled` property or configuration state. |
| `filter` | `DofFilter filter` | Holds the `filter` property or configuration state. |
| `nativeResolution` | `bool nativeResolution` | Holds the `nativeResolution` property or configuration state. |
| `foregroundRingCount` | `int foregroundRingCount` | Holds the `foregroundRingCount` property or configuration state. |
| `backgroundRingCount` | `int backgroundRingCount` | Holds the `backgroundRingCount` property or configuration state. |
| `fastGatherRingCount` | `int fastGatherRingCount` | Holds the `fastGatherRingCount` property or configuration state. |
| `maxForegroundCOC` | `int maxForegroundCOC` | Holds the `maxForegroundCOC` property or configuration state. |
| `maxBackgroundCOC` | `int maxBackgroundCOC` | Holds the `maxBackgroundCOC` property or configuration state. |
| `hashCode` | `int get hashCode` | Checks current state or capability and returns a boolean value. |
| `copyToNative` | `void copyToNative(ffi_gen.filament_depth_of_field_options out)` | Executes `copyToNative` operation. |

#### `class VignetteOptions`

`VignetteOptions`: `class` representing the data model or functionality of the module.

**Constructors:**
- `VignetteOptions.fromNative(ffi_gen.filament_vignette_options out)`: Initializes `VignetteOptions.fromNative(ffi_gen.filament_vignette_options out)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `midPoint` | `double midPoint` | Holds the `midPoint` property or configuration state. |
| `roundness` | `double roundness` | Holds the `roundness` property or configuration state. |
| `feather` | `double feather` | Holds the `feather` property or configuration state. |
| `colorR` | `double colorR` | Holds the `colorR` property or configuration state. |
| `colorG` | `double colorG` | Holds the `colorG` property or configuration state. |
| `colorB` | `double colorB` | Holds the `colorB` property or configuration state. |
| `colorA` | `double colorA` | Holds the `colorA` property or configuration state. |
| `enabled` | `bool enabled` | Holds the `enabled` property or configuration state. |
| `hashCode` | `int get hashCode` | Checks current state or capability and returns a boolean value. |
| `copyToNative` | `void copyToNative(ffi_gen.filament_vignette_options out)` | Executes `copyToNative` operation. |

#### `class RenderQuality`

`RenderQuality`: `class` representing the data model or functionality of the module.

**Constructors:**
- `RenderQuality.fromNative(ffi_gen.filament_render_quality out)`: Initializes `RenderQuality.fromNative(ffi_gen.filament_render_quality out)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `hdrColorBuffer` | `QualityLevel hdrColorBuffer` | Holds the `hdrColorBuffer` property or configuration state. |
| `hashCode` | `int get hashCode` | Checks current state or capability and returns a boolean value. |
| `copyToNative` | `void copyToNative(ffi_gen.filament_render_quality out)` | Executes `copyToNative` operation. |

#### `enum AmbientOcclusionType`

`AmbientOcclusionType`: Enumeration listing system options and state constants.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `gtao` | `gtao` | Holds the `gtao` property or configuration state. |
| `toNative` | `int toNative()` | Executes `toNative` operation. |
| `fromNative` | `static AmbientOcclusionType fromNative(int val)` | Executes `fromNative` operation. |

#### `class AmbientOcclusionOptions`

`AmbientOcclusionOptions`: `class` representing the data model or functionality of the module.

**Constructors:**
- `AmbientOcclusionOptions.fromNative(ffi_gen.filament_ambient_occlusion_options out)`: Initializes `AmbientOcclusionOptions.fromNative(ffi_gen.filament_ambient_occlusion_options out)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `aoType` | `AmbientOcclusionType aoType` | Holds the `aoType` property or configuration state. |
| `radius` | `double radius` | Holds the `radius` property or configuration state. |
| `power` | `double power` | Holds the `power` property or configuration state. |
| `bias` | `double bias` | Holds the `bias` property or configuration state. |
| `resolution` | `double resolution` | Holds the `resolution` property or configuration state. |
| `intensity` | `double intensity` | Holds the `intensity` property or configuration state. |
| `bilateralThreshold` | `double bilateralThreshold` | Holds the `bilateralThreshold` property or configuration state. |
| `quality` | `QualityLevel quality` | Holds the `quality` property or configuration state. |
| `lowPassFilter` | `QualityLevel lowPassFilter` | Holds the `lowPassFilter` property or configuration state. |
| `upsampling` | `QualityLevel upsampling` | Holds the `upsampling` property or configuration state. |
| `enabled` | `bool enabled` | Holds the `enabled` property or configuration state. |
| `bentNormals` | `bool bentNormals` | Holds the `bentNormals` property or configuration state. |
| `minHorizonAngleRad` | `double minHorizonAngleRad` | Holds the `minHorizonAngleRad` property or configuration state. |
| `ssctLightConeRad` | `double ssctLightConeRad` | Holds the `ssctLightConeRad` property or configuration state. |
| `ssctShadowDistance` | `double ssctShadowDistance` | Holds the `ssctShadowDistance` property or configuration state. |
| `ssctContactDistanceMax` | `double ssctContactDistanceMax` | Holds the `ssctContactDistanceMax` property or configuration state. |
| `ssctIntensity` | `double ssctIntensity` | Holds the `ssctIntensity` property or configuration state. |
| `ssctLightDirectionX` | `double ssctLightDirectionX` | Holds the `ssctLightDirectionX` property or configuration state. |
| `ssctLightDirectionY` | `double ssctLightDirectionY` | Holds the `ssctLightDirectionY` property or configuration state. |
| `ssctLightDirectionZ` | `double ssctLightDirectionZ` | Holds the `ssctLightDirectionZ` property or configuration state. |
| `ssctDepthBias` | `double ssctDepthBias` | Holds the `ssctDepthBias` property or configuration state. |
| `ssctDepthSlopeBias` | `double ssctDepthSlopeBias` | Holds the `ssctDepthSlopeBias` property or configuration state. |
| `ssctSampleCount` | `int ssctSampleCount` | Holds the `ssctSampleCount` property or configuration state. |
| `ssctRayCount` | `int ssctRayCount` | Holds the `ssctRayCount` property or configuration state. |
| `ssctEnabled` | `bool ssctEnabled` | Holds the `ssctEnabled` property or configuration state. |
| `gtaoSampleSliceCount` | `int gtaoSampleSliceCount` | Holds the `gtaoSampleSliceCount` property or configuration state. |
| `gtaoSampleStepsPerSlice` | `int gtaoSampleStepsPerSlice` | Holds the `gtaoSampleStepsPerSlice` property or configuration state. |
| `gtaoThicknessHeuristic` | `double gtaoThicknessHeuristic` | Holds the `gtaoThicknessHeuristic` property or configuration state. |
| `gtaoUseVisibilityBitmasks` | `bool gtaoUseVisibilityBitmasks` | Holds the `gtaoUseVisibilityBitmasks` property or configuration state. |
| `gtaoConstThickness` | `double gtaoConstThickness` | Holds the `gtaoConstThickness` property or configuration state. |
| `gtaoLinearThickness` | `bool gtaoLinearThickness` | Holds the `gtaoLinearThickness` property or configuration state. |
| `hashCode` | `int get hashCode` | Checks current state or capability and returns a boolean value. |
| `copyToNative` | `void copyToNative(ffi_gen.filament_ambient_occlusion_options out)` | Executes `copyToNative` operation. |

#### `class MultiSampleAntiAliasingOptions`

`MultiSampleAntiAliasingOptions`: `class` representing the data model or functionality of the module.

**Constructors:**
- `MultiSampleAntiAliasingOptions.fromNative(ffi_gen.filament_multi_sample_anti_aliasing_options out)`: Initializes `MultiSampleAntiAliasingOptions.fromNative(ffi_gen.filament_multi_sample_anti_aliasing_options out)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `enabled` | `bool enabled` | Holds the `enabled` property or configuration state. |
| `sampleCount` | `int sampleCount` | Holds the `sampleCount` property or configuration state. |
| `customResolve` | `bool customResolve` | Holds the `customResolve` property or configuration state. |
| `hashCode` | `int get hashCode` | Checks current state or capability and returns a boolean value. |
| `copyToNative` | `void copyToNative(ffi_gen.filament_multi_sample_anti_aliasing_options out)` | Executes `copyToNative` operation. |

#### `enum TaaBoxType`

`TaaBoxType`: Enumeration listing system options and state constants.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `aabbVariance` | `aabbVariance` | Holds the `aabbVariance` property or configuration state. |
| `toNative` | `int toNative()` | Executes `toNative` operation. |
| `fromNative` | `static TaaBoxType fromNative(int val)` | Executes `fromNative` operation. |

#### `enum TaaBoxClipping`

`TaaBoxClipping`: Enumeration listing system options and state constants.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `none` | `none` | Holds the `none` property or configuration state. |
| `toNative` | `int toNative()` | Executes `toNative` operation. |
| `fromNative` | `static TaaBoxClipping fromNative(int val)` | Executes `fromNative` operation. |

#### `enum TaaJitterPattern`

`TaaJitterPattern`: Enumeration listing system options and state constants.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `halton23X32` | `halton23X32` | Holds the `halton23X32` property or configuration state. |
| `toNative` | `int toNative()` | Executes `toNative` operation. |
| `fromNative` | `static TaaJitterPattern fromNative(int val)` | Executes `fromNative` operation. |

#### `class TemporalAntiAliasingOptions`

`TemporalAntiAliasingOptions`: `class` representing the data model or functionality of the module.

**Constructors:**
- `TemporalAntiAliasingOptions.fromNative(ffi_gen.filament_temporal_anti_aliasing_options out)`: Initializes `TemporalAntiAliasingOptions.fromNative(ffi_gen.filament_temporal_anti_aliasing_options out)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `filterWidth` | `double filterWidth` | Holds the `filterWidth` property or configuration state. |
| `feedback` | `double feedback` | Holds the `feedback` property or configuration state. |
| `lodBias` | `double lodBias` | Holds the `lodBias` property or configuration state. |
| `sharpness` | `double sharpness` | Holds the `sharpness` property or configuration state. |
| `enabled` | `bool enabled` | Holds the `enabled` property or configuration state. |
| `upscaling` | `double upscaling` | Holds the `upscaling` property or configuration state. |
| `filterHistory` | `bool filterHistory` | Holds the `filterHistory` property or configuration state. |
| `filterInput` | `bool filterInput` | Holds the `filterInput` property or configuration state. |
| `useYCoCg` | `bool useYCoCg` | Holds the `useYCoCg` property or configuration state. |
| `hdr` | `bool hdr` | Holds the `hdr` property or configuration state. |
| `boxType` | `TaaBoxType boxType` | Holds the `boxType` property or configuration state. |
| `boxClipping` | `TaaBoxClipping boxClipping` | Holds the `boxClipping` property or configuration state. |
| `jitterPattern` | `TaaJitterPattern jitterPattern` | Holds the `jitterPattern` property or configuration state. |
| `varianceGamma` | `double varianceGamma` | Holds the `varianceGamma` property or configuration state. |
| `preventFlickering` | `bool preventFlickering` | Holds the `preventFlickering` property or configuration state. |
| `historyReprojection` | `bool historyReprojection` | Holds the `historyReprojection` property or configuration state. |
| `motionVectors` | `bool motionVectors` | Renders per-pixel motion vectors in the structure pass (which then runs at full resolution) and reprojects the TAA history with them instead of the camera matrices alone, so moving, transform-animated, skinned and morphed objects stop ghosting (a shared `SkinningBuffer` keeps no previous palette). Export the buffer with `FilamentView.motionVectorTexture` / `MotionVectorBuffer`; needs `FilamentView.motionVectorsSupported`. Default `false`. |
| `algorithm` | `TaaAlgorithm algorithm` | `TaaAlgorithm.filament` (Filament's TAA) or `TaaAlgorithm.fsr3`: the FidelityFX Super Resolution 3.1 upscaler as fragment passes, fed by the structure pass motion vectors (implied); only `upscaling`, `sharpness`, `lodBias` and `jitterPattern` apply; feature level 1, no stereo; an external upscaler (DLSS) takes precedence. Default `filament`. |
| `frameGeneration` | `bool frameGeneration` | FSR3 frame generation: an interpolated frame is presented before each rendered frame (double the presented rate, half a frame of latency). Needs `TaaAlgorithm.fsr3` and a view rendering into the swap chain without guard band; with `SwapChainConfig.disableVsync` the renderer paces the two presents. Default `false`. |
| `hashCode` | `int get hashCode` | Checks current state or capability and returns a boolean value. |
| `copyToNative` | `void copyToNative(ffi_gen.filament_temporal_anti_aliasing_options out)` | Executes `copyToNative` operation. |

#### `class ScreenSpaceReflectionsOptions`

`ScreenSpaceReflectionsOptions`: `class` representing the data model or functionality of the module.

**Constructors:**
- `ScreenSpaceReflectionsOptions.fromNative(ffi_gen.filament_screen_space_reflections_options out)`: Initializes `ScreenSpaceReflectionsOptions.fromNative(ffi_gen.filament_screen_space_reflections_options out)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `thickness` | `double thickness` | Holds the `thickness` property or configuration state. |
| `bias` | `double bias` | Holds the `bias` property or configuration state. |
| `maxDistance` | `double maxDistance` | Holds the `maxDistance` property or configuration state. |
| `stride` | `double stride` | Holds the `stride` property or configuration state. |
| `enabled` | `bool enabled` | Holds the `enabled` property or configuration state. |
| `hashCode` | `int get hashCode` | Checks current state or capability and returns a boolean value. |
| `copyToNative` | `void copyToNative(ffi_gen.filament_screen_space_reflections_options out)` | Executes `copyToNative` operation. |

#### `class GuardBandOptions`

`GuardBandOptions`: `class` representing the data model or functionality of the module.

**Constructors:**
- `GuardBandOptions.fromNative(ffi_gen.filament_guard_band_options out)`: Initializes `GuardBandOptions.fromNative(ffi_gen.filament_guard_band_options out)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `enabled` | `bool enabled` | Holds the `enabled` property or configuration state. |
| `hashCode` | `int get hashCode` | Checks current state or capability and returns a boolean value. |
| `copyToNative` | `void copyToNative(ffi_gen.filament_guard_band_options out)` | Executes `copyToNative` operation. |

#### `enum AntiAliasing`

`AntiAliasing`: Enumeration listing system options and state constants.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `fxaa` | `fxaa` | Holds the `fxaa` property or configuration state. |
| `toNative` | `int toNative()` | Executes `toNative` operation. |
| `fromNative` | `static AntiAliasing fromNative(int val)` | Executes `fromNative` operation. |

#### `enum Dithering`

`Dithering`: Enumeration listing system options and state constants.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `temporal` | `temporal` | Holds the `temporal` property or configuration state. |
| `toNative` | `int toNative()` | Executes `toNative` operation. |
| `fromNative` | `static Dithering fromNative(int val)` | Executes `fromNative` operation. |

#### `enum ShadowType`

`ShadowType`: Enumeration listing system options and state constants.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `pcfd` | `pcfd` | Holds the `pcfd` property or configuration state. |
| `toNative` | `int toNative()` | Executes `toNative` operation. |
| `fromNative` | `static ShadowType fromNative(int val)` | Executes `fromNative` operation. |

#### `class VsmShadowOptions`

`VsmShadowOptions`: `class` representing the data model or functionality of the module.

**Constructors:**
- `VsmShadowOptions.fromNative(ffi_gen.filament_vsm_shadow_options out)`: Initializes `VsmShadowOptions.fromNative(ffi_gen.filament_vsm_shadow_options out)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `anisotropy` | `int anisotropy` | Holds the `anisotropy` property or configuration state. |
| `mipmapping` | `bool mipmapping` | Holds the `mipmapping` property or configuration state. |
| `msaaSamples` | `int msaaSamples` | Holds the `msaaSamples` property or configuration state. |
| `highPrecision` | `bool highPrecision` | Holds the `highPrecision` property or configuration state. |
| `minVarianceScale` | `double minVarianceScale` | Holds the `minVarianceScale` property or configuration state. |
| `lightBleedReduction` | `double lightBleedReduction` | Holds the `lightBleedReduction` property or configuration state. |
| `hashCode` | `int get hashCode` | Checks current state or capability and returns a boolean value. |
| `copyToNative` | `void copyToNative(ffi_gen.filament_vsm_shadow_options out)` | Executes `copyToNative` operation. |

#### `class SoftShadowOptions`

`SoftShadowOptions`: `class` representing the data model or functionality of the module.

**Constructors:**
- `SoftShadowOptions.fromNative(ffi_gen.filament_soft_shadow_options out)`: Initializes `SoftShadowOptions.fromNative(ffi_gen.filament_soft_shadow_options out)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `penumbraScale` | `double penumbraScale` | Holds the `penumbraScale` property or configuration state. |
| `penumbraRatioScale` | `double penumbraRatioScale` | Holds the `penumbraRatioScale` property or configuration state. |
| `maxPenumbraRatio` | `double maxPenumbraRatio` | Holds the `maxPenumbraRatio` property or configuration state. |
| `maxSearchRadius` | `double maxSearchRadius` | Holds the `maxSearchRadius` property or configuration state. |
| `hashCode` | `int get hashCode` | Checks current state or capability and returns a boolean value. |
| `copyToNative` | `void copyToNative(ffi_gen.filament_soft_shadow_options out)` | Executes `copyToNative` operation. |

#### `class StereoscopicOptions`

`StereoscopicOptions`: `class` representing the data model or functionality of the module.

**Constructors:**
- `StereoscopicOptions.fromNative(ffi_gen.filament_stereoscopic_options out)`: Initializes `StereoscopicOptions.fromNative(ffi_gen.filament_stereoscopic_options out)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `enabled` | `bool enabled` | Holds the `enabled` property or configuration state. |
| `copyToNative` | `void copyToNative(ffi_gen.filament_stereoscopic_options out)` | Executes `copyToNative` operation. |

---

[Previous: Renderer, views and frame pacing](renderer-and-view.md) | [Up: flutter_filament](index.md) | [Next: Scene and geometry](scene-and-geometry.md)
