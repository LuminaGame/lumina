part of '../asset_repository.dart';

/// Scanning the project's contents: the asset index, content folders,
/// asset type inference and creating an empty asset.
mixin _AssetScanning on _AssetRepositoryState {

  /// Every `.lmas` under `<projectPath>/contents`, read from the project's
  /// asset index: the files are stat'ed and only new or
  /// changed ones are summarised; thumbnails come from their byte range in
  /// the file (a texture without one shows its image). Nothing is decoded in
  /// full.
  @override
  List<RealAssetInfo> scanProjectContents(String projectPath) {
    final contentsDir = Directory('$projectPath/contents');
    if (!contentsDir.existsSync()) {
      _logger.log('contents/ directory missing at $projectPath. Creating...', level: 'warning', source: 'AssetRepository');
      contentsDir.createSync(recursive: true);
      return [];
    }

    final root = projectPath.endsWith('/') ? projectPath.substring(0, projectPath.length - 1) : projectPath;
    final List<RealAssetInfo> results = [];
    try {
      final index = LuminaAssetIndex.open(root);
      index.refreshSync();
      for (final e in index.entries) {
        results.add(_infoFromIndexEntry(root, index, e));
      }
      _logger.log(
        'Scanned ${results.length} real .lmas asset containers in $projectPath/contents '
        '(asset index: ${index.lastRefreshStats.decoded} summarised, ${index.lastRefreshStats.elapsed.inMilliseconds} ms)',
        level: 'info',
        source: 'AssetRepository',
      );
    } catch (e) {
      _logger.log('Error scanning contents/ directory: $e', level: 'error', source: 'AssetRepository');
    }

    return results;
  }

  /// Indexes just [relativePaths] (the `.lmas` files an import wrote) and
  /// describes each as [scanProjectContents] would — without walking
  /// `contents/`. Paths that are gone are left out.
  List<RealAssetInfo> indexAndDescribe(String projectPath, Iterable<String> relativePaths) {
    final root = projectPath.endsWith('/') ? projectPath.substring(0, projectPath.length - 1) : projectPath;
    final index = LuminaAssetIndex.open(root);
    final paths = relativePaths.toList();
    index.refreshPaths(paths);
    return [
      for (final p in paths)
        if (index.byPath(p) case final entry?) _infoFromIndexEntry(root, index, entry),
    ];
  }

  RealAssetInfo _infoFromIndexEntry(String root, LuminaAssetIndex index, AssetIndexEntry e) {
    final summary = e.summary;
    final lmasPath = '$root/${e.path}';
    var type = summary.type != AssetType.unknown ? summary.type : _inferAssetType(lmasPath);
    final lowerName = e.fileName.toLowerCase();
    if ((type == AssetType.filamesh || type == AssetType.unknown) &&
        (lmasPath.contains('/meshes/skeletal/') || lowerName.startsWith('skm_') || lmasPath.contains('/skeletal/'))) {
      type = AssetType.filameshSk;
    }
    final unreadable = summary.type == AssetType.unknown && summary.assetId.isEmpty && summary.name.isEmpty;
    return RealAssetInfo(
      fileName: e.fileName,
      relativePath: e.path,
      type: type,
      bytes: e.size,
      thumbnailBytes: index.thumbnailOf(e),
      thumbnailSource: summary.thumbnailSource,
      thumbnailAssetModified: summary.metadata['thumbnail_asset_modified'],
      lmasPath: lmasPath,
      assetId: unreadable ? null : summary.assetId,
      references: summary.references,
      lastModified: e.modified,
    );
  }

  List<String> scanContentFolders(String projectPath) {
    final contentsDir = Directory('$projectPath/contents');
    if (!contentsDir.existsSync()) return ['contents'];

    final Set<String> folders = {'contents'};
    try {
      final entities = contentsDir.listSync(recursive: true, followLinks: false);
      for (final entity in entities) {
        if (entity is Directory) {
          final relative = entity.path.substring(projectPath.length + 1).replaceAll(r'\', '/');
          if (relative.contains('.thumbnails') || relative.contains('temp')) continue;
          folders.add(relative);
        } else if (entity is File) {
          final relativeFile = entity.path.substring(projectPath.length + 1).replaceAll(r'\', '/');
          if (relativeFile.endsWith('.collections.json')) continue;
          if (relativeFile.contains('.thumbnails') || relativeFile.contains('temp')) continue;
          
          final dirPath = entity.parent.path.substring(projectPath.length + 1).replaceAll(r'\', '/');
          if (!folders.contains(dirPath)) {
            folders.add(dirPath);
          }
        }
      }
    } catch (e) {
      _logger.log('Error scanning folders: $e', level: 'error', source: 'AssetRepository');
    }
    final sorted = folders.toList()..sort();
    return sorted;
  }

  AssetType _inferAssetType(String filePath) {
    final lower = filePath.toLowerCase();
    
    // Auto-detect static vs skeletal by quickly scanning for "skins" or "animations" in the GLB JSON chunk
    if (lower.endsWith('.glb') || lower.endsWith('.gltf')) {
      try {
        final bytes = File(filePath).readAsBytesSync();
        if (bytes.length >= 20 && bytes[0] == 0x67 && bytes[1] == 0x6C && bytes[2] == 0x54 && bytes[3] == 0x46) {
          // It's a GLB. Find JSON chunk
          final length = bytes.buffer.asByteData().getUint32(12, Endian.little);
          if (bytes.length >= 20 + length) {
            final jsonStr = utf8.decode(bytes.sublist(20, 20 + length));
            if (jsonStr.contains('"animations"')) {
              final isAnimSeq = lower.contains('_anim') ||
                  lower.contains('anim_') ||
                  lower.contains('mf_') ||
                  lower.contains('_walk') ||
                  lower.contains('_run') ||
                  lower.contains('_idle') ||
                  lower.contains('_jump') ||
                  lower.contains('_bwd') ||
                  lower.contains('_fwd') ||
                  lower.contains('_sprint');
              return isAnimSeq ? AssetType.animation : AssetType.filameshSk;
            } else if (jsonStr.contains('"skins"')) {
              return AssetType.filameshSk;
            }
          }
        }
      } catch (_) {}
    }
    
    if (lower.contains('/meshes/skeletal/') || lower.contains('/skeletal/') || lower.contains('/skm/') || filePath.split('/').last.toLowerCase().startsWith('skm_')) {
      return AssetType.filameshSk;
    }
    if (lower.contains('/meshes/') || lower.endsWith('.obj') || lower.endsWith('.gltf') || lower.endsWith('.glb') || lower.endsWith('.filamesh')) {
      return AssetType.filamesh;
    }
    if (lower.contains('/materials/') || lower.endsWith('.filamat') || lower.endsWith('.mat')) {
      return AssetType.filamat;
    }
    if (lower.contains('/textures/') || lower.endsWith('.png') || lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.tga') || lower.endsWith('.ktx2')) {
      return AssetType.texture;
    }
    if (lower.contains('/blueprints/') || lower.endsWith('.bp')) {
      return AssetType.actor;
    }
    if (lower.contains('/animations/') || lower.contains('/anim/') || lower.endsWith('.anim') || lower.contains('anim_') || lower.contains('mf_') || lower.contains('_walk') || lower.contains('_run') || lower.contains('_idle') || lower.contains('_bwd') || lower.contains('_fwd') || lower.contains('_sprint') || lower.contains('_jump')) {
      return AssetType.animation;
    }
    if (lower.contains('/audio/') || lower.endsWith('.wav') || lower.endsWith('.ogg') || lower.endsWith('.mp3')) {
      return AssetType.audio;
    }
    if (lower.contains('/levels/')) {
      return AssetType.level;
    }
    if (lower.endsWith('.lmas')) {
      return AssetType.unknown;
    }
    return AssetType.unknown;
  }

  Future<void> createAsset({
    required String projectPath,
    required String subFolder,
    required String fileName,
    required AssetType type,
  }) async {
    final file = File('$projectPath/contents/$subFolder/$fileName');
    if (!file.parent.existsSync()) {
      file.parent.createSync(recursive: true);
    }

    final thumbBytes = await _generateThumbnailBytes(type);

    final asset = LuminaAsset(
      assetId: fileName.replaceAll('.', '_'),
      name: fileName,
      type: type,
      hasThumbnail: thumbBytes != null,
      thumbnailPng: thumbBytes,
    );

    file.writeAsStringSync(jsonEncode(asset.toMap()));
    _logger.log('Created real asset file at ${file.path}', level: 'success', source: 'AssetRepository');
  }
}
