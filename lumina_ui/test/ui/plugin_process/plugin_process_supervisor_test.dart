import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:lumina_ui/ui/core/services/crash_report.dart';
import 'package:lumina_ui/ui/core/services/plugin_process/plugin_process_supervisor.dart';

import 'plugin_process_harness.dart';

void main() {
  late PluginProcessHarness h;

  tearDown(() => h.dispose());

  ProcessBackedCommand menuCommand() =>
      h.registry.allMenuCommands.firstWhere((e) => e.key == kFakeMenuPath).value as ProcessBackedCommand;

  Future<McpToolResult> callTool(String name, Map<String, Object?> args) => h.mcpTools.call(
        name,
        args,
        context: (tool) => McpCallContext(
          sessionId: 'test',
          clientName: 'test',
          transport: McpTransport.inProcess,
          tool: tool.name,
          risk: tool.riskOf(args),
          groups: tool.groups,
          arguments: args,
          caller: 'test',
        ),
      );

  test('contributions, commands, tools and declarative panels of a real child process', () async {
    h = await PluginProcessHarness.create();
    h.mode = 'normal';
    final s = h.supervisor;
    expect(identical(h.registry.processChannel(kFakePluginName), s), isTrue);
    await s.start();
    await waitForStatus(s, PluginProcessStatus.running);
    expect(s.state.value.pid, isNotNull);

    expect(h.registry.allMenuCommands.map((e) => e.key), contains(kFakeMenuPath));
    expect(h.registry.allPanels.map((p) => p.id), contains(kFakePanelId));
    expect(h.registry.allConsoleCommands.keys, contains('fake_echo'));
    expect(h.registry.slotButtons(EditorSlot.statusBarRight).map((b) => b.effectiveId), contains('$kFakePluginName.fake_slot'));
    expect(h.mcpTools.byName('$kFakePluginName.echo'), isNotNull);

    final cmd = menuCommand();
    expect(cmd.canExecute(), isTrue);
    expect(cmd.unavailableReason, isNull);
    await cmd.execute(null);
    await waitFor(() => h.commandMarker.existsSync(), reason: 'the command marker');
    // Ran in the child, not in this (the editor's) process.
    expect(s.reportedPid, isNot(pid));
    expect(h.commandMarker.readAsStringSync(), '$kFakeCommandId ran in pid ${s.reportedPid}');

    final result = await callTool('$kFakePluginName.echo', {'text': 'hi'});
    expect(result.isError, isFalse);
    expect(jsonDecode(result.content.first['text'] as String), {'text': 'hi'});

    h.registry.allConsoleCommands['fake_echo']!.handler(['a', 'b']);
    await waitFor(() => s.logTail.any((l) => l.contains('console a b')), reason: 'the console log line');

    final view = s.viewOf(kFakeViewId)!;
    expect(view.value.find('count')!['value'], 'not pressed');
    final events = s.events('hello').first;
    final progress = s.progress.first;
    expect(await s.call('echo', {'x': 1}), {'x': 1});
    await s.call('emit', {'n': 2});
    expect((await events).data, {'n': 2});
    expect((await progress).fraction, 0.5);
  });

  test('a declarative panel event is answered with a patch of its view', () async {
    h = await PluginProcessHarness.create();
    h.mode = 'normal';
    final s = h.supervisor;
    await s.start();
    await waitForStatus(s, PluginProcessStatus.running);
    final panel = h.registry.allPanels.firstWhere((p) => p.id == kFakePanelId);
    expect(panel.title, 'Fake Panel');
    expect(panel.defaultDock, PanelDefaultDock.right);
    final view = s.viewOf(kFakeViewId)!;
    await s.sendViewEvent(const PluginViewEvent(viewId: kFakeViewId, controlId: 'press', kind: 'pressed'));
    await waitFor(() => view.value.find('count')!['value'] == 'pressed 1', reason: 'the patched view');
  });

  test('channel calls time out, and fail as unavailable while the process is not running', () async {
    h = await PluginProcessHarness.create();
    h.mode = 'normal';
    final s = h.supervisor;
    await expectLater(s.call('echo'), throwsA(isA<PluginRemoteError>().having((e) => e.code, 'code', PluginErrorCodes.unavailable)));
    await s.start();
    await waitForStatus(s, PluginProcessStatus.running);
    await expectLater(
      s.call('slow', const {}, const Duration(milliseconds: 300)),
      throwsA(isA<PluginRemoteError>().having((e) => e.code, 'code', PluginErrorCodes.timeout)),
    );
    // Still running: one slow call is not a hang.
    expect(s.state.value.status, PluginProcessStatus.running);
    await s.stop();
    expect(s.state.value.status, PluginProcessStatus.stopped);
    await expectLater(s.call('echo'), throwsA(isA<PluginRemoteError>().having((e) => e.code, 'code', PluginErrorCodes.unavailable)));
    // A stopped plugin's tool answers an error result, not an exception.
    final r = await callTool('$kFakePluginName.echo', {'text': 'x'});
    expect(r.isError, isTrue);
    expect(r.content.first['text'], contains('$kFakePluginName stopped'));
  });

  test('a hung process is detected after three missed pings, killed and restarted', () async {
    h = await PluginProcessHarness.create();
    h.mode = 'hang';
    final s = h.supervisor;
    final seen = <PluginProcessStatus>[];
    s.state.addListener(() => seen.add(s.state.value.status));
    await s.start();
    await waitFor(() => seen.contains(PluginProcessStatus.running), reason: 'the first registration');
    final firstPid = s.state.value.pid;
    await waitForStatus(s, PluginProcessStatus.hung);
    expect(s.state.value.reason, 'not responding');
    // While hung its contributions are kept but unavailable.
    expect(h.registry.allMenuCommands.map((e) => e.key), contains(kFakeMenuPath));
    expect(menuCommand().canExecute(), isFalse);
    expect(menuCommand().unavailableReason, '$kFakePluginName stopped: not responding');
    final slot = h.registry.slotButtons(EditorSlot.statusBarRight).first.button.state.value;
    expect(slot.enabled, isFalse);
    expect(slot.tooltip, '$kFakePluginName stopped: not responding');
    expect(s.logTail.any((l) => l.contains('missed health check 3 of 3')), isTrue);

    h.mode = 'normal';
    await waitFor(() => s.state.value.status == PluginProcessStatus.running && s.state.value.pid != firstPid,
        reason: 'the restart');
    expect(s.state.value.restarts, 1);
    expect(menuCommand().canExecute(), isTrue);
    // Re-registration replaced the contributions: no duplicates.
    expect(h.registry.allMenuCommands.where((e) => e.key == kFakeMenuPath), hasLength(1));
    expect(h.registry.allPanels.where((p) => p.id == kFakePanelId), hasLength(1));
    expect(h.mcpTools.tools.where((t) => t.name == '$kFakePluginName.echo'), hasLength(1));
    // A hang is not a crash report.
    expect(h.crashReporter.filed, isEmpty);
  });

  test('a process exiting with code 3 is crashed: a plugin crash report with the exit code and log tail, editor marker untouched', () async {
    h = await PluginProcessHarness.create();
    await h.crashReporter.startSession();
    final marker = h.crashReporter.sessionMarker;
    final markerBefore = marker.readAsStringSync();
    h.mode = 'normal';
    final s = h.supervisor;
    await s.start();
    await waitForStatus(s, PluginProcessStatus.running);
    final pid = s.state.value.pid;
    final childPid = s.reportedPid;
    await s.call('exit', {'code': 3}).catchError((_) => null);
    await waitForStatus(s, PluginProcessStatus.crashed);
    expect(s.state.value.exitCode, 3);
    expect(s.state.value.reason, startsWith('exited with code 3'));
    expect(s.lastExitCode, 3);

    await h.crashReporter.flush();
    final report = h.crashReporter.filed.single;
    expect(report.kind, CrashReportKind.pluginCrash);
    expect(report.plugin, kFakePluginName);
    expect(report.exitCode, 3);
    expect(report.logTail.join('\n'), contains('fake plugin $kFakePluginName starting in mode normal (pid $childPid)'));
    expect(h.crashReporter.pending.value?.id, report.id);
    final stored = await h.crashReporter.stored();
    expect(stored.single.kind, CrashReportKind.pluginCrash);
    expect(stored.single.exitCode, 3);
    expect(marker.existsSync(), isTrue);
    expect(marker.readAsStringSync(), markerBefore);

    // It comes back on its own.
    await waitFor(() => s.state.value.status == PluginProcessStatus.running && s.state.value.pid != pid, reason: 'the restart');
  });

  test('a native crash in the process is a crashed plugin, not an editor crash', () async {
    h = await PluginProcessHarness.create();
    h.mode = 'normal';
    final s = h.supervisor;
    await s.start();
    await waitForStatus(s, PluginProcessStatus.running);
    await s.call('crash').catchError((_) => null);
    await waitForStatus(s, PluginProcessStatus.crashed);
    expect(s.state.value.exitCode, isNot(0));
    await h.crashReporter.flush();
    expect(h.crashReporter.filed.single.logTail.join('\n'), contains('null pointer'));
  });

  test('three failed restarts stop the plugin; a manual restart starts the count again', () async {
    h = await PluginProcessHarness.create();
    h.mode = 'exit3';
    final s = h.supervisor;
    await s.start();
    await waitForStatus(s, PluginProcessStatus.stopped, timeout: const Duration(seconds: 60));
    expect(s.startCount, 4);
    expect(s.state.value.restarts, 3);
    expect(s.state.value.exitCode, 3);
    expect(s.state.value.reason, contains('gave up after 3 restarts'));
    expect(h.crashReporter.filed, hasLength(4));
    expect(h.crashReporter.filed.every((r) => r.exitCode == 3), isTrue);

    h.mode = 'normal';
    await s.restart();
    await waitForStatus(s, PluginProcessStatus.running);
    expect(s.state.value.restarts, 0);
    expect(s.startCount, 5);
    expect(h.registry.allMenuCommands.map((e) => e.key), contains(kFakeMenuPath));
  });

  test('a manual restart of a running process shuts it down cleanly and starts a new one', () async {
    h = await PluginProcessHarness.create();
    h.mode = 'normal';
    final s = h.supervisor;
    await s.start();
    await waitForStatus(s, PluginProcessStatus.running);
    final pid = s.state.value.pid;
    await s.restart();
    await waitFor(() => s.state.value.status == PluginProcessStatus.running && s.state.value.pid != pid, reason: 'the new process');
    expect(s.lastExitCode, 0);
    expect(h.crashReporter.filed, isEmpty);
  });

  test('the in-process override runs the same protocol inside the editor, status in process', () async {
    h = await PluginProcessHarness.create(inEditor: true);
    h.mode = 'normal';
    final s = h.supervisor;
    expect(s.runsInEditorProcess, isTrue);
    await s.start();
    await waitForStatus(s, PluginProcessStatus.inProcess);
    expect(s.state.value.isAvailable, isTrue);
    expect(s.state.value.pid, isNull);
    await menuCommand().execute(null);
    await waitFor(() => h.commandMarker.existsSync(), reason: 'the command marker');
    expect(h.commandMarker.readAsStringSync(), '$kFakeCommandId ran in pid $pid');
    expect(await s.call('echo', {'a': true}), {'a': true});

    // Back to its own process: same channel object, a child pid.
    await h.manager.setRunInEditorProcess(kFakePluginName, false);
    await waitForStatus(s, PluginProcessStatus.running);
    expect(s.state.value.pid, isNot(pid));
    expect(identical(h.registry.processChannel(kFakePluginName), s), isTrue);
  });

  test('a hello with a wrong token is refused', () async {
    h = await PluginProcessHarness.create();
    h.mode = 'normal';
    final s = h.supervisor;
    await s.start();
    await waitForStatus(s, PluginProcessStatus.running);
    // A second connection with a forged token: refused, the plugin unaffected.
    final port = s.port!;
    final socket = await Socket.connect(InternetAddress.loopbackIPv4, port);
    final conn = PluginConnection(input: socket, output: socket);
    await expectLater(
      conn.request(PluginMethods.hello, {'v': kPluginProtocolVersion, 'plugin': kFakePluginName, 'token': 'forged', 'pid': 1}),
      throwsA(isA<PluginRemoteError>()),
    );
    await conn.close();
    expect(s.state.value.status, PluginProcessStatus.running);
  });
}
