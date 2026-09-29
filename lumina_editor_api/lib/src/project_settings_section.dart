import 'dart:convert';

import 'package:flutter/widgets.dart';

/// A page a plugin adds to Project Settings ▸ Plugins. Its
/// values live in the project manifest under
/// `plugin_settings.<pluginName>` and go through the settings screen's
/// Apply / Revert.
@immutable
class ProjectSettingsSection {
  const ProjectSettingsSection({
    required this.id,
    required this.title,
    required this.builder,
    this.icon,
    this.keywords = const [],
  });

  /// Unique within the plugin (e.g. `miniai`).
  final String id;

  /// The row in the category list (e.g. "AI Assistant").
  final String title;
  final IconData? icon;

  /// Extra words the settings search matches.
  final List<String> keywords;

  /// The page; edits go through [PluginSettingsHandle.set].
  final Widget Function(BuildContext context, PluginSettingsHandle settings) builder;
}

/// The plugin's settings as the Project Settings screen edits them (the
/// unsaved working copy).
abstract class PluginSettingsHandle {
  Map<String, Object?> get values;

  T? get<T>(String key) {
    final v = values[key];
    return v is T ? v : null;
  }

  /// Sets [key] to a JSON value; null removes it. A key that looks like a
  /// secret is refused: `.lmproject` is shared with the team.
  void set(String key, Object? value);

  /// Fires after every [set].
  Listenable get changes;

  static final RegExp _secret = RegExp(r'key|secret|token|password|credential', caseSensitive: false);

  /// Throws when [key] cannot go into the project manifest.
  static void checkKey(String key, Object? value) {
    if (key.isEmpty) throw ArgumentError.value(key, 'key', 'empty');
    if (_secret.hasMatch(key)) {
      throw ArgumentError.value(key, 'key', 'looks like a secret; secrets never go into the project file (keep them in PluginStorage)');
    }
    try {
      jsonEncode(value);
    } on JsonUnsupportedObjectError {
      throw ArgumentError.value(value, key, 'not a JSON value');
    }
  }
}

/// A [PluginSettingsHandle] over a plain map (tests, detached contexts).
class MapPluginSettingsHandle extends PluginSettingsHandle {
  MapPluginSettingsHandle([Map<String, Object?>? initial]) : _values = {...?initial};

  final Map<String, Object?> _values;
  final ChangeNotifier _changes = ChangeNotifier();

  @override
  Map<String, Object?> get values => Map.unmodifiable(_values);

  @override
  void set(String key, Object? value) {
    PluginSettingsHandle.checkKey(key, value);
    if (value == null) {
      _values.remove(key);
    } else {
      _values[key] = value;
    }
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    _changes.notifyListeners();
  }

  @override
  Listenable get changes => _changes;
}
