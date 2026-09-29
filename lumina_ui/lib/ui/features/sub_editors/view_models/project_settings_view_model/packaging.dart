part of '../project_settings_view_model.dart';

/// Packaging: target selection, host toolchain probing, package/cancel and
/// the packaging log.
mixin _ProjectSettingsPackaging on _ProjectSettingsViewModelState {

  // Packaging

  /// Ticks or unticks a packaging platform in the working copy.
  void setTargetSelected(String target, bool selected) =>
      _update((p) => p.copyWith(packaging: p.packaging.withTarget(target, selected)));
  void setOutputDir(String dir) => _update((p) => p.copyWith(packaging: p.packaging.copyWith(outputDir: dir)));

  @override
  HostBuildTargets? get hostTargets => _hostTargets;
  bool get isProbingTargets => _probingTargets;

  /// Runs `flutter doctor -v` once (shared with the Build Manager) so every
  /// target row can say why it cannot be built.
  Future<void> probeTargets() async {
    if (_hostTargets != null || _probingTargets) return;
    _probingTargets = true;
    notifyListeners();
    final probed = _usesRealProcesses ? await HostBuildTargets.shared() : await HostBuildTargets.probe(processStarter: _processStarter);
    _hostTargets = probed;
    _probingTargets = false;
    if (!_disposed) notifyListeners();
  }

  String? _engineReason(String target) => target == 'web'
      ? (webModule == null ? FlutterFilamentWebModule.missingReason : null)
      : HostBuildTargets.engineUnsupportedReason(target);

  /// Why [target] cannot be packaged from this host (host, toolchain,
  /// engine); empty when it can, or while the toolchain is not probed yet.
  List<String> reasonsFor(String target) => _hostTargets?.reasonsFor(target, engineReason: _engineReason) ?? const [];

  List<PackagingLogLine> get packagingLog => List.unmodifiable(_packagingLog);

  /// Where [target]'s package goes with the working copy's output dir.
  String packageDirFor(String target) => project.packaging.packageDirFor(projectDirPath, target);

  /// Why Package Project cannot start, or null.
  String? get packageDisabledReason {
    if (_working == null) return 'No project loaded';
    if (_packaging.isRunning) return 'Packaging is running';
    if (project.packaging.targets.isEmpty) return 'Tick at least one target platform';
    if (_probingTargets) return 'Probing the Flutter toolchain (flutter doctor -v)…';
    final h = _hostTargets;
    if (h != null && !h.flutterAvailable) return h.error ?? 'The Flutter SDK is not available';
    return null;
  }

  /// Packages every ticked target in turn, each into its own
  /// `<output dir>/package/<target>` folder: the game's code is generated
  /// once, targets that cannot be built are reported with their reasons
  /// (never spawned), and the others run a real `flutter build`. Returns the
  /// run's result.
  Future<BuildStepStatus?> packageProject() async {
    if (_working == null || _packaging.isRunning) return null;
    await probeTargets();
    final disabled = packageDisabledReason;
    if (disabled != null) {
      _logger.log('Package Project unavailable: $disabled', level: 'error', source: 'Packaging');
      notifyListeners();
      return null;
    }
    final targets = List<String>.of(project.packaging.targets);
    final token = BuildCancellationToken();
    _packagingToken = token;
    _packagingLog.clear();
    final statuses = {for (final t in targets) t: PackageTargetStatus.pending};
    final durations = <String, Duration>{};
    final dirs = <String, String>{};
    final messages = <String, String>{};
    _packaging = PackagingRunState(isRunning: true, statuses: Map.of(statuses), stage: 'Starting…');
    notifyListeners();
    BuildStepStatus? result;
    String stage = 'Starting…';
    // Every packaged target gets the project icon.
    final icons = ProjectIconPackaging(projectDir: projectDirPath, project: project);
    final step = PackageTargetsStep(
      targets: targets,
      reasonsFor: reasonsFor,
      packageDirFor: packageDirFor,
      processStarter: _processStarter,
      codeGenerator: _codeGenerator,
      webModule: webModule,
      beforeBuild: icons.beforeBuild,
      afterPackage: icons.afterPackage,
    );
    await for (final event in BuildPipelineService().run(BuildPlan(steps: [step]), projectDir: projectDirPath, project: project, token: token)) {
      switch (event) {
        case BuildLogEvent(:final level, :final message, :final source, :final replaceLast):
          final line = PackagingLogLine(at: event.at, level: level, source: source, message: message);
          if (replaceLast && _packagingLog.isNotEmpty && _packagingLog.last.source == source) {
            _packagingLog[_packagingLog.length - 1] = line;
          } else {
            _packagingLog.add(line);
          }
          if (!replaceLast) _logger.log(message, level: level, source: 'Packaging');
        case BuildTargetStarted(:final target, :final index, :final count):
          statuses[target] = PackageTargetStatus.running;
          stage = 'Packaging ${packagingPlatformLabel(target)} (${index + 1}/$count)…';
        case BuildTargetFinished(:final target, :final status, :final duration, :final packageDir, :final message):
          statuses[target] = status;
          durations[target] = duration;
          if (packageDir != null) dirs[target] = packageDir;
          if (status != PackageTargetStatus.ok) messages[target] = message;
        case BuildPipelineFinished(:final status):
          result = status;
        default:
          break;
      }
      _packaging = PackagingRunState(
        isRunning: result == null,
        statuses: Map.of(statuses),
        durations: Map.of(durations),
        packageDirs: Map.of(dirs),
        messages: Map.of(messages),
        result: result,
        stage: result == null ? stage : ProjectSettingsViewModel._finishedStage(result, statuses),
      );
      if (!_disposed) notifyListeners();
    }
    _packagingToken = null;
    _packaging = PackagingRunState(
      statuses: Map.of(statuses),
      durations: Map.of(durations),
      packageDirs: Map.of(dirs),
      messages: Map.of(messages),
      result: result ?? BuildStepStatus.failed,
      stage: ProjectSettingsViewModel._finishedStage(result ?? BuildStepStatus.failed, statuses),
    );
    _logger.log(_packaging.stage!, level: result == BuildStepStatus.ok ? 'success' : 'error', source: 'Packaging');
    if (!_disposed) notifyListeners();
    return result;
  }

  /// Stops the running `flutter build` and every target after it.
  void cancelPackaging() => _packagingToken?.cancel();
}
