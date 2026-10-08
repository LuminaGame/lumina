part of '../editor_view_model.dart';

/// Content Browser state (search, filters, folders, collections, reveal) and
/// asset create / rename / move / delete on disk.
mixin _EditorAssetsAndContentBrowser on _EditorViewModelState {
  List<Collection> get collections => _collections;

  String get searchQuery => _searchQuery;
  set searchQuery(String value) {
    if (_searchQuery != value) {
      _searchQuery = value;
      notifyListeners();
    }
  }

  Set<AssetType> get activeTypeFilters => _activeTypeFilters;
  set activeTypeFilters(Set<AssetType> value) {
    _activeTypeFilters = value;
    notifyListeners();
  }

  String get sortMode => _sortMode;
  set sortMode(String value) {
    if (_sortMode != value) {
      _sortMode = value;
      notifyListeners();
    }
  }

  bool get showAllAssets => _showAllAssets;
  set showAllAssets(bool value) {
    if (_showAllAssets != value) {
      _showAllAssets = value;
      notifyListeners();
    }
  }

  @override
  String? get selectedFolder => _selectedFolder;
  @override
  set selectedFolder(String? value) {
    if (_selectedFolder != value) {
      _selectedFolder = value;
      _activeCollection = null;
      _showMarketplaceAssets = false;
      // Navigating to a folder browses it.
      _showAllAssets = false;
      // …and opens the Sources tree down to it.
      if (value != null) expandFolderAncestors(value);
      notifyListeners();
    }
  }

  /// Whether [folder] is open in the Sources tree.
  bool isFolderExpanded(String folder) => layoutState.expandedFolders.contains(folder);

  /// Opens or closes [folder] in the Sources tree; the change is persisted
  /// with the editor layout.
  void setFolderExpanded(String folder, bool expanded) {
    final changed = expanded ? layoutState.expandedFolders.add(folder) : layoutState.expandedFolders.remove(folder);
    if (!changed) return;
    _writeLayoutState();
    notifyListeners();
  }

  void toggleFolderExpanded(String folder) => setFolderExpanded(folder, !isFolderExpanded(folder));

  /// Opens every ancestor of [folder] (not [folder] itself) so its tree row
  /// is visible: navigation from the grid, breadcrumbs, Browse to asset and
  /// imports lands on a revealed folder.
  void expandFolderAncestors(String folder) {
    var changed = false;
    var parent = ContentFolders.parentOf(folder);
    while (parent.isNotEmpty && parent != '/') {
      changed = layoutState.expandedFolders.add(parent) || changed;
      parent = ContentFolders.parentOf(parent);
    }
    if (changed) _writeLayoutState();
  }

  /// Rewrites (or with [to] null drops) the expanded paths at or under
  /// [folder] after a folder rename / delete.
  void _remapExpandedFolders(String folder, String? to) {
    bool within(String path) => path == folder || path.startsWith('$folder/');
    final affected = layoutState.expandedFolders.where(within).toList();
    if (affected.isEmpty) return;
    layoutState.expandedFolders.removeAll(affected);
    if (to != null) layoutState.expandedFolders.addAll(affected.map((p) => '$to${p.substring(folder.length)}'));
    _writeLayoutState();
  }

  Set<String> get favoriteFolders => _favoriteFolders;

  void toggleFavoriteFolder(String folder) {
    if (_favoriteFolders.contains(folder)) {
      _favoriteFolders.remove(folder);
    } else {
      _favoriteFolders.add(folder);
    }
    notifyListeners();
  }

  String? get activeCollection => _activeCollection;
  set activeCollection(String? value) {
    if (_activeCollection != value) {
      _activeCollection = value;
      if (value != null) {
        _selectedFolder = null;
        _showMarketplaceAssets = false;
      }
      notifyListeners();
    }
  }

  bool get showRecentlyModified => _showRecentlyModified;
  set showRecentlyModified(bool value) {
    if (_showRecentlyModified != value) {
      _showRecentlyModified = value;
      if (value) {
        _activeCollection = null;
        _selectedFolder = null;
        _showMarketplaceAssets = false;
      }
      notifyListeners();
    }
  }

  /// The project's content folders (and the plugins' content roots). The
  /// folder walk is cached: widgets read this on every build, and a build
  /// runs per landed thumbnail, so walking `contents/` each time stalled the
  /// UI. The cache is dropped whenever the asset list is rescanned
  /// ([_refreshAssets]: import, save, move, delete, rename) or a folder is
  /// created.
  List<String> get sourceFolders {
    final cached = _sourceFolderCache;
    final scanned = cached != null && cached.$1 == projectDirPath
        ? cached.$2
        : (_sourceFolderCache = (projectDirPath, List<String>.unmodifiable(_assetRepo.scanContentFolders(projectDirPath)))).$2;
    return [...scanned, ..._pluginContentRoots.values];
  }

  Future<void> loadCollections() async {
    _collections = _collectionsRepo.loadCollections(projectDirPath);
    notifyListeners();
  }

  void createCollection(String name) {
    _collections.add(Collection(name: name, assets: []));
    _collectionsRepo.saveCollections(projectDirPath, _collections);
    notifyListeners();
  }

  void deleteCollection(String name) {
    _collections.removeWhere((c) => c.name == name);
    if (_activeCollection == name) _activeCollection = null;
    _collectionsRepo.saveCollections(projectDirPath, _collections);
    notifyListeners();
  }

  void addToCollection(String collectionName, String assetId) {
    final col = _collections.firstWhere(
      (c) => c.name == collectionName,
      orElse: () => Collection(name: collectionName, assets: []),
    );
    if (!_collections.contains(col)) _collections.add(col);
    if (!col.assets.any((a) => a.assetId == assetId)) {
      final asset = _realAssets.firstWhere((a) => a.assetId == assetId);
      col.assets.add(
        CollectionAsset(assetId: assetId, assetPath: asset.relativePath),
      );
      _collectionsRepo.saveCollections(projectDirPath, _collections);
      notifyListeners();
    }
  }

  void removeFromCollection(String collectionName, String assetId) {
    final col = _collections.firstWhere((c) => c.name == collectionName);
    col.assets.removeWhere((a) => a.assetId == assetId);
    _collectionsRepo.saveCollections(projectDirPath, _collections);
    notifyListeners();
  }

  List<RealAssetInfo> recentlyModified(int n) {
    final list = List<RealAssetInfo>.from(_realAssets);
    list.sort(
      (a, b) => (b.lastModified?.millisecondsSinceEpoch ?? 0).compareTo(
        a.lastModified?.millisecondsSinceEpoch ?? 0,
      ),
    );
    return list.take(n).toList();
  }

  List<RealAssetInfo> get visibleAssets {
    List<RealAssetInfo> list = [];

    if (_showRecentlyModified) {
      list = recentlyModified(20);
    } else if (_showMarketplaceAssets) {
      // Everything the Marketplace installed into the project.
      list = _realAssets.where((a) => a.relativePath.startsWith('${EditorViewModel.marketplaceFolder}/')).toList();
    } else if (_activeCollection != null) {
      final col = _collections.firstWhere(
        (c) => c.name == _activeCollection,
        orElse: () => Collection(name: '', assets: []),
      );
      final ids = col.assets.map((a) => a.assetId).toSet();
      list = _realAssets.where((a) => ids.contains(a.assetId)).toList();
    } else if (_showAllAssets) {
      list = List<RealAssetInfo>.from(_realAssets);
    } else {
      // The selected folder only; a search
      // widens to the folder's subtree, Show All to the whole project.
      final folder = _selectedFolder ?? 'contents';
      list = _searchQuery.isNotEmpty
          ? _realAssets.where((a) => a.relativePath.replaceAll(r'\', '/').startsWith('$folder/')).toList()
          : _realAssets.where((a) => ContentFolders.parentOf(a.relativePath) == folder).toList();
    }

    if (_activeTypeFilters.isNotEmpty) {
      list = list.where((a) => _activeTypeFilters.contains(a.type)).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((a) {
        if (a.fileName.toLowerCase().contains(q)) return true;
        if (a.assetId?.toLowerCase().contains(q) == true) return true;

        bool metaMatches = false;
        try {
          final file = File('$projectDirPath/${a.relativePath}');
          if (file.existsSync()) {
            final bytes = file.readAsBytesSync();
            LuminaAsset? asset;
            try {
              asset = LuminaAsset.fromBytes(bytes);
            } catch (_) {
              final str = utf8.decode(bytes);
              final map = jsonDecode(str);
              if (map is Map) {
                asset = LuminaAsset.fromMap(Map<String, dynamic>.from(map));
              }
            }
            if (asset != null && asset.metadata.isNotEmpty) {
              for (final v in asset.metadata.values) {
                if (v.toString().toLowerCase().contains(q)) {
                  metaMatches = true;
                  break;
                }
              }
            }
          }
        } catch (_) {}
        return metaMatches;
      }).toList();
    }

    if (_sortMode == 'Name ↑') {
      list.sort((a, b) => a.fileName.compareTo(b.fileName));
    } else if (_sortMode == 'Name ↓') {
      list.sort((a, b) => b.fileName.compareTo(a.fileName));
    } else if (_sortMode == 'Size ↑') {
      list.sort((a, b) => a.bytes.compareTo(b.bytes));
    } else if (_sortMode == 'Size ↓') {
      list.sort((a, b) => b.bytes.compareTo(a.bytes));
    } else if (_sortMode == 'Type') {
      list.sort((a, b) => a.type.name.compareTo(b.type.name));
    } else if (_sortMode == 'Last Modified ↓') {
      list.sort(
        (a, b) => (b.lastModified?.millisecondsSinceEpoch ?? 0).compareTo(
          a.lastModified?.millisecondsSinceEpoch ?? 0,
        ),
      );
    }

    return list;
  }

  /// Whether the grid shows the selected folder's subfolders as tiles: a
  /// folder is being browsed (no search, Show All, collection or smart view).
  bool get showsFolderTiles =>
      !_showRecentlyModified &&
      !_showMarketplaceAssets &&
      _activeCollection == null &&
      !_showAllAssets &&
      _searchQuery.isEmpty;

  /// The selected folder's direct subfolders, sorted by name; empty when [showsFolderTiles] is false.
  List<String> get visibleFolders {
    if (!showsFolderTiles) return const [];
    final folder = _selectedFolder ?? 'contents';
    final children = sourceFolders.where((f) => f != folder && ContentFolders.parentOf(f) == folder).toList()
      ..sort((a, b) => a.split('/').last.toLowerCase().compareTo(b.split('/').last.toLowerCase()));
    return children;
  }

  /// Content Browser → New Folder: creates [name] (made unique with `_1`,
  /// `_2`…) under [parent] with a keep-marker and returns its path.
  String createContentFolder(String parent, String name) {
    _sourceFolderCache = null;
    final clean = name.trim().replaceAll(RegExp(r'[\\/]'), '_');
    final base = clean.isEmpty ? 'NewFolder' : clean;
    var candidate = '$parent/$base';
    var n = 1;
    while (Directory('$projectDirPath/$candidate').existsSync()) {
      candidate = '$parent/${base}_${n++}';
    }
    final dir = Directory('$projectDirPath/$candidate')..createSync(recursive: true);
    ContentFolders.writeMarker(dir.path);
    _logger.log('Created folder $candidate/', level: 'info', source: 'ContentBrowser');
    notifyListeners();
    return candidate;
  }

  /// Content Browser → Rename folder: renames [folder] to [newName] on disk,
  /// rewrites every reference to an asset inside it, and keeps the browser's
  /// selection, favourites and the active level pointing at the new path.
  /// Returns the new path, or null when the name is empty, taken, or the
  /// folder is the `contents` root.
  String? renameContentFolder(String folder, String newName) {
    final clean = newName.trim();
    if (clean.isEmpty || clean.contains('/') || clean.contains(r'\') || !folder.contains('/')) return null;
    final target = '${ContentFolders.parentOf(folder)}/$clean';
    if (target == folder) return folder;
    final src = Directory('$projectDirPath/$folder');
    if (!src.existsSync() || Directory('$projectDirPath/$target').existsSync()) return null;
    src.renameSync('$projectDirPath/$target');
    _updateReferencePathsInProject('$folder/', '$target/');
    String moved(String path) => path == folder || path.startsWith('$folder/') ? '$target${path.substring(folder.length)}' : path;
    _selectedFolder = _selectedFolder == null ? null : moved(_selectedFolder!);
    _favoriteFolders = _favoriteFolders.map(moved).toSet();
    _remapExpandedFolders(folder, target);
    final level = _project.activeLevel;
    if (level.startsWith('$folder/')) {
      _project = _project.copyWith(activeLevel: moved(level));
      _markDirty();
    }
    _logger.log('Renamed folder $folder/ to $target/', level: 'info', source: 'ContentBrowser');
    _refreshAssets();
    return target;
  }

  /// Content Browser → Delete folder: deletes [folder] and every asset in it
  /// (through the asset delete path, so placed actors are cleaned up). The
  /// `contents` root and a folder holding the open level are refused (false).
  Future<bool> deleteContentFolder(String folder) async {
    if (!folder.contains('/')) return false;
    if (_project.activeLevel.startsWith('$folder/')) return false;
    final inside = _realAssets.where((a) => a.relativePath.startsWith('$folder/')).toList();
    if (inside.isNotEmpty) await deleteMultipleAssetsCascadeAndCleanScene(inside);
    final dir = Directory('$projectDirPath/$folder');
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    bool within(String path) => path == folder || path.startsWith('$folder/');
    if (_selectedFolder != null && within(_selectedFolder!)) _selectedFolder = ContentFolders.parentOf(folder);
    _favoriteFolders.removeWhere(within);
    _remapExpandedFolders(folder, null);
    _logger.log('Deleted folder $folder/ (${inside.length} asset(s))', level: 'warning', source: 'ContentBrowser');
    _refreshAssets();
    return true;
  }

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

  /// The asset "Browse to asset" last asked the Content Browser to select,
  /// and a serial that changes with every request so the same
  /// asset can be browsed to twice.
  String? get contentBrowserRevealPath => _contentBrowserRevealPath;
  int get contentBrowserRevealSerial => _contentBrowserRevealSerial;

  /// The assets selected in the Content Browser: project-relative paths in
  /// selection order. The browser widget edits this set in place as the user
  /// clicks, Shift-clicks and Ctrl-clicks.
  Set<String> get contentBrowserSelection => _contentBrowserSelection;

  /// The Content Browser asset clicked last (the anchor of a Shift-click
  /// range); null when nothing was clicked.
  String? get contentBrowserPrimaryAsset => _contentBrowserPrimaryAsset;
  set contentBrowserPrimaryAsset(String? path) => _contentBrowserPrimaryAsset = path;

  /// Replaces the Content Browser selection with [paths]; the last one
  /// becomes the primary asset.
  void selectContentBrowserAssets(Iterable<String> paths) {
    _contentBrowserSelection
      ..clear()
      ..addAll(paths);
    _contentBrowserPrimaryAsset = _contentBrowserSelection.isEmpty ? null : _contentBrowserSelection.last;
    notifyListeners();
  }

  /// The scanned copy of [asset] (with the thumbnail rendered since a list
  /// was built), or [asset] itself.
  RealAssetInfo latestAsset(RealAssetInfo asset) =>
      _realAssets.where((a) => a.relativePath == asset.relativePath).firstOrNull ?? asset;

  /// "Browse to asset" (from an asset picker): the level tab and
  /// the Content Browser come to the front, open at the asset's folder with
  /// the asset selected.
  void browseToAsset(RealAssetInfo asset) {
    final path = asset.relativePath.replaceAll(r'\', '/');
    final slash = path.lastIndexOf('/');
    _activeTabIndex = 0;
    layoutState.activeBottomTab = 0;
    layoutState.bottomVisible = true;
    _showRecentlyModified = false;
    _activeCollection = null;
    _searchQuery = '';
    _activeTypeFilters = {};
    selectedFolder = slash > 0 ? path.substring(0, slash) : 'contents';
    _contentBrowserRevealPath = path;
    _contentBrowserRevealSerial++;
    _contentBrowserSelection
      ..clear()
      ..add(path);
    _contentBrowserPrimaryAsset = path;
    _logger.log('Browsed to $path in the Content Browser', level: 'info', source: 'ContentBrowser');
    notifyListeners();
  }

  /// Focuses the Content Browser on [relativeAssetPath]'s folder and filters
  /// the grid to its name (Build Manager's "Reveal in Content Browser").
  @override
  void revealAssetInContentBrowser(String relativeAssetPath) {
    final slash = relativeAssetPath.lastIndexOf('/');
    final folder = slash > 0
        ? relativeAssetPath.substring(0, slash)
        : 'contents';
    var name = slash >= 0
        ? relativeAssetPath.substring(slash + 1)
        : relativeAssetPath;
    if (name.endsWith('.lmas')) name = name.substring(0, name.length - 5);
    selectedFolder = folder;
    searchQuery = name;
    _logger.log(
      'Revealed $relativeAssetPath in Content Browser',
      level: 'info',
      source: 'BuildManager',
    );
    notifyListeners();
  }
}

/// The material source a new asset is written with: a new material starts
/// from the Material Editor's template, so it opens as nodes and compiles;
/// other types carry none.
String _newAssetMatSource(AssetType type, String fileName) => type == AssetType.filamat
    ? MaterialEditorViewModel.newMaterialSource(fileName.replaceAll('.lmas', ''))
    : '';
