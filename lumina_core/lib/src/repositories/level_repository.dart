import 'dart:io';

import 'package:lumina_core/src/formats/lumina_level_document.dart';

/// Reads and writes a project's level `.lmas` containers:
/// the whole document, keeping every key of the level as it is on disk. The
/// engine adds `loadLevelBlueprint` / `saveLevelBlueprint` (`package:lumina`).
class LuminaLevelRepository {
  /// The project directory the level paths are relative to.
  final String projectDir;

  const LuminaLevelRepository(this.projectDir);

  File _file(String relativePath) => File('$projectDir/$relativePath');

  /// The level at [relativePath] (`contents/levels/L_Test.lmas`), or null
  /// when there is no such level.
  LuminaLevelDocument? load(String relativePath) {
    final file = _file(relativePath);
    if (!file.existsSync()) return null;
    return LuminaLevelDocument.tryParse(file.readAsStringSync(), relativePath: relativePath);
  }

  /// Writes [level] to its path.
  void save(LuminaLevelDocument level) {
    final file = _file(level.relativePath)..parent.createSync(recursive: true);
    file.writeAsStringSync(level.encode());
  }
}
