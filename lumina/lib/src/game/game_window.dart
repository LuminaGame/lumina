import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:lumina_core/lumina_core.dart' show ObservableValue;

import 'package:lumina/src/utility/lumina_platform.dart';

/// How the game's window is shown on a desktop.
///
/// [borderlessFullscreen] is the fullscreen modern games use: a window
/// without title bar or borders that covers the whole monitor it is on
/// (taskbar included) at the monitor's native resolution. There is no
/// exclusive mode: Filament renders into a texture that Flutter's compositor
/// presents, so the game never owns a swap chain that could take the display
/// exclusively; a borderless window covering the monitor is presented by the
/// compositor without extra copies.
enum LuminaWindowMode {
  windowed('windowed', 'Windowed'),
  borderlessFullscreen('borderless_fullscreen', 'Borderless Fullscreen');

  const LuminaWindowMode(this.id, this.label);

  /// The value stored in the user settings file and sent to the runner.
  final String id;

  /// What Blueprint nodes and menus show.
  final String label;

  /// The mode [text] names: an [id], a [label] or `fullscreen` / `borderless`,
  /// ignoring case, spaces, `_` and `-`. Null for anything else.
  static LuminaWindowMode? parse(String text) {
    final key = text.toLowerCase().replaceAll(RegExp(r'[\s_\-]'), '');
    return switch (key) {
      'windowed' || 'window' => LuminaWindowMode.windowed,
      'borderlessfullscreen' || 'fullscreen' || 'borderless' || 'fullscreenwindowed' => LuminaWindowMode.borderlessFullscreen,
      _ => null,
    };
  }
}

/// What changes the real window: the generated runner's `lumina/window`
/// channel (lumina_widgets installs it in `LuminaWidgets.ensureInitialized`).
abstract interface class LuminaWindowModeBackend {
  /// The window's current mode, or null when the runner has no window-mode
  /// support (a runner generated before it).
  Future<LuminaWindowMode?> getMode();

  /// Shows the window in [mode]; whether the runner applied it.
  Future<bool> setMode(LuminaWindowMode mode);

  /// Called when the runner changed the mode itself (Alt+Enter, F11).
  set onModeChanged(void Function(LuminaWindowMode mode)? listener);
}

/// The game window's mode (windowed or borderless fullscreen), what the
/// Blueprint nodes `Set Fullscreen Mode`, `Get Fullscreen Mode` and
/// `Toggle Fullscreen` drive.
///
/// The generated runner starts the window in the project's
/// `Start Fullscreen` mode and toggles it on Alt+Enter and F11; the generated
/// `main()` calls [restore] before the first frame, which re-applies the mode
/// the player chose last time (kept under `window_mode` in the per-player
/// `user_settings.json`, see [settingsFileFor]). Without a [backend] (the
/// editor's Play-In-Editor, the web, tests) the mode is only recorded.
abstract final class LuminaGameWindow {
  /// The runner's window, set by lumina_widgets on desktop.
  static LuminaWindowModeBackend? backend;

  /// The current mode.
  static final ObservableValue<LuminaWindowMode> mode = ObservableValue(LuminaWindowMode.windowed);

  /// Where the player's choice is kept; null keeps nothing (Play-In-Editor).
  static String? settingsFilePath;

  static Future<void> _pendingWrite = Future<void>.value();

  /// Completes when the last mode change and its settings write are done.
  static Future<void> get pendingWrite => _pendingWrite;

  /// The key under which the mode is stored in the settings file.
  static const String settingsKey = 'window_mode';

  /// The per-player settings file next to a game's [saveGamesDirectory]
  /// (`<app support>/<game>/SaveGames` → `<app support>/<game>/user_settings.json`).
  static String settingsFileFor(String saveGamesDirectory) {
    final trimmed = saveGamesDirectory.replaceAll(RegExp(r'[\\/]+$'), '');
    final cut = trimmed.lastIndexOf(RegExp(r'[\\/]'));
    if (cut <= 0) return '$trimmed/user_settings.json';
    return '${trimmed.substring(0, cut)}${trimmed[cut]}user_settings.json';
  }

  /// Applies the player's saved mode, or [startMode] (Project Settings >
  /// Start Fullscreen) when they never chose one, and listens for the
  /// runner's own toggles. Returns the mode the window is in.
  static Future<LuminaWindowMode> restore({
    LuminaWindowMode startMode = LuminaWindowMode.windowed,
    String? settingsFilePath,
  }) async {
    if (settingsFilePath != null) LuminaGameWindow.settingsFilePath = settingsFilePath;
    final target = await _readSaved() ?? startMode;
    final b = backend;
    if (b == null) {
      mode.value = target;
      return target;
    }
    b.onModeChanged = (m) {
      mode.value = m;
      _pendingWrite = _save(m);
    };
    try {
      final current = await b.getMode();
      if (current == null) {
        // A runner without window-mode support: leave the window as it is.
        return mode.value;
      }
      mode.value = current;
      if (current != target && await b.setMode(target)) mode.value = target;
    } on Object catch (e) {
      developer.log('Window mode could not be restored: $e', name: 'LuminaGameWindow');
    }
    return mode.value;
  }

  /// Shows the window in [next] and keeps it as the player's choice. Returns
  /// whether a runner applied it (false without one; the mode is recorded).
  static Future<bool> setMode(LuminaWindowMode next) {
    mode.value = next;
    final done = Completer<bool>();
    _pendingWrite = () async {
      var applied = false;
      final b = backend;
      if (b != null) {
        try {
          applied = await b.setMode(next);
        } on Object catch (e) {
          developer.log('Window mode $next failed: $e', name: 'LuminaGameWindow');
        }
      }
      await _save(next);
      done.complete(applied);
    }();
    return done.future;
  }

  /// Windowed ↔ borderless fullscreen.
  static Future<bool> toggle() => setMode(
      mode.value == LuminaWindowMode.windowed ? LuminaWindowMode.borderlessFullscreen : LuminaWindowMode.windowed);

  static Future<LuminaWindowMode?> _readSaved() async {
    final path = settingsFilePath;
    if (path == null || LuminaPlatform.isWeb) return null;
    try {
      final file = File(path);
      if (!await file.exists()) return null;
      final decoded = jsonDecode(await file.readAsString());
      final value = decoded is Map ? decoded[settingsKey] : null;
      return value is String ? LuminaWindowMode.parse(value) : null;
    } on Object {
      return null;
    }
  }

  static Future<void> _save(LuminaWindowMode m) async {
    final path = settingsFilePath;
    if (path == null || LuminaPlatform.isWeb) return;
    try {
      final file = File(path);
      var data = <String, dynamic>{};
      if (await file.exists()) {
        try {
          final decoded = jsonDecode(await file.readAsString());
          if (decoded is Map) data = Map<String, dynamic>.from(decoded);
        } on FormatException {
          // A damaged file is replaced.
        }
      }
      data[settingsKey] = m.id;
      await file.parent.create(recursive: true);
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data), flush: true);
    } on Object catch (e) {
      developer.log('Window mode could not be saved to $path: $e', name: 'LuminaGameWindow');
    }
  }

  /// Back to a fresh process's state (tests).
  static void resetForTesting() {
    backend?.onModeChanged = null;
    backend = null;
    settingsFilePath = null;
    mode.value = LuminaWindowMode.windowed;
    _pendingWrite = Future<void>.value();
  }
}
