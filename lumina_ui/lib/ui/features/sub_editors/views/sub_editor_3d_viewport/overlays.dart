part of '../sub_editor_3d_viewport.dart';

/// Wireframe, collision and overlay line sets, node visibility and the
/// shading-mode switch.
mixin _SubEditor3DViewportOverlays on _SubEditor3DViewportStateBase {

  @override
  void _updateSelectedNodeWireframe() {
    if (_nativeScene == null || _nativeEngine == null) return;
    try {
      if (_selectedNodeWireframe != null) {
        _nativeEngine!.flushAndWait();
        _nativeScene!.removeEntity(_selectedNodeWireframe!.entityId);
        _selectedNodeWireframe!.dispose();
        _selectedNodeWireframe = null;
        _nativeEngine!.flushAndWait();
      }

      final node = widget.selectedNode;
      if (node != null &&
          node.isVisible &&
          (node.type == GlbNodeType.mesh || node.meshIndex != null)) {
        final pos = node.getAllDescendantPositions();
        final ind = node.getAllDescendantIndices();
        if (pos.isNotEmpty && ind.isNotEmpty && ind.length <= 150000) {
          _selectedNodeWireframe = FilamentWireframeMesh.create(
            engine: _nativeEngine!,
            positions: pos,
            indices: ind,
          );
          if (_selectedNodeWireframe != null) {
            _nativeScene!.addEntity(_selectedNodeWireframe!.entityId);
          }
        }
      }
    } catch (e) {
      debugPrint('[SubEditor3DViewport] Node wireframe update error: $e');
    }
  }

  /// Builds, replaces or removes the native collision lines.
  @override
  void _updateCollisionLines({bool force = false}) {
    if (_nativeScene == null || _nativeEngine == null) return;
    final lines = widget.collisionLines;
    if (!force && identical(lines, _collisionLinesBuilt)) return;
    try {
      if (_collisionWireframe != null) {
        _nativeEngine!.flushAndWait();
        _nativeScene!.removeEntity(_collisionWireframe!.entityId);
        _collisionWireframe!.dispose();
        _collisionWireframe = null;
      }
      _collisionLinesBuilt = lines;
      if (lines == null || lines.indices.isEmpty) return;
      _collisionWireframe = FilamentWireframeMesh.createLineSegments(
        engine: _nativeEngine!,
        positions: lines.positions,
        lineIndices: lines.indices,
      );
      if (_collisionWireframe != null) {
        _nativeScene!.addEntity(_collisionWireframe!.entityId);
      }
    } catch (e) {
      debugPrint('[SubEditor3DViewport] Collision lines update error: $e');
    }
  }

  /// Builds, restyles or removes the native lines of
  /// [SubEditor3DViewport.overlayLines] so they match it; a set whose
  /// signature is unchanged keeps its entity.
  void _updateOverlayLines({bool force = false}) {
    final engine = _nativeEngine;
    final scene = _nativeScene;
    if (engine == null || scene == null) return;
    final wanted = {for (final s in widget.overlayLines) s.id: s};
    try {
      for (final id in _overlayWires.keys.toList()) {
        final set = wanted[id];
        if (!force && set != null && _overlayWires[id]!.$1 == set.signature) continue;
        final (_, wire) = _overlayWires.remove(id)!;
        engine.flushAndWait();
        scene.removeEntity(wire.entityId);
        wire.dispose();
      }
      for (final set in widget.overlayLines) {
        if (_overlayWires.containsKey(set.id) || set.indices.isEmpty) continue;
        final wire = FilamentWireframeMesh.createLineSegments(
          engine: engine,
          positions: set.positions,
          lineIndices: set.indices,
        );
        if (wire == null) continue;
        if (wire.hasMaterial) wire.setColor(set.r, set.g, set.b, 1.0);
        if (set.xray) {
          // Over the mesh it sits in (Filament's HUD recipe).
          final rm = FilamentRenderableManager(engine);
          rm.getMaterialInstanceAt(wire.entityId, 0)?.setDepthCulling(false);
          rm.setPriority(wire.entityId, 7);
        }
        scene.addEntity(wire.entityId);
        _overlayWires[set.id] = (set.signature, wire);
      }
    } catch (e) {
      debugPrint('[SubEditor3DViewport] Overlay lines update error: $e');
    }
  }

  @override
  void _updateNodeVisibilities() {
    if (_nativeScene == null || _nativeAsset == null) return;
    try {
      final entities = _nativeAsset!.entities;
      if (entities.isEmpty) return;

      final allNodes = widget.glbMesh?.allNodes ?? [];
      final rootNodes = widget.glbMesh?.rootNodes ?? [];

      final Set<int> visibleNodeIndices = {};

      void checkVisibility(GlbNode node, bool parentVisible) {
        final bool effectivelyVisible = parentVisible && node.isVisible;
        if (effectivelyVisible) {
          visibleNodeIndices.add(node.index);
        }
        for (final child in node.children) {
          checkVisibility(child, effectivelyVisible);
        }
      }

      for (final root in rootNodes) {
        checkVisibility(root, true);
      }

      if (rootNodes.isEmpty) {
        for (final node in allNodes) {
          if (node.isVisible) visibleNodeIndices.add(node.index);
        }
      }

      final hiddenNodes = allNodes
          .where((n) => !visibleNodeIndices.contains(n.index))
          .toList();
      if (hiddenNodes.isEmpty) return; // Keep all entities in scene

      for (final node in hiddenNodes) {
        final nodeEntities = _nativeAsset!.getEntitiesByName(node.name);
        for (final entityId in nodeEntities) {
          _nativeScene!.removeEntity(entityId);
        }
      }
    } catch (e) {
      debugPrint('[SubEditor3DViewport] Visibility update error: $e');
    }
  }

  void _updateWireframeMesh() {
    if (_nativeScene == null || _nativeEngine == null) return;
    if (_shadingMode == ViewportShadingMode.wireframe) {
      if (_nativeWireframeMesh != null) {
        _nativeScene!.removeEntity(_nativeWireframeMesh!.entityId);
        _nativeWireframeMesh!.dispose();
        _nativeWireframeMesh = null;
      }
      if (widget.glbMesh != null &&
          widget.glbMesh!.positions.isNotEmpty &&
          widget.glbMesh!.indices.isNotEmpty) {
        _nativeWireframeMesh = FilamentWireframeMesh.create(
          engine: _nativeEngine!,
          positions: widget.glbMesh!.positions,
          indices: widget.glbMesh!.indices,
        );
        if (_nativeWireframeMesh != null) {
          _nativeScene!.addEntity(_nativeWireframeMesh!.entityId);
        }
      }
    }
  }

  void _updateShadingMode(ViewportShadingMode mode) {
    setState(() {
      _shadingMode = mode;
      if (_nativeScene != null && _nativeEngine != null) {
        try {
          if (mode == ViewportShadingMode.wireframe) {
            // Hide solid asset meshes in wireframe mode
            if (_nativeAsset != null) {
              _nativeAsset!.removeFromScene(_nativeScene!);
            }
            for (final a in _componentAssets.values) {
              a.removeFromScene(_nativeScene!);
            }
            for (final s in _socketAssets.values) {
              s.mesh.removeFromScene(_nativeScene!);
            }
            // Lazy create native C++ Filament LINES wireframe mesh
            if (_nativeWireframeMesh == null &&
                widget.glbMesh != null &&
                widget.glbMesh!.positions.isNotEmpty &&
                widget.glbMesh!.indices.isNotEmpty) {
              _nativeWireframeMesh = FilamentWireframeMesh.create(
                engine: _nativeEngine!,
                positions: widget.glbMesh!.positions,
                indices: widget.glbMesh!.indices,
              );
            }
            // Show native C++ Filament LINES wireframe mesh
            if (_nativeWireframeMesh != null) {
              _nativeScene!.addEntity(_nativeWireframeMesh!.entityId);
            }
          } else {
            // Hide native C++ Filament LINES wireframe mesh
            if (_nativeWireframeMesh != null) {
              _nativeScene!.removeEntity(_nativeWireframeMesh!.entityId);
            }
            // Show solid asset meshes back in Lit/Unlit modes
            if (_nativeAsset != null) {
              _nativeAsset!.addToScene(_nativeScene!);
            }
            for (final a in _componentAssets.values) {
              a.addToScene(_nativeScene!);
            }
            // Socket previews follow their host mesh.
            for (final s in _socketAssets.values) {
              s.mesh.addToScene(_nativeScene!);
            }
          }
        } catch (e) {
          debugPrint('[Lumina Studio UI] Wireframe toggle error: $e');
        }
      }
    });
  }
}
