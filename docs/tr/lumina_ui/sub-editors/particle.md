[English](../../../en/lumina_ui/sub-editors/particle.md)

# Parçacık editörü

Parçacık editörü: CPU emitter'lardan oluşan bir parçacık sistemi belgesi, ömür boyu değerler için eğri ve gradient editörleri ve engine'in kendi parçacık component'iyle çalışan canlı önizleme. Dosya yolları `lumina_ui/` paket dizinine görelidir.

**Bu sayfada:**

- [`lib/ui/features/sub_editors/views/particle/curve_editors.dart`](#libuifeaturessub_editorsviewsparticlecurve_editorsdart)
- [`lib/ui/features/sub_editors/views/particle/particle_sub_editor.dart`](#libuifeaturessub_editorsviewsparticleparticle_sub_editordart)
- [`lib/ui/features/sub_editors/view_models/particle_editor_view_model.dart`](#libuifeaturessub_editorsview_modelsparticle_editor_view_modeldart)
- [`lib/ui/features/sub_editors/services/particle_preview_scene.dart`](#libuifeaturessub_editorsservicesparticle_preview_scenedart)
- [`lib/ui/features/sub_editors/models/particle_system_document.dart`](#libuifeaturessub_editorsmodelsparticle_system_documentdart)

## `lib/ui/features/sub_editors/views/particle/curve_editors.dart`

### `class ParticleGradientEditor`

`colorOverLife` gradient bar.  The strip is painted by sampling [sample] — the runtime's own `LuminaParticleEmitterConfig.sampleColorAt` — so what the editor shows is exactly what the simulation will produce. Click empty space to add a stop, drag a handle to move it (`t` clamped to `[0, 1]`, list re-sorted by the view model), click a handle to select it, right-click to delete.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `stops` | `List<LuminaGradientStop> stops` | `stops` alanını (field/property) ve ilişkili veriyi saklar. |
| `selectedIndex` | `int? selectedIndex` | `selectedIndex` alanını (field/property) ve ilişkili veriyi saklar. |
| `createState` | `State<ParticleGradientEditor> createState() => _ParticleGradientEditorSt...` | Yeni bir `State` örneği veya ilişkili GPU kaynağını oluşturur ve yapılandırır. |

### `class _ParticleGradientEditorState`

`_ParticleGradientEditorState`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

### `class _GradientPainter`

`_GradientPainter`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `stops` | `List<LuminaGradientStop> stops` | `stops` alanını (field/property) ve ilişkili veriyi saklar. |
| `selectedIndex` | `int? selectedIndex` | `selectedIndex` alanını (field/property) ve ilişkili veriyi saklar. |
| `barHeight` | `double barHeight` | `barHeight` alanını (field/property) ve ilişkili veriyi saklar. |
| `paint` | `void paint(Canvas canvas, Size size)` | `paint` işlemini gerçekleştirir. |
| `shouldRepaint` | `bool shouldRepaint(covariant _GradientPainter old)` | `shouldRepaint` işlemini gerçekleştirir. |

### `class ParticleCurveEditor`

`sizeOverLife` curve canvas: points `(t, scale)` with linear segments, drawn by sampling the runtime's `sampleSizeAt`.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `points` | `List<LuminaCurvePoint> points` | `points` alanını (field/property) ve ilişkili veriyi saklar. |
| `selectedIndex` | `int? selectedIndex` | `selectedIndex` alanını (field/property) ve ilişkili veriyi saklar. |
| `maxScale` | `double maxScale` | Vertical range of the canvas (scale axis). |
| `createState` | `State<ParticleCurveEditor> createState() => _ParticleCurveEditorState()` | Yeni bir `State` örneği veya ilişkili GPU kaynağını oluşturur ve yapılandırır. |

### `class _ParticleCurveEditorState`

`_ParticleCurveEditorState`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

### `class _CurvePainter`

`_CurvePainter`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `points` | `List<LuminaCurvePoint> points` | `points` alanını (field/property) ve ilişkili veriyi saklar. |
| `selectedIndex` | `int? selectedIndex` | `selectedIndex` alanını (field/property) ve ilişkili veriyi saklar. |
| `maxScale` | `double maxScale` | `maxScale` alanını (field/property) ve ilişkili veriyi saklar. |
| `paint` | `void paint(Canvas canvas, Size size)` | `paint` işlemini gerçekleştirir. |
| `shouldRepaint` | `bool shouldRepaint(covariant _CurvePainter old)` | `shouldRepaint` işlemini gerçekleştirir. |

## `lib/ui/features/sub_editors/views/particle/particle_sub_editor.dart`

**Üst Düzey Fonksiyonlar (Top-level Functions):**

- **`LuminaParticleEmitterConfig particleEmitterDefaults() => LuminaParticleEmitterConfig()`**: Default engine config, re-exported for callers building a fresh document.

### `class ParticleSubEditor`

Particle sub-editor.  Edits exactly `LuminaParticleEmitterConfig`: the engine's CPU emitter. GPU-compute simulation, Scratch Pad HLSL node graph, curl-noise / attraction / collision forces and ribbon / light renderers are **not** built: the engine runs none of them, so no dead controls exist for them. They are future scope.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `assetName` | `String assetName` | `assetName` alanını (field/property) ve ilişkili veriyi saklar. |
| `assetPath` | `String? assetPath` | `assetPath` alanını (field/property) ve ilişkili veriyi saklar. |
| `projectDirPath` | `String? projectDirPath` | `projectDirPath` alanını (field/property) ve ilişkili veriyi saklar. |
| `onBind` | `SubEditorBindCallback? onBind` | `onBind` alanını (field/property) ve ilişkili veriyi saklar. |
| `onClose` | `VoidCallback? onClose` | `onClose` alanını (field/property) ve ilişkili veriyi saklar. |
| `createState` | `State<ParticleSubEditor> createState() => _ParticleSubEditorState()` | Yeni bir `State` örneği veya ilişkili GPU kaynağını oluşturur ve yapılandırır. |

### `enum ParticleStage`

The five stage blocks of the emitter stack.

### `extension on`

`on`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `extension` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `key` | `String get key` | `key` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `title` | `String get title` | `title` özelliğinin anlık değerini okuyan getter erişimcisi. |

### `class _ParticleSubEditorState`

`_ParticleSubEditorState`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `vm` | `final ParticleEditorViewModel vm` | `vm` alanını (field/property) ve ilişkili veriyi saklar. |
| `initState` | `void initState()` | `initState` işlemini gerçekleştirir. |
| `viewModelForTest` | `ParticleEditorViewModel get viewModelForTest` | Test/smoke hook: the live view model behind this editor. |
| `dispose` | `void dispose()` | Yerel FFI göstericilerini, dinleyicileri ve bellek bloklarını serbest bırakır. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

### `class _NumField`

Numeric field committing on Enter / focus loss — `maxParticles` re-allocates the pool, so per-keystroke commits are exactly what we must avoid.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `fieldKey` | `ValueKey<String> fieldKey` | `fieldKey` alanını (field/property) ve ilişkili veriyi saklar. |
| `value` | `double value` | `value` alanını (field/property) ve ilişkili veriyi saklar. |
| `isInt` | `bool isInt` | `isInt` alanını (field/property) ve ilişkili veriyi saklar. |
| `createState` | `State<_NumField> createState() => _NumFieldState()` | Yeni bir `State` örneği veya ilişkili GPU kaynağını oluşturur ve yapılandırır. |

### `class _NumFieldState`

`_NumFieldState`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `initState` | `void initState()` | `initState` işlemini gerçekleştirir. |
| `didUpdateWidget` | `void didUpdateWidget(covariant _NumField old)` | `didUpdateWidget` işlemini gerçekleştirir. |
| `dispose` | `void dispose()` | Yerel FFI göstericilerini, dinleyicileri ve bellek bloklarını serbest bırakır. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

## `lib/ui/features/sub_editors/view_models/particle_editor_view_model.dart`

### `class ParticleEditorViewModel`

View model of the Particle sub-editor.  Owns a [ParticleSystemDocument] — a named list of [LuminaParticleEmitterConfig]s — loaded from and saved into a PARTICLE `.lmas` through the real `LuminaAsset` container, plus the live preview: one real [LuminaParticleSystemComponent] per *enabled* emitter, built with a fixed [previewSeed] so the simulation is reproducible frame for frame.  There is no editor-side particle simulator: [activeParticleCount], [sampleColorAt] and [sampleSizeAt] all read the engine types directly, so what the editor shows is what the runtime will do.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `assetPath` | `String assetPath` | Path of the PARTICLE `.lmas` on disk. |
| `projectDirPath` | `String? projectDirPath` | Project root (`…/<Project>`), used to resolve mesh picks and references. |
| `previewSeed` | `int previewSeed` | Fixed simulation seed — deterministic preview (and smoke screenshots). |
| `preview` | `ParticlePreviewScene preview` | `preview` alanını (field/property) ve ilişkili veriyi saklar. |
| `isLoaded` | `bool get isLoaded` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `isDirty` | `bool get isDirty` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `asset` | `LuminaAsset? get asset` | `asset` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `document` | `ParticleSystemDocument get document` | `document` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `emitters` | `List<ParticleEmitterEntry> get emitters` | `emitters` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `enabledEmitters` | `List<ParticleEmitterEntry> get enabledEmitters` | `enabledEmitters` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `selectedEmitterIndex` | `int get selectedEmitterIndex` | İlgili aktör veya varlığı seçili duruma getirir. |
| `selectedEmitter` | `ParticleEmitterEntry get selectedEmitter` | İlgili aktör veya varlığı seçili duruma getirir. |
| `config` | `LuminaParticleEmitterConfig get config` | The selected emitter's immutable engine config. |
| `availableMeshes` | `List<RealAssetInfo> get availableMeshes` | `availableMeshes` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `fileBasename` | `String get fileBasename` | `fileBasename` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `open` | `void open()` | Reads the `.lmas`; a PARTICLE asset without a document starts from the engine defaults (Content Browser → New Particle System). |
| `errors` | `Map<String, String> get errors` | Inline field errors keyed by `spawnRate` / `maxParticles` / `lifetime` / `speed` / `duration` / `bursts`; empty when the document may be saved. |
| `errorFor` | `String? errorFor(String field)` | `errorFor` işlemini gerçekleştirir. |
| `canSave` | `bool get canSave` | `canSave` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `setSpawnRate` | `void setSpawnRate(double v) => _mutate((c) => copyEmitterConfig(c, spawn...` | `SpawnRate` parametresini günceller ve sisteme uygular. |
| `setMaxParticles` | `void setMaxParticles(int v)` | `MaxParticles` parametresini günceller ve sisteme uygular. |
| `setLifetimeMin` | `void setLifetimeMin(double v) => _mutate((c) => copyEmitterConfig(c, lif...` | `LifetimeMin` parametresini günceller ve sisteme uygular. |
| `setLifetimeMax` | `void setLifetimeMax(double v) => _mutate((c) => copyEmitterConfig(c, lif...` | `LifetimeMax` parametresini günceller ve sisteme uygular. |
| `setSpeedMin` | `void setSpeedMin(double v) => _mutate((c) => copyEmitterConfig(c, speedM...` | `SpeedMin` parametresini günceller ve sisteme uygular. |
| `setSpeedMax` | `void setSpeedMax(double v) => _mutate((c) => copyEmitterConfig(c, speedM...` | `SpeedMax` parametresini günceller ve sisteme uygular. |
| `setConeAngleDegrees` | `void setConeAngleDegrees(double v)` | `ConeAngleDegrees` parametresini günceller ve sisteme uygular. |
| `setInheritVelocityScale` | `void setInheritVelocityScale(Vector3 v) => _mutate((c) => copyEmitterCon...` | `InheritVelocityScale` parametresini günceller ve sisteme uygular. |
| `setGravity` | `void setGravity(Vector3 v) => _mutate((c) => copyEmitterConfig(c, gravit...` | `Gravity` parametresini günceller ve sisteme uygular. |
| `setDrag` | `void setDrag(double v) => _mutate((c) => copyEmitterConfig(c, drag: v))` | `Drag` parametresini günceller ve sisteme uygular. |
| `setLooping` | `void setLooping(bool v) => _mutate((c) => copyEmitterConfig(c, looping: v))` | `Looping` parametresini günceller ve sisteme uygular. |
| `setDuration` | `void setDuration(double v) => _mutate((c) => copyEmitterConfig(c, durati...` | `Duration` parametresini günceller ve sisteme uygular. |
| `addBurst` | `void addBurst(double time, int count) => _mutate((c)` | Koleksiyona veya sahneye yeni bir öğe ekler. |
| `removeBurst` | `void removeBurst(int index) => _mutate((c)` | Belirtilen `Burst` nesnesini/bileşenini serbest bırakır ve güvenle temizler. |
| `setBurstTime` | `void setBurstTime(int index, double time) => _mutate((c)` | `BurstTime` parametresini günceller ve sisteme uygular. |
| `setBurstCount` | `void setBurstCount(int index, int count) => _mutate((c)` | `BurstCount` parametresini günceller ve sisteme uygular. |
| `setBillboard` | `void setBillboard(bool v) => _mutate((c)` | `Billboard` parametresini günceller ve sisteme uygular. |
| `setMeshAsset` | `void setMeshAsset(RealAssetInfo? mesh)` | Picks a real FILAMESH `.lmas` as the emitter's mesh renderer. Storing the project-relative path keeps the reference portable; `null` restores the built-in billboard quad. |
| `addColorStop` | `void addColorStop(double t, Vector4 rgba) => _mutate((c)` | Koleksiyona veya sahneye yeni bir öğe ekler. |
| `moveColorStop` | `void moveColorStop(int index, double t) => _mutate((c)` | `moveColorStop` işlemini gerçekleştirir. |
| `setColorStopRgba` | `void setColorStopRgba(int index, Vector4 rgba) => _mutate((c)` | `ColorStopRgba` parametresini günceller ve sisteme uygular. |
| `removeColorStop` | `void removeColorStop(int index) => _mutate((c)` | Belirtilen `ColorStop` nesnesini/bileşenini serbest bırakır ve güvenle temizler. |
| `addSizePoint` | `void addSizePoint(double t, double scale) => _mutate((c)` | Koleksiyona veya sahneye yeni bir öğe ekler. |
| `moveSizePoint` | `void moveSizePoint(int index, double t, double scale) => _mutate((c)` | `moveSizePoint` işlemini gerçekleştirir. |
| `removeSizePoint` | `void removeSizePoint(int index) => _mutate((c)` | Belirtilen `SizePoint` nesnesini/bileşenini serbest bırakır ve güvenle temizler. |
| `sampleColorAt` | `Vector4 sampleColorAt(double t) => config.sampleColorAt(t)` | Runtime-parity sampling: delegates to the engine config itself. |
| `sampleSizeAt` | `double sampleSizeAt(double t) => config.sampleSizeAt(t)` | `sampleSizeAt` işlemini gerçekleştirir. |
| `selectEmitter` | `void selectEmitter(int index)` | İlgili aktör veya varlığı seçili duruma getirir. |
| `addEmitter` | `void addEmitter(String name)` | Koleksiyona veya sahneye yeni bir öğe ekler. |
| `duplicateEmitter` | `void duplicateEmitter(int index)` | `duplicateEmitter` işlemini gerçekleştirir. |
| `renameEmitter` | `void renameEmitter(int index, String name)` | `renameEmitter` işlemini gerçekleştirir. |
| `setEmitterEnabled` | `void setEmitterEnabled(int index, bool enabled)` | `EmitterEnabled` parametresini günceller ve sisteme uygular. |
| `deleteEmitter` | `void deleteEmitter(int index)` | Deletes an emitter; the last one is kept (a system always has one). |
| `stageSummary` | `String stageSummary(String stage)` | Per-stage summary shown on the collapsed accordion headers. |
| `save` | `Future<bool> save()` | Mevcut durumu veya varlığı diske dosya olarak serileştirip yazar. |
| `isPlaying` | `bool get isPlaying` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `simSpeed` | `double get simSpeed` | `simSpeed` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `simTime` | `double get simTime` | `simTime` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `isPreviewAttached` | `bool get isPreviewAttached` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `components` | `List<LuminaParticleSystemComponent> get components` | The live engine components — one per enabled emitter. |
| `activeParticleCount` | `int get activeParticleCount` | Real `liveParticleCount` summed over the live components. |
| `particleBudget` | `int get particleBudget` | Total pool budget (`maxParticles`) across the enabled emitters. |
| `statsLabel` | `String get statsLabel` | `statsLabel` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `play` | `void play()` | `play` işlemini gerçekleştirir. |
| `pause` | `void pause()` | `pause` işlemini gerçekleştirir. |
| `togglePlay` | `void togglePlay() => _isPlaying ? pause() : play()` | İlgili özelliğin açık/kapalı durumunu tersine çevirir. |
| `setSimSpeed` | `void setSimSpeed(double v)` | `SimSpeed` parametresini günceller ve sisteme uygular. |
| `advance` | `void advance(double dt)` | Advances the simulation by `dt · simSpeed` when playing. Called by the preview scene's render ticker (and directly by tests). |
| `stepFrame` | `void stepFrame()` | Advances exactly one 1/60 s tick without leaving the paused state. |
| `resetSimulation` | `void resetSimulation()` | `Reset Sim` — the components' own reset, not an editor-side fake. |
| `attachPreview` | `void attachPreview(LuminaWorld world)` | `attachPreview` işlemini gerçekleştirir. |
| `detachPreview` | `void detachPreview(LuminaWorld world)` | `detachPreview` işlemini gerçekleştirir. |
| `dispose` | `void dispose()` | Yerel FFI göstericilerini, dinleyicileri ve bellek bloklarını serbest bırakır. |
| `notifyListeners` | `void notifyListeners()` | `notifyListeners` işlemini gerçekleştirir. |

## `lib/ui/features/sub_editors/services/particle_preview_scene.dart`

### `class ParticlePreviewScene`

Drives the Particle sub-editor's live viewport through lumina.  The viewport hands over a [LuminaWorld] bound to its Filament engine; this scene mounts a sun, a plain sky, and one [LuminaActor] per *enabled* emitter carrying the view model's **real** [LuminaParticleSystemComponent] — the same instance whose `liveParticleCount` the stats overlay reads. There is no editor-side particle simulator.  Simulation stepping stays with the view model (play / pause / sim speed / step frame), so this scene ticks the world with `dt = 0`: that runs the render-prep phase (the component pushes each live particle's transform into Filament) without advancing the sim twice.  The particles are drawn by the engine component itself (`LuminaParticleSystemComponent`): it batches a pair of crossed quads per live particle with that particle's own over-life colour and size. The editor only mounts the components, lights the scene and drives the clock — it does not draw particles of its own.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `isAttached` | `bool get isAttached` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `world` | `LuminaWorld? get world` | `world` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `setComponents` | `void setComponents(List<LuminaParticleSystemComponent> components)` | Hands over the live engine components (one per enabled emitter). Called again whenever the view model rebuilds them after a config edit. |
| `releaseComponents` | `void releaseComponents()` | Drops the scene's references to the components before the view model replaces them (the viewport still owns the engine: unregister before the engine goes away). |
| `detach` | `void detach()` | `detach` işlemini gerçekleştirir. |
| `spriteCapacity` | `int get spriteCapacity` | Pool budget across the live components, capped for the preview. |
| `liveSpriteCount` | `int get liveSpriteCount` | Particles the engine components drew on their last render prep. |
| `syncParticles` | `void syncParticles()` | Kept for callers that used to force a sprite rebuild; the component now rebuilds its own geometry on every render prep, so this only pumps one. |

## `lib/ui/features/sub_editors/models/particle_system_document.dart`

**Üst Düzey Fonksiyonlar (Top-level Functions):**

- **`Map<String, dynamic> encodeEmitterConfig(LuminaParticleEmitterConfig c)`**: `encodeEmitterConfig` işlemini gerçekleştirir.
- **`LuminaParticleEmitterConfig decodeEmitterConfig(Map<String, dynamic> map)`**: `decodeEmitterConfig` işlemini gerçekleştirir.

### `class ParticleSystemDocument`

Versioned persistence model for a PARTICLE `.lmas`.  A particle *system* is a named list of emitters, each one a [LuminaParticleEmitterConfig] — the engine's CPU particle emitter. The document stores exactly that config's fields, nothing the engine cannot run, and round-trips through `LuminaAsset.metadata['particle_system']` so the Dart code generator can emit a `LuminaParticleEmitterConfig` literal.

**Yapıcı Metotlar (Constructors):**
- `ParticleSystemDocument.createDefault()`: A brand new system: one emitter carrying the engine defaults verbatim.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `version` | `int version` | `version` alanını (field/property) ve ilişkili veriyi saklar. |
| `emitters` | `List<ParticleEmitterEntry> emitters` | `emitters` alanını (field/property) ve ilişkili veriyi saklar. |
| `toJson` | `Map<String, dynamic> toJson()` | Nesneyi JSON haritasına serileştirir. |
| `toJsonString` | `String toJsonString() => jsonEncode(toJson())` | `toJsonString` işlemini gerçekleştirir. |
| `fromJson` | `static ParticleSystemDocument fromJson(Map<String, dynamic> map)` | Veri haritasından nesneyi yeniden oluşturur. |
| `tryParse` | `static ParticleSystemDocument? tryParse(String? source)` | Parses [source]; returns null when the payload is absent or unreadable (the caller then starts from [ParticleSystemDocument.createDefault]). |
| `clone` | `ParticleSystemDocument clone()` | `clone` işlemini gerçekleştirir. |

### `class ParticleEmitterEntry`

One named emitter slot inside a [ParticleSystemDocument].

**Yapıcı Metotlar (Constructors):**
- `ParticleEmitterEntry.fromJson(Map<String, dynamic> map)`: `ParticleEmitterEntry.fromJson(Map<String, dynamic> map)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `name` | `String name` | `name` alanını (field/property) ve ilişkili veriyi saklar. |
| `enabled` | `bool enabled` | `enabled` alanını (field/property) ve ilişkili veriyi saklar. |
| `config` | `LuminaParticleEmitterConfig config` | `config` alanını (field/property) ve ilişkili veriyi saklar. |
| `toJson` | `Map<String, dynamic> toJson()` | Nesneyi JSON haritasına serileştirir. |
| `clone` | `ParticleEmitterEntry clone()` | `clone` işlemini gerçekleştirir. |

---

[Önceki: Navigasyon editörü](navigation.md) | [Üst: Alt editörler](index.md) | [Sonraki: Fizik asset editörü](physics-asset.md)
