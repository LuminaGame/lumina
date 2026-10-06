part of 'plugin_extension_registry.dart';

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
