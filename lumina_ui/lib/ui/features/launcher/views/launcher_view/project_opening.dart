part of '../launcher_view.dart';

/// Opening projects: the initial `--project`, the project editor resolver,
/// the build splash and the self-check before a rebuild.
mixin _LauncherProjectOpening on _LauncherViewStateBase {
  void _openMainEditor(
    BuildContext context, {
    required LuminaProject project,
    String? projectDir,
    String? startupWarning,
  }) {
    // [projectDir] is the project folder the editor edits as it is, whatever
    // it is called (a copied, cloned or renamed project need not be named
    // after the project); without one the editor falls back to
    // ~/Lumina Projects/<name>.
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, _, _) =>
            widget.editorBuilder?.call(project, projectDir, startupWarning) ??
            MainEditorView(project: project, projectDir: projectDir, startupWarning: startupWarning),
      ),
    );
  }

  // --- Every Open goes through the project editor resolver ------

  /// `--project <dir>`: open it as soon as the launcher is up.
  Future<void> _openInitialProject(String dir) async {
    final name = EditorHostGeneratorService.projectNameIn(dir);
    if (name == null) {
      if (mounted) {
        setState(() {
          _loadingInitialProject = false;
          _startupError = 'Could not find a project in "$dir".';
        });
      }
      return;
    }
    setState(() {
      _initialLoadingStatus = 'Opening $name…';
      _initialLoadingProgress = 0.35;
    });
    LuminaProject? loaded;
    try {
      loaded = await _viewModel.openExternal(p.join(dir, '$name.lmproject'));
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingInitialProject = false;
          _startupError = 'Could not load project "$name": $e';
        });
      }
      return;
    }
    if (loaded == null || !mounted) {
      if (mounted) {
        setState(() {
          _loadingInitialProject = false;
          _startupError = 'Could not open project "$name".';
        });
      }
      return;
    }
    setState(() {
      _initialLoadingStatus = 'Checking project editor…';
      _initialLoadingProgress = 0.60;
    });
    await _openProject(loaded, dir, rebuild: LuminaEditorHost.args.rebuild, updateEditor: LuminaEditorHost.args.updateEditor);
  }

  static String _inactivePluginsWarning(List<String> names) =>
      'Code plugins inactive in this session: ${names.join(', ')}. Reopen the project from the launcher and build its '
      'editor to use them.';

  /// [updateEditor]: a project editor handed the project over after the
  /// user chose Update there; its editor is updated without asking again.
  Future<void> _openProject(LuminaProject project, String projectDir, {bool rebuild = false, bool updateEditor = false}) async {
    // A project editor opens its own project (after checking it is not
    // stale); `--no-plugins` opens any project in this binary.
    if (LuminaEditorHost.isProjectEditor) return _selfCheckThenOpen(project, projectDir);
    if (LuminaEditorHost.args.noPlugins) {
      final plugins = await _viewModel.editorResolver.enabledCodePlugins(projectDir);
      if (!mounted) return;
      return _openMainEditor(context,
          project: project,
          projectDir: projectDir,
          startupWarning: plugins.isEmpty ? null : _inactivePluginsWarning([for (final d in plugins) d.name]));
    }

    if (!_loadingInitialProject) {
      setState(() {
        _openingProject = project;
        _openingProjectStatus = 'Checking project editor…';
        _openingProjectProgress = 0.40;
      });
    } else {
      setState(() {
        _initialLoadingStatus = 'Checking project editor…';
        _initialLoadingProgress = 0.60;
      });
    }

    setState(() => _resolving = true);
    ProjectEditorDecision decision;
    String? fallbackWarning;
    // Whether the resolver itself chose to open in place (per-project
    // editors off, no code plugins), not a fallback after an error.
    var resolvedInPlace = false;
    // The project's editor comes from another engine than this Studio's.
    EditorEngineUpdate? update;
    try {
      decision = await _viewModel.resolveProjectEditor(projectDir, rebuild: rebuild);
      resolvedInPlace = decision is OpenInPlace;
      if (decision is ExecCached || decision is NeedsBuild) {
        try {
          update = await _viewModel.projectEditorUpdate(projectDir);
        } catch (e) {
          // The project still opens with the editor it has.
          EngineLoggerService().log('Could not compare the project editor of $projectDir with this Studio: $e',
              level: 'warning', source: 'Launcher');
        }
      }
    } catch (e) {
      // No Flutter on PATH, an unreadable plugin: the project still opens.
      List<LuminaPluginDescriptor> plugins;
      try {
        plugins = await _viewModel.editorResolver.enabledCodePlugins(projectDir);
      } catch (_) {
        plugins = const [];
      }
      decision = plugins.isEmpty ? const OpenInPlace() : MissingBinary("Could not check this project's editor: $e", plugins);
      // Say why a project that would have its own editor opened here.
      if (plugins.isEmpty && _viewModel.editorResolver.everyProject) {
        fallbackWarning = "Could not build this project's editor ($e); it opened in this editor.";
      }
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
    if (!mounted) return;
    if (update != null) {
      final answer = updateEditor
          ? const ProjectEditorUpdateAnswer(ProjectEditorUpdateChoice.update)
          : await ProjectEditorUpdateDialog.show(context,
              projectName: project.projectName, fromLabel: update.fromLabel, toLabel: update.toLabel);
      if (!mounted) return;
      switch (answer.choice) {
        case ProjectEditorUpdateChoice.cancel:
          if (_loadingInitialProject) setState(() => _loadingInitialProject = false);
          if (_openingProject != null) setState(() => _openingProject = null);
          return;
        case ProjectEditorUpdateChoice.update:
          final plugins = decision is NeedsBuild ? decision.plugins : await _viewModel.editorResolver.enabledCodePlugins(projectDir);
          if (!mounted) return;
          return _showBuildSplash(project, projectDir, plugins, update: update);
        case ProjectEditorUpdateChoice.openWithOldEditor:
          if (answer.dontAskAgain) _viewModel.dismissProjectEditorUpdate(projectDir, update);
      }
    }
    switch (decision) {
      case OpenInPlace():
        // No copy of the engine to update: the project now belongs to this
        // Studio's version.
        if (_loadingInitialProject) {
          setState(() {
            _initialLoadingStatus = '100% - Ready';
            _initialLoadingProgress = 1.0;
          });
        } else if (_openingProject != null) {
          setState(() {
            _openingProjectStatus = '100% - Ready';
            _openingProjectProgress = 1.0;
          });
        }
        final opened = resolvedInPlace ? await _viewModel.recordEngineVersion(project, projectDir) : project;
        if (!mounted) return;
        _openMainEditor(context, project: opened, projectDir: projectDir, startupWarning: fallbackWarning);
      case ExecCached(:final entry):
        if (_loadingInitialProject) {
          setState(() {
            _initialLoadingStatus = 'Starting project editor…';
            _initialLoadingProgress = 0.90;
          });
        } else if (_openingProject != null) {
          setState(() {
            _openingProjectStatus = 'Starting project editor…';
            _openingProjectProgress = 0.90;
          });
        }
        try {
          await _viewModel.execProjectEditor(entry.executable, projectDir);
        } catch (e) {
          if (mounted) {
            setState(() {
              _loadingInitialProject = false;
              _openingProject = null;
              _startupError = 'Could not launch project editor: $e';
            });
          }
        }
      case NeedsBuild(:final plugins):
        _showBuildSplash(project, projectDir, plugins);
      case MissingBinary(:final reason, :final plugins, :final pluginNames):
        final choice = await MissingEditorBinaryDialog.show(context,
            projectName: project.projectName, pluginNames: pluginNames, reason: reason);
        if (!mounted) return;
        switch (choice) {
          case MissingBinaryChoice.buildAndOpen:
            _showBuildSplash(project, projectDir, plugins);
          case MissingBinaryChoice.openWithoutPlugins:
            _openMainEditor(context, project: project, projectDir: projectDir, startupWarning: _inactivePluginsWarning(pluginNames));
          case MissingBinaryChoice.cancel:
            if (_loadingInitialProject) setState(() => _loadingInitialProject = false);
            if (_openingProject != null) setState(() => _openingProject = null);
            break;
        }
    }
  }

  /// [update]: the splash first replaces the project's copy of the engine
  /// source with this Studio's.
  void _showBuildSplash(LuminaProject project, String projectDir, List<LuminaPluginDescriptor> plugins, {EditorEngineUpdate? update}) {
    if (_openingProject != null) setState(() => _openingProject = null);
    final build = _viewModel.projectEditorBuild(project.projectName, projectDir, plugins, update: update);
    // With a native window the splash resizes it to 720×400; in tests it is
    // drawn at that size in the middle of the test window.
    final manageWindow = EditorBuildSplash.manageNativeWindow && Platform.environment['FLUTTER_TEST'] != 'true';
    Navigator.of(context)
        .push(
          PageRouteBuilder(
            pageBuilder: (routeContext, _, _) {
              final splash = EditorBuildSplash(
                viewModel: build,
                manageWindow: manageWindow,
                onSucceeded: (vm) {
                  final outcome = vm.outcome;
                  if (outcome is EditorBuildSucceeded) {
                    _viewModel.execProjectEditor(outcome.entry.executable, projectDir).catchError((e) {
                      if (mounted) {
                        setState(() {
                          _loadingInitialProject = false;
                          _openingProject = null;
                          _startupError = 'Could not start project editor: $e';
                        });
                        if (routeContext.mounted) Navigator.of(routeContext).pop();
                      }
                    });
                  }
                },
                onOpenWithoutPlugins: () {
                  Navigator.of(routeContext).pop();
                  _openMainEditor(context,
                      project: project,
                      projectDir: projectDir,
                      startupWarning: plugins.isEmpty
                          ? "This project's editor did not build; it opened in this editor (see the build log)."
                          : _inactivePluginsWarning([for (final d in plugins) d.name]));
                },
                onClose: () {
                  Navigator.of(routeContext).pop();
                  if (mounted && _loadingInitialProject) {
                    setState(() => _loadingInitialProject = false);
                  }
                  if (mounted && _openingProject != null) {
                    setState(() => _openingProject = null);
                  }
                },
              );
              return manageWindow
                  ? splash
                  : ColoredBox(
                      color: EditorColors.background,
                      child: Center(child: SizedBox.fromSize(size: EditorBuildSplash.windowSize, child: splash)),
                    );
            },
          ),
        )
        .whenComplete(build.dispose);
  }

  /// A project editor started on its own (desktop shortcut, `flutter run`)
  /// first asks to update to a newer Lumina Studio on this machine (the last
  /// one that started, see [LuminaStudioRecord]) through that Studio, then
  /// checks its compiled-in fingerprint against the project's current
  /// inputs; a stale one offers to rebuild through the launcher.
  Future<void> _selfCheckThenOpen(LuminaProject project, String projectDir) async {
    // Started by a launcher (`--launcher-exe`), the launcher already asked.
    final studio = LuminaEditorHost.args.launcherExe == null ? LuminaStudioRecord.read(configDir: _viewModel.configDir) : null;
    EditorEngineUpdate? update;
    if (studio != null &&
        File(studio.executable).existsSync() &&
        !p.equals(p.normalize(studio.executable), p.normalize(Platform.resolvedExecutable))) {
      try {
        // The engine that Studio recorded when it last started.
        update = await _viewModel.editorResolver.engineUpdate(projectDir, engineRoot: studio.engineRoot, current: studio.engine);
        if (update != null && _viewModel.updatePrompts.isDismissed(projectDir, update.current)) update = null;
      } catch (_) {
        update = null;
      }
    }
    if (!mounted) return;
    if (update != null) {
      final answer = await ProjectEditorUpdateDialog.show(context,
          projectName: project.projectName, fromLabel: update.fromLabel, toLabel: update.toLabel);
      if (!mounted) return;
      switch (answer.choice) {
        case ProjectEditorUpdateChoice.update:
          await EditorHandOff.instance.restartThroughLauncher(projectDir, updateEditor: true, launcher: studio!.executable);
          return;
        case ProjectEditorUpdateChoice.cancel:
          await EditorHandOff.instance.returnToLauncher(launcher: studio!.executable);
          if (mounted && _loadingInitialProject) setState(() => _loadingInitialProject = false);
          return;
        case ProjectEditorUpdateChoice.openWithOldEditor:
          if (answer.dontAskAgain) _viewModel.dismissProjectEditorUpdate(projectDir, update);
      }
    }
    if (!mounted) return;
    List<String> reasons;
    try {
      reasons = await _viewModel.editorResolver.staleSelfCheck(projectDir, LuminaEditorHost.compiledFingerprint);
    } catch (_) {
      reasons = const [];
    }
    if (!mounted) return;
    if (reasons.isEmpty) return _openMainEditor(context, project: project, projectDir: projectDir);
    final rebuild = await showOverlay<bool>(
      context,
      const DialogConfiguration(),
      builder: (ctx) => AlertDialog(
        key: const Key('stale_project_editor_dialog'),
        title: const Text('Project editor out of date'),
        content: Text("This project's editor is out of date (${reasons.join(', ')}). Rebuild now?"),
        actions: [
          OutlineButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Continue anyway')),
          PrimaryButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Rebuild')),
        ],
      ),
    ).future;
    if (!mounted) return;
    if (rebuild == true) {
      await EditorHandOff.instance.restartThroughLauncher(projectDir, rebuild: true);
      return;
    }
    _openMainEditor(context,
        project: project,
        projectDir: projectDir,
        startupWarning: 'This project editor is out of date (${reasons.join(', ')}); continuing with the old build.');
  }
}
