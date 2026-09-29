import 'dart:convert';
import 'dart:io';

import '../../data/models/lumina_level_document.dart';
import '../../data/services/engine_logger_service.dart';
import '../../src/blueprint/level_blueprint.dart';
import '../models/use_case_results.dart';
import 'use_case_validation.dart';

/// Writes the active level as a `contents/levels/<levelName>.lmas` JSON container.
///
/// The container is exactly what Lumina Studio writes on Save Level: `assetId`
/// (`level_<name>`), `name`, `type: 'level'`, `relativePath`, `rawPayload: null` and
/// `metadata.actors` — the actor maps (`EditorActorNode.toMap()`) are passed through
/// untouched. Validation and I/O failures are reported in the result, never thrown.
class SaveLevelUseCase {
  static const String levelsSubdir = 'contents/levels';
  static const String _source = 'SaveLevel';

  final EngineLoggerService _logger;

  SaveLevelUseCase({EngineLoggerService? logger}) : _logger = logger ?? EngineLoggerService();

  Future<SaveLevelResult> call({
    required String projectDir,
    required String levelName,
    required List<Map<String, dynamic>> actors,
  }) async {
    final validation = validateProjectDir(projectDir) ?? validateLevelName(levelName);
    if (validation != null) {
      _logger.log('Save Level rejected: $validation', level: 'error', source: _source);
      return SaveLevelResult.failure(levelName, validation);
    }

    _logger.log('Saving level "$levelName" (${actors.length} actors) to disk...', source: _source);
    try {
      final levelsDir = Directory('$projectDir/$levelsSubdir');
      if (!levelsDir.existsSync()) levelsDir.createSync(recursive: true);

      final relativePath = '$levelsSubdir/$levelName.lmas';
      final file = File('$projectDir/$relativePath');
      // The level's Blueprint lives in the same container and
      // is kept across a Save Level that only carries the actors.
      final previous = file.existsSync() ? LuminaLevelDocument.tryParse(file.readAsStringSync(), relativePath: relativePath) : null;
      final levelBlueprint = previous?.metadata[LuminaLevelBlueprintDocument.metadataKey];
      final container = <String, dynamic>{
        'assetId': 'level_$levelName',
        'name': levelName,
        'type': 'level',
        'relativePath': relativePath,
        'rawPayload': null,
        'metadata': {'actors': actors, if (levelBlueprint is Map) LuminaLevelBlueprintDocument.metadataKey: levelBlueprint},
      };
      file.writeAsStringSync(jsonEncode(container));

      _logger.log('Level asset "$levelName.lmas" saved (${actors.length} actors).', level: 'success', source: _source);
      return SaveLevelResult.success(levelName: levelName, levelFilePath: file.path, actorCount: actors.length);
    } on IOException catch (e) {
      _logger.log('Failed to write level "$levelName": $e', level: 'error', source: _source);
      return SaveLevelResult.failure(levelName, 'Failed to write level: $e');
    }
  }
}
