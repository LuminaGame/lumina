[English](../../en/lumina/game.md)

# Oyun çatısı (game framework)

Bir dünyayı çalışan uygulamaya bağlayan oyun çatısı: game instance ve subsystem'leri, game mode ve game state, HUD overlay, `LuminaGame` ve `LuminaGameWidget`, play state, player camera manager, player start'lar, primitive actor'ler ve şablon character. Dosya yolları `lumina/` paket dizinine görelidir.

**Bu sayfada:**

- [`lib/src/game/game_instance.dart`](#libsrcgamegame_instancedart)
- [`lib/src/game/game_mode.dart`](#libsrcgamegame_modedart)
- [`lib/src/game/game_state.dart`](#libsrcgamegame_statedart)
- [`lib/src/game/lumina_game.dart`](#libsrcgamelumina_gamedart)
- [`lib/src/game/play_state.dart`](#libsrcgameplay_statedart)
- [`lib/src/game/player_camera_manager.dart`](#libsrcgameplayer_camera_managerdart)
- [`lib/src/game/player_start.dart`](#libsrcgameplayer_startdart)
- [`lib/src/game/primitive_actor.dart`](#libsrcgameprimitive_actordart)
- [`lib/src/game/template_character.dart`](#libsrcgametemplate_characterdart)
- [`lib/src/game/console.dart`](#libsrcgameconsoledart)
- [`lib/src/game/static_mesh_actor.dart`](#libsrcgamestatic_mesh_actordart)
- [`lib/src/game/template_clips.dart`](#libsrcgametemplate_clipsdart)
- [`lib/src/game/template_content.dart`](#libsrcgametemplate_contentdart)

## `lib/src/game/game_instance.dart`

### `class LuminaGameInstanceSubsystem`

Base class for global, lifetime-bound services attached to a [LuminaGameInstance].

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `owner` | `LuminaGameInstance? get owner` | The game instance this subsystem is bound to. |
| `isInitialized` | `bool get isInitialized` | Whether this subsystem has been initialized. |
| `onInitialize` | `void onInitialize(LuminaGameInstance owner)` | Called when the subsystem is registered with the game instance. |
| `onDeinitialize` | `void onDeinitialize()` | Called when the game instance is shutting down. |

### `class LuminaGameInstance`

The engine-lifetime singleton surviving world transitions. Bir `ChangeEmitter`'dır (`lumina_core`): dinleyiciler dünya değişince haber alır; bir widget `asListenable()` ile dinler (`lumina_widgets`). Bir oyunu gösteren oyun widget'ı, oyun host'u ve HUD [lumina_widgets](../lumina_widgets/index.md) içindedir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `world` | `LuminaWorld? get world` | The currently mounted world (null before mount / during transition). |
| `primaryPlayerController` | `LuminaPlayerController? get primaryPlayerController` | The local player's controller, created once at first world mount. |
| `init` | `void init()` | Initializes the game instance and its subsystems. |
| `shutdown` | `void shutdown()` | Called after the last world is cleaned up to deinitialize subsystems. |
| `setNativeContext` | `void setNativeContext(FilamentEngine engine, FilamentScene scene)` | Called by the Game to establish native context before first world mount. |
| `setInitialWorld` | `void setInitialWorld(LuminaWorld newWorld)` | Sets the initial world. |
| `replaceWorld` | `void replaceWorld(LuminaWorld newWorld)` | Replaces the current world with [newWorld] (used by `LuminaGame.restart`).  Cleans up the old world, installs the new one, unpossesses the retained [primaryPlayerController], then fires [onWorldChanged] and notifies listeners. Unlike [openLevel] the caller owns the new world's native context and level tree. |
| `openLevel` | `Future<void> openLevel(LuminaLevel Function() levelBuilder)` | Disposes the current world and creates a new one. |

## `lib/src/game/game_mode.dart`

### `class LuminaGameMode`

Defines the rules of a running world.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `gameState` | `LuminaGameState get gameState` | The game state for this mode. Available after [initGame]. |
| `hasMatchStarted` | `bool get hasMatchStarted` | Whether the match has started. |
| `hasMatchEnded` | `bool get hasMatchEnded` | Whether the match has ended. |
| `initGame` | `void initGame(LuminaWorld world)` | Called once before any actor onBeginPlay. Creates the game state. |
| `autoActivatedCamera` | `LuminaCameraActor? autoActivatedCamera()` | Dünyada `autoActivateForPlayer` açık ilk kamera aktörü ya da null; `login` onu yeni oyuncunun görüş hedefi yapar. |
| `logout` | `void logout(LuminaPlayerController controller)` | Unpossesses and destroys the pawn, and removes player state from game state. |
| `handleStartingNewPlayer` | `void handleStartingNewPlayer(LuminaPlayerController controller)` | Called after login to start a new player. Default implementation calls restartPlayer. |
| `canRestartPlayer` | `bool canRestartPlayer(LuminaPlayerController controller)` | Determines if the player can be restarted. |
| `startMatch` | `void startMatch()` | Starts the match. |
| `endMatch` | `void endMatch()` | Ends the match. |

## `lib/src/game/game_state.dart`

### `enum LuminaMatchState`

The phase of a match.

### `class LuminaGameState`

The shared, observable snapshot of match state and player states.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `playerArray` | `List<LuminaPlayerState> get playerArray` | Gets the unmodifiable list of connected player states. |
| `matchState` | `LuminaMatchState get matchState` | Gets the current match state. |
| `elapsedTime` | `double get elapsedTime` | Gets the elapsed time of the match in seconds. Accumulates only while [matchState] is [LuminaMatchState.inProgress]. |
| `hasMatchStarted` | `bool get hasMatchStarted` | Whether the match has started. |
| `hasMatchEnded` | `bool get hasMatchEnded` | Whether the match has ended. |
| `addPlayerState` | `void addPlayerState(LuminaPlayerState state)` | Adds a player state to the game state. |
| `removePlayerState` | `void removePlayerState(LuminaPlayerState state)` | Removes a player state from the game state. |
| `getPlayerStateById` | `LuminaPlayerState? getPlayerStateById(int playerId)` | Looks up a player state by ID. |
| `setMatchState` | `void setMatchState(LuminaMatchState next)` | Transitions the match state. Throws [StateError] for illegal backwards transitions. |
| `tick` | `void tick(double deltaTime)` | Called during world tick phase 2 to accumulate elapsed time. |
| `addListener` | `void addListener(void Function() listener)` | Adds a listener for changes to this game state. |
| `removeListener` | `void removeListener(void Function() listener)` | Removes a listener from this game state. |
| `notifyChanged` | `void notifyChanged()` | Notifies listeners that the state has changed. |

## `lib/src/game/game_window.dart`

Masaüstünde oyun penceresinin modu. Üretilen runner (`windows/runner/lumina_window_mode.cpp`,
`linux/runner/lumina_window_mode.cc`; lumina_editor_data'daki `GameWindowRunnerService` yazar) pencereyi projenin
**Start Fullscreen** ayarındaki modda açar, Alt+Enter ve F11 ile değiştirir ve `lumina/game_window` kanalını yanıtlar;
`LuminaWindowModeChannel` (lumina_widgets) onunla konuşan [LuminaGameWindow.backend]'dir. Üretilen `main()`
`runApp`'ten önce [LuminaGameWindow.restore]'u çağırır; oyuncunun son seçimi ilk kareden önce geri gelir.

### `enum LuminaWindowMode`

| Değer | `id` | `label` | Anlamı |
|---|---|---|---|
| `windowed` | `windowed` | `Windowed` | Başlık çubuğu ve kenarlıkları olan normal pencere; Alt+Enter önceki boyut ve konumuna döndürür. |
| `borderlessFullscreen` | `borderless_fullscreen` | `Borderless Fullscreen` | Windows: üzerinde bulunduğu monitörün tamamını (`MonitorFromWindow` → `rcMonitor`, görev çubuğu dahil) monitörün fiziksel çözünürlüğünde kaplayan, başlık çubuğu, kenarlığı ve yuvarlak köşesi olmayan bir `WS_POPUP` pencere. Linux: `gtk_window_fullscreen` (X11 ve Wayland). |

`parse(text)` bir `id`, bir `label`, `fullscreen` ya da `borderless` kabul eder (büyük/küçük harf, boşluk, `_` ve `-` yok sayılır); aksi halde null.

Özel (exclusive) mod yoktur (dolayısıyla `VK_EXT_full_screen_exclusive` de yok): Filament başsız bir swap chain'e
çizer ve kareyi Flutter'ın compositor'ü sunar; oyun ekranı tek başına alabilecek sunulabilir bir swap chain'e hiç
sahip olmaz. Monitörü kaplayan kenarlıksız pencere güncel oyunların varsayılanıdır; compositor onu ek kopya olmadan
sunar, Alt+Tab ve overlay'ler çalışmaya devam eder.

### `abstract interface class LuminaWindowModeBackend`

| Üye | İmza | Açıklama |
|---|---|---|
| `getMode` | `Future<LuminaWindowMode?> getMode()` | Pencerenin modu; pencere modu desteği olmayan (ondan önce üretilmiş) bir runner'da null. |
| `setMode` | `Future<bool> setMode(LuminaWindowMode mode)` | Pencereyi `mode` ile gösterir; runner'ın uygulayıp uygulamadığı. |
| `onModeChanged` | `set onModeChanged(void Function(LuminaWindowMode)? listener)` | Runner modu kendisi değiştirdiğinde (Alt+Enter, F11) çağrılır. |

### `abstract final class LuminaGameWindow`

| Üye | İmza | Açıklama |
|---|---|---|
| `backend` | `static LuminaWindowModeBackend? backend` | Runner'ın penceresi; `LuminaWidgets.ensureInitialized` Windows ve Linux'ta atar. Testlerde ve web'de null. |
| `mode` | `static final ObservableValue<LuminaWindowMode> mode` | Şu anki mod (`Get Fullscreen Mode`'un okuduğu). |
| `settingsFilePath` | `static String? settingsFilePath` | Oyuncunun seçiminin saklandığı yer; null hiçbir şey saklamaz (Play-In-Editor). |
| `settingsKey` | `static const String settingsKey = 'window_mode'` | O JSON dosyasındaki anahtarı; dosyanın diğer anahtarları korunur. |
| `settingsFileFor` | `static String settingsFileFor(String saveGamesDirectory)` | `<app support>/<oyun>/SaveGames` → `<app support>/<oyun>/SaveGames/GameUserSettings.json`; grafik ayarlarıyla paylaşılan dosya (`LuminaGameUserSettingsFile`). |
| `restore` | `static Future<LuminaWindowMode> restore({LuminaWindowMode startMode = windowed, String? settingsFilePath})` | Eski bir `user_settings.json`'ı bir kez birleştirir, kayıtlı seçimi, yoksa `startMode`'u (Project Settings > Start Fullscreen) uygular, sonra kayıtlı ekran çözünürlüğünü ve monitörü (`LuminaGameDisplay.restore`) ve hedef kare hızını ve VSync'i (`LuminaGameFramePacing.restore`, ilk kareden önce), ve runner'ın değişikliklerini dinler (her biri kaydedilir ve çözünürlüğü yeniden uygular). Zaten o modda olan runner'a dokunulmaz. |
| `setMode` | `static Future<bool> setMode(LuminaWindowMode next)` | `next`'i kaydeder ve runner'dan uygulamasını ister; runner yoksa false (mod yine kaydedilir). |
| `toggle` | `static Future<bool> toggle()` | Pencereli ↔ kenarlıksız tam ekran. |
| `pendingWrite` | `static Future<void> get pendingWrite` | Son değişiklik ve ayar yazımı bitince tamamlanır. |
| `resetForTesting` | `static void resetForTesting()` | Yeni bir sürecin durumu. |

## `lib/src/game/game_display.dart`, `display_info.dart`, `game_user_settings_file.dart`

Ekran çözünürlüğü ve monitörler. Üretilen runner'ın `lumina/game_window` kanalı ayrıca `getDisplays`,
`setClientSize` ve `moveToMonitor`'a yanıt verir ve `displayChanged` çağırır; Windows ve Linux'ta
[LuminaGameDisplay.backend] `LuminaWindowModeChannel` (lumina_widgets), web'de `LuminaWebDisplayBackend`'dir.

### Modeller

| Tür | Üyeler | Açıklama |
|---|---|---|
| `LuminaDisplayMode` | `width`, `height`, `refreshRate` (Hz, 0 = bilinmiyor); `toList`, `fromList` | Fiziksel piksel olarak bir mod. |
| `LuminaMonitor` | `index`, `name` (model, ör. `DELL U3419W`), `device` (`\\.\DISPLAY1`), `primary`, `bounds`, `workArea` (`LuminaScreenRect`), `current`, `modes`, `scale`; `resolutions`, `refreshRatesFor(w, h)`, `fromMap`, `toMap` | `resolutions`: `modes`'un farklı boyutları ve geçerli boyut, önce genişliğe sonra yüksekliğe göre artan. |
| `LuminaDisplayInfo` | `monitors`, `currentMonitor`, `clientSize`, `current`; `fromMap`, `toMap` | Runner'ın `getDisplays` yanıtı (kullanılabilir monitör yoksa null). |

### `abstract interface class LuminaDisplayBackend`

| Üye | İmza | Açıklama |
|---|---|---|
| `queryDisplays` | `Future<LuminaDisplayInfo?> queryDisplays()` | Monitörler ve istemci alanı; ekran desteği olmayan runner'da null. |
| `setClientSize` | `Future<(int, int)?> setClientSize(int width, int height)` | Pencereli: fiziksel piksel olarak istemci alanı, monitörün çalışma alanına sığdırılır ve ortalanır; elde edileni döndürür. Pencere boyutlanamıyorsa (web, eski runner'lar) null. |
| `moveToMonitor` | `Future<bool> moveToMonitor(int index)` | Tam ekran: o monitörü kaplar (pencereli yerleşimi de oraya ortalar); pencereli: pencereyi ona ortalar. |
| `onDisplayChanged` | `set onDisplayChanged(void Function(LuminaDisplayInfo)? listener)` | Bir ekran değişti ya da pencere başka bir monitöre geçti. |

### `abstract final class LuminaGameDisplay`

Seçilen çözünürlüğün anlamı: **pencereli**, pencerenin istemci alanı (oyun istemci boyutunda çizer); **kenarlıksız
tam ekran**, pencere monitörü kaplamaya devam eder ve oyunun çizim hedefi (Filament view'ı ve dokusu) seçilen
boyuttur; `LuminaGameWidget(followScreenResolution: true)` onu en-boy oranını koruyarak monitöre ölçekler (siyah
bantlar). Monitör kadar ya da daha büyük bir boyut doğal çözünürlükte çizer. Boyutlanamayan bir pencere (web, runner
yok) seçilen boyutu tam ekrandaki gibi ölçekleyerek çizer. Ekran modu hiç değişmez (exclusive tam ekran yok). Filament'in
dinamik çözünürlüğü değil çizim hedefi kullanılır: dinamik çözünürlük viewport'u monitör boyutunda tutar (letterbox
olmaz) ve ölçeğini zaten upscaler'lar kullanır. View seçilen boyutta olunca **Resolution Scale** seçilen × ölçek
boyutunda çizer, **FSR3 / DLSS** seçilen boyutun kalite ölçeğinde çizip seçilen boyutu üretir; Flutter da bu kareyi
monitöre ölçekler. `Get Viewport Size` bu çıktı boyutudur ve oyun host'u işaretçiyi bu boyuta eşler (lumina_widgets'taki `LuminaRenderSpace`): `Get Mouse Position` seçilen çözünürlüğün pikselindedir, oyunun UI'ı resmin içinde yerleşir, bantlardaki tıklamalar hiçbir yere ulaşmaz.

| Üye | İmza | Açıklama |
|---|---|---|
| `backend` | `static LuminaDisplayBackend? backend` | `LuminaWidgets.ensureInitialized` kurar. |
| `info` | `static final ObservableValue<LuminaDisplayInfo?> info` | Son rapor (başlangıç, `displayChanged`, her uygulama). |
| `renderResolution` | `static final ObservableValue<(int, int)?> renderResolution` | Oyun widget'ının izlediği sabit çizim boyutu; null: kendi boyutu. |
| `screenResolution` / `fullscreenMonitor` | `static (int, int)? get` / `static int? get` | Uygulanan seçim (null: doğal / olduğu yer). |
| `apply` | `static Future<void> apply({(int, int)? resolution, int? monitor, bool persist = true})` | Seçimi hemen alır, sonra sırayla taşır / boyutlar ve ayar dosyasına `screen_resolution` / `fullscreen_monitor` yazar. |
| `onWindowModeChanged` | `static Future<void> onWindowModeChanged()` | Seçimi yeni moda göre yeniden uygular (`LuminaGameWindow`, Set Fullscreen Mode, Alt+Enter ve F11'den sonra çağırır). |
| `restore` | `static Future<void> restore(Map<String, dynamic> settings)` | Başlangıç (`LuminaGameWindow.restore`'dan): ekran değişikliklerini dinler, ekranları okur, kayıtlı seçimi geri yazmadan uygular. |
| `currentResolution`, `desktopMode`, `supportedResolutions`, `refreshRatesFor`, `monitorCount`, `currentMonitor` | static | Blueprint düğümlerinin döndürdüğü (rapor yoksa çizim boyutundan yedek değerler). |
| `resolutionFrom` / `monitorFrom` / `settingsPatch` | static | Ayar dosyası anahtarları: `screen_resolution: {width, height}`, `fullscreen_monitor: {index, device, name}` (aygıt kimliği indisten önce gelir). |
| `pendingApply` / `resetForTesting` | static | Son uygulamadan sonra tamamlanır / yeni bir sürecin durumu. |

### `abstract final class LuminaGameUserSettingsFile`

Oyuncu başına tek dosya, `<save games>/GameUserSettings.json`: `window_mode`, `screen_resolution`,
`fullscreen_monitor` ve `LuminaUserSettingsSubsystem.saveSettings`'in yazdığı her şeyi tutan düz bir JSON nesnesi.
Her yazan kendi anahtarlarını birleştirir (`update`), bilmediği anahtarlar korunur; böylece yeni ayarlar ve başka
yazanlar bir arada yaşar; yazmalar sıralıdır. Web'de hiçbir şey yazılmaz.

| Üye | İmza | Açıklama |
|---|---|---|
| `pathFor` / `legacyPathFor` | `static String pathFor(String saveDirectory)` | `<saveDirectory>/GameUserSettings.json`; save dizininin yanındaki eski `user_settings.json`. |
| `read` | `static Future<Map<String, dynamic>> read(String path)` | Eksik ya da bozuk dosyada boş. |
| `update` | `static Future<bool> update(String path, Map<String, Object?> patch)` | `patch`'i birleştirir; null değer anahtarını siler. |
| `migrateLegacy` | `static Future<bool> migrateLegacy({required String path, String? legacyPath})` | Bir kez: eski dosyanın ayar dosyasında olmayan anahtarlarını ekler (ayar dosyası kazanır), sonra eski dosyayı siler. |
| `idle` | `static Future<void> get idle` | Sıradaki yazmalar bitince tamamlanır. |

## `lib/src/game/game_frame_pacing.dart`

Oyunun hedef kare hızı ve VSync'i: `LuminaGameWidget`'ın dünya tick'ini ve çizdiği kareleri neye göre zamanladığı ve
Set Target FPS / Set VSync Enabled'ın Apply Scalability Settings ile değiştirdiği değer.

**Yürürlükte olan.** Projenin Target FPS ve VSync'i (Project Settings; üretilen `main()`'e yazılır ve `LuminaGameHost`
→ `LuminaGameWidget`'a geçer) varsayılandır; oyuncunun uyguladığı seçim bunların önüne geçer. Save Game User Settings
seçimi `GameUserSettings.json`'a yazar (`target_fps`, `vsync`); seçim yoksa anahtar yazılmaz, böylece sonraki bir proje
değişikliği oyuncuya yine ulaşır. `LuminaGameWindow.restore` (üretilen `main()`'de, `runApp`'tan önce) kayıtlı seçimi
ilk kareden önce geri koyar.

**Derlenmiş oyun nasıl gösterir, VSync neyi kontrol edebilir.** Filament oyunu ekran dışı (headless) bir swap chain'e
çizer; kare bir `RawImage`'a geri okunur, Flutter onu birleştirip ekranın vsync'inde gösterir. Dolayısıyla:
- Hiçbir hız ekranın yenileme hızını aşmaz (60 Hz: 120 FPS ve sınırsız ikisi de 60 gösterir) ve VSync ne derse desin
  görüntü yırtılmaz. Hedefe bazı yenilemelerde çizip bazılarını atlayarak ulaşılır (flutter_filament'taki
  `FilamentFrameLimiter`; dünya tick'i ve görünüm aynı yenilemelerde çalışsın diye ortak kullanılır).
- **VSync açık**: her kare aynı tam sayıda yenileme boyunca gösterilir; hızı hedefte ya da altında tutan en küçük sayı:
  eşit kare süreleri (60 Hz: 30 ve 45 FPS ikisi de 30; 144 Hz: 60 FPS 48 olur).
- **VSync kapalı**: hedef ortalamadır; kareler komşu yenileme sayıları arasında değişir (60 Hz, 45 FPS: bir ve iki
  yenileme).
- **Direct sunumda** ([aşağıda](#libsrcgamegame_presentationdart)) VSync swap chain'in sunum kipidir (açık: FIFO,
  kapalı: anında) ve geri okuma yoktur.
- Filament'in `SwapChain::CONFIG_DISABLE_VSYNC`'i (ve vsync'siz bir Vulkan swap chain'in sunum iş parçacığı, yama
  `0016`) yalnızca pencereye kendisi sunan bir swap chain için anlamlıdır; Flutter ile gösterilen oyunda böyle bir swap
  chain yoktur.
- Gösterilen hız ayrıca çizim + geri okuma maliyetiyle sınırlıdır (RTX PRO 2000'de beş test-assets nesnesiyle ölçüldü:
  1920×1350'de 60 FPS, 3440×1440 kenarlıksız tam ekranda yaklaşık 32 FPS; dünya hedef hızda tick etmeye devam eder).
- **Web**: tarayıcının `requestAnimationFrame`'i vsync'tir (hep açık); sınırlayıcı yalnızca yenileme hızının altına
  indirebilir.
- **Kare üretimi**: üretilen kareleri yalnızca kendisi sunan bir swap chain gösterir
  ([flutter_filament dlss.md](../flutter_filament/dlss.md)); Flutter ile gösterilen oyun çizilen her kare için bir kare
  gösterir, bu yüzden hedef FPS çizilen kareleri sayar. Pencere swap chain'i kullanılan yerde kare üretimi orada VSync
  kapalı ister ve sunumlarını kendi iş parçacığında aralar.
- **Play-In-Editor** editörün hızını hiç değiştirmez: `PieController.startPie` projenin ayarlarıyla
  `beginPlayInEditor` çağırır, her oturum onlardan başlar; Set/Apply kaydedilir (Get onları döner) ama editör
  viewport'u kendi hızında çizmeye devam eder.

| Üye | İmza | Açıklama |
|---|---|---|
| `LuminaFramePacingSettings` | `const LuminaFramePacingSettings({int targetFps = 0, bool vsyncEnabled = false})` | Bir değer: hedef FPS (0 = sınırsız) ve VSync. |
| `settings` | `static final ObservableValue<LuminaFramePacingSettings> settings` | Yürürlükte olan; oyun widget'ı hemen izler. |
| `targetFps` / `vsyncEnabled` | `static int get targetFps`, `static bool get vsyncEnabled` | Yürürlükteki değerler. |
| `hasPlayerChoice` | `static bool get hasPlayerChoice` | Oyuncunun bir seçim uygulayıp uygulamadığı (ya da geri yüklenip yüklenmediği). |
| `setProjectDefaults` | `static void setProjectDefaults({required int targetFps, required bool vsyncEnabled})` | Projenin ayarları (oyun widget'ı kendi `targetFps` / `vsyncEnabled`'ıyla çağırır). |
| `apply` | `static void apply({int? targetFps, bool? vsyncEnabled})` | Oyuncunun seçimini yürürlüğe koyar (null o yarıyı korur); negatif FPS 0'dır. |
| `restore` | `static void restore(Map<String, dynamic> saved)` | Başlangıç: ayar dosyasındaki `target_fps` / `vsync`, varsa. |
| `beginPlayInEditor` | `static void beginPlayInEditor({required int targetFps, required bool vsyncEnabled})` | Önceki oturumun seçimini unutur ve projenin ayarlarını koyar. |
| `settingsPatch` | `static Map<String, Object?> settingsPatch()` | `{target_fps, vsync}`: oyuncunun seçimi, yoksa null. |
| `targetFpsKey` / `vsyncKey` | `'target_fps'`, `'vsync'` | Ayar dosyası anahtarları. |
| `resetForTesting` | `static void resetForTesting()` | Yeni bir sürecin durumu. |

## `lib/src/game/game_presentation.dart`

Derlenen bir oyunun karelerini nasıl gösterdiği (işi lumina_widgets yapar; bu sınıf karar verir).

- **Flutter** (varsayılan, `LuminaPresentationMode.flutter`): Filament ekran dışı bir swap chain'e çizer, kare bir
  `RawImage`'e geri okunur, UI'ı Flutter birleştirir ve sunar. Her yerde çalışır; editör viewport'u ve Play-In-Editor
  hep böyledir (Flutter panelleri karenin üstündedir, bunu native bir pencere yapamaz).
- **Direct** (`LuminaPresentationMode.direct`): Filament kendine ait bir pencerede (üretilen runner'ın sunum penceresi,
  Flutter view'inin girdi almayan bir alt penceresi) bir Vulkan swap chain'e çizer ve sunar; uygulamanın tüm UI'ı (HUD,
  UMG katmanı, menüler, açılır pencereler) yerleşim ve girdi için Flutter widget'ı olarak kalır, değiştiğinde ekran
  dışında çizilir ve Filament onu üretilenler dahil her sunulan karenin üzerine karıştırır
  ([lumina_widgets](../lumina_widgets/index.md#doğrudan-sunum), [flutter_filament](../flutter_filament/renderer-and-view.md)).
  Geri okuma yok; frame generation'ın kareleri ekrana ulaşır.

**Geçerli olan.** `resolve(project:, player:, frameGeneration:)`: oyuncunun seçimi (`GameUserSettings.json` anahtarı
`presentation`, `LuminaGameWindow.restore` geri yükler) projeninkinin (Project Settings > Presentation, `.lmproject`
içinde `settings.presentation`, üretilen `main()` tarafından `LuminaGameHost(presentation:)`'a verilir) önüne geçer;
geçerli frame generation (`LuminaRtxController.frameGenerationActive`: DLSS Frame Generation ya da view'de FSR3 frame
generation) oyuncu Flutter seçmediyse Direct ister. Direct çalışamadığında ev sahibi nedenini bildirir
(`reportFallback`) ve `decision` o nedenle Flutter olur, bir kez loglanır: web (canvas'ı tarayıcı sunar), Vulkan dışı
backend, sunum penceresi olmayan runner (önceden üretilmiş proje; şimdilik Linux), başarısız swap chain. Çalışırken
geçiş pencereyi ve swap chain'i oluşturur ya da bırakır; view ve UI bağlı kalır.

**Flutter yürürlükteyken frame generation.** Oyun yine de Flutter üzerinden sunarken (oyuncu Flutter'ı seçti, Direct
geri döndü) frame generation uygulanmış kalır: oyun çalışmaya devam eder, Flutter çizilen her kare için bir kare
gösterir ve üretilen kareler gösterilmez; oyun widget'ı bir uyarı loglar. View her karede bir kez çizilir (yalnızca
`FilamentWidget` tarafından); sunum ve frame generation'ın hiçbir birleşiminde geri okuma tıkanmaz
([lumina_widgets](../lumina_widgets/index.md#doğrudan-sunum)).

**Tasarım.**
- *Kare döngüsü*: sahibi değişmedi. Flutter'ın vsync geri çağrıları (oyun widget'ının ticker'ı ve paylaşılan
  `FilamentFrameLimiter`) dünyayı tick'ler ve `beginFrame` / render / `endFrame` çağırır; sunumu Filament'in sürücü
  iş parçacığı (VSync kapalıyken `0016` yamasının sunum iş parçacığı) yapar. Çizim hızı en fazla ekran yenileme
  hızıdır; frame generation sunumları bunun ötesine çarpar.
- *VSync / Target FPS*: VSync açık swap chain'in FIFO sunum kipidir (`SwapChainConfig.none`), kapalı
  `SwapChainConfig.disableVsync` (anında sunum, frame generation için backend zamanlar); Apply swap chain'i yeniden
  kurar. Target FPS sınırlayıcıda kalır.
- *Boyut, küçültme, DPI*: runner penceresini Flutter view'inin üzerinde tutar ve `surfaceChanged` bildirir; Filament
  swap chain'i pencere boyutunda yeniden kurar; küçültülmüşken (0 x 0) çizim atlanır. Yeni küçülmüş bir pencereden
  büyük viewport kırpılır (yama `0017`). View'in viewport'u çift piksele yuvarlanır (DLSS Frame Generation tek
  boyutlarda siyah kare yazar).
- *Alt+Enter / tam ekran / ekran çözünürlüğü*: pencere kipleri eskisi gibi runner'ındır; seçilen çözünürlük view'i
  pencerenin içinde, pencerenin pikselinde siyah bantlarla yerleştirir (Resolution Scale ve upscaler'lar daha az çizer).
- *Girdi*: Flutter'ın, değişmedi (`LuminaRenderSpace`); sunum penceresi devre dışıdır ve isabet testine şeffaftır.
- *HDR*: SDR (UNORM swap chain); yama setinde HDR çıkışı yok.

**Ölçüldü** (RTX PRO 2000, 60 Hz 3440x1440 ekran, beş test-assets nesnesi, `D:/fs/dp` üretilmiş oyun kopyası):

| | Flutter | Direct |
|---|---|---|
| kenarlıksız tam ekran 3440x1440, FG kapalı, VSync kapalı | 33,8-35,4 sunum/s | 60,0 (CV 0,12) |
| pencere 1264x861, FG kapalı | 48,0 | 60,2 (CV 0,07) |
| tam ekran, DLSS FG 2x / 4x / FSR3 FG (VSync kapalı) | takılır (fence zaman aşımı) | 120,0 / 118,1 / 119,9 |
| pencere, DLSS FG 2x / 4x / FSR3 FG | - | 119,7 / 142,1 / 115,1 |
| VSync açık, FG kapalı / DLSS 2x | - | 60,4 / 60,3 (FIFO) |

3440x1440'ta UI resmi: Flutter'ın raster iş parçacığında 14-19 ms geri okuma, UI iş parçacığında 1,5-4,7 ms yükleme,
değişiklikten Filament'e yaklaşık bir kare (16-24 ms); yalnızca UI değiştiğinde alınır (10 Hz HUD saati: saniyede 10).
60 Hz birleştirilen bir ekranda saniyede yaklaşık 120'den fazla sunum gösterilmez (2x görünür, 4x / 6x için daha hızlı
ekran gerekir).

| Üye | İmza | Açıklama |
|---|---|---|
| `LuminaPresentationMode` | `flutter`, `direct`; `id`, `parse(Object?)` | Kip; dosyalarda `'flutter'` / `'direct'`. |
| `LuminaPresentationDecision` | `(mode, {reason})` | Bir kip ve nedeni. |
| `resolve` | `static LuminaPresentationDecision resolve({required project, player, bool frameGeneration = false})` | Yukarıdaki kurallar. |
| `requested` / `decision` | `static final ObservableValue<LuminaPresentationDecision>` | Oyunun istediği / geçerli olan. |
| `setProjectDefault` / `apply` / `restore` / `settingsPatch` | | Proje ayarı, oyuncu seçimi (null unutur), ayar dosyasından başlangıç, dosya anahtarı. |
| `setFrameGenerationActive` / `reportFallback` / `reset` | | Frame generation açık/kapalı; ev sahibi yapamadı (null: yapabiliyor); varsayılanlar. |

## `lib/src/game/lumina_game.dart`

### `class LuminaGame`

Entrypoint class for building declarative Lumina game applications.  Besides the mount / tick / dispose lifecycle it exposes the editor-facing play control surface (Play-In-Editor): [pause], [resume], [step], [restart] and a broadcast [playStateStream] a toolbar can bind to.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `gameInstance` | `final LuminaGameInstance gameInstance` | `gameInstance` alanını (field/property) ve ilişkili veriyi saklar. |
| `world` | `LuminaWorld? get world` | `world` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `playState` | `LuminaPlayState get playState` | Current play state: `stopped` before [mountGame] / after [disposeGame], `playing` after [mountGame], `paused` after [pause]. |
| `isPaused` | `bool get isPaused` | Whether the game is paused ([tickGame] is a no-op; only [step] advances the world). |
| `playStateStream` | `Stream<LuminaPlayState> get playStateStream` | Broadcast stream emitting one event per play-state *transition* (idempotent [pause] / [resume] calls emit nothing). Closed by [disposeGame] after the final `stopped` event. |
| `pause` | `void pause()` | Pauses the mounted world: timers, subsystem ticks, actor ticks, audio and `timeSeconds` freeze. Idempotent; no-op while `stopped`. |
| `resume` | `void resume()` | Resumes a paused world. Idempotent; no-op while `stopped`. |
| `step` | `void step(double deltaTime)` | Advances the world by exactly one tick of [deltaTime] regardless of the pause flag (the game stays paused). Equivalent to one [tickGame] while playing. Throws [StateError] while `stopped`. |
| `restart` | `void restart()` | Tears the current world down and starts a fresh one from the same declarative tree on the same engine/scene ([LuminaGameInstance.replaceWorld]). If the old world had begun play, `beginPlay()` is called on the new one. Ends in the `playing` state. Throws [StateError] while `stopped`. |
| `mountGame` | `void mountGame(FilamentEngine engine, FilamentScene scene)` | Initializes declarative game tree and mounts [LuminaWorld]. |
| `tickGame` | `void tickGame(double deltaTime)` | Ticks the game loop and mounted world. No-op while [isPaused] (use [step]). |
| `disposeGame` | `void disposeGame()` | Disposes game tree and world resources. |

## `lib/src/game/play_state.dart`

### `enum LuminaPlayState`

Editor-facing play state of a [LuminaGame] (Play-In-Editor toolbar state).  Transitions: `stopped` → `playing` on `mountGame`, `playing` ⇄ `paused` via `pause()` / `resume()`, and any state → `stopped` on `disposeGame`.

## `lib/src/game/player_camera_manager.dart`

### `class LuminaMinimalViewInfo`

`LuminaMinimalViewInfo`: Kullanıcı arayüzünü (UI) oluşturan ve kullanıcı etkileşimlerini dinleyen shadcn_flutter bileşenidir.

`camera` alanı, hedefin bir kamera bileşeni varsa ve harmanlama yoksa görüş hedefinin kamerasıdır (aksi halde null); `nearClip` / `farClip` o kameranınkidir. Dünya ve Play o zaman projeksiyonunu, kırpma düzlemlerini ve pozlamasını da kullanır.

### `enum LuminaViewTargetBlendFunction`

`LuminaViewTargetBlendFunction`: Sistemde kullanılan seçenekleri ve durumları listeleyen numaralandırma türüdür.

### `class LuminaCameraShake`

`LuminaCameraShake`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `locationAmplitude` | `Vector3 locationAmplitude` | `locationAmplitude` alanını (field/property) ve ilişkili veriyi saklar. |
| `rotationAmplitudeDegrees` | `Vector3 rotationAmplitudeDegrees` | `rotationAmplitudeDegrees` alanını (field/property) ve ilişkili veriyi saklar. |
| `locationFrequency` | `Vector3 locationFrequency` | `locationFrequency` alanını (field/property) ve ilişkili veriyi saklar. |
| `duration` | `double duration` | `duration` alanını (field/property) ve ilişkili veriyi saklar. |
| `blendInTime` | `double blendInTime` | `blendInTime` alanını (field/property) ve ilişkili veriyi saklar. |
| `blendOutTime` | `double blendOutTime` | `blendOutTime` alanını (field/property) ve ilişkili veriyi saklar. |
| `initialPhase` | `double initialPhase` | `initialPhase` alanını (field/property) ve ilişkili veriyi saklar. |
| `isFinished` | `bool get isFinished` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `updateAndGetShake` | `Vector3 updateAndGetShake(double deltaTime)` | Mevcut verileri veya durumu günceller. |

### `class LuminaPlayerCameraManager`

`LuminaPlayerCameraManager`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Yapıcı Metotlar (Constructors):**
- `LuminaPlayerCameraManager(this.playerController)`: `LuminaPlayerCameraManager(this.playerController)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `playerController` | `LuminaPlayerController playerController` | `playerController` alanını (field/property) ve ilişkili veriyi saklar. |
| `viewTarget` | `LuminaActor? get viewTarget` | `viewTarget` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `setViewTarget` | `void setViewTarget(LuminaActor target)` | `ViewTarget` parametresini günceller ve sisteme uygular. |
| `setFov` | `void setFov(double newFov)` | `Fov` parametresini günceller ve sisteme uygular. |
| `resetFov` | `void resetFov()` | Değerleri veya durumları varsayılan ayarlarına sıfırlar. |
| `startCameraShake` | `void startCameraShake(LuminaCameraShake shake)` | `startCameraShake` işlemini gerçekleştirir. |
| `updateCamera` | `void updateCamera(double deltaTime)` | Mevcut verileri veya durumu günceller. |

## `lib/src/game/camera_actor.dart`

### `class LuminaCameraActor`

Bir levele yerleştirilmiş kamera: levelin `LuminaCameraSettings`'ini taşıyan bir `LuminaCameraComponent` (kökü; kendi −Z'sine, yani yazılmış +Y'ye bakar). Kamerası etkin olmaz, yani görüntüyü kendiliğinden sahiplenilen pawn'dan almaz; bir görüş hedefi (view target) olarak içinden bakılır — bir Blueprint'ten `Set View Target with Blend` ya da her oturum açan oyuncunun görüş hedefi yapan `autoActivateForPlayer` (`LuminaGameMode.login`). Dünya onu kendi projeksiyonu, kırpma düzlemleri ve pozlamasıyla çizer. Play ve üretilen level her yerleştirilmiş `Camera` aktörünü bununla kurar.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `LuminaCameraActor` | `LuminaCameraActor({LuminaObjectKey? key, Vector3? location, Quaternion? rotation, Vector3? scale, LuminaCameraSettings settings})` | Ayarlar uygulanmış, verilen dönüşümde bir kamera. |
| `settings` | `final LuminaCameraSettings settings` | Kameranın kurulduğu ayarlar. |
| `cameraComponent` | `final LuminaCameraComponent cameraComponent` | İçinden bakılan kamera; aktörün kökü. |
| `autoActivateForPlayer` | `bool get autoActivateForPlayer` | Bir oyuncunun oturum açtığı andan itibaren bu kameradan bakıp bakmadığı. |

## `lib/src/game/player_start.dart`

### `class LuminaPlayerStart`

An actor that specifies a spawn point for players in the level.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `playerStartTag` | `String? playerStartTag` | Optional tag used by the GameMode to match a specific start. |

## `lib/src/game/primitive_actor.dart`

**Üst Düzey Fonksiyonlar (Top-level Functions):**

- **`LuminaPrimitiveShape luminaPrimitiveShapeFrom(String? name)`**: Parses the `shape` string an editor `LuminaProceduralMeshComponent` carries. Anything unrecognised is a box, so an old or hand-edited level still loads.
- **`Vector3 luminaHexToRgb(String? hex)`**: Parses `#RRGGBB` / `#AARRGGBB` into a 0..1 RGB vector; mid grey on error.
- **`Vector3 luminaPrimitiveSize(Map<String, dynamic> properties)`**: Bir editör `LuminaProceduralMeshComponent` girdisinin tarif ettiği temel şeklin çalışma zamanı (Y yukarı) boyutu, cm. `sizeX` / `sizeY` / `sizeZ` her kayıtlı level değeri gibi Z yukarı yazılır (`sizeZ` yükseklik, `sizeY` yazım Y'si boyunca derinlik) ve [LuminaAxes.extent] ile dönüştürülür; eksik bir boyut 100 cm'dir. Level viewport'u, Play, level kod üreticisi ve level küçük resimleri boyutları buradan okur.

### `enum LuminaPrimitiveShape`

Shapes a [LuminaPrimitiveActor] can take.

### `class LuminaPrimitiveGeometry`

CPU-side vertex data for a primitive shape, in metres, centred on the actor origin. Planes lie in the XZ plane at y = 0.

**Yapıcı Metotlar (Constructors):**
- `LuminaPrimitiveGeometry(this.positions, this.normals, this.uvs, this.indices)`: `LuminaPrimitiveGeometry(this.positions, this.normals, this.uvs, this.indices)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `positions` | `Float32List positions` | `positions` alanını (field/property) ve ilişkili veriyi saklar. |
| `normals` | `Float32List normals` | `normals` alanını (field/property) ve ilişkili veriyi saklar. |
| `uvs` | `Float32List uvs` | `uvs` alanını (field/property) ve ilişkili veriyi saklar. |
| `indices` | `Uint32List indices` | `indices` alanını (field/property) ve ilişkili veriyi saklar. |
| `vertexCount` | `int get vertexCount` | `vertexCount` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `solidColors` | `Uint8List solidColors(Vector3 rgb)` | One opaque RGBA vertex colour per vertex.  The colour is not optional: the gltfio ubershader drops a primitive that declares no `COLOR` attribute without drawing it at all. |
| `build` | `static LuminaPrimitiveGeometry build(LuminaPrimitiveShape shape, Vector3...` | Deklaratif alt nesne veya widget ağacını inşa eder. |

### `class LuminaPrimitiveActor`

An engine-drawn primitive authored in Lumina Studio: a [LuminaProceduralMeshComponent] section plus a matching box collider, so a character can stand on it without any imported art asset.  Both Play-In-Editor and the generated game build the same actor from the same `LuminaProceduralMeshComponent` properties in `metadata.actors`. `materialOverrideAsset` (aktöre atanmış materyal, bir materyal `.lmas`) her bölümde rengin yerine çizilir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `shape` | `LuminaPrimitiveShape shape` | `shape` alanını (field/property) ve ilişkili veriyi saklar. |
| `size` | `Vector3 size` | Çalışma zamanı (Y yukarı) boyutu, cm: `size.y` yüksekliktir. Kayıtlı, Z yukarı bileşen boyutları [luminaPrimitiveSize] ile dönüştürülür. |
| `color` | `Vector3 color` | `color` alanını (field/property) ve ilişkili veriyi saklar. |
| `meshComponent` | `final LuminaProceduralMeshComponent meshComponent` | `meshComponent` alanını (field/property) ve ilişkili veriyi saklar. |
| `collisionComponent` | `final LuminaCollisionComponent collisionComponent` | `collisionComponent` alanını (field/property) ve ilişkili veriyi saklar. |
| `onBeginPlay` | `void onBeginPlay()` | Olay tetiklendiğinde çalışan geri çağırım metodudur. |

## `lib/src/game/template_character.dart`

**Üst Düzey Fonksiyonlar (Top-level Functions):**

- **`LuminaInputAction('IA_Move', valueType: InputValueType.axis2D)`**: `LuminaInputAction` işlemini gerçekleştirir.
- **`LuminaInputAction('IA_Look', valueType: InputValueType.axis2D)`**: `LuminaInputAction` işlemini gerçekleştirir.

### `class LuminaTemplateCharacterTuning`

The movement and camera numbers the First Person / Third Person templates are built from.  They live here because the same character exists twice: as generated source inside the user's project (`lib/pawns/<Project>Character.dart`, which the editor process cannot import), and as [LuminaTemplateCharacter], which Play-In-Editor instantiates directly. `DartCodeGeneratorService` interpolates these constants into the generated source and a parity test fails if the two drift apart.

**Yapıcı Metotlar (Constructors):**
- `LuminaTemplateCharacterTuning._()`: `LuminaTemplateCharacterTuning._()` nesnesini ilklendirir.

### `class LuminaTemplateCharacter`

The player character the First Person and Third Person templates scaffold, as a real engine class Play-In-Editor can spawn.  This is deliberately *not* what the shipped game runs: the launcher writes the equivalent as ordinary source the user owns and edits. Both are built from [LuminaTemplateCharacterTuning], so pressing Play in the editor and running the generated project move the same way.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `thirdPerson` | `bool thirdPerson` | True when the camera rides a boom behind the character. |
| `springArmComponent` | `LuminaSpringArmComponent? springArmComponent` | The boom, or null in first person. |
| `cameraComponent` | `final LuminaCameraComponent cameraComponent` | `cameraComponent` alanını (field/property) ve ilişkili veriyi saklar. |
| `onMove` | `void onMove(LuminaInputActionValue value)` | Drives the character along the control rotation's forward/right axes. |
| `onLook` | `void onLook(LuminaInputActionValue value)` | Feeds mouse deltas to the controller. Pitch is clamped by [LuminaPlayerController.onTick]; it is deliberately not clamped again here. |
| `onJump` | `void onJump(LuminaInputActionValue value) => jump()` | Jumps through the character movement component. |

## `lib/src/game/console.dart`

### `typedef LuminaConsoleCommand`

A console command: the arguments after the command name and the world it runs against (null outside play).

### `abstract final class LuminaConsole`

The tiny console registry `Execute Console Command` routes to: `stat fps`, `quit`, `slomo <x>`, `open <level>` are built in; a project registers its own with [register].

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `showFps` | `static bool showFps` | Whether `stat fps` turned the frame-rate readout on. |
| `register` | `static void register(String name, LuminaConsoleCommand command)` | Adds (or replaces) the project command [name]. |
| `unregister` | `static void unregister(String name)` |  |
| `clearRegistered` | `static void clearRegistered()` | Drops every project command; the built-ins stay. |
| `commandNames` | `static List<String> get commandNames` | The built-in and registered command names. |
| `execute` | `static bool execute(LuminaWorld? world, String line)` | Runs [line] (`slomo 0.5`); true when a command handled it. Unknown commands are logged and return false. |

## `lib/src/game/static_mesh_actor.dart`

### `class LuminaStaticMeshActor`

A placed static mesh and its simple collision.

The root [meshComponent] draws the mesh asset as a plain [LuminaStaticMeshComponent] does. Every entry of [collisionHulls] becomes one [LuminaCollisionComponent.convexHull] in [collisionComponents]: `worldStatic`, blocking everything, at the mesh's origin. Scene components do not inherit their parent's scale, so each hull component carries the actor's scale itself, and [actorScale] keeps them in step.

Every entry of [collisionPrimitives] (authored boxes, spheres and capsules) becomes one more collider next to them, sized for the actor's scale.

A mesh with neither has no collision.

`materialOverrideAsset` (seviyeye yerleştirilmiş bir mesh'e atanan materyal), mesh'in kendi materyallerinin yerine her bölümde çizilir ([LuminaStaticMeshComponent.materialOverrideAsset]).

**Yapıcı Metotlar (Constructors):**

- `LuminaStaticMeshActor({LuminaObjectKey? key, Vector3? location, Quaternion? rotation, Vector3? scale, required String meshAssetPath, bool castShadows = true, bool visible =...`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `meshComponent` | `final LuminaStaticMeshComponent meshComponent` | The drawn mesh (the root component). |
| `collisionHulls` | `final List<LuminaCollisionHull> collisionHulls` | The authored hulls, in [collisionComponents] order. |
| `collisionPrimitives` | `final List<LuminaCollisionPrimitive> collisionPrimitives` | The authored box / sphere / capsule shapes, in [primitiveComponents] order. |
| `collisionComponents` | `final List<LuminaCollisionComponent> collisionComponents` | One convex collision component per hull, then one per primitive. |
| `primitiveComponents` | `final List<LuminaCollisionComponent> primitiveComponents` | The components of [collisionPrimitives]. |

## `lib/src/game/template_clips.dart`

### `class LuminaThirdPersonClips`

The clip set of the Third Person template's character bundle, kept free of engine imports so `tool/build_third_person_content.dart` (plain `dart run`, no Flutter) can read it. `LuminaThirdPersonContent` exposes the same constants to the engine.

The character and its clips are Quaternius' CC0 "Universal Base Characters" and "Universal Animation Library" 1 and 2 (see `assets/templates/third_person/LICENSE.txt`). The libraries animate forward only: the side and backward walk / jog cycles are derived from the forward ones by the build tool (see [walks]).

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `meshAssetName` | `static const String meshAssetName` | Name of the skeletal mesh asset, in the bundle and in a project. |
| `bundledMeshPath` | `static const String bundledMeshPath` | The merged GLB, relative to the lumina package root. |
| `idle` | `static const String idle` |  |
| `jump` | `static const String jump` |  |
| `fallLoop` | `static const String fallLoop` |  |
| `land` | `static const String land` |  |
| `dash` | `static const String dash` | The dash plays a dodge roll. |
| `wallJump` | `static const String wallJump` | The wall jump plays the second library's flip jump. |
| `rootMotionClips` | `static const Set<String> rootMotionClips` | Clips exported with root motion on the `root` bone, which the merger strips. The libraries' in-place exports carry none. |
| `idleBreaks` | `static const List<String> idleBreaks` | The idle breaks one of which plays after standing still a while. |
| `turns` | `static const Map<String, double> turns` | Turn-in-place clips by the yaw (degrees, right positive) each turns through. The libraries have none, so a standing character simply turns with its capsule. |
| `walks` | `static const List<String> walks` | The eight-way walk, in [LuminaLocomotionDirection] order (forward, then clockwise). Only the forward cycle is authored; the build tool turns it toward the other forward directions and plays it backward for the backward ones (see [directionDegrees]). |
| `jogs` | `static const List<String> jogs` | The eight-way jog, in the same order and derived the same way: the sprint row of the locomotion blend space. |
| `directionDegrees` | `static const List<double> directionDegrees` | Direction (degrees, right positive) of each entry of [walks] / [jogs]. |
| `aimOffsetBones` | `static const List<(String, double)> aimOffsetBones` | The aim offset's bone chain on this skeleton and each bone's share of the aim (its head bone is `Head`). |
| `names` | `static const List<String> names` | Every clip in the bundle, in the order the tool merges them (which is the gltfio animation index order). |

## `lib/src/game/template_content.dart`

### `class LuminaThirdPersonContent`

The art the Third Person template ships: a CC0 character with its idle, eight-direction walk / jog and movement clips merged into one GLB, so a single gltfio asset (one animator) plays them all.

`tool/build_third_person_content.dart` builds [bundledMeshPath] from the Quaternius packs listed in `assets/templates/third_person/LICENSE.txt`. The file is **not** a Flutter asset of this package — that would ship it inside every game that depends on lumina. Project scaffolding reads it from the engine package on disk and copies it into the new project's `contents/`.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `meshAssetName` | `static const String meshAssetName` | Name of the skeletal mesh asset, in the bundle and in a project. |
| `bundledMeshPath` | `static const String bundledMeshPath` | The merged GLB, relative to the lumina package root. |
| `projectMeshAssetPath` | `static const String projectMeshAssetPath` | Where a Third Person project keeps the mesh asset and its GLB companion. |
| `projectMeshGlbPath` | `static const String projectMeshGlbPath` |  |
| `projectAnimationDir` | `static const String projectAnimationDir` | Folder of the per-clip animation assets that reference the mesh. |
| `idleClip` | `static const String idleClip` |  |
| `walkClips` | `static const Map<LuminaLocomotionDirection, String> walkClips` | The walk cycle per direction; see [LuminaThirdPersonClips.walks]. |
| `jogClips` | `static const Map<LuminaLocomotionDirection, String> jogClips` | The jog cycle per direction: the sprint row of [locomotionBlendSpace]. |
| `clipNames` | `static const List<String> clipNames` | Every clip in the bundle, in the order the tool merges them (which is the gltfio animation index order); see [LuminaThirdPersonClips.names]. |
| `jumpClip` | `static const String jumpClip` |  |
| `fallLoopClip` | `static const String fallLoopClip` |  |
| `landClip` | `static const String landClip` |  |
| `dashClip` | `static const String dashClip` |  |
| `wallJumpClip` | `static const String wallJumpClip` |  |
| `idleBreakClips` | `static const List<String> idleBreakClips` | The idle breaks one of which plays after standing still a while. |
| `turnClips` | `static const Map<String, double> turnClips` | Turn-in-place clips by the yaw (degrees, right positive) each turns through; see [LuminaThirdPersonClips.turns]. |
| `walkReferenceSpeed` | `static const double walkReferenceSpeed` | Ground speed at which the walk clips play at rate 1 without foot slide. Measured by forward kinematics on the bundled clips: the planted `ball_l` / `ball_r` moves back at 1.0 m/s relative to `root`, a stroll. |
| `jogReferenceSpeed` | `static const double jogReferenceSpeed` | Ground speed at which the jog clips play at rate 1 without foot slide. Measured the same way as [walkReferenceSpeed]: 6.0 m/s, a fast run, so the held sprint (480 cm/s) plays it at 0.8×. |
| `mannequinLocomotion` | `static const LuminaLocomotionClipSet mannequinLocomotion` | Idle + eight-way walk + eight-way jog for the character. |
| `maxWalkRate` | `static const double maxWalkRate` | Play-rate ceiling of the walk cycle; see [mannequinLocomotion]. |
| `animBlueprintName` | `static const String animBlueprintName` | The character's Animation Blueprint and walk blend space, as a Third Person project stores them. |
| `walkBlendSpaceName` | `static const String walkBlendSpaceName` |  |
| `projectAnimBlueprintPath` | `static const String projectAnimBlueprintPath` |  |
| `projectWalkBlendSpacePath` | `static const String projectWalkBlendSpacePath` |  |
| `locomotionBlendSpaceName` | `static const String locomotionBlendSpaceName` | The 2D Direction × Speed locomotion blend space ABP_Character's Walk state plays; `BS_Walk` stays for projects scaffolded earlier. |
| `projectLocomotionBlendSpacePath` | `static const String projectLocomotionBlendSpacePath` |  |
| `blendSpaces` | `static Map<String, LuminaBlendSpaceDocument> get blendSpaces` | Every blend space a Third Person project ships, by asset path. |
| `characterBlueprintName` | `static const String characterBlueprintName` | The template's character and game mode Blueprints. |
| `gameModeBlueprintName` | `static const String gameModeBlueprintName` |  |
| `characterBlueprintPath` | `static const String characterBlueprintPath` |  |
| `gameModeBlueprintPath` | `static const String gameModeBlueprintPath` |  |
| `characterBlueprintCrossBoxWires` | `static const List<(String, String, String, String)> characterBlueprintCrossBoxWires = [ ('forward', 'return_va...` | The wires of [characterBlueprint]'s Event Graph that cross comment boxes on purpose, as (from node, from pin, to node, to pin). The only one is the Dash launching along the Move box's pure `Get Forward Vector`, which is the free-look-aware move yaw's forward. It is a data read, not an exec link, so no event runs another's chain. |
| `characterBlueprint` | `static LuminaBlueprintDocument characterBlueprint({List<LuminaInputAction> inputActions = const [], bool withM...` | `LuminaTemplateCharacter(thirdPerson: true)` as a Character Blueprint: its components and tuning, the character mesh animated by [animBlueprint] (unless [withMesh] is false), the Third Person Move / Look / Jump graph, a held IA_Sprint (the walk speed cap raised to [LuminaTemplateCharacterTuning.thirdPersonSprintSpeed]), an IA_Dash launch and a Tick wall trace for ABP_Character. Authoring space throughout (cm, Z up). [inputActions] type the input event nodes; [meshAsset] is the character mesh reference. |
| `gameModeBlueprint` | `static LuminaBlueprintDocument get gameModeBlueprint` | The template's game mode: [characterBlueprint] as the Default Pawn Class. |
| `walkBlendSpace` | `static LuminaBlendSpaceDocument get walkBlendSpace` | The eight walk cycles on a Direction axis (degrees, right positive, as `calculate_direction` gives it); backward sits at both ends. |
| `locomotionBlendSpace` | `static LuminaBlendSpaceDocument get locomotionBlendSpace` | The locomotion blend space: Direction (degrees, right positive) × Speed (cm/s). The walk clips sit on the [walkReferenceSpeed] row and the jog clips on the [jogReferenceSpeed] row, each row with backward at both ends of the direction ring. |
| `idleBreakAfterSeconds` | `static const double idleBreakAfterSeconds` | Seconds of standing still before an idle break may start (the break also waits for the idle clip to have played through once). |
| `turn90Degrees` | `static const double turn90Degrees` | Root yaw offsets (degrees, absolute) beyond which a standing character turns in place with a 90° / 180° clip, when [turnClips] has them. |
| `turn180Degrees` | `static const double turn180Degrees` |  |
| `jumpToFallAfterSeconds` | `static const double jumpToFallAfterSeconds` | Seconds into the jump clip after which still falling hands over to the fall loop. |
| `dashSpeed` | `static const double dashSpeed` | The dash: IA_Dash (Left Ctrl) launches the character at [dashSpeed] (cm/s, along the control yaw, replacing the horizontal velocity) and keeps `IsDashing` for [dashSeconds]; the roll gives way to the walk after [dashWalkAfterSeconds] (once the character is back on its feet) when still moving, or plays through into Idle. |
| `dashSeconds` | `static const double dashSeconds` |  |
| `dashWalkAfterSeconds` | `static const double dashWalkAfterSeconds` |  |
| `wallTraceDistance` | `static const double wallTraceDistance` | How far ahead of the eyes the character's Tick looks for a wall (`WallAhead`, the wall jump's condition). |
| `animBlueprint` | `static LuminaAnimBlueprintDocument get animBlueprint` | [mannequinLocomotion] and the rest of the movement set as an Animation Blueprint. The update graph stores the pawn's ground speed, walk direction, falling state, whether it is rising (falling with upward velocity: it just jumped) and how long it has stood still. The state machine idles below the idle threshold, walks the [locomotionBlendSpace] at a rate matched to the ground speed, plays the jump → fall loop → land clips through the air (the wall jump clip when rising into a wall the character's Tick trace reports as `WallAhead`), the dash clip while the character's IA_Dash graph holds `IsDashing`, and one of the idle breaks after [idleBreakAfterSeconds] of standing (the instance's reserved `StateTime` and `ClipFinished` variables). With [turnClips], a standing character keeps its feet planted and turns in place once the controller has turned it past [turn90Degrees] / [turn180Degrees] (`RootYawOffset`); without them it turns with its capsule. Every transition blends over the template's crossfade. |
| `animBlueprintWith` | `static LuminaAnimBlueprintDocument animBlueprintWith({Map<String, double> turns = turnClips})` | [animBlueprint] for a bundle with the turn-in-place clips [turns] (clip name → yaw in degrees, right positive; the 90° and 180° turns each way that have a clip get a state). |

---

[Önceki: Render cihazları](rendering.md) | [Üst: lumina (engine çekirdeği)](index.md) | [Sonraki: User widget'lar](user-widgets.md)
