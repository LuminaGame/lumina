part of '../asset_repository.dart';

/// Emitting an imported asset family (meshes, materials, textures,
/// skeleton, animations) and importing external files.
mixin _AssetFamilyEmission on _AssetRepositoryState {

  /// STEP 4: Emit Asset Family
  ///
  /// A texture whose map already carries `thumbnailPng` (drawn by
  /// [renderImportThumbnails]) keeps it, so with every thumbnail drawn this
  /// needs no `dart:ui` and runs in the import worker isolate. Every
  /// project-relative `.lmas` path written is added to [writtenPaths].
  @override
  Future<List<LuminaAsset>> emitAssetFamily({
    required Map<String, String> targetPaths,
    required Map<String, dynamic> convertedData,
    List<String>? writtenPaths,
  }) async {
    final List<LuminaAsset> emittedAssets = [];
    final projectPath = convertedData['projectPath'] as String;

    // We will assume convertedData contains:
    // 'primaryPayload': Uint8List
    // 'primaryType': AssetType
    // 'baseName': String
    // 'materials': List of Map { 'name': 'M_...', 'baseColor': ..., 'textures': [{'slot': 'baseColorMap', 'name': 'T_...'}] }
    // 'textures': List of Map { 'name': 'T_...', 'payload': Uint8List }
    // 'thumbnailPng': Uint8List (optional)
    
    // 1. Generate UUIDs for all emitted assets
    // Wait, the task says: "Re-import of the same source file -> existing asset_ids are preserved for overwritten assets, not regenerated"
    final Map<String, String> uuidMap = {};
    for (final key in targetPaths.keys) {
      final path = '$projectPath/${targetPaths[key]}';
      final file = File(path);
      if (file.existsSync()) {
        try {
           final bytes = file.readAsBytesSync();
           final asset = LuminaAsset.fromBytes(bytes);
           uuidMap[key] = asset.assetId;
        } catch (_) {
           uuidMap[key] = AssetRepository._generateUuidV4();
        }
      } else {
        uuidMap[key] = AssetRepository._generateUuidV4();
      }
    }

    final baseName = convertedData['baseName'] as String;

    // Helper to write asset
    void writeAsset(String key, LuminaAsset asset) {
      final path = '$projectPath/${targetPaths[key]}';
      final file = File(path);
      if (!file.parent.existsSync()) file.parent.createSync(recursive: true);
      file.writeAsBytesSync(asset.toProtoBufferBytes());
      emittedAssets.add(asset);
      writtenPaths?.add(targetPaths[key]!);
    }

    // 2. Textures
    final textures = convertedData['textures'] as List<dynamic>? ?? [];
    final sourceFile = (convertedData['importMetadata'] as Map?)?['source_file'] as String?;
    for (final texMap in textures) {
      final name = texMap['name'] as String;
      final payload = texMap['payload'] as Uint8List;
      final format = texMap['format'] as String? ?? 'PNG';
      final settings = texMap['settings'] as Map?;
      final thumbBytes = texMap.containsKey('thumbnailPng')
          ? texMap['thumbnailPng'] as Uint8List?
          : await _generateThumbnailBytes(AssetType.texture, rawPayload: payload);
      final asset = LuminaAsset(
        assetId: uuidMap[name]!,
        name: name,
        type: AssetType.texture,
        hasThumbnail: thumbBytes != null,
        thumbnailPng: thumbBytes,
        rawPayload: payload,
        metadata: {
          'format': format,
          // The Texture editor's settings (colour space, compression group).
          if (settings != null) 'texture_settings': jsonEncode(settings),
          // A standalone texture's own entry: the file it came from, for the
          // Texture editor's Reimport.
          if (name == baseName && sourceFile != null) 'source_file': sourceFile,
        },
        references: [],
      );
      writeAsset(name, asset);

      // Write companion image file (.png/.jpg) beside .lmas
      if (targetPaths.containsKey(name)) {
        final ext = format.toLowerCase() == 'jpeg' || format.toLowerCase() == 'jpg' ? 'jpg' : 'png';
        final lmasPath = '$projectPath/${targetPaths[name]}';
        final imgFile = File(lmasPath.replaceAll(RegExp(r'\.lmas$'), '.$ext'));
        try {
          if (!imgFile.parent.existsSync()) imgFile.parent.createSync(recursive: true);
          imgFile.writeAsBytesSync(payload);
        } catch (_) {}
      }
    }

    // 3. Materials
    final materials = convertedData['materials'] as List<dynamic>? ?? [];
    for (final matMap in materials) {
      final name = matMap['name'] as String;
      final rawMatSource = matMap['rawMatSource'] as String? ?? 'compiled material source...';
      final baseColor = matMap['baseColor'] as List<double>? ?? [1,1,1,1];
      final matTextures = matMap['textures'] as List<dynamic>? ?? [];
      
      final List<AssetReference> refs = [];
      for (final mt in matTextures) {
        final slot = mt['slot'] as String;
        final tname = mt['name'] as String;
        if (targetPaths.containsKey(tname)) {
          refs.add(AssetReference(
            slotName: slot,
            assetId: uuidMap[tname]!,
            assetPath: targetPaths[tname]!,
          ));
        }
      }
      
      final asset = LuminaAsset(
        assetId: uuidMap[name]!,
        name: name,
        type: AssetType.filamat,
        rawMatSource: rawMatSource,
        metadata: {
          'baseColor': '${baseColor[0]},${baseColor[1]},${baseColor[2]},${baseColor[3]}',
          if (matMap['metallic'] is num) 'metallic': '${matMap['metallic']}',
          if (matMap['roughness'] is num) 'roughness': '${matMap['roughness']}',
          if (matMap['emissive'] is List) 'emissive': (matMap['emissive'] as List).join(','),
        },
        references: refs,
      );
      writeAsset(name, asset);
    }

    // 3.5. Animations
    final animations = convertedData['animations'] as List<dynamic>? ?? [];
    for (final animMap in animations) {
      final name = animMap['name'] as String;
      final payload = animMap['payload'] as Uint8List;
      if (targetPaths.containsKey(name)) {
        final asset = LuminaAsset(
          assetId: uuidMap[name]!,
          name: name,
          type: AssetType.animation,
          rawPayload: payload,
          references: [],
        );
        writeAsset(name, asset);
      }
    }

    // 4. Primary (Mesh)
    final primaryType = convertedData['primaryType'] as AssetType;
    final primaryPayload = convertedData['primaryPayload'] as Uint8List;
    final primaryThumbnail = convertedData['thumbnailPng'] as Uint8List?;
    final meshFormat = convertedData['payloadFormat'] as String? ?? 'filamesh';
    
    final List<AssetReference> meshRefs = [];
    int slotIndex = 0;
    for (final matMap in materials) {
      final name = matMap['name'] as String;
      if (targetPaths.containsKey(name)) {
        meshRefs.add(AssetReference(
          slotName: 'material_slot_$slotIndex',
          assetId: uuidMap[name]!,
          assetPath: targetPaths[name]!,
        ));
      }
      slotIndex++;
    }

    final importMetadata = (convertedData['importMetadata'] as Map<String, String>?) ?? const {};
    if (primaryType == AssetType.animation &&
        importMetadata['source_format'] == 'FBX' &&
        _isGlbBytes(primaryPayload)) {
      _emitAnimation(
        projectPath: projectPath,
        targetPaths: targetPaths,
        convertedData: convertedData,
        primaryAssetId: uuidMap['primary']!,
        importMetadata: importMetadata,
        writeAsset: writeAsset,
        writtenPaths: writtenPaths,
      );
      return emittedAssets;
    }

    final primaryAsset = LuminaAsset(
      assetId: uuidMap['primary']!,
      name: baseName,
      type: primaryType,
      hasThumbnail: primaryThumbnail != null,
      thumbnailPng: primaryThumbnail,
      rawPayload: primaryPayload,
      references: meshRefs,
      metadata: {
        'payload_format': meshFormat,
        ...importMetadata,
      },
    );
    writeAsset('primary', primaryAsset);

    // If it's a 3D mesh, also write companion .entity.glb file beside .lmas
    if (primaryType == AssetType.filamesh || primaryType == AssetType.filameshSk || primaryType == AssetType.actor) {
      if (targetPaths.containsKey('primary')) {
        final primaryLmasPath = '$projectPath/${targetPaths['primary']}';
        final companionGlb = File(primaryLmasPath.replaceAll(RegExp(r'\.lmas$'), '.entity.glb'));
        try {
          if (!companionGlb.parent.existsSync()) companionGlb.parent.createSync(recursive: true);
          companionGlb.writeAsBytesSync(primaryPayload);
        } catch (_) {}
      }
    }

    // A standalone texture's image beside its .lmas, as for an extracted
    // texture (it used to come from a second texture asset).
    if (primaryType == AssetType.texture && targetPaths.containsKey('primary')) {
      final ext = EncodedImageFormat.sniff(primaryPayload) == EncodedImageFormat.jpeg ? 'jpg' : 'png';
      final imgFile = File('$projectPath/${targetPaths['primary']}'.replaceAll(RegExp(r'\.lmas$'), '.$ext'));
      try {
        if (!imgFile.parent.existsSync()) imgFile.parent.createSync(recursive: true);
        imgFile.writeAsBytesSync(primaryPayload);
      } catch (_) {}
    }

    return emittedAssets;
  }

  /// Writes an imported animation. Bound to a skeletal
  /// mesh, each clip is retargeted into that mesh's GLB and gets an asset
  /// that references the mesh and carries no payload (like the Third Person
  /// template's clips); the first clip is the primary asset, further takes
  /// sit beside it as `<clip>.lmas`. Unbound, the primary keeps the clip GLB
  /// as its payload and says why in `retarget_status`.
  void _emitAnimation({
    required String projectPath,
    required Map<String, String> targetPaths,
    required Map<String, dynamic> convertedData,
    required String primaryAssetId,
    required Map<String, String> importMetadata,
    required void Function(String key, LuminaAsset asset) writeAsset,
    List<String>? writtenPaths,
  }) {
    final baseName = convertedData['baseName'] as String;
    final payload = convertedData['primaryPayload'] as Uint8List;
    final thumbnail = convertedData['thumbnailPng'] as Uint8List?;
    final clips = (convertedData['animationClips'] as List?)?.cast<String>() ?? const <String>[];
    final target = convertedData['retargetTarget'] as String?;
    var note = convertedData['retargetNote'] as String? ?? 'not bound';

    if (target != null && clips.isNotEmpty) {
      try {
        final binding = AnimationImportBinder.bind(
          projectPath: projectPath,
          meshLmasPath: target,
          clipGlb: payload,
          clipNames: clips,
        );
        final meshRef = AssetReference(slotName: 'skeletal_mesh', assetId: binding.meshAssetId, assetPath: target);
        final primaryDir = File('$projectPath/${targetPaths['primary']}').parent.path;
        for (var i = 0; i < binding.clips.length; i++) {
          final clip = binding.clips[i];
          final asset = LuminaAsset(
            assetId: i == 0 ? primaryAssetId : AssetRepository._generateUuidV4(),
            name: i == 0 ? baseName : clip.clipName,
            type: AssetType.animation,
            hasThumbnail: thumbnail != null,
            thumbnailPng: thumbnail,
            references: [meshRef],
            metadata: {
              ...importMetadata,
              ...AnimationImportBinder.clipMetadata(target, clip),
              'retarget_status': 'bound: $note',
            },
          );
          if (i == 0) {
            writeAsset('primary', asset);
          } else {
            File('$primaryDir/${clip.clipName}.lmas').writeAsBytesSync(asset.toProtoBufferBytes());
            writtenPaths?.add('${File(targetPaths['primary']!).parent.path}/${clip.clipName}.lmas');
          }
          _logger.log(
            'Retargeted clip "${clip.clipName}" onto $target (${clip.mappedBones.length} bones mapped, '
            '${clip.restBones.length} held at rest, pelvis ×${clip.pelvisTranslationScale.toStringAsFixed(3)}, '
            '${clip.duration.toStringAsFixed(2)} s) as animation ${clip.clipIndex}.',
            level: 'success',
            source: 'AssetRepository',
          );
        }
        return;
      } catch (e) {
        note = 'not bound: retargeting onto $target failed: $e';
        _logger.log('Animation "$baseName" $note', level: 'error', source: 'AssetRepository');
      }
    } else {
      _logger.log('Animation "$baseName" $note', level: 'warning', source: 'AssetRepository');
    }

    writeAsset(
      'primary',
      LuminaAsset(
        assetId: primaryAssetId,
        name: baseName,
        type: AssetType.animation,
        hasThumbnail: thumbnail != null,
        thumbnailPng: thumbnail,
        rawPayload: payload,
        metadata: {
          'payload_format': 'glb',
          ...importMetadata,
          if (clips.isNotEmpty) 'clip_name': clips.first,
          'retarget_status': note,
        },
      ),
    );
  }

  /// Imports one external file: [prepareImport] → [writeImport] on the
  /// calling isolate. The Content Browser's batches go through `ImportQueue`
  /// instead, which runs the same steps in a worker
  /// isolate and writes exactly what this writes.
  Future<RealAssetInfo> importExternalFile({
    required String projectPath,
    required String sourceFilePath,
    String? targetSubFolder, // now equivalent to browserSelectedFolder
    bool autoOrganize = true,
    String? targetSkeletonPath,
    List<String> textureSearchDirs = const [],
  }) async {
    final prepared = await prepareImport(
      projectPath: projectPath,
      sourceFilePath: sourceFilePath,
      targetSubFolder: targetSubFolder,
      autoOrganize: autoOrganize,
      targetSkeletonPath: targetSkeletonPath,
      textureSearchDirs: textureSearchDirs,
    );
    return (await writeImport(prepared)).info;
  }
}
