import 'dart:io';
import 'package:pub_semver/pub_semver.dart';

import 'lumina_project.dart';

export 'plugin_isolation.dart';

enum PluginOrigin { engine, project, user }

enum PluginModuleType { editor, runtime }

class PluginModuleDescriptor {
  final String name;
  final PluginModuleType type;
  final String entryLibrary;

  /// The in-process `LuminaEditorPlugin` class (`"registration_class"`): the
  /// plugin itself, or the UI shell of an isolated plugin. Null only on an
  /// editor module of an isolated plugin that has no shell (a
  /// `PluginProcessAdapter` or declarative panels only): everything then
  /// runs in its process, nothing registers in the editor process.
  final String? registrationClass;

  /// The `LuminaPluginProcess` subclass in [entryLibrary] that runs in the
  /// plugin's own process (`.lmplugin` `"process_class"`). Required on an
  /// editor module of a plugin with `"isolation": "process"`.
  final String? processClass;

  PluginModuleDescriptor({
    required this.name,
    required this.type,
    required this.entryLibrary,
    this.registrationClass,
    this.processClass,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type.name,
        'entry_library': entryLibrary,
        if (registrationClass != null) 'registration_class': registrationClass,
        if (processClass != null) 'process_class': processClass,
      };

  factory PluginModuleDescriptor.fromJson(Map<String, dynamic> json) {
    return PluginModuleDescriptor(
      name: json['name'] as String,
      type: PluginModuleType.values.byName(json['type'] as String),
      entryLibrary: json['entry_library'] as String,
      registrationClass: json['registration_class'] as String?,
      processClass: json['process_class'] as String?,
    );
  }
}

class PluginDependencyRef {
  final String name;
  final VersionConstraint version;

  PluginDependencyRef({
    required this.name,
    required this.version,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'version': version.toString(),
      };

  factory PluginDependencyRef.fromJson(Map<String, dynamic> json) {
    return PluginDependencyRef(
      name: json['name'] as String,
      version: VersionConstraint.parse(json['version'] as String),
    );
  }
}

class LuminaPluginDescriptor {
  final String name;
  final String? friendlyName;
  final Version version;
  final String? description;
  final String category;
  final List<String> authors;
  final VersionConstraint? engineVersion;
  final List<PluginDependencyRef> dependencies;
  final List<PluginModuleDescriptor> modules;
  final bool enabledByDefault;
  final bool canContainContent;

  /// Where the editor module runs (`.lmplugin` `"isolation"`); a project
  /// can override it (see [effectiveIsolation]).
  final PluginIsolation isolation;
  final Map<String, dynamic> extras;

  // Derived / set by discovery
  final Directory pluginDir;
  final PluginOrigin origin;

  bool get isContentOnly => canContainContent && modules.isEmpty;

  /// The editor module that names a `process_class`, or null.
  PluginModuleDescriptor? get processModule {
    for (final m in modules) {
      if (m.type == PluginModuleType.editor && m.processClass != null) return m;
    }
    return null;
  }

  /// The process part's class name ([processModule]'s `process_class`).
  String? get processClass => processModule?.processClass;

  /// Where this plugin runs in [project]. An isolated plugin
  /// (`"isolation": "process"` with a `process_class`) runs in its own
  /// process unless the project's `plugin_isolation` forces it
  /// `in_process` (the same process part, run inside the editor: how an
  /// isolated plugin is debugged). Any other plugin runs in process: it has
  /// no process part to start, whatever the project says.
  PluginIsolation effectiveIsolation([LuminaProject? project]) {
    if (isolation != PluginIsolation.process || processClass == null) return PluginIsolation.inProcess;
    return project?.pluginIsolation[name] ?? PluginIsolation.process;
  }
  
  File? get iconFile {
    final f = File('${pluginDir.path}/resources/icon128.png');
    return f.existsSync() ? f : null;
  }

  LuminaPluginDescriptor({
    required this.name,
    this.friendlyName,
    required this.version,
    this.description,
    this.category = 'Other',
    this.authors = const [],
    this.engineVersion,
    this.dependencies = const [],
    this.modules = const [],
    this.enabledByDefault = false,
    this.canContainContent = false,
    this.isolation = PluginIsolation.inProcess,
    this.extras = const {},
    required this.pluginDir,
    required this.origin,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'name': name,
      if (friendlyName != null) 'friendly_name': friendlyName,
      'version': version.toString(),
      if (description != null) 'description': description,
      if (category != 'Other') 'category': category,
      if (authors.isNotEmpty) 'authors': authors,
      if (engineVersion != null) 'engine_version': engineVersion.toString(),
      if (dependencies.isNotEmpty)
        'dependencies': dependencies.map((e) => e.toJson()).toList(),
      if (modules.isNotEmpty) 'modules': modules.map((e) => e.toJson()).toList(),
      if (enabledByDefault) 'enabled_by_default': true,
      if (canContainContent) 'can_contain_content': true,
      if (isolation != PluginIsolation.inProcess) 'isolation': isolation.manifestValue,
    };
    json.addAll(extras);
    return json;
  }

  factory LuminaPluginDescriptor.fromJson(Map<String, dynamic> json, {required Directory pluginDir, required PluginOrigin origin}) {
    final extras = Map<String, dynamic>.from(json);
    
    final name = extras.remove('name') as String;
    final friendlyName = extras.remove('friendly_name') as String?;
    final version = Version.parse(extras.remove('version') as String);
    final description = extras.remove('description') as String?;
    
    // category could have been empty string
    final rawCategory = json['category'] as String?;
    final actualCategory = (rawCategory == null || rawCategory.isEmpty) ? 'Other' : rawCategory;
    if (json.containsKey('category')) extras.remove('category');

    final authorsList = extras.remove('authors') as List<dynamic>? ?? [];
    final authors = authorsList.map((e) => e.toString()).toList();
    
    final rawEngineVersion = extras.remove('engine_version') as String?;
    final engineVersion = rawEngineVersion != null ? VersionConstraint.parse(rawEngineVersion) : null;
    
    final depsList = extras.remove('dependencies') as List<dynamic>? ?? [];
    final dependencies = depsList.map((e) => PluginDependencyRef.fromJson(e as Map<String, dynamic>)).toList();
    
    final modsList = extras.remove('modules') as List<dynamic>? ?? [];
    final modules = modsList.map((e) => PluginModuleDescriptor.fromJson(e as Map<String, dynamic>)).toList();
    
    final enabledByDefault = extras.remove('enabled_by_default') as bool? ?? false;
    final canContainContent = extras.remove('can_contain_content') as bool? ?? false;

    final rawIsolation = extras.remove('isolation');
    final isolation = rawIsolation == null ? PluginIsolation.inProcess : PluginIsolation.tryParse(rawIsolation);
    if (isolation == null) {
      throw FormatException('"isolation" must be "in_process" or "process", got "$rawIsolation"');
    }

    return LuminaPluginDescriptor(
      name: name,
      friendlyName: friendlyName,
      version: version,
      description: description,
      category: actualCategory,
      authors: authors,
      engineVersion: engineVersion,
      dependencies: dependencies,
      modules: modules,
      enabledByDefault: enabledByDefault,
      canContainContent: canContainContent,
      isolation: isolation,
      extras: extras,
      pluginDir: pluginDir,
      origin: origin,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LuminaPluginDescriptor &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          version == other.version &&
          pluginDir.path == other.pluginDir.path;

  @override
  int get hashCode => name.hashCode ^ version.hashCode ^ pluginDir.path.hashCode;
}
