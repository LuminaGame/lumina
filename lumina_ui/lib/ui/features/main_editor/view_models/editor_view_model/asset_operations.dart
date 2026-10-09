part of '../editor_view_model.dart';

/// Content Browser asset operations: the reference graph, rename, move,
/// duplicate, size/references/migrate, new assets, and deletes that clean the
/// open level of actors using the deleted assets.
mixin _EditorAssetOperations on _EditorViewModelState, _EditorAssetsAndContentBrowser {
  AssetReferenceGraph get referenceGraph {
    if (_referenceGraph == null) {
      _referenceGraph = AssetReferenceGraph();
      _referenceGraph!.build(_realAssets);
    }
    return _referenceGraph!;
  }

  static final _assetNamePattern = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$');

  /// Content Browser → Rename. Renames the `.lmas` and its
  /// companion files, heals the assets that reference it, and re-points the
  /// open level (its actors' asset paths and, for a level, `activeLevel`).
  /// Returns null on success, or why the name was refused.
  String? renameAsset(String absolutePath, String newName) {
    final name = newName.trim();
    if (!_assetNamePattern.hasMatch(name)) {
      return 'Use letters, digits and underscores, not starting with a digit.';
    }
    final file = File(absolutePath);
    final newPath = '${file.parent.path}/$name.lmas';
    if (newPath == absolutePath) return null;
    if (File(newPath).existsSync()) return 'An asset named $name already exists in this folder.';
    try {
      _assetRepo.renameAsset(projectDirPath, absolutePath, name, referenceGraph);
    } catch (e) {
      return 'Could not rename: $e';
    }
    _retargetAssetPath(absolutePath, newPath);
    _logger.log('Renamed ${file.uri.pathSegments.last} to $name.lmas', level: 'info', source: 'ContentBrowser');
    refreshAssets();
    return null;
  }

  /// Re-points every reference the open level holds to [oldPath] at
  /// [newPath], keeping each reference's absolute or project-relative form.
  void _retargetAssetPath(String oldPath, String newPath) {
    final oldRel = _projectRelativeRef(oldPath);
    final newRel = _projectRelativeRef(newPath);
    String? moved(String? ref) {
      if (ref == null || ref.isEmpty || _projectRelativeRef(ref) != oldRel) return null;
      // `p.isAbsolute`, not `startsWith('/')` — `C:\…` is absolute too.
      return p.isAbsolute(ref) ? '$projectDirPath/$newRel' : newRel;
    }

    var changed = false;
    for (final actor in _actors) {
      final mesh = moved(actor.meshAssetPath);
      if (mesh != null) {
        actor.meshAssetPath = mesh;
        changed = true;
      }
      final bp = moved(actor.blueprintClass);
      if (bp != null) {
        actor.blueprintClass = bp;
        changed = true;
      }
      final mat = moved(actor.materialPath);
      if (mat != null) {
        actor.materialPath = mat;
        changed = true;
      }
      for (final c in actor.components) {
        for (final key in c.properties.keys.toList()) {
          final value = c.properties[key];
          final to = value is String ? moved(value) : null;
          if (to != null) {
            c.properties[key] = to;
            changed = true;
          }
        }
      }
    }
    if (_project.activeLevel == oldRel) {
      _project = _project.copyWith(activeLevel: newRel);
      _projectRepo.saveProject(_project, projectDirPath);
    }
    if (changed) {
      _markDirty();
      notifyListeners();
    }
  }

  void moveAsset(String absolutePath, String targetFolder) {
    _assetRepo.moveAsset(
      projectDirPath,
      absolutePath,
      targetFolder,
      referenceGraph,
    );
    refreshAssets();
  }

  void duplicateAsset(String absolutePath) {
    _assetRepo.duplicateAsset(absolutePath);
    refreshAssets();
  }

  Map<String, int> sizeInfo(String absolutePath) {
    return _assetRepo.sizeInfo(projectDirPath, absolutePath, referenceGraph);
  }

  List<RealAssetInfo> referencersOf(String assetId) {
    return referenceGraph.referencersOf(assetId);
  }

  List<RealAssetInfo> dependenciesOf(String assetId) {
    return referenceGraph.dependenciesOf(assetId);
  }

  /// Migrate…: the files [absolutePath]'s dependency closure would
  /// copy into [targetProjectPath], each marked when the target has it.
  List<AssetMigrateEntry> migratePreview(String absolutePath, String targetProjectPath) =>
      _assetRepo.migratePreview(projectDirPath, absolutePath, targetProjectPath, referenceGraph);

  /// Copies the closure into [targetProjectPath] (conflicts skipped, never
  /// overwritten) and logs the result.
  List<AssetMigrateEntry> migrateAsset(String absolutePath, String targetProjectPath) {
    final report = _assetRepo.migrateAsset(projectDirPath, absolutePath, targetProjectPath, referenceGraph);
    final copied = report.where((e) => e.copied).length;
    final skipped = report.where((e) => e.conflict).length;
    _logger.log('Migrated ${File(absolutePath).uri.pathSegments.last} to $targetProjectPath: '
        '$copied copied, $skipped skipped (already there)',
        level: skipped == 0 ? 'success' : 'warning', source: 'ContentBrowser');
    return report;
  }

  @override
  Future<void> createNewAsset({
    required AssetType type,
    required String subFolder,
  }) async {
    // The asset count is not a free name once an asset has been
    // deleted, so step past every name already on disk.
    var count = _realAssets.length + 1;
    while (File('$projectDirPath/contents/$subFolder/NewAsset_$count.lmas').existsSync()) {
      count++;
    }
    await createNewAssetOnDisk(subFolder, 'NewAsset_$count.lmas', type);
    _logger.log(
      'Created asset "NewAsset_$count.lmas" under contents/$subFolder/',
      level: 'success',
      source: 'ContentBrowser',
    );
  }

  /// Writes a new `.lmas` under `contents/<subFolder>/`. Never replaces a
  /// file that is already there: returns false and writes nothing.
  @override
  Future<bool> createNewAssetOnDisk(
    String subFolder,
    String fileName,
    AssetType type,
  ) async {
    if (File('$projectDirPath/contents/$subFolder/$fileName').existsSync()) {
      _logger.log(
        'Not creating contents/$subFolder/$fileName: a file with that name already exists.',
        level: 'warning',
        source: 'ContentBrowser',
      );
      return false;
    }
    await _assetRepo.createAsset(
      projectPath: projectDirPath,
      subFolder: subFolder,
      fileName: fileName,
      type: type,
      rawMatSource: _newAssetMatSource(type, fileName),
    );
    _refreshAssets();
    return true;
  }

  Future<void> createCustomAsset({
    required String customTypeId,
    required String displayName,
    String? subFolder,
  }) async {
    final folder = subFolder ?? customTypeId.split('.').first;
    final dir = Directory('$projectDirPath/contents/$folder');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    var count = 1;
    final safeName = displayName.replaceAll(' ', '_');
    while (File('${dir.path}/${safeName}_$count.lmas').existsSync()) {
      count++;
    }
    final fileName = '${safeName}_$count.lmas';
    final lmasFile = File('${dir.path}/$fileName');
    final asset = LuminaAsset(
      assetId: fileName.replaceAll('.', '_'),
      name: '${safeName}_$count',
      type: AssetType.unknown,
      metadata: {
        'custom_type': customTypeId,
        kAssetPathMetadataKey: lmasFile.path,
      },
    );
    await lmasFile.writeAsString(jsonEncode(asset.toMap()));
    _logger.log(
      'Created $displayName asset "$fileName" under contents/$folder/',
      level: 'success',
      source: 'ContentBrowser',
    );
    _refreshAssets();
    final relativePath = 'contents/$folder/$fileName';
    openAssetEditorByPath(relativePath);
  }

  Future<List<EditorActorNode>> deleteAsset(RealAssetInfo asset) =>
      deleteAssetCascadeAndCleanScene(asset);

  Future<void> moveAssetToFolder(
    RealAssetInfo asset,
    String targetSubFolder,
  ) async {
    final oldRelPath = asset.relativePath;
    final fileName = asset.fileName;
    final destDir = Directory('$projectDirPath/$targetSubFolder');
    if (!destDir.existsSync()) {
      destDir.createSync(recursive: true);
    }
    final newRelPath = '$targetSubFolder/$fileName';
    final oldFile = File('$projectDirPath/$oldRelPath');
    final newFile = File('$projectDirPath/$newRelPath');

    if (oldFile.existsSync()) {
      oldFile.renameSync(newFile.path);
    }

    if (asset.lmasPath != null) {
      final lmasFile = File(asset.lmasPath!);
      if (lmasFile.existsSync()) {
        final lmasName = lmasFile.uri.pathSegments.last;
        final newLmasFile = File('${destDir.path}/$lmasName');
        lmasFile.renameSync(newLmasFile.path);
      }
    }

    _updateReferencePathsInProject(oldRelPath, newRelPath);
    // The open level's actors follow the asset, as after Rename.
    _retargetAssetPath('$projectDirPath/$oldRelPath', '$projectDirPath/$newRelPath');
    _logger.log(
      'Moved asset "$fileName" to $targetSubFolder/',
      level: 'info',
      source: 'ContentBrowser',
    );
    _refreshAssets();
  }

  @override
  void _updateReferencePathsInProject(String oldPath, String newPath) {
    final contentsDir = Directory('$projectDirPath/contents');
    if (contentsDir.existsSync()) {
      contentsDir.listSync(recursive: true).whereType<File>().forEach((file) {
        if (file.path.endsWith('.lmas') || file.path.endsWith('.json')) {
          try {
            final content = file.readAsStringSync();
            if (content.contains(oldPath)) {
              file.writeAsStringSync(content.replaceAll(oldPath, newPath));
            }
          } catch (_) {}
        }
      });
    }
  }

  Future<List<EditorActorNode>> deleteAssetCascadeAndCleanScene(
    RealAssetInfo asset, {
    List<RealAssetInfo>? cascadeAssets,
  }) {
    return deleteMultipleAssetsCascadeAndCleanScene([
      asset,
    ], cascadeAssets: cascadeAssets);
  }

  /// The level actors that reference any of [assets]: a placed mesh
  /// (`meshAssetPath`), a Blueprint instance (`blueprintClass`), a material
  /// override, or any component property holding the asset's path. Matching
  /// is by path, never by actor name.
  @override
  List<EditorActorNode> actorsReferencingAssets(Iterable<RealAssetInfo> assets) {
    final targets = <String>{};
    for (final a in assets) {
      targets.add(_projectRelativeRef(a.relativePath));
      final lmas = a.lmasPath;
      if (lmas != null) targets.add(_projectRelativeRef(lmas));
    }
    if (targets.isEmpty) return const [];
    bool refers(Object? value) =>
        value is String && value.isNotEmpty && targets.contains(_projectRelativeRef(value));
    return _actors
        .where((actor) =>
            refers(actor.meshAssetPath) ||
            refers(actor.blueprintClass) ||
            refers(actor.materialPath) ||
            actor.components.any((c) => c.properties.values.any(refers)))
        .toList();
  }

  String _projectRelativeRef(String ref) {
    final path = ref.replaceAll('\\', '/');
    final root = '${projectDirPath.replaceAll('\\', '/')}/';
    return path.startsWith(root) ? path.substring(root.length) : path;
  }

  /// Deletes [assets] (and [cascadeAssets]) from disk and removes the level
  /// actors that reference them as one undoable step; returns those actors.
  /// The files themselves are not restored by undo.
  @override
  Future<List<EditorActorNode>> deleteMultipleAssetsCascadeAndCleanScene(
    List<RealAssetInfo> assets, {
    List<RealAssetInfo>? cascadeAssets,
  }) async {
    final assetsToDelete = <RealAssetInfo>{...assets, ...?cascadeAssets};
    final affected = actorsReferencingAssets(assetsToDelete);

    for (final a in assetsToDelete) {
      final file = File('$projectDirPath/${a.relativePath}');
      // An authored Animation Sequence's clip lives in its skeletal mesh's
      // GLB too: it goes with the asset.
      final lmas = a.lmasPath ?? (a.relativePath.endsWith('.lmas') ? file.path : null);
      if (lmas != null && a.type == AssetType.animation) {
        try {
          AuthoredAnimationStore.detach(projectDirPath, _projectRelativeRef(lmas));
        } catch (e) {
          _logger.log('Could not take the clip of ${a.relativePath} out of its skeletal mesh: $e',
              level: 'warning', source: 'ContentBrowser');
        }
      }
      if (file.existsSync()) {
        file.deleteSync();
      }
      if (a.lmasPath != null && File(a.lmasPath!).existsSync()) {
        File(a.lmasPath!).deleteSync();
      }
    }

    if (affected.isNotEmpty) {
      final affectedIds = {for (final a in affected) a.id};
      final positions = {for (final a in affected) a.id: _actors.indexOf(a)};
      void apply() {
        _actors.removeWhere((a) => affectedIds.contains(a.id));
        _selectedActorIds.removeWhere(affectedIds.contains);
        if (_selectedActor != null && affectedIds.contains(_selectedActor!.id)) {
          _selectedActor = null;
        }
        _markDirty();
        notifyListeners();
      }

      void undo() {
        final ordered = [...affected]..sort((a, b) => positions[a.id]!.compareTo(positions[b.id]!));
        for (final a in ordered) {
          _actors.insert(positions[a.id]!.clamp(0, _actors.length), a);
        }
        _markDirty();
        notifyListeners();
      }

      apply();
      transactions.record(
        EditorTransaction(
          label: assetsToDelete.length == 1
              ? 'Delete Asset ${assetsToDelete.first.fileName.split('.').first}'
              : 'Delete ${assetsToDelete.length} Assets',
          undo: undo,
          redo: apply,
        ),
      );
    }

    _logger.log(
      affected.isEmpty
          ? 'Deleted ${assetsToDelete.length} asset(s); no placed actor referenced them'
          : 'Deleted ${assetsToDelete.length} asset(s) and removed ${affected.length} actor(s) that used them: '
              '${affected.map((a) => a.name).join(', ')}',
      level: 'warning',
      source: 'ContentBrowser',
    );
    _refreshAssets();
    _markDirty();
    return affected;
  }
}
