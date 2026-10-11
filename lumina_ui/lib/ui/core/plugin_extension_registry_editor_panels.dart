part of 'plugin_extension_registry.dart';

/// Where editor panel Widget Blueprints dock: their side panels, tabs and
/// menu items are kept under a key of their own ([editorPanelsKey]), apart
/// from what the owning plugin's shell or process registers, so either
/// registers again without touching the other; a `projectSettings` panel is
/// the owning plugin's own Project Settings section (its values are that
/// plugin's `plugin_settings`).
extension EditorPanelContributions on PluginExtensionRegistry {
  /// The contribution key of [owner]'s editor panels (a plugin name, or
  /// `project`).
  static String editorPanelsKey(String owner) => 'editorPanels@$owner';

  /// Replaces [owner]'s editor panel contributions with what [register]
  /// adds, and [owner]'s editor-panel settings sections (under [plugin]) with
  /// [settingsSections].
  void setEditorPanelContributions(
    String owner,
    void Function(LuminaEditorContext context) register, {
    String? plugin,
    List<ProjectSettingsSection> settingsSections = const [],
  }) {
    _registerProcess(editorPanelsKey(owner), register);
    _replaceEditorPanelSections(owner, plugin, settingsSections);
    processStateChanged(editorPanelsKey(owner));
  }

  /// Removes everything [owner]'s editor panels contributed.
  void removeEditorPanelContributions(String owner) {
    _removeProcessItems(editorPanelsKey(owner));
    _replaceEditorPanelSections(owner, null, const []);
    processStateChanged(editorPanelsKey(owner));
  }

  static const String _sectionPrefix = 'editorPanel:';

  void _replaceEditorPanelSections(String owner, String? plugin, List<ProjectSettingsSection> sections) {
    final marker = '$_sectionPrefix$owner/';
    for (final list in _settingsSections.values) {
      list.removeWhere((s) => s.id.startsWith(marker));
    }
    if (plugin == null || sections.isEmpty) return;
    final list = _settingsSections.putIfAbsent(plugin, () => []);
    for (final s in sections) {
      assert(s.id.startsWith(marker), 'editor panel settings sections are keyed $marker<panel>');
      list
        ..removeWhere((x) => x.id == s.id)
        ..add(s);
    }
  }
}
