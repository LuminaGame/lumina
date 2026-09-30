part of '../asset_repository.dart';

/// Converting a staged import into `.lmas` assets.
mixin _AssetStagedConversion on _AssetRepositoryState {

  ///
  /// For an animation GLB, [targetSkeletonPath] picks the project skeletal
  /// mesh (`contents/...lmas`) its clips are retargeted onto: null matches
  /// one automatically by bone names, `''` keeps the animation unbound.
  ///
  /// With [renderThumbnails] false nothing here touches `dart:ui`, so the
  /// conversion can run in a background isolate: the
  /// thumbnail is left as a [PendingImportThumbnail] under
  /// `pendingThumbnail` — its mesh already parsed and projected — for
  /// [renderImportThumbnails] to draw on the UI isolate.
  @override
  Future<Map<String, dynamic>> convertStagedAsset({
    required String projectPath,
    required String stagedFilePath,
    required AssetType detectedType,
    String? targetSkeletonPath,
    bool renderThumbnails = true,
  }) async {
    final sourceFile = File(stagedFilePath);
    final originalFileName = sourceFile.uri.pathSegments.last;
    final baseName = originalFileName.contains('.') ? originalFileName.substring(0, originalFileName.lastIndexOf('.')) : originalFileName;

    Uint8List primaryPayload = await sourceFile.readAsBytes();
    String meshFormat = 'glb';
    
    final isMeshType = detectedType == AssetType.filamesh ||
        detectedType == AssetType.filameshSk ||
        detectedType == AssetType.actor;

    if (isMeshType) {
      if (FlutterAssimp.isSupportedFormat(stagedFilePath) &&
          !stagedFilePath.toLowerCase().endsWith('.glb') &&
          !stagedFilePath.toLowerCase().endsWith('.gltf')) {
        try {
          final hint = originalFileName.contains('.') ? originalFileName.substring(originalFileName.lastIndexOf('.') + 1).toLowerCase() : 'fbx';
          final glbConverted = await Isolate.run(() async {
            final memRes = await FlutterAssimp.convertMemoryToGlb(primaryPayload, hint: hint);
            if (memRes != null && memRes.isNotEmpty) return memRes;
            final tempGlbPath = '${Directory.systemTemp.path}/lumina_conv_${DateTime.now().millisecondsSinceEpoch}.glb';
            final ok = await FlutterAssimp.convertFileToGlb(stagedFilePath, tempGlbPath);
            if (ok && File(tempGlbPath).existsSync()) {
              final bytes = File(tempGlbPath).readAsBytesSync();
              File(tempGlbPath).deleteSync();
              return bytes;
            }
            return null;
          });

          if (glbConverted != null && glbConverted.isNotEmpty) {
            primaryPayload = await GlbParserService.convertGlbTgaToPngAsync(glbConverted, searchDirs: [sourceFile.parent.path, '$projectPath/contents/textures']);
          }
        } catch (_) {}
      } else if (primaryPayload.length >= 12 && primaryPayload[0] == 0x67 && primaryPayload[1] == 0x6C && primaryPayload[2] == 0x54 && primaryPayload[3] == 0x46) {
        primaryPayload = await GlbParserService.convertGlbTgaToPngAsync(primaryPayload, searchDirs: [sourceFile.parent.path, '$projectPath/contents/textures']);
      }
    }

    final List<Map<String, dynamic>> materialsList = [];
    final List<Map<String, dynamic>> texturesList = [];
    final List<Map<String, dynamic>> animationsList = [];
    
    if (isMeshType && 
        primaryPayload.length > 50 && primaryPayload[0] == 0x67) {
      
      Map<String, dynamic>? gltfJson;
      try {
        final length = primaryPayload.buffer.asByteData().getUint32(12, Endian.little);
        if (primaryPayload.length >= 20 + length) {
          final jsonStr = utf8.decode(primaryPayload.sublist(20, 20 + length));
          gltfJson = jsonDecode(jsonStr) as Map<String, dynamic>;
        }
      } catch (_) {}

      if (gltfJson != null) {
        final images = gltfJson['images'] as List<dynamic>? ?? [];
        final bufferViews = gltfJson['bufferViews'] as List<dynamic>? ?? [];
        final textures = gltfJson['textures'] as List<dynamic>? ?? [];
        final materials = gltfJson['materials'] as List<dynamic>? ?? [];
        final animations = gltfJson['animations'] as List<dynamic>? ?? [];

        final jsonLength = primaryPayload.buffer.asByteData().getUint32(12, Endian.little);
        final binOffset = 20 + jsonLength;
        final binBytes = primaryPayload.length > binOffset + 8 ? primaryPayload.sublist(binOffset + 8) : Uint8List(0);

        // What each image is sampled as decides its colour
        // space — normal / metallic-roughness / occlusion maps are data
        // (linear), everything else colour (sRGB).
        final Map<int, Set<String>> imageSlots = {};
        for (final m in materials) {
          for (final (slot, ref) in FbxImportService.textureSlots(m as Map)) {
            final texIdx = ref['index'] as int?;
            if (texIdx == null || texIdx >= textures.length) continue;
            final source = (textures[texIdx] as Map)['source'] as int? ?? texIdx;
            imageSlots.putIfAbsent(source, () => {}).add(slot);
          }
        }

        final Map<int, String> imageIndexToName = {};
        for (int imgIdx = 0; imgIdx < images.length; imgIdx++) {
          final imgMap = images[imgIdx] as Map<String, dynamic>;
          final rawImgName = imgMap['name'] as String? ?? 'Tex$imgIdx';
          final safeTexName = ImportedAssetNames.texture(rawImgName, baseName);
          imageIndexToName[imgIdx] = safeTexName;

          Uint8List? imgBytes;
          if (imgMap['bufferView'] != null) {
            final bvIdx = imgMap['bufferView'] as int;
            if (bvIdx < bufferViews.length) {
              final bv = bufferViews[bvIdx] as Map<String, dynamic>;
              final byteOffset = bv['byteOffset'] as int? ?? 0;
              final byteLength = bv['byteLength'] as int? ?? 0;
              if (byteOffset + byteLength <= binBytes.length) {
                imgBytes = binBytes.sublist(byteOffset, byteOffset + byteLength);
              }
            }
          } else if (imgMap['uri'] != null) {
            final uriStr = imgMap['uri'] as String;
            if (uriStr.startsWith('data:')) {
              try {
                final commaIdx = uriStr.indexOf(',');
                if (commaIdx != -1) {
                  imgBytes = base64Decode(uriStr.substring(commaIdx + 1));
                }
              } catch (_) {}
            } else {
              final srcDir = sourceFile.parent;
              final externalFile = File('${srcDir.path}/$uriStr');
              if (externalFile.existsSync()) {
                imgBytes = externalFile.readAsBytesSync();
              }
            }
          }

          final mimeType = imgMap['mimeType'] as String? ?? '';
          final format = mimeType.contains('jpeg') || mimeType.contains('jpg') ? 'JPEG' : 'PNG';

          final slots = imageSlots[imgIdx] ?? const <String>{};
          final linear = slots.isNotEmpty &&
              slots.every((s) => s == 'normalMap' || s == 'metallicRoughnessMap' || s == 'occlusionMap');
          texturesList.add({
            'name': safeTexName,
            'payload': imgBytes ?? Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]),
            'format': format,
            if (slots.isNotEmpty)
              'settings': {'srgb': !linear, 'group': linear && slots.contains('normalMap') ? 'Normalmap' : 'World'},
          });
        }

        // Process materials
        int matIdx = 0;
        for (final m in materials) {
          final matMap = m as Map<String, dynamic>;
          final rawMatName = matMap['name'] as String? ?? 'Mat$matIdx';
          final safeMatName = ImportedAssetNames.material(rawMatName, baseName);

          List<double> baseColor = [0.8, 0.8, 0.8, 1.0];
          // glTF defaults: metallic 1, roughness 1, no emission.
          var metallic = 1.0;
          var roughness = 1.0;
          final emissive = FbxMaterialMapper.emissiveOf(matMap);
          final List<Map<String, String>> texRefs = [];

          if (matMap['pbrMetallicRoughness'] != null) {
            final pbr = matMap['pbrMetallicRoughness'] as Map<String, dynamic>;
            metallic = (pbr['metallicFactor'] as num?)?.toDouble() ?? 1.0;
            roughness = (pbr['roughnessFactor'] as num?)?.toDouble() ?? 1.0;
            if (pbr['baseColorFactor'] != null) {
              final bcf = pbr['baseColorFactor'] as List<dynamic>;
              if (bcf.length >= 3) {
                baseColor = [
                  (bcf[0] as num).toDouble(),
                  (bcf[1] as num).toDouble(),
                  (bcf[2] as num).toDouble(),
                  bcf.length > 3 ? (bcf[3] as num).toDouble() : 1.0,
                ];
              }
            }
            if (pbr['baseColorTexture'] != null) {
              final texIdx = (pbr['baseColorTexture'] as Map<String, dynamic>)['index'] as int?;
              if (texIdx != null && texIdx < textures.length) {
                final texObj = textures[texIdx] as Map<String, dynamic>;
                final sourceImgIdx = texObj['source'] as int? ?? texIdx;
                final texName = imageIndexToName[sourceImgIdx] ?? 'T_${baseName}_BaseColor_$texIdx';
                texRefs.add({'slot': 'baseColorMap', 'name': texName});
              }
            }
            if (pbr['metallicRoughnessTexture'] != null) {
              final texIdx = (pbr['metallicRoughnessTexture'] as Map<String, dynamic>)['index'] as int?;
              if (texIdx != null && texIdx < textures.length) {
                final texObj = textures[texIdx] as Map<String, dynamic>;
                final sourceImgIdx = texObj['source'] as int? ?? texIdx;
                final texName = imageIndexToName[sourceImgIdx] ?? 'T_${baseName}_MetallicRoughness_$texIdx';
                texRefs.add({'slot': 'metallicRoughnessMap', 'name': texName});
              }
            }
          }
          if (matMap['normalTexture'] != null) {
            final texIdx = (matMap['normalTexture'] as Map<String, dynamic>)['index'] as int?;
            if (texIdx != null && texIdx < textures.length) {
              final texObj = textures[texIdx] as Map<String, dynamic>;
              final sourceImgIdx = texObj['source'] as int? ?? texIdx;
              final texName = imageIndexToName[sourceImgIdx] ?? 'T_${baseName}_NormalMap_$texIdx';
              texRefs.add({'slot': 'normalMap', 'name': texName});
            }
          }
          if (matMap['occlusionTexture'] != null) {
            final texIdx = (matMap['occlusionTexture'] as Map<String, dynamic>)['index'] as int?;
            if (texIdx != null && texIdx < textures.length) {
              final texObj = textures[texIdx] as Map<String, dynamic>;
              final sourceImgIdx = texObj['source'] as int? ?? texIdx;
              final texName = imageIndexToName[sourceImgIdx] ?? 'T_${baseName}_OcclusionMap_$texIdx';
              texRefs.add({'slot': 'occlusionMap', 'name': texName});
            }
          }
          if (matMap['emissiveTexture'] != null) {
            final texIdx = (matMap['emissiveTexture'] as Map<String, dynamic>)['index'] as int?;
            if (texIdx != null && texIdx < textures.length) {
              final texObj = textures[texIdx] as Map<String, dynamic>;
              final sourceImgIdx = texObj['source'] as int? ?? texIdx;
              final texName = imageIndexToName[sourceImgIdx] ?? 'T_${baseName}_EmissiveMap_$texIdx';
              texRefs.add({'slot': 'emissiveMap', 'name': texName});
            }
          }
          if (matMap['extensions'] != null && matMap['extensions']['KHR_materials_specular'] != null) {
            final spec = matMap['extensions']['KHR_materials_specular'] as Map<String, dynamic>;
            if (spec['specularTexture'] != null) {
              final texIdx = (spec['specularTexture'] as Map<String, dynamic>)['index'] as int?;
              if (texIdx != null && texIdx < textures.length) {
                final texObj = textures[texIdx] as Map<String, dynamic>;
                final sourceImgIdx = texObj['source'] as int? ?? texIdx;
                final texName = imageIndexToName[sourceImgIdx] ?? 'T_${baseName}_SpecularMap_$texIdx';
                texRefs.add({'slot': 'specularMap', 'name': texName});
              }
            }
          }

          final rawMatSource = buildImportedMaterialSource(
            name: safeMatName,
            baseColor: baseColor,
            metallic: metallic,
            roughness: roughness,
            emissive: emissive,
            textureSlots: texRefs.map((r) => r['slot']!).toList(),
          );

          materialsList.add({
            'name': safeMatName,
            'rawMatSource': rawMatSource,
            'baseColor': baseColor,
            'metallic': metallic,
            'roughness': roughness,
            'emissive': emissive,
            'textures': texRefs,
          });
          matIdx++;
        }

        // Process animations
        int animIdx = 0;
        for (final anim in animations) {
          final animMap = anim as Map<String, dynamic>;
          final aName = animMap['name'] as String? ?? 'A_${baseName}_Clip$animIdx';
          final safeAnimName = aName.startsWith('A_') ? aName : 'A_${baseName}_$aName';
          animationsList.add({
            'name': safeAnimName,
            'payload': primaryPayload,
          });
          animIdx++;
        }
      }
    }
    // A standalone texture is the primary asset alone: listing it under
    // `textures` as well wrote it twice with two ids.

    Uint8List? thumbBytes;
    PendingImportThumbnail? pendingThumbnail;
    if (isMeshType || detectedType == AssetType.texture) {
      if (renderThumbnails) {
        thumbBytes = await _generateThumbnailBytes(detectedType, rawPayload: primaryPayload);
      } else {
        pendingThumbnail = PendingImportThumbnail(
          type: detectedType,
          fromPayload: true,
          geometry: await MeshThumbnailGeometry.forPayload(detectedType, primaryPayload),
        );
      }
    }

    final sidecar = _takeImportSidecar(stagedFilePath);
    final importMetadata = <String, String>{
      for (final e in ((sidecar['metadata'] as Map?) ?? const {}).entries) '${e.key}': '${e.value}',
    };

    // An FBX animation: its clips and the skeletal mesh
    // they will play on. (A glTF animation keeps the pre-FBX behaviour.)
    List<String> animationClips = const [];
    String? retargetTarget;
    String? retargetNote;
    final fromFbx = importMetadata['source_format'] == 'FBX';
    if (fromFbx && detectedType == AssetType.animation && _isGlbBytes(primaryPayload)) {
      if (renderThumbnails) {
        thumbBytes ??= await _generateThumbnailBytes(AssetType.animation);
      } else {
        pendingThumbnail ??= const PendingImportThumbnail(type: AssetType.animation, fromPayload: false);
      }
      animationClips = GlbAnimationMerger.animationNames(primaryPayload);
      if (targetSkeletonPath == '') {
        retargetNote = 'not bound: import chose no skeletal mesh';
      } else {
        final skeletal = [
          for (final a in scanProjectContents(projectPath))
            if (a.type == AssetType.filameshSk) a.relativePath,
        ];
        if (targetSkeletonPath != null) {
          final ranked = AnimationImportBinder.rankTargets(
            projectPath: projectPath,
            skeletalMeshLmasPaths: [targetSkeletonPath],
            clipGlb: primaryPayload,
          );
          if (ranked.isNotEmpty && ranked.first.match.matched > 0) {
            retargetTarget = targetSkeletonPath;
            retargetNote = 'chosen: ${ranked.first.match.matched}/${ranked.first.match.animated} bones match';
          } else {
            retargetNote = 'not bound: $targetSkeletonPath shares no bone with the clip';
          }
        } else {
          final picked = AnimationImportBinder.pickTarget(
            projectPath: projectPath,
            skeletalMeshLmasPaths: skeletal,
            clipGlb: primaryPayload,
          );
          if (picked != null) {
            retargetTarget = picked.lmasPath;
            retargetNote = 'matched by bone names: ${picked.match.matched}/${picked.match.animated} bones';
          } else {
            retargetNote = skeletal.isEmpty
                ? 'not bound: the project has no skeletal mesh'
                : 'not bound: no skeletal mesh shares at least half of the clip\'s bones';
          }
        }
      }
    }

    return {
      'projectPath': projectPath,
      'primaryPayload': primaryPayload,
      'primaryType': detectedType,
      'baseName': baseName,
      'payloadFormat': meshFormat,
      'thumbnailPng': thumbBytes,
      'pendingThumbnail': ?pendingThumbnail,
      'materials': materialsList,
      'textures': texturesList,
      'animations': animationsList,
      'importMetadata': importMetadata,
      'animationClips': animationClips,
      'retargetTarget': retargetTarget,
      'retargetNote': retargetNote,
    };
  }
}
