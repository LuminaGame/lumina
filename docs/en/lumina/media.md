[Türkçe](../../tr/lumina/media.md)

# Media Subsystem (Video & Audio Player)

The media subsystem provides high-performance video and audio playback across desktop and mobile platforms powered by `media-kit` (libmpv hardware decoding), integrated seamlessly into Lumina's runtime, UMG widgets, Blueprint scripting system, and Lumina Studio UI.

File paths are relative to the `lumina/` package directory.

**On this page:**

- [Architecture & Initialization](#architecture--initialization)
- [`lib/src/media/lumina_media.dart`](#libsrcmedialumina_mediadart)
- [`lib/src/media/video/lumina_video_controller.dart`](#libsrcmediavideolumina_video_controllerdart)
- [`lib/src/media/video/lumina_video_player.dart`](#libsrcmediavideolumina_video_playerdart)
- [`lib/src/media/audio/lumina_audio_controller.dart`](#libsrcmediaaudiolumina_audio_controllerdart)
- [`lib/src/media/audio/lumina_audio_player.dart`](#libsrcmediaaudiolumina_audio_playerdart)
- [`lib/src/umg/umg_media_widgets.dart`](#libsrcumgumg_media_widgetsdart)
- [Blueprint Video Nodes](#blueprint-video-nodes)
- [Lumina Studio UI Widgets](#lumina-studio-ui-widgets)

---

## Architecture & Initialization

The media subsystem is built on top of `media_kit`, `media_kit_video`, and `media_kit_libs_video`:

1. **Hardware Acceleration**: On desktop (Windows, Linux, macOS) and mobile platforms, media decoding and video output are accelerated using native libmpv binaries.
2. **Headless & Testing Fallback**: When running headless unit tests or environments without native shared libraries, `LuminaVideoController` and `LuminaAudioController` automatically detect native library availability (`LuminaMedia.isNativeAvailable`) and fallback to a deterministic internal playback simulator. This allows test suites and CI pipelines to execute without crashes or mock dependencies.
3. **Pluggable & Extensible**: Plugins (such as `gem_x_plugin`) migrate directly from standard Flutter `video_player` to `LuminaVideoController` and `LuminaVideoPlayer` with full API compatibility (`ValueNotifier<LuminaVideoPlayerValue>`).

---

## `lib/src/media/lumina_media.dart`

### `class LuminaMedia`

Coordinates subsystem initialization across Lumina and Lumina Studio.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `ensureInitialized` | `static void ensureInitialized()` | Initializes native bindings and media playback hooks. Safe to call multiple times. |
| `isNativeAvailable` | `static bool get isNativeAvailable` | Returns whether the native libmpv runtime was successfully loaded and available. |

---

## `lib/src/media/video/lumina_video_controller.dart`

### `class LuminaVideoPlayerValue`

An immutable state snapshot of a video player's current playback status.

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `isInitialized` | `final bool isInitialized` | Whether the video source has been loaded and initialized. |
| `isPlaying` | `final bool isPlaying` | Whether playback is actively running. |
| `isBuffering` | `final bool isBuffering` | Whether the media stream is currently buffering. |
| `isCompleted` | `final bool isCompleted` | Whether playback has reached the end of the media source. |
| `isLooping` | `final bool isLooping` | Whether playback loops upon reaching the end. |
| `position` | `final Duration position` | Current playback position timestamp. |
| `duration` | `final Duration duration` | Total media duration. |
| `size` | `final Size size` | Video frame resolution in pixels. |
| `aspectRatio` | `double get aspectRatio` | Aspect ratio (`width / height`) of the video stream. |
| `volume` | `final double volume` | Current audio volume between `0.0` and `1.0`. |
| `playbackRate` | `final double playbackRate` | Current playback rate multiplier (e.g. `1.0`, `1.5`, `2.0`). |
| `hasError` | `bool get hasError` | Whether an error has occurred during media loading or playback. |
| `errorDescription` | `final String? errorDescription` | Error message string if an error occurred. |

### `class LuminaVideoController`

A controller managing video loading, hardware-accelerated playback, scrubbing, and notifications (`ValueNotifier<LuminaVideoPlayerValue>`).

**Constructors:**

- `LuminaVideoController.file(File file, {bool autoPlay = false, bool looping = false, double volume = 1.0, double playbackRate = 1.0, bool preferHeadless = false})`
- `LuminaVideoController.asset(String assetPath, {bool autoPlay = false, bool looping = false, double volume = 1.0, double playbackRate = 1.0, bool preferHeadless = false})`
- `LuminaVideoController.network(String uri, {bool autoPlay = false, bool looping = false, double volume = 1.0, double playbackRate = 1.0, bool preferHeadless = false})`

**Members:**

| Member | Signature | Description |
| :--- | :--- | :--- |
| `initialize` | `Future<void> initialize()` | Opens the video media source, sets up video streams, and signals initialization. |
| `play` | `Future<void> play()` | Starts or resumes video playback. |
| `pause` | `Future<void> pause()` | Pauses video playback. |
| `stop` | `Future<void> stop()` | Stops playback and rewinds to the beginning (`Duration.zero`). |
| `seekTo` | `Future<void> seekTo(Duration position)` | Seeks playback to the specified target position timestamp. |
| `setVolume` | `Future<void> setVolume(double volume)` | Adjusts video volume between `0.0` (mute) and `1.0` (maximum). |
| `setPlaybackRate` | `Future<void> setPlaybackRate(double rate)` | Adjusts playback speed (clamped between `0.25` and `4.0`). |
| `setLooping` | `Future<void> setLooping(bool looping)` | Toggles continuous loop playback. |
| `dispose` | `Future<void> dispose()` | Cleans up native player handles, textures, and subscriptions. |

---

## `lib/src/media/video/lumina_video_player.dart`

### `class LuminaVideoPlayer`

A Flutter widget that embeds the native hardware-accelerated video rendering surface for a `LuminaVideoController`.

**Constructors:**

- `const LuminaVideoPlayer({super.key, required this.controller, this.fit = BoxFit.contain, this.alignment = Alignment.center, this.filterQuality = FilterQuality.low, this.controls})`

---

## `lib/src/media/audio/lumina_audio_controller.dart`

### `class LuminaAudioPlayerValue`

An immutable status snapshot representing non-spatialized background music, voiceover, or interface audio stream playback.

### `class LuminaAudioController`

A lightweight media controller dedicated to standalone audio streams without rendering overhead.

**Constructors:**

- `LuminaAudioController.file(File file, {bool autoPlay = false, bool looping = false, double volume = 1.0, double playbackRate = 1.0, bool preferHeadless = false})`
- `LuminaAudioController.asset(String assetPath, {bool autoPlay = false, bool looping = false, double volume = 1.0, double playbackRate = 1.0, bool preferHeadless = false})`
- `LuminaAudioController.network(String uri, {bool autoPlay = false, bool looping = false, double volume = 1.0, double playbackRate = 1.0, bool preferHeadless = false})`

---

## `lib/src/media/audio/lumina_audio_player.dart`

### `class LuminaAudioPlayer`

A widget providing visual playback state and controls for an audio controller.

---

## `lib/src/umg/umg_media_widgets.dart`

UMG runtime widgets enabling game developers to place video and audio players in their in-game UI layouts and HUDs.

### `class LuminaUmgVideoPlayer`

A UMG widget for in-game video playback. Supports specifying file/asset/network paths, autoplay, looping, volume, box fit, and automatic lifecycle disposal.

### `class LuminaUmgAudioPlayer`

A UMG widget for in-game audio playback and soundtrack orchestration.

---

## Blueprint Video Nodes

Lumina Blueprints include 11 standard media nodes available in the node palette under `Media`:

| Node Name | Type | Description |
| :--- | :--- | :--- |
| `Open Video` | Impure | Creates or reopens a video controller given a file, asset, or URL path with optional autoplay and looping flags. |
| `Play Video` | Impure | Starts or resumes video playback on the target controller. |
| `Pause Video` | Impure | Pauses video playback on the target controller. |
| `Stop Video` | Impure | Stops playback and rewinds to the beginning on the target controller. |
| `Seek Video` | Impure | Seeks playback to a specific timestamp in milliseconds. |
| `Set Video Volume` | Impure | Sets controller audio volume between `0.0` and `1.0`. |
| `Set Video Rate` | Impure | Sets playback rate multiplier (`0.25` - `4.0`). |
| `Set Video Looping` | Impure | Toggles looping state. |
| `Is Video Playing` | Pure | Returns boolean indicating if video is currently playing. |
| `Get Video Position` | Pure | Returns current playback position in milliseconds. |
| `Get Video Duration` | Pure | Returns total video duration in milliseconds. |

---

## Lumina Studio UI Widgets

Exported from `lumina_ui` (`package:lumina_ui/lumina_ui.dart` and `lib/ui/core/widgets/media/editor_media_widgets.dart`):

1. **`LuminaVideoPlayerWidget`**: Built using `shadcn_flutter`, featuring:
   - Hardware video surface display.
   - Play/Pause toggle and Stop buttons.
   - Position and total duration timecodes (`00:12 / 01:45`).
   - Interactive progress scrubbing slider.
   - Volume popover with mute toggle and vertical volume slider.
   - Loop toggle button.
   - Playback rate dropdown menu (`0.5x`, `1.0x`, `1.25x`, `1.5x`, `2.0x`).
2. **`LuminaAudioPlayerWidget`**: Lightweight `shadcn_flutter` audio player with playback bar, timecode, volume, and looping options.
