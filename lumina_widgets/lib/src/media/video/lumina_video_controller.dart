import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'package:lumina/src/media/lumina_media.dart';
import 'package:lumina/src/media/video/lumina_video_player_value.dart';

/// Controller managing the playback lifecycle of video and audio streams
/// through media_kit native integration, with a built-in deterministic fallback
/// for headless and testing environments.
class LuminaVideoController extends ValueNotifier<LuminaVideoPlayerValue> {
  LuminaVideoController({
    String? source,
    this.autoPlay = false,
    this.loop = false,
    this.initialVolume = 1.0,
    this._preferHeadless = false,
  })  : _source = source,
        super(LuminaVideoPlayerValue.uninitialized().copyWith(
          isLooping: loop,
          volume: initialVolume.clamp(0.0, 1.0),
          source: source,
        ));

  /// Creates a controller configured for a local filesystem file.
  factory LuminaVideoController.file(
    File file, {
    bool autoPlay = false,
    bool loop = false,
    double volume = 1.0,
  }) =>
      LuminaVideoController(
        source: file.path,
        autoPlay: autoPlay,
        loop: loop,
        initialVolume: volume,
      );

  /// Creates a controller configured for a network URI.
  factory LuminaVideoController.network(
    String url, {
    bool autoPlay = false,
    bool loop = false,
    double volume = 1.0,
  }) =>
      LuminaVideoController(
        source: url,
        autoPlay: autoPlay,
        loop: loop,
        initialVolume: volume,
      );

  /// Creates a controller configured for a bundled asset.
  factory LuminaVideoController.asset(
    String asset, {
    bool autoPlay = false,
    bool loop = false,
    double volume = 1.0,
  }) =>
      LuminaVideoController(
        source: asset.startsWith('asset://') ? asset : 'asset:///$asset',
        autoPlay: autoPlay,
        loop: loop,
        initialVolume: volume,
      );

  /// Creates a pure headless controller that simulates playback deterministically
  /// without loading native media_kit or GPU texture buffers.
  factory LuminaVideoController.headless({
    Duration duration = const Duration(seconds: 10),
    Size size = const Size(1920, 1080),
    bool autoPlay = false,
    bool loop = false,
    double volume = 1.0,
  }) {
    final controller = LuminaVideoController(
      autoPlay: autoPlay,
      loop: loop,
      initialVolume: volume,
      preferHeadless: true,
    );
    controller._headlessDuration = duration;
    controller._headlessSize = size;
    return controller;
  }

  final bool autoPlay;
  final bool loop;
  final double initialVolume;
  final bool _preferHeadless;

  String? _source;
  Duration _headlessDuration = const Duration(seconds: 10);
  Size _headlessSize = const Size(1920, 1080);
  Timer? _headlessTimer;

  Player? _player;
  VideoController? _videoController;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  bool _isDisposed = false;
  Completer<void>? _initCompleter;

  /// Underlying media_kit Player instance, or null in headless mode.
  Player? get rawPlayer => _player;

  /// Underlying media_kit VideoController instance, or null in headless mode.
  VideoController? get rawVideoController => _videoController;

  /// Whether this controller is running in headless / simulated mode.
  bool get isHeadless => _player == null;

  /// Whether the controller is disposed.
  bool get isDisposed => _isDisposed;

  /// Initializes the video player and loads the source if specified.
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
          _videoController = VideoController(p);

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

          _subscriptions.add(p.stream.videoParams.listen((params) {
            if (!_isDisposed) {
              final w = (params.w ?? 0).toDouble();
              final h = (params.h ?? 0).toDouble();
              if (w > 0 && h > 0) {
                value = value.copyWith(size: Size(w, h));
              }
            }
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
          // Native init failed (e.g. libmpv dynamic link failure in test runner)
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
      size: _headlessSize,
      isLooping: loop,
      volume: initialVolume.clamp(0.0, 1.0),
      source: _source,
    );
    if (autoPlay) play();
  }

  Future<void> _openNativeSource(String src, {required bool autoPlay}) async {
    final p = _player;
    if (p == null) return;
    final media = Media(src);

    Future<Duration> resolveDuration() async {
      if (p.state.duration > Duration.zero) return p.state.duration;
      try {
        return await p.stream.duration
            .firstWhere((dur) => dur > Duration.zero)
            .timeout(const Duration(seconds: 3), onTimeout: () => p.state.duration);
      } catch (_) {
        return p.state.duration;
      }
    }

    Future<VideoParams> resolveVideoParams() async {
      if ((p.state.width ?? 0) > 0 && (p.state.height ?? 0) > 0) {
        return p.state.videoParams;
      }
      try {
        return await p.stream.videoParams
            .firstWhere((vp) => (vp.w ?? 0) > 0 && (vp.h ?? 0) > 0)
            .timeout(const Duration(milliseconds: 1500), onTimeout: () => p.state.videoParams);
      } catch (_) {
        return p.state.videoParams;
      }
    }

    final durTask = resolveDuration();
    final paramsTask = resolveVideoParams();

    await p.open(media, play: autoPlay);

    final dur = await durTask;
    final vp = await paramsTask;

    final resolvedDuration = dur > Duration.zero
        ? dur
        : (p.state.duration > Duration.zero ? p.state.duration : value.duration);
    final w = (vp.w ?? p.state.width ?? 0).toDouble();
    final h = (vp.h ?? p.state.height ?? 0).toDouble();
    final resolvedSize = (w > 0 && h > 0) ? Size(w, h) : value.size;

    value = value.copyWith(
      isInitialized: true,
      duration: resolvedDuration,
      size: resolvedSize,
      source: src,
      clearError: true,
    );
  }

  /// Opens and loads [source] into the player.
  Future<void> open(String source, {bool autoPlay = false}) async {
    _source = source;
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

  /// Starts or resumes video playback.
  Future<void> play() async {
    if (_isDisposed) return;
    if (_player != null) {
      await _player!.play();
    } else {
      value = value.copyWith(isPlaying: true, isCompleted: false);
      _startHeadlessTick();
    }
  }

  /// Pauses video playback.
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

  /// Toggles between play and pause.
  Future<void> playOrPause() async {
    if (value.isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  /// Stops video playback and resets playhead to start.
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

  /// Seeks to specified [position].
  Future<void> seekTo(Duration position) async {
    if (_isDisposed) return;
    final max = value.duration > Duration.zero ? value.duration : _headlessDuration;
    final clamped = position < Duration.zero
        ? Duration.zero
        : (position > max ? max : position);

    value = value.copyWith(
      position: clamped,
      isCompleted: clamped >= max && max > Duration.zero,
    );

    if (_player != null) {
      await _player!.seek(clamped);
    }
  }

  /// Seeks to specified position in fractional seconds.
  Future<void> seekToSeconds(double seconds) =>
      seekTo(Duration(milliseconds: (seconds * 1000).round()));

  /// Sets audio output volume in 0.0 .. 1.0 range.
  Future<void> setVolume(double volume) async {
    if (_isDisposed) return;
    final v = volume.clamp(0.0, 1.0);
    if (_player != null) {
      await _player!.setVolume(v * 100.0);
    }
    value = value.copyWith(volume: v);
  }

  /// Sets playback speed multiplier (e.g. 1.0 = normal, 2.0 = 2x).
  Future<void> setPlaybackSpeed(double speed) async {
    if (_isDisposed) return;
    final r = speed <= 0 ? 1.0 : speed;
    if (_player != null) {
      await _player!.setRate(r);
    }
    value = value.copyWith(playbackSpeed: r);
  }

  /// Alias for [setPlaybackSpeed].
  Future<void> setRate(double rate) => setPlaybackSpeed(rate);

  /// Sets looping behavior.
  Future<void> setLooping(bool loop) async {
    if (_isDisposed) return;
    if (_player != null) {
      await _player!.setPlaylistMode(loop ? PlaylistMode.loop : PlaylistMode.none);
    }
    value = value.copyWith(isLooping: loop);
  }

  void _startHeadlessTick() {
    _headlessTimer?.cancel();
    const interval = Duration(milliseconds: 33); // ~30 fps
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
    _videoController = null;
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
