import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_server_service.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_server_settings.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/host_editor_mcp.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart' show McpTool, McpSchema, McpToolResult, McpToolRisk, McpToolGroups;

import '../helpers/mcp_test_client.dart';
import '../helpers/temp_project.dart';

/// A real MCP client (JSON-RPC 2.0 over Streamable HTTP, a
/// plain `HttpClient`) against the editor's MCP server on a real
/// `EditorViewModel` over a real temp project. Every server starts on an
/// ephemeral port under a temp config directory, so nothing here can touch
/// a running editor's port or `~/.config/lumina`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late Directory configDir;
  late EditorViewModel vm;
  late McpServerService server;
  late McpTestClient client;

  const levelPath = 'contents/levels/L_Main.lmas';

  setUp(() async {
    root = Directory.systemTemp.createTempSync('lumina_mcp_test_');
    configDir = Directory('${root.path}/config')..createSync();
    final projectDir = Directory('${root.path}/McpProject')..createSync();
    const project = LuminaProject(projectName: 'McpProject', activeLevel: levelPath);
    File('${projectDir.path}/McpProject.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
    Directory('${projectDir.path}/contents/levels').createSync(recursive: true);
    vm = EditorViewModel(
      initialProject: project,
      projectLocation: root.path,
      enableTimers: false,
      autoInitAssets: false,
    );
    server = McpServerService(vm, configDir: configDir, settings: McpServerSettings.load(configDir: configDir));
    expect(await server.start(port: 0), isTrue);
    client = McpTestClient(server.url!, server.token);
  });

  tearDown(() async {
    client.close();
    await server.stop();
    // Wait for the source-control probe, then delete with a retry.
    await vm.close();
    await deleteTempProject(root);
  });

  group('handshake and transport', () {
    test('initialize negotiates the protocol, names the server and issues a session', () async {
      final reply = await client.post({
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'initialize',
        'params': {
          'protocolVersion': '2025-06-18',
          'capabilities': {},
          'clientInfo': {'name': 'test', 'version': '0'},
        },
      });
      expect(reply.status, HttpStatus.ok);
      expect(reply.headers.value('mcp-session-id'), isNotNull);
      expect(reply.headers.contentType?.mimeType, 'application/json');
      final result = (reply.json as Map)['result'] as Map;
      expect(result['protocolVersion'], '2025-06-18');
      expect((result['serverInfo'] as Map)['name'], 'lumina-studio');
      expect((result['capabilities'] as Map).containsKey('tools'), isTrue);
      expect((result['capabilities'] as Map).containsKey('resources'), isTrue);

      final initialized = await client.post({'jsonrpc': '2.0', 'method': 'notifications/initialized'});
      expect(initialized.status, HttpStatus.accepted);

      // The newest revision is echoed back; an unknown one gets the default.
      final other = McpTestClient(server.url!, server.token);
      addTearDown(other.close);
      expect((await other.handshake(protocolVersion: '2025-11-25'))['protocolVersion'], '2025-11-25');
      final odd = McpTestClient(server.url!, server.token);
      addTearDown(odd.close);
      expect((await odd.handshake(protocolVersion: '1999-01-01'))['protocolVersion'], '2025-06-18');
    });

    test('a missing or wrong token is refused, GET without a session is 400, another path is 404', () async {
      final noAuth = await client.post({'jsonrpc': '2.0', 'id': 1, 'method': 'ping'}, omitAuthorization: true);
      expect(noAuth.status, HttpStatus.unauthorized);
      expect(noAuth.headers.value(HttpHeaders.wwwAuthenticateHeader), contains('Bearer'));

      final wrong = await client.post({'jsonrpc': '2.0', 'id': 1, 'method': 'ping'}, bearer: 'not-the-token');
      expect(wrong.status, HttpStatus.unauthorized);

      final get = await client.post('', method: 'GET');
      expect(get.status, HttpStatus.badRequest, reason: 'GET opens the notification stream of a session');

      final elsewhere = await client.post({'jsonrpc': '2.0', 'id': 1, 'method': 'ping'}, path: '/other');
      expect(elsewhere.status, HttpStatus.notFound);
    });

    // GET /mcp is a session's server-to-client SSE stream; a
    // plugin tool added or removed pushes notifications/tools/list_changed.
    test('GET /mcp streams tools/list_changed to a session; DELETE closes the stream', () async {
      final init = await client.handshake();
      expect(((init['capabilities'] as Map)['tools'] as Map)['listChanged'], isTrue);

      final http = realHttpClient();
      addTearDown(() => http.close(force: true));
      final request = await http.getUrl(Uri.parse(server.url!));
      request.headers
        ..set(HttpHeaders.authorizationHeader, 'Bearer ${server.token}')
        ..set(HttpHeaders.acceptHeader, 'text/event-stream')
        ..set('Mcp-Session-Id', client.sessionId!);
      final response = await request.close();
      expect(response.statusCode, HttpStatus.ok);
      expect(response.headers.contentType?.mimeType, 'text/event-stream');
      final received = StringBuffer();
      final listChanged = Completer<void>();
      final closed = Completer<void>();
      response.transform(utf8.decoder).listen((chunk) {
        received.write(chunk);
        if (received.toString().contains('notifications/tools/list_changed') && !listChanged.isCompleted) listChanged.complete();
      }, onDone: () => closed.complete());

      HostEditorMcp(server.tools).scoped('probe').registerTool(McpTool(
        name: 'ping_tool',
        description: 'A probe tool.',
        inputSchema: McpSchema.object({}),
        handler: (_) => McpToolResult.text('pong'),
        risk: McpToolRisk.readOnly,
        groups: {McpToolGroups.core},
      ));
      await listChanged.future.timeout(const Duration(seconds: 2), onTimeout: () => fail('no list_changed; the stream had: $received'));
      expect(received.toString(), contains('data: {"jsonrpc":"2.0","method":"notifications/tools/list_changed"}'));

      final delete = await client.post('', method: 'DELETE');
      expect(delete.status, HttpStatus.ok);
      await closed.future.timeout(const Duration(seconds: 2), onTimeout: () => fail('DELETE did not close the stream'));
    });

    test('malformed input is a JSON-RPC error, not a transport failure', () async {
      await client.handshake();
      final parse = await client.post('{not json');
      expect(parse.status, HttpStatus.ok);
      expect(((parse.json as Map)['error'] as Map)['code'], -32700);

      final unknown = await client.post({'jsonrpc': '2.0', 'id': 7, 'method': 'nope/nothing'});
      expect(((unknown.json as Map)['error'] as Map)['code'], -32601);
      expect((unknown.json as Map)['id'], 7);

      final noTool = await client.post({
        'jsonrpc': '2.0',
        'id': 8,
        'method': 'tools/call',
        'params': {'name': 'no_such_tool', 'arguments': {}},
      });
      final error = (noTool.json as Map)['error'] as Map;
      expect(error['code'], -32602);
      expect(error['message'], contains('no_such_tool'));

      // Once a session was issued, a request without it is 400 and an unknown one 404.
      final missing = await client.post({'jsonrpc': '2.0', 'id': 9, 'method': 'ping'}, omitSession: true);
      expect(missing.status, HttpStatus.badRequest);
      final stale = McpTestClient(server.url!, server.token)..sessionId = 'deadbeefdeadbeefdeadbeefdeadbeef';
      addTearDown(stale.close);
      expect((await stale.post({'jsonrpc': '2.0', 'id': 10, 'method': 'ping'})).status, HttpStatus.notFound);
    });

    test('tools/list names every level tool with a description and an object schema', () async {
      await client.handshake();
      final tools = await client.listTools();
      final names = tools.map((t) => t['name']).toSet();
      expect(
        names,
        containsAll(<String>[
          'project_info',
          'list_actors',
          'get_actor',
          'list_actor_types',
          'spawn_actor',
          'spawn_actor_from_asset',
          'set_actor_transform',
          'set_actor_property',
          'rename_actor',
          'delete_actor',
          'duplicate_actor',
          'select_actors',
          'clear_selection',
          'save_level',
          'undo',
          'redo',
          'undo_state',
        ]),
      );
      for (final tool in tools) {
        expect((tool['description'] as String).trim(), isNotEmpty, reason: '${tool['name']} has no description');
        final schema = tool['inputSchema'] as Map;
        expect(schema['type'], 'object', reason: '${tool['name']} schema');
        expect(schema['properties'], isA<Map>(), reason: '${tool['name']} schema');
      }

      final info = (await client.callTool('project_info')).data;
      expect(info['world_units'], 'cm');
      expect(info['up_axis'], 'z');
      expect(info['project_name'], 'McpProject');
    });

    test('resources list the project manifest and the output log', () async {
      await client.handshake();
      final list = await client.request('resources/list');
      final uris = (list['resources'] as List).map((r) => (r as Map)['uri']).toList();
      expect(uris, containsAll(<String>['lumina://project', 'lumina://output-log']));

      final project = await client.request('resources/read', {'uri': 'lumina://project'});
      final text = ((project['contents'] as List).first as Map)['text'] as String;
      expect((jsonDecode(text) as Map)['project_name'], 'McpProject');

      await client.callTool('spawn_actor', {'type': 'PointLight'});
      final log = await client.request('resources/read', {'uri': 'lumina://output-log'});
      expect(((log['contents'] as List).first as Map)['text'], contains('Spawned new actor'));
    });

    test('the connection file is written 0600 on start and removed on stop', () async {
      final file = File('${configDir.path}/mcp_server.json');
      expect(file.existsSync(), isTrue);
      final info = jsonDecode(file.readAsStringSync()) as Map;
      expect(info['port'], server.port);
      expect(info['token'], server.token);
      expect(info['projectDir'], vm.projectDirPath);
      expect(info['url'], server.url);
      if (!Platform.isWindows) {
        expect(file.statSync().mode & 0x1FF, 0x180, reason: 'mode must be 600');
      }

      await client.handshake();
      final url = server.url!;
      await server.stop();
      expect(file.existsSync(), isFalse);
      final after = McpTestClient(url, client.token);
      addTearDown(after.close);
      await expectLater(after.post({'jsonrpc': '2.0', 'id': 1, 'method': 'ping'}), throwsA(isA<SocketException>()));
    });

    // The editor disposes its service with the view model; the old
    // dispose() started an async stop() that called notifyListeners() after
    // super.dispose() ("McpServerService used after being disposed"), and a
    // start() still binding when the editor closed did the same.
    test('disposing a running service, or one still starting, never touches the disposed notifier', () async {
      // A notification after dispose throws (ChangeNotifier's debug check)
      // from an async tail; an uncaught async error fails this test.
      final file = File('${configDir.path}/mcp_server.json');
      final running = McpServerService(vm, configDir: configDir, settings: McpServerSettings.load(configDir: configDir));
      expect(await running.start(port: 0), isTrue);
      running.dispose();
      expect(running.isRunning, isFalse);
      expect(file.existsSync(), isFalse, reason: 'dispose removes the connection file at once');

      final starting = McpServerService(vm, configDir: configDir, settings: McpServerSettings.load(configDir: configDir));
      final bound = starting.start(port: 0);
      starting.dispose();
      expect(await bound, isFalse, reason: 'a start that finishes after dispose does not listen');
      expect(starting.isRunning, isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
  });

  group('level tools change the real level and are undoable', () {
    setUp(() => client.handshake());

    test('spawn_actor places a light at the given location as one undo step', () async {
      final before = vm.actors.length;
      final reply = await client.callTool('spawn_actor', {
        'type': 'PointLight',
        'location': [100, 200, 50],
      });
      expect(reply.isError, isFalse, reason: reply.text);
      expect(vm.actors.length, before + 1);
      final actor = vm.actors.last;
      expect(actor.type, 'PointLight');
      expect(actor.location, [100.0, 200.0, 50.0]);
      expect(vm.transactions.canUndo, isTrue);
      expect(vm.transactions.undoLabel, 'Undo MCP: Spawn ${actor.name}');
      expect((reply.data['actor'] as Map)['id'], actor.id);

      final undone = await client.callTool('undo');
      expect(undone.data['undone'], 'Undo MCP: Spawn ${actor.name}');
      expect(vm.actors.length, before);

      await client.callTool('redo');
      expect(vm.actors.length, before + 1);
      expect(vm.actors.last.location, [100.0, 200.0, 50.0]);
    });

    test('set_actor_transform writes location, rotation and scale as one undo step',() async {
      await client.callTool('spawn_actor', {'type': 'Primitive'});
      final actor = vm.actors.last;
      final reply = await client.callTool('set_actor_transform', {
        'id': actor.id,
        'location': [10, 20, 30],
        'rotation': [0, 0, 90],
        'scale': [2, 2, 2],
      });
      expect(reply.isError, isFalse, reason: reply.text);
      expect(actor.location, [10.0, 20.0, 30.0]);
      expect(actor.rotation, [0.0, 0.0, 90.0]);
      expect(actor.scale, [2.0, 2.0, 2.0]);

      final undone = await client.callTool('undo');
      expect(undone.isError, isFalse, reason: undone.text);
      expect(actor.location, [0.0, 0.0, 0.0]);
      expect(actor.rotation, [0.0, 0.0, 0.0]);
      expect(actor.scale, [1.0, 1.0, 1.0]);
      // One more undo removes the spawn itself.
      await client.callTool('undo');
      expect(vm.actors.any((a) => a.id == actor.id), isFalse);
    });

    test('spawn_actor_from_asset places an imported barrel and save_level writes it to disk', () async {
      final glb = File('${Directory.current.parent.path}/test-assets/Props/Barrels/fuel_barrel_red.glb');
      if (!glb.existsSync()) {
        markTestSkipped('test-assets not present');
        return;
      }
      await vm.ensureDefaultLevelAssets();
      await vm.processImportPipeline(sourceFilePath: glb.path);
      final mesh = vm.realAssets.where((a) => a.type == AssetType.filamesh && a.fileName.contains('fuel_barrel_red')).first;

      final before = vm.actors.length;
      final reply = await client.callTool('spawn_actor_from_asset', {
        'asset': mesh.relativePath,
        'location': [0, 150, 0],
      });
      expect(reply.isError, isFalse, reason: reply.text);
      expect(vm.actors.length, before + 1);
      final actor = vm.actors.last;
      expect(actor.type, 'Mesh');
      expect(actor.meshData, isNotNull, reason: 'the placed actor draws the barrel');
      expect(reply.data['has_geometry'], isTrue);
      expect(actor.location, [0.0, 150.0, 0.0]);

      final saved = await client.callTool('save_level');
      expect(saved.isError, isFalse, reason: saved.text);
      final levelFile = File('${vm.projectDirPath}/$levelPath');
      expect(levelFile.existsSync(), isTrue);
      final level = jsonDecode(levelFile.readAsStringSync()) as Map;
      final actors = ((level['metadata'] as Map)['actors'] as List).cast<Map>();
      expect(actors.any((a) => a['id'] == actor.id && a['name'] == actor.name), isTrue);
      expect(File('${vm.projectDirPath}/lib/levels/l_main.dart').existsSync(), isTrue);
      expect(vm.project.isDirty, isFalse);

      final missing = await client.callTool('spawn_actor_from_asset', {'asset': 'contents/meshes/nope.lmas'});
      expect(missing.isError, isTrue);
      expect(missing.text, contains('list_assets'));
    });

    test('properties, rename, delete, duplicate and selection go through the view model', () async {
      await client.callTool('spawn_actor', {'type': 'PointLight', 'name': 'Lamp'});
      final lamp = vm.actors.last;
      expect(lamp.name, 'Lamp');

      final mobility = await client.callTool('set_actor_property', {'id': lamp.id, 'property': 'mobility', 'value': 'Static'});
      expect(mobility.isError, isFalse, reason: mobility.text);
      expect(lamp.mobility, 'Static');
      await client.callTool('undo');
      expect(lamp.mobility, 'Movable');

      await client.callTool('set_actor_property', {'id': lamp.id, 'property': 'light_intensity', 'value': 1234});
      expect(lamp.lightIntensity, 1234.0);
      await client.callTool('set_actor_property', {'id': lamp.id, 'property': 'visible', 'value': false});
      expect(lamp.isVisible, isFalse);
      await client.callTool('undo');
      expect(lamp.isVisible, isTrue);
      final wrong = await client.callTool('set_actor_property', {'id': lamp.id, 'property': 'visible', 'value': 'yes'});
      expect(wrong.isError, isTrue);
      expect(wrong.text, contains('boolean'));

      final renamed = await client.callTool('rename_actor', {'id': lamp.id, 'name': 'Lantern'});
      expect(renamed.isError, isFalse, reason: renamed.text);
      expect(lamp.name, 'Lantern');
      await client.callTool('undo');
      expect(lamp.name, 'Lamp');

      final duplicated = await client.callTool('duplicate_actor', {'id': lamp.id});
      expect(duplicated.isError, isFalse, reason: duplicated.text);
      final copies = (duplicated.data['actors'] as List).cast<Map>();
      expect(copies, hasLength(1));
      expect(copies.first['name'], 'Lamp_Copy');
      expect(copies.first['id'], isNot(lamp.id));
      expect(vm.actors.any((a) => a.id == copies.first['id']), isTrue);
      await client.callTool('undo');
      expect(vm.actors.any((a) => a.id == copies.first['id']), isFalse);

      final selected = await client.callTool('select_actors', {
        'ids': [lamp.id],
      });
      expect(selected.isError, isFalse);
      expect(vm.selectedActorIds, {lamp.id});
      await client.callTool('clear_selection');
      expect(vm.selectedActorIds, isEmpty);

      final deleted = await client.callTool('delete_actor', {'id': lamp.id});
      expect(deleted.isError, isFalse, reason: deleted.text);
      expect((deleted.data['deleted_ids'] as List), contains(lamp.id));
      expect(vm.actors.any((a) => a.id == lamp.id), isFalse);
      await client.callTool('undo');
      expect(vm.actors.any((a) => a.id == lamp.id), isTrue, reason: 'undo restores the actor with its id');
    });

    test('bad arguments are named, and refusals carry the editor\'s own reason', () async {
      await expectLater(
        client.callTool('spawn_actor', {}),
        throwsA(isA<McpRpcError>().having((e) => e.message, 'message', contains('"type"'))),
      );
      await expectLater(
        client.callTool('set_actor_transform', {'id': 'nope', 'location': [1, 2, 3]}),
        throwsA(isA<McpRpcError>().having((e) => e.message, 'message', contains('No actor with id "nope"'))),
      );
      await expectLater(
        client.callTool('spawn_actor', {'type': 'Primitive', 'location': [1, 2]}),
        throwsA(isA<McpRpcError>().having((e) => e.message, 'message', contains('three numbers'))),
      );
      final unknownType = await client.callTool('spawn_actor', {'type': 'Teapot'});
      expect(unknownType.isError, isTrue);
      expect(unknownType.text, contains('PointLight'));

      final first = await client.callTool('spawn_actor', {'type': 'Environment'});
      expect(first.isError, isFalse, reason: first.text);
      final second = await client.callTool('spawn_actor', {'type': 'Environment'});
      expect(second.isError, isTrue);
      expect(second.text, vm.spawnRefusalFor('Environment'));

      final nothing = await client.callTool('redo');
      expect(nothing.isError, isTrue);
      expect(nothing.text, 'Nothing to redo.');
    });

    test('a level edit is refused while Play runs', () async {
      vm.startSimulation();
      vm.transactions.isFrozen = true;
      addTearDown(() {
        vm.transactions.isFrozen = false;
        vm.stopSimulation();
      });
      final reply = await client.callTool('spawn_actor', {'type': 'Primitive'});
      expect(reply.isError, isTrue);
      expect(reply.text, contains('stop_pie'));
      expect((await client.callTool('project_info')).data['pie'], {'playing': true, 'paused': false});
    });
  });
}
