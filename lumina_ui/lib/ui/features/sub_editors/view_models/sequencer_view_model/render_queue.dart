part of '../sequencer_view_model.dart';

/// The movie render queue: output location, progress and
/// starting/cancelling a render.
mixin _SequencerRenderQueue on _SequencerViewModelState {

  // ---------------------------------------------------------------------------
  // Movie render queue
  // ---------------------------------------------------------------------------

  /// Root of the open project. Explicit when the shell supplies it, otherwise
  /// derived from the asset path by walking up past `contents/`.
  @override
  String get projectDirPath {
    final explicit = _projectDirPath;
    if (explicit != null) return explicit;
    var dir = File(assetPath).parent;
    while (dir.path != dir.parent.path) {
      // Project paths mix `/` and `\` on Windows; split on both.
      if (dir.path.split(RegExp(r'[\\/]')).last == 'contents') {
        return dir.parent.path;
      }
      dir = dir.parent;
    }
    return File(assetPath).parent.path;
  }

  @override
  set projectDirPath(String value) => _projectDirPath = value;

  bool get isRendering => _isRendering;

  /// True when the last [startRender] was refused because the sequence has
  /// unsaved edits — the dialog turns this into a "Save & Render" prompt.
  bool get renderRequiresSave => _renderRequiresSave;
  MovieRenderProgress? get renderProgress => _renderProgress;
  String? get renderMessage => _renderMessage;
  String? get renderError => _renderError;
  Directory? get lastRenderDir => _lastRenderDir;

  /// Default output folder name for the render dialog.
  String defaultRenderOutputName([DateTime? now]) =>
      MovieRenderJob.defaultOutputName(fileBasename, now);

  /// Walks [job] frame by frame through [frameSource], writing a numbered PNG
  /// sequence into the project. Returns true only when the whole range landed
  /// on disk with its manifest.
  Future<bool> startRender(
    MovieRenderJob job, {
    required MovieFrameSource frameSource,
    bool saveFirst = false,
  }) async {
    if (_isRendering) {
      _renderMessage = 'A movie render is already running.';
      notifyListeners();
      return false;
    }
    if (_isDirty) {
      if (!saveFirst) {
        _renderRequiresSave = true;
        _renderMessage = 'Save the sequence before rendering.';
        notifyListeners();
        return false;
      }
      final saved = await save();
      if (!saved) {
        _renderMessage = 'Could not save the sequence — render aborted.';
        notifyListeners();
        return false;
      }
    }

    _renderRequiresSave = false;
    _renderMessage = null;
    _renderError = null;
    _renderProgress = null;
    _isRendering = true;
    _lastRenderDir = job.outputDir;
    if (_isPlaying) pause();
    final token = _renderToken = MovieRenderCancellationToken();
    notifyListeners();

    var completed = false;
    try {
      await for (final p in _renderService.render(job, frameSource: frameSource, token: token)) {
        _renderProgress = p;
        if (p.phase == MovieRenderPhase.completed) completed = true;
        notifyListeners();
      }
      if (completed) {
        EngineLoggerService().log(
          'Rendered ${job.totalFrames} frame(s) to ${job.outputDir.path}',
          level: 'info',
        );
      }
    } catch (e, st) {
      _renderError = e.toString();
      EngineLoggerService().log('Movie render failed: $e\n$st', level: 'error');
    } finally {
      _isRendering = false;
      _renderToken = null;
      // The offscreen job never touches the level, but a scrub before it did:
      // leave the editor exactly as `stop()` would.
      restoreLevel();
      notifyListeners();
    }
    return completed;
  }

  /// Cooperative cancel — the loop stops between frames, never mid-readback.
  void cancelRender() {
    if (!_isRendering) return;
    _renderToken?.cancel();
    _renderMessage = 'Cancelling after the current frame…';
    notifyListeners();
  }
}
