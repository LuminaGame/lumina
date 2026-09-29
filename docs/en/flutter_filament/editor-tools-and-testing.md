[Türkçe](../../tr/flutter_filament/editor-tools-and-testing.md)

# Editor primitives, tools and testing

Helpers used by the editor and by tests: the editor grid, selection box and transform gizmo primitives, the offline tools (mipmaps, specular F0, image diff) and `package:flutter_filament/testing.dart`, which re-exports the smoke-test helpers of `lumina_smoke`. File paths are relative to the `flutter_filament/` package directory.

**On this page:**

- [Native C bridge](#native-c-bridge)
  - [`src/tools_c.h`](#srctools_ch)
- [Dart API](#dart-api)
  - [`lib/src/editor_primitives.dart`](#libsrceditor_primitivesdart)
  - [`lib/src/tools.dart`](#libsrctoolsdart)
  - [`lib/testing.dart`](#libtestingdart)

## Native C bridge

The C functions below are declared in the package's `src/` headers and called from Dart through FFI.

### `src/tools_c.h`

| C Function | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `filament_tools_inspect_material_json` | `FFI_PLUGIN_EXPORT char* filament_tools_inspect_material_json(const ...` | Executes native Filament `filament_tools_inspect_material_json` C binding. |
| `filament_tools_inspect_material_text` | `FFI_PLUGIN_EXPORT char* filament_tools_inspect_material_text(const ...` | Executes native Filament `filament_tools_inspect_material_text` C binding. |
| `filament_tools_generate_mipmap_level_rgba8` | `FFI_PLUGIN_EXPORT uint8_t filament_tools_generate_mipmap_level_rgba...` | Executes native Filament `filament_tools_generate_mipmap_level_rgba8` C binding. |
| `filament_tools_free_string` | `FFI_PLUGIN_EXPORT void filament_tools_free_string(char* str);` | Executes native Filament `filament_tools_free_string` C binding. |
| `filament_tools_free_buffer` | `FFI_PLUGIN_EXPORT void filament_tools_free_buffer(void* ptr);` | Executes native Filament `filament_tools_free_buffer` C binding. |

## Dart API

### `lib/src/editor_primitives.dart`

#### `class FilamentEditorGrid`

Manages native Filament 3D GPU Editor Floor Grid and World Axes.

**Constructors:**
- `FilamentEditorGrid._(this.engine, this._mesh)`: Initializes `FilamentEditorGrid._(this.engine, this._mesh)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `engine` | `FilamentEngine engine` | Holds the `engine` property or configuration state. |
| `entityId` | `int? get entityId` | Getter accessor returning the current value of `entityId`. |
| `isDisposed` | `bool get isDisposed` | Checks current state or capability and returns a boolean value. |
| `addToScene` | `void addToScene(FilamentScene scene)` | Appends a new item to the collection or scene. |
| `removeFromScene` | `void removeFromScene(FilamentScene scene)` | Releases and safely disposes the specified `FromScene` resource. |
| `dispose` | `void dispose()` | Releases native FFI pointers, event subscriptions, and allocated memory. |

#### `class FilamentSelectionBox`

Manages native Filament 3D GPU Selection Bounding Box around active actor.

**Constructors:**
- `FilamentSelectionBox(this.engine)`: Initializes `FilamentSelectionBox(this.engine)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `engine` | `FilamentEngine engine` | Holds the `engine` property or configuration state. |
| `entityId` | `int? get entityId` | Getter accessor returning the current value of `entityId`. |
| `isDisposed` | `bool get isDisposed` | Checks current state or capability and returns a boolean value. |
| `isInScene` | `bool get isInScene` | Checks current state or capability and returns a boolean value. |
| `setTransform` | `void setTransform(List<double> transformMatrix16)` | Sets world transform matrix for the selection bounding box entity. |
| `addToScene` | `void addToScene(FilamentScene scene)` | Appends a new item to the collection or scene. |
| `removeFromScene` | `void removeFromScene(FilamentScene scene)` | Releases and safely disposes the specified `FromScene` resource. |
| `dispose` | `void dispose()` | Releases native FFI pointers, event subscriptions, and allocated memory. |

#### `enum GizmoMode`

Manages native Filament 3D GPU Transform Gizmo (Translate, Rotate, Scale).

#### `class FilamentTransformGizmo`

`FilamentTransformGizmo`: `class` representing the data model or functionality of the module.

**Constructors:**
- `FilamentTransformGizmo(this.engine)`: Initializes `FilamentTransformGizmo(this.engine)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `engine` | `FilamentEngine engine` | Holds the `engine` property or configuration state. |
| `isDisposed` | `bool get isDisposed` | Checks current state or capability and returns a boolean value. |
| `isInScene` | `bool get isInScene` | Checks current state or capability and returns a boolean value. |
| `mode` | `GizmoMode get mode` | Getter accessor returning the current value of `mode`. |
| `handleIds` | `List<String> get handleIds` | Handle identifiers currently built for [mode] (e.g. `x`, `y`, `z`, `xy`). |
| `lastTransform` | `List<double> get lastTransform` | The 4x4 column-major transform matrix last sent to Filament. |
| `entityIds` | `List<int> get entityIds` | Entity ids of every handle mesh, in [handleIds] order. |
| `entityIdOf` | `int? entityIdOf(String handleId)` | Entity id of the handle named [handleId], or null when it does not exist. |
| `setMode` | `void setMode(GizmoMode newMode)` | Updates the `Mode` parameter and applies changes to the system. |
| `defaultHandleColor` | `static List<double> defaultHandleColor(String handleId)` | The colour a handle carries when nothing is hovered: red X, green Y, blue Z, white for the uniform/centre handle. |
| `handlesAreColourable` | `bool get handlesAreColourable` | Whether every handle owns a compiled material instance. False means the wireframe material did not compile and the manipulator renders white whatever colour is set on it. |
| `colorOf` | `List<double>? colorOf(String handleId)` | The rgba a handle is currently painted, or null when there is no such handle in the current mode. |
| `setHandleHighlight` | `void setHandleHighlight(String handleId, bool isHighlighted)` | Updates the `HandleHighlight` parameter and applies changes to the system. |
| `setAllHandlesDimmed` | `void setAllHandlesDimmed(String? activeHandle)` | Paints [activeHandle] as the one under the pointer and leaves every other handle at its axis colour. Passing null returns all of them to their axis colours. |
| `setPosition` | `void setPosition(double x, double y, double z, [double scale = 1.0])` | Updates the `Position` parameter and applies changes to the system. |
| `addToScene` | `void addToScene(FilamentScene scene)` | Appends a new item to the collection or scene. |
| `removeFromScene` | `void removeFromScene(FilamentScene scene)` | Releases and safely disposes the specified `FromScene` resource. |
| `dispose` | `void dispose()` | Releases native FFI pointers, event subscriptions, and allocated memory. |

### `lib/src/tools.dart`

#### `class MipmapResult`

Mipmap generation result container.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `pixels` | `Uint8List pixels` | Holds the `pixels` property or configuration state. |
| `width` | `int width` | Holds the `width` property or configuration state. |
| `height` | `int height` | Holds the `height` property or configuration state. |

#### `class SpecularF0Result`

RGB Color vector container for specular reflectance F0.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `r` | `double r` | Holds the `r` property or configuration state. |
| `g` | `double g` | Holds the `g` property or configuration state. |
| `b` | `double b` | Holds the `b` property or configuration state. |

#### `class ImageDiffResult`

Image diff comparison result container (`diffimg` tool).

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `meanError` | `double meanError` | Holds the `meanError` property or configuration state. |
| `maxError` | `double maxError` | Holds the `maxError` property or configuration state. |
| `diffPixels` | `Uint8List diffPixels` | Holds the `diffPixels` property or configuration state. |

#### `class FilamentTools`

Native C/FFI integrated Filament Tools utility suite.  Provides zero-subprocess, native in-process access to Filament tools including: - Material binary inspection (JSON & Text format via `matdbg`) - Binary asset encoding into C++ header code (`resgen`) - Box-filtered RGBA8 texture mipmap level generation (`mipgen`) - GLSL shader minifier & comment stripper (`glslminifier`) - Reoriented Normal Mapping (RNM) normal map blending (`normal-blending`) - Dielectric & Conductor Fresnel F0 reflectance calculations (`specular-color`) - Spherical Harmonics 3rd-order diffuse IBL calculation (`cmgen`) - Image visual diff & comparison metrics (`diffimg`) - Specular Ambient Occlusion LUT calculation (`cso-lut`) - ZSTD archive compression & decompression (`uberz`) - Frame pipeline render debug visualizer dump (`frame_pipeline_visualizer`)

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `inspectMaterialJson` | `static String? inspectMaterialJson(Uint8List filamatBuffer)` | Inspects a compiled `.filamat` binary buffer natively via FFI and returns a JSON metadata string. |
| `inspectMaterialText` | `static String? inspectMaterialText(Uint8List filamatBuffer)` | Inspects a compiled `.filamat` binary buffer natively via FFI and returns a human-readable text summary string. |
| `minifyGlsl` | `static String? minifyGlsl(String glslCode)` | Minifies GLSL shader source code by removing comments, empty lines, and indentation (`glslminifier` tool). |
| `computeDielectricF0` | `static double computeDielectricF0(double ior)` | Computes dielectric specular reflectance F0 from Index of Refraction (IOR) (`specular-color` tool). |
| `zstdCompress` | `static Uint8List? zstdCompress(Uint8List data)` | Compresses binary buffer using ZSTD algorithm (`uberz` tool). |
| `zstdDecompress` | `static Uint8List? zstdDecompress(Uint8List compressedData)` | Decompresses ZSTD compressed binary buffer (`uberz` tool). |

### `lib/testing.dart`

The smoke-test helpers come from the `lumina_smoke` package of the tools repository: `package:flutter_filament/testing.dart` re-exports `package:lumina_smoke/lumina_smoke.dart` (`SmokeArtifacts`, `SmokeVideo`, `SmokeVideoRecorder`, `SmokeWebm` and the rest). See [lumina_smoke](https://github.com/LuminaGame/tools/tree/main/docs) for the API. For tests only; `flutter_filament.dart` does not export it.

---

[Previous: Math types](math.md) | [Up: flutter_filament](index.md) | [Next: Platform integration and GPU selection](platform.md)
