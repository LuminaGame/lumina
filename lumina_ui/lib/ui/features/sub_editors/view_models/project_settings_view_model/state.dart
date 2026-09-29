part of '../project_settings_view_model.dart';

/// State shared by the [ProjectSettingsViewModel] domain mixins: every
/// instance field (in the original order, so initialisers run in the same
/// order) and the members the mixins call on one another.
abstract class _ProjectSettingsViewModelState extends ChangeNotifier {
  final String projectDirPath;
  final ProjectRepository _projectRepo;
  final AssetRepository _assetRepo;
  final EngineLoggerService _logger;
  final ProcessStarter _processStarter;

  /// Called after a successful [apply] with the saved manifest.
  void Function(LuminaProject saved)? onApplied;

  LuminaProject? _onDisk;
  LuminaProject? _working;
  String? _manifestPath;
  bool _isLoading = true;
  String? _loadError;
  String _filterQuery = '';
  List<LevelChoice> _levels = const [];
  List<String> _gameModeClasses = const ['LuminaGameMode'];
  PackagingRunState _packaging = const PackagingRunState();
  final List<PackagingLogLine> _packagingLog = [];
  BuildCancellationToken? _packagingToken;
  HostBuildTargets? _hostTargets;
  bool _probingTargets = false;
  final CookCodeGenerator? _codeGenerator;
  final List<String>? _webModulePackageRoots;

  _ProjectSettingsViewModelState({
    required this.projectDirPath,
    ProjectRepository? projectRepository,
    AssetRepository? assetRepository,
    EngineLoggerService? logger,
    ProcessStarter? processStarter,
    LuminaProject? initialProject,
    HostBuildTargets? hostTargets,
    CookCodeGenerator? codeGenerator,
    List<String>? webModulePackageRoots,
  })  : _projectRepo = projectRepository ?? ProjectRepository(),
        _assetRepo = assetRepository ?? AssetRepository(),
        _logger = logger ?? EngineLoggerService(),
        _processStarter = processStarter ?? ProjectSettingsViewModel._defaultStarter,
        _usesRealProcesses = processStarter == null,
        // ignore: prefer_initializing_formals
        _hostTargets = hostTargets,
        // ignore: prefer_initializing_formals
        _codeGenerator = codeGenerator,
        // ignore: prefer_initializing_formals
        _webModulePackageRoots = webModulePackageRoots {
    if (initialProject != null) {
      _onDisk = initialProject;
      _working = initialProject;
      _isLoading = false;
    }
  }

  /// No process seam was injected: the toolchain probe is the shared one.
  final bool _usesRealProcesses;

  List<String> _pawnClasses = const [''];

  String? _widgetLibraryStatus;
  String? _widgetLibraryError;

  // Branding

  String? _iconStatus;
  String? _iconError;

  /// flutter_filament's WebAssembly module (web packages), looked up once.
  late final FlutterFilamentWebModule? webModule = FlutterFilamentWebModule.locate(
    packageRoots: _webModulePackageRoots ?? [projectDirPath, ProjectRepository.luminaPackagePath, LuminaEditorHost.uiRoot],
  );

  String? _webLoadingStatus;
  String? _webLoadingError;

  final WebPreviewServer _webLoadingPreview = WebPreviewServer();
  Uri? _webLoadingPreviewUrl;

  /// Opens the browser; the default is the platform's "open URL" command.
  Future<void> Function(Uri url)? openUrl;

  bool _disposed = false;

  // --- Implemented by the domain mixins or [ProjectSettingsViewModel]. ---

  LuminaProject get project;

  PackagingRunState get packaging;

  Future<bool> apply();

  void _update(LuminaProject Function(LuminaProject p) fn);

  HostBuildTargets? get hostTargets;
}
