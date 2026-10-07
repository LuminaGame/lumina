import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_jobs.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_server_service.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_server_settings.dart';

import '../helpers/mcp_test_client.dart';
import '../helpers/temp_project.dart';

/// The job registry and its four tools (list_jobs, get_job,
/// wait_job, cancel_job) through a real MCP client over HTTP against a real
/// editor on a temp project.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late EditorViewModel vm;
  late McpServerService server;
  late McpTestClient client;

  setUp(() async {
    root = Directory.systemTemp.createTempSync('lumina_mcp_jobs_');
    final configDir = Directory('${root.path}/config')..createSync();
    final projectDir = Directory('${root.path}/JobsProject')..createSync();
    const project = LuminaProject(projectName: 'JobsProject', activeLevel: 'contents/levels/L_Main.lmas');
    File('${projectDir.path}/JobsProject.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
    vm = EditorViewModel(initialProject: project, projectLocation: root.path, enableTimers: false, autoInitAssets: false);
    server = McpServerService(vm, configDir: configDir, settings: McpServerSettings.load(configDir: configDir));
    expect(await server.start(port: 0), isTrue);
    client = McpTestClient(server.url!, server.token);
    await client.handshake();
  });

  tearDown(() async {
    client.close();
    await server.stop();
    await vm.close();
    await deleteTempProject(root);
  });

  Future<Map<String, Object?>> ok(String tool, [Map<String, Object?> args = const {}]) async {
    final r = await client.callTool(tool, args);
    expect(r.isError, isFalse, reason: '$tool: ${r.text}');
    return r.data;
  }

  test('a job that completes after 200 ms: get_job shows running, then succeeded with its result', () async {
    final job = server.jobs.start('test', title: 'Two hundred ms', run: (job) async {
      job.addLog('working');
      await Future<void>.delayed(const Duration(milliseconds: 200));
      return {'answer': 42};
    });
    expect(job.id, 'job_1');
    final running = await ok('get_job', {'id': job.id});
    expect(running['state'], 'running');
    expect(running['result'], isNull);
    await Future<void>.delayed(const Duration(milliseconds: 350));
    final done = await ok('get_job', {'id': job.id});
    expect(done['state'], 'succeeded');
    expect(done['result'], {'answer': 42});
    expect(done['finished'], isNotNull);
    expect((await ok('list_jobs', {'state': 'succeeded'}))['jobs'], hasLength(1));
    expect((await ok('list_jobs', {'state': 'running'}))['jobs'], isEmpty);
  });

  test('wait_job: a short timeout says timed_out; a long one returns right after completion; over 25 s is -32602', () async {
    final gate = Completer<void>();
    final job = server.jobs.start('test', run: (job) async {
      await gate.future;
      return 'done';
    });
    final short = await ok('wait_job', {'id': job.id, 'timeout_ms': 50});
    expect(short['timed_out'], isTrue);
    expect(short['state'], 'running');

    final sw = Stopwatch()..start();
    final waiting = client.callTool('wait_job', {'id': job.id, 'timeout_ms': 25000});
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final completedAt = sw.elapsedMilliseconds;
    gate.complete();
    final waited = (await waiting).data;
    expect(waited['timed_out'], isFalse);
    expect(waited['state'], 'succeeded');
    expect(waited['result'], 'done');
    expect(sw.elapsedMilliseconds - completedAt, lessThan(300), reason: 'wait_job returns as soon as the job ends');

    await expectLater(
      client.callTool('wait_job', {'id': job.id, 'timeout_ms': 60000}),
      throwsA(isA<McpRpcError>().having((e) => e.code, 'code', -32602).having((e) => e.message, 'message', contains('25000'))),
    );
  });

  test('a second exclusive build_pipeline job is refused naming job_1', () async {
    final gate = Completer<void>();
    final first = server.jobs.start('build_all', exclusive: 'build_pipeline', run: (_) => gate.future);
    expect(first.id, 'job_1');
    expect(
      () => server.jobs.start('cook_and_package', exclusive: 'build_pipeline', run: (_) async => null),
      throwsA(isA<McpJobConflict>().having((e) => e.message, 'message', contains('job_1'))),
    );
    // Another resource is free.
    final other = server.jobs.start('standalone', exclusive: 'standalone', run: (_) async => null);
    expect(other.id, 'job_2');
    gate.complete();
    await first.settled;
    // Once it finished, the key is free again.
    final again = server.jobs.start('cook_and_package', exclusive: 'build_pipeline', run: (_) async => null);
    await again.settled;
    expect(again.state, McpJobState.succeeded);
  });

  test('cancel_job runs the cancel callback once and the job is cancelled', () async {
    var cancels = 0;
    final stop = Completer<void>();
    final job = server.jobs.start('test', cancel: () {
      cancels++;
      if (!stop.isCompleted) stop.complete();
    }, run: (_) => stop.future);
    final cancelled = await ok('cancel_job', {'id': job.id});
    expect(cancelled['state'], 'cancelled');
    expect(cancels, 1);
    final again = await client.callTool('cancel_job', {'id': job.id});
    expect(again.isError, isTrue);
    expect(again.text, contains('already cancelled'));
    expect(cancels, 1, reason: 'the cancel callback runs once');
    expect((await ok('get_job', {'id': job.id}))['state'], 'cancelled');
  });

  test('get_job pages the log with since_log_index and tail; an unknown id is -32602', () async {
    final job = server.jobs.start('test', run: (job) async {
      for (var i = 0; i < 6; i++) {
        job.addLog('line $i', level: i == 5 ? 'warning' : 'info', source: 'Test');
      }
      return null;
    });
    await job.settled;
    final page = await ok('get_job', {'id': job.id, 'since_log_index': 3});
    final lines = (page['log'] as List).cast<Map>();
    expect(lines.map((l) => l['index']), [3, 4, 5]);
    expect(lines.last, {'index': 5, 'level': 'warning', 'source': 'Test', 'message': 'line 5'});
    expect(page['next_log_index'], 6);
    final tail = await ok('get_job', {'id': job.id, 'tail': 2});
    expect((tail['log'] as List).map((l) => (l as Map)['index']), [4, 5]);
    await expectLater(
      client.callTool('get_job', {'id': job.id, 'tail': 2001}),
      throwsA(isA<McpRpcError>().having((e) => e.code, 'code', -32602)),
    );
    await expectLater(
      client.callTool('get_job', {'id': 'job_99'}),
      throwsA(isA<McpRpcError>().having((e) => e.message, 'message', contains('job_1'))),
    );
  });

  test('a job whose run throws ends failed with the error', () async {
    final job = server.jobs.start('test', run: (_) async => throw const McpJobFailure('flutter pub get failed', result: {'exit_code': 1}));
    await job.settled;
    final failed = await ok('get_job', {'id': job.id});
    expect(failed['state'], 'failed');
    expect(failed['error'], 'flutter pub get failed');
    expect(failed['result'], {'exit_code': 1});
  });

  test('the 51st job evicts the first', () async {
    for (var i = 0; i < 51; i++) {
      server.jobs.start('test', run: (_) async => i);
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final ids = ((await ok('list_jobs'))['jobs'] as List).map((j) => (j as Map)['id']).toList();
    expect(ids, hasLength(50));
    expect(ids.first, 'job_2');
    expect(ids.last, 'job_51');
    expect(server.jobs.byId('job_1'), isNull);
  });

  test('the job tools are core: a session listing only the level group still lists them', () async {
    final tools = {for (final t in await client.listTools(groups: ['level'])) t['name']};
    expect(tools, containsAll(['list_jobs', 'get_job', 'wait_job', 'cancel_job']));
  });
}
