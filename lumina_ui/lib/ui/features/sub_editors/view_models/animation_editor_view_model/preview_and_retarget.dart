part of '../animation_editor_view_model.dart';

/// Choosing the preview skeletal mesh and retargeting the animation onto
/// another skeleton.
mixin _AnimationEditorPreviewAndRetarget on _AnimationEditorViewModelState {

  Future<void> setPreviewMesh(RealAssetInfo meshAsset, {bool markDirty = true}) async {
    _previewMeshAsset = meshAsset;
    _previewMeshPath = meshAsset.relativePath;
    if (markDirty) {
      _isDirty = true;
    }

    final projectDir = AnimationEditorViewModel._findProjectDir(assetPath);
    final targetPath = meshAsset.lmasPath ??
        (projectDir != null ? '$projectDir/${meshAsset.relativePath}' : null);
    if (targetPath != null) {
      final file = File(targetPath);
      if (file.existsSync()) {
        try {
          var parsedMesh = await AssetRepository.loadMeshFromDisk(targetPath);
          if (parsedMesh == null) {
            final bytes = await file.readAsBytes();
            LuminaAsset? meshLuminaAsset;
            try {
              meshLuminaAsset = LuminaAsset.fromBytes(bytes);
            } catch (_) {}
            if (meshLuminaAsset?.rawPayload != null &&
                meshLuminaAsset!.rawPayload!.isNotEmpty) {
              parsedMesh =
                  await GlbParserService.parseGlb(meshLuminaAsset.rawPayload!);
            }
          }
          if (parsedMesh != null) {
            if (_clips.isNotEmpty && parsedMesh.animations.isEmpty) {
              _glbMesh = parsedMesh.copyWith(animations: _clips);
            } else {
              _glbMesh = parsedMesh;
            }
            _refreshSkeleton();
            _updatePlaybackController();
          }
        } catch (_) {}
      }
    }
    notifyListeners();
  }

  Future<String?> executeRetarget({
    required RealAssetInfo targetMeshAsset,
    required String outputName,
  }) async {
    final projectDir = AnimationEditorViewModel._findProjectDir(assetPath);
    if (projectDir == null) return null;

    final cleanName = outputName.replaceAll(RegExp(r'\.lmas$'), '');
    final outDir = Directory('$projectDir/contents/animations');
    await outDir.create(recursive: true);

    final outPath = '${outDir.path}/$cleanName.lmas';
    final companionGlbPath = '${outDir.path}/$cleanName.entity.glb';

    // 1. Resolve source GLB bytes containing animation clips
    Uint8List? sourceGlbBytes;
    if (_asset?.rawPayload != null && _asset!.rawPayload!.isNotEmpty) {
      sourceGlbBytes = _asset!.rawPayload!;
    } else {
      final sourceMeshRel = _asset?.metadata['source_mesh'];
      if (sourceMeshRel != null && sourceMeshRel.isNotEmpty) {
        final sourceMeshAbs = '$projectDir/$sourceMeshRel';
        final compFile = File(sourceMeshAbs.replaceAll(RegExp(r'\.lmas$'), '.entity.glb'));
        if (await compFile.exists()) {
          sourceGlbBytes = await compFile.readAsBytes();
        } else {
          final lmasFile = File(sourceMeshAbs);
          if (await lmasFile.exists()) {
            try {
              final lmasAsset = LuminaAsset.fromBytes(await lmasFile.readAsBytes());
              if (lmasAsset.rawPayload != null && lmasAsset.rawPayload!.isNotEmpty) {
                sourceGlbBytes = lmasAsset.rawPayload!;
              }
            } catch (_) {}
          }
        }
      }
    }
    if (sourceGlbBytes == null && _glbMesh?.rawPayload != null && _glbMesh!.rawPayload!.isNotEmpty) {
      sourceGlbBytes = _glbMesh!.rawPayload!;
    }

    // 2. Resolve target GLB bytes
    Uint8List? targetGlbBytes;
    final targetLmasPath = targetMeshAsset.lmasPath ?? '$projectDir/${targetMeshAsset.relativePath}';
    final targetCompFile = File(targetLmasPath.replaceAll(RegExp(r'\.lmas$'), '.entity.glb'));
    if (await targetCompFile.exists()) {
      targetGlbBytes = await targetCompFile.readAsBytes();
    } else {
      final targetLmasFile = File(targetLmasPath);
      if (await targetLmasFile.exists()) {
        try {
          final targetAsset = LuminaAsset.fromBytes(await targetLmasFile.readAsBytes());
          if (targetAsset.rawPayload != null && targetAsset.rawPayload!.isNotEmpty) {
            targetGlbBytes = targetAsset.rawPayload!;
          }
        } catch (_) {}
      }
    }

    // 3. Perform real GLB retargeting if models have skins and animation
    GlbRetargetResult? retargetResult;
    if (sourceGlbBytes != null && targetGlbBytes != null) {
      try {
        final clipIdx = (_selectedClip >= 0 && _selectedClip < _clips.length) ? _selectedClip : 0;
        final target = targetGlbBytes, clip = sourceGlbBytes;
        // Retargeting a clip into a full skeletal mesh GLB is CPU work on
        // hundreds of megabytes: a background isolate.
        retargetResult = await Isolate.run(() => GlbAnimationRetargeter.retargetInto(
              target: target,
              clip: clip,
              clipName: cleanName,
              animationIndex: clipIdx,
            ));
      } catch (e) {
        debugPrint('[AnimationEditorViewModel] GlbAnimationRetargeter error: $e');
      }
    }

    // 4. Save companion .entity.glb if retarget succeeded
    if (retargetResult != null) {
      await File(companionGlbPath).writeAsBytes(retargetResult.glb);
    }

    // 5. Build and save new .lmas asset
    final updatedMetadata = Map<String, String>.from(_asset?.metadata ?? {});
    updatedMetadata['source_mesh'] = targetMeshAsset.relativePath;
    updatedMetadata['target_mesh'] = targetMeshAsset.relativePath;
    updatedMetadata['preview_mesh_path'] = targetMeshAsset.relativePath;
    updatedMetadata['clip_name'] = cleanName;
    updatedMetadata['clip_index'] = '0';
    final animProps = {
      'rate_scale': _rateScale,
      'interpolation': _interpolation,
      'additive_type': _additiveType,
      'frame_rate': _frameRate,
      'default_clip': 0,
      'preview_mesh_path': targetMeshAsset.relativePath,
    };
    updatedMetadata['anim_properties'] = jsonEncode(animProps);
    updatedMetadata['last_modified'] = DateTime.now().toIso8601String();

    final newAsset = LuminaAsset(
      assetId: 'retarget_${DateTime.now().millisecondsSinceEpoch}',
      name: cleanName,
      type: AssetType.animation,
      rawPayload: retargetResult != null ? Uint8List(0) : (_asset?.rawPayload ?? Uint8List(0)),
      thumbnailPng: _asset?.thumbnailPng,
      metadata: updatedMetadata,
    );

    await File(outPath).writeAsBytes(newAsset.toProtoBufferBytes());

    // 6. Switch live preview in active editor to the newly retargeted model and clip
    if (retargetResult != null) {
      try {
        final parsedMesh = await GlbParserService.parseGlb(retargetResult.glb);
        if (parsedMesh != null) {
          _previewMeshAsset = targetMeshAsset;
          _previewMeshPath = targetMeshAsset.relativePath;
          _glbMesh = parsedMesh;
          _clips = List<GlbAnimationClip>.from(parsedMesh.animations);
          _selectedClip = 0;
          _positionSeconds = 0.0;
          _updatePlaybackController();
          notifyListeners();
        }
      } catch (_) {}
    }

    AssetRepository.notifyAssetsChanged();

    return outPath;
  }
}
