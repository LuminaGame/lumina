import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_filament/filament.dart';
import 'package:vector_math/vector_math_64.dart' hide Frustum;

import 'package:lumina_core/lumina_core.dart';
import 'package:lumina/src/assets/glb_loader.dart';
import 'package:lumina/src/collision/collision_subsystem.dart';
import 'package:lumina/src/components/collision/collision_component.dart';
import 'package:lumina/src/object/actor.dart';
import 'package:lumina/src/utility/lumina_assets.dart';
import 'package:lumina/src/components/base/scene_component.dart';
import 'package:lumina/src/components/mesh/instanced_static_mesh_component.dart';
import 'package:lumina/src/components/mesh/procedural_mesh_component.dart';
import 'package:lumina/src/components/landscape/landscape_brush_cursor.dart';
import 'package:lumina/src/components/landscape/landscape_mesh_builder.dart';
import 'package:lumina/src/components/landscape/landscape_residency.dart';
import 'package:lumina/src/components/landscape/landscape_section_map.dart';

part 'landscape_component/state.dart';
part 'landscape_component/residency.dart';
part 'landscape_component/brush_cursor.dart';
part 'landscape_component/foliage.dart';

/// Renders a sculpted terrain — heightmap tiles plus foliage layers — from a
/// `LANDSCAPE` `.lmas` payload.
///
/// This is the single implementation of terrain drawing in the stack: the
/// Landscape sub-editor's preview, the level viewport and generated game code
/// all mount this component, so what a designer sculpts is exactly what ships.
/// The terrain is one [LuminaProceduralMeshComponent] with one section per
/// tile (see [LandscapeSectionMap]); each foliage layer becomes one or more
/// [LuminaInstancedStaticMeshComponent]s built from the real geometry of that
/// layer's mesh asset.
///
/// ## Lighting
///
/// The terrain is drawn with the **lit**, vertex-coloured ubershader variant:
/// tiles are shaded by the heightmap's own normals, their
/// vertex colour is a slope-derived albedo (grass → rock, see
/// [LandscapeMeshBuilder.writeAlbedo]), and every tile casts and receives the
/// world's shadows. Foliage is lit too, in its glTF's base colour, and casts
/// and receives shadows. [buildTerrainMaterial] is the one place to change the
/// terrain material; a weight-blended multi-layer material is the remaining
/// gap.
///
/// ## Known engine limits, stated rather than hidden
///
/// * **Foliage is chunked.** Filament caps one instanced renderable at
///   `engine.maxAutomaticInstances` — **64** on this machine's Vulkan backend
///   — so a layer's instances are split across that many renderables each.
///   Chunks hold contiguous slices, so batch order matches the payload order.
/// * **Collision.** The terrain is a walkable heightfield collider:
///   once its payload is loaded, [collisionComponent] — a
///   [CollisionShapeType.heightfield] component over the same heightmap the
///   tiles are built from, at this component's world transform — registers
///   with the world's `LuminaCollisionSubsystem`. Capsules and spheres sweep
///   and overlap against it and rays hit it, so a character walks, steps and
///   stops on it exactly where the drawn surface is; it reads the heightmap
///   live, so a sculpt moves the collider too. [sampleHeightAtWorld] and
///   [sampleNormalAtWorld] remain the analytic ground query.
class LuminaLandscapeComponent extends _LuminaLandscapeComponentState
    with
        _LandscapeResidency,
        _LandscapeBrushCursor,
        _LandscapeFoliage {
  LuminaLandscapeComponent({
    super.data,
    super.assetPath,
    super.quadsPerSection,
    super.unitsPerMetre,
    super.foliageMeshScale,
    super.foliageChunkCapacity,
    super.residencyBudget,
    super.key,
    super.location,
    super.rotation,
    super.scale,
    super.isVisible,
  });

  /// A terrain the editor fills in itself.
  ///
  /// The Landscape sub-editor owns a live heightmap and streams tile rebuilds
  /// and painted foliage as the user sculpts, so it mounts an empty component
  /// and drives [createTerrainSection], [updateTerrainSection],
  /// [mountFoliageLayer] and [addFoliageInstance] directly — the same GPU path
  /// the runtime build uses, rather than a second implementation.
  LuminaLandscapeComponent.editable({
    super.quadsPerSection,
    super.unitsPerMetre,
    super.foliageMeshScale,
    super.foliageChunkCapacity,
    super.residencyBudget,
    super.data,
    super.key,
    super.location,
    super.rotation,
    super.scale,
    super.isVisible,
  }) : super.editable();

  /// Tiles up to which a terrain simply mounts everything (a 513² terrain is
  /// 64 tiles / ~540 k triangles — cheaper to hold than to stream).
  static const int autoStreamTileThreshold = 64;

  /// The heightmap/foliage payload, once loaded.
  @override
  LandscapeData? get data => _data;

  /// The tile map the sections were built from.
  LandscapeSectionMap? get sectionMap => _sectionMap;

  /// The procedural mesh carrying the terrain tiles.
  LuminaProceduralMeshComponent? get terrainMesh => _terrain;

  /// Number of terrain tiles currently mounted.
  @override
  int get sectionCount => _terrain?.sectionCount ?? 0;

  /// Why the payload could not be read, when it could not.
  String? get loadError => _loadError;

  /// Why a foliage layer could not be mounted, when one could not.
  String? get foliageError => _foliageError;

  /// True once the terrain tiles have been created.
  bool get isTerrainBuilt => _terrainBuilt;

  /// The terrain's heightfield collider, once the payload is loaded.
  LuminaCollisionComponent? get collisionComponent => _collision;

  /// The instanced renderables carrying layer [layerIndex]'s foliage.
  List<LuminaInstancedStaticMeshComponent> foliageChunksOf(int layerIndex) =>
      List.unmodifiable(_batches[layerIndex]?.chunks ?? const <LuminaInstancedStaticMeshComponent>[]);

  /// Total renderables drawing foliage across every layer.
  int get foliageChunkCount => _batches.values.fold(0, (s, b) => s + b.chunks.length);

  /// Layer indices that currently have a mounted instance batch.
  Iterable<int> get mountedFoliageLayers => _batches.keys;

  /// Live instances mounted for layer [layerIndex].
  int foliageInstanceCount(int layerIndex) {
    final batch = _batches[layerIndex];
    if (batch == null) return _pendingInstances[layerIndex]?.length ?? 0;
    return batch.chunks.fold(0, (s, c) => s + c.instanceCount);
  }

  /// The transform a painted [instance] is drawn with in this component:
  /// see [foliageMatrix].
  @override
  Matrix4 foliageMatrixOf(FoliageInstance instance) =>
      foliageMatrix(instance, unitsPerMetre: unitsPerMetre, foliageMeshScale: foliageMeshScale);

  /// The one rule for a foliage instance's transform: its terrain-space
  /// position (metres) × [unitsPerMetre], and its mesh — a glTF, so metres —
  /// × [unitsPerMetre] (the asset unit scale) × [foliageMeshScale].
  ///
  /// In a centimetre world a 1.15 m barrel painted at scale 1 is 115 units
  /// tall; in the Landscape editor's metre-scaled preview it is 1.15.
  static Matrix4 foliageMatrix(
    FoliageInstance instance, {
    required double unitsPerMetre,
    double foliageMeshScale = 1.0,
  }) =>
      instance.toMatrix(unitsPerMetre: unitsPerMetre, meshScale: unitsPerMetre * foliageMeshScale);

  /// The transform of layer [layerIndex]'s [instanceIndex]-th instance, read
  /// back out of the GPU batch it actually lives in.
  Matrix4 foliageInstanceTransform(int layerIndex, int instanceIndex) {
    final batch = _batches[layerIndex];
    if (batch == null) throw StateError('foliage layer $layerIndex is not mounted');
    final capacity = _effectiveChunkCapacity();
    final chunk = instanceIndex ~/ capacity;
    if (chunk < 0 || chunk >= batch.chunks.length) {
      throw RangeError.index(instanceIndex, batch.chunks, 'instanceIndex', 'no such foliage instance');
    }
    return batch.chunks[chunk].instanceTransform(instanceIndex % capacity);
  }

  // --- Terrain queries ---------------------------------------------------------

  /// Terrain height (world units) under a world-space XZ position.
  ///
  /// This is the same bilinear sample the mesh vertices are built from, offset
  /// by the component's own world transform, so a pawn clamped to it stands
  /// exactly on the drawn surface.
  double sampleHeightAtWorld(double worldX, double worldZ) {
    final d = _data;
    if (d == null) return 0.0;
    final origin = worldLocation;
    final local = d.sampleHeight(
      (worldX - origin.x) / unitsPerMetre,
      (worldZ - origin.z) / unitsPerMetre,
    );
    return local * unitsPerMetre + origin.y;
  }

  /// Unit surface normal under a world-space XZ position.
  Vector3 sampleNormalAtWorld(double worldX, double worldZ) {
    final d = _data;
    if (d == null) return Vector3(0.0, 1.0, 0.0);
    final origin = worldLocation;
    return d.sampleNormal(
      (worldX - origin.x) / unitsPerMetre,
      (worldZ - origin.z) / unitsPerMetre,
    );
  }

  /// True when a world XZ position lies inside the terrain footprint.
  bool containsWorld(double worldX, double worldZ) {
    final d = _data;
    if (d == null) return false;
    final origin = worldLocation;
    return d.contains((worldX - origin.x) / unitsPerMetre, (worldZ - origin.z) / unitsPerMetre);
  }

  // --- Lifecycle ---------------------------------------------------------------

  @override
  void onRegister(LuminaActor ownerActor) {
    super.onRegister(ownerActor);
    if (ownerActor.world == null) return;
    if (_editable) return;
    if (_loadsFromBundle) {
      _foliageBuild ??= _loadBundledThenBuild();
      return;
    }
    _buildTerrain();
    _foliageBuild ??= _buildFoliage();
  }

  @override
  void onUnregister() {
    _dropCollision();
    _brushCursor = null;
    _cursorMesh?.onUnregister();
    _cursorMesh = null;
    _cursorMaterial?.dispose();
    _cursorMaterial = null;
    clearFoliage();
    _geometryCache.clear();
    _terrain?.onUnregister();
    _terrain = null;
    _terrainBuilt = false;
    _remeshedSections.clear();
    _residentLod.clear();
    _residentEdges.clear();
    _residentIndexCount.clear();
    _residentTriangles = 0;
    _terrainMaterial?.dispose();
    _terrainMaterial = null;
    _provider?.dispose();
    _provider = null;
    super.onUnregister();
  }

  /// Completes once the terrain tiles **and** every foliage layer are mounted.
  ///
  /// Foliage geometry is parsed from real mesh assets, which is asynchronous;
  /// terrain is synchronous. Callers that only need the terrain can ignore
  /// this.
  Future<void> ensureBuilt() async {
    _buildTerrain();
    _foliageBuild ??= _buildFoliage();
    await _foliageBuild;
  }

  /// Replaces the payload and rebuilds every tile and foliage layer from it.
  ///
  /// This is what the sub-editor calls when a terrain is opened or resized,
  /// and what a level uses to hot-swap a landscape asset.
  Future<void> mountPayload(LandscapeData payload) async {
    clearTerrain();
    clearFoliage();
    _data = payload;
    _terrainBuilt = false;
    _foliageBuild = null;
    await ensureBuilt();
  }

  /// Ensures the empty procedural mesh exists so the editor can push tiles
  /// into it. Returns null when there is no live native context.
  @override
  LuminaProceduralMeshComponent? ensureTerrainMesh() {
    if (_terrain != null) return _terrain;
    final ownerActor = owner;
    if (ownerActor == null) return null;
    final terrain = LuminaProceduralMeshComponent();
    terrain.attachToComponent(this);
    terrain.onRegister(ownerActor);
    _terrain = terrain;
    return terrain;
  }

  /// Uploads one whole terrain tile.
  ///
  /// The tile's tangent frame comes from its normals with an order-preserving
  /// builder ([terrainTangentAlgorithm]), so its vertex rows stay the
  /// heightmap's rows and later windowed uploads land where they should. Should
  /// the builder ever remesh a tile anyway, that is recorded here and reported
  /// by [supportsPartialUpdate].
  @override
  void createTerrainSection(
    int sectionIndex, {
    required Float32List positions,
    required Float32List normals,
    required Float32List uv0,
    required Uint8List colors,
    required Uint32List indices,
  }) {
    final terrain = ensureTerrainMesh();
    if (terrain == null) return;
    terrain.createMeshSection(
      sectionIndex,
      positions: positions,
      normals: normals,
      uv0: uv0,
      colors: colors,
      indices: indices,
      material: buildTerrainMaterial(),
      tangentAlgorithm: terrainTangentAlgorithm,
      dynamic: true,
      castShadows: true,
      receiveShadows: true,
    );
    _noteRemesh(terrain, sectionIndex);
    // A tile pushed in by the editor is resident at full detail; recording it
    // keeps the residency stats and the partial-update rule consistent between
    // the editor path and the payload-driven one.
    _residentLod[sectionIndex] = 1;
    _residentEdges[sectionIndex] = LandscapeEdgeSteps.none;
    _residentIndexCount[sectionIndex] = indices.length;
    final map = _sectionMap;
    if (map != null) {
      _residentTriangles += LandscapeResidency.triangleCountOf(map, sectionIndex, 1);
    }
  }

  /// Uploads one row-contiguous vertex window of an existing tile.
  ///
  /// [normals] re-derive the window's tangent frames (the lit terrain shades
  /// with them); [colors], when given, replace the window's albedo — pass the
  /// output of [LandscapeMeshBuilder.fillVertices] so a sculpted slope turns to
  /// rock where it steepens.
  @override
  void updateTerrainSection(
    SectionUpdateWindow window, {
    required Float32List positions,
    required Float32List normals,
    Uint8List? colors,
  }) {
    final terrain = _terrain;
    if (terrain == null || !terrain.hasSection(window.sectionIndex)) return;
    terrain.updateMeshSection(
      window.sectionIndex,
      positions: positions,
      normals: normals,
      colors: colors,
      vertexOffset: window.vertexOffset,
    );
  }

  /// Drops every terrain tile (the foliage batches are left alone).
  void clearTerrain() {
    _terrain?.clearAllMeshSections();
    _remeshedSections.clear();
    _residentLod.clear();
    _residentEdges.clear();
    _residentIndexCount.clear();
    _residentTriangles = 0;
    _tilesOutsideBudget = 0;
    _terrainBuilt = false;
  }

  // --- Terrain construction ----------------------------------------------------

  void _buildTerrain() {
    if (_terrainBuilt) return;
    final ownerActor = owner;
    if (ownerActor == null) return;
    final d = _loadData();
    if (d == null) return;

    final map = LandscapeSectionMap(gridResolution: d.gridResolution, quadsPerSection: quadsPerSection);
    _sectionMap = map;
    _ensureCollision(d);

    ensureTerrainMesh();
    // Mounting is residency-driven from the start: a small terrain's budget is
    // unlimited so everything lands, a large one only mounts what fits around
    // the camera. Tiles take an order-preserving tangent frame; a tile the
    // builder remeshed anyway is recorded so a later windowed
    // upload rebuilds the tile instead of writing the wrong rows.
    updateResidency(_residencyCamera);
    _terrainBuilt = true;
  }

  /// Creates (or re-points) the heightfield collider over [d] and registers
  /// it with the collision subsystem when there is one.
  ///
  /// The collider is a child of this component with the same relative scale
  /// (child scene components do not inherit scale), so it follows the placed
  /// Landscape actor's transform. It is registered with the subsystem
  /// directly rather than through `LuminaActor.addComponent`, which may not be
  /// called while the actor is registering its components — and because it
  /// is not in `actor.components`, a subsystem installed *after* the actor
  /// (Play-In-Editor and the generated game both install collision after
  /// mounting the level) cannot find it by scanning: the component
  /// registers again from [onBeginPlay] and, failing that, on its first tick.
  void _ensureCollision(LandscapeData d) {
    final ownerActor = owner;
    if (ownerActor == null) return;
    final existing = _collision;
    if (existing != null && existing.heightfield?.data == d) {
      existing.markCollisionDirty();
      return;
    }
    _dropCollision();
    final collision = LuminaCollisionComponent.heightfield(
      shape: HeightfieldShape(d, unitsPerMetre: unitsPerMetre),
      scale: relativeScale.clone(),
    );
    CollisionProfile.applyBlockAll(collision);
    collision.objectType = CollisionObjectType.worldStatic;
    collision.attachToComponent(this);
    collision.onRegister(ownerActor);
    _collision = collision;
    _collisionRegisteredWith = null;
    _registerCollision();
  }

  /// Registers the collider with the world's collision subsystem, once per
  /// subsystem: a no-op until the subsystem exists, and again after it is
  /// replaced.
  void _registerCollision() {
    final collision = _collision;
    if (collision == null) return;
    final subsystem = owner?.world?.subsystems.getSubsystem<LuminaCollisionSubsystem>();
    if (subsystem == null || identical(subsystem, _collisionRegisteredWith)) return;
    subsystem.register(collision);
    _collisionRegisteredWith = subsystem;
  }

  @override
  void onBeginPlay() {
    super.onBeginPlay();
    _registerCollision();
  }

  @override
  void onTick(double deltaTime) {
    super.onTick(deltaTime);
    if (_collision != null && _collisionRegisteredWith == null) _registerCollision();
  }

  void _dropCollision() {
    final collision = _collision;
    if (collision == null) return;
    _collisionRegisteredWith?.unregister(collision);
    _collisionRegisteredWith = null;
    collision.onUnregister();
    _collision = null;
  }

  /// True when tile [sectionIndex] can take a windowed vertex upload.
  ///
  /// A tile that does not exist yet can never take one — a fresh component
  /// after registration has no sections at all, and answering "yes" there
  /// silently drops every upload.
  bool supportsPartialUpdate(int sectionIndex) =>
      _terrain != null &&
      _terrain!.hasSection(sectionIndex) &&
      !_remeshedSections.contains(sectionIndex) &&
      // A decimated tile's vertex rows are not the heightmap's rows, so a
      // window computed in full-resolution rows would address the wrong ones.
      _residentLod[sectionIndex] == 1;

  /// How terrain tiles get their tangent frame: from the heightmap normals
  /// alone (Frisvad), which keeps every vertex where the heightmap put it.
  ///
  /// MIKKTSPACE (the default when `uv0` is present) welds a 65×65 grid back to
  /// the same vertex count **in a different order**; a sculpt's
  /// windowed upload into such a tile writes rows into the wrong vertices and
  /// cracks it. A heightfield has one normal per sample and no normal map, so
  /// a normals-only frame loses nothing.
  static const TsmAlgorithm terrainTangentAlgorithm = TsmAlgorithm.frisvad;

  /// Records whether the tangent builder remeshed tile [sectionIndex] — split
  /// or merely reordered its vertices — so windowed uploads skip it.
  @override
  void _noteRemesh(LuminaProceduralMeshComponent terrain, int sectionIndex) {
    if (terrain.isSectionRemeshed(sectionIndex)) {
      _remeshedSections.add(sectionIndex);
    } else {
      _remeshedSections.remove(sectionIndex);
    }
  }

  /// The material the terrain tiles are drawn with.
  ///
  /// Lit + vertex colours: the vertex colour is the albedo (a white base
  /// colour factor), shaded by the tiles' normals under the world's lights.
  @override
  FilamentMaterialInstance? buildTerrainMaterial() {
    if (_terrainMaterial != null) return _terrainMaterial;
    final w = owner?.world;
    if (w == null || !w.hasNativeContext) return null;
    try {
      _provider ??= FilamentMaterialProvider.ubershader(w.filamentEngine);
      final mi = _provider!
          .createMaterialInstance(
            MaterialKey(unlit: false, doubleSided: true, hasVertexColors: true),
            label: 'lumina_landscape_terrain',
          )
          .instance;
      if (mi == null) return null;
      mi.setFloat4('baseColorFactor', 1.0, 1.0, 1.0, 1.0);
      mi.setFloat('metallicFactor', 0.0);
      mi.setFloat('roughnessFactor', 0.95);
      mi.setCullingMode(CullingMode.none);
      _terrainMaterial = mi;
      return mi;
    } catch (e) {
      _loadError = 'terrain material unavailable: $e';
      return null;
    }
  }

  @override
  LandscapeData? _loadData() {
    if (_data != null) return _data;
    final path = assetPath;
    if (path == null) return null;
    // If the file exists directly on disk (running on desktop or locally),
    // load it synchronously so collision is ready immediately on frame 0.
    try {
      final file = File(path);
      if (file.existsSync()) {
        return _data = _decode(path, file.readAsBytesSync());
      }
    } catch (_) {
      // Fall through to bundle loading if disk read fails.
    }
    // A game reading from its bundle loads asynchronously (_loadBundledThenBuild).
    if (LuminaAssets.defaultProvider != null) return null;
    _loadError = 'landscape asset not found: $path';
    return null;
  }

  /// A shipped game has no file system: it reads the asset through
  /// [LuminaAssets.defaultProvider] (its asset bundle) before building.
  bool get _loadsFromBundle => _data == null && assetPath != null && LuminaAssets.defaultProvider != null;

  Future<void> _loadBundledThenBuild() async {
    final path = assetPath!;
    try {
      final d = _decode(path, await LuminaAssets.defaultProvider!(path));
      if (d != null) {
        if (d.samplesAreExternal) {
          final sidecarPath = LandscapeData.sidecarPathFor(path);
          try {
            final sidecarBytes = await LuminaAssets.defaultProvider!(sidecarPath);
            d.readSidecarBytes(sidecarBytes);
          } catch (_) {
            final localSidecar = File(sidecarPath);
            if (localSidecar.existsSync()) {
              d.readSidecar(localSidecar);
            }
          }
        }
        _data = d;
      }
    } catch (e) {
      _loadError = 'landscape asset "$path" could not be read: $e';
      return;
    }
    if (owner?.world == null) return;
    _buildTerrain();
    await _buildFoliage();
  }

  /// The heightmap in [bytes]: a `.lmas` payload or a raw landscape blob.
  LandscapeData? _decode(String path, Uint8List bytes) {
    if (path.toLowerCase().endsWith('.lmas')) {
      final payload = LuminaAsset.fromBytes(bytes).rawPayload;
      if (payload == null || payload.isEmpty) {
        _loadError = 'landscape asset "$path" carries no payload';
        return null;
      }
      bytes = payload;
    }
    final d = LandscapeData.fromBytes(bytes);
    if (d.samplesAreExternal) {
      try {
        final sidecar = File(LandscapeData.sidecarPathFor(path));
        if (sidecar.existsSync()) {
          d.readSidecar(sidecar);
        }
      } catch (_) {}
    }
    return d;
  }

  /// Real geometry of a foliage mesh asset (`.lmas` payload or raw `.glb`).
  static Future<_FoliageGeometry?> _loadFoliageGeometry(String path) async {
    try {
      var bytes = await LuminaAssets.resolve(null)(path);
      if (path.toLowerCase().endsWith('.lmas')) {
        final payload = LuminaAsset.fromBytes(bytes).rawPayload;
        if (payload == null || payload.isEmpty) return null;
        bytes = payload;
      }
      final parsed = await LuminaGlbLoader.parse(bytes);
      if (parsed == null || parsed.positions.isEmpty || parsed.indices.isEmpty) return null;
      return _FoliageGeometry.fromParsed(parsed.positions, parsed.indices, baseColor: parsed.baseColor);
    } catch (_) {
      return null;
    }
  }
}
