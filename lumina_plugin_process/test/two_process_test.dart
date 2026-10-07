import 'dart:convert';
import 'dart:io';

import 'package:lumina_plugin_process/lumina_plugin_process.dart';
import 'package:lumina_plugin_process/testing.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// A pure-Dart plugin process (`example/pure_process.dart`) started with
/// `dart run` as a real child process talks to a [LoopbackHost] in this one
/// over a real loopback socket: no Flutter on either side.
void main() {
  late LoopbackHost host;
  Process? child;
  final output = StringBuffer();

  setUp(() => output.clear());

  tearDown(() async {
    child?.kill();
    await host.close();
  });

  test('a pure-Dart plugin process in another dart process registers, answers and shuts down with exit code 0',
      () async {
    host = await LoopbackHost.start(settings: const {'density': 3});
    final launch = host.launch('pure_sample');
    final dart = _dartExecutable();
    child = await Process.start(
      dart,
      ['run', p.join('example', 'pure_process.dart'), ...launch.toArgs()],
      workingDirectory: _packageRoot().path,
      runInShell: Platform.isWindows && dart == 'dart',
    );
    final process = child!;
    process.stdout.transform(utf8.decoder).listen(output.write);
    process.stderr.transform(utf8.decoder).listen(output.write);

    // The handshake comes from the child, and its contributions arrive.
    final contributions = await host.contributions.timeout(const Duration(minutes: 2),
        onTimeout: () => fail('no contributions from the child process; its output:\n$output'));
    expect(host.helloArgs!['plugin'], 'pure_sample');
    // `dart run` may run the script in a process of its own below the one
    // started here: the hello's pid is the plugin's, never this test's.
    final childPid = host.helloArgs!['pid'];
    expect(childPid, isA<int>());
    expect(childPid, isNot(pid), reason: 'the hello comes from another process');
    expect(contributions.menuItems.single.path, 'Tools/Pure Sample/Greet');
    expect(contributions.slotButtons.single.state.tooltip, 'Idle');
    expect(contributions.mcpTools.single.name, 'square');

    // Ping and core.call.
    expect(await host.call(PluginMethods.ping), <String, Object?>{});
    final greeting = await host.call(PluginMethods.call, {
      'method': 'greet',
      'args': {'name': 'Lumina'},
    }) as Map;
    expect(greeting['greeting'], 'Hello, Lumina');
    expect(greeting['pid'], childPid);
    expect((await host.next(PluginMethods.event))['data'], {'count': 1});
    // The slot button's ObservableValue sends its new state.
    expect(((await host.next(PluginMethods.slotState))['state'] as Map)['tooltip'], 'Greeted 1');

    // The test host's link is what a UI shell calls.
    expect(host.link.state.value.status, PluginProcessStatus.running);
    expect(await host.link.call('settings'), {'density': 3});
    host.connection.notify(PluginMethods.settings, {
      'settings': {'density': 5},
    });
    expect(await host.link.call('settings'), {'density': 5});

    // Level edits go through the editor side, as one undo step.
    final placed = await host.link.call('placeCrates', {'count': 2}) as Map;
    expect(placed['names'], ['Crate0', 'Crate1']);
    expect([for (final a in host.level.actors) a.name], ['Crate0', 'Crate1']);
    expect(host.level.undo.map((s) => s.$1), ['Place crates']);

    // An MCP tool and a menu command run in the child.
    final square = await host.call(PluginMethods.mcpTool, {
      'tool': 'pure_sample.square',
      'arguments': {'n': 7},
    }) as Map;
    expect(McpToolResult.fromJson(square.cast()).structuredContent, {'n': 49});
    await host.call(PluginMethods.command, {'commandId': 'pure_sample.greet'});
    expect((await host.next(PluginMethods.log))['message'], 'greet from the menu');

    // Shutdown: the child exits on its own with 0.
    await host.call(PluginMethods.shutdown);
    final code = await process.exitCode.timeout(const Duration(seconds: 30),
        onTimeout: () => fail('the child process did not exit after core.shutdown; its output:\n$output'));
    expect(code, PluginProcessExitCodes.ok, reason: '$output');
    expect(host.link.state.value.status, PluginProcessStatus.crashed, reason: 'the link closed with the process');
  }, timeout: const Timeout(Duration(minutes: 3)));
}

/// The `dart` running this test (`dart test`), else `dart` from the PATH.
String _dartExecutable() {
  final exe = Platform.resolvedExecutable;
  return p.basenameWithoutExtension(exe) == 'dart' ? exe : 'dart';
}

/// The `lumina_plugin_process` package directory (`dart test` runs from it).
Directory _packageRoot() {
  final dir = Directory.current;
  final pubspec = File(p.join(dir.path, 'pubspec.yaml'));
  if (!pubspec.existsSync() || !pubspec.readAsStringSync().contains('name: lumina_plugin_process')) {
    throw StateError('run `dart test` from the lumina_plugin_process package directory (cwd: ${dir.path})');
  }
  return dir;
}
