import 'package:flutter/widgets.dart';

/// Immutable state snapshot of a [LuminaAudioController].
@immutable
class LuminaAudioPlayerValue {
  const LuminaAudioPlayerValue({
    this.isInitialized = false,
    this.isPlaying = false,
    this.isLooping = false,
    this.isBuffering = false,
    this.isCompleted = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.volume = 1.0,
    this.playbackSpeed = 1.0,
    this.source,
    this.title,
    this.errorDescription,
  });

  const LuminaAudioPlayerValue.uninitialized() : this();

  final bool isInitialized;
  final bool isPlaying;
  final bool isLooping;
  final bool isBuffering;
  final bool isCompleted;
  final Duration position;
  final Duration duration;
  final double volume;
  final double playbackSpeed;
  final String? source;
  final String? title;
  final String? errorDescription;

  bool get hasError => errorDescription != null;

  LuminaAudioPlayerValue copyWith({
    bool? isInitialized,
    bool? isPlaying,
    bool? isLooping,
    bool? isBuffering,
    bool? isCompleted,
    Duration? position,
    Duration? duration,
    double? volume,
    double? playbackSpeed,
    String? source,
    String? title,
    String? errorDescription,
    bool clearError = false,
  }) {
    return LuminaAudioPlayerValue(
      isInitialized: isInitialized ?? this.isInitialized,
      isPlaying: isPlaying ?? this.isPlaying,
      isLooping: isLooping ?? this.isLooping,
      isBuffering: isBuffering ?? this.isBuffering,
      isCompleted: isCompleted ?? this.isCompleted,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      volume: volume ?? this.volume,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      source: source ?? this.source,
      title: title ?? this.title,
      errorDescription: clearError ? null : (errorDescription ?? this.errorDescription),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LuminaAudioPlayerValue &&
        other.isInitialized == isInitialized &&
        other.isPlaying == isPlaying &&
        other.isLooping == isLooping &&
        other.isBuffering == isBuffering &&
        other.isCompleted == isCompleted &&
        other.position == position &&
        other.duration == duration &&
        other.volume == volume &&
        other.playbackSpeed == playbackSpeed &&
        other.source == source &&
        other.title == title &&
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
        source,
        title,
        errorDescription,
      );

  @override
  String toString() =>
      'LuminaAudioPlayerValue(init: $isInitialized, playing: $isPlaying, '
      'pos: $position / $duration, loop: $isLooping, vol: $volume, error: $errorDescription)';
}
