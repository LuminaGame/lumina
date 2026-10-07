import 'package:lumina_core/lumina_core.dart';

import 'package:lumina/src/blueprint/level_blueprint.dart';

/// The Level Blueprint of a level `.lmas`, read into the engine's
/// [LuminaLevelBlueprintDocument]. `lumina_core` keeps the stored JSON
/// ([LuminaLevelDocument.levelBlueprintJson]); the graph types are the engine's.
extension LuminaLevelDocumentBlueprint on LuminaLevelDocument {
  /// The level's Blueprint: an empty graph when none is stored.
  LuminaLevelBlueprintDocument get levelBlueprint =>
      LuminaLevelBlueprintDocument.fromLevelMetadata(metadata, levelPath: relativePath);

  /// Stores [value] under `metadata.levelBlueprint`; an empty Blueprint
  /// removes the key, so a level without a script stays as it was.
  set levelBlueprint(LuminaLevelBlueprintDocument? value) =>
      levelBlueprintJson = value == null || value.isEmpty ? null : value.toJson();

  /// The placed actors a Level Blueprint refers to by name.
  List<LuminaBlueprintLevelActorRef> get levelActorRefs => LuminaBlueprintLevelActorRef.fromActorMaps(actors);
}

/// Reading and writing only a level's Blueprint, keeping every other key of
/// the level as it is on disk.
extension LuminaLevelRepositoryBlueprint on LuminaLevelRepository {
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
