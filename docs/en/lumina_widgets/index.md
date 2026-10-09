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
`WidgetsFlutterBinding.ensureInitialized()`; `LuminaGameWidget`, Lumina Studio's start-up and Play call it too.

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
  nothing is captured;
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
| `targetFps` / `vsyncEnabled` | `int targetFps`, `bool vsyncEnabled` | Forwarded to the game widget. |
| `captureMouse` | `bool captureMouse` | Whether the host takes the mouse (default `true`); off, pointer deltas still turn the view. |

### `class LuminaGameHostState`

| Member | Signature | Description |
| :--- | :--- | :--- |
| `game` | `LuminaGame get game` | The running game (a new one after each Change Level). |
| `freeCursor` | `bool get freeCursor` | Whether the pointer is free and visible. |
| `changeLevel` | `Future<void> changeLevel(String levelName)` | Switches to a level once preloaded; completes after its BeginPlay. |

## `lib/src/game/lumina_widget.dart`

### `class LuminaGameHostConfiguration`

Wrap embedded previews in `LuminaGameHostConfiguration(allowHeadlessFrameDriver: false, child: ...)` before mounting when each viewport already presents its own frames. This disables the additional 1×1 swap chain and frame driver for descendant game widgets; their game ticker remains active. Configure it before mounting; changing this option does not rebuild existing native scenes.

### `class LuminaGameWidget`

`frameViews` optionally selects multiple `FilamentView` camera regions for the
widget's single GPU frame. Its callback receives the default view and physical
surface width/height; set each view's viewport using bottom-left coordinates.
Views may use independent scenes and cameras. The host owns any additional
views and must release them in `game.disposeGame()` before its engine lease is
released. For this arrangement use `useHeadlessSwapChain: false` so the widget
provides the only frame driver and swap chain. Without the callback, the default
view renders as before.


Flutter widget that embeds the `FilamentWidget` viewport and drives the [LuminaGame] loop via [LuminaFrameDriver].  The widget is the game host: it calls `LuminaWidgets.ensureInitialized` and, once per process and never on the web, `LuminaRtxController.requestExtensions` (ray tracing and DLSS need Vulkan extensions before the shared engine exists), then [LuminaGame.mountGame] and `beginPlay()` on the mounted world once `FilamentWidget` has created the scene.  Play control: - [paused] is declarative: flipping it calls [LuminaGame.pause] / [LuminaGame.resume] once the scene exists (and on scene creation if it starts `true`). - [onPlayStateChanged] receives every [LuminaPlayState] transition of [game] for the widget's lifetime — bind an editor toolbar to it.  Swap chain: - With [useHeadlessSwapChain] (default `true`, today's behaviour) the widget creates a 1×1 headless swap chain plus a [LuminaFrameDriver], so the world is ticked with a vsync-derived, frame-paced delta time and [LuminaFrameDriver.frameStats] is available to the HUD overlay. - With `false` no extra swap chain or driver is created: the ticker calls [LuminaGame.tickGame] with a fixed 1/60 s delta and `FilamentWidget` presents through its own swap chain. Use this for hosts that must not allocate a second swap chain; note that no frame stats are produced in that mode.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `game` | `LuminaGame game` | Holds the `game` property or configuration state. |
| `hudBuilder` | `LuminaHudBuilder? hudBuilder` | Holds the `hudBuilder` property or configuration state. |
| `paused` | `bool paused` | Declarative pause flag forwarded to [LuminaGame.pause] / [LuminaGame.resume]. |
| `useHeadlessSwapChain` | `bool useHeadlessSwapChain` | Whether to create the 1×1 headless swap chain + [LuminaFrameDriver] (see class docs). |
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
