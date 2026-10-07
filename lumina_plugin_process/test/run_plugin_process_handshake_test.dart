import 'dart:io';

import 'package:lumina_plugin_process/lumina_plugin_process.dart';
import 'package:lumina_plugin_process/testing.dart';
import 'package:test/test.dart';

import 'support/sample_process.dart';

void main() {
  late LoopbackHost host;

  tearDown(() => host.close());

  test('hello carries version, token and pid; contributions arrive; ping answers', () async {
    host = await LoopbackHost.start();
    final process = SampleProcess();
    final exit = runPluginProcessMain(host.launch('sample'), process);

    final contributions = await host.contributions;
    expect(host.helloArgs, {'v': kPluginProtocolVersion, 'plugin': 'sample', 'token': 'token-1', 'pid': pid});
    expect(contributions.menus.single.title, 'Sample');
    final item = contributions.menuItems.single;
    expect(item.path, 'Sample/Run');
    expect(item.order, 2);
    expect(item.checked, false);
    expect(item.command.id, 'sample.run');
    expect(item.command.icon, kSampleIcon);
    expect(item.command.dynamicEnablement, isTrue);
    expect(contributions.slotButtons.single.slot, 'statusBarRight');
    expect(contributions.slotButtons.single.state.tooltip, 'Idle');
    expect(contributions.slotButtons.single.command.dynamicEnablement, isFalse);
    expect(contributions.mcpTools.single.name, 'double');
    expect(contributions.mcpTools.single.risk, 'readOnly');
    expect(contributions.importers.single.extensions, ['txt']);
    expect(contributions.consoleCommands.single.name, 'sample.say');
    expect(contributions.panels.single.view.find('count')!['value'], '0');

    expect(await host.call(PluginMethods.ping), <String, Object?>{});

    // The project was open at launch: onProjectOpened ran after register.
    expect(await host.next(PluginMethods.event, where: (a) => a['name'] == 'opened'), {'name': 'opened', 'data': 'Proj'});
    expect(process.lifecycle, ['register', 'opened:Proj']);

    expect(await host.call(PluginMethods.shutdown), isNull);
    expect(await exit, PluginProcessExitCodes.ok);
    expect(process.lifecycle.last, 'shutdown');
  });

  test('the hello hands the process its plugin folder', () async {
    host = await LoopbackHost.start(pluginDir: r'C:\plugins\sample');
    final exit = runPluginProcessMain(host.launch('sample'), SampleProcess());
    await host.contributions;
    expect(await host.call(PluginMethods.call, {'method': 'pluginDir'}), r'C:\plugins\sample');
    await host.call(PluginMethods.shutdown);
    expect(await exit, PluginProcessExitCodes.ok);
  });

  test('a wrong token is refused and the process exits non-zero', () async {
    host = await LoopbackHost.start();
    final code = await runPluginProcessMain(host.launch('sample', token: 'forged'), SampleProcess());
    expect(code, PluginProcessExitCodes.refused);
    expect(host.helloArgs!['token'], 'forged');
  });

  test('an editor speaking another protocol version is refused', () async {
    host = await LoopbackHost.start(answerVersion: kPluginProtocolVersion + 1);
    final process = SampleProcess();
    final code = await runPluginProcessMain(host.launch('sample'), process);
    expect(code, PluginProcessExitCodes.refused);
    expect(process.lifecycle, isEmpty);
  });

  test('an unreachable editor port exits with connectFailed', () async {
    host = await LoopbackHost.start();
    final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = probe.port;
    await probe.close();
    final code = await runPluginProcessMain(
      PluginProcessLaunch(pluginName: 'sample', port: port, token: 'token-1'),
      SampleProcess(),
    );
    expect(code, PluginProcessExitCodes.connectFailed);
  });

  test('the editor dropping the connection ends the process with a non-zero code', () async {
    host = await LoopbackHost.start();
    final exit = runPluginProcessMain(host.launch('sample'), SampleProcess());
    await host.contributions;
    await host.call(PluginMethods.ping);
    await host.connection.close();
    final code = await exit;
    expect(code, PluginProcessExitCodes.connectionLost);
    expect(code, isNot(0));
  });

  test('without an open project no project hook runs and the project store is empty', () async {
    host = await LoopbackHost.start(withProject: false);
    final process = SampleProcess();
    final exit = runPluginProcessMain(host.launch('sample'), process);
    await host.contributions;
    expect(await host.call(PluginMethods.call, {'method': 'project'}), {'name': null, 'store': null});
    expect(process.lifecycle, ['register']);
    await host.call(PluginMethods.shutdown);
    expect(await exit, 0);
  });

  test('a shutdown answered before the register reply is a clean exit', () async {
    host = await LoopbackHost.start();
    host.beforeRegisterReply = () async {
      await host.call(PluginMethods.shutdown);
    };
    final code = await runPluginProcessMain(host.launch('sample'), SampleProcess());
    expect(code, PluginProcessExitCodes.ok);
  });

  test("the plugin's own crash reports reach the editor log while the process runs, and the handler goes with it", () async {
    host = await LoopbackHost.start();
    expect(LuminaPluginCrashReporter.hasHandler, isFalse);
    final exit = runPluginProcessMain(host.launch('sample'), SampleProcess());
    await host.contributions;
    expect(LuminaPluginCrashReporter.hasHandler, isTrue);
    await host.call(PluginMethods.call, {'method': 'reportCrash'});
    final log = await host.next(PluginMethods.log, where: (a) => '${a['message']}'.contains('native call failed'));
    expect(log['level'], 'error');
    expect(log['source'], 'sample');
    expect(log['message'], contains('while loading the model'));
    await host.call(PluginMethods.shutdown);
    expect(await exit, PluginProcessExitCodes.ok);
    expect(LuminaPluginCrashReporter.hasHandler, isFalse);
  });

  test('a register() that throws is logged and exits with registerFailed', () async {
    host = await LoopbackHost.start();
    final exit = runPluginProcessMain(host.launch('sample'), _BrokenProcess());
    final log = await host.next(PluginMethods.log);
    expect(log['level'], 'error');
    expect(log['message'], contains('the plugin could not start'));
    expect(await exit, PluginProcessExitCodes.registerFailed);
  });
}

class _BrokenProcess extends LuminaPluginProcess {
  @override
  String get pluginName => 'sample';

  @override
  void register(PluginProcessContext context) => throw StateError('the plugin could not start');
}
