part of 'plugin_extension_registry.dart';

/// What the registry does for plugins with a process part: their shell's
/// panels, tabs and asset editors sit in a process guard, and their
/// process's contributions are kept apart from their shell's so either can
/// register again without removing the other.
extension _RegistryProcesses on PluginExtensionRegistry {
  bool _isIsolated(String plugin) => _processes?.isIsolated(plugin) ?? false;

  /// [builder] inside [plugin]'s process guard (unchanged for a plugin
  /// without a process part).
  Widget Function(BuildContext) _guarded(String plugin, Widget Function(BuildContext) builder) => (context) {
        final supervisor = _processes?.supervisorOf(plugin);
        if (supervisor == null) return builder(context);
        return PluginProcessGuard(
          channel: supervisor,
          logTail: () => supervisor.logTail,
          logRevision: supervisor.logRevision,
          child: Builder(builder: builder),
        );
      };

  EditorPanelDescriptor _guardPanel(String plugin, EditorPanelDescriptor panel) => !_isIsolated(plugin)
      ? panel
      : EditorPanelDescriptor(
          id: panel.id,
          title: panel.title,
          icon: panel.icon,
          builder: _guarded(plugin, panel.builder),
          defaultDock: panel.defaultDock,
          defaultAlwaysVisible: panel.defaultAlwaysVisible,
        );

  EditorTabDescriptor _guardTab(String plugin, EditorTabDescriptor tab) => !_isIsolated(plugin)
      ? tab
      : EditorTabDescriptor(
          id: tab.id,
          title: tab.title,
          icon: tab.icon,
          builder: _guarded(plugin, tab.builder),
          contentDroppable: tab.contentDroppable,
          contentBrowserOpened: tab.contentBrowserOpened,
        );

  EditorAssetTypeHandler _guardAssetType(String plugin, EditorAssetTypeHandler handler) {
    final factory = handler.editorFactory;
    if (factory == null || !_isIsolated(plugin)) return handler;
    return EditorAssetTypeHandler(
      assetType: handler.assetType,
      customTypeId: handler.customTypeId,
      displayName: handler.displayName,
      icon: handler.icon,
      thumbnailBuilder: handler.thumbnailBuilder,
      editorFactory: (context, asset) => _guarded(plugin, (c) => factory(c, asset))(context),
      contentDroppable: handler.contentDroppable,
      contentBrowserOpened: handler.contentBrowserOpened,
    );
  }

  /// The contribution lists, by plugin.
  List<Map<String, List<Object>>> get _contributionLists => [
        _menuEntries,
        _menus,
        _toolbarButtons,
        _slotButtons,
        _panels,
        _tabs,
        _assetTypes,
        _importers,
        _detailsCustomizations,
        _settingsSections,
      ];

  /// Everything [plugin] has registered now.
  Set<Object> _itemsOf(String plugin) => {
        for (final m in _contributionLists) ...?m[plugin],
        ...?_consoleCommands[plugin]?.values,
      };

  /// Removes [plugin]'s entry of [contributions] except what its process
  /// registered (a shell registering again).
  void _dropShellItems(Map<String, Object> contributions, String plugin) {
    final owned = _processOwned[plugin];
    final value = contributions[plugin];
    if (owned == null || owned.isEmpty || value == null) {
      contributions.remove(plugin);
    } else if (value is List) {
      value.removeWhere((x) => !owned.contains(x));
    } else if (value is Map) {
      value.removeWhere((_, x) => !owned.contains(x));
    } else {
      contributions.remove(plugin);
    }
  }

  void _registerProcess(String plugin, void Function(LuminaEditorContext context) register) {
    _removeProcessItems(plugin);
    final before = _itemsOf(plugin);
    final toolsBefore = _mcpHost?.toolsOf(plugin) ?? const <String>{};
    final previous = _currentPlugin;
    _currentPlugin = plugin;
    try {
      register(this);
    } catch (e, s) {
      logger.log('Plugin $plugin: its process contributions could not be registered: $e\n$s', level: 'error', source: 'Plugins');
    } finally {
      _currentPlugin = previous;
    }
    _processOwned[plugin] = _itemsOf(plugin).difference(before);
    _processTools[plugin] = (_mcpHost?.toolsOf(plugin) ?? const <String>{}).difference(toolsBefore);
  }

  void _removeProcessItems(String plugin) {
    final owned = _processOwned.remove(plugin) ?? const <Object>{};
    if (owned.isNotEmpty) {
      for (final m in _contributionLists) {
        m[plugin]?.removeWhere(owned.contains);
      }
      _consoleCommands[plugin]?.removeWhere((_, c) => owned.contains(c));
    }
    final tools = _processTools.remove(plugin);
    if (tools != null && tools.isNotEmpty) _mcpHost?.removeTools(plugin, tools);
  }
}
