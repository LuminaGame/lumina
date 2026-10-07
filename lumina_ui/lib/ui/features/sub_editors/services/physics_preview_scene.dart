import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_filament/flutter_filament.dart'
    show
        CullingMode,
        FilamentEngine,
        FilamentMaterialInstance,
        FilamentMaterialProvider,
        FilamentRenderableManager,
        FilamentWireframeMesh,
        MaterialKey;
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

import 'package:lumina_ui/ui/features/sub_editors/models/physics_asset_document.dart';

/// Triangulated body geometry for the `Solid Bodies` view mode.
class PhysicsSolidMesh {
  final String name;
  final Float32List positions;
  final Float32List normals;
  final Uint8List colors;
  final Uint32List indices;

  const PhysicsSolidMesh({
    required this.name,
    required this.positions,
    required this.normals,
    required this.colors,
    required this.indices,
  });

  int get vertexCount => positions.length ~/ 3;
  int get triangleCount => indices.length ~/ 3;
}

/// Builds world-space line geometry for the Physics Asset editor's body and
/// constraint overlays.
///
/// Capsules go through the engine's own [LuminaCapsuleComponent.buildCapsuleWireframe]
/// so the editor draws exactly the shape the collision stack tests; boxes and
/// spheres are line sets built from the same world transform chain
/// (`entityWorld x G_bone x offset`).
class PhysicsOverlayBuilder {
  static const int circleSegments = 16;

  /// Wireframe for [body] placed at [world].
  static PhysicsOverlayLineSet buildBody(
    PhysicsBody body,
    Matrix4 world, {
    bool isSelected = false,
    bool dimmed = false,
    bool filled = false,
  }) {
    final List<Vector3> pts;
    switch (body.shape) {
      case PhysicsShapeType.capsule:
        pts = _capsulePoints(body, world);
        break;
      case PhysicsShapeType.box:
        pts = _boxPoints(body, world);
        break;
      case PhysicsShapeType.sphere:
        pts = _spherePoints(body, world);
        break;
    }
    return _fromSegmentPairs(
      name: body.name,
      pts: pts,
      isSelected: isSelected,
      dimmed: dimmed,
      filled: filled,
    );
  }

  /// Axis tripod drawn at the joint point between the two constrained bodies
  /// ([axisLength] in cm, world units).
  static PhysicsOverlayLineSet buildConstraint(
    PhysicsConstraint constraint,
    Matrix4 worldA,
    Matrix4 worldB, {
    bool isSelected = false,
    double axisLength = 12.0,
  }) {
    final joint = (worldA.getTranslation() + worldB.getTranslation()) * 0.5;
    final rot = Quaternion.fromRotation(worldB.getRotation());
    final pts = <Vector3>[];
    for (final axis in [Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)]) {
      final dir = rot.rotated(axis) * axisLength;
      pts..add(joint)..add(joint + dir);
    }
    // A short link between the two body centres makes the pairing readable.
    pts..add(worldA.getTranslation())..add(worldB.getTranslation());
    return _fromSegmentPairs(
      name: constraint.name,
      pts: pts,
      isConstraint: true,
      isSelected: isSelected,
    );
  }

  static PhysicsOverlayLineSet _fromSegmentPairs({
    required String name,
    required List<Vector3> pts,
    bool isConstraint = false,
    bool isSelected = false,
    bool dimmed = false,
    bool filled = false,
  }) {
    final positions = <double>[];
    final indices = <int>[];
    for (int i = 0; i + 1 < pts.length; i += 2) {
      final base = positions.length ~/ 3;
      positions..addAll([pts[i].x, pts[i].y, pts[i].z])..addAll([pts[i + 1].x, pts[i + 1].y, pts[i + 1].z]);
      indices..add(base)..add(base + 1);
    }
    return PhysicsOverlayLineSet(
      name: name,
      positions: positions,
      lineIndices: indices,
      isConstraint: isConstraint,
      isSelected: isSelected,
      dimmed: dimmed,
      filled: filled,
    );
  }

  /// Translucent solid geometry for [body] at [world] (Solid Bodies mode).
  ///
  /// Capsules and spheres share one lat/long tessellation — a capsule is the
  /// same sphere with its two halves pushed apart by the inner segment, which
  /// is exactly the engine's `halfHeight - radius` convention.
  static PhysicsSolidMesh buildSolidBody(
    PhysicsBody body,
    Matrix4 world, {
    bool isSelected = false,
    bool dimmed = false,
    int latBands = 10,
    int longBands = 16,
  }) {
    final positions = <double>[];
    final normals = <double>[];
    final indices = <int>[];

    if (body.shape == PhysicsShapeType.box) {
      _appendBox(body.halfExtents, positions, normals, indices);
    } else {
      final r = body.shape == PhysicsShapeType.sphere ? body.radius : body.radius;
      final segHalf = body.shape == PhysicsShapeType.capsule
          ? math.max(0.0, body.effectiveHalfHeight - body.radius)
          : 0.0;
      _appendCapsule(r, segHalf, latBands, longBands, positions, normals, indices);
    }

    // World transform: positions by the full matrix, normals by its rotation.
    final rot = Quaternion.fromRotation(world.getRotation());
    final outPositions = Float32List(positions.length);
    final outNormals = Float32List(normals.length);
    for (int i = 0; i < positions.length; i += 3) {
      final p = (world * Vector4(positions[i], positions[i + 1], positions[i + 2], 1.0)).xyz;
      outPositions[i] = p.x;
      outPositions[i + 1] = p.y;
      outPositions[i + 2] = p.z;
      final n = rot.rotated(Vector3(normals[i], normals[i + 1], normals[i + 2]));
      outNormals[i] = n.x;
      outNormals[i + 1] = n.y;
      outNormals[i + 2] = n.z;
    }

    final vertexCount = outPositions.length ~/ 3;
    final rgba = isSelected
        ? const [255, 214, 79, 150]
        : (dimmed ? const [120, 120, 130, 70] : const [80, 170, 255, 110]);
    final colors = Uint8List(vertexCount * 4);
    for (int v = 0; v < vertexCount; v++) {
      colors[v * 4] = rgba[0];
      colors[v * 4 + 1] = rgba[1];
      colors[v * 4 + 2] = rgba[2];
      colors[v * 4 + 3] = rgba[3];
    }

    return PhysicsSolidMesh(
      name: body.name,
      positions: outPositions,
      normals: outNormals,
      colors: colors,
      indices: Uint32List.fromList(indices),
    );
  }

  static void _appendBox(
    List<double> half,
    List<double> positions,
    List<double> normals,
    List<int> indices,
  ) {
    const faces = <List<double>>[
      [1, 0, 0], [-1, 0, 0],
      [0, 1, 0], [0, -1, 0],
      [0, 0, 1], [0, 0, -1],
    ];
    for (final n in faces) {
      final normal = Vector3(n[0], n[1], n[2]);
      // Two in-plane axes for this face.
      final tangent = normal.x.abs() > 0.5 ? Vector3(0, 1, 0) : Vector3(1, 0, 0);
      final bitangent = normal.cross(tangent);
      final base = positions.length ~/ 3;
      for (final s in const [[-1.0, -1.0], [1.0, -1.0], [1.0, 1.0], [-1.0, 1.0]]) {
        final p = normal.clone()
          ..multiply(Vector3(half[0], half[1], half[2]))
          ..add(tangent * (s[0] * _axisHalf(tangent, half)))
          ..add(bitangent * (s[1] * _axisHalf(bitangent, half)));
        positions.addAll([p.x, p.y, p.z]);
        normals.addAll([normal.x, normal.y, normal.z]);
      }
      indices.addAll([base, base + 1, base + 2, base, base + 2, base + 3]);
    }
  }

  static double _axisHalf(Vector3 axis, List<double> half) =>
      (axis.x.abs() * half[0]) + (axis.y.abs() * half[1]) + (axis.z.abs() * half[2]);

  static void _appendCapsule(
    double radius,
    double segHalf,
    int latBands,
    int longBands,
    List<double> positions,
    List<double> normals,
    List<int> indices,
  ) {
    final rows = <int>[];
    void emitRow(double theta, double yOffset) {
      rows.add(positions.length ~/ 3);
      final sinT = math.sin(theta);
      final cosT = math.cos(theta);
      for (int j = 0; j <= longBands; j++) {
        final phi = 2.0 * math.pi * j / longBands;
        final nx = sinT * math.cos(phi);
        final ny = cosT;
        final nz = sinT * math.sin(phi);
        positions.addAll([nx * radius, ny * radius + yOffset, nz * radius]);
        normals.addAll([nx, ny, nz]);
      }
    }

    for (int i = 0; i <= latBands; i++) {
      final theta = math.pi * i / latBands;
      final cosT = math.cos(theta);
      if (cosT.abs() < 1e-9 && segHalf > 0.0) {
        emitRow(theta, segHalf);
        emitRow(theta, -segHalf);
      } else {
        emitRow(theta, cosT >= 0.0 ? segHalf : -segHalf);
      }
    }

    for (int r = 0; r + 1 < rows.length; r++) {
      final a = rows[r];
      final b = rows[r + 1];
      for (int j = 0; j < longBands; j++) {
        indices.addAll([a + j, b + j, b + j + 1, a + j, b + j + 1, a + j + 1]);
      }
    }
  }

  static List<Vector3> _capsulePoints(PhysicsBody body, Matrix4 world) {
    final capsule = LuminaCapsuleComponent(
      location: world.getTranslation(),
      rotation: Quaternion.fromRotation(world.getRotation()),
      radius: body.radius,
      halfHeight: body.effectiveHalfHeight,
    );
    return capsule.buildCapsuleWireframe(segments: circleSegments);
  }

  static List<Vector3> _boxPoints(PhysicsBody body, Matrix4 world) {
    final h = body.halfExtents;
    final corners = <Vector3>[];
    for (final sx in const [-1.0, 1.0]) {
      for (final sy in const [-1.0, 1.0]) {
        for (final sz in const [-1.0, 1.0]) {
          final local = Vector3(sx * h[0], sy * h[1], sz * h[2]);
          corners.add((world * Vector4(local.x, local.y, local.z, 1.0)).xyz);
        }
      }
    }
    // Corner index = (sx<<2) | (sy<<1) | sz with 0 => -1, 1 => +1.
    const edges = <List<int>>[
      [0, 1], [1, 3], [3, 2], [2, 0], // x = -1 face
      [4, 5], [5, 7], [7, 6], [6, 4], // x = +1 face
      [0, 4], [1, 5], [2, 6], [3, 7], // connecting edges
    ];
    final pts = <Vector3>[];
    for (final e in edges) {
      pts..add(corners[e[0]])..add(corners[e[1]]);
    }
    return pts;
  }

  static List<Vector3> _spherePoints(PhysicsBody body, Matrix4 world) {
    final centre = world.getTranslation();
    final rot = Quaternion.fromRotation(world.getRotation());
    final r = body.radius;
    final pts = <Vector3>[];
    final step = (2.0 * math.pi) / circleSegments;

    void ring(Vector3 u, Vector3 v) {
      for (int i = 0; i < circleSegments; i++) {
        final a = i * step;
        final b = (i + 1) * step;
        final p1 = centre + rot.rotated(u * (math.cos(a) * r) + v * (math.sin(a) * r));
        final p2 = centre + rot.rotated(u * (math.cos(b) * r) + v * (math.sin(b) * r));
        pts..add(p1)..add(p2);
      }
    }

    ring(Vector3(1, 0, 0), Vector3(0, 1, 0));
    ring(Vector3(1, 0, 0), Vector3(0, 0, 1));
    ring(Vector3(0, 1, 0), Vector3(0, 0, 1));
    return pts;
  }
}

/// Mounts the skeletal mesh and the authored body / constraint overlays into
/// the sub-editor viewport's real Filament scene.
///
/// The viewport hands over its [LuminaWorld] (already carrying the native
/// context) through `onPreviewWorldReady`. The mesh is a lumina mesh
/// component, drawn at its asset unit scale (glTF metres x
/// [LuminaUnits.unitsPerMetre], so a human character is 170-180 cm tall, the scale the
/// bodies are authored at), lit by a sun and a sky of its own.
/// Every line set becomes one [FilamentWireframeMesh]. Only sets whose
/// geometry actually changed are rebuilt, and teardown follows the viewport's
/// `flushAndWait` -> remove -> dispose ordering.
class PhysicsPreviewScene {
  LuminaWorld? _world;

  String? _meshPath;
  Uint8List? _meshPayload;
  LuminaStaticMeshComponent? _mesh;
  LuminaActor? _meshActor;
  final List<LuminaActor> _environment = [];
  final Map<String, FilamentWireframeMesh> _meshes = {};
  final Map<String, String> _signatures = {};

  LuminaActor? _solidActor;
  LuminaProceduralMeshComponent? _solid;
  FilamentMaterialProvider? _materialProvider;
  FilamentMaterialInstance? _solidMaterial;
  final Map<String, int> _solidSections = {};
  final Map<String, String> _solidSignatures = {};
  int _nextSolidSection = 0;

  bool get isAttached => _world != null && !_world!.isCleanedUp;

  /// Number of live native wireframe entities (one per visible line set).
  int get entityCount => _meshes.length;

  /// Number of live translucent solid-body sections.
  int get solidSectionCount => _solidSections.length;

  /// The mounted skeletal mesh component, while attached.
  LuminaStaticMeshComponent? get meshComponent => _mesh;

  /// The lumina component the preview draws the skeletal mesh [path] with:
  /// the GLB [payload] at lumina's default asset unit scale (glTF metres ->
  /// cm), the scale `PhysicsAssetEditorViewModel.meshUnitScale` authors at.
  static LuminaStaticMeshComponent meshComponentFor(String path, Uint8List payload) => LuminaStaticMeshComponent(
        key: const LuminaObjectKey('physics_preview_mesh'),
        meshAssetPath: path,
        assetProvider: (_) async => payload,
      );

  /// Shows the skeletal mesh at [path] ([payload] is its GLB, the `.lmas`
  /// raw payload); the same path again keeps the mounted mesh.
  void setMesh(String? path, Uint8List? payload) {
    if (path == _meshPath) return;
    _unmountMesh();
    _meshPath = path;
    _meshPayload = payload;
    _mountMesh();
  }

  void _mountMesh() {
    final world = _world;
    final path = _meshPath;
    final payload = _meshPayload;
    if (world == null || world.isCleanedUp || _meshActor != null) return;
    if (path == null || payload == null || payload.isEmpty) return;
    try {
      final mesh = meshComponentFor(path, payload);
      _mesh = mesh;
      _meshActor = LuminaActor(key: const LuminaObjectKey('physics_preview_mesh_actor'), root: mesh);
      world.persistentLevel.registerActor(_meshActor!);
      // A skinned mesh needs its joint matrices once to draw its bind pose.
      mesh.loaded.then((_) {
        if (!identical(_mesh, mesh) || !isAttached) return;
        mesh.assetInstance?.animator.updateBoneMatrices();
      }).catchError((Object e) => debugPrint('[PhysicsPreviewScene] mesh load failed: $e'));
    } catch (e) {
      debugPrint('[PhysicsPreviewScene] mesh mount failed: $e');
      _meshActor = null;
      _mesh = null;
    }
  }

  void _unmountMesh() {
    final world = _world;
    final actor = _meshActor;
    _meshActor = null;
    _mesh = null;
    if (world == null || world.isCleanedUp || actor == null) return;
    try {
      world.persistentLevel.unregisterActor(actor);
    } catch (e) {
      debugPrint('[PhysicsPreviewScene] mesh unmount failed: $e');
    }
  }

  /// A sun and a sky: the viewport skips its studio lights for a preview
  /// world, and a PBR mesh with no light is black.
  void _mountEnvironment(LuminaWorld world) {
    try {
      for (final actor in [
        LuminaActor(
          key: const LuminaObjectKey('physics_preview_sun'),
          root: LuminaDirectionalLightComponent(
            rotation: Quaternion.euler(35 * math.pi / 180, -50 * math.pi / 180, 0),
            color: Vector3(1.0, 0.97, 0.92),
            intensity: 90000.0,
            castShadows: true,
            isSun: true,
          ),
        ),
        LuminaActor(
          key: const LuminaObjectKey('physics_preview_sky'),
          root: LuminaSkyComponent.color(
            color: Vector4(0.10, 0.11, 0.14, 1.0),
            skyIntensity: 14000.0,
            iblIntensity: 22000.0,
          ),
        ),
      ]) {
        world.persistentLevel.registerActor(actor);
        _environment.add(actor);
      }
    } catch (e) {
      debugPrint('[PhysicsPreviewScene] environment failed: $e');
    }
  }

  void attach(LuminaWorld world) {
    detach();
    if (world.isCleanedUp || !world.hasNativeContext) return;
    _world = world;
    _mountEnvironment(world);
    _mountMesh();
    try {
      _solid = LuminaProceduralMeshComponent();
      _solidActor = LuminaActor(key: const LuminaObjectKey('physics_solid_overlay'), root: _solid!);
      world.persistentLevel.registerActor(_solidActor!);
    } catch (e) {
      debugPrint('[PhysicsPreviewScene] solid overlay actor failed: $e');
      _solid = null;
      _solidActor = null;
    }
  }

  /// Rebuilds the translucent solid bodies so they match [meshes] exactly.
  void syncSolid(List<PhysicsSolidMesh> meshes) {
    final overlay = _solid;
    final world = _world;
    if (overlay == null || world == null || world.isCleanedUp) return;
    final wanted = {for (final m in meshes) m.name: m};
    try {
      for (final name in _solidSections.keys.toList()) {
        final mesh = wanted[name];
        if (mesh != null && _solidSignatures[name] == _solidSignatureOf(mesh)) continue;
        overlay.clearMeshSection(_solidSections.remove(name)!);
        _solidSignatures.remove(name);
      }
      for (final mesh in meshes) {
        if (_solidSections.containsKey(mesh.name)) continue;
        if (mesh.positions.isEmpty || mesh.indices.isEmpty) continue;
        final section = _nextSolidSection++;
        overlay.createMeshSection(
          section,
          positions: mesh.positions,
          normals: mesh.normals,
          colors: mesh.colors,
          indices: mesh.indices,
          material: _translucentMaterial(),
          generateTangents: false,
        );
        _solidSections[mesh.name] = section;
        _solidSignatures[mesh.name] = _solidSignatureOf(mesh);
      }
      world.tick(1.0 / 60.0);
    } catch (e) {
      debugPrint('[PhysicsPreviewScene] solid sync failed: $e');
    }
  }

  String _solidSignatureOf(PhysicsSolidMesh mesh) {
    final buffer = StringBuffer()..write(mesh.positions.length)..write(mesh.colors.isEmpty ? 0 : mesh.colors[3]);
    for (int i = 0; i < mesh.positions.length; i += 7) {
      buffer.write(mesh.positions[i].toStringAsFixed(5));
    }
    return buffer.toString();
  }

  FilamentMaterialInstance? _translucentMaterial() {
    final cached = _solidMaterial;
    if (cached != null) return cached;
    final world = _world;
    if (world == null || !world.hasNativeContext) return null;
    try {
      _materialProvider ??= FilamentMaterialProvider.ubershader(world.filamentEngine);
      final result = _materialProvider!.createMaterialInstance(
        MaterialKey(unlit: true, alphaMode: 2, doubleSided: true, hasVertexColors: true),
        label: 'physics_solid_body',
      );
      final mi = result.instance;
      if (mi == null) return null;
      mi.setFloat4('baseColorFactor', 1.0, 1.0, 1.0, 1.0);
      mi.setCullingMode(CullingMode.none);
      mi.setDepthWrite(false);
      // X-ray: bodies sit inside the skin they wrap, so they draw over it.
      mi.setDepthCulling(false);
      _solidMaterial = mi;
      return mi;
    } catch (e) {
      debugPrint('[PhysicsPreviewScene] solid material failed: $e');
      return null;
    }
  }

  /// Colours a line set like its solid body (white lines vanish against a
  /// light mesh) and draws it over the mesh, whose skin it sits inside: no
  /// depth test, last among opaque renderables (Filament's HUD recipe).
  static void _style(FilamentEngine engine, FilamentWireframeMesh mesh, PhysicsOverlayLineSet set) {
    final (r, g, b) = set.isSelected
        ? (1.0, 0.84, 0.31)
        : set.isConstraint
            ? (1.0, 0.6, 0.1)
            : set.dimmed
                ? (0.47, 0.47, 0.51)
                : (0.31, 0.67, 1.0);
    if (mesh.hasMaterial) mesh.setColor(r, g, b, 1.0);
    final rm = FilamentRenderableManager(engine);
    rm.getMaterialInstanceAt(mesh.entityId, 0)?.setDepthCulling(false);
    rm.setPriority(mesh.entityId, 7);
  }

  /// Rebuilds the native entities so they match [sets] exactly.
  void sync(List<PhysicsOverlayLineSet> sets) {
    final world = _world;
    if (world == null || world.isCleanedUp) return;
    final engine = world.filamentEngineOrNull;
    final scene = world.filamentSceneOrNull;
    if (engine == null || scene == null) return;

    final wanted = {for (final s in sets) s.name: s};
    try {
      for (final name in _meshes.keys.toList()) {
        final set = wanted[name];
        if (set != null && _signatures[name] == _signatureOf(set)) continue;
        engine.flushAndWait();
        final mesh = _meshes.remove(name)!;
        _signatures.remove(name);
        scene.removeEntity(mesh.entityId);
        mesh.dispose();
        engine.flushAndWait();
      }
      for (final set in sets) {
        if (_meshes.containsKey(set.name)) continue;
        if (set.positions.isEmpty || set.lineIndices.isEmpty) continue;
        final mesh = FilamentWireframeMesh.createLineSegments(
          engine: engine,
          positions: set.positions,
          lineIndices: set.lineIndices,
        );
        if (mesh == null) continue;
        _style(engine, mesh, set);
        scene.addEntity(mesh.entityId);
        _meshes[set.name] = mesh;
        _signatures[set.name] = _signatureOf(set);
      }
    } catch (e) {
      debugPrint('[PhysicsPreviewScene] overlay sync failed: $e');
    }
  }

  void detach() {
    _unmountMesh();
    final world = _world;
    _world = null;
    try {
      if (world != null && !world.isCleanedUp) {
        for (final actor in _environment) {
          world.persistentLevel.unregisterActor(actor);
        }
      }
      _environment.clear();
      if (world != null && !world.isCleanedUp && _solidActor != null) {
        world.persistentLevel.unregisterActor(_solidActor!);
      }
      _solidMaterial?.dispose();
      _materialProvider?.dispose();
    } catch (e) {
      debugPrint('[PhysicsPreviewScene] solid detach: $e');
    }
    _solidMaterial = null;
    _materialProvider = null;
    _solidActor = null;
    _solid = null;
    _solidSections.clear();
    _solidSignatures.clear();
    _nextSolidSection = 0;

    if (_meshes.isEmpty) return;
    final engine = world?.filamentEngineOrNull;
    final scene = world?.filamentSceneOrNull;
    for (final entry in _meshes.entries) {
      try {
        engine?.flushAndWait();
        if (world != null && !world.isCleanedUp) scene?.removeEntity(entry.value.entityId);
        entry.value.dispose();
      } catch (_) {}
    }
    _meshes.clear();
    _signatures.clear();
  }

  String _signatureOf(PhysicsOverlayLineSet set) {
    final buffer = StringBuffer()
      ..write(set.isSelected)
      ..write(set.dimmed)
      ..write(set.filled)
      ..write(set.positions.length);
    for (final p in set.positions) {
      buffer.write(p.toStringAsFixed(5));
    }
    return buffer.toString();
  }
}
