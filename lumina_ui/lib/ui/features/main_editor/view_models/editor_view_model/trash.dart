part of '../editor_view_model.dart';

/// Recoverable asset operations: deletes go to the project
/// trash (`.lumina/trash/`) as one undo step, and the files an import or a
/// new asset wrote can be undone into the trash. The Content Browser's own
/// Delete stays a hard delete behind its confirm dialog.
mixin _EditorTrash on _EditorViewModelState, _EditorAssetsAndContentBrowser {
  ProjectTrash? _trash;

  ProjectTrash get projectTrash {
    final current = _trash;
    if (current != null && current.projectDir == projectDirPath) return current;
    return _trash = ProjectTrash(projectDirPath);
  }

  String _relativeOf(String path) {
    final norm = path.replaceAll('\\', '/');
    final root = '${projectDirPath.replaceAll('\\', '/')}/';
    return norm.startsWith(root) ? norm.substring(root.length) : norm;
  }

  /// The files of [assets]: each source file and its `.lmas`.
  List<String> _filesOf(Iterable<RealAssetInfo> assets) => [
        for (final a in assets) ...[
          _relativeOf(a.relativePath),
          if (a.lmasPath != null) _relativeOf(a.lmasPath!),
        ],
      ];

  /// The authored Animation Sequences among [files] (project relative), by
  /// their `clip_index`: their clips live in their skeletal meshes' GLBs too.
  List<String> _authoredSequencesIn(Iterable<String> files) {
    final found = <(int, String)>[];
    for (final rel in files) {
      if (!rel.endsWith('.lmas')) continue;
      final file = File('$projectDirPath/$rel');
      if (!file.existsSync()) continue;
      try {
        final asset = LuminaAsset.fromBytes(file.readAsBytesSync());
        if (asset.type != AssetType.animation || !AuthoredAnimationStore.isAuthored(asset)) continue;
        found.add((int.tryParse(asset.metadata['clip_index'] ?? '') ?? 0, rel));
      } catch (_) {}
    }
    found.sort((a, b) => a.$1.compareTo(b.$1));
    return [for (final f in found) f.$2];
  }

  /// Before [files] leave the project: the clips of the authored sequences
  /// among them leave their meshes' GLBs and `animation_clips`.
  void _detachAuthoredClips(Iterable<String> files) {
    for (final rel in _authoredSequencesIn(files)) {
      try {
        if (AuthoredAnimationStore.detach(projectDirPath, rel)) {
          _logger.log('Took the clip of $rel out of its skeletal mesh', level: 'info', source: 'ContentBrowser');
        }
      } catch (e) {
        _logger.log('Could not take the clip of $rel out of its skeletal mesh: $e', level: 'warning', source: 'ContentBrowser');
      }
    }
  }

  /// After [files] came back: the clips of the authored sequences among them
  /// go back into their meshes, in `clip_index` order (each where it was).
  void _attachAuthoredClips(Iterable<String> files) {
    for (final rel in _authoredSequencesIn(files)) {
      try {
        if (AuthoredAnimationStore.attach(projectDirPath, rel)) {
          _logger.log('Put the clip of $rel back into its skeletal mesh', level: 'info', source: 'ContentBrowser');
        }
      } catch (e) {
        _logger.log('Could not put the clip of $rel back into its skeletal mesh: $e', level: 'warning', source: 'ContentBrowser');
      }
    }
  }

  /// Deletes [assets] like the Content Browser's cascade — the files and the
  /// level actors that reference them — but moves the files to the project
  /// trash, with the removed actors in its manifest, as one undo step: undo
  /// restores the files byte-identical and re-inserts the actors (same ids,
  /// same Outliner positions); redo trashes them again under the same id.
  Future<({TrashEntry entry, List<EditorActorNode> removed})> deleteAssetsToTrash(
    List<RealAssetInfo> assets, {
    TransactionOrigin? origin,
  }) async {
    final affected = actorsReferencingAssets(assets);
    final positions = {for (final a in affected) a.id: _actors.indexOf(a)};
    final affectedIds = {for (final a in affected) a.id};
    final label = assets.length == 1 ? 'Delete Asset ${assets.first.fileName.split('.').first}' : 'Delete ${assets.length} Assets';
    final files = _filesOf(assets);
    final by = origin ?? TransactionManager.currentOrigin;
    _detachAuthoredClips(files);
    final entry = projectTrash.moveToTrashSync(
      files,
      reason: label,
      origin: by,
      actors: [for (final a in affected) a.toMap()],
    );
    final id = entry.id;

    void removeActors() {
      _actors.removeWhere((a) => affectedIds.contains(a.id));
      _selectedActorIds.removeWhere(affectedIds.contains);
      if (_selectedActor != null && affectedIds.contains(_selectedActor!.id)) _selectedActor = null;
    }

    void finish() {
      _refreshAssets();
      _markDirty();
      notifyListeners();
    }

    removeActors();
    transactions.record(EditorTransaction(
      label: label,
      undo: () {
        projectTrash.restoreSync(id);
        _attachAuthoredClips(files);
        final ordered = [...affected]..sort((a, b) => positions[a.id]!.compareTo(positions[b.id]!));
        for (final a in ordered) {
          _actors.insert(positions[a.id]!.clamp(0, _actors.length), a);
        }
        finish();
      },
      redo: () {
        _detachAuthoredClips(files);
        projectTrash.moveToTrashSync(files, reason: label, origin: by, actors: entry.actors, id: id);
        removeActors();
        finish();
      },
    ));
    _logger.log(
      'Moved ${files.length} file(s) to .lumina/trash/$id'
      '${affected.isEmpty ? '' : ' and removed ${affected.length} actor(s): ${affected.map((a) => a.name).join(', ')}'}',
      level: 'warning',
      source: 'ContentBrowser',
    );
    finish();
    return (entry: entry, removed: affected);
  }

  /// Content Browser folder delete, recoverable (the MCP server's
  /// `delete_content_folder`): every file under [folder] — its assets (the
  /// same cascade as [deleteAssetsToTrash]: the level actors that reference
  /// them are removed, restorable with the same ids), keep-markers and
  /// companions — moves into one trash entry, then the emptied directory tree
  /// goes, all as one undo step. Undo (or `restore_asset`) brings the folder
  /// back. Throws [ArgumentError] for the `contents` root, a folder holding the
  /// open level, or a folder that does not exist — what
  /// [deleteContentFolder] refuses too.
  Future<({TrashEntry entry, List<EditorActorNode> removed, List<String> assets})> deleteContentFolderToTrash(
    String folder, {
    TransactionOrigin? origin,
  }) async {
    final path = folder.replaceAll(r'\', '/').replaceAll(RegExp(r'/+$'), '');
    if (!path.startsWith('contents/')) throw ArgumentError('The contents root cannot be deleted; name a folder under it.');
    if (_project.activeLevel.startsWith('$path/')) {
      throw ArgumentError('$path holds the open level (${_project.activeLevel}); open another level first.');
    }
    final dir = Directory('$projectDirPath/$path');
    if (!dir.existsSync()) throw ArgumentError('No folder $path in the project.');
    final inside = _realAssets.where((a) => a.relativePath.replaceAll(r'\', '/').startsWith('$path/')).toList();
    final affected = actorsReferencingAssets(inside);
    final positions = {for (final a in affected) a.id: _actors.indexOf(a)};
    final affectedIds = {for (final a in affected) a.id};
    final files = <String>{
      ..._filesOf(inside),
      for (final f in dir.listSync(recursive: true).whereType<File>()) _relativeOf(f.path),
    }.toList()
      ..sort();
    final label = 'Delete Folder ${path.split('/').last}';
    final by = origin ?? TransactionManager.currentOrigin;
    _detachAuthoredClips(files);
    final entry = projectTrash.moveToTrashSync(files, reason: label, origin: by, actors: [for (final a in affected) a.toMap()]);
    final id = entry.id;

    bool within(String p) => p == path || p.startsWith('$path/');
    void removeTree() {
      final d = Directory('$projectDirPath/$path');
      // Only directories are left once every file is in the trash.
      if (d.existsSync() && d.listSync(recursive: true).whereType<File>().isEmpty) d.deleteSync(recursive: true);
      if (_selectedFolder != null && within(_selectedFolder!)) _selectedFolder = ContentFolders.parentOf(path);
      _favoriteFolders.removeWhere(within);
      _remapExpandedFolders(path, null);
    }

    void removeActors() {
      _actors.removeWhere((a) => affectedIds.contains(a.id));
      _selectedActorIds.removeWhere(affectedIds.contains);
      if (_selectedActor != null && affectedIds.contains(_selectedActor!.id)) _selectedActor = null;
    }

    void finish() {
      _refreshAssets();
      _markDirty();
      notifyListeners();
    }

    removeTree();
    removeActors();
    transactions.record(EditorTransaction(
      label: label,
      undo: () {
        projectTrash.restoreSync(id);
        _attachAuthoredClips(files);
        final ordered = [...affected]..sort((a, b) => positions[a.id]!.compareTo(positions[b.id]!));
        for (final a in ordered) {
          _actors.insert(positions[a.id]!.clamp(0, _actors.length), a);
        }
        finish();
      },
      redo: () {
        _detachAuthoredClips(files);
        projectTrash.moveToTrashSync(files, reason: label, origin: by, actors: entry.actors, id: id);
        removeTree();
        removeActors();
        finish();
      },
    ));
    _logger.log(
      'Moved folder $path/ (${inside.length} asset(s), ${files.length} file(s)) to .lumina/trash/$id'
      '${affected.isEmpty ? '' : ' and removed ${affected.length} actor(s): ${affected.map((a) => a.name).join(', ')}'}',
      level: 'warning',
      source: 'ContentBrowser',
    );
    finish();
    return (entry: entry, removed: affected, assets: [for (final a in inside) _relativeOf(a.relativePath)]);
  }

  /// Restores trash entry [id] (`restore_asset`): its files, and the actors it
  /// removed that are not in the level any more; one undo step that trashes
  /// them again. Throws [TrashConflict] when a path exists again.
  Future<({TrashEntry entry, List<EditorActorNode> actors})> restoreFromTrash(String id) async {
    final entry = projectTrash.restoreSync(id);
    final files = [for (final f in entry.files) f.original];
    _attachAuthoredClips(files);
    final existing = {for (final a in _actors) a.id};
    final actors = [
      for (final m in entry.actors)
        if (!existing.contains(m['id'])) EditorActorNode.fromMap(m),
    ];
    final ids = {for (final a in actors) a.id};
    void addActors() {
      _actors.addAll(actors);
      _refreshAssets();
      _markDirty();
      notifyListeners();
    }

    addActors();
    transactions.record(EditorTransaction(
      label: 'Restore ${entry.reason.replaceFirst(RegExp(r'^Delete '), '')}',
      undo: () {
        _detachAuthoredClips(files);
        projectTrash.moveToTrashSync(files, reason: entry.reason, actors: entry.actors, id: id);
        _actors.removeWhere((a) => ids.contains(a.id));
        _selectedActorIds.removeWhere(ids.contains);
        _refreshAssets();
        _markDirty();
        notifyListeners();
      },
      redo: () {
        projectTrash.restoreSync(id);
        _attachAuthoredClips(files);
        addActors();
      },
    ));
    _logger.log('Restored ${files.length} file(s) from .lumina/trash/$id', level: 'info', source: 'ContentBrowser');
    return (entry: entry, actors: actors);
  }

  /// The files under `contents/` with their size and mtime, to find what an
  /// import or a new asset wrote.
  Map<String, String> contentsSnapshot() {
    final dir = Directory('$projectDirPath/contents');
    if (!dir.existsSync()) return const {};
    return {
      for (final f in dir.listSync(recursive: true).whereType<File>())
        _relativeOf(f.path): '${f.lengthSync()}|${f.lastModifiedSync().microsecondsSinceEpoch}',
    };
  }

  /// The files under `contents/` now that were not in [before] (a
  /// [contentsSnapshot]).
  List<String> filesCreatedSince(Map<String, String> before) =>
      [for (final k in contentsSnapshot().keys) if (!before.containsKey(k)) k]..sort();

  /// One undo step for files an operation wrote (`import_asset`,
  /// `create_asset`, the Content Browser's New Animation Sequence / Animation
  /// Blueprint / Blend Space): undo moves exactly [created] to the trash (an
  /// authored sequence's clip leaves its mesh with it), redo puts them back.
  void recordCreatedFilesUndo(List<String> created, String label) {
    if (created.isEmpty) return;
    String? id;
    transactions.record(EditorTransaction(
      label: label,
      undo: () {
        _detachAuthoredClips(created);
        id = projectTrash.moveToTrashSync(created, reason: 'Undo $label', id: id).id;
        _refreshAssets();
        notifyListeners();
      },
      redo: () {
        final entryId = id;
        if (entryId != null) projectTrash.restoreSync(entryId);
        _attachAuthoredClips(created);
        _refreshAssets();
        notifyListeners();
      },
    ));
  }
}
