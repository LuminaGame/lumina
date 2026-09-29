import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'filament_prebuilt.dart';
import 'lumina_data_dir.dart';
import 'openriglogic_prebuilt.dart';
import 'workspace_paths.dart';

/// What the release workflow compiles into a Lumina Studio build
/// (`--dart-define`): the release tag, its commit and the engine repo. All
/// empty in a dev build.
abstract final class LuminaRelease {
  /// The release tag, e.g. `v0.1.0`; empty in dev builds.
  static const String version = String.fromEnvironment('LUMINA_VERSION');

  /// The full commit SHA the release was built from.
  static const String commit = String.fromEnvironment('LUMINA_COMMIT');

  static const String _repo = String.fromEnvironment('LUMINA_REPO');

  /// The engine repo the release fetches its source from.
  static String get repo => _repo.isEmpty ? kLuminaGitUrl : _repo;

  /// Whether this is a release build.
  static bool get isRelease => version.isNotEmpty;
}

/// Downloads (or finds) the prebuilt Filament build [version] and returns
/// its directory, usable as the hooks' `filament_dir`. The signature of
/// [FilamentPrebuilt.ensure].
typedef FilamentProvider = Future<Directory> Function({
  required String version,
  required String releaseTag,
  required Directory cacheRoot,
  void Function(double progress, String message)? onProgress,
});

/// Downloads (or finds) the prebuilt OpenRigLogic library of the
/// [releaseTag] release and returns its directory, whose `lib` folder the
/// root pubspec's `riglogic_lib_dir` names. The signature of
/// [OpenRigLogicPrebuilt.ensure].
typedef OpenRigLogicProvider = Future<Directory> Function({
  required String releaseTag,
  required Directory cacheRoot,
  void Function(double progress, String message)? onProgress,
});

/// The steps of [EngineBootstrap.ensure], in order.
enum EngineBootstrapStep {
  prerequisites('Checking prerequisites'),
  source('Downloading engine source'),
  filament('Downloading Filament'),
  openriglogic('Downloading OpenRigLogic'),
  packages('Resolving packages');

  const EngineBootstrapStep(this.label);

  final String label;
}

/// An event of [EngineBootstrap.run] / [EngineBootstrap.ensure].
sealed class EngineBootstrapEvent {
  const EngineBootstrapEvent();
}

/// [step] started or advanced; [fraction] is null while unknown.
final class EngineBootstrapProgress extends EngineBootstrapEvent {
  final EngineBootstrapStep step;
  final double? fraction;
  final String message;

  const EngineBootstrapProgress(this.step, this.message, {this.fraction});

  @override
  String toString() => '[${step.name}] $message${fraction == null ? '' : ' (${(fraction! * 100).round()}%)'}';
}

/// A line of tool output (git, flutter) during [step].
final class EngineBootstrapLog extends EngineBootstrapEvent {
  final EngineBootstrapStep step;
  final String line;

  const EngineBootstrapLog(this.step, this.line);

  @override
  String toString() => '[${step.name}] $line';
}

/// [step] finished; [skipped] when there was nothing to do.
final class EngineBootstrapStepDone extends EngineBootstrapEvent {
  final EngineBootstrapStep step;
  final bool skipped;

  const EngineBootstrapStepDone(this.step, {this.skipped = false});
}

/// The prerequisite check's findings (sent whether or not any is missing).
final class EngineBootstrapPrerequisites extends EngineBootstrapEvent {
  final List<EnginePrerequisite> prerequisites;

  const EngineBootstrapPrerequisites(this.prerequisites);
}

/// The checkout is ready and active.
final class EngineBootstrapCompleted extends EngineBootstrapEvent {
  final EngineCheckout checkout;

  const EngineBootstrapCompleted(this.checkout);
}

/// The bootstrap stopped; running it again resumes.
final class EngineBootstrapFailed extends EngineBootstrapEvent {
  final EngineBootstrapException error;

  const EngineBootstrapFailed(this.error);
}

/// A tool the engine source needs on this machine.
class EnginePrerequisite {
  /// Display name, e.g. `Git`.
  final String name;

  /// Where it was found (a path, a version), or null when missing.
  final String? location;

  /// Missing required prerequisites stop the bootstrap; the others (the C++
  /// toolchain, needed only to build games and project editors) are
  /// reported.
  final bool required;

  /// How to install it.
  final String hint;

  const EnginePrerequisite({required this.name, required this.location, required this.required, required this.hint});

  bool get found => location != null;

  @override
  String toString() => '$name: ${location ?? 'missing'}';
}

/// Why [EngineBootstrap.ensure] stopped.
class EngineBootstrapException implements Exception {
  final String message;

  /// The step that failed.
  final EngineBootstrapStep step;

  /// The required prerequisites that are missing (step
  /// [EngineBootstrapStep.prerequisites]).
  final List<EnginePrerequisite> missing;

  const EngineBootstrapException(this.message, {required this.step, this.missing = const []});

  @override
  String toString() => 'EngineBootstrapException(${step.name}): $message';
}

/// A complete engine checkout, as recorded in its marker file.
class EngineCheckout {
  /// The checkout directory (`<data>/engine/<version>`).
  final String dir;

  /// The release tag it belongs to.
  final String version;

  /// The commit it is checked out at (detached).
  final String commit;

  /// The git URL it was cloned from.
  final String repo;

  /// The prebuilt Filament version (`tool/filament/VERSION`) and directory
  /// its `filament` link points at.
  final String filamentVersion;
  final String filamentDir;

  /// The prebuilt OpenRigLogic directory its `openriglogic` link points at.
  final String openriglogicDir;

  final DateTime completedAt;

  const EngineCheckout({
    required this.dir,
    required this.version,
    required this.commit,
    required this.repo,
    required this.filamentVersion,
    required this.filamentDir,
    required this.openriglogicDir,
    required this.completedAt,
  });

  Map<String, Object?> toJson() => {
        'version': version,
        'commit': commit,
        'repo': repo,
        'filamentVersion': filamentVersion,
        'filamentDir': filamentDir,
        'openriglogicDir': openriglogicDir,
        'completedAt': completedAt.toUtc().toIso8601String(),
      };

  static EngineCheckout? fromJson(String dir, Object? json) {
    if (json is! Map) return null;
    String? s(String k) => json[k] is String ? json[k] as String : null;
    final version = s('version'), commit = s('commit'), repo = s('repo');
    final fv = s('filamentVersion'), fd = s('filamentDir'), rd = s('openriglogicDir');
    if (version == null || commit == null || repo == null || fv == null || fd == null || rd == null) return null;
    return EngineCheckout(
      dir: dir,
      version: version,
      commit: commit,
      repo: repo,
      filamentVersion: fv,
      filamentDir: fd,
      openriglogicDir: rd,
      completedAt: DateTime.tryParse(s('completedAt') ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

/// Fetches the engine source of a release build: the installed Lumina Studio
/// is a prebuilt binary, but generating games, project editors and plugins
/// needs the engine's source, at exactly the commit the binary was built
/// from.
///
/// [ensure] makes `<engineRoot>/<version>` a partial git clone of [repo]
/// checked out (detached) at [commit], links the prebuilt Filament for the
/// checkout's `tool/filament/VERSION` as its `filament` folder and the
/// release's prebuilt OpenRigLogic as its `openriglogic` folder (the root
/// pubspec's hook settings name both), runs `flutter pub get` there
/// (the pinned `ref:`s and the committed lock resolve the other repos), writes
/// a marker file and points [LuminaWorkspace.root] at the checkout.
///
/// Every step is idempotent: a complete checkout starts without the network,
/// an interrupted one resumes (a clone whose objects arrived is checked out,
/// a broken one is cloned again). Checkouts of older versions are kept.
class EngineBootstrap {
  /// The release tag, e.g. `v0.1.0`: the checkout's folder name, and the
  /// commit to check out when [commit] is empty.
  final String version;

  /// The commit to check out; empty: the tag [version].
  final String commit;

  /// The engine repo (any git URL, `file://` included).
  final String repo;

  /// Where checkouts live (`<data>/engine`).
  final Directory engineRoot;

  /// Where prebuilt Filament builds live (`<data>/filament`).
  final Directory filamentRoot;

  /// Where prebuilt OpenRigLogic libraries live (`<data>/openriglogic`).
  final Directory openriglogicRoot;

  /// The environment tools are looked up in and run with.
  final Map<String, String> environment;

  /// Supplies the prebuilt Filament; defaults to [defaultFilamentProvider],
  /// else [FilamentPrebuilt.ensure] (the release's assets).
  final FilamentProvider? filament;

  /// Supplies the prebuilt OpenRigLogic; defaults to
  /// [defaultOpenRigLogicProvider], else [OpenRigLogicPrebuilt.ensure].
  final OpenRigLogicProvider? openriglogic;

  /// Whether to look for the C++ toolchain (reported, never blocking).
  final bool checkToolchain;

  final String _os;

  /// The Filament provider bootstraps use unless given one (null:
  /// [FilamentPrebuilt.ensure]).
  static FilamentProvider? defaultFilamentProvider;

  /// The OpenRigLogic provider bootstraps use unless given one (null:
  /// [OpenRigLogicPrebuilt.ensure]).
  static OpenRigLogicProvider? defaultOpenRigLogicProvider;

  /// The checkout's links to the prebuilt Filament and OpenRigLogic.
  static const String filamentLink = 'filament';
  static const String openriglogicLink = 'openriglogic';

  /// The marker a complete checkout carries, inside its `.git` folder (so it
  /// never shows as a change and goes when the checkout goes).
  static const String markerName = 'lumina-engine.json';

  EngineBootstrap({
    required this.version,
    this.commit = '',
    this.repo = kLuminaGitUrl,
    Directory? engineRoot,
    Directory? filamentRoot,
    Directory? openriglogicRoot,
    Map<String, String>? environment,
    this.filament,
    this.openriglogic,
    this.checkToolchain = true,
    String? operatingSystem,
  })  : engineRoot = engineRoot ?? LuminaDataDir.engineRoot(environment: environment),
        filamentRoot = filamentRoot ?? LuminaDataDir.filamentRoot(environment: environment),
        openriglogicRoot = openriglogicRoot ?? LuminaDataDir.openriglogicRoot(environment: environment),
        environment = Map.of(environment ?? Platform.environment),
        _os = operatingSystem ?? Platform.operatingSystem;

  /// The bootstrap of this release build ([LuminaRelease]).
  factory EngineBootstrap.release({FilamentProvider? filament, OpenRigLogicProvider? openriglogic}) => EngineBootstrap(
      version: LuminaRelease.version,
      commit: LuminaRelease.commit,
      repo: LuminaRelease.repo,
      filament: filament,
      openriglogic: openriglogic);

  /// Whether this process needs a bootstrap: a release build that does not
  /// run from a source workspace (`LUMINA_WORKSPACE`, or an ancestor
  /// checkout).
  static bool get needed => LuminaRelease.isRelease && LuminaWorkspace.findSourceRoot() == null;

  bool get _windows => _os == 'windows';

  /// `<engineRoot>/<version>`.
  Directory get checkoutDir => Directory(p.join(engineRoot.path, _safeName(version)));

  File get markerFile => File(p.join(checkoutDir.path, '.git', markerName));

  /// The checkout when it is complete — marker present and matching, `.git/HEAD`
  /// at the commit, Filament and OpenRigLogic linked, packages resolved — else null. Reads
  /// files only (no git, no network).
  EngineCheckout? readyCheckout() {
    try {
      if (!markerFile.existsSync()) return null;
      final checkout = EngineCheckout.fromJson(checkoutDir.path, jsonDecode(markerFile.readAsStringSync()));
      if (checkout == null || checkout.version != version || checkout.repo != repo) return null;
      if (commit.isNotEmpty && checkout.commit != commit) return null;
      final head = File(p.join(checkoutDir.path, '.git', 'HEAD'));
      if (!head.existsSync() || head.readAsStringSync().trim() != checkout.commit) return null;
      if (!_linkOk(filamentLink, checkout.filamentDir)) return null;
      if (!_linkOk(openriglogicLink, checkout.openriglogicDir)) return null;
      if (!File(p.join(checkoutDir.path, '.dart_tool', 'package_config.json')).existsSync()) return null;
      return checkout;
    } on FileSystemException {
      return null;
    } on FormatException {
      return null;
    }
  }

  /// The marker of the fetched checkout at [dir], or null when [dir] is not
  /// one (a source workspace). Project editors built from a release checkout
  /// read it to find the engine commit they belong to.
  static EngineCheckout? readMarker(String dir) {
    try {
      final file = File(p.join(dir, '.git', markerName));
      if (!file.existsSync()) return null;
      return EngineCheckout.fromJson(p.normalize(p.absolute(dir)), jsonDecode(file.readAsStringSync()));
    } on FileSystemException {
      return null;
    } on FormatException {
      return null;
    }
  }

  /// Makes [LuminaWorkspace.root] resolve to [checkout] for this process.
  static void activate(EngineCheckout checkout) =>
      LuminaWorkspace.useCheckout(checkout.dir, commit: checkout.commit, repo: checkout.repo);

  /// [ensure] as a stream: its events, ending with [EngineBootstrapCompleted]
  /// or [EngineBootstrapFailed].
  Stream<EngineBootstrapEvent> run({bool force = false, bool activate = true}) {
    final controller = StreamController<EngineBootstrapEvent>();
    () async {
      try {
        final checkout = await ensure(force: force, activate: activate, onEvent: controller.add);
        controller.add(EngineBootstrapCompleted(checkout));
      } on EngineBootstrapException catch (e) {
        controller.add(EngineBootstrapFailed(e));
      } catch (e) {
        controller.add(EngineBootstrapFailed(EngineBootstrapException('$e', step: EngineBootstrapStep.source)));
      } finally {
        await controller.close();
      }
    }();
    return controller.stream;
  }

  /// Makes the checkout complete (see the class comment) and returns it;
  /// with [activate], points [LuminaWorkspace.root] at it. [force] deletes
  /// the checkout first and downloads it again. Throws
  /// [EngineBootstrapException].
  Future<EngineCheckout> ensure({void Function(EngineBootstrapEvent)? onEvent, bool force = false, bool activate = true}) async {
    void emit(EngineBootstrapEvent e) => onEvent?.call(e);
    if (version.isEmpty) {
      throw const EngineBootstrapException('No release version: this build has no engine source to fetch.', step: EngineBootstrapStep.prerequisites);
    }

    emit(const EngineBootstrapProgress(EngineBootstrapStep.prerequisites, 'Looking for Git, the Flutter SDK and a C++ toolchain'));
    final prerequisites = await checkPrerequisites();
    emit(EngineBootstrapPrerequisites(prerequisites));
    for (final pr in prerequisites) {
      emit(EngineBootstrapLog(EngineBootstrapStep.prerequisites, pr.found ? '${pr.name}: ${pr.location}' : '${pr.name}: not found. ${pr.hint}'));
    }
    final missing = [for (final pr in prerequisites) if (pr.required && !pr.found) pr];
    if (missing.isNotEmpty) {
      throw EngineBootstrapException('Missing: ${missing.map((m) => m.name).join(', ')}.',
          step: EngineBootstrapStep.prerequisites, missing: missing);
    }
    emit(const EngineBootstrapStepDone(EngineBootstrapStep.prerequisites));
    final git = prerequisites.firstWhere((pr) => pr.name == 'Git').location!;
    final flutter = prerequisites.firstWhere((pr) => pr.name == 'Flutter SDK').location!;

    await engineRoot.create(recursive: true);
    final lock = await File(p.join(engineRoot.path, '${_safeName(version)}.lock')).open(mode: FileMode.write);
    try {
      await lock.lock(FileLock.blockingExclusive);
      if (force && checkoutDir.existsSync()) {
        emit(EngineBootstrapLog(EngineBootstrapStep.source, 'Deleting ${checkoutDir.path} to download it again'));
        await _wipe(checkoutDir);
      }

      final ready = readyCheckout();
      if (ready != null) {
        for (final step in EngineBootstrapStep.values.skip(1)) {
          emit(EngineBootstrapStepDone(step, skipped: true));
        }
        emit(EngineBootstrapLog(EngineBootstrapStep.packages, 'Engine ${ready.version} (${ready.commit}) is ready at ${ready.dir}'));
        if (activate) EngineBootstrap.activate(ready);
        return ready;
      }
      if (markerFile.existsSync()) markerFile.deleteSync();

      final resolved = await _ensureSource(git, emit);
      emit(const EngineBootstrapStepDone(EngineBootstrapStep.source));

      final filamentVersion = _filamentVersion();
      final filamentDir = await _ensureFilament(filamentVersion, emit);
      emit(const EngineBootstrapStepDone(EngineBootstrapStep.filament));

      final openriglogicDir = await _ensureOpenRigLogic(emit);
      emit(const EngineBootstrapStepDone(EngineBootstrapStep.openriglogic));

      await _pubGet(flutter, emit);
      emit(const EngineBootstrapStepDone(EngineBootstrapStep.packages));

      final checkout = EngineCheckout(
        dir: checkoutDir.path,
        version: version,
        commit: resolved,
        repo: repo,
        filamentVersion: filamentVersion,
        filamentDir: filamentDir,
        openriglogicDir: openriglogicDir,
        completedAt: DateTime.now(),
      );
      markerFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(checkout.toJson()));
      if (activate) EngineBootstrap.activate(checkout);
      return checkout;
    } finally {
      try {
        await lock.unlock();
      } on FileSystemException {
        // Closing releases it too.
      }
      await lock.close();
    }
  }

  // ---------------------------------------------------------------------------
  // Prerequisites

  /// Git and the Flutter SDK (required), and the C++ toolchain the engine's
  /// native code builds with (reported only), found through [environment].
  Future<List<EnginePrerequisite>> checkPrerequisites() async {
    final out = <EnginePrerequisite>[
      EnginePrerequisite(
        name: 'Git',
        location: findExecutable('git'),
        required: true,
        hint: _windows
            ? 'Install Git for Windows (https://git-scm.com/download/win, or `winget install Git.Git`) and restart Lumina Studio.'
            : 'Install git with your package manager (e.g. `sudo apt install git`).',
      ),
      EnginePrerequisite(
        name: 'Flutter SDK',
        location: findExecutable('flutter'),
        required: true,
        hint: 'Install the Flutter SDK (https://docs.flutter.dev/get-started/install) and add its bin folder to PATH.',
      ),
    ];
    if (checkToolchain) out.addAll(await _toolchain());
    return out;
  }

  Future<List<EnginePrerequisite>> _toolchain() async {
    if (_windows) {
      final x86 = _env('ProgramFiles(x86)') ?? r'C:\Program Files (x86)';
      final vswhere = p.join(x86, 'Microsoft Visual Studio', 'Installer', 'vswhere.exe');
      String? location;
      if (File(vswhere).existsSync()) {
        try {
          final r = await Process.run(vswhere, [
            '-latest', '-products', '*', //
            '-requires', 'Microsoft.VisualStudio.Component.VC.Tools.x86.x64',
            '-property', 'installationPath',
          ]);
          final path = '${r.stdout}'.trim();
          if (r.exitCode == 0 && path.isNotEmpty) location = path.split(RegExp(r'\r?\n')).first;
        } on ProcessException {
          location = null;
        }
      }
      return [
        EnginePrerequisite(
          name: 'Visual Studio C++ Build Tools',
          location: location,
          required: false,
          hint: 'Install Visual Studio 2022 (or its Build Tools) with the "Desktop development with C++" workload.',
        ),
      ];
    }
    if (_os == 'macos') {
      return [
        EnginePrerequisite(
          name: 'Xcode command line tools',
          location: findExecutable('clang'),
          required: false,
          hint: 'Run `xcode-select --install`.',
        ),
      ];
    }
    const apt = 'sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev';
    String? gtk;
    final pkgConfig = findExecutable('pkg-config');
    if (pkgConfig != null) {
      try {
        final r = await Process.run(pkgConfig, ['--modversion', 'gtk+-3.0'], environment: environment, includeParentEnvironment: false);
        if (r.exitCode == 0) gtk = 'GTK ${'${r.stdout}'.trim()}';
      } on ProcessException {
        gtk = null;
      }
    }
    return [
      for (final tool in ['clang', 'cmake', 'ninja'])
        EnginePrerequisite(name: tool, location: findExecutable(tool), required: false, hint: 'Install it: `$apt`.'),
      EnginePrerequisite(name: 'GTK 3 development files', location: gtk, required: false, hint: 'Install them: `$apt`.'),
    ];
  }

  /// [name]'s full path on [environment]'s `PATH` (with `PATHEXT` on
  /// Windows), or null.
  String? findExecutable(String name) {
    final path = _env('PATH') ?? '';
    final exts = _windows
        ? [...(_env('PATHEXT') ?? '.COM;.EXE;.BAT;.CMD').split(';').where((e) => e.isNotEmpty).map((e) => e.toLowerCase())]
        : const [''];
    for (final dir in path.split(_windows ? ';' : ':')) {
      if (dir.trim().isEmpty) continue;
      for (final ext in exts) {
        final candidate = p.join(dir.trim(), '$name$ext');
        final stat = FileStat.statSync(candidate);
        if (stat.type != FileSystemEntityType.file) continue;
        if (!_windows && stat.mode & 0x49 == 0) continue; // no exec bit
        return candidate;
      }
    }
    return null;
  }

  String? _env(String name) {
    final exact = environment[name];
    if (exact != null || !_windows) return exact;
    final lower = name.toLowerCase();
    for (final e in environment.entries) {
      if (e.key.toLowerCase() == lower) return e.value;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Source

  Future<String> _ensureSource(String git, void Function(EngineBootstrapEvent) emit) async {
    const step = EngineBootstrapStep.source;
    final dir = checkoutDir;
    if (dir.existsSync() && !await _isOwnRepo(git)) {
      emit(EngineBootstrapLog(step, '${dir.path} is not a complete clone of $repo: downloading it again'));
      await _wipe(dir);
    }
    if (!dir.existsSync()) {
      emit(EngineBootstrapProgress(step, 'Cloning $repo', fraction: 0));
      final r = await _git(git, [
        'clone', '--filter=blob:none', '--no-checkout', '--progress', //
        if (_windows) ...['-c', 'core.longpaths=true'],
        repo, dir.path,
      ], step: step, emit: emit, workingDirectory: engineRoot.path);
      if (r != 0) {
        await _wipe(dir);
        throw EngineBootstrapException('Could not clone $repo (git exited with $r). Check the network connection and retry.', step: step);
      }
    }

    final target = commit.isNotEmpty ? commit : 'refs/tags/$version';
    var resolved = await _revParse(git, '$target^{commit}');
    if (resolved == null) {
      emit(EngineBootstrapProgress(step, 'Fetching $target'));
      if (commit.isNotEmpty) {
        await _git(git, ['fetch', '--filter=blob:none', '--progress', 'origin', commit], step: step, emit: emit);
        resolved = await _revParse(git, '$target^{commit}');
      }
      if (resolved == null) {
        await _git(git, ['fetch', '--filter=blob:none', '--progress', '--tags', 'origin'], step: step, emit: emit);
        resolved = await _revParse(git, '$target^{commit}');
      }
      if (resolved == null) {
        throw EngineBootstrapException('$repo has no commit ${commit.isNotEmpty ? commit : 'for tag $version'}.', step: step);
      }
    }

    final head = await _revParse(git, 'HEAD');
    final dirty = await _gitOutput(git, ['status', '--porcelain', '--untracked-files=no']);
    if (head != resolved || dirty == null || dirty.trim().isNotEmpty) {
      emit(EngineBootstrapProgress(step, 'Checking out $resolved', fraction: 0.8));
      final r = await _git(git, ['-c', 'advice.detachedHead=false', 'checkout', '--force', '--progress', '--detach', resolved],
          step: step, emit: emit);
      if (r != 0) {
        throw EngineBootstrapException('Could not check out $resolved (git exited with $r). Check the network connection and retry.',
            step: step);
      }
    } else {
      emit(EngineBootstrapLog(step, 'Already at $resolved'));
    }
    emit(EngineBootstrapProgress(step, 'Engine source at $resolved', fraction: 1));
    return resolved;
  }

  /// Whether [checkoutDir] holds its own `.git` (not a parent's) whose
  /// origin is [repo].
  Future<bool> _isOwnRepo(String git) async {
    final gitDir = Directory(p.join(checkoutDir.path, '.git'));
    if (!File(p.join(gitDir.path, 'HEAD')).existsSync()) return false;
    final top = await _gitOutput(git, ['rev-parse', '--absolute-git-dir']);
    if (top == null || !p.equals(p.normalize(top.trim()), p.normalize(gitDir.absolute.path))) return false;
    final origin = await _gitOutput(git, ['config', '--get', 'remote.origin.url']);
    return origin != null && origin.trim() == repo;
  }

  Future<String?> _revParse(String git, String rev) async {
    final out = await _gitOutput(git, ['rev-parse', '--verify', '--quiet', rev]);
    final sha = out?.trim();
    return sha == null || sha.isEmpty ? null : sha;
  }

  Map<String, String> get _gitEnvironment => {...environment, 'GIT_TERMINAL_PROMPT': '0'};

  Future<String?> _gitOutput(String git, List<String> args) async {
    try {
      final r = await Process.run(git, args,
          workingDirectory: checkoutDir.path, environment: _gitEnvironment, includeParentEnvironment: false, stdoutEncoding: utf8);
      return r.exitCode == 0 ? '${r.stdout}' : null;
    } on ProcessException {
      return null;
    }
  }

  static final RegExp _gitPercent = RegExp(r'^(Receiving objects|Resolving deltas|Updating files|remote: [^:]+):\s+(\d+)%');

  /// Runs git, streaming its output; `%` progress lines become progress
  /// events. Returns the exit code.
  Future<int> _git(String git, List<String> args,
      {required EngineBootstrapStep step, required void Function(EngineBootstrapEvent) emit, String? workingDirectory}) {
    return _stream(git, args, step: step, emit: emit, workingDirectory: workingDirectory ?? checkoutDir.path, environment: _gitEnvironment,
        progress: (line) {
      final m = _gitPercent.firstMatch(line);
      if (m == null) return null;
      final pct = int.parse(m.group(2)!) / 100;
      final phase = m.group(1)!;
      // Clone: objects to 70%, deltas to 80%; checkout: files to 100%.
      final fraction = switch (phase) {
        'Receiving objects' => pct * 0.7,
        'Resolving deltas' => 0.7 + pct * 0.1,
        'Updating files' => 0.8 + pct * 0.2,
        _ => null,
      };
      return EngineBootstrapProgress(step, line, fraction: fraction);
    });
  }

  Future<int> _stream(String exe, List<String> args,
      {required EngineBootstrapStep step,
      required void Function(EngineBootstrapEvent) emit,
      required String workingDirectory,
      required Map<String, String> environment,
      bool runInShell = false,
      EngineBootstrapProgress? Function(String line)? progress}) async {
    final Process process;
    try {
      process = await Process.start(exe, args,
          workingDirectory: workingDirectory, environment: environment, includeParentEnvironment: false, runInShell: runInShell);
    } on ProcessException catch (e) {
      emit(EngineBootstrapLog(step, 'Could not start $exe: ${e.message}'));
      return -1;
    }
    String? lastProgress;
    void onLine(String raw) {
      final line = raw.trimRight();
      if (line.isEmpty) return;
      final pr = progress?.call(line);
      if (pr != null) {
        // Throttle: one event per distinct line, and a log line when a phase ends.
        if (pr.message == lastProgress) return;
        lastProgress = pr.message;
        emit(pr);
        if (line.contains('100%') || line.contains('done')) emit(EngineBootstrapLog(step, line));
        return;
      }
      emit(EngineBootstrapLog(step, line));
    }

    Future<void> pump(Stream<List<int>> s) =>
        s.transform(const Utf8Decoder(allowMalformed: true)).transform(const _CrLfSplitter()).forEach(onLine);
    await Future.wait([pump(process.stdout), pump(process.stderr)]);
    return process.exitCode;
  }

  // ---------------------------------------------------------------------------
  // Filament

  String _filamentVersion() {
    final file = File(p.join(checkoutDir.path, 'tool', 'filament', 'VERSION'));
    if (!file.existsSync()) {
      throw EngineBootstrapException('The engine source has no tool/filament/VERSION: it does not say which Filament build it needs.',
          step: EngineBootstrapStep.filament);
    }
    final v = file.readAsStringSync().trim();
    if (v.isEmpty) throw const EngineBootstrapException('tool/filament/VERSION is empty.', step: EngineBootstrapStep.filament);
    return v;
  }

  Future<String> _ensureFilament(String filamentVersion, void Function(EngineBootstrapEvent) emit) async {
    const step = EngineBootstrapStep.filament;
    final FilamentProvider provider = filament ?? defaultFilamentProvider ?? FilamentPrebuilt.ensure;
    emit(EngineBootstrapProgress(step, 'Filament $filamentVersion', fraction: 0));
    final Directory dir;
    try {
      dir = await provider(
        version: filamentVersion,
        releaseTag: version,
        cacheRoot: filamentRoot,
        onProgress: (fraction, message) => emit(EngineBootstrapProgress(step, message, fraction: fraction)),
      );
    } on EngineBootstrapException {
      rethrow;
    } catch (e) {
      throw EngineBootstrapException('Could not get the prebuilt Filament $filamentVersion: $e', step: step);
    }
    final target = p.normalize(dir.absolute.path);
    if (!Directory(target).existsSync()) {
      throw EngineBootstrapException('The prebuilt Filament $filamentVersion is missing at $target.', step: step);
    }
    await _link(filamentLink, target, step);
    emit(EngineBootstrapLog(step, 'Linked ${p.join(checkoutDir.path, filamentLink)} -> $target'));
    emit(EngineBootstrapProgress(step, 'Filament $filamentVersion ready', fraction: 1));
    return target;
  }

  // ---------------------------------------------------------------------------
  // OpenRigLogic

  /// Links the release's prebuilt OpenRigLogic as `<checkout>/openriglogic`:
  /// flutter_riglogic comes from git (the pub cache), where its hook finds no
  /// built library, so the root pubspec's `riglogic_lib_dir` names
  /// `openriglogic/lib`.
  Future<String> _ensureOpenRigLogic(void Function(EngineBootstrapEvent) emit) async {
    const step = EngineBootstrapStep.openriglogic;
    final OpenRigLogicProvider provider = openriglogic ?? defaultOpenRigLogicProvider ?? OpenRigLogicPrebuilt.ensure;
    emit(const EngineBootstrapProgress(step, 'OpenRigLogic', fraction: 0));
    final Directory dir;
    try {
      dir = await provider(
        releaseTag: version,
        cacheRoot: openriglogicRoot,
        onProgress: (fraction, message) => emit(EngineBootstrapProgress(step, message, fraction: fraction)),
      );
    } on EngineBootstrapException {
      rethrow;
    } catch (e) {
      throw EngineBootstrapException('Could not get the prebuilt OpenRigLogic of $version: $e', step: step);
    }
    final target = p.normalize(dir.absolute.path);
    if (!Directory(target).existsSync()) {
      throw EngineBootstrapException('The prebuilt OpenRigLogic of $version is missing at $target.', step: step);
    }
    await _link(openriglogicLink, target, step);
    emit(EngineBootstrapLog(step, 'Linked ${p.join(checkoutDir.path, openriglogicLink)} -> $target'));
    emit(const EngineBootstrapProgress(step, 'OpenRigLogic ready', fraction: 1));
    return target;
  }

  /// `<checkout>/<name>` → [target]: a directory junction on Windows (no
  /// admin rights needed), a symlink elsewhere. The root pubspec's hook
  /// settings (and every hook's `../filament` fallback) name these folders.
  Future<void> _link(String name, String target, EngineBootstrapStep step) async {
    final path = p.join(checkoutDir.path, name);
    final link = Link(path);
    if (link.existsSync()) {
      if (_sameDir(link.targetSync(), target)) return;
      link.deleteSync();
    } else if (FileSystemEntity.typeSync(path, followLinks: false) != FileSystemEntityType.notFound) {
      FileSystemEntity.typeSync(path, followLinks: false) == FileSystemEntityType.directory
          ? Directory(path).deleteSync(recursive: true)
          : File(path).deleteSync();
    }
    if (!_windows) {
      link.createSync(target);
      return;
    }
    // `Link.create` makes a symbolic link on Windows, which needs Developer
    // Mode or admin rights; a junction needs neither.
    final cmd = p.join(_env('SystemRoot') ?? r'C:\Windows', 'System32', 'cmd.exe');
    final r = await Process.run(cmd, ['/c', 'mklink', '/J', p.normalize(path), p.normalize(target)],
        environment: environment, includeParentEnvironment: false);
    if (r.exitCode != 0) {
      throw EngineBootstrapException('Could not link $path to $target: ${'${r.stderr}'.trim()} ${'${r.stdout}'.trim()}',
          step: step);
    }
  }

  bool _linkOk(String name, String target) {
    final link = Link(p.join(checkoutDir.path, name));
    try {
      return link.existsSync() && _sameDir(link.targetSync(), target) && Directory(target).existsSync();
    } on FileSystemException {
      return false;
    }
  }

  bool _sameDir(String a, String b) {
    String norm(String s) {
      var n = p.normalize(s.startsWith(r'\\?\') ? s.substring(4) : s);
      if (_windows) n = n.toLowerCase();
      return n;
    }

    return norm(a) == norm(b);
  }

  // ---------------------------------------------------------------------------
  // Packages

  Future<void> _pubGet(String flutter, void Function(EngineBootstrapEvent) emit) async {
    const step = EngineBootstrapStep.packages;
    emit(const EngineBootstrapProgress(step, 'flutter pub get'));
    final code = await _stream(flutter, ['pub', 'get'],
        step: step,
        emit: emit,
        workingDirectory: checkoutDir.path,
        environment: environment,
        runInShell: _windows && !flutter.toLowerCase().endsWith('.exe'));
    if (code != 0) {
      throw EngineBootstrapException('`flutter pub get` failed (exit code $code). Check the network connection and retry.', step: step);
    }
    emit(const EngineBootstrapProgress(step, 'Packages resolved', fraction: 1));
  }

  // ---------------------------------------------------------------------------

  /// Deletes [dir] without following links (the targets of the `filament`
  /// and `openriglogic` links are shared), clearing the read-only flag git
  /// sets on pack files.
  Future<void> _wipe(Directory dir) async {
    if (!dir.existsSync()) return;
    for (final name in [filamentLink, openriglogicLink]) {
      final link = Link(p.join(dir.path, name));
      if (link.existsSync()) link.deleteSync();
    }
    try {
      await dir.delete(recursive: true);
    } on FileSystemException {
      if (_windows) {
        await Process.run('attrib', ['-R', '${dir.path}\\*', '/S', '/D'], runInShell: true);
      } else {
        await Process.run('chmod', ['-R', 'u+w', dir.path]);
      }
      await dir.delete(recursive: true);
    }
  }

  static String _safeName(String v) => v.replaceAll(RegExp(r'[<>:"/\\|?*\s]'), '_');
}

/// Splits text on `\n`, `\r\n` and bare `\r` (git redraws progress lines
/// with `\r`).
class _CrLfSplitter extends StreamTransformerBase<String, String> {
  const _CrLfSplitter();

  @override
  Stream<String> bind(Stream<String> stream) async* {
    var carry = '';
    await for (final chunk in stream) {
      final parts = (carry + chunk).split(RegExp(r'\r\n|\r|\n'));
      carry = parts.removeLast();
      yield* Stream.fromIterable(parts);
    }
    if (carry.isNotEmpty) yield carry;
  }
}
