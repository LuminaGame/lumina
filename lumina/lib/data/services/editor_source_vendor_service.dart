import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../models/lumina_project.dart' show kLuminaEngineVersion;
import 'directory_link.dart';
import 'editor_build_fingerprint.dart' show engineRepoState;
import 'engine_identity.dart';
import 'workspace_paths.dart';

/// A project's copy of the engine source comes from another engine than the
/// running one (see [EditorSourceVendorService.engineUpdate]).
class EditorEngineUpdate {
  /// The engine the copy was taken from, as its stamp records it; null for a
  /// copy made before stamps recorded it.
  final EngineIdentity? copied;

  /// The project's `.lmproject` `engine_version`, when it names a version.
  final String? projectEngineVersion;

  /// The engine a sync would copy from.
  final EngineIdentity current;

  /// The copied repos whose engine source changed since the copy.
  final List<String> changedRepos;

  const EditorEngineUpdate({required this.copied, required this.current, this.projectEngineVersion, this.changedRepos = const []});

  /// The copy's engine for the user: its label, else the project's
  /// `engine_version`, else "an older engine".
  String get fromLabel => copied?.label ?? projectEngineVersion ?? 'an older engine';

  /// The running engine for the user; with a copy of the same version and
  /// commit (edits in a source checkout) the changed repos are named.
  String get toLabel => copied != null && copied!.key == current.key && changedRepos.isNotEmpty
      ? '${current.label}, changed: ${changedRepos.join(', ')}'
      : current.label;

  @override
  String toString() => 'EditorEngineUpdate($fromLabel → $toLabel)';
}

/// Copies the engine's Dart source, dependencies included, into a project's
/// editor host: `<host>/lumina_ui/`, `<host>/lumina/`,
/// `<host>/flutter_filament/`, … at the workspace's relative layout, so the
/// copied pubspecs' `path: ../x` entries resolve among themselves. Packages
/// from other repos (git dependencies: flutter_assimp, flutter_riglogic,
/// flutter_gstreamer and lumina_smoke from `tools`, the marketplace's shared
/// package) are copied from where the
/// engine workspace resolved them (its package config: the pub cache, or a
/// local checkout through `pubspec_overrides.yaml`) to `<host>/<name>/`; the
/// host pubspec overrides every one of them to its copy. Filament's C++ tree
/// is linked (`<host>/filament` → `<engine>/filament`), never copied; so is
/// the prebuilt OpenRigLogic library folder of a release checkout
/// (`<host>/openriglogic` → `<engine>/openriglogic`), which a flutter_riglogic
/// copied from the pub cache needs.
///
/// The copy is made once and is the project's own afterwards: only [sync]
/// replaces it.
class EditorSourceVendorService {
  /// The workspace root holding `lumina_ui/`, `lumina/`, `filament/`, ….
  final String engineRoot;

  /// The package whose path-dependency closure is copied.
  final String rootPackage;

  /// Links each package to the engine instead of copying it: for engine
  /// development and tests, where a ~650 MB copy per build is pointless.
  /// Projects never use it.
  final bool linkPackages;

  EditorSourceVendorService({required this.engineRoot, this.rootPackage = 'lumina_ui', this.linkPackages = false});

  static const String stampFileName = '.lumina_source.json';

  /// Filament's C++ tree, linked beside the copied packages because the
  /// native-assets hooks resolve `../filament/…` from their package root.
  static const String filamentDir = 'filament';

  /// The prebuilt OpenRigLogic folder a release checkout links (see
  /// EngineBootstrap), linked beside the copied packages when the engine has
  /// one; the host pubspec's `riglogic_lib_dir` names its `lib`.
  static const String openriglogicDir = 'openriglogic';

  /// Skipped directly under each package root: build outputs, tests and
  /// backlog docs, none of which the editor build reads.
  static const Set<String> packageExcludes = {
    '.git',
    '.dart_tool',
    'build',
    'test',
    'integration_test',
    'example',
    'todo',
    'docs',
    'coverage',
    '.idea',
  };

  /// Skipped at any depth.
  static const Set<String> anywhereExcludes = {'.git', '.dart_tool'};

  static Map<String, dynamic>? readStamp(String hostDir) {
    final f = File(p.join(hostDir, stampFileName));
    if (!f.existsSync()) return null;
    try {
      return jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    } on FormatException {
      return null;
    }
  }

  /// The packages copied into [hostDir] (relative, `/`), from its stamp; empty
  /// when it holds no copy.
  static List<String> copiedRepos(String hostDir) {
    final packages = readStamp(hostDir)?['packages'];
    return packages is List ? [for (final p in packages) '$p'] : const [];
  }

  /// The package dirs (relative to the host, `/`-separated) reachable from
  /// [rootPackage] through `path:` and `git:` dependencies and overrides, in
  /// discovery order: see [packageSources].
  List<String> packageClosure() => packageSources().keys.toList();

  /// Each [packageClosure] entry and the directory it is copied from. A
  /// `path:` dependency inside [engineRoot] keeps its relative place; one
  /// leaving it is a [StateError]. A `git:` dependency (a package of another
  /// repo) is copied from where the engine workspace resolved it (see
  /// [LuminaWorkspace.resolvedPackageDir]) to `<name>`; one the engine has not
  /// resolved is a [StateError]. Path dependencies of such a package are
  /// copied by name too.
  Map<String, String> packageSources() {
    final out = <String, String>{};
    void visit(String rel, String dir, {required bool external}) {
      if (out.containsKey(rel)) return;
      out[rel] = dir;
      final pubspec = File(p.join(dir, 'pubspec.yaml'));
      if (!pubspec.existsSync()) throw StateError('No pubspec.yaml in $dir');
      final yaml = loadYaml(pubspec.readAsStringSync()) as YamlMap;
      final found = <(String, String, bool)>[];
      for (final section in ['dependencies', 'dependency_overrides']) {
        final deps = yaml[section];
        if (deps is! YamlMap) continue;
        for (final e in deps.entries) {
          final v = e.value;
          if (v is! YamlMap) continue;
          final name = '${e.key}';
          if (v['path'] != null) {
            final target = p.normalize(p.join(dir, v['path'].toString()));
            if (external) {
              found.add((name, target, true));
              continue;
            }
            final relTarget = p.relative(target, from: engineRoot);
            if (p.isAbsolute(relTarget) || relTarget.startsWith('..')) {
              throw StateError('$name (from $rel) is outside the engine at $target; it cannot be copied into a project');
            }
            found.add((relTarget.replaceAll(r'\', '/'), target, false));
          } else if (v['git'] != null) {
            final resolved = LuminaWorkspace.resolvedPackageDir(engineRoot, name);
            if (resolved == null || !File(p.join(resolved, 'pubspec.yaml')).existsSync()) {
              throw StateError('$name (from $rel) is a git dependency the engine has not resolved; run `flutter pub get` in $engineRoot');
            }
            found.add((name, resolved, true));
          }
        }
      }
      for (final (r, d, ext) in found) {
        visit(r, d, external: ext);
      }
    }

    visit(rootPackage, p.join(engineRoot, rootPackage), external: false);
    return out;
  }

  /// [packageClosure] without packages nested in another one (they travel
  /// inside their parent).
  List<String> copyRoots() {
    final all = packageClosure();
    return [
      for (final rel in all)
        if (!all.any((o) => o != rel && rel.startsWith('$o/'))) rel,
    ];
  }

  /// Whether [hostDir] holds a complete copy: the stamp, every package in it
  /// and the Filament link.
  bool isVendored(String hostDir) {
    final stamp = readStamp(hostDir);
    final packages = stamp?['packages'];
    if (packages is! List || packages.isEmpty) return false;
    for (final rel in packages) {
      if (!File(p.join(hostDir, '$rel', 'pubspec.yaml')).existsSync()) return false;
    }
    return FileSystemEntity.typeSync(p.join(hostDir, filamentDir)) != FileSystemEntityType.notFound;
  }

  /// Copies the source unless [hostDir] already holds it; true when it
  /// copied.
  Future<bool> vendorIfMissing(String hostDir, {void Function(double fraction, String file)? onProgress}) async {
    if (isVendored(hostDir)) return false;
    await vendor(hostDir, onProgress: onProgress);
    return true;
  }

  /// Replaces the copy with the engine's current source; edits made in the
  /// project's copy are lost.
  Future<void> sync(String hostDir, {void Function(double fraction, String file)? onProgress}) =>
      vendor(hostDir, onProgress: onProgress);

  /// Copies every [copyRoots] package into [hostDir] (replacing what is
  /// there), links Filament and writes the stamp. Each package is copied
  /// into `<host>/.source.tmp/` first and moved into place only when all of
  /// them copied, so an interrupted copy leaves the old state.
  Future<void> vendor(String hostDir, {void Function(double fraction, String file)? onProgress}) async {
    final filament = Directory(p.join(engineRoot, filamentDir));
    if (!filament.existsSync()) {
      throw StateError('The engine has no filament/ at ${filament.path}; the editor build links it');
    }
    final sources = packageSources();
    final roots = copyRoots();
    final closure = sources.keys.toList();
    final files = <(String, String)>[]; // (source, relative to the host)
    if (!linkPackages) {
      for (final rel in roots) {
        _collect(Directory(sources[rel]!), rel, closure, files);
      }
    }

    final tmp = Directory(p.join(hostDir, '.source.tmp'));
    if (tmp.existsSync()) await tmp.delete(recursive: true);
    try {
      for (var i = 0; i < files.length; i++) {
        final (src, rel) = files[i];
        final dest = File(p.join(tmp.path, rel));
        await dest.parent.create(recursive: true);
        await File(src).copy(dest.path);
        onProgress?.call((i + 1) / files.length, rel);
      }
      if (files.isEmpty) onProgress?.call(1, '');
      for (final rel in roots) {
        final dest = Directory(p.join(hostDir, rel));
        // A link in its place is removed, never followed into its target.
        if (FileSystemEntity.isLinkSync(dest.path)) {
          await Link(dest.path).delete();
        } else if (dest.existsSync()) {
          await dest.delete(recursive: true);
        }
        await dest.parent.create(recursive: true);
        final staged = Directory(p.join(tmp.path, rel));
        if (linkPackages) {
          await Link(dest.path).create(p.absolute(sources[rel]!));
        } else if (staged.existsSync()) {
          await staged.rename(dest.path);
        } else {
          await dest.create(recursive: true);
        }
      }
    } finally {
      if (tmp.existsSync()) await tmp.delete(recursive: true);
    }

    final link = Link(p.join(hostDir, filamentDir));
    if (FileSystemEntity.typeSync(link.path, followLinks: false) != FileSystemEntityType.notFound) {
      if (FileSystemEntity.isLinkSync(link.path)) {
        await link.delete();
      } else {
        await Directory(link.path).delete(recursive: true);
      }
    }
    // A junction on Windows: no admin rights or Developer Mode needed.
    DirectoryLink.createSync(link.path, filament.path);
    await linkOpenRigLogic(hostDir);

    final revisions = <String, String>{};
    for (final repo in _repos(roots)) {
      revisions[repo] = await engineRepoState(_sourceOf(repo, sources));
    }
    await File(p.join(hostDir, stampFileName)).writeAsString(const JsonEncoder.withIndent('  ').convert({
      'engineRoot': p.normalize(p.absolute(engineRoot)).replaceAll(r'\', '/'),
      'copiedAt': DateTime.now().toUtc().toIso8601String(),
      'packages': roots,
      'engineRevisions': revisions,
      'engine': (await EngineIdentity.of(engineRoot)).toJson(),
    }));
  }

  /// The engine [hostDir]'s copy was taken from, from its stamp; null when
  /// the stamp predates the record (or there is no copy).
  static EngineIdentity? copiedEngine(String hostDir) => EngineIdentity.fromJson(readStamp(hostDir)?['engine']);

  /// Whether [hostDir]'s copy comes from another engine than [current] (the
  /// engine this service copies from): null when the host holds no copy or
  /// the copy is current. A stamp that records its engine differs when that
  /// engine is not [current] or the engine's source changed since
  /// ([engineChangedSince]: in a source checkout, edits count). An older
  /// stamp differs when the source changed or the project's
  /// [projectEngineVersion] names another version; the creators'
  /// placeholder [kLuminaEngineVersion] names none.
  Future<EditorEngineUpdate?> engineUpdate(String hostDir, {required EngineIdentity current, String? projectEngineVersion}) async {
    if (!isVendored(hostDir)) return null;
    final copied = copiedEngine(hostDir);
    final changed = await engineChangedSince(hostDir);
    final recorded = projectEngineVersion == null ? '' : EngineIdentity.stripTag(projectEngineVersion.trim());
    final projectVersion = recorded.isEmpty || recorded == kLuminaEngineVersion ? null : recorded;
    final differs = copied != null
        ? copied.key != current.key || changed.isNotEmpty
        : changed.isNotEmpty || (projectVersion != null && projectVersion != current.version);
    if (!differs) return null;
    return EditorEngineUpdate(copied: copied, current: current, projectEngineVersion: projectVersion, changedRepos: changed);
  }

  /// `<host>/openriglogic` → `<engine>/openriglogic` when the engine has
  /// that folder (a release checkout); otherwise no link (a stale one is
  /// removed). Part of [vendor]; also run for a copy made before the engine
  /// had the folder.
  Future<void> linkOpenRigLogic(String hostDir) async {
    final link = Link(p.join(hostDir, openriglogicDir));
    if (FileSystemEntity.isLinkSync(link.path)) await link.delete();
    final target = Directory(p.join(engineRoot, openriglogicDir));
    if (target.existsSync()) DirectoryLink.createSync(link.path, target.path);
  }

  /// The engine repos (top-level dirs) whose state changed since [hostDir]'s
  /// copy was made.
  Future<List<String>> engineChangedSince(String hostDir) async {
    final revisions = readStamp(hostDir)?['engineRevisions'];
    if (revisions is! Map) return const [];
    final changed = <String>[];
    Map<String, String>? sources;
    for (final e in revisions.entries) {
      var dir = p.join(engineRoot, '${e.key}');
      if (!Directory(dir).existsSync()) {
        // A package of another repo, copied by name.
        try {
          dir = _sourceOf('${e.key}', sources ??= packageSources());
        } on StateError {
          continue;
        }
      }
      if (!Directory(dir).existsSync()) continue;
      if (await engineRepoState(dir) != e.value) changed.add('${e.key}');
    }
    return changed;
  }

  /// The top-level dir of each copied package (`flutter_filament` for
  /// `flutter_filament/example`).
  static List<String> _repos(List<String> roots) => {for (final r in roots) r.split('/').first}.toList();

  /// Where the top-level host dir [repo] is copied from: its [sources] entry
  /// (a package of another repo), else `<engine>/<repo>`.
  String _sourceOf(String repo, Map<String, String> sources) => sources[repo] ?? p.join(engineRoot, repo);

  /// Every file under [dir] (copied to [rel] in the host) to copy, skipping
  /// [packageExcludes] under each package root of [closure],
  /// [anywhereExcludes] and generated `flutter/ephemeral` folders. Links are
  /// not followed.
  void _collect(Directory dir, String rel, List<String> closure, List<(String, String)> out) {
    final isPackageRoot = closure.contains(rel) || File(p.join(dir.path, 'pubspec.yaml')).existsSync();
    final entries = dir.listSync(followLinks: false)..sort((a, b) => a.path.compareTo(b.path));
    for (final e in entries) {
      final name = p.basename(e.path);
      if (anywhereExcludes.contains(name)) continue;
      if (isPackageRoot && packageExcludes.contains(name)) continue;
      if (e is Directory) {
        if (name == 'ephemeral' && p.basename(dir.path) == 'flutter') continue;
        _collect(e, '$rel/$name', closure, out);
      } else if (e is File) {
        out.add((e.path, '$rel/$name'));
      }
    }
  }
}
