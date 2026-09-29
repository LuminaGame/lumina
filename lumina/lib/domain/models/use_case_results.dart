import '../../data/models/lumina_project.dart';
import '../../data/repositories/asset_repository.dart';

/// Result of [SaveLevelUseCase]: where the `.lmas` level container landed on disk.
class SaveLevelResult {
  final bool isSuccess;
  final String levelName;
  final String? levelFilePath;
  final int actorCount;
  final String? error;

  const SaveLevelResult.success({
    required this.levelName,
    required String this.levelFilePath,
    required this.actorCount,
  })  : isSuccess = true,
        error = null;

  const SaveLevelResult.failure(this.levelName, String this.error)
      : isSuccess = false,
        levelFilePath = null,
        actorCount = 0;

  @override
  String toString() => isSuccess
      ? 'SaveLevelResult.success($levelFilePath, actors: $actorCount)'
      : 'SaveLevelResult.failure($levelName: $error)';
}

/// Result of [GenerateDartCodeUseCase]: the generated Dart files and the cleaned manifest.
class GenerateDartCodeResult {
  final bool isSuccess;
  final String? mainDartPath;
  final String? levelDartPath;
  final List<String> writtenFiles;
  final LuminaProject? updatedProject;
  final String? error;

  const GenerateDartCodeResult.success({
    required String this.mainDartPath,
    required String this.levelDartPath,
    required this.writtenFiles,
    this.updatedProject,
  })  : isSuccess = true,
        error = null;

  const GenerateDartCodeResult.failure(String this.error)
      : isSuccess = false,
        mainDartPath = null,
        levelDartPath = null,
        writtenFiles = const [],
        updatedProject = null;

  @override
  String toString() => isSuccess
      ? 'GenerateDartCodeResult.success(${writtenFiles.join(', ')})'
      : 'GenerateDartCodeResult.failure($error)';
}

/// Result of [ImportAssetUseCase]: the imported asset's `.lmas` description.
class ImportAssetResult {
  final bool isSuccess;
  final String sourceFilePath;
  final RealAssetInfo? asset;
  final String? error;

  const ImportAssetResult.success({
    required this.sourceFilePath,
    required RealAssetInfo this.asset,
  })  : isSuccess = true,
        error = null;

  const ImportAssetResult.failure(this.sourceFilePath, String this.error)
      : isSuccess = false,
        asset = null;

  @override
  String toString() => isSuccess
      ? 'ImportAssetResult.success(${asset!.relativePath})'
      : 'ImportAssetResult.failure($sourceFilePath: $error)';
}
