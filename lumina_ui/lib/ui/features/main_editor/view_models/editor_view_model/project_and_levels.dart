part of '../editor_view_model.dart';

/// What happens to the open level's unsaved changes when another level is
/// opened: saved first, dropped, or the switch is called off.
enum UnsavedLevelChoice { save, discard, cancel }

/// Project and level lifecycle: default level scaffolding, asset rescans,
/// new/open/switch level, level import, project settings and source control
/// restores.
mixin _EditorProjectAndLevels on _EditorViewModelState {
  /// Tools → Clear Derived Data Cache: empties the open
  /// project's `DerivedDataCache/` and the in-memory sanitized-GLB memo, so the
  /// next load of every oversized asset rebuilds its texture-budgeted GLB. The
  /// cache logs what it freed to the Output Log.
  @override
  Future<DerivedDataCacheUsage> clearDerivedDataCache() async {
    AssetRepository.clearSanitizedGlbCache();
    try {
      return await DerivedDataCache(projectDirPath).clear();
    } on FileSystemException catch (e) {
      _logger.log('Could not clear the Derived Data Cache at $projectDirPath/${DerivedDataCache.directoryName}: $e',
          level: 'error', source: 'DerivedDataCache');
      return const DerivedDataCacheUsage(0, 0);
    }
  }

  void setProject(LuminaProject proj) {
    _project = proj;
    _ensureDefaultLevelAssets();
    // Editor viewport quality is a per-user preference for this project, so
    // it is restored on open rather than read from the manifest.
    loadQualitySettings();
    notifyListeners();
  }

  Future<void> ensureDefaultLevelAssets() => _ensureDefaultLevelAssets();
  @override
  void refreshAssets() => _refreshAssets();

  Future<void> _ensureDefaultLevelAssets() {
    if (_scaffoldFuture != null) return _scaffoldFuture!;
    _scaffoldFuture = _doEnsureDefaultLevelAssets();
    return _scaffoldFuture!;
  }

  /// Writes [starterLevelActors] into [levelFile]'s `metadata.actors` if the
  /// file has no actor list yet. Returns true when the file was seeded.
  bool _seedLevelFileIfEmpty(File levelFile) {
    if (!levelFile.existsSync()) return false;
    Map<String, dynamic> map;
    try {
      final decoded = jsonDecode(levelFile.readAsStringSync());
      if (decoded is! Map) return false;
      map = Map<String, dynamic>.from(decoded);
    } catch (_) {
      return false;
    }
    final metadata = map['metadata'] is Map
        ? Map<String, dynamic>.from(map['metadata'] as Map)
        : <String, dynamic>{};
    if (metadata['actors'] is List) return false;
    metadata['actors'] = EditorViewModel.starterLevelActors().map((a) => a.toMap()).toList();
    map['metadata'] = metadata;
    levelFile.writeAsStringSync(jsonEncode(map));
    _logger.log(
      'Seeded starter actors into ${levelFile.path}',
      level: 'info',
      source: 'EditorViewModel',
    );
    return true;
  }

  Future<void> _doEnsureDefaultLevelAssets() async {
    try {
      final contentsDir = Directory('$projectDirPath/contents');
      if (!contentsDir.existsSync()) {
        contentsDir.createSync(recursive: true);
      }

      final existing = _assetRepo.scanProjectContents(projectDirPath);
      if (existing.isEmpty) {
        await _assetRepo.createAsset(
          projectPath: projectDirPath,
          subFolder: 'meshes',
          fileName: 'SM_Rock_Basalt.lmas',
          type: AssetType.filamesh,
        );
        await _assetRepo.createAsset(
          projectPath: projectDirPath,
          subFolder: 'materials',
          fileName: 'M_Ground_PBR.lmas',
          type: AssetType.filamat,
          rawMatSource: _newAssetMatSource(AssetType.filamat, 'M_Ground_PBR.lmas'),
        );
        await _assetRepo.createAsset(
          projectPath: projectDirPath,
          subFolder: 'textures',
          fileName: 'T_Ground_Albedo.lmas',
          type: AssetType.texture,
        );
        await _assetRepo.createAsset(
          projectPath: projectDirPath,
          subFolder: 'blueprints',
          fileName: 'BP_CharacterController.lmas',
          type: AssetType.actor,
        );
        await _assetRepo.createAsset(
          projectPath: projectDirPath,
          subFolder: 'levels',
          fileName: '$activeLevelName.lmas',
          type: AssetType.level,
        );
      }

      final levelFile = File(
        '$projectDirPath/contents/levels/$activeLevelName.lmas',
      );
      _seedLevelFileIfEmpty(levelFile);
      if (levelFile.existsSync()) {
        try {
          final content = levelFile.readAsStringSync();
          final map = jsonDecode(content);
          if (map is Map &&
              map['metadata'] != null &&
              map['metadata']['actors'] != null) {
            final rawList = map['metadata']['actors'] as List;
            final loadedActors = <EditorActorNode>[];
            for (final item in rawList) {
              if (item is Map) {
                final node = EditorActorNode.fromMap(
                  Map<String, dynamic>.from(item),
                );
                loadedActors.add(node);
              }
            }
            _sanitizeLoadedActorIds(loadedActors);
            _actors.clear();
            _actors.addAll(loadedActors);
          }
          if (map is Map) _loadLevelEnvironment(map['metadata']);
          if (map is Map) _loadLevelNavigation(map['metadata']);
          if (map is Map) _loadLevelWorldPartition(map['metadata']);
          if (map is Map) _readLevelBlueprintMeta(map['metadata']);
        } catch (e) {
          _logger.log(
            'Failed to read level ${levelFile.path}: $e',
            level: 'error',
            source: 'EditorViewModel',
          );
        }
      }

      for (final actor in List.of(_actors)) {
        if (actor.meshData == null) {
          await _loadActorMeshData(actor);
        }
      }
      // The camera this project was last edited with; a first open frames the
      // level's geometry instead (levels differ in scale, so a fixed default
      // hides some).
      if (!await restoreSavedCamera()) frameLevelBounds();

      _refreshAssets();
    } finally {}
  }

  @override
  void _refreshAssets() {
    _realAssets = _assetRepo.scanProjectContents(projectDirPath);
    _referenceGraph = null;
    // Save/import/delete/move all funnel through here: refresh git badges
    // (single-flight inside the view model, so bursts cost one `git status`).
    sourceControl.refresh();
    // …and queue a thumbnail for every asset that has none or an old one.
    _enqueueStaleThumbnails();
    for (final actor in List.of(_actors)) {
      if (actor.meshData == null) {
        _loadActorMeshData(actor);
      }
    }
    pieController.registerWidgetClasses();
    notifyListeners();
  }

  /// Adopts a manifest saved by the Project Settings editor so the toolbar
  /// scalability state, VSync and every other section share the same truth.
  void applyProjectSettings(LuminaProject saved) {
    final libraryChanged = saved.ui.widgetLibrary != _project.ui.widgetLibrary;
    _project = saved.copyWith(isDirty: false);
    // The applied plugin settings reach the plugins.
    extensionRegistry.publishPluginSettings(saved.pluginSettings);
    // The launcher's ShadcnLayer wrap follows the new widget library.
    if (libraryChanged) unawaited(saveLevelAndGenerateCode());
    _logger.log(
      'Project settings applied: preset ${saved.settings.qualityPreset}, vsync ${saved.settings.vsyncEnabled}, target fps ${saved.settings.targetFps}',
      level: 'info',
      source: 'ProjectSettings',
    );
    _setQuality(
      _quality.copyWith(preset: saved.settings.qualityPreset),
      'Quality preset from Project Settings',
    );
    notifyListeners();
  }

  /// After `Revert File`: re-scan assets and, when the reverted path is the
  /// active level, reload it from disk so in-memory actors match the tree.
  void _onSourceControlFileRestored(String relativePath) {
    if (relativePath == _project.activeLevel) {
      switchLevel(relativePath);
    }
    _refreshAssets();
  }

  /// The project's levels, as File → Open Level lists them and MCP's
  /// `list_levels` returns them: every
  /// `contents/levels/*.lmas`, project-relative, sorted by name.
  @override
  List<String> get levelFiles {
    final dir = Directory('$projectDirPath/contents/levels');
    if (!dir.existsSync()) return const [];
    return [
      for (final f in dir.listSync().whereType<File>())
        if (f.path.endsWith('.lmas')) 'contents/levels/${f.uri.pathSegments.last}',
    ]..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  /// `File → New Level…`: writes a new level `.lmas` seeded from
  /// [templateId] ([LevelTemplateCatalog]) and switches to it.
  ///
  /// The container itself is written by `AssetRepository.createAsset`, which
  /// writes **JSON** — deliberately, because that is what [switchLevel] /
  /// [importLevelData] read back. (The launcher's scaffolder writes protobuf
  /// bytes for the same `.lmas` file type; new levels made here are always the
  /// JSON flavour.) The template's actors and world-partition section are
  /// written into the file *before* switching, because [switchLevel] clears
  /// the in-memory level and reloads it from disk.
  ///
  /// The whole thing is one undoable editor action: undo deletes the file and
  /// returns to the previously active level.
  /// Whether `contents/levels/<levelName>.lmas` already exists; File → New
  /// Level refuses such a name instead of overwriting the level.
  bool levelNameTaken(String levelName) {
    final trimmed = levelName.trim();
    return trimmed.isNotEmpty &&
        File('$projectDirPath/contents/levels/$trimmed.lmas').existsSync();
  }

  /// Creates `contents/levels/<levelName>.lmas` from [templateId] and opens
  /// it. Returns false, touching nothing, for an empty name or a level that
  /// already exists.
  Future<bool> createLevelFromTemplate(
    String levelName,
    String templateId,
  ) async {
    final trimmed = levelName.trim();
    if (trimmed.isEmpty) return false;
    final fileName = '$trimmed.lmas';
    final relativePath = 'contents/levels/$fileName';
    final previousLevel = _project.activeLevel;
    final template = LevelTemplateCatalog.byId(templateId);

    if (!await createNewAssetOnDisk('levels', fileName, AssetType.level)) {
      return false;
    }

    final file = File('$projectDirPath/$relativePath');
    var seededJson = '';
    try {
      final decoded = jsonDecode(file.readAsStringSync());
      final map = decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : <String, dynamic>{};
      final metadata = map['metadata'] is Map
          ? Map<String, dynamic>.from(map['metadata'] as Map)
          : <String, dynamic>{};
      final seededActors = template.levelActors;
      // `Empty` really is empty: it must not even carry an `actors` key, or
      // the lazy starter-seeding would never fire for it later.
      if (seededActors.isNotEmpty) metadata['actors'] = seededActors;
      final partition = template.worldPartition;
      if (partition != null) metadata['worldPartition'] = partition;
      map['metadata'] = metadata;
      seededJson = jsonEncode(map);
      file.writeAsStringSync(seededJson);
    } catch (e) {
      _logger.log(
        'Failed to seed new level ${file.path}: $e',
        level: 'error',
        source: 'EditorViewModel',
      );
    }

    switchLevel(relativePath, keepHistory: true);
    _refreshAssets();
    _logger.log(
      'Created level "$fileName" from the ${template.title} template '
      '(${template.levelActors.length} actors'
      '${template.worldPartition != null ? ', world partition enabled' : ''}).',
      level: 'success',
      source: 'EditorViewModel',
    );

    final redoJson = seededJson;
    transactions.record(
      EditorTransaction(
        label: 'New Level $trimmed',
        undo: () {
          if (file.existsSync()) file.deleteSync();
          _refreshAssets();
          switchLevel(previousLevel, keepHistory: true);
        },
        redo: () {
          file.parent.createSync(recursive: true);
          file.writeAsStringSync(redoJson);
          _refreshAssets();
          switchLevel(relativePath, keepHistory: true);
        },
      ),
    );
    return true;
  }

  /// Whether the open level may be left. A clean level always may.
  /// A dirty one asks Save / Don't Save / Cancel over [context]; with no
  /// [context] (MCP, plugins) it takes [ifDirty], and without that it refuses
  /// rather than drop unsaved work.
  @override
  Future<bool> confirmLeavingLevel({BuildContext? context, UnsavedLevelChoice? ifDirty}) async {
    if (!_project.isDirty) return true;
    var choice = ifDirty;
    if (choice == null && context != null && context.mounted) {
      choice = await _askUnsavedLevel(context);
    }
    switch (choice) {
      case UnsavedLevelChoice.save:
        await saveLevelAndGenerateCode();
        return true;
      case UnsavedLevelChoice.discard:
        return true;
      case UnsavedLevelChoice.cancel:
      case null:
        _logger.log(
          '${_project.activeLevel.split('/').last} has unsaved changes; it stays open.',
          level: 'warning',
          source: 'EditorViewModel',
        );
        return false;
    }
  }

  /// Opens [levelRelativePath] after [confirmLeavingLevel]: every user-facing
  /// "open this level" goes through here; [switchLevel] is the unguarded
  /// primitive. Returns whether the level was opened.
  @override
  Future<bool> openLevelGuarded(
    String levelRelativePath, {
    BuildContext? context,
    UnsavedLevelChoice? ifDirty,
  }) {
    if (levelRelativePath == _project.activeLevel) return Future.value(true);
    // A clean level switches at once, synchronously.
    if (!_project.isDirty) {
      switchLevel(levelRelativePath);
      return Future.value(true);
    }
    return confirmLeavingLevel(context: context, ifDirty: ifDirty).then((ok) {
      if (ok) switchLevel(levelRelativePath);
      return ok;
    });
  }

  Future<UnsavedLevelChoice> _askUnsavedLevel(BuildContext context) async {
    final level = _project.activeLevel.split('/').last.replaceAll('.lmas', '');
    final choice = await showOverlay<UnsavedLevelChoice>(
      context,
      const DialogConfiguration(),
      builder: (ctx) => AlertDialog(
        key: const ValueKey('unsaved_level_prompt'),
        title: const Text('Save Level?'),
        content: Text('$level has unsaved changes. Save them before opening another level?'),
        actions: [
          OutlineButton(
            key: const ValueKey('unsaved_level_prompt_cancel'),
            onPressed: () => Navigator.of(ctx).pop(UnsavedLevelChoice.cancel),
            child: const Text('Cancel'),
          ),
          OutlineButton(
            key: const ValueKey('unsaved_level_prompt_discard'),
            onPressed: () => Navigator.of(ctx).pop(UnsavedLevelChoice.discard),
            child: const Text("Don't Save"),
          ),
          PrimaryButton(
            key: const ValueKey('unsaved_level_prompt_save'),
            onPressed: () => Navigator.of(ctx).pop(UnsavedLevelChoice.save),
            child: const Text('Save'),
          ),
        ],
      ),
    ).future;
    return choice ?? UnsavedLevelChoice.cancel;
  }

  @override
  /// Loads [levelRelativePath] from disk as the open level. The previous
  /// level's undo history ends here: its steps capture that
  /// level's actors. Only New Level's own switch, whose undo returns to the
  /// previous level, passes [keepHistory].
  void switchLevel(String levelRelativePath, {bool keepHistory = false}) {
    // The previous level's Blueprint tab closes (saved
    // into its own level, or discarded, as the user answers).
    _closeLevelBlueprintsExcept(levelRelativePath);
    if (!keepHistory && !transactions.isApplying) transactions.clear();
    // The level just loaded from disk has no unsaved changes.
    _project = _project.copyWith(activeLevel: levelRelativePath, isDirty: false);
    _projectRepo.saveProject(_project, projectDirPath);

    _actors.clear();
    _selectedActor = null;
    _levelEnvironment = {};
    _levelNavigation = {};
    _levelWorldPartition = {};
    _levelBlueprintMeta = null;

    final levelFile = File('$projectDirPath/$levelRelativePath');
    if (levelFile.existsSync()) {
      try {
        final content = levelFile.readAsStringSync();
        importLevelData(content);
      } catch (e) {
        _logger.log('Failed to load level data: $e', level: 'error');
      }
    }

    for (final actor in List.of(_actors)) {
      if (actor.meshData == null) {
        _loadActorMeshData(actor);
      }
    }

    _logger.log(
      'Switched to level: $levelRelativePath',
      level: 'info',
      source: 'EditorViewModel',
    );
    notifyListeners();
  }

  void importLevelData(String content) {
    importLevelDataFromJson(jsonDecode(content));
  }

  void importLevelDataFromJson(dynamic map) {
    if (map is! Map) return;
    if (map['metadata'] != null && map['metadata']['actors'] != null) {
      final rawList = map['metadata']['actors'] as List;
      final loadedActors = <EditorActorNode>[];
      for (final item in rawList) {
        if (item is Map) {
          final node = EditorActorNode.fromMap(Map<String, dynamic>.from(item));
          loadedActors.add(node);
        }
      }
      _sanitizeLoadedActorIds(loadedActors);
      if (loadedActors.isNotEmpty) {
        _actors.clear();
        _actors.addAll(loadedActors);
      }
    }
    // The level's own settings sections load whether or not the level has
    // actors — an Open World level can legitimately author a partition before
    // anything is placed in it.
    _loadLevelEnvironment(map['metadata']);
    _loadLevelNavigation(map['metadata']);
    _loadLevelWorldPartition(map['metadata']);
    _readLevelBlueprintMeta(map['metadata']);
  }

  /// Ensures every loaded actor has a unique ID. If historical duplicate IDs exist
  /// (e.g. from prior spawner collisions), folders keep the ID so hierarchy remains
  /// intact, while duplicates are reassigned unique IDs.
  void _sanitizeLoadedActorIds(List<EditorActorNode> actors) {
    if (actors.length <= 1) return;

    final actorsById = <String, List<EditorActorNode>>{};
    for (final a in actors) {
      actorsById.putIfAbsent(a.id, () => []).add(a);
    }

    final hasDuplicates = actorsById.values.any((list) => list.length > 1);
    if (!hasDuplicates) return;

    final allIds = <String>{for (final a in actors) a.id};
    var nextIndex = 1;
    var reassignedAny = false;

    for (final entry in actorsById.entries) {
      final list = entry.value;
      if (list.length <= 1) continue;

      // When multiple actors share an ID, choose which one retains the ID:
      // 1. A 'Folder' keeps the ID so its grouped children stay attached.
      // 2. Otherwise, the earliest actor in the list keeps the ID.
      EditorActorNode keeper = list.first;
      var bestScore = -1;
      for (var i = 0; i < list.length; i++) {
        final candidate = list[i];
        var score = list.length - i;
        if (candidate.type == 'Folder') {
          score += 100;
        }
        if (score > bestScore) {
          bestScore = score;
          keeper = candidate;
        }
      }

      for (final node in list) {
        if (identical(node, keeper)) continue;

        while (allIds.contains('act_$nextIndex')) {
          nextIndex++;
        }
        final newId = 'act_$nextIndex';
        allIds.add(newId);

        final idx = actors.indexOf(node);
        if (idx != -1) {
          actors[idx] = node.copy(id: newId);
        }
        reassignedAny = true;
      }
    }

    if (reassignedAny) {
      _logger.log(
        'Sanitized duplicate actor IDs in loaded level.',
        level: 'warning',
        source: 'EditorViewModel',
      );
      _markDirty();
    }
  }
}
