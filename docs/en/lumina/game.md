[Türkçe](../../tr/lumina/game.md)

# Game framework

The game framework that ties a world to a running app: the game instance and its subsystems, game mode and game state, `LuminaGame`, play state, the player camera manager, player starts, primitive actors and the template character. File paths are relative to the `lumina/` package directory.

**On this page:**

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

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `owner` | `LuminaGameInstance? get owner` | The game instance this subsystem is bound to. |
| `isInitialized` | `bool get isInitialized` | Whether this subsystem has been initialized. |
| `onInitialize` | `void onInitialize(LuminaGameInstance owner)` | Called when the subsystem is registered with the game instance. |
| `onDeinitialize` | `void onDeinitialize()` | Called when the game instance is shutting down. |

### `class LuminaGameInstance`

The engine-lifetime singleton surviving world transitions. It is a `ChangeEmitter` (`lumina_core`): listeners hear when the world changes; a widget listens through `asListenable()` (`lumina_widgets`). The game widget, the game host and the HUD that show a game are in [lumina_widgets](../lumina_widgets/index.md).

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
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

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `gameState` | `LuminaGameState get gameState` | The game state for this mode. Available after [initGame]. |
| `hasMatchStarted` | `bool get hasMatchStarted` | Whether the match has started. |
| `hasMatchEnded` | `bool get hasMatchEnded` | Whether the match has ended. |
| `initGame` | `void initGame(LuminaWorld world)` | Called once before any actor onBeginPlay. Creates the game state. |
| `autoActivatedCamera` | `LuminaCameraActor? autoActivatedCamera()` | The first camera actor in the world with `autoActivateForPlayer` set, or null; `login` makes it the new player's view target. |
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

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
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

The game window's mode on the desktop. The generated runner (`windows/runner/lumina_window_mode.cpp`,
`linux/runner/lumina_window_mode.cc`, written by `GameWindowRunnerService` in lumina_editor_data) opens the window in
the project's **Start Fullscreen** mode, toggles it on Alt+Enter and F11 and answers the `lumina/game_window` channel;
`LuminaWindowModeChannel` (lumina_widgets) is the [LuminaGameWindow.backend] it talks to. The generated `main()` calls
[LuminaGameWindow.restore] before `runApp`, so the player's last choice is back before the first frame.

### `enum LuminaWindowMode`

| Value | `id` | `label` | Meaning |
|---|---|---|---|
| `windowed` | `windowed` | `Windowed` | A normal window with title bar and borders; Alt+Enter restores the size and place it had. |
| `borderlessFullscreen` | `borderless_fullscreen` | `Borderless Fullscreen` | Windows: a `WS_POPUP` window covering the whole monitor it is on (`MonitorFromWindow` → `rcMonitor`, taskbar included) at the monitor's physical resolution, no title bar, border or rounded corners. Linux: `gtk_window_fullscreen` (X11 and Wayland). |

`parse(text)` accepts an `id`, a `label`, `fullscreen` or `borderless` (case, spaces, `_` and `-` ignored); null otherwise.

There is no exclusive mode (and so no `VK_EXT_full_screen_exclusive`): Filament renders into a headless swap chain
whose frame Flutter's compositor presents, so the game never owns a presentable swap chain that could take the display
exclusively. A borderless window covering the monitor is what current games default to; the compositor presents it
without an extra copy, and Alt+Tab and overlays keep working.

### `abstract interface class LuminaWindowModeBackend`

| Member | Signature | Description |
|---|---|---|
| `getMode` | `Future<LuminaWindowMode?> getMode()` | The window's mode; null from a runner without window-mode support (generated before it). |
| `setMode` | `Future<bool> setMode(LuminaWindowMode mode)` | Shows the window in `mode`; whether the runner applied it. |
| `onModeChanged` | `set onModeChanged(void Function(LuminaWindowMode)? listener)` | Called when the runner changed the mode itself (Alt+Enter, F11). |

### `abstract final class LuminaGameWindow`

| Member | Signature | Description |
|---|---|---|
| `backend` | `static LuminaWindowModeBackend? backend` | The runner's window; `LuminaWidgets.ensureInitialized` sets it on Windows and Linux. Null in tests and on the web. |
| `mode` | `static final ObservableValue<LuminaWindowMode> mode` | The current mode (what `Get Fullscreen Mode` reads). |
| `settingsFilePath` | `static String? settingsFilePath` | Where the player's choice is kept; null keeps nothing (Play-In-Editor). |
| `settingsKey` | `static const String settingsKey = 'window_mode'` | Its key in that JSON file; other keys of the file are kept. |
| `settingsFileFor` | `static String settingsFileFor(String saveGamesDirectory)` | `<app support>/<game>/SaveGames` → `<app support>/<game>/SaveGames/GameUserSettings.json`, the file shared with the graphics settings (`LuminaGameUserSettingsFile`). |
| `restore` | `static Future<LuminaWindowMode> restore({LuminaWindowMode startMode = windowed, String? settingsFilePath})` | Merges a legacy `user_settings.json` once, applies the saved choice, or `startMode` (Project Settings > Start Fullscreen) when there is none, then the saved screen resolution and monitor (`LuminaGameDisplay.restore`), and listens to the runner's toggles (each one is saved and re-applies the resolution). A runner already in the mode is left alone. |
| `setMode` | `static Future<bool> setMode(LuminaWindowMode next)` | Records and saves `next` and asks the runner to apply it; false without a runner (the mode is still recorded). |
| `toggle` | `static Future<bool> toggle()` | Windowed ↔ borderless fullscreen. |
| `pendingWrite` | `static Future<void> get pendingWrite` | Completes when the last change and its settings write are done. |
| `resetForTesting` | `static void resetForTesting()` | A fresh process's state. |

## `lib/src/game/game_display.dart`, `display_info.dart`, `game_user_settings_file.dart`

The screen resolution and the monitors. The generated runner's `lumina/game_window` channel also answers
`getDisplays`, `setClientSize` and `moveToMonitor` and calls `displayChanged`; `LuminaWindowModeChannel` (lumina_widgets)
is the [LuminaGameDisplay.backend] on Windows and Linux, `LuminaWebDisplayBackend` on the web.

### Models

| Type | Members | Description |
|---|---|---|
| `LuminaDisplayMode` | `width`, `height`, `refreshRate` (Hz, 0 = unknown); `toList`, `fromList` | One mode in physical pixels. |
| `LuminaMonitor` | `index`, `name` (model, e.g. `DELL U3419W`), `device` (`\\.\DISPLAY1`), `primary`, `bounds`, `workArea` (`LuminaScreenRect`), `current`, `modes`, `scale`; `resolutions`, `refreshRatesFor(w, h)`, `fromMap`, `toMap` | `resolutions`: the distinct sizes of `modes` plus the current one, ascending by width then height. |
| `LuminaDisplayInfo` | `monitors`, `currentMonitor`, `clientSize`, `current`; `fromMap`, `toMap` | The runner's `getDisplays` answer (null without a usable monitor). |

### `abstract interface class LuminaDisplayBackend`

| Member | Signature | Description |
|---|---|---|
| `queryDisplays` | `Future<LuminaDisplayInfo?> queryDisplays()` | The monitors and the client area; null from a runner without display support. |
| `setClientSize` | `Future<(int, int)?> setClientSize(int width, int height)` | Windowed: the client area in physical pixels, clamped to the monitor's work area and centred; returns what it got. Null when the window cannot be resized (web, older runners). |
| `moveToMonitor` | `Future<bool> moveToMonitor(int index)` | Fullscreen: covers that monitor (and centres the windowed placement there); windowed: centres the window on it. |
| `onDisplayChanged` | `set onDisplayChanged(void Function(LuminaDisplayInfo)? listener)` | A display changed, or the window ended up on another monitor. |

### `abstract final class LuminaGameDisplay`

What the chosen resolution means: **windowed**, the window's client area (the game renders at the client size);
**borderless fullscreen**, the window keeps covering the monitor and the game's render target (the Filament view and
its texture) is the chosen size, which `LuminaGameWidget(followScreenResolution: true)` scales to the monitor with
its aspect ratio kept (black bars). A size at least the monitor's renders native. A window that cannot be resized
(web, no runner) renders the chosen size scaled, as in fullscreen. The display mode itself never changes (no
exclusive fullscreen). It is the render target, not Filament's dynamic resolution, because dynamic resolution keeps
the viewport at the monitor size (no letterbox) and the upscalers already own its scale: with the view at the chosen
size, **Resolution Scale** renders at chosen × scale and **FSR3 / DLSS** render at their quality scale of the chosen
size and output the chosen size; Flutter then scales that frame to the monitor. `Get Viewport Size` is that output size, and the game host maps the pointer into it (`LuminaRenderSpace` in lumina_widgets): `Get Mouse Position` is in the chosen resolution's pixels, the game's UI is laid out in the picture, clicks on the bars reach nothing.

| Member | Signature | Description |
|---|---|---|
| `backend` | `static LuminaDisplayBackend? backend` | Set by `LuminaWidgets.ensureInitialized`. |
| `info` | `static final ObservableValue<LuminaDisplayInfo?> info` | The last report (start, `displayChanged`, every apply). |
| `renderResolution` | `static final ObservableValue<(int, int)?> renderResolution` | The fixed render size the game widget follows; null: its own size. |
| `screenResolution` / `fullscreenMonitor` | `static (int, int)? get` / `static int? get` | The applied choice (null: native / where it is). |
| `apply` | `static Future<void> apply({(int, int)? resolution, int? monitor, bool persist = true})` | Takes the choice at once, then moves / resizes in order and writes `screen_resolution` / `fullscreen_monitor` to the settings file. |
| `onWindowModeChanged` | `static Future<void> onWindowModeChanged()` | Re-applies the choice for the new mode (`LuminaGameWindow` calls it after Set Fullscreen Mode, Alt+Enter, F11). |
| `restore` | `static Future<void> restore(Map<String, dynamic> settings)` | Start-up (from `LuminaGameWindow.restore`): listens for display changes, reads the displays, applies the stored choice without writing it. |
| `currentResolution`, `desktopMode`, `supportedResolutions`, `refreshRatesFor`, `monitorCount`, `currentMonitor` | static | What the Blueprint nodes return (fallbacks from the render size without a report). |
| `resolutionFrom` / `monitorFrom` / `settingsPatch` | static | The settings-file keys: `screen_resolution: {width, height}`, `fullscreen_monitor: {index, device, name}` (the device id wins over the index). |
| `pendingApply` / `resetForTesting` | static | Completes after the last apply / a fresh process's state. |

### `abstract final class LuminaGameUserSettingsFile`

The one per-player file, `<save games>/GameUserSettings.json`: a flat JSON object holding `window_mode`,
`screen_resolution`, `fullscreen_monitor` and everything `LuminaUserSettingsSubsystem.saveSettings` writes. Every
writer merges its keys (`update`) and keys it does not know are kept, so newer settings and other writers coexist;
writes are serialized. Nothing is written on the web.

| Member | Signature | Description |
|---|---|---|
| `pathFor` / `legacyPathFor` | `static String pathFor(String saveDirectory)` | `<saveDirectory>/GameUserSettings.json`; the legacy `user_settings.json` beside the save directory. |
| `read` | `static Future<Map<String, dynamic>> read(String path)` | Empty for a missing or damaged file. |
| `update` | `static Future<bool> update(String path, Map<String, Object?> patch)` | Merges `patch`; a null value removes its key. |
| `migrateLegacy` | `static Future<bool> migrateLegacy({required String path, String? legacyPath})` | Once: adds the legacy file's keys the settings file lacks (the settings file wins), then deletes the legacy file. |
| `idle` | `static Future<void> get idle` | Completes when queued writes are done. |

## `lib/src/game/lumina_game.dart`

### `class LuminaGame`

Entrypoint class for building declarative Lumina game applications.  Besides the mount / tick / dispose lifecycle it exposes the editor-facing play control surface (Play-In-Editor): [pause], [resume], [step], [restart] and a broadcast [playStateStream] a toolbar can bind to.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `gameInstance` | `final LuminaGameInstance gameInstance` | Holds the `gameInstance` property or configuration state. |
| `world` | `LuminaWorld? get world` | Getter accessor returning the current value of `world`. |
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

`LuminaMinimalViewInfo`: shadcn_flutter UI component rendering interface elements and listening to interactions.

Its `camera` is the view target's camera component when the target has one and no blend runs (null otherwise); `nearClip` / `farClip` are that camera's. The world and Play then also use its projection, clip planes and exposure.

### `enum LuminaViewTargetBlendFunction`

`LuminaViewTargetBlendFunction`: Enumeration listing system options and state constants.

### `class LuminaCameraShake`

`LuminaCameraShake`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `locationAmplitude` | `Vector3 locationAmplitude` | Holds the `locationAmplitude` property or configuration state. |
| `rotationAmplitudeDegrees` | `Vector3 rotationAmplitudeDegrees` | Holds the `rotationAmplitudeDegrees` property or configuration state. |
| `locationFrequency` | `Vector3 locationFrequency` | Holds the `locationFrequency` property or configuration state. |
| `duration` | `double duration` | Holds the `duration` property or configuration state. |
| `blendInTime` | `double blendInTime` | Holds the `blendInTime` property or configuration state. |
| `blendOutTime` | `double blendOutTime` | Holds the `blendOutTime` property or configuration state. |
| `initialPhase` | `double initialPhase` | Holds the `initialPhase` property or configuration state. |
| `isFinished` | `bool get isFinished` | Checks current state or capability and returns a boolean value. |
| `updateAndGetShake` | `Vector3 updateAndGetShake(double deltaTime)` | Updates the current state or data values. |

### `class LuminaPlayerCameraManager`

`LuminaPlayerCameraManager`: `class` representing the data model or functionality of the module.

**Constructors:**
- `LuminaPlayerCameraManager(this.playerController)`: Initializes `LuminaPlayerCameraManager(this.playerController)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `playerController` | `LuminaPlayerController playerController` | Holds the `playerController` property or configuration state. |
| `viewTarget` | `LuminaActor? get viewTarget` | Getter accessor returning the current value of `viewTarget`. |
| `setViewTarget` | `void setViewTarget(LuminaActor target)` | Updates the `ViewTarget` parameter and applies changes to the system. |
| `setFov` | `void setFov(double newFov)` | Updates the `Fov` parameter and applies changes to the system. |
| `resetFov` | `void resetFov()` | Resets values or state back to defaults. |
| `startCameraShake` | `void startCameraShake(LuminaCameraShake shake)` | Executes `startCameraShake` operation. |
| `updateCamera` | `void updateCamera(double deltaTime)` | Updates the current state or data values. |

## `lib/src/game/camera_actor.dart`

### `class LuminaCameraActor`

A camera placed in a level: a `LuminaCameraComponent` (its root, looking down its −Z, the authored +Y) carrying the level's `LuminaCameraSettings`. Its camera stays inactive, so it never takes the view from the possessed pawn by itself; it is looked through as a view target — `Set View Target with Blend` from a Blueprint, or `autoActivateForPlayer`, which makes it the view target of each player logging in (`LuminaGameMode.login`). The world then renders it with its own projection, clip planes and exposure. Play and the generated level build every placed `Camera` actor as one.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `LuminaCameraActor` | `LuminaCameraActor({LuminaObjectKey? key, Vector3? location, Quaternion? rotation, Vector3? scale, LuminaCameraSettings settings})` | A camera at the transform with the settings applied. |
| `settings` | `final LuminaCameraSettings settings` | The settings the camera was built with. |
| `cameraComponent` | `final LuminaCameraComponent cameraComponent` | The camera looked through; the actor's root. |
| `autoActivateForPlayer` | `bool get autoActivateForPlayer` | Whether a player looks through this camera from login on. |

## `lib/src/game/player_start.dart`

### `class LuminaPlayerStart`

An actor that specifies a spawn point for players in the level.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `playerStartTag` | `String? playerStartTag` | Optional tag used by the GameMode to match a specific start. |

## `lib/src/game/primitive_actor.dart`

**Top-level Functions:**

- **`LuminaPrimitiveShape luminaPrimitiveShapeFrom(String? name)`**: Parses the `shape` string an editor `LuminaProceduralMeshComponent` carries. Anything unrecognised is a box, so an old or hand-edited level still loads.
- **`Vector3 luminaHexToRgb(String? hex)`**: Parses `#RRGGBB` / `#AARRGGBB` into a 0..1 RGB vector; mid grey on error.
- **`Vector3 luminaPrimitiveSize(Map<String, dynamic> properties)`**: The runtime (Y-up) extent in cm of the basic shape an editor `LuminaProceduralMeshComponent` entry describes. Its `sizeX` / `sizeY` / `sizeZ` are authored Z up like every stored level value (`sizeZ` is the height, `sizeY` the depth along authoring Y), converted through [LuminaAxes.extent]; a missing size is 100 cm. The level viewport, Play, the level code generator and level thumbnails all read sizes here.

### `enum LuminaPrimitiveShape`

Shapes a [LuminaPrimitiveActor] can take.

### `class LuminaPrimitiveGeometry`

CPU-side vertex data for a primitive shape, in metres, centred on the actor origin. Planes lie in the XZ plane at y = 0.

**Constructors:**
- `LuminaPrimitiveGeometry(this.positions, this.normals, this.uvs, this.indices)`: Initializes `LuminaPrimitiveGeometry(this.positions, this.normals, this.uvs, this.indices)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `positions` | `Float32List positions` | Holds the `positions` property or configuration state. |
| `normals` | `Float32List normals` | Holds the `normals` property or configuration state. |
| `uvs` | `Float32List uvs` | Holds the `uvs` property or configuration state. |
| `indices` | `Uint32List indices` | Holds the `indices` property or configuration state. |
| `vertexCount` | `int get vertexCount` | Getter accessor returning the current value of `vertexCount`. |
| `solidColors` | `Uint8List solidColors(Vector3 rgb)` | One opaque RGBA vertex colour per vertex.  The colour is not optional: the gltfio ubershader drops a primitive that declares no `COLOR` attribute without drawing it at all. |
| `build` | `static LuminaPrimitiveGeometry build(LuminaPrimitiveShape shape, Vector3...` | Constructs and returns the declarative element or widget hierarchy. |

### `class LuminaPrimitiveActor`

An engine-drawn primitive authored in Lumina Studio: a [LuminaProceduralMeshComponent] section plus a matching box collider, so a character can stand on it without any imported art asset.  Both Play-In-Editor and the generated game build the same actor from the same `LuminaProceduralMeshComponent` properties in `metadata.actors`. A `materialOverrideAsset` (the actor's assigned material, a material `.lmas`) is drawn in place of the colour on every section.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `shape` | `LuminaPrimitiveShape shape` | Holds the `shape` property or configuration state. |
| `size` | `Vector3 size` | The runtime (Y-up) extent in cm: `size.y` is the height. The stored, Z-up component sizes convert through [luminaPrimitiveSize]. |
| `color` | `Vector3 color` | Holds the `color` property or configuration state. |
| `meshComponent` | `final LuminaProceduralMeshComponent meshComponent` | Holds the `meshComponent` property or configuration state. |
| `collisionComponent` | `final LuminaCollisionComponent collisionComponent` | Holds the `collisionComponent` property or configuration state. |
| `onBeginPlay` | `void onBeginPlay()` | Callback invoked when the corresponding event is triggered. |

## `lib/src/game/template_character.dart`

**Top-level Functions:**

- **`LuminaInputAction('IA_Move', valueType: InputValueType.axis2D)`**: Executes `LuminaInputAction` operation.
- **`LuminaInputAction('IA_Look', valueType: InputValueType.axis2D)`**: Executes `LuminaInputAction` operation.

### `class LuminaTemplateCharacterTuning`

The movement and camera numbers the First Person / Third Person templates are built from.  They live here because the same character exists twice: as generated source inside the user's project (`lib/pawns/<Project>Character.dart`, which the editor process cannot import), and as [LuminaTemplateCharacter], which Play-In-Editor instantiates directly. `DartCodeGeneratorService` interpolates these constants into the generated source and a parity test fails if the two drift apart.

**Constructors:**
- `LuminaTemplateCharacterTuning._()`: Initializes `LuminaTemplateCharacterTuning._()`.

### `class LuminaTemplateCharacter`

The player character the First Person and Third Person templates scaffold, as a real engine class Play-In-Editor can spawn.  This is deliberately *not* what the shipped game runs: the launcher writes the equivalent as ordinary source the user owns and edits. Both are built from [LuminaTemplateCharacterTuning], so pressing Play in the editor and running the generated project move the same way.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `thirdPerson` | `bool thirdPerson` | True when the camera rides a boom behind the character. |
| `springArmComponent` | `LuminaSpringArmComponent? springArmComponent` | The boom, or null in first person. |
| `cameraComponent` | `final LuminaCameraComponent cameraComponent` | Holds the `cameraComponent` property or configuration state. |
| `onMove` | `void onMove(LuminaInputActionValue value)` | Drives the character along the control rotation's forward/right axes. |
| `onLook` | `void onLook(LuminaInputActionValue value)` | Feeds mouse deltas to the controller. Pitch is clamped by [LuminaPlayerController.onTick]; it is deliberately not clamped again here. |
| `onJump` | `void onJump(LuminaInputActionValue value) => jump()` | Jumps through the character movement component. |

## `lib/src/game/console.dart`

### `typedef LuminaConsoleCommand`

A console command: the arguments after the command name and the world it runs against (null outside play).

### `abstract final class LuminaConsole`

The tiny console registry `Execute Console Command` routes to: `stat fps`, `quit`, `slomo <x>`, `open <level>` are built in; a project registers its own with [register].

**Members:**

| Member | Signature | Description |
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

`materialOverrideAsset` (the material a placed level mesh is assigned) is drawn on every section in place of the mesh's own materials ([LuminaStaticMeshComponent.materialOverrideAsset]).

**Constructors:**

- `LuminaStaticMeshActor({LuminaObjectKey? key, Vector3? location, Quaternion? rotation, Vector3? scale, required String meshAssetPath, bool castShadows = true, bool visible =...`

**Members:**

| Member | Signature | Description |
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

**Members:**

| Member | Signature | Description |
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

**Members:**

| Member | Signature | Description |
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

[Previous: Rendering devices](rendering.md) | [Up: lumina (engine core)](index.md) | [Next: User widgets](user-widgets.md)
