[English](../../en/flutter_filament/view-options.md)

# View seçenekleri ve color grading

View başına render seçenekleri (dynamic resolution, bloom, fog, depth of field, vignette, ambient occlusion, anti-aliasing, screen-space reflections, gölgeler ve daha fazlası) ile tone mapper'lar, color grading ve color transform'lar. Dosya yolları `flutter_filament/` paket dizinine görelidir.

**Bu sayfada:**

- [Native C köprüsü](#native-c-köprüsü)
  - [`src/color_grading_c.h`](#srccolor_grading_ch)
  - [`src/color_transform_c.h`](#srccolor_transform_ch)
- [Dart API](#dart-api)
  - [`lib/src/color_grading.dart`](#libsrccolor_gradingdart)
  - [`lib/src/color_transform.dart`](#libsrccolor_transformdart)
  - [`lib/src/view_options.dart`](#libsrcview_optionsdart)

## Native C köprüsü

Aşağıdaki C fonksiyonları paketin `src/` header'larında tanımlanır ve Dart'tan FFI ile çağrılır.

### `src/color_grading_c.h`

| C Fonksiyonu | İmzası | Açıklama ve Ne İşe Yaradığı |
| :--- | :--- | :--- |
| `filament_tone_mapper_create` | `void* filament_tone_mapper_create(int type);` | İlgili Filament C API kaynağını GPU/motor üzerinde tahsis eder ve ilklendirir. |
| `filament_tone_mapper_create_agx` | `void* filament_tone_mapper_create_agx(int look);` | İlgili Filament C API kaynağını GPU/motor üzerinde tahsis eder ve ilklendirir. |
| `filament_tone_mapper_create_generic` | `void* filament_tone_mapper_create_generic(float contrast, float mid...` | İlgili Filament C API kaynağını GPU/motor üzerinde tahsis eder ve ilklendirir. |
| `filament_tone_mapper_destroy` | `void filament_tone_mapper_destroy(void* tone_mapper);` | İlgili Filament C API nesnesini yok eder ve GPU belleğini serbest bırakır. |
| `filament_color_grading_builder_create` | `void* filament_color_grading_builder_create(void);` | İlgili Filament C API kaynağını GPU/motor üzerinde tahsis eder ve ilklendirir. |
| `filament_color_grading_builder_quality` | `void filament_color_grading_builder_quality(void* builder, int qual...` | Filament yerel `filament_color_grading_builder_quality` C fonksiyonunu çalıştırır. |
| `filament_color_grading_builder_format` | `void filament_color_grading_builder_format(void* builder, int lut_f...` | Filament yerel `filament_color_grading_builder_format` C fonksiyonunu çalıştırır. |
| `filament_color_grading_builder_dimensions` | `void filament_color_grading_builder_dimensions(void* builder, uint8...` | Filament yerel `filament_color_grading_builder_dimensions` C fonksiyonunu çalıştırır. |
| `filament_color_grading_builder_tone_mapper` | `void filament_color_grading_builder_tone_mapper(void* builder, void...` | Filament yerel `filament_color_grading_builder_tone_mapper` C fonksiyonunu çalıştırır. |
| `filament_color_grading_builder_exposure` | `void filament_color_grading_builder_exposure(void* builder, float e...` | Filament yerel `filament_color_grading_builder_exposure` C fonksiyonunu çalıştırır. |
| `filament_color_grading_builder_night_adaptation` | `void filament_color_grading_builder_night_adaptation(void* builder,...` | Filament yerel `filament_color_grading_builder_night_adaptation` C fonksiyonunu çalıştırır. |
| `filament_color_grading_builder_white_balance` | `void filament_color_grading_builder_white_balance(void* builder, fl...` | Filament yerel `filament_color_grading_builder_white_balance` C fonksiyonunu çalıştırır. |
| `filament_color_grading_builder_channel_mixer` | `void filament_color_grading_builder_channel_mixer(void* builder, co...` | Filament yerel `filament_color_grading_builder_channel_mixer` C fonksiyonunu çalıştırır. |
| `filament_color_grading_builder_shadows_midtones_highlights` | `void filament_color_grading_builder_shadows_midtones_highlights(voi...` | Filament yerel `filament_color_grading_builder_shadows_midtones_highlights` C fonksiyonunu çalıştırır. |
| `filament_color_grading_builder_slope_offset_power` | `void filament_color_grading_builder_slope_offset_power(void* builde...` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_color_grading_builder_contrast` | `void filament_color_grading_builder_contrast(void* builder, float c...` | Filament yerel `filament_color_grading_builder_contrast` C fonksiyonunu çalıştırır. |
| `filament_color_grading_builder_vibrance` | `void filament_color_grading_builder_vibrance(void* builder, float v...` | Filament yerel `filament_color_grading_builder_vibrance` C fonksiyonunu çalıştırır. |
| `filament_color_grading_builder_saturation` | `void filament_color_grading_builder_saturation(void* builder, float...` | Filament yerel `filament_color_grading_builder_saturation` C fonksiyonunu çalıştırır. |
| `filament_color_grading_builder_curves` | `void filament_color_grading_builder_curves(void* builder, const flo...` | Filament yerel `filament_color_grading_builder_curves` C fonksiyonunu çalıştırır. |
| `filament_color_grading_builder_luminance_scaling` | `void filament_color_grading_builder_luminance_scaling(void* builder...` | Filament yerel `filament_color_grading_builder_luminance_scaling` C fonksiyonunu çalıştırır. |
| `filament_color_grading_builder_gamut_mapping` | `void filament_color_grading_builder_gamut_mapping(void* builder, bo...` | Filament yerel `filament_color_grading_builder_gamut_mapping` C fonksiyonunu çalıştırır. |
| `filament_color_grading_builder_build` | `void* filament_color_grading_builder_build(void* builder, void* eng...` | Filament yerel `filament_color_grading_builder_build` C fonksiyonunu çalıştırır. |
| `filament_color_grading_builder_destroy` | `void filament_color_grading_builder_destroy(void* builder);` | İlgili Filament C API nesnesini yok eder ve GPU belleğini serbest bırakır. |
| `filament_view_set_color_grading` | `void filament_view_set_color_grading(void* view, void* color_grading);` | İlgili Filament parametresini veya motor durumunu C katmanında günceller. |
| `filament_engine_destroy_color_grading` | `void filament_engine_destroy_color_grading(void* engine, void* colo...` | İlgili Filament C API nesnesini yok eder ve GPU belleğini serbest bırakır. |

### `src/color_transform_c.h`

| C Fonksiyonu | İmzası | Açıklama ve Ne İşe Yaradığı |
| :--- | :--- | :--- |
| `filament_color_srgb_to_linear` | `FFI_PLUGIN_EXPORT FilLinearImage* filament_color_srgb_to_linear(con...` | Filament yerel `filament_color_srgb_to_linear` C fonksiyonunu çalıştırır. |
| `filament_color_linear_to_srgb` | `FFI_PLUGIN_EXPORT FilLinearImage* filament_color_linear_to_srgb(con...` | Filament yerel `filament_color_linear_to_srgb` C fonksiyonunu çalıştırır. |
| `filament_color_to_grayscale` | `FFI_PLUGIN_EXPORT FilLinearImage* filament_color_to_grayscale(const...` | Filament yerel `filament_color_to_grayscale` C fonksiyonunu çalıştırır. |
| `filament_color_srgb_bytes_to_linear` | `FFI_PLUGIN_EXPORT FilLinearImage* filament_color_srgb_bytes_to_line...` | Filament yerel `filament_color_srgb_bytes_to_linear` C fonksiyonunu çalıştırır. |
| `filament_color_linear_to_srgb_bytes` | `FFI_PLUGIN_EXPORT void filament_color_linear_to_srgb_bytes( const F...` | Filament yerel `filament_color_linear_to_srgb_bytes` C fonksiyonunu çalıştırır. |
| `filament_color_linear_to_rgbm` | `FFI_PLUGIN_EXPORT FilLinearImage* filament_color_linear_to_rgbm(con...` | Filament yerel `filament_color_linear_to_rgbm` C fonksiyonunu çalıştırır. |
| `filament_color_rgbm_to_linear` | `FFI_PLUGIN_EXPORT FilLinearImage* filament_color_rgbm_to_linear(con...` | Filament yerel `filament_color_rgbm_to_linear` C fonksiyonunu çalıştırır. |
| `filament_color_linear_to_rgb_10_11_11_rev` | `FFI_PLUGIN_EXPORT void filament_color_linear_to_rgb_10_11_11_rev( c...` | Filament yerel `filament_color_linear_to_rgb_10_11_11_rev` C fonksiyonunu çalıştırır. |

## Dart API

### `lib/src/color_grading.dart`

#### `enum ToneMapperType`

Available tone-mapping operator types in Filament.

**Yapıcı Metotlar (Constructors):**
- `ToneMapperType(this.value)`: `ToneMapperType(this.value)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `displayRange` | `displayRange(8)` | `displayRange` işlemini gerçekleştirir. |
| `value` | `int value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |

#### `enum AgxLook`

Creative adjustment look for AgX tone mapper.

**Yapıcı Metotlar (Constructors):**
- `AgxLook(this.value)`: `AgxLook(this.value)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `golden` | `golden(2)` | `golden` işlemini gerçekleştirir. |
| `value` | `int value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |

#### `class ToneMapper`

A tone mapping operator in Filament.  ToneMapper instances are plain heap objects used during [ColorGradingBuilder.build] to bake the 3D LUT. They are NOT engine-owned and must be kept alive until [ColorGradingBuilder.build] completes.

**Yapıcı Metotlar (Constructors):**
- `ToneMapper(ToneMapperType type)`: Creates a standard tone mapper of the specified [type].
- `ToneMapper.linear() => ToneMapper(ToneMapperType.linear)`: Creates a linear tone mapper.
- `ToneMapper.aces() => ToneMapper(ToneMapperType.aces)`: Creates an ACES tone mapper.
- `ToneMapper.acesLegacy() => ToneMapper(ToneMapperType.acesLegacy)`: Creates an ACES Legacy tone mapper.
- `ToneMapper.filmic() => ToneMapper(ToneMapperType.filmic)`: Creates a filmic tone mapper.
- `ToneMapper.pbrNeutral() => ToneMapper(ToneMapperType.pbrNeutral)`: Creates a PBR Neutral tone mapper.
- `ToneMapper.gt7() => ToneMapper(ToneMapperType.gt7)`: Creates a Gran Turismo 7 tone mapper.
- `ToneMapper._(this._ptr)`: `ToneMapper._(this._ptr)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `isDisposed` | `bool get isDisposed` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `destroy` | `void destroy()` | Frees the ToneMapper instance. |

#### `enum ColorGradingQuality`

Quality level of the ColorGrading 3D LUT.  Distinct from View QualityLevel.

**Yapıcı Metotlar (Constructors):**
- `ColorGradingQuality(this.value)`: `ColorGradingQuality(this.value)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `ultra` | `ultra(3)` | `ultra` işlemini gerçekleştirir. |
| `value` | `int value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |

#### `enum LutFormat`

Storage format for the 3D LUT backing texture.

**Yapıcı Metotlar (Constructors):**
- `LutFormat(this.value)`: `LutFormat(this.value)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `float` | `float(1)` | `float` işlemini gerçekleştirir. |
| `value` | `int value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |

#### `class ColorGrading`

ColorGrading transforms the colors of the HDR buffer rendered by Filament.  Created via [ColorGradingBuilder] and destroyed via [destroy].

**Yapıcı Metotlar (Constructors):**
- `ColorGrading._(this._ptr, this._engine)`: `ColorGrading._(this._ptr, this._engine)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `isDisposed` | `bool get isDisposed` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `destroy` | `void destroy()` | Destroys this ColorGrading resource in the Filament engine. |

#### `class ColorGradingBuilder`

Fluent builder for creating a [ColorGrading] object.

**Yapıcı Metotlar (Constructors):**
- `ColorGradingBuilder() : _ptr = c.filament_color_grading_builder_create()`: `ColorGradingBuilder() : _ptr = c.filament_color_grading_builder_create()` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
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

**Üst Düzey Fonksiyonlar (Top-level Functions):**

- **`LinearImage srgbToLinear(LinearImage src)`**: Converts an sRGB [LinearImage] to linear color space using the exact piecewise sRGB transfer function.
- **`LinearImage linearToSrgb(LinearImage src)`**: Converts a linear [LinearImage] to sRGB color space.
- **`LinearImage toGrayscale(LinearImage src)`**: Converts a [LinearImage] to 1-channel grayscale using Rec.709 luminance weights (0.2126R + 0.7152G + 0.0722B).
- **`LinearImage linearToRgbm(LinearImage src)`**: Converts a linear HDR [LinearImage] to a 4-channel RGBM representation.
- **`LinearImage rgbmToLinear(LinearImage src)`**: Converts an RGBM [LinearImage] back to a 3-channel linear HDR image.
- **`Uint32List linearToRgb101111Rev(LinearImage src)`**: Encodes a linear [LinearImage] to a packed RGB_10_11_11_REV (R11G11B10F) uint32 buffer.

### `lib/src/view_options.dart`

#### `enum QualityLevel`

`QualityLevel`: Sistemde kullanılan seçenekleri ve durumları listeleyen numaralandırma türüdür.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `ultra` | `ultra` | `ultra` alanını (field/property) ve ilişkili veriyi saklar. |
| `toNative` | `int toNative()` | `toNative` işlemini gerçekleştirir. |
| `fromNative` | `static QualityLevel fromNative(int val)` | `fromNative` işlemini gerçekleştirir. |

#### `enum BlendMode`

`BlendMode`: Sistemde kullanılan seçenekleri ve durumları listeleyen numaralandırma türüdür.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `translucent` | `translucent` | `translucent` alanını (field/property) ve ilişkili veriyi saklar. |
| `toNative` | `int toNative()` | `toNative` işlemini gerçekleştirir. |
| `fromNative` | `static BlendMode fromNative(int val)` | `fromNative` işlemini gerçekleştirir. |

#### `class DynamicResolutionOptions`

`DynamicResolutionOptions`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `DynamicResolutionOptions.fromNative(ffi_gen.filament_dynamic_resolution_options out)`: `DynamicResolutionOptions.fromNative(ffi_gen.filament_dynamic_resolution_options out)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `minScaleX` | `double minScaleX` | `minScaleX` alanını (field/property) ve ilişkili veriyi saklar. |
| `minScaleY` | `double minScaleY` | `minScaleY` alanını (field/property) ve ilişkili veriyi saklar. |
| `maxScaleX` | `double maxScaleX` | `maxScaleX` alanını (field/property) ve ilişkili veriyi saklar. |
| `maxScaleY` | `double maxScaleY` | `maxScaleY` alanını (field/property) ve ilişkili veriyi saklar. |
| `sharpness` | `double sharpness` | `sharpness` alanını (field/property) ve ilişkili veriyi saklar. |
| `enabled` | `bool enabled` | `enabled` alanını (field/property) ve ilişkili veriyi saklar. |
| `homogeneousScaling` | `bool homogeneousScaling` | `homogeneousScaling` alanını (field/property) ve ilişkili veriyi saklar. |
| `quality` | `QualityLevel quality` | `quality` alanını (field/property) ve ilişkili veriyi saklar. |
| `upscaler` | `Upscaler upscaler` | Çıktıyı hangi upscaler'ın oluşturacağı: `Upscaler.builtin` (`quality`'ye göre bilinear / SGSR1 / FSR1) ya da `Upscaler.external` (view'ın harici upscaler'ı, bkz. [DLSS Super Resolution](dlss.md); kayıtlı değilse FSR1'e döner). Varsayılan `builtin`. |
| `hashCode` | `int get hashCode` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `copyToNative` | `void copyToNative(ffi_gen.filament_dynamic_resolution_options out)` | `copyToNative` işlemini gerçekleştirir. |

#### `enum BloomBlendMode`

`BloomBlendMode`: Sistemde kullanılan seçenekleri ve durumları listeleyen numaralandırma türüdür.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `interpolate` | `interpolate` | `interpolate` alanını (field/property) ve ilişkili veriyi saklar. |
| `toNative` | `int toNative()` | `toNative` işlemini gerçekleştirir. |
| `fromNative` | `static BloomBlendMode fromNative(int val)` | `fromNative` işlemini gerçekleştirir. |

#### `class BloomOptions`

`BloomOptions`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `BloomOptions.fromNative(ffi_gen.filament_bloom_options out)`: `BloomOptions.fromNative(ffi_gen.filament_bloom_options out)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `dirtStrength` | `double dirtStrength` | `dirtStrength` alanını (field/property) ve ilişkili veriyi saklar. |
| `strength` | `double strength` | `strength` alanını (field/property) ve ilişkili veriyi saklar. |
| `resolution` | `int resolution` | `resolution` alanını (field/property) ve ilişkili veriyi saklar. |
| `levels` | `int levels` | `levels` alanını (field/property) ve ilişkili veriyi saklar. |
| `blendMode` | `BloomBlendMode blendMode` | `blendMode` alanını (field/property) ve ilişkili veriyi saklar. |
| `threshold` | `bool threshold` | `threshold` alanını (field/property) ve ilişkili veriyi saklar. |
| `enabled` | `bool enabled` | `enabled` alanını (field/property) ve ilişkili veriyi saklar. |
| `highlight` | `double highlight` | `highlight` alanını (field/property) ve ilişkili veriyi saklar. |
| `quality` | `QualityLevel quality` | `quality` alanını (field/property) ve ilişkili veriyi saklar. |
| `lensFlare` | `bool lensFlare` | `lensFlare` alanını (field/property) ve ilişkili veriyi saklar. |
| `starburst` | `bool starburst` | `starburst` alanını (field/property) ve ilişkili veriyi saklar. |
| `chromaticAberration` | `double chromaticAberration` | `chromaticAberration` alanını (field/property) ve ilişkili veriyi saklar. |
| `ghostCount` | `int ghostCount` | `ghostCount` alanını (field/property) ve ilişkili veriyi saklar. |
| `ghostSpacing` | `double ghostSpacing` | `ghostSpacing` alanını (field/property) ve ilişkili veriyi saklar. |
| `ghostThreshold` | `double ghostThreshold` | `ghostThreshold` alanını (field/property) ve ilişkili veriyi saklar. |
| `haloThickness` | `double haloThickness` | `haloThickness` alanını (field/property) ve ilişkili veriyi saklar. |
| `haloRadius` | `double haloRadius` | `haloRadius` alanını (field/property) ve ilişkili veriyi saklar. |
| `haloThreshold` | `double haloThreshold` | `haloThreshold` alanını (field/property) ve ilişkili veriyi saklar. |
| `hashCode` | `int get hashCode` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `copyToNative` | `void copyToNative(ffi_gen.filament_bloom_options out)` | `copyToNative` işlemini gerçekleştirir. |

#### `class FogOptions`

`FogOptions`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `FogOptions.fromNative(ffi_gen.filament_fog_options out)`: `FogOptions.fromNative(ffi_gen.filament_fog_options out)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `distance` | `double distance` | `distance` alanını (field/property) ve ilişkili veriyi saklar. |
| `cutOffDistance` | `double cutOffDistance` | `cutOffDistance` alanını (field/property) ve ilişkili veriyi saklar. |
| `maximumOpacity` | `double maximumOpacity` | `maximumOpacity` alanını (field/property) ve ilişkili veriyi saklar. |
| `height` | `double height` | `height` alanını (field/property) ve ilişkili veriyi saklar. |
| `heightFalloff` | `double heightFalloff` | `heightFalloff` alanını (field/property) ve ilişkili veriyi saklar. |
| `colorR` | `double colorR` | `colorR` alanını (field/property) ve ilişkili veriyi saklar. |
| `colorG` | `double colorG` | `colorG` alanını (field/property) ve ilişkili veriyi saklar. |
| `colorB` | `double colorB` | `colorB` alanını (field/property) ve ilişkili veriyi saklar. |
| `density` | `double density` | `density` alanını (field/property) ve ilişkili veriyi saklar. |
| `inScatteringStart` | `double inScatteringStart` | `inScatteringStart` alanını (field/property) ve ilişkili veriyi saklar. |
| `inScatteringSize` | `double inScatteringSize` | `inScatteringSize` alanını (field/property) ve ilişkili veriyi saklar. |
| `fogColorFromIbl` | `bool fogColorFromIbl` | `fogColorFromIbl` alanını (field/property) ve ilişkili veriyi saklar. |
| `enabled` | `bool enabled` | `enabled` alanını (field/property) ve ilişkili veriyi saklar. |
| `hashCode` | `int get hashCode` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `copyToNative` | `void copyToNative(ffi_gen.filament_fog_options out)` | `copyToNative` işlemini gerçekleştirir. |

#### `enum DofFilter`

`DofFilter`: Sistemde kullanılan seçenekleri ve durumları listeleyen numaralandırma türüdür.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `median` | `median` | `median` alanını (field/property) ve ilişkili veriyi saklar. |
| `toNative` | `int toNative()` | `toNative` işlemini gerçekleştirir. |
| `fromNative` | `static DofFilter fromNative(int val)` | `fromNative` işlemini gerçekleştirir. |

#### `class DepthOfFieldOptions`

`DepthOfFieldOptions`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `DepthOfFieldOptions.fromNative(ffi_gen.filament_depth_of_field_options out)`: `DepthOfFieldOptions.fromNative(ffi_gen.filament_depth_of_field_options out)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `cocScale` | `double cocScale` | `cocScale` alanını (field/property) ve ilişkili veriyi saklar. |
| `cocAspectRatio` | `double cocAspectRatio` | `cocAspectRatio` alanını (field/property) ve ilişkili veriyi saklar. |
| `maxApertureDiameter` | `double maxApertureDiameter` | `maxApertureDiameter` alanını (field/property) ve ilişkili veriyi saklar. |
| `enabled` | `bool enabled` | `enabled` alanını (field/property) ve ilişkili veriyi saklar. |
| `filter` | `DofFilter filter` | `filter` alanını (field/property) ve ilişkili veriyi saklar. |
| `nativeResolution` | `bool nativeResolution` | `nativeResolution` alanını (field/property) ve ilişkili veriyi saklar. |
| `foregroundRingCount` | `int foregroundRingCount` | `foregroundRingCount` alanını (field/property) ve ilişkili veriyi saklar. |
| `backgroundRingCount` | `int backgroundRingCount` | `backgroundRingCount` alanını (field/property) ve ilişkili veriyi saklar. |
| `fastGatherRingCount` | `int fastGatherRingCount` | `fastGatherRingCount` alanını (field/property) ve ilişkili veriyi saklar. |
| `maxForegroundCOC` | `int maxForegroundCOC` | `maxForegroundCOC` alanını (field/property) ve ilişkili veriyi saklar. |
| `maxBackgroundCOC` | `int maxBackgroundCOC` | `maxBackgroundCOC` alanını (field/property) ve ilişkili veriyi saklar. |
| `hashCode` | `int get hashCode` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `copyToNative` | `void copyToNative(ffi_gen.filament_depth_of_field_options out)` | `copyToNative` işlemini gerçekleştirir. |

#### `class VignetteOptions`

`VignetteOptions`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `VignetteOptions.fromNative(ffi_gen.filament_vignette_options out)`: `VignetteOptions.fromNative(ffi_gen.filament_vignette_options out)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `midPoint` | `double midPoint` | `midPoint` alanını (field/property) ve ilişkili veriyi saklar. |
| `roundness` | `double roundness` | `roundness` alanını (field/property) ve ilişkili veriyi saklar. |
| `feather` | `double feather` | `feather` alanını (field/property) ve ilişkili veriyi saklar. |
| `colorR` | `double colorR` | `colorR` alanını (field/property) ve ilişkili veriyi saklar. |
| `colorG` | `double colorG` | `colorG` alanını (field/property) ve ilişkili veriyi saklar. |
| `colorB` | `double colorB` | `colorB` alanını (field/property) ve ilişkili veriyi saklar. |
| `colorA` | `double colorA` | `colorA` alanını (field/property) ve ilişkili veriyi saklar. |
| `enabled` | `bool enabled` | `enabled` alanını (field/property) ve ilişkili veriyi saklar. |
| `hashCode` | `int get hashCode` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `copyToNative` | `void copyToNative(ffi_gen.filament_vignette_options out)` | `copyToNative` işlemini gerçekleştirir. |

#### `class RenderQuality`

`RenderQuality`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `RenderQuality.fromNative(ffi_gen.filament_render_quality out)`: `RenderQuality.fromNative(ffi_gen.filament_render_quality out)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `hdrColorBuffer` | `QualityLevel hdrColorBuffer` | `hdrColorBuffer` alanını (field/property) ve ilişkili veriyi saklar. |
| `hashCode` | `int get hashCode` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `copyToNative` | `void copyToNative(ffi_gen.filament_render_quality out)` | `copyToNative` işlemini gerçekleştirir. |

#### `enum AmbientOcclusionType`

`AmbientOcclusionType`: Sistemde kullanılan seçenekleri ve durumları listeleyen numaralandırma türüdür.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `gtao` | `gtao` | `gtao` alanını (field/property) ve ilişkili veriyi saklar. |
| `toNative` | `int toNative()` | `toNative` işlemini gerçekleştirir. |
| `fromNative` | `static AmbientOcclusionType fromNative(int val)` | `fromNative` işlemini gerçekleştirir. |

#### `class AmbientOcclusionOptions`

`AmbientOcclusionOptions`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `AmbientOcclusionOptions.fromNative(ffi_gen.filament_ambient_occlusion_options out)`: `AmbientOcclusionOptions.fromNative(ffi_gen.filament_ambient_occlusion_options out)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `aoType` | `AmbientOcclusionType aoType` | `aoType` alanını (field/property) ve ilişkili veriyi saklar. |
| `radius` | `double radius` | `radius` alanını (field/property) ve ilişkili veriyi saklar. |
| `power` | `double power` | `power` alanını (field/property) ve ilişkili veriyi saklar. |
| `bias` | `double bias` | `bias` alanını (field/property) ve ilişkili veriyi saklar. |
| `resolution` | `double resolution` | `resolution` alanını (field/property) ve ilişkili veriyi saklar. |
| `intensity` | `double intensity` | `intensity` alanını (field/property) ve ilişkili veriyi saklar. |
| `bilateralThreshold` | `double bilateralThreshold` | `bilateralThreshold` alanını (field/property) ve ilişkili veriyi saklar. |
| `quality` | `QualityLevel quality` | `quality` alanını (field/property) ve ilişkili veriyi saklar. |
| `lowPassFilter` | `QualityLevel lowPassFilter` | `lowPassFilter` alanını (field/property) ve ilişkili veriyi saklar. |
| `upsampling` | `QualityLevel upsampling` | `upsampling` alanını (field/property) ve ilişkili veriyi saklar. |
| `enabled` | `bool enabled` | `enabled` alanını (field/property) ve ilişkili veriyi saklar. |
| `bentNormals` | `bool bentNormals` | `bentNormals` alanını (field/property) ve ilişkili veriyi saklar. |
| `minHorizonAngleRad` | `double minHorizonAngleRad` | `minHorizonAngleRad` alanını (field/property) ve ilişkili veriyi saklar. |
| `ssctLightConeRad` | `double ssctLightConeRad` | `ssctLightConeRad` alanını (field/property) ve ilişkili veriyi saklar. |
| `ssctShadowDistance` | `double ssctShadowDistance` | `ssctShadowDistance` alanını (field/property) ve ilişkili veriyi saklar. |
| `ssctContactDistanceMax` | `double ssctContactDistanceMax` | `ssctContactDistanceMax` alanını (field/property) ve ilişkili veriyi saklar. |
| `ssctIntensity` | `double ssctIntensity` | `ssctIntensity` alanını (field/property) ve ilişkili veriyi saklar. |
| `ssctLightDirectionX` | `double ssctLightDirectionX` | `ssctLightDirectionX` alanını (field/property) ve ilişkili veriyi saklar. |
| `ssctLightDirectionY` | `double ssctLightDirectionY` | `ssctLightDirectionY` alanını (field/property) ve ilişkili veriyi saklar. |
| `ssctLightDirectionZ` | `double ssctLightDirectionZ` | `ssctLightDirectionZ` alanını (field/property) ve ilişkili veriyi saklar. |
| `ssctDepthBias` | `double ssctDepthBias` | `ssctDepthBias` alanını (field/property) ve ilişkili veriyi saklar. |
| `ssctDepthSlopeBias` | `double ssctDepthSlopeBias` | `ssctDepthSlopeBias` alanını (field/property) ve ilişkili veriyi saklar. |
| `ssctSampleCount` | `int ssctSampleCount` | `ssctSampleCount` alanını (field/property) ve ilişkili veriyi saklar. |
| `ssctRayCount` | `int ssctRayCount` | `ssctRayCount` alanını (field/property) ve ilişkili veriyi saklar. |
| `ssctEnabled` | `bool ssctEnabled` | `ssctEnabled` alanını (field/property) ve ilişkili veriyi saklar. |
| `gtaoSampleSliceCount` | `int gtaoSampleSliceCount` | `gtaoSampleSliceCount` alanını (field/property) ve ilişkili veriyi saklar. |
| `gtaoSampleStepsPerSlice` | `int gtaoSampleStepsPerSlice` | `gtaoSampleStepsPerSlice` alanını (field/property) ve ilişkili veriyi saklar. |
| `gtaoThicknessHeuristic` | `double gtaoThicknessHeuristic` | `gtaoThicknessHeuristic` alanını (field/property) ve ilişkili veriyi saklar. |
| `gtaoUseVisibilityBitmasks` | `bool gtaoUseVisibilityBitmasks` | `gtaoUseVisibilityBitmasks` alanını (field/property) ve ilişkili veriyi saklar. |
| `gtaoConstThickness` | `double gtaoConstThickness` | `gtaoConstThickness` alanını (field/property) ve ilişkili veriyi saklar. |
| `gtaoLinearThickness` | `bool gtaoLinearThickness` | `gtaoLinearThickness` alanını (field/property) ve ilişkili veriyi saklar. |
| `hashCode` | `int get hashCode` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `copyToNative` | `void copyToNative(ffi_gen.filament_ambient_occlusion_options out)` | `copyToNative` işlemini gerçekleştirir. |

#### `class MultiSampleAntiAliasingOptions`

`MultiSampleAntiAliasingOptions`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `MultiSampleAntiAliasingOptions.fromNative(ffi_gen.filament_multi_sample_anti_aliasing_options out)`: `MultiSampleAntiAliasingOptions.fromNative(ffi_gen.filament_multi_sample_anti_aliasing_options out)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `enabled` | `bool enabled` | `enabled` alanını (field/property) ve ilişkili veriyi saklar. |
| `sampleCount` | `int sampleCount` | `sampleCount` alanını (field/property) ve ilişkili veriyi saklar. |
| `customResolve` | `bool customResolve` | `customResolve` alanını (field/property) ve ilişkili veriyi saklar. |
| `hashCode` | `int get hashCode` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `copyToNative` | `void copyToNative(ffi_gen.filament_multi_sample_anti_aliasing_options out)` | `copyToNative` işlemini gerçekleştirir. |

#### `enum TaaBoxType`

`TaaBoxType`: Sistemde kullanılan seçenekleri ve durumları listeleyen numaralandırma türüdür.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `aabbVariance` | `aabbVariance` | `aabbVariance` alanını (field/property) ve ilişkili veriyi saklar. |
| `toNative` | `int toNative()` | `toNative` işlemini gerçekleştirir. |
| `fromNative` | `static TaaBoxType fromNative(int val)` | `fromNative` işlemini gerçekleştirir. |

#### `enum TaaBoxClipping`

`TaaBoxClipping`: Sistemde kullanılan seçenekleri ve durumları listeleyen numaralandırma türüdür.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `none` | `none` | `none` alanını (field/property) ve ilişkili veriyi saklar. |
| `toNative` | `int toNative()` | `toNative` işlemini gerçekleştirir. |
| `fromNative` | `static TaaBoxClipping fromNative(int val)` | `fromNative` işlemini gerçekleştirir. |

#### `enum TaaJitterPattern`

`TaaJitterPattern`: Sistemde kullanılan seçenekleri ve durumları listeleyen numaralandırma türüdür.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `halton23X32` | `halton23X32` | `halton23X32` alanını (field/property) ve ilişkili veriyi saklar. |
| `toNative` | `int toNative()` | `toNative` işlemini gerçekleştirir. |
| `fromNative` | `static TaaJitterPattern fromNative(int val)` | `fromNative` işlemini gerçekleştirir. |

#### `class TemporalAntiAliasingOptions`

`TemporalAntiAliasingOptions`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `TemporalAntiAliasingOptions.fromNative(ffi_gen.filament_temporal_anti_aliasing_options out)`: `TemporalAntiAliasingOptions.fromNative(ffi_gen.filament_temporal_anti_aliasing_options out)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `filterWidth` | `double filterWidth` | `filterWidth` alanını (field/property) ve ilişkili veriyi saklar. |
| `feedback` | `double feedback` | `feedback` alanını (field/property) ve ilişkili veriyi saklar. |
| `lodBias` | `double lodBias` | `lodBias` alanını (field/property) ve ilişkili veriyi saklar. |
| `sharpness` | `double sharpness` | `sharpness` alanını (field/property) ve ilişkili veriyi saklar. |
| `enabled` | `bool enabled` | `enabled` alanını (field/property) ve ilişkili veriyi saklar. |
| `upscaling` | `double upscaling` | `upscaling` alanını (field/property) ve ilişkili veriyi saklar. |
| `filterHistory` | `bool filterHistory` | `filterHistory` alanını (field/property) ve ilişkili veriyi saklar. |
| `filterInput` | `bool filterInput` | `filterInput` alanını (field/property) ve ilişkili veriyi saklar. |
| `useYCoCg` | `bool useYCoCg` | `useYCoCg` alanını (field/property) ve ilişkili veriyi saklar. |
| `hdr` | `bool hdr` | `hdr` alanını (field/property) ve ilişkili veriyi saklar. |
| `boxType` | `TaaBoxType boxType` | `boxType` alanını (field/property) ve ilişkili veriyi saklar. |
| `boxClipping` | `TaaBoxClipping boxClipping` | `boxClipping` alanını (field/property) ve ilişkili veriyi saklar. |
| `jitterPattern` | `TaaJitterPattern jitterPattern` | `jitterPattern` alanını (field/property) ve ilişkili veriyi saklar. |
| `varianceGamma` | `double varianceGamma` | `varianceGamma` alanını (field/property) ve ilişkili veriyi saklar. |
| `preventFlickering` | `bool preventFlickering` | `preventFlickering` alanını (field/property) ve ilişkili veriyi saklar. |
| `historyReprojection` | `bool historyReprojection` | `historyReprojection` alanını (field/property) ve ilişkili veriyi saklar. |
| `motionVectors` | `bool motionVectors` | Structure pass'te piksel başına hareket vektörü üretir (pass bu durumda tam çözünürlükte çalışır) ve TAA geçmişini yalnızca kamera matrisleri yerine bu vektörlerle yeniden projekte eder; hareket eden, transform ile canlandırılan, skinned ve morph'lu nesnelerdeki gölgelenme (ghosting) biter (paylaşılan bir `SkinningBuffer` önceki paleti tutmaz). Tamponu `FilamentView.motionVectorTexture` / `MotionVectorBuffer` ile dışa aktarın; `FilamentView.motionVectorsSupported` gerekir. Varsayılan `false`. |
| `algorithm` | `TaaAlgorithm algorithm` | `TaaAlgorithm.filament` (Filament'in TAA'sı) ya da `TaaAlgorithm.fsr3`: structure pass hareket vektörleriyle (örtük) beslenen, fragment pass'lerden oluşan FidelityFX Super Resolution 3.1 upscaler; yalnızca `upscaling`, `sharpness`, `lodBias` ve `jitterPattern` geçerlidir; özellik düzeyi 1, stereo yok; harici bir upscaler (DLSS) önceliklidir. Varsayılan `filament`. |
| `frameGeneration` | `bool frameGeneration` | FSR3 kare üretimi: her çizilen kareden önce ara değerlenmiş bir kare sunulur (sunulan hız iki katı, yarım kare gecikme). `TaaAlgorithm.fsr3` ve koruma bandı olmadan swap chain'e çizen bir view gerekir; `SwapChainConfig.disableVsync` ile iki sunumu renderer zamanlar. Varsayılan `false`. |
| `hashCode` | `int get hashCode` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `copyToNative` | `void copyToNative(ffi_gen.filament_temporal_anti_aliasing_options out)` | `copyToNative` işlemini gerçekleştirir. |

#### `class ScreenSpaceReflectionsOptions`

`ScreenSpaceReflectionsOptions`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `ScreenSpaceReflectionsOptions.fromNative(ffi_gen.filament_screen_space_reflections_options out)`: `ScreenSpaceReflectionsOptions.fromNative(ffi_gen.filament_screen_space_reflections_options out)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `thickness` | `double thickness` | `thickness` alanını (field/property) ve ilişkili veriyi saklar. |
| `bias` | `double bias` | `bias` alanını (field/property) ve ilişkili veriyi saklar. |
| `maxDistance` | `double maxDistance` | `maxDistance` alanını (field/property) ve ilişkili veriyi saklar. |
| `stride` | `double stride` | `stride` alanını (field/property) ve ilişkili veriyi saklar. |
| `enabled` | `bool enabled` | `enabled` alanını (field/property) ve ilişkili veriyi saklar. |
| `hashCode` | `int get hashCode` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `copyToNative` | `void copyToNative(ffi_gen.filament_screen_space_reflections_options out)` | `copyToNative` işlemini gerçekleştirir. |

#### `class GuardBandOptions`

`GuardBandOptions`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `GuardBandOptions.fromNative(ffi_gen.filament_guard_band_options out)`: `GuardBandOptions.fromNative(ffi_gen.filament_guard_band_options out)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `enabled` | `bool enabled` | `enabled` alanını (field/property) ve ilişkili veriyi saklar. |
| `hashCode` | `int get hashCode` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `copyToNative` | `void copyToNative(ffi_gen.filament_guard_band_options out)` | `copyToNative` işlemini gerçekleştirir. |

#### `enum AntiAliasing`

`AntiAliasing`: Sistemde kullanılan seçenekleri ve durumları listeleyen numaralandırma türüdür.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `fxaa` | `fxaa` | `fxaa` alanını (field/property) ve ilişkili veriyi saklar. |
| `toNative` | `int toNative()` | `toNative` işlemini gerçekleştirir. |
| `fromNative` | `static AntiAliasing fromNative(int val)` | `fromNative` işlemini gerçekleştirir. |

#### `enum Dithering`

`Dithering`: Sistemde kullanılan seçenekleri ve durumları listeleyen numaralandırma türüdür.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `temporal` | `temporal` | `temporal` alanını (field/property) ve ilişkili veriyi saklar. |
| `toNative` | `int toNative()` | `toNative` işlemini gerçekleştirir. |
| `fromNative` | `static Dithering fromNative(int val)` | `fromNative` işlemini gerçekleştirir. |

#### `enum ShadowType`

`ShadowType`: Sistemde kullanılan seçenekleri ve durumları listeleyen numaralandırma türüdür.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `pcfd` | `pcfd` | `pcfd` alanını (field/property) ve ilişkili veriyi saklar. |
| `toNative` | `int toNative()` | `toNative` işlemini gerçekleştirir. |
| `fromNative` | `static ShadowType fromNative(int val)` | `fromNative` işlemini gerçekleştirir. |

#### `class VsmShadowOptions`

`VsmShadowOptions`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `VsmShadowOptions.fromNative(ffi_gen.filament_vsm_shadow_options out)`: `VsmShadowOptions.fromNative(ffi_gen.filament_vsm_shadow_options out)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `anisotropy` | `int anisotropy` | `anisotropy` alanını (field/property) ve ilişkili veriyi saklar. |
| `mipmapping` | `bool mipmapping` | `mipmapping` alanını (field/property) ve ilişkili veriyi saklar. |
| `msaaSamples` | `int msaaSamples` | `msaaSamples` alanını (field/property) ve ilişkili veriyi saklar. |
| `highPrecision` | `bool highPrecision` | `highPrecision` alanını (field/property) ve ilişkili veriyi saklar. |
| `minVarianceScale` | `double minVarianceScale` | `minVarianceScale` alanını (field/property) ve ilişkili veriyi saklar. |
| `lightBleedReduction` | `double lightBleedReduction` | `lightBleedReduction` alanını (field/property) ve ilişkili veriyi saklar. |
| `hashCode` | `int get hashCode` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `copyToNative` | `void copyToNative(ffi_gen.filament_vsm_shadow_options out)` | `copyToNative` işlemini gerçekleştirir. |

#### `class SoftShadowOptions`

`SoftShadowOptions`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `SoftShadowOptions.fromNative(ffi_gen.filament_soft_shadow_options out)`: `SoftShadowOptions.fromNative(ffi_gen.filament_soft_shadow_options out)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `penumbraScale` | `double penumbraScale` | `penumbraScale` alanını (field/property) ve ilişkili veriyi saklar. |
| `penumbraRatioScale` | `double penumbraRatioScale` | `penumbraRatioScale` alanını (field/property) ve ilişkili veriyi saklar. |
| `maxPenumbraRatio` | `double maxPenumbraRatio` | `maxPenumbraRatio` alanını (field/property) ve ilişkili veriyi saklar. |
| `maxSearchRadius` | `double maxSearchRadius` | `maxSearchRadius` alanını (field/property) ve ilişkili veriyi saklar. |
| `hashCode` | `int get hashCode` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `copyToNative` | `void copyToNative(ffi_gen.filament_soft_shadow_options out)` | `copyToNative` işlemini gerçekleştirir. |

#### `class StereoscopicOptions`

`StereoscopicOptions`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `StereoscopicOptions.fromNative(ffi_gen.filament_stereoscopic_options out)`: `StereoscopicOptions.fromNative(ffi_gen.filament_stereoscopic_options out)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `enabled` | `bool enabled` | `enabled` alanını (field/property) ve ilişkili veriyi saklar. |
| `copyToNative` | `void copyToNative(ffi_gen.filament_stereoscopic_options out)` | `copyToNative` işlemini gerçekleştirir. |

---

[Önceki: Renderer, view'ler ve frame pacing](renderer-and-view.md) | [Üst: flutter_filament](index.md) | [Sonraki: Sahne ve geometri](scene-and-geometry.md)
