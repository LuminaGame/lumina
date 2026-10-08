import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/editor_entry.dart' show appThemeModeNotifier;
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme_data.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme_store.dart';
import 'package:lumina_ui/ui/core/window/lumina_window.dart';
import 'package:lumina_ui/ui/core/window/window_controls.dart';
import 'package:lumina_ui/ui/core/host/editor_host.dart';
import 'package:lumina_ui/ui/features/launcher/services/project_editor_resolver.dart';
import 'package:lumina_ui/ui/features/launcher/services/project_editor_update.dart';
import 'package:lumina_ui/ui/features/launcher/views/editor_build_splash.dart';
import 'package:lumina_ui/ui/features/launcher/views/lumina_splash_screen.dart';
import 'package:lumina_ui/ui/features/launcher/views/missing_editor_binary_dialog.dart';
import 'package:lumina_ui/ui/features/launcher/views/project_editor_update_dialog.dart';
import 'package:lumina_ui/ui/features/launcher/view_models/launcher_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/launcher/views/create_project_dialog.dart';
import 'package:lumina_ui/ui/features/launcher/views/launcher_recent_projects_pane.dart';
import 'package:lumina_ui/ui/features/launcher/views/launcher_settings_panes.dart';
import 'package:lumina_ui/ui/features/launcher/views/launcher_templates_pane.dart';
import 'package:lumina_ui/ui/features/launcher/views/pending_model_import_banner.dart';
import 'package:lumina_ui/ui/features/launcher/view_models/create_project_view_model.dart';

class LauncherView extends StatefulWidget {
  final LauncherViewModel? viewModel;

  /// `--project <dir>` — open this project as soon as the
  /// launcher is up, through the same resolver as Open.
  final String? initialProjectDir;

  /// Builds the editor an Open lands in (default: [MainEditorView]); tests
  /// pass one with a view model they control.
  final Widget Function(LuminaProject project, String? projectLocation, String? startupWarning)? editorBuilder;

  /// Explicitly control whether startup splash is shown (in tests defaults to false
  /// unless initialProjectDir != null; in normal desktop execution defaults to true).
  final bool? showStartupSplash;

  const LauncherView({
    super.key,
    this.viewModel,
    this.initialProjectDir,
    this.editorBuilder,
    this.showStartupSplash,
  });

  @override
  State<LauncherView> createState() => _LauncherViewState();
}

class _LauncherViewState extends State<LauncherView> {
  late final LauncherViewModel _viewModel;
  late bool _loadingInitialProject;
  String _initialLoadingStatus = 'Opening project…';
  double? _initialLoadingProgress = 0.20;
  String? _startupError;

  late bool _loadingLauncher;
  String _launcherLoadingStatus = 'Scanning projects…';
  double? _launcherLoadingProgress = 0.25;

  LuminaProject? _openingProject;
  String _openingProjectStatus = 'Opening project…';
  double? _openingProjectProgress = 0.30;

  @override
  void initState() {
    super.initState();
    _viewModel = widget.viewModel ?? LauncherViewModel();
    _viewModel.addListener(_onViewModelChanged);
    _loadingInitialProject = widget.initialProjectDir != null;

    final isTest = Platform.environment['FLUTTER_TEST'] == 'true';
    _loadingLauncher = widget.initialProjectDir == null &&
        (widget.showStartupSplash ?? !isTest);

    // The stock editor tells project editors started on their own which
    // Studio (and engine) this machine runs now.
    if (!LuminaEditorHost.isProjectEditor) unawaited(LuminaStudioRecord.recordThisStudio(configDir: _viewModel.configDir));
    final initial = widget.initialProjectDir;
    if (initial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openInitialProject(initial));
    } else if (_loadingLauncher) {
      _startLauncherLoading();
    }
  }

  Future<void> _startLauncherLoading() async {
    setState(() {
      _launcherLoadingStatus = 'Scanning projects…';
      _launcherLoadingProgress = 0.35;
    });

    try {
      _viewModel.refreshInstalledTemplates();
      await _viewModel.loadRecentProjects();
    } catch (_) {
      // Continue even if initial refresh encounters issues
    }

    if (!mounted) return;
    setState(() {
      _launcherLoadingStatus = 'Loading workspace…';
      _launcherLoadingProgress = 0.70;
    });

    final isTest = Platform.environment['FLUTTER_TEST'] == 'true';
    if (!isTest) {
      await Future<void>.delayed(const Duration(milliseconds: 700));
    }

    if (!mounted) return;
    setState(() {
      _launcherLoadingStatus = '100% - Ready';
      _launcherLoadingProgress = 1.0;
    });

    if (!isTest) {
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }

    if (!mounted) return;
    setState(() {
      _loadingLauncher = false;
    });
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);
    if (widget.viewModel == null) {
      _viewModel.dispose();
    }
    super.dispose();
  }

  void _onViewModelChanged() {
    if (appThemeModeNotifier.value != _viewModel.themeMode) {
      appThemeModeNotifier.value = _viewModel.themeMode;
    }
    if (mounted) {
      setState(() {});
    }
  }


  void _openMainEditor(
    BuildContext context, {
    required LuminaProject project,
    String? projectDir,
    String? startupWarning,
  }) {
    // [projectDir] is the project folder; EditorViewModel wants its parent, so
    // the editor opens the real folder on disk instead of falling back to
    // ~/Lumina Projects/<name>.
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, _, _) {
          final location = projectDir == null ? null : Directory(projectDir).parent.path;
          return widget.editorBuilder?.call(project, location, startupWarning) ??
              MainEditorView(project: project, projectLocation: location, startupWarning: startupWarning);
        },
      ),
    );
  }

  // --- Every Open goes through the project editor resolver ------

  /// "Checking project editor…" while the resolver runs.
  bool _resolving = false;

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

  @override
  Widget build(BuildContext context) {
    // The switch shows and sets the editor theme's
    // brightness — Lumina Light, or back to Lumina Dark.
    final themes = EditorThemeScope.of(context);
    final isDark = themes.active.brightness == Brightness.dark;

    if (_loadingInitialProject) {
      return _buildProjectLoadingScreen(context);
    }
    if (_loadingLauncher) {
      return _buildLauncherLoadingScreen(context);
    }
    if (_openingProject != null) {
      return _buildOpeningProjectScreen(context);
    }

    final launcher = Scaffold(
      child: Container(
        color: EditorColors.background,
        child: Column(
          children: [
            // Top App Header
            // the header is the window's title bar —
            // drag to move, double-click to maximize, window buttons at the
            // right end.
            Container(
              height: 52,
              padding: EdgeInsets.only(left: 20 + LuminaWindow.leadingInset),
              decoration: const BoxDecoration(
                color: EditorColors.cardHeader,
                border: Border(bottom: BorderSide(color: EditorColors.border)),
              ),
              child: Row(
                children: [
                  Image.asset(
                    isDark ? 'assets/logo_white.png' : 'assets/logo_black.png',
                    height: 52,
                    errorBuilder: (ctx, _, _) => const Icon(
                      LucideIcons.box,
                      size: 24,
                      color: EditorColors.primary,
                    ),
                  ),

                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2.5,
                    ),
                    decoration: BoxDecoration(
                      color: EditorColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: EditorColors.primary.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      _viewModel.engineDisplayVersion,
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        fontFamily: EditorTypography.monoFamily,
                        color: EditorColors.primary,
                      ),
                    ),
                  ),
                  const Expanded(
                    child: WindowDragArea(key: ValueKey('launcher_title_drag_area')),
                  ),
                  // Theme Mode Switcher
                  Row(
                    children: [
                      Icon(
                        isDark ? LucideIcons.moon : LucideIcons.sun,
                        size: 14,
                        color: isDark ? EditorColors.primary : Colors.amber,
                      ),
                      const SizedBox(width: 8),
                      Switch(
                        value: isDark,
                        onChanged: (val) {
                          _viewModel.toggleTheme(val);
                          themes.activate(val ? EditorThemeData.luminaDark.name : EditorThemeData.luminaLight.name);
                        },
                      ),
                    ],
                  ),
                  SizedBox(width: LuminaWindow.drawsOwnControls ? 16 : 20),
                  const LuminaWindowControls(height: 52),
                ],
              ),
            ),

            if (_startupError != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                color: EditorColors.destructive.withValues(alpha: 0.15),
                child: Row(
                  children: [
                    Icon(LucideIcons.triangleAlert, size: 16, color: EditorColors.destructive),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _startupError!,
                        style: const TextStyle(fontSize: 12, color: EditorColors.destructive),
                      ),
                    ),
                    IconButton.ghost(
                      density: ButtonDensity.compact,
                      icon: const Icon(LucideIcons.x, size: 14),
                      onPressed: () => setState(() => _startupError = null),
                    ),
                  ],
                ),
              ),

            // Model files from "Open with" wait for a project.
            const PendingModelImportBanner(),

            // Main Content Area with Left Navigation Bar & Center Pane
            Expanded(
              child: Row(
                children: [
                  // Left Navigation Sidebar
                  Container(
                    width: 220,
                    decoration: const BoxDecoration(
                      color: EditorColors.cardHeader,
                      border: Border(
                        right: BorderSide(color: EditorColors.border),
                      ),
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 12),
                        _buildNavButton(
                          0,
                          'Recent Projects',
                          LucideIcons.clock,
                        ),
                        _buildNavButton(
                          1,
                          'Templates',
                          LucideIcons.layoutTemplate,
                        ),
                        _buildNavButton(2, 'Engine Versions', LucideIcons.cpu),
                        _buildNavButton(3, 'Settings', LucideIcons.settings),
                        const Spacer(),
                        // Sidebar Footer
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Image.asset(
                                isDark ? 'assets/logo_white.png' : 'assets/logo_black.png',
                                height: 20,
                                errorBuilder: (ctx, _, _) => const Icon(
                                  LucideIcons.box,
                                  size: 16,
                                  color: EditorColors.mutedForeground,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Lumina Engine ${_viewModel.engineVersion}',
                                  style: const TextStyle(
                                    fontSize: 9,
                                    color: EditorColors.mutedForeground,
                                    fontFamily: EditorTypography.monoFamily,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Center Selected Tab Content Pane
                  Expanded(
                    child: IndexedStack(
                      index: _viewModel.selectedTabIndex,
                      children: [
                        LauncherRecentProjectsPane(
                          viewModel: _viewModel,
                          onOpenProject: (project, dir) => _openProject(project, dir),
                          onNewProject: () => _showNewProjectDialog(context),
                        ),
                        LauncherTemplatesPane(
                          viewModel: _viewModel,
                          onUseTemplate: (id) => _showNewProjectDialog(context, initialTemplate: id),
                        ),
                        LauncherEngineVersionsPane(viewModel: _viewModel),
                        LauncherSettingsPane(viewModel: _viewModel),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Action Bar
            Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              decoration: const BoxDecoration(
                color: EditorColors.cardHeader,
                border: Border(top: BorderSide(color: EditorColors.border)),
              ),
              child: Row(
                children: [
                  OutlineButton(
                    onPressed: () => _handleOpenExternal(context),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.folderOpen, size: 14),
                        SizedBox(width: 8),
                        Text('Open External...'),
                      ],
                    ),
                  ),
                  const Spacer(),
                  PrimaryButton(
                    onPressed: () => _showNewProjectDialog(context),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.plus, size: 14),
                        SizedBox(width: 8),
                        Text('New Project...'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (!_resolving) return launcher;
    // The resolver hashes the plugins and the engine revision
    // before a project opens.
    return Stack(children: [
      launcher,
      Positioned.fill(
        child: ColoredBox(
          color: EditorColors.background.withValues(alpha: 0.6),
          child: const Center(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              CircularProgressIndicator(size: 16),
              SizedBox(width: 10),
              Text('Checking project editor…', key: Key('launcher_resolving'), style: TextStyle(fontSize: 12, color: EditorColors.foreground)),
            ]),
          ),
        ),
      ),
    ]);
  }

  Widget _buildNavButton(int index, String label, IconData icon) {
    final isSelected = _viewModel.selectedTabIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      child: GestureDetector(
        onTap: () => _viewModel.setTab(index),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: isSelected
                ? EditorColors.primary.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: isSelected
                ? Border.all(color: EditorColors.primary.withValues(alpha: 0.5))
                : null,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected
                    ? EditorColors.primary
                    : EditorColors.mutedForeground,
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected
                      ? EditorColors.primary
                      : EditorColors.foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Future<void> _handleOpenExternal(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['lmproject'],
    );
    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      final loaded = await _viewModel.openExternal(path);
      if (loaded != null && context.mounted) {
        await _openProject(loaded, File(path).parent.path);
      }
    }
  }


  void _showNewProjectDialog(BuildContext context, {String? initialTemplate}) {
    // Templates installed since the launcher opened.
    _viewModel.refreshInstalledTemplates();
    showOverlay(
      context,
      const DialogConfiguration(),
      builder: (ctx) {
        final createVM = CreateProjectViewModel(
          launcherVM: _viewModel,
          projectRepo: _viewModel.projectRepo,
        );
        if (initialTemplate != null) {
          createVM.updateTemplate(initialTemplate);
        }
        return CreateProjectDialog(
          viewModel: createVM,
          onSuccess: () {
            if (createVM.activeProject != null) {
              _openProject(createVM.activeProject!, '${createVM.location}/${createVM.name}');
            }
          },
        );
      },
    );
  }

  Widget _buildProjectLoadingScreen(BuildContext context) {
    final projectName = widget.initialProjectDir != null
        ? (EditorHostGeneratorService.projectNameIn(widget.initialProjectDir!) ?? p.basename(widget.initialProjectDir!))
        : 'Project';

    final manageWindow = EditorBuildSplash.manageNativeWindow && Platform.environment['FLUTTER_TEST'] != 'true';

    return LuminaSplashScreen(
      splashKey: const Key('project_loading_splash'),
      title: 'Lumina Studio',
      subtitle: 'Lumina Editor ${_viewModel.engineDisplayVersion} · $projectName',
      statusText: _initialLoadingStatus,
      statusKey: const Key('initial_project_loading_status'),
      progress: _initialLoadingProgress,
      progressBarKey: const Key('initial_project_loading_progress_bar'),
      manageWindow: manageWindow,
      alwaysShowActions: true,
      onCancel: () {
        setState(() {
          _loadingInitialProject = false;
        });
      },
      cancelLabel: 'Cancel to Projects',
      cancelKey: const Key('initial_project_loading_cancel'),
    );
  }

  Widget _buildLauncherLoadingScreen(BuildContext context) {
    final manageWindow = EditorBuildSplash.manageNativeWindow && Platform.environment['FLUTTER_TEST'] != 'true';

    return LuminaSplashScreen(
      splashKey: const Key('launcher_loading_splash'),
      title: 'Lumina Studio',
      subtitle: 'Lumina Editor ${_viewModel.engineDisplayVersion}',
      statusText: _launcherLoadingStatus,
      statusKey: const Key('launcher_loading_status'),
      progress: _launcherLoadingProgress,
      progressBarKey: const Key('launcher_loading_progress_bar'),
      manageWindow: manageWindow,
      alwaysShowActions: true,
      onCancel: () {
        setState(() {
          _loadingLauncher = false;
        });
      },
      cancelLabel: 'Open Projects',
      cancelKey: const Key('launcher_loading_skip'),
    );
  }

  Widget _buildOpeningProjectScreen(BuildContext context) {
    final manageWindow = EditorBuildSplash.manageNativeWindow && Platform.environment['FLUTTER_TEST'] != 'true';
    final project = _openingProject!;

    return LuminaSplashScreen(
      splashKey: const Key('opening_project_splash'),
      title: 'Lumina Studio',
      subtitle: 'Lumina Editor ${_viewModel.engineDisplayVersion} · ${project.projectName}',
      statusText: _openingProjectStatus,
      statusKey: const Key('opening_project_status'),
      progress: _openingProjectProgress,
      progressBarKey: const Key('opening_project_progress_bar'),
      manageWindow: manageWindow,
      alwaysShowActions: true,
      onCancel: () {
        setState(() {
          _openingProject = null;
          _resolving = false;
        });
      },
      cancelLabel: 'Cancel',
      cancelKey: const Key('opening_project_cancel'),
    );
  }
}