import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:lumina_core/lumina_core.dart';
import 'package:lumina/data/services/editor_build_service.dart';
import 'package:lumina/data/services/editor_host_generator_service.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'editor_build_test_support.dart';

/// Replays a recorded `flutter build` output line by line as a real
/// [Process] would stream it.
class ReplayProcess implements Process {
  final List<String> lines;
  final int code;
  final Duration lineDelay;
  final bool hang;
  final _out = StreamController<List<int>>();
  final _exit = Completer<int>();
  bool killed = false;

  ReplayProcess(this.lines, {this.code = 0, this.lineDelay = Duration.zero, this.hang = false}) {
    () async {
      for (final l in lines) {
        if (killed) break;
        _out.add(utf8.encode('$l\n'));
        if (lineDelay > Duration.zero) await Future<void>.delayed(lineDelay);
      }
      while (hang && !killed) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      await _out.close();
      if (!_exit.isCompleted) _exit.complete(killed ? -1 : code);
    }();
  }

  @override
  Stream<List<int>> get stdout => _out.stream;
  @override
  Stream<List<int>> get stderr => const Stream.empty();
  @override
  Future<int> get exitCode => _exit.future;
  @override
  int get pid => 424242;
  @override
  IOSink get stdin => IOSink(StreamController<List<int>>().sink);
  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) => killed = true;
}

/// Generate → pub get → build → install, with real
/// phase progress. `flutter build` is the recorded real output of a
/// generated host (`test/fixtures/editor_build/windows_release.log`, captured
/// once from `flutter build windows --release -v`); `pub get` runs for real.
void main() {
  final engineRoot = LuminaWorkspace.root;
  final fixture = File(p.join(LuminaWorkspace.package('lumina'), 'test', 'fixtures', 'editor_build', 'windows_release.log'));
  final recorded = const LineSplitter().convert(fixture.readAsStringSync());
  // The recorded host: 3 packages with a build hook (flutter_filament,
  // flutter_assimp, flutter_riglogic) and a 9-project Visual Studio solution.
  const recordedHooks = 3, recordedProjects = 9;

  group('progress parser over the recorded log', () {
    test('fractions are monotonic and the phases follow the table order', () {
      final parser = EditorBuildProgressParser(hookPackages: recordedHooks, linkTargets: () => recordedProjects);
      var last = 0.0;
      final phases = <EditorBuildPhase>[parser.phase];
      for (final l in recorded) {
        parser.feed(l);
        expect(parser.overall, greaterThanOrEqualTo(last), reason: l);
        last = parser.overall;
        if (phases.last != parser.phase) phases.add(parser.phase);
      }
      expect(phases, [EditorBuildPhase.buildingNativeAssets, EditorBuildPhase.compilingDart, EditorBuildPhase.linking]);
      expect(parser.inPhase, 1.0, reason: 'the build ends linked');
      expect(parser.overall, closeTo(EditorBuildPhase.installing.overall(0), 1e-9));
    });

    test('native assets reach 100 % exactly at the last hook line', () {
      final parser = EditorBuildProgressParser(hookPackages: recordedHooks, linkTargets: () => recordedProjects);
      final hookDoneLines = [for (var i = 0; i < recorded.length; i++) if (recorded[i].contains('output.json contents:')) i];
      expect(hookDoneLines, hasLength(recordedHooks));
      final messages = <String>{};
      for (var i = 0; i < recorded.length; i++) {
        parser.feed(recorded[i]);
        messages.add(parser.message);
        if (i < hookDoneLines.last) {
          expect(parser.phase == EditorBuildPhase.buildingNativeAssets && parser.inPhase < 1.0, isTrue, reason: 'line $i');
        }
        if (i == hookDoneLines.last) {
          expect(parser.phase, EditorBuildPhase.buildingNativeAssets);
          expect(parser.inPhase, 1.0);
          break;
        }
      }
      expect(messages, containsAll(['Building native assets (flutter_assimp)', 'Building native assets (flutter_filament)', 'Building native assets (flutter_riglogic)']));
    });

    test('a line without a count leaves the bar where it is', () {
      final parser = EditorBuildProgressParser(hookPackages: 3);
      expect(parser.feed('Building Windows application...'), isFalse);
      expect(parser.overall, EditorBuildPhase.buildingNativeAssets.overall(0));
    });
  });

  group('EditorBuildService', () {
    late EditorBuildFixture fx;
    late EditorBuildCache cache;
    setUp(() async {
      fx = await EditorBuildFixture.create(engineRoot: engineRoot);
      cache = EditorBuildCache(root: Directory(p.join(fx.temp.path, 'cache', 'editor-builds')), nativeRoot: Directory(p.join(fx.temp.path, 'cache', 'native')));
    });
    tearDown(() => fx.dispose());

    Future<FlutterToolInfo> flutterInfo() async => const FlutterToolInfo('3.47.5', '6a19cca564');

    EditorBuildService service(Future<Process> Function(List<String> args) build, {Future<void> Function(int)? killTree}) => EditorBuildService(
          engineRoot: engineRoot,
          // The copy's layout as links (the real copy is
          // editor_source_vendor_service_test's and the smoke run's).
          vendor: EditorSourceVendorService(engineRoot: engineRoot, linkPackages: true),
          hostAliasRoot: Directory(p.join(fx.temp.path, 'hosts')),
          cache: cache,
          platform: 'windows',
          flutterExecutable: Platform.isWindows ? 'flutter.bat' : 'flutter',
          flutterInfo: flutterInfo,
          killTree: killTree,
          processStarter: (exe, args, {workingDirectory, environment}) =>
              args.first == 'build' ? build(args) : defaultEditorBuildProcessStarter(exe, args, workingDirectory: workingDirectory, environment: environment),
        );

    test('streams the phases in order with monotonic fractions from real pub get + the recorded build', () async {
      List<String>? buildArgs;
      final svc = service((args) async {
        buildArgs = args;
        return ReplayProcess(recorded);
      });
      final job = svc.start(fx.projectDir.path, [await fx.plugin()]);
      final events = <EditorBuildProgress>[];
      job.progress.listen(events.add);
      final outcome = await job.result;
      // The replay leaves no binary behind, so install reports that — the
      // real install is the smoke run's.
      expect(outcome, isA<EditorBuildFailed>());
      expect((outcome as EditorBuildFailed).message, contains('produced no'));

      var last = 0.0;
      final order = <EditorBuildPhase>[];
      for (final e in events) {
        expect(e.fraction, greaterThanOrEqualTo(last));
        last = e.fraction;
        if (order.isEmpty || order.last != e.phase) order.add(e.phase);
      }
      expect(order, EditorBuildPhase.values.toList(), reason: 'generate → resolve → native assets → compile → link → install');
      expect(events.where((e) => e.phase == EditorBuildPhase.buildingNativeAssets).map((e) => e.fraction).reduce((a, b) => a > b ? a : b),
          closeTo(EditorBuildPhase.buildingNativeAssets.overall(1), 1e-9));
      expect(buildArgs, containsAll(['build', 'windows', '--release']));
      expect(buildArgs!.any((a) => a.startsWith('--dart-define=LUMINA_EDITOR_FINGERPRINT=')), isTrue);
      expect(job.logPath, isNotNull);
      expect(File(job.logPath!).readAsStringSync(), contains('Running build hooks for windows_x64 done.'));
      expect(p.dirname(job.logPath!), cache.root.path);
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('the first build copies the source (links here), a second one leaves the copy alone', () async {
      expect(EditorBuildPhase.values.first, EditorBuildPhase.copyingSource);
      expect(EditorBuildPhase.values.fold<int>(0, (s, ph) => s + ph.weight), 100);
      final host = EditorHostGeneratorService.hostDirOf(fx.projectDir.path);
      final svc = service((args) async => ReplayProcess(recorded));
      final firstEvents = <EditorBuildProgress>[];
      final first = svc.start(fx.projectDir.path, const []);
      first.progress.listen(firstEvents.add);
      await first.result;
      expect(firstEvents.first.phase, EditorBuildPhase.copyingSource);
      expect(EditorSourceVendorService(engineRoot: engineRoot).isVendored(host), isTrue);
      expect(FileSystemEntity.isLinkSync(p.join(host, 'filament')), isTrue);
      expect(File(p.join(host, 'pubspec.yaml')).readAsStringSync(), contains('  lumina_ui:\n    path: lumina_ui\n'));
      expect(File(first.logPath!).readAsStringSync(), contains('Copying the editor source'));

      final marker = File(p.join(host, EditorSourceVendorService.stampFileName)).readAsStringSync();
      final second = svc.start(fx.projectDir.path, const []);
      await second.result;
      expect(File(p.join(host, EditorSourceVendorService.stampFileName)).readAsStringSync(), marker, reason: 'not copied again');
      expect(File(second.logPath!).readAsStringSync(), isNot(contains('Copying the editor source')));
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('on Windows a host under a path with a space builds through a space-free junction', () {
      final spaced = Directory(p.join(fx.temp.path, 'Lumina Projects', 'Space Game', '.lumina', 'editor'))..createSync(recursive: true);
      final aliases = Directory(p.join(fx.temp.path, 'hosts'));
      final svc = EditorBuildService(engineRoot: engineRoot, cache: cache, platform: 'windows', hostAliasRoot: aliases);
      final dir = svc.buildDirOf(spaced.path);
      if (!Platform.isWindows) {
        expect(dir, spaced.path, reason: 'other hosts build in place');
        return;
      }
      expect(p.isWithin(aliases.path, dir), isTrue);
      expect(p.basename(dir), isNot(contains(' ')));
      expect(FileSystemEntity.isLinkSync(dir), isTrue);
      File(p.join(spaced.path, 'marker.txt')).writeAsStringSync('in the project');
      expect(File(p.join(dir, 'marker.txt')).readAsStringSync(), 'in the project', reason: 'the files stay in the project');
      expect(svc.buildDirOf(spaced.path), dir, reason: 'stable per host');
      final other = Directory(p.join(fx.temp.path, 'Other Game', '.lumina', 'editor'))..createSync(recursive: true);
      expect(svc.buildDirOf(other.path), isNot(dir), reason: 'one alias per host');
    });

    test('a non-zero exit fails with the last 50 log lines and the log path', () async {
      final failing = [...recorded.take(400), 'error MSB8066: Custom build exited with code 1.', 'Build FAILED.'];
      final job = service((args) async => ReplayProcess(failing, code: 1)).start(fx.projectDir.path, [await fx.plugin()]);
      final outcome = await job.result;
      expect(outcome, isA<EditorBuildFailed>());
      final failed = outcome as EditorBuildFailed;
      expect(failed.lastLines, hasLength(EditorBuildService.failureTailLines));
      expect(failed.lastLines.join('\n'), contains('Build FAILED.'));
      expect(failed.message, contains('exited with code 1'));
      expect(failed.logPath, job.logPath);
      expect(File(failed.logPath!).readAsStringSync(), contains('error MSB8066'));
      expect(cache.hashes(), isEmpty);
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('cancel kills the process tree and leaves no cache entry and no .tmp', () async {
      ReplayProcess? proc;
      final killed = <int>[];
      final svc = service((args) async => proc = ReplayProcess(recorded, lineDelay: const Duration(milliseconds: 2), hang: true),
          killTree: (pid) async {
        killed.add(pid);
        proc?.kill();
      });
      final job = svc.start(fx.projectDir.path, [await fx.plugin()]);
      await job.progress.firstWhere((e) => e.phase == EditorBuildPhase.buildingNativeAssets);
      job.cancel();
      final outcome = await job.result;
      expect(outcome, isA<EditorBuildCancelled>());
      expect(killed, [424242]);
      expect(proc!.killed, isTrue);
      expect(cache.hashes(), isEmpty);
      expect(cache.root.listSync().where((e) => e.path.endsWith('.tmp')), isEmpty);
      expect(File(job.logPath!).readAsStringSync(), contains('Build cancelled'));
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('the host stamp and the cache entry are written on a cache hit', () async {
      // Pre-populate the cache under the hash this host resolves to, as a
      // concurrent launcher would: the service then installs nothing.
      final plugin = await fx.plugin();
      var built = false;
      final first = service((args) async {
        built = true;
        return ReplayProcess(recorded);
      });
      // Resolve once to learn the hash (generate + real pub get).
      await first.start(fx.projectDir.path, [plugin]).result;
      final host = EditorHostGeneratorService.hostDirOf(fx.projectDir.path);
      final hash = fingerprintOf(await fingerprintComponents(EditorHostInputs(
        hostDir: host,
        engineRoot: host,
        repos: EditorSourceVendorService.copiedRepos(host),
        pluginDirs: {'a_plugin': fx.pluginDir.path},
        flutterVersion: '3.47.5',
        flutterRevision: '6a19cca564',
        platform: EditorHostInputs.currentPlatform(),
        mode: 'release',
      )));
      final bundle = Directory(p.join(fx.temp.path, 'bundle'))..createSync();
      File(p.join(bundle.path, 'host_game_editor.exe')).writeAsStringSync('exe');
      await cache.install(hash, bundle, stamp: {'executable': 'host_game_editor.exe'});

      built = false;
      final outcome = await service((args) async {
        built = true;
        return ReplayProcess(recorded);
      }).start(fx.projectDir.path, [plugin]).result;
      expect(outcome, isA<EditorBuildSucceeded>());
      expect(built, isFalse, reason: 'no flutter build on a hit');
      final stamp = jsonDecode(File(p.join(host, EditorHostGeneratorService.stampFileName)).readAsStringSync()) as Map;
      expect(stamp['hash'], hash);
      expect((stamp['inputs'] as Map).keys, containsAll(['host.pubspec', 'host.lock', 'flutter', 'mode', 'plugin:a_plugin', 'engine:lumina_ui']));
      for (final k in ['engineRevision', 'flutterVersion', 'platform', 'mode', 'builtAt']) {
        expect(stamp.containsKey(k), isTrue, reason: k);
      }
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}
