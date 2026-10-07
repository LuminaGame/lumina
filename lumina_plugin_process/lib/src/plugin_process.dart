import 'dart:async';
import 'dart:io';

import 'dart:typed_data';

import 'package:lumina_core/lumina_core.dart' show Observable;
import 'package:lumina_plugin_protocol/lumina_plugin_protocol.dart';

import 'package:lumina_plugin_process/src/editor_level.dart';
import 'package:lumina_plugin_process/src/mcp/mcp_types.dart';
import 'package:lumina_plugin_process/src/plugin_storage.dart';

/// The part of a plugin that runs in its own process (the "plugin
/// process"), started by the editor from its own executable with
/// `--lumina-plugin-process <name>`. A native crash, a hang or a leak here
/// takes down this process only: the editor marks the plugin stopped,
/// files a plugin crash report and offers Restart.
///
/// A plugin opts in with `"isolation": "process"` in its `.lmplugin` and
/// names this class as its module's `process_class`. It may also keep an
/// in-process `LuminaEditorPlugin` (its UI shell: panels, tabs, asset
/// editors with full Flutter widgets) that talks to this side only through
/// `LuminaEditorContext.processChannel` — the shell holds no native
/// library, starts no child process and does no heavy work; everything
/// that can crash or block lives here.
///
/// Everything registered here is data ([PluginProcessContext]); handlers
/// run in this process. Long jobs report through
/// [PluginProcessContext.progress] / [PluginProcessContext.emit] so the
/// health ping keeps answering; a handler that blocks this isolate on CPU
/// work makes the process look hung (it is restarted after three missed
/// pings), so CPU-heavy work goes to `Isolate.run` here too.
abstract class LuminaPluginProcess {
  /// The plugin's name, the same as its `.lmplugin` `name` and its shell's
  /// `LuminaEditorPlugin.pluginName`.
  String get pluginName;

  /// Registers handlers and contributions. Called once per process run,
  /// after the handshake; contributions are sent to the editor when it
  /// returns.
  FutureOr<void> register(PluginProcessContext context);

  /// The editor opened [project] (also called right after [register] when a
  /// project is already open).
  FutureOr<void> onProjectOpened(EditorProjectInfo project) {}

  /// The project is closing: finish pending writes. Bounded by the host.
  Future<void> onProjectClosing() async {}

  /// The process is about to exit (editor shutdown, plugin disabled,
  /// restart): stop child processes, release native resources.
  Future<void> onShutdown() async {}
}

/// A command shown by the editor (menu item, slot button, slot menu entry)
/// and run in the plugin process.
class PluginProcessCommand {
  const PluginProcessCommand({
    required this.id,
    required this.label,
    required this.run,
    this.icon,
    this.shortcutLabel = '',
    this.canExecute,
  });

  final String id;
  final String label;

  /// The icon as data; a Flutter program builds one from an `IconData` with
  /// `pluginIconOf(icon)` (`lumina_editor_api`).
  final PluginIconSpec? icon;
  final String shortcutLabel;
  final FutureOr<void> Function() run;

  /// When set, the editor asks before showing the command enabled.
  final FutureOr<bool> Function()? canExecute;
}

/// A slot button registered from the plugin process; changes of [state]
/// are sent to the editor. [state] is an [Observable] (an `ObservableValue`
/// to set it from the process; `asObservable()` adapts a Flutter
/// `ValueListenable`).
class PluginProcessSlotButton {
  const PluginProcessSlotButton({
    required this.id,
    required this.slot,
    required this.state,
    required this.command,
    this.order = 0,
    this.menu,
  });

  final String id;

  /// `EditorSlot.name`.
  final String slot;
  final Observable<PluginButtonStateSpec> state;
  final PluginProcessCommand command;
  final int order;
  final List<PluginProcessCommand>? menu;
}

/// A declarative panel registered from the plugin process: the editor renders
/// [initial]; [onEvent] receives the user's actions; the plugin updates the
/// panel with [PluginViewHandle.replace] / [PluginViewHandle.patch].
class PluginProcessViewPanel {
  const PluginProcessViewPanel({
    required this.id,
    required this.title,
    required this.initial,
    required this.onEvent,
    this.icon,
    this.dock = 'left',
    this.defaultAlwaysVisible = false,
  });

  final String id;
  final String title;
  final PluginIconSpec? icon;

  /// `PanelDefaultDock.name`.
  final String dock;
  final bool defaultAlwaysVisible;
  final PluginViewSpec initial;
  final FutureOr<void> Function(PluginViewEvent event, PluginViewHandle view) onEvent;
}

/// Updates one rendered declarative view.
abstract class PluginViewHandle {
  String get viewId;

  /// The spec as last sent.
  PluginViewSpec get current;

  void replace(PluginViewSpec spec);
  void patch(PluginViewPatch patch);
}

/// An importer whose import runs in the plugin process.
class PluginProcessImporter {
  const PluginProcessImporter({
    required this.id,
    required this.extensions,
    required this.description,
    required this.import,
  });

  final String id;
  final List<String> extensions;
  final String description;

  /// Imports [source] into [targetDirectory]; returns the created asset's
  /// path or throws with a message the editor shows.
  final Future<String?> Function(File source, String targetDirectory) import;
}

/// What a plugin process registers with and calls into the editor through.
/// Everything here crosses the process boundary as data.
abstract class PluginProcessContext {
  String get pluginName;

  /// The open project, or null (also delivered to
  /// [LuminaPluginProcess.onProjectOpened]).
  EditorProjectInfo? get project;

  /// This plugin's applied project settings; updates when Project Settings
  /// applies.
  Observable<Map<String, Object?>> get pluginSettings;

  /// The same per-user / per-project JSON store the in-process shell sees.
  PluginStorage get storage;

  /// The folder the plugin is installed in (the one holding its
  /// `.lmplugin`), where it finds files it ships next to its code
  /// (executables, models); null when the editor does not know it. A plugin
  /// process cannot use `Isolate.resolvePackageUri` in a release build.
  String? get pluginDir;

  /// The open level, proxied to the editor: every edit is an undoable editor
  /// transaction there. [PluginLevelAccess.changes] fires on the editor's
  /// `core.levelChanged` notifications; `runTransaction` groups proxied
  /// edits into one undo step on the editor.
  PluginLevelAccess get level;

  /// Answers the shell's `PluginProcessChannel.call(method, args)`.
  /// The handler returns JSON (or a future of it).
  void handle(String method, FutureOr<Object?> Function(Map<String, Object?> args) handler);

  /// Sends an event to the shell (`PluginProcessChannel.events`). [data]
  /// must be JSON.
  void emit(String name, [Object? data]);

  /// Reports progress of [task] (shown by the shell, and in the Plugin
  /// Manager's status for long jobs). [finished] ends the task.
  void progress(String task, {required String step, int? done, int? total, String? message, bool finished = false});

  /// Writes to the editor's log under this plugin's name.
  void log(String message, {String level = 'info'});

  /// Saves an asset into the open project through the editor (thumbnail,
  /// Content Browser refresh), as `LuminaEditorContext.saveAsset`.
  Future<void> saveAsset({required String relativePath, Uint8List? bytes, bool generateThumbnail = true});

  void registerMenu(PluginMenuSpec menu);
  void registerMenuItem(String menuPath, PluginProcessCommand command,
      {int order = 0, String? section, Observable<bool>? checked});
  void registerSlotButton(PluginProcessSlotButton button);
  void registerMcpTool(McpTool tool);
  void registerImporter(PluginProcessImporter importer);
  void registerConsoleCommand(String name, String help, FutureOr<void> Function(List<String> args) handler);
  void registerViewPanel(PluginProcessViewPanel panel);

  /// The handle of a registered declarative view (its spec's id), to update
  /// it outside its own events (after an MCP tool call, a finished job, …);
  /// null for an unknown id.
  PluginViewHandle? view(String viewId);

  /// Shows / hides one of this plugin's panels (shell or declarative) in the
  /// editor.
  Future<void> showPanel(String panelId);
  Future<void> hidePanel(String panelId);

  /// Opens one of the shell's workspace tabs.
  Future<void> openTab(String tabId, {String? title});

  /// Calls an editor MCP tool (as `EditorMcp.callTool`).
  Future<McpToolResult> callMcpTool(String name, Map<String, Object?> arguments);
}
