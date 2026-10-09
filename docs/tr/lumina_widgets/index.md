[English](../../en/lumina_widgets/index.md)

# lumina_widgets — bir oyunun Flutter tarafı

`lumina_widgets`, çalışan bir oyunun Flutter üzerinden gösterdiği ya da okuduğu her şeyi tutar. Kendi widget'ı, UMG'si
ya da medya arayüzü olmayan motor paketinin (`lumina`) üzerine kuruludur:

- Filament görüntüsünü barındırıp oyun döngüsünü süren oyun widget'ı ([`LuminaGameWidget`](#libsrcgamelumina_widgetdart))
  ve üretilen bir oyunun gösterdiği oyun ekranı ([`LuminaGameHost`](#libsrcgamegame_hostdart)): klavye, işaretçi ve fare
  yakalama (`lumina_mouse_capture`) dünyanın `LuminaInputSubsystem`'ine aktarılır; Open Level / Change Level;
- HUD katmanı ve ekrandaki `Print String` satırları ([`LuminaHudOverlay`](#libsrcgamehud_overlaydart));
- UMG: runtime widget'ları, element binding'leri, widget katmanı ve builder'lar, tema rengi extension'ları
  ([UMG sayfası](umg.md));
- media_kit üzerinde medya oynatıcıları ve UMG medya widget'ları ([medya sayfası](media.md));
- web derlemesinin yükleme ekranı bağlantısı ([`LuminaWebLoading`](#libsrcutilityweb_loadingdart));
- motorun saf observable'larının Flutter görünümleri ([adaptörler](#libsrcfoundationobservable_adaptersdart)) ve motora
  Flutter'dan gerekenleri veren [`LuminaWidgets.ensureInitialized`](#libsrclumina_widgets_bindingdart).

Dosya yolları `lumina_widgets/` paket dizinine görelidir.

## Kütüphaneler

| Kütüphane | Nedir |
| :--- | :--- |
| `package:lumina_widgets/lumina_game.dart` | Bir oyunun import ettiği: `package:lumina/lumina_runtime.dart` (motor runtime'ı), `lumina_widgets.dart` ve `lumina_mouse_capture`. Kod üreteci bunu launcher, level, input, karakter, game mode ve UMG widget dosyalarına yazar. |
| `package:lumina_widgets/lumina_widgets.dart` | Yalnızca bu paket. Lumina Studio buna `package:lumina_editor_data/lumina_editor.dart` üzerinden ulaşır; `lumina_editor_api` medya oynatıcılarını ve observable adaptörlerini yeniden export eder. |

Derlenmiş Blueprint sınıfları ve kayıtları (`lib/actors/`, `lib/anim/`, `blueprint_registry.g.dart`,
`blueprint/blueprint_functions.g.dart`) yalnızca motoru kullanır ve `package:lumina/lumina_runtime.dart` import etmeye
devam eder. Bir proje hem `lumina`'ya hem `lumina_widgets`'a bağlıdır (`ProjectEngineLink` iki git bağımlılığını ve yerel
override'ları yazar); eski bir proje açılınca oyun arayüzünü kullanan dosyaları yeniden yazılır ve bağımlılık eklenir
(`LuminaGeneratedCodeMigration.migrateGameImports` / `migratePubspecGameDependency`).

## Motorun bu pakete bıraktıkları

Motor hiçbir Flutter arayüz kütüphanesi import etmez (`lumina/test/architecture/engine_has_no_widgets_test.dart`,
`lumina.dart` ve `lumina_runtime.dart`'ı ulaştıkları her paketle birlikte dolaşır; `dart:ui` yalnızca listelediği üç
görüntü-codec kütüphanesinde, `package:flutter/foundation.dart` hiçbir yerde serbesttir). Uygulamadan bir şeye
ihtiyaç duyduğu yerde, bu paketin açılışta doldurduğu bir bağlantı noktası sunar:

| Motor bağlantı noktası | Doldurulan değer | Kullanan |
| :--- | :--- | :--- |
| `LuminaPlatform.override` | Flutter'ın `defaultTargetPlatform`'u | `Get Platform Name` (`LuminaPlatform.displayName`); yoksa platform `dart:io`'dan gelir (web derlemesinde `web`). |
| `LuminaAssets.bundleProvider` | `rootBundle` | Prosedürel gökyüzünün shader'ı ve dokuları (`packages/lumina/assets/sky/…`). |
| `LuminaVideoPlayback.factory` | `LuminaVideoController` (media_kit) | Blueprint video node'ları (yoksa `Open Video` null döner). |

Motor durumu `lumina_core`'un saf türleriyle (`ChangeSignal`, `Observable`, `ChangeEmitter`, `ObservableValue`) haber
verir: `LuminaGameInstance` bir `ChangeEmitter`, `LuminaPlayerController.cursorState` bir `ChangeSignal`,
`LuminaWidgetSubsystem.activeWidgets` ve `LuminaGraphicsDevices.inUse` birer `ObservableValue`'dur. Widget'lar
`asListenable()` / `asValueListenable()` ile dinler.

**Bu sayfada:**

- [`lib/src/lumina_widgets_binding.dart`](#libsrclumina_widgets_bindingdart)
- [`lib/src/game/game_host.dart`](#libsrcgamegame_hostdart)
- [`lib/src/game/lumina_widget.dart`](#libsrcgamelumina_widgetdart)
- [`lib/src/game/hud_overlay.dart`](#libsrcgamehud_overlaydart)
- [`lib/src/foundation/observable_adapters.dart`](#libsrcfoundationobservable_adaptersdart)
- [`lib/src/utility/web_loading.dart`](#libsrcutilityweb_loadingdart)

## `lib/src/lumina_widgets_binding.dart`

### `abstract final class LuminaWidgets`

Açılışta motoru Flutter'a bağlar: `LuminaPlatform.override`, `LuminaAssets.bundleProvider` ve
`LuminaVideoPlayback.factory` değerlerini ayarlar (her birini yalnızca host ayarlamamışsa). Üretilen bir oyun bunu
`main()` içinde `WidgetsFlutterBinding.ensureInitialized()` sonrasında çağırır; `LuminaGameWidget`, Lumina Studio'nun
açılışı ve Play de çağırır. Windows ve Linux'ta `LuminaGameWindow.backend`'i bir
[`LuminaWindowModeChannel`](#libsrcutilitywindow_mode_channeldart) olarak da ayarlar.

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `ensureInitialized` | `static void ensureInitialized()` | Tekrar çağrılabilir (idempotent). |
| `isInitialized` | `static bool get isInitialized` | Çalışıp çalışmadığı. |
| `platformOf` | `static LuminaPlatform platformOf(TargetPlatform platform)` | Bir Flutter platformunun motordaki karşılığı (aynı adlar). |

## `lib/src/game/game_host.dart`

### `typedef LuminaGameFactory`

`LuminaGame Function(String levelName)`: bir level'ı oynatan oyunu oluşturur (üretilen oyunun
`MyGame(levelName: …)` çağrısı).

### `class LuminaGameHost`

Bütün bir oyun ekranı: üstünde `LuminaWidgetLayer` bulunan [`LuminaGameWidget`](#class-luminagamewidget) ve çalışan
dünyanın `LuminaInputSubsystem`'ine aktarılan Flutter girdisi:

- her klavye tuşu motorun tuş tablosundan geçer (`LuminaKey.fromKeyId(event.logicalKey.keyId)`), basma ve bırakma;
- işaretçi hareketi `MouseX` / `MouseY` olarak: yakalanan farenin göreli hareketinden, hiçbir şey yakalanmamışken
  işaretçinin kendi deltalarından;
- fare yakalama (`LuminaMouseCapture.backend`): ilk kare yerleşince ve tıklamada alınır, biri başarılı olana dek
  işaretçi girdikçe yeniden denenir; oyuncu 0'ın controller'ı serbest imleç istediğinde (Set Show Mouse Cursor, bir UI
  input modu) bırakılır, imleci gizleyince geri alınır, dispose'da bırakılır;
- `LuminaGame.onChangeLevelRequested` / `onOpenLevelRequested`: `LuminaLevelPreloader` level'ı önceden yükleyince
  `createGame` ile o level için yeni bir oyun; `levelNames` içinde olmayan bir level `StateError` ile reddedilir.

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `createGame` | `LuminaGameFactory createGame` | Bir level adı için oyunu oluşturur. |
| `initialLevel` | `String initialLevel` | İlk oyunun oynattığı level. |
| `levelNames` | `Set<String>? levelNames` | Change Level'ın kabul ettiği level'lar; null hepsini kabul eder. |
| `targetFps` / `vsyncEnabled` | `int targetFps`, `bool vsyncEnabled` | Oyun widget'ına iletilir. |
| `captureMouse` | `bool captureMouse` | Host'un fareyi alıp almadığı (varsayılan `true`); kapalıyken işaretçi deltaları yine görüşü döndürür. |

### `class LuminaGameHostState`

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `game` | `LuminaGame get game` | Çalışan oyun (her Change Level sonrası yenisi). |
| `freeCursor` | `bool get freeCursor` | İşaretçinin serbest ve görünür olup olmadığı. |
| `changeLevel` | `Future<void> changeLevel(String levelName)` | Önceden yüklenince bir level'a geçer; o level'ın BeginPlay'inden sonra tamamlanır. |

## `lib/src/game/lumina_widget.dart`

### `class LuminaGameHostConfiguration`

Her viewport kendi karelerini sunuyorsa önizlemeleri mount işleminden önce `LuminaGameHostConfiguration(allowHeadlessFrameDriver: false, child: ...)` ile sarın. Bu ayar alt oyun widget'larının ek 1×1 swap chain ve frame driver oluşturmasını engeller; oyun ticker'ı çalışmaya devam eder. Mount öncesinde ayarlayın; sonradan değiştirmek mevcut native sahneleri yeniden oluşturmaz.

### `class LuminaGameWidget`

`frameViews`, widget'ın tek GPU karesinde birden fazla `FilamentView` kamera
bölgesi render etmesini sağlar. Callback varsayılan view ile fiziksel yüzey
genişliği ve yüksekliğini alır. Her view'ın viewport'unu sol alt köşeyi başlangıç
alarak ayarlayın. View'lar bağımsız sahne ve kamera kullanabilir. Ek view'ları
oluşturan host, engine lease bırakılmadan önce `game.disposeGame()` içinde
kaynakları serbest bırakmalıdır. Bu düzende `useHeadlessSwapChain: false`
kullanın; tek kare döngüsü ve swap chain widget tarafından sağlanır. Callback
yoksa varsayılan view önceki şekilde render edilir.


Flutter widget that embeds the `FilamentWidget` viewport and drives the [LuminaGame] loop via [LuminaFrameDriver].  The widget is the game host: it calls `LuminaWidgets.ensureInitialized` and, once per process and never on the web, `LuminaRtxController.requestExtensions` (ray tracing and DLSS need Vulkan extensions before the shared engine exists), then [LuminaGame.mountGame] and `beginPlay()` on the mounted world once `FilamentWidget` has created the scene.  Play control: - [paused] is declarative: flipping it calls [LuminaGame.pause] / [LuminaGame.resume] once the scene exists (and on scene creation if it starts `true`). - [onPlayStateChanged] receives every [LuminaPlayState] transition of [game] for the widget's lifetime — bind an editor toolbar to it.  Swap chain: - With [useHeadlessSwapChain] (default `true`, today's behaviour) the widget creates a 1×1 headless swap chain plus a [LuminaFrameDriver], so the world is ticked with a vsync-derived, frame-paced delta time and [LuminaFrameDriver.frameStats] is available to the HUD overlay. - With `false` no extra swap chain or driver is created: the ticker calls [LuminaGame.tickGame] with a fixed 1/60 s delta and `FilamentWidget` presents through its own swap chain. Use this for hosts that must not allocate a second swap chain; note that no frame stats are produced in that mode.


`decorated` ve `physicalResolution` `FilamentWidget`'a iletilir (varsayılanlar `true` / `false`: mantıksal boyutta
kenarlıklı panel). Üretilen oyunların gösterdiği ekran olan [`LuminaGameHost`](#class-luminagamehost) `false` / `true`
verir: kare pencereyi ekranın fiziksel pikselinde kenardan kenara doldurur; kenarlıksız tam ekran bir oyun
monitörün doğal çözünürlüğünde çizer.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `game` | `LuminaGame game` | `game` alanını (field/property) ve ilişkili veriyi saklar. |
| `hudBuilder` | `LuminaHudBuilder? hudBuilder` | `hudBuilder` alanını (field/property) ve ilişkili veriyi saklar. |
| `paused` | `bool paused` | Declarative pause flag forwarded to [LuminaGame.pause] / [LuminaGame.resume]. |
| `useHeadlessSwapChain` | `bool useHeadlessSwapChain` | Whether to create the 1×1 headless swap chain + [LuminaFrameDriver] (see class docs). |
| `createState` | `State<LuminaGameWidget> createState() => _LuminaGameWidgetState()` | Yeni bir `State` örneği veya ilişkili GPU kaynağını oluşturur ve yapılandırır. |

### `class _LuminaGameWidgetState`

`_LuminaGameWidgetState`: Kullanıcı arayüzünü (UI) oluşturan ve kullanıcı etkileşimlerini dinleyen shadcn_flutter bileşenidir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `initState` | `void initState()` | `initState` işlemini gerçekleştirir. |
| `didUpdateWidget` | `void didUpdateWidget(LuminaGameWidget oldWidget)` | `didUpdateWidget` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `dispose` | `void dispose()` | Yerel FFI göstericilerini, dinleyicileri ve bellek bloklarını serbest bırakır. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

## `lib/src/game/hud_overlay.dart`

### `class LuminaHudOverlay`

`LuminaHudOverlay`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `game` | `LuminaGame game` | `game` alanını (field/property) ve ilişkili veriyi saklar. |
| `hudBuilder` | `LuminaHudBuilder hudBuilder` | `hudBuilder` alanını (field/property) ve ilişkili veriyi saklar. |
| `createState` | `State<LuminaHudOverlay> createState() => _LuminaHudOverlayState()` | Yeni bir `State` örneği veya ilişkili GPU kaynağını oluşturur ve yapılandırır. |

### `class _LuminaHudOverlayState`

`_LuminaHudOverlayState`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `initState` | `void initState()` | `initState` işlemini gerçekleştirir. |
| `didUpdateWidget` | `void didUpdateWidget(LuminaHudOverlay oldWidget)` | `didUpdateWidget` işlemini gerçekleştirir. |
| `dispose` | `void dispose()` | Yerel FFI göstericilerini, dinleyicileri ve bellek bloklarını serbest bırakır. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

## `lib/src/foundation/observable_adapters.dart`

`lumina_core`'un saf değişim türlerinin Flutter görünümleri ve Flutter'ınkilerin saf görünümleri. Bir görünüm
`addListener` / `removeListener` çağrılarını kaynağına iletir ve değerini okur; kendi durumu yoktur, aynı kaynağın
görünümü iki kez istendiğinde aynı nesne döner (böylece `build` içinde çağırmak yeniden abone olmaz). Gidiş-dönüş
kaynağın kendisini verir.

| Extension | Üye | Açıklama |
| :--- | :--- | :--- |
| `ObservableAsValueListenable<T>` on `Observable<T>` | `ValueListenable<T> asValueListenable()` | `ValueListenableBuilder` için (`LuminaGraphicsDevices.inUse.asValueListenable()`). |
| `ChangeSignalAsListenable` on `ChangeSignal` | `Listenable asListenable()` | `ListenableBuilder` için (`controller.cursorState.asListenable()`). |
| `ValueListenableAsObservable<T>` on `ValueListenable<T>` | `Observable<T> asObservable()` | Saf koda (bir plugin süreci API'sine) verilen bir Flutter değeri. |
| `ListenableAsChangeSignal` on `Listenable` | `ChangeSignal asChangeSignal()` | Saf koda verilen bir Flutter notifier'ı. |

## `lib/src/utility/window_mode_channel.dart`

### `class LuminaWindowModeChannel implements LuminaWindowModeBackend`

Üretilen runner'ın penceresi ([`LuminaGameWindow.backend`](../lumina/game.md#libsrcgamegame_windowdart)),
`lumina/game_window` method channel'ı üzerinden; `LuminaWidgets.ensureInitialized` Windows ve Linux'ta kurar. Runner
(`windows/runner/lumina_window_mode.cpp`, `linux/runner/lumina_window_mode.cc`) `getMode` (`windowed` /
`borderless_fullscreen`), `setMode {mode}` (uygulayıp uygulamadığı) ve `getInfo` (tanılama: fiziksel piksel
`[left, top, right, bottom]` olarak `window`, `monitor`, `work`; `client` `[w, h]`, `popup`, `caption`, `foreground`)
çağrılarını yanıtlar, Alt+Enter ya da F11 sonrası `modeChanged {mode}` çağırır. Bunları bilmeyen bir runner (editör,
önceden üretilmiş oyunlar) `MissingPluginException` atar: mod yok, hiçbir şey uygulanmaz.

| Üye | İmza | Açıklama |
|---|---|---|
| `channelName` | `static const String channelName = 'lumina/game_window'` | Kanal. |
| `getMode` / `setMode` / `onModeChanged` | bkz. `LuminaWindowModeBackend` | Yukarıdaki runner protokolü. |
| `windowInfo` | `Future<Map<String, Object?>?> windowInfo()` | `getInfo`; bildiren bir runner yoksa null. |

## `lib/src/utility/web_loading.dart`

### `abstract final class LuminaWebLoading`

The generated game's side of the web loading screen.

A web build's `index.html` shows a plain HTML/CSS screen from the first byte; its `loading.js` tracks the Flutter engine's download itself and exposes `window.luminaLoading.progress(fraction, label)`. Once Dart runs, the generated `main()` calls [prepareGame], which loads the renderer's WebAssembly module and preloads the game's bundled assets, reporting each step there, before `runApp`. The screen fades out on Flutter's first frame, so it covers the whole download.

Native builds skip all of it: [prepareGame] returns at once and nothing here imports `dart:js_interop` outside the web (conditional import).

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `engineEnd` | `static const double engineEnd` | The loading bar's phases: the Flutter engine fills it up to [engineEnd] (tracked by `loading.js` alone), the renderer's wasm from [rendererStart] to [rendererEnd] (its bytes mapped by `loading.js`, which holds the same numbers), the asset preload the rest. |
| `rendererStart` | `static const double rendererStart` |  |
| `rendererEnd` | `static const double rendererEnd` |  |
| `isWeb` | `static bool get isWeb` | Whether this is a web build. |
| `progress` | `static void progress(double fraction, String label)` | Moves the page's loading screen to [fraction] (0–1, never backwards) with [label] under it. A no-op on native builds and on pages without the loading screen. |
| `preloadedCount` | `static int get preloadedCount` | Preloaded assets not handed out yet. |
| `prepareGame` | `static Future<void> prepareGame({AssetBundle? bundle, String contentsPrefix = 'contents/'}) async` | Web builds: loads the renderer, then every asset under [contentsPrefix] in [bundle]'s manifest, reporting progress to the loading screen. Call after `LuminaAssets.defaultProvider` is set and before `runApp`. |
| `preloadAssets` | `static Future<int> preloadAssets(AssetBundle bundle, {String prefix = 'contents/', int concurrency = 4, void F...` | Loads every asset of [bundle]'s manifest whose key starts with [prefix], [concurrency] at a time, calling [onProgress] with the count done (from 0 to the total). The bytes are kept until the runtime first asks for that path: [LuminaAssets.defaultProvider] is wrapped to hand each one out once, so the level's meshes and textures do not download twice. Whatever is not asked for within [keepFor] is dropped (null: kept until [releasePreloaded]). Returns the number of assets loaded. |
| `releasePreloaded` | `static void releasePreloaded()` | Drops every preloaded asset not handed out yet. |

## `lib/src/utility/web_loading_hook_stub.dart`

**Üst düzey fonksiyonlar ve değişkenler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `isWeb` | `const bool isWeb` |  |
| `progress` | `void progress(double fraction, String label)` |  |
| `loadRenderer` | `Future<void> loadRenderer() async` |  |

## `lib/src/utility/web_loading_hook_web.dart`

### `extension type _LuminaLoadingJs._(JSObject _)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `progress` | `external void progress(JSNumber fraction, JSString label)` |  |

**Üst düzey fonksiyonlar ve değişkenler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `isWeb` | `const bool isWeb` |  |
| `progress` | `void progress(double fraction, String label)` | Reports to `window.luminaLoading.progress`; a page without the loading screen (a hand-written index.html) is left alone. |
| `loadRenderer` | `Future<void> loadRenderer()` | Downloads and instantiates the renderer's WebAssembly module. |

---

[Üst: lumina_widgets](index.md) | [Sonraki: UMG](umg.md)
