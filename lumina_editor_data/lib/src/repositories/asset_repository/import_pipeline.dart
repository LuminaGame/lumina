part of '../asset_repository.dart';

/// The two-step import: prepare, thumbnails, then write.
mixin _AssetImportPipeline on _AssetRepositoryState {

  /// Steps 1–3 of an import: stage the source into `temp/`, convert it and
  /// resolve where each asset of its family goes. Nothing is written under
  /// `contents/` yet.
  ///
  /// With [renderThumbnails] false no step touches `dart:ui` or Filament, so
  /// this runs in the import worker isolate; the thumbnails are then drawn by
  /// [renderImportThumbnails] on the UI isolate before [writeImport].
  @override
  Future<PreparedImport> prepareImport({
    required String projectPath,
    required String sourceFilePath,
    String? targetSubFolder,
    bool autoOrganize = true,
    bool generateLods = false,
    String? targetSkeletonPath,
    bool renderThumbnails = true,
    String? targetBaseName,
    List<String> textureSearchDirs = const [],
  }) async {
    if (ImportFormats.kindOf(sourceFilePath) == ImportFormatKind.asset) {
      return _prepareAssetCopy(
        projectPath: projectPath,
        sourceFilePath: sourceFilePath,
        targetSubFolder: targetSubFolder,
        autoOrganize: autoOrganize,
        targetBaseName: targetBaseName,
      );
    }
    // 1. Stage Import
    final staged = await stageImport(
      projectPath: projectPath,
      sourceFilePath: sourceFilePath,
      generateLods: generateLods,
      baseName: targetBaseName,
      textureSearchDirs: textureSearchDirs,
    );
    final stagedPath = staged['stagedPath'] as String;
    final type = AssetRepository.assetTypeForDetectedKind(staged['detectedKind'] as String);

    // 2. Convert
    final Map<String, dynamic> converted;
    try {
      converted = await convertStagedAsset(
        projectPath: projectPath,
        stagedFilePath: stagedPath,
        detectedType: type,
        targetSkeletonPath: targetSkeletonPath,
        renderThumbnails: renderThumbnails,
      );
    } catch (_) {
      AssetRepository._deleteStaged(stagedPath);
      rethrow;
    }

    // 3. Resolve Target Paths
    final baseName = converted['baseName'] as String;
    final List<String> extractedSubs = [];
    final materials = converted['materials'] as List;
    final textures = converted['textures'] as List;
    final animations = converted['animations'] as List? ?? [];
    for (final m in materials) {
      extractedSubs.add(m['name'] as String);
    }
    for (final t in textures) {
      extractedSubs.add(t['name'] as String);
    }
    for (final a in animations) {
      extractedSubs.add(a['name'] as String);
    }

    final targetPaths = resolveTargetPaths(
      projectPath: projectPath,
      baseName: baseName,
      primaryType: type,
      autoOrganize: autoOrganize,
      browserSelectedFolder: targetSubFolder,
      extractedSubAssets: extractedSubs,
    );
    return PreparedImport(
      sourcePath: sourceFilePath,
      stagedPath: stagedPath,
      type: type,
      baseName: baseName,
      converted: converted,
      targetPaths: targetPaths,
    );
  }

  /// Draws the thumbnails a [prepareImport] with `renderThumbnails: false`
  /// left pending — the primary asset's and each extracted texture's — with
  /// the same drawing [convertStagedAsset] and [emitAssetFamily] use, so the
  /// written `.lmas` files are byte-for-byte what a direct import writes.
  /// Runs on the UI isolate (`dart:ui`); the mesh was already parsed and
  /// projected in the worker, so what is left is painting ≤ 5000 triangles
  /// and encoding a 128 px PNG.
  @override
  Future<void> renderImportThumbnails(PreparedImport prepared) async {
    applyThumbnails(prepared, await renderThumbnailJob(thumbnailJobFor(prepared)));
  }

  /// What drawing [prepared]'s pending thumbnails needs, and nothing more —
  /// the projected mesh, not the mesh payload — so the import worker sends
  /// the UI isolate only that.
  ImportThumbnailJob thumbnailJobFor(PreparedImport prepared) {
    final converted = prepared.converted;
    final pending = converted['pendingThumbnail'] as PendingImportThumbnail?;
    final textures = (converted['textures'] as List? ?? const []).cast<Map<String, dynamic>>();
    return ImportThumbnailJob(
      primary: pending,
      primaryImage: pending != null && pending.fromPayload && pending.type == AssetType.texture
          ? converted['primaryPayload'] as Uint8List
          : null,
      textureImages: [
        for (final t in textures)
          if (!t.containsKey('thumbnailPng')) t['payload'] as Uint8List,
      ],
    );
  }

  /// Draws [job] on the UI isolate (`dart:ui`), as [convertStagedAsset] and
  /// [emitAssetFamily] draw them.
  Future<ImportThumbnails> renderThumbnailJob(ImportThumbnailJob job) async {
    final pending = job.primary;
    Uint8List? primary;
    if (pending != null) {
      primary = await _generateThumbnailBytes(
        pending.type,
        rawPayload: job.primaryImage,
        geometry: pending.geometry,
        geometryResolved: pending.fromPayload,
      );
    }
    return ImportThumbnails(
      hasPrimary: pending != null,
      primary: primary,
      textures: [
        for (final image in job.textureImages)
          await _generateThumbnailBytes(AssetType.texture, rawPayload: image, geometryResolved: true),
      ],
    );
  }

  /// Puts thumbnails drawn by [renderThumbnailJob] into [prepared].
  void applyThumbnails(PreparedImport prepared, ImportThumbnails drawn) {
    final converted = prepared.converted;
    if (drawn.hasPrimary) {
      converted.remove('pendingThumbnail');
      converted['thumbnailPng'] = drawn.primary;
    }
    var i = 0;
    for (final tex in (converted['textures'] as List? ?? const [])) {
      final texMap = tex as Map<String, dynamic>;
      if (texMap.containsKey('thumbnailPng')) continue;
      texMap['thumbnailPng'] = drawn.textures[i++];
    }
  }

  /// A `.lmas` copied in from another project or folder:
  /// no staging or conversion; it keeps its id unless [targetBaseName]
  /// renames it, which makes it a new asset (new id, new name).
  Future<PreparedImport> _prepareAssetCopy({
    required String projectPath,
    required String sourceFilePath,
    String? targetSubFolder,
    required bool autoOrganize,
    String? targetBaseName,
  }) async {
    final file = File(sourceFilePath);
    if (!file.existsSync()) throw Exception('Source file does not exist: $sourceFilePath');
    var bytes = await file.readAsBytes();
    final LuminaAsset asset;
    try {
      asset = LuminaAsset.fromBytes(bytes);
    } catch (e) {
      throw FormatException('${file.uri.pathSegments.last} is not a Lumina asset: $e');
    }
    final fileName = file.uri.pathSegments.last;
    var baseName = fileName.substring(0, fileName.length - '.lmas'.length);
    if (targetBaseName != null && targetBaseName.isNotEmpty && targetBaseName != baseName) {
      baseName = targetBaseName;
      bytes = LuminaAsset(
        assetId: AssetRepository._generateUuidV4(),
        name: targetBaseName,
        type: asset.type,
        hasThumbnail: asset.hasThumbnail,
        thumbnailPng: asset.thumbnailPng,
        rawPayload: asset.rawPayload,
        rawMatSource: asset.rawMatSource,
        references: asset.references,
        metadata: asset.metadata,
      ).toProtoBufferBytes();
    }
    final targetPaths = resolveTargetPaths(
      projectPath: projectPath,
      baseName: baseName,
      primaryType: asset.type,
      autoOrganize: autoOrganize,
      browserSelectedFolder: targetSubFolder,
      extractedSubAssets: const [],
    );
    return PreparedImport(
      sourcePath: sourceFilePath,
      stagedPath: '',
      type: asset.type,
      baseName: baseName,
      converted: {
        'projectPath': projectPath,
        'baseName': baseName,
        'assetCopy': bytes,
        'materials': const [],
        'textures': const [],
        'animations': const [],
      },
      targetPaths: targetPaths,
    );
  }

  /// Step 4 of an import: writes the asset family under `contents/` and
  /// removes the staged copy. Isolate-safe once [renderImportThumbnails]
  /// has run (or when [prepareImport] rendered its thumbnails itself).
  @override
  Future<ImportWriteResult> writeImport(PreparedImport prepared) async {
    final projectPath = prepared.converted['projectPath'] as String;
    final copied = prepared.converted['assetCopy'] as Uint8List?;
    if (copied != null) {
      // A `.lmas` from elsewhere: written as it is.
      final primaryPath = prepared.targetPaths['primary']!;
      final file = File('$projectPath/$primaryPath');
      file.parent.createSync(recursive: true);
      file.writeAsBytesSync(copied);
      final asset = LuminaAsset.fromBytes(copied);
      return ImportWriteResult(
        info: RealAssetInfo(
          fileName: '${prepared.baseName}.lmas',
          relativePath: primaryPath,
          type: prepared.type,
          bytes: asset.rawPayload?.length ?? 0,
          thumbnailBytes: asset.thumbnailPng,
          lmasPath: file.path,
        ),
        writtenPaths: [primaryPath],
      );
    }
    final written = <String>[];
    final List<LuminaAsset> emitted;
    try {
      emitted = await emitAssetFamily(
        targetPaths: prepared.targetPaths,
        convertedData: prepared.converted,
        writtenPaths: written,
      );
    } finally {
      AssetRepository._deleteStaged(prepared.stagedPath);
    }

    final baseName = prepared.baseName;
    final primary = emitted.firstWhere((e) => e.name == baseName, orElse: () => emitted.first);
    final primaryPath = prepared.targetPaths['primary']!;

    return ImportWriteResult(
      info: RealAssetInfo(
        fileName: '$baseName.lmas',
        relativePath: primaryPath,
        type: prepared.type,
        bytes: primary.rawPayload?.length ?? 0,
        thumbnailBytes: primary.thumbnailPng,
        lmasPath: '$projectPath/$primaryPath',
      ),
      writtenPaths: written,
    );
  }
}
