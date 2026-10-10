[Türkçe](../../tr/lumina_widgets/index.md)

# lumina_widgets — the Flutter side of a game

`lumina_widgets` holds everything a running game shows or reads through Flutter, on top of the engine package
(`lumina`), which has no widget, UMG or media UI of its own:

- the game widget that hosts the Filament view and drives the game loop ([`LuminaGameWidget`](#libsrcgamelumina_widgetdart)),
  and the game screen a generated game shows ([`LuminaGameHost`](#libsrcgamegame_hostdart)): keyboard, pointer and mouse
  capture (`lumina_mouse_capture`) bridged into the world's `LuminaInputSubsystem`, Open Level / Change Level;
- the HUD overlay and the on-screen `Print String` lines ([`LuminaHudOverlay`](#libsrcgamehud_overlaydart));
- UMG: the runtime widgets, their element bindings, the widget layer and builders, the theme colour extensions
  ([UMG page](umg.md));
- media players on media_kit and the UMG media widgets ([media page](media.md));
- the web build's loading-screen glue ([`LuminaWebLoading`](#libsrcutilityweb_loadingdart));
- Flutter views of the engine's pure observables ([adapters](#libsrcfoundationobservable_adaptersdart)) and
  [`LuminaWidgets.ensureInitialized`](#libsrclumina_widgets_bindingdart), which hands the engine what it needs from
  Flutter.

File paths are relative to the `lumina_widgets/` package directory.

## Libraries

| Library | What it is |
| :--- | :--- |
| `package:lumina_widgets/lumina_game.dart` | What a game imports: `package:lumina/lumina_runtime.dart` (the engine runtime), `lumina_widgets.dart` and `lumina_mouse_capture`. The code generator writes it into the launcher, levels, input, character, game mode and UMG widget files. |
| `package:lumina_widgets/lumina_widgets.dart` | This package alone. Lumina Studio reaches it through `package:lumina_editor_data/lumina_editor.dart`; `lumina_editor_api` re-exports the media players and the observable adapters. |

Compiled Blueprint classes and their registries (`lib/actors/`, `lib/anim/`, `blueprint_registry.g.dart`,
`blueprint/blueprint_functions.g.dart`) use the engine only and keep importing `package:lumina/lumina_runtime.dart`.
A project depends on both `lumina` and `lumina_widgets` (`ProjectEngineLink` writes the two git dependencies and the
local overrides); opening an older project rewrites the files that use the game UI and adds the dependency
(`LuminaGeneratedCodeMigration.migrateGameImports` / `migratePubspecGameDependency`).

## What the engine leaves to this package

The engine imports no Flutter UI library (`lumina/test/architecture/engine_has_no_widgets_test.dart` walks
`lumina.dart` and `lumina_runtime.dart` through every package they reach; `dart:ui` is allowed only in the three
image-codec libraries it lists, and `package:flutter/foundation.dart` nowhere). Where it needs something from the
app, it exposes a seam that this package fills at start-up:

| Engine seam | Filled with | Used by |
| :--- | :--- | :--- |
| `LuminaPlatform.override` | Flutter's `defaultTargetPlatform` | `Get Platform Name` (`LuminaPlatform.displayName`); without it the platform comes from `dart:io` (`web` in a web build). |
| `LuminaAssets.bundleProvider` | `rootBundle` | The procedural sky's shader and textures (`packages/lumina/assets/sky/…`). |
| `LuminaVideoPlayback.factory` | `LuminaVideoController` (media_kit) | The Blueprint video nodes (`Open Video` returns null without it). |

Engine state notifies through `lumina_core`'s pure types (`ChangeSignal`, `Observable`, `ChangeEmitter`,
`ObservableValue`): `LuminaGameInstance` is a `ChangeEmitter`, `LuminaPlayerController.cursorState` a `ChangeSignal`,
`LuminaWidgetSubsystem.activeWidgets` and `LuminaGraphicsDevices.inUse` are `ObservableValue`s. Widgets listen through
`asListenable()` / `asValueListenable()`.

**On this page:**

- [`lib/src/lumina_widgets_binding.dart`](#libsrclumina_widgets_bindingdart)
- [`lib/src/game/game_host.dart`](#libsrcgamegame_hostdart)
- [`lib/src/game/lumina_widget.dart`](#libsrcgamelumina_widgetdart)
- [`lib/src/game/hud_overlay.dart`](#libsrcgamehud_overlaydart)
- [`lib/src/foundation/observable_adapters.dart`](#libsrcfoundationobservable_adaptersdart)
- [`lib/src/utility/web_loading.dart`](#libsrcutilityweb_loadingdart)

## `lib/src/lumina_widgets_binding.dart`

### `abstract final class LuminaWidgets`

Connects the engine to Flutter at start-up: sets `LuminaPlatform.override`, `LuminaAssets.bundleProvider` and
`LuminaVideoPlayback.factory` (each only when the host has not set it). A generated game calls it in `main()` after
`WidgetsFlutterBinding.ensureInitialized()`; `LuminaGameWidget`, Lumina Studio's start-up and Play call it too. On
Windows and Linux it also sets `LuminaGameWindow.backend` to a [`LuminaWindowModeChannel`](#libsrcutilitywindow_mode_channeldart).

| Member | Signature | Description |
| :--- | :--- | :--- |
| `ensureInitialized` | `static void ensureInitialized()` | Idempotent. |
| `isInitialized` | `static bool get isInitialized` | Whether it ran. |
| `platformOf` | `static LuminaPlatform platformOf(TargetPlatform platform)` | The engine's platform for a Flutter one (same names). |

## `lib/src/game/game_host.dart`

### `typedef LuminaGameFactory`

`LuminaGame Function(String levelName)`: creates the game that plays a level (a generated game's
`MyGame(levelName: …)`).

### `class LuminaGameHost`

A whole game screen: the [`LuminaGameWidget`](#class-luminagamewidget) with the `LuminaWidgetLayer` on top, and the
Flutter input bridged into the running world's `LuminaInputSubsystem`:

- every keyboard key through the engine's key table (`LuminaKey.fromKeyId(event.logicalKey.keyId)`), key down and up;
- pointer motion as `MouseX` / `MouseY`: from the captured mouse's relative motion, or the pointer's own deltas while
  nothing is captured; these look deltas are never scaled by the screen resolution (the same hand movement turns the
  view the same at any resolution);
- the pointer position (`Get Mouse Position`) in the view's pixels, the space of `Get Viewport Size`, `Project World to
  Screen` and `Deproject Screen to World` ([`LuminaRenderSpace`](#class-luminarenderspace)): with a letterboxed screen
  resolution it is relative to the picture and in the chosen resolution's pixels, clamped to the picture's edge over
  the black bars; windowed it is the window position × the device pixel ratio;
- mouse buttons as `LeftMouseButton` / `RightMouseButton` / `MiddleMouseButton` / thumb keys: while the cursor is
  visible, only clicks on the picture that the game's UI does not take (a UMG button consumes its click; clicks on the
  black bars reach nothing; Input Mode UI Only sends none); while the game holds the hidden, captured cursor, every
  click. A release always reaches the game;
- mouse capture (`LuminaMouseCapture.backend`): taken once the first frame laid out and on a click, retried while the
  pointer enters until one succeeds, released while player 0's controller wants a free cursor (Set Show Mouse Cursor, a
  UI input mode) and taken back when it hides the cursor, released on dispose;
- `LuminaGame.onChangeLevelRequested` / `onOpenLevelRequested`: a new game from `createGame` on that level once
  `LuminaLevelPreloader` preloaded it; a level not in `levelNames` is refused with a `StateError`.

| Member | Signature | Description |
| :--- | :--- | :--- |
| `createGame` | `LuminaGameFactory createGame` | Creates the game for a level name. |
| `initialLevel` | `String initialLevel` | The level the first game plays. |
| `levelNames` | `Set<String>? levelNames` | The levels Change Level accepts; null accepts any. |
| `targetFps` / `vsyncEnabled` | `int targetFps`, `bool vsyncEnabled` | The project's settings, forwarded to the game widget: the defaults of `LuminaGameFramePacing` until the player applies their own. |
| `captureMouse` | `bool captureMouse` | Whether the host takes the mouse (default `true`); off, pointer deltas still turn the view. |

### `class LuminaGameHostState`

| Member | Signature | Description |
| :--- | :--- | :--- |
| `game` | `LuminaGame get game` | The running game (a new one after each Change Level). |
| `freeCursor` | `bool get freeCursor` | Whether the pointer is free and visible. |
| `changeLevel` | `Future<void> changeLevel(String levelName)` | Switches to a level once preloaded; completes after its BeginPlay. |

## `lib/src/game/lumina_widget.dart`

### `class LuminaGameHostConfiguration`

Wrap embedded previews in `LuminaGameHostConfiguration(allowHeadlessFrameDriver: false, child: ...)` before mounting when each viewport already presents its own frames. This disables the frame driver for descendant game widgets (their world is ticked by the game ticker with the real interval between frames); the driver never renders the view either way. Configure it before mounting; changing this option does not rebuild existing native scenes.

### `class LuminaGameWidget`

`frameViews` optionally selects multiple `FilamentView` camera regions for the
widget's single GPU frame. Its callback receives the default view and physical
surface width/height; set each view's viewport using bottom-left coordinates.
Views may use independent scenes and cameras. The host owns any additional
views and must release them in `game.disposeGame()` before its engine lease is
released. For this arrangement use `useHeadlessSwapChain: false` so the game ticker
drives the world. Without the callback, the default
view renders as before.


Flutter widget that embeds the `FilamentWidget` viewport and drives the [LuminaGame] loop via [LuminaFrameDriver].  The widget is the game host: it calls `LuminaWidgets.ensureInitialized` and, once per process and never on the web, `LuminaRtxController.requestExtensions` (ray tracing and DLSS need Vulkan extensions before the shared engine exists), then [LuminaGame.mountGame] and `beginPlay()` on the mounted world once `FilamentWidget` has created the scene.  Play control: - [paused] is declarative: flipping it calls [LuminaGame.pause] / [LuminaGame.resume] once the scene exists (and on scene creation if it starts `true`). - [onPlayStateChanged] receives every [LuminaPlayState] transition of [game] for the widget's lifetime — bind an editor toolbar to it.  Frame driver: the `FilamentWidget` is the only renderer of the game's view on both presentation paths, so the view's temporal history (TAA, upscalers, frame generation) advances once per shown frame. - With [useHeadlessSwapChain] (default `true`; the name is historical, no swap chain is created) the world is ticked by a [LuminaFrameDriver] built without a swap chain: a vsync-derived, frame-paced delta time; `onFrameDriver` receives the driver. - With `false` the ticker calls [LuminaGame.tickGame] with the real interval between ticked refreshes as the delta.  Frame rate: [targetFps] and [vsyncEnabled] are the project's settings, the defaults of `LuminaGameFramePacing`, which the player's choice (Set Target FPS / Set VSync Enabled + Apply Scalability Settings, or the one restored from `GameUserSettings.json`) overrides. The widget follows what is in force at once: the world ticks and the view renders on the same display refreshes (one shared `FilamentFrameLimiter`); the frame is presented by Flutter on the display's vsync, so no target goes above the refresh rate ([lumina game.md](../lumina/game.md)).


`decorated` and `physicalResolution` are forwarded to `FilamentWidget` (defaults `true` / `false`: the bordered panel
at logical size). [`LuminaGameHost`](#class-luminagamehost), the screen generated games show, passes `false` /
`true`: the frame fills the window edge to edge at the display's physical pixels, so a borderless fullscreen game
renders at the monitor's native resolution. It also passes `followScreenResolution: true`: the view then renders at
`LuminaGameDisplay.renderResolution` (the player's screen resolution in borderless fullscreen, or where the window
cannot be resized) through `FilamentWidget.renderResolution`, scaled into the largest box of its aspect ratio, centred
on black (`LuminaScreenResolutionBox`, `lib/src/game/screen_resolution_box.dart`). The widget tree stays the same when
the resolution changes, so the view and its engine resources survive. The game's UI (`hudBuilder` and
`LuminaGameWidget.viewportOverlay`, where the host puts the UMG layer) is laid out in the same box, at the chosen
resolution's logical size (`LuminaRenderSpace.layoutSize`, the resolution / device pixel ratio) and scaled with the
picture, so it looks as in a window of that resolution and is drawn and hit where the picture is, never on the bars.

### Direct presentation

`allowDirectPresentation` (false; `LuminaGameHost` passes true, the editor never) and `presentation` (the project's
`LuminaPresentationMode`) let a built game present directly when `LuminaGamePresentation.requested` says so. The
widget then gives its `FilamentWidget` a `LuminaWindowSurface` (`lib/src/game/window_surface.dart`: the runner's
presentation window over the `lumina/game_window` channel: `createSurface`, `destroySurface`, `surfaceChanged`) and
publishes the `FilamentUiOverlay` it gets to `LuminaUiCapture.directOverlay`; on a fallback it reports the reason
(`LuminaGamePresentation.reportFallback`, logged once) and stays on the texture path. The tree never changes shape, so
switching keeps the view and the UI. On both paths the `FilamentWidget`'s render is the only render of the view (the
frame driver only ticks the world), and while presenting directly `LuminaScreenResolutionBox(barsOnly: true)` paints
black only on the bars.

**Frame generation on the Flutter path.** Frame generation in force asks for Direct by itself, which is where its
frames reach the screen. When it stays on while the game presents through Flutter (the player chose Flutter, Direct
fell back, the editor), the game keeps running: the `FilamentWidget` renders the view once per frame into its headless
swap chain, reads it back and Flutter shows that frame; the generated frames are presented into the headless swap
chain and never shown. The widget logs a warning (`Frame generation is on but the game presents through Flutter
(<reason>) ...`) once each time this starts. Earlier the frame driver rendered the view a second time into a 1x1
headless swap chain; with frame generation on that stalled the readback (repeated `readPixels` fence timeouts, the
game froze), and with it off it cost frame rate (offscreen, RTX PRO 2000, five props: 199 vs 405 frames/s at
1024x768, 137 vs 206 at 1920x1080, 92.5 vs 118 at 3440x1440; `test/smoke/flutter_presentation_frame_generation_smoke_test.dart`).

`LuminaUiCapture` (`lib/src/game/ui_capture.dart`) renders its child offscreen for a `FilamentUiOverlay`: the child is
its own compositing layer; a picture is taken only after a frame that added that layer to the scene again (any change
under it, nested repaint boundaries included) or changed its size, at the device pixel ratio (`toImageSync` +
`toByteData(rawRgba)`, premultiplied), one capture at a time; `stats` (`LuminaUiCaptureStats`: captures, skipped
frames, size, readback / upload / latency microseconds). `LuminaUiCaptureRoot` wraps a whole app (a generated
`main()` runs `runApp(const LuminaUiCaptureRoot(child: MyLuminaGameApp()))`) so everything Flutter draws (popups,
dialogs, overlays) reaches the picture; the generated app's Scaffold is transparent. Without a root the game widget
captures its own subtree.

### `class LuminaRenderSpace`

`lib/src/game/render_space.dart`. The game's render space inside the area that shows it, the one mapping the host, the
resolution box and the tests share: `rect` (where the picture is drawn, letterboxed for a `renderResolution`),
`viewportPixels` (what the view renders and `Get Viewport Size` reports: the chosen resolution, else the space × the
device pixel ratio for a physical-pixel view), `layoutSize` (the UI's logical size), `toViewport(local)` (view pixels,
null on the bars), `clampToViewport(local)` and `fromViewport(pixels)`. Resolution Scale and the FSR3 / DLSS upscalers
render inside the view at a lower internal size; positions stay in the view's output pixels.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `game` | `LuminaGame game` | Holds the `game` property or configuration state. |
| `hudBuilder` | `LuminaHudBuilder? hudBuilder` | Holds the `hudBuilder` property or configuration state. |
| `paused` | `bool paused` | Declarative pause flag forwarded to [LuminaGame.pause] / [LuminaGame.resume]. |
| `useHeadlessSwapChain` | `bool useHeadlessSwapChain` | Whether a [LuminaFrameDriver] ticks the world (frame-paced delta time; historical name, no swap chain is created). |
| `onFrameDriver` | `ValueChanged<LuminaFrameDriver>? onFrameDriver` | Receives the frame driver once the scene exists (not called without one). |
| `createState` | `State<LuminaGameWidget> createState() => _LuminaGameWidgetState()` | Creates, configures, and returns a new `State` instance or associated GPU resource. |

### `class _LuminaGameWidgetState`

`_LuminaGameWidgetState`: shadcn_flutter UI component rendering interface elements and listening to interactions.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `initState` | `void initState()` | Executes `initState` operation. |
| `didUpdateWidget` | `void didUpdateWidget(LuminaGameWidget oldWidget)` | Getter accessor returning the current value of `didUpdateWidget`. |
| `dispose` | `void dispose()` | Releases native FFI pointers, event subscriptions, and allocated memory. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

## `lib/src/game/hud_overlay.dart`

### `class LuminaHudOverlay`

`LuminaHudOverlay`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `game` | `LuminaGame game` | Holds the `game` property or configuration state. |
| `hudBuilder` | `LuminaHudBuilder hudBuilder` | Holds the `hudBuilder` property or configuration state. |
| `createState` | `State<LuminaHudOverlay> createState() => _LuminaHudOverlayState()` | Creates, configures, and returns a new `State` instance or associated GPU resource. |

### `class _LuminaHudOverlayState`

`_LuminaHudOverlayState`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `initState` | `void initState()` | Executes `initState` operation. |
| `didUpdateWidget` | `void didUpdateWidget(LuminaHudOverlay oldWidget)` | Executes `didUpdateWidget` operation. |
| `dispose` | `void dispose()` | Releases native FFI pointers, event subscriptions, and allocated memory. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

## `lib/src/foundation/observable_adapters.dart`

Flutter views of `lumina_core`'s pure change types and pure views of Flutter's. A view forwards `addListener` /
`removeListener` to its source and reads its value; it keeps no state, and asking for the view of the same source twice
returns the same object (so calling it in `build` does not resubscribe). A round trip returns the source.

| Extension | Member | Description |
| :--- | :--- | :--- |
| `ObservableAsValueListenable<T>` on `Observable<T>` | `ValueListenable<T> asValueListenable()` | For a `ValueListenableBuilder` (`LuminaGraphicsDevices.inUse.asValueListenable()`). |
| `ChangeSignalAsListenable` on `ChangeSignal` | `Listenable asListenable()` | For a `ListenableBuilder` (`controller.cursorState.asListenable()`). |
| `ValueListenableAsObservable<T>` on `ValueListenable<T>` | `Observable<T> asObservable()` | A Flutter value handed to pure code (a plugin process API). |
| `ListenableAsChangeSignal` on `Listenable` | `ChangeSignal asChangeSignal()` | A Flutter notifier handed to pure code. |

## `lib/src/utility/window_mode_channel.dart`

### `class LuminaWindowModeChannel implements LuminaWindowModeBackend, LuminaDisplayBackend`

The generated runner's window ([`LuminaGameWindow.backend`](../lumina/game.md#libsrcgamegame_windowdart)) over the
`lumina/game_window` method channel; `LuminaWidgets.ensureInitialized` installs it on Windows and Linux. The runner
(`windows/runner/lumina_window_mode.cpp`, `linux/runner/lumina_window_mode.cc`) answers `getMode` (`windowed` /
`borderless_fullscreen`), `setMode {mode}` (whether it applied) and `getInfo` (diagnostics: `window`, `monitor`, `work`
as `[left, top, right, bottom]` physical pixels, `client` `[w, h]`, `popup`, `caption`, `foreground`), and calls
`modeChanged {mode}` after Alt+Enter or F11. For the screen resolution ([`LuminaGameDisplay.backend`](../lumina/game.md#libsrcgamegame_displaydart-display_infodart-game_user_settings_filedart),
the same object) it answers `getDisplays` (monitors with name, device, bounds, work area, current mode, every mode,
scale; the current monitor; the client size), `setClientSize {width, height}` (the client size it got) and
`moveToMonitor {index}`, and calls `displayChanged` when a display changes or the window moves to another monitor.
For direct presentation it answers `createSurface` (`{handle, width, height}` or an `unsupported` error) and
`destroySurface`, and calls `surfaceChanged`; `onSurfaceChanged` receives those.
A runner without them (the editor, games generated earlier) throws `MissingPluginException`: no mode, no displays,
nothing applied.

`LuminaWebDisplayBackend` (`lib/src/utility/web_display_backend.dart`) is the web's display backend: one monitor, the
browser screen (`window.screen` × `devicePixelRatio`) with its current mode only and no refresh rate, the page's
viewport as client size; it cannot resize or move the window, so a chosen resolution renders scaled in the canvas.

| Member | Signature | Description |
|---|---|---|
| `channelName` | `static const String channelName = 'lumina/game_window'` | The channel. |
| `getMode` / `setMode` / `onModeChanged` | see `LuminaWindowModeBackend` | The runner protocol above. |
| `windowInfo` | `Future<Map<String, Object?>?> windowInfo()` | `getInfo`, or null without a runner that reports it. |
| `queryDisplays` / `setClientSize` / `moveToMonitor` / `onDisplayChanged` | see `LuminaDisplayBackend` | The display protocol above. |

## `lib/src/utility/web_loading.dart`

### `abstract final class LuminaWebLoading`

The generated game's side of the web loading screen.

A web build's `index.html` shows a plain HTML/CSS screen from the first byte; its `loading.js` tracks the Flutter engine's download itself and exposes `window.luminaLoading.progress(fraction, label)`. Once Dart runs, the generated `main()` calls [prepareGame], which loads the renderer's WebAssembly module and preloads the game's bundled assets, reporting each step there, before `runApp`. The screen fades out on Flutter's first frame, so it covers the whole download.

Native builds skip all of it: [prepareGame] returns at once and nothing here imports `dart:js_interop` outside the web (conditional import).

**Members:**

| Member | Signature | Description |
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

**Top-level functions and variables:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `isWeb` | `const bool isWeb` |  |
| `progress` | `void progress(double fraction, String label)` |  |
| `loadRenderer` | `Future<void> loadRenderer() async` |  |

## `lib/src/utility/web_loading_hook_web.dart`

### `extension type _LuminaLoadingJs._(JSObject _)`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `progress` | `external void progress(JSNumber fraction, JSString label)` |  |

**Top-level functions and variables:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `isWeb` | `const bool isWeb` |  |
| `progress` | `void progress(double fraction, String label)` | Reports to `window.luminaLoading.progress`; a page without the loading screen (a hand-written index.html) is left alone. |
| `loadRenderer` | `Future<void> loadRenderer()` | Downloads and instantiates the renderer's WebAssembly module. |

---

[Up: lumina_widgets](index.md) | [Next: UMG](umg.md)
