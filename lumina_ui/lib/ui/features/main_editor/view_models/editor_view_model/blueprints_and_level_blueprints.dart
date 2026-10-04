part of '../editor_view_model.dart';

/// Level Blueprint tabs, open Blueprint editors, and
/// Blueprint / Widget Blueprint asset creation.
mixin _EditorBlueprintsAndLevelBlueprints on _EditorViewModelState {
  /// The active level's Level Blueprint as Save Level writes it.
  LuminaLevelBlueprintDocument get activeLevelBlueprint =>
      LuminaLevelBlueprintDocument.fromLevelMetadata({LuminaLevelBlueprintDocument.metadataKey: _levelBlueprintMeta},
          levelPath: _project.activeLevel);

  @override
  void _readLevelBlueprintMeta(Object? metadata) {
    final stored = metadata is Map ? metadata[LuminaLevelBlueprintDocument.metadataKey] : null;
    _levelBlueprintMeta = stored is Map ? Map<String, dynamic>.from(jsonDecode(jsonEncode(stored)) as Map) : null;
  }

  /// The open Level Blueprint editor of [levelPath] (default: the active
  /// level), or null.
  LevelBlueprintEditorViewModel? levelBlueprintEditor([String? levelPath]) =>
      _levelBlueprintEditors[levelPath ?? _project.activeLevel];

  /// The active level's placed actors as a Level Blueprint refers to them:
  /// name, class (the placed Blueprint's, else the type's engine class), id.
  List<LuminaBlueprintLevelActorRef> get levelActorRefs => LuminaBlueprintLevelActorRef.fromActorMaps([
        for (final a in _actors)
          {'id': a.id, 'name': a.name, 'type': a.type, if (a.blueprintClass != null) 'blueprintClass': a.blueprintClass},
      ]);

  /// Blueprints ▸ Open Level Blueprint (Edit ▸ Level Blueprint, Ctrl+Shift+B):
  /// opens [levelPath]'s (default: the active level's) Blueprint in its tab,
  /// `<Level> (Level Blueprint)`, or focuses the tab when it is open.
  @override
  LevelBlueprintEditorViewModel openLevelBlueprint([String? levelPath]) {
    final path = levelPath ?? _project.activeLevel;
    final tabId = EditorViewModel.levelBlueprintTabId(path);
    var vm = _levelBlueprintEditors[path];
    if (vm == null) {
      final isActive = path == _project.activeLevel;
      final meta = isActive ? _levelBlueprintMeta : null;
      vm = LevelBlueprintEditorViewModel(
        projectDirectory: projectDirPath,
        levelPath: path,
        // The outliner's actors while this is the level being edited.
        levelActorsSource: isActive ? () => levelActorRefs : null,
        selectedActorNames: () => path == _project.activeLevel ? [for (final a in selectedActors) a.name] : const [],
        onSaved: (saved) {
          if (path == _project.activeLevel) _levelBlueprintMeta = saved.isEmpty ? null : saved.toJson();
        },
        initial: meta == null ? null : LuminaLevelBlueprintDocument.fromJson(meta, levelPath: path),
      );
      _levelBlueprintEditors[path] = vm;
      final session = vm;
      bindTabSession(tabId, notifier: session, save: session.save, isDirty: () => session.isDirty);
      session.prepare();
    }
    final existing = _openTabs.indexWhere((t) => t.id == tabId);
    if (existing != -1) {
      _activeTabIndex = existing;
    } else {
      _openTabs.add(EditorTabInfo(id: tabId, title: EditorViewModel.levelBlueprintTabTitle(path), category: EditorViewModel.levelBlueprintCategory));
      _activeTabIndex = _openTabs.length - 1;
      _logger.log('Opened the Level Blueprint of ${vm.levelName}', level: 'info', source: 'EditorViewModel');
    }
    notifyListeners();
    return vm;
  }

  /// A closed Level Blueprint tab's editor is disposed once its widget is gone.
  @override
  void _releaseLevelBlueprintEditor(EditorTabInfo tab) {
    if (tab.category != EditorViewModel.levelBlueprintCategory) return;
    final path = tab.id.substring('level_blueprint:'.length);
    final vm = _levelBlueprintEditors.remove(path);
    if (vm == null) return;
    _disposeAfterFrame(vm);
  }

  void _disposeAfterFrame(ChangeNotifier notifier) {
    try {
      SchedulerBinding.instance.addPostFrameCallback((_) => notifier.dispose());
      SchedulerBinding.instance.scheduleFrame();
    } catch (_) {
      notifier.dispose();
    }
  }

  /// Switching levels closes the other levels' Blueprint tabs; one with
  /// unsaved changes is saved into its own level, or discarded, as
  /// [onLevelBlueprintSavePrompt] answers.
  @override
  void _closeLevelBlueprintsExcept(String levelPath) {
    for (final entry in _levelBlueprintEditors.entries.toList()) {
      if (entry.key == levelPath) continue;
      final vm = entry.value;
      final tabId = EditorViewModel.levelBlueprintTabId(entry.key);
      final index = _openTabs.indexWhere((t) => t.id == tabId);
      unbindTabSession(tabId);
      _levelBlueprintEditors.remove(entry.key);
      if (index > 0) {
        _openTabs.removeAt(index);
        if (_activeTabIndex == index) {
          _activeTabIndex = 0;
        } else if (_activeTabIndex > index) {
          _activeTabIndex--;
        }
      }
      if (!vm.isDirty) {
        _disposeAfterFrame(vm);
        continue;
      }
      final prompt = onLevelBlueprintSavePrompt;
      final title = EditorViewModel.levelBlueprintTabTitle(entry.key);
      unawaited(() async {
        final save = prompt == null ? true : await prompt(title);
        if (save) {
          final ok = await vm.save();
          _logger.log(ok ? 'Saved $title before switching levels' : 'Could not save $title',
              level: ok ? 'success' : 'error', source: 'EditorViewModel');
        } else {
          _logger.log('Discarded the unsaved changes of $title', level: 'warning', source: 'EditorViewModel');
        }
        _disposeAfterFrame(vm);
      }());
    }
  }

  /// The outliner renamed placed actor [oldName]: the active level's Level
  /// Blueprint references follow it (the stored copy and an open editor).
  @override
  void _renameLevelBlueprintReferences(String oldName, String newName) {
    final meta = _levelBlueprintMeta;
    if (meta != null) {
      final doc = LuminaBlueprintDocument.fromJson(meta);
      if (LevelBlueprintEditorViewModel.renameActorReferences(doc, oldName, newName) > 0) {
        _levelBlueprintMeta = LuminaLevelBlueprintDocument(levelPath: _project.activeLevel, blueprint: doc).toJson();
      }
    }
    levelBlueprintEditor()?.renameLevelActor(oldName, newName);
  }

  /// Creates a Blueprint class [name] under [folder] (a `contents/`
  /// subfolder: the Content Browser folder the user is in;
  /// default `contents/blueprints`).
  Future<void> createBlueprintWithParent({
    required String name,
    required String parentClass,
    String? folder,
  }) async {
    // A widget parent makes a Widget Blueprint (parent `UserWidget`), which the
    // widget designer edits; it is not an actor Blueprint.
    if (parentClass == kWidgetBlueprintParentClass) {
      await createWidgetBlueprint(name: name, folder: folder);
      return;
    }
    final target = contentSubfolderOrNull(folder) ?? 'contents/blueprints';
    final blueprintsDir = Directory('$projectDirPath/$target');
    if (!blueprintsDir.existsSync()) {
      blueprintsDir.createSync(recursive: true);
    }

    final lmasFile = File('${blueprintsDir.path}/$name.lmas');

    final defaultDoc = BlueprintEditorViewModel.createDefaultDocument(
      name,
      parentClass: parentClass,
    );
    final payloadJson = defaultDoc.toFormattedJson();

    final lmasAsset = LuminaAsset(
      assetId: 'bp_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      type: AssetType.actor,
      rawPayload: Uint8List.fromList(utf8.encode(payloadJson)),
      rawMatSource: payloadJson,
      metadata: {'parent_class': parentClass},
    );
    lmasFile.writeAsBytesSync(lmasAsset.toProtoBufferBytes());
    // Code is generated into lib/actors/ when the Blueprint compiles;
    // nothing is written beside the asset.

    _logger.log(
      'Created Blueprint Class "$name" (Parent: $parentClass) at $target/',
      level: 'success',
      source: 'ContentBrowser',
    );
    _refreshAssets();
    final rel = '$target/$name.lmas';
    final created = _realAssets.where((a) => a.relativePath == rel).firstOrNull;
    if (created != null) {
      openSubEditorTab('Blueprint', asset: created);
    }
  }

  /// Creates a Widget Blueprint (a default designer canvas) under [folder]
  /// (default `contents/widgets/`) and returns its project-relative path. A
  /// taken name gets the next free `_<n>` suffix rather than overwriting.
  Future<String> createWidgetBlueprint({String name = 'WBP_NewWidget', String? folder}) async {
    final target = contentSubfolderOrNull(folder) ?? kWidgetBlueprintFolder;
    final path = createWidgetBlueprintAsset(projectDirPath: projectDirPath, name: name, folder: target);
    _logger.log(
      'Created Widget Blueprint "${path.split('/').last}" (Parent: $kWidgetBlueprintParentClass) at $target/',
      level: 'success',
      source: 'ContentBrowser',
    );
    _refreshAssets();
    return path;
  }

  // --- Blueprints and Play -----------------------------

  /// Blueprint editors open in tabs, by the view models their tabs bound.
  @override
  Iterable<BlueprintEditorViewModel> get openBlueprintEditors =>
      _tabSessions.values.map((s) => s.notifier).whereType<BlueprintEditorViewModel>();

  /// UMG designers open in tabs: Play runs their widget
  /// graphs as they are in the editor, saved or not.
  Iterable<UmgEditorViewModel> get openWidgetEditors =>
      _tabSessions.values.map((s) => s.notifier).whereType<UmgEditorViewModel>();

  /// Open Blueprint editors' documents by project-relative path: Play plays
  /// them as they are in the editor.
  Map<String, LuminaBlueprintDocument> get openBlueprintDocuments => {
        ..._inMemoryBlueprintDocuments,
        for (final vm in openBlueprintEditors)
          BlueprintPlayPreflight.relativePath(projectDirPath, vm.assetPath): vm.document,
      };

  /// Registers an in-memory Blueprint document (e.g. for testing, preview, or
  /// without opening a tab session).
  void registerInMemoryBlueprintDocument(String pathOrName, LuminaBlueprintDocument document) {
    _inMemoryBlueprintDocuments[pathOrName] = document;
  }
}

/// [folder] as a project-relative `contents/…` subfolder (`blueprints/doors`
/// → `contents/blueprints/doors`), or null for none, the `contents` root, a
/// plugin content root or a path that climbs out.
String? contentSubfolderOrNull(String? folder) {
  if (folder == null) return null;
  var f = folder.trim().replaceAll(r'\', '/');
  f = f.replaceAll(RegExp(r'^/+|/+$'), '');
  if (f.isEmpty || f == 'contents') return null;
  if (!f.startsWith('contents/')) {
    if (RegExp(r'^[A-Za-z]:').hasMatch(folder.trim()) || folder.trim().startsWith('/')) return null;
    f = 'contents/$f';
  }
  if (f.split('/').any((s) => s.isEmpty || s == '.' || s == '..')) return null;
  return f;
}
