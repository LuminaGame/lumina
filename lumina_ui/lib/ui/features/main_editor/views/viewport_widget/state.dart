part of '../viewport_widget.dart';

/// Native handles, input and gizmo state shared by the level viewport's
/// mixins.
abstract class _ViewportWidgetStateBase extends State<ViewportWidget> with TickerProviderStateMixin {
  double _viewportWidth = 800.0;
  double _viewportHeight = 600.0;
  final GlobalKey _viewportKey = GlobalKey();

  FilamentCamera? _nativeCamera;
  FilamentScene? _nativeScene;
  FilamentEngine? _nativeEngine;
  FilamentView? _nativeView;
  int _appliedQualityRevision = -1;

  /// The scale the gizmo is currently drawn at, so hover hit-testing can use
  /// the same size the user sees rather than a fixed world offset.
  double _gizmoScale = 1.0;
  /// The level's own light actors, as PIE builds them: the
  /// edit-mode scene has no light of its own.
  final EditorLevelLights _levelLights = EditorLevelLights();

  /// The level's environment actors — Exponential Height Fog, Post Process
  /// Volumes, Local Fog Volumes — realised as
  /// their runtime components in an editor world bound to this viewport's
  /// view, blended for the editor camera by lumina's post-process blender.
  final EditorLevelPostProcess _levelPostProcess = EditorLevelPostProcess();

  /// Volume outlines: a
  /// Post Process Volume's box always (bright selected, dim otherwise), a
  /// Local Fog Volume's sphere/box while selected. Keyed by actor id with
  /// the signature each was built from.
  final Map<String, (String, FilamentWireframeMesh)> _volumeWires = {};

  /// What each volume outline was drawn with: its colour alpha and its world
  /// half-extent (extent × actor scale, runtime axes).
  final Map<String, ({double alpha, Vector3 halfExtent})> _volumeWireState = {};

  /// This viewport's claim on the process's shared engine: the engine outlives [State.dispose], which
  /// runs after the FilamentWidget child is gone.
  FilamentEngineLease? _engineLease;

  /// Each mesh actor's instance of its engine-wide shared asset (lumina's
  /// mesh cache): a mesh placed twice, or also open in a sub-editor, is
  /// uploaded once.
  final Map<String, LuminaMeshHandle> _actorAssets = {};

  /// The payload each handle in [_actorAssets] was made from; a new payload
  /// (a re-import) replaces the instance.
  final Map<String, Uint8List> _actorPayloads = {};

  /// The material each mesh actor's instance draws in place of its own (the
  /// actor's assigned material), and the assignment it was last synced for
  /// (a path that could not be drawn stays there too, logged once).
  final Map<String, LuminaInstanceMaterialOverride> _actorMaterials = {};
  final Map<String, String?> _actorMaterialPaths = {};

  /// Actors whose mesh is loading; bumping [_meshGeneration] drops loads that
  /// land after the viewport's native objects were freed.
  final Set<String> _actorLoading = {};
  int _meshGeneration = 0;
  final Set<String> _visibleInScene = {};

  /// The level's sky background and image-based lighting, realised from the
  /// `Environment` (`Sky & Atmosphere`) actor. Filament takes a PBR surface's
  /// ambient diffuse *and all of its ambient specular* from the scene's
  /// IndirectLight, so a viewport without one renders imported meshes as black
  /// silhouettes.
  final EditorSceneEnvironment _sceneEnvironment = EditorSceneEnvironment();

  /// The level's Procedural Sky & Ocean, realised from the `ProceduralSky`
  /// actor. Independent of [_sceneEnvironment]: this draws the visible sky and
  /// lights nothing, that one supplies the image-based lighting. A level may
  /// carry either, both or neither.
  final EditorProceduralSky _proceduralSky = EditorProceduralSky();

  /// Ticker timestamp the procedural sky's day cycle is advanced from.
  Duration _lastSkyTickTime = Duration.zero;
  FilamentEditorGrid? _nativeGrid;
  double _lastGridStep = -1;
  double _lastGridExtent = -1;
  bool _lastGridVisible = true;
  final Map<String, FilamentSelectionBox> _selectionBoxes = {};

  /// Capsule wires of placed Character Blueprints.
  final Map<String, FilamentWireframeMesh> _capsuleWires = {};

  /// Light visualisers: a directional
  /// light's direction arrow (always, dimmer when unselected), a spot
  /// light's cone and a point light's attenuation sphere (while selected).
  /// Built in light-local runtime space and placed with the actor's own
  /// matrix, so the arrow is the exact direction `EditorLevelLights` gives
  /// Filament. Keyed by actor id, with the signature each was built from.
  final Map<String, (String, FilamentWireframeMesh)> _lightWires = {};

  /// The Wireframe view mode: every drawn mesh
  /// actor — static meshes, Blueprint meshes, a placed landscape's proxy
  /// tiles — as its triangle edges only, no filled surface, in the wireframe
  /// blue, or the selection colour while selected. One line mesh per actor
  /// from the actor's parsed `GlbMeshData` (its positions carry the node
  /// transforms, so the wire takes the same matrix as the solid root);
  /// the solid gltfio instance leaves the scene while the mode is on. Keyed
  /// by actor id with the mesh data and selection it was built from.
  final Map<String, (GlbMeshData, bool, FilamentWireframeMesh)> _meshWires = {};

  /// Actors whose mesh is too large for a wireframe, logged once each.
  final Set<String> _meshWiresSkipped = {};
  FilamentTransformGizmo? _nativeGizmo;
  String? _lastSelectedActorId;

  // Mouse buttons & interaction tracking
  bool _isRmbDown = false;
  bool _isLmbDown = false;
  bool _isMmbDown = false;
  Offset _downPos = Offset.zero;
  bool _hasMovedDuringDrag = false;

  // Active pressed keys for continuous WASD flight
  final Set<LogicalKeyboardKey> _pressedKeys = {};

  /// The view's keyboard focus. A click in the view takes it, so the fly keys,
  /// F and End work after typing somewhere else; the editor shell's shortcuts
  /// (EditorShortcutsScope) sit above it and get every key it lets through.
  final FocusNode _keyboardFocus = FocusNode(debugLabel: 'Viewport');
  late final Ticker _flyTicker;
  late final Ticker _pieTicker;
  int _lastPieTick = 0;
  Duration _lastTickTime = Duration.zero;

  // Render Throttle / ReadPixels Skip Counter
  int _skipReadPixelsFrames = 0;

  // Camera Speed HUD feedback toast
  bool _showSpeedBadge = false;
  Timer? _speedBadgeTimer;

  /// Guards [_syncPieSession] against the notifications that starting and
  /// stopping a session raise while it is still running.
  bool _syncingPie = false;

  bool _lastVmPlaying = false;
  bool _lastVmPaused = false;

  /// The editor camera pose (yaw, pitch, distance, pan) the Filament camera was
  /// last pointed through, or null when a Play session has aimed it since.
  (double, double, double, double, double, double)? _pushedCameraPose;

  /// The EV100 last pushed to the viewport camera.
  double? _appliedEv100;

  String? _hoveredGizmoAxis;

  /// The gizmo drag in progress (shared solvers).
  TransformGizmoDrag? _gizmoDragOp;
  Vector3 _dragStartActorLoc = Vector3.zero();
  Vector3 _dragStartActorRot = Vector3.zero();
  Vector3 _dragStartActorScale = Vector3.zero();

  String? _draggingGizmoAxis;
  Offset? _marqueeStart;
  Offset? _marqueeCurrent;
  Offset? _dropPreviewPos;
  RealAssetInfo? _dropPreviewAsset;

  // --- Implemented by the domain mixins or [_ViewportWidgetState]. ---

  bool get _wireframeMode;

  void _syncMeshWires();

  void _syncLightWires();

  void _syncCapsuleWires();

  void _syncPieSession();

  void _syncActorAssets();

  List<double> get _editorCameraEyeAuthoring;

  void _syncLevelPostProcess();

  bool get _pieOwnsTheScene;

  bool _editorActorDrawn(String actorId);

  bool get _pieCameraDrivesView;

  List<int> get editorLightEntitiesForTest;

  (double, double, double, double, double, double) get _editorCameraPose;

  void _updateNativeCamera();

  void _syncAutoExposure();

  _CameraMatrix _overlayCamera(Size viewportSize);
}
