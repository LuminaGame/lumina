import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lumina_editor_data/lumina_editor.dart';

import 'package:lumina_ui/ui/core/services/plugin_process/plugin_process_supervisor.dart';
import 'package:lumina_ui/ui/features/plugin_manager/services/plugin_importer.dart';
import 'package:lumina_ui/ui/features/plugin_manager/services/plugin_remover.dart';

class PluginManagerViewModel extends ChangeNotifier {
  final PluginRegistryService registryService;
  final Future<void> Function(String name, bool enabled, {bool cascade})? onSetEnabled;

  /// Runs after an import changed what is on disk (the editor rescans its
  /// plugin roots); without it the registry is refreshed directly.
  final Future<void> Function()? onPluginsChanged;

  /// Import from Folder / Import from Zip pickers; null uses the OS dialog.
  Future<String?> Function()? folderPicker;
  Future<String?> Function()? zipPicker;

  /// Builds the importer for one import; defaults to the user plugin
  /// directory with every scanned plugin as a possible name conflict.
  final PluginImporter Function(List<LuminaPluginDescriptor> existing)? importerFactory;

  /// Whether this editor session registered plugin `name` (it stays active
  /// until a restart even once removed); null: none is.
  final bool Function(String name)? isPluginLoaded;

  /// Builds the remover for one removal; defaults to the per-user plugin
  /// data folder and the Marketplace's install records.
  final PluginRemover Function()? removerFactory;

  /// The supervisor of plugin `name`'s process, or null when it has none
  /// (an in-process plugin, or no editor behind the manager).
  final PluginProcessSupervisor? Function(String name)? processOf;

  /// Whether the project forces plugin `name` into the editor process.
  final bool Function(String name)? runsInEditorProcess;

  /// Writes the project's `plugin_isolation` override for plugin `name`.
  final Future<void> Function(String name, bool inEditorProcess)? onSetRunInEditorProcess;

  String _searchQuery = '';
  String _selectedCategory = 'ALL PLUGINS';
  String _selectedGroup = 'ALL'; // ALL, INSTALLED, BUILT-IN
  PluginEntry? _selectedEntry;

  PluginManagerViewModel({
    required this.registryService,
    this.onSetEnabled,
    this.onPluginsChanged,
    this.folderPicker,
    this.zipPicker,
    this.importerFactory,
    this.isPluginLoaded,
    this.removerFactory,
    this.processOf,
    this.runsInEditorProcess,
    this.onSetRunInEditorProcess,
  });

  /// The process of plugin [name], when it runs in one.
  PluginProcessSupervisor? processFor(String name) => processOf?.call(name);

  /// Restarts plugin [name]'s process (resets its automatic restarts).
  Future<void> restartProcess(String name) async => processFor(name)?.restart();

  bool _switchingIsolation = false;

  /// A plugin is being moved in or out of the editor process.
  bool get switchingIsolation => _switchingIsolation;

  /// "Run in editor process (debugging)" for plugin [name].
  bool runsInEditor(String name) => runsInEditorProcess?.call(name) ?? false;

  Future<void> setRunInEditorProcess(String name, bool inEditorProcess) async {
    final set = onSetRunInEditorProcess;
    if (set == null) return;
    _switchingIsolation = true;
    notifyListeners();
    try {
      await set(name, inEditorProcess);
    } finally {
      _switchingIsolation = false;
      notifyListeners();
    }
  }

  bool _importing = false;
  bool _disposed = false;

  @override
  void notifyListeners() {
    // An import can finish after the Plugins tab closed.
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// An import is being validated or copied.
  bool get importing => _importing;

  PluginImporter? _pendingImporter;

  PluginImporter _importer() {
    final existing = [for (final e in registryService.entries) e.descriptor];
    return importerFactory?.call(existing) ?? PluginImporter(existing: existing);
  }

  /// Import from Folder / Import from Zip: validates the plugin at [path] and
  /// copies it into the user plugin directory. An
  /// [PluginImportStatus.alreadyInstalled] result waits for [confirmReplace]
  /// or [cancelImport]; an installed plugin is listed and selected.
  Future<PluginImportResult> importPlugin(PluginImportSource source, String path) async {
    _importing = true;
    notifyListeners();
    try {
      final importer = _importer();
      final result = source == PluginImportSource.folder ? await importer.importFolder(path) : await importer.importZip(path);
      if (result.status == PluginImportStatus.alreadyInstalled) _pendingImporter = importer;
      if (result.status == PluginImportStatus.installed) await _afterInstall(result);
      return result;
    } finally {
      _importing = false;
      notifyListeners();
    }
  }

  /// Replace on "already installed": the new copy replaces the installed
  /// one (the previous copy comes back if writing fails).
  Future<PluginImportResult> confirmReplace(PluginImportResult pending) async {
    final candidate = pending.candidate;
    if (candidate == null) return pending;
    final importer = _pendingImporter ?? _importer();
    _pendingImporter = null;
    _importing = true;
    notifyListeners();
    try {
      final result = await importer.install(candidate, replace: true);
      if (result.status == PluginImportStatus.installed) await _afterInstall(result);
      return result;
    } finally {
      _importing = false;
      notifyListeners();
    }
  }

  /// Cancel on "already installed": drops what the import staged.
  void cancelImport(PluginImportResult pending) {
    final candidate = pending.candidate;
    if (candidate != null) PluginImporter.discardCandidate(candidate);
    _pendingImporter = null;
  }

  Future<void> _afterInstall(PluginImportResult result) async {
    if (onPluginsChanged != null) {
      await onPluginsChanged!();
    } else {
      await registryService.refresh();
    }
    final name = result.candidate?.name;
    _selectedGroup = 'ALL';
    _selectedCategory = 'ALL PLUGINS';
    _selectedEntry = registryService.entries.where((e) => e.descriptor.name == name).firstOrNull;
  }

  bool _removing = false;

  /// A removal is running.
  bool get removing => _removing;

  PluginRemover _remover() => removerFactory?.call() ?? PluginRemover();

  /// What removing the user or project plugin [entry] deletes and changes,
  /// before anything is deleted. Throws [ArgumentError] for a built-in.
  PluginRemovalPlan planRemoval(PluginEntry entry) => _remover().plan(
        entry,
        entries: registryService.entries,
        roots: registryService.repo.roots,
        projectDir: registryService.projectDirPath,
        loaded: isPluginLoaded?.call(entry.descriptor.name) ?? false,
      );

  /// Removes the plugin [plan] describes (with its saved data when
  /// [deleteData]). Once its folder is gone, a plugin that was enabled is
  /// disabled in the open project with the plugins that depend on it (the
  /// project's `enabled_plugins` and editor host follow, as the switch
  /// does), the plugin roots are rescanned, and the selection moves to the
  /// plugin of the same name that comes back, else to the neighbour in the
  /// list. A removal that stopped changes nothing in the project.
  Future<PluginRemovalResult> removePlugin(PluginRemovalPlan plan, {bool deleteData = false}) async {
    _removing = true;
    notifyListeners();
    try {
      final before = entries;
      final index = before.indexWhere((e) => e.descriptor.name == plan.name);
      var result = _remover().remove(plan, deleteData: deleteData);
      if (!result.removed) return result;
      if (plan.enabled) {
        final enable = await setEnabled(plan.name, false, cascade: true);
        result = result.withProject(disabled: [plan.name, ...plan.dependents], restartRequired: enable.restartRequired);
      }
      if (onPluginsChanged != null) {
        await onPluginsChanged!();
      } else {
        await registryService.refresh();
      }
      final back = registryService.entries.where((e) => e.descriptor.name == plan.name).firstOrNull;
      if (back != null) {
        _selectedGroup = 'ALL';
        _selectedCategory = 'ALL PLUGINS';
        _selectedEntry = back;
      } else {
        final now = entries;
        _selectedEntry = now.isEmpty ? null : now[(index < 0 ? 0 : index).clamp(0, now.length - 1)];
      }
      return result;
    } finally {
      _removing = false;
      notifyListeners();
    }
  }

  String get searchQuery => _searchQuery;
  set searchQuery(String value) {
    _searchQuery = value;
    notifyListeners();
  }

  String get selectedCategory => _selectedCategory;
  String get selectedGroup => _selectedGroup;

  void selectCategory(String group, String category) {
    _selectedGroup = group;
    _selectedCategory = category;
    notifyListeners();
  }

  PluginEntry? get selectedEntry => _selectedEntry;
  set selectedEntry(PluginEntry? entry) {
    _selectedEntry = entry;
    notifyListeners();
  }

  List<PluginEntry> get entries {
    var list = registryService.entries;
    
    if (_selectedGroup == 'INSTALLED') {
      list = list.where((e) => e.descriptor.origin == PluginOrigin.project || e.descriptor.origin == PluginOrigin.user).toList();
    } else if (_selectedGroup == 'BUILT-IN') {
      list = list.where((e) => e.descriptor.origin == PluginOrigin.engine).toList();
    }

    if (_selectedCategory != 'ALL PLUGINS') {
      list = list.where((e) => e.descriptor.category == _selectedCategory).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((e) {
        final d = e.descriptor;
        return d.name.toLowerCase().contains(q) ||
               (d.friendlyName?.toLowerCase().contains(q) ?? false) ||
               (d.description?.toLowerCase().contains(q) ?? false) ||
               d.authors.any((a) => a.toLowerCase().contains(q));
      }).toList();
    }

    return list;
  }

  int get installedCount {
    return registryService.entries.where((e) => e.descriptor.origin == PluginOrigin.project || e.descriptor.origin == PluginOrigin.user).length;
  }
  
  int get builtInCount {
    return registryService.entries.where((e) => e.descriptor.origin == PluginOrigin.engine).length;
  }

  int get totalCount => registryService.entries.length;

  int get enabledCount => registryService.entries.where((e) => e.enabled).length;

  List<PluginScanError> get scanErrors => registryService.scanErrors;

  Map<String, int> get categoryCounts {
    final counts = <String, int>{};
    for (final e in registryService.entries) {
      final cat = e.descriptor.category;
      counts[cat] = (counts[cat] ?? 0) + 1;
    }
    return counts;
  }

  Future<void> refresh() async {
    await registryService.refresh();
    notifyListeners();
  }

  Future<EnableResult> setEnabled(String name, bool enabled, {bool cascade = false}) async {
    final res = await registryService.setEnabled(name, enabled, cascade: cascade);
    if (onSetEnabled != null) {
      await onSetEnabled!(name, enabled, cascade: cascade);
    }
    notifyListeners();
    return res;
  }

  PluginResolution resolve(Set<String> wantedEnabled) {
    return registryService.resolve(wantedEnabled);
  }

  /// The plugin names and scan roots a new plugin's name must not collide
  /// with, as the New Plugin wizard checks them live.
  String? validateNewPluginName(String name) => PluginTemplateGeneratorService.validatePluginName(
        name,
        existingPluginNames: [for (final e in registryService.entries) e.descriptor.name],
        scanRoots: [for (final r in registryService.repo.roots) r.dir],
      );

  /// The project a new plugin is generated into: the one whose `plugins/`
  /// root the registry scans.
  Directory defaultProjectRoot() {
    for (final r in registryService.repo.roots) {
      if (r.origin == PluginOrigin.project) return r.dir.parent;
    }
    return Directory.current;
  }

  /// The `lumina_editor_api` package a code plugin depends on:
  /// `LUMINA_ENGINE_ROOT` (the package itself, or the
  /// workspace holding it), then the `lumina_editor_api` beside the editor
  /// checkout ([LuminaWorkspace]). Throws [StateError] when neither exists;
  /// never a hardcoded home directory.
  static Directory resolveEditorApiRoot({Map<String, String>? environment}) {
    final env = (environment ?? Platform.environment)['LUMINA_ENGINE_ROOT'];
    final candidates = <String>[
      if (env != null && env.isNotEmpty) ...[env, '$env/lumina_editor_api', '$env/../lumina_editor_api'],
      LuminaWorkspace.package('lumina_editor_api'),
    ];
    for (final c in candidates) {
      final pubspec = File('$c/pubspec.yaml');
      if (pubspec.existsSync() && RegExp(r'^name:\s*lumina_editor_api\s*$', multiLine: true).hasMatch(pubspec.readAsStringSync())) {
        return Directory(c).absolute;
      }
    }
    throw StateError('lumina_editor_api was not found (looked in ${candidates.join(', ')}). '
        'Set LUMINA_ENGINE_ROOT to the Lumina workspace.');
  }

  /// File → New Plugin (the wizard and the MCP tool
  /// `create_plugin`): generates [spec] under `<projectRoot>/plugins/`, logs
  /// every generator line to [onLog], and rescans the registry on success.
  /// Never enables the plugin: the wizard asks the user, an agent calls
  /// `set_plugin_enabled`. A name [validateNewPluginName] refuses fails
  /// without touching the disk.
  Future<PluginGenerationResult> createPlugin(
    PluginTemplateSpec spec, {
    Directory? projectRoot,
    Directory? editorApiRoot,
    void Function(String message)? onLog,
    PluginTemplateGeneratorService? generator,
  }) async {
    final invalid = validateNewPluginName(spec.name);
    if (invalid != null) {
      onLog?.call(invalid);
      return PluginGenerationResult.failure(failureOutput: invalid, log: [invalid]);
    }
    Directory apiRoot() {
      if (editorApiRoot != null) return editorApiRoot;
      // A content-only plugin has no Dart package, so it needs no API root.
      if (spec.templateType == PluginTemplateType.contentOnly) {
        try {
          return resolveEditorApiRoot();
        } on StateError {
          return Directory.current;
        }
      }
      return resolveEditorApiRoot();
    }

    final service = generator ??
        PluginTemplateGeneratorService(
          projectRoot: projectRoot ?? defaultProjectRoot(),
          editorApiRoot: apiRoot(),
          onLog: onLog,
        );
    final result = await service.generate(spec);
    if (result.success) await refresh();
    return result;
  }
}
