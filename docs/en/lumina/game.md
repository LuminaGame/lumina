[Türkçe](../../tr/lumina/game.md)

# Game framework

The game framework that ties a world to a running app: the game instance and its subsystems, game mode and game state, the HUD overlay, `LuminaGame` and `LuminaGameWidget`, play state, the player camera manager, player starts, primitive actors and the template character. File paths are relative to the `lumina/` package directory.

**On this page:**

- [`lib/src/game/game_instance.dart`](#libsrcgamegame_instancedart)
- [`lib/src/game/game_mode.dart`](#libsrcgamegame_modedart)
- [`lib/src/game/game_state.dart`](#libsrcgamegame_statedart)
- [`lib/src/game/hud_overlay.dart`](#libsrcgamehud_overlaydart)
- [`lib/src/game/lumina_game.dart`](#libsrcgamelumina_gamedart)
- [`lib/src/game/lumina_widget.dart`](#libsrcgamelumina_widgetdart)
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

The engine-lifetime singleton surviving world transitions.

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

## `lib/src/game/lumina_widget.dart`

### `class LuminaGameWidget`

Flutter widget that embeds the `FilamentWidget` viewport and drives the [LuminaGame] loop via [LuminaFrameDriver].  The widget is the game host: it calls [LuminaGame.mountGame] and `beginPlay()` on the mounted world once `FilamentWidget` has created the scene.  Play control: - [paused] is declarative: flipping it calls [LuminaGame.pause] / [LuminaGame.resume] once the scene exists (and on scene creation if it starts `true`). - [onPlayStateChanged] receives every [LuminaPlayState] transition of [game] for the widget's lifetime — bind an editor toolbar to it.  Swap chain: - With [useHeadlessSwapChain] (default `true`, today's behaviour) the widget creates a 1×1 headless swap chain plus a [LuminaFrameDriver], so the world is ticked with a vsync-derived, frame-paced delta time and [LuminaFrameDriver.frameStats] is available to the HUD overlay. - With `false` no extra swap chain or driver is created: the ticker calls [LuminaGame.tickGame] with a fixed 1/60 s delta and `FilamentWidget` presents through its own swap chain. Use this for hosts that must not allocate a second swap chain; note that no frame stats are produced in that mode.

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

## `lib/src/game/play_state.dart`

### `enum LuminaPlayState`

Editor-facing play state of a [LuminaGame] (Play-In-Editor toolbar state).  Transitions: `stopped` → `playing` on `mountGame`, `playing` ⇄ `paused` via `pause()` / `resume()`, and any state → `stopped` on `disposeGame`.

## `lib/src/game/player_camera_manager.dart`

### `class LuminaMinimalViewInfo`

`LuminaMinimalViewInfo`: shadcn_flutter UI component rendering interface elements and listening to interactions.

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
| `size` | `Vector3 size` | Holds the `size` property or configuration state. |
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

- `LuminaStaticMeshActor({Key? key, Vector3? location, Quaternion? rotation, Vector3? scale, required String meshAssetPath, bool castShadows = true, bool visible =...`

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

[Previous: Rendering devices](rendering.md) | [Up: lumina (engine core)](index.md) | [Next: Game UI widgets (UMG runtime)](umg.md)
