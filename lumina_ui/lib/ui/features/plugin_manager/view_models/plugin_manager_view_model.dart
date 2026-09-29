import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lumina/data/services/plugin_registry_service.dart';
import 'package:lumina/data/services/plugin_template_generator_service.dart';
import 'package:lumina/data/services/workspace_paths.dart';
import 'package:lumina/data/models/lumina_plugin_descriptor.dart';
import 'package:lumina/data/repositories/plugin_repository.dart';

class PluginManagerViewModel extends ChangeNotifier {
  final PluginRegistryService registryService;
  final Future<void> Function(String name, bool enabled, {bool cascade})? onSetEnabled;

  String _searchQuery = '';
  String _selectedCategory = 'ALL PLUGINS';
  String _selectedGroup = 'ALL'; // ALL, INSTALLED, BUILT-IN
  PluginEntry? _selectedEntry;

  PluginManagerViewModel({
    required this.registryService,
    this.onSetEnabled,
  });

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
