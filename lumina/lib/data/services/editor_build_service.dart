import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:lumina/data/models/lumina_plugin_descriptor.dart';
import 'package:lumina/data/services/editor_build_cache.dart';
import 'package:lumina/data/services/editor_build_fingerprint.dart';
import 'package:lumina/data/services/editor_host_generator_service.dart';
import 'package:lumina/data/services/editor_source_vendor_service.dart';
import 'package:lumina/data/services/space_free_build_dir.dart';
import 'package:path/path.dart' as p;

/// The phases of a project editor build, with their share of the bar.
enum EditorBuildPhase {
  /// The engine source into the project, once.
  copyingSource(12, 'Copying editor source'),
  generatingHost(3, 'Generating editor host'),
  resolvingPackages(10, 'Resolving packages'),
  buildingNativeAssets(30, 'Building native assets'),
  compilingDart(33, 'Compiling editor'),
  linking(7, 'Linking'),
  installing(5, 'Installing');

  const EditorBuildPhase(this.weight, this.label);

  /// Percent of the whole build (the weights sum to 100).
  final int weight;
  final String label;

  /// The overall fraction when this phase is [inPhase] done.
  double overall(double inPhase) {
    var done = 0;
    for (final ph in EditorBuildPhase.values) {
      if (ph == this) break;
      done += ph.weight;
    }
    return (done + weight * inPhase.clamp(0.0, 1.0)) / 100.0;
  }
}

class EditorBuildProgress {
  final EditorBuildPhase phase;

  /// Overall 0–1, monotonic non-decreasing over a build.
  final double fraction;
  final String message;
  final String? logLine;

  const EditorBuildProgress(this.phase, this.fraction, this.message, {this.logLine});

  @override
  String toString() => '${(fraction * 100).floor()}% - $message';
}

sealed class EditorBuildOutcome {
  const EditorBuildOutcome();
}

class EditorBuildSucceeded extends EditorBuildOutcome {
  final EditorBuildEntry entry;
  final String? logPath;

  /// The whole build, from generation to install (zero on a cache hit).
  final Duration elapsed;
  const EditorBuildSucceeded(this.entry, this.logPath, this.elapsed);
}

class EditorBuildFailed extends EditorBuildOutcome {
  final String message;

  /// The last [EditorBuildService.failureTailLines] lines of the log.
  final List<String> lastLines;
  final String? logPath;
  const EditorBuildFailed(this.message, this.lastLines, this.logPath);
}

class EditorBuildCancelled extends EditorBuildOutcome {
  final String? logPath;
  const EditorBuildCancelled(this.logPath);
}

/// Starts a child process; the same shape as the cook step's starter, so a
/// test replays recorded output through it.
typedef EditorBuildProcessStarter = Future<Process> Function(String executable, List<String> arguments,
    {String? workingDirectory, Map<String, String>? environment});

Future<Process> defaultEditorBuildProcessStarter(String executable, List<String> arguments,
        {String? workingDirectory, Map<String, String>? environment}) =>
    Process.start(executable, arguments,
        workingDirectory: workingDirectory, environment: environment, runInShell: Platform.isWindows);

/// Kills [pid] and its children (`flutter` is a script that runs the tool,
/// which runs MSBuild/CMake/ninja and the hooks).
Future<void> killProcessTree(int pid) async {
  if (Platform.isWindows) {
    await Process.run('taskkill', ['/T', '/F', '/PID', '$pid']);
    return;
  }
  Future<List<int>> children(int parent) async {
    final r = await Process.run('pgrep', ['-P', '$parent']);
    return (r.stdout as String).split('\n').map((l) => int.tryParse(l.trim())).whereType<int>().toList();
  }

  final all = <int>[];
  Future<void> collect(int id) async {
    for (final c in await children(id)) {
      all.add(c);
      await collect(c);
    }
  }

  await collect(pid);
  for (final id in [pid, ...all.reversed]) {
    Process.killPid(id, ProcessSignal.sigkill);
  }
}

/// One running build. [progress] is a broadcast stream; [result] completes
/// once, with the outcome.
class EditorBuildJob {
  final Stream<EditorBuildProgress> progress;
  final Future<EditorBuildOutcome> result;
  final void Function() _cancel;
  final String? Function() _logPath;

  EditorBuildJob._(this.progress, this.result, this._cancel, this._logPath);

  void cancel() => _cancel();

  /// `<cache>/<hash>.log`, once the hash is known (after `pub get`).
  String? get logPath => _logPath();
}

/// Maps `flutter build <platform> -v` output to phases and in-phase
/// fractions. Only counts the output carries move the bar:
/// - native assets: completed build hooks (`output.json contents:` after a
///   hook's "Running (cd package…" line) against [hookPackages];
/// - compiling: the flutter_assemble targets the tool reports complete
///   (kernel snapshot, AOT snapshot, bundle assets);
/// - linking: MSBuild's finished projects against the [linkTargets] of the
///   generated solution, or CMake/ninja's `[n/m]` steps.
/// A line without a count leaves the bar where it is.
///
/// The tool runs the hooks and the kernel compile in parallel; the bar stays
/// in the native-assets phase until the last hook is done (a compile
/// milestone seen meanwhile is applied when the phase is entered).
class EditorBuildProgressParser {
  /// How many packages in the host's package graph have a `hook/build.dart`.
  final int hookPackages;

  /// How many projects MSBuild builds (the top-level `.sln`'s projects), read
  /// when linking starts; null or 0 when unknown (non-Windows).
  final int Function()? linkTargets;

  EditorBuildProgressParser({required this.hookPackages, this.linkTargets});

  EditorBuildPhase phase = EditorBuildPhase.buildingNativeAssets;
  double inPhase = 0;
  String message = EditorBuildPhase.buildingNativeAssets.label;

  String? _currentHook;
  final Set<String> _hooksDone = {};
  double _compileMilestone = 0;
  final Set<String> _projectsDone = {};
  int _projectsDoneAtLink = 0;
  int? _linkTotal;

  static final _hookStart = RegExp(r'Running `\(cd (.+?)[\/]?;');
  static final _hooksFinished = RegExp(r'Running build hooks for \S+ done\.|build_hooks: Complete|Skipping target: build_hooks');
  static final _projectDone = RegExp(r'Done Building Project "([^"]+\.vcxproj)"');
  static final _step = RegExp(r'^\s*(?:\[[^\]]*\]\s*)*\[\s*(\d+)\s*/\s*(\d+)\s*\]');

  /// flutter_assemble targets and how far through compiling they are.
  static const Map<String, double> _compileMilestones = {
    'kernel_snapshot_program: Starting': 0.05,
    'kernel_snapshot_program: Complete': 0.4,
    'aot_elf_release: Starting': 0.45,
    'aot_elf_profile: Starting': 0.45,
    'aot_elf_release: Complete': 0.9,
    'aot_elf_profile: Complete': 0.9,
    '_assets: Complete': 1.0,
  };

  /// Feeds one line; returns true when the phase or fraction moved.
  bool feed(String line) {
    final before = (phase, inPhase, message);
    for (final m in _compileMilestones.entries) {
      if (line.contains(m.key) && m.value > _compileMilestone) _compileMilestone = m.value;
    }
    final done = _projectDone.firstMatch(line);
    if (done != null) _projectsDone.add(done.group(1)!.toLowerCase());

    switch (phase) {
      case EditorBuildPhase.buildingNativeAssets:
        final start = _hookStart.firstMatch(line);
        if (start != null) {
          _currentHook = start.group(1)!.replaceAll(r'\', '/').split('/').lastWhere((s) => s.isNotEmpty);
          message = '${EditorBuildPhase.buildingNativeAssets.label} ($_currentHook)';
        } else if (line.contains('output.json contents:') && _currentHook != null) {
          if (_hooksDone.add(_currentHook!) && hookPackages > 0) {
            inPhase = (_hooksDone.length / hookPackages).clamp(0.0, 1.0);
          }
        } else if (_hooksFinished.hasMatch(line)) {
          inPhase = 1;
          _enter(EditorBuildPhase.compilingDart);
          inPhase = _compileMilestone;
        }
      case EditorBuildPhase.compilingDart:
        if (_compileMilestone > inPhase) inPhase = _compileMilestone;
        if (done != null && done.group(1)!.toLowerCase().endsWith('flutter_assemble.vcxproj') ||
            line.contains('Building Linux application') && _compileMilestone >= 1) {
          inPhase = 1;
          _enter(EditorBuildPhase.linking);
          _projectsDoneAtLink = _projectsDone.length;
          _linkTotal = linkTargets?.call();
        }
      case EditorBuildPhase.linking:
        final total = _linkTotal ?? 0;
        if (done != null && total > _projectsDoneAtLink) {
          final f = (_projectsDone.length - _projectsDoneAtLink) / (total - _projectsDoneAtLink);
          if (f > inPhase) inPhase = f.clamp(0.0, 1.0);
          message = '${EditorBuildPhase.linking.label} (${p.basenameWithoutExtension(done.group(1)!.replaceAll(r'\', '/'))})';
        }
        final step = _step.firstMatch(line);
        if (step != null) {
          final n = int.parse(step.group(1)!), m = int.parse(step.group(2)!);
          if (m > 0 && n / m > inPhase) inPhase = (n / m).clamp(0.0, 1.0);
        }
        if (line.contains('Built build')) inPhase = 1;
      default:
        break;
    }
    return before != (phase, inPhase, message);
  }

  void _enter(EditorBuildPhase to) {
    if (to.index <= phase.index) return;
    phase = to;
    inPhase = 0;
    message = to.label;
  }

  double get overall => phase.overall(inPhase);

  /// Projects in the generated Visual Studio solution of [hostDir]'s build.
  static int msBuildProjects(String buildDir) {
    final dir = Directory(buildDir);
    if (!dir.existsSync()) return 0;
    for (final f in dir.listSync().whereType<File>()) {
      if (f.path.endsWith('.sln')) {
        return f.readAsLinesSync().where((l) => l.startsWith('Project(')).length;
      }
    }
    return 0;
  }
}

/// Generates, resolves, builds and installs a project editor:
/// **generate → pub get → flutter build → install**, as a stream of
/// [EditorBuildProgress] and one [EditorBuildOutcome]. The full log goes to
/// `<cache>/<hash>.log`.
class EditorBuildService {
  final String engineRoot;
  final EditorBuildCache cache;
  final EditorHostGeneratorService generator;

  /// Copies the engine source into the project before the first build.
  final EditorSourceVendorService vendor;
  final String flutterExecutable;
  final EditorBuildProcessStarter _starter;
  final Future<void> Function(int pid) _killTree;
  final Future<FlutterToolInfo> Function() flutterInfo;

  /// `release` (default) or `debug`.
  final String mode;

  /// `windows`, `linux` or `macos`.
  final String platform;

  /// Extra environment for the child processes (the smoke run redirects the
  /// caches with it).
  final Map<String, String>? environment;

  /// Whether to delete the host's `.dart_tool/` and `build/` after install
  /// (only the bundle is cached).
  final bool cleanHostAfterInstall;

  /// Windows: where the space-free build aliases of project hosts live
  /// Defaults to `%LOCALAPPDATA%\lumina\hosts`.
  final Directory? hostAliasRoot;

  static const int failureTailLines = 50;

  EditorBuildService({
    required this.engineRoot,
    EditorBuildCache? cache,
    EditorHostGeneratorService? generator,
    EditorSourceVendorService? vendor,
    String? flutterExecutable,
    EditorBuildProcessStarter? processStarter,
    Future<void> Function(int pid)? killTree,
    Future<FlutterToolInfo> Function()? flutterInfo,
    this.mode = 'release',
    String? platform,
    this.environment,
    this.cleanHostAfterInstall = true,
    this.hostAliasRoot,
  })  : cache = cache ?? EditorBuildCache(),
        generator = generator ?? EditorHostGeneratorService(engineRoot: engineRoot, platform: platform),
        vendor = vendor ?? EditorSourceVendorService(engineRoot: engineRoot),
        flutterExecutable = flutterExecutable ?? 'flutter',
        _starter = processStarter ?? defaultEditorBuildProcessStarter,
        _killTree = killTree ?? killProcessTree,
        flutterInfo = flutterInfo ?? FlutterToolInfo.probe,
        platform = platform ?? Platform.operatingSystem;

  /// Where `pub get` and `flutter build` run for [hostDir]: the host itself,
  /// or on Windows a junction to it under a space-free root (see
  /// [SpaceFreeBuildDir]). The files stay in the project.
  String buildDirOf(String hostDir) => SpaceFreeBuildDir.of(hostDir, aliasRoot: hostAliasRoot, platform: platform);

  /// `build/<platform>/…` holding the runnable bundle, relative to the host.
  String bundleDirOf(String hostDir) => switch (platform) {
        'windows' => p.join(hostDir, 'build', 'windows', 'x64', 'runner', mode == 'debug' ? 'Debug' : 'Release'),
        'macos' => p.join(hostDir, 'build', 'macos', 'Build', 'Products', mode == 'debug' ? 'Debug' : 'Release'),
        _ => p.join(hostDir, 'build', 'linux', 'x64', mode, 'bundle'),
      };

  /// The executable inside the bundle.
  String executableIn(String packageName) => switch (platform) {
        'windows' => '$packageName.exe',
        'macos' => p.join('$packageName.app', 'Contents', 'MacOS', packageName),
        _ => packageName,
      };

  /// Packages in the host's package graph that have a `hook/build.dart`
  /// (from `.dart_tool/package_config.json`).
  static int countHookPackages(String hostDir) {
    final config = File(p.join(hostDir, '.dart_tool', 'package_config.json'));
    if (!config.existsSync()) return 0;
    final json = jsonDecode(config.readAsStringSync()) as Map<String, dynamic>;
    var n = 0;
    for (final pkg in (json['packages'] as List).cast<Map<String, dynamic>>()) {
      final root = Uri.parse(pkg['rootUri'] as String);
      final dir = root.isAbsolute ? root.toFilePath() : p.normalize(p.join(p.dirname(config.path), root.toFilePath()));
      if (File(p.join(dir, 'hook', 'build.dart')).existsSync()) n++;
    }
    return n;
  }

  /// Builds the project editor of [projectDir]. [syncSource] replaces the
  /// project's copy of the engine source first, even when one is there (the
  /// update to the running engine), and [onSourceSynced] runs once the new
  /// copy is in place.
  EditorBuildJob start(String projectDir, List<LuminaPluginDescriptor> plugins,
      {String? projectName, bool syncSource = false, FutureOr<void> Function()? onSourceSynced}) {
    final controller = StreamController<EditorBuildProgress>.broadcast();
    final result = Completer<EditorBuildOutcome>();
    var cancelled = false;
    Process? running;
    String? logPath;
    final log = <String>[];
    IOSink? sink;
    var last = 0.0;

    void emit(EditorBuildPhase phase, double overall, String message, {String? line}) {
      if (overall < last) overall = last;
      last = overall;
      if (!controller.isClosed) controller.add(EditorBuildProgress(phase, overall, message, logLine: line));
    }

    void logLine(String line) {
      log.add(line);
      sink?.writeln(line);
    }

    Future<int> run(List<String> args, String cwd, void Function(String line) onLine) async {
      logLine('\$ $flutterExecutable ${args.join(' ')}   (in $cwd)');
      final proc = running = await _starter(flutterExecutable, args, workingDirectory: cwd, environment: environment);
      if (cancelled) await _killTree(proc.pid);
      final done = <Future<void>>[];
      for (final stream in [proc.stdout, proc.stderr]) {
        done.add(stream.transform(utf8.decoder).transform(const LineSplitter()).listen((l) {
          logLine(l);
          onLine(l);
        }).asFuture<void>());
      }
      final code = await proc.exitCode;
      await Future.wait(done);
      running = null;
      return code;
    }

    Future<EditorBuildOutcome> failed(String message) async {
      logLine('BUILD FAILED: $message');
      await sink?.flush();
      final tail = log.length <= failureTailLines ? List<String>.from(log) : log.sublist(log.length - failureTailLines);
      return EditorBuildFailed(message, tail, logPath);
    }

    Future<EditorBuildOutcome> body() async {
      final sw = Stopwatch()..start();
      final hostDir = EditorHostGeneratorService.hostDirOf(projectDir);

      // The engine source into the project, once; a copy that is
      // already there (possibly edited) is left alone unless [syncSource].
      const copying = EditorBuildPhase.copyingSource;
      final label = syncSource ? 'Updating editor source' : copying.label;
      emit(copying, 0, label);
      if (syncSource || !vendor.isVendored(hostDir)) {
        final start = syncSource
            ? 'Updating the editor source in $hostDir from $engineRoot (edits in the copy are replaced)'
            : 'Copying the editor source from $engineRoot into $hostDir';
        logLine(start);
        await Directory(hostDir).create(recursive: true);
        // On the splash's log too (after the first await: the splash listens
        // once start returns).
        emit(copying, 0, label, line: start);
        var shown = -1;
        try {
          await vendor.vendor(hostDir, onProgress: (fraction, file) {
            if (cancelled) throw const _Cancelled();
            final percent = (fraction * 100).floor();
            if (percent == shown) return;
            shown = percent;
            emit(copying, copying.overall(fraction), '$label ($percent %)', line: file);
          });
        } on _Cancelled {
          return EditorBuildCancelled(logPath);
        } on StateError catch (e) {
          return failed('copying the editor source failed: ${e.message}');
        } on FileSystemException catch (e) {
          return failed('copying the editor source failed: ${e.message} (${e.path})');
        }
        final copied = 'Copied the editor source (${EditorSourceVendorService.copiedRepos(hostDir).join(', ')})';
        logLine(copied);
        emit(copying, copying.overall(1), label, line: copied);
        if (syncSource) await onSourceSynced?.call();
      } else {
        await vendor.linkOpenRigLogic(hostDir);
      }
      emit(copying, copying.overall(1), label);
      if (cancelled) return EditorBuildCancelled(logPath);

      emit(EditorBuildPhase.generatingHost, EditorBuildPhase.generatingHost.overall(0), EditorBuildPhase.generatingHost.label);
      final gen = await generator.generate(projectDir, plugins, projectName: projectName);
      if (gen.status != EditorHostStatus.generated) return failed('the project enables no code plugins');
      logLine('Generated ${gen.packageName} in $hostDir');
      emit(EditorBuildPhase.generatingHost, EditorBuildPhase.generatingHost.overall(1), EditorBuildPhase.generatingHost.label);
      if (cancelled) return EditorBuildCancelled(logPath);

      // Windows: through a space-free alias of the host (see buildDirOf).
      final buildDir = buildDirOf(hostDir);
      if (buildDir != hostDir) logLine('Building through $buildDir -> $hostDir');
      emit(EditorBuildPhase.resolvingPackages, EditorBuildPhase.resolvingPackages.overall(0), EditorBuildPhase.resolvingPackages.label);
      final pubGet = await run(['pub', 'get'], buildDir, (l) => emit(EditorBuildPhase.resolvingPackages, last, EditorBuildPhase.resolvingPackages.label, line: l));
      if (cancelled) return EditorBuildCancelled(logPath);
      if (pubGet != 0) return failed('flutter pub get exited with code $pubGet');
      // The host keeps the engine's versions unless a code plugin's
      // constraints forced another one; the editor source was not built
      // against that version, so the log says which.
      for (final moved in generator.movedFromEngineLock(hostDir)) {
        logLine('Warning: a code plugin moved $moved (the engine was built with the first version)');
      }
      emit(EditorBuildPhase.resolvingPackages, EditorBuildPhase.resolvingPackages.overall(1), EditorBuildPhase.resolvingPackages.label);

      final flutter = await flutterInfo();
      final inputs = EditorHostInputs(
        hostDir: hostDir,
        // The build compiles the project's copy.
        engineRoot: hostDir,
        repos: EditorSourceVendorService.copiedRepos(hostDir),
        pluginDirs: {for (final d in EditorHostGeneratorService.editorCodePlugins(plugins)) d.name: d.pluginDir.path},
        flutterVersion: flutter.version,
        flutterRevision: flutter.revision,
        platform: EditorHostInputs.currentPlatform(),
        mode: mode,
      );
      final components = await fingerprintComponents(inputs);
      final hash = fingerprintOf(components);
      await cache.root.create(recursive: true);
      logPath = cache.logFile(hash).path;
      sink = cache.logFile(hash).openWrite();
      for (final l in log) {
        sink!.writeln(l);
      }
      logLine('Editor fingerprint $hash');

      return cache.withLock(hash, () async {
        final hit = cache.lookup(hash);
        if (hit != null) {
          // Another launcher built it while we resolved packages.
          logLine('Cache hit: ${hit.dir.path}');
          await _writeHostStamp(hostDir, hash, components, flutter, hit.stamp['executable'] as String?);
          emit(EditorBuildPhase.installing, 1, EditorBuildPhase.installing.label);
          await sink?.flush();
          return EditorBuildSucceeded(hit, logPath, sw.elapsed);
        }

        final parser = EditorBuildProgressParser(
          hookPackages: countHookPackages(hostDir),
          linkTargets: () => EditorBuildProgressParser.msBuildProjects(p.join(hostDir, 'build', 'windows', 'x64')),
        );
        emit(parser.phase, parser.overall, parser.message);
        final args = ['build', platform, '--$mode', '-v', '--dart-define=LUMINA_EDITOR_FINGERPRINT=$hash'];
        final code = await run(args, buildDir, (l) {
          parser.feed(l);
          emit(parser.phase, parser.overall, parser.message, line: l);
        });
        if (cancelled) return EditorBuildCancelled(logPath);
        if (code != 0) return failed('flutter build $platform --$mode exited with code $code');
        _appendHookLogs(hostDir, logLine);

        emit(EditorBuildPhase.installing, EditorBuildPhase.installing.overall(0), EditorBuildPhase.installing.label);
        final bundle = Directory(bundleDirOf(hostDir));
        final exe = executableIn(gen.packageName!);
        if (!File(p.join(bundle.path, exe)).existsSync()) return failed('the build produced no ${p.join(bundle.path, exe)}');
        final stamp = _stamp(hash, components, flutter, exe);
        final entry = await cache.install(hash, bundle, stamp: stamp);
        await _writeHostStamp(hostDir, hash, components, flutter, exe);
        if (cleanHostAfterInstall) {
          for (final d in ['.dart_tool', 'build']) {
            final dir = Directory(p.join(hostDir, d));
            try {
              if (dir.existsSync()) await dir.delete(recursive: true);
            } on FileSystemException catch (e) {
              logLine('Could not remove $d: ${e.message}');
            }
          }
        }
        logLine('Installed ${entry.executable} in ${sw.elapsed.inSeconds}s');
        emit(EditorBuildPhase.installing, 1, 'Starting editor');
        await sink?.flush();
        return EditorBuildSucceeded(entry, logPath, sw.elapsed);
      });
    }

    () async {
      EditorBuildOutcome outcome;
      try {
        outcome = await body();
      } catch (e, st) {
        outcome = await failed('$e\n$st');
      }
      if (outcome is EditorBuildCancelled) logLine('Build cancelled');
      await sink?.flush();
      await sink?.close();
      await controller.close();
      result.complete(outcome);
    }();

    return EditorBuildJob._(controller.stream, result.future, () {
      if (cancelled) return;
      cancelled = true;
      final proc = running;
      if (proc != null) unawaited(_killTree(proc.pid));
    }, () => logPath);
  }

  Map<String, dynamic> _stamp(String hash, Map<String, String> components, FlutterToolInfo flutter, String exe) => {
        'hash': hash,
        'inputs': components,
        'engineRevision': {for (final e in components.entries) if (e.key.startsWith('engine:')) e.key.substring(7): e.value},
        'flutterVersion': flutter.version,
        'platform': EditorHostInputs.currentPlatform(),
        'mode': mode,
        'builtAt': DateTime.now().toUtc().toIso8601String(),
        'executable': exe,
      };

  Future<void> _writeHostStamp(String hostDir, String hash, Map<String, String> components, FlutterToolInfo flutter, String? exe) async {
    await File(p.join(hostDir, EditorHostGeneratorService.stampFileName))
        .writeAsString(const JsonEncoder.withIndent('  ').convert(_stamp(hash, components, flutter, exe ?? '')));
  }

  /// The hooks' own output (`native cache hit …`, compiler lines) lives under
  /// `.dart_tool/hooks_runner/`, which is deleted after install; keep it in
  /// the build log.
  static void _appendHookLogs(String hostDir, void Function(String) logLine) {
    final dir = Directory(p.join(hostDir, '.dart_tool', 'hooks_runner'));
    if (!dir.existsSync()) return;
    final files = dir.listSync(recursive: true).whereType<File>().where((f) => p.basename(f.path) == 'stdout.txt').toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final f in files) {
      final rel = p.relative(f.path, from: dir.path).replaceAll(r'\', '/');
      logLine('--- hook output: ${rel.split('/').first} ---');
      for (final l in const LineSplitter().convert(f.readAsStringSync())) {
        logLine(l);
      }
    }
  }
}

/// Thrown from the copy's progress callback to stop it on cancel.
class _Cancelled implements Exception {
  const _Cancelled();
}
