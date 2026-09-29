part of '../editor_view_model.dart';

/// The Content Browser thumbnail queue.
///
/// Every asset whose thumbnail is missing or older than the asset is queued
/// whenever the asset list is rescanned (project open, import, level save,
/// create/move/delete) and whenever a sub-editor bound to a tab saves. The
/// queue renders one asset at a time through lumina's ThumbnailService —
/// Filament for meshes, materials, levels and Blueprints — and each tile
/// updates as its thumbnail lands.
mixin _EditorThumbnails on _EditorViewModelState {
  int get thumbnailQueueLength => _thumbnailQueue.length;
  String? get currentThumbnailJob =>
      _thumbnailQueue.isNotEmpty ? _thumbnailQueue.first.split('/').last : null;
  double? get thumbnailQueueProgress => _thumbnailTotal == 0
      ? null
      : (_thumbnailTotal - _thumbnailQueue.length) / _thumbnailTotal;

  /// The `.lmas` paths waiting for a thumbnail, the one in progress first.
  List<String> get pendingThumbnails => List.unmodifiable(_thumbnailQueue);

  /// Completes once the thumbnail queue has nothing left to render.
  Future<void> get thumbnailQueueIdle {
    if (!_isProcessingThumbnails && _thumbnailQueue.isEmpty) return Future.value();
    return (_thumbnailIdle ??= Completer<void>()).future;
  }

  void enqueueThumbnail(String lmasPath, {bool force = false}) {
    if (_disposed) return;
    if (force) _forcedThumbnails.add(lmasPath);
    if (!_thumbnailQueue.contains(lmasPath)) {
      _thumbnailQueue.add(lmasPath);
      // Counts every job since the queue was last empty (it resets to 0
      // then), so progress is done / total.
      _thumbnailTotal++;
      notifyListeners();
      _processThumbnailQueue();
    }
  }

  /// Queues a thumbnail for each of [lmasPaths] that is missing or stale
  /// and completes once none of them is waiting any more (e.g.
  /// a batch import's `thumbnail` stage).
  @override
  Future<void> thumbnailsFor(Iterable<RealAssetInfo> assets) {
    if (!_autoThumbnails || _disposed) return Future.value();
    final waits = <Future<void>>[];
    for (final asset in assets) {
      final path = asset.lmasPath;
      if (path == null || !ThumbnailService.isStaleInfo(asset)) continue;
      final waiter = Completer<void>();
      (_thumbnailWaiters[path] ??= []).add(waiter);
      waits.add(waiter.future);
      enqueueThumbnail(path);
    }
    return Future.wait(waits);
  }

  /// Renders [lmasPath]'s thumbnail again even when it is current (the
  /// Content Browser's "Regenerate Thumbnail").
  void regenerateThumbnail(String lmasPath) => enqueueThumbnail(lmasPath, force: true);

  /// Queues every scanned asset whose thumbnail is missing or stale.
  @override
  void _enqueueStaleThumbnails() {
    if (!_autoThumbnails || _disposed) return;
    for (final asset in _realAssets) {
      final path = asset.lmasPath;
      if (path == null || _thumbnailQueue.contains(path)) continue;
      if (ThumbnailService.isStaleInfo(asset)) enqueueThumbnail(path);
    }
  }

  /// A sub-editor bound to [tabId] changed; when its asset was saved after its
  /// thumbnail (a few `stat`s, no read), queue a new one.
  @override
  void _thumbnailAfterSubEditorChange(String tabId) {
    if (!_autoThumbnails || _disposed) return;
    final tab = _openTabs.where((t) => t.id == tabId).firstOrNull;
    final path = tab?.asset?.lmasPath;
    if (path == null || _thumbnailQueue.contains(path)) return;
    final info = _realAssets.where((a) => a.lmasPath == path).firstOrNull ?? tab!.asset!;
    if (ThumbnailService.isStaleInfo(info)) enqueueThumbnail(path);
  }

  /// The thumbnail renderer lights with the editor's bundled studio IBL.
  Future<void> _ensureThumbnailEnvironment() async {
    if (_thumbnailEnvironmentReady) return;
    _thumbnailEnvironmentReady = true;
    final renderer = _thumbnailService.renderer;
    if (renderer.environmentIbl != null) return;
    try {
      renderer.environmentIbl = await EditorSceneEnvironment.ensureAssetsLoaded();
    } catch (_) {
      // No bundle (plain Dart tests): the renderer keeps its ambient light.
    }
  }

  Future<void> _processThumbnailQueue() async {
    if (_isProcessingThumbnails) return;
    _isProcessingThumbnails = true;

    try {
      await _ensureThumbnailEnvironment();
      while (_thumbnailQueue.isNotEmpty && !_disposed) {
        final lmasPath = _thumbnailQueue.first;
        notifyListeners(); // Update current job
        final force = _forcedThumbnails.remove(lmasPath);

        try {
          final result = await _thumbnailService.generate(lmasPath, force: force);
          if (result != null && !_disposed) {
            _applyThumbnail(lmasPath, result);
          }
        } catch (e) {
          _logger.log(
            'Thumbnail failed for ${lmasPath.split('/').last}: $e',
            level: 'warning',
            source: 'Thumbnails',
          );
        }

        _thumbnailQueue.remove(lmasPath);
        for (final waiter in _thumbnailWaiters.remove(lmasPath) ?? const <Completer<void>>[]) {
          if (!waiter.isCompleted) waiter.complete();
        }
        if (_thumbnailQueue.isEmpty) {
          _thumbnailTotal = 0;
        }
        if (_disposed) break;
        notifyListeners();

        // Let the UI take a frame between thumbnails.
        await Future<void>.delayed(Duration.zero);
      }
    } finally {
      _isProcessingThumbnails = false;
      final idle = _thumbnailIdle;
      _thumbnailIdle = null;
      if (idle != null && !idle.isCompleted) idle.complete();
      if (!_disposed) notifyListeners();
    }
  }

  /// Puts a freshly rendered thumbnail on its tile without rescanning the
  /// project.
  void _applyThumbnail(String lmasPath, ThumbnailResult result) {
    final index = _realAssets.indexWhere((a) => a.lmasPath == lmasPath);
    if (index == -1) return;
    final old = _realAssets[index];
    final file = File(lmasPath);
    _realAssets = List.of(_realAssets)
      ..[index] = RealAssetInfo(
        fileName: old.fileName,
        relativePath: old.relativePath,
        type: old.type,
        bytes: file.existsSync() ? file.lengthSync() : old.bytes,
        thumbnailBytes: result.png,
        thumbnailSource: result.source,
        lmasPath: old.lmasPath,
        assetId: old.assetId,
        references: old.references,
        lastModified: file.existsSync() ? file.lastModifiedSync() : old.lastModified,
      );
  }

  /// Whether thumbnails are generated in the background (off in tests that
  /// build the editor with `enableTimers: false`).
  bool get autoGeneratesThumbnails => _autoThumbnails;

  /// An asset picker row shows an asset with no thumbnail: queue one, when
  /// background thumbnails are on.
  void requestAssetThumbnail(RealAssetInfo asset) {
    final path = asset.lmasPath;
    if (!_autoThumbnails || path == null || _thumbnailQueue.contains(path)) return;
    enqueueThumbnail(path);
  }
}
