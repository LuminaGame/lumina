part of '../editor_view_model.dart';

/// Plugin scanning and enable/disable.
mixin _EditorPlugins on _EditorViewModelState {
  bool get pluginRestartRequired => _pluginRestartRequired;

  /// Completes once the first plugin scan has set up [pluginRegistry].
  final Completer<void> _pluginsScanned = Completer<void>();

  Future<void> _scanPlugins() async {
    try {
      await _scanPluginRoots();
    } finally {
      if (!_pluginsScanned.isCompleted) _pluginsScanned.complete();
    }
  }

  Future<void> _scanPluginRoots() async {
    final repo = PluginRepository(roots: editorPluginScanRoots(projectDirPath));

    final result = await repo.scanAll();
    LuminaEditorHost.pluginDirs = {for (final p in result.plugins) p.name: p.pluginDir.path};
    for (final err in result.errors) {
      _logger.log(
        'Plugin error: ${err.message} (${err.filePath})',
        level: 'error',
        source: 'PluginDiscovery',
      );
    }
    _logger.log(
      'Found ${result.plugins.length} plugins during discovery.',
      level: 'info',
      source: 'PluginDiscovery',
    );

    // Enabling a code plugin regenerates this project's editor
    // host (<project>/.lumina/editor/); the engine checkout is never touched.
    pluginRegistry = PluginRegistryService(
      repo: repo,
      projectRepo: _projectRepo,
      hostGenerator: EditorHostGeneratorService(engineRoot: LuminaEditorHost.engineRoot),
    );

    await pluginRegistry.initialize(projectDirPath);
    _updatePluginState();
  }

  void _updatePluginState() {
    _pluginRestartRequired = false;
    _pluginContentRoots.clear();

    // The Plugins menu files ungrouped items under each plugin's
    // friendly name, and menu-path problems show on the plugin's row.
    extensionRegistry.setPluginTitles({
      for (final e in pluginRegistry.entries) e.descriptor.name: e.descriptor.friendlyName ?? e.descriptor.name,
    });
    // So does a `register` that threw.
    const registrationIssueTypes = {
      PluginIssueType.invalidMenuPath,
      PluginIssueType.menuConflict,
      PluginIssueType.tooManyMenus,
      PluginIssueType.registrationFailed,
    };
    for (final entry in pluginRegistry.entries) {
      final name = entry.descriptor.name;
      final error = extensionRegistry.registrationErrorOf(name);
      entry.issues = [
        ...entry.issues.where((i) => !registrationIssueTypes.contains(i.type)),
        ...extensionRegistry.menuIssuesFor(name),
        if (error != null) PluginIssue(PluginIssueType.registrationFailed, 'Plugin $name failed to register: $error'),
      ];
    }

    for (final entry in pluginRegistry.entries) {
      if (entry.enabled) {
        if (entry.descriptor.isContentOnly) {
          final contentDir = p.join(entry.descriptor.pluginDir.path, 'content');
          if (Directory(contentDir).existsSync()) {
            _pluginContentRoots[entry.descriptor.friendlyName ??
                    entry.descriptor.name] =
                contentDir;
          }
        }
      }
      if (entry.restartPending) {
        _pluginRestartRequired = true;
      }
    }
    notifyListeners();
  }

  /// Completes once the first plugin scan has set up [pluginRegistry].
  Future<void> get pluginsScanned => _pluginsScanned.future;

  /// Enables or disables plugin [name] and returns the registry's result
  /// (`restart_required` for a code plugin, dependency
  /// issues). Never restarts: the Restart Editor banner does, on the user's
  /// click.
  Future<EnableResult> enablePlugin(
    String name,
    bool enabled, {
    bool cascade = false,
  }) async {
    final result = await pluginRegistry.setEnabled(
      name,
      enabled,
      cascade: cascade,
    );
    if (result.issues.isEmpty) {
      _updatePluginState();
    }
    return result;
  }

  /// Scans the plugin roots again (a plugin was installed or removed, e.g.
  /// by the Marketplace), so the Plugin Manager lists what is on disk.
  /// A restart a code plugin change is waiting for stays pending: the
  /// banner remains after an install or a removal rescans.
  Future<void> rescanPlugins() async {
    await _pluginsScanned.future;
    final restartPending = _pluginRestartRequired;
    await pluginRegistry.refresh();
    _updatePluginState();
    if (restartPending && !_pluginRestartRequired) {
      _pluginRestartRequired = true;
      notifyListeners();
    }
  }

  /// Whether this editor session registered plugin [name] (its code stays
  /// loaded until the editor restarts, even once it is disabled or removed).
  bool isPluginLoaded(String name) => extensionRegistry.registeredPlugins.any((p) => p.pluginName == name);

  /// `editor.restart` and the banner's Restart Editor. Saves
  /// through the normal save-all path, then hands off to the launcher with
  /// `--project`: it sees this project's editor is stale and rebuilds it
  /// behind the splash. Without a launcher the exit(70) contract stays.
  @override
  Future<void> restartEditor() async {
    _logger.log('Restarting editor to apply plugin changes...', level: 'info', source: 'Editor');
    if (_project.isDirty) await saveLevelAndGenerateCode();
    await EditorHandOff.instance.restartThroughLauncher(projectDirPath);
  }

  void dismissPluginRestart() {
    _pluginRestartRequired = false;
    notifyListeners();
  }
}
