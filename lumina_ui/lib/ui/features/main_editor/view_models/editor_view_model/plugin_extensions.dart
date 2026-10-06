part of '../editor_view_model.dart';

/// The bottom panel's own tabs (Content Browser, Output Log, Blueprint);
/// plugin panels follow them, in registration order.
const int kBuiltInBottomTabs = 3;

/// What the host does with plugins' registrations: plugin
/// panels as bottom-panel tabs with a Window-menu entry each, plugin importers
/// in the Import flow, and plugin console commands behind the Output Log's
/// command line. Toolbar buttons are drawn by the toolbar itself.
mixin _EditorPluginExtensions on _EditorViewModelState {
  /// Plugin panel visibility, handed to plugins as
  /// `context.panels`.
  late final EditorPanelsController panelsController = EditorPanelsController(
    layout: () => layoutState,
    panels: () => extensionRegistry.allPanels,
    bottomTabIndex: (id) {
      final index = pluginPanels.indexWhere((p) => p.id == id);
      return index < 0 ? -1 : kBuiltInBottomTabs + index;
    },
    save: saveLayoutState,
    warn: (message) => _logger.log(message, level: 'warning', source: 'Plugins'),
  );

  /// The plugin panels shown as bottom-panel tabs: every panel but the
  /// `PanelDefaultDock.right` ones, which live in the right dock.
  List<EditorPanelDescriptor> get pluginPanels =>
      [for (final p in extensionRegistry.allPanels) if (!EditorPanelsController.isRight(p)) p];

  /// Every plugin panel, for the Window menu.
  List<EditorPanelDescriptor> get allPluginPanels => extensionRegistry.allPanels;

  /// The Window-menu command for plugin panel [panelId].
  static String panelCommandId(String panelId) => 'window.panel.$panelId';

  /// The Window-menu command that toggles "Always" (shown in every editor
  /// tab) for right-dock panel [panelId].
  static String panelAlwaysCommandId(String panelId) => 'window.panelAlways.$panelId';

  /// Registers (again) one `window.panel.<id>` command per plugin panel;
  /// called whenever the extension registry changes. A right-dock panel's
  /// command toggles it; a bottom panel's shows its tab. A right-dock panel
  /// also gets a `window.panelAlways.<id>` command.
  void _syncPluginPanelCommands() {
    for (final panel in allPluginPanels) {
      if (EditorPanelsController.isRight(panel) && commands.byId(panelAlwaysCommandId(panel.id)) == null) {
        commands.register(EditorCommand(
          id: panelAlwaysCommandId(panel.id),
          label: '${panel.title}: Show in Every Editor',
          icon: LucideIcons.pin,
          canExecute: () => true,
          execute: (_) => panelsController.toggleAlwaysVisible(panel.id),
        ));
      }
      if (commands.byId(panelCommandId(panel.id)) != null) continue;
      commands.register(EditorCommand(
        id: panelCommandId(panel.id),
        label: panel.title,
        icon: panel.icon,
        canExecute: () => true,
        execute: (_) => EditorPanelsController.isRight(panel) ? panelsController.toggle(panel.id) : panelsController.show(panel.id),
      ));
    }
    panelsController.refresh();
  }

  // --- Plugin processes ----------------------------------------

  /// The isolated plugins compiled into this editor
  /// (`LuminaEditorHost.pluginProcesses`), each in its own supervised
  /// process, or in the editor process when the project says so.
  late final PluginProcessManager pluginProcesses = PluginProcessManager(
    host: extensionRegistry,
    processes: LuminaEditorHost.pluginProcesses,
    inEditorProcess: () => PluginIsolationOverrides.inEditorProcess(project),
  );

  /// Whether the project runs [plugin]'s process part inside the editor
  /// (Plugin Manager ▸ "Run in editor process (debugging)").
  bool pluginRunsInEditorProcess(String plugin) => PluginIsolationOverrides.runsInEditorProcess(project, plugin);

  /// Writes the project's `plugin_isolation` override for [plugin] and, when
  /// this editor has its process part, moves it there now.
  Future<void> setPluginRunsInEditorProcess(String plugin, bool inEditorProcess) async {
    // The plugin registry keeps its own copy of the project: both learn the
    // override; the editor's copy (with everything else it holds) is saved last.
    await pluginRegistry.setIsolationOverride(plugin, inEditorProcess ? PluginIsolation.inProcess : null);
    _project = PluginIsolationOverrides.withInEditorProcess(project, plugin, inEditorProcess);
    await _projectRepo.saveProject(_project, projectDirPath);
    // This editor moves it now: no restart is pending.
    if (pluginProcesses.isIsolated(plugin)) {
      for (final e in pluginRegistry.entries) {
        if (e.descriptor.name == plugin) e.restartPending = false;
      }
    }
    _logger.log(
      inEditorProcess
          ? 'Plugin $plugin now runs in the editor process (debugging): a crash or hang in it affects the editor'
          : 'Plugin $plugin runs in its own process again',
      level: inEditorProcess ? 'warning' : 'info',
      source: 'Plugins',
    );
    await pluginProcesses.setRunInEditorProcess(plugin, inEditorProcess);
    notifyListeners();
  }

  // --- Lifecycle -----------------------------------------------

  bool _pluginsClosed = false;
  bool _pluginsShutDown = false;

  /// Tells [plugin] which project is open (called as it registers).
  void _pluginRegistered(LuminaEditorPlugin plugin) {
    try {
      plugin.onProjectOpened(EditorProjectInfo(name: project.projectName, dir: projectDirPath));
    } catch (e) {
      _logger.log('Plugin ${plugin.pluginName}: onProjectOpened failed: $e', level: 'error', source: 'Plugins');
    }
  }

  /// Runs every registered plugin's `onProjectClosing`, and when [exiting]
  /// its `onEditorShutdown` then `unregister`, plugin by plugin. Each hook is
  /// bounded by [hookTimeout]; a hook that throws or times out is logged and
  /// the rest go on. Idempotent.
  Future<void> shutdownPlugins({required bool exiting, Duration hookTimeout = const Duration(seconds: 5)}) async {
    final closing = !_pluginsClosed;
    final shuttingDown = exiting && !_pluginsShutDown;
    _pluginsClosed = true;
    if (exiting) _pluginsShutDown = true;
    if (!closing && !shuttingDown) return;
    // Plugin processes first, in parallel; each call is bounded.
    if (closing) await pluginProcesses.projectClosing();
    if (shuttingDown) await pluginProcesses.shutdownAll();
    for (final plugin in extensionRegistry.registeredPlugins) {
      if (closing) await _pluginHook(plugin, 'onProjectClosing', plugin.onProjectClosing, hookTimeout);
      if (shuttingDown) {
        await _pluginHook(plugin, 'onEditorShutdown', plugin.onEditorShutdown, hookTimeout);
        await _pluginHook(plugin, 'unregister', () async => plugin.unregister(extensionRegistry), hookTimeout);
      }
    }
  }

  Future<void> _pluginHook(LuminaEditorPlugin plugin, String hook, Future<void> Function() run, Duration timeout) async {
    try {
      await run().timeout(timeout);
    } on TimeoutException {
      _logger.log('Plugin ${plugin.pluginName}: $hook timed out after ${timeout.inMilliseconds} ms; going on',
          level: 'warning', source: 'Plugins');
    } catch (e) {
      _logger.log('Plugin ${plugin.pluginName}: $hook failed: $e', level: 'error', source: 'Plugins');
    }
  }

  Future<void> _shutdownPluginsForExit() => shutdownPlugins(exiting: true);

  /// Shows plugin panel [panelId] (the right dock or its bottom tab).
  void showPluginPanel(String panelId) => panelsController.show(panelId);

  /// Whether plugin panel [panelId] is open.
  bool isPluginPanelShowing(String panelId) => panelsController.isVisible(panelId);

  // --- Importers -------------------------------------------------------------

  /// Every extension Content Browser ▸ Import accepts: the pipeline's own
  /// (`ImportFormats`) and every plugin importer's.
  List<String> get importExtensions => {
        ...ImportFormats.extensions,
        for (final importer in extensionRegistry.allImporters)
          for (final ext in importer.extensions) ext.toLowerCase().replaceFirst('.', ''),
      }.toList(growable: false);

  /// The plugin importer that handles [path] by its extension, or null when
  /// the built-in pipeline does.
  EditorImporter? pluginImporterFor(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0) return null;
    final ext = path.substring(dot + 1).toLowerCase();
    for (final importer in extensionRegistry.allImporters) {
      if (importer.extensions.any((e) => e.toLowerCase().replaceFirst('.', '') == ext)) return importer;
    }
    return null;
  }

  /// Runs each of [paths] through its plugin importer, into the Content
  /// Browser's selected folder; logs every outcome and refreshes the asset
  /// list once. Paths no plugin handles are skipped (the caller sends them to
  /// the built-in pipeline).
  Future<List<ImportResult>> importWithPluginImporters(List<String> paths) async {
    final folder = selectedFolder ?? 'contents';
    final target = Directory('$projectDirPath/$folder')..createSync(recursive: true);
    final results = <ImportResult>[];
    for (final path in paths) {
      final importer = pluginImporterFor(path);
      if (importer == null) continue;
      final name = path.split(RegExp(r'[/\\]')).last;
      ImportResult result;
      try {
        result = await importer.import(File(path), ImportContext(targetDirectory: target.path));
      } catch (e) {
        result = ImportResult.failure('$e');
      }
      results.add(result);
      if (result.success) {
        _logger.log('Imported $name with ${importer.description}${result.assetPath == null ? '' : ' → ${result.assetPath}'}',
            level: 'success', source: 'Import');
      } else {
        _logger.log('${importer.description} could not import $name: ${result.error ?? 'unknown error'}',
            level: 'error', source: 'Import');
      }
    }
    if (results.any((r) => r.success)) refreshAssets();
    return results;
  }

  // --- Console commands ------------------------------------------------------

  /// Runs one Output Log command line: `<command> [args…]`. `help` lists the
  /// registered commands; an unknown command is logged as an error. The
  /// command itself is echoed under source `Console`.
  void runConsoleCommand(String line) {
    final parts = line.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return;
    final name = parts.first;
    final args = parts.sublist(1);
    _logger.log('> ${parts.join(' ')}', level: 'info', source: 'Console');
    final all = extensionRegistry.allConsoleCommands;
    if (name == 'help') {
      final names = all.keys.toList()..sort();
      _logger.log(
        names.isEmpty
            ? 'No console commands are registered.'
            : 'Console commands:\n${[for (final n in names) '  $n — ${all[n]!.help}'].join('\n')}',
        level: 'info',
        source: 'Console',
      );
      return;
    }
    final command = all[name];
    if (command == null) {
      _logger.log('Unknown console command "$name" (type help for the list)', level: 'error', source: 'Console');
      return;
    }
    try {
      command.handler(args);
    } catch (e) {
      _logger.log('$name failed: $e', level: 'error', source: 'Console');
    }
  }
}
