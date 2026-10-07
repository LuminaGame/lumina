part of '../sub_editor_3d_viewport.dart';

/// State shared by the sub-editor viewport's domain mixins: every instance
/// field (in the original order) and the members the mixins call on one another.
abstract class _SubEditor3DViewportStateBase extends State<SubEditor3DViewport> {

  late PreviewShape _shape;
  ViewportShadingMode _shadingMode = ViewportShadingMode.lit;
  final String _perspective = 'Perspective';

  double _viewportAspect = 16.0 / 9.0;
  // The pose Reset camera gives: 25° above the target, looking down. The
  // orbit treats pitch as elevation, so a negative start looked up from
  // under the floor.
  double _cameraYaw = -35.0;
  double _cameraPitch = 25.0;
  double _cameraDistance = 8.0;
  Offset _cameraPan = Offset.zero;

  bool _isDragging = false;

  /// True while a plain LMB press belongs to [SubEditor3DViewport.brushInput].
  bool _brushStroking = false;
  Offset? _tapDownPosition;
  int _tapDownButtons = 0;
  Size _viewportSize = Size.zero;

  FilamentEngine? _nativeEngine;
  FilamentCamera? _nativeCamera;
  FilamentScene? _nativeScene;
  /// This viewport's instances of the meshes its engine shares with every
  /// other viewport.
  ViewportMesh? _nativeAsset;
  final Map<String, ViewportMesh> _componentAssets = {};

  /// The socket preview meshes by socket name, with the `.lmas` each was
  /// loaded from and the joint it is parented to.
  final Map<String, ({String path, int joint, ViewportMesh mesh})> _socketAssets = {};

  /// Bumped whenever the socket attachments are torn down, so a load that
  /// lands afterwards is released instead of shown.
  int _socketGeneration = 0;

  /// Whether this viewport draws [SubEditor3DViewport.glbMesh] /
  /// `meshComponents` itself (not a preview world or a material preview).
  bool _drawsMeshes = false;

  /// Bumped when the native objects are freed or the components rebuilt, so
  /// a mesh load that lands afterwards is released instead of shown.
  int _meshGeneration = 0;

  /// The key, fill and rim lights of the studio rig, destroyed with the
  /// viewport: the engine is shared and would keep them.
  final List<int> _studioLights = [];

  /// This viewport's claim on the shared engine, released at the end of
  /// [State.dispose] — after the FilamentWidget child is gone — so nothing
  /// here is ever freed after its engine.
  FilamentEngineLease? _engineLease;
  FilamentWireframeMesh? _nativeWireframeMesh;
  FilamentWireframeMesh? _selectedNodeWireframe;

  /// The native lines of [SubEditor3DViewport.collisionLines], and the
  /// instance they were built from.
  FilamentWireframeMesh? _collisionWireframe;
  Object? _collisionLinesBuilt;

  /// The native lines of [SubEditor3DViewport.overlayLines] by set id, with
  /// the signature each was built from.
  final Map<String, (String, FilamentWireframeMesh)> _overlayWires = {};
  FilamentEditorGrid? _nativeGrid;
  final MaterialPreviewRenderer _materialPreview = MaterialPreviewRenderer();

  /// Sky + image-based lighting for this preview scene. Sub-editors keep the
  /// neutral editor backdrop (so the grid and gizmos stay readable) but must
  /// have a real IndirectLight, otherwise PBR meshes shade to black.
  final EditorSceneEnvironment _sceneEnvironment = EditorSceneEnvironment(
    showSkyBackground: false,
  );
  LuminaWorld? _previewWorld;

  double _targetCenterX = 0.0;
  double _targetCenterY = 0.0;
  double _targetCenterZ = 0.0;
  int _skipReadPixelsFrames = 25;
  Timer? _warmupTimer;

  // ---------------------------------------------------------------------------
  // Transform gizmo
  // ---------------------------------------------------------------------------

  /// Keyboard focus for the gizmo's Q/W/E/R and Esc; taken on pointer down.
  final FocusNode _viewportFocus = FocusNode(debugLabel: 'SubEditor3DViewport');

  /// The handle under the pointer, when not dragging.
  String? _gizmoHover;

  /// The drag in progress, the handle it holds and the target it started on.
  TransformGizmoDrag? _gizmoDrag;
  String? _gizmoDragHandle;
  SubEditorGizmoTarget? _gizmoDragTarget;

  /// A press on a locked target: no drag, only the hint banner.
  bool _gizmoDragLocked = false;

  /// The live delta banner (`ΔX +25.0 cm`), null when idle.
  String? _gizmoBanner;

  /// Whether the material preview's camera is still where
  /// [_materialFitDistance] put it (the user has not zoomed).
  bool _materialFramed = false;

  Map<String, double>? _appliedMorphWeights;

  /// Materials created for section overrides, kept so they outlive the frame and
  /// can be torn down with the widget.
  final Map<int, FilamentMaterial> _sectionMaterials = {};
  final Map<int, FilamentMaterialInstance> _sectionMaterialInstances = {};
  Map<int, Uint8List> _appliedSectionMaterials = const {};

  Map<String, List<double>>? _appliedJointDeltas;
  final Map<int, List<double>> _restEntityTransforms = {};
  final Set<int> _posedEntities = {};

  /// The native asset's entities by joint name, for [SubEditor3DViewport.jointLocalPose].
  final Map<String, List<int>> _jointEntities = {};

  // --- Implemented by the domain mixins or [_SubEditor3DViewportState]. ---

  bool get _nativeScale;

  bool get _isMaterialPreview;

  Vector3 _yUpTarget();

  double _materialFitDistance();

  void _updateSelectedNodeWireframe();

  void _updateCollisionLines({bool force = false});

  void _updateNodeVisibilities();

  void _applySectionMaterials({bool force = false});

  void _applyPreviewMaterialToSections();

  void _applyMorphWeights({bool force = false});

  void _applyJointTransforms({bool force = false});

  void _onPlaybackChanged();

  void _applyJointLocalPose();

  ViewportRay? _brushRay(Offset local);

  void _updateNativeCamera();
}
