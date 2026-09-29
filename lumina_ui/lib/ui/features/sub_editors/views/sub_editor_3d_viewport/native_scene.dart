part of '../sub_editor_3d_viewport.dart';

/// Native Filament preview: mesh and component asset loading, material
/// preview mounting, bounds framing, warm-up and teardown.
mixin _SubEditor3DViewportNativeScene on _SubEditor3DViewportStateBase {

  bool get _hasNativePreview => _SubEditor3DViewportState._usedNativePreview(widget);

  /// Native-scale camera steps (metres-ish) vs the software painter's units.
  @override
  bool get _nativeScale =>
      widget.onPreviewWorldReady != null ||
      (widget.glbMesh?.rawPayload != null &&
          widget.glbMesh!.rawPayload!.isNotEmpty) ||
      (widget.meshComponents != null &&
          widget.meshComponents!.any(
            (c) =>
                c.glbMesh.rawPayload != null &&
                c.glbMesh.rawPayload!.isNotEmpty,
          ));
  @override
  bool get _isMaterialPreview =>
      MaterialPreviewRenderer.isFilamatPackage(widget.previewMaterialBytes) &&
      !(widget.glbMesh?.rawPayload != null &&
          widget.glbMesh!.rawPayload!.isNotEmpty);

  void _startWarmupTimer() {
    final hasNativePayload = _hasNativePreview;
    if (!hasNativePayload) return;
    _warmupTimer?.cancel();
    _warmupTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_skipReadPixelsFrames > 0) {
        setState(() {
          _skipReadPixelsFrames--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  List<double> _createTransformMatrix(
    double tx,
    double ty,
    double tz,
    double pitchDeg,
    double yawDeg,
    double rollDeg,
    double sx,
    double sy,
    double sz,
  ) {
    final radX = pitchDeg * math.pi / 180.0;
    final radY = yawDeg * math.pi / 180.0;
    final radZ = rollDeg * math.pi / 180.0;

    final cx = math.cos(radX), sx_ = math.sin(radX);
    final cy = math.cos(radY), sy_ = math.sin(radY);
    final cz = math.cos(radZ), sz_ = math.sin(radZ);

    final m00 = (cy * cz + sy_ * sx_ * sz_) * sx;
    final m10 = (cx * sz_) * sx;
    final m20 = (-sy_ * cz + cy * sx_ * sz_) * sx;
    final m30 = 0.0;

    final m01 = (-cy * sz_ + sy_ * sx_ * cz) * sy;
    final m11 = (cx * cz) * sy;
    final m21 = (sy_ * sz_ + cy * sx_ * cz) * sy;
    final m31 = 0.0;

    final m02 = (sy_ * cx) * sz;
    final m12 = (-sx_) * sz;
    final m22 = (cy * cx) * sz;
    final m32 = 0.0;

    final m03 = tx;
    final m13 = ty;
    final m23 = tz;
    final m33 = 1.0;

    return [
      m00,
      m10,
      m20,
      m30,
      m01,
      m11,
      m21,
      m31,
      m02,
      m12,
      m22,
      m32,
      m03,
      m13,
      m23,
      m33,
    ];
  }

  void _rebuildComponentAssets(FilamentEngine engine, FilamentScene scene) {
    for (final asset in _componentAssets.values) {
      asset.removeFromScene(scene);
      asset.dispose();
    }
    _componentAssets.clear();
    final generation = ++_meshGeneration;

    if (widget.meshComponents == null || widget.meshComponents!.isEmpty) return;

    for (final comp in widget.meshComponents!) {
      if (!comp.isVisible ||
          comp.glbMesh.rawPayload == null ||
          comp.glbMesh.rawPayload!.isEmpty) {
        continue;
      }
      ViewportMesh.acquire(engine, comp.glbMesh.rawPayload!).then((asset) {
        if (asset == null) return;
        if (!mounted || generation != _meshGeneration || _nativeScene == null) {
          asset.dispose();
          return;
        }
        _componentAssets[comp.id] = asset;
        try {
          asset.animator.updateBoneMatrices();
        } catch (_) {}

        try {
          final loc = comp.location;
          final rot = comp.rotation;
          final scl = comp.scale;
          final m = _createTransformMatrix(
            loc.isNotEmpty ? loc[0] : 0.0,
            loc.length > 2 ? loc[2] : 0.0,
            loc.length > 1 ? -loc[1] : 0.0,
            rot.isNotEmpty ? rot[0] : 0.0,
            rot.length > 2 ? rot[2] : 0.0,
            rot.length > 1 ? -rot[1] : 0.0,
            scl.isNotEmpty ? scl[0] : 1.0,
            scl.length > 2 ? scl[2] : 1.0,
            scl.length > 1 ? scl[1] : 1.0,
          );
          FilamentTransformManager(engine).setTransform(asset.rootEntity, m);
        } catch (e) {
          debugPrint('[SubEditor3DViewport] Transform error for ${comp.id}: $e');
        }

        asset.addToScene(scene);
        _recalculateBoundsAndFraming();
      }, onError: (Object e) => debugPrint('[SubEditor3DViewport] mesh component ${comp.id}: $e'));
    }
  }

  /// Loads [SubEditor3DViewport.glbMesh] as an instance of the engine's
  /// shared asset for its payload, then shows and dresses it.
  void _loadNativeMesh(FilamentEngine engine, FilamentScene scene, Uint8List payload) {
    final generation = ++_meshGeneration;
    ViewportMesh.acquire(engine, payload, sourcePath: widget.meshSourcePath).then((asset) {
      if (asset == null) return;
      if (!mounted || generation != _meshGeneration || _nativeScene == null) {
        asset.dispose();
        return;
      }
      // Socket previews hang from the old mesh's joints.
      _releaseSocketAttachments();
      if (_nativeAsset != null) {
        _nativeAsset!.removeFromScene(scene);
        _nativeAsset!.dispose();
        _nativeAsset = null;
      }
      if (_nativeWireframeMesh != null) {
        scene.removeEntity(_nativeWireframeMesh!.entityId);
        _nativeWireframeMesh!.dispose();
        _nativeWireframeMesh = null;
      }
      for (final material in _sectionMaterials.values) {
        material.dispose();
      }
      _sectionMaterials.clear();
      _sectionMaterialInstances.clear();
      _appliedSectionMaterials = const {};

      _nativeAsset = asset;
      try {
        if (widget.playbackController != null) {
          _onPlaybackChanged();
        } else {
          asset.animator.updateBoneMatrices();
        }
      } catch (_) {}
      _recalculateBoundsAndFraming();

      if (_shadingMode == ViewportShadingMode.wireframe) {
        if (widget.glbMesh != null &&
            widget.glbMesh!.positions.isNotEmpty &&
            widget.glbMesh!.indices.isNotEmpty) {
          _nativeWireframeMesh = FilamentWireframeMesh.create(
            engine: engine,
            positions: widget.glbMesh!.positions,
            indices: widget.glbMesh!.indices,
          );
          if (_nativeWireframeMesh != null) {
            scene.addEntity(_nativeWireframeMesh!.entityId);
          }
        }
      } else {
        asset.addToScene(scene);
        _updateNodeVisibilities();
      }

      _applyMorphWeights(force: true);
      _applyJointTransforms(force: true);
      _applySectionMaterials(force: true);
      _updateSelectedNodeWireframe();
      _updateCollisionLines(force: true);
      _syncSocketAttachments();
      // Shader compilation for the new materials: skip readbacks a moment.
      _skipReadPixelsFrames = math.max(_skipReadPixelsFrames, 15);
      _startWarmupTimer();
      setState(() {});
    }, onError: (Object e) => debugPrint('[SubEditor3DViewport] mesh load failed: $e'));
  }

  /// Shows [SubEditor3DViewport.socketAttachments]: each preview
  /// mesh's root is parented to its bone's joint in the host mesh with the
  /// socket offset as its local transform, so Filament draws it at
  /// `entityWorld × G_bone × offset` and it follows the pose. A bone the
  /// host has no joint for falls back to the rest-pose world transform.
  void _syncSocketAttachments() {
    final engine = _nativeEngine;
    final scene = _nativeScene;
    if (engine == null || engine.isDisposed || scene == null || !_drawsMeshes) return;
    final wanted = {for (final a in widget.socketAttachments) a.socketName: a};
    for (final name in _socketAssets.keys.toList()) {
      if (wanted[name]?.assetPath != _socketAssets[name]!.path) _releaseSocketAsset(name);
    }
    for (final a in wanted.values) {
      final have = _socketAssets[a.socketName];
      if (have != null) {
        _socketAssets[a.socketName] = (path: have.path, joint: _placeSocketAsset(engine, have.mesh, a), mesh: have.mesh);
        continue;
      }
      final payload = a.mesh.rawPayload;
      if (payload == null || payload.isEmpty) continue;
      final generation = _socketGeneration;
      ViewportMesh.acquire(engine, payload, sourcePath: a.assetPath).then((mesh) {
        if (mesh == null) return;
        final current = widget.socketAttachments.where((w) => w.socketName == a.socketName).firstOrNull;
        if (!mounted ||
            generation != _socketGeneration ||
            _nativeScene == null ||
            current == null ||
            current.assetPath != a.assetPath ||
            _socketAssets.containsKey(a.socketName)) {
          mesh.dispose();
          return;
        }
        _socketAssets[a.socketName] = (path: a.assetPath, joint: _placeSocketAsset(engine, mesh, current), mesh: mesh);
        if (_shadingMode != ViewportShadingMode.wireframe) mesh.addToScene(_nativeScene!);
        setState(() {});
      }, onError: (Object e) => debugPrint('[SubEditor3DViewport] socket preview ${a.socketName}: $e'));
    }
  }

  /// Parents [mesh] to [a]'s joint with the socket offset; returns the joint
  /// (0 when the host has none and the rest-pose world transform is used).
  int _placeSocketAsset(FilamentEngine engine, ViewportMesh mesh, SkeletalSocketAttachment a) {
    final tm = FilamentTransformManager(engine);
    final joints = _nativeAsset?.getEntitiesByName(a.boneName) ?? const <int>[];
    final joint = joints.isEmpty ? 0 : joints.first;
    tm.setParent(mesh.rootEntity, joint);
    tm.setTransform(mesh.rootEntity, joint == 0 ? a.restWorld.storage : a.localOffset.storage);
    return joint;
  }

  /// Takes one socket preview out of the scene and gives its instance back
  /// unparented (the shared cache may hand it to another viewport).
  void _releaseSocketAsset(String name) {
    final entry = _socketAssets.remove(name);
    if (entry == null) return;
    final engine = _nativeEngine;
    if (_nativeScene != null) entry.mesh.removeFromScene(_nativeScene!);
    if (engine != null && !engine.isDisposed) {
      final tm = FilamentTransformManager(engine);
      tm.setParent(entry.mesh.rootEntity, 0);
      tm.setTransform(entry.mesh.rootEntity, Matrix4.identity().storage);
    }
    entry.mesh.dispose();
  }

  /// Releases every socket preview — before the host mesh they hang from goes.
  void _releaseSocketAttachments() {
    _socketGeneration++;
    for (final name in _socketAssets.keys.toList()) {
      _releaseSocketAsset(name);
    }
  }

  /// Frees everything this viewport made on the shared engine — preview
  /// world, material preview, wires, grid, lights, meshes, section materials —
  /// while the engine is alive. Called from the
  /// FilamentWidget's onDispose (the scene still exists) and again from
  /// [State.dispose]; idempotent.
  void _disposeNative() {
    final engine = _nativeEngine;
    final scene = _nativeScene;
    _meshGeneration++;
    if (engine == null || engine.isDisposed) return;
    try {
      engine.flushAndWait();
      _sceneEnvironment.detach();
      final pw = _previewWorld;
      if (pw != null) {
        _previewWorld = null;
        widget.onPreviewWorldDisposing?.call(pw);
        pw.cleanup();
        engine.flushAndWait();
      }
      _materialPreview.dispose();
      if (_nativeWireframeMesh != null) {
        scene?.removeEntity(_nativeWireframeMesh!.entityId);
        _nativeWireframeMesh!.dispose();
        _nativeWireframeMesh = null;
      }
      if (_selectedNodeWireframe != null) {
        scene?.removeEntity(_selectedNodeWireframe!.entityId);
        _selectedNodeWireframe!.dispose();
        _selectedNodeWireframe = null;
      }
      // The collision view's lines go with the engine that made them.
      if (_collisionWireframe != null) {
        scene?.removeEntity(_collisionWireframe!.entityId);
        _collisionWireframe!.dispose();
        _collisionWireframe = null;
        _collisionLinesBuilt = null;
      }
      for (final (_, wire) in _overlayWires.values) {
        scene?.removeEntity(wire.entityId);
        wire.dispose();
      }
      _overlayWires.clear();
      if (_nativeGrid != null) {
        _nativeGrid!.dispose();
        _nativeGrid = null;
      }
      for (final light in _studioLights) {
        scene?.removeEntity(light);
        engine.destroyEntityComponents(light);
        engine.destroyEntity(light);
      }
      _studioLights.clear();
      engine.flushAndWait();
      _releaseSocketAttachments();
      if (_nativeAsset != null) {
        if (scene != null) _nativeAsset!.removeFromScene(scene);
        _nativeAsset!.dispose();
        _nativeAsset = null;
      }
      _restEntityTransforms.clear();
      _posedEntities.clear();
      _appliedJointDeltas = null;
      for (final a in _componentAssets.values) {
        if (scene != null) a.removeFromScene(scene);
        a.dispose();
      }
      _componentAssets.clear();
      // Section materials last: the instance may still point at them until
      // it is released (an orphaned instance is never drawn again).
      for (final instance in _sectionMaterialInstances.values) {
        instance.dispose();
      }
      _sectionMaterialInstances.clear();
      for (final material in _sectionMaterials.values) {
        material.dispose();
      }
      _sectionMaterials.clear();
    } catch (e) {
      debugPrint('[Lumina Studio UI] Safe sub-editor disposal: $e');
    }
    _nativeScene = null;
    _nativeCamera = null;
  }

  void _mountMaterialPreview(FilamentEngine engine, FilamentScene scene) {
    final bytes = widget.previewMaterialBytes;
    if (bytes == null || bytes.isEmpty) return;
    final ok = _materialPreview.mount(
      engine: engine,
      scene: scene,
      filamatBytes: bytes,
      shape: _shape == PreviewShape.mesh ? PreviewShape.sphere : _shape,
      parameters: widget.previewMaterialParams,
    );
    if (ok) {
      // Unit-scale primitive: frame it tightly around the origin.
      _targetCenterX = 0.0;
      _targetCenterY = 0.0;
      _targetCenterZ = 0.0;
      _cameraDistance = _materialFitDistance();
      _materialFramed = true;
      _updateNativeCamera();
    }
  }

  /// The distance at which the preview primitive's bounding sphere fits the
  /// narrower of the two fields of view, with a margin. The projection's 45°
  /// is vertical, so a tall, narrow pane sees much less across.
  @override
  double _materialFitDistance() {
    final mesh = PreviewMeshFactory.build(_shape == PreviewShape.mesh ? PreviewShape.sphere : _shape);
    var r2 = 0.0;
    for (var k = 0; k < 3; k++) {
      final e = math.max(mesh.minBounds[k].abs(), mesh.maxBounds[k].abs());
      r2 += e * e;
    }
    const vHalf = 22.5 * math.pi / 180.0;
    final hHalf = math.atan(math.tan(vHalf) * _viewportAspect);
    return math.sqrt(r2) / math.sin(math.min(vHalf, hHalf)) * 1.08;
  }

  void _recalculateBoundsAndFraming() {
    final isNative = _nativeScale;
    if (widget.initialCameraDistance != null &&
        widget.glbMesh == null &&
        (widget.meshComponents == null || widget.meshComponents!.isEmpty)) {
      _cameraDistance = widget.initialCameraDistance!;
      final target = widget.initialCameraTarget;
      if (target != null) {
        _targetCenterX = target.x;
        _targetCenterY = target.y;
        _targetCenterZ = target.z;
      }
      _updateNativeCamera();
      return;
    }

    final activeMeshes = <({GlbMeshData mesh, List<double> loc, List<double> scl})>[];
    if (widget.meshComponents != null && widget.meshComponents!.isNotEmpty) {
      for (final comp in widget.meshComponents!) {
        if (comp.isVisible && comp.glbMesh.positions.isNotEmpty) {
          activeMeshes.add((
            mesh: comp.glbMesh,
            loc: comp.location,
            scl: comp.scale,
          ));
        }
      }
    } else if (widget.glbMesh != null && widget.glbMesh!.positions.isNotEmpty) {
      activeMeshes.add((
        mesh: widget.glbMesh!,
        loc: const [0.0, 0.0, 0.0],
        scl: const [1.0, 1.0, 1.0],
      ));
    }

    if (activeMeshes.isNotEmpty) {
      double minX = double.infinity, minY = double.infinity, minZ = double.infinity;
      double maxX = -double.infinity, maxY = -double.infinity, maxZ = -double.infinity;

      for (final item in activeMeshes) {
        final m = item.mesh;
        final sx = item.scl.isNotEmpty ? item.scl[0].abs() : 1.0;
        final sy = item.scl.length > 1 ? item.scl[1].abs() : 1.0;
        final sz = item.scl.length > 2 ? item.scl[2].abs() : 1.0;

        final cMinX = m.minBounds[0] * sx + (item.loc.isNotEmpty ? item.loc[0] : 0.0);
        final cMaxX = m.maxBounds[0] * sx + (item.loc.isNotEmpty ? item.loc[0] : 0.0);
        final cMinY = m.minBounds[1] * sy + (item.loc.length > 1 ? item.loc[1] : 0.0);
        final cMaxY = m.maxBounds[1] * sy + (item.loc.length > 1 ? item.loc[1] : 0.0);
        final cMinZ = m.minBounds[2] * sz + (item.loc.length > 2 ? item.loc[2] : 0.0);
        final cMaxZ = m.maxBounds[2] * sz + (item.loc.length > 2 ? item.loc[2] : 0.0);

        minX = math.min(minX, math.min(cMinX, cMaxX));
        maxX = math.max(maxX, math.max(cMinX, cMaxX));
        minY = math.min(minY, math.min(cMinY, cMaxY));
        maxY = math.max(maxY, math.max(cMinY, cMaxY));
        minZ = math.min(minZ, math.min(cMinZ, cMaxZ));
        maxZ = math.max(maxZ, math.max(cMinZ, cMaxZ));
      }

      _targetCenterX = (minX + maxX) / 2.0;
      _targetCenterY = (minY + maxY) / 2.0;
      _targetCenterZ = (minZ + maxZ) / 2.0;

      final spanX = (maxX - minX).abs();
      final spanY = (maxY - minY).abs();
      final spanZ = (maxZ - minZ).abs();
      final maxSpan = math.max(spanX, math.max(spanY, spanZ));
      _cameraDistance = math.max(0.5, maxSpan * 1.8);
    } else {
      _cameraDistance = isNative ? 8.0 : 350.0;
    }
    _updateNativeCamera();
  }
}
