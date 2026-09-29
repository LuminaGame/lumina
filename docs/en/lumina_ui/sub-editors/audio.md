[Türkçe](../../../tr/lumina_ui/sub-editors/audio.md)

# Audio editor

The audio editor: waveform display, transport, attenuation curve editing and sound settings, backed by a pure-Dart WAV decoder. File paths are relative to the `lumina_ui/` package directory.

**On this page:**

- [`lib/ui/features/sub_editors/views/audio_sub_editor.dart`](#libuifeaturessub_editorsviewsaudio_sub_editordart)
- [`lib/ui/features/sub_editors/view_models/audio_editor_view_model.dart`](#libuifeaturessub_editorsview_modelsaudio_editor_view_modeldart)
- [`lib/ui/features/sub_editors/services/audio_wav_decoder_service.dart`](#libuifeaturessub_editorsservicesaudio_wav_decoder_servicedart)
- [`lib/ui/features/sub_editors/models/audio_editor_state.dart`](#libuifeaturessub_editorsmodelsaudio_editor_statedart)

## `lib/ui/features/sub_editors/views/audio_sub_editor.dart`

### `class AudioSubEditor`

AudioEditor.  Scoped honestly to what the engine's audio layer really provides today: PCM decoded in Dart, a transport routed through [LuminaAudioBackend], and an attenuation curve editor that evaluates the runtime's own [LuminaSoundAttenuation]. A sound node graph, HRTF/binaural, occlusion and the spectrum analyzer are future scope and deliberately absent rather than shipped as dead tabs.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `assetName` | `String assetName` | Holds the `assetName` property or configuration state. |
| `assetPath` | `String? assetPath` | Holds the `assetPath` property or configuration state. |
| `asset` | `RealAssetInfo? asset` | Holds the `asset` property or configuration state. |
| `viewModel` | `AudioEditorViewModel? viewModel` | Holds the `viewModel` property or configuration state. |
| `onClose` | `VoidCallback? onClose` | Holds the `onClose` property or configuration state. |
| `onBind` | `SubEditorBindCallback? onBind` | Holds the `onBind` property or configuration state. |
| `createState` | `State<AudioSubEditor> createState() => _AudioSubEditorState()` | Creates, configures, and returns a new `State` instance or associated GPU resource. |

### `class _AudioSubEditorState`

`_AudioSubEditorState`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `viewModelForTest` | `AudioEditorViewModel get viewModelForTest` | Exposed for smoke/integration tests that drive the real editor shell. |
| `initState` | `void initState()` | Executes `initState` operation. |
| `dispose` | `void dispose()` | Releases native FFI pointers, event subscriptions, and allocated memory. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

### `class _AttenuationTab`

`_AttenuationTab`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `vm` | `AudioEditorViewModel vm` | Holds the `vm` property or configuration state. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

### `class _AudioPropertiesPanel`

`_AudioPropertiesPanel`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `vm` | `AudioEditorViewModel vm` | Holds the `vm` property or configuration state. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

### `class AudioWaveformPainter`

Draws the min/max peak envelope per channel (L/R stacked), a time ruler and the playhead needle. Peaks are always re-binned from the decoded samples.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `audio` | `DecodedAudio audio` | Holds the `audio` property or configuration state. |
| `startFrame` | `int startFrame` | Holds the `startFrame` property or configuration state. |
| `endFrame` | `int endFrame` | Holds the `endFrame` property or configuration state. |
| `playheadSeconds` | `double playheadSeconds` | Holds the `playheadSeconds` property or configuration state. |
| `binCount` | `int binCount` | Holds the `binCount` property or configuration state. |
| `paint` | `void paint(Canvas canvas, Size size)` | Executes `paint` operation. |
| `shouldRepaint` | `bool shouldRepaint(covariant AudioWaveformPainter old)` | Executes `shouldRepaint` operation. |

### `class AudioAttenuationPainter`

Plots gain (0–1) against distance for the selected attenuation model, with the inner-radius and falloff handles and the distance probe.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `maxDistance` | `double maxDistance` | Holds the `maxDistance` property or configuration state. |
| `innerRadius` | `double innerRadius` | Holds the `innerRadius` property or configuration state. |
| `outerDistance` | `double outerDistance` | Holds the `outerDistance` property or configuration state. |
| `probeDistance` | `double probeDistance` | Holds the `probeDistance` property or configuration state. |
| `probeGain` | `double probeGain` | Holds the `probeGain` property or configuration state. |
| `enabled` | `bool enabled` | Holds the `enabled` property or configuration state. |
| `paint` | `void paint(Canvas canvas, Size size)` | Executes `paint` operation. |
| `shouldRepaint` | `bool shouldRepaint(covariant AudioAttenuationPainter old)` | Executes `shouldRepaint` operation. |

## `lib/ui/features/sub_editors/view_models/audio_editor_view_model.dart`

### `class AudioEditorViewModel`

View model behind the AudioEditor.  Honest scope: the engine's audio layer is pure Dart over a pluggable [LuminaAudioBackend] and **no real backend is chosen yet**. So this view model decodes the PCM itself, drives the playhead from ticked game time, derives the VU meter from the decoded samples, and routes every transport action through the backend interface — audible when a real backend is registered, silent-but-functional with [NullAudioBackend].

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `assetPath` | `String assetPath` | Holds the `assetPath` property or configuration state. |
| `backend` | `LuminaAudioBackend get backend` | Getter accessor returning the current value of `backend`. |
| `hasRealBackend` | `bool get hasRealBackend` | Checks current state or capability and returns a boolean value. |
| `backendStatus` | `String get backendStatus` | Getter accessor returning the current value of `backendStatus`. |
| `asset` | `LuminaAsset? get asset` | Getter accessor returning the current value of `asset`. |
| `audio` | `DecodedAudio? get audio` | Getter accessor returning the current value of `audio`. |
| `isLoading` | `bool get isLoading` | Checks current state or capability and returns a boolean value. |
| `hasError` | `bool get hasError` | Checks current state or capability and returns a boolean value. |
| `errorMessage` | `String? get errorMessage` | Getter accessor returning the current value of `errorMessage`. |
| `settings` | `AudioSettings get settings` | Getter accessor returning the current value of `settings`. |
| `isDirty` | `bool get isDirty` | Checks current state or capability and returns a boolean value. |
| `isPlaying` | `bool get isPlaying` | Checks current state or capability and returns a boolean value. |
| `positionSeconds` | `double get positionSeconds` | Getter accessor returning the current value of `positionSeconds`. |
| `activeHandle` | `LuminaAudioHandle? get activeHandle` | Getter accessor returning the current value of `activeHandle`. |
| `finishedCount` | `int get finishedCount` | Getter accessor returning the current value of `finishedCount`. |
| `vuPeaks` | `List<double> get vuPeaks` | Getter accessor returning the current value of `vuPeaks`. |
| `duration` | `double get duration` | Getter accessor returning the current value of `duration`. |
| `playbackFraction` | `double get playbackFraction` | Getter accessor returning the current value of `playbackFraction`. |
| `effectiveVolume` | `double get effectiveVolume` | Getter accessor returning the current value of `effectiveVolume`. |
| `zoom` | `double get zoom` | Getter accessor returning the current value of `zoom`. |
| `viewStartFraction` | `double get viewStartFraction` | Getter accessor returning the current value of `viewStartFraction`. |
| `visibleStartFrame` | `int get visibleStartFrame` | Getter accessor returning the current value of `visibleStartFrame`. |
| `visibleEndFrame` | `int get visibleEndFrame` | Getter accessor returning the current value of `visibleEndFrame`. |
| `probeDistance` | `double get probeDistance` | Getter accessor returning the current value of `probeDistance`. |
| `outerDistance` | `double get outerDistance` | Getter accessor returning the current value of `outerDistance`. |
| `plotMaxDistance` | `double get plotMaxDistance` | The curve canvas plots 0 → outer × 1.2 so the floor beyond the falloff edge stays visible. |
| `innerRadiusHandleFraction` | `double get innerRadiusHandleFraction` | Getter accessor returning the current value of `innerRadiusHandleFraction`. |
| `falloffHandleFraction` | `double get falloffHandleFraction` | Getter accessor returning the current value of `falloffHandleFraction`. |
| `gainAt` | `double gainAt(double distance)` | Gain at [distance] — evaluated by the runtime's own [LuminaSoundAttenuation], so the plot and the engine cannot drift. |
| `probeGain` | `double get probeGain` | Getter accessor returning the current value of `probeGain`. |
| `probeLabel` | `String get probeLabel` | Getter accessor returning the current value of `probeLabel`. |
| `fileBasename` | `String get fileBasename` | Getter accessor returning the current value of `fileBasename`. |
| `sampleRateLabel` | `String get sampleRateLabel` | Getter accessor returning the current value of `sampleRateLabel`. |
| `bitDepthLabel` | `String get bitDepthLabel` | Getter accessor returning the current value of `bitDepthLabel`. |
| `channelsLabel` | `String get channelsLabel` | Getter accessor returning the current value of `channelsLabel`. |
| `durationLabel` | `String get durationLabel` | Getter accessor returning the current value of `durationLabel`. |
| `sampleCountLabel` | `String get sampleCountLabel` | Getter accessor returning the current value of `sampleCountLabel`. |
| `positionLabel` | `String get positionLabel` | Getter accessor returning the current value of `positionLabel`. |
| `formatTime` | `static String formatTime(double seconds)` | Executes `formatTime` operation. |
| `load` | `Future<void> load()` | Loads data from disk or memory buffer into the engine. |
| `play` | `Future<void> play()` | Executes `play` operation. |
| `stop` | `void stop()` | Executes `stop` operation. |
| `tick` | `void tick(double dt)` | Advances the playhead by [dt] seconds of **game-tick** time (never a wall-clock `Timer`), and advances the headless backend simulation so a non-looping preview really ends through `onFinished`. |
| `seekSeconds` | `void seekSeconds(double seconds)` | Executes `seekSeconds` operation. |
| `seekFraction` | `void seekFraction(double fraction) => seekSeconds(fraction.clamp(0.0, 1....` | Executes `seekFraction` operation. |
| `setVolumeMultiplier` | `void setVolumeMultiplier(double v)` | Updates the `VolumeMultiplier` parameter and applies changes to the system. |
| `setPitchMultiplier` | `void setPitchMultiplier(double v)` | Updates the `PitchMultiplier` parameter and applies changes to the system. |
| `setPitchRandomization` | `void setPitchRandomization(double v)` | Updates the `PitchRandomization` parameter and applies changes to the system. |
| `setSoundClass` | `void setSoundClass(AudioSoundClass c)` | Updates the `SoundClass` parameter and applies changes to the system. |
| `setLooping` | `void setLooping(bool value)` | Updates the `Looping` parameter and applies changes to the system. |
| `setSpatialized` | `void setSpatialized(bool value)` | Updates the `Spatialized` parameter and applies changes to the system. |
| `setAttenuationModel` | `void setAttenuationModel(LuminaAttenuationModel model)` | Updates the `AttenuationModel` parameter and applies changes to the system. |
| `setInnerRadius` | `void setInnerRadius(double value)` | Moves the inner-radius handle. The falloff edge (`inner + falloff`) is held still — the two handles share one axis and must not cross, so the falloff shrinks as the inner radius grows (validation: inner ≤ outer). |
| `setFalloffDistance` | `void setFalloffDistance(double value)` | Updates the `FalloffDistance` parameter and applies changes to the system. |
| `dragInnerRadiusToFraction` | `void dragInnerRadiusToFraction(double fraction)` | Canvas drag → distance. [fraction] is the pointer's x position across the curve canvas, which spans `0 → plotMaxDistance`. |
| `setInnerRadius` | `setInnerRadius(fraction.clamp(0.0, 1.0) * plotMaxDistance)` | Updates the `InnerRadius` parameter and applies changes to the system. |
| `dragFalloffEdgeToFraction` | `void dragFalloffEdgeToFraction(double fraction)` | Executes `dragFalloffEdgeToFraction` operation. |
| `setProbeDistance` | `void setProbeDistance(double value)` | Updates the `ProbeDistance` parameter and applies changes to the system. |
| `save` | `Future<bool> save()` | Serializes and writes the current state or asset to disk. |
| `dispose` | `void dispose()` | Releases native FFI pointers, event subscriptions, and allocated memory. |

## `lib/ui/features/sub_editors/services/audio_wav_decoder_service.dart`

### `class WavDecodeException`

Typed failure raised by [WavDecoderService]. The audio editor renders this message instead of drawing a fabricated waveform.

**Constructors:**
- `WavDecodeException(this.message)`: Initializes `WavDecodeException(this.message)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `message` | `String message` | Holds the `message` property or configuration state. |
| `toString` | `String toString()` | Executes `toString` operation. |

### `class AudioPeakEnvelope`

Per-channel min/max peak envelope, one entry per bin.

**Constructors:**
- `AudioPeakEnvelope(this.mins, this.maxs)`: Initializes `AudioPeakEnvelope(this.mins, this.maxs)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `mins` | `Float32List mins` | Holds the `mins` property or configuration state. |
| `maxs` | `Float32List maxs` | Holds the `maxs` property or configuration state. |
| `binCount` | `int get binCount` | Getter accessor returning the current value of `binCount`. |

### `class DecodedAudio`

Fully decoded, normalized (±1.0) PCM from a RIFF/WAVE file.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `sampleRate` | `int sampleRate` | Holds the `sampleRate` property or configuration state. |
| `bitDepth` | `int bitDepth` | Holds the `bitDepth` property or configuration state. |
| `channels` | `int channels` | Holds the `channels` property or configuration state. |
| `isFloat` | `bool isFloat` | Holds the `isFloat` property or configuration state. |
| `samples` | `List<Float32List> samples` | One [Float32List] per channel, each [frameCount] long, normalized to ±1. |
| `frameCount` | `int get frameCount` | Getter accessor returning the current value of `frameCount`. |
| `totalSampleCount` | `int get totalSampleCount` | Total decoded sample count across all channels. |
| `duration` | `double get duration` | Getter accessor returning the current value of `duration`. |

### `class WavDecoderService`

Pure-Dart RIFF/WAVE decoder: PCM 16/24/32-bit integer and IEEE float32, mono or stereo. No native dependency, no audio package.  It lives in `lumina_ui` for now; the API is self-contained and the file can be moved into `lumina` verbatim.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `decode` | `static DecodedAudio decode(Uint8List bytes)` | Executes `decode` operation. |

## `lib/ui/features/sub_editors/models/audio_editor_state.dart`

**Top-level Functions:**

- **`String attenuationModelLabel(LuminaAttenuationModel model) => switch (model)`**: Executes `attenuationModelLabel` operation.

### `enum AudioSoundClass`

Mixer bus an AUDIO asset belongs to. Corresponds to a sound class and is stored verbatim in the `.lmas` metadata.

**Constructors:**
- `AudioSoundClass(this.label)`: Initializes `AudioSoundClass(this.label)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `ui` | `ui('UI')` | Executes `ui` operation. |
| `label` | `String label` | Holds the `label` property or configuration state. |
| `fromLabel` | `static AudioSoundClass fromLabel(String? label)` | Executes `fromLabel` operation. |

### `class AudioAttenuationSettings`

Distance attenuation block — the editor-side mirror of `LuminaSoundAttenuation`. The curve math itself is never re-implemented here: [AudioEditorViewModel] evaluates the runtime class so the plotted curve and the engine agree by construction.

**Constructors:**
- `AudioAttenuationSettings.fromJson(Map<String, dynamic> json)`: Initializes `AudioAttenuationSettings.fromJson(Map<String, dynamic> json)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `model` | `LuminaAttenuationModel model` | Holds the `model` property or configuration state. |
| `innerRadius` | `double innerRadius` | Holds the `innerRadius` property or configuration state. |
| `falloffDistance` | `double falloffDistance` | Holds the `falloffDistance` property or configuration state. |
| `toJson` | `Map<String, dynamic> toJson()` | Serializes the object to a JSON map. |
| `copy` | `AudioAttenuationSettings copy()` | Executes `copy` operation. |
| `hashCode` | `int get hashCode` | Checks current state or capability and returns a boolean value. |

### `class AudioSettings`

Everything the AudioEditor persists into `LuminaAsset.metadata['audio_settings']` as one versioned JSON string (metadata is `Map<String, String>`).

**Constructors:**
- `AudioSettings.fromJson(Map<String, dynamic> json)`: Initializes `AudioSettings.fromJson(Map<String, dynamic> json)`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `volumeMultiplier` | `double volumeMultiplier` | Holds the `volumeMultiplier` property or configuration state. |
| `pitchMultiplier` | `double pitchMultiplier` | Holds the `pitchMultiplier` property or configuration state. |
| `pitchRandomization` | `double pitchRandomization` | Holds the `pitchRandomization` property or configuration state. |
| `soundClass` | `AudioSoundClass soundClass` | Holds the `soundClass` property or configuration state. |
| `looping` | `bool looping` | Holds the `looping` property or configuration state. |
| `spatialized` | `bool spatialized` | Holds the `spatialized` property or configuration state. |
| `attenuation` | `AudioAttenuationSettings attenuation` | Holds the `attenuation` property or configuration state. |
| `toJson` | `Map<String, dynamic> toJson()` | Serializes the object to a JSON map. |
| `copy` | `AudioSettings copy()` | Executes `copy` operation. |
| `hashCode` | `int get hashCode` | Checks current state or capability and returns a boolean value. |

---

[Previous: Animation editor](animation.md) | [Up: Sub-editors](index.md) | [Next: Blueprint editor](blueprint.md)
