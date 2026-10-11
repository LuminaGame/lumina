part of '../editor_view_model.dart';

/// Editor panel Widget Blueprints: the host that discovers, compiles,
/// docks and runs them, the folders it scans, and the per-actor edits their
/// graphs make through the level library.
mixin _EditorPanelsSupport on _EditorViewModelState, _EditorPlugins {
  EditorPanelHost? _editorPanelHost;
  EditorPanelDocking? _editorPanelDocking;

  /// The editor panel host (started by the editor with [startEditorPanels]).
  EditorPanelHost get editorPanels => _editorPanelHost ??= EditorPanelHost(this as EditorViewModel);

  /// Where the panels dock (menus, right dock, tabs, dialogs, settings).
  EditorPanelDocking get editorPanelDocking =>
      _editorPanelDocking ??= EditorPanelDocking(editorPanels, this as EditorViewModel);

  void _disposeEditorPanels() {
    _editorPanelDocking?.dispose();
    _editorPanelHost?.dispose();
  }

  /// Starts editor panels once the plugins are known.
  Future<void> startEditorPanels() async {
    await _pluginsScanned.future;
    if (_disposed) return;
    editorPanelDocking.attach();
    await editorPanels.start();
  }

  /// Where editor panels are looked for: the `content/` folder of every
  /// enabled plugin that can contain content, then the project's
  /// `contents/`.
  List<EditorPanelSource> editorPanelSources() {
    final sources = <EditorPanelSource>[];
    if (_pluginsScanned.isCompleted) {
      for (final e in pluginRegistry.entries) {
        final d = e.descriptor;
        if (!e.enabled || !d.canContainContent) continue;
        sources.add(EditorPanelSource.plugin(name: d.name, friendlyName: d.friendlyName ?? d.name, pluginDir: d.pluginDir.path));
      }
    }
    sources.add(EditorPanelSource.project(projectDirPath));
    return sources;
  }

  /// Content Browser ▸ New ▸ Editor Panel Widget: a working editor panel
  /// (a section, a property row, a button wired to Show Toast) in [folder]
  /// (default `contents/editor`). Returns its project-relative path.
  Future<String> createEditorPanelWidget({String name = 'EPW_NewEditorPanel', String? folder}) async {
    final path = await createEditorPanelAsset(
        projectDirPath: projectDirPath, name: name, folder: contentSubfolderOrNull(folder) ?? kEditorPanelFolder);
    _logger.log('Created editor panel Widget Blueprint ${path.split('/').last} at $path', level: 'success', source: 'ContentBrowser');
    _refreshAssets();
    return path;
  }

  /// The designer's "Run as Editor Panel": the saved panel at [assetPath]
  /// (re)compiled and opened where it docks. The author running their own
  /// panel trusts it. Returns whether it could be opened.
  Future<bool> runAsEditorPanel(String assetPath) async {
    final host = editorPanels;
    if (!host.isStarted) await startEditorPanels();
    await host.refreshSources();
    final target = p.normalize(p.absolute(assetPath));
    final rt = host.panels.values.where((r) => p.normalize(p.absolute(r.entry.filePath)) == target).firstOrNull;
    if (rt == null) {
      _logger.log('${p.basename(assetPath)} is not an editor panel the editor can find (Class Settings ▸ Editor Panel, '
          "under the project's contents/ or an enabled plugin's content/).", level: 'warning', source: 'Editor Panels');
      return false;
    }
    if (rt.entry.isProjectPanel) await host.trustProjectPanels([rt.id]);
    editorPanelDocking.open(rt.id);
    return true;
  }

  /// Whether [path] is content of an engine plugin (shipped with Lumina
  /// Studio): the designer opens it read-only; a user or project plugin's
  /// content stays editable (its author develops it from its folder).
  bool isReadOnlyPluginContent(String? path) {
    if (path == null || !_pluginsScanned.isCompleted) return false;
    final target = p.normalize(p.absolute(path));
    for (final e in pluginRegistry.entries) {
      final d = e.descriptor;
      if (d.origin != PluginOrigin.engine) continue;
      if (p.isWithin(p.normalize(p.absolute(d.pluginDir.path)), target)) return true;
    }
    return false;
  }

  /// Sets one actor's transform as one undo step (in an editor panel's open
  /// transaction, part of that step): an editor panel's `Set Actor
  /// Transform`, which never changes the selection.
  bool setActorTransformWithTransaction(String id,
      {List<double>? location, List<double>? rotation, List<double>? scale, String label = 'Set Actor Transform'}) {
    final actor = _actors.where((a) => a.id == id).firstOrNull;
    if (actor == null || actor.isLocked) return false;
    final before = (List<double>.of(actor.location), List<double>.of(actor.rotation), List<double>.of(actor.scale));
    final after = (
      location == null ? before.$1 : List<double>.of(location),
      rotation == null ? before.$2 : List<double>.of(rotation),
      scale == null ? before.$3 : List<double>.of(scale),
    );
    void apply((List<double>, List<double>, List<double>) t) {
      actor
        ..location = List<double>.of(t.$1)
        ..rotation = List<double>.of(t.$2)
        ..scale = List<double>.of(t.$3);
      _markDirty();
      notifyListeners();
    }

    apply(after);
    transactions.record(EditorTransaction(label: label, undo: () => apply(before), redo: () => apply(after)));
    return true;
  }

  /// Sets [key] of [plugin]'s project settings (`.lmproject`
  /// `plugin_settings.<plugin>`; null removes it), saves the project and
  /// publishes the settings to the plugin (its process gets them as
  /// `pluginSettings`). Secret-looking keys are refused.
  Future<void> setProjectPluginSetting(String plugin, String key, Object? value) async {
    PluginSettingsHandle.checkKey(key, value);
    final all = {for (final e in _project.pluginSettings.entries) e.key: Map<String, Object?>.of(e.value)};
    final mine = all.putIfAbsent(plugin, () => <String, Object?>{});
    if (value == null) {
      mine.remove(key);
    } else {
      mine[key] = value;
    }
    if (mine.isEmpty) all.remove(plugin);
    _project = _project.copyWith(pluginSettings: all);
    await _projectRepo.saveProject(_project, projectDirPath);
    extensionRegistry.publishPluginSettings(_project.pluginSettings);
    notifyListeners();
  }
}
