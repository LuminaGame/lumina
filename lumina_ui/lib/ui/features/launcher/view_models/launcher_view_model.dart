import 'dart:convert';
import 'dart:io';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_editor_data/lumina_editor.dart';

import 'package:lumina_ui/ui/core/host/editor_host.dart';
import 'package:lumina_ui/ui/features/main_editor/services/editor_preferences.dart';
import 'package:lumina_ui/ui/features/launcher/services/installed_template_repository.dart';
import 'package:lumina_ui/ui/features/launcher/services/project_editor_resolver.dart';
import 'package:lumina_ui/ui/features/launcher/services/project_editor_update.dart';
import 'package:lumina_ui/ui/features/launcher/view_models/editor_build_view_model.dart';

/// Maps a [GameTemplate.icon] hint to the launcher's Lucide icon.
const Map<String, IconData> kLauncherTemplateIcons = {
  'box': LucideIcons.box,
  'eye': LucideIcons.eye,
  'user': LucideIcons.user,
};

class LauncherTemplate {
  final String id;
  final String title;
  final String description;
  final IconData icon;

  const LauncherTemplate({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
  });
}

class LauncherViewModel extends ChangeNotifier {
  final ProjectRepository _projectRepo;
  final EngineLoggerService _logger = EngineLoggerService();
  final Directory? configDir;

  static String get defaultProjectsDir =>
      '${Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? ''}/Lumina Projects';

  int _selectedTabIndex = 0;
  ThemeMode _themeMode = ThemeMode.dark;
  String _defaultProjectsDirectory = defaultProjectsDir;
  List<RecentProjectEntry> _allRecentProjects = [];
  bool _showMissingProjects = false;
  bool _isLoading = false;
  final bool _isCreating = false;
  String _projectName = 'MyFirstLuminaGame';
  String _projectPath = defaultProjectsDir;
  LuminaProject? _activeProject;

  int get selectedTabIndex => _selectedTabIndex;
  ThemeMode get themeMode => _themeMode;
  ProjectRepository get projectRepo => _projectRepo;

  String get defaultProjectsDirectory => _defaultProjectsDirectory;
  /// The projects the launcher offers. Entries whose path cannot be found are
  /// left out unless [showMissingProjects] is on, so a fresh launch does not
  /// present rows that cannot open.
  List<RecentProjectEntry> get recentProjects => _showMissingProjects
      ? _allRecentProjects
      : _allRecentProjects.where((entry) => !entry.isMissing).toList();

  /// Every recorded project, including unreachable ones.
  List<RecentProjectEntry> get allRecentProjects => List.unmodifiable(_allRecentProjects);

  /// How many recorded projects cannot be found on disk. They stay in
  /// `recent_projects.json` — a drive that is not mounted today may be back
  /// tomorrow, and dropping someone's history is worse than a stale row — and
  /// stay reachable through [showMissingProjects], which is where the `Missing`
  /// badge and its `Locate…` repair action live.
  int get missingProjectCount => _allRecentProjects.where((e) => e.isMissing).length;

  /// Whether unreachable projects are listed alongside the reachable ones.
  bool get showMissingProjects => _showMissingProjects;

  void setShowMissingProjects(bool value) {
    if (_showMissingProjects == value) return;
    _showMissingProjects = value;
    notifyListeners();
  }
  bool get isLoading => _isLoading;
  bool get isCreating => _isCreating;
  String get projectName => _projectName;
  String get projectPath => _projectPath;
  LuminaProject? get activeProject => _activeProject;

  String get engineVersion => kLuminaEngineVersion;
  /// The release tag in a release build, else the source version.
  String get engineDisplayVersion => LuminaRelease.isRelease ? LuminaRelease.version : kLuminaEngineDisplayVersion;

  /// The launcher's template list, derived from the shared
  /// [GameTemplateCatalog] so the chips, the Templates pane and the scaffolder
  /// can never drift apart. Only the icon is a UI concern.
  final List<LauncherTemplate> templates = List.unmodifiable(
    GameTemplateCatalog.all.map(
      (t) => LauncherTemplate(
        id: t.id,
        title: t.title,
        description: t.description,
        icon: kLauncherTemplateIcons[t.icon] ?? LucideIcons.box,
      ),
    ),
  );

  /// The game templates installed under
  /// `<config>/templates/` (from the Marketplace, or copied in by hand),
  /// offered after the built-in [templates].
  late final InstalledTemplateRepository installedTemplateRepo =
      InstalledTemplateRepository.forConfigDir(resolvedConfigDir);

  List<InstalledGameTemplate> _installedTemplates = const [];
  List<InstalledGameTemplate> get installedTemplates => _installedTemplates;

  /// Rescans the templates folder (an install from the Marketplace window,
  /// a folder copied in); invalid folders are reported in the Output Log.
  void refreshInstalledTemplates() {
    _installedTemplates = installedTemplateRepo.scan();
    notifyListeners();
  }

  /// Removes a Marketplace template (its folder and licenses.json entry).
  bool uninstallTemplate(InstalledGameTemplate template) {
    final ok = installedTemplateRepo.uninstall(template);
    refreshInstalledTemplates();
    return ok;
  }

  /// The environment a GPU override is read from (`FILAMENT_GPU`,
  /// `VK_DEVICE_INDEX`); the process environment unless a test passes one.
  final Map<String, String>? environment;

  String? _graphicsDevice;
  List<LuminaGraphicsDevice>? _graphicsDevices;

  /// The saved GPU name; null for Automatic.
  String? get graphicsDevice => _graphicsDevice;

  /// The Vulkan devices on this machine, enumerated once per launcher.
  List<LuminaGraphicsDevice> get graphicsDevices => _graphicsDevices ??= LuminaGraphicsDevices.list();

  /// `FILAMENT_GPU=…` / `VK_DEVICE_INDEX=…` when the environment chooses the
  /// GPU instead of the saved setting.
  String? get graphicsDeviceOverride =>
      LuminaGraphicsDevices.describeOverride(environment ?? Platform.environment);

  /// A saved name that no longer matches a device (driver or hardware
  /// change): kept, but Automatic is used until the device returns.
  bool get graphicsDeviceIsStale {
    final saved = _graphicsDevice;
    return saved != null && !graphicsDevices.any((d) => d.name.contains(saved));
  }

  /// Saves [deviceName] (null or '' for Automatic) and makes it the GPU of
  /// every engine created from now on.
  Future<void> setGraphicsDevice(String? deviceName) async {
    _graphicsDevice = deviceName == null || deviceName.isEmpty ? null : deviceName;
    _applyGraphicsDevice();
    await saveSettings();
    notifyListeners();
  }

  void _applyGraphicsDevice() => LuminaGraphicsDevices.usePreferred(
        _graphicsDevice == null || graphicsDeviceIsStale ? null : _graphicsDevice,
        environment: environment,
      );

  LauncherViewModel({
    ProjectRepository? projectRepo,
    this.configDir,
    this.environment,
    this._editorResolver,
    this._buildServiceFactory,
  }) : _projectRepo = projectRepo ?? ProjectRepository(configDir: configDir) {
    loadSettings();
    loadRecentProjects();
    refreshInstalledTemplates();
  }

  Directory get resolvedConfigDir => _projectRepo.resolvedConfigDir;

  File get _settingsFile => File('${resolvedConfigDir.path}/launcher_settings.json');

  Future<void> loadSettings() async {
    try {
      final file = _settingsFile;
      if (file.existsSync()) {
        final content = file.readAsStringSync();
        if (content.trim().isNotEmpty) {
          final map = jsonDecode(content) as Map<String, dynamic>;
          final modeStr = map['theme_mode'] as String?;
          if (modeStr == 'light') {
            _themeMode = ThemeMode.light;
          } else if (modeStr == 'system') {
            _themeMode = ThemeMode.system;
          } else {
            _themeMode = ThemeMode.dark;
          }

          final dirStr = map['default_projects_dir'] as String?;
          if (dirStr != null && dirStr.isNotEmpty) {
            _defaultProjectsDirectory = dirStr;
            _projectPath = dirStr;
          }
          final gpu = map['graphics_device'] as String?;
          _graphicsDevice = gpu == null || gpu.isEmpty ? null : gpu;
          notifyListeners();
        }
      }
    } catch (e) {
      _logger.log('Failed to load launcher settings: $e', level: 'warning', source: 'Launcher');
    }
    // Before any engine exists: the launcher is the app's first screen.
    _applyGraphicsDevice();
  }

  Future<void> saveSettings() async {
    try {
      final map = {
        'theme_mode': _themeMode == ThemeMode.light ? 'light' : (_themeMode == ThemeMode.system ? 'system' : 'dark'),
        'default_projects_dir': _defaultProjectsDirectory,
        'graphics_device': _graphicsDevice,
      };
      // Atomic: another editor process may be reading it.
      ConfigJsonFile(_settingsFile).write(map);
    } catch (e) {
      _logger.log('Failed to save launcher settings: $e', level: 'error', source: 'Launcher');
    }
  }

  void setTab(int index) {
    _selectedTabIndex = index;
    // The Templates pane shows what the Marketplace installed since.
    if (index == 1) {
      refreshInstalledTemplates();
    } else {
      notifyListeners();
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await saveSettings();
    notifyListeners();
  }

  Future<void> toggleTheme(bool isDark) async {
    await setThemeMode(isDark ? ThemeMode.dark : ThemeMode.light);
  }

  Future<void> setDefaultProjectsDirectory(String path) async {
    _defaultProjectsDirectory = path;
    _projectPath = path;
    await saveSettings();
    notifyListeners();
  }

  Future<void> loadRecentProjects() async {
    _isLoading = true;
    notifyListeners();
    _allRecentProjects = await _projectRepo.getRecentProjects();
    final missing = _allRecentProjects.where((e) => e.isMissing).toList();
    if (missing.isNotEmpty && !_showMissingProjects) {
      _logger.log(
        'Hid ${missing.length} recent project(s) whose path could not be found: '
        '${missing.map((e) => e.projectDir).join(', ')}',
        level: 'warning',
        source: 'Launcher',
      );
    }
    _isLoading = false;
    notifyListeners();
  }

  void updateProjectName(String val) {
    _projectName = val;
    notifyListeners();
  }

  void updateProjectPath(String val) {
    _projectPath = val;
    notifyListeners();
  }

  Future<LuminaProject?> openProject(RecentProjectEntry entry) async {
    final lmprojectPath = '${entry.projectDir}/${entry.project.projectName}.lmproject';
    final project = await _projectRepo.loadProject(lmprojectPath);
    if (project != null) {
      _activeProject = project;
      _logger.log('Opened project "${project.projectName}" from ${entry.projectDir}', level: 'success', source: 'Launcher');
      await loadRecentProjects();
    }
    return project;
  }

  // --- Per-project editors -----------------------------------

  ProjectEditorResolver? _editorResolver;
  final EditorBuildService Function(ProjectEditorResolver resolver)? _buildServiceFactory;

  /// Decides how a project opens; its build mode and cache come from Editor
  /// Preferences › Project Editor Builds.
  ProjectEditorResolver get editorResolver => _editorResolver ??= () {
        final prefs = EditorPreferences.load(configDir: configDir);
        return ProjectEditorResolver(
          mode: prefs.editorBuildMode,
          everyProject: prefs.perProjectEditors,
          cache: prefs.editorBuildCacheDir == null ? null : EditorBuildCache(root: Directory(prefs.editorBuildCacheDir!)),
        );
      }();

  /// In place, the cached project editor, a build, or the missing-binary
  /// prompt (`--rebuild` forces a build).
  Future<ProjectEditorDecision> resolveProjectEditor(String projectDir, {bool rebuild = false}) async {
    final decision = await editorResolver.resolve(projectDir, rebuild: rebuild);
    _logger.log(
      switch (decision) {
        OpenInPlace() => 'Opening $projectDir in this editor (per-project editors off; no code plugins)',
        ExecCached(:final entry) => 'Opening $projectDir in its project editor ${entry.executable}',
        NeedsBuild(:final reason) => 'The project editor of $projectDir needs a build: $reason',
        MissingBinary(:final reason) => 'The project editor of $projectDir is missing: $reason',
      },
      level: 'info',
      source: 'Launcher',
    );
    return decision;
  }

  /// The "Don't ask again for this version" answers, per project on this
  /// machine (this launcher's config folder).
  late final ProjectEditorUpdatePrompts updatePrompts = ProjectEditorUpdatePrompts(configDir: configDir);

  /// Whether the project's editor should be offered an update to this
  /// Studio's engine: its copy of the engine source comes from another
  /// engine and the user did not ask to skip this one.
  Future<EditorEngineUpdate?> projectEditorUpdate(String projectDir) async {
    final update = await editorResolver.engineUpdate(projectDir);
    if (update == null) return null;
    if (updatePrompts.isDismissed(projectDir, update.current)) {
      _logger.log(
          "The project editor of $projectDir is from Lumina ${update.fromLabel}; not asking to update it to "
          "Lumina ${update.toLabel} (Don't ask again)",
          level: 'info',
          source: 'Launcher');
      return null;
    }
    _logger.log('The project editor of $projectDir is from Lumina ${update.fromLabel}; this Studio is Lumina ${update.toLabel}',
        level: 'info', source: 'Launcher');
    return update;
  }

  /// "Don't ask again for this version": [update]'s engine is not offered
  /// for [projectDir] again on this machine.
  void dismissProjectEditorUpdate(String projectDir, EditorEngineUpdate update) {
    updatePrompts.dismiss(projectDir, update.current);
    _logger.log("Won't ask again to update the project editor of $projectDir to Lumina ${update.current.label}",
        level: 'info', source: 'Launcher');
  }

  /// Writes [version] (default: this Studio's) as the project's
  /// `engine_version` and logs the change; returns [project] carrying it.
  Future<LuminaProject> recordEngineVersion(LuminaProject project, String projectDir, {String? version}) async {
    final v = version ?? LuminaRelease.displayVersion;
    final previous = await _projectRepo.updateEngineVersion(projectDir, v);
    if (previous == null) return project.engineVersion == v ? project : project.copyWith(engineVersion: v);
    _logger.log('${project.projectName}: engine_version ${previous.isEmpty ? '(none)' : previous} → $v (opened in Lumina $v)',
        level: 'info', source: 'Launcher');
    return project.copyWith(engineVersion: v);
  }

  /// The build behind the splash, for [plugins] of the project at [projectDir].
  /// [update] first replaces the project's copy of the engine source with
  /// this Studio's and records its version as the project's
  /// `engine_version`.
  EditorBuildViewModel projectEditorBuild(String projectName, String projectDir, List<LuminaPluginDescriptor> plugins,
      {EditorEngineUpdate? update}) {
    final resolver = editorResolver;
    final service = _buildServiceFactory?.call(resolver) ??
        EditorBuildService(
          engineRoot: resolver.engineRoot,
          cache: resolver.cache,
          generator: resolver.generator,
          mode: resolver.mode,
          flutterInfo: resolver.flutterInfo,
        );
    return EditorBuildViewModel(
      projectName: projectName,
      projectDir: projectDir,
      engineVersion: kLuminaEngineVersion,
      hasPlugins: plugins.isNotEmpty,
      startBuild: () => service.start(
        projectDir,
        plugins,
        projectName: projectName,
        syncSource: update != null,
        onSourceSynced: update == null
            ? null
            : () async {
                _logger.log(
                    "Updated the project editor source of $projectName from Lumina ${update.fromLabel} to Lumina ${update.current.label}",
                    level: 'info',
                    source: 'Launcher');
                final previous = await _projectRepo.updateEngineVersion(projectDir, update.current.version);
                if (previous != null) {
                  _logger.log('$projectName: engine_version ${previous.isEmpty ? '(none)' : previous} → ${update.current.version}',
                      level: 'info', source: 'Launcher');
                }
              },
      ),
    );
  }

  /// Execs [executable] (a project editor) on [projectDir]; the launcher quits.
  Future<void> execProjectEditor(String executable, String projectDir) {
    _logger.log('Handing off to $executable --project $projectDir', level: 'info', source: 'Launcher');
    return EditorHandOff.instance.execProjectEditor(executable, projectDir);
  }

  Future<LuminaProject?> openExternal(String lmprojectPath) async {
    final project = await _projectRepo.loadProject(lmprojectPath);
    if (project != null) {
      _activeProject = project;
      _logger.log('Opened external project "${project.projectName}" from $lmprojectPath', level: 'success', source: 'Launcher');
      await loadRecentProjects();
    }
    return project;
  }

  Future<void> renameProject(RecentProjectEntry entry, String newName) async {
    _logger.log('Renaming project "${entry.project.projectName}" to "$newName"...', level: 'info', source: 'Launcher');
    await _projectRepo.renameProject(
      oldProjectDir: entry.projectDir,
      newProjectName: newName,
    );
    await loadRecentProjects();
  }

  Future<void> duplicateProject(RecentProjectEntry entry) async {
    _logger.log('Duplicating project "${entry.project.projectName}"...', level: 'info', source: 'Launcher');
    await _projectRepo.duplicateProject(
      sourceProjectDir: entry.projectDir,
    );
    await loadRecentProjects();
  }

  Future<void> removeFromHub(RecentProjectEntry entry) async {
    _logger.log('Removing project "${entry.project.projectName}" from hub...', level: 'info', source: 'Launcher');
    await _projectRepo.removeRecentProject(entry.projectDir);
    await loadRecentProjects();
  }

  Future<void> deleteFromDisk(RecentProjectEntry entry) async {
    _logger.log('Deleting project "${entry.project.projectName}" from disk (${entry.projectDir})...', level: 'warning', source: 'Launcher');
    await _projectRepo.deleteProjectFromDisk(entry.projectDir);
    await loadRecentProjects();
  }

  Future<LuminaProject?> locateProject(RecentProjectEntry entry, String newLmprojectPath) async {
    _logger.log('Locating moved project "${entry.project.projectName}" at "$newLmprojectPath"...', level: 'info', source: 'Launcher');
    final repaired = await _projectRepo.locateProject(
      oldProjectDir: entry.projectDir,
      newLmprojectPath: newLmprojectPath,
    );
    await loadRecentProjects();
    return repaired;
  }

  Future<void> revealInFileManager(RecentProjectEntry entry) async {
    final dir = entry.projectDir;
    _logger.log('Revealing in file manager: $dir', level: 'info', source: 'Launcher');
    try {
      if (Platform.isLinux) {
        await Process.run('xdg-open', [dir]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [dir]);
      } else if (Platform.isWindows) {
        await Process.run('explorer', [dir]);
      }
    } catch (e) {
      _logger.log('Failed to open file manager for $dir: $e', level: 'warning', source: 'Launcher');
    }
  }
}
