/// Where a code plugin's editor module runs.
///
/// Written in a `.lmplugin` as `"isolation": "in_process" | "process"`
/// (default `in_process`) and, as a per-project override, in a `.lmproject`
/// as `"plugin_isolation": {"<plugin>": "in_process" | "process"}`.
enum PluginIsolation {
  /// Inside the editor process: a hang freezes the editor, a native crash
  /// closes it. The default, and what the built-in plugins use.
  inProcess('in_process'),

  /// The plugin's process part (the module's `process_class`) runs in its
  /// own process, supervised by the editor; its UI shell stays in the editor
  /// and talks to it over a channel.
  process('process');

  const PluginIsolation(this.manifestValue);

  /// The value written in `.lmplugin` / `.lmproject` files.
  final String manifestValue;

  /// The isolation named by [value] (`in_process` or `process`), or null for
  /// anything else.
  static PluginIsolation? tryParse(Object? value) {
    for (final v in values) {
      if (v.manifestValue == value) return v;
    }
    return null;
  }
}
