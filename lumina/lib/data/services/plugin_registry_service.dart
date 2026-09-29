import 'dart:io';
import 'package:lumina/data/models/lumina_plugin_descriptor.dart';
import 'package:lumina/data/models/lumina_project.dart';
import 'package:lumina/data/repositories/plugin_repository.dart';
import 'package:lumina/data/repositories/project_repository.dart';
import 'package:lumina/data/services/editor_host_generator_service.dart';
import 'package:pub_semver/pub_semver.dart';

enum PluginIssueType {
  missingDependency,
  versionConflict,
  dependencyCycle,
  engineVersionMismatch,
  requiredBy,
  missingPlugin,

  /// A menu item under a built-in menu or an unknown root.
  invalidMenuPath,

  /// A top-level menu title already taken (built-in or another
  /// plugin's).
  menuConflict,

  /// More plugin top-level menus than the title bar holds; the
  /// extra menu folds into `Plugins ▸ <title>`.
  tooManyMenus,
}

class PluginIssue {
  final PluginIssueType type;
  final String message;
  PluginIssue(this.type, this.message);
}

class PluginEntry {
  final LuminaPluginDescriptor descriptor;
  bool enabled;
  bool restartPending;
  List<PluginIssue> issues;

  PluginEntry({
    required this.descriptor,
    this.enabled = false,
    this.restartPending = false,
    this.issues = const [],
  });
}

class PluginResolution {
  final List<LuminaPluginDescriptor> resolvedPlugins;
  final List<PluginIssue> issues;
  PluginResolution(this.resolvedPlugins, this.issues);
}

class EnableResult {
  final bool restartRequired;
  final List<PluginIssue> issues;
  EnableResult({required this.restartRequired, required this.issues});
}

class PluginRegistryService {
  final PluginRepository repo;
  final ProjectRepository projectRepo;

  /// A code-plugin change regenerates the open project's editor
  /// host (`<project>/.lumina/editor/`) — never the engine checkout.
  final EditorHostGeneratorService? hostGenerator;

  final Map<String, PluginEntry> _entries = {};
  final List<PluginScanError> _scanErrors = [];
  
  LuminaProject? _currentProject;
  String? _currentProjectDirPath;

  PluginRegistryService({required this.repo, required this.projectRepo, this.hostGenerator});

  /// The enabled plugins that contribute editor code.
  List<LuminaPluginDescriptor> get enabledCodePlugins =>
      EditorHostGeneratorService.editorCodePlugins([for (final e in _entries.values) if (e.enabled) e.descriptor]);

  Future<void> _regenerateHost() async {
    final generator = hostGenerator;
    final dir = _currentProjectDirPath;
    if (generator == null || dir == null) return;
    await generator.generate(dir, enabledCodePlugins, projectName: _currentProject?.projectName);
  }

  List<PluginEntry> get entries => _entries.values.toList();
  List<PluginScanError> get scanErrors => _scanErrors;

  Future<void> refresh() async {
    if (_currentProjectDirPath != null) {
      await initialize(_currentProjectDirPath!);
    }
  }

  Future<void> initialize(String projectDirPath) async {
    _entries.clear();
    _scanErrors.clear();
    _currentProjectDirPath = projectDirPath;
    
    final proj = await projectRepo.loadProject('$projectDirPath/project.lmproject');
    if (proj == null) {
      final dir = Directory(projectDirPath);
      if (dir.existsSync()) {
        final list = dir.listSync().where((f) => f.path.endsWith('.lmproject')).toList();
        if (list.isNotEmpty) {
          _currentProject = await projectRepo.loadProject(list.first.path);
        }
      }
    } else {
      _currentProject = proj;
    }
    
    if (_currentProject == null) return;
    
    final scanResult = await repo.scanAll();
    _scanErrors.addAll(scanResult.errors);
    
    final savedEnabled = _currentProject!.enabledPlugins;
    bool needsSave = false;
    
    for (final desc in scanResult.plugins) {
      _entries[desc.name] = PluginEntry(descriptor: desc);
    }
    
    if (savedEnabled == null) {
      for (final desc in scanResult.plugins) {
        if (desc.enabledByDefault) {
          _entries[desc.name]!.enabled = true;
          needsSave = true;
        }
      }
    } else {
      for (final name in savedEnabled) {
        if (_entries.containsKey(name)) {
          _entries[name]!.enabled = true;
        }
      }
    }
    
    if (needsSave) {
      await _saveProjectState();
    }
  }

  Future<void> _saveProjectState() async {
    if (_currentProject == null || _currentProjectDirPath == null) return;
    
    final enabledNames = _entries.values
        .where((e) => e.enabled)
        .map((e) => e.descriptor.name)
        .toList()
      ..sort();
      
    final updated = _currentProject!.copyWith(enabledPlugins: enabledNames);
    _currentProject = updated;
    await projectRepo.saveProject(updated, _currentProjectDirPath!);
  }

  PluginResolution resolve(Set<String> wantedEnabled) {
    final issues = <PluginIssue>[];
    final resolved = <LuminaPluginDescriptor>[];
    final visited = <String>{};
    final visiting = <String>{};

    void visit(String name, String? requestedBy) {
      if (visiting.contains(name)) {
        issues.add(PluginIssue(PluginIssueType.dependencyCycle, 'Dependency cycle detected: ${visiting.join(" -> ")} -> $name'));
        return;
      }
      if (visited.contains(name)) return;

      final entry = _entries[name];
      if (entry == null) {
        issues.add(PluginIssue(PluginIssueType.missingDependency, 'Missing dependency $name (requested by $requestedBy)'));
        return;
      }

      visiting.add(name);

      for (final dep in entry.descriptor.dependencies) {
        final depEntry = _entries[dep.name];
        if (depEntry == null) {
          issues.add(PluginIssue(PluginIssueType.missingDependency, 'Missing dependency ${dep.name} (requested by $name)'));
        } else {
          if (!dep.version.allows(depEntry.descriptor.version)) {
            issues.add(PluginIssue(PluginIssueType.versionConflict, 'Version conflict: $name requires ${dep.name} ${dep.version}, found ${depEntry.descriptor.version}'));
          }
          visit(dep.name, name);
        }
      }

      visiting.remove(name);
      visited.add(name);
      resolved.add(entry.descriptor);
    }

    // Convert Set to sorted list for deterministic tie-break by name
    final sortedWanted = wantedEnabled.toList()..sort();
    for (final name in sortedWanted) {
      visit(name, 'user');
    }

    return PluginResolution(resolved, issues);
  }

  Future<EnableResult> setEnabled(String name, bool enabled, {bool cascade = false}) async {
    if (enabled) {
      final wanted = _entries.values.where((e) => e.enabled).map((e) => e.descriptor.name).toSet();
      wanted.add(name);
      
      final res = resolve(wanted);
      if (res.issues.isNotEmpty) {
        return EnableResult(restartRequired: false, issues: res.issues);
      }
      
      bool restartRequired = false;
      for (final desc in res.resolvedPlugins) {
        final entry = _entries[desc.name]!;
        if (!entry.enabled) {
          entry.enabled = true;
          if (!desc.isContentOnly) {
            entry.restartPending = true;
            restartRequired = true;
          }
        }
      }
      
      await _saveProjectState();
      if (restartRequired) await _regenerateHost();
      return EnableResult(restartRequired: restartRequired, issues: []);
      
    } else {
      // Disable
      final dependents = <String>[];
      for (final entry in _entries.values.where((e) => e.enabled)) {
        if (entry.descriptor.name == name) continue;
        if (entry.descriptor.dependencies.any((d) => d.name == name)) {
          dependents.add(entry.descriptor.name);
        }
      }
      
      if (dependents.isNotEmpty && !cascade) {
        return EnableResult(
          restartRequired: false,
          issues: [PluginIssue(PluginIssueType.requiredBy, 'Plugin $name is required by ${dependents.join(", ")}')],
        );
      }
      
      final toDisable = {name};
      if (cascade) {
        toDisable.addAll(dependents);
      }
      
      bool restartRequired = false;
      for (final disableName in toDisable) {
        final entry = _entries[disableName];
        if (entry != null && entry.enabled) {
          entry.enabled = false;
          if (!entry.descriptor.isContentOnly) {
            entry.restartPending = true;
            restartRequired = true;
          }
        }
      }
      
      await _saveProjectState();
      if (restartRequired) await _regenerateHost();
      return EnableResult(restartRequired: restartRequired, issues: []);
    }
  }
}
