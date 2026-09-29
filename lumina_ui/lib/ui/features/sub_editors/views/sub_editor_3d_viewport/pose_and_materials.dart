part of '../sub_editor_3d_viewport.dart';

/// Per-section material overrides, morph weights, joint deltas and
/// animation playback applied to the native assets.
mixin _SubEditor3DViewportPoseAndMaterials on _SubEditor3DViewportStateBase {

  bool _mapEquals(Map<String, double>? a, Map<String, double>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }

  /// Swaps the bound material onto each overridden section's primitive.
  ///
  /// gltfio builds one renderable entity per mesh node, with one primitive per
  /// glTF primitive, both in file order — the same order the parser fills
  /// `subPrimitives`. Walking the renderables and accumulating their primitive
  /// counts therefore gives section index → (entity, primitive).
  @override
  void _applySectionMaterials({bool force = false}) {
    final engine = _nativeEngine;
    final asset = _nativeAsset;
    if (engine == null || asset == null) return;

    final overrides = widget.sectionMaterialOverrides;
    if (!force && _bytesMapEquals(_appliedSectionMaterials, overrides)) return;
    _appliedSectionMaterials = Map<int, Uint8List>.from(overrides);

    if (overrides.isEmpty) return;

    try {
      final rm = FilamentRenderableManager(engine);
      var section = 0;
      for (final entity in asset.renderableEntities) {
        if (!rm.hasComponent(entity)) continue;
        final primitiveCount = rm.getPrimitiveCount(entity);
        for (var primitive = 0; primitive < primitiveCount; primitive++, section++) {
          final bytes = overrides[section];
          if (bytes == null || bytes.isEmpty) continue;

          var instance = _sectionMaterialInstances[section];
          if (instance == null) {
            final material = FilamentMaterial.fromBuffer(
              engine: engine,
              filamatBuffer: bytes,
            );
            instance = material.createInstance('LuminaSectionMaterial$section');
            _sectionMaterials[section] = material;
            _sectionMaterialInstances[section] = instance;
          }
          rm.setMaterialInstanceAt(entity, primitive, instance);
        }
      }
      engine.flushAndWait();
    } catch (e) {
      debugPrint('[SubEditor3DViewport] section material override failed: $e');
    }
  }

  bool _bytesMapEquals(Map<int, Uint8List> a, Map<int, Uint8List> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      final other = b[entry.key];
      if (other == null || !identical(other, entry.value)) return false;
    }
    return true;
  }

  @override
  void _applyMorphWeights({bool force = false}) {
    if (_nativeAsset == null || _nativeEngine == null) return;
    final weightsMap = widget.morphWeights ?? const {};
    if (!force && _mapEquals(_appliedMorphWeights, widget.morphWeights)) {
      return;
    }
    _appliedMorphWeights = widget.morphWeights != null
        ? Map<String, double>.from(widget.morphWeights!)
        : null;

    try {
      final rm = FilamentRenderableManager(_nativeEngine!);
      for (final entity in _nativeAsset!.entities) {
        var count = _nativeAsset!.getMorphTargetCountAt(entity);
        if (count <= 0 && rm.hasComponent(entity)) {
          count = rm.getMorphTargetCount(entity);
        }
        if (count > 0 && rm.hasComponent(entity)) {
          final weightsList = Float32List(count);
          for (var i = 0; i < count; i++) {
            var name = _nativeAsset!.getMorphTargetNameAt(entity, i);
            if (name == null || name.isEmpty) {
              if (widget.glbMesh != null &&
                  i < widget.glbMesh!.morphTargets.length) {
                name = widget.glbMesh!.morphTargets[i].name;
              }
            }
            if (name != null && weightsMap.containsKey(name)) {
              weightsList[i] = weightsMap[name]!;
            }
          }
          rm.setMorphWeights(entity, weightsList);
        }
      }
      _nativeEngine?.flushAndWait();
    } catch (e) {
      debugPrint('[SubEditor3DViewport] Morph weights update error: $e');
    }
  }

  bool _jointDeltasEquals(
    Map<String, List<double>>? a,
    Map<String, List<double>>? b,
  ) {
    if (identical(a, b)) return true;
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      final listA = a[key];
      final listB = b[key];
      if (listA == null || listB == null || listA.length != listB.length) {
        return false;
      }
      for (int i = 0; i < listA.length; i++) {
        if ((listA[i] - listB[i]).abs() > 1e-6) return false;
      }
    }
    return true;
  }

  @override
  void _applyJointTransforms({bool force = false}) {
    if (_nativeAsset == null || _nativeEngine == null) return;
    if (!force && _jointDeltasEquals(_appliedJointDeltas, widget.jointDeltas)) {
      return;
    }
    _appliedJointDeltas = widget.jointDeltas != null
        ? Map<String, List<double>>.from(widget.jointDeltas!)
        : null;

    try {
      final tm = FilamentTransformManager(_nativeEngine!);
      if (_restEntityTransforms.isEmpty) {
        for (final entity in _nativeAsset!.entities) {
          if (tm.hasComponent(entity)) {
            _restEntityTransforms[entity] = tm.getTransform(entity);
          }
        }
      }

      final deltas = widget.jointDeltas ?? const {};
      tm.transaction(() {
        if (deltas.isEmpty) {
          for (final entity in _posedEntities) {
            final rest = _restEntityTransforms[entity];
            if (rest != null) {
              tm.setTransform(entity, rest);
            }
          }
          _posedEntities.clear();
        } else {
          final newlyPosed = <int>{};
          for (final entry in deltas.entries) {
            final jointName = entry.key;
            final d = entry.value;
            if (d.length < 9) continue;
            final entities = _nativeAsset!.getEntitiesByName(jointName);
            for (final entity in entities) {
              final rest = _restEntityTransforms[entity];
              if (rest != null) {
                final tx = d[0];
                final ty = d[1];
                final tz = d[2];
                final rx = d[3];
                final ry = d[4];
                final rz = d[5];
                final sx = d[6];
                final sy = d[7];
                final sz = d[8];

                final radX = rx * math.pi / 180.0;
                final radY = ry * math.pi / 180.0;
                final radZ = rz * math.pi / 180.0;

                final deltaMat = Matrix4.identity()
                  ..translate(tx * 0.01, ty * 0.01, tz * 0.01)
                  ..rotateX(radX)
                  ..rotateY(radY)
                  ..rotateZ(radZ);
                if (sx != 0.0 || sy != 0.0 || sz != 0.0) {
                  deltaMat.scale(1.0 + sx, 1.0 + sy, 1.0 + sz);
                }

                final mRest = Matrix4.fromList(rest);
                final mPosed = mRest * deltaMat;
                tm.setTransform(entity, mPosed.storage.toList());
                newlyPosed.add(entity);
              }
            }
          }

          for (final entity in _posedEntities) {
            if (!newlyPosed.contains(entity)) {
              final rest = _restEntityTransforms[entity];
              if (rest != null) {
                tm.setTransform(entity, rest);
              }
            }
          }
          _posedEntities
            ..clear()
            ..addAll(newlyPosed);
        }
      });

      _nativeAsset!.animator.updateBoneMatrices();
      _nativeEngine?.flushAndWait();
    } catch (e) {
      debugPrint('[SubEditor3DViewport] Joint transforms update error: $e');
    }
  }

  @override
  void _onPlaybackChanged() {
    if (_nativeAsset != null && widget.playbackController != null) {
      final ctrl = widget.playbackController!;
      try {
        ctrl.recordCall('applyAnimation');
        _nativeAsset!.animator.applyAnimation(ctrl.clipIndex, ctrl.timeSeconds);
        ctrl.recordCall('updateBoneMatrices');
        _nativeAsset!.animator.updateBoneMatrices();
      } catch (e) {
        // Guard against disposed native animator
      }
    }
    for (final asset in _componentAssets.values) {
      try {
        if (widget.playbackController != null) {
          final ctrl = widget.playbackController!;
          asset.animator.applyAnimation(ctrl.clipIndex, ctrl.timeSeconds);
        }
        asset.animator.updateBoneMatrices();
      } catch (_) {}
    }
  }
}
