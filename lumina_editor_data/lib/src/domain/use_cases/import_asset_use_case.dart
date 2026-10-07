import 'dart:io';

import 'package:lumina_editor_data/src/repositories/asset_repository.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina_editor_data/src/domain/models/use_case_results.dart';
import 'package:lumina_editor_data/src/domain/use_cases/use_case_validation.dart';

/// Imports an external model/texture/audio file into a project's `contents/` tree
/// through [AssetRepository.importExternalFile] (stage → convert → resolve paths → emit
/// `.lmas` family). FBX goes through the native Assimp bridge into standard glTF;
/// an FBX animation is retargeted onto a project skeletal mesh
/// ([targetSkeletonPath] null = matched by bone names, `''` = keep it unbound).
/// Thrown pipeline errors (a corrupt FBX included) become a failure result.
class ImportAssetUseCase {
  static const String _source = 'ImportPipeline';

  final AssetRepository _assetRepository;
  final EngineLoggerService _logger;

  ImportAssetUseCase({AssetRepository? assetRepository, EngineLoggerService? logger})
      : _assetRepository = assetRepository ?? AssetRepository(),
        _logger = logger ?? EngineLoggerService();

  Future<ImportAssetResult> call({
    required String projectDir,
    required String sourceFilePath,
    String? targetSubFolder,
    bool autoOrganize = true,
    String? targetSkeletonPath,
    List<String> textureSearchDirs = const [],
  }) async {
    final dirError = validateProjectDir(projectDir);
    if (dirError != null) {
      _logger.log('Import rejected: $dirError', level: 'error', source: _source);
      return ImportAssetResult.failure(sourceFilePath, dirError);
    }
    final source = File(sourceFilePath);
    if (sourceFilePath.trim().isEmpty || !source.existsSync()) {
      final msg = 'Source file does not exist: $sourceFilePath';
      _logger.log('Import rejected: $msg', level: 'error', source: _source);
      return ImportAssetResult.failure(sourceFilePath, msg);
    }
    final baseFileName = source.uri.pathSegments.last;
    _logger.log('Importing "$baseFileName"...', source: _source);
    try {
      final imported = await _assetRepository.importExternalFile(
        projectPath: projectDir,
        sourceFilePath: sourceFilePath,
        targetSubFolder: targetSubFolder,
        autoOrganize: autoOrganize,
        targetSkeletonPath: targetSkeletonPath,
        textureSearchDirs: textureSearchDirs,
      );
      _logger.log('Imported "$baseFileName" → ${imported.relativePath}', level: 'success', source: _source);
      return ImportAssetResult.success(sourceFilePath: sourceFilePath, asset: imported);
    } catch (e) {
      _logger.log('Import failed: $e', level: 'error', source: _source);
      return ImportAssetResult.failure(sourceFilePath, 'Import failed: $e');
    }
  }
}
