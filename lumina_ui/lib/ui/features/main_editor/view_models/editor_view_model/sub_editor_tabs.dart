part of '../editor_view_model.dart';

/// The main workspace tabs and the sub-editor tab sessions (save-on-close).
mixin _EditorSubEditorTabs on _EditorViewModelState {
  List<EditorTabInfo> get openTabs {
    _syncLevelTabTitle();
    return List.unmodifiable(_openTabs);
  }

  /// Keeps the level tab named after the level that is actually open.
  void _syncLevelTabTitle() {
    for (var i = 0; i < _openTabs.length; i++) {
      final tab = _openTabs[i];
      if (tab.id != EditorViewModel.kLevelTabId) continue;
      if (tab.title == activeLevelName) return;
      _openTabs[i] = EditorTabInfo(
        id: tab.id,
        title: activeLevelName,
        category: tab.category,
        asset: tab.asset,
        isDirty: tab.isDirty,
      );
      return;
    }
  }

  int get activeTabIndex => _activeTabIndex;
  EditorTabInfo get currentTab {
    _syncLevelTabTitle();
    return _openTabs[_activeTabIndex];
  }

  void selectTab(int index) {
    if (index >= 0 && index < _openTabs.length) {
      _activeTabIndex = index;
      notifyListeners();
    }
  }

  @override
  void openSubEditorTab(
    String category, {
    String? title,
    RealAssetInfo? asset,
  }) {
    String cleanName = '';
    if (asset != null) {
      cleanName = asset.fileName;
      if (cleanName.endsWith('.lmas')) {
        cleanName = cleanName.substring(0, cleanName.length - 5);
      }
    }
    final tabTitle = title ?? (asset != null ? cleanName : '$category Editor');
    final tabId = asset != null
        ? (asset.lmasPath ?? asset.relativePath)
        : 'tab_$category';

    final existingIndex = _openTabs.indexWhere(
      (t) => t.id == tabId || t.title == tabTitle,
    );
    if (existingIndex != -1) {
      _activeTabIndex = existingIndex;
    } else {
      _openTabs.add(
        EditorTabInfo(
          id: tabId,
          title: tabTitle,
          category: category,
          asset: asset,
        ),
      );
      _activeTabIndex = _openTabs.length - 1;
    }
    _logger.log(
      'Opened Sub-Editor workspace tab: $tabTitle ($category)',
      level: 'info',
      source: 'EditorViewModel',
    );
    notifyListeners();
  }

  /// Binds a mounted sub-editor's view model to the tab identified by
  /// [tabId], so the shell can query dirty state and save it on close.
  @override
  void bindTabSession(
    String tabId, {
    required Listenable notifier,
    required Future<bool> Function() save,
    required bool Function() isDirty,
  }) {
    unbindTabSession(tabId);
    final session = EditorTabSession(
      notifier: notifier,
      save: save,
      isDirty: isDirty,
      onChanged: () {
        // A save rewrites the asset after its thumbnail: queue a new one.
        _thumbnailAfterSubEditorChange(tabId);
        // Sub-editor view models notify from initState/build; defer.
        scheduleMicrotask(() {
          if (!_disposed) notifyListeners();
        });
      },
    );
    _tabSessions[tabId] = session;
    notifier.addListener(session.onChanged);
  }

  @override
  void unbindTabSession(String tabId) {
    final existing = _tabSessions.remove(tabId);
    if (existing != null) {
      existing.notifier.removeListener(existing.onChanged);
    }
  }

  bool hasTabSession(String tabId) => _tabSessions.containsKey(tabId);

  /// The view model bound to the open tab [tabId] (a `MaterialEditorViewModel`,
  /// a `BlueprintEditorViewModel`, …), or null when no sub-editor is bound to
  /// it. The MCP tools edit an open asset through this.
  Listenable? editorSessionFor(String tabId) => _tabSessions[tabId]?.notifier;

  /// Whether the tab at [index] has unsaved changes, consulting the bound
  /// sub-editor session when there is one.
  bool isTabDirty(int index) {
    if (index < 0 || index >= _openTabs.length) return false;
    final tab = _openTabs[index];
    if (index == 0) return _project.isDirty;
    final session = _tabSessions[tab.id];
    if (session != null) return session.isDirty() || tab.isDirty;
    return tab.isDirty;
  }

  /// Saves the tab at [index] through its bound sub-editor (or the level
  /// save path for the main tab). Returns false when nothing could save it
  /// or the save failed.
  Future<bool> saveTab(int index) async {
    if (index < 0 || index >= _openTabs.length) return false;
    final tab = _openTabs[index];
    if (index == 0) {
      await saveLevelAndGenerateCode();
      return true;
    }
    final session = _tabSessions[tab.id];
    if (session == null) {
      _logger.log(
        'No save handler bound for tab "${tab.title}"',
        level: 'warning',
        source: 'EditorViewModel',
      );
      return false;
    }
    try {
      final ok = await session.save();
      if (ok) {
        tab.isDirty = false;
        _thumbnailAfterSubEditorChange(tab.id);
        _logger.log(
          'Saved "${tab.title}"',
          level: 'success',
          source: 'EditorViewModel',
        );
      } else {
        _logger.log(
          'Save failed for "${tab.title}"',
          level: 'error',
          source: 'EditorViewModel',
        );
      }
      notifyListeners();
      return ok;
    } catch (e) {
      _logger.log(
        'Save threw for "${tab.title}": $e',
        level: 'error',
        source: 'EditorViewModel',
      );
      return false;
    }
  }

  void closeTab(int index) {
    if (index == 0) return; // Cannot close main 3D level tab
    if (index >= 0 && index < _openTabs.length) {
      unbindTabSession(_openTabs[index].id);
      _releaseLevelBlueprintEditor(_openTabs[index]);
      _openTabs.removeAt(index);
      if (_activeTabIndex >= _openTabs.length) {
        _activeTabIndex = _openTabs.length - 1;
      }
      notifyListeners();
    }
  }

  /// Opens the asset at [assetPath] (absolute, or relative to the project)
  /// in its editor — the one a Content Browser double-click opens
  /// (`subEditorCategoryFor`): a plugin asset type (a plugin's
  /// `registerAssetType`, matched by the `.lmas`' `metadata.custom_type`)
  /// with its `editorFactory`, a level in the level editor.
  @override
  void openAssetEditorByPath(String assetPath) {
    final prefix = '$projectDirPath/';
    final relative = assetPath.startsWith(prefix) ? assetPath.substring(prefix.length) : assetPath;
    RealAssetInfo? asset = _realAssets.where((a) => a.relativePath == relative).firstOrNull;
    if (asset == null) {
      _refreshAssets();
      asset = _realAssets.where((a) => a.relativePath == relative).firstOrNull;
    }
    if (asset == null) {
      _logger.log('Cannot open $relative: not an asset of this project', level: 'warning', source: 'ContentBrowser');
      return;
    }
    final category = subEditorCategoryFor(asset, extensions: extensionRegistry);
    if (category == null) {
      // No one to ask here, so a dirty level stays open.
      openLevelGuarded(asset.relativePath);
      return;
    }
    openSubEditorTab(category, asset: asset);
  }
}
