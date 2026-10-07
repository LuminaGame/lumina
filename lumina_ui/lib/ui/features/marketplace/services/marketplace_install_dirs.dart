import 'dart:io';

import 'package:lumina_core/lumina_core.dart';
import 'package:lumina_marketplace_shared/lumina_marketplace_shared.dart';

import 'package:lumina_ui/ui/core/services/user_plugin_dir.dart';

/// Where each install kind of a Marketplace listing lands.
///
/// A manifest's targets are relative to one of these, by the root prefix
/// the server gives them ([manifestRootPrefix]): `contents/Marketplace/…`
/// to the open project, `plugins/<package>/` to the user plugin directory
/// (the one the Plugin Manager scans), `themes/` to the editor themes
/// directory (the theme store reads `<config>/themes/*.json`) and
/// `templates/` to the editor templates directory.
class MarketplaceInstallDirs {
  const MarketplaceInstallDirs({
    required this.projectRoot,
    required this.pluginDir,
    required this.themesDir,
    required this.templatesDir,
    required this.editorLicensesFile,
  });

  /// The open project's directories, the user plugin directory
  /// ([UserPluginDir]) and the editor config directory ([LuminaConfigDir]).
  factory MarketplaceInstallDirs.resolve({String? projectRoot, Directory? configDir}) {
    final config = LuminaConfigDir.resolve(explicit: configDir).path;
    return MarketplaceInstallDirs(
      projectRoot: projectRoot,
      pluginDir: UserPluginDir.resolve().path,
      themesDir: '$config/themes',
      templatesDir: '$config/templates',
      editorLicensesFile: '$config/marketplace/licenses.json',
    );
  }

  /// The open project, or null in the launcher (assets cannot install then).
  final String? projectRoot;
  final String pluginDir;
  final String themesDir;
  final String templatesDir;

  /// `licenses.json` for the editor-wide installs (plugins, themes,
  /// templates).
  final String editorLicensesFile;

  /// The project's `contents/Marketplace/licenses.json`.
  String? get projectLicensesFile => projectRoot == null ? null : '$projectRoot/contents/Marketplace/licenses.json';

  /// The prefix every target of [kind] starts with in an install manifest.
  static String manifestRootPrefix(InstallKind kind) => switch (kind) {
        InstallKind.projectContents => 'contents/Marketplace/',
        InstallKind.plugin => 'plugins/',
        InstallKind.theme => 'themes/',
        InstallKind.gameTemplate => 'templates/',
      };
}
