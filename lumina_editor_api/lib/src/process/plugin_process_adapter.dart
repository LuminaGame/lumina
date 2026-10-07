import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:lumina_core/lumina_core.dart' show AssetType;

import 'package:lumina_editor_api/src/api_types.dart';

/// Runs an unchanged [LuminaEditorPlugin] in a plugin process.
///
/// Its [LuminaEditorPlugin.register] gets a [LuminaEditorHostContext] whose
/// data registrations (menus, menu items, toolbar and slot buttons, console
/// commands, importers, MCP tools) become protocol contributions served in
/// this process, and whose storage, settings, panels, tabs, MCP calls,
/// `saveAsset` and [LuminaEditorHostContext.level] go to the editor through
/// the [PluginProcessContext]. Commands run with a null `BuildContext`.
///
/// What builds widgets cannot leave the editor's process: `registerPanel`,
/// `registerTab`, `registerAssetType`, `registerDetailsCustomization`,
/// `registerProjectSettingsSection`, `build3DViewport` and
/// `buildAssetPicker` throw an [UnsupportedError] that names the API, so
/// registration fails with that message in the editor log. Such a plugin
/// keeps those parts in its in-process UI shell, or describes its panels
/// with [PluginProcessViewPanel].
///
/// Lifecycle: `onProjectOpened` and `onProjectClosing` are forwarded;
/// `onShutdown` calls `onEditorShutdown`, then `unregister`.
class PluginProcessAdapter extends LuminaPluginProcess {
  PluginProcessAdapter(this.plugin);

  final LuminaEditorPlugin plugin;
  PluginAdapterContext? _context;

  @override
  String get pluginName => plugin.pluginName;

  @override
  FutureOr<void> register(PluginProcessContext context) {
    final adapted = _context = PluginAdapterContext(context);
    plugin.register(adapted);
  }

  @override
  void onProjectOpened(EditorProjectInfo project) => plugin.onProjectOpened(project);

  @override
  Future<void> onProjectClosing() => plugin.onProjectClosing();

  @override
  Future<void> onShutdown() async {
    try {
      await plugin.onEditorShutdown();
    } finally {
      final c = _context;
      if (c != null) plugin.unregister(c);
    }
  }
}

/// The [LuminaEditorHostContext] a [PluginProcessAdapter] gives the plugin.
class PluginAdapterContext extends LuminaEditorHostContext {
  PluginAdapterContext(this.process) : _panels = _ProcessPanels(process), _mcp = _ProcessMcp(process);

  final PluginProcessContext process;
  final _ProcessPanels _panels;
  final _ProcessMcp _mcp;
  int _importers = 0;

  static Never _refuse(String api, String why) =>
      throw UnsupportedError('$api needs the editor process: $why. Keep it in the plugin\'s in-process UI shell '
          '(LuminaEditorPlugin) or describe the panel with PluginProcessViewPanel.');

  static PluginProcessCommand commandOf(EditorCommand c) => PluginProcessCommand(
        id: c.id,
        label: c.label,
        icon: c.icon == null ? null : pluginIconOf(c.icon!),
        shortcutLabel: c.shortcutLabel,
        run: () => c.execute(null),
        canExecute: () => c.canExecute(),
      );

  static PluginButtonStateSpec stateOf(EditorButtonState s) => PluginButtonStateSpec(
        icon: pluginIconOf(s.icon),
        tooltip: s.tooltip,
        label: s.label,
        tone: s.tone.name,
        enabled: s.enabled,
        active: s.active,
        badge: s.badge,
        busy: s.busy,
      );

  @override
  EditorLevelAccess get level => process.level.asEditorLevelAccess();

  @override
  void registerMenuItem(String menuPath, EditorCommand command,
      {EditorMenuItemOptions options = const EditorMenuItemOptions()}) {
    process.registerMenuItem(menuPath, commandOf(command),
        order: options.order, section: options.section, checked: options.checked?.asObservable());
  }

  @override
  void registerMenu(EditorMenuDescriptor menu) => process.registerMenu(
      PluginMenuSpec(id: menu.id, title: menu.title, placement: menu.placement.name, order: menu.order));

  @override
  void registerToolbarButton(EditorToolbarButton button) {
    final slot = EditorSlot.values.where((s) => s.name == button.group).firstOrNull ?? EditorSlot.levelToolbarEnd;
    process.registerSlotButton(PluginProcessSlotButton(
      id: button.id,
      slot: slot.name,
      state: ObservableValue(PluginButtonStateSpec(icon: pluginIconOf(button.icon), tooltip: button.tooltip)),
      command: commandOf(button.command),
    ));
  }

  @override
  void registerSlotButton(EditorSlotButton button) {
    process.registerSlotButton(PluginProcessSlotButton(
      id: button.id,
      slot: button.slot.name,
      state: _MappedObservable(button.state, stateOf),
      command: commandOf(button.command),
      order: button.order,
      menu: button.menu?.map(commandOf).toList(),
    ));
  }

  @override
  EditorPanels get panels => _panels;

  @override
  EditorMcp get mcp => _mcp;

  @override
  PluginStorage get storage => process.storage;

  @override
  ValueListenable<Map<String, Object?>> get pluginSettings => process.pluginSettings.asValueListenable();

  @override
  void registerProjectSettingsSection(ProjectSettingsSection section) =>
      _refuse('registerProjectSettingsSection', 'a settings page is a widget builder');

  @override
  void registerPanel(EditorPanelDescriptor panel) =>
      _refuse('registerPanel', 'panel "${panel.id}" is a widget builder');

  @override
  void registerTab(EditorTabDescriptor tab) => _refuse('registerTab', 'tab "${tab.id}" is a widget builder');

  @override
  void openTab(String tabId, {String? title}) {
    process.openTab(tabId, title: title).catchError((Object e) {
      process.log('openTab $tabId failed: $e', level: 'error');
    });
  }

  @override
  void registerAssetType(EditorAssetTypeHandler handler) => _refuse(
      'registerAssetType',
      handler.editorFactory != null
          ? 'asset type "${handler.displayName}" has an editor widget'
          : 'asset type "${handler.displayName}" builds thumbnails in the editor');

  @override
  void registerImporter(EditorImporter importer) {
    final id = 'importer${++_importers}_${importer.extensions.join('_')}';
    process.registerImporter(PluginProcessImporter(
      id: id,
      extensions: importer.extensions,
      description: importer.description,
      import: (source, targetDirectory) async {
        final r = await importer.import(source, ImportContext(targetDirectory: targetDirectory));
        if (!r.success) throw PluginImportError(r.error ?? 'import failed');
        return r.assetPath;
      },
    ));
  }

  @override
  void registerDetailsCustomization(DetailsCustomization c) =>
      _refuse('registerDetailsCustomization', 'a Details section is a widget builder');

  @override
  void registerConsoleCommand(String name, String help, void Function(List<String> args) handler) =>
      process.registerConsoleCommand(name, help, handler);

  @override
  Future<void> saveAsset({required String relativePath, Uint8List? bytes, bool generateThumbnail = true}) =>
      process.saveAsset(relativePath: relativePath, bytes: bytes, generateThumbnail: generateThumbnail);

  @override
  void reportCrash(Object error, StackTrace? stack, {String? plugin, String? context}) {
    final where = context == null || context.isEmpty ? '' : ' while $context';
    process.log('error$where: $error${stack == null ? '' : '\n$stack'}', level: 'error');
  }

  /// The process part has no channel to itself.
  @override
  PluginProcessChannel processChannel(String pluginName) => PluginProcessChannel.detached(pluginName);

  @override
  Widget build3DViewport(BuildContext context, Plugin3DViewportOptions options) =>
      _refuse('build3DViewport', 'a Filament viewport lives in the editor');

  @override
  Widget buildAssetPicker(
    BuildContext context, {
    required String? selectedPath,
    required ValueChanged<String?> onSelected,
    Set<AssetType>? typeFilter,
    String placeholder = 'None',
    bool allowClear = false,
    bool expand = true,
  }) =>
      _refuse('buildAssetPicker', 'the asset picker is an editor widget');
}

/// [EditorPanels] over `host.panels`: [isVisible] and [visibility] follow
/// this plugin's own show / hide calls.
class _ProcessPanels extends EditorPanels {
  _ProcessPanels(this.process);

  final PluginProcessContext process;
  final Map<String, ValueNotifier<bool>> _visible = {};

  ValueNotifier<bool> _of(String id) => _visible.putIfAbsent(id, () => ValueNotifier(false));

  @override
  bool isVisible(String panelId) => _visible[panelId]?.value ?? false;

  @override
  void show(String panelId, {bool focus = true}) {
    _of(panelId).value = true;
    process.showPanel(panelId).catchError((Object e) => process.log('show $panelId failed: $e', level: 'error'));
  }

  @override
  void hide(String panelId) {
    _of(panelId).value = false;
    process.hidePanel(panelId).catchError((Object e) => process.log('hide $panelId failed: $e', level: 'error'));
  }

  @override
  ValueListenable<bool> visibility(String panelId) => _of(panelId);
}

/// [EditorMcp] in a plugin process: [registerTool] contributes the tool,
/// [callTool] calls any editor tool through `host.mcp.call`, [listTools]
/// lists this plugin's own tools.
class _ProcessMcp extends EditorMcp {
  _ProcessMcp(this.process);

  final PluginProcessContext process;
  final List<McpTool> _tools = [];
  final McpChangeSignal _changed = McpChangeSignal();

  @override
  void registerTool(McpTool tool) {
    process.registerMcpTool(tool);
    _tools.add(tool);
    _changed.notify();
  }

  @override
  List<McpTool> listTools({Set<String>? groups}) =>
      [for (final t in _tools) if (groups == null || t.groups.intersection(groups).isNotEmpty) t];

  @override
  Future<McpToolResult> callTool(String name, Map<String, Object?> args, {String? caller}) =>
      process.callMcpTool(name, args);

  @override
  Stream<McpToolCallEvent> get calls => const Stream.empty();

  @override
  McpChangeSignal get toolsChanged => _changed;
}

/// [source] seen through [map], as a pure [Observable].
class _MappedObservable<S, T> extends Observable<T> {
  _MappedObservable(this.source, this.map);

  final ValueListenable<S> source;
  final T Function(S) map;

  @override
  T get value => map(source.value);

  @override
  void addListener(void Function() listener) => source.addListener(listener);

  @override
  void removeListener(void Function() listener) => source.removeListener(listener);
}
