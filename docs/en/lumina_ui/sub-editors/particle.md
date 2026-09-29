[Türkçe](../../../tr/lumina_ui/sub-editors/particle.md)

# Particle editor

The Particle editor: a particle system document of CPU emitters, curve and gradient editors for over-life values, and a live preview driven by the engine's own particle component. File paths are relative to the `lumina_ui/` package directory.

**On this page:**

- [`lib/ui/features/sub_editors/views/particle/curve_editors.dart`](#libuifeaturessub_editorsviewsparticlecurve_editorsdart)
- [`lib/ui/features/sub_editors/views/particle/particle_sub_editor.dart`](#libuifeaturessub_editorsviewsparticleparticle_sub_editordart)
- [`lib/ui/features/sub_editors/view_models/particle_editor_view_model.dart`](#libuifeaturessub_editorsview_modelsparticle_editor_view_modeldart)
- [`lib/ui/features/sub_editors/services/particle_preview_scene.dart`](#libuifeaturessub_editorsservicesparticle_preview_scenedart)
- [`lib/ui/features/sub_editors/models/particle_system_document.dart`](#libuifeaturessub_editorsmodelsparticle_system_documentdart)

## `lib/ui/features/sub_editors/views/particle/curve_editors.dart`

### `class ParticleGradientEditor`

`colorOverLife` gradient bar.  The strip is painted by sampling [sample] — the runtime's own `LuminaParticleEmitterConfig.sampleColorAt` — so what the editor shows is exactly what the simulation will produce. Click empty space to add a stop, drag a handle to move it (`t` clamped to `[0, 1]`, list re-sorted by the view model), click a handle to select it, right-click to delete.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `stops` | `List<LuminaGradientStop> stops` | Holds the `stops` property or configuration state. |
| `selectedIndex` | `int? selectedIndex` | Holds the `selectedIndex` property or configuration state. |
| `createState` | `State<ParticleGradientEditor> createState() => _ParticleGradientEditorSt...` | Creates, configures, and returns a new `State` instance or associated GPU resource. |

### `class _ParticleGradientEditorState`

`_ParticleGradientEditorState`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

### `class _GradientPainter`

`_GradientPainter`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `stops` | `List<LuminaGradientStop> stops` | Holds the `stops` property or configuration state. |
| `selectedIndex` | `int? selectedIndex` | Holds the `selectedIndex` property or configuration state. |
| `barHeight` | `double barHeight` | Holds the `barHeight` property or configuration state. |
| `paint` | `void paint(Canvas canvas, Size size)` | Executes `paint` operation. |
| `shouldRepaint` | `bool shouldRepaint(covariant _GradientPainter old)` | Executes `shouldRepaint` operation. |

### `class ParticleCurveEditor`

`sizeOverLife` curve canvas: points `(t, scale)` with linear segments, drawn by sampling the runtime's `sampleSizeAt`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `points` | `List<LuminaCurvePoint> points` | Holds the `points` property or configuration state. |
| `selectedIndex` | `int? selectedIndex` | Holds the `selectedIndex` property or configuration state. |
| `maxScale` | `double maxScale` | Vertical range of the canvas (scale axis). |
| `createState` | `State<ParticleCurveEditor> createState() => _ParticleCurveEditorState()` | Creates, configures, and returns a new `State` instance or associated GPU resource. |

### `class _ParticleCurveEditorState`

`_ParticleCurveEditorState`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

### `class _CurvePainter`

`_CurvePainter`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `points` | `List<LuminaCurvePoint> points` | Holds the `points` property or configuration state. |
| `selectedIndex` | `int? selectedIndex` | Holds the `selectedIndex` property or configuration state. |
| `maxScale` | `double maxScale` | Holds the `maxScale` property or configuration state. |
| `paint` | `void paint(Canvas canvas, Size size)` | Executes `paint` operation. |
| `shouldRepaint` | `bool shouldRepaint(covariant _CurvePainter old)` | Executes `shouldRepaint` operation. |

## `lib/ui/features/sub_editors/views/particle/particle_sub_editor.dart`

**Top-level Functions:**

- **`LuminaParticleEmitterConfig particleEmitterDefaults() => LuminaParticleEmitterConfig()`**: Default engine config, re-exported for callers building a fresh document.

### `class ParticleSubEditor`

Particle sub-editor.  Edits exactly `LuminaParticleEmitterConfig`: the engine's CPU emitter. GPU-compute simulation, Scratch Pad HLSL node graph, curl-noise / attraction / collision forces and ribbon / light renderers are **not** built: the engine runs none of them, so no dead controls exist for them. They are future scope.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `assetName` | `String assetName` | Holds the `assetName` property or configuration state. |
| `assetPath` | `String? assetPath` | Holds the `assetPath` property or configuration state. |
| `projectDirPath` | `String? projectDirPath` | Holds the `projectDirPath` property or configuration state. |
| `onBind` | `SubEditorBindCallback? onBind` | Holds the `onBind` property or configuration state. |
| `onClose` | `VoidCallback? onClose` | Holds the `onClose` property or configuration state. |
| `createState` | `State<ParticleSubEditor> createState() => _ParticleSubEditorState()` | Creates, configures, and returns a new `State` instance or associated GPU resource. |

### `enum ParticleStage`

The five stage blocks of the emitter stack.

### `extension on`

`on`: `extension` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `key` | `String get key` | Getter accessor returning the current value of `key`. |
| `title` | `String get title` | Getter accessor returning the current value of `title`. |

### `class _ParticleSubEditorState`

`_ParticleSubEditorState`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `vm` | `final ParticleEditorViewModel vm` | Holds the `vm` property or configuration state. |
| `initState` | `void initState()` | Executes `initState` operation. |
| `viewModelForTest` | `ParticleEditorViewModel get viewModelForTest` | Test/smoke hook: the live view model behind this editor. |
| `dispose` | `void dispose()` | Releases native FFI pointers, event subscriptions, and allocated memory. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

### `class _NumField`

Numeric field committing on Enter / focus loss — `maxParticles` re-allocates the pool, so per-keystroke commits are exactly what we must avoid.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `fieldKey` | `ValueKey<String> fieldKey` | Holds the `fieldKey` property or configuration state. |
| `value` | `double value` | Holds the `value` property or configuration state. |
| `isInt` | `bool isInt` | Holds the `isInt` property or configuration state. |
| `createState` | `State<_NumField> createState() => _NumFieldState()` | Creates, configures, and returns a new `State` instance or associated GPU resource. |

### `class _NumFieldState`

`_NumFieldState`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `initState` | `void initState()` | Executes `initState` operation. |
| `didUpdateWidget` | `void didUpdateWidget(covariant _NumField old)` | Executes `didUpdateWidget` operation. |
| `dispose` | `void dispose()` | Releases native FFI pointers, event subscriptions, and allocated memory. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

## `lib/ui/features/sub_editors/view_models/particle_editor_view_model.dart`

### `class ParticleEditorViewModel`

View model of the Particle sub-editor.  Owns a [ParticleSystemDocument] — a named list of [LuminaParticleEmitterConfig]s — loaded from and saved into a PARTICLE `.lmas` through the real `LuminaAsset` container, plus the live preview: one real [LuminaParticleSystemComponent] per *enabled* emitter, built with a fixed [previewSeed] so the simulation is reproducible frame for frame.  There is no editor-side particle simulator: [activeParticleCount], [sampleColorAt] and [sampleSizeAt] all read the engine types directly, so what the editor shows is what the runtime will do.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `assetPath` | `String assetPath` | Path of the PARTICLE `.lmas` on disk. |
| `projectDirPath` | `String? projectDirPath` | Project root (`…/<Project>`), used to resolve mesh picks and references. |
| `previewSeed` | `int previewSeed` | Fixed simulation seed — deterministic preview (and smoke screenshots). |
| `preview` | `ParticlePreviewScene preview` | Holds the `preview` property or configuration state. |
| `isLoaded` | `bool get isLoaded` | Checks current state or capability and returns a boolean value. |
| `isDirty` | `bool get isDirty` | Checks current state or capability and returns a boolean value. |
| `asset` | `LuminaAsset? get asset` | Getter accessor returning the current value of `asset`. |
| `document` | `ParticleSystemDocument get document` | Getter accessor returning the current value of `document`. |
| `emitters` | `List<ParticleEmitterEntry> get emitters` | Getter accessor returning the current value of `emitters`. |
| `enabledEmitters` | `List<ParticleEmitterEntry> get enabledEmitters` | Getter accessor returning the current value of `enabledEmitters`. |
| `selectedEmitterIndex` | `int get selectedEmitterIndex` | Selects the target actor or asset. |
| `selectedEmitter` | `ParticleEmitterEntry get selectedEmitter` | Selects the target actor or asset. |
| `config` | `LuminaParticleEmitterConfig get config` | The selected emitter's immutable engine config. |
| `availableMeshes` | `List<RealAssetInfo> get availableMeshes` | Getter accessor returning the current value of `availableMeshes`. |
| `fileBasename` | `String get fileBasename` | Getter accessor returning the current value of `fileBasename`. |
| `open` | `void open()` | Reads the `.lmas`; a PARTICLE asset without a document starts from the engine defaults (Content Browser → New Particle System). |
| `errors` | `Map<String, String> get errors` | Inline field errors keyed by `spawnRate` / `maxParticles` / `lifetime` / `speed` / `duration` / `bursts`; empty when the document may be saved. |
| `errorFor` | `String? errorFor(String field)` | Executes `errorFor` operation. |
| `canSave` | `bool get canSave` | Getter accessor returning the current value of `canSave`. |
| `setSpawnRate` | `void setSpawnRate(double v) => _mutate((c) => copyEmitterConfig(c, spawn...` | Updates the `SpawnRate` parameter and applies changes to the system. |
| `setMaxParticles` | `void setMaxParticles(int v)` | Updates the `MaxParticles` parameter and applies changes to the system. |
| `setLifetimeMin` | `void setLifetimeMin(double v) => _mutate((c) => copyEmitterConfig(c, lif...` | Updates the `LifetimeMin` parameter and applies changes to the system. |
| `setLifetimeMax` | `void setLifetimeMax(double v) => _mutate((c) => copyEmitterConfig(c, lif...` | Updates the `LifetimeMax` parameter and applies changes to the system. |
| `setSpeedMin` | `void setSpeedMin(double v) => _mutate((c) => copyEmitterConfig(c, speedM...` | Updates the `SpeedMin` parameter and applies changes to the system. |
| `setSpeedMax` | `void setSpeedMax(double v) => _mutate((c) => copyEmitterConfig(c, speedM...` | Updates the `SpeedMax` parameter and applies changes to the system. |
| `setConeAngleDegrees` | `void setConeAngleDegrees(double v)` | Updates the `ConeAngleDegrees` parameter and applies changes to the system. |
| `setInheritVelocityScale` | `void setInheritVelocityScale(Vector3 v) => _mutate((c) => copyEmitterCon...` | Updates the `InheritVelocityScale` parameter and applies changes to the system. |
| `setGravity` | `void setGravity(Vector3 v) => _mutate((c) => copyEmitterConfig(c, gravit...` | Updates the `Gravity` parameter and applies changes to the system. |
| `setDrag` | `void setDrag(double v) => _mutate((c) => copyEmitterConfig(c, drag: v))` | Updates the `Drag` parameter and applies changes to the system. |
| `setLooping` | `void setLooping(bool v) => _mutate((c) => copyEmitterConfig(c, looping: v))` | Updates the `Looping` parameter and applies changes to the system. |
| `setDuration` | `void setDuration(double v) => _mutate((c) => copyEmitterConfig(c, durati...` | Updates the `Duration` parameter and applies changes to the system. |
| `addBurst` | `void addBurst(double time, int count) => _mutate((c)` | Appends a new item to the collection or scene. |
| `removeBurst` | `void removeBurst(int index) => _mutate((c)` | Releases and safely disposes the specified `Burst` resource. |
| `setBurstTime` | `void setBurstTime(int index, double time) => _mutate((c)` | Updates the `BurstTime` parameter and applies changes to the system. |
| `setBurstCount` | `void setBurstCount(int index, int count) => _mutate((c)` | Updates the `BurstCount` parameter and applies changes to the system. |
| `setBillboard` | `void setBillboard(bool v) => _mutate((c)` | Updates the `Billboard` parameter and applies changes to the system. |
| `setMeshAsset` | `void setMeshAsset(RealAssetInfo? mesh)` | Picks a real FILAMESH `.lmas` as the emitter's mesh renderer. Storing the project-relative path keeps the reference portable; `null` restores the built-in billboard quad. |
| `addColorStop` | `void addColorStop(double t, Vector4 rgba) => _mutate((c)` | Appends a new item to the collection or scene. |
| `moveColorStop` | `void moveColorStop(int index, double t) => _mutate((c)` | Executes `moveColorStop` operation. |
| `setColorStopRgba` | `void setColorStopRgba(int index, Vector4 rgba) => _mutate((c)` | Updates the `ColorStopRgba` parameter and applies changes to the system. |
| `removeColorStop` | `void removeColorStop(int index) => _mutate((c)` | Releases and safely disposes the specified `ColorStop` resource. |
| `addSizePoint` | `void addSizePoint(double t, double scale) => _mutate((c)` | Appends a new item to the collection or scene. |
| `moveSizePoint` | `void moveSizePoint(int index, double t, double scale) => _mutate((c)` | Executes `moveSizePoint` operation. |
| `removeSizePoint` | `void removeSizePoint(int index) => _mutate((c)` | Releases and safely disposes the specified `SizePoint` resource. |
| `sampleColorAt` | `Vector4 sampleColorAt(double t) => config.sampleColorAt(t)` | Runtime-parity sampling: delegates to the engine config itself. |
| `sampleSizeAt` | `double sampleSizeAt(double t) => config.sampleSizeAt(t)` | Executes `sampleSizeAt` operation. |
| `selectEmitter` | `void selectEmitter(int index)` | Selects the target actor or asset. |
| `addEmitter` | `void addEmitter(String name)` | Appends a new item to the collection or scene. |
| `duplicateEmitter` | `void duplicateEmitter(int index)` | Executes `duplicateEmitter` operation. |
| `renameEmitter` | `void renameEmitter(int index, String name)` | Executes `renameEmitter` operation. |
| `setEmitterEnabled` | `void setEmitterEnabled(int index, bool enabled)` | Updates the `EmitterEnabled` parameter and applies changes to the system. |
| `deleteEmitter` | `void deleteEmitter(int index)` | Deletes an emitter; the last one is kept (a system always has one). |
| `stageSummary` | `String stageSummary(String stage)` | Per-stage summary shown on the collapsed accordion headers. |
| `save` | `Future<bool> save()` | Serializes and writes the current state or asset to disk. |
| `isPlaying` | `bool get isPlaying` | Checks current state or capability and returns a boolean value. |
| `simSpeed` | `double get simSpeed` | Getter accessor returning the current value of `simSpeed`. |
| `simTime` | `double get simTime` | Getter accessor returning the current value of `simTime`. |
| `isPreviewAttached` | `bool get isPreviewAttached` | Checks current state or capability and returns a boolean value. |
| `components` | `List<LuminaParticleSystemComponent> get components` | The live engine components — one per enabled emitter. |
| `activeParticleCount` | `int get activeParticleCount` | Real `liveParticleCount` summed over the live components. |
| `particleBudget` | `int get particleBudget` | Total pool budget (`maxParticles`) across the enabled emitters. |
| `statsLabel` | `String get statsLabel` | Getter accessor returning the current value of `statsLabel`. |
| `play` | `void play()` | Executes `play` operation. |
| `pause` | `void pause()` | Executes `pause` operation. |
| `togglePlay` | `void togglePlay() => _isPlaying ? pause() : play()` | Toggles the target feature or visibility on/off. |
| `setSimSpeed` | `void setSimSpeed(double v)` | Updates the `SimSpeed` parameter and applies changes to the system. |
| `advance` | `void advance(double dt)` | Advances the simulation by `dt · simSpeed` when playing. Called by the preview scene's render ticker (and directly by tests). |
| `stepFrame` | `void stepFrame()` | Advances exactly one 1/60 s tick without leaving the paused state. |
| `resetSimulation` | `void resetSimulation()` | `Reset Sim` — the components' own reset, not an editor-side fake. |
| `attachPreview` | `void attachPreview(LuminaWorld world)` | Executes `attachPreview` operation. |
| `detachPreview` | `void detachPreview(LuminaWorld world)` | Executes `detachPreview` operation. |
| `dispose` | `void dispose()` | Releases native FFI pointers, event subscriptions, and allocated memory. |
| `notifyListeners` | `void notifyListeners()` | Executes `notifyListeners` operation. |

## `lib/ui/features/sub_editors/services/particle_preview_scene.dart`

### `class ParticlePreviewScene`

Drives the Particle sub-editor's live viewport through lumina.  The viewport hands over a [LuminaWorld] bound to its Filament engine; this scene mounts a sun, a plain sky, and one [LuminaActor] per *enabled* emitter carrying the view model's **real** [LuminaParticleSystemComponent] — the same instance whose `liveParticleCount` the stats overlay reads. There is no editor-side particle simulator.  Simulation stepping stays with the view model (play / pause / sim speed / step frame), so this scene ticks the world with `dt = 0`: that runs the render-prep phase (the component pushes each live particle's transform into Filament) without advancing the sim twice.  The particles are drawn by the engine component itself (`LuminaParticleSystemComponent`): it batches a pair of crossed quads per live particle with that particle's own over-life colour and size. The editor only mounts the components, lights the scene and drives the clock — it does not draw particles of its own.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `isAttached` | `bool get isAttached` | Checks current state or capability and returns a boolean value. |
| `world` | `LuminaWorld? get world` | Getter accessor returning the current value of `world`. |
| `setComponents` | `void setComponents(List<LuminaParticleSystemComponent> components)` | Hands over the live engine components (one per enabled emitter). Called again whenever the view model rebuilds them after a config edit. |
| `releaseComponents` | `void releaseComponents()` | Drops the scene's references to the components before the view model replaces them (the viewport still owns the engine: unregister before the engine goes away). |
| `detach` | `void detach()` | Executes `detach` operation. |
| `spriteCapacity` | `int get spriteCapacity` | Pool budget across the live components, capped for the preview. |
| `liveSpriteCount` | `int get liveSpriteCount` | Particles the engine components drew on their last render prep. |
| `syncParticles` | `void syncParticles()` | Kept for callers that used to force a sprite rebuild; the component now rebuilds its own geometry on every render prep, so this only pumps one. |

## `lib/ui/features/sub_editors/models/particle_system_document.dart`

**Top-level Functions:**

- **`Map<String, dynamic> encodeEmitterConfig(LuminaParticleEmitterConfig c)`**: Executes `encodeEmitterConfig` operation.
- **`LuminaParticleEmitterConfig decodeEmitterConfig(Map<String, dynamic> map)`**: Executes `decodeEmitterConfig` operation.

### `class ParticleSystemDocument`

Versioned persistence model for a PARTICLE `.lmas`.  A particle *system* is a named list of emitters, each one a [LuminaParticleEmitterConfig] — the engine's CPU particle emitter. The document stores exactly that config's fields, nothing the engine cannot run, and round-trips through `LuminaAsset.metadata['particle_system']` so the Dart code generator can emit a `LuminaParticleEmitterConfig` literal.

**Constructors:**
- `ParticleSystemDocument.createDefault()`: A brand new system: one emitter carrying the engine defaults verbatim.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `version` | `int version` | Holds the `version` property or configuration state. |
| `emitters` | `List<ParticleEmitterEntry> emitters` | Holds the `emitters` property or configuration state. |
| `toJson` | `Map<String, dynamic> toJson()` | Serializes the object to a JSON map. |
| `toJsonString` | `String toJsonString() => jsonEncode(toJson())` | Executes `toJsonString` operation. |
| `fromJson` | `static ParticleSystemDocument fromJson(Map<String, dynamic> map)` | Reconstructs the object from a serialized map/JSON. |
| `tryParse` | `static ParticleSystemDocument? tryParse(String? source)` | Parses [source]; returns null when the payload is absent or unreadable (the caller then starts from [ParticleSystemDocument.createDefault]). |
| `clone` | `ParticleSystemDocument clone()` | Executes `clone` operation. |

### `class ParticleEmitterEntry`

One named emitter slot inside a [ParticleSystemDocument].

**Constructors:**
- `ParticleEmitterEntry.fromJson(Map<String, dynamic> map)`: Initializes `ParticleEmitterEntry.fromJson(Map<String, dynamic> map)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `name` | `String name` | Holds the `name` property or configuration state. |
| `enabled` | `bool enabled` | Holds the `enabled` property or configuration state. |
| `config` | `LuminaParticleEmitterConfig config` | Holds the `config` property or configuration state. |
| `toJson` | `Map<String, dynamic> toJson()` | Serializes the object to a JSON map. |
| `clone` | `ParticleEmitterEntry clone()` | Executes `clone` operation. |

---

[Previous: Navigation editor](navigation.md) | [Up: Sub-editors](index.md) | [Next: Physics asset editor](physics-asset.md)
