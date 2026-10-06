// A plugin process written by hand against the wire protocol, for the
// supervisor tests: pure Dart (dart:io, dart:ffi and the protocol package),
// so it runs as a real child process with `dart fake_plugin_process.dart` and,
// for the in-process override, inside the test.
import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:lumina_plugin_protocol/lumina_plugin_protocol.dart';

const String kFakePluginName = 'fake_plugin';
const String kFakeMenuPath = 'Plugins/Fake/Do Thing';
const String kFakeCommandId = 'fake.do';
const String kFakePanelId = 'fake_panel';
const String kFakeViewId = 'fake_view';

/// `LucideIcons.plug`.
const PluginIconSpec kFakeIcon = PluginIconSpec(58242, fontFamily: 'LucideIcons', fontPackage: 'shadcn_flutter');

/// What the fake plugin registers.
const PluginContributions kFakeContributions = PluginContributions(
  menuItems: [
    PluginMenuItemSpec(path: kFakeMenuPath, command: PluginCommandSpec(id: kFakeCommandId, label: 'Do Thing', icon: kFakeIcon)),
    PluginMenuItemSpec(path: 'Plugins/Fake/Fake Settings', command: PluginCommandSpec(id: 'fake.settings', label: 'Fake Settings')),
    PluginMenuItemSpec(path: 'Plugins/Fake/Fake Preview', command: PluginCommandSpec(id: 'fake.preview', label: 'Fake Preview'), checked: false),
  ],
  slotButtons: [
    PluginSlotButtonSpec(
      id: 'fake_slot',
      slot: 'statusBarRight',
      state: PluginButtonStateSpec(icon: kFakeIcon, tooltip: 'Fake plugin', label: 'Fake'),
      command: PluginCommandSpec(id: 'fake.slot', label: 'Fake slot'),
    ),
  ],
  mcpTools: [
    PluginMcpToolSpec(
      name: 'echo',
      title: 'Echo',
      description: 'Answers with its arguments.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'text': {'type': 'string'},
        },
      },
      risk: 'readOnly',
    ),
  ],
  consoleCommands: [PluginConsoleCommandSpec(name: 'fake_echo', help: 'Logs its arguments from the plugin process')],
  panels: [
    PluginViewPanelSpec(
      id: kFakePanelId,
      title: 'Fake Panel',
      icon: kFakeIcon,
      dock: 'right',
      view: PluginViewSpec(id: kFakeViewId, children: [
        PluginControl(kind: PluginControlKind.text, id: 'count', props: {'value': 'not pressed', 'style': 'body'}),
        PluginControl(kind: PluginControlKind.button, id: 'press', props: {'text': 'Press', 'tone': 'primary', 'enabled': true}),
      ]),
    ),
  ],
);

/// The start mode, read from [controlPath] (a file the test writes): `normal`,
/// `hang` (blocks its isolate right after registering), `exit3` (exits with
/// code 3 before registering).
String fakeModeOf(String controlPath) {
  final f = File(controlPath);
  return f.existsSync() ? f.readAsStringSync().trim() : 'normal';
}

/// Runs the fake plugin against the editor named by [launch]. Writes
/// `<controlPath>.cmd` when its menu command runs. In a child process it
/// exits the process; with [inEditor] it completes with the exit code
/// instead (the in-process override).
Future<int> runFakePlugin(PluginProcessLaunch launch, {required String controlPath, bool inEditor = false}) async {
  final mode = fakeModeOf(controlPath);
  final done = Completer<int>();
  Future<void> finish(int code) async {
    if (inEditor) {
      if (!done.isCompleted) done.complete(code);
      return;
    }
    await stdout.flush();
    await stderr.flush();
    exit(code);
  }

  stdout.writeln('fake plugin ${launch.pluginName} starting in mode $mode (pid $pid)');
  final socket = await Socket.connect(InternetAddress.loopbackIPv4, launch.port);
  final conn = PluginConnection(input: socket, output: socket);
  var presses = 0;
  // The editor's hello answer, returned by the `launch` call.
  Object? helloAnswer;
  conn
    ..onRequest(PluginMethods.ping, (_) => const <String, Object?>{})
    ..onRequest(PluginMethods.call, (args) async {
      final inner = (args['args'] as Map?)?.cast<String, Object?>() ?? const {};
      switch (args['method']) {
        case 'echo':
          return inner;
        case 'launch':
          return {'projectDir': launch.projectDir, 'hello': helloAnswer};
        case 'slow':
          return Completer<Object?>().future;
        case 'exit':
          final code = inner['code'] as int? ?? 1;
          stderr.writeln('fake plugin exiting with code $code');
          unawaited(finish(code));
          return null;
        case 'crash':
          stderr.writeln('fake plugin writes through a null pointer');
          await stderr.flush();
          Pointer<Int64>.fromAddress(8).value = 1;
          return null;
        case 'emit':
          conn.notify(PluginMethods.event, {'name': 'hello', 'data': inner});
          conn.notify(PluginMethods.progress, {'task': 't', 'step': 'half', 'done': 1, 'total': 2, 'finished': false});
          return null;
        case 'level':
          final tx = await conn.request(PluginMethods.level, {'op': 'beginTransaction', 'label': 'Fake scatter'}) as Map;
          final ids = <Object?>[];
          for (final name in ['Fake A', 'Fake B']) {
            final r = await conn.request(PluginMethods.level, {
              'op': 'addActors',
              'actors': [
                {'name': name, 'type': 'Empty', 'location': [0, 0, 0]},
              ],
            });
            ids.addAll(r as List);
          }
          await conn.request(PluginMethods.level, {'op': 'endTransaction', 'tx': tx['tx']});
          return ids;
      }
      throw PluginRemoteError(code: PluginErrorCodes.unknownMethod, message: 'no handler for ${args['method']}');
    })
    ..onRequest(PluginMethods.command, (args) async {
      await File('$controlPath.cmd').writeAsString('${args['commandId']} ran in pid $pid');
      conn.notify(PluginMethods.log, {'level': 'info', 'message': 'ran ${args['commandId']}'});
      return null;
    })
    ..onRequest(PluginMethods.canExecute, (_) => true)
    ..onRequest(PluginMethods.mcpTool, (args) => {
          'content': [
            {'type': 'text', 'text': jsonEncode(args['arguments'])},
          ],
          'isError': false,
        })
    ..onRequest(PluginMethods.console, (args) {
      conn.notify(PluginMethods.log, {'level': 'info', 'message': 'console ${(args['args'] as List).join(' ')}'});
      return null;
    })
    ..onRequest(PluginMethods.viewEvent, (args) {
      presses++;
      conn.notify(PluginMethods.view, {
        'viewId': args['viewId'],
        'patch': {
          'ops': [
            {
              'id': 'count',
              'set': {'value': 'pressed $presses'},
            },
          ],
        },
      });
      return null;
    })
    ..onRequest(PluginMethods.projectOpened, (_) => null)
    ..onRequest(PluginMethods.projectClosing, (_) => null)
    ..onRequest(PluginMethods.shutdown, (_) {
      Timer(const Duration(milliseconds: 50), () => finish(0));
      return null;
    });
  unawaited(conn.done.then((_) => finish(inEditor ? 0 : 2)));

  helloAnswer = await conn.request(PluginMethods.hello, {'v': kPluginProtocolVersion, 'plugin': launch.pluginName, 'token': launch.token, 'pid': pid});
  if (mode == 'exit3') {
    stderr.writeln('fake plugin exiting with code 3 before registering');
    await finish(3);
    return done.future;
  }
  await conn.request(PluginMethods.register, kFakeContributions.toJson());
  conn.notify(PluginMethods.log, {'level': 'info', 'message': 'fake plugin registered'});
  if (mode == 'hang') {
    stdout.writeln('fake plugin hangs now');
    await stdout.flush();
    sleep(const Duration(days: 1));
  }
  return done.future;
}
