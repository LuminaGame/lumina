import 'dart:io';

import 'package:lumina_plugin_process/lumina_plugin_process.dart';
import 'package:lumina_plugin_process/testing.dart';
import 'package:test/test.dart';

import 'support/sample_process.dart';

void main() {
  late LoopbackHost host;
  late SampleProcess process;
  late Future<int> exit;

  setUp(() async {
    host = await LoopbackHost.start();
    process = SampleProcess();
    exit = runPluginProcessMain(host.launch('sample'), process);
    await host.contributions;
  });

  tearDown(() async {
    if (!host.connection.isClosed) {
      await host.call(PluginMethods.shutdown);
      expect(await exit, PluginProcessExitCodes.ok);
    }
    await host.close();
  });

  Future<Object?> call(String method, [Map<String, Object?> args = const {}]) =>
      host.call(PluginMethods.call, {'method': method, 'args': args});

  test('a handler updates a declarative view outside its events through context.view', () async {
    expect(await call('setCount', {'n': 5}), {'found': true, 'unknown': true});
    final update = await host.next(PluginMethods.view, where: (a) => a['viewId'] == 'sample.view' && a['patch'] != null);
    final patch = PluginViewPatch.fromJson((update['patch'] as Map).cast());
    expect(patch.ops.single.controlId, 'count');
    expect(patch.ops.single.set['value'], '5');
  });

  test('a UI shell reaches the process through the test host link', () async {
    final link = host.link;
    expect(link.state.value.status, PluginProcessStatus.running);
    expect(await link.call('echo', {'x': 1}), {'echo': {'x': 1}});
    final event = link.events('hello').first;
    final progress = link.progress.first;
    await link.call('notify', {'n': 7});
    expect((await event).data, {'n': 7});
    final p = await progress;
    expect((p.task, p.step, p.fraction), ('job', 'half', 0.5));
  });

  test('core.call reaches the handler; an unknown method answers unknown_method', () async {
    expect(await call('echo', {'a': 1}), {'echo': {'a': 1}});
    await expectLater(
      call('nope'),
      throwsA(isA<PluginRemoteError>().having((e) => e.code, 'code', PluginErrorCodes.unknownMethod)),
    );
  });

  test('a throwing handler answers an error, is logged and the loop goes on', () async {
    await expectLater(
      call('boom'),
      throwsA(isA<PluginRemoteError>()
          .having((e) => e.code, 'code', PluginErrorCodes.handlerFailed)
          .having((e) => e.message, 'message', contains('the handler broke'))),
    );
    final log = await host.next(PluginMethods.log, where: (a) => '${a['message']}'.contains('the handler broke'));
    expect(log['level'], 'error');

    // An uncaught asynchronous error is logged too and kills nothing.
    expect(await call('asyncBoom'), 'started');
    await host.next(PluginMethods.log, where: (a) => '${a['message']}'.contains('broke later'));

    expect(await host.call(PluginMethods.ping), <String, Object?>{});
    expect(await call('echo', {'still': true}), {'echo': {'still': true}});
  });

  test('commands run and answer canExecute', () async {
    expect(await host.call(PluginMethods.canExecute, {'commandId': 'sample.run'}), isTrue);
    process.allowRun = false;
    expect(await host.call(PluginMethods.canExecute, {'commandId': 'sample.run'}), isFalse);
    expect(await host.call(PluginMethods.canExecute, {'commandId': 'sample.status'}), isTrue);

    expect(await host.call(PluginMethods.command, {'commandId': 'sample.run'}), isNull);
    expect(process.runs, 1);
    expect(await host.next(PluginMethods.event, where: (a) => a['name'] == 'ran'), {'name': 'ran', 'data': 1});
    await expectLater(
      host.call(PluginMethods.command, {'commandId': 'missing'}),
      throwsA(isA<PluginRemoteError>().having((e) => e.code, 'code', PluginErrorCodes.badArguments)),
    );
  });

  test('MCP tool calls answer McpToolResult json, by plain or namespaced name', () async {
    final r = await host.call(PluginMethods.mcpTool, {'tool': 'double', 'arguments': {'n': 21}}) as Map;
    expect(McpToolResult.fromJson(r.cast()).structuredContent, {'n': 42});
    final ns = await host.call(PluginMethods.mcpTool, {'tool': 'sample.double', 'arguments': {'n': 1}}) as Map;
    expect(ns['structuredContent'], {'n': 2});

    final failed = await host.call(PluginMethods.mcpTool, {'tool': 'double', 'arguments': {'n': -1}}) as Map;
    expect(failed['isError'], isTrue);
    expect(McpToolResult.fromJson(failed.cast()).content.single['text'], contains('negative'));

    await expectLater(
      host.call(PluginMethods.mcpTool, {'tool': 'double', 'arguments': {'n': 'x'}}),
      throwsA(isA<PluginRemoteError>().having((e) => e.code, 'code', PluginErrorCodes.badArguments)),
    );
  });

  test('imports run in the process and report failures as data', () async {
    final src = File('${host.root.path}/note.txt')..writeAsStringSync('hello');
    final target = Directory('${host.project!.dir}/contents/notes')..createSync(recursive: true);
    final ok = await host.call(PluginMethods.import, {
      'importerId': 'txt',
      'sourcePath': src.path,
      'targetDirectory': target.path,
    }) as Map;
    expect(ok['success'], isTrue);
    expect(File(ok['assetPath'] as String).readAsStringSync(), '{"note":"hello"}');

    final empty = File('${host.root.path}/empty.txt')..writeAsStringSync('');
    final bad = await host.call(PluginMethods.import, {
      'importerId': 'txt',
      'sourcePath': empty.path,
      'targetDirectory': target.path,
    }) as Map;
    expect(bad, {'success': false, 'error': 'the note is empty'});
  });

  test('console commands get their arguments', () async {
    expect(await host.call(PluginMethods.console, {'name': 'sample.say', 'args': ['a', 'b']}), isNull);
    expect(await host.next(PluginMethods.event, where: (a) => a['name'] == 'said'), {
      'name': 'said',
      'data': ['a', 'b'],
    });
  });

  test('a view event reaches the panel and its patch comes back with host.view', () async {
    const event = PluginViewEvent(viewId: 'sample.view', controlId: 'inc', kind: 'pressed');
    expect(await host.call(PluginMethods.viewEvent, event.toJson()), isNull);
    final view = await host.next(PluginMethods.view);
    expect(view['viewId'], 'sample.view');
    final patch = PluginViewPatch.fromJson((view['patch'] as Map).cast());
    expect(patch.ops.single.set, {'value': '1'});
    await host.call(PluginMethods.viewEvent, event.toJson());
    final second = await host.next(PluginMethods.view);
    expect(((second['patch'] as Map)['ops'] as List).single, {'id': 'count', 'set': {'value': '2'}});
  });

  test('slot button states and menu check marks are sent as they change', () async {
    process.slotState.value = const PluginButtonStateSpec(icon: kSampleIcon, tooltip: 'Busy', busy: true, badge: '2');
    final s = await host.next(PluginMethods.slotState);
    expect(s['id'], 'status');
    final state = PluginButtonStateSpec.fromJson((s['state'] as Map).cast());
    expect((state.tooltip, state.busy, state.badge), ('Busy', true, '2'));

    process.checked.value = true;
    expect(await host.next(PluginMethods.menuChecked), {'path': 'Sample/Run', 'checked': true});
  });

  test('settings notifications update pluginSettings', () async {
    expect(await call('settings'), {'density': 3});
    host.connection.notify(PluginMethods.settings, {'settings': {'density': 7, 'mode': 'fast'}});
    await host.call(PluginMethods.ping);
    expect(await call('settings'), {'density': 7, 'mode': 'fast'});
  });

  test('emit, progress and log reach the editor', () async {
    await call('notify', {'n': 5});
    expect(await host.next(PluginMethods.event), {'name': 'hello', 'data': {'n': 5}});
    final p = PluginProgress.fromJson(await host.next(PluginMethods.progress));
    expect((p.task, p.step, p.fraction, p.finished), ('job', 'half', 0.5, false));
    expect(await host.next(PluginMethods.log, where: (a) => a['message'] == 'working'), {
      'level': 'warning',
      'message': 'working',
    });
  });

  test('saveAsset, panels, tabs and editor MCP calls go to the editor', () async {
    final r = await call('editorCalls') as Map;
    expect(File('${host.project!.dir}/contents/gen/a.bin').readAsBytesSync(), [1, 2, 3]);
    expect([for (final (m, a) in host.requests) '$m ${a['op'] ?? a['relativePath'] ?? a['tool']}'], [
      'host.saveAsset contents/gen/a.bin',
      'host.panels show',
      'host.panels hide',
      'host.tabs openTab',
      'host.mcp.call list_actors',
    ]);
    expect(host.requests[3].$2, {'op': 'openTab', 'tabId': 'sample.tab', 'title': 'Sample'});
    expect(McpToolResult.fromJson(r.cast()).structuredContent, {'tool': 'list_actors', 'echo': {'limit': 2}});
  });

  test('project hooks and the project store follow core.projectOpened / core.projectClosing', () async {
    final store = await call('project') as Map;
    expect(store, {'name': 'Proj', 'store': host.projectStoreDir});
    expect(await call('store', {'k': 1}), {'k': 1});
    expect(File('${host.projectStoreDir}/state.json').existsSync(), isTrue);

    await host.call(PluginMethods.projectClosing);
    expect(process.lifecycle.last, 'closing');
    expect(await call('project'), {'name': null, 'store': null});

    final other = Directory('${host.root.path}/Other')..createSync();
    await host.call(PluginMethods.projectOpened, {'name': 'Other', 'dir': other.path});
    expect(process.lifecycle.last, 'opened:Other');
    expect(await call('project'), {'name': 'Other', 'store': '${other.path}/.lumina/plugins/sample'});
  });
}
