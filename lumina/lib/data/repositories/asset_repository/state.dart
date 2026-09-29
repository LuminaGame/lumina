part of '../asset_repository.dart';

/// State shared by the [AssetRepository] domain mixins: every
/// instance field (in the original order, so initialisers run in the same
/// order) and the members the mixins call on one another.
abstract class _AssetRepositoryState {

  final EngineLoggerService _logger = EngineLoggerService();

  // --- Implemented by the domain mixins or [AssetRepository]. ---

  List<RealAssetInfo> scanProjectContents(String projectPath);

  Future<Map<String, dynamic>> stageImport({
    required String projectPath,
    required String sourceFilePath,
    required bool generateLods,
    String? baseName,
    List<String> textureSearchDirs,
  });

  Future<Map<String, dynamic>> convertStagedAsset({
    required String projectPath,
    required String stagedFilePath,
    required AssetType detectedType,
    String? targetSkeletonPath,
    bool renderThumbnails = true,
  });

  Map<String, String> resolveTargetPaths({
    required String projectPath,
    required String baseName,
    required AssetType primaryType,
    required bool autoOrganize,
    required String? browserSelectedFolder,
    required List<String> extractedSubAssets,
  });

  Future<List<LuminaAsset>> emitAssetFamily({
    required Map<String, String> targetPaths,
    required Map<String, dynamic> convertedData,
    List<String>? writtenPaths,
  });

  Future<PreparedImport> prepareImport({
    required String projectPath,
    required String sourceFilePath,
    String? targetSubFolder,
    bool autoOrganize = true,
    bool generateLods = false,
    String? targetSkeletonPath,
    bool renderThumbnails = true,
    String? targetBaseName,
    List<String> textureSearchDirs,
  });

  Future<void> renderImportThumbnails(PreparedImport prepared);

  Future<ImportWriteResult> writeImport(PreparedImport prepared);

  Future<Uint8List?> _generateThumbnailBytes(
    AssetType type, {
    Uint8List? rawPayload,
    MeshThumbnailGeometry? geometry,
    bool geometryResolved = false,
  });
}
