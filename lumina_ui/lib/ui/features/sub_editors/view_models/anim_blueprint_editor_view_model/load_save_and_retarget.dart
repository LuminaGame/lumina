part of '../anim_blueprint_editor_view_model.dart';

/// Loading and saving the ANIM_BLUEPRINT `.lmas`, the target mesh and its
/// blend spaces, and retargeting the Anim Blueprint to another skeleton.
mixin _AnimBlueprintEditorLoadSaveAndRetarget on _AnimBlueprintEditorViewModelState {

  // ---------------------------------------------------------------------------
  // Load / save
  // ---------------------------------------------------------------------------

  Future<void> load() async {
    _skeletalMeshCache = null;
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
    _poseDatabasePaths = AnimGraphAssetService.poseSearchDatabasesFor(dir, _document.targetMesh);
    _poseDatabases.clear();
    final databases = {
      ..._poseDatabasePaths,
      for (final m in _document.stateMachines)
        for (final s in m.states)
          if (s.pose.database != null && s.pose.database!.isNotEmpty) s.pose.database!,
    };
    for (final path in databases) {
      final db = AnimGraphAssetService.readPoseSearchDatabase(dir, path);
      if (db != null) _poseDatabases[path] = db;
    }
  }

  /// Pose search databases the Motion Matching states play.
  @override
  Map<String, LuminaPoseSearchDatabaseDocument> get statePoseDatabases => {
        for (final m in _document.stateMachines)
          for (final s in m.states)
            if (s.pose.database != null && _poseDatabases.containsKey(s.pose.database)) s.pose.database!: _poseDatabases[s.pose.database]!,
      };

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
        if (s.pose.kind == LuminaAnimPoseKind.clip) {
          if (s.pose.clip != null && s.pose.clip!.isNotEmpty) {
            clips.add(s.pose.clip!);
          }
          for (final c in s.pose.clips) {
            if (c.isNotEmpty) clips.add(c);
          }
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

      // 1. The clips and Blend Spaces the states play.
      final directClips = <String>{};
      final blendSpacePaths = <String>{};
      for (final sm in _document.stateMachines) {
        for (final st in sm.states) {
          if (st.pose.kind == LuminaAnimPoseKind.clip) {
            if (st.pose.clip != null && st.pose.clip!.isNotEmpty) {
              directClips.add(st.pose.clip!);
            }
            for (final c in st.pose.clips) {
              if (c.isNotEmpty) directClips.add(c);
            }
          } else if (st.pose.kind == LuminaAnimPoseKind.blendSpace && st.pose.blendSpace != null && st.pose.blendSpace!.isNotEmpty) {
            blendSpacePaths.add(st.pose.blendSpace!);
          }
        }
      }

      // 2–6. Reading the meshes, retargeting every clip, writing the clips,
      // the target mesh and the Blend Spaces: a background isolate.
      final result = await AnimBlueprintRetargetWorker.run(AnimBlueprintRetargetJob(
        projectDir: dir,
        sourceMeshRel: _document.targetMesh,
        targetMeshRel: targetMeshRel,
        directClips: directClips,
        blendSpacePaths: blendSpacePaths,
        knownBlendSpaces: {
          for (final path in blendSpacePaths)
            if (_blendSpaces[path] != null) path: _blendSpaces[path]!,
        },
      ));
      for (final message in result.messages) {
        debugPrint('[AnimBlueprintEditorViewModel] $message');
      }
      final retargetedClips = result.retargetedClips;
      final oldToNewBlendSpaces = result.oldToNewBlendSpaces;

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
        final document = _document;
        await Isolate.run(() => AnimGraphAssetService.writeAnimBlueprint(dir, newRelPath, document));
        finalPath = '$dir/$newRelPath';
      } else {
        await save();
        finalPath = assetPath;
      }

      // 9. Sync target mesh, reload clips and blend spaces, reset preview
      _skeletalMeshCache = null;
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
