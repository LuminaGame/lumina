// Named parameters cannot be private, so the settings fields are assigned
// in the initializer list.
// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_filament/filament.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:vector_math/vector_math_64.dart';

import 'package:lumina/src/assets/glb_loader.dart';
import 'package:lumina/src/components/mesh/procedural_mesh_component.dart';
import 'package:lumina/src/object/actor.dart';
import 'package:lumina/src/physics/cloth/cloth_geometry.dart';
import 'package:lumina/src/physics/cloth/cloth_material.dart';
import 'package:lumina/src/physics/cloth/cloth_properties.dart';
import 'package:lumina/src/physics/physics_subsystem.dart';
import 'package:lumina/src/utility/lumina_assets.dart';
import 'package:lumina/src/world/world.dart';

export 'package:lumina/src/physics/cloth/cloth_geometry.dart' show LuminaClothGeometry, LuminaClothPinning;

/// Cloth: a sheet or a mesh asset simulated as a soft body (flags, curtains,
/// banners, loose cloth draped over things).
///
/// - **Shape**: [meshAsset] (a static mesh `.glb`; its vertices are welded at
///   UV seams for the simulation) or, without one, a [gridWidth] x
///   [gridHeight] cm sheet of [gridColumns] x [gridRows] quads in the local
///   XY plane, facing +Z, hanging from its top edge at the component origin.
/// - **Pins**: [pinning] (an edge or the top corners) and [pinnedVertices]
///   (simulation vertex indices) stay where the component puts them: attach
///   the component to a moving parent (a body, a bone socket) and the pinned
///   vertices follow it, dragging the cloth.
/// - **Material**: [stiffness] (stretch, 0..1), [bendStiffness] (0..1),
///   [massKg] (the whole cloth), [damping], [friction], [thickness] (cm, the
///   distance it keeps from surfaces), [iterations], [gravityScale].
/// - **Look**: [color] (linear), [baseColorTexture] (a texture asset or
///   image on the cloth's UVs, tinted by the colour) or [materialAsset] (a
///   project material drawn instead), [castShadows].
/// - **Self-collision**: with [selfCollision] the cloth keeps
///   [selfCollisionDistance] cm between its own layers (a fold, a sheet
///   falling on itself).
/// - **Wind**: [wind] (cm/s, runtime axes) pulls the cloth at [windDrag] per
///   second, its strength varying by [windTurbulence] (0..1) over time.
/// - **Motion**: [inertiaScale] (0..1) is how much of its owner's motion
///   the cloth resists: 1 keeps all of its inertia in the world (it lags and
///   swings when the owner moves or turns), 0 moves it rigidly with the
///   owner. A move of more than [teleportDistance] cm or a turn of more than
///   [teleportRotation] degrees within one step is a teleport: the cloth is
///   carried along whole (a garment is put back on its body).
/// - **Collision**: with every body and collider of the world's physics (the
///   level, simulating props, a character's capsule).
///
/// Cloth needs the Jolt physics backend (native desktop). With the Dart
/// backend (the web, a build without Jolt) the component draws its rest pose
/// and logs once that cloth is not simulated.
class LuminaClothComponent extends LuminaProceduralMeshComponent {
  LuminaClothComponent({
    super.key,
    super.location,
    super.rotation,
    super.scale,
    this.meshAsset,
    this.gridWidth = 200,
    this.gridHeight = 150,
    this.gridColumns = 24,
    this.gridRows = 18,
    LuminaClothPinning pinning = LuminaClothPinning.topEdge,
    List<int> pinnedVertices = const [],
    double massKg = 1.0,
    double stiffness = 0.95,
    double bendStiffness = 0.3,
    double damping = 0.5,
    double friction = 0.5,
    double thickness = 1.0,
    int iterations = 8,
    double gravityScale = 1.0,
    Vector3? wind,
    this.windDrag = 1.0,
    this.windTurbulence = 0.3,
    this.inertiaScale = 1.0,
    this.teleportDistance = 100,
    this.teleportRotation = 60,
    bool selfCollision = false,
    double selfCollisionDistance = 2.0,
    bool simulate = true,
    Vector3? color,
    this.baseColorTexture,
    this.materialAsset,
    this.castShadows = true,
    this.assetProvider,
  }) : _pinning = pinning,
       _selfCollision = selfCollision,
       _selfCollisionDistance = selfCollisionDistance,
       _pinnedVertices = List.of(pinnedVertices),
       _massKg = massKg,
       _stiffness = stiffness,
       _bendStiffness = bendStiffness,
       _damping = damping,
       _friction = friction,
       _thickness = thickness,
       _iterations = iterations,
       _gravityScale = gravityScale,
       _simulate = simulate,
       wind = wind ?? Vector3.zero(),
       color = color ?? Vector3(0.75, 0.12, 0.1);

  /// A static mesh `.glb` whose triangles are the cloth; null for a grid.
  final String? meshAsset;
  final double gridWidth;
  final double gridHeight;
  final int gridColumns;
  final int gridRows;

  /// Where [meshAsset] is read from (null: [LuminaAssets.defaultProvider]).
  final LuminaAssetProvider? assetProvider;

  /// Wind velocity (cm/s, runtime axes), its pull per second and gustiness.
  Vector3 wind;
  double windDrag;
  double windTurbulence;

  /// How much of the owner's motion the cloth resists (0..1), and the move
  /// (cm) or turn (degrees) within one step that counts as a teleport.
  double inertiaScale;
  double teleportDistance;
  double teleportRotation;

  /// Base colour (linear 0..1; it tints [baseColorTexture]), and whether the
  /// cloth casts shadows.
  Vector3 color;
  final bool castShadows;

  /// A texture asset (`.lmas`) or image drawn on the cloth's UVs, and a
  /// project material asset drawn instead of the built-in material.
  final String? baseColorTexture;
  final String? materialAsset;

  LuminaClothPinning _pinning;
  List<int> _pinnedVertices;
  double _massKg, _stiffness, _bendStiffness, _damping, _friction, _thickness, _gravityScale;
  int _iterations;
  bool _simulate, _selfCollision;
  double _selfCollisionDistance;

  LuminaClothGeometry? _geometry;
  Future<void>? _loading;
  final Completer<void> _ready = Completer<void>();
  Float32List? _simPositions, _simNormals, _renderPositions, _renderNormals;
  late final LuminaClothMaterial _look = LuminaClothMaterial(
    materialAsset: materialAsset,
    baseColorTexture: baseColorTexture,
    assetProvider: assetProvider,
  );
  Future<void>? _lookLoading;
  final Completer<void> _lookDone = Completer<void>();
  LuminaPhysicsSubsystem? _physics;
  bool _warned = false;

  /// Increases whenever a setting the simulation is built from changes.
  int settingsVersion = 0;

  /// The geometry once built (rest pose, local cm).
  LuminaClothGeometry? get geometry => _geometry;

  /// Completes when the geometry is built and the cloth draws.
  Future<void> get ready => _ready.future;

  /// Whether a physics backend simulates the cloth now.
  bool get isSimulating {
    final physics = _physics;
    return physics != null && (physics.backend.cloth?.contains(this) ?? false);
  }

  LuminaClothPinning get pinning => _pinning;
  set pinning(LuminaClothPinning v) => _change(() => _pinning = v);
  List<int> get pinnedVertices => List.unmodifiable(_pinnedVertices);
  set pinnedVertices(List<int> v) => _change(() => _pinnedVertices = List.of(v));
  double get massKg => _massKg;
  set massKg(double v) => _change(() => _massKg = math.max(v, 1e-3));
  double get stiffness => _stiffness;
  set stiffness(double v) => _change(() => _stiffness = v.clamp(0.0, 1.0));
  double get bendStiffness => _bendStiffness;
  set bendStiffness(double v) => _change(() => _bendStiffness = v.clamp(0.0, 1.0));
  double get damping => _damping;
  set damping(double v) => _change(() => _damping = math.max(v, 0.0));
  double get friction => _friction;
  set friction(double v) => _change(() => _friction = math.max(v, 0.0));
  double get thickness => _thickness;
  set thickness(double v) => _change(() => _thickness = math.max(v, 0.0));
  int get iterations => _iterations;
  set iterations(int v) => _change(() => _iterations = v.clamp(1, 64));
  double get gravityScale => _gravityScale;
  set gravityScale(double v) => _change(() => _gravityScale = v);
  bool get selfCollision => _selfCollision;
  set selfCollision(bool v) => _change(() => _selfCollision = v);
  double get selfCollisionDistance => _selfCollisionDistance;
  set selfCollisionDistance(double v) => _change(() => _selfCollisionDistance = math.max(v, 0.1));

  /// The material instance the cloth is drawn with now (null before it
  /// draws).
  FilamentMaterialInstance? get drawnMaterial => _look.current;

  /// Whether [baseColorTexture] or [materialAsset] is drawn (loaded).
  bool get drawsLook => _look.isLoaded;

  /// Completes when [baseColorTexture] or [materialAsset] is drawn (or could
  /// not be loaded) once the cloth draws in a world; at once without either.
  Future<void> get lookReady =>
      (materialAsset ?? '').isEmpty && (baseColorTexture ?? '').isEmpty ? Future.value() : _lookDone.future;

  /// Turning simulation off draws the rest pose; on starts from it.
  bool get simulate => _simulate;
  set simulate(bool v) {
    if (v == _simulate) return;
    _simulate = v;
    _syncSimulation();
  }

  void _change(void Function() apply) {
    apply();
    settingsVersion++;
    final sim = _physics?.backend.cloth;
    if (sim != null && sim.contains(this)) sim.rebuild(this);
  }

  /// Simulation vertices pinned by [pinning] and [pinnedVertices].
  List<int> resolvePinnedVertices() {
    final g = _geometry;
    if (g == null) return const [];
    final set = <int>{...g.pinnedBy(_pinning, tolerance: math.max(0.5, _pinTolerance(g))), ..._pinnedVertices}
      ..removeWhere((i) => i < 0 || i >= g.simVertexCount);
    return set.toList()..sort();
  }

  static double _pinTolerance(LuminaClothGeometry g) {
    final b = g.bounds;
    final size = b.max - b.min;
    return math.max(size.x, math.max(size.y, size.z)) * 0.005;
  }

  /// Pins simulation vertex [vertex] where it is now ([pinned]) or frees it;
  /// the simulation keeps running (no rebuild). Saved with [pinnedVertices].
  void pinVertex(int vertex, {bool pinned = true}) {
    final g = _geometry;
    if (vertex < 0 || (g != null && vertex >= g.simVertexCount)) return;
    if (pinned && !_pinnedVertices.contains(vertex)) {
      _pinnedVertices.add(vertex);
    } else if (!pinned) {
      _pinnedVertices.remove(vertex);
    }
    final sim = _physics?.backend.cloth;
    if (sim != null && sim.contains(this)) sim.setPinned(this, vertex, pinned);
  }

  /// Moves the cloth back to its rest pose (pins where the component is).
  void reset() {
    final sim = _physics?.backend.cloth;
    if (sim != null && sim.contains(this)) sim.rebuild(this);
    _drawRest();
  }

  // --- Lifecycle ------------------------------------------------------------------

  @override
  void onRegister(LuminaActor ownerActor) {
    super.onRegister(ownerActor);
    _loading ??= _build();
  }

  Future<void> _build() async {
    try {
      // A grid builds at once, so a cloth registered with a running world
      // simulates from its first frame (Blueprint BeginPlay sees it).
      final built = buildClothGeometry();
      final geometry = built is Future<LuminaClothGeometry> ? await built : built;
      if (owner == null) return;
      _geometry = geometry;
      _createSection(geometry);
      _attachPhysics();
      if (!_ready.isCompleted) _ready.complete();
    } catch (e, st) {
      EngineLoggerService().log('Cloth: could not build "${meshAsset ?? 'grid'}": $e', level: 'error', source: 'Cloth');
      if (!_ready.isCompleted) _ready.completeError(e, st);
    }
  }

  @override
  void onBeginPlay() {
    super.onBeginPlay();
    _attachPhysics();
  }

  /// Joins the world's physics once both the geometry and the world exist
  /// (whichever comes last: the build, or begin play).
  void _attachPhysics() {
    if (_physics != null || _geometry == null) return;
    final world = owner?.world;
    if (world == null) return;
    _physics = LuminaPhysicsSubsystem.ensure(world);
    _physics?.addCloth(this);
    _syncSimulation();
  }

  /// The cloth's rest geometry in its local frame (cm): the grid, or
  /// [meshAsset] parsed and welded on a worker isolate.
  FutureOr<LuminaClothGeometry> buildClothGeometry() {
    final asset = meshAsset;
    if (asset == null || asset.isEmpty) {
      return LuminaClothGeometry.grid(width: gridWidth, height: gridHeight, columns: gridColumns, rows: gridRows);
    }
    return _loadMesh(asset);
  }

  Future<LuminaClothGeometry> _loadMesh(String path) async {
    final bytes = await LuminaAssets.resolve(assetProvider)(path);
    try {
      return await Isolate.run(() async {
        // Draco-compressed meshes decode with the engine's native decoder,
        // which runs on this worker isolate too.
        final mesh = await GlbReader.parse(bytes, decoders: GlbDecoders(draco: LuminaGlbLoader.decoders.draco));
        if (mesh == null) throw StateError('not a readable GLB');
        return LuminaClothGeometry.fromMesh(mesh);
      }, debugName: 'cloth mesh');
    } on UnsupportedError {
      // No isolates (the web): parse here.
      final mesh = await LuminaGlbLoader.parse(bytes);
      if (mesh == null) throw StateError('not a readable GLB');
      return LuminaClothGeometry.fromMesh(mesh);
    }
  }

  void _createSection(LuminaClothGeometry g) {
    _renderPositions = Float32List.fromList(g.renderPositions);
    _renderNormals = Float32List.fromList(g.renderNormals);
    _simPositions = Float32List(g.simVertexCount * 3);
    _simNormals = Float32List(g.simVertexCount * 3);
    createMeshSection(
      0,
      positions: _renderPositions!,
      normals: _renderNormals!,
      uv0: g.renderUvs,
      // The lit ubershader multiplies the base colour by vertex colours.
      colors: Uint8List(g.renderVertexCount * 4)..fillRange(0, g.renderVertexCount * 4, 255),
      indices: g.renderIndices,
      material: _createMaterial(),
      tangentAlgorithm: TsmAlgorithm.frisvad,
      dynamic: true,
      castShadows: castShadows,
      receiveShadows: true,
    );
  }

  FilamentMaterialInstance? _createMaterial() {
    final world = owner?.world;
    if (world == null || !world.hasNativeContext) return null;
    final mi = _look.create(world, color);
    if ((materialAsset ?? '').isNotEmpty || (baseColorTexture ?? '').isNotEmpty) {
      _lookLoading ??= _look
          .load(world, color, (loaded) {
            if (hasSection(0)) setSectionMaterial(0, loaded);
          })
          .whenComplete(() {
            if (!_lookDone.isCompleted) _lookDone.complete();
          });
    }
    return mi;
  }

  void _syncSimulation() {
    final physics = _physics;
    if (physics == null || _geometry == null) return;
    final sim = physics.backend.cloth;
    if (sim == null) {
      if (_simulate && !_warned) {
        _warned = true;
        EngineLoggerService().log(
          'Cloth needs the Jolt physics backend; this cloth draws its rest pose '
          '(physics backend: ${physics.backend.name}).',
          level: 'warning',
          source: 'Cloth',
        );
      }
      return;
    }
    if (_simulate && !sim.contains(this)) {
      sim.add(this);
    } else if (!_simulate && sim.contains(this)) {
      sim.remove(this);
      _drawRest();
    }
  }

  /// Draws the simulated pose (or the rest pose when not simulated).
  @override
  void onRenderPrep(LuminaWorld world) {
    // A section built before the world had its renderer (the component was
    // registered before the level was mounted) has no entity yet.
    final built = _geometry;
    if (built != null && world.hasNativeContext && (!hasSection(0) || sectionEntity(0) == 0)) {
      if (hasSection(0)) clearMeshSection(0);
      _createSection(built);
    }
    final g = _geometry, sp = _simPositions, sn = _simNormals, rp = _renderPositions, rn = _renderNormals;
    final sim = _physics?.backend.cloth;
    if (g != null && sp != null && sn != null && rp != null && rn != null && sim != null && sim.read(this, sp, sn)) {
      final map = g.renderToSim;
      for (var i = 0; i < map.length; i++) {
        final s = map[i] * 3;
        rp[3 * i] = sp[s];
        rp[3 * i + 1] = sp[s + 1];
        rp[3 * i + 2] = sp[s + 2];
        rn[3 * i] = sn[s];
        rn[3 * i + 1] = sn[s + 1];
        rn[3 * i + 2] = sn[s + 2];
      }
      if (hasSection(0)) updateMeshSection(0, positions: rp, normals: rn);
    }
    super.onRenderPrep(world);
  }

  void _drawRest() {
    final g = _geometry;
    if (g == null || !hasSection(0)) return;
    _renderPositions!.setAll(0, g.renderPositions);
    _renderNormals!.setAll(0, g.renderNormals);
    updateMeshSection(0, positions: _renderPositions, normals: _renderNormals);
  }

  /// The simulated pose in local cm, one vertex per simulation vertex (the
  /// rest pose when not simulated).
  Float32List currentSimPositions() {
    final g = _geometry;
    if (g == null) return Float32List(0);
    final out = Float32List(g.simVertexCount * 3);
    final normals = Float32List(g.simVertexCount * 3);
    final sim = _physics?.backend.cloth;
    if (sim == null || !sim.read(this, out, normals)) out.setAll(0, g.simPositions);
    return out;
  }

  @override
  void onUnregister() {
    _physics?.removeCloth(this);
    _physics = null;
    clearAllMeshSections();
    _look.dispose();
    super.onUnregister();
  }

  // --- Properties -------------------------------------------------------------------

  /// A cloth from Blueprint / level properties (authoring axes for [wind]).
  factory LuminaClothComponent.fromProperties(Map<String, dynamic> p, {LuminaAssetProvider? assetProvider}) {
    final r = LuminaClothPropertyReader(p);
    return LuminaClothComponent(
      meshAsset: r.text('meshAsset'),
      gridWidth: r.number('gridWidth', 200),
      gridHeight: r.number('gridHeight', 150),
      gridColumns: r.integer('gridColumns', 24),
      gridRows: r.integer('gridRows', 18),
      pinning: LuminaClothPinning.parse(p['pinning']) ?? LuminaClothPinning.topEdge,
      pinnedVertices: r.integers('pinnedVertices'),
      massKg: r.number('massKg', 1.0),
      stiffness: r.number('stiffness', 0.95),
      bendStiffness: r.number('bendStiffness', 0.3),
      damping: r.number('damping', 0.5),
      friction: r.number('friction', 0.5),
      thickness: r.number('thickness', 1.0),
      iterations: r.integer('iterations', 8),
      gravityScale: r.number('gravityScale', 1.0),
      wind: r.wind,
      windDrag: r.number('windDrag', 1.0),
      windTurbulence: r.number('windTurbulence', 0.3),
      inertiaScale: r.number('inertiaScale', 1.0),
      teleportDistance: r.number('teleportDistance', 100),
      teleportRotation: r.number('teleportRotation', 60),
      selfCollision: r.flag('selfCollision', false),
      selfCollisionDistance: r.number('selfCollisionDistance', 2.0),
      simulate: r.flag('simulate', true),
      color: r.color,
      baseColorTexture: r.text('baseColorTexture'),
      materialAsset: r.text('materialAsset'),
      castShadows: r.flag('castShadows', true),
      assetProvider: assetProvider,
    );
  }

  /// The properties [LuminaClothComponent.fromProperties] reads.
  Map<String, Object?> toProperties() => {
    if (meshAsset != null) 'meshAsset': meshAsset,
    'gridWidth': gridWidth,
    'gridHeight': gridHeight,
    'gridColumns': gridColumns,
    'gridRows': gridRows,
    'pinning': _pinning.name,
    if (_pinnedVertices.isNotEmpty) 'pinnedVertices': List.of(_pinnedVertices),
    ...materialProperties(),
  };

  /// The material, wind, motion and drawing properties every cloth shares.
  Map<String, Object?> materialProperties() => {
    'massKg': _massKg,
    'stiffness': _stiffness,
    'bendStiffness': _bendStiffness,
    'damping': _damping,
    'friction': _friction,
    'thickness': _thickness,
    'iterations': _iterations,
    'gravityScale': _gravityScale,
    'wind': LuminaAxes.toAuthoringLocation(wind),
    'windDrag': windDrag,
    'windTurbulence': windTurbulence,
    'inertiaScale': inertiaScale,
    'teleportDistance': teleportDistance,
    'teleportRotation': teleportRotation,
    'selfCollision': _selfCollision,
    'selfCollisionDistance': _selfCollisionDistance,
    'simulate': _simulate,
    'color': [color.x, color.y, color.z],
    if (baseColorTexture != null) 'baseColorTexture': baseColorTexture,
    if (materialAsset != null) 'materialAsset': materialAsset,
    'castShadows': castShadows,
  };
}
