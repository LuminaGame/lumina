import 'dart:io';

import 'package:flutter/foundation.dart' show ValueListenable, mapEquals;
import 'package:flutter/widgets.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart';

import '../features/mcp_server/services/host_editor_mcp.dart';
import 'theme/editor_theme_access.dart';

class PluginExtensionRegistry extends ChangeNotifier implements LuminaEditorHostContext, EditorThemeHost {
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
  EditorMcp get mcp {
    final plugin = _currentPlugin ?? builtInPlugin;
    final factory = _mcpFactory;
    if (factory == null) return EditorMcp.detached(pluginName: plugin);
    return HostEditorMcp.lazyScoped(() => _mcpHost ??= factory(), plugin);
  }

  /// Plugins read the active editor theme (read-only).
  @override
  EditorThemeAccess get theme => const HostEditorThemeAccess();

  @override
  EditorLevelAccess get level {
    final l = _level;
    if (l == null) throw StateError('PluginExtensionRegistry has no level attached: call attachLevel before registering plugins');
    return l;
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
      _assetTypes,
      _importers,
      _detailsCustomizations,
      _consoleCommands,
      _settingsSections,
    ]) {
      contributions.remove(pluginName);
    }
    // Its MCP tools too.
    _mcpHost?.removePlugin(pluginName);
    _currentPlugin = pluginName;
  }

  void endRegistration() {
    _currentPlugin = null;
    notifyListeners();
  }

  /// Helper to run a plugin's register within a scoped [beginRegistration]
  /// and [endRegistration] block.
  void registerPlugin(LuminaEditorPlugin plugin) {
    beginRegistration(plugin.pluginName);
    _plugins[plugin.pluginName] = plugin;
    try {
      plugin.register(this);
    } finally {
      endRegistration();
    }
    onPluginRegistered?.call(plugin);
  }

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
  PluginStorage get storage {
    final plugin = _currentPlugin ?? builtInPlugin;
    final root = _dataRoot?.call() ?? Directory('${Directory.systemTemp.path}/lumina_plugin_data');
    final project = _projectDir?.call();
    return PluginStorage(
      userDir: Directory('${root.path}/$plugin'),
      projectDir: project == null ? null : Directory('$project/.lumina/plugins/$plugin'),
    );
  }

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
    _panels.putIfAbsent(plugin, () => []).add(panel);
  }

  @override
  void registerAssetType(EditorAssetTypeHandler handler) {
    final plugin = _currentPlugin ?? 'BuiltIn';
    _assetTypes.putIfAbsent(plugin, () => []).add(handler);
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
}

/// One accepted menu item, placed at its effective path: a
/// legacy `Tools/PCG/…` plugin item sits at `Plugins/PCG/…`.
class PluginMenuEntry {
  final String plugin;
  final List<String> _segments;
  final EditorCommand command;
  final EditorMenuItemOptions options;

  /// `Plugins/<Item>` with no group: filed under the plugin's title.
  final bool ungrouped;

  /// Registered under the deprecated `Tools/…` root.
  final bool legacy;

  PluginExtensionRegistry? _registry;

  PluginMenuEntry._(this.plugin, this._segments, this.command, this.options, {this.ungrouped = false, this.legacy = false});

  /// The effective path segments, the top-level menu first.
  List<String> get segments => ungrouped
      ? [_segments.first, _registry?.pluginTitle(plugin) ?? plugin, ..._segments.skip(1)]
      : _segments;

  String get path => segments.join('/');
}

/// A plugin-owned top-level menu.
class PluginMenu {
  final String plugin;
  final EditorMenuDescriptor menu;
  const PluginMenu(this.plugin, this.menu);
}

/// A console command as the host holds it: its help text and handler.
class RegisteredConsoleCommand {
  final String help;
  final void Function(List<String>) handler;
  RegisteredConsoleCommand(this.help, this.handler);
}

/// A slot button as the host holds it: its plugin and its
/// effective id `<plugin>.<id>`.
class RegisteredSlotButton {
  final String plugin;
  final String effectiveId;
  final EditorSlotButton button;
  final int _sequence;
  const RegisteredSlotButton._(this.plugin, this.effectiveId, this.button, this._sequence);
}
