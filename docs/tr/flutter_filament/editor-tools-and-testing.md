[English](../../en/flutter_filament/editor-tools-and-testing.md)

# Editör primitifleri, araçlar ve test

Editörün ve testlerin kullandığı yardımcılar: editör grid'i, seçim kutusu ve transform gizmo primitifleri, offline araçlar (mipmap, specular F0, görsel karşılaştırma) ve `lumina_smoke`'un smoke test yardımcılarını yeniden export eden `package:flutter_filament/testing.dart`. Dosya yolları `flutter_filament/` paket dizinine görelidir.

**Bu sayfada:**

- [Native C köprüsü](#native-c-köprüsü)
  - [`src/tools_c.h`](#srctools_ch)
- [Dart API](#dart-api)
  - [`lib/src/editor_primitives.dart`](#libsrceditor_primitivesdart)
  - [`lib/src/tools.dart`](#libsrctoolsdart)
  - [`lib/testing.dart`](#libtestingdart)

## Native C köprüsü

Aşağıdaki C fonksiyonları paketin `src/` header'larında tanımlanır ve Dart'tan FFI ile çağrılır.

### `src/tools_c.h`

| C Fonksiyonu | İmzası | Açıklama ve Ne İşe Yaradığı |
| :--- | :--- | :--- |
| `filament_tools_inspect_material_json` | `FFI_PLUGIN_EXPORT char* filament_tools_inspect_material_json(const ...` | Filament yerel `filament_tools_inspect_material_json` C fonksiyonunu çalıştırır. |
| `filament_tools_inspect_material_text` | `FFI_PLUGIN_EXPORT char* filament_tools_inspect_material_text(const ...` | Filament yerel `filament_tools_inspect_material_text` C fonksiyonunu çalıştırır. |
| `filament_tools_generate_mipmap_level_rgba8` | `FFI_PLUGIN_EXPORT uint8_t filament_tools_generate_mipmap_level_rgba...` | Filament yerel `filament_tools_generate_mipmap_level_rgba8` C fonksiyonunu çalıştırır. |
| `filament_tools_free_string` | `FFI_PLUGIN_EXPORT void filament_tools_free_string(char* str);` | Filament yerel `filament_tools_free_string` C fonksiyonunu çalıştırır. |
| `filament_tools_free_buffer` | `FFI_PLUGIN_EXPORT void filament_tools_free_buffer(void* ptr);` | Filament yerel `filament_tools_free_buffer` C fonksiyonunu çalıştırır. |

## Dart API

### `lib/src/editor_primitives.dart`

#### `class FilamentEditorGrid`

Manages native Filament 3D GPU Editor Floor Grid and World Axes.

**Yapıcı Metotlar (Constructors):**
- `FilamentEditorGrid._(this.engine, this._mesh)`: `FilamentEditorGrid._(this.engine, this._mesh)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `engine` | `FilamentEngine engine` | `engine` alanını (field/property) ve ilişkili veriyi saklar. |
| `entityId` | `int? get entityId` | `entityId` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `isDisposed` | `bool get isDisposed` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `addToScene` | `void addToScene(FilamentScene scene)` | Koleksiyona veya sahneye yeni bir öğe ekler. |
| `removeFromScene` | `void removeFromScene(FilamentScene scene)` | Belirtilen `FromScene` nesnesini/bileşenini serbest bırakır ve güvenle temizler. |
| `dispose` | `void dispose()` | Yerel FFI göstericilerini, dinleyicileri ve bellek bloklarını serbest bırakır. |

#### `class FilamentSelectionBox`

Manages native Filament 3D GPU Selection Bounding Box around active actor.

**Yapıcı Metotlar (Constructors):**
- `FilamentSelectionBox(this.engine)`: `FilamentSelectionBox(this.engine)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `engine` | `FilamentEngine engine` | `engine` alanını (field/property) ve ilişkili veriyi saklar. |
| `entityId` | `int? get entityId` | `entityId` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `isDisposed` | `bool get isDisposed` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `isInScene` | `bool get isInScene` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `setTransform` | `void setTransform(List<double> transformMatrix16)` | Sets world transform matrix for the selection bounding box entity. |
| `addToScene` | `void addToScene(FilamentScene scene)` | Koleksiyona veya sahneye yeni bir öğe ekler. |
| `removeFromScene` | `void removeFromScene(FilamentScene scene)` | Belirtilen `FromScene` nesnesini/bileşenini serbest bırakır ve güvenle temizler. |
| `dispose` | `void dispose()` | Yerel FFI göstericilerini, dinleyicileri ve bellek bloklarını serbest bırakır. |

#### `enum GizmoMode`

Manages native Filament 3D GPU Transform Gizmo (Translate, Rotate, Scale).

#### `class FilamentTransformGizmo`

`FilamentTransformGizmo`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `FilamentTransformGizmo(this.engine)`: `FilamentTransformGizmo(this.engine)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `engine` | `FilamentEngine engine` | `engine` alanını (field/property) ve ilişkili veriyi saklar. |
| `isDisposed` | `bool get isDisposed` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `isInScene` | `bool get isInScene` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `mode` | `GizmoMode get mode` | `mode` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `handleIds` | `List<String> get handleIds` | Handle identifiers currently built for [mode] (e.g. `x`, `y`, `z`, `xy`). |
| `lastTransform` | `List<double> get lastTransform` | The 4x4 column-major transform matrix last sent to Filament. |
| `entityIds` | `List<int> get entityIds` | Entity ids of every handle mesh, in [handleIds] order. |
| `entityIdOf` | `int? entityIdOf(String handleId)` | Entity id of the handle named [handleId], or null when it does not exist. |
| `setMode` | `void setMode(GizmoMode newMode)` | `Mode` parametresini günceller ve sisteme uygular. |
| `defaultHandleColor` | `static List<double> defaultHandleColor(String handleId)` | The colour a handle carries when nothing is hovered: red X, green Y, blue Z, white for the uniform/centre handle. |
| `handlesAreColourable` | `bool get handlesAreColourable` | Whether every handle owns a compiled material instance. False means the wireframe material did not compile and the manipulator renders white whatever colour is set on it. |
| `colorOf` | `List<double>? colorOf(String handleId)` | The rgba a handle is currently painted, or null when there is no such handle in the current mode. |
| `setHandleHighlight` | `void setHandleHighlight(String handleId, bool isHighlighted)` | `HandleHighlight` parametresini günceller ve sisteme uygular. |
| `setAllHandlesDimmed` | `void setAllHandlesDimmed(String? activeHandle)` | Paints [activeHandle] as the one under the pointer and leaves every other handle at its axis colour. Passing null returns all of them to their axis colours. |
| `setPosition` | `void setPosition(double x, double y, double z, [double scale = 1.0])` | `Position` parametresini günceller ve sisteme uygular. |
| `addToScene` | `void addToScene(FilamentScene scene)` | Koleksiyona veya sahneye yeni bir öğe ekler. |
| `removeFromScene` | `void removeFromScene(FilamentScene scene)` | Belirtilen `FromScene` nesnesini/bileşenini serbest bırakır ve güvenle temizler. |
| `dispose` | `void dispose()` | Yerel FFI göstericilerini, dinleyicileri ve bellek bloklarını serbest bırakır. |

### `lib/src/tools.dart`

#### `class MipmapResult`

Mipmap generation result container.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `pixels` | `Uint8List pixels` | `pixels` alanını (field/property) ve ilişkili veriyi saklar. |
| `width` | `int width` | `width` alanını (field/property) ve ilişkili veriyi saklar. |
| `height` | `int height` | `height` alanını (field/property) ve ilişkili veriyi saklar. |

#### `class SpecularF0Result`

RGB Color vector container for specular reflectance F0.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `r` | `double r` | `r` alanını (field/property) ve ilişkili veriyi saklar. |
| `g` | `double g` | `g` alanını (field/property) ve ilişkili veriyi saklar. |
| `b` | `double b` | `b` alanını (field/property) ve ilişkili veriyi saklar. |

#### `class ImageDiffResult`

Image diff comparison result container (`diffimg` tool).

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `meanError` | `double meanError` | `meanError` alanını (field/property) ve ilişkili veriyi saklar. |
| `maxError` | `double maxError` | `maxError` alanını (field/property) ve ilişkili veriyi saklar. |
| `diffPixels` | `Uint8List diffPixels` | `diffPixels` alanını (field/property) ve ilişkili veriyi saklar. |

#### `class FilamentTools`

Native C/FFI integrated Filament Tools utility suite.  Provides zero-subprocess, native in-process access to Filament tools including: - Material binary inspection (JSON & Text format via `matdbg`) - Binary asset encoding into C++ header code (`resgen`) - Box-filtered RGBA8 texture mipmap level generation (`mipgen`) - GLSL shader minifier & comment stripper (`glslminifier`) - Reoriented Normal Mapping (RNM) normal map blending (`normal-blending`) - Dielectric & Conductor Fresnel F0 reflectance calculations (`specular-color`) - Spherical Harmonics 3rd-order diffuse IBL calculation (`cmgen`) - Image visual diff & comparison metrics (`diffimg`) - Specular Ambient Occlusion LUT calculation (`cso-lut`) - ZSTD archive compression & decompression (`uberz`) - Frame pipeline render debug visualizer dump (`frame_pipeline_visualizer`)

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `inspectMaterialJson` | `static String? inspectMaterialJson(Uint8List filamatBuffer)` | Inspects a compiled `.filamat` binary buffer natively via FFI and returns a JSON metadata string. |
| `inspectMaterialText` | `static String? inspectMaterialText(Uint8List filamatBuffer)` | Inspects a compiled `.filamat` binary buffer natively via FFI and returns a human-readable text summary string. |
| `minifyGlsl` | `static String? minifyGlsl(String glslCode)` | Minifies GLSL shader source code by removing comments, empty lines, and indentation (`glslminifier` tool). |
| `computeDielectricF0` | `static double computeDielectricF0(double ior)` | Computes dielectric specular reflectance F0 from Index of Refraction (IOR) (`specular-color` tool). |
| `zstdCompress` | `static Uint8List? zstdCompress(Uint8List data)` | Compresses binary buffer using ZSTD algorithm (`uberz` tool). |
| `zstdDecompress` | `static Uint8List? zstdDecompress(Uint8List compressedData)` | Decompresses ZSTD compressed binary buffer (`uberz` tool). |

### `lib/testing.dart`

Smoke test yardımcıları tools repository'sindeki `lumina_smoke` paketinden gelir: `package:flutter_filament/testing.dart`, `package:lumina_smoke/lumina_smoke.dart`'ı (`SmokeArtifacts`, `SmokeVideo`, `SmokeVideoRecorder`, `SmokeWebm` ve diğerleri) yeniden export eder. API için bkz. [lumina_smoke](https://github.com/LuminaGame/tools/tree/main/docs). Yalnızca testler içindir; `flutter_filament.dart` bunu export etmez.

---

[Önceki: Matematik tipleri](math.md) | [Üst: flutter_filament](index.md) | [Sonraki: Platform entegrasyonu ve GPU seçimi](platform.md)
