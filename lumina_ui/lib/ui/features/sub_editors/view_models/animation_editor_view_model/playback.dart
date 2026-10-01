part of '../animation_editor_view_model.dart';

/// Playback: play/pause, speed, rate, interpolation, clip selection,
/// stepping/seeking, ticking and notify dispatch.
mixin _AnimationEditorPlayback on _AnimationEditorViewModelState {

  @override
  void play() {
    if (_isPlaying) return;
    _isPlaying = true;
    _lastElapsed = null;
    _ticker?.start();
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

  void togglePlay() {
    if (_isPlaying) {
      pause();
    } else {
      play();
    }
  }

  void setLooping(bool loop) {
    _isLooping = loop;
    notifyListeners();
  }

  void setSpeed(double s) {
    _speed = s;
    notifyListeners();
  }

  void setRateScale(double r) {
    _rateScale = r;
    _isDirty = true;
    notifyListeners();
  }

  void setInterpolation(String interp) {
    _interpolation = interp;
    _isDirty = true;
    if (_interpolation == 'Step') {
      seek(_positionSeconds);
    } else {
      notifyListeners();
    }
  }

  void setAdditiveType(String type) {
    _additiveType = type;
    _isDirty = true;
    notifyListeners();
  }

  void setFrameRate(double fps) {
    if (fps > 0) {
      _frameRate = fps;
      if (_authoredClip != null) {
        // Keys stay on their frames; the clip plays faster or slower.
        _authoredClip!.frameRate = fps;
        _authoredChanged();
      }
      _isDirty = true;
      notifyListeners();
    }
  }

  @override
  void selectClip(int index) {
    if (index >= 0 && index < _clips.length) {
      _selectedClip = index;
      _positionSeconds = 0.0;
      _recentlyFiredNotifies.clear();
      _updatePlaybackController();
      notifyListeners();
    }
  }

  void stepFrame(int delta) {
    final frameDuration = 1.0 / _frameRate;
    double newTime;

    if (_interpolation == 'Step') {
      final targetFrame = currentFrame + delta;
      newTime = targetFrame * frameDuration;
    } else {
      newTime = _positionSeconds + delta * frameDuration;
    }

    if (duration > 0) {
      if (newTime < 0.0) {
        newTime = 0.0;
      } else if (newTime > duration) {
        if (_isLooping) {
          newTime = newTime % duration;
        } else {
          newTime = duration;
        }
      }
    } else {
      newTime = 0.0;
    }

    _positionSeconds = newTime;
    _recentlyFiredNotifies.clear();
    _updatePlaybackController();
    notifyListeners();
  }

  void seek(double timeSeconds) {
    double clamped = timeSeconds;
    if (duration > 0) {
      clamped = clamped.clamp(0.0, duration);
    } else {
      clamped = 0.0;
    }

    if (_interpolation == 'Step') {
      final frame = (clamped * _frameRate).round();
      clamped = (frame / _frameRate).clamp(0.0, duration > 0 ? duration : 0.0);
    }

    _positionSeconds = clamped;
    _recentlyFiredNotifies.clear();
    _updatePlaybackController();
    notifyListeners();
  }

  void tickDelta(double dt) {
    if (!_isPlaying || duration <= 0) return;

    final advance = dt * _speed * _rateScale;
    final prevPosition = _positionSeconds;
    double nextPosition = prevPosition + advance;
    bool wrapped = false;

    if (nextPosition >= duration) {
      if (_isLooping) {
        nextPosition = nextPosition % duration;
        wrapped = true;
      } else {
        nextPosition = duration;
        pause();
      }
    }

    _positionSeconds = nextPosition;
    _dispatchNotifies(prevPosition, nextPosition, wrapped);
    _updatePlaybackController();
    notifyListeners();
  }

  void _dispatchNotifies(double prevTime, double newTime, bool wrapped) {
    _recentlyFiredNotifies.clear();
    if (wrapped) {
      _checkInterval(prevTime, duration);
      _checkInterval(-1e-6, newTime);
    } else {
      _checkInterval(prevTime, newTime);
    }
  }

  void _checkInterval(double tStart, double tEnd) {
    final fired = _notifies.where((n) => n.time > tStart && n.time <= tEnd).toList();
    fired.sort((a, b) => a.time.compareTo(b.time));
    for (final n in fired) {
      _recentlyFiredNotifies.add(n);
      EngineLoggerService().log(
        'AnimNotify fired: ${n.name} (${n.type.name}) at ${n.time.toStringAsFixed(3)}s',
        level: 'info',
        source: 'AnimationEditor',
      );
    }
  }

  @override
  void _onTick(Duration elapsed) {
    if (_lastElapsed == null) {
      _lastElapsed = elapsed;
      return;
    }
    final dt = (elapsed - _lastElapsed!).inMicroseconds / 1000000.0;
    _lastElapsed = elapsed;
    tickDelta(dt);
  }

  @override
  void _updatePlaybackController() {
    // A preview that was not keyed lasts until the playhead moves.
    if (_dragBone == null && _pendingPose.isNotEmpty) {
      _pendingPose.clear();
      _authoredChanged();
    }
    playbackController.setPlayback(
      clipIndex: _selectedClip,
      timeSeconds: _positionSeconds,
    );
  }
}
