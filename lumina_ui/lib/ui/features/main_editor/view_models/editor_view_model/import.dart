part of '../editor_view_model.dart';

/// Asset import: the single-file pipeline and the background import queue.
mixin _EditorImport on _EditorViewModelState {
  bool get isImporting => _isImporting || (_importJobs?.isRunning ?? false);
  String get importStatusMessage =>
      (_importJobs?.isRunning ?? false) ? _importJobs!.headline : _importStatusMessage;
  double? get importProgress => (_importJobs?.isRunning ?? false) ? _importJobs!.overallFraction : _importProgress;

  /// Runs the 4-step import. An `.fbx` is converted natively into standard
  /// glTF first; an animation it holds is retargeted
  /// onto [targetSkeletonPath] (a project skeletal mesh `.lmas`, relative),
  /// onto the best bone-name match when null, or left unbound when `''`.
  Future<void> processImportPipeline({
    required String sourceFilePath,
    String? targetSubFolder,
    bool autoOrganizeFiles = true,
    bool generateLods = false,
    String? targetSkeletonPath,
    List<String> textureSearchDirs = const [],
  }) async {
    final sourceFile = File(sourceFilePath);
    final baseFileName = sourceFile.existsSync()
        ? sourceFile.uri.pathSegments.last
        : 'Asset';

    _isImporting = true;
    _importStatusMessage = 'Importing "$baseFileName"...';
    _importProgress = 0.1;
    notifyListeners();

    try {
      _logger.log(
        '--- START IMPORT PIPELINE ---',
        level: 'info',
        source: 'ImportPipeline',
      );

      // STEP 1: Pre-processing & Temp Copy
      _importStatusMessage = 'Staging "$baseFileName"...';
      _importProgress = 0.25;
      notifyListeners();

      final staged = await _assetRepo.stageImport(
        projectPath: projectDirPath,
        sourceFilePath: sourceFilePath,
        generateLods: generateLods,
        textureSearchDirs: textureSearchDirs,
      );

      final stagedPath = staged['stagedPath'] as String;
      final detectedKind = staged['detectedKind'] as String;
      AssetType type;
      if (detectedKind == 'static mesh') {
        type = AssetType.filamesh;
      } else if (detectedKind == 'skeletal mesh') {
        type = AssetType.filameshSk;
      } else if (detectedKind == 'animation') {
        type = AssetType.animation;
      } else if (detectedKind == 'texture') {
        type = AssetType.texture;
      } else if (detectedKind == 'audio') {
        type = AssetType.audio;
      } else if (detectedKind == 'material') {
        type = AssetType.filamat;
      } else {
        type = AssetType.filamesh;
      }

      // STEP 2: Conversion
      _importStatusMessage = 'Converting "$baseFileName"...';
      _importProgress = 0.50;
      notifyListeners();

      final converted = await _assetRepo.convertStagedAsset(
        projectPath: projectDirPath,
        stagedFilePath: stagedPath,
        detectedType: type,
        targetSkeletonPath: targetSkeletonPath,
      );

      // STEP 3: Auto Organize / Target Paths
      _importStatusMessage = 'Resolving paths...';
      _importProgress = 0.75;
      notifyListeners();

      final baseName = converted['baseName'] as String;
      final List<String> extractedSubs = [];
      final materials = converted['materials'] as List;
      final textures = converted['textures'] as List;
      final animations = converted['animations'] as List? ?? [];
      for (final m in materials) {
        extractedSubs.add(m['name'] as String);
      }
      for (final t in textures) {
        extractedSubs.add(t['name'] as String);
      }
      for (final a in animations) {
        extractedSubs.add(a['name'] as String);
      }

      final targetPaths = _assetRepo.resolveTargetPaths(
        projectPath: projectDirPath,
        baseName: baseName,
        primaryType: type,
        autoOrganize: autoOrganizeFiles,
        browserSelectedFolder: targetSubFolder,
        extractedSubAssets: extractedSubs,
      );

      // STEP 4: Emit Asset Family
      _importStatusMessage = 'Emitting asset family...';
      _importProgress = 0.90;
      notifyListeners();

      await _assetRepo.emitAssetFamily(
        targetPaths: targetPaths,
        convertedData: converted,
      );

      // Cleanup temp
      try {
        File(stagedPath).deleteSync();
      } catch (_) {}

      _logger.log(
        '--- IMPORT PIPELINE COMPLETE ---',
        level: 'success',
        source: 'ImportPipeline',
      );

      _importStatusMessage = 'Import completed successfully!';
      _importProgress = 1.0;
      notifyListeners();
    } catch (e) {
      _logger.log(
        'Import failed with exception: $e',
        level: 'error',
        source: 'ImportPipeline',
      );
    } finally {
      await Future.delayed(const Duration(milliseconds: 300));
      _isImporting = false;
      _importStatusMessage = '';
      _importProgress = null;
      _refreshAssets();
    }
  }

  Future<void> importAssetFile(
    String filePath, {
    String? targetSubFolder,
  }) async {
    await importAssetFileAndReturn(filePath, targetSubFolder: targetSubFolder);
  }

  /// Imports one file through the background import queue and returns the
  /// imported asset, or null when the import failed (the failure is logged
  /// to the output log). A thin wrapper over [importAssetFiles] for plugins
  /// and MCP tools.
  Future<RealAssetInfo?> importAssetFileAndReturn(
    String filePath, {
    String? targetSubFolder,
  }) async {
    final results = await importAssetFiles([filePath], targetSubFolder: targetSubFolder, autoOrganize: true);
    return results.single.result;
  }

  /// The editor's import queue (created on first use).
  @override
  ImportQueue get importQueue => _importQueue ??= ImportQueue(
        projectPath: projectDirPath,
        workers: editorPreferences.importWorkers,
        thumbnailStep: (written) => thumbnailsFor(written.assets),
      );

  /// The import progress panel's state.
  @override
  ImportJobsViewModel get importJobs => _importJobs ??= ImportJobsViewModel(
        importQueue,
        onAssetsLanded: _onImportedAssets,
        onBatchFinished: (_) {
          if (_disposed) return;
          sourceControl.refresh();
          notifyListeners();
        },
      )..addListener(_notifyWhileImporting);

  /// Whether a batch import is running.
  @override
  bool get isBatchImporting => _importJobs?.isRunning ?? false;

  /// Queues [paths] for import and returns at once (the dialog closes, the
  /// editor stays usable). The future completes with each file's final
  /// state once all of them are done.
  Future<List<ImportProgress>> importAssetFiles(
    List<String> paths, {
    String? targetSubFolder,
    bool autoOrganize = true,
    bool generateLods = false,
    String? targetSkeletonPath,
    List<String> textureSearchDirs = const [],
  }) {
    return importRequests([
      for (final path in paths)
        ImportRequest(
          sourcePath: path,
          targetSubFolder: targetSubFolder,
          autoOrganize: autoOrganize,
          generateLods: generateLods,
          targetSkeletonPath: targetSkeletonPath,
          textureSearchDirs: textureSearchDirs,
        ),
    ]);
  }

  /// [importAssetFiles] with one request per file (its own target folder
  /// and name, as a folder import needs).
  Future<List<ImportProgress>> importRequests(List<ImportRequest> requests) {
    importJobs; // the panel follows the queue from its first event
    importQueue.workers = editorPreferences.importWorkers;
    return importQueue.enqueue(requests);
  }

  /// Imports every file of [scan] under [options]:
  /// mirrored into the target folder (or auto-organized), the conflict
  /// policy applied, on the background queue. The Content Browser shows the
  /// target folder, which fills as files land. Completes when all are done.
  Future<List<ImportProgress>> importAssetFolder(ImportFolderScan scan, ImportFolderOptions options) {
    final plan = ImportFolderPlan.build(scan, projectPath: projectDirPath, options: options);
    final target = ImportFolderPlan.normalizeFolder(options.targetFolder);
    _logger.log(
      'Import Asset Folder: ${plan.imports.length} of ${scan.files.length} files from ${scan.root} → '
      '${options.autoOrganize ? 'auto-organized folders' : target}'
      '${plan.skippedExisting.isEmpty ? '' : ' (${plan.skippedExisting.length} already imported, skipped)'}'
      '${scan.skipped.isEmpty ? '' : ' · ${scan.skipped.length} unsupported file(s) left out'}',
      level: 'info',
      source: 'ContentBrowser',
    );
    for (final s in scan.skipped) {
      _logger.log('Import Asset Folder skipped ${s.relativePath}: ${s.reason}', level: 'warning', source: 'ContentBrowser');
    }
    if (!options.autoOrganize) {
      final dir = Directory('$projectDirPath/$target')..createSync(recursive: true);
      ContentFolders.writeMarker(dir.path);
      _showRecentlyModified = false;
      _activeCollection = null;
      selectedFolder = target;
    }
    if (plan.imports.isEmpty) {
      notifyListeners();
      return Future.value(const <ImportProgress>[]);
    }
    return importRequests(plan.requests);
  }

  /// Stops the running batch after the files in progress.
  @override
  void cancelImports() => _importJobs?.cancel();

  /// Opens the Output Log showing errors only (the import panel's "Show
  /// errors").
  void showImportErrors() {
    outputLogFilter.value = 'error';
    layoutState.bottomVisible = true;
    layoutState.activeBottomTab = EditorLayoutState.outputLogTab;
    saveLayoutState();
  }

  /// Puts a landed file's assets on the Content Browser without a rescan.
  void _onImportedAssets(List<RealAssetInfo> assets) {
    if (_disposed || assets.isEmpty) return;
    final byPath = {for (final a in assets) a.lmasPath ?? a.relativePath: a};
    _realAssets = [
      for (final a in _realAssets)
        if (!byPath.containsKey(a.lmasPath ?? a.relativePath)) a,
      ...assets,
    ];
    _referenceGraph = null;
    notifyListeners();
  }

  void _notifyWhileImporting() {
    // The editor chrome shows the batch's headline; one rebuild per file.
    final finished = _importJobs?.finished ?? 0;
    if (finished == _lastImportNotice) return;
    _lastImportNotice = finished;
    if (!_disposed) notifyListeners();
  }
}
