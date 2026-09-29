part of '../landscape_component.dart';

/// State shared by the [LuminaLandscapeComponent] domain mixins: every
/// instance field (in the original order, so initialisers run in the same
/// order) and the members the mixins call on one another.
abstract class _LuminaLandscapeComponentState extends LuminaSceneComponent {
  /// The `.lmas` this terrain was authored in, when it was loaded from disk.
  final String? assetPath;

  /// Quads per terrain tile along each axis (the section granularity).
  final int quadsPerSection;

  /// Preview/world units per terrain metre.
  final double unitsPerMetre;

  /// An extra correction on top of the asset unit scale, default 1.0.
  ///
  /// Foliage meshes are glTF, i.e. metres, so every
  /// instance is drawn × [unitsPerMetre] — the same asset unit scale a static
  /// mesh component applies — and then × this factor. It is not a unit
  /// conversion; leave it at 1.0 unless a project's foliage GLBs really are
  /// authored at another scale. See [LuminaLandscapeComponent.foliageMatrix].
  final double foliageMeshScale;

  /// Instances per foliage renderable. Defaults to the engine's real
  /// `maxAutomaticInstances`, which is the only honest value.
  final int? foliageChunkCapacity;

  /// What may be mounted at once.
  ///
  /// Null means "decide from the terrain's size": a terrain of at most
  /// [LuminaLandscapeComponent.autoStreamTileThreshold] tiles mounts whole, anything larger streams
  /// against [LandscapeResidencyBudget]'s defaults. At 8129² the terrain is
  /// 16 129 tiles and ~68 M vertices, so mounting it whole is not an option
  /// that exists.
  final LandscapeResidencyBudget? residencyBudget;

  LandscapeData? _data;
  LandscapeSectionMap? _sectionMap;
  LuminaProceduralMeshComponent? _terrain;

  final Map<int, _FoliageBatch> _batches = {};
  final Map<String, _FoliageGeometry?> _geometryCache = {};

  /// Instances painted while a layer's mesh asset is still being parsed.
  final Map<int, List<Matrix4>> _pendingInstances = {};
  FilamentMaterialProvider? _provider;
  FilamentMaterialInstance? _terrainMaterial;

  /// Tiles the tangent generator remeshed (split or reordered) — windowed uploads into
  /// these would write the wrong rows, so they must be rebuilt whole.
  final Set<int> _remeshedSections = {};

  final bool _editable;
  bool _terrainBuilt = false;

  /// Tile index → mounted LOD step, and the neighbour steps it was stitched
  /// against (a tile must be rebuilt when either changes).
  final Map<int, int> _residentLod = {};
  final Map<int, LandscapeEdgeSteps> _residentEdges = {};
  final Map<int, int> _residentIndexCount = {};
  int _residentTriangles = 0;
  int _tilesOutsideBudget = 0;
  Vector3 _residencyCamera = Vector3.zero();
  Future<void>? _foliageBuild;
  String? _loadError;
  String? _foliageError;

  LuminaProceduralMeshComponent? _cursorMesh;
  FilamentMaterialInstance? _cursorMaterial;
  LandscapeBrushCursor? _brushCursor;

  LuminaCollisionComponent? _collision;
  LuminaCollisionSubsystem? _collisionRegisteredWith;

  _LuminaLandscapeComponentState({
    LandscapeData? data,
    this.assetPath,
    this.quadsPerSection = 64,
    this.unitsPerMetre = LuminaUnits.unitsPerMetre,
    this.foliageMeshScale = 1.0,
    this.foliageChunkCapacity,
    this.residencyBudget,
    super.key,
    super.location,
    super.rotation,
    super.scale,
    super.isVisible,
  })  : _data = data,
        _editable = false {
    if (data == null && (assetPath == null || assetPath!.isEmpty)) {
      throw ArgumentError('LuminaLandscapeComponent needs either a payload or an assetPath');
    }
  }

  /// A terrain the editor fills in itself.
  ///
  /// The Landscape sub-editor owns a live heightmap and streams tile rebuilds
  /// and painted foliage as the user sculpts, so it mounts an empty component
  /// and drives [createTerrainSection], [updateTerrainSection],
  /// [mountFoliageLayer] and [addFoliageInstance] directly — the same GPU path
  /// the runtime build uses, rather than a second implementation.
  _LuminaLandscapeComponentState.editable({
    this.quadsPerSection = 64,
    this.unitsPerMetre = LuminaUnits.unitsPerMetre,
    this.foliageMeshScale = 1.0,
    this.foliageChunkCapacity,
    this.residencyBudget,
    LandscapeData? data,
    super.key,
    super.location,
    super.rotation,
    super.scale,
    super.isVisible,
  })  : assetPath = null,
        // ignore: prefer_initializing_formals
        _data = data,
        _editable = true;

  // --- Implemented by the domain mixins or [LuminaLandscapeComponent]. ---

  LandscapeData? get data;

  int get sectionCount;

  Matrix4 foliageMatrixOf(FoliageInstance instance);

  LuminaProceduralMeshComponent? ensureTerrainMesh();

  void createTerrainSection(
    int sectionIndex, {
    required Float32List positions,
    required Float32List normals,
    required Float32List uv0,
    required Uint8List colors,
    required Uint32List indices,
  });

  void updateTerrainSection(
    SectionUpdateWindow window, {
    required Float32List positions,
    required Float32List normals,
    Uint8List? colors,
  });

  void _noteRemesh(LuminaProceduralMeshComponent terrain, int sectionIndex);

  FilamentMaterialInstance? buildTerrainMaterial();

  LandscapeData? _loadData();

  Aabb3 get terrainBounds;

  Future<void> mountFoliageLayer(int layerIndex, {required String meshAssetPath});

  int addFoliageInstance(int layerIndex, Matrix4 transform);
}
