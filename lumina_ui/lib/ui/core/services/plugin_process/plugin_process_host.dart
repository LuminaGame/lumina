
import 'package:flutter/foundation.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart';

/// What a [PluginProcessSupervisor] needs from the editor: where a plugin
/// process's requests land (level, assets, panels, tabs, MCP, log) and where
/// its contributions are registered. `PluginExtensionRegistry` implements it.
abstract interface class PluginProcessHost {
  /// Writes [message] to the editor's Output Log under [plugin].
  void logPlugin(String plugin, String message, {String level = 'info'});

  /// The open level, or null in a bare registration context.
  EditorLevelAccess? get levelAccess;

  EditorPanels get panels;

  void openTab(String tabId, {String? title});

  Future<void> saveAsset({required String relativePath, Uint8List? bytes, bool generateThumbnail = true});

  /// [plugin]'s view of the editor's MCP tools.
  EditorMcp mcpFor(String plugin);

  /// [plugin]'s per-user and per-project store (the directories the hello
  /// answer hands the process).
  PluginStorage storageFor(String plugin);

  /// [plugin]'s applied project settings.
  ValueListenable<Map<String, Object?>> settingsFor(String plugin);

  /// The open project, or null.
  EditorProjectInfo? get projectInfo;

  /// Registers what [plugin]'s process contributes: [register] runs against
  /// the editor's registration context; what it adds replaces the previous
  /// process registration of [plugin] and leaves its in-process shell's
  /// contributions alone.
  void registerProcessContributions(String plugin, void Function(LuminaEditorContext context) register);

  /// Drops what [plugin]'s process registered (the plugin was disabled or
  /// switched mode).
  void removeProcessContributions(String plugin);

  /// [plugin]'s process changed state: menus, slot buttons and panels that
  /// show its availability rebuild.
  void processStateChanged(String plugin);
}
