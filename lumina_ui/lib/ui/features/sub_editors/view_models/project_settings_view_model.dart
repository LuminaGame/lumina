import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart' show ProjectSettingsSection, PluginSettingsHandle;
import 'package:lumina_ui/ui/core/host/editor_host.dart' show LuminaEditorHost;

import 'package:lumina_ui/ui/features/sub_editors/services/build_pipeline_service.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/project_icon_packaging.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/project_icon_rasterizer.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/umg_widget_codegen.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/umg_widget_validator.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/web_preview_server.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/build_manager_view_model.dart' show BuildManagerViewModel;

part 'project_settings_view_model/state.dart';
part 'project_settings_view_model/widget_library_and_icon.dart';
part 'project_settings_view_model/packaging.dart';
part 'project_settings_view_model/web_loading_screen.dart';
part 'project_settings_view_model/models.dart';

typedef ProcessStarter = Future<Process> Function(String executable, List<String> arguments, {String? workingDirectory});

/// Edits the real `.lmproject` manifest: loads it through [ProjectRepository],
/// keeps a working copy with dirty tracking and per-category validation, and
/// writes it back on [apply]. Graphics changes are pushed to the editor via
/// [onApplied] so the toolbar scalability state is shared, not copied.
class ProjectSettingsViewModel extends _ProjectSettingsViewModelState
    with
        _ProjectSettingsWidgetLibraryAndIcon,
        _ProjectSettingsPackaging,
        _ProjectSettingsWebLoadingScreen {
  ProjectSettingsViewModel({
    required super.projectDirPath,
    super.projectRepository,
    super.assetRepository,
    super.logger,
    super.processStarter,
    super.initialProject,
    super.hostTargets,
    super.codeGenerator,
    super.webModulePackageRoots,
  });

  static Future<Process> _defaultStarter(String executable, List<String> arguments, {String? workingDirectory}) =>
      Process.start(executable, arguments, workingDirectory: workingDirectory, runInShell: true);

  // --- state -------------------------------------------------------------

  bool get isLoading => _isLoading;
  String? get loadError => _loadError;
  bool get hasProject => _working != null;
  @override
  LuminaProject get project => _working!;
  LuminaProject? get onDiskProject => _onDisk;
  String? get manifestPath => _manifestPath;
  String get filterQuery => _filterQuery;
  List<LevelChoice> get levels => _levels;
  List<String> get gameModeClasses => _gameModeClasses;
  @override
  PackagingRunState get packaging => _packaging;

  bool get isDirty {
    if (_working == null || _onDisk == null) return false;
    return jsonEncode(_working!.toMap()) != jsonEncode(_onDisk!.toMap());
  }

  // --- load / revert / apply -------------------------------------------

  /// Locates `<projectDir>/<name>.lmproject` (any `.lmproject` if the name is
  /// unknown) and loads it. Never throws; [loadError] reports failures.
  Future<void> load() async {
    _isLoading = true;
    _loadError = null;
    notifyListeners();
    try {
      final path = _resolveManifestPath();
      if (path == null) {
        _loadError = 'No .lmproject found in $projectDirPath';
      } else {
        final loaded = await _projectRepo.loadProject(path);
        if (loaded == null) {
          _loadError = 'Could not read $path';
        } else {
          _manifestPath = path;
          _onDisk = loaded;
          _working = loaded;
        }
      }
      _refreshLevels();
      _refreshGameModes();
    } catch (e) {
      _loadError = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String? _resolveManifestPath() {
    final dir = Directory(projectDirPath);
    if (!dir.existsSync()) return null;
    final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.lmproject')).toList();
    if (files.isEmpty) return null;
    final name = _working?.projectName;
    if (name != null) {
      final preferred = files.where((f) => f.path.endsWith('/$name.lmproject'));
      if (preferred.isNotEmpty) return preferred.first.path;
    }
    return files.first.path;
  }

  /// Rescans the project for the Maps & Modes choices (levels, game modes,
  /// pawn classes): assets created, moved or saved after [load] appear.
  /// The working copy is untouched; listeners hear only a changed list.
  void refreshChoices() {
    if (projectDirPath.isEmpty) return;
    final before = jsonEncode([_levels.map((l) => l.relativePath).toList(), _gameModeClasses, _pawnClasses]);
    _refreshLevels();
    _refreshGameModes();
    final after = jsonEncode([_levels.map((l) => l.relativePath).toList(), _gameModeClasses, _pawnClasses]);
    if (after != before) notifyListeners();
  }

  void _refreshLevels() {
    try {
      final assets = _assetRepo.scanProjectContents(projectDirPath);
      _levels = assets
          .where((a) => a.type == AssetType.level)
          .map((a) => LevelChoice(
                relativePath: a.relativePath,
                displayName: a.fileName.replaceAll('.lmas', ''),
                thumbnail: a.thumbnailBytes,
              ))
          .toList()
        ..sort((a, b) => a.displayName.compareTo(b.displayName));
    } catch (e) {
      _logger.log('Level scan failed: $e', level: 'warning', source: 'ProjectSettings');
      _levels = const [];
    }
  }

  void _refreshGameModes() {
    final classes = <String>{'LuminaGameMode'};
    final actorsDir = Directory('$projectDirPath/lib/actors');
    if (actorsDir.existsSync()) {
      final re = RegExp(r'class\s+(\w+)\s+extends\s+LuminaGameMode\b');
      for (final f in actorsDir.listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.dart')) continue;
        try {
          for (final m in re.allMatches(f.readAsStringSync())) {
            classes.add(m.group(1)!);
          }
        } catch (_) {}
      }
    }
    // GameMode Blueprints (by `.lmas` path) and the
    // Pawn / Character Blueprints a Default Pawn Class can name.
    final gameModeBlueprints = <String>[];
    final pawnBlueprints = <String>[];
    try {
      for (final a in _assetRepo.scanProjectContents(projectDirPath)) {
        if (a.type != AssetType.actor || a.lmasPath == null) continue;
        final parent = _blueprintParent(a.lmasPath!);
        if (parent == 'LuminaGameMode') gameModeBlueprints.add(a.relativePath);
        if (parent == 'LuminaPawn' || parent == 'LuminaCharacter') pawnBlueprints.add(a.relativePath);
      }
    } catch (_) {}
    // Dart classes a Blueprint generated are listed by their Blueprint path.
    classes.removeWhere((c) => gameModeBlueprints.any((p) => _className(p) == c));
    _gameModeClasses = [...classes.toList()..sort(), ...gameModeBlueprints..sort()];
    _pawnClasses = ['', ...pawnBlueprints..sort()];
  }

  /// Maps & Modes "Default Pawn Class": "" (from the game mode) or a Pawn /
  /// Character Blueprint path.
  List<String> get pawnClasses => _pawnClasses;

  /// The Dart class a Blueprint at [path] compiles into ([dartTypeName]).
  static String _className(String path) => dartTypeName(path.split('/').last.replaceAll('.lmas', ''));

  static String? _blueprintParent(String lmasPath) {
    try {
      final payload = LuminaAsset.fromBytes(File(lmasPath).readAsBytesSync()).rawPayload;
      if (payload == null || payload.isEmpty) return null;
      final map = jsonDecode(utf8.decode(payload));
      return map is Map ? map['parentClass'] as String? : null;
    } catch (_) {
      return null;
    }
  }

  /// Reloads the on-disk manifest, discarding edits.
  Future<void> revert() async {
    if (_manifestPath == null) {
      _working = _onDisk;
      notifyListeners();
      return;
    }
    final loaded = await _projectRepo.loadProject(_manifestPath!);
    if (loaded != null) {
      _onDisk = loaded;
      _working = loaded;
    } else {
      _working = _onDisk;
    }
    _logger.log('Project settings reverted to disk', level: 'info', source: 'ProjectSettings');
    notifyListeners();
  }

  /// Validates every category; refuses to save while errors exist. Warnings
  /// (e.g. a map whose file is gone) do not block saving.
  @override
  Future<bool> apply() async {
    if (_working == null) return false;
    final errors = validationErrors;
    if (errors.values.any((l) => l.isNotEmpty)) {
      _logger.log(
        'Project settings not saved: ${errors.values.expand((e) => e).join('; ')}',
        level: 'error',
        source: 'ProjectSettings',
      );
      notifyListeners();
      return false;
    }
    // A new widget library changes the game's dependencies
    // first; when `flutter pub get` fails nothing is saved.
    final previousLibrary = _onDisk?.ui.widgetLibrary ?? kUmgWidgetLibraryShadcn;
    final library = _working!.ui.widgetLibrary;
    final libraryChanged = library != previousLibrary;
    if (libraryChanged && !await _switchWidgetLibrary(previousLibrary, library)) {
      notifyListeners();
      return false;
    }
    final stamped = _working!.copyWith(
      isDirty: false,
      lastModifiedTimestamp: DateTime.now().toIso8601String(),
    );
    await _projectRepo.saveProject(stamped, projectDirPath);
    DartCodeGeneratorService().writeProjectInputDart(projectDirPath, stamped.input);
    final previousBranding = _onDisk?.branding ?? const ProjectBrandingSettings();
    final brandingChanged = jsonEncode(previousBranding.toMap()) != jsonEncode(stamped.branding.toMap());
    if (brandingChanged) {
      await _writeAppIcons(stamped);
    }
    // `flutter run -d chrome` shows the new loading screen too.
    final previousStyle = _onDisk?.packaging.webLoadingStyle ?? const ProjectWebLoadingStyle();
    if ((brandingChanged || jsonEncode(previousStyle.toMap()) != jsonEncode(stamped.packaging.webLoadingStyle.toMap())) &&
        Directory('$projectDirPath/web').existsSync()) {
      await _writeWebLoadingScreen(stamped);
    }
    if (libraryChanged) {
      _widgetLibraryStatus = 'Regenerating UMG widgets…';
      notifyListeners();
      final results = await UmgWidgetCodegen.recompileProject(projectDirPath, library: library);
      _widgetLibraryStatus = 'Widget library set to ${widgetLibraryLabel(library)}; regenerated ${results.length} widget(s)';
      _logger.log(_widgetLibraryStatus!, level: 'success', source: 'ProjectSettings');
    }
    _manifestPath ??= '$projectDirPath/${stamped.projectName}.lmproject';
    _onDisk = stamped;
    _working = stamped;
    _logger.log('Project settings saved to $_manifestPath', level: 'success', source: 'ProjectSettings');
    onApplied?.call(stamped);
    notifyListeners();
    return true;
  }

  // --- validation --------------------------------------------------------

  static final RegExp _dartPackageName = RegExp(r'^[A-Za-z][A-Za-z0-9_]*$');
  static final RegExp _actionName = RegExp(r'^[A-Za-z][A-Za-z0-9_]*$');

  /// Blocking errors keyed by [ProjectSettingsCategory] id.
  Map<String, List<String>> get validationErrors {
    final p = _working;
    final out = <String, List<String>>{for (final c in ProjectSettingsCategory.all) c: <String>[]};
    if (p == null) return out;

    if (p.branding.iconBackgroundArgb == null) {
      out[ProjectSettingsCategory.description]!.add('Icon Background "${p.branding.iconBackground}" must be a #RRGGBB colour');
    }
    if (p.projectName.trim().isEmpty) {
      out[ProjectSettingsCategory.description]!.add('Project name is required');
    } else if (!_dartPackageName.hasMatch(p.projectName)) {
      out[ProjectSettingsCategory.description]!.add('Project name may only contain letters, digits and underscores');
    }

    if (p.settings.targetFps < 0 || p.settings.targetFps > 240) {
      out[ProjectSettingsCategory.graphics]!.add('Target FPS must be between 0 (unlimited) and 240');
    }

    final names = <String>{};
    for (final a in p.input.actions) {
      if (!_actionName.hasMatch(a.name)) {
        out[ProjectSettingsCategory.input]!.add('Invalid action name "${a.name}"');
      }
      if (!names.add(a.name)) {
        out[ProjectSettingsCategory.input]!.add('Duplicate action name "${a.name}"');
      }
    }
    final ctxNames = <String>{};
    for (final c in p.input.mappingContexts) {
      if (c.name.trim().isEmpty) out[ProjectSettingsCategory.input]!.add('Mapping context needs a name');
      if (!ctxNames.add(c.name)) out[ProjectSettingsCategory.input]!.add('Duplicate mapping context "${c.name}"');
      for (final m in c.mappings) {
        if (!names.contains(m.action)) {
          out[ProjectSettingsCategory.input]!.add('Mapping in "${c.name}" refers to unknown action "${m.action}"');
        }
        if (m.keyId == 0) {
          out[ProjectSettingsCategory.input]!.add('Mapping for "${m.action}" in "${c.name}" has no key');
        }
      }
    }

    if (p.physics.fixedTimestep <= 0 || p.physics.fixedTimestep > 1) {
      out[ProjectSettingsCategory.physics]!.add('Fixed timestep must be in (0, 1] seconds');
    }
    out[ProjectSettingsCategory.packaging]!.addAll(p.packaging.webLoadingStyle.problems());
    for (final t in p.packaging.targets) {
      if (!kPackagingPlatforms.contains(t)) {
        out[ProjectSettingsCategory.packaging]!.add('Unknown packaging target "$t" (known: ${kPackagingPlatforms.join(', ')})');
      }
    }
    return out;
  }

  /// Non-blocking warnings (a missing default map is allowed).
  Map<String, List<String>> get validationWarnings {
    final p = _working;
    final out = <String, List<String>>{for (final c in ProjectSettingsCategory.all) c: <String>[]};
    if (p == null) return out;
    for (final entry in {
      'Editor Startup Map': p.mapsAndModes.editorStartupMap,
      'Game Default Map': p.mapsAndModes.gameDefaultMap,
    }.entries) {
      final rel = entry.value;
      if (rel.isEmpty) continue;
      if (!File('$projectDirPath/$rel').existsSync()) {
        out[ProjectSettingsCategory.mapsAndModes]!.add('${entry.key} "$rel" does not exist on disk');
      }
    }
    for (final a in p.input.actions) {
      final bound = p.input.mappingContexts.any((c) => c.mappings.any((m) => m.action == a.name));
      if (!bound) out[ProjectSettingsCategory.input]!.add('Action "${a.name}" has no key binding');
    }
    if (!p.branding.usesDefaultIcon && !File('$projectDirPath/${p.branding.icon}').existsSync()) {
      out[ProjectSettingsCategory.description]!.add('Project Icon "${p.branding.icon}" does not exist on disk');
    }
    if (p.packaging.targets.isEmpty) {
      out[ProjectSettingsCategory.packaging]!.add('No target platform is ticked: Package Project has nothing to build');
    }
    final logo = p.packaging.webLoadingStyle.logo;
    if (logo != ProjectWebLoadingStyle.logoFromIcon && logo != ProjectWebLoadingStyle.logoNone && !File('$projectDirPath/$logo').existsSync()) {
      out[ProjectSettingsCategory.packaging]!.add('Web loading logo "$logo" does not exist on disk: the loading screen will have no logo');
    }
    return out;
  }

  int errorCount(String category) => validationErrors[category]?.length ?? 0;

  // --- search ------------------------------------------------------------

  void setFilterQuery(String q) {
    _filterQuery = q.trim().toLowerCase();
    notifyListeners();
  }

  /// Categories whose title or row keywords match the query (all when
  /// empty): the built-in ones, then the plugins' pages.
  List<String> get visibleCategories {
    final plugins = [
      for (final (plugin, section) in pluginSections)
        if (_filterQuery.isEmpty ||
            section.title.toLowerCase().contains(_filterQuery) ||
            plugin.toLowerCase().contains(_filterQuery) ||
            section.keywords.any((k) => k.toLowerCase().contains(_filterQuery)))
          pluginCategoryId(plugin, section.id),
    ];
    if (_filterQuery.isEmpty) return [...ProjectSettingsCategory.all, ...plugins];
    return [
      ...ProjectSettingsCategory.all.where((c) {
        if (ProjectSettingsCategory.title(c).toLowerCase().contains(_filterQuery)) return true;
        return ProjectSettingsCategory.keywords[c]!.any((k) => k.contains(_filterQuery));
      }),
      ...plugins,
    ];
  }

  // --- Plugin pages + plugin_settings -----------------------------------

  /// The plugins' Project Settings pages (the editor passes its registry's).
  List<(String, ProjectSettingsSection)> pluginSections = const [];

  static String pluginCategoryId(String plugin, String sectionId) => 'plugin:$plugin/$sectionId';

  static bool isPluginCategory(String category) => category.startsWith('plugin:');

  /// The (plugin, section) behind a `plugin:` category id.
  (String, ProjectSettingsSection)? pluginSectionOf(String category) {
    for (final entry in pluginSections) {
      if (pluginCategoryId(entry.$1, entry.$2.id) == category) return entry;
    }
    return null;
  }

  String categoryTitle(String category) => pluginSectionOf(category)?.$2.title ?? ProjectSettingsCategory.title(category);

  /// [plugin]'s settings in the working copy.
  Map<String, Object?> pluginSettingsOf(String plugin) => Map.unmodifiable(_working?.pluginSettings[plugin] ?? const {});

  /// Sets [key] of [plugin] in the working copy (Apply writes it); null
  /// removes it. Secret-looking keys are refused.
  void setPluginSetting(String plugin, String key, Object? value) {
    PluginSettingsHandle.checkKey(key, value);
    _update((p) {
      final next = {...?p.pluginSettings[plugin]};
      if (value == null) {
        next.remove(key);
      } else {
        next[key] = value;
      }
      final all = {...p.pluginSettings};
      if (next.isEmpty) {
        all.remove(plugin);
      } else {
        all[plugin] = next;
      }
      return p.copyWith(pluginSettings: all);
    });
  }

  final Map<String, PluginSettingsHandle> _handles = {};

  /// The handle a plugin page edits.
  PluginSettingsHandle pluginHandle(String plugin) => _handles.putIfAbsent(plugin, () => _ProjectPluginSettingsHandle(this, plugin));

  /// Whether a settings row labelled [label] matches the current query.
  bool rowMatches(String label) => _filterQuery.isEmpty || label.toLowerCase().contains(_filterQuery);

  // --- editing -----------------------------------------------------------

  @override
  void _update(LuminaProject Function(LuminaProject p) fn) {
    if (_working == null) return;
    _working = fn(_working!);
    notifyListeners();
  }

  void setProjectName(String v) => _update((p) => p.copyWith(projectName: v));
  void setDescription(String v) => _update((p) => p.copyWith(description: v));

  EngineScalabilitySettings _settings(LuminaProject p) => p.settings;

  EngineScalabilitySettings _copySettings(
    EngineScalabilitySettings s, {
    int? targetFps,
    bool? vsyncEnabled,
    String? qualityPreset,
    ScalabilityCategory? scalability,
    bool? startFullscreen,
  }) =>
      EngineScalabilitySettings(
        targetFps: targetFps ?? s.targetFps,
        vsyncEnabled: vsyncEnabled ?? s.vsyncEnabled,
        qualityPreset: qualityPreset ?? s.qualityPreset,
        scalability: scalability ?? s.scalability,
        autoOrganizeFiles: s.autoOrganizeFiles,
        autoSaveIntervalSeconds: s.autoSaveIntervalSeconds,
        startFullscreen: startFullscreen ?? s.startFullscreen,
      );

  /// Selecting a preset instantly expands every per-category tier.
  void setQualityPreset(String preset) => _update((p) => p.copyWith(
        settings: _copySettings(_settings(p),
            qualityPreset: preset.toLowerCase(), scalability: ScalabilityPresets.forPreset(preset)),
      ));

  void setScalabilityField(String field, String tier) => _update((p) {
        final c = p.settings.scalability;
        final next = ScalabilityCategory(
          viewDistance: field == 'viewDistance' ? tier : c.viewDistance,
          shadowQuality: field == 'shadowQuality' ? tier : c.shadowQuality,
          antiAliasing: field == 'antiAliasing' ? tier : c.antiAliasing,
          postProcessing: field == 'postProcessing' ? tier : c.postProcessing,
          textureQuality: field == 'textureQuality' ? tier : c.textureQuality,
          shadingQuality: field == 'shadingQuality' ? tier : c.shadingQuality,
        );
        return p.copyWith(settings: _copySettings(p.settings, qualityPreset: 'custom', scalability: next));
      });

  void setTargetFps(int fps) => _update((p) => p.copyWith(settings: _copySettings(p.settings, targetFps: fps)));
  void setVSync(bool on) => _update((p) => p.copyWith(settings: _copySettings(p.settings, vsyncEnabled: on)));
  void setStartFullscreen(bool on) => _update((p) => p.copyWith(settings: _copySettings(p.settings, startFullscreen: on)));

  // Enhanced Input
  void addAction([String? name]) => _update((p) {
        var n = name ?? 'IA_NewAction';
        var i = 1;
        final existing = p.input.actions.map((a) => a.name).toSet();
        while (existing.contains(n)) {
          n = '${name ?? 'IA_NewAction'}_${i++}';
        }
        return p.copyWith(input: p.input.copyWith(actions: [...p.input.actions, ProjectInputAction(name: n)]));
      });

  void updateAction(int index, {String? name, ProjectInputValueType? valueType}) => _update((p) {
        final list = [...p.input.actions];
        final old = list[index];
        final updated = old.copyWith(name: name, valueType: valueType);
        list[index] = updated;
        // Keep mappings pointing at a renamed action.
        var contexts = p.input.mappingContexts;
        if (name != null && name != old.name) {
          contexts = contexts
              .map((c) => c.copyWith(
                  mappings: c.mappings.map((m) => m.action == old.name ? m.copyWith(action: name) : m).toList()))
              .toList();
        }
        return p.copyWith(input: p.input.copyWith(actions: list, mappingContexts: contexts));
      });

  void removeAction(int index) => _update((p) {
        final list = [...p.input.actions];
        final removed = list.removeAt(index);
        final contexts = p.input.mappingContexts
            .map((c) => c.copyWith(mappings: c.mappings.where((m) => m.action != removed.name).toList()))
            .toList();
        return p.copyWith(input: p.input.copyWith(actions: list, mappingContexts: contexts));
      });

  void addMappingContext([String? name]) => _update((p) => p.copyWith(
        input: p.input.copyWith(mappingContexts: [
          ...p.input.mappingContexts,
          ProjectMappingContext(name: name ?? 'IMC_Default', priority: p.input.mappingContexts.length),
        ]),
      ));

  void updateMappingContext(int index, {String? name, int? priority}) => _update((p) {
        final list = [...p.input.mappingContexts];
        list[index] = list[index].copyWith(name: name, priority: priority);
        return p.copyWith(input: p.input.copyWith(mappingContexts: list));
      });

  void removeMappingContext(int index) => _update((p) {
        final list = [...p.input.mappingContexts]..removeAt(index);
        return p.copyWith(input: p.input.copyWith(mappingContexts: list));
      });

  void addMapping(int contextIndex, ProjectInputMapping mapping) => _update((p) {
        final list = [...p.input.mappingContexts];
        final c = list[contextIndex];
        list[contextIndex] = c.copyWith(mappings: [...c.mappings, mapping]);
        return p.copyWith(input: p.input.copyWith(mappingContexts: list));
      });

  void updateMapping(int contextIndex, int mappingIndex,
          {String? action, int? keyId, String? keyLabel, double? scale, String? axis}) =>
      _update((p) {
        final list = [...p.input.mappingContexts];
        final c = list[contextIndex];
        final maps = [...c.mappings];
        maps[mappingIndex] = maps[mappingIndex].copyWith(action: action, keyId: keyId, keyLabel: keyLabel, scale: scale, axis: axis);
        list[contextIndex] = c.copyWith(mappings: maps);
        return p.copyWith(input: p.input.copyWith(mappingContexts: list));
      });

  void removeMapping(int contextIndex, int mappingIndex) => _update((p) {
        final list = [...p.input.mappingContexts];
        final c = list[contextIndex];
        final maps = [...c.mappings]..removeAt(mappingIndex);
        list[contextIndex] = c.copyWith(mappings: maps);
        return p.copyWith(input: p.input.copyWith(mappingContexts: list));
      });

  // Maps & Modes
  void setEditorStartupMap(String relativePath) =>
      _update((p) => p.copyWith(mapsAndModes: p.mapsAndModes.copyWith(editorStartupMap: relativePath)));
  void setGameDefaultMap(String relativePath) =>
      _update((p) => p.copyWith(mapsAndModes: p.mapsAndModes.copyWith(gameDefaultMap: relativePath)));
  void setDefaultGameMode(String className) =>
      _update((p) => p.copyWith(mapsAndModes: p.mapsAndModes.copyWith(defaultGameMode: className)));

  /// "" uses the game mode's own pawn; a path overrides it.
  void setDefaultPawnClass(String path) =>
      _update((p) => p.copyWith(mapsAndModes: p.mapsAndModes.copyWith(defaultPawnClass: path)));

  // Physics
  void setGravityZ(double g) => _update((p) => p.copyWith(physics: p.physics.copyWith(gravityZ: g)));
  void setFixedTimestep(double dt) => _update((p) => p.copyWith(physics: p.physics.copyWith(fixedTimestep: dt)));

  static String widgetLibraryLabel(String library) =>
      library == kUmgWidgetLibraryFlutter ? 'Plain Flutter widgets' : 'shadcn_flutter';

  static String _finishedStage(BuildStepStatus result, Map<String, PackageTargetStatus> statuses) {
    final ok = statuses.values.where((s) => s == PackageTargetStatus.ok).length;
    return switch (result) {
      BuildStepStatus.ok => 'Packaged all $ok target(s)',
      BuildStepStatus.cancelled => 'Packaging cancelled ($ok of ${statuses.length} packaged)',
      _ => 'Packaged $ok of ${statuses.length} target(s)',
    };
  }

  @override
  void dispose() {
    _disposed = true;
    _packagingToken?.cancel();
    unawaited(_webLoadingPreview.stop());
    super.dispose();
  }
}

/// A plugin page's view of the working copy.
class _ProjectPluginSettingsHandle extends PluginSettingsHandle {
  _ProjectPluginSettingsHandle(this._vm, this._plugin);

  final ProjectSettingsViewModel _vm;
  final String _plugin;

  @override
  Map<String, Object?> get values => _vm.pluginSettingsOf(_plugin);

  @override
  void set(String key, Object? value) => _vm.setPluginSetting(_plugin, key, value);

  @override
  Listenable get changes => _vm;
}
