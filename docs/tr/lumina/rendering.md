[English](../../en/lumina/rendering.md)

# Render cihazları

Engine'in hangi GPU üzerinde render ettiği ve render işlemini neyin yaptığı: Vulkan cihazlarını listeleme, tercih edilen cihazı sonradan oluşturulan her engine'e uygulama ve kullanılan Filament sürümünü ve backend'i bildirme. Dosya yolları `lumina/` paket dizinine görelidir.

## `lib/src/rendering/graphics_device.dart`

### `class LuminaGraphicsDevice`

A GPU the engine can render on (Vulkan device).

**Yapıcı Metotlar (Constructors):**

- `const LuminaGraphicsDevice({required this.name, required this.typeLabel, required this.index, required this.isDiscrete})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `name` | `final String name` |  |
| `typeLabel` | `final String typeLabel` |  |
| `index` | `final int index` |  |
| `isDiscrete` | `final bool isDiscrete` |  |
| `label` | `String get label` | `NVIDIA RTX PRO 2000 Blackwell · Discrete`. |

### `abstract final class LuminaGraphicsDevices`

Which GPU the editor renders on: lists the Vulkan devices, applies the saved choice to every engine created afterwards, and tracks the device the running engine actually uses.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `inUse` | `static final ValueNotifier<String?> inUse` | The device of the most recent engine [reportEngine] saw; null until one exists (or on a non-Vulkan backend). |
| `list` | `static List<LuminaGraphicsDevice> list()` |  |
| `matches` | `static bool matches(String deviceName)` | Whether [deviceName] still names one of this machine's devices. |
| `describeOverride` | `static String? describeOverride(Map<String, String> environment)` | `FILAMENT_GPU=…` or `VK_DEVICE_INDEX=…` when the environment chooses the GPU (smoke and CI runs); null otherwise. |
| `environmentOverride` | `static String? get environmentOverride` |  |
| `usePreferred` | `static void usePreferred(String? deviceName, {Map<String, String>? environment})` | Makes [deviceName] (null = automatic) the GPU of every engine created from now on. An environment override wins: the preference then stays automatic so flutter_filament reads the environment. |
| `reportEngine` | `static void reportEngine(FilamentEngine engine)` | Records the device [engine] renders on, for the status bar and the launcher's "(in use)" mark. |

## `lib/src/rendering/render_backend_info.dart`

### `abstract final class LuminaRenderBackendInfo`

What renders Lumina: the Filament release the engine is linked against and its material version, read from the library at runtime, plus Filament's credit. The editor reads these here and never imports flutter_filament for them.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `filamentVersion` | `static String get filamentVersion` | The linked Filament release, e.g. `1.77.0`. |
| `filamentMaterialVersion` | `static int get filamentMaterialVersion` | The material package version the linked Filament accepts. |
| `filamentLicense` | `static const String filamentLicense` |  |
| `filamentUrl` | `static const String filamentUrl` |  |

---

[Önceki: Materyaller ve post-processing](materials-and-post-process.md) | [Üst: lumina (engine çekirdeği)](index.md) | [Sonraki: Oyun çatısı (game framework)](game.md)
