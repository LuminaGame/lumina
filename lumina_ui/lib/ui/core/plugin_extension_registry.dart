import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show ValueListenable, mapEquals;
import 'package:flutter/widgets.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart';

import 'package:lumina_ui/ui/features/mcp_server/services/host_editor_mcp.dart';
import 'package:lumina_ui/ui/core/plugin_3d_viewport_container.dart';
import 'package:lumina_ui/ui/core/property_editors/asset_picker_select.dart';
import 'package:lumina_ui/ui/core/services/plugin_process/plugin_process_host.dart';
import 'package:lumina_ui/ui/core/services/plugin_process/plugin_process_manager.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme_access.dart';
import 'package:lumina_ui/ui/core/widgets/plugin_process_guard.dart';

part 'plugin_extension_registry_entries.dart';
part 'plugin_extension_registry_processes.dart';

class PluginExtensionRegistry extends ChangeNotifier implements LuminaEditorHostContext, EditorThemeHost, PluginProcessHost {
  final EngineLoggerService logger;

  PluginExtensionRegistry({required this.logger});

  /// The sub-editor tab category a plugin asset opens under:
  /// `pluginAsset:<customTypeId>`. `SubEditorWorkspaceWidget`
  /// renders the handler's `editorFactory` for it.
  static const String pluginAssetCategoryPrefix = 'pluginAsset:';

  EditorLevelAccess? _level;

  /// The host attaches the open level before registering plugins; a registry without one is a bare registration context.
  void attachLevel(EditorLevelAccess level) => _level = level;

  bool get hasLevel => _level != null;

  EditorPanels? _panelsAccess;
  final EditorPanels _detachedPanels = EditorPanels.detached();

  /// The editor's panel visibility, before plugins register.
  void attachPanels(EditorPanels panels) => _panelsAccess = panels;

  @override
  EditorPanels get panels => _panelsAccess ?? _detachedPanels;

  HostEditorMcp Function()? _mcpFactory;
  HostEditorMcp? _mcpHost;

  /// The editor's MCP tools, created on first use (the MCP
  /// service is lazy).
  void attachMcp(HostEditorMcp Function() host) => _mcpFactory = host;

  /// The registering plugin's view of the editor's MCP tools; a bare
  /// registration context gets a detached one.
  @override
  EditorMcp get mcp => mcpFor(_currentPlugin ?? builtInPlugin);

  /// Plugins read the active editor theme (read-only).
  @override
  EditorThemeAccess get theme => const HostEditorThemeAccess();

  @override
  EditorLevelAccess get level {
    final l = _level;
    if (l == null) throw StateError('PluginExtensionRegistry has no level attached: call attachLevel before registering plugins');
    return l;
  }

  Future<void> Function({
    required String relativePath,
    Uint8List? bytes,
    bool generateThumbnail,
  })? _assetSaver;

  /// Attaches the host function that handles saving assets, updating Content
  /// Browser, and enqueuing thumbnail generation.
  void attachAssetSaver(
    Future<void> Function({
      required String relativePath,
      Uint8List? bytes,
      bool generateThumbnail,
    }) saver,
  ) {
    _assetSaver = saver;
  }

  @override
  Future<void> saveAsset({
    required String relativePath,
    Uint8List? bytes,
    bool generateThumbnail = true,
  }) async {
    final saver = _assetSaver;
    if (saver != null) {
      await saver(
        relativePath: relativePath,
        bytes: bytes,
        generateThumbnail: generateThumbnail,
      );
    }
  }

  PluginProcessManager? _processes;

  /// The supervisors of the isolated plugins: their channels, guards and
  /// process contributions. Without one every channel is detached.
  void attachProcesses(PluginProcessManager processes) => _processes = processes;

  PluginProcessManager? get processes => _processes;

  // PluginProcessHost: what plugin processes reach (see
  // plugin_extension_registry_processes.dart).
  final Map<String, Set<Object>> _processOwned = {};
  final Map<String, Set<String>> _processTools = {};
  EditorProjectInfo? Function()? _projectInfo;

  /// The open project, told to plugin processes in their hello.
  void attachProjectInfo(EditorProjectInfo? Function() info) => _projectInfo = info;

  @override
  EditorProjectInfo? get projectInfo => _projectInfo?.call();

  @override
  void logPlugin(String plugin, String message, {String level = 'info'}) => logger.log(message, level: level, source: plugin);

  @override
  EditorLevelAccess? get levelAccess => _level;

  @override
  EditorMcp mcpFor(String plugin) =>
      _mcpFactory == null ? EditorMcp.detached(pluginName: plugin) : HostEditorMcp.lazyScoped(() => _mcpHost ??= _mcpFactory!(), plugin);

  @override
  PluginStorage storageFor(String plugin) {
    final root = _dataRoot?.call() ?? Directory('${Directory.systemTemp.path}/lumina_plugin_data');
    final project = _projectDir?.call();
    return PluginStorage(
      userDir: Directory('${root.path}/$plugin'),
      projectDir: project == null ? null : Directory('$project/.lumina/plugins/$plugin'),
    );
  }

  @override
  ValueListenable<Map<String, Object?>> settingsFor(String plugin) => _settingsNotifier(plugin);

  @override
  void registerProcessContributions(String plugin, void Function(LuminaEditorContext context) register) {
    _registerProcess(plugin, register);
    notifyListeners();
  }

  @override
  void removeProcessContributions(String plugin) {
    _removeProcessItems(plugin);
    notifyListeners();
  }

  @override
  void processStateChanged(String plugin) => notifyListeners();

  /// [pluginName]'s supervisor when it has a process part, else a detached
  /// channel.
  @override
  PluginProcessChannel processChannel(String pluginName) =>
      _processes?.supervisorOf(pluginName) ?? PluginProcessChannel.detached(pluginName);

  @override
  void reportCrash(
    Object error,
    StackTrace? stack, {
    String? plugin,
    String? context,
  }) {
    final targetPlugin = plugin ?? _currentPlugin ?? builtInPlugin;
    LuminaPluginCrashReporter.reportCrash(
      error,
      stack,
      plugin: targetPlugin,
      context: context,
    );
  }

  /// `(path, mtime)` → the custom type id read from the `.lmas`, so a
  /// content-browser rebuild never re-reads unchanged files.
  final Map<String, (int, String?)> _customTypeCache = {};

  /// The plugin asset type handler for [asset] — an `.lmas` of
  /// `AssetType.unknown` whose `metadata.custom_type` names a registered
  /// `customTypeId` — or null for every built-in asset.
  EditorAssetTypeHandler? handlerForAsset(RealAssetInfo asset) {
    final path = asset.lmasPath;
    if (path == null || asset.type != AssetType.unknown) return null;
    final handlers = allAssetTypes.where((h) => h.customTypeId != null).toList();
    if (handlers.isEmpty) return null;
    final customType = customTypeOf(path);
    if (customType == null) return null;
    for (final h in handlers) {
      if (h.customTypeId == customType) return h;
    }
    return null;
  }

  /// The `metadata.custom_type` of the `.lmas` at [path], or null.
  String? customTypeOf(String path) {
    final file = File(path);
    if (!file.existsSync()) return null;
    final mtime = file.lastModifiedSync().millisecondsSinceEpoch;
    final cached = _customTypeCache[path];
    if (cached != null && cached.$1 == mtime) return cached.$2;
    String? type;
    try {
      type = LuminaAsset.fromBytes(file.readAsBytesSync()).metadata[kCustomAssetTypeKey];
    } catch (_) {
      type = null;
    }
    _customTypeCache[path] = (mtime, type);
    return type;
  }

  /// The registration name of the host's own contributions.
  static const String builtInPlugin = 'BuiltIn';

  /// The menu bar's own top-level menus: plugins may not put items in them
  /// (Plugins excepted) or reuse their titles.
  static const List<String> builtInMenuTitles = ['File', 'Edit', 'View', 'Build', 'Debug', 'Tools', 'Plugins', 'Window', 'Help'];

  /// Plugin top-level menus the title bar holds before the rest fold into
  /// `Plugins ▸ <title>` (the bar is the window's drag region).
  static const int maxPluginMenus = 3;

  // Internal storage keyed by pluginName
  final Map<String, List<PluginMenuEntry>> _menuEntries = {};
  final Map<String, List<EditorMenuDescriptor>> _menus = {};
  final Map<String, Set<String>> _foldedMenus = {};
  final Map<String, List<PluginIssue>> _menuIssues = {};
  final Map<String, String> _pluginTitles = {};
  final Map<String, List<EditorToolbarButton>> _toolbarButtons = {};
  final Map<String, List<RegisteredSlotButton>> _slotButtons = {};
  final Map<String, List<EditorPanelDescriptor>> _panels = {};
  final Map<String, List<EditorTabDescriptor>> _tabs = {};
  final Map<String, List<EditorAssetTypeHandler>> _assetTypes = {};
  final Map<String, List<EditorImporter>> _importers = {};
  final Map<String, List<DetailsCustomization>> _detailsCustomizations = {};
  
  // Custom type for console commands to hold handler and help text
  final Map<String, Map<String, RegisteredConsoleCommand>> _consoleCommands = {};

  String? _currentPlugin;

  void beginRegistration(String pluginName) {
    // A plugin contributes once: registering it again (the boot registrar
    // and a test, or a re-enable) replaces what it registered before instead
    // of adding a second copy of every item.
    for (final contributions in <Map<String, Object>>[
      _menuEntries,
      _menus,
      _foldedMenus,
      _menuIssues,
      _toolbarButtons,
      _slotButtons,
      _panels,
      _tabs,
      _assetTypes,
      _importers,
      _detailsCustomizations,
      _consoleCommands,
      _settingsSections,
    ]) {
      _dropShellItems(contributions, pluginName);
    }
    // Its MCP tools too (its process's tools stay: they are registered again
    // by the process itself).
    final keepTools = _processTools[pluginName] ?? const <String>{};
    _mcpHost?.removeTools(pluginName, (_mcpHost?.toolsOf(pluginName) ?? const <String>{}).difference(keepTools));
    _currentPlugin = pluginName;
  }

  void endRegistration() {
    _currentPlugin = null;
    notifyListeners();
  }

  /// Runs [plugin]'s `register` within a scoped [beginRegistration] and
  /// [endRegistration] block. A plugin whose `register` throws is not
  /// registered: what it contributed before the error is removed, the error
  /// is logged under its name and kept as its [registrationErrorOf], and the
  /// editor goes on. Returns whether the plugin registered.
  bool registerPlugin(LuminaEditorPlugin plugin) {
    final name = plugin.pluginName;
    beginRegistration(name);
    _plugins[name] = plugin;
    _registrationErrors.remove(name);
    Object? error;
    StackTrace? stack;
    try {
      plugin.register(this);
    } catch (e, s) {
      error = e;
      stack = s;
      // Drops what it registered before the error.
      beginRegistration(name);
      _plugins.remove(name);
    } finally {
      endRegistration();
    }
    if (error != null) {
      _registrationErrors[name] = '$error';
      logger.log('Plugin $name failed to register and is not loaded: $error\n$stack', level: 'error', source: 'Plugins');
      return false;
    }
    onPluginRegistered?.call(plugin);
    return true;
  }

  final Map<String, String> _registrationErrors = {};

  /// The error [plugin]'s `register` threw on its last registration, or
  /// null when it registered.
  String? registrationErrorOf(String plugin) => _registrationErrors[plugin];

  final Map<String, LuminaEditorPlugin> _plugins = {};

  /// The host tells a newly registered plugin which project is
  /// open (`onProjectOpened`).
  void Function(LuminaEditorPlugin plugin)? onPluginRegistered;

  /// The registered plugin instances (one per name, the latest),
  /// whose lifecycle hooks the host calls.
  List<LuminaEditorPlugin> get registeredPlugins => List.unmodifiable(_plugins.values);

  // ── Project Settings sections + plugin_settings ──────────

  final Map<String, List<ProjectSettingsSection>> _settingsSections = {};
  final Map<String, ValueNotifier<Map<String, Object?>>> _pluginSettings = {};
  Map<String, Map<String, Object?>> _publishedSettings = const {};

  @override
  void registerProjectSettingsSection(ProjectSettingsSection section) {
    final plugin = _currentPlugin ?? builtInPlugin;
    final list = _settingsSections.putIfAbsent(plugin, () => []);
    list
      ..removeWhere((s) => s.id == section.id)
      ..add(section);
  }

  /// Every plugin's Project Settings pages, as (plugin, section), in
  /// registration order.
  List<(String, ProjectSettingsSection)> get projectSettingsSections => [
        for (final e in _settingsSections.entries)
          for (final s in e.value) (e.key, s),
      ];

  /// The registering plugin's applied settings (captured, like [storage]).
  @override
  ValueListenable<Map<String, Object?>> get pluginSettings => _settingsNotifier(_currentPlugin ?? builtInPlugin);

  ValueNotifier<Map<String, Object?>> _settingsNotifier(String plugin) =>
      _pluginSettings.putIfAbsent(plugin, () => ValueNotifier(Map.unmodifiable(_publishedSettings[plugin] ?? const {})));

  /// The project's `plugin_settings` as applied (the editor calls this on
  /// load and after Project Settings applies); each plugin's notifier
  /// changes only when its own block did.
  void publishPluginSettings(Map<String, Map<String, Object?>> settings) {
    _publishedSettings = settings;
    for (final e in _pluginSettings.entries) {
      final next = settings[e.key] ?? const {};
      if (!mapEquals(e.value.value, next)) e.value.value = Map.unmodifiable(next);
    }
  }

  Directory Function()? _dataRoot;
  String? Function()? _projectDir;

  /// Where plugin data lives — per user under [dataRoot], per
  /// project under `<project>/.lumina/plugins/`.
  void attachStorage({required Directory Function() dataRoot, required String? Function() projectDir}) {
    _dataRoot = dataRoot;
    _projectDir = projectDir;
  }

  /// The registering plugin's own store (captured, like [mcp]).
  @override
  PluginStorage get storage => storageFor(_currentPlugin ?? builtInPlugin);

  @override
  void registerMenuItem(String menuPath, EditorCommand command,
      {EditorMenuItemOptions options = const EditorMenuItemOptions()}) {
    final plugin = _currentPlugin ?? builtInPlugin;
    final segments = menuPath.split('/').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if (plugin == builtInPlugin) {
      _addMenuEntry(PluginMenuEntry._(plugin, segments, command, options));
      return;
    }
    if (segments.length < 2) {
      _menuIssue(plugin, PluginIssueType.invalidMenuPath,
          'Plugin $plugin: menu path "$menuPath" names no menu and item; use Plugins/<Group>/<Item>');
      return;
    }
    final root = segments.first;
    final rest = segments.sublist(1);
    if (root == 'Plugins') {
      _addMenuEntry(PluginMenuEntry._(plugin, ['Plugins', ...rest], command, options, ungrouped: rest.length == 1));
    } else if (_foldedMenus[plugin]?.contains(root) ?? false) {
      _addMenuEntry(PluginMenuEntry._(plugin, ['Plugins', ...segments], command, options));
    } else if (_menus[plugin]?.any((m) => m.title == root) ?? false) {
      _addMenuEntry(PluginMenuEntry._(plugin, segments, command, options));
    } else if (root == 'Tools') {
      // Legacy location: Tools/<Group>/… becomes
      // Plugins/<Group>/…; an ungrouped Tools/<Item> goes under the plugin.
      final warned = _menuEntries[plugin]?.any((e) => e.legacy) ?? false;
      if (!warned) {
        logger.log(
          'Plugin $plugin registers menu items under Tools/, which is deprecated: they now appear in the Plugins menu '
          '(register them as Plugins/<Group>/<Item>)',
          level: 'warning',
          source: 'PluginRegistry',
        );
      }
      _addMenuEntry(PluginMenuEntry._(plugin, ['Plugins', ...rest], command, options, ungrouped: rest.length == 1, legacy: true));
    } else {
      final why = builtInMenuTitles.contains(root)
          ? 'the built-in $root menu does not take plugin items'
          : 'no menu titled "$root" is registered by this plugin (registerMenu first)';
      _menuIssue(plugin, PluginIssueType.invalidMenuPath, 'Plugin $plugin: menu path "$menuPath" rejected: $why');
    }
  }

  void _addMenuEntry(PluginMenuEntry entry) {
    entry._registry = this;
    _checkDuplicateCommand(entry.command.id, entry.plugin);
    _menuEntries.putIfAbsent(entry.plugin, () => []).add(entry);
  }

  void _menuIssue(String plugin, PluginIssueType type, String message) {
    _menuIssues.putIfAbsent(plugin, () => []).add(PluginIssue(type, message));
    logger.log(message, level: 'error', source: 'PluginRegistry');
  }

  @override
  void registerMenu(EditorMenuDescriptor menu) {
    final plugin = _currentPlugin ?? builtInPlugin;
    final title = menu.title.trim();
    String? owner;
    for (final e in _menus.entries) {
      if (e.value.any((m) => m.title == title)) owner = e.key;
    }
    if (builtInMenuTitles.contains(title) || owner != null || title.isEmpty) {
      _menuIssue(plugin, PluginIssueType.menuConflict,
          'Plugin $plugin: top-level menu "$title" conflicts with ${owner == null ? 'a built-in menu' : 'the menu of plugin $owner'}');
      return;
    }
    if (pluginMenus.length >= maxPluginMenus) {
      _foldedMenus.putIfAbsent(plugin, () => {}).add(title);
      _menuIssue(plugin, PluginIssueType.tooManyMenus,
          'Plugin $plugin: the menu bar holds $maxPluginMenus plugin menus; "$title" appears as Plugins ▸ $title instead');
      return;
    }
    _menus.putIfAbsent(plugin, () => []).add(menu);
  }

  /// The Plugin Manager titles plugins by their friendly names; an ungrouped
  /// `Plugins/<Item>` is filed under the same title.
  void setPluginTitles(Map<String, String> titles) {
    _pluginTitles
      ..clear()
      ..addAll(titles);
    notifyListeners();
  }

  String pluginTitle(String plugin) => _pluginTitles[plugin] ?? plugin;

  /// The menu issues [plugin] caused in its last registration.
  List<PluginIssue> menuIssuesFor(String plugin) => List.unmodifiable(_menuIssues[plugin] ?? const []);

  /// Every accepted menu item whose effective path starts at the top-level
  /// menu [root], in registration order.
  List<PluginMenuEntry> menuEntriesUnder(String root) => [
        for (final list in _menuEntries.values)
          for (final e in list)
            if (e.segments.first == root) e,
      ];

  /// The plugin-owned top-level menus the menu bar shows, by placement then
  /// order then registration.
  List<PluginMenu> get pluginMenus {
    final all = [
      for (final e in _menus.entries)
        for (final m in e.value) PluginMenu(e.key, m),
    ];
    final indexed = all.asMap().entries.toList()
      ..sort((a, b) {
        final byPlacement = a.value.menu.placement.index.compareTo(b.value.menu.placement.index);
        if (byPlacement != 0) return byPlacement;
        final byOrder = a.value.menu.order.compareTo(b.value.menu.order);
        return byOrder != 0 ? byOrder : a.key.compareTo(b.key);
      });
    return [for (final e in indexed) e.value];
  }

  @override
  void registerToolbarButton(EditorToolbarButton button) {
    final plugin = _currentPlugin ?? 'BuiltIn';
    _checkDuplicateCommand(button.command.id, plugin);
    _toolbarButtons.putIfAbsent(plugin, () => []).add(button);
    // Drawn as a slot button; `group` names the slot.
    final slot = EditorSlot.values.where((s) => s.name == button.group).firstOrNull ?? EditorSlot.levelToolbarEnd;
    _addSlotButton(plugin, EditorSlotButton(
      id: button.id,
      slot: slot,
      state: ValueNotifier(EditorButtonState(icon: button.icon, tooltip: button.tooltip)),
      command: button.command,
    ));
  }

  @override
  void registerSlotButton(EditorSlotButton button) => _addSlotButton(_currentPlugin ?? builtInPlugin, button);

  void _addSlotButton(String plugin, EditorSlotButton button) {
    final effectiveId = '$plugin.${button.id}';
    if (_slotButtons.values.expand((e) => e).any((b) => b.effectiveId == effectiveId)) {
      logger.log('Duplicate slot button id $effectiveId from plugin $plugin: the first one is kept', level: 'error', source: 'PluginRegistry');
      return;
    }
    _slotButtons.putIfAbsent(plugin, () => []).add(RegisteredSlotButton._(plugin, effectiveId, button, _slotSequence++));
  }

  int _slotSequence = 0;

  /// The buttons in [slot], by `order`, ties in registration
  /// order.
  List<RegisteredSlotButton> slotButtons(EditorSlot slot) => [
        for (final list in _slotButtons.values)
          for (final b in list)
            if (b.button.slot == slot) b,
      ]..sort((a, b) {
          final byOrder = a.button.order.compareTo(b.button.order);
          return byOrder != 0 ? byOrder : a._sequence.compareTo(b._sequence);
        });

  @override
  void registerPanel(EditorPanelDescriptor panel) {
    final plugin = _currentPlugin ?? 'BuiltIn';
    for (var p in _panels.values.expand((e) => e)) {
      if (p.id == panel.id) {
        logger.log('Duplicate panel id ${panel.id} from plugin $plugin', level: 'error', source: 'PluginRegistry');
        return;
      }
    }
    _panels.putIfAbsent(plugin, () => []).add(_guardPanel(plugin, panel));
  }

  @override
  void registerAssetType(EditorAssetTypeHandler handler) {
    final plugin = _currentPlugin ?? 'BuiltIn';
    _assetTypes.putIfAbsent(plugin, () => []).add(_guardAssetType(plugin, handler));
  }

  @override
  void registerImporter(EditorImporter importer) {
    final plugin = _currentPlugin ?? 'BuiltIn';
    _importers.putIfAbsent(plugin, () => []).add(importer);
  }

  @override
  void registerDetailsCustomization(DetailsCustomization c) {
    final plugin = _currentPlugin ?? 'BuiltIn';
    _detailsCustomizations.putIfAbsent(plugin, () => []).add(c);
  }

  @override
  void registerConsoleCommand(String name, String help, void Function(List<String> args) handler) {
    final plugin = _currentPlugin ?? 'BuiltIn';
    final cmds = _consoleCommands.values.expand((e) => e.keys).toSet();
    if (cmds.contains(name)) {
      logger.log('Duplicate console command $name from plugin $plugin', level: 'error', source: 'PluginRegistry');
      return;
    }
    _consoleCommands.putIfAbsent(plugin, () => {})[name] = RegisteredConsoleCommand(help, handler);
  }

  void _checkDuplicateCommand(String id, String pluginName) {
    final allCmds = _menuEntries.values.expand((e) => e).map((e) => e.command.id).toSet()
      ..addAll(_toolbarButtons.values.expand((e) => e).map((e) => e.command.id));
    if (allCmds.contains(id)) {
      logger.log('Duplicate command id $id from plugin $pluginName', level: 'error', source: 'PluginRegistry');
      // In a real app we'd throw or return, but for now we just log it as per instructions
    }
  }

  // Getters for routing
  /// Every accepted menu item as `(effective path, command)`.
  List<MapEntry<String, EditorCommand>> get allMenuCommands => [
        for (final list in _menuEntries.values)
          for (final e in list) MapEntry(e.path, e.command),
      ];

  List<EditorToolbarButton> get allToolbarButtons => _toolbarButtons.values.expand((e) => e).toList();
  List<EditorPanelDescriptor> get allPanels => _panels.values.expand((e) => e).toList();
  List<EditorAssetTypeHandler> get allAssetTypes => _assetTypes.values.expand((e) => e).toList();
  List<EditorImporter> get allImporters => _importers.values.expand((e) => e).toList();
  List<DetailsCustomization> get allDetailsCustomizations => _detailsCustomizations.values.expand((e) => e).toList();
  Map<String, RegisteredConsoleCommand> get allConsoleCommands {
    Map<String, RegisteredConsoleCommand> map = {};
    for (var entry in _consoleCommands.values) {
      map.addAll(entry);
    }
    return map;
  }

  void Function(String tabId, {String? title})? _tabOpener;
  void attachTabOpener(void Function(String tabId, {String? title}) opener) => _tabOpener = opener;

  @override
  void registerTab(EditorTabDescriptor tab) {
    final plugin = _currentPlugin ?? builtInPlugin;
    final list = _tabs.putIfAbsent(plugin, () => []);
    list.removeWhere((t) => t.id == tab.id);
    list.add(_guardTab(plugin, tab));
  }

  @override
  void openTab(String tabId, {String? title}) {
    final tab = findTab(tabId);
    final t = title ?? tab?.title ?? tabId;
    _tabOpener?.call(tabId, title: t);
  }

  EditorTabDescriptor? findTab(String tabId) {
    for (final list in _tabs.values) {
      for (final t in list) {
        if (t.id == tabId) return t;
      }
    }
    return null;
  }

  List<EditorTabDescriptor> get allTabs => [
        for (final list in _tabs.values) ...list,
      ];

  List<RealAssetInfo> Function()? _assetsProvider;

  /// Attaches the host function providing the active project's assets.
  void attachAssetsProvider(List<RealAssetInfo> Function() provider) {
    _assetsProvider = provider;
  }

  @override
  Widget buildAssetPicker(
    BuildContext context, {
    required String? selectedPath,
    required ValueChanged<String?> onSelected,
    Set<AssetType>? typeFilter,
    String placeholder = 'None',
    bool allowClear = false,
    bool expand = true,
  }) {
    final scope = AssetPickerScope.maybeOf(context);
    final all = scope?.allAssets?.call() ?? _assetsProvider?.call() ?? const <RealAssetInfo>[];
    return AssetPickerSelect(
      assets: all,
      selectedPath: selectedPath,
      typeFilter: typeFilter,
      placeholder: placeholder,
      allowClear: allowClear,
      expand: expand,
      onSelected: (asset) => onSelected(asset.relativePath),
      onCleared: allowClear ? () => onSelected(null) : null,
    );
  }

  @override
  Widget build3DViewport(BuildContext context, Plugin3DViewportOptions options) {
    return Plugin3DViewportContainer(
      options: options,
      projectDir: _projectDir?.call(),
    );
  }
}
