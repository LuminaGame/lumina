[English](../../en/lumina/audio.md)

# Ses

Ses katmanı: takılıp çıkarılabilir bir ses backend'i (testler için headless null backend ile), dünyada ses çalan ses subsystem'i ve mesafe attenuation'lı ses asset'leri. Dosya yolları `lumina/` paket dizinine görelidir.

**Bu sayfada:**

- [`lib/src/audio/audio_backend.dart`](#libsrcaudioaudio_backenddart)
- [`lib/src/audio/audio_subsystem.dart`](#libsrcaudioaudio_subsystemdart)
- [`lib/src/audio/sound_base.dart`](#libsrcaudiosound_basedart)

## `lib/src/audio/audio_backend.dart`

### `extension type const`

Opaque integer handle representing an active audio instance in the audio backend.

### `class LuminaAudioBackend`

Abstract pluggable backend driver for low-level audio decoding and playback.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `initialize` | `Future<void> initialize()` | `initialize` işlemini gerçekleştirir. |
| `shutdown` | `Future<void> shutdown()` | `shutdown` işlemini gerçekleştirir. |
| `setVolume` | `void setVolume(LuminaAudioHandle h, double volume)` | `Volume` parametresini günceller ve sisteme uygular. |
| `setPitch` | `void setPitch(LuminaAudioHandle h, double pitch)` | `Pitch` parametresini günceller ve sisteme uygular. |
| `setPan` | `void setPan(LuminaAudioHandle h, double pan)` | `Pan` parametresini günceller ve sisteme uygular. |
| `pause` | `void pause(LuminaAudioHandle h)` | `pause` işlemini gerçekleştirir. |
| `resume` | `void resume(LuminaAudioHandle h)` | `resume` işlemini gerçekleştirir. |
| `stop` | `void stop(LuminaAudioHandle h)` | `stop` işlemini gerçekleştirir. |
| `isPlaying` | `bool isPlaying(LuminaAudioHandle h)` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |

### `class _ActiveSoundInfo`

`_ActiveSoundInfo`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `sound` | `LuminaSoundBase sound` | `sound` alanını (field/property) ve ilişkili veriyi saklar. |
| `volume` | `double volume` | `volume` alanını (field/property) ve ilişkili veriyi saklar. |
| `pitch` | `double pitch` | `pitch` alanını (field/property) ve ilişkili veriyi saklar. |
| `pan` | `double pan` | `pan` alanını (field/property) ve ilişkili veriyi saklar. |
| `looping` | `bool looping` | `looping` alanını (field/property) ve ilişkili veriyi saklar. |
| `isPaused` | `bool isPaused` | `isPaused` alanını (field/property) ve ilişkili veriyi saklar. |
| `elapsed` | `double elapsed` | `elapsed` alanını (field/property) ve ilişkili veriyi saklar. |

### `class NullAudioBackend`

Headless in-memory mock backend that records calls and synthesizes finish events for tests.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `initialize` | `Future<void> initialize()` | `initialize` işlemini gerçekleştirir. |
| `shutdown` | `Future<void> shutdown()` | `shutdown` işlemini gerçekleştirir. |
| `setVolume` | `void setVolume(LuminaAudioHandle h, double volume)` | `Volume` parametresini günceller ve sisteme uygular. |
| `setPitch` | `void setPitch(LuminaAudioHandle h, double pitch)` | `Pitch` parametresini günceller ve sisteme uygular. |
| `setPan` | `void setPan(LuminaAudioHandle h, double pan)` | `Pan` parametresini günceller ve sisteme uygular. |
| `pause` | `void pause(LuminaAudioHandle h)` | `pause` işlemini gerçekleştirir. |
| `resume` | `void resume(LuminaAudioHandle h)` | `resume` işlemini gerçekleştirir. |
| `stop` | `void stop(LuminaAudioHandle h)` | `stop` işlemini gerçekleştirir. |
| `isPlaying` | `bool isPlaying(LuminaAudioHandle h)` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `tick` | `void tick(double deltaTime)` | Advances playback simulation in headless mode, triggering [onFinished] for expired sound clips. |

## `lib/src/audio/audio_subsystem.dart`

### `class LuminaAudioSubsystem`

Central audio subsystem managing spatial listener coordinates, master volume, and spatial parameter updates.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `backend` | `LuminaAudioBackend backend` | `backend` alanını (field/property) ve ilişkili veriyi saklar. |
| `masterVolume` | `double get masterVolume` | Global master volume scalar (0.0 to 1.0). |
| `masterVolume` | `masterVolume(double v)` | `masterVolume` işlemini gerçekleştirir. |
| `registerComponent` | `void registerComponent(LuminaAudioComponent comp)` | Registers an active audio component. |
| `unregisterComponent` | `void unregisterComponent(LuminaAudioComponent comp)` | Unregisters an audio component. |
| `onWorldTick` | `void onWorldTick(double deltaTime)` | Olay tetiklendiğinde çalışan geri çağırım metodudur. |
| `calculateAttenuation` | `double calculateAttenuation(LuminaSoundBase sound, Vector3 emitterLocation)` | Calculates the 3D distance attenuation gain for [sound] at [emitterLocation]. |
| `calculatePan` | `double calculatePan(Vector3 emitterLocation)` | Calculates the stereo panning scalar (-1.0 left, +1.0 right) for [emitterLocation] in listener local space. |
| `pauseAll` | `void pauseAll()` | Pauses every component that is currently playing with a live handle and remembers them so [resumeAll] resumes exactly those (components paused/stopped by the user are untouched). |
| `resumeAll` | `void resumeAll()` | Resumes the components paused by the last [pauseAll] that still hold their handle. |
| `onWorldPauseChanged` | `void onWorldPauseChanged(bool paused)` | Olay tetiklendiğinde çalışan geri çağırım metodudur. |
| `stopAll` | `void stopAll()` | Stops all currently playing audio components. |
| `onWorldShutdown` | `void onWorldShutdown()` | Olay tetiklendiğinde çalışan geri çağırım metodudur. |

## `lib/src/audio/sound_base.dart`

### `enum LuminaAttenuationModel`

Attenuation curve models for distance-based 3D sound volume falloff.

### `class LuminaSoundAttenuation`

Distance-based 3D spatial attenuation settings.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `innerRadius` | `double innerRadius` | `innerRadius` alanını (field/property) ve ilişkili veriyi saklar. |
| `falloffDistance` | `double falloffDistance` | `falloffDistance` alanını (field/property) ve ilişkili veriyi saklar. |
| `model` | `LuminaAttenuationModel model` | `model` alanını (field/property) ve ilişkili veriyi saklar. |
| `calculateGain` | `double calculateGain(double distance)` | Calculates the volume gain factor (0.0 to 1.0) for a given distance in meters. |

### `class LuminaSoundBase`

Abstract base descriptor for sound assets and streams.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `soundId` | `String soundId` | `soundId` alanını (field/property) ve ilişkili veriyi saklar. |
| `baseVolume` | `double baseVolume` | `baseVolume` alanını (field/property) ve ilişkili veriyi saklar. |
| `basePitch` | `double basePitch` | `basePitch` alanını (field/property) ve ilişkili veriyi saklar. |
| `looping` | `bool looping` | `looping` alanını (field/property) ve ilişkili veriyi saklar. |
| `attenuation` | `LuminaSoundAttenuation? attenuation` | `attenuation` alanını (field/property) ve ilişkili veriyi saklar. |
| `duration` | `double? duration` | `duration` alanını (field/property) ve ilişkili veriyi saklar. |

### `class LuminaSoundWave`

File or bundle-backed sound wave asset descriptor.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `assetPath` | `String assetPath` | `assetPath` alanını (field/property) ve ilişkili veriyi saklar. |

---

[Önceki: Animasyon](animation.md) | [Üst: lumina (engine çekirdeği)](index.md) | [Sonraki: Çarpışma](collision.md)
