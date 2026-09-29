part of '../sequencer_view_model.dart';

/// The live level binding (evaluation written onto the editor's actors)
/// and the transport: ticker, play/pause/stop, keyframe stepping, range.
mixin _SequencerPlaybackAndLevelBinding on _SequencerViewModelState {

  // ---------------------------------------------------------------------------
  // Live level binding: evaluation writes onto EditorViewModel's actors
  // ---------------------------------------------------------------------------

  /// Binds the cinematic to the live level. [actors] resolves the current
  /// actor list (usually `editorViewModel.actors`), [onChanged] is the
  /// editor's notify path so outliner/details/viewport redraw the same frame.
  void bindLevel({required List<EditorActorNode> Function() actors, VoidCallback? onChanged}) {
    restoreLevel();
    _levelActors = actors;
    _onLevelChanged = onChanged;
  }

  /// Puts every touched actor property back to its pre-preview value and
  /// forgets the snapshot. A cinematic preview never dirties the level: the
  /// writes bypass the transaction/dirty path entirely.
  @override
  void restoreLevel() {
    if (_snapshot.isEmpty) return;
    final actors = _levelActors?.call() ?? const <EditorActorNode>[];
    for (final snap in _snapshot.values) {
      final actor = _findActor(actors, snap.actorId);
      if (actor != null) snap.restore(actor);
    }
    _snapshot.clear();
    _onLevelChanged?.call();
  }

  EditorActorNode? _findActor(List<EditorActorNode> actors, String id) {
    for (final a in actors) {
      if (a.id == id) return a;
    }
    return null;
  }

  @override
  void _applyPlayheadToLevel() {
    final provider = _levelActors;
    if (provider == null) return;
    final actors = provider();
    if (actors.isEmpty) return;

    bool touched = false;
    for (final sample in SequencerViewModel._evaluator.evaluate(_data, _playheadPosition)) {
      if (sample.values.isEmpty) continue;
      final actor = _findActor(actors, sample.actorId);
      if (actor == null) continue;
      for (final entry in sample.values.entries) {
        final writer = _ChannelSnapshot.resolve(actor, sample, entry.key);
        if (writer == null) continue;
        _snapshot.putIfAbsent(writer.id, () => writer..capture(actor));
        writer.write(actor, entry.value);
        touched = true;
      }
    }
    if (touched) _onLevelChanged?.call();
  }

  // ---------------------------------------------------------------------------
  // Transport
  // ---------------------------------------------------------------------------

  /// Drives playback from the widget's frame clock. Without a ticker (unit
  /// tests) advance the clock manually with [advanceClock].
  @override
  void attachTicker(TickerProvider vsync) {
    _ticker?.dispose();
    _ticker = vsync.createTicker(_onTick);
    if (_isPlaying) {
      _lastElapsed = null;
      _ticker!.start();
    }
  }

  /// Drops the widget-owned ticker (the widget is going away while the view
  /// model may live on, e.g. when injected by a test or a tab session).
  void detachTicker() {
    _ticker?.dispose();
    _ticker = null;
    _lastElapsed = null;
  }

  void _onTick(Duration elapsed) {
    final last = _lastElapsed;
    _lastElapsed = elapsed;
    if (last == null) return;
    final dt = (elapsed - last).inMicroseconds / 1e6;
    advanceClock(dt);
  }

  void play() {
    if (_isPlaying) return;
    if (_playheadPosition >= rangeEnd && !_isLooping) {
      _playheadPosition = _rangeStart.toDouble();
    }
    _isPlaying = true;
    _lastElapsed = null;
    _applyPlayheadToLevel();
    if (_ticker != null && !_ticker!.isActive) _ticker!.start();
    notifyListeners();
  }

  @override
  void pause() {
    if (!_isPlaying) return;
    _isPlaying = false;
    _ticker?.stop();
    _lastElapsed = null;
    notifyListeners();
  }

  void togglePlay() => _isPlaying ? pause() : play();

  /// Stops playback, returns the playhead to the range start and restores the
  /// actors' pre-preview state.
  @override
  void stop() {
    _isPlaying = false;
    _ticker?.stop();
    _lastElapsed = null;
    _playheadPosition = _rangeStart.toDouble();
    restoreLevel();
    notifyListeners();
  }

  /// Advances playback by [dt] seconds at the sequence fps, honouring the
  /// playback range and loop mode. Fractional frames accumulate; only the
  /// displayed frame is rounded.
  void advanceClock(double dt) {
    if (!_isPlaying || dt <= 0) return;
    final curFps = fps > 0 ? fps : 30;
    final start = _rangeStart.toDouble();
    final end = rangeEnd.toDouble();
    double next = _playheadPosition + dt * curFps;

    if (next > end) {
      final span = end - start;
      if (_isLooping && span > 0) {
        next = start + (next - start) % span;
      } else {
        next = end;
        _isPlaying = false;
        _ticker?.stop();
        _lastElapsed = null;
      }
    }
    _setPlayhead(next);
  }

  void goToFirstFrame() => scrubToFrame(_rangeStart);

  void nextKeyframe() {
    final frames = SequencerEvaluator.mergedKeyFrames(_data);
    final current = playheadFrame;
    for (final f in frames) {
      if (f > current) {
        scrubToFrame(f);
        return;
      }
    }
  }

  void previousKeyframe() {
    final frames = SequencerEvaluator.mergedKeyFrames(_data);
    final current = playheadFrame;
    for (final f in frames.reversed) {
      if (f < current) {
        scrubToFrame(f);
        return;
      }
    }
  }

  void setLooping(bool loop) {
    if (_isLooping == loop) return;
    _isLooping = loop;
    notifyListeners();
  }

  void setPlaybackRange(int start, int end) {
    final len = _data.lengthFrames;
    final s = start.clamp(0, len);
    final e = end.clamp(0, len);
    _rangeStart = s <= e ? s : e;
    _rangeEnd = (s <= e ? e : s) >= len ? null : (s <= e ? e : s);
    notifyListeners();
  }

  void setRangeStart(int start) => setPlaybackRange(start, rangeEnd);
  void setRangeEnd(int end) => setPlaybackRange(_rangeStart, end);

  void setTimeFormat(SequencerTimeFormat format) {
    if (_timeFormat == format) return;
    _timeFormat = format;
    notifyListeners();
  }
}
