part of '../anim_blueprint_editor_view_model.dart';

/// Loading and saving the ANIM_BLUEPRINT `.lmas`, the target mesh and its
/// blend spaces, and retargeting the Anim Blueprint to another skeleton.
mixin _AnimBlueprintEditorLoadSaveAndRetarget on _AnimBlueprintEditorViewModelState {

  // ---------------------------------------------------------------------------
  // Load / save
  // ---------------------------------------------------------------------------

  Future<void> load() async {
    final dir = projectDir;
    final doc = dir == null ? null : AnimGraphAssetService.readAnimBlueprint(dir, relativePath);
    _document = doc ?? LuminaAnimBlueprintDocument();
    _onDiskJson = doc == null ? '' : AnimBlueprintEditorViewModel._json(_document);
    _syncTargetMesh();
    transactions.clear();
    _ruleEditors.clear();
    _location = const AnimGraphLocation.animGraph();
    _compileStatus = BlueprintCompileStatus.unknown;
    _rows = const [];
    _revision++;
    notifyListeners();
    eventGraph.documentChanged();
  }

  void _syncTargetMesh() {
    _targetMeshRevision++;
    final dir = projectDir;
    if (dir != null) {
      _clips = AnimGraphAssetService.clipNames(dir, _document.targetMesh);
      _reloadBlendSpaces();
      final source = AnimGraphAssetService.meshSource(dir, _document.targetMesh);
      preview.setMesh(source?.path, provider: source?.provider);
    }
    _previewRevision = -1;
  }

  /// Sets the target skeletal mesh of this Animation Blueprint, reloading
  /// clips, blend spaces, and the preview scene mesh.
  bool setTargetMesh(String newTargetMesh) {
    if (newTargetMesh == _document.targetMesh) return true;
    final ok = mutate('Change Target Mesh', () {
      _document = _document.copyWith(targetMesh: newTargetMesh);
      _syncTargetMesh();
      return true;
    });
    return ok == true;
  }

  @override
  void _reloadBlendSpaces() {
    final dir = projectDir;
    if (dir == null) return;
    _blendSpacePaths = AnimGraphAssetService.blendSpacesFor(dir, _document.targetMesh);
    _blendSpaces.clear();
    final wanted = {
      ..._blendSpacePaths,
      for (final m in _document.stateMachines)
        for (final s in m.states)
          if (s.pose.blendSpace != null && s.pose.blendSpace!.isNotEmpty) s.pose.blendSpace!,
    };
    for (final path in wanted) {
      final bs = AnimGraphAssetService.readBlendSpace(dir, path);
      if (bs != null) _blendSpaces[path] = bs;
    }
  }

  /// Blend Spaces the states play, as the validator and preview read them.
  @override
  Map<String, LuminaBlendSpaceDocument> get stateBlendSpaces => {
        for (final m in _document.stateMachines)
          for (final s in m.states)
            if (s.pose.blendSpace != null && _blendSpaces.containsKey(s.pose.blendSpace)) s.pose.blendSpace!: _blendSpaces[s.pose.blendSpace]!,
      };
  bool get isRetargeting => _isRetargeting;

  /// Returns all unique animation clips referenced across all state machines
  /// (both direct state clips and samples from referenced Blend Spaces).
  List<String> get linkedClips {
    final clips = <String>{};
    for (final m in _document.stateMachines) {
      for (final s in m.states) {
        if (s.pose.kind == LuminaAnimPoseKind.clip && s.pose.clip != null && s.pose.clip!.isNotEmpty) {
          clips.add(s.pose.clip!);
        } else if (s.pose.kind == LuminaAnimPoseKind.blendSpace && s.pose.blendSpace != null && s.pose.blendSpace!.isNotEmpty) {
          final bs = _blendSpaces[s.pose.blendSpace] ?? (projectDir != null ? AnimGraphAssetService.readBlendSpace(projectDir!, s.pose.blendSpace!) : null);
          if (bs != null) {
            for (final sample in bs.samples) {
              if (sample.clip.isNotEmpty) clips.add(sample.clip);
            }
          }
        }
      }
    }
    return clips.toList()..sort();
  }

  /// Returns all Blend Space asset paths referenced by states in this Animation Blueprint.
  List<String> get linkedBlendSpacePaths {
    final paths = <String>{};
    for (final m in _document.stateMachines) {
      for (final s in m.states) {
        if (s.pose.kind == LuminaAnimPoseKind.blendSpace && s.pose.blendSpace != null && s.pose.blendSpace!.isNotEmpty) {
          paths.add(s.pose.blendSpace!);
        }
      }
    }
    return paths.toList()..sort();
  }

  /// Retargets all linked animations (state clips and blend spaces) to [targetMeshAsset]
  /// and updates the Animation Blueprint document, target mesh entity GLB, and preview.
  /// If [saveAsNew] is true, writes a new Animation Blueprint file under the target mesh folder.
  Future<String?> executeRetarget({
    required RealAssetInfo targetMeshAsset,
    String? outputName,
    bool saveAsNew = false,
  }) async {
    final dir = projectDir;
    if (dir == null) return null;

    _isRetargeting = true;
    notifyListeners();

    try {
      final targetMeshRel = targetMeshAsset.relativePath;
      final targetBase = AnimGraphAssetService.baseName(targetMeshRel);
      final sourceMeshRel = _document.targetMesh;
      final sourceBase = AnimGraphAssetService.baseName(sourceMeshRel);

      // 1. Gather all linked clips & blend spaces
      final directClips = <String>{};
      final referencedBlendSpaces = <String, LuminaBlendSpaceDocument>{};
      final blendSpaceClips = <String>{};

      for (final sm in _document.stateMachines) {
        for (final st in sm.states) {
          if (st.pose.kind == LuminaAnimPoseKind.clip && st.pose.clip != null && st.pose.clip!.isNotEmpty) {
            directClips.add(st.pose.clip!);
          } else if (st.pose.kind == LuminaAnimPoseKind.blendSpace && st.pose.blendSpace != null && st.pose.blendSpace!.isNotEmpty) {
            final bsPath = st.pose.blendSpace!;
            final bsDoc = _blendSpaces[bsPath] ?? AnimGraphAssetService.readBlendSpace(dir, bsPath);
            if (bsDoc != null) {
              referencedBlendSpaces[bsPath] = bsDoc;
              for (final s in bsDoc.samples) {
                if (s.clip.isNotEmpty) blendSpaceClips.add(s.clip);
              }
            }
          }
        }
      }

      final allClips = {...directClips, ...blendSpaceClips}.toList()..sort();

      // 2. Resolve source GLB bytes
      Uint8List? sourceGlbBytes;
      final sourceCompFile = File('$dir/${sourceMeshRel.replaceAll(RegExp(r'\.lmas$'), '.entity.glb')}');
      if (sourceCompFile.existsSync()) {
        sourceGlbBytes = await sourceCompFile.readAsBytes();
      } else if (sourceMeshRel.isNotEmpty) {
        final sourceLmasFile = File('$dir/$sourceMeshRel');
        if (sourceLmasFile.existsSync()) {
          try {
            final lmas = LuminaAsset.fromBytes(await sourceLmasFile.readAsBytes());
            if (lmas.rawPayload != null && lmas.rawPayload!.isNotEmpty) {
              sourceGlbBytes = lmas.rawPayload!;
            }
          } catch (_) {}
        }
      }

      // 3. Resolve target GLB bytes
      Uint8List? targetGlbBytes;
      final targetCompFile = File('$dir/${targetMeshRel.replaceAll(RegExp(r'\.lmas$'), '.entity.glb')}');
      if (targetCompFile.existsSync()) {
        targetGlbBytes = await targetCompFile.readAsBytes();
      } else {
        final targetLmasFile = File('$dir/$targetMeshRel');
        if (targetLmasFile.existsSync()) {
          try {
            final lmas = LuminaAsset.fromBytes(await targetLmasFile.readAsBytes());
            if (lmas.rawPayload != null && lmas.rawPayload!.isNotEmpty) {
              targetGlbBytes = lmas.rawPayload!;
            }
          } catch (_) {}
        }
      }

      if (targetGlbBytes == null) {
        throw Exception('Target skeletal mesh GLB not found for $targetMeshRel');
      }

      // Helper to find source GLB and animation index for a specific clip name
      ({Uint8List glb, int index})? resolveClipSource(String clipName) {
        if (sourceGlbBytes != null) {
          try {
            final names = GlbAnimationMerger.animationNames(sourceGlbBytes);
            final idx = names.indexOf(clipName);
            if (idx >= 0) return (glb: sourceGlbBytes, index: idx);
          } catch (_) {}
        }
        final candidates = [
          '$dir/contents/animations/$sourceBase/$clipName.entity.glb',
          '$dir/contents/animations/$sourceBase/$clipName.lmas',
          '$dir/contents/animations/$clipName.entity.glb',
          '$dir/contents/animations/$clipName.lmas',
        ];
        for (final c in candidates) {
          final f = File(c);
          if (f.existsSync()) {
            try {
              final bytes = f.readAsBytesSync();
              if (c.endsWith('.entity.glb')) {
                final names = GlbAnimationMerger.animationNames(bytes);
                final idx = names.indexOf(clipName);
                return (glb: bytes, index: idx >= 0 ? idx : 0);
              } else {
                final lmas = LuminaAsset.fromBytes(bytes);
                if (lmas.rawPayload != null && lmas.rawPayload!.isNotEmpty) {
                  final names = GlbAnimationMerger.animationNames(lmas.rawPayload!);
                  final idx = names.indexOf(clipName);
                  return (glb: lmas.rawPayload!, index: idx >= 0 ? idx : 0);
                }
              }
            } catch (_) {}
          }
        }
        return null;
      }

      // 4. Retarget clips sequentially into target mesh GLB
      var currentTargetGlb = targetGlbBytes;
      final retargetedClips = <String>[];
      final targetAnimDir = Directory('$dir/contents/animations/$targetBase');
      if (!targetAnimDir.existsSync()) {
        targetAnimDir.createSync(recursive: true);
      }

      for (final clipName in allClips) {
        final src = resolveClipSource(clipName);
        if (src == null) {
          debugPrint('[AnimBlueprintEditorViewModel] Source clip not found: $clipName');
          continue;
        }

        try {
          final res = GlbAnimationRetargeter.retargetInto(
            target: currentTargetGlb,
            clip: src.glb,
            clipName: clipName,
            animationIndex: src.index,
          );
          currentTargetGlb = res.glb;
          retargetedClips.add(clipName);

          // Write companion .entity.glb for individual animation clip
          final clipGlbFile = File('${targetAnimDir.path}/$clipName.entity.glb');
          await clipGlbFile.writeAsBytes(res.glb);

          // Write .lmas for individual animation asset
          final clipLmasFile = File('${targetAnimDir.path}/$clipName.lmas');
          final animAsset = LuminaAsset(
            assetId: 'retarget_${clipName}_${DateTime.now().millisecondsSinceEpoch}',
            name: clipName,
            type: AssetType.animation,
            rawPayload: Uint8List(0),
            metadata: {
              'source_mesh': targetMeshRel,
              'target_mesh': targetMeshRel,
              'preview_mesh_path': targetMeshRel,
              'clip_name': clipName,
              'clip_index': '${res.clipIndex}',
              'last_modified': DateTime.now().toIso8601String(),
            },
          );
          await clipLmasFile.writeAsBytes(animAsset.toProtoBufferBytes());
        } catch (e) {
          debugPrint('[AnimBlueprintEditorViewModel] Error retargeting $clipName: $e');
        }
      }

      // 5. Save updated target companion GLB
      if (retargetedClips.isNotEmpty) {
        await targetCompFile.writeAsBytes(currentTargetGlb);

        // Update target mesh .lmas metadata if exists
        final targetLmasFile = File('$dir/$targetMeshRel');
        if (targetLmasFile.existsSync() && targetMeshRel.endsWith('.lmas')) {
          try {
            final lmas = LuminaAsset.fromBytes(await targetLmasFile.readAsBytes());
            final allNames = GlbAnimationMerger.animationNames(currentTargetGlb);
            final meta = Map<String, String>.from(lmas.metadata);
            meta['animation_clips'] = allNames.join(',');
            final updatedLmas = LuminaAsset(
              assetId: lmas.assetId,
              name: lmas.name,
              type: lmas.type,
              rawPayload: lmas.rawPayload,
              rawMatSource: lmas.rawMatSource,
              thumbnailPng: lmas.thumbnailPng,
              hasThumbnail: lmas.hasThumbnail,
              references: lmas.references,
              metadata: meta,
            );
            await targetLmasFile.writeAsBytes(updatedLmas.toProtoBufferBytes());
          } catch (_) {}
        }
      }

      // 6. Retarget referenced Blend Spaces
      final oldToNewBlendSpaces = <String, String>{};
      for (final entry in referencedBlendSpaces.entries) {
        final oldBsPath = entry.key;
        final oldBsDoc = entry.value;
        final bsBaseName = AnimGraphAssetService.baseName(oldBsPath);
        final newBsRelPath = 'contents/animations/$targetBase/$bsBaseName.lmas';

        final newBsDoc = LuminaBlendSpaceDocument(
          axes: oldBsDoc.axes,
          samples: oldBsDoc.samples,
        );
        AnimGraphAssetService.writeBlendSpace(
          dir,
          newBsRelPath,
          newBsDoc,
          targetMesh: targetMeshRel,
        );
        oldToNewBlendSpaces[oldBsPath] = newBsRelPath;
      }

      // 7. Update state machine states with new blend space paths
      final newMachines = _document.stateMachines.map((sm) {
        final newStates = sm.states.map((st) {
          if (st.pose.kind == LuminaAnimPoseKind.blendSpace && st.pose.blendSpace != null) {
            final newBs = oldToNewBlendSpaces[st.pose.blendSpace] ?? st.pose.blendSpace!;
            final newPose = LuminaAnimPose.blendSpace(
              newBs,
              xVariable: st.pose.xVariable ?? '',
              yVariable: st.pose.yVariable,
              rate: st.pose.rate,
              rateVariable: st.pose.rateVariable,
              rateReference: st.pose.rateReference,
              minRate: st.pose.minRate,
              maxRate: st.pose.maxRate,
            );
            return LuminaAnimState(st.name, newPose, x: st.x, y: st.y);
          }
          return st;
        }).toList();
        return LuminaAnimStateMachine(
          name: sm.name,
          entryState: sm.entryState,
          states: newStates,
          transitions: sm.transitions,
          sampleCrossFade: sm.sampleCrossFade,
        );
      }).toList();

      _document = _document.copyWith(
        targetMesh: targetMeshRel,
        stateMachines: newMachines,
      );

      // 8. Save Animation Blueprint (in-place or as new file)
      String finalPath;
      final cleanName = (outputName ?? '').trim().replaceAll(RegExp(r'\.lmas$'), '');
      if (saveAsNew && cleanName.isNotEmpty && cleanName != name) {
        final newRelPath = 'contents/animations/$targetBase/$cleanName.lmas';
        AnimGraphAssetService.writeAnimBlueprint(dir, newRelPath, _document);
        finalPath = '$dir/$newRelPath';
      } else {
        await save();
        finalPath = assetPath;
      }

      // 9. Sync target mesh, reload clips and blend spaces, reset preview
      _syncTargetMesh();
      _previewRevision = -1;
      _lastPreviewState = null;
      _lastPreviewClip = null;
      _revision++;
      notifyListeners();

      EngineLoggerService().log(
        'Retargeted Animation Blueprint $name to $targetBase (${retargetedClips.length} clips, ${oldToNewBlendSpaces.length} blend spaces)',
        level: 'info',
      );

      AssetRepository.notifyAssetsChanged();

      return finalPath;
    } finally {
      _isRetargeting = false;
      notifyListeners();
    }
  }

  Future<bool> save() async {
    final dir = projectDir;
    if (dir == null) return false;
    AnimGraphAssetService.writeAnimBlueprint(dir, relativePath, _document);
    _onDiskJson = AnimBlueprintEditorViewModel._json(_document);
    EngineLoggerService().log('Saved Animation Blueprint $relativePath', level: 'info');
    AssetRepository.notifyAssetsChanged();
    notifyListeners();
    return true;
  }
}
