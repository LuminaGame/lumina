import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:lumina/src/utility/lumina_platform.dart';

/// The player's settings file: one flat JSON object,
/// `GameUserSettings.json` in the game's save directory, holding everything
/// the player chooses — the window mode (`window_mode`), the screen
/// resolution and monitor (`screen_resolution`, `fullscreen_monitor`), and
/// the graphics settings `LuminaUserSettingsSubsystem` saves.
///
/// Every writer merges its keys into the file ([update]) instead of
/// replacing it, so keys written by other code (or by a newer version of the
/// game) survive. Writes are serialized: two writers never interleave a
/// read and a write. Nothing is written on the web.
abstract final class LuminaGameUserSettingsFile {
  /// The file's name in the save directory.
  static const String fileName = 'GameUserSettings.json';

  /// Where earlier versions kept the window mode: next to the save
  /// directory (`<game>/user_settings.json`, beside `<game>/SaveGames`).
  static const String legacyFileName = 'user_settings.json';

  static Future<void> _queue = Future<void>.value();

  /// Completes when every queued write is done.
  static Future<void> get idle => _queue;

  /// `<saveDirectory>/GameUserSettings.json`.
  static String pathFor(String saveDirectory) {
    final trimmed = saveDirectory.replaceAll(RegExp(r'[\\/]+$'), '');
    return '$trimmed/$fileName';
  }

  /// The legacy `user_settings.json` that belongs with the settings file at
  /// [settingsPath]: in the parent of its directory.
  static String legacyPathFor(String settingsPath) {
    final dir = _dirname(settingsPath);
    final parent = _dirname(dir);
    return '$parent/$legacyFileName';
  }

  static String _dirname(String path) {
    final trimmed = path.replaceAll(RegExp(r'[\\/]+$'), '');
    final cut = trimmed.lastIndexOf(RegExp(r'[\\/]'));
    if (cut < 0) return '.';
    if (cut == 0) return trimmed.substring(0, 1);
    return trimmed.substring(0, cut);
  }

  /// The file at [path] as a map; empty when it is missing, damaged or not
  /// an object.
  static Future<Map<String, dynamic>> read(String path) async {
    if (LuminaPlatform.isWeb) return <String, dynamic>{};
    try {
      final file = File(path);
      if (!await file.exists()) return <String, dynamic>{};
      final decoded = jsonDecode(await file.readAsString());
      return decoded is Map ? Map<String, dynamic>.from(decoded) : <String, dynamic>{};
    } on Object {
      return <String, dynamic>{};
    }
  }

  /// Merges [patch] into the file at [path] (a null value removes its key),
  /// keeping every other key; false when it cannot be written.
  static Future<bool> update(String path, Map<String, Object?> patch) =>
      _enqueue(() => _merge(path, patch, overwrite: true));

  /// Merges the legacy `user_settings.json` at [legacyPath] into [path]
  /// once: its keys the settings file does not have yet are added (the
  /// settings file's own keys win), then the legacy file is deleted. True
  /// when a legacy file was migrated.
  static Future<bool> migrateLegacy({required String path, String? legacyPath}) => _enqueue(() async {
        if (LuminaPlatform.isWeb) return false;
        final legacy = File(legacyPath ?? legacyPathFor(path));
        try {
          if (!await legacy.exists()) return false;
          Map<String, Object?> old = const {};
          try {
            final decoded = jsonDecode(await legacy.readAsString());
            if (decoded is Map) old = Map<String, Object?>.from(decoded);
          } on FormatException {
            // A damaged legacy file has nothing to keep.
          }
          if (old.isNotEmpty && !await _merge(path, old, overwrite: false)) return false;
          await legacy.delete();
          return true;
        } on Object catch (e) {
          developer.log('Settings migration from ${legacy.path} failed: $e', name: 'LuminaGameUserSettingsFile');
          return false;
        }
      });

  static Future<bool> _enqueue(Future<bool> Function() job) {
    final done = Completer<bool>();
    _queue = _queue.then((_) async {
      try {
        done.complete(await job());
      } on Object catch (e) {
        developer.log('Settings write failed: $e', name: 'LuminaGameUserSettingsFile');
        done.complete(false);
      }
    });
    return done.future;
  }

  static Future<bool> _merge(String path, Map<String, Object?> patch, {required bool overwrite}) async {
    if (LuminaPlatform.isWeb) return false;
    final file = File(path);
    try {
      final data = await read(path);
      for (final entry in patch.entries) {
        if (!overwrite && data.containsKey(entry.key)) continue;
        if (entry.value == null) {
          data.remove(entry.key);
        } else {
          data[entry.key] = entry.value;
        }
      }
      await file.parent.create(recursive: true);
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data), flush: true);
      return true;
    } on Object catch (e) {
      developer.log('Settings could not be saved to $path: $e', name: 'LuminaGameUserSettingsFile');
      return false;
    }
  }

  /// Back to a fresh process's state (tests).
  static void resetForTesting() => _queue = Future<void>.value();
}
