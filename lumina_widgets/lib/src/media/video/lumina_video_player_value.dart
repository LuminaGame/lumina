import 'package:flutter/widgets.dart';

/// Immutable state snapshot of a [LuminaVideoController].
@immutable
class LuminaVideoPlayerValue {
  const LuminaVideoPlayerValue({
    this.isInitialized = false,
    this.isPlaying = false,
    this.isLooping = false,
    this.isBuffering = false,
    this.isCompleted = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.volume = 1.0,
    this.playbackSpeed = 1.0,
    this.size = Size.zero,
    this.source,
    this.errorDescription,
  });

  /// An uninitialized video player state.
  const LuminaVideoPlayerValue.uninitialized() : this();

  /// Whether the video source has been loaded and dimensions/duration are ready.
  final bool isInitialized;

  /// Whether the video is actively playing.
  final bool isPlaying;

  /// Whether the player will loop back to start upon completion.
  final bool isLooping;

  /// Whether the player is currently buffering data.
  final bool isBuffering;

  /// Whether playback has reached the end of the media source.
  final bool isCompleted;

  /// Current playback position.
  final Duration position;

  /// Total duration of the video.
  final Duration duration;

  /// Output audio volume in 0.0 .. 1.0 range.
  final double volume;

  /// Playback speed multiplier (e.g., 1.0 = normal, 2.0 = double speed).
  final double playbackSpeed;

  /// Native resolution (pixel width and height) of the video track.
  final Size size;

  /// Loaded URI or file path of the video.
  final String? source;

  /// Error message if an error occurred during loading or playback.
  final String? errorDescription;

  /// Whether an error occurred.
  bool get hasError => errorDescription != null;

  /// Aspect ratio (width / height) or default 16/9 if dimensions are empty.
  double get aspectRatio {
    if (size.width > 0 && size.height > 0) {
      return size.width / size.height;
    }
    return 16.0 / 9.0;
  }

  /// Copies this value with optional overridden fields.
  LuminaVideoPlayerValue copyWith({
    bool? isInitialized,
    bool? isPlaying,
    bool? isLooping,
    bool? isBuffering,
    bool? isCompleted,
    Duration? position,
    Duration? duration,
    double? volume,
    double? playbackSpeed,
    Size? size,
    String? source,
    String? errorDescription,
    bool clearError = false,
  }) {
    return LuminaVideoPlayerValue(
      isInitialized: isInitialized ?? this.isInitialized,
      isPlaying: isPlaying ?? this.isPlaying,
      isLooping: isLooping ?? this.isLooping,
      isBuffering: isBuffering ?? this.isBuffering,
      isCompleted: isCompleted ?? this.isCompleted,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      volume: volume ?? this.volume,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      size: size ?? this.size,
      source: source ?? this.source,
      errorDescription: clearError ? null : (errorDescription ?? this.errorDescription),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LuminaVideoPlayerValue &&
        other.isInitialized == isInitialized &&
        other.isPlaying == isPlaying &&
        other.isLooping == isLooping &&
        other.isBuffering == isBuffering &&
        other.isCompleted == isCompleted &&
        other.position == position &&
        other.duration == duration &&
        other.volume == volume &&
        other.playbackSpeed == playbackSpeed &&
        other.size == size &&
        other.source == source &&
        other.errorDescription == errorDescription;
  }

  @override
  int get hashCode => Object.hash(
        isInitialized,
        isPlaying,
        isLooping,
        isBuffering,
        isCompleted,
        position,
        duration,
        volume,
        playbackSpeed,
        size,
        source,
        errorDescription,
      );

  @override
  String toString() =>
      'LuminaVideoPlayerValue(init: $isInitialized, playing: $isPlaying, '
      'pos: $position / $duration, loop: $isLooping, vol: $volume, speed: $playbackSpeed, '
      'size: $size, error: $errorDescription)';
}
