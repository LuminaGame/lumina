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
| `inUse` | `static final ObservableValue<String?> inUse` | [reportEngine]'in gördüğü son engine'in cihazı; biri oluşana dek (ya da Vulkan olmayan bir backend'de) null. Bir widget `asValueListenable()` ile dinler (`lumina_widgets`). |
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
| `filamentVersion` | `static String get filamentVersion` | The linked Filament release, e.g. `1.77.2`. |
| `filamentMaterialVersion` | `static int get filamentMaterialVersion` | The material package version the linked Filament accepts. |
| `filamentLicense` | `static const String filamentLicense` |  |
| `filamentUrl` | `static const String filamentUrl` |  |

---

[Önceki: Materyaller ve post-processing](materials-and-post-process.md) | [Üst: lumina (engine çekirdeği)](index.md) | [Sonraki: Oyun çatısı (game framework)](game.md)

## Nöral render: OpenDLSS-NR (deneysel, üçüncü taraf)

`lib/src/post_process/neural_rendering/`, [OpenDLSS-NR geçişini](../flutter_filament/opendlss-nr.md) Lumina'nın view'larında çalıştırır. OpenDLSS-NR, NVIDIA'nın DLSS 5 nöral render'ının üçüncü taraf, resmî olmayan bir yeniden uygulamasıdır; NVIDIA'nın model ağırlıklarına ihtiyaç duyar ve Lumina bunları sağlamaz, dağıtmaz, nasıl edinileceğini de anlatmaz. Bir proje isteğe bağlı olarak açmadıkça kapalıdır (Proje Ayarları ▸ Neural rendering, kullanıcının onaylaması gereken bir uyarının arkasında).

- `ProjectNeuralRenderingSettings` (`lumina_core`, `.lmproject` içinde `neural_rendering`): `enabled`, `acknowledgedAt`, `weightsPath` (makineye özgü), `intensity`, `localTone`, `localStructure`, `autoMask`, `style` (`none` / `natural` / `cinematic`), `paperWhite`, `colorStrength`; `active` = açık ve onaylanmış.
- `LuminaNeuralRendering`: `projectOptIn` (yalnızca projesi açtıysa üretilen oyunun `main()`'i tarafından, ağırlık yolu olmadan ayarlanır), `editorWeightsPath`, `resolveWeightsPath()` (editör yolu, sonra oyuncunun `GameUserSettings.json` içindeki `neural_rendering_weights` değeri, sonra `LUMINA_OPENDLSS_NR_WEIGHTS` ortam değişkeni), `requestDeviceFeatures()` (`LuminaRtxController.requestExtensions(neuralRendering: true)` ile: editör her zaman, oyun yalnızca açtıysa).
- `LuminaNeuralRenderingController(engine, view)`: `apply(settings, weightsPath:)` GPU'yu denetler, ağırlıkları arka plan isolate'lerinde doğrular ve yükler, geçişi kaydeder; `status` (`LuminaNeuralRenderingStatus`: `off`, `unsupported`, `weightsMissing`, `invalidWeights`, `loading`, GPU süresiyle `running`, `failed`) nedeniyle birlikte, bir kez loglanır; `tick()` kendini kapatan geçişi bırakır.
- Oyunlar: `LuminaUserSettingsSubsystem` (`LuminaUserSettingsNeuralRendering` mixin'i) isteği dünyanın view'ına uygular; `setNeuralRenderingWeightsPath` oyuncunun klasörünü hazırlar, `GameUserSettings.json`'da saklanır. **Paketlenmiş bir oyun asla ağırlık içermez**; klasör yoksa geçiş kapalı kalır ve log nereden ayarlanacağını söyler.
