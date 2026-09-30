import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_server_service.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_server_settings.dart';

/// The stdio bridge (`bin/lumina_mcp_bridge.dart`) spawned
/// as a client would spawn it, with `LUMINA_CONFIG_DIR` pointing at a temp
/// directory: it must find the running server through `mcp_server.json`,
/// forward requests, and explain itself when no editor is running.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final bridge = File('${Directory.current.path}/bin/lumina_mcp_bridge.dart');
  // The SDK's `dart`, as a client launches the bridge. Under `flutter test`
  // `Platform.resolvedExecutable` is `flutter_tester`, which prints its VM
  // service banner on stdout ahead of the bridge's first response line.
  final dart = () {
    final exe = Platform.resolvedExecutable.replaceAll(r'\', '/');
    final cache = exe.indexOf('/bin/cache/');
    if (cache >= 0) {
      final sdkDart = '${exe.substring(0, cache)}/bin/cache/dart-sdk/bin/dart${Platform.isWindows ? '.exe' : ''}';
      if (File(sdkDart).existsSync()) return sdkDart;
    }
    return 'dart';
  }();

  late Directory root;
  late Directory configDir;

  setUp(() {
    root = Directory.systemTemp.createTempSync('lumina_mcp_bridge_test_');
    configDir = Directory('${root.path}/config')..createSync();
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  /// One request through the bridge; returns the decoded response line.
  Future<Map<String, Object?>> ask(Process process, StreamQueueLite lines, Map<String, Object?> message) async {
    process.stdin.writeln(jsonEncode(message));
    final line = await lines.next.timeout(const Duration(seconds: 20));
    return Map<String, Object?>.from(jsonDecode(line) as Map);
  }

  Future<(Process, StreamQueueLite)> spawn({List<String> args = const []}) async {
    final process = await Process.start(
      dart,
      [bridge.path, ...args],
      environment: {...Platform.environment, 'LUMINA_CONFIG_DIR': configDir.path},
    );
    process.stderr.transform(utf8.decoder).listen(stderr.write);
    final lines = StreamQueueLite(process.stdout.transform(utf8.decoder).transform(const LineSplitter()));
    addTearDown(() {
      process.kill();
    });
    return (process, lines);
  }

  test('the bridge script exists and imports only dart: libraries', () {
    expect(bridge.existsSync(), isTrue, reason: bridge.path);
    final imports = RegExp(r"^import '([^']+)';", multiLine: true)
        .allMatches(bridge.readAsStringSync())
        .map((m) => m.group(1)!)
        .toList();
    expect(imports, isNotEmpty);
    expect(imports.every((i) => i.startsWith('dart:')), isTrue, reason: '$imports');
  });

  test('forwards initialize and tools/list to the running server', () async {
    final projectDir = Directory('${root.path}/BridgeProject')..createSync();
    const project = LuminaProject(projectName: 'BridgeProject', activeLevel: 'contents/levels/L_Main.lmas');
    File('${projectDir.path}/BridgeProject.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
    final vm = EditorViewModel(initialProject: project, projectLocation: root.path, enableTimers: false, autoInitAssets: false);
    addTearDown(vm.dispose);
    final server = McpServerService(vm, configDir: configDir, settings: McpServerSettings.load(configDir: configDir));
    expect(await server.start(port: 0), isTrue);
    addTearDown(server.stop);

    final (process, lines) = await spawn();
    final init = await ask(process, lines, {
      'jsonrpc': '2.0',
      'id': 1,
      'method': 'initialize',
      'params': {
        'protocolVersion': '2025-06-18',
        'capabilities': {},
        'clientInfo': {'name': 'bridge-test', 'version': '0'},
      },
    });
    expect(init['id'], 1);
    final result = init['result'] as Map;
    expect((result['serverInfo'] as Map)['name'], 'lumina-studio');

    // A notification gets no line back; the next request still answers.
    process.stdin.writeln(jsonEncode({'jsonrpc': '2.0', 'method': 'notifications/initialized'}));
    final list = await ask(process, lines, {'jsonrpc': '2.0', 'id': 2, 'method': 'tools/list'});
    expect(list['id'], 2);
    final names = ((list['result'] as Map)['tools'] as List).map((t) => (t as Map)['name']).toList();
    expect(names, contains('spawn_actor'));

    // The bridge carried the session id: the server saw one session.
    expect(server.sessionCount, 1);

    final call = await ask(process, lines, {
      'jsonrpc': '2.0',
      'id': 3,
      'method': 'tools/call',
      'params': {
        'name': 'spawn_actor',
        'arguments': {'type': 'PointLight'},
      },
    });
    expect((call['result'] as Map)['isError'], isFalse);
    expect(vm.actors.any((a) => a.type == 'PointLight'), isTrue);
  });

  // `--groups level` connects to /mcp?groups=level.
  test('started with --groups level, the bridge lists the 27 level and 9 core tools', () async {
    final projectDir = Directory('${root.path}/GroupsProject')..createSync();
    const project = LuminaProject(projectName: 'GroupsProject', activeLevel: 'contents/levels/L_Main.lmas');
    File('${projectDir.path}/GroupsProject.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
    final vm = EditorViewModel(initialProject: project, projectLocation: root.path, enableTimers: false, autoInitAssets: false);
    addTearDown(vm.dispose);
    final server = McpServerService(vm, configDir: configDir, settings: McpServerSettings.load(configDir: configDir));
    expect(await server.start(port: 0), isTrue);
    addTearDown(server.stop);

    final (process, lines) = await spawn(args: ['--groups', 'level']);
    await ask(process, lines, {
      'jsonrpc': '2.0',
      'id': 1,
      'method': 'initialize',
      'params': {'protocolVersion': '2025-06-18', 'capabilities': {}, 'clientInfo': {'name': 'bridge-groups', 'version': '0'}},
    });
    final list = await ask(process, lines, {'jsonrpc': '2.0', 'id': 2, 'method': 'tools/list'});
    expect(((list['result'] as Map)['tools'] as List), hasLength(36));
    expect(server.sessionList.single.groups, {'level'});
  });

  test('with no editor running, a request is answered with -32000 naming the connection file', () async {
    final (process, lines) = await spawn();
    final reply = await ask(process, lines, {'jsonrpc': '2.0', 'id': 1, 'method': 'initialize', 'params': {}});
    final error = reply['error'] as Map;
    expect(error['code'], -32000);
    expect(error['message'], contains('mcp_server.json'));
    expect(reply['id'], 1);
  });
}

/// The next line of a stream, one at a time (no `package:async` dependency).
class StreamQueueLite {
  StreamQueueLite(Stream<String> stream) {
    _sub = stream.listen((line) {
      if (_waiting.isNotEmpty) {
        _waiting.removeAt(0).complete(line);
      } else {
        _buffered.add(line);
      }
    }, onDone: () {
      for (final w in _waiting) {
        w.completeError(StateError('bridge exited'));
      }
      _waiting.clear();
    });
  }

  late final StreamSubscription<String> _sub;
  final List<String> _buffered = [];
  final List<Completer<String>> _waiting = [];

  Future<String> get next {
    if (_buffered.isNotEmpty) return Future.value(_buffered.removeAt(0));
    final c = Completer<String>();
    _waiting.add(c);
    return c.future;
  }

  Future<void> cancel() => _sub.cancel();
}
