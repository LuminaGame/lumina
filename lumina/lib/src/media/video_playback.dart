/// A video the engine plays without knowing how: what the Blueprint
/// `Open Video` node returns and the other video nodes drive. The engine
/// holds no media player; the game's Flutter side (`lumina_widgets`, whose
/// `LuminaVideoController` implements this on media_kit) registers
/// [LuminaVideoPlayback.factory] at start-up.
abstract interface class LuminaVideoPlayback {
  /// Creates a playback of [source] (a file path, `asset://…` or a URL), set
  /// by the host; null when the host has no video player (a headless world,
  /// a test), and then `Open Video` returns nothing.
  static LuminaVideoPlayback Function({
    required String source,
    bool autoPlay,
    bool loop,
    double initialVolume,
  })? factory;

  /// Opens the source; the other members work once it completes.
  Future<void> initialize();

  Future<void> play();

  Future<void> pause();

  Future<void> stop();

  /// Seeks to [seconds] from the start.
  Future<void> seekToSeconds(double seconds);

  /// 0–1.
  Future<void> setVolume(double volume);

  /// 1 is normal speed.
  Future<void> setPlaybackSpeed(double rate);

  Future<void> setLooping(bool loop);

  bool get isPlaying;

  Duration get position;

  Duration get duration;
}
