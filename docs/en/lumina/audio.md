[Türkçe](../../tr/lumina/audio.md)

# Audio

The audio layer: a pluggable audio backend (with a headless null backend for tests), the audio subsystem that plays sounds in the world, and sound assets with distance attenuation. File paths are relative to the `lumina/` package directory.

**On this page:**

- [`lib/src/audio/audio_backend.dart`](#libsrcaudioaudio_backenddart)
- [`lib/src/audio/audio_subsystem.dart`](#libsrcaudioaudio_subsystemdart)
- [`lib/src/audio/sound_base.dart`](#libsrcaudiosound_basedart)

## `lib/src/audio/audio_backend.dart`

### `extension type const`

Opaque integer handle representing an active audio instance in the audio backend.

### `class LuminaAudioBackend`

Abstract pluggable backend driver for low-level audio decoding and playback.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `initialize` | `Future<void> initialize()` | Executes `initialize` operation. |
| `shutdown` | `Future<void> shutdown()` | Executes `shutdown` operation. |
| `setVolume` | `void setVolume(LuminaAudioHandle h, double volume)` | Updates the `Volume` parameter and applies changes to the system. |
| `setPitch` | `void setPitch(LuminaAudioHandle h, double pitch)` | Updates the `Pitch` parameter and applies changes to the system. |
| `setPan` | `void setPan(LuminaAudioHandle h, double pan)` | Updates the `Pan` parameter and applies changes to the system. |
| `pause` | `void pause(LuminaAudioHandle h)` | Executes `pause` operation. |
| `resume` | `void resume(LuminaAudioHandle h)` | Executes `resume` operation. |
| `stop` | `void stop(LuminaAudioHandle h)` | Executes `stop` operation. |
| `isPlaying` | `bool isPlaying(LuminaAudioHandle h)` | Checks current state or capability and returns a boolean value. |

### `class _ActiveSoundInfo`

`_ActiveSoundInfo`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `sound` | `LuminaSoundBase sound` | Holds the `sound` property or configuration state. |
| `volume` | `double volume` | Holds the `volume` property or configuration state. |
| `pitch` | `double pitch` | Holds the `pitch` property or configuration state. |
| `pan` | `double pan` | Holds the `pan` property or configuration state. |
| `looping` | `bool looping` | Holds the `looping` property or configuration state. |
| `isPaused` | `bool isPaused` | Holds the `isPaused` property or configuration state. |
| `elapsed` | `double elapsed` | Holds the `elapsed` property or configuration state. |

### `class NullAudioBackend`

Headless in-memory mock backend that records calls and synthesizes finish events for tests.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `initialize` | `Future<void> initialize()` | Executes `initialize` operation. |
| `shutdown` | `Future<void> shutdown()` | Executes `shutdown` operation. |
| `setVolume` | `void setVolume(LuminaAudioHandle h, double volume)` | Updates the `Volume` parameter and applies changes to the system. |
| `setPitch` | `void setPitch(LuminaAudioHandle h, double pitch)` | Updates the `Pitch` parameter and applies changes to the system. |
| `setPan` | `void setPan(LuminaAudioHandle h, double pan)` | Updates the `Pan` parameter and applies changes to the system. |
| `pause` | `void pause(LuminaAudioHandle h)` | Executes `pause` operation. |
| `resume` | `void resume(LuminaAudioHandle h)` | Executes `resume` operation. |
| `stop` | `void stop(LuminaAudioHandle h)` | Executes `stop` operation. |
| `isPlaying` | `bool isPlaying(LuminaAudioHandle h)` | Checks current state or capability and returns a boolean value. |
| `tick` | `void tick(double deltaTime)` | Advances playback simulation in headless mode, triggering [onFinished] for expired sound clips. |

## `lib/src/audio/audio_subsystem.dart`

### `class LuminaAudioSubsystem`

Central audio subsystem managing spatial listener coordinates, master volume, and spatial parameter updates.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `backend` | `LuminaAudioBackend backend` | Holds the `backend` property or configuration state. |
| `masterVolume` | `double get masterVolume` | Global master volume scalar (0.0 to 1.0). |
| `masterVolume` | `masterVolume(double v)` | Executes `masterVolume` operation. |
| `registerComponent` | `void registerComponent(LuminaAudioComponent comp)` | Registers an active audio component. |
| `unregisterComponent` | `void unregisterComponent(LuminaAudioComponent comp)` | Unregisters an audio component. |
| `onWorldTick` | `void onWorldTick(double deltaTime)` | Callback invoked when the corresponding event is triggered. |
| `calculateAttenuation` | `double calculateAttenuation(LuminaSoundBase sound, Vector3 emitterLocation)` | Calculates the 3D distance attenuation gain for [sound] at [emitterLocation]. |
| `calculatePan` | `double calculatePan(Vector3 emitterLocation)` | Calculates the stereo panning scalar (-1.0 left, +1.0 right) for [emitterLocation] in listener local space. |
| `pauseAll` | `void pauseAll()` | Pauses every component that is currently playing with a live handle and remembers them so [resumeAll] resumes exactly those (components paused/stopped by the user are untouched). |
| `resumeAll` | `void resumeAll()` | Resumes the components paused by the last [pauseAll] that still hold their handle. |
| `onWorldPauseChanged` | `void onWorldPauseChanged(bool paused)` | Callback invoked when the corresponding event is triggered. |
| `stopAll` | `void stopAll()` | Stops all currently playing audio components. |
| `onWorldShutdown` | `void onWorldShutdown()` | Callback invoked when the corresponding event is triggered. |

## `lib/src/audio/sound_base.dart`

### `enum LuminaAttenuationModel`

Attenuation curve models for distance-based 3D sound volume falloff.

### `class LuminaSoundAttenuation`

Distance-based 3D spatial attenuation settings.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `innerRadius` | `double innerRadius` | Holds the `innerRadius` property or configuration state. |
| `falloffDistance` | `double falloffDistance` | Holds the `falloffDistance` property or configuration state. |
| `model` | `LuminaAttenuationModel model` | Holds the `model` property or configuration state. |
| `calculateGain` | `double calculateGain(double distance)` | Calculates the volume gain factor (0.0 to 1.0) for a given distance in meters. |

### `class LuminaSoundBase`

Abstract base descriptor for sound assets and streams.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `soundId` | `String soundId` | Holds the `soundId` property or configuration state. |
| `baseVolume` | `double baseVolume` | Holds the `baseVolume` property or configuration state. |
| `basePitch` | `double basePitch` | Holds the `basePitch` property or configuration state. |
| `looping` | `bool looping` | Holds the `looping` property or configuration state. |
| `attenuation` | `LuminaSoundAttenuation? attenuation` | Holds the `attenuation` property or configuration state. |
| `duration` | `double? duration` | Holds the `duration` property or configuration state. |

### `class LuminaSoundWave`

File or bundle-backed sound wave asset descriptor.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `assetPath` | `String assetPath` | Holds the `assetPath` property or configuration state. |

---

[Previous: Animation](animation.md) | [Up: lumina (engine core)](index.md) | [Next: Collision](collision.md)
