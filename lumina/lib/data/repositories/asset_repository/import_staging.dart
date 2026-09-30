part of '../asset_repository.dart';

/// Staging an import: GLB / FBX staging and the target paths it resolves.
mixin _AssetImportStaging on _AssetRepositoryState {

  // --- IMPORT PIPELINE STEPS ---

  /// STEP 1: Pre-processing & Temp Copy
  /// Copies source into `<project>/temp/`, decodes .webp to .png, and handles LOD prompt logic.
  @override
  Future<Map<String, dynamic>> stageImport({
    required String projectPath,
    required String sourceFilePath,
    required bool generateLods,
    String? baseName,
    List<String> textureSearchDirs = const [],
  }) async {
    final sourceFile = File(sourceFilePath);
    if (!sourceFile.existsSync()) {
      throw Exception('Source file does not exist: $sourceFilePath');
    }

    var tempDir = Directory('$projectPath/temp');
    if (!tempDir.existsSync()) {
      tempDir.createSync(recursive: true);
    }
    
    final sourceFileName = sourceFile.uri.pathSegments.last;
    final sourceBase = sourceFileName.contains('.') ? sourceFileName.substring(0, sourceFileName.lastIndexOf('.')) : sourceFileName;
    final sourceExt = sourceFileName.substring(sourceBase.length);
    // [baseName] renames the import (conflict policy
    // "rename"); the staged file's name is the asset's name.
    final originalFileName = baseName == null || baseName.isEmpty ? sourceFileName : '$baseName$sourceExt';
    final stagedBase = baseName == null || baseName.isEmpty ? sourceBase : baseName;
    // Two files of the same name in flight (a folder import's subfolders)
    // must not share temp/<name>: the second stages into its own folder.
    final lowerExt = sourceExt.toLowerCase();
    final stagedExt = lowerExt == '.webp' || lowerExt == '.tga' ? '.png' : (lowerExt == '.gltf' || FbxImportService.isFbx(sourceFileName) ? '.glb' : sourceExt);
    if (File('${tempDir.path}/$stagedBase$stagedExt').existsSync()) {
      tempDir = tempDir.createTempSync('stage_');
    }
    if (FbxImportService.isFbx(originalFileName)) {
      return _stageFbx(
        sourceFile: sourceFile,
        tempDir: tempDir,
        generateLods: generateLods,
        baseName: stagedBase,
        textureSearchDirs: textureSearchDirs,
      );
    }
    if (originalFileName.toLowerCase().endsWith('.glb')) {
      AssetRepository.checkGlbContainer(sourceFile);
    }
    final isWebp = originalFileName.toLowerCase().endsWith('.webp');
    final isTga = originalFileName.toLowerCase().endsWith('.tga');
    final isGltf = originalFileName.toLowerCase().endsWith('.gltf');
    
    String stagedFileName = '$stagedBase$stagedExt';

    final tempFile = File('${tempDir.path}/$stagedFileName');
    
    if (isGltf) {
      // The .gltf and the .bin / images it references
      // become one GLB, so the payload is self-contained.
      await tempFile.writeAsBytes(GltfPacker.packFile(sourceFile.path));
    } else if (isTga || isWebp) {
      // TGA and WebP are stored as PNG; the Texture editor's Reimport runs
      // the same conversion.
      await tempFile.writeAsBytes(await ImportImageConversion.importBytes(sourceFile));
    } else {
      await sourceFile.copy(tempFile.path);
    }

    _logger.log('[Step 1/4] Pre-processed & copied "$originalFileName" to temp/ directory.', level: 'info', source: 'AssetRepository');
    
    if (generateLods) {
      _logger.log('LOD generation not yet available', level: 'warning', source: 'AssetRepository');
    }

    // Detect kind
    String detectedKind = 'static mesh';
    final lower = originalFileName.toLowerCase();
    if (lower.endsWith('.glb') || lower.endsWith('.gltf')) {
      try {
        final bytes = await tempFile.readAsBytes();
        if (bytes.length >= 20 && bytes[0] == 0x67 && bytes[1] == 0x6C && bytes[2] == 0x54 && bytes[3] == 0x46) {
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
              detectedKind = isAnimSeq ? 'animation' : 'skeletal mesh';
            } else if (jsonStr.contains('"skins"')) {
              detectedKind = 'skeletal mesh';
            }
          }
        }
      } catch (_) {}
    } else if (lower.endsWith('.filamat') || lower.endsWith('.mat')) {
      detectedKind = 'material';
    } else {
      // The shared table: textures, audio, meshes.
      detectedKind = ImportFormats.stagedKindOf(lower);
    }

    // A standalone texture remembers the file it came from: the Texture
    // editor's Reimport reads `source_file`. Every
    // pipeline folds the sidecar into the asset's metadata.
    if (detectedKind == 'texture') {
      File('${tempFile.path}.import.json').writeAsStringSync(jsonEncode({
        'metadata': {'source_file': sourceFile.absolute.uri.toFilePath()},
      }));
    }

    return {
      'stagedPath': tempFile.path,
      'detectedKind': detectedKind,
      'metadata': {
        if (isWebp || isTga) 'format': 'PNG', // Since we converted it
      }
    };
  }

  /// STEP 1 for an FBX: converts the source — from its
  /// own folder, so relative texture paths resolve — into standard glTF
  /// (metres, Y up, one named clip per take, collision hulls removed) and
  /// stages that as `temp/<name>.glb`. What the conversion did goes into a
  /// `<staged>.import.json` sidecar that [convertStagedAsset] folds into the
  /// asset's metadata. An animation-only file (skeleton and keys, no mesh)
  /// is detected as `animation`, a skinned one as `skeletal mesh`.
  Future<Map<String, dynamic>> _stageFbx({
    required File sourceFile,
    required Directory tempDir,
    required bool generateLods,
    String? baseName,
    List<String> textureSearchDirs = const [],
  }) async {
    final fileName = sourceFile.uri.pathSegments.last;
    baseName ??= fileName.substring(0, fileName.lastIndexOf('.'));
    final FbxImportResult fbx;
    try {
      fbx = await FbxImportService.convert(sourceFile.path, textureSearchDirs: textureSearchDirs);
    } on FbxImportException catch (e) {
      _logger.log(e.message, level: 'error', source: 'AssetRepository');
      rethrow;
    }
    final staged = File('${tempDir.path}/$baseName.glb')..writeAsBytesSync(fbx.glb);
    final metadata = fbx.toAssetMetadata(assetBaseName: baseName);
    _logFbxTextures(fileName, baseName, fbx, textureSearchDirs);
    File('${staged.path}.import.json').writeAsStringSync(jsonEncode({
      'metadata': metadata,
      'clip_names': fbx.clipNames,
    }));

    final json = GlbDocument.parse(fbx.glb, label: fileName).json;
    final hasMeshes = ((json['meshes'] as List?) ?? const []).isNotEmpty;
    final hasSkins = ((json['skins'] as List?) ?? const []).isNotEmpty;
    final hasAnimations = ((json['animations'] as List?) ?? const []).isNotEmpty;
    final detectedKind = !hasMeshes && hasAnimations
        ? 'animation'
        : hasSkins
            ? 'skeletal mesh'
            : 'static mesh';

    final hulls = fbx.collisionHulls.length;
    _logger.log(
      '[Step 1/4] Converted FBX "$fileName" → glTF ($detectedKind; unit scale ${fbx.report['unit_scale']}, '
      'up ${fbx.report['up_axis'] ?? 'as imported'} → +Y'
      '${fbx.clipNames.isEmpty ? '' : '; clips: ${fbx.clipNames.join(', ')}'}'
      '${hulls == 0 ? '' : '; $hulls collision hull${hulls == 1 ? '' : 's'} kept as data'}).',
      level: 'info',
      source: 'AssetRepository',
    );
    if (generateLods) {
      _logger.log('LOD generation not yet available', level: 'warning', source: 'AssetRepository');
    }
    return {
      'stagedPath': staged.path,
      'detectedKind': detectedKind,
      'metadata': metadata,
    };
  }

  /// One Output Log warning per texture the FBX references
  /// but that was found nowhere (naming the file, the materials and slots it
  /// was for, and where it was looked for), one line per texture bound.
  void _logFbxTextures(String fileName, String baseName, FbxImportResult fbx, List<String> textureSearchDirs) {
    const slotLabels = {
      'baseColorMap': 'base colour map',
      'normalMap': 'normal map',
      'emissiveMap': 'emissive map',
      'metallicRoughnessMap': 'metallic/roughness map',
      'occlusionMap': 'occlusion map',
    };
    final byFile = <String, List<Map<String, dynamic>>>{};
    for (final d in fbx.missingTextureDetails) {
      byFile.putIfAbsent('${d['path']}', () => []).add(d);
    }
    final folders = [
      ...textureSearchDirs.where((d) => d.trim().isNotEmpty),
      'the FBX\'s folder and its Textures/ subfolders',
    ].join(', ');
    for (final entry in byFile.entries) {
      final uses = entry.value
          .map((d) => '${ImportedAssetNames.material('${d['material']}', baseName)} (${slotLabels[d['slot']] ?? d['slot']})')
          .toSet()
          .join(', ');
      _logger.log(
        'FBX "$fileName": texture "${entry.value.first['file']}" for $uses was not found '
        '(the FBX points at ${entry.key}; looked in $folders). The material is imported without it — '
        'put the file next to the FBX or choose its folder as Textures Folder in the import options, then re-import.',
        level: 'warning',
        source: 'AssetRepository',
      );
    }
    for (final b in fbx.materialTextures) {
      final file = '${b['file']}'.isEmpty ? 'embedded image' : File('${b['file']}').uri.pathSegments.last;
      _logger.log(
        'FBX "$fileName": ${ImportedAssetNames.material('${b['material']}', baseName)} '
        '${slotLabels[b['slot']] ?? b['slot']} ← $file (${b['source']}).',
        level: 'info',
        source: 'AssetRepository',
      );
    }
  }

  /// STEP 3: Auto Organize / Target Paths
  @override
  Map<String, String> resolveTargetPaths({
    required String projectPath,
    required String baseName,
    required AssetType primaryType,
    required bool autoOrganize,
    required String? browserSelectedFolder,
    required List<String> extractedSubAssets,
  }) {
    final result = <String, String>{};
    
    // Determine primary path
    String primaryPath = '';
    if (autoOrganize) {
      final lowerBase = baseName.toLowerCase();
      final isSkeletal = primaryType == AssetType.filameshSk ||
          primaryType == AssetType.actor ||
          lowerBase.startsWith('skm_') ||
          lowerBase.contains('skeletal') ||
          lowerBase.contains('skeleton') ||
          lowerBase.contains('manny') ||
          lowerBase.contains('quinn') ||
          lowerBase.contains('character');

      if (isSkeletal) {
        primaryPath = 'contents/meshes/skeletal/$baseName.lmas';
      } else if (primaryType == AssetType.filamesh) {
        primaryPath = 'contents/meshes/static/$baseName.lmas';
      } else if (primaryType == AssetType.texture) {
        primaryPath = 'contents/textures/$baseName.lmas';
      } else if (primaryType == AssetType.audio) {
        primaryPath = 'contents/audio/$baseName.lmas';
      } else if (primaryType == AssetType.animation) {
        primaryPath = 'contents/animations/$baseName/$baseName.lmas';
      } else if (primaryType == AssetType.particle) {
        primaryPath = 'contents/particles/$baseName.lmas';
      } else {
        primaryPath = 'contents/meshes/static/$baseName.lmas';
      }
    } else {
      final folder = browserSelectedFolder ?? 'contents';
      primaryPath = '$folder/$baseName.lmas';
    }
    result['primary'] = primaryPath;
    
    // Sub assets
    for (final sub in extractedSubAssets) {
      if (autoOrganize) {
        if (sub.startsWith('M_')) {
          result[sub] = 'contents/materials/$baseName/$sub.lmas';
        } else if (sub.startsWith('T_')) {
          result[sub] = 'contents/textures/$baseName/$sub.lmas';
        } else if (sub.startsWith('A_')) {
          result[sub] = 'contents/animations/$baseName/$sub.lmas';
        } else {
          result[sub] = 'contents/$baseName/$sub.lmas';
        }
      } else {
        final folder = browserSelectedFolder ?? 'contents';
        if (sub.startsWith('M_')) {
          result[sub] = '$folder/materials/$sub.lmas';
        } else if (sub.startsWith('T_')) {
          result[sub] = '$folder/textures/$sub.lmas';
        } else if (sub.startsWith('A_')) {
          result[sub] = '$folder/animations/$sub.lmas';
        } else {
          result[sub] = '$folder/$sub.lmas';
        }
      }
    }
    
    return result;
  }
}

/// Reads and removes the `.import.json` sidecar [_stageFbx] (or, for a
/// texture, [stageImport]) wrote beside
/// [stagedFilePath] (every pipeline deletes only the staged file itself).
Map<String, dynamic> _takeImportSidecar(String stagedFilePath) {
  final sidecar = File('$stagedFilePath.import.json');
  if (!sidecar.existsSync()) return const {};
  try {
    return jsonDecode(sidecar.readAsStringSync()) as Map<String, dynamic>;
  } catch (_) {
    return const {};
  } finally {
    try {
      sidecar.deleteSync();
    } catch (_) {}
  }
}

bool _isGlbBytes(Uint8List bytes) =>
    bytes.length > 20 && bytes[0] == 0x67 && bytes[1] == 0x6C && bytes[2] == 0x54 && bytes[3] == 0x46;

/// STEP 2: Conversion
/// Converts GLB/OBJ to .filamesh and materials to .filamat
