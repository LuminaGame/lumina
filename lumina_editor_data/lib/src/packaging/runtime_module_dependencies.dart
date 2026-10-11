import 'dart:convert';
import 'dart:io';

import 'package:lumina_core/lumina_core.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// One enabled plugin's runtime module as a game dependency.
class RuntimeModuleDependency {
  /// The plugin's name (`.lmplugin` `name`).
  final String plugin;

  /// The Dart package the game depends on (the plugin folder's pubspec name).
  final String package;

  /// The library the generated registration imports
  /// (`package:lumina_plugin_openxr/runtime.dart`).
  final String library;

  /// The class whose static `register(settings)` the game calls.
  final String registrationClass;

  /// The plugin folder (absolute, `/`-separated).
  final String dir;

  /// The git source when the plugin folder is a git checkout with a remote:
  /// the URL, the path inside the repository (null at its root) and the
  /// commit checked out.
  final String? gitUrl;
  final String? gitPath;
  final String? gitRef;

  /// Packages the plugin's own `pubspec_overrides.yaml` pins to local
  /// folders (name → absolute dir): its local closure.
  final Map<String, String> closure;

  const RuntimeModuleDependency({
    required this.plugin,
    required this.package,
    required this.library,
    required this.registrationClass,
    required this.dir,
    this.gitUrl,
    this.gitPath,
    this.gitRef,
    this.closure = const {},
  });

  /// Whether the pubspec names a git source (published) rather than the folder.
  bool get isGit => gitUrl != null && gitRef != null;

  /// The import prefix in the generated registration file.
  String get alias => package;
}

/// Makes every enabled plugin's `runtime` module a dependency of the game:
///
/// - `pubspec.yaml` lists the plugin packages between
///   [pubspecBegin] / [pubspecEnd] under `dependencies:`: the git URL and
///   commit when the plugin folder is a git checkout with a remote, else the
///   folder's path;
/// - a git plugin checked out locally is pinned to that checkout (and the
///   packages its own `pubspec_overrides.yaml` pins) in the project's
///   gitignored `pubspec_overrides.yaml`, inside
///   [ProjectEngineLink.pluginOverridesBegin] (kept when the engine link
///   rewrites the file);
/// - `lib/plugin_runtime_modules.g.dart` imports each module's library and
///   calls its registration class's `register(settings)` from
///   `registerPluginRuntimeModules()`, which the generated `main()` runs
///   first.
///
/// Disabling a plugin and applying again removes all three.
abstract final class RuntimeModuleDependencies {
  static const String pubspecBegin = '  # BEGIN LUMINA PLUGINS (generated)';
  static const String pubspecEnd = '  # END LUMINA PLUGINS';

  /// The registration file, relative to the project.
  static const String registrationFile = 'lib/plugin_runtime_modules.g.dart';

  static String _slash(String path) => p.normalize(p.absolute(path)).replaceAll(r'\', '/');

  /// The runtime modules of [enabled] (plugins without one are skipped),
  /// sorted by plugin name.
  static Future<List<RuntimeModuleDependency>> resolve(List<LuminaPluginDescriptor> enabled) async {
    final out = <RuntimeModuleDependency>[];
    for (final plugin in [...enabled]..sort((a, b) => a.name.compareTo(b.name))) {
      final modules = plugin.runtimeModules;
      if (modules.isEmpty) continue;
      final module = modules.first;
      final registration = module.registrationClass;
      if (registration == null) continue;
      // The folder itself, not a link to it (a project plugin is often a
      // junction to its checkout): git and the pins need the real path.
      final dir = _slash(await plugin.pluginDir.resolveSymbolicLinks());
      var package = plugin.name;
      String? repository;
      final pubspec = File('$dir/pubspec.yaml');
      if (await pubspec.exists()) {
        final yaml = loadYaml(await pubspec.readAsString());
        if (yaml is YamlMap) {
          package = '${yaml['name'] ?? plugin.name}';
          final repo = yaml['repository'];
          if (repo is String && repo.isNotEmpty) repository = repo;
        }
      }
      final entry = module.entryLibrary.replaceAll(r'\', '/');
      final library = 'package:$package/${entry.startsWith('lib/') ? entry.substring(4) : entry}';
      final git = await _gitSource(dir, repository);
      out.add(RuntimeModuleDependency(
        plugin: plugin.name,
        package: package,
        library: library,
        registrationClass: registration,
        dir: dir,
        gitUrl: git?.url,
        gitPath: git?.path,
        gitRef: git?.ref,
        closure: await _localClosure(dir),
      ));
    }
    return out;
  }

  /// The git source of [dir]: its repository's `origin` URL (else
  /// [repository]), the folder's path inside it and HEAD; null when [dir] is
  /// not in a git checkout or neither URL is known.
  static Future<({String url, String? path, String ref})?> _gitSource(String dir, String? repository) async {
    Future<String?> git(List<String> args) async {
      try {
        final r = await Process.run('git', ['-C', dir, ...args]);
        if (r.exitCode != 0) return null;
        final out = '${r.stdout}'.trim();
        return out.isEmpty ? null : out;
      } on ProcessException {
        return null;
      }
    }

    final top = await git(['rev-parse', '--show-toplevel']);
    if (top == null) return null;
    final ref = await git(['rev-parse', 'HEAD']);
    final url = await git(['remote', 'get-url', 'origin']) ?? repository;
    if (ref == null || url == null) return null;
    final rel = p.relative(dir, from: top).replaceAll(r'\', '/');
    return (url: url, path: rel == '.' ? null : rel, ref: ref);
  }

  /// The local folders [dir]'s own `pubspec_overrides.yaml` pins.
  static Future<Map<String, String>> _localClosure(String dir) async {
    final file = File('$dir/pubspec_overrides.yaml');
    if (!await file.exists()) return const {};
    final yaml = loadYaml(await file.readAsString());
    final overrides = yaml is YamlMap ? yaml['dependency_overrides'] : null;
    if (overrides is! YamlMap) return const {};
    final out = <String, String>{};
    for (final e in overrides.entries) {
      final v = e.value;
      if (v is YamlMap && v['path'] is String) {
        final path = v['path'] as String;
        final abs = p.isAbsolute(path) ? path : p.join(dir, path);
        if (Directory(abs).existsSync()) out['${e.key}'] = _slash(abs);
      }
    }
    return out;
  }

  /// The `dependencies:` block for [deps] (markers included), or empty.
  static String pubspecBlock(List<RuntimeModuleDependency> deps) {
    if (deps.isEmpty) return '';
    final b = StringBuffer('$pubspecBegin\n');
    for (final d in deps) {
      if (d.isGit) {
        b
          ..writeln('  ${d.package}:')
          ..writeln('    git:')
          ..writeln('      url: ${d.gitUrl}');
        if (d.gitPath != null) b.writeln('      path: ${d.gitPath}');
        b.writeln('      ref: ${d.gitRef}');
      } else {
        b
          ..writeln('  ${d.package}:')
          ..writeln("    path: '${d.dir}'");
      }
    }
    b.writeln(pubspecEnd);
    return b.toString();
  }

  /// The overrides block: every git plugin pinned to its local checkout,
  /// plus the local closures (a package named twice keeps its first folder).
  /// Packages in [exclude] (pinned elsewhere in the file, by the engine
  /// link) are left out: a second key would be invalid YAML.
  static String overridesBlock(List<RuntimeModuleDependency> deps, {Set<String> exclude = const {}}) {
    final pins = <String, String>{};
    for (final d in deps) {
      if (d.isGit) pins.putIfAbsent(d.package, () => d.dir);
    }
    for (final d in deps) {
      for (final e in d.closure.entries) {
        pins.putIfAbsent(e.key, () => e.value);
      }
    }
    pins.removeWhere((name, _) => exclude.contains(name));
    if (pins.isEmpty) return '';
    final b = StringBuffer('${ProjectEngineLink.pluginOverridesBegin}\n');
    for (final name in pins.keys.toList()..sort()) {
      b
        ..writeln('  $name:')
        ..writeln("    path: '${pins[name]}'");
    }
    b.writeln(ProjectEngineLink.pluginOverridesEnd);
    return b.toString();
  }

  /// `lib/plugin_runtime_modules.g.dart` for [deps] with [settings] (JSON
  /// values) handed to every registration.
  static String registrationSource(List<RuntimeModuleDependency> deps, Map<String, Object?> settings) {
    final b = StringBuffer()
      ..writeln('// GENERATED CODE - DO NOT MODIFY BY HAND')
      ..writeln('// The enabled plugins\' runtime modules (Project Settings > Plugins).')
      ..writeln('// ignore_for_file: directives_ordering, unused_import')
      ..writeln();
    for (final d in deps) {
      b.writeln("import '${d.library}' as ${d.alias};");
    }
    b
      ..writeln()
      ..writeln('/// The project settings each runtime module is registered with.')
      ..writeln('const Map<String, Object?> kPluginRuntimeSettings = ${_literal(settings)};')
      ..writeln()
      ..writeln('/// Registers every enabled plugin\'s runtime module (its components,')
      ..writeln('/// Blueprint nodes and presentation), before the game starts.')
      ..writeln('void registerPluginRuntimeModules() {');
    for (final d in deps) {
      b.writeln('  ${d.alias}.${d.registrationClass}.register(kPluginRuntimeSettings);');
    }
    b.writeln('}');
    return b.toString();
  }

  static String _literal(Object? v) {
    if (v == null || v is bool || v is num) return '$v';
    if (v is String) return "'${v.replaceAll(r'\', r'\\').replaceAll("'", r"\'").replaceAll(r'$', r'\$')}'";
    if (v is List) return '<Object?>[${v.map(_literal).join(', ')}]';
    if (v is Map) return '<String, Object?>{${v.entries.map((e) => '${_literal('${e.key}')}: ${_literal(e.value)}').join(', ')}}';
    return _literal(jsonEncode(v));
  }

  /// Applies [deps] to [projectDir] (pubspec block, overrides block,
  /// registration file); returns whether `pubspec.yaml` or the overrides
  /// changed (the caller then runs `flutter pub get`).
  static Future<bool> apply(String projectDir, List<RuntimeModuleDependency> deps,
      {Map<String, Object?> settings = const {}}) async {
    var changed = false;
    final pubspec = File('$projectDir/pubspec.yaml');
    if (!await pubspec.exists()) {
      // Nothing to add and nothing written before: a folder that is not a
      // Flutter app yet has nothing to clean up either.
      if (deps.isEmpty) return false;
      throw StateError('No pubspec.yaml in $projectDir');
    }
    final raw = await pubspec.readAsString();
    final crlf = raw.contains('\r\n');
    final original = raw.replaceAll('\r\n', '\n');
    var text = _withoutBlock(original, pubspecBegin, pubspecEnd);
    final block = pubspecBlock(deps);
    if (block.isNotEmpty) {
      // A hand-added dependency on the same package would be a duplicate key.
      for (final d in deps) {
        text = _withoutDependency(text, d.package);
      }
      final m = RegExp(r'^dependencies:[ \t]*\n', multiLine: true).firstMatch(text);
      text = m == null ? '$text\ndependencies:\n$block' : text.replaceRange(m.end, m.end, block);
    }
    if (text != original) {
      await pubspec.writeAsString(crlf ? text.replaceAll('\n', '\r\n') : text);
      changed = true;
    }

    final overrides = File('$projectDir/${ProjectEngineLink.overridesFileName}');
    final before = await overrides.exists() ? await overrides.readAsString() : '';
    final others = ProjectEngineLink.withPluginOverridesBlock(before, '');
    final pinned = {for (final m in RegExp(r'^  ([A-Za-z_][A-Za-z0-9_]*):', multiLine: true).allMatches(others)) m.group(1)!};
    final after = ProjectEngineLink.withPluginOverridesBlock(before, overridesBlock(deps, exclude: pinned));
    if (after != before.replaceAll('\r\n', '\n') && !(before.isEmpty && after.isEmpty)) {
      await overrides.writeAsString(after);
      ProjectEngineLink.ensureOverridesIgnored(projectDir);
      changed = true;
    }

    final registration = File('$projectDir/$registrationFile');
    if (deps.isEmpty) {
      if (await registration.exists()) await registration.delete();
    } else {
      final source = registrationSource(deps, settings);
      if (!await registration.exists() || await registration.readAsString() != source) {
        await registration.parent.create(recursive: true);
        await registration.writeAsString(source);
      }
    }
    return changed;
  }

  static String _withoutBlock(String text, String begin, String end) {
    final start = text.indexOf(begin);
    if (start < 0) return text;
    final stop = text.indexOf(end, start);
    if (stop < 0) return text;
    var e = stop + end.length;
    if (e < text.length && text[e] == '\n') e++;
    return text.replaceRange(start, e, '');
  }

  /// [text] without a top-level `dependencies:` entry for [package] outside
  /// the generated block (a hand-added one).
  static String _withoutDependency(String text, String package) {
    final lines = text.split('\n');
    final deps = lines.indexWhere((l) => RegExp(r'^dependencies:\s*$').hasMatch(l));
    if (deps < 0) return text;
    for (var i = deps + 1; i < lines.length; i++) {
      final l = lines[i];
      if (l.isNotEmpty && !l.startsWith(' ') && !l.startsWith('#')) break;
      if (RegExp('^  ${RegExp.escape(package)}:').hasMatch(l)) {
        var j = i + 1;
        while (j < lines.length && (lines[j].startsWith('    ') || lines[j].trim().isEmpty && j + 1 < lines.length && lines[j + 1].startsWith('    '))) {
          j++;
        }
        lines.removeRange(i, j);
        break;
      }
    }
    return lines.join('\n');
  }
}
