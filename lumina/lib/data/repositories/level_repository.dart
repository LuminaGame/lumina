import 'dart:io';

import '../../src/blueprint/level_blueprint.dart';
import '../models/lumina_level_document.dart';

/// Reads and writes a project's level `.lmas` containers:
/// the whole document, or only its Level Blueprint, keeping every other key
/// of the level as it is on disk.
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

  /// The Level Blueprint of [relativePath]; an empty graph when the level has
  /// none (or does not exist yet).
  LuminaLevelBlueprintDocument loadLevelBlueprint(String relativePath) =>
      load(relativePath)?.levelBlueprint ?? LuminaLevelBlueprintDocument(levelPath: relativePath);

  /// Stores [blueprint] in its level (`metadata.levelBlueprint`), creating a
  /// level container when none exists. Returns the saved level.
  LuminaLevelDocument saveLevelBlueprint(LuminaLevelBlueprintDocument blueprint) {
    final path = blueprint.levelPath;
    final level = load(path) ?? LuminaLevelDocument(relativePath: path);
    level.levelBlueprint = blueprint;
    save(level);
    return level;
  }
}
