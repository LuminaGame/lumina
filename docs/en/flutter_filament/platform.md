[Türkçe](../../tr/flutter_filament/platform.md)

# Platform integration and GPU selection

Platform glue of the bindings: the engine host that shares one Filament engine per backend and GPU through leases, the Vulkan GPU listing and preference, `FilamentWeb` start-up on the web and natively, and the native and web variants of the Flutter widget. File paths are relative to the `flutter_filament/` package directory.

**On this page:**

- [`lib/src/engine_host.dart`](#libsrcengine_hostdart)
- [`lib/src/gpu.dart`](#libsrcgpudart)
- [`lib/src/web_init_native.dart`](#libsrcweb_init_nativedart)
- [`lib/src/web_init_web.dart`](#libsrcweb_init_webdart)
- [`lib/src/widget_native.dart`](#libsrcwidget_nativedart)
- [`lib/src/widget_web.dart`](#libsrcwidget_webdart)

## `lib/src/engine_host.dart`

### `class FilamentEngineLease`

A claim on a shared [FilamentEngine].

Every holder — a viewport, a thumbnail renderer, a sub-editor that frees engine objects in its own `dispose` — takes one and releases it when it is done with the engine. The engine stays alive while any lease is held and is destroyed by [FilamentEngineHost] after the last [release], once its engine-scoped resources are gone.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `owner` | `final String owner` | Who holds this lease, for leak reports (`FilamentEngineHost.leaseOwners`). |
| `engine` | `FilamentEngine get engine` | The shared engine. Throws after [release]. |
| `isReleased` | `bool get isReleased` | Whether [release] was called. |
| `release` | `void release()` | Gives the engine back. The last release destroys it (engine-scoped resources first). Calling it again does nothing. |

### `abstract final class FilamentEngineHost`

One Filament engine per process and GPU, shared by every viewport.

Engines are keyed by backend and GPU preference (`gpu`, else [FilamentEngine.defaultGpuPreference] at the time of the call), so viewports asking for the same GPU share one engine, and changing the preference gives new viewports a new engine while existing ones keep theirs. Each viewport still owns its own swap chain, renderer, view, scene and camera on it.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `acquire` | `static FilamentEngineLease? acquire({String owner = 'anonymous', FilamentBackend backend = FilamentBackend.def...` | A lease on the shared engine for [backend] and [gpu], creating the engine (with [config], only used then) when there is none. Null when no engine can be created on this host. |
| `retain` | `static FilamentEngineLease? retain(FilamentEngine engine, {String owner = 'anonymous'})` | Another lease on [engine] if the host owns it; null for an engine created directly with `FilamentEngine.create` (its creator owns it). |
| `owns` | `static bool owns(FilamentEngine engine)` | Whether the host owns [engine]. |
| `leaseCount` | `static int leaseCount(FilamentEngine engine)` | How many leases hold [engine] (0 when the host does not own it). |
| `leaseOwners` | `static List<String> leaseOwners(FilamentEngine engine)` | The owners of [engine]'s leases, in the order they were taken. |
| `liveEngines` | `static List<FilamentEngine> get liveEngines` | The engines the host currently owns. |
| `liveEngineCount` | `static int get liveEngineCount` | How many engines the host currently owns. |

## `lib/src/gpu.dart`

### `enum FilamentGpuType`

The kind of a Vulkan physical device (`VkPhysicalDeviceType`).

**Values:**

- `other`
- `integrated`
- `discrete`
- `virtualGpu`
- `cpu`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `fromVulkan` | `static FilamentGpuType fromVulkan(int type)` |  |
| `label` | `String get label` | A short label for pickers: Discrete, Integrated, Virtual, CPU, Other. |

### `class FilamentGpuInfo`

One Vulkan device, as the system loader enumerates it.

**Constructors:**

- `const FilamentGpuInfo({required this.name, required this.type, required this.vendorId, required this.deviceId, required this.index,})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `name` | `final String name` |  |
| `type` | `final FilamentGpuType type` |  |
| `vendorId` | `final int vendorId` |  |
| `deviceId` | `final int deviceId` |  |
| `index` | `final int index` | Position in the loader's enumeration: the index a [FilamentGpuPreference] or `VK_DEVICE_INDEX` refers to. |

### `class FilamentGpuPreference`

Which GPU a Vulkan engine should render on: a device-name substring, an enumeration index, or neither ([automatic], Filament's own choice unless the environment sets `FILAMENT_GPU` / `VK_DEVICE_INDEX`). Other backends ignore it.

**Constructors:**

- `const FilamentGpuPreference({this.deviceName, this.index})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `deviceName` | `final String? deviceName` |  |
| `index` | `final int? index` |  |
| `automatic` | `static const FilamentGpuPreference automatic` |  |
| `isAutomatic` | `bool get isAutomatic` |  |

### `abstract final class FilamentGpu`

Lists the GPUs a Vulkan engine can render on.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `listVulkanDevices` | `static List<FilamentGpuInfo> listVulkanDevices()` | Enumerates the Vulkan devices through the system loader, independently of any engine. Empty when Vulkan is unavailable (and on the web). |
| `livePlatformCount` | `static int get livePlatformCount` | Vulkan platforms alive in this process: one per Vulkan engine not yet disposed. For leak checks. |

## `lib/src/web_init_native.dart`

### `abstract final class FilamentWeb`

Platform initialisation for flutter_filament.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `ensureInitialized` | `static Future<void> ensureInitialized({String moduleUrl = 'flutter_filament.js'}) async` | Native platforms link the library at build time: nothing to do. |
| `isWeb` | `static const bool isWeb` | Whether this is a web build. |

## `lib/src/web_init_web.dart`

### `abstract final class FilamentWeb`

Platform initialisation for flutter_filament.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `ensureInitialized` | `static Future<void> ensureInitialized({String moduleUrl = 'flutter_filament.js'}) async` | Loads the WebAssembly module (`flutter_filament.js` + `.wasm` from [moduleUrl]'s directory) and registers the generated struct layouts and callback types. Call once before using any flutter_filament API on the web. Idempotent. |
| `isWeb` | `static const bool isWeb` | Whether this is a web build. |

## `lib/src/widget_native.dart`

### `class NativeFilamentWidgetState`

**Top-level functions and variables:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `createFilamentWidgetState` | `State<FilamentWidget> createFilamentWidgetState()` | Native platforms: render into a headless swap chain and present the readback through a [RawImage]. |

## `lib/src/widget_web.dart`

### `class WebFilamentWidgetState`

**Top-level functions and variables:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `createFilamentWidgetState` | `State<FilamentWidget> createFilamentWidgetState()` | Web builds: Filament's WebGL2 backend presents straight into a `<canvas>` hosted by a platform view — no readback, no decode. |

---

[Previous: Editor primitives, tools and testing](editor-tools-and-testing.md) | [Up: flutter_filament](index.md) | [Next: lumina (engine core)](../lumina/index.md)
