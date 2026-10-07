import 'package:lumina_core/lumina_core.dart';

/// The project's per-plugin isolation override for the editor:
/// `.lmproject` `plugin_isolation: {"<plugin>": "in_process"}` runs that
/// isolated plugin's process part inside the editor (for debugging it with
/// the editor's debugger); no entry keeps the manifest's choice.
abstract final class PluginIsolationOverrides {
  /// The plugins [project] forces into the editor process.
  static Set<String> inEditorProcess(LuminaProject project) => {
        for (final e in project.pluginIsolation.entries)
          if (e.value == PluginIsolation.inProcess) e.key,
      };

  /// Whether [project] forces [plugin] into the editor process.
  static bool runsInEditorProcess(LuminaProject project, String plugin) =>
      project.pluginIsolation[plugin] == PluginIsolation.inProcess;

  /// [project] with [plugin] forced in process ([inEditorProcess]) or back
  /// to its manifest's isolation.
  static LuminaProject withInEditorProcess(LuminaProject project, String plugin, bool inEditorProcess) {
    final overrides = Map<String, PluginIsolation>.from(project.pluginIsolation)..remove(plugin);
    if (inEditorProcess) overrides[plugin] = PluginIsolation.inProcess;
    return project.copyWith(pluginIsolation: overrides);
  }
}
