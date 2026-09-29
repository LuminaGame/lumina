import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/core/host/editor_host.dart' show LuminaEditorHost;

import '../services/build_pipeline_service.dart';
import '../services/project_icon_packaging.dart';
import '../services/web_preview_server.dart';

/// Per-step UI state derived from real pipeline events.
class BuildStepState {
  final BuildStepStatus status;
  final Duration? duration;
  final String? progressLabel;
  final String? message;
  const BuildStepState({this.status = BuildStepStatus.pending, this.duration, this.progressLabel, this.message});

  BuildStepState copyWith({BuildStepStatus? status, Duration? duration, String? progressLabel, String? message}) => BuildStepState(
        status: status ?? this.status,
        duration: duration ?? this.duration,
        progressLabel: progressLabel ?? this.progressLabel,
        message: message ?? this.message,
      );
}

/// One packaging target's state in the last run.
class PackageTargetState {
  final PackageTargetStatus status;
  final Duration? duration;
  final String? message;
  final String? packageDir;
  final int? sizeBytes;
  final List<String> reasons;
  const PackageTargetState({
    this.status = PackageTargetStatus.pending,
    this.duration,
    this.message,
    this.packageDir,
    this.sizeBytes,
    this.reasons = const [],
  });
}

/// One console line; timestamps are the event's real wall-clock time.
class BuildLogLine {
  final DateTime at;
  final String level;
  final String source;
  final String message;
  const BuildLogLine({required this.at, required this.level, required this.source, required this.message});

  String get timestamp =>
      '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}:${at.second.toString().padLeft(2, '0')}';
}

/// Build Manager state: step selection, target/config, one pipeline at a
/// time, per-step status + durations, the live log and validation issues.
/// Every line shown originates from a [BuildEvent]; logs are also forwarded
/// to [EngineLoggerService] so the main Output Log sees builds.
class BuildManagerViewModel extends ChangeNotifier {
  static const String logSource = 'BuildManager';

  final String projectDirPath;
  final LuminaProject? _initialProject;
  final LuminaProject? Function()? _projectProvider;
  final EngineLoggerService _logger;
  final BuildPipelineService _pipeline;
  final BuildProcessStarter? _processStarter;
  final MaterialCompiler? _materialCompiler;
  final NavigationBuilder? _navigationBuilder;
  final ThumbnailService? _thumbnailService;
  final CookCodeGenerator? _codeGenerator;
  final String flutterExecutable;

  /// Asked before Cook when Validate Assets failed; null means "do not cook".
  Future<bool> Function(List<ValidationIssue> issues)? confirmCookDespiteValidation;

  /// While an agent's build runs, answers the "validation
  /// failed — cook anyway?" question in place of
  /// [confirmCookDespiteValidation], so no dialog waits for a click.
  Future<bool> Function(List<ValidationIssue> issues)? confirmCookOverride;

  /// Invoked by the issue table's `Reveal in Content Browser`.
  void Function(ValidationIssue issue)? onRevealIssue;

  /// Opens the served web build (`Launch in Browser`); null uses
  /// [openInSystemBrowser].
  Future<void> Function(Uri url)? openUrl;

  final List<String>? _webModulePackageRoots;
  final WebPreviewServer _preview = WebPreviewServer();

  /// Called with the new target list when a target is ticked or unticked
  /// here; the editor updates its project and saves the `.lmproject`.
  /// Without it the view model saves the manifest.
  void Function(List<String> targets)? onTargetsChanged;
  List<String>? _targetsOverride;
  final Map<String, PackageTargetState> _targetStates = {};

  final Map<BuildStepKind, bool> _enabled = {
    BuildStepKind.precompileMaterials: true,
    BuildStepKind.buildNavigation: true,
    BuildStepKind.regenerateThumbnails: true,
    BuildStepKind.validateAssets: true,
  };
  final Map<BuildStepKind, BuildStepState> _states = {for (final k in BuildStepKind.values) k: const BuildStepState()};
  final List<BuildLogLine> _log = [];
  final List<ValidationIssue> _issues = [];

  HostBuildTargets? _hostTargets;
  bool _probing = false;
  BuildConfiguration _configuration = BuildConfiguration.shipping;
  String _extraFlags = '';
  bool _bundleWebResources = false;

  bool _isRunning = false;
  BuildStepKind? _currentStep;
  String _currentStage = 'Idle';
  int _completedSteps = 0;
  int _totalSteps = 0;
  String? _artifactPath;
  Uri? _previewUrl;
  BuildStepStatus? _lastPipelineStatus;
  BuildCancellationToken? _token;
  String? _packagingTarget;
  StreamSubscription<BuildEvent>? _subscription;
  Timer? _ticker;
  final Stopwatch _elapsed = Stopwatch();
  bool _disposed = false;

  BuildManagerViewModel({
    required this.projectDirPath,
    LuminaProject? project,
    LuminaProject? Function()? projectProvider,
    EngineLoggerService? logger,
    BuildPipelineService? pipeline,
    BuildProcessStarter? processStarter,
    MaterialCompiler? materialCompiler,
    NavigationBuilder? navigationBuilder,
    ThumbnailService? thumbnailService,
    CookCodeGenerator? codeGenerator,
    HostBuildTargets? hostTargets,
    this.flutterExecutable = 'flutter',
    this.confirmCookDespiteValidation,
    this.onRevealIssue,
    this.openUrl,
    this.onTargetsChanged,
    List<String>? webModulePackageRoots,
  })  : _initialProject = project,
        // ignore: prefer_initializing_formals
        _webModulePackageRoots = webModulePackageRoots,
        // ignore: prefer_initializing_formals
        _projectProvider = projectProvider,
        _logger = logger ?? EngineLoggerService(),
        _pipeline = pipeline ?? BuildPipelineService(),
        // ignore: prefer_initializing_formals
        _processStarter = processStarter,
        // ignore: prefer_initializing_formals
        _materialCompiler = materialCompiler,
        // ignore: prefer_initializing_formals
        _navigationBuilder = navigationBuilder,
        // ignore: prefer_initializing_formals
        _thumbnailService = thumbnailService,
        // ignore: prefer_initializing_formals
        _codeGenerator = codeGenerator,
        // ignore: prefer_initializing_formals
        _hostTargets = hostTargets;

  // --- read state ---------------------------------------------------------

  LuminaProject? get project => _projectProvider?.call() ?? _initialProject;
  bool isStepEnabled(BuildStepKind kind) => _enabled[kind] ?? false;
  BuildStepState stepState(BuildStepKind kind) => _states[kind]!;
  List<BuildLogLine> get logLines => List.unmodifiable(_log);
  List<ValidationIssue> get issues => List.unmodifiable(_issues);
  HostBuildTargets? get hostTargets => _hostTargets;
  bool get isProbing => _probing;
  bool get flutterAvailable => _hostTargets?.flutterAvailable ?? false;
  String? get flutterVersion => _hostTargets?.flutterVersion;
  /// The toolchains `flutter doctor` reports as ready here.
  List<String> get availableTargets => _hostTargets?.targets ?? const [];

  /// The platforms a Lumina game can be packaged for from this host now
  /// (no host, toolchain or engine reason).
  List<String> get buildableTargets => _hostTargets == null ? const [] : kPackagingPlatforms.where((t) => reasonsFor(t).isEmpty).toList();

  /// flutter_filament's WebAssembly module, looked up once: first through
  /// the project's own dependencies (the flutter_filament its game links),
  /// then the engine's and the editor's. Null disables web cooks.
  late final FlutterFilamentWebModule? webModule = FlutterFilamentWebModule.locate(
    packageRoots: _webModulePackageRoots ?? [projectDirPath, ProjectRepository.luminaPackagePath, LuminaEditorHost.uiRoot],
  );

  /// Why the engine cannot build [target] (flutter_filament's native
  /// build), or null.
  String? unsupportedReason(String target) => target == 'web'
      ? (webModule == null ? FlutterFilamentWebModule.missingReason : null)
      : HostBuildTargets.engineUnsupportedReason(target);

  /// Every reason [target] cannot be packaged here (host, toolchain, engine);
  /// empty until the toolchain is probed, and empty when buildable.
  List<String> reasonsFor(String target) => _hostTargets?.reasonsFor(target, engineReason: unsupportedReason) ?? const [];

  /// The ticked packaging targets: the project's `packaging.targets`, the
  /// same list Project Settings edits.
  List<String> get selectedTargets => _targetsOverride ?? project?.packaging.targets ?? [Platform.isWindows ? 'windows' : Platform.isMacOS ? 'macos' : 'linux'];
  bool isTargetSelected(String target) => selectedTargets.contains(target);

  ProjectPackagingSettings get _packaging => (project?.packaging ?? const ProjectPackagingSettings()).copyWith(targets: selectedTargets);

  BuildConfiguration get configuration => _configuration;
  String get extraFlags => _extraFlags;

  /// Web cooks only: bundle CanvasKit & co. so the build runs offline
  /// (`--no-web-resources-cdn`).
  bool get bundleWebResources => _bundleWebResources;
  bool get isRunning => _isRunning;
  BuildStepKind? get currentStep => _currentStep;
  String get currentStage => _currentStage;
  int get completedSteps => _completedSteps;
  int get totalSteps => _totalSteps;
  Duration get elapsed => _elapsed.elapsed;

  /// The package root of the last fully successful Cook & Package.
  String? get artifactPath => _artifactPath;

  /// Per-target results of the last Cook & Package.
  PackageTargetState targetState(String target) => _targetStates[target] ?? const PackageTargetState();

  /// Size on disk of the web package, once packaged.
  int? get artifactSizeBytes => _targetStates['web']?.sizeBytes;

  /// The web package folder of the last run, when web was packaged.
  String? get webPackageDir => _targetStates['web']?.status == PackageTargetStatus.ok ? _targetStates['web']!.packageDir : null;

  /// The address `Launch in Browser` serves the web build on, while served.
  Uri? get previewUrl => _previewUrl;

  /// True after a successful web package, until the next build starts.
  bool get canLaunchInBrowser => !_isRunning && webPackageDir != null;
  BuildStepStatus? get lastPipelineStatus => _lastPipelineStatus;

  /// Global progress 0..1, or null while the cook (unmeasurable) runs.
  double? get globalProgress {
    if (_totalSteps == 0) return _isRunning ? null : 0;
    if (_currentStep == BuildStepKind.cookAndPackage) return null;
    return _completedSteps / _totalSteps;
  }

  /// The literal argv Cook spawns for [target] (`flutter` + these).
  List<String> cookArgumentsFor(String target) => _packageStep(const []).argumentsFor(target);

  /// The argv of every ticked target, in order.
  Map<String, List<String>> get cookArguments => {for (final t in selectedTargets) t: cookArgumentsFor(t)};

  /// Where [target]'s package goes: `<output dir>/package/<target>`.
  String packageDirFor(String target) => _packaging.packageDirFor(projectDirPath, target);

  String? get cookDisabledReason {
    if (_probing) return 'Probing the Flutter toolchain (flutter doctor -v)…';
    final h = _hostTargets;
    if (h == null) return 'Flutter toolchain not probed yet';
    if (!h.flutterAvailable) return h.error ?? 'Flutter SDK is not available on this host';
    if (selectedTargets.isEmpty) return 'Tick at least one target platform';
    return null;
  }

  bool get cookEnabled => !_isRunning && cookDisabledReason == null;

  // --- tab session contract ------------------------------------------------

  bool get isDirty => false;
  Future<bool> save() async => true;

  // --- setup ----------------------------------------------------------------

  /// Probes the host toolchain once (skipped when targets were injected).
  Future<void> init() async {
    if (_hostTargets != null || _probing) return;
    _probing = true;
    notifyListeners();
    final probed = _processStarter == null ? await HostBuildTargets.shared() : await HostBuildTargets.probe(processStarter: _processStarter);
    if (_disposed) return;
    _hostTargets = probed;
    _probing = false;
    if (probed.flutterAvailable) {
      _append('info', 'Flutter ${probed.flutterVersion ?? '?'} detected; buildable targets: ${buildableTargets.join(', ')}');
      for (final t in selectedTargets) {
        final reasons = reasonsFor(t);
        if (reasons.isNotEmpty) _append('warning', '${HostBuildTargets.labelFor(t)} is ticked but cannot be built here: ${reasons.join(' ')}');
      }
    } else {
      _append('warning', 'Cook & Package disabled: ${probed.error}');
    }
    notifyListeners();
  }

  void setStepEnabled(BuildStepKind kind, bool enabled) {
    if (kind == BuildStepKind.cookAndPackage) return;
    _enabled[kind] = enabled;
    notifyListeners();
  }

  /// Ticks or unticks [target]. Unbuildable targets stay tickable: their
  /// reasons are shown next to them and reported when packaging.
  void setTargetSelected(String target, bool selected) {
    if (_isRunning) return;
    final next = _packaging.withTarget(target, selected).targets;
    final changed = onTargetsChanged;
    if (changed != null) {
      _targetsOverride = null;
      changed(next);
    } else {
      _targetsOverride = next;
      final p = project;
      if (p != null) unawaited(ProjectRepository().saveProject(p.copyWith(packaging: _packaging), projectDirPath));
    }
    notifyListeners();
  }

  void setConfiguration(BuildConfiguration configuration) {
    _configuration = configuration;
    notifyListeners();
  }

  void setBundleWebResources(bool bundle) {
    _bundleWebResources = bundle;
    notifyListeners();
  }

  void setExtraFlags(String flags) {
    _extraFlags = flags;
    notifyListeners();
  }

  void clearLog() {
    _log.clear();
    notifyListeners();
  }

  String get logText => _log.map((l) => '${l.timestamp} [${l.level.toUpperCase()}] [${l.source}] ${l.message}').join('\n');

  // --- running ----------------------------------------------------------------

  List<BuildStep> _assetSteps() => [
        if (isStepEnabled(BuildStepKind.precompileMaterials)) MaterialPrecompileStep(compiler: _materialCompiler),
        if (isStepEnabled(BuildStepKind.buildNavigation)) NavigationBuildStep(builder: _navigationBuilder),
        if (isStepEnabled(BuildStepKind.regenerateThumbnails)) ThumbnailRegenStep(thumbnailService: _thumbnailService),
        if (isStepEnabled(BuildStepKind.validateAssets)) AssetValidationStep(),
      ];

  /// Runs the checked steps in the fixed order.
  Future<BuildStepStatus?> buildAll() => _run(BuildPlan(steps: _assetSteps()));

  PackageTargetsStep _packageStep(List<String> targets) {
    final p = project;
    // Every packaged target gets the project icon.
    final icons = p == null ? null : ProjectIconPackaging(projectDir: projectDirPath, project: p);
    return PackageTargetsStep(
        targets: targets,
        reasonsFor: reasonsFor,
        packageDirFor: packageDirFor,
        configuration: _configuration,
        extraFlags: _extraFlags,
        flutterExecutable: flutterExecutable,
        processStarter: _processStarter,
        codeGenerator: _codeGenerator,
        webModule: webModule,
        bundleWebResources: _bundleWebResources,
        beforeBuild: icons?.beforeBuild,
        afterPackage: icons?.afterPackage,
      );
  }

  /// Runs the checked steps, then packages every ticked target in turn.
  Future<BuildStepStatus?> cookAndPackage() {
    if (!cookEnabled) {
      _append('error', 'Cook & Package unavailable: ${cookDisabledReason ?? 'already running'}');
      notifyListeners();
      return Future.value(null);
    }
    return _run(BuildPlan(steps: [..._assetSteps(), _packageStep(selectedTargets)]), packaging: true);
  }

  /// Serves the last web build on localhost and opens it in a browser.
  /// Returns the served URL, or null when there is no web build to show.
  Future<Uri?> launchInBrowser() async {
    final artifact = webPackageDir;
    if (!canLaunchInBrowser || artifact == null) return null;
    final Uri url;
    try {
      url = await _preview.start(artifact);
    } catch (e) {
      _append('error', 'Could not serve $artifact: $e');
      notifyListeners();
      return null;
    }
    _previewUrl = url;
    _append('info', 'Serving $artifact at $url');
    notifyListeners();
    try {
      await (openUrl ?? openInSystemBrowser)(url);
      _append('success', 'Opened $url in the browser');
    } catch (e) {
      _append('error', 'Could not open a browser ($e). Open $url yourself.');
    }
    if (!_disposed) notifyListeners();
    return url;
  }

  /// The platform's "open this URL" command.
  static Future<void> openInSystemBrowser(Uri url) async {
    final (exe, args) = Platform.isMacOS
        ? ('open', [url.toString()])
        : Platform.isWindows
            ? ('cmd', ['/c', 'start', '', url.toString()])
            : ('xdg-open', [url.toString()]);
    await Process.start(exe, args, mode: ProcessStartMode.detached);
  }

  static int _sizeOnDisk(String path) {
    final type = FileSystemEntity.typeSync(path);
    if (type == FileSystemEntityType.file) return File(path).lengthSync();
    if (type != FileSystemEntityType.directory) return 0;
    return Directory(path).listSync(recursive: true).whereType<File>().fold(0, (sum, f) => sum + f.lengthSync());
  }

  void cancel() {
    if (!_isRunning) return;
    _append('warning', 'Cancel requested — stopping after the current asset / killing flutter build');
    _currentStage = 'Cancelling…';
    _token?.cancel();
    notifyListeners();
  }

  Future<BuildStepStatus?> _run(BuildPlan plan, {bool packaging = false}) async {
    if (_isRunning) {
      _append('warning', 'A build is already running');
      notifyListeners();
      return null;
    }
    if (plan.steps.isEmpty) {
      _append('warning', 'No build steps selected');
      notifyListeners();
      return null;
    }
    _isRunning = true;
    _issues.clear();
    _artifactPath = null;
    if (packaging) {
      _targetStates
        ..clear()
        ..addAll({for (final t in selectedTargets) t: const PackageTargetState()});
    }
    // The next build rewrites build/web: stop serving the old one.
    if (_previewUrl != null) {
      _previewUrl = null;
      unawaited(_preview.stop());
    }
    _lastPipelineStatus = null;
    _completedSteps = 0;
    _totalSteps = plan.steps.length;
    _currentStep = null;
    _currentStage = 'Starting…';
    for (final k in BuildStepKind.values) {
      _states[k] = const BuildStepState();
    }
    _elapsed
      ..reset()
      ..start();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) => notifyListeners());
    final token = BuildCancellationToken();
    _token = token;
    _append('info', 'Build started: ${plan.steps.map((s) => s.kind.label).join(' → ')}');
    notifyListeners();

    final completer = Completer<BuildStepStatus?>();
    BuildStepStatus? finalStatus;
    _subscription = _pipeline
        .run(
      plan,
      projectDir: projectDirPath,
      project: project,
      token: token,
      shouldContinue: _shouldContinue,
    )
        .listen((event) {
      _onEvent(event);
      if (event is BuildPipelineFinished) finalStatus = event.status;
    }, onError: (Object e, StackTrace st) {
      _append('error', 'Pipeline error: $e');
      finalStatus = BuildStepStatus.failed;
    }, onDone: () {
      _finish(finalStatus ?? BuildStepStatus.failed);
      if (!completer.isCompleted) completer.complete(finalStatus);
    });
    return completer.future;
  }

  Future<bool> _shouldContinue(BuildStepKind next, Map<BuildStepKind, StepResult> results) async {
    if (next != BuildStepKind.cookAndPackage) return true;
    final validation = results[BuildStepKind.validateAssets];
    if (validation == null || validation.status != BuildStepStatus.failed) return true;
    final confirm = confirmCookOverride ?? confirmCookDespiteValidation;
    if (confirm == null) {
      _append('error', 'Cook & Package skipped: asset validation failed (${_issues.length} issue(s))');
      return false;
    }
    _currentStage = 'Waiting for confirmation (validation failed)…';
    notifyListeners();
    final go = await confirm(List.unmodifiable(_issues));
    if (!go) _append('warning', 'Cook & Package declined after failed validation');
    return go;
  }

  void _onEvent(BuildEvent event) {
    switch (event) {
      case BuildStepStarted(:final kind):
        _currentStep = kind;
        _currentStage = 'Running ${kind.label}…';
        _states[kind] = const BuildStepState(status: BuildStepStatus.running);
      case BuildStepProgress(:final kind, :final label):
        _states[kind] = _states[kind]!.copyWith(progressLabel: label);
        _currentStage = '${kind.label}: $label';
      case BuildLogEvent(:final level, :final message, :final source, :final replaceLast, :final kind):
        if (replaceLast && _log.isNotEmpty && _log.last.source == source) {
          _log[_log.length - 1] = BuildLogLine(at: event.at, level: level, source: source, message: message);
        } else {
          _log.add(BuildLogLine(at: event.at, level: level, source: source, message: message));
        }
        _logger.log(message, level: level, source: logSource);
        if (kind == BuildStepKind.cookAndPackage && !replaceLast && _packagingTarget != null) {
          _currentStage = 'Packaging ${packagingPlatformLabel(_packagingTarget!)}… ($message)';
        }
      case BuildTargetStarted(:final target, :final index, :final count):
        _packagingTarget = target;
        _currentStage = 'Packaging ${packagingPlatformLabel(target)} (${index + 1}/$count)…';
        _targetStates[target] = const PackageTargetState(status: PackageTargetStatus.running);
      case BuildTargetFinished(:final target, :final status, :final message, :final packageDir, :final duration, :final reasons):
        if (_packagingTarget == target) _packagingTarget = null;
        _targetStates[target] = PackageTargetState(
          status: status,
          duration: duration,
          message: message,
          packageDir: packageDir,
          reasons: reasons,
          sizeBytes: packageDir == null ? null : _sizeOnDisk(packageDir),
        );
      case BuildValidationIssue(:final issue):
        _issues.add(issue);
      case BuildStepFinished(:final kind, :final status, :final duration, :final message):
        _completedSteps++;
        _states[kind] = _states[kind]!.copyWith(status: status, duration: duration, message: message);
        _currentStep = null;
      case BuildPipelineFinished(:final status):
        _lastPipelineStatus = status;
        if (status == BuildStepStatus.ok && _targetStates.isNotEmpty) {
          _artifactPath = _packaging.outputDirIn(projectDirPath);
        }
    }
    notifyListeners();
  }

  void _finish(BuildStepStatus status) {
    _ticker?.cancel();
    _ticker = null;
    _elapsed.stop();
    _subscription = null;
    _token = null;
    _isRunning = false;
    _currentStep = null;
    _lastPipelineStatus ??= status;
    _currentStage = switch (_lastPipelineStatus!) {
      BuildStepStatus.ok => 'Build finished in ${_fmt(_elapsed.elapsed)}${_artifactPath != null ? ' — artifact: $_artifactPath' : ''}',
      BuildStepStatus.cancelled => 'Build cancelled after ${_fmt(_elapsed.elapsed)}',
      _ => 'Build failed after ${_fmt(_elapsed.elapsed)}',
    };
    _append(
      switch (_lastPipelineStatus!) {
        BuildStepStatus.ok => 'success',
        BuildStepStatus.cancelled => 'warning',
        _ => 'error',
      },
      _currentStage,
    );
    if (!_disposed) notifyListeners();
  }

  void _append(String level, String message) {
    _log.add(BuildLogLine(at: DateTime.now(), level: level, source: logSource, message: message));
    _logger.log(message, level: level, source: logSource);
  }

  static String _fmt(Duration d) =>
      d.inMilliseconds < 1000 ? '${d.inMilliseconds} ms' : '${(d.inMilliseconds / 1000).toStringAsFixed(1)} s';

  @override
  void dispose() {
    _disposed = true;
    unawaited(_preview.stop());
    _token?.cancel();
    _ticker?.cancel();
    _subscription?.cancel();
    super.dispose();
  }
}
