part of '../editor_view_model.dart';

/// The state every EditorViewModel domain mixin shares: all instance fields
/// (declared in their original order, so initialisers run in the same
/// order), the core accessors, and the cross-domain members the mixins
/// call on one another.
abstract class _EditorViewModelState extends ChangeNotifier {
  /// The level viewport's live Filament scene while it exists, for views
  /// that draw the same level (the Sequencer's viewport); null before the
  /// level viewport is up and after it is gone.
  final ValueNotifier<EditorLevelScene?> levelScene = ValueNotifier<EditorLevelScene?>(null);

  final CollectionsRepository _collectionsRepo = CollectionsRepository();

  List<Collection> _collections = [];

  String _searchQuery = '';

  Set<AssetType> _activeTypeFilters = {};

  String _sortMode = 'Name ↑';

  /// Content browser "Show All": lists the whole
  /// project instead of the selected folder (search and type filters then
  /// apply project-wide).
  bool _showAllAssets = false;

  String? _selectedFolder = 'contents';

  Set<String> _favoriteFolders = {};

  String? _activeCollection;

  bool _showRecentlyModified = false;

  /// The Content Browser's Marketplace smart view: every
  /// asset under `contents/Marketplace/`.
  bool _showMarketplaceAssets = false;

  /// Window → Marketplace, created when first opened.
  MarketplaceViewModel? _marketplace;

  // Thumbnail Queue
  final ThumbnailService _thumbnailService;

  /// Whether stale thumbnails are queued automatically (off in tests that
  /// construct the editor with `enableTimers: false`, unless asked for).
  final bool _autoThumbnails;
  AssetReferenceGraph? _referenceGraph;
  final List<String> _thumbnailQueue = [];
  final Set<String> _forcedThumbnails = {};
  int _thumbnailTotal = 0;
  bool _isProcessingThumbnails = false;
  bool _thumbnailEnvironmentReady = false;
  Completer<void>? _thumbnailIdle;

  final Map<String, List<Completer<void>>> _thumbnailWaiters = {};

  final ProjectRepository _projectRepo = ProjectRepository();
  final AssetRepository _assetRepo = AssetRepository();
  final EngineLoggerService _logger = EngineLoggerService();

  late final PluginExtensionRegistry extensionRegistry;

  /// Git status/commit/history over the real `git` CLI.
  late final SourceControlViewModel sourceControl;
  final DartCodeGeneratorService _codeGen = DartCodeGeneratorService();
  AutoSaveTimerService? _autoSaveTimer;

  LuminaProject _project;
  List<RealAssetInfo> _realAssets = [];
  StreamSubscription<EngineLogEntry>? _logSub;
  StreamSubscription<void>? _assetsChangedSub;

  bool _isDisposed = false;
  // Perspective Pose Backup
  double _perspYaw = -35.0;
  double _perspPitch = 25.0;
  double _perspPanX = 0.0;
  double _perspPanY = 0.0;
  double _perspPanZ = 0.0;
  double _perspDistance = 250.0;

  // Real Frame Stats
  final List<double> _fpsHistory = [];
  final List<double> _cpuHistory = [];

  final ValueNotifier<int> _frameStatsRevision = ValueNotifier<int>(0);

  bool isFlyNavigating = false;

  // Background Asset Import State & Live Progress
  bool _isImporting = false;
  String _importStatusMessage = '';
  double? _importProgress;

  late final EditorCommandRegistry commands;
  final TransactionManager transactions = TransactionManager();

  /// The user's Editor Preferences, per user in the editor's
  /// config directory: when W/A/S/D fly the level viewport.
  late final EditorPreferences editorPreferences = EditorPreferences.load();

  /// Installed by an open Sequencer: offered every committed transform edit
  /// of actors (the level viewport's gizmo, Details) with each actor's
  /// transform before it, and returns the ids it took (the actors the
  /// sequence animates, keyed there instead). Those get no level undo step
  /// and do not dirty the level.
  Set<String> Function(
    List<({EditorActorNode actor, List<double> location, List<double> rotation, List<double> scale})> edits,
  )? actorTransformEditHandler;

  /// The project's Dart functions exposed to Blueprints:
  /// scanned on open and when an annotated file under lib/ changes.
  late final ProjectBlueprintFunctions blueprintFunctions = ProjectBlueprintFunctions(projectDirPath)
    ..addListener(_notifyUnlessDisposed);

  /// Play Standalone: the project built and run as its
  /// own process.
  late final StandaloneGameRunner standalone =
      StandaloneGameRunner(projectDirPath, flutterExecutable: standaloneFlutterExecutable)..addListener(_notifyUnlessDisposed);

  /// Play on Device: the Android SDK on this machine (null: none, and
  /// Play's dropdown shows no Play on Device section).
  late final AndroidSdk? androidSdk = (androidSdkLocator ?? AndroidSdk.locate)();

  AndroidDeviceList? _androidDevices;
  AndroidDeviceRunner? _androidRunner;

  /// The devices and emulators Play on Device lists, and the one chosen last.
  AndroidDeviceList get androidDevices => _androidDevices ??= AndroidDeviceList(
      androidSdk == null ? null : AndroidDeviceProbe(androidSdk!, starter: androidProcessStarter))
    ..addListener(_notifyUnlessDisposed);

  /// Runs the project on an Android device; null without an Android SDK.
  AndroidDeviceRunner? get androidRunner {
    final sdk = androidSdk;
    if (sdk == null) return null;
    return _androidRunner ??= AndroidDeviceRunner(projectDirPath, sdk,
        starter: androidProcessStarter, flutterExecutable: standaloneFlutterExecutable)
      ..addListener(_notifyUnlessDisposed);
  }

  /// For tests: how Play on Device finds the Android SDK (a temp SDK, or
  /// none) and starts adb / the emulator / flutter (stand-ins that record the
  /// commands); set before [androidSdk] / [androidDevices] are first read.
  @visibleForTesting
  AndroidSdk? Function()? androidSdkLocator;
  @visibleForTesting
  AndroidProcessStarter? androidProcessStarter;

  /// The editor's MCP server: AI agents operate this editor
  /// through it. Started by the shell when the settings allow it.
  McpServerService? _mcpServer;

  void Function()? onStartSimulationRequest;
  void Function()? onStopSimulationRequest;

  late EditorLayoutState layoutState;

  /// The Window menu's panel rows, checked while their
  /// panel is open (re-read on every notification, so an open menu follows).
  late final EditorLayoutFlag outlinerOpen = EditorLayoutFlag(this, () => layoutState, (l) => l.isOutlinerOpen);
  late final EditorLayoutFlag detailsOpen = EditorLayoutFlag(this, () => layoutState, (l) => l.isDetailsOpen);
  late final EditorLayoutFlag bottomPanelOpen = EditorLayoutFlag(this, () => layoutState, (l) => l.isBottomPanelOpen);
  late final EditorLayoutFlag outputLogOpen = EditorLayoutFlag(this, () => layoutState, (l) => l.isOutputLogOpen);

  // Real Engine Performance Counters
  double _fps = 60.0;
  double _cpuMs = 1.2;
  double _gpuMs = 4.1;

  // 3D Viewport Camera State (navigation model)
  double _cameraYaw = -35.0; // degrees
  double _cameraPitch = 25.0; // degrees (-89° to +89°)
  double _cameraPanX = 0.0; // target/pivot X
  double _cameraPanY = 0.0; // target/pivot Y
  double _cameraPanZ = 0.0; // target/pivot Z
  double _cameraDistance = 250.0; // distance from target/pivot

  // Camera flight speed scalar: Level 1 to 8
  int _cameraSpeedScalar = 4;

  // Active Editor State
  String _activeTool = 'select';

  String _gizmoSpace = 'world';

  Map<String, List<double>>? _dragSnapshotLocation;
  Map<String, List<double>>? _dragSnapshotRotation;
  Map<String, List<double>>? _dragSnapshotScale;

  /// True while the open transform drag was started by a live `updateActor*`
  /// write (`isCommit: false`: a Details scrub, a Navigation editor slider)
  /// rather than by [beginTransformDrag] (the viewport gizmo, which ends its
  /// own drag on pointer-up). Nothing else ends such a drag, so the gesture's
  /// committing write does, recording its one undo transaction.
  bool _implicitTransformDrag = false;

  bool _isPlaying = false;
  bool _isPaused = false;
  EditorActorNode? _selectedActor;
  final Set<String> _selectedActorIds = {};

  // Real Level Scene Graph
  final List<EditorActorNode> _actors = [];

  final String? _customProjectLocation;

  final List<EditorTabInfo> _openTabs = [
    EditorTabInfo(id: EditorViewModel.kLevelTabId, title: '', category: 'level'),
  ];
  int _activeTabIndex = 0;

  /// Zoom (view extent) shared by the orthographic views, independent of the
  /// perspective orbit distance.
  double _orthoDistance = 500.0;

  bool _logNotifyScheduled = false;
  bool _disposed = false;

  // --- Sub-editor tab sessions (save-on-close) ---
  final Map<String, EditorTabSession> _tabSessions = {};

  final Map<String, LevelBlueprintEditorViewModel> _levelBlueprintEditors = {};

  /// The active level's stored Level Blueprint (`metadata.levelBlueprint`
  /// JSON) as the level editor knows it: read with the level, replaced when
  /// the Level Blueprint editor saves, renamed with the level's actors, and
  /// written back by every Save Level. Null when the level has none.
  Map<String, dynamic>? _levelBlueprintMeta;

  /// Asked when switching levels closes a Level Blueprint with unsaved
  /// changes: resolve true to save it, false to discard. Without a handler
  /// (headless) the changes are saved.
  Future<bool> Function(String title)? onLevelBlueprintSavePrompt;

  // --- Level environment section (sun / sky / fog / post-process mixer) ---
  Map<String, dynamic> _levelEnvironment = {};

  // --- Level navigation section (NavMeshBoundsVolume config, nav editor) ---
  Map<String, dynamic> _levelNavigation = {};
  int _navigationBuildRequests = 0;

  // --- Level world-partition section (Open World levels) -------------------
  //
  // Persisted alongside `actors` / `environment` / `navigation` as
  // `metadata.worldPartition`, and mapped 1:1 onto the real runtime:
  // `cellSize` and `maxCellTransitionsPerTick` are
  // `LuminaWorldPartitionSubsystem`'s own constructor arguments and
  // `loadingRange` is the `LuminaStreamingSourceComponent.loadingRadius`
  // applied to sources that author none. All three are METRES / counts in the
  // runtime's own units — the editor's snap grid is centimetre-scale, which is
  // a separate, open workspace-wide question.
  //
  // The editor does NOT stream cells in and out while editing; this section is
  // authoring data that reaches the generated game, and the panel says so.
  Map<String, dynamic> _levelWorldPartition = {};

  Future<void>? _scaffoldFuture;

  // Background batch import
  //
  // Every Content Browser import goes through one ImportQueue: conversion in
  // worker isolates, the UI isolate only painting thumbnails and indexing,
  // so a 50-file batch never freezes the editor. Assets appear in the
  // Content Browser as each file lands (no rescan per file); the progress
  // panel reads [importJobs].
  ImportQueue? _importQueue;
  ImportJobsViewModel? _importJobs;

  /// File → Import Asset Folder…'s directory picker; null uses the OS
  /// dialog. Tests and smokes point it at a real folder on disk.
  Future<String?> Function()? importFolderPicker;

  /// The Import Asset Options dialog's Textures Folder picker; null uses the OS dialog. Tests point it at a real folder.
  Future<String?> Function()? importTexturesFolderPicker;

  /// Content Browser → Migrate…'s target project picker; null
  /// uses the OS dialog. Tests point it at a real second project.
  Future<String?> Function()? migrateTargetPicker;

  /// The Plugin Manager's Import from Folder / Import from Zip pickers; null
  /// uses the OS dialog. Tests and smokes point them at a real plugin
  /// folder or zip on disk.
  Future<String?> Function()? pluginFolderPicker;
  Future<String?> Function()? pluginZipPicker;

  /// The Output Log's level filter (`all`, `info`, `warning`, `error`,
  /// `success`), so "Show errors" can open it filtered.
  final ValueNotifier<String> outputLogFilter = ValueNotifier<String>('all');

  int _lastImportNotice = -1;

  // Outliner tree expansion: per-session editor view state, not level data.
  final Set<String> _outlinerExpanded = {};

  // The outliner row put into inline rename (F2, New Folder).
  String? _outlinerRenamingId;

  // Filter & Visibility State
  String _outlinerSearchQuery = '';

  String? _outlinerTypeFilter;

  Map<String, bool>? _soloSnapshot;

  /// The World Partition section before an uncommitted Details scrub:
  /// the commit records one undo step from it.
  Map<String, dynamic>? _worldPartitionGestureStart;

  /// Why the last Play did not start (compile errors), empty otherwise.
  List<PlayBlocker> playBlockers = const [];

  /// Shows [playBlockers] (the viewport opens the compile-errors dialog).
  void Function(List<PlayBlocker> blockers)? onPlayBlocked;

  /// Blueprint warnings of the last Play that started (a project function
  /// that needs Play Standalone), by Blueprint and node.
  List<PlayBlocker> playWarnings = const [];

  /// Shows [playWarnings] (the viewport toasts them).
  void Function(List<PlayBlocker> warnings)? onPlayWarnings;

  final EditorQualityStore _qualityStore;
  EditorQualitySettings _quality = const EditorQualitySettings();
  int _qualityRevision = 0;

  Future<void>? _pendingQualitySave;

  // --- Build Manager ---
  BuildManagerViewModel? _buildManagerVm;

  /// For tests: what the Build Manager spawns `flutter build` with
  /// (a stand-in child process) and the host toolchain it assumes; set
  /// before [buildManagerViewModel] is first read.
  @visibleForTesting
  BuildProcessStarter? buildProcessStarter;
  @visibleForTesting
  HostBuildTargets? buildHostTargets;

  /// For tests: the `flutter` Play Standalone builds with (a
  /// stand-in); set before [standalone] is first read.
  @visibleForTesting
  String standaloneFlutterExecutable = 'flutter';

  String? _contentBrowserRevealPath;
  int _contentBrowserRevealSerial = 0;

  /// The Content Browser's selected assets (project-relative paths, in
  /// selection order) and the one clicked last.
  final Set<String> _contentBrowserSelection = {};
  String? _contentBrowserPrimaryAsset;

  late final PluginRegistryService pluginRegistry;
  bool _pluginRestartRequired = false;

  final Map<String, String> _pluginContentRoots = {};

  /// Runs the initialiser list EditorViewModel's constructor used to have,
  /// after the field initialisers above, so construction order is unchanged.
  _EditorViewModelState({
    LuminaProject? initialProject,
    String? projectDirPath,
    String? projectLocation,
    required bool enableTimers,
    EditorQualityStore? qualityStore,
    ThumbnailService? thumbnailService,
    bool? autoGenerateThumbnails,
  }) : _qualityStore = qualityStore ?? EditorQualityStore(),
       _thumbnailService = thumbnailService ?? ThumbnailService(),
       _autoThumbnails = autoGenerateThumbnails ?? enableTimers,
       _customProjectLocation = projectDirPath ?? projectLocation,
       _project =
           initialProject ??
           const LuminaProject(
             projectName: 'MyFirstLuminaGame',
             engineVersion: '0.0.1',
             activeLevel: 'contents/levels/L_OpenWorld_Main.lmas',
           );

  EngineLoggerService get logger => _logger;

  void _notifyUnlessDisposed() {
    if (!_disposed) notifyListeners();
  }

  // Getters
  LuminaProject get project => _project;
  String get engineVersion => _project.engineVersion;
  String get activeLevelName =>
      _project.activeLevel.split('/').last.replaceAll('.lmas', '');

  bool get isPlaying => _isPlaying;
  bool get isPaused => _isPaused;
  EditorActorNode? get selectedActor => _selectedActor;
  EditorActorNode? get primarySelectedActor => _selectedActor;
  Set<String> get selectedActorIds => _selectedActorIds;

  List<EditorActorNode> get selectedActors {
    return _selectedActorIds
        .map(
          (id) => _actors.cast<EditorActorNode?>().firstWhere(
            (a) => a?.id == id,
            orElse: () => null,
          ),
        )
        .where((a) => a != null)
        .cast<EditorActorNode>()
        .toList();
  }

  String? get selectedActorId => _selectedActor?.id;
  List<EditorActorNode> get actors => List.unmodifiable(_actors);

  List<RealAssetInfo> get realAssets => _realAssets;
  List<EngineLogEntry> get logs => List.unmodifiable(_logger.logs);

  void clearLogs() {
    _logger.clear();
    notifyListeners();
  }

  String get projectDirPath {
    if (_customProjectLocation != null) {
      return '$_customProjectLocation/${_project.projectName}';
    }
    final home =
        Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        Directory.systemTemp.path;
    return '$home/Lumina Projects/${_project.projectName}';
  }

  void _markDirty() {
    _project = _project.copyWith(
      isDirty: true,
      lastModifiedTimestamp: DateTime.now().toIso8601String(),
    );
    notifyListeners();
  }

  /// This view model as its public type, for the few calls that hand the
  /// editor to a dialog or a command builder.
  EditorViewModel get _self;

  // ---------------------------------------------------------------------
  // Members the domain mixins use from one another. Each is implemented
  // (with @override) in exactly one mixin or in EditorViewModel itself.

  // EditorViewModel
  PieController get pieController;

  // editor_view_model/project_and_levels.dart
  Future<DerivedDataCacheUsage> clearDerivedDataCache();
  void refreshAssets();
  void _refreshAssets();
  void switchLevel(String levelRelativePath);
  Future<bool> confirmLeavingLevel({BuildContext? context, UnsavedLevelChoice? ifDirty});
  List<String> get levelFiles;
  Future<bool> openLevelGuarded(String levelRelativePath, {BuildContext? context, UnsavedLevelChoice? ifDirty});

  // editor_view_model/level_sections.dart
  void _loadLevelEnvironment(dynamic metadata);
  void _loadLevelNavigation(dynamic metadata);
  void _loadLevelWorldPartition(dynamic metadata);
  bool get worldPartitionEnabled;
  double get worldPartitionCellSize;
  void requestNavigationBuild();

  // editor_view_model/actor_spawning.dart
  Future<void> _loadActorMeshData(EditorActorNode actor);
  void _refreshPrimitiveMesh(EditorActorNode actor);
  String _uniqueActorId();

  // editor_view_model/outliner.dart
  EditorActorNode? _nodeById(String? id);
  String createFolderFromSelection();
  void _revealInOutliner(String? id);
  void requestOutlinerRename(String id);
  void duplicateActorSubtree(String id);
  void deleteActorSubtree(String id, {bool keepChildren = false});
  List<EditorActorNode> _cloneActors(List<EditorActorNode> source);

  // editor_view_model/selection_and_transforms.dart
  void cancelActiveOperation();
  void deleteSelectedActor();
  void setActiveTool(String tool);
  void setViewportMode(String mode);
  void selectActor(EditorActorNode? actor);
  void selectActors(Iterable<String> ids);
  void setActorSelection(Iterable<String> ids, {String? primaryId});
  void clearSelection();
  void duplicateSelectedActor();
  void applyPropertyToSelection(
    String? componentType,
    String propertyId,
    dynamic value, {
    bool relative = false,
    int? axis,
  });

  // editor_view_model/camera_and_viewport.dart
  void setCameraMode(String mode);
  void setViewMode(String mode);
  void resetCamera();
  void frameLevelBounds();
  void focusCameraOnActor(EditorActorNode actor);
  void _setQuality(EditorQualitySettings next, String what);
  Future<void> loadQualitySettings();

  // editor_view_model/assets_and_content_browser.dart
  String? get selectedFolder;
  set selectedFolder(String? value);
  Future<void> createNewAsset({
    required AssetType type,
    required String subFolder,
  });
  Future<bool> createNewAssetOnDisk(
    String subFolder,
    String fileName,
    AssetType type,
  );
  void revealAssetInContentBrowser(String relativeAssetPath);

  // editor_view_model/thumbnails.dart
  Future<void> thumbnailsFor(Iterable<RealAssetInfo> assets);
  void _enqueueStaleThumbnails();
  void _thumbnailAfterSubEditorChange(String tabId);

  // editor_view_model/import.dart
  ImportQueue get importQueue;
  ImportJobsViewModel get importJobs;
  bool get isBatchImporting;
  void cancelImports();

  // editor_view_model/sub_editor_tabs.dart
  void openSubEditorTab(
    String category, {
    String? title,
    RealAssetInfo? asset,
  });
  void bindTabSession(
    String tabId, {
    required Listenable notifier,
    required Future<bool> Function() save,
    required bool Function() isDirty,
  });
  void unbindTabSession(String tabId);
  void openAssetEditorByPath(String assetPath);

  // editor_view_model/blueprints_and_level_blueprints.dart
  void _readLevelBlueprintMeta(Object? metadata);
  LevelBlueprintEditorViewModel openLevelBlueprint([String? levelPath]);
  void _releaseLevelBlueprintEditor(EditorTabInfo tab);
  void _closeLevelBlueprintsExcept(String levelPath);
  void _renameLevelBlueprintReferences(String oldName, String newName);
  Iterable<BlueprintEditorViewModel> get openBlueprintEditors;

  // editor_view_model/play_in_editor.dart
  void togglePauseSimulation();
  void stepSimulation();
  void stopSimulation();
  void togglePlaySimulation();
  Future<bool> playStandalone();
  Future<void> stopStandalone();
  Future<bool> playOnAndroidDevice(AndroidDevice device);

  // editor_view_model/plugins.dart
  Future<void> restartEditor();

  // editor_view_model/codegen_and_save.dart
  Future<void> saveLevelAndGenerateCode();
  Future<List<String>> generateDartCode();
  void saveLayoutState();
  void _writeLayoutState();
  BuildManagerViewModel get buildManagerViewModel;
  Future<void> _cookAndPackageFromMenu();

  // editor_view_model/dialogs.dart
  void _promptNewLevel(BuildContext? ctx);
  void _promptOpenLevel(BuildContext? ctx);
  void _promptNewAsset(BuildContext? ctx);
  void _promptExitStudio(BuildContext? ctx);
  void _showAboutDialog(BuildContext? ctx);
}
