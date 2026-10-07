import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'package:lumina/data/services/directory_link.dart';
import 'package:lumina/data/services/editor_source_vendor_service.dart';
import 'package:lumina/data/services/workspace_paths.dart';

/// How a game project reaches the engine.
///
/// The project's `pubspec.yaml` depends on `lumina` through git
/// ([kLuminaGitUrl], `path: lumina`), so it is committable and builds on any
/// machine once the LuminaGame repos are published. One of two things makes
/// it build on the machine of the engine checkout the editor runs from:
///
/// - a gitignored `pubspec_overrides.yaml` pinning `lumina` and every package
///   of its path/git closure (`flutter_filament`, the tools packages, …) to
///   the local checkout (absolute `/`-separated paths: the project folder and
///   the engine are on unrelated paths, often on different drives); each
///   local package's hook then finds Filament through its own `../filament`.
///   A release checkout resolves the tools packages from git (the pub cache),
///   where nothing is beside them: then the hook settings below are written
///   too, relative to the project and naming gitignored links in
///   [engineLinksDir] to the engine's native build folders, so the committed
///   pubspec holds no machine path;
/// - or, building against git, `hooks: user_defines:` in `pubspec.yaml` telling the native-assets hooks
///   of flutter_filament / flutter_assimp / flutter_riglogic where this
///   machine's Filament build, libc++ and RigLogic library are. A package
///   resolved from git (a pub-cache checkout) has no `../filament` beside
///   it. The hooks runner reads user-defines from the root `pubspec.yaml`
///   only (pub rejects a `hooks` key in `pubspec_overrides.yaml`), so this
///   block holds machine paths; it is rewritten whenever the project is
///   linked again.
class ProjectEngineLink {
  ProjectEngineLink._();

  static const String overridesFileName = 'pubspec_overrides.yaml';

  /// The packages whose hooks take the settings [hookUserDefines] writes.
  static const List<String> hookedPackages = ['flutter_filament', 'flutter_assimp', 'flutter_riglogic'];

  /// The first line of the generated `hooks:` comment, found again on
  /// every relink.
  static const String hooksMarker = '# Lumina Studio: where this machine keeps the engine\'s native builds';

  /// The project folder (under the gitignored `.lumina/`) holding links to the
  /// engine's native build folders that the relative hook settings name.
  static const String engineLinksDir = '.lumina/engine';

  /// Whether a hooked package of [packages] (name → dir) has no Filament
  /// beside it (`<package>/../filament`): the engine resolved it from git,
  /// into the pub cache, so its hook needs the settings.
  static bool needsHookUserDefines(Map<String, String> packages) {
    for (final name in hookedPackages) {
      final dir = packages[name];
      if (dir == null) continue;
      if (FileSystemEntity.typeSync(p.join(dir, '..', 'filament')) == FileSystemEntityType.notFound) return true;
    }
    return false;
  }

  /// [hookUserDefines] made relative: every folder it names gets a link in
  /// `<projectDir>/.lumina/engine/` (named after its setting, `_dir` dropped:
  /// `filament`, `riglogic_lib`, `libcxx`), and the settings name those links
  /// relative to the project's pubspec. Links no setting names any more are
  /// removed. The links are junctions on Windows ([DirectoryLink]).
  static Map<String, Map<String, String>> linkedHookUserDefines(String projectDir, String engineRoot,
      {Map<String, String>? packages}) {
    final absolute = hookUserDefines(engineRoot, packages: packages);
    final linksDir = Directory(p.join(projectDir, engineLinksDir));
    final targets = <String, String>{}; // link name -> target dir
    final out = <String, Map<String, String>>{};
    for (final MapEntry(key: package, value: settings) in absolute.entries) {
      for (final MapEntry(key: key, value: uri) in settings.entries) {
        final target = p.normalize(Directory.fromUri(Uri.parse(uri)).path);
        var name = key.endsWith('_dir') ? key.substring(0, key.length - 4) : key;
        if (targets[name] != null && !p.equals(targets[name]!, target)) name = '${name}_$package';
        targets[name] = target;
        (out[package] ??= {})[key] = '$engineLinksDir/$name';
      }
    }
    _syncLinks(linksDir, targets);
    return out;
  }

  /// Makes [linksDir] hold exactly [targets] (name → dir) as links.
  static void _syncLinks(Directory linksDir, Map<String, String> targets) {
    if (linksDir.existsSync()) {
      for (final e in linksDir.listSync(followLinks: false)) {
        if (e is! Link) continue;
        final target = targets[p.basename(e.path)];
        if (target != null && _sameDir(e.targetSync(), target)) continue;
        e.deleteSync();
      }
    }
    for (final MapEntry(key: name, value: target) in targets.entries) {
      final link = Link(p.join(linksDir.path, name));
      if (link.existsSync()) continue;
      linksDir.createSync(recursive: true);
      DirectoryLink.createSync(link.path, target);
    }
    if (targets.isEmpty && linksDir.existsSync() && linksDir.listSync().isEmpty) linksDir.deleteSync();
  }

  static bool _sameDir(String a, String b) {
    String norm(String s) {
      final n = p.normalize(s.startsWith(r'\\?\') ? s.substring(4) : s);
      return Platform.isWindows ? n.toLowerCase() : n;
    }

    return norm(a) == norm(b);
  }

  /// The git form of the engine dependency (no trailing newline), from [url]
  /// at [ref]. Both default to the engine checkout the editor fetched for
  /// its release ([LuminaWorkspace.engineRepo], [LuminaWorkspace.engineCommit]),
  /// so a project generated by a release editor builds against that exact
  /// commit; from a source workspace the URL is [kLuminaGitUrl] and there is
  /// no `ref:` (the default branch).
  static String engineDependency({String indent = '  ', String? ref, String? url}) {
    final pin = ref ?? LuminaWorkspace.engineCommit;
    final repo = url ?? LuminaWorkspace.engineRepo ?? kLuminaGitUrl;
    return '${indent}lumina:\n$indent  git:\n$indent    url: $repo\n$indent    path: lumina'
        '${pin == null || pin.isEmpty ? '' : '\n$indent    ref: $pin'}';
  }

  /// The engine workspace root holding [luminaPackageDir] (default
  /// [LuminaWorkspace.package]`('lumina')`), or null when it is not a local
  /// checkout (no `lumina/pubspec.yaml` there).
  static String? localEngineRoot({String? luminaPackageDir}) {
    final lumina = luminaPackageDir ?? LuminaWorkspace.package('lumina');
    if (!File(p.join(lumina, 'pubspec.yaml')).existsSync()) return null;
    return p.dirname(p.normalize(p.absolute(lumina)));
  }

  /// `lumina` and every package of its path/git closure as [engineRoot]
  /// resolved them (name → absolute dir). When the closure cannot be walked
  /// (the engine was never `pub get`-ed), only `lumina` and the
  /// `flutter_filament` beside it.
  static Map<String, String> localPackages(String engineRoot, {void Function(String)? onLog}) {
    final out = <String, String>{};
    try {
      final sources = EditorSourceVendorService(engineRoot: engineRoot, rootPackage: 'lumina').packageSources();
      for (final dir in sources.values) {
        final yaml = loadYaml(File(p.join(dir, 'pubspec.yaml')).readAsStringSync());
        final name = yaml is YamlMap ? yaml['name'] : null;
        if (name != null) out['$name'] = p.normalize(p.absolute(dir));
      }
    } on StateError catch (e) {
      onLog?.call('Could not resolve the engine closure of $engineRoot (${e.message}); pinning lumina and flutter_filament only');
    } on Exception catch (e) {
      onLog?.call('Could not resolve the engine closure of $engineRoot ($e); pinning lumina and flutter_filament only');
    }
    for (final name in ['lumina', 'flutter_filament']) {
      final dir = p.join(engineRoot, name);
      if (File(p.join(dir, 'pubspec.yaml')).existsSync()) out.putIfAbsent(name, () => p.normalize(p.absolute(dir)));
    }
    return out;
  }

  /// The `pubspec_overrides.yaml` pinning [packages] (name → dir).
  static String overridesYaml(Map<String, String> packages, String engineRoot) {
    final b = StringBuffer()
      ..writeln('# Local development (gitignored): the engine checkout at')
      ..writeln('# ${_slash(engineRoot)}')
      ..writeln('# instead of the git dependencies in pubspec.yaml. Written by Lumina')
      ..writeln('# Studio; delete this file to build against $kLuminaGitUrl.')
      ..writeln('dependency_overrides:');
    for (final name in packages.keys.toList()..sort()) {
      b
        ..writeln('  $name:')
        ..writeln("    path: '${_slash(packages[name]!)}'");
    }
    return b.toString();
  }

  /// The hook settings (package → key → the dir's `file:` URI) for
  /// this machine: the engine workspace's own `hooks: user_defines:`
  /// (relative to its root pubspec), `<engine>/filament` when it names no
  /// Filament, and the built RigLogic library of the flutter_riglogic
  /// [packages] resolves to. Only directories that exist are kept.
  static Map<String, Map<String, String>> hookUserDefines(String engineRoot, {Map<String, String>? packages}) {
    final out = <String, Map<String, String>>{};
    void put(String package, String key, String dir) {
      if (!Directory(dir).existsSync()) return;
      // A file URI, not a path: the hooks resolve the value against the
      // pubspec's URI (`Uri.resolve`), which reads `D:/…` as a URI with
      // the scheme `d`.
      (out[package] ??= {})[key] = Uri.directory(p.normalize(p.absolute(dir))).toString();
    }

    final rootPubspec = File(p.join(engineRoot, 'pubspec.yaml'));
    if (rootPubspec.existsSync()) {
      try {
        final yaml = loadYaml(rootPubspec.readAsStringSync());
        final hooks = yaml is YamlMap ? yaml['hooks'] : null;
        final defines = hooks is YamlMap ? hooks['user_defines'] : null;
        if (defines is YamlMap) {
          for (final e in defines.entries) {
            final package = '${e.key}';
            if (!hookedPackages.contains(package) || e.value is! YamlMap) continue;
            for (final d in (e.value as YamlMap).entries) {
              final value = '${d.value}';
              put(package, '${d.key}', p.isAbsolute(value) ? value : p.join(engineRoot, value));
            }
          }
        }
      } on YamlException {
        // An unreadable engine pubspec: the defaults below still apply.
      }
    }
    final filament = p.join(engineRoot, 'filament');
    for (final package in ['flutter_filament', 'flutter_assimp']) {
      if (out[package]?['filament_dir'] == null) put(package, 'filament_dir', filament);
    }
    final riglogic = packages?['flutter_riglogic'] ?? LuminaWorkspace.resolvedPackageDir(engineRoot, 'flutter_riglogic');
    if (riglogic != null && out['flutter_riglogic']?['riglogic_lib_dir'] == null) {
      put('flutter_riglogic', 'riglogic_lib_dir', p.join(riglogic, 'third_party', 'openriglogic', 'lib'));
    }
    return {for (final k in hookedPackages) if (out[k] != null) k: out[k]!};
  }

  /// [pubspec] with the `hooks:` block this class wrote (under [hooksMarker];
  /// with [anyBlock], any top-level `hooks:` block) replaced by [defines], or
  /// removed when [defines] is empty; the new block is appended at the end.
  /// A `hooks:` block of the user's own is kept, and then none is added (a
  /// second top-level key would be invalid YAML).
  static String withHookUserDefines(String pubspec, Map<String, Map<String, String>> defines, {bool anyBlock = false}) {
    final nl = pubspec.contains('\r\n') ? '\r\n' : '\n';
    final lines = const LineSplitter().convert(pubspec);
    final kept = <String>[];
    var inHooks = false;
    var inMarker = false;
    var marked = false;
    var foreign = false;
    for (final line in lines) {
      if (line == hooksMarker) {
        inMarker = true;
        marked = true;
        continue;
      }
      if (inMarker && line.startsWith('#')) continue;
      inMarker = false;
      if (RegExp(r'^hooks:\s*(#.*)?$').hasMatch(line)) {
        if (marked || anyBlock) {
          inHooks = true;
          marked = false;
          continue;
        }
        foreign = true;
      }
      marked = false;
      if (inHooks) {
        if (line.trim().isEmpty || line.startsWith(' ') || line.startsWith('\t')) continue;
        inHooks = false;
      }
      kept.add(line);
    }
    while (kept.isNotEmpty && kept.last.trim().isEmpty) {
      kept.removeLast();
    }
    if (defines.isEmpty || foreign) return '${kept.join(nl)}$nl';
    final b = StringBuffer()
      ..write(kept.join(nl))
      ..write(nl)
      ..write(nl)
      ..write('$hooksMarker$nl')
      ..write('# (Filament, libc++, RigLogic), for the native-assets hooks of the engine$nl')
      ..write('# packages; the hooks runner reads them from this file only. Rewritten$nl')
      ..write('# for the machine that links the project to its engine.$nl')
      ..write('hooks:$nl')
      ..write('  user_defines:$nl');
    for (final package in defines.keys) {
      b.write('    $package:$nl');
      for (final e in defines[package]!.entries) {
        b.write("      ${e.key}: '${e.value}'$nl");
      }
    }
    return b.toString();
  }

  /// [pubspec] with its `lumina:` dependency in the git form (added under
  /// `dependencies:` when missing); a `path:` or other source is replaced.
  /// The git `ref:` is [ref], else the release commit [engineDependency]
  /// defaults to; with neither, a `ref:` the existing dependency already has
  /// is kept (a source-workspace editor does not unpin a project a release
  /// editor pinned).
  static String withGitEngineDependency(String pubspec, {String? ref}) {
    final nl = pubspec.contains('\r\n') ? '\r\n' : '\n';
    final text = pubspec.replaceAll('\r\n', '\n');
    final lines = text.split('\n');
    final deps = lines.indexWhere((l) => RegExp(r'^dependencies:\s*(#.*)?$').hasMatch(l));
    String join(List<String> ls) => ls.join('\n').replaceAll('\n', nl);
    if (deps < 0) {
      final body = text.endsWith('\n') ? text : '$text\n';
      return join('$body\ndependencies:\n${engineDependency(ref: ref)}\n'.split('\n'));
    }
    var end = deps + 1;
    while (end < lines.length && (lines[end].isEmpty || lines[end].startsWith(' ') || lines[end].startsWith('#'))) {
      end++;
    }
    final at = lines.sublist(deps + 1, end).indexWhere((l) => RegExp(r'^  lumina:(\s|$)').hasMatch(l));
    if (at < 0) {
      lines.insert(deps + 1, engineDependency(ref: ref));
      return join(lines);
    }
    final start = deps + 1 + at;
    var stop = start + 1;
    while (stop < end && lines[stop].startsWith('    ')) {
      stop++;
    }
    String? keptRef;
    for (final l in lines.sublist(start + 1, stop)) {
      final m = RegExp(r'^      ref:\s*([^\s#]+)').firstMatch(l);
      if (m != null) keptRef = m.group(1)!.replaceAll(RegExp(r'''^['"]|['"]$'''), '');
    }
    lines.replaceRange(start, stop, [engineDependency(ref: ref ?? LuminaWorkspace.engineCommit ?? keptRef)]);
    return join(lines);
  }

  /// Adds `pubspec_overrides.yaml` to [projectDir]'s `.gitignore`; false
  /// when it was listed already.
  static bool ensureOverridesIgnored(String projectDir) {
    final file = File(p.join(projectDir, '.gitignore'));
    final existing = file.existsSync() ? file.readAsStringSync() : '';
    const rules = {overridesFileName, '/$overridesFileName'};
    if (LineSplitter.split(existing).any((l) => rules.contains(l.trim()))) return false;
    final out = StringBuffer(existing);
    if (existing.isNotEmpty) {
      if (!existing.endsWith('\n')) out.writeln();
      out.writeln();
    }
    out
      ..writeln('# The local engine checkout this project builds against (machine paths)')
      ..writeln(overridesFileName);
    file.writeAsStringSync(out.toString());
    return true;
  }

  /// Links the project at [projectDir] to the engine: the git `lumina`
  /// dependency in its pubspec, and — when the editor runs from a local
  /// checkout ([localEngineRoot]) — either the gitignored
  /// `pubspec_overrides.yaml` ([localOverrides], the default; every local
  /// package's hook finds Filament through its own `../filament`, so a hook
  /// block written earlier is removed — unless a package resolves from the
  /// pub cache ([needsHookUserDefines]), which gets the relative
  /// [linkedHookUserDefines]), or, building against git
  /// (`localOverrides: false`), the hook settings, unless an overrides file
  /// is in effect. Without a local checkout an existing overrides file and
  /// hook block are left as they are. Idempotent.
  static ProjectEngineLinkResult apply(String projectDir,
      {String? luminaPackageDir, bool localOverrides = true, void Function(String)? onLog}) {
    final pubspecFile = File(p.join(projectDir, 'pubspec.yaml'));
    if (!pubspecFile.existsSync()) throw StateError('No pubspec.yaml in $projectDir');
    final before = pubspecFile.readAsStringSync();
    var pubspec = withGitEngineDependency(before);
    final engineRoot = localEngineRoot(luminaPackageDir: luminaPackageDir);
    Map<String, String> packages = const {};
    Map<String, Map<String, String>> defines = const {};
    final overrides = File(p.join(projectDir, overridesFileName));
    if (engineRoot != null && localOverrides) {
      packages = localPackages(engineRoot, onLog: onLog);
      defines = needsHookUserDefines(packages)
          ? linkedHookUserDefines(projectDir, engineRoot, packages: packages)
          : const <String, Map<String, String>>{};
      if (defines.isEmpty) _syncLinks(Directory(p.join(projectDir, engineLinksDir)), const {});
      pubspec = withHookUserDefines(pubspec, defines);
      final yaml = overridesYaml(packages, engineRoot);
      if (!overrides.existsSync() || overrides.readAsStringSync() != yaml) overrides.writeAsStringSync(yaml);
      ensureOverridesIgnored(projectDir);
    } else if (engineRoot != null) {
      if (!overrides.existsSync()) {
        defines = hookUserDefines(engineRoot, packages: localPackages(engineRoot, onLog: onLog));
      }
      pubspec = withHookUserDefines(pubspec, defines);
    }
    if (pubspec != before) pubspecFile.writeAsStringSync(pubspec);
    return ProjectEngineLinkResult(engineRoot: engineRoot, overrides: packages, hookUserDefines: defines);
  }

  static String _slash(String path) => path.replaceAll(r'\', '/');
}

/// What [ProjectEngineLink.apply] did.
class ProjectEngineLinkResult {
  /// The local engine checkout the project was linked to; null: git only.
  final String? engineRoot;

  /// The packages pinned in `pubspec_overrides.yaml` (name → dir).
  final Map<String, String> overrides;

  /// The hook settings written into `pubspec.yaml`.
  final Map<String, Map<String, String>> hookUserDefines;

  const ProjectEngineLinkResult({this.engineRoot, this.overrides = const {}, this.hookUserDefines = const {}});

  bool get isLocal => engineRoot != null;
}
