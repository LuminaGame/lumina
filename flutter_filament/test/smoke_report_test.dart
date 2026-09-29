// flutter_filament's configuration of the shared smoke report
// (tool/smoke_report.dart): its categories and backends, and real runs of
// the tool. The runner and the report themselves are tested in lumina_smoke.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_filament/testing.dart';
import 'package:lumina_smoke/report.dart';
import 'package:test/test.dart';

import '../tool/smoke_report.dart';

/// The render fixture the nested runs drive (a real render on each backend).
const _fixture = 'test/smoke/fixtures/render_smoke_fixture.dart';

/// Marks every process of one nested tool run: the variable is inherited by
/// the flutter tool and its `flutter_tester`s, so a process that escaped its
/// process group (reparented to `systemd --user`) is still found.
const _runMarkVar = 'FILAMENT_SMOKE_TEST_RUN_MARK';

/// Live processes (pid → command name) whose environment holds
/// `$_runMarkVar=$mark`. Linux only (reads `/proc`); empty elsewhere.
Map<int, String> _markedProcesses(String mark) {
  final found = <int, String>{};
  if (!Platform.isLinux) return found;
  final entry = '$_runMarkVar=$mark';
  for (final e in Directory('/proc').listSync(followLinks: false)) {
    final id = int.tryParse(e.path.substring(e.path.lastIndexOf('/') + 1));
    if (id == null || id == pid) continue;
    try {
      final environ = latin1.decode(File('/proc/$id/environ').readAsBytesSync());
      if (!environ.split('\x00').contains(entry)) continue;
      found[id] = File('/proc/$id/comm').readAsStringSync().trim();
    } catch (_) {
      // Gone meanwhile, or not ours to read.
    }
  }
  return found;
}

/// Sends [signal] (`TERM`, `KILL`, `0`) to the process group [group].
bool _signalGroup(int group, String signal) => Process.runSync('kill', ['-$signal', '--', '-$group']).exitCode == 0;

/// SIGTERM to [group] (the tool then terminates its own child groups), up to
/// [grace] for it to go, then SIGKILL.
Future<void> _terminateGroup(int group, {Duration grace = const Duration(seconds: 10)}) async {
  if (!_signalGroup(group, 'TERM')) return;
  final end = DateTime.now().add(grace);
  while (DateTime.now().isBefore(end) && _signalGroup(group, '0')) {
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
  _signalGroup(group, 'KILL');
}

void main() {
  group('filamentTestCategories', () {
    String cat(String path, [String name = 'x']) => filamentSmokeConfig.categoryOf(path, name);

    test('maps test files to their module', () {
      expect(cat('/r/test/smoke/camera_smoke_test.dart'), 'camera');
      expect(cat('/r/test/src/manipulator_raycast_test.dart'), 'camutils');
      expect(cat('/r/test/src/material_instance_params_test.dart'), 'material_instance');
      expect(cat('/r/test/src/material_test.dart'), 'material');
      expect(cat('/r/test/src/gltf_material_leak_test.dart'), 'gltfio');
      expect(cat('/r/test/src/iblprefilter_test.dart'), 'iblprefilter');
      expect(cat('/r/test/src/ibl_sh_test.dart'), 'ibl');
      expect(cat('/r/test/smoke/indirect_light_smoke_test.dart'), 'indirect_light');
      expect(cat('/r/test/src/texture_sampler_test.dart'), 'texture_sampler');
      expect(cat('/r/test/texture_set_image_test.dart'), 'texture');
      expect(cat('/r/test/src/color_transform_test.dart'), 'image');
      expect(cat('/r/test/src/ktx2_reader_test.dart'), 'ktxreader');
      expect(cat('/r/test/smoke/skinning_buffer_smoke_test.dart'), 'skinning_buffer');
      expect(cat('/r/test/smoke/morph_target_buffer_smoke_test.dart'), 'morph_target_buffer');
      expect(cat('/r/test/smoke/instance_buffer_smoke_test.dart'), 'instance_buffer');
      expect(cat('/r/test/src/frame_pacer_test.dart'), 'frame_pacing');
      expect(cat('/r/test/src/view_options_test.dart'), 'view');
      expect(cat('/r/test/src/transform_test.dart'), 'transform_manager');
      expect(cat('/r/test/smoke/filamat_smoke_test.dart'), 'filamat');
      expect(cat('/r/test/smoke/fixtures/render_smoke_fixture.dart'), 'renderer');
      expect(cat('/r/test/web/canvas_smoke_test.dart'), 'web');
      expect(cat('/r/test/math/viewport_norm_decompose_test.dart'), 'dart_math');
      expect(cat(r'C:\r\test\math\viewport_norm_decompose_test.dart'), 'dart_math', reason: 'Windows paths');
      expect(cat('/r/test/smoke_report_test.dart'), '00_test_report');
      expect(cat('unknown', 'Engine Smoke Tests engine: renders on the chosen GPU'), 'engine');
      expect(cat('opengl/web_api__gltf_barrel.png', 'web api: gltf barrel through the Dart API'), 'web');
      expect(cat('unknown', 'test1'), 'Other');
      expect(filamentSmokeConfig.categoryOrder('Other'), greaterThan(filamentSmokeConfig.categoryOrder('web')));
      expect(filamentSmokeConfig.categoryOrder('engine'), lessThan(filamentSmokeConfig.categoryOrder('camera')));
    });
  });

  group('what a run runs', () {
    List<String> plan(List<String> args) => [
          for (final p in planSmokeRuns(smokeRunMode(args), filamentSmokeConfig))
            '${p.kind.name}@${p.backend!.name}: ${p.targets.join(' ')}',
        ];

    test('a targeted smoke file runs on both backends, whatever the path separator, and merges', () {
      for (final target in ['test/smoke/engine_smoke_test.dart', r'test\smoke\engine_smoke_test.dart']) {
        expect(plan([target, '--no-dashboard']), ['smoke@opengl: $target', 'smoke@vulkan: $target'], reason: target);
      }
      expect(smokeRunMode(['test/smoke/engine_smoke_test.dart']).merge, isTrue);
    });

    test('a targeted unit file runs on OpenGL only, and --plain-name is a filter, not a target', () {
      expect(plan(['test/src/engine_test.dart', '--plain-name', 'creates an engine']), ['unit@opengl: test/src/engine_test.dart']);
      expect(smokeRunMode(['test/src/engine_test.dart', '--plain-name', 'creates an engine']).filters,
          ['--plain-name', 'creates an engine']);
    });

    test('no targets: the smoke folder on both backends from a clean build/; --all adds test/ on OpenGL', () {
      expect(smokeRunMode(const []).wipe, isTrue);
      expect(plan(const []), ['smoke@opengl: test/smoke', 'smoke@vulkan: test/smoke']);
      final all = plan(['--all']);
      expect(all.first, startsWith('unit@opengl: '));
      expect(all.first.substring(all.first.indexOf(':') + 2).split(' '), isNot(contains('test/smoke')));
      expect(all.skip(1), ['smoke@opengl: test/smoke', 'smoke@vulkan: test/smoke']);
      expect(plan(['--unit-only']).map((p) => p.split(':').first), ['unit@opengl', 'smoke@opengl']);
    });
  });

  group('the tool', () {
    late Directory tempDir;
    late Directory artifacts;
    final groups = <int>[];
    final marks = <String>[];
    var runs = 0;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('filament_smoke_report_test_');
      artifacts = Directory('${tempDir.path}/smoke_artifacts')..createSync();
    });

    tearDown(() {
      // Nothing a nested run started may outlive the test, even after a
      // timeout: kill its group, then anything still carrying its mark.
      for (final group in groups) {
        _signalGroup(group, 'KILL');
      }
      for (final mark in marks) {
        for (final id in _markedProcesses(mark).keys) {
          Process.killPid(id, ProcessSignal.sigkill);
        }
      }
      groups.clear();
      marks.clear();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    /// Runs the tool (on Linux as the leader of its own process group), with
    /// every process of the run marked by [_runMarkVar]. The group is
    /// terminated when [deadline] passes or [killWhen] completes.
    Future<({int exitCode, String stdout, String stderr, String mark})> runTool(
      List<String> args, {
      Duration deadline = const Duration(minutes: 6),
      Future<void> Function(String mark)? killWhen,
    }) async {
      final mark = '$pid-${DateTime.now().microsecondsSinceEpoch}-${runs++}';
      marks.add(mark);
      // The script directly (not `dart run`): `dart run` would wait on the
      // build-hooks lock while this test itself runs under the tool.
      final command = ['dart', File('tool/smoke_report.dart').absolute.path, ...args];
      final environment = {
        'LUMINA_SMOKE_OUT': artifacts.path,
        'LUMINA_SMOKE_REPORT_OUT': '${tempDir.path}/smoke_report.html',
        'LUMINA_SMOKE_EVENTS_OUT': '${tempDir.path}/events.jsonl',
        _runMarkVar: mark,
      };
      final process = Platform.isLinux
          ? await Process.start('setsid', command, environment: environment)
          : await Process.start(command.first, command.sublist(1), environment: environment, runInShell: Platform.isWindows);
      if (Platform.isLinux) groups.add(process.pid);
      final out = process.stdout.transform(utf8.decoder).join();
      final err = process.stderr.transform(utf8.decoder).join();
      var killed = false;
      Future<void> kill() async {
        if (killed) return;
        killed = true;
        if (Platform.isLinux) {
          await _terminateGroup(process.pid);
        } else {
          process.kill();
        }
      }

      final timer = Timer(deadline, kill);
      unawaited(killWhen?.call(mark).then((_) => kill()));
      final code = await process.exitCode;
      timer.cancel();
      const drain = Duration(seconds: 10);
      return (
        exitCode: code,
        stdout: await out.timeout(drain, onTimeout: () => ''),
        stderr: await err.timeout(drain, onTimeout: () => ''),
        mark: mark,
      );
    }

    test('--report-only renders the events file with the package title and categories', () async {
      File('${tempDir.path}/events.jsonl').writeAsStringSync([
        {'suite': {'id': 0, 'path': '${Directory.current.path}/test/smoke/camera_smoke_test.dart'}, 'type': 'suite', 'time': 0},
        {'test': {'id': 1, 'name': 'camera: dolly in', 'suiteID': 0}, 'type': 'testStart', 'time': 0},
        {'testID': 1, 'result': 'success', 'type': 'testDone', 'time': 1},
      ].map(jsonEncode).join('\n'));
      final res = await runTool(['--report-only']);
      expect(res.exitCode, 0, reason: '${res.stdout}\n${res.stderr}');
      expect(File('${tempDir.path}/smoke_report.html').readAsStringSync(), contains('Filament Engine Test Report'));
      expect(File('${tempDir.path}/smoke_report/camera.html').existsSync(), isTrue);
    });

    test('a targeted run of a real render on both backends merges into the existing report', () async {
      final keepDir = Directory('${artifacts.path}/opengl')..createSync(recursive: true);
      final kept = SmokeArtifacts.saveScreenshotToDir('old unit test', SmokeArtifacts.encodePng(2, 2, Uint8List(16)), keepDir);
      final cwd = Directory.current.path;
      Map<String, dynamic> tag(Map<String, dynamic> e, int run, String target) =>
          {...e, 'run': run, 'target': target, 'backend': 'opengl'};
      final previous = [
        // The fixture's own earlier, failing result: replaced.
        tag({'suite': {'id': 0, 'path': '$cwd/$_fixture'}, 'type': 'suite', 'time': 0}, 0, _fixture),
        tag({'test': {'id': 1, 'name': 'stale render smoke test', 'suiteID': 0}, 'type': 'testStart', 'time': 0}, 0, _fixture),
        tag({'testID': 1, 'result': 'failure', 'type': 'testDone', 'time': 1}, 0, _fixture),
        // Another file: kept.
        tag({'suite': {'id': 0, 'path': '$cwd/test/smoke_report_test.dart'}, 'type': 'suite', 'time': 0}, 1, 'test/smoke_report_test.dart'),
        tag({'test': {'id': 1, 'name': 'old unit test', 'suiteID': 0}, 'type': 'testStart', 'time': 0}, 1, 'test/smoke_report_test.dart'),
        tag({'testID': 1, 'result': 'success', 'type': 'testDone', 'time': 1}, 1, 'test/smoke_report_test.dart'),
      ];
      File('${tempDir.path}/events.jsonl').writeAsStringSync(previous.map(jsonEncode).join('\n'));

      final res = await runTool([_fixture, '--no-dashboard']);
      expect(_markedProcesses(res.mark), isEmpty, reason: 'no flutter_tester (or anything else) of the nested run survives it');
      expect(res.exitCode, 0, reason: 'the fixture renders; the stale failure was replaced\n${res.stdout}\n${res.stderr}');
      expect(kept.existsSync(), isTrue, reason: 'a targeted run keeps build/smoke_artifacts');
      final page = File('${tempDir.path}/smoke_report/renderer.html').readAsStringSync();
      expect(page, contains('render smoke: suzanne frame to PNG'));
      expect(page, contains('src="../smoke_artifacts/opengl/render_smoke_suzanne_frame_to_png.png"'));
      expect(page, contains('src="../smoke_artifacts/vulkan/render_smoke_suzanne_frame_to_png.png"'));
      expect(page, contains('<span class="backend-tag vulkan">vulkan</span>'), reason: 'the fixture runs on both backends');
      expect(page, isNot(contains('stale render smoke test')));
      expect(File('${tempDir.path}/smoke_report/00_test_report.html').readAsStringSync(), contains('old unit test'),
          reason: 'results of other files are kept');
    }, timeout: const Timeout(Duration(minutes: 8)));

    test('a nested run terminated mid-test leaves no flutter_tester behind', () async {
      // A test that never finishes: the run only ends by being terminated,
      // as on a deadline or a test timeout.
      final hang = File('${tempDir.path}/hang_test.dart')
        ..writeAsStringSync('''
import 'dart:async';
import 'package:test/test.dart';
void main() => test('hangs', () => Completer<void>().future, timeout: Timeout.none);
''');
      var sawTester = false;
      final res = await runTool([hang.path, '--no-dashboard'], killWhen: (mark) async {
        final end = DateTime.now().add(const Duration(minutes: 3));
        while (DateTime.now().isBefore(end)) {
          if (_markedProcesses(mark).containsValue('flutter_tester')) {
            sawTester = true;
            return;
          }
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
      });
      expect(sawTester, isTrue, reason: 'the nested run reached its flutter_tester before it was terminated');
      // No assertion on res.exitCode: it is the `dart` launcher's, which
      // reports a signal exit inconsistently.
      expect(_markedProcesses(res.mark), isEmpty,
          reason: 'the tool terminated its flutter test group: no flutter_tester was reparented to systemd');
    }, testOn: 'linux', timeout: const Timeout(Duration(minutes: 5)));
  });
}
