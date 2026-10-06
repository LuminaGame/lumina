import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

import '../lumina_media.dart';
import 'lumina_audio_player_value.dart';

/// Controller managing audio playback through media_kit native integration,
/// with a deterministic headless fallback for unit test and CLI environments.
class LuminaAudioController extends ValueNotifier<LuminaAudioPlayerValue> {
  LuminaAudioController({
    String? source,
    String? title,
    this.autoPlay = false,
    this.loop = false,
    this.initialVolume = 1.0,
    this._preferHeadless = false,
  })  : _source = source,
        super(LuminaAudioPlayerValue.uninitialized().copyWith(
          isLooping: loop,
          volume: initialVolume.clamp(0.0, 1.0),
          source: source,
          title: title,
        ));

  factory LuminaAudioController.file(
    File file, {
    String? title,
    bool autoPlay = false,
    bool loop = false,
    double volume = 1.0,
  }) =>
      LuminaAudioController(
        source: file.path,
        title: title ?? file.uri.pathSegments.last,
        autoPlay: autoPlay,
        loop: loop,
        initialVolume: volume,
      );

  factory LuminaAudioController.network(
    String url, {
    String? title,
    bool autoPlay = false,
    bool loop = false,
    double volume = 1.0,
  }) =>
      LuminaAudioController(
        source: url,
        title: title ?? url.split('/').last,
        autoPlay: autoPlay,
        loop: loop,
        initialVolume: volume,
      );

  factory LuminaAudioController.asset(
    String asset, {
    String? title,
    bool autoPlay = false,
    bool loop = false,
    double volume = 1.0,
  }) =>
      LuminaAudioController(
        source: asset.startsWith('asset://') ? asset : 'asset:///$asset',
        title: title ?? asset.split('/').last,
        autoPlay: autoPlay,
        loop: loop,
        initialVolume: volume,
      );

  factory LuminaAudioController.headless({
    Duration duration = const Duration(seconds: 30),
    String? title,
    bool autoPlay = false,
    bool loop = false,
    double volume = 1.0,
  }) {
    final controller = LuminaAudioController(
      title: title,
      autoPlay: autoPlay,
      loop: loop,
      initialVolume: volume,
      preferHeadless: true,
    );
    controller._headlessDuration = duration;
    return controller;
  }

  final bool autoPlay;
  final bool loop;
  final double initialVolume;
  final bool _preferHeadless;

  String? _source;
  Duration _headlessDuration = const Duration(seconds: 30);
  Timer? _headlessTimer;

  Player? _player;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  bool _isDisposed = false;
  Completer<void>? _initCompleter;

  Player? get rawPlayer => _player;
  bool get isHeadless => _player == null;
  bool get isDisposed => _isDisposed;

  Future<void> initialize() async {
    if (_initCompleter != null) return _initCompleter!.future;
    _initCompleter = Completer<void>();

    try {
      LuminaMedia.ensureInitialized();
      final useNative = !_preferHeadless && LuminaMedia.isNativeAvailable;

      if (useNative) {
        try {
          final p = Player();
          _player = p;

          _subscriptions.add(p.stream.position.listen((pos) {
            if (!_isDisposed) value = value.copyWith(position: pos);
          }));

          _subscriptions.add(p.stream.duration.listen((dur) {
            if (!_isDisposed && dur > Duration.zero) {
              value = value.copyWith(duration: dur, isInitialized: true);
            }
          }));

          _subscriptions.add(p.stream.playing.listen((playing) {
            if (!_isDisposed) value = value.copyWith(isPlaying: playing);
          }));

          _subscriptions.add(p.stream.buffering.listen((buffering) {
            if (!_isDisposed) value = value.copyWith(isBuffering: buffering);
          }));

          _subscriptions.add(p.stream.completed.listen((completed) {
            if (!_isDisposed) value = value.copyWith(isCompleted: completed);
          }));

          _subscriptions.add(p.stream.error.listen((err) {
            if (!_isDisposed && err.isNotEmpty) {
              value = value.copyWith(errorDescription: err);
            }
          }));

          await p.setPlaylistMode(loop ? PlaylistMode.loop : PlaylistMode.none);
          await p.setVolume((initialVolume * 100.0).clamp(0.0, 100.0));

          if (_source != null && _source!.isNotEmpty) {
            await _openNativeSource(_source!, autoPlay: autoPlay);
          }
        } catch (_) {
          _fallbackToHeadless();
        }
      } else {
        _fallbackToHeadless();
      }

      if (!_initCompleter!.isCompleted) _initCompleter!.complete();
    } catch (e, st) {
      if (!_initCompleter!.isCompleted) _initCompleter!.completeError(e, st);
    }

    return _initCompleter!.future;
  }

  void _fallbackToHeadless() {
    _cleanupNative();
    value = value.copyWith(
      isInitialized: true,
      duration: _headlessDuration,
      isLooping: loop,
      volume: initialVolume.clamp(0.0, 1.0),
      source: _source,
    );
    if (autoPlay) play();
  }

  Future<void> _openNativeSource(String src, {required bool autoPlay}) async {
    final p = _player;
    if (p == null) return;
    await p.open(Media(src), play: autoPlay);
    value = value.copyWith(
      isInitialized: true,
      source: src,
      clearError: true,
    );
  }

  Future<void> open(String source, {String? title, bool autoPlay = false}) async {
    _source = source;
    if (title != null) value = value.copyWith(title: title);
    if (_player != null) {
      await _openNativeSource(source, autoPlay: autoPlay);
    } else {
      value = value.copyWith(
        source: source,
        position: Duration.zero,
        isCompleted: false,
        clearError: true,
      );
      if (autoPlay) play();
    }
  }

  Future<void> play() async {
    if (_isDisposed) return;
    if (_player != null) {
      await _player!.play();
    } else {
      value = value.copyWith(isPlaying: true, isCompleted: false);
      _startHeadlessTick();
    }
  }

  Future<void> pause() async {
    if (_isDisposed) return;
    if (_player != null) {
      await _player!.pause();
    } else {
      _headlessTimer?.cancel();
      _headlessTimer = null;
      value = value.copyWith(isPlaying: false);
    }
  }

  Future<void> playOrPause() async {
    if (value.isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> stop() async {
    if (_isDisposed) return;
    if (_player != null) {
      await _player!.stop();
      value = value.copyWith(isPlaying: false, position: Duration.zero);
    } else {
      _headlessTimer?.cancel();
      _headlessTimer = null;
      value = value.copyWith(isPlaying: false, position: Duration.zero);
    }
  }

  Future<void> seekTo(Duration position) async {
    if (_isDisposed) return;
    final max = value.duration > Duration.zero ? value.duration : _headlessDuration;
    final clamped = position < Duration.zero
        ? Duration.zero
        : (position > max ? max : position);

    if (_player != null) {
      await _player!.seek(clamped);
    } else {
      value = value.copyWith(
        position: clamped,
        isCompleted: clamped >= max && max > Duration.zero,
      );
    }
  }

  Future<void> seekToSeconds(double seconds) =>
      seekTo(Duration(milliseconds: (seconds * 1000).round()));

  Future<void> setVolume(double volume) async {
    if (_isDisposed) return;
    final v = volume.clamp(0.0, 1.0);
    if (_player != null) {
      await _player!.setVolume(v * 100.0);
    }
    value = value.copyWith(volume: v);
  }

  Future<void> setPlaybackSpeed(double speed) async {
    if (_isDisposed) return;
    final r = speed <= 0 ? 1.0 : speed;
    if (_player != null) {
      await _player!.setRate(r);
    }
    value = value.copyWith(playbackSpeed: r);
  }

  Future<void> setLooping(bool loop) async {
    if (_isDisposed) return;
    if (_player != null) {
      await _player!.setPlaylistMode(loop ? PlaylistMode.loop : PlaylistMode.none);
    }
    value = value.copyWith(isLooping: loop);
  }

  void _startHeadlessTick() {
    _headlessTimer?.cancel();
    const interval = Duration(milliseconds: 50);
    _headlessTimer = Timer.periodic(interval, (_) {
      if (_isDisposed) {
        _headlessTimer?.cancel();
        return;
      }
      final stepMs = (interval.inMilliseconds * value.playbackSpeed).round();
      final newPos = value.position + Duration(milliseconds: stepMs);
      final max = value.duration > Duration.zero ? value.duration : _headlessDuration;

      if (newPos >= max) {
        if (value.isLooping) {
          value = value.copyWith(position: Duration.zero);
        } else {
          _headlessTimer?.cancel();
          _headlessTimer = null;
          value = value.copyWith(
            position: max,
            isPlaying: false,
            isCompleted: true,
          );
        }
      } else {
        value = value.copyWith(position: newPos);
      }
    });
  }

  void _cleanupNative() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    _subscriptions.clear();
    _player?.dispose();
    _player = null;
  }

  @override
  void dispose() {
    _isDisposed = true;
    _headlessTimer?.cancel();
    _headlessTimer = null;
    _cleanupNative();
    super.dispose();
  }
}
