part of '../viewport_widget.dart';

/// Line overlays drawn into the scene: mesh wireframes, light and capsule
/// helpers, volume outlines and the level post-process they follow.
mixin _ViewportWireframes on _ViewportWidgetStateBase {

  /// Test seam: the volume outlines drawn, by actor id.
  Map<String, FilamentWireframeMesh> get volumeWiresForTest => {for (final e in _volumeWires.entries) e.key: e.value.$2};

  /// Test seam: [_volumeWireState].
  Map<String, ({double alpha, Vector3 halfExtent})> get volumeWireStateForTest => Map.unmodifiable(_volumeWireState);

  /// Test seam: the environment post-process service.
  EditorLevelPostProcess get levelPostProcessForTest => _levelPostProcess;

  /// Test seam: the light visualisers drawn, by actor id.
  Map<String, FilamentWireframeMesh> get lightWiresForTest => {for (final e in _lightWires.entries) e.key: e.value.$2};

  @override
  bool get _wireframeMode => widget.viewModel.viewMode == 'Wireframe';

  /// Test seam: actors drawn as wireframes, by actor id.
  Set<String> get meshWiresForTest => _meshWires.keys.toSet();

  /// Test seam: the wireframe entity of [actorId], if it has one.
  int? meshWireEntityForTest(String actorId) => _meshWires[actorId]?.$3.entityId;

  @override
  void _syncMeshWires() {
    final engine = _nativeEngine;
    final scene = _nativeScene;
    if (engine == null || scene == null) return;
    final selected = widget.viewModel.selectedActorIds;
    final wanted = <String, EditorActorNode>{};
    if (_wireframeMode) {
      for (final a in widget.viewModel.actors) {
        final mesh = a.meshData;
        if (mesh != null && mesh.positions.isNotEmpty && mesh.indices.isNotEmpty && _editorActorDrawn(a.id)) {
          wanted[a.id] = a;
        }
      }
    }
    for (final id in _meshWires.keys.where((id) => !wanted.containsKey(id)).toList()) {
      final (_, _, wire) = _meshWires.remove(id)!;
      try {
        scene.removeEntity(wire.entityId);
        wire.dispose();
      } catch (_) {}
    }
    if (!_wireframeMode) _meshWiresSkipped.clear();
    for (final actor in wanted.values) {
      final mesh = actor.meshData!;
      final isSelected = selected.contains(actor.id);
      var entry = _meshWires[actor.id];
      if (entry != null && (!identical(entry.$1, mesh) || entry.$2 != isSelected)) {
        scene.removeEntity(entry.$3.entityId);
        entry.$3.dispose();
        _meshWires.remove(actor.id);
        entry = null;
      }
      if (entry == null) {
        if (mesh.indices.length > _ViewportWidgetState._wireframeIndexCap) {
          if (_meshWiresSkipped.add(actor.id)) {
            EngineLoggerService().log(
              'Wireframe: "${actor.name}" has ${mesh.indices.length ~/ 3} triangles, over the '
              '${_ViewportWidgetState._wireframeIndexCap ~/ 3} the view mode draws; shown as its bounds only',
              level: 'warning',
              source: 'Viewport',
            );
          }
          continue;
        }
        final wire = FilamentWireframeMesh.create(engine: engine, positions: mesh.positions, indices: mesh.indices);
        if (wire == null) continue;
        final (r, g, b) = isSelected ? _ViewportWidgetState._wireframeSelectedColor : _ViewportWidgetState._wireframeColor;
        wire.setColor(r, g, b, 1.0);
        entry = (mesh, isSelected, wire);
        _meshWires[actor.id] = entry;
        scene.addEntity(wire.entityId);
      }
      // The solid root's matrix: stored Z-up cm → Y up, with the asset's unit
      // scale (EditorTransforms.meshMatrix), so edges sit on the surface.
      FilamentTransformManager(engine).setTransform(entry.$3.entityId, EditorTransforms.meshMatrix(actor).storage.toList());
    }
  }

  /// Test seam: the world direction a directional light's arrow points in
  /// (runtime Y-up), from the transform Filament holds for its wire.
  Vector3? lightArrowDirectionForTest(String actorId) {
    final wire = _lightWires[actorId]?.$2;
    final engine = _nativeEngine;
    if (wire == null || engine == null) return null;
    final m = Matrix4.fromList(FilamentTransformManager(engine).getWorldTransform(wire.entityId));
    return (m.transform3(Vector3(0, 0, -1)) - m.transform3(Vector3.zero()))..normalize();
  }

  @override
  void _syncLightWires() {
    final engine = _nativeEngine;
    final scene = _nativeScene;
    if (engine == null || scene == null) return;
    final selected = widget.viewModel.selectedActorIds;
    final wanted = <String, (EditorActorNode, bool)>{
      for (final a in widget.viewModel.actors)
        if (LightActorProperties.isLightActor(a) &&
            _editorActorDrawn(a.id) &&
            (selected.contains(a.id) || LightActorProperties.componentTypeFor(a.type) == 'LuminaDirectionalLightComponent'))
          a.id: (a, selected.contains(a.id)),
    };
    for (final id in _lightWires.keys.where((id) => !wanted.containsKey(id)).toList()) {
      final (_, wire) = _lightWires.remove(id)!;
      try {
        scene.removeEntity(wire.entityId);
        wire.dispose();
      } catch (_) {}
    }
    for (final entry in wanted.entries) {
      final (actor, isSelected) = entry.value;
      final signature = '${actor.type}|${LightActorProperties.read(actor).signature}|$isSelected';
      var wire = _lightWires[entry.key]?.$2;
      if (wire != null && _lightWires[entry.key]!.$1 != signature) {
        scene.removeEntity(wire.entityId);
        wire.dispose();
        _lightWires.remove(entry.key);
        wire = null;
      }
      if (wire == null) {
        final (positions, lines) = _lightLines(actor);
        wire = FilamentWireframeMesh.createLineSegments(engine: engine, positions: positions, lineIndices: lines);
        if (wire == null) continue;
        // The light colour: amber-yellow, full when selected.
        wire.setColor(1.0, 0.85, 0.3, isSelected ? 1.0 : 0.45);
        _lightWires[entry.key] = (signature, wire);
        scene.addEntity(wire.entityId);
      }
      // The actor's matrix without its scale: a visualiser is not scaled.
      final m = Matrix4.compose(LuminaAxes.location(actor.location), LuminaAxes.rotation(actor.rotation), Vector3.all(1));
      FilamentTransformManager(engine).setTransform(wire.entityId, m.storage.toList());
    }
  }

  /// Test seam: actors whose capsule wire is drawn.
  Set<String> get capsuleWiresForTest => _capsuleWires.keys.toSet();

  @override
  void _syncCapsuleWires() {
    final engine = _nativeEngine;
    final scene = _nativeScene;
    if (engine == null || scene == null) return;
    final wanted = {
      for (final a in widget.viewModel.actors)
        if (a.blueprintPreview?.isCharacter == true && _editorActorDrawn(a.id)) a.id: a,
    };
    for (final id in _capsuleWires.keys.where((id) => !wanted.containsKey(id)).toList()) {
      final wire = _capsuleWires.remove(id)!;
      try {
        scene.removeEntity(wire.entityId);
        wire.dispose();
      } catch (_) {}
    }
    for (final actor in wanted.values) {
      var wire = _capsuleWires[actor.id];
      if (wire == null) {
        final preview = actor.blueprintPreview!;
        final (positions, lines) = _capsuleLines(preview.capsuleRadius, preview.capsuleHalfHeight);
        wire = FilamentWireframeMesh.createLineSegments(engine: engine, positions: positions, lineIndices: lines);
        if (wire == null) continue;
        _capsuleWires[actor.id] = wire;
        scene.addEntity(wire.entityId);
      }
      FilamentTransformManager(engine)
          .setTransform(wire.entityId, EditorTransforms.blueprintActorMatrix(actor).storage.toList());
    }
  }

  /// Environment actors → the view's post-processing, for the editor camera;
  /// yields to a Play session like the lights.
  @override
  void _syncLevelPostProcess() {
    if (!_levelPostProcess.isAttached) return;
    _levelPostProcess.sync(
      widget.viewModel.actors,
      quality: widget.viewModel.quality.applyFeatures(LuminaPostProcessSettings.standard()),
      environmentSection: widget.viewModel.levelEnvironment,
      cameraAuthoring: _editorCameraEyeAuthoring,
      isVisible: widget.viewModel.isEffectivelyVisible,
      enabled: !_pieOwnsTheScene,
    );
    _syncVolumeWires();
  }

  void _syncVolumeWires() {
    final engine = _nativeEngine;
    final scene = _nativeScene;
    if (engine == null || scene == null) return;
    final selected = widget.viewModel.selectedActorIds;
    final wanted = <String, (EditorActorNode, bool)>{
      for (final a in widget.viewModel.actors)
        if (EnvironmentActorProperties.isVolume(a) &&
            _editorActorDrawn(a.id) &&
            !EnvironmentActorProperties.isUnbound(a) &&
            (selected.contains(a.id) || a.type == EnvironmentActorProperties.postProcessVolumeType))
          a.id: (a, selected.contains(a.id)),
    };
    for (final id in _volumeWires.keys.where((id) => !wanted.containsKey(id)).toList()) {
      final (_, wire) = _volumeWires.remove(id)!;
      _volumeWireState.remove(id);
      try {
        scene.removeEntity(wire.entityId);
        wire.dispose();
      } catch (_) {}
    }
    for (final entry in wanted.entries) {
      final (actor, isSelected) = entry.value;
      final signature = '${EnvironmentActorProperties.signature(actor)}|$isSelected';
      var wire = _volumeWires[entry.key]?.$2;
      if (wire != null && _volumeWires[entry.key]!.$1 != signature) {
        scene.removeEntity(wire.entityId);
        wire.dispose();
        _volumeWires.remove(entry.key);
        wire = null;
      }
      if (wire == null) {
        final (positions, lines) = _volumeLines(actor);
        wire = FilamentWireframeMesh.createLineSegments(engine: engine, positions: positions, lineIndices: lines);
        if (wire == null) continue;
        // The volume teal: full when selected, dim otherwise.
        final alpha = isSelected ? 1.0 : 0.35;
        wire.setColor(0.2, 0.9, 0.8, alpha);
        _volumeWires[entry.key] = (signature, wire);
        _volumeWireState[entry.key] = (
          alpha: alpha,
          halfExtent: EnvironmentActorProperties.runtimeHalfExtent(actor)..multiply(LuminaAxes.scale(actor.scale)),
        );
        scene.addEntity(wire.entityId);
      }
      FilamentTransformManager(engine).setTransform(
        wire.entityId,
        EnvironmentActorProperties.runtimeTransform(actor).storage.toList(),
      );
    }
  }
}

/// Line segments of the visualiser of [actor] (light-local, Y up, −Z
/// forward): an arrow, a cone or a sphere.
(List<double>, List<int>) _lightLines(EditorActorNode actor) {
  final positions = <double>[];
  final lines = <int>[];
  int add(double x, double y, double z) {
    positions.addAll([x, y, z]);
    return positions.length ~/ 3 - 1;
  }

  void ring(double radius, double z, {int n = 32, Vector3? axis}) {
    final start = positions.length ~/ 3;
    for (var i = 0; i < n; i++) {
      final a = 2 * math.pi * i / n;
      final x = radius * math.cos(a), y = radius * math.sin(a);
      if (axis == null) {
        add(x, y, z);
      } else if (axis.x != 0) {
        add(0, x, y);
      } else {
        add(x, 0, y);
      }
      lines.addAll([start + i, start + (i + 1) % n]);
    }
  }

  final p = LightActorProperties.read(actor);
  switch (LightActorProperties.componentTypeFor(actor.type)) {
    case 'LuminaPointLightComponent':
      final r = p.attenuationRadius;
      ring(r, 0);
      ring(r, 0, axis: Vector3(1, 0, 0));
      ring(r, 0, axis: Vector3(0, 1, 0));
      // A small cross at the light itself.
      for (final d in [Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)]) {
        final a = add(-d.x * 10, -d.y * 10, -d.z * 10);
        final b = add(d.x * 10, d.y * 10, d.z * 10);
        lines.addAll([a, b]);
      }
    case 'LuminaSpotLightComponent':
      final r = p.attenuationRadius;
      final apex = add(0, 0, 0);
      for (final (angle, rays) in [(p.outerConeAngle, 8), (p.innerConeAngle, 0)]) {
        final rad = angle * math.pi / 180.0;
        final ringRadius = r * math.sin(rad);
        final depth = -r * math.cos(rad);
        final start = positions.length ~/ 3;
        ring(ringRadius, depth);
        for (var i = 0; i < rays; i++) {
          lines.addAll([apex, start + (i * 32 ~/ rays)]);
        }
      }
    default:
      // Directional: an arrow along −Z with a four-fin head, and a short
      // cross at the tail.
      const len = _ViewportWidgetState._lightArrowLength;
      final tail = add(0, 0, 0);
      final tip = add(0, 0, -len);
      lines.addAll([tail, tip]);
      const head = len * 0.2, spread = len * 0.08;
      for (final (fx, fy) in [(1.0, 0.0), (-1.0, 0.0), (0.0, 1.0), (0.0, -1.0)]) {
        final fin = add(fx * spread, fy * spread, -len + head);
        lines.addAll([tip, fin]);
      }
      for (final (fx, fy) in [(1.0, 0.0), (0.0, 1.0)]) {
        final a = add(-fx * 20, -fy * 20, 0);
        final b = add(fx * 20, fy * 20, 0);
        lines.addAll([a, b]);
      }
  }
  return (positions, lines);
}

/// Line segments of a capsule of [radius] and [halfHeight] about the
/// origin, Y up (runtime space).
(List<double>, List<int>) _capsuleLines(double radius, double halfHeight) {
  const n = 24;
  final positions = <double>[];
  final lines = <int>[];
  final cyl = math.max(0.0, halfHeight - radius);
  int ring(double y) {
    final start = positions.length ~/ 3;
    for (var i = 0; i < n; i++) {
      final a = 2 * math.pi * i / n;
      positions.addAll([radius * math.cos(a), y, radius * math.sin(a)]);
      lines.addAll([start + i, start + (i + 1) % n]);
    }
    return start;
  }

  final top = ring(cyl);
  final bottom = ring(-cyl);
  for (var i = 0; i < n; i += n ~/ 4) {
    lines.addAll([top + i, bottom + i]);
  }
  // Hemispheres: two half-circle arcs each, in the XY and ZY planes.
  for (final sign in [1.0, -1.0]) {
    for (final plane in [0, 1]) {
      final start = positions.length ~/ 3;
      const m = 12;
      for (var i = 0; i <= m; i++) {
        final a = math.pi * i / m;
        final horizontal = radius * math.cos(a);
        final y = sign * (cyl + radius * math.sin(a));
        positions.addAll(plane == 0 ? [horizontal, y, 0.0] : [0.0, y, horizontal]);
        if (i > 0) lines.addAll([start + i - 1, start + i]);
      }
    }
  }
  return (positions, lines);
}

/// Line geometry of a volume outline in the actor's local runtime frame
/// (unscaled: the actor matrix carries the scale): a box's 12 edges, or a
/// sphere's three great circles.
(List<double>, List<int>) _volumeLines(EditorActorNode actor) {
  final e = EnvironmentActorProperties.runtimeHalfExtent(actor);
  final positions = <double>[];
  final lines = <int>[];
  if (EnvironmentActorProperties.isSphere(actor)) {
    const segments = 48;
    final r = e.x;
    for (var axis = 0; axis < 3; axis++) {
      final base = positions.length ~/ 3;
      for (var i = 0; i < segments; i++) {
        final a = i / segments * 2 * math.pi;
        final c = r * math.cos(a);
        final s = r * math.sin(a);
        positions.addAll(axis == 0 ? [0.0, c, s] : axis == 1 ? [c, 0.0, s] : [c, s, 0.0]);
        lines.addAll([base + i, base + (i + 1) % segments]);
      }
    }
    return (positions, lines);
  }
  for (var i = 0; i < 8; i++) {
    positions.addAll([(i & 1) == 0 ? -e.x : e.x, (i & 2) == 0 ? -e.y : e.y, (i & 4) == 0 ? -e.z : e.z]);
  }
  for (var i = 0; i < 8; i++) {
    for (final bit in [1, 2, 4]) {
      if ((i & bit) == 0) lines.addAll([i, i | bit]);
    }
  }
  return (positions, lines);
}
