import 'dart:async';
import 'sound_base.dart';

/// Opaque integer handle representing an active audio instance in the audio backend.
extension type const LuminaAudioHandle(int value) {}

/// Abstract pluggable backend driver for low-level audio decoding and playback.
abstract class LuminaAudioBackend {
  Future<void> initialize();
  Future<void> shutdown();

  Future<LuminaAudioHandle> play(
    LuminaSoundBase sound, {
    required double volume,
    required double pitch,
    required double pan,
    required bool looping,
  });

  void setVolume(LuminaAudioHandle h, double volume);
  void setPitch(LuminaAudioHandle h, double pitch);
  void setPan(LuminaAudioHandle h, double pan);
  void pause(LuminaAudioHandle h);
  void resume(LuminaAudioHandle h);
  void stop(LuminaAudioHandle h);
  bool isPlaying(LuminaAudioHandle h);

  void Function(LuminaAudioHandle handle)? onFinished;
}

class _ActiveSoundInfo {
  final LuminaSoundBase sound;
  double volume;
  double pitch;
  double pan;
  bool looping;
  bool isPaused;
  double elapsed;

  _ActiveSoundInfo({
    required this.sound,
    required this.volume,
    required this.pitch,
    required this.pan,
    required this.looping,
    this.isPaused = false,
    this.elapsed = 0.0,
  });
}

/// Headless in-memory mock backend that records calls and synthesizes finish events for tests.
class NullAudioBackend implements LuminaAudioBackend {
  static int _nextHandle = 1;
  final Map<LuminaAudioHandle, _ActiveSoundInfo> _activeSounds = {};

  final List<String> callLog = [];
  final List<({LuminaSoundBase sound, double volume, double pitch, double pan, bool looping})> playCalls = [];
  final List<LuminaAudioHandle> stopCalls = [];
  final List<({LuminaAudioHandle handle, double volume})> volumeCalls = [];
  final List<({LuminaAudioHandle handle, double pitch})> pitchCalls = [];
  final List<({LuminaAudioHandle handle, double pan})> panCalls = [];

  bool isInitialized = false;
  bool isShutdown = false;

  @override
  void Function(LuminaAudioHandle handle)? onFinished;

  @override
  Future<void> initialize() async {
    isInitialized = true;
    callLog.add('initialize');
  }

  @override
  Future<void> shutdown() async {
    isShutdown = true;
    callLog.add('shutdown');
    _activeSounds.clear();
  }

  @override
  Future<LuminaAudioHandle> play(
    LuminaSoundBase sound, {
    required double volume,
    required double pitch,
    required double pan,
    required bool looping,
  }) async {
    final handle = LuminaAudioHandle(_nextHandle++);
    _activeSounds[handle] = _ActiveSoundInfo(
      sound: sound,
      volume: volume,
      pitch: pitch,
      pan: pan,
      looping: looping,
    );
    playCalls.add((sound: sound, volume: volume, pitch: pitch, pan: pan, looping: looping));
    callLog.add('play($handle)');
    return handle;
  }

  @override
  void setVolume(LuminaAudioHandle h, double volume) {
    if (_activeSounds.containsKey(h)) {
      _activeSounds[h]!.volume = volume;
      volumeCalls.add((handle: h, volume: volume));
      callLog.add('setVolume($h, $volume)');
    }
  }

  @override
  void setPitch(LuminaAudioHandle h, double pitch) {
    if (_activeSounds.containsKey(h)) {
      _activeSounds[h]!.pitch = pitch;
      pitchCalls.add((handle: h, pitch: pitch));
      callLog.add('setPitch($h, $pitch)');
    }
  }

  @override
  void setPan(LuminaAudioHandle h, double pan) {
    if (_activeSounds.containsKey(h)) {
      _activeSounds[h]!.pan = pan;
      panCalls.add((handle: h, pan: pan));
      callLog.add('setPan($h, $pan)');
    }
  }

  @override
  void pause(LuminaAudioHandle h) {
    if (_activeSounds.containsKey(h)) {
      _activeSounds[h]!.isPaused = true;
      callLog.add('pause($h)');
    }
  }

  @override
  void resume(LuminaAudioHandle h) {
    if (_activeSounds.containsKey(h)) {
      _activeSounds[h]!.isPaused = false;
      callLog.add('resume($h)');
    }
  }

  @override
  void stop(LuminaAudioHandle h) {
    if (_activeSounds.remove(h) != null) {
      stopCalls.add(h);
      callLog.add('stop($h)');
    }
  }

  @override
  bool isPlaying(LuminaAudioHandle h) {
    final s = _activeSounds[h];
    return s != null && !s.isPaused;
  }

  /// Advances playback simulation in headless mode, triggering [onFinished] for expired sound clips.
  void tick(double deltaTime) {
    final completed = <LuminaAudioHandle>[];
    for (final entry in _activeSounds.entries) {
      final info = entry.value;
      if (info.isPaused || info.looping) continue;
      if (info.sound.duration != null) {
        info.elapsed += deltaTime;
        if (info.elapsed >= info.sound.duration!) {
          completed.add(entry.key);
        }
      }
    }

    for (final h in completed) {
      _activeSounds.remove(h);
      onFinished?.call(h);
    }
  }
}
