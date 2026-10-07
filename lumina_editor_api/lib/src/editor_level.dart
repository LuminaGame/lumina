import 'package:flutter/widgets.dart';
import 'package:lumina/lumina.dart' show AssetType;

import 'package:lumina_editor_api/src/api_types.dart';

/// The open level, as the host exposes it to plugins: the level operations
/// (`EditorLevelOperations`, pure Dart in `lumina_plugin_process`) plus a
/// Flutter [changes] listenable for widgets.
///
/// Every edit is an undoable editor transaction and marks the level dirty,
/// exactly like the same edit made through the Outliner or the Details
/// panel; nothing here bypasses the host's transaction, dirty-flag or
/// auto-save path. A plugin process sees the same level as a
/// [PluginLevelAccess]; [PluginLevelAccessAsEditor.asEditorLevelAccess] and
/// [EditorLevelAccessAsPlugin.asPluginLevelAccess] convert between the two.
abstract class EditorLevelAccess implements EditorLevelOperations {
  /// Notifies after any change to the level (actors, selection, save).
  Listenable get changes;
}

/// See [EditorLevelAccess].
extension PluginLevelAccessAsEditor on PluginLevelAccess {
  /// This level with a Flutter [EditorLevelAccess.changes]; the same level
  /// always gives the same view.
  EditorLevelAccess asEditorLevelAccess() {
    final self = this;
    if (self is _PluginLevelView) return self.level;
    return _editorViews[this] ??= _EditorLevelView(this);
  }
}

/// See [EditorLevelAccess].
extension EditorLevelAccessAsPlugin on EditorLevelAccess {
  /// This level with a pure [PluginLevelAccess.changes]; the same level
  /// always gives the same view.
  PluginLevelAccess asPluginLevelAccess() {
    final self = this;
    if (self is _EditorLevelView) return self.level;
    return _pluginViews[this] ??= _PluginLevelView(this);
  }
}

final Expando<EditorLevelAccess> _editorViews = Expando('asEditorLevelAccess');
final Expando<PluginLevelAccess> _pluginViews = Expando('asPluginLevelAccess');

/// Forwards every operation to [level]; only `changes` differs.
abstract class _LevelView implements EditorLevelOperations {
  EditorLevelOperations get target;

  @override
  String get projectDirPath => target.projectDirPath;

  @override
  String get activeLevelPath => target.activeLevelPath;

  @override
  List<EditorActorSnapshot> get actors => target.actors;

  @override
  List<String> get selectedActorIds => target.selectedActorIds;

  @override
  Future<List<String>> addActors(List<EditorActorSpec> specs, {String? label}) =>
      target.addActors(specs, label: label);

  @override
  Future<T> runTransaction<T>(String label, Future<T> Function() body) => target.runTransaction(label, body);

  @override
  String? get undoTopLabel => target.undoTopLabel;

  @override
  bool undoIfTop(String label) => target.undoIfTop(label);

  @override
  void removeActors(Iterable<String> ids, {String? label}) => target.removeActors(ids, label: label);

  @override
  void setComponentProperty(String actorId, String componentType, String propertyId, Object? value, {String? label}) =>
      target.setComponentProperty(actorId, componentType, propertyId, value, label: label);

  @override
  void selectActors(Iterable<String> ids) => target.selectActors(ids);

  @override
  Future<void> saveLevel() => target.saveLevel();

  @override
  void openAssetEditor(String assetPath) => target.openAssetEditor(assetPath);

  @override
  Future<bool> openLevel(String relativePath, {bool show = true}) => target.openLevel(relativePath, show: show);

  @override
  void log(String message, {String level = 'info', String source = 'Plugin'}) =>
      target.log(message, level: level, source: source);
}

class _EditorLevelView extends _LevelView implements EditorLevelAccess {
  _EditorLevelView(this.level);

  final PluginLevelAccess level;

  @override
  EditorLevelOperations get target => level;

  @override
  Listenable get changes => level.changes.asListenable();
}

class _PluginLevelView extends _LevelView implements PluginLevelAccess {
  _PluginLevelView(this.level);

  final EditorLevelAccess level;

  @override
  EditorLevelOperations get target => level;

  @override
  ChangeSignal get changes => level.changes.asChangeSignal();
}

/// The context a running Lumina Studio hands to [LuminaEditorPlugin.register]:
/// the seven extension points plus the open level.
///
/// A bare [LuminaEditorContext] (a plugin's own unit test, a registration
/// smoke) has no level, so plugins that edit the level check
/// `context is LuminaEditorHostContext` and keep the [level] for later.
abstract class LuminaEditorHostContext implements LuminaEditorContext {
  EditorLevelAccess get level;

  /// Builds a real Filament 3D viewport for a plugin editor.
  Widget build3DViewport(BuildContext context, Plugin3DViewportOptions options);

  /// Builds a standard searchable asset picker combobox with thumbnail preview,
  /// type filtering, recent assets, and Content Browser browse integration.
  Widget buildAssetPicker(
    BuildContext context, {
    required String? selectedPath,
    required ValueChanged<String?> onSelected,
    Set<AssetType>? typeFilter,
    String placeholder = 'None',
    bool allowClear = false,
    bool expand = true,
  });
}

/// Standard searchable asset picker combobox for plugins.
/// Delegates to [LuminaEditorHostContext.buildAssetPicker] to render
/// the editor's live asset catalog with thumbnails and type filtering.
class EditorAssetPicker extends StatelessWidget {
  final LuminaEditorHostContext hostContext;
  final String? selectedPath;
  final ValueChanged<String?> onSelected;
  final Set<AssetType>? typeFilter;
  final String placeholder;
  final bool allowClear;
  final bool expand;

  const EditorAssetPicker({
    super.key,
    required this.hostContext,
    required this.selectedPath,
    required this.onSelected,
    this.typeFilter,
    this.placeholder = 'None',
    this.allowClear = false,
    this.expand = true,
  });

  @override
  Widget build(BuildContext context) {
    return hostContext.buildAssetPicker(
      context,
      selectedPath: selectedPath,
      onSelected: onSelected,
      typeFilter: typeFilter,
      placeholder: placeholder,
      allowClear: allowClear,
      expand: expand,
    );
  }
}
