[Türkçe](../../tr/lumina/rendering.md)

# Rendering devices

Which GPU the engine renders on and what renders it: listing the Vulkan devices, applying a preferred device to every engine created afterwards, and reporting the Filament release and backend in use. File paths are relative to the `lumina/` package directory.

## `lib/src/rendering/graphics_device.dart`

### `class LuminaGraphicsDevice`

A GPU the engine can render on (Vulkan device).

**Constructors:**

- `const LuminaGraphicsDevice({required this.name, required this.typeLabel, required this.index, required this.isDiscrete})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `name` | `final String name` |  |
| `typeLabel` | `final String typeLabel` |  |
| `index` | `final int index` |  |
| `isDiscrete` | `final bool isDiscrete` |  |
| `label` | `String get label` | `NVIDIA RTX PRO 2000 Blackwell · Discrete`. |

### `abstract final class LuminaGraphicsDevices`

Which GPU the editor renders on: lists the Vulkan devices, applies the saved choice to every engine created afterwards, and tracks the device the running engine actually uses.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `inUse` | `static final ObservableValue<String?> inUse` | The device of the most recent engine [reportEngine] saw; null until one exists (or on a non-Vulkan backend). A widget listens through `asValueListenable()` (`lumina_widgets`). |
| `list` | `static List<LuminaGraphicsDevice> list()` |  |
| `matches` | `static bool matches(String deviceName)` | Whether [deviceName] still names one of this machine's devices. |
| `describeOverride` | `static String? describeOverride(Map<String, String> environment)` | `FILAMENT_GPU=…` or `VK_DEVICE_INDEX=…` when the environment chooses the GPU (smoke and CI runs); null otherwise. |
| `environmentOverride` | `static String? get environmentOverride` |  |
| `usePreferred` | `static void usePreferred(String? deviceName, {Map<String, String>? environment})` | Makes [deviceName] (null = automatic) the GPU of every engine created from now on. An environment override wins: the preference then stays automatic so flutter_filament reads the environment. |
| `reportEngine` | `static void reportEngine(FilamentEngine engine)` | Records the device [engine] renders on, for the status bar and the launcher's "(in use)" mark. |

## `lib/src/rendering/render_backend_info.dart`

### `abstract final class LuminaRenderBackendInfo`

What renders Lumina: the Filament release the engine is linked against and its material version, read from the library at runtime, plus Filament's credit. The editor reads these here and never imports flutter_filament for them.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `filamentVersion` | `static String get filamentVersion` | The linked Filament release, e.g. `1.77.2`. |
| `filamentMaterialVersion` | `static int get filamentMaterialVersion` | The material package version the linked Filament accepts. |
| `filamentLicense` | `static const String filamentLicense` |  |
| `filamentUrl` | `static const String filamentUrl` |  |

---

[Previous: Materials and post-processing](materials-and-post-process.md) | [Up: lumina (engine core)](index.md) | [Next: Game framework](game.md)
