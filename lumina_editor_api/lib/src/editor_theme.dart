import 'package:flutter/foundation.dart' show Listenable;
import 'package:flutter/painting.dart' show Color;
import 'package:flutter/widgets.dart' show Brightness;

/// The editor's active colour theme, read-only, so a
/// plugin's panels and asset editors paint in the same colours as the host.
///
/// Tokens are the keys of the theme JSON — `background`, `card`,
/// `cardHeader`, `rail`, `foreground`, `mutedForeground`, `primary`,
/// `accent`, `destructive`, `warning`, `border`, the `pin*` Blueprint pin
/// colours, `chart1`…`chart5`, … ([tokens] lists them). Listen to it to
/// repaint when the user switches or edits the theme in Editor Preferences →
/// Appearance. A plugin cannot change the theme.
abstract class EditorThemeAccess implements Listenable {
  /// The active theme's name ("Lumina Dark", or a user theme).
  String get name;

  Brightness get brightness;

  /// Every colour token the theme defines.
  Iterable<String> get tokens;

  /// The active value of [token]; throws [ArgumentError] for an unknown one.
  Color color(String token);

  double get radius;
}

/// Implemented by the context a running Lumina Studio hands to
/// `LuminaEditorPlugin.register` (next to `LuminaEditorHostContext`): check
/// `context is EditorThemeHost` and keep [theme] to paint plugin panels in the
/// editor's colours. A bare test context has no theme.
abstract class EditorThemeHost {
  EditorThemeAccess get theme;
}
