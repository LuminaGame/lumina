part of '../anim_blueprint_editor_view_model.dart';

/// State shared by the [AnimBlueprintEditorViewModel] domain mixins: every
/// instance field (in the original order, so initialisers run in the same
/// order) and the members the mixins call on one another.
abstract class _AnimBlueprintEditorViewModelState extends ChangeNotifier implements BlueprintGraphHost {
  /// The `.lmas` file (absolute, or relative to the working directory).
  final String assetPath;
  late final String? projectDir = AnimGraphAssetService.projectDirOf(assetPath);

  LuminaAnimBlueprintDocument _document = LuminaAnimBlueprintDocument();
  String _onDiskJson = '';
  final TransactionManager transactions = TransactionManager();
  String? _interactionBefore;
  String? _interactionLabel;
  int _revision = 0;

  List<String> _clips = const [];
  List<String> _blendSpacePaths = const [];
  final Map<String, LuminaBlendSpaceDocument> _blendSpaces = {};

  AnimGraphLocation _location = const AnimGraphLocation.animGraph();
  String? _selectedState;
  String? _selectedTransition;
  String? _selectedVariable;

  BlueprintCompileStatus _compileStatus = BlueprintCompileStatus.unknown;
  List<AnimCompileRow> _rows = const [];
  String _generatedCode = '';

  /// The preview: the Blueprint running on its target mesh.
  final AnimPreviewScene preview = AnimPreviewScene();
  double _ownerSpeed = 0.0;
  double _ownerDirection = 0.0;
  bool _ownerFalling = false;
  final Map<String, Object?> _overrides = {};
  int _previewRevision = -1;
  Set<String> _previewOverrideKeys = const {};
  String? _previewError;
  String? _lastPreviewState;
  String? _lastPreviewClip;

  late final BlueprintGraphEditor eventGraph = BlueprintGraphEditor(
    host: this,
    graphSource: () => _document.eventGraph,
    nodeFilter: AnimBlueprintEditorViewModel._eventGraphAccepts,
    diagnosticsSource: () => [
      for (final r in _rows)
        if (r.location?.view == AnimGraphView.eventGraph) r.diagnostic,
    ],
  );
  final Map<String, BlueprintGraphEditor> _ruleEditors = {};

  _AnimBlueprintEditorViewModelState({required this.assetPath}) {
    preview.beforeTick = _beforePreviewTick;
    preview.afterTick = _afterPreviewTick;
  }

  List<RealAssetInfo>? _projectAssetsCache;
  int _projectAssetsRevision = -1;

  /// Bumped whenever the target mesh (and so the clip list) is reloaded.
  int _targetMeshRevision = 0;

  bool _isRetargeting = false;

  // --- Implemented by the domain mixins or [AnimBlueprintEditorViewModel]. ---

  String get name;

  String get relativePath;

  LuminaAnimBlueprintDocument get document;

  String get targetMesh;

  List<String> get clips;

  LuminaAnimStateMachine? get machine;

  AnimGraphLocation get location;

  void _reloadBlendSpaces();

  Map<String, LuminaBlendSpaceDocument> get stateBlendSpaces;

  String _snapshot();

  void open(AnimGraphLocation location);

  LuminaAnimTransition? transition(String id);

  BlueprintGraphEditor ruleEditor(String id);

  void _beforePreviewTick(double dt);

  void _afterPreviewTick();
}
