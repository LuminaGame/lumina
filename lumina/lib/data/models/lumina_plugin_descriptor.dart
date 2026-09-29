import 'dart:io';
import 'package:pub_semver/pub_semver.dart';

enum PluginOrigin { engine, project, user }

enum PluginModuleType { editor, runtime }

class PluginModuleDescriptor {
  final String name;
  final PluginModuleType type;
  final String entryLibrary;
  final String registrationClass;

  PluginModuleDescriptor({
    required this.name,
    required this.type,
    required this.entryLibrary,
    required this.registrationClass,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type.name,
        'entry_library': entryLibrary,
        'registration_class': registrationClass,
      };

  factory PluginModuleDescriptor.fromJson(Map<String, dynamic> json) {
    return PluginModuleDescriptor(
      name: json['name'] as String,
      type: PluginModuleType.values.byName(json['type'] as String),
      entryLibrary: json['entry_library'] as String,
      registrationClass: json['registration_class'] as String,
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
  final Map<String, dynamic> extras;

  // Derived / set by discovery
  final Directory pluginDir;
  final PluginOrigin origin;

  bool get isContentOnly => canContainContent && modules.isEmpty;
  
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
    final category = extras.remove('category') as String? ?? (extras['category'] == '' ? 'Other' : 'Other');
    
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
