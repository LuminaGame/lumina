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

  LuminaBlueprintDocument? _loadBlueprintDocumentByClassName(String className) {
    final dir = _findProjectDir(assetPath);
    if (dir == null) return null;
    final contentsDir = Directory('$dir/contents');
    if (!contentsDir.existsSync()) return null;
    try {
      for (final entity in contentsDir.listSync(recursive: true, followLinks: false)) {
        if (entity is File && entity.path.endsWith('.lmas')) {
          final fileName = entity.path.split(RegExp(r'[\\/]')).last;
          if (fileName == '$className.lmas') {
            final asset = LuminaAsset.fromBytes(entity.readAsBytesSync());
            if (asset.rawPayload != null && asset.rawPayload!.isNotEmpty) {
              final decoded = jsonDecode(utf8.decode(asset.rawPayload!));
              return LuminaBlueprintDocument.fromJson(Map<String, dynamic>.from(decoded as Map));
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// Variables inherited from parent Blueprint classes.
  List<LuminaBlueprintVariable> get inheritedVariables {
    final vars = <LuminaBlueprintVariable>[];
    final visited = <String>{fileBasename};
    var currentParent = _document.parentClass;
    while (!LuminaBlueprintClass.isEngineParent(currentParent) && visited.add(currentParent)) {
      final parentDoc = _loadBlueprintDocumentByClassName(currentParent);
      if (parentDoc == null) break;
      vars.insertAll(0, parentDoc.variables);
      currentParent = parentDoc.parentClass;
    }
    return vars;
  }

  /// Components inherited from parent Blueprint classes.
  List<LuminaBlueprintComponent> get inheritedComponents {
    final comps = <LuminaBlueprintComponent>[];
    final visited = <String>{fileBasename};
    var currentParent = _document.parentClass;
    while (!LuminaBlueprintClass.isEngineParent(currentParent) && visited.add(currentParent)) {
      final parentDoc = _loadBlueprintDocumentByClassName(currentParent);
      if (parentDoc == null) break;
      comps.insertAll(0, parentDoc.components);
      currentParent = parentDoc.parentClass;
    }
    return comps;
  }

  /// All variables: inherited variables merged with this document's own variables.
  List<LuminaBlueprintVariable> get allVariables => [
        ...inheritedVariables.where((iv) => !_document.variables.any((v) => v.name == iv.name)),
        ..._document.variables,
      ];

  /// All components: inherited components merged with this document's own components.
  List<LuminaBlueprintComponent> get allComponents {
    final list = <LuminaBlueprintComponent>[];
    for (final ic in inheritedComponents) {
      final overrideComp = _document.components.where((c) => c.id == ic.id).firstOrNull;
      list.add(overrideComp ?? ic);
    }
    for (final c in _document.components) {
      if (!inheritedComponents.any((ic) => ic.id == c.id)) {
        list.add(c);
      }
    }
    return list;
  }

  /// Whether a component is inherited from a parent Blueprint.
  bool isInheritedComponent(String id) =>
      inheritedComponents.any((c) => c.id == id);

  /// Whether an inherited component has been overridden in this child Blueprint.
  bool isComponentOverridden(String id) =>
      inheritedComponents.any((c) => c.id == id) && _document.components.any((c) => c.id == id);

  /// Whether a variable is inherited from a parent Blueprint.
  bool isInheritedVariable(String name) =>
      inheritedVariables.any((v) => v.name == name);

  /// Custom events inherited from parent Blueprint classes.
  List<LuminaBlueprintCustomEvent> get inheritedCustomEvents {
    final events = <LuminaBlueprintCustomEvent>[];
    final visited = <String>{fileBasename};
    var currentParent = _document.parentClass;
    while (!LuminaBlueprintClass.isEngineParent(currentParent) && visited.add(currentParent)) {
      List<LuminaBlueprintCustomEvent>? parentEvents = _catalog?.actorEvents[currentParent];
      final parentDoc = _loadBlueprintDocumentByClassName(currentParent);
      if (parentDoc != null) {
        parentEvents = LuminaBlueprintNodeLibrary.customEventsOf(parentDoc.eventGraph);
      }
      if (parentEvents != null) {
        for (final e in parentEvents) {
          if (!events.any((existing) => existing.name == e.name)) {
            events.add(e);
          }
        }
      }
      if (parentDoc != null) {
        currentParent = parentDoc.parentClass;
      } else {
        currentParent = _catalog?.actorParents[currentParent] ?? '';
      }
    }
    return events;
  }

  /// Whether a custom event is inherited from a parent Blueprint.
  bool isInheritedCustomEvent(String name) =>
      inheritedCustomEvents.any((e) => e.name == name);
}
