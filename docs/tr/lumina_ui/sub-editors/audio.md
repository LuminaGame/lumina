[English](../../../en/lumina_ui/sub-editors/audio.md)

# Ses editörü

Ses editörü: saf Dart bir WAV decoder'ı üzerinde dalga formu görünümü, transport, attenuation eğrisi düzenleme ve ses ayarları. Dosya yolları `lumina_ui/` paket dizinine görelidir.

**Bu sayfada:**

- [`lib/ui/features/sub_editors/views/audio_sub_editor.dart`](#libuifeaturessub_editorsviewsaudio_sub_editordart)
- [`lib/ui/features/sub_editors/view_models/audio_editor_view_model.dart`](#libuifeaturessub_editorsview_modelsaudio_editor_view_modeldart)
- [`lib/ui/features/sub_editors/services/audio_wav_decoder_service.dart`](#libuifeaturessub_editorsservicesaudio_wav_decoder_servicedart)
- [`lib/ui/features/sub_editors/models/audio_editor_state.dart`](#libuifeaturessub_editorsmodelsaudio_editor_statedart)

## `lib/ui/features/sub_editors/views/audio_sub_editor.dart`

### `class AudioSubEditor`

AudioEditor.  Scoped honestly to what the engine's audio layer really provides today: PCM decoded in Dart, a transport routed through [LuminaAudioBackend], and an attenuation curve editor that evaluates the runtime's own [LuminaSoundAttenuation]. A sound node graph, HRTF/binaural, occlusion and the spectrum analyzer are future scope and deliberately absent rather than shipped as dead tabs.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `assetName` | `String assetName` | `assetName` alanını (field/property) ve ilişkili veriyi saklar. |
| `assetPath` | `String? assetPath` | `assetPath` alanını (field/property) ve ilişkili veriyi saklar. |
| `asset` | `RealAssetInfo? asset` | `asset` alanını (field/property) ve ilişkili veriyi saklar. |
| `viewModel` | `AudioEditorViewModel? viewModel` | `viewModel` alanını (field/property) ve ilişkili veriyi saklar. |
| `onClose` | `VoidCallback? onClose` | `onClose` alanını (field/property) ve ilişkili veriyi saklar. |
| `onBind` | `SubEditorBindCallback? onBind` | `onBind` alanını (field/property) ve ilişkili veriyi saklar. |
| `createState` | `State<AudioSubEditor> createState() => _AudioSubEditorState()` | Yeni bir `State` örneği veya ilişkili GPU kaynağını oluşturur ve yapılandırır. |

### `class _AudioSubEditorState`

`_AudioSubEditorState`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `viewModelForTest` | `AudioEditorViewModel get viewModelForTest` | Exposed for smoke/integration tests that drive the real editor shell. |
| `initState` | `void initState()` | `initState` işlemini gerçekleştirir. |
| `dispose` | `void dispose()` | Yerel FFI göstericilerini, dinleyicileri ve bellek bloklarını serbest bırakır. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

### `class _AttenuationTab`

`_AttenuationTab`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `vm` | `AudioEditorViewModel vm` | `vm` alanını (field/property) ve ilişkili veriyi saklar. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

### `class _AudioPropertiesPanel`

`_AudioPropertiesPanel`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `vm` | `AudioEditorViewModel vm` | `vm` alanını (field/property) ve ilişkili veriyi saklar. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

### `class AudioWaveformPainter`

Draws the min/max peak envelope per channel (L/R stacked), a time ruler and the playhead needle. Peaks are always re-binned from the decoded samples.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `audio` | `DecodedAudio audio` | `audio` alanını (field/property) ve ilişkili veriyi saklar. |
| `startFrame` | `int startFrame` | `startFrame` alanını (field/property) ve ilişkili veriyi saklar. |
| `endFrame` | `int endFrame` | `endFrame` alanını (field/property) ve ilişkili veriyi saklar. |
| `playheadSeconds` | `double playheadSeconds` | `playheadSeconds` alanını (field/property) ve ilişkili veriyi saklar. |
| `binCount` | `int binCount` | `binCount` alanını (field/property) ve ilişkili veriyi saklar. |
| `paint` | `void paint(Canvas canvas, Size size)` | `paint` işlemini gerçekleştirir. |
| `shouldRepaint` | `bool shouldRepaint(covariant AudioWaveformPainter old)` | `shouldRepaint` işlemini gerçekleştirir. |

### `class AudioAttenuationPainter`

Plots gain (0–1) against distance for the selected attenuation model, with the inner-radius and falloff handles and the distance probe.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `maxDistance` | `double maxDistance` | `maxDistance` alanını (field/property) ve ilişkili veriyi saklar. |
| `innerRadius` | `double innerRadius` | `innerRadius` alanını (field/property) ve ilişkili veriyi saklar. |
| `outerDistance` | `double outerDistance` | `outerDistance` alanını (field/property) ve ilişkili veriyi saklar. |
| `probeDistance` | `double probeDistance` | `probeDistance` alanını (field/property) ve ilişkili veriyi saklar. |
| `probeGain` | `double probeGain` | `probeGain` alanını (field/property) ve ilişkili veriyi saklar. |
| `enabled` | `bool enabled` | `enabled` alanını (field/property) ve ilişkili veriyi saklar. |
| `paint` | `void paint(Canvas canvas, Size size)` | `paint` işlemini gerçekleştirir. |
| `shouldRepaint` | `bool shouldRepaint(covariant AudioAttenuationPainter old)` | `shouldRepaint` işlemini gerçekleştirir. |

## `lib/ui/features/sub_editors/view_models/audio_editor_view_model.dart`

### `class AudioEditorViewModel`

View model behind the AudioEditor.  Honest scope: the engine's audio layer is pure Dart over a pluggable [LuminaAudioBackend] and **no real backend is chosen yet**. So this view model decodes the PCM itself, drives the playhead from ticked game time, derives the VU meter from the decoded samples, and routes every transport action through the backend interface — audible when a real backend is registered, silent-but-functional with [NullAudioBackend].

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `assetPath` | `String assetPath` | `assetPath` alanını (field/property) ve ilişkili veriyi saklar. |
| `backend` | `LuminaAudioBackend get backend` | `backend` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `hasRealBackend` | `bool get hasRealBackend` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `backendStatus` | `String get backendStatus` | `backendStatus` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `asset` | `LuminaAsset? get asset` | `asset` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `audio` | `DecodedAudio? get audio` | `audio` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `isLoading` | `bool get isLoading` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `hasError` | `bool get hasError` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `errorMessage` | `String? get errorMessage` | `errorMessage` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `settings` | `AudioSettings get settings` | `settings` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `isDirty` | `bool get isDirty` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `isPlaying` | `bool get isPlaying` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `positionSeconds` | `double get positionSeconds` | `positionSeconds` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `activeHandle` | `LuminaAudioHandle? get activeHandle` | `activeHandle` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `finishedCount` | `int get finishedCount` | `finishedCount` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `vuPeaks` | `List<double> get vuPeaks` | `vuPeaks` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `duration` | `double get duration` | `duration` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `playbackFraction` | `double get playbackFraction` | `playbackFraction` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `effectiveVolume` | `double get effectiveVolume` | `effectiveVolume` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `zoom` | `double get zoom` | `zoom` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `viewStartFraction` | `double get viewStartFraction` | `viewStartFraction` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `visibleStartFrame` | `int get visibleStartFrame` | `visibleStartFrame` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `visibleEndFrame` | `int get visibleEndFrame` | `visibleEndFrame` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `probeDistance` | `double get probeDistance` | `probeDistance` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `outerDistance` | `double get outerDistance` | `outerDistance` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `plotMaxDistance` | `double get plotMaxDistance` | The curve canvas plots 0 → outer × 1.2 so the floor beyond the falloff edge stays visible. |
| `innerRadiusHandleFraction` | `double get innerRadiusHandleFraction` | `innerRadiusHandleFraction` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `falloffHandleFraction` | `double get falloffHandleFraction` | `falloffHandleFraction` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `gainAt` | `double gainAt(double distance)` | Gain at [distance] — evaluated by the runtime's own [LuminaSoundAttenuation], so the plot and the engine cannot drift. |
| `probeGain` | `double get probeGain` | `probeGain` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `probeLabel` | `String get probeLabel` | `probeLabel` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `fileBasename` | `String get fileBasename` | `fileBasename` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `sampleRateLabel` | `String get sampleRateLabel` | `sampleRateLabel` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `bitDepthLabel` | `String get bitDepthLabel` | `bitDepthLabel` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `channelsLabel` | `String get channelsLabel` | `channelsLabel` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `durationLabel` | `String get durationLabel` | `durationLabel` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `sampleCountLabel` | `String get sampleCountLabel` | `sampleCountLabel` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `positionLabel` | `String get positionLabel` | `positionLabel` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `formatTime` | `static String formatTime(double seconds)` | `formatTime` işlemini gerçekleştirir. |
| `load` | `Future<void> load()` | Veriyi diskten veya bellekten okuyarak motora yükler ve kullanılabilir hale getirir. |
| `play` | `Future<void> play()` | `play` işlemini gerçekleştirir. |
| `stop` | `void stop()` | `stop` işlemini gerçekleştirir. |
| `tick` | `void tick(double dt)` | Advances the playhead by [dt] seconds of **game-tick** time (never a wall-clock `Timer`), and advances the headless backend simulation so a non-looping preview really ends through `onFinished`. |
| `seekSeconds` | `void seekSeconds(double seconds)` | `seekSeconds` işlemini gerçekleştirir. |
| `seekFraction` | `void seekFraction(double fraction) => seekSeconds(fraction.clamp(0.0, 1....` | `seekFraction` işlemini gerçekleştirir. |
| `setVolumeMultiplier` | `void setVolumeMultiplier(double v)` | `VolumeMultiplier` parametresini günceller ve sisteme uygular. |
| `setPitchMultiplier` | `void setPitchMultiplier(double v)` | `PitchMultiplier` parametresini günceller ve sisteme uygular. |
| `setPitchRandomization` | `void setPitchRandomization(double v)` | `PitchRandomization` parametresini günceller ve sisteme uygular. |
| `setSoundClass` | `void setSoundClass(AudioSoundClass c)` | `SoundClass` parametresini günceller ve sisteme uygular. |
| `setLooping` | `void setLooping(bool value)` | `Looping` parametresini günceller ve sisteme uygular. |
| `setSpatialized` | `void setSpatialized(bool value)` | `Spatialized` parametresini günceller ve sisteme uygular. |
| `setAttenuationModel` | `void setAttenuationModel(LuminaAttenuationModel model)` | `AttenuationModel` parametresini günceller ve sisteme uygular. |
| `setInnerRadius` | `void setInnerRadius(double value)` | Moves the inner-radius handle. The falloff edge (`inner + falloff`) is held still — the two handles share one axis and must not cross, so the falloff shrinks as the inner radius grows (validation: inner ≤ outer). |
| `setFalloffDistance` | `void setFalloffDistance(double value)` | `FalloffDistance` parametresini günceller ve sisteme uygular. |
| `dragInnerRadiusToFraction` | `void dragInnerRadiusToFraction(double fraction)` | Canvas drag → distance. [fraction] is the pointer's x position across the curve canvas, which spans `0 → plotMaxDistance`. |
| `setInnerRadius` | `setInnerRadius(fraction.clamp(0.0, 1.0) * plotMaxDistance)` | `InnerRadius` parametresini günceller ve sisteme uygular. |
| `dragFalloffEdgeToFraction` | `void dragFalloffEdgeToFraction(double fraction)` | `dragFalloffEdgeToFraction` işlemini gerçekleştirir. |
| `setProbeDistance` | `void setProbeDistance(double value)` | `ProbeDistance` parametresini günceller ve sisteme uygular. |
| `save` | `Future<bool> save()` | Mevcut durumu veya varlığı diske dosya olarak serileştirip yazar. |
| `dispose` | `void dispose()` | Yerel FFI göstericilerini, dinleyicileri ve bellek bloklarını serbest bırakır. |

## `lib/ui/features/sub_editors/services/audio_wav_decoder_service.dart`

### `class WavDecodeException`

Typed failure raised by [WavDecoderService]. The audio editor renders this message instead of drawing a fabricated waveform.

**Yapıcı Metotlar (Constructors):**
- `WavDecodeException(this.message)`: `WavDecodeException(this.message)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `message` | `String message` | `message` alanını (field/property) ve ilişkili veriyi saklar. |
| `toString` | `String toString()` | `toString` işlemini gerçekleştirir. |

### `class AudioPeakEnvelope`

Per-channel min/max peak envelope, one entry per bin.

**Yapıcı Metotlar (Constructors):**
- `AudioPeakEnvelope(this.mins, this.maxs)`: `AudioPeakEnvelope(this.mins, this.maxs)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `mins` | `Float32List mins` | `mins` alanını (field/property) ve ilişkili veriyi saklar. |
| `maxs` | `Float32List maxs` | `maxs` alanını (field/property) ve ilişkili veriyi saklar. |
| `binCount` | `int get binCount` | `binCount` özelliğinin anlık değerini okuyan getter erişimcisi. |

### `class DecodedAudio`

Fully decoded, normalized (±1.0) PCM from a RIFF/WAVE file.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `sampleRate` | `int sampleRate` | `sampleRate` alanını (field/property) ve ilişkili veriyi saklar. |
| `bitDepth` | `int bitDepth` | `bitDepth` alanını (field/property) ve ilişkili veriyi saklar. |
| `channels` | `int channels` | `channels` alanını (field/property) ve ilişkili veriyi saklar. |
| `isFloat` | `bool isFloat` | `isFloat` alanını (field/property) ve ilişkili veriyi saklar. |
| `samples` | `List<Float32List> samples` | One [Float32List] per channel, each [frameCount] long, normalized to ±1. |
| `frameCount` | `int get frameCount` | `frameCount` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `totalSampleCount` | `int get totalSampleCount` | Total decoded sample count across all channels. |
| `duration` | `double get duration` | `duration` özelliğinin anlık değerini okuyan getter erişimcisi. |

### `class WavDecoderService`

Pure-Dart RIFF/WAVE decoder: PCM 16/24/32-bit integer and IEEE float32, mono or stereo. No native dependency, no audio package.  It lives in `lumina_ui` for now; the API is self-contained and the file can be moved into `lumina` verbatim.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `decode` | `static DecodedAudio decode(Uint8List bytes)` | `decode` işlemini gerçekleştirir. |

## `lib/ui/features/sub_editors/models/audio_editor_state.dart`

**Üst Düzey Fonksiyonlar (Top-level Functions):**

- **`String attenuationModelLabel(LuminaAttenuationModel model) => switch (model)`**: `attenuationModelLabel` işlemini gerçekleştirir.

### `enum AudioSoundClass`

Mixer bus an AUDIO asset belongs to. Corresponds to a sound class and is stored verbatim in the `.lmas` metadata.

**Yapıcı Metotlar (Constructors):**
- `AudioSoundClass(this.label)`: `AudioSoundClass(this.label)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `ui` | `ui('UI')` | `ui` işlemini gerçekleştirir. |
| `label` | `String label` | `label` alanını (field/property) ve ilişkili veriyi saklar. |
| `fromLabel` | `static AudioSoundClass fromLabel(String? label)` | `fromLabel` işlemini gerçekleştirir. |

### `class AudioAttenuationSettings`

Distance attenuation block — the editor-side mirror of `LuminaSoundAttenuation`. The curve math itself is never re-implemented here: [AudioEditorViewModel] evaluates the runtime class so the plotted curve and the engine agree by construction.

**Yapıcı Metotlar (Constructors):**
- `AudioAttenuationSettings.fromJson(Map<String, dynamic> json)`: `AudioAttenuationSettings.fromJson(Map<String, dynamic> json)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `model` | `LuminaAttenuationModel model` | `model` alanını (field/property) ve ilişkili veriyi saklar. |
| `innerRadius` | `double innerRadius` | `innerRadius` alanını (field/property) ve ilişkili veriyi saklar. |
| `falloffDistance` | `double falloffDistance` | `falloffDistance` alanını (field/property) ve ilişkili veriyi saklar. |
| `toJson` | `Map<String, dynamic> toJson()` | Nesneyi JSON haritasına serileştirir. |
| `copy` | `AudioAttenuationSettings copy()` | `copy` işlemini gerçekleştirir. |
| `hashCode` | `int get hashCode` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |

### `class AudioSettings`

Everything the AudioEditor persists into `LuminaAsset.metadata['audio_settings']` as one versioned JSON string (metadata is `Map<String, String>`).

**Yapıcı Metotlar (Constructors):**
- `AudioSettings.fromJson(Map<String, dynamic> json)`: `AudioSettings.fromJson(Map<String, dynamic> json)` nesnesini ilklendirir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `volumeMultiplier` | `double volumeMultiplier` | `volumeMultiplier` alanını (field/property) ve ilişkili veriyi saklar. |
| `pitchMultiplier` | `double pitchMultiplier` | `pitchMultiplier` alanını (field/property) ve ilişkili veriyi saklar. |
| `pitchRandomization` | `double pitchRandomization` | `pitchRandomization` alanını (field/property) ve ilişkili veriyi saklar. |
| `soundClass` | `AudioSoundClass soundClass` | `soundClass` alanını (field/property) ve ilişkili veriyi saklar. |
| `looping` | `bool looping` | `looping` alanını (field/property) ve ilişkili veriyi saklar. |
| `spatialized` | `bool spatialized` | `spatialized` alanını (field/property) ve ilişkili veriyi saklar. |
| `attenuation` | `AudioAttenuationSettings attenuation` | `attenuation` alanını (field/property) ve ilişkili veriyi saklar. |
| `toJson` | `Map<String, dynamic> toJson()` | Nesneyi JSON haritasına serileştirir. |
| `copy` | `AudioSettings copy()` | `copy` işlemini gerçekleştirir. |
| `hashCode` | `int get hashCode` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |

---

[Önceki: Animasyon editörü](animation.md) | [Üst: Alt editörler](index.md) | [Sonraki: Blueprint editörü](blueprint.md)
