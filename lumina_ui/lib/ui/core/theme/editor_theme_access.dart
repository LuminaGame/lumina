import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Brightness, Color;
import 'package:lumina_editor_api/lumina_editor_api.dart';

import 'editor_theme_data.dart';
import 'editor_theme_store.dart';

/// The host's side of `EditorThemeAccess`: plugins read
/// the active editor theme through it and are notified when it changes.
/// Read-only — a plugin cannot switch or edit the theme.
class HostEditorThemeAccess implements EditorThemeAccess {
  const HostEditorThemeAccess();

  ValueListenable<EditorThemeData> get _theme => EditorTheme.listenable;

  @override
  String get name => _theme.value.name;

  @override
  Brightness get brightness => _theme.value.brightness;

  @override
  Iterable<String> get tokens => [for (final t in EditorThemeData.tokens) t.key];

  @override
  Color color(String token) {
    if (!EditorThemeData.tokenKeys.contains(token)) throw ArgumentError.value(token, 'token', 'not an editor theme token');
    return _theme.value.color(token);
  }

  @override
  double get radius => _theme.value.radius;

  @override
  void addListener(VoidCallback listener) => _theme.addListener(listener);

  @override
  void removeListener(VoidCallback listener) => _theme.removeListener(listener);
}
