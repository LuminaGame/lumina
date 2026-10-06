import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lumina_plugin_protocol/lumina_plugin_protocol.dart';

import '../mcp/mcp_types.dart';
import '../plugin_storage.dart';
import 'level_proxy.dart';
import 'plugin_process.dart';

/// A console command registered from a plugin process.
class PluginProcessConsoleCommand {
  const PluginProcessConsoleCommand(this.name, this.help, this.handler);
  final String name;
  final String help;
  final FutureOr<void> Function(List<String> args) handler;
}

/// The [PluginProcessContext] of a running plugin process: keeps what the
/// plugin registers (served by the `core.*` handlers) and sends its calls
/// into the editor over [connection].
///
/// Contributions are collected until [contributions] is sent with
/// `host.register`; registering one after that is a [StateError] (the editor
/// takes them once per process run). [handle] works at any time.
class ConnectedPluginProcessContext implements PluginProcessContext {
  ConnectedPluginProcessContext({
    required this.connection,
    required this.pluginName,
    required EditorProjectInfo? project,
    required Map<String, Object?> settings,
    required Directory userDir,
    required Directory? projectStoreDir,
    this.pluginDir,
  })  : _project = project, // ignore: prefer_initializing_formals
        _settings = ValueNotifier(Map.unmodifiable(settings)),
        _storage = PluginStorage(userDir: userDir, projectDir: projectStoreDir) {
    _level = PluginLevelProxy(connection, onError: (m) => log(m, level: 'error'));
  }

  final PluginConnection connection;

  @override
  final String pluginName;

  @override
  final String? pluginDir;

  EditorProjectInfo? _project;
  final ValueNotifier<Map<String, Object?>> _settings;
  PluginStorage _storage;
  late final PluginLevelProxy _level;

  /// Timeout of a proxied call that may run a while (an MCP tool, a save).
  static const Duration longTimeout = Duration(seconds: 60);

  final Map<String, FutureOr<Object?> Function(Map<String, Object?>)> handlers = {};
  final Map<String, PluginProcessCommand> commands = {};
  final List<PluginMenuSpec> _menus = [];
  final List<(PluginMenuItemSpec, ValueListenable<bool>?)> _menuItems = [];
  final List<PluginProcessSlotButton> slotButtons = [];
  final Map<String, McpTool> mcpTools = {};
  final Map<String, PluginProcessImporter> importers = {};
  final Map<String, PluginProcessConsoleCommand> consoleCommands = {};
  final Map<String, PluginProcessViewPanel> viewPanels = {};
  final Map<String, ProcessViewHandle> views = {};
  final List<void Function()> _unwatch = [];
  bool _sent = false;

  @override
  EditorProjectInfo? get project => _project;

  @override
  ValueListenable<Map<String, Object?>> get pluginSettings => _settings;

  @override
  PluginStorage get storage => _storage;

  @override
  PluginLevelProxy get level => _level;

  // --- editor → process state -----------------------------------------------

  void projectOpened(EditorProjectInfo project, {String? storeDir}) {
    _project = project;
    _storage = PluginStorage(
      userDir: _storage.userDir,
      projectDir: Directory(storeDir ?? '${project.dir}/.lumina/plugins/$pluginName'),
    );
  }

  void projectClosed() {
    _project = null;
    _storage = PluginStorage(userDir: _storage.userDir);
  }

  void settingsChanged(Map<String, Object?> settings) => _settings.value = Map.unmodifiable(settings);

  // --- registration -----------------------------------------------------------

  void _checkOpen(String what) {
    if (_sent) {
      throw StateError('$pluginName: $what after register() returned; contributions are sent once per process run');
    }
  }

  void _addCommand(PluginProcessCommand command) => commands[command.id] = command;

  static PluginCommandSpec commandSpec(PluginProcessCommand c) => PluginCommandSpec(
        id: c.id,
        label: c.label,
        icon: c.icon,
        shortcutLabel: c.shortcutLabel,
        dynamicEnablement: c.canExecute != null,
      );

  @override
  void handle(String method, FutureOr<Object?> Function(Map<String, Object?> args) handler) =>
      handlers[method] = handler;

  @override
  void registerMenu(PluginMenuSpec menu) {
    _checkOpen('registerMenu');
    _menus.add(menu);
  }

  @override
  void registerMenuItem(String menuPath, PluginProcessCommand command,
      {int order = 0, String? section, ValueListenable<bool>? checked}) {
    _checkOpen('registerMenuItem');
    _addCommand(command);
    _menuItems.add((
      PluginMenuItemSpec(
        path: menuPath,
        command: commandSpec(command),
        order: order,
        section: section,
        checked: checked?.value,
      ),
      checked,
    ));
  }

  @override
  void registerSlotButton(PluginProcessSlotButton button) {
    _checkOpen('registerSlotButton');
    if (slotButtons.any((b) => b.id == button.id)) {
      throw ArgumentError.value(button.id, 'id', 'a slot button with this id is already registered');
    }
    _addCommand(button.command);
    for (final c in button.menu ?? const <PluginProcessCommand>[]) {
      _addCommand(c);
    }
    slotButtons.add(button);
  }

  @override
  void registerMcpTool(McpTool tool) {
    _checkOpen('registerMcpTool');
    mcpTools[tool.name] = tool;
  }

  @override
  void registerImporter(PluginProcessImporter importer) {
    _checkOpen('registerImporter');
    importers[importer.id] = importer;
  }

  @override
  void registerConsoleCommand(String name, String help, FutureOr<void> Function(List<String> args) handler) {
    _checkOpen('registerConsoleCommand');
    consoleCommands[name] = PluginProcessConsoleCommand(name, help, handler);
  }

  @override
  void registerViewPanel(PluginProcessViewPanel panel) {
    _checkOpen('registerViewPanel');
    viewPanels[panel.id] = panel;
    views[panel.initial.id] = ProcessViewHandle(connection, panel);
  }

  @override
  PluginViewHandle? view(String viewId) => views[viewId];

  /// Everything registered, as `host.register` sends it; from now on
  /// registrations are refused.
  PluginContributions contributions() {
    _sent = true;
    return PluginContributions(
      menus: List.of(_menus),
      menuItems: [for (final m in _menuItems) m.$1],
      slotButtons: [
        for (final b in slotButtons)
          PluginSlotButtonSpec(
            id: b.id,
            slot: b.slot,
            state: b.state.value,
            command: commandSpec(b.command),
            order: b.order,
            menu: b.menu == null ? null : [for (final c in b.menu!) commandSpec(c)],
          ),
      ],
      mcpTools: [
        for (final t in mcpTools.values)
          PluginMcpToolSpec(
            name: t.name,
            title: t.title ?? t.name,
            description: t.description,
            inputSchema: t.inputSchema,
            risk: t.risk.name,
            groups: t.groups.toList(),
            idempotent: t.idempotent ?? false,
            openWorld: t.openWorld ?? false,
            removesContent: t.removesContent,
          ),
      ],
      importers: [
        for (final i in importers.values)
          PluginImporterSpec(id: i.id, extensions: i.extensions, description: i.description),
      ],
      consoleCommands: [for (final c in consoleCommands.values) PluginConsoleCommandSpec(name: c.name, help: c.help)],
      panels: [
        for (final p in viewPanels.values)
          PluginViewPanelSpec(
            id: p.id,
            title: p.title,
            icon: p.icon,
            dock: p.dock,
            defaultAlwaysVisible: p.defaultAlwaysVisible,
            view: p.initial,
          ),
      ],
    );
  }

  /// Sends slot button states and menu check marks as they change
  /// (`host.slotState`, `host.menuChecked`).
  void watchLiveState() {
    for (final b in slotButtons) {
      void send() => connection.notify(PluginMethods.slotState, {'id': b.id, 'state': b.state.value.toJson()});
      b.state.addListener(send);
      _unwatch.add(() => b.state.removeListener(send));
    }
    for (final (item, checked) in _menuItems) {
      if (checked == null) continue;
      void send() => connection.notify(PluginMethods.menuChecked, {'path': item.path, 'checked': checked.value});
      checked.addListener(send);
      _unwatch.add(() => checked.removeListener(send));
    }
  }

  void dispose() {
    for (final u in _unwatch) {
      u();
    }
    _unwatch.clear();
    _level.dispose();
  }

  // --- process → editor -------------------------------------------------------

  @override
  void emit(String name, [Object? data]) => connection.notify(PluginMethods.event, {'name': name, 'data': data});

  @override
  void progress(String task, {required String step, int? done, int? total, String? message, bool finished = false}) =>
      connection.notify(PluginMethods.progress, {
        'task': task,
        'step': step,
        'done': done,
        'total': total,
        'message': message,
        'finished': finished,
      });

  @override
  void log(String message, {String level = 'info'}) =>
      connection.notify(PluginMethods.log, {'level': level, 'message': message});

  @override
  Future<void> saveAsset({required String relativePath, Uint8List? bytes, bool generateThumbnail = true}) async {
    await connection.request(
      PluginMethods.saveAsset,
      {
        'relativePath': relativePath,
        if (bytes != null) 'bytesBase64': base64Encode(bytes),
        'generateThumbnail': generateThumbnail,
      },
      longTimeout,
    );
  }

  @override
  Future<void> showPanel(String panelId) async {
    await connection.request(PluginMethods.panels, {'op': 'show', 'panelId': panelId});
  }

  @override
  Future<void> hidePanel(String panelId) async {
    await connection.request(PluginMethods.panels, {'op': 'hide', 'panelId': panelId});
  }

  /// Whether the editor shows [panelId] now.
  Future<bool> isPanelVisible(String panelId) async =>
      await connection.request(PluginMethods.panels, {'op': 'isVisible', 'panelId': panelId}) == true;

  @override
  Future<void> openTab(String tabId, {String? title}) async {
    await connection.request(PluginMethods.tabs, {'op': 'openTab', 'tabId': tabId, 'title': ?title});
  }

  @override
  Future<McpToolResult> callMcpTool(String name, Map<String, Object?> arguments) async {
    final r = await connection.request(PluginMethods.mcpCall, {'tool': name, 'arguments': arguments}, longTimeout);
    if (r is! Map) return McpToolResult.error('$name returned no result');
    return McpToolResult.fromJson(r.cast());
  }
}

/// The [PluginViewHandle] of one declarative panel: [replace] and [patch]
/// keep [current] and send `host.view`.
class ProcessViewHandle implements PluginViewHandle {
  ProcessViewHandle(this._connection, this.panel) : _current = panel.initial;

  final PluginConnection _connection;
  final PluginProcessViewPanel panel;
  PluginViewSpec _current;

  @override
  String get viewId => panel.initial.id;

  @override
  PluginViewSpec get current => _current;

  @override
  void replace(PluginViewSpec spec) {
    _current = spec;
    _connection.notify(PluginMethods.view, {'viewId': viewId, 'spec': spec.toJson()});
  }

  @override
  void patch(PluginViewPatch patch) {
    _current = _current.apply(patch);
    _connection.notify(PluginMethods.view, {'viewId': viewId, 'patch': patch.toJson()});
  }
}
