part of '../blueprint_editor_view_model.dart';

/// State shared by the [BlueprintEditorViewModel] domain mixins: every
/// instance field (in the original order, so initialisers run in the same
/// order) and the members the mixins call on one another.
abstract class _BlueprintEditorViewModelState extends ChangeNotifier implements BlueprintGraphHost {
  final String assetPath;
  LuminaAsset? _asset;
  late LuminaBlueprintDocument _document;
  String _onDiskJson = '';
  String? _selectedComponentId;
  String? _selectedVariable;

  /// Undo / redo for every document edit.
  final TransactionManager transactions = TransactionManager();
  String? _interactionBefore;
  String? _interactionLabel;

  List<LuminaInputAction> _inputActions = const [];
  BlueprintCompileStatus _compileStatus = BlueprintCompileStatus.unknown;
  List<LuminaBlueprintDiagnostic> _diagnostics = const [];
  int _revision = 0;
  (int, String)? _codeCache;

  /// The event graph as the canvas edits it.
  late final BlueprintGraphEditor eventGraph = BlueprintGraphEditor(
    host: this,
    graphSource: () => _document.eventGraph,
    diagnosticsSource: () => _diagnostics,
    pinOptionsProvider: assetPinOptions,
    pinnedEntriesSource: pinnedPaletteEntries,
  );

  /// Function and macro graph editors by [BlueprintGraphRef.key]; made on
  /// first use, dropped with their graph.
  final Map<String, BlueprintGraphEditor> _graphEditors = {};
  BlueprintGraphRef _activeGraph = BlueprintGraphRef.eventGraph;

  /// The project's enum / interface assets and pickable asset paths; null without a project directory.
  BlueprintAssetCatalog? _assets;
  Map<String, List<String>> _knownEnumValues = const {};

  List<RealAssetInfo> _availableSkeletalMeshes = [];
  List<RealAssetInfo> _availableStaticMeshes = [];
  List<RealAssetInfo> _availableAnimations = [];
  List<RealAssetInfo> _availableMaterials = [];
  List<({String path, String targetMesh})> _availableAnimBlueprints = [];
  List<String> _availableWidgetClasses = const ['WBP_HUD'];

  /// The 3D Viewport's preview: this Blueprint's actor, built the
  /// way Play builds it, in the viewport's world. It follows every component
  /// edit and the Components panel's selection.
  final BlueprintPreviewScene preview = BlueprintPreviewScene();
  String? _previewProjectDir;

  /// The project's widget classes and Blueprint class parents, refreshed when assets change; null without a
  /// project directory.
  WidgetClassCatalog? _catalog;

  /// [initialDocument] opens a document that does not live in an actor
  /// `.lmas` payload (a level's Blueprint, stored in
  /// the level) as the unedited baseline.
  _BlueprintEditorViewModelState({
    required this.assetPath,
    LuminaAsset? initialAsset,
    LuminaBlueprintDocument? initialDocument,
  }) : _asset = initialAsset {
    if (initialDocument != null) {
      _document = initialDocument;
      _onDiskJson = _document.toFormattedJson();
    } else if (_asset != null) {
      _document = _documentFromAsset(_asset!);
      _onDiskJson = _asset!.rawPayload != null && _asset!.rawPayload!.isNotEmpty ? _document.toFormattedJson() : '';
    } else {
      _document = BlueprintEditorViewModel.createDefaultDocument(fileBasename);
      _seedDefaultGraph();
      // Nothing is edited yet: the default document is the baseline, so an
      // editor opened before (or without) a file on disk is not dirty.
      _onDiskJson = _document.toFormattedJson();
    }
    _previewProjectDir = _findProjectDir(assetPath);
    if (_previewProjectDir != null) {
      try {
        _scanProjectAssets(_previewProjectDir!);
      } catch (_) {}
      _catalog = WidgetClassCatalog(_previewProjectDir!)..addListener(_catalogChanged);
      _assets = BlueprintAssetCatalog(_previewProjectDir!)..addListener(_assetsChanged);
      _rememberEnumValues();
    }
    _syncPreview();
  }

  // ---------------------------------------------------------------------------
  // Component transform drags
  // ---------------------------------------------------------------------------

  int _componentTransformRevision = 0;
  String? _transformDragId;

  String? _propertyEditId;
  List<String> _pawnBlueprints = const [];

  // ---------------------------------------------------------------------------
  // My Blueprint selection of functions, macros and dispatchers
  // ---------------------------------------------------------------------------

  String? _selectedFunction;
  String? _selectedMacro;
  String? _selectedDispatcher;

  // ---------------------------------------------------------------------------
  // Collapse and expand
  // ---------------------------------------------------------------------------

  /// Why the last [collapseSelection] refused, or null.
  String? collapseRefusal;

  // --- Implemented by the domain mixins or [BlueprintEditorViewModel]. ---

  void _catalogChanged();

  void _rememberEnumValues();

  void _assetsChanged();

  void _graphsChanged();

  String get fileBasename;

  List<BlueprintPaletteEntry> pinnedPaletteEntries();

  @protected
  void applyCompileResult(List<LuminaBlueprintDiagnostic> issues);

  LuminaBlueprintDocument get document;

  List<LuminaInputAction> get inputActions;

  LuminaBlueprintTypeContext _contextFor({LuminaBlueprintFunctionGraph? function, LuminaBlueprintMacroGraph? macro});

  List<LuminaBlueprintDiagnostic> get diagnostics;

  void _syncPreview();

  LuminaBlueprintDocument get engineDocument;

  void _restore(String json);

  void _pruneGraphState();

  void undo();

  void redo();

  Set<String> get selectedNodeIds;

  void _seedDefaultGraph();

  Iterable<LuminaBlueprintGraph> get allGraphs;

  void _removeNodesEverywhere(Set<String> ids);

  ({BlueprintGraphRef graph, LuminaBlueprintNode node})? findNode(String id);

  String? get projectDir;

  void setProperty(String componentId, String propName, dynamic value);

  void _refreshBakedMeshPhysics();

  List<LuminaBlueprintComponent> get convexComponentsWithoutHull;

  LuminaBlueprintDocument _documentFromAsset(LuminaAsset asset);

  void _scanProjectAssets(String projectDir);

  Future<bool> save();

  List<BlueprintGraphRef> get graphs;

  BlueprintGraphEditor graphEditor(BlueprintGraphRef ref);

  List<String>? assetPinOptions(LuminaBlueprintNode node, LuminaBlueprintPinSpec pin);

  bool _nameTaken(String name);

  List<LuminaBlueprintNode> nodesCallingFunction(String name);

  List<LuminaBlueprintNode> nodesCallingMacro(String name);

  LuminaBlueprintNode? collapseSelection({required bool toMacro, String? name, BlueprintGraphRef? graph});
}
