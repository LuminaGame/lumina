import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:lumina/lumina.dart'; // For LuminaAsset

import 'editor_command.dart';
import 'editor_slot_button.dart';
import 'editor_panels.dart';
import 'mcp/editor_mcp.dart';
import 'plugin_storage.dart';
import 'project_settings_section.dart';
export 'editor_command.dart';
export 'editor_level.dart';
export 'editor_theme.dart';
export 'editor_slot_button.dart';
export 'editor_panels.dart';
export 'mcp/mcp_types.dart';
export 'mcp/editor_mcp.dart';
export 'plugin_storage.dart';
export 'project_settings_section.dart';

/// `LuminaAsset.metadata` key a plugin asset type carries its
/// [EditorAssetTypeHandler.customTypeId] under: an `.lmas` of `AssetType.unknown`
/// with `metadata[kCustomAssetTypeKey] == customTypeId` is that plugin's asset,
/// and the Content Browser opens it with the handler's `editorFactory`.
const String kCustomAssetTypeKey = 'custom_type';

/// `LuminaAsset.metadata` key the host sets on the asset it passes to
/// [EditorAssetTypeHandler.editorFactory]: the absolute path of the `.lmas`,
/// so the editor can write the asset back.
const String kAssetPathMetadataKey = 'asset_path';

/// A static icon button. The host turns it into an
/// [EditorSlotButton]: [group] names an [EditorSlot]
/// (`'levelToolbarAfterBlueprints'`, …), any other group goes to
/// [EditorSlot.levelToolbarEnd]. Prefer [EditorSlotButton] for a label, tone,
/// badge or live state.
class EditorToolbarButton {
  final String id;
  final String tooltip;
  final IconData icon;
  final EditorCommand command;
  final String group;

  const EditorToolbarButton({
    required this.id,
    required this.tooltip,
    required this.icon,
    required this.command,
    required this.group,
  });
}

enum PanelDefaultDock { left, right, bottom, floating }

class EditorPanelDescriptor {
  final String id;
  final String title;
  final IconData icon;
  final Widget Function(BuildContext) builder;
  final PanelDefaultDock defaultDock;

  /// Whether a `PanelDefaultDock.right` panel shows in every editor tab (the
  /// sub-editors included) rather than in the level editor only, until the
  /// user chooses with the dock's pin button or the Window menu. The user's
  /// choice is saved with the editor layout; Reset Layout returns to this.
  final bool defaultAlwaysVisible;

  const EditorPanelDescriptor({
    required this.id,
    required this.title,
    required this.icon,
    required this.builder,
    this.defaultDock = PanelDefaultDock.left,
    this.defaultAlwaysVisible = false,
  });
}

/// A full-page workspace editor tab a plugin provides.
class EditorTabDescriptor {
  final String id;
  final String title;
  final IconData icon;
  final Widget Function(BuildContext context) builder;

  const EditorTabDescriptor({
    required this.id,
    required this.title,
    this.icon = const IconData(0xe255, fontFamily: 'MaterialIcons'),
    required this.builder,
  });
}

/// Configuration for rendering a Filament 3D viewport inside a plugin editor.
class Plugin3DViewportOptions {
  final String title;
  final String? meshPath;
  final Uint8List? glbBytes;
  final Map<String, List<double>>? jointLocalPose;
  final Widget? overlayHUD;
  final double? cameraDistance;

  const Plugin3DViewportOptions({
    this.title = 'Viewport',
    this.meshPath,
    this.glbBytes,
    this.jointLocalPose,
    this.overlayHUD,
    this.cameraDistance,
  });
}

class EditorAssetTypeHandler {
  final AssetType? assetType;
  final String? customTypeId;
  final String displayName;
  final IconData icon;
  final Future<Uint8List?> Function(LuminaAsset) thumbnailBuilder;
  final Widget Function(BuildContext, LuminaAsset)? editorFactory;

  const EditorAssetTypeHandler({
    this.assetType,
    this.customTypeId,
    required this.displayName,
    required this.icon,
    required this.thumbnailBuilder,
    this.editorFactory,
  }) : assert(assetType != null || customTypeId != null);
}

class ImportContext {
  final String targetDirectory;
  const ImportContext({required this.targetDirectory});
}

class ImportResult {
  final bool success;
  final String? assetPath;
  final String? error;
  const ImportResult.success(this.assetPath) : success = true, error = null;
  const ImportResult.failure(this.error) : success = false, assetPath = null;
}

class EditorImporter {
  final List<String> extensions;
  final String description;
  final Future<ImportResult> Function(File source, ImportContext ctx) import;

  const EditorImporter({
    required this.extensions,
    required this.description,
    required this.import,
  });
}

class DetailsTarget {
  final Object target;
  final void Function(String name, dynamic value) setProperty;

  const DetailsTarget({
    required this.target,
    required this.setProperty,
  });
}

class DetailsCustomization {
  final String targetTypeId;
  final String sectionTitle;
  final Widget Function(BuildContext, DetailsTarget) builder;

  const DetailsCustomization({
    required this.targetTypeId,
    required this.sectionTitle,
    required this.builder,
  });
}

/// How a plugin menu item sits in its (sub)menu.
class EditorMenuItemOptions {
  /// Sorts items within one (sub)menu; lower first, ties keep registration
  /// order.
  final int order;

  /// Items of different sections are separated by a divider; sections appear
  /// in the order their first item sorts.
  final String? section;

  /// When set, the item shows a check mark that follows the notifier.
  final ValueListenable<bool>? checked;

  const EditorMenuItemOptions({this.order = 0, this.section, this.checked});
}

/// Where a plugin-owned top-level menu goes in the menu bar.
enum EditorMenuPlacement {
  /// After the Plugins menu, before Window.
  beforeWindow,

  /// After Window, before Help.
  beforeHelp,
}

/// A top-level menu a plugin owns. Fill it with
/// `registerMenuItem('<title>/…', command)`. Built-in titles (File … Help,
/// Plugins) and another plugin's title are refused.
class EditorMenuDescriptor {
  final String id;
  final String title;
  final EditorMenuPlacement placement;

  /// Sorts plugin menus sharing a placement.
  final int order;

  const EditorMenuDescriptor({
    required this.id,
    required this.title,
    this.placement = EditorMenuPlacement.beforeWindow,
    this.order = 0,
  });
}

abstract class LuminaEditorContext {
  /// Adds [command] to the menu bar at [menuPath]. A plugin registers under
  /// `Plugins/<Group>/…` (the Plugins menu) or under the title of a menu it
  /// registered with [registerMenu]; built-in menus (File, Edit, View, Build,
  /// Debug, Window, Help) refuse plugin items. Legacy `Tools/…` paths are
  /// moved to `Plugins/…` with a deprecation warning.
  void registerMenuItem(String menuPath, EditorCommand command,
      {EditorMenuItemOptions options = const EditorMenuItemOptions()});

  /// Registers a top-level menu the plugin owns.
  void registerMenu(EditorMenuDescriptor menu);
  void registerToolbarButton(EditorToolbarButton button);

  /// Puts a button with live state in a named slot of the level toolbar or
  /// the status bar.
  void registerSlotButton(EditorSlotButton button);

  /// Opens, closes and observes the plugin's panels. Safe to
  /// keep from `register`.
  EditorPanels get panels;

  /// The editor's MCP tools: register this plugin's tools, list
  /// and call any tool in process. Safe to keep from `register`.
  EditorMcp get mcp;

  /// This plugin's JSON store, per user and per open project.
  PluginStorage get storage;

  /// Adds a page to Project Settings ▸ Plugins.
  void registerProjectSettingsSection(ProjectSettingsSection section);

  /// This plugin's applied project settings (`.lmproject`
  /// `plugin_settings.<pluginName>`); updates when Project Settings applies.
  ValueListenable<Map<String, Object?>> get pluginSettings;
  void registerPanel(EditorPanelDescriptor panel);

  /// Registers a full-page workspace editor tab (opened via [openTab]).
  void registerTab(EditorTabDescriptor tab);

  /// Opens the workspace editor tab with [tabId].
  void openTab(String tabId, {String? title});

  void registerAssetType(EditorAssetTypeHandler handler);
  void registerImporter(EditorImporter importer);
  void registerDetailsCustomization(DetailsCustomization c);
  void registerConsoleCommand(String name, String help, void Function(List<String> args) handler);

  /// Saves an asset to the active project at [relativePath] (e.g.
  /// `contents/animations/SK_MH_2/prpr.lmas`), optionally writing [bytes] if
  /// provided, generates a thumbnail when [generateThumbnail] is true, and
  /// notifies the Content Browser to refresh.
  Future<void> saveAsset({
    required String relativePath,
    Uint8List? bytes,
    bool generateThumbnail = true,
  }) async {}
}

abstract class LuminaEditorPlugin {
  String get pluginName;

  /// Adds this plugin's contributions to [context]. The editor's layout is
  /// loaded first, so [LuminaEditorContext.panels] reports the saved
  /// visibility here. If it throws, the editor drops what it registered,
  /// logs the error under [pluginName] and shows it in the Plugin Manager;
  /// the other plugins and the editor go on.
  void register(LuminaEditorContext context);

  /// The last call a plugin gets, after [onEditorShutdown].
  void unregister(LuminaEditorContext context) {}

  /// The editor has [project] open; called after [register].
  void onProjectOpened(EditorProjectInfo project) {}

  /// The project is closing: finish pending writes. Bounded by a
  /// host timeout.
  Future<void> onProjectClosing() async {}

  /// The editor is exiting: stop child processes. Bounded by a
  /// host timeout; not called after a crash.
  Future<void> onEditorShutdown() async {}
}
