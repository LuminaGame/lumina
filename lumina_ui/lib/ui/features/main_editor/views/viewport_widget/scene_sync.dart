part of '../viewport_widget.dart';

/// Keeps the Filament scene in step with the view model: environment,
/// sky, grid, actor meshes, quality, and native teardown.
mixin _ViewportSceneSync on _ViewportWidgetStateBase {

  /// Rebinds the level's sky and ambient light from the `Environment` actor.
  /// Cheap and idempotent — only what actually changed is rebuilt, so it is
  /// safe on every Details-panel keystroke.
  void _syncSceneEnvironment() {
    _sceneEnvironment.projectDirPath = widget.viewModel.projectDirPath;
    // A level without an Environment actor has no sky and no image-based
    // light, as in the game.
    _sceneEnvironment.applyLevel(
      EditorSceneEnvironment.describeLevel(
        widget.viewModel.actors,
        environmentSection: widget.viewModel.levelEnvironment,
      ),
    );
  }

  /// Rebinds the level's Procedural Sky & Ocean from the `ProceduralSky` actor,
  /// or tears it down when the level has none.
  void _syncProceduralSky() {
    _proceduralSky.apply(
      EditorProceduralSky.describeLevel(widget.viewModel.actors),
    );
  }

  void _onViewModelUpdated() {
    _syncPieSession();
    _syncActorAssets();
    _syncGrid();
    _syncSceneEnvironment();
    _syncProceduralSky();
    // A sky light added or removed changes the exposure.
    _syncAutoExposure();
    // Outliner Focus, Reset Camera, the Navigation editor and the end of a
    // Play session move the camera in the view model, not through a viewport
    // gesture; without this the render kept the old view.
    if (_editorCameraPose != _pushedCameraPose) _updateNativeCamera();
    if (mounted) {
      setState(() {});
    }
  }

  /// Frees everything this viewport created on the shared engine — meshes,
  /// lights, grid, boxes, wires, gizmo, sky — while the engine is alive, so
  /// nothing outlives it and nothing is left behind for the viewports that
  /// keep drawing. Idempotent.
  void _disposeNative() {
    final engine = _nativeEngine;
    final scene = _nativeScene;
    // Views drawing this scene let go of it before it is freed.
    final shared = widget.viewModel.levelScene.value;
    if (shared != null && identical(shared.scene, scene)) widget.viewModel.levelScene.value = null;
    _meshGeneration++;
    _actorLoading.clear();
    if (engine == null || engine.isDisposed) {
      _actorAssets.clear();
      _actorPayloads.clear();
      _actorMaterials.clear();
      _actorMaterialPaths.clear();
      _meshWires.clear();
      _nativeScene = null;
      _nativeCamera = null;
      return;
    }
    try {
      engine.flushAndWait();
      _sceneEnvironment.detach();
      _proceduralSky.detach();
      // The meshes' own materials go back before the assigned ones are
      // destroyed.
      for (final material in _actorMaterials.values) {
        material.dispose();
      }
      _actorMaterials.clear();
      _actorMaterialPaths.clear();
      for (final handle in _actorAssets.values) {
        if (scene != null && !scene.isDisposed) scene.removeEntities(handle.instance.entities);
        handle.release();
      }
      _actorAssets.clear();
      _actorPayloads.clear();
      _visibleInScene.clear();
      for (final wire in _capsuleWires.values) {
        if (scene != null && !scene.isDisposed) scene.removeEntity(wire.entityId);
        wire.dispose();
      }
      _capsuleWires.clear();
      for (final (_, wire) in _lightWires.values) {
        if (scene != null && !scene.isDisposed) scene.removeEntity(wire.entityId);
        wire.dispose();
      }
      _lightWires.clear();
      for (final (_, wire) in _volumeWires.values) {
        if (scene != null && !scene.isDisposed) scene.removeEntity(wire.entityId);
        wire.dispose();
      }
      _volumeWires.clear();
      _volumeWireState.clear();
      for (final (_, _, wire) in _meshWires.values) {
        if (scene != null && !scene.isDisposed) scene.removeEntity(wire.entityId);
        wire.dispose();
      }
      _meshWires.clear();
      if (_nativeGrid != null) {
        _nativeGrid!.dispose();
        _nativeGrid = null;
      }
      for (final b in _selectionBoxes.values) {
        b.dispose();
      }
      _selectionBoxes.clear();
      if (_nativeGizmo != null) {
        _nativeGizmo!.dispose();
        _nativeGizmo = null;
      }
      _levelLights.detach();
      _levelPostProcess.detach();
    } catch (e) {
      debugPrint('[Lumina Main Viewport] Safe disposal: $e');
    }
    _nativeScene = null;
    _nativeCamera = null;
  }

  void _syncGrid() {
    if (_nativeScene == null) return;
    final vm = widget.viewModel;
    // The editor grid is scenery the player should not see.
    final gridWanted = vm.showFlags["Grid"] == true && !_pieCameraDrivesView;

    if (_nativeGrid != null) {
      if (_lastGridStep != vm.gridStep || _lastGridExtent != vm.gridExtent) {
        _nativeGrid!.removeFromScene(_nativeScene!);

        // Native teardown requires flush
        _nativeEngine!.flushAndWait();

        _nativeGrid!.dispose();
        _nativeGrid = null;
      }
    }

    if (_nativeGrid == null && gridWanted) {
      _nativeGrid = FilamentEditorGrid.create(
        engine: _nativeEngine!,
        extent: vm.gridExtent,
        step: vm.gridStep,
      );
      _nativeGrid!.addToScene(_nativeScene!);
      _lastGridStep = vm.gridStep;
      _lastGridExtent = vm.gridExtent;
      _lastGridVisible = true;
    } else if (_nativeGrid != null) {
      if (gridWanted && !_lastGridVisible) {
        _nativeGrid!.addToScene(_nativeScene!);
      } else if (!gridWanted && _lastGridVisible) {
        _nativeGrid!.removeFromScene(_nativeScene!);
      }
      _lastGridVisible = gridWanted;
    }
  }

  /// Takes the engine's shared asset for [payload] (uploading it only when
  /// no viewport on this engine has it yet) and gives [actor] its own
  /// instance; placed and shown by the next [_syncActorAssets].
  void _loadActorMesh(EditorActorNode actor, Uint8List payload) {
    final engine = _nativeEngine!;
    final generation = _meshGeneration;
    final id = actor.id;
    _actorLoading.add(id);
    EngineLoggerService().log(
      'Binding Native Filament C++ Asset for actor "${actor.name}" (payload: ${payload.length} bytes, id: $id)',
      level: 'info',
      source: 'FilamentNative',
    );
    LuminaMeshAssetCache.forEngine(engine)
        .acquireBytes(payload, sourcePath: actor.meshAssetPath ?? 'actor:$id')
        .then((handle) {
      if (generation != _meshGeneration) {
        handle?.release();
        return;
      }
      _actorLoading.remove(id);
      if (handle == null) return;
      final current = widget.viewModel.actors.where((a) => a.id == id).firstOrNull;
      if (!mounted || _nativeScene == null || current == null || !identical(current.meshData?.rawPayload, payload)) {
        handle.release();
        return;
      }
      _actorAssets[id] = handle;
      _actorPayloads[id] = payload;
      try {
        handle.instance.animator.updateBoneMatrices();
      } catch (_) {
        // Not a skinned mesh or no animator.
      }
      EngineLoggerService().log(
        'Actor "${actor.name}" added to Native Filament Scene (entityCount: ${handle.instance.entityCount}, rootEntity: ${handle.instance.root}, '
        'shared asset: ${LuminaMeshAssetCache.forEngine(engine).entries.where((e) => e.key == handle.key).firstOrNull?.handles ?? 1} holder(s))',
        level: 'success',
        source: 'FilamentNative',
      );
      // Give the GPU 15 frames to compile shaders/pipelines for the new
      // asset without waiting for the readPixels fence.
      _skipReadPixelsFrames = 15;
      _syncActorAssets();
      setState(() {});
    }, onError: (Object e, StackTrace stack) {
      if (generation != _meshGeneration) return;
      _actorLoading.remove(id);
      EngineLoggerService().log(
        'Exception creating Native Filament asset for actor "${actor.name}": $e\n$stack',
        level: 'error',
        source: 'FilamentNative',
      );
    });
  }

  void _releaseActorMesh(String id) {
    _actorMaterialPaths.remove(id);
    try {
      _actorMaterials.remove(id)?.dispose();
    } catch (_) {}
    final handle = _actorAssets.remove(id);
    _actorPayloads.remove(id);
    _visibleInScene.remove(id);
    if (handle == null) return;
    try {
      if (_nativeScene != null) _nativeScene!.removeEntities(handle.instance.entities);
    } catch (_) {}
    handle.release();
  }

  /// Draws [actor]'s assigned material on every section of its instance, as
  /// Play and the built game do, or gives the mesh its own materials back;
  /// only when the assignment, the material file or a texture its samplers
  /// name changed (saved, reimported, its settings changed). A material that
  /// cannot be drawn is reported to the Output Log once.
  void _syncActorMaterial(EditorActorNode actor, LuminaMeshHandle handle) {
    final path = LuminaLevelActorMaterial.pathOf({
      'type': actor.type,
      'materialPath': actor.materialPath,
      'blueprintClass': actor.blueprintClass,
    });
    final projectDir = widget.viewModel.projectDirPath;
    final file = path == null
        ? null
        : File(path.startsWith('/') || RegExp(r'^[A-Za-z]:/').hasMatch(path) ? path : '$projectDir/$path');
    // A recompiled material, or a texture it draws saved again, is drawn anew
    // (the old textures go with the old material).
    String? revision(List<String> textures) =>
        path == null ? null : LuminaLevelActorMaterial.revision(path, projectDir: projectDir, textures: textures);
    final key = revision(_actorMaterials[actor.id]?.texturePaths ?? const []);
    if (_actorMaterialPaths.containsKey(actor.id) && _actorMaterialPaths[actor.id] == key) return;
    _actorMaterialPaths[actor.id] = key;
    _actorMaterials.remove(actor.id)?.dispose();
    if (path == null || file == null) return;
    final problem = LuminaLevelActorMaterial.problem(path, projectDir: projectDir);
    if (problem != null) {
      EngineLoggerService().log(
        'Actor "${actor.name}" draws its own materials: its material $problem',
        level: 'warning',
        source: 'FilamentNative',
      );
      return;
    }
    try {
      // The textures its samplers name are project files (`contents/…`).
      final material = LuminaInstanceMaterialOverride.fromBytes(
        _nativeEngine!,
        path,
        file.readAsBytesSync(),
        assetProvider: (texture) => File(File(texture).isAbsolute ? texture : '$projectDir/$texture').readAsBytes(),
      );
      material.applyTo(handle.instance);
      _actorMaterials[actor.id] = material;
      _actorMaterialPaths[actor.id] = revision(material.texturePaths);
      unawaited(material.texturesLoaded.then((_) {
        material.textures.missing.forEach((sampler, reason) => EngineLoggerService().log(
              'Actor "${actor.name}": material $path draws sampler $sampler without its texture: $reason',
              level: 'warning',
              source: 'FilamentNative',
            ));
      }));
      EngineLoggerService().log(
        'Actor "${actor.name}" draws material $path',
        level: 'info',
        source: 'FilamentNative',
      );
    } catch (e) {
      EngineLoggerService().log(
        'Actor "${actor.name}" draws its own materials: material $path could not be drawn: $e',
        level: 'warning',
        source: 'FilamentNative',
      );
    }
  }

  @override
  void _syncActorAssets() {
    if (_nativeScene == null || _nativeEngine == null) return;

    final currentActorIds = widget.viewModel.actors.map((a) => a.id).toSet();

    // 1. Release the instances of deleted actors
    final toRemove = _actorAssets.keys
        .where((id) => !currentActorIds.contains(id))
        .toList();
    for (final id in toRemove) {
      _releaseActorMesh(id);
    }

    // 2. Load, show / hide and place the current actors' meshes
    for (final actor in widget.viewModel.actors) {
      Uint8List? payload = actor.meshData?.rawPayload;

      if (payload != null &&
          payload.length >= 12 &&
          payload[0] == 0x67 &&
          payload[1] == 0x6C &&
          payload[2] == 0x54 &&
          payload[3] == 0x46) {
        if (_actorAssets.containsKey(actor.id) && !identical(_actorPayloads[actor.id], payload)) {
          _releaseActorMesh(actor.id);
        }
        final handle = _actorAssets[actor.id];
        if (handle == null) {
          if (!_actorLoading.contains(actor.id)) _loadActorMesh(actor, payload);
          continue;
        }
        _syncActorMaterial(actor, handle);

        // In Wireframe the edges stand in for the surface.
        final isVisible = _editorActorDrawn(actor.id) && !_wireframeMode;
        final currentlyVisible = _visibleInScene.contains(actor.id);

        if (isVisible && !currentlyVisible) {
          _nativeScene!.addEntities(handle.instance.entities);
          _visibleInScene.add(actor.id);
        } else if (!isVisible && currentlyVisible) {
          _nativeScene!.removeEntities(handle.instance.entities);
          _visibleInScene.remove(actor.id);
        }

        try {
          // Stored Z-up cm → the scene's Y up, with the mesh's asset unit
          // scale (glTF metres ×100), by the rule PIE and the game share.
          final m = EditorTransforms.meshMatrix(actor).storage.toList();
          FilamentTransformManager(
            _nativeEngine!,
          ).setTransform(handle.instance.root, m);
          try {
            handle.instance.animator.updateBoneMatrices();
          } catch (_) {}
        } catch (e) {
          EngineLoggerService().log(
            'Transform update error for actor "${actor.name}": $e',
            level: 'warning',
            source: 'FilamentNative',
          );
        }
      } else if (_actorAssets.containsKey(actor.id)) {
        _releaseActorMesh(actor.id);
      }
    }

    _syncCapsuleWires();
    _syncLightWires();
    _syncMeshWires();

    // 3. Synchronize Native Filament 3D Selection Boxes
    if (_nativeScene != null && _nativeEngine != null) {
      final currentSelectedIds = widget.viewModel.selectedActorIds;
      final boxesToRemove = _selectionBoxes.keys
          .where((id) => !currentSelectedIds.contains(id))
          .toList();

      for (final id in boxesToRemove) {
        final box = _selectionBoxes.remove(id);
        if (box != null) {
          box.removeFromScene(_nativeScene!);
          box.dispose();
        }
      }

      for (final selectedId in currentSelectedIds) {
        final actor = widget.viewModel.actors
            .where((a) => a.id == selectedId)
            .firstOrNull;
        if (actor != null) {
          var box = _selectionBoxes[selectedId];
          if (box == null) {
            box = FilamentSelectionBox(_nativeEngine!);
            _selectionBoxes[selectedId] = box;

            final glb = actor.meshData;
            _nativeEngine?.flushAndWait();
            if (glb != null &&
                glb.minBounds.length >= 3 &&
                glb.maxBounds.length >= 3) {
              box.updateBounds(
                scene: _nativeScene!,
                minBounds: glb.minBounds,
                maxBounds: glb.maxBounds,
                baseScale: 1.0,
              );
            } else {
              box.updateBounds(
                scene: _nativeScene!,
                minBounds: [-25.0, -25.0, 0.0],
                maxBounds: [25.0, 25.0, 50.0],
                baseScale: 1.0,
              );
            }
            _nativeEngine?.flushAndWait();
            box.addToScene(_nativeScene!);
          }

          box.setTransform(EditorTransforms.actorMatrix(actor).storage.toList());
        }
      }

      // Gizmo is only on primary selected
      final primary = widget.viewModel.showFlags["Transform Gizmo"] == true
          ? widget.viewModel.primarySelectedActor
          : null;
      if (primary != null) {
        if (_lastSelectedActorId != primary.id) {
          _nativeGizmo?.removeFromScene(_nativeScene!);
          _nativeGizmo?.addToScene(_nativeScene!);
          _lastSelectedActorId = primary.id;
        }

        final loc = primary.location;
        final dx = widget.viewModel.cameraPanX - loc[0];
        final dy = widget.viewModel.cameraPanY - loc[1];
        final dz = widget.viewModel.cameraPanZ - loc[2];
        final camDist =
            math.sqrt(dx * dx + dy * dy + dz * dz) +
            widget.viewModel.cameraDistance;
        // Constant on-screen size: at distance d a
        // 45-degree view is 0.414*d tall from centre to edge, and the axis
        // should take [_gizmoScreenFraction] of that. The old divisor made the
        // gizmo three times bigger, which swallowed metre-scale actors whole.
        final gizmoScale =
            (camDist * 0.414 * _ViewportWidgetState._gizmoScreenFraction / _ViewportWidgetState._gizmoAxisLen).clamp(
              0.02,
              8.0,
            );
        _gizmoScale = gizmoScale;
        // The gizmo has to be the tool the user picked: translate arrows,
        // rotation rings or scale handles. Without this it stayed on its
        // default mode forever and the rings were never drawn.
        final wantedMode = switch (widget.viewModel.activeTool) {
          'rotate' => fil.GizmoMode.rotate,
          'scale' => fil.GizmoMode.scale,
          _ => fil.GizmoMode.translate,
        };
        if (_nativeGizmo != null && _nativeGizmo!.mode != wantedMode) {
          _nativeGizmo!.removeFromScene(_nativeScene!);
          _nativeGizmo!.setMode(wantedMode);
          _nativeGizmo!.addToScene(_nativeScene!);
          _hoveredGizmoAxis = null;
        }
        // FilamentTransformGizmo.setTransform does the editor's Z-up to
        // Filament's Y-up conversion itself (its translation row is
        // `x, z, -y`), so this passes editor coordinates straight through.
        // Converting here as well applied the swap twice and put the gizmo
        // somewhere else entirely for any actor away from the origin.
        _nativeGizmo?.setPosition(loc[0], loc[1], loc[2], gizmoScale);
      } else {
        if (_lastSelectedActorId != null) {
          _nativeGizmo?.removeFromScene(_nativeScene!);
          _lastSelectedActorId = null;
        }
      }

      // Lighting: the level's light actors, unless Unlit, the
      // Lighting show flag is off, or a Play session's world (which builds
      // the same lights) owns the scene.
      final wantsLighting =
          widget.viewModel.viewMode != 'Unlit' &&
          widget.viewModel.showFlags['Lighting'] != false &&
          !_pieOwnsTheScene;
      _levelLights.sync(
        widget.viewModel.actors,
        enabled: wantsLighting,
        isVisible: widget.viewModel.isEffectivelyVisible,
      );
      _syncAutoExposure();
      _syncLevelPostProcess();
    }
  }

  /// The editor camera's eye in authoring axes (cm, Z-up): the point the
  /// post-process blender evaluates volumes at.
  @override
  List<double> get _editorCameraEyeAuthoring {
    final vm = widget.viewModel;
    final yawRad = vm.cameraYaw * math.pi / 180.0;
    final pitchRad = vm.cameraPitch.clamp(-90.0, 90.0) * math.pi / 180.0;
    final dist = vm.cameraDistance;
    return [
      vm.cameraPanX + dist * math.cos(pitchRad) * math.sin(yawRad),
      vm.cameraPanY - dist * math.cos(pitchRad) * math.cos(yawRad),
      vm.cameraPanZ + dist * math.sin(pitchRad),
    ];
  }

  /// The live Filament view, so smoke tests can assert what the renderer was
  /// actually told rather than what the view model believes.
  FilamentView? get nativeViewForTest => _nativeView;

  /// Test seams: the edit-mode scene, its engine, the light
  /// entities the viewport put in it, and whether the level's sky and
  /// image-based light are bound.
  FilamentScene? get nativeSceneForTest => _nativeScene;
  FilamentEngine? get nativeEngineForTest => _nativeEngine;
  @override
  List<int> get editorLightEntitiesForTest => [
        for (final e in _levelLights.lightEntities)
          if (_nativeScene?.hasEntity(e) ?? false) e,
      ];
  bool get editorEnvironmentAttachedForTest => _sceneEnvironment.isAttached;

  /// Test seam: the root and renderable entities of the mesh
  /// instance drawn for [actorId], or null while it has none in the scene.
  ({int root, List<int> entities})? actorInstanceInSceneForTest(String actorId) {
    final handle = _actorAssets[actorId];
    if (handle == null || !_visibleInScene.contains(actorId)) return null;
    return (root: handle.instance.root, entities: List<int>.of(handle.instance.entities));
  }

  /// Pushes the editor's quality settings into the live Filament view.
  ///
  /// The view model owns the settings and bumps `qualityRevision` on every
  /// change; this re-applies only when that number moves, so it is safe to
  /// call from `build`.
  void _applyEditorQuality({bool force = false}) {
    final view = _nativeView;
    if (view == null) return;
    final revision = widget.viewModel.qualityRevision;
    if (!force && revision == _appliedQualityRevision) return;
    _appliedQualityRevision = revision;
    widget.viewModel.quality.applyToView(view);
  }
}
