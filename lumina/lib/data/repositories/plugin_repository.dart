import 'dart:convert';
import 'dart:io';

import 'package:pub_semver/pub_semver.dart';
import 'package:path/path.dart' as p;

import '../models/lumina_plugin_descriptor.dart';

enum PluginErrorKind {
  missingManifest,
  multipleManifests,
  malformedJson,
  schemaViolation,
  nameMismatch,
  invalidVersion,
  invalidConstraint,
  duplicateName
}

class PluginScanError {
  final String filePath;
  final PluginErrorKind kind;
  final String message;
  final int? jsonOffset;

  PluginScanError({
    required this.filePath,
    required this.kind,
    required this.message,
    this.jsonOffset,
  });

  @override
  String toString() => 'PluginScanError($kind): $message at $filePath${jsonOffset != null ? ' (offset $jsonOffset)' : ''}';
}

class PluginManifestException implements Exception {
  final PluginScanError error;
  PluginManifestException(this.error);
  
  @override
  String toString() => error.toString();
}

class PluginScanRoot {
  /// The folder whose sub-folders are plugins; for a [PluginScanRoot.packages]
  /// root, the folder the packages were resolved for (the workspace root).
  final Directory dir;
  final PluginOrigin origin;

  /// The plugin folders themselves, when they do not share a parent (the
  /// packages a workspace resolved, wherever they live); null scans [dir]'s
  /// sub-folders.
  final List<Directory>? packageDirs;

  PluginScanRoot({required this.dir, required this.origin}) : packageDirs = null;

  /// A root made of the given plugin folders ([packageDirs]); [dir] is the
  /// workspace they were resolved for.
  PluginScanRoot.packages({required this.dir, required List<Directory> this.packageDirs, required this.origin});

  /// The folders scanned as plugins.
  List<Directory> candidates() {
    final listed = packageDirs;
    if (listed != null) return [for (final d in listed) if (d.existsSync()) d];
    if (!dir.existsSync()) return const [];
    return dir.listSync().whereType<Directory>().toList();
  }
}

class PluginScanResult {
  final List<LuminaPluginDescriptor> plugins;
  final List<PluginScanError> errors;

  PluginScanResult({required this.plugins, required this.errors});
}

class PluginRepository {
  final List<PluginScanRoot> roots;

  PluginRepository({required this.roots});

  Future<PluginScanResult> scanAll() async {
    final allPlugins = <LuminaPluginDescriptor>[];
    final allErrors = <PluginScanError>[];

    // Priority: project > user > engine
    final sortedRoots = List<PluginScanRoot>.from(roots)..sort((a, b) {
      int priority(PluginOrigin o) {
        switch (o) {
          case PluginOrigin.project: return 3;
          case PluginOrigin.user: return 2;
          case PluginOrigin.engine: return 1;
        }
      }
      return priority(b.origin).compareTo(priority(a.origin));
    });

    final seenNames = <String, LuminaPluginDescriptor>{};

    for (final root in sortedRoots) {
      for (final entity in root.candidates()) {
        final manifests = entity.listSync().whereType<File>().where((f) => f.path.endsWith('.lmplugin')).toList();
        
        if (manifests.isEmpty) {
          allErrors.add(PluginScanError(
            filePath: entity.path,
            kind: PluginErrorKind.missingManifest,
            message: 'Directory has no .lmplugin manifest'
          ));
          continue;
        }
        if (manifests.length > 1) {
          allErrors.add(PluginScanError(
            filePath: entity.path,
            kind: PluginErrorKind.multipleManifests,
            message: 'Directory has multiple .lmplugin manifests'
          ));
          continue;
        }

        final manifest = manifests.first;
        try {
          final plugin = await loadInternal(manifest, root.origin);
          
          if (seenNames.containsKey(plugin.name)) {
            allErrors.add(PluginScanError(
              filePath: manifest.path,
              kind: PluginErrorKind.duplicateName,
              message: 'Plugin "${plugin.name}" is shadowed by ${seenNames[plugin.name]!.origin.name} root'
            ));
          } else {
            seenNames[plugin.name] = plugin;
            allPlugins.add(plugin);
          }
        } on PluginManifestException catch (e) {
          allErrors.add(e.error);
        } catch (e) {
          allErrors.add(PluginScanError(
            filePath: manifest.path,
            kind: PluginErrorKind.schemaViolation,
            message: 'Unknown error: $e'
          ));
        }
      }
    }

    return PluginScanResult(plugins: allPlugins, errors: allErrors);
  }

  Future<LuminaPluginDescriptor> load(File manifest) async {
    // Used by wizard, assume user origin if not specified, though usually handled via scan
    return loadInternal(manifest, PluginOrigin.user);
  }

  Future<LuminaPluginDescriptor> loadInternal(File manifest, PluginOrigin origin) async {
    final content = manifest.readAsStringSync();
    dynamic parsed;
    try {
      parsed = jsonDecode(content);
    } on FormatException catch (e) {
      throw PluginManifestException(PluginScanError(
        filePath: manifest.path,
        kind: PluginErrorKind.malformedJson,
        message: 'Malformed JSON: ${e.message}',
        jsonOffset: e.offset,
      ));
    }

    if (parsed is! Map<String, dynamic>) {
      throw PluginManifestException(PluginScanError(
        filePath: manifest.path,
        kind: PluginErrorKind.schemaViolation,
        message: 'Root must be a JSON object',
      ));
    }
    
    // Check name mismatch
    final name = parsed['name'] as String?;
    if (name == null) {
      throw PluginManifestException(PluginScanError(
        filePath: manifest.path,
        kind: PluginErrorKind.schemaViolation,
        message: 'Missing "name" field',
      ));
    }

    final basename = p.basenameWithoutExtension(manifest.path);
    if (name != basename) {
      throw PluginManifestException(PluginScanError(
        filePath: manifest.path,
        kind: PluginErrorKind.nameMismatch,
        message: 'Manifest name "$name" does not match file basename "$basename"',
      ));
    }
    
    // Name validation
    if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(name)) {
      throw PluginManifestException(PluginScanError(
        filePath: manifest.path,
        kind: PluginErrorKind.schemaViolation,
        message: 'Invalid Dart package name "$name"',
      ));
    }

    // Version
    final verString = parsed['version'] as String?;
    if (verString == null) {
      throw PluginManifestException(PluginScanError(
        filePath: manifest.path,
        kind: PluginErrorKind.schemaViolation,
        message: 'Missing "version" field',
      ));
    }
    try {
      Version.parse(verString);
    } catch (e) {
      throw PluginManifestException(PluginScanError(
        filePath: manifest.path,
        kind: PluginErrorKind.invalidVersion,
        message: 'Invalid version string: "$verString"',
      ));
    }

    // Engine version
    final evString = parsed['engine_version'] as String?;
    if (evString != null) {
      try {
        VersionConstraint.parse(evString);
      } catch (e) {
        throw PluginManifestException(PluginScanError(
          filePath: manifest.path,
          kind: PluginErrorKind.invalidConstraint,
          message: 'Invalid engine_version constraint: "$evString"',
        ));
      }
    }

    // Modules
    final mods = parsed['modules'] as List<dynamic>?;
    if (mods != null) {
      for (var i = 0; i < mods.length; i++) {
        final mod = mods[i];
        if (mod is! Map<String, dynamic>) continue;
        final type = mod['type'] as String?;
        if (type != 'editor' && type != 'runtime') {
          throw PluginManifestException(PluginScanError(
            filePath: manifest.path,
            kind: PluginErrorKind.schemaViolation,
            message: '`modules[$i].type` must be "editor" or "runtime", got "$type"',
          ));
        }
      }
    }

    try {
      return LuminaPluginDescriptor.fromJson(parsed, pluginDir: manifest.parent, origin: origin);
    } catch (e) {
      throw PluginManifestException(PluginScanError(
        filePath: manifest.path,
        kind: PluginErrorKind.schemaViolation,
        message: 'Schema validation error: $e',
      ));
    }
  }
}
