import 'dart:io';

import '../models/lumina_asset.dart';
import '../models/lumina_theme_document.dart';

/// Service for managing Lumina UI Theme `.lmas` files in projects.
class LuminaThemeService {
  static const String themesSubdir = 'contents/themes';
  static const String defaultThemeFileName = 'DefaultTheme.lmas';

  /// Ensures that a default theme exists under `<projectDir>/contents/themes/DefaultTheme.lmas`.
  /// If the file does not exist, it is created with [seedTheme] (or [LuminaThemeDocument.defaultShadcnDark]).
  static Future<File> ensureDefaultTheme(
    String projectDirPath, {
    LuminaThemeDocument? seedTheme,
  }) async {
    final dir = Directory('$projectDirPath/$themesSubdir');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    final file = File('$projectDirPath/$themesSubdir/$defaultThemeFileName');
    if (!file.existsSync()) {
      final doc = seedTheme ?? LuminaThemeDocument.defaultShadcnDark();
      final asset = doc.toAsset(name: 'DefaultTheme');
      await file.writeAsBytes(asset.toProtoBufferBytes());
    }
    return file;
  }

  /// Loads a [LuminaThemeDocument] from a `.lmas` file at [lmasPath].
  static Future<LuminaThemeDocument> loadTheme(String lmasPath) async {
    final file = File(lmasPath);
    if (!file.existsSync()) {
      return LuminaThemeDocument.defaultShadcnDark();
    }
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      return LuminaThemeDocument.defaultShadcnDark();
    }
    try {
      final asset = LuminaAsset.fromBytes(bytes);
      return LuminaThemeDocument.fromAsset(asset);
    } catch (_) {
      return LuminaThemeDocument.defaultShadcnDark();
    }
  }

  /// Saves a [LuminaThemeDocument] to a `.lmas` file at [lmasPath].
  static Future<void> saveTheme(String lmasPath, LuminaThemeDocument doc) async {
    final file = File(lmasPath);
    final parent = file.parent;
    if (!parent.existsSync()) {
      parent.createSync(recursive: true);
    }
    final assetName = file.uri.pathSegments.last.replaceAll('.lmas', '');
    final asset = doc.toAsset(name: assetName);
    await file.writeAsBytes(asset.toProtoBufferBytes());
  }

  /// Lists all theme `.lmas` files in [projectDirPath].
  static List<String> listThemePaths(String projectDirPath) {
    final dir = Directory('$projectDirPath/$themesSubdir');
    if (!dir.existsSync()) return const [];
    return dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.lmas'))
        .map((f) => f.path.replaceAll('\\', '/'))
        .toList();
  }
}
