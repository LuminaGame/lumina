part of 'viewport_runtime.dart';

/// The preview's view modes ([LuminaViewportViewMode]): Lit draws the
/// scene as described; Unlit turns the key light, the description's lights
/// and shadows off (the IBL alone lights the base and vertex colours);
/// Wireframe hides each mesh's solid and draws its triangle edges, built
/// from the mesh's GLB on a worker isolate.
mixin _ViewportViewMode {
  FilamentEngine get engine;
  FilamentScene get scene;
  FilamentView get view;
  Map<String, _RuntimeNode> get _nodes;
  LuminaActor? get _keyLight;
  bool get isDisposed;
  Future<Uint8List> _read(String path);

  /// The densest mesh Wireframe draws as lines; denser ones stay solid.
  static const int wireframeTriangleCap = 3000000;

  String _viewMode = LuminaViewportViewMode.lit;

  /// Line meshes by node id, and what they were built from.
  final Map<String, (String, FilamentWireframeMesh)> _wires = {};
  final Map<String, String> _wireRequests = {};

  /// The view mode applied now.
  String get viewMode => _viewMode;

  /// Node ids whose wireframe is drawn (tests, diagnostics).
  Iterable<String> get wireframeNodeIds => _wires.keys;

  /// The line entity of node [id]'s wireframe, if drawn.
  int? wireframeEntityOf(String id) => _wires[id]?.$2.entityId;

  /// The key light's intensity now (0 in Unlit; tests, diagnostics).
  double get keyLightLux {
    final key = _keyLight?.rootComponent;
    return key is LuminaLightComponent ? key.intensity : 0.0;
  }

  /// Whether a mesh's solid is drawn (not in Wireframe).
  bool get _solidShown => _viewMode != LuminaViewportViewMode.wireframe;

  void _applyViewMode(String mode) {
    _viewMode = mode;
    final lit = mode != LuminaViewportViewMode.unlit;
    view.shadowingEnabled = lit;
    final key = _keyLight?.rootComponent;
    if (key is LuminaLightComponent) key.intensity = lit ? _ViewportStage.keyLightIntensity : 0.0;
    for (final node in _nodes.values) {
      _applyNodeLight(node);
      _applyNodeSolid(node);
    }
    _syncWires();
  }

  /// A description light's intensity under the view mode.
  void _applyNodeLight(_RuntimeNode node) {
    final light = node.root;
    if (light is! LuminaLightComponent) return;
    final l = node.json['light'];
    final described = l is Map && l['intensity'] is num ? (l['intensity']! as num).toDouble() : 100000.0;
    light.intensity = _viewMode == LuminaViewportViewMode.unlit ? 0.0 : described;
  }

  /// Shows or hides a mesh's solid for the view mode and its `visible`.
  void _applyNodeSolid(_RuntimeNode node) {
    final mesh = node.mesh;
    if (mesh == null) return;
    final visible = node.json['visible'] != false;
    final wired = _wires.containsKey(node.id);
    mesh.visible = visible && (_solidShown || !wired);
    final wire = _wires[node.id]?.$2;
    if (wire != null) {
      final inScene = scene.hasEntity(wire.entityId);
      if (visible && !inScene) scene.addEntity(wire.entityId);
      if (!visible && inScene) scene.removeEntity(wire.entityId);
    }
  }

  /// Builds the missing wireframes (Wireframe) or drops them all.
  void _syncWires() {
    if (_solidShown) {
      for (final id in _wires.keys.toList()) {
        _dropWire(id);
      }
      for (final node in _nodes.values) {
        _applyNodeSolid(node);
      }
      return;
    }
    for (final node in _nodes.values) {
      if (node.mesh == null || !node.loaded) continue;
      final source = node.meshAsset;
      if (_wires[node.id]?.$1 == source || _wireRequests[node.id] == source) continue;
      _dropWire(node.id);
      unawaited(_buildWire(node, source));
    }
  }

  Future<void> _buildWire(_RuntimeNode node, String source) async {
    _wireRequests[node.id] = source;
    LuminaViewportWireSource? wire;
    try {
      final bytes = await LuminaMeshAssetCache.meshBytes(_read, source);
      wire = await Isolate.run(() async {
        final direct = LuminaViewportWireSource.read(bytes, maxTriangles: wireframeTriangleCap);
        if (direct != null || !LuminaViewportWireSource.usesDraco(bytes)) return direct;
        // Draco-compressed primitives: decoded by the engine's reader.
        final data = await GlbReader.parse(bytes, decoders: GlbDecoders(draco: LuminaGlbLoader.decoders.draco));
        if (data == null || data.indices.isEmpty || data.triangleCount > wireframeTriangleCap) return null;
        return LuminaViewportWireSource(Float32List.fromList(data.positions), Uint32List.fromList(data.indices));
      });
    } catch (e) {
      developer.log('Wireframe of $source failed: $e', name: 'LuminaViewport');
    }
    if (_wireRequests[node.id] != source) return;
    _wireRequests.remove(node.id);
    final root = node.mesh?.rootEntity;
    if (isDisposed || _solidShown || !identical(_nodes[node.id], node) || node.meshAsset != source || root == null) return;
    if (wire == null) {
      developer.log('Wireframe: $source has no triangles or more than $wireframeTriangleCap; drawn solid', name: 'LuminaViewport');
      return;
    }
    final mesh = FilamentWireframeMesh.create(engine: engine, positions: wire.positions, indices: wire.indices);
    if (mesh == null) return;
    mesh.setColor(0.72, 0.78, 0.88, 1.0);
    // Under the mesh's root entity, so it follows the node and the asset's
    // unit scale; the positions carry the GLB's node transforms.
    FilamentTransformManager(engine).setParent(mesh.entityId, root);
    _wires[node.id] = (source, mesh);
    _applyNodeSolid(node);
  }

  void _dropWire(String id) {
    _wireRequests.remove(id);
    final wire = _wires.remove(id)?.$2;
    if (wire == null) return;
    try {
      if (scene.hasEntity(wire.entityId)) scene.removeEntity(wire.entityId);
      wire.dispose();
    } catch (_) {
      // The engine went first.
    }
  }
}
