import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:lumina_core/src/formats/lumina_project.dart' show kLuminaEngineDisplayVersion;
import 'package:lumina_core/src/services/filament_prebuilt.dart';
import 'package:lumina_core/src/services/lumina_data_dir.dart';
import 'package:lumina_core/src/services/jolt_prebuilt.dart';
import 'package:lumina_core/src/services/openriglogic_prebuilt.dart';
import 'package:lumina_core/src/services/workspace_paths.dart';

part 'engine_bootstrap/types.dart';
part 'engine_bootstrap/source.dart';
part 'engine_bootstrap/artifacts.dart';

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

  /// Where prebuilt Jolt Physics builds live (`<data>/jolt`).
  final Directory joltRoot;

  /// The environment tools are looked up in and run with.
  final Map<String, String> environment;

  /// Supplies the prebuilt Filament; defaults to [defaultFilamentProvider],
  /// else [FilamentPrebuilt.ensure] (the `filament-<VERSION>` release, else
  /// this release's own assets).
  final FilamentProvider? filament;

  /// Supplies the prebuilt OpenRigLogic; defaults to
  /// [defaultOpenRigLogicProvider], else [OpenRigLogicPrebuilt.ensure].
  final OpenRigLogicProvider? openriglogic;

  /// Supplies the prebuilt Jolt Physics; defaults to [defaultJoltProvider],
  /// else [JoltPrebuilt.ensure].
  final JoltProvider? jolt;

  /// Whether to look for the C++ toolchain (reported, never blocking).
  final bool checkToolchain;

  final String _os;

  /// The Filament provider bootstraps use unless given one (null:
  /// [FilamentPrebuilt.ensure]).
  static FilamentProvider? defaultFilamentProvider;

  /// The OpenRigLogic provider bootstraps use unless given one (null:
  /// [OpenRigLogicPrebuilt.ensure]).
  static OpenRigLogicProvider? defaultOpenRigLogicProvider;

  /// The Jolt Physics provider bootstraps use unless given one (null:
  /// [JoltPrebuilt.ensure]).
  static JoltProvider? defaultJoltProvider;

  /// The checkout's links to the prebuilt Filament and OpenRigLogic.
  static const String filamentLink = 'filament';
  static const String openriglogicLink = 'openriglogic';
  static const String joltLink = 'jolt';

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
    Directory? joltRoot,
    Map<String, String>? environment,
    this.filament,
    this.openriglogic,
    this.jolt,
    this.checkToolchain = true,
    String? operatingSystem,
  })  : engineRoot = engineRoot ?? LuminaDataDir.engineRoot(environment: environment),
        filamentRoot = filamentRoot ?? LuminaDataDir.filamentRoot(environment: environment),
        openriglogicRoot = openriglogicRoot ?? LuminaDataDir.openriglogicRoot(environment: environment),
        joltRoot = joltRoot ?? LuminaDataDir.joltRoot(environment: environment),
        environment = Map.of(environment ?? Platform.environment),
        _os = operatingSystem ?? Platform.operatingSystem;

  /// The bootstrap of this release build ([LuminaRelease]).
  factory EngineBootstrap.release({FilamentProvider? filament, OpenRigLogicProvider? openriglogic, JoltProvider? jolt}) =>
      EngineBootstrap(
          version: LuminaRelease.version,
          commit: LuminaRelease.commit,
          repo: LuminaRelease.repo,
          filament: filament,
          openriglogic: openriglogic,
          jolt: jolt);

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
      if (checkout.joltDir.isNotEmpty && !_linkOk(joltLink, checkout.joltDir)) return null;
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

      final joltDir = await _ensureJolt(emit);
      emit(EngineBootstrapStepDone(EngineBootstrapStep.jolt, skipped: joltDir.isEmpty));

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
        joltDir: joltDir,
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

  static String _safeName(String v) => v.replaceAll(RegExp(r'[<>:"/\\|?*\s]'), '_');
}
