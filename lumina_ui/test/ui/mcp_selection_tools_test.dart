import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_server_service.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_server_settings.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_editor_view_model.dart';

import '../helpers/mcp_test_client.dart';
import '../helpers/temp_project.dart';

/// `get_selection` and the `lumina://selection` resource: what the user has
/// selected in the level, the Content Browser and the active tab — a real
/// MCP client over HTTP (and the stdio bridge) against a real editor on a
/// real temp project with real imported props.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final assets = '${Directory.current.parent.path}/test-assets/Props';
  final barrelGlb = File('$assets/Barrels/fuel_barrel_red.glb');
  final acGlb = File('$assets/AC_units/aircon_small.glb');
  const mainLevel = 'contents/levels/L_Main.lmas';

  late Directory root;
  late Directory configDir;
  late EditorViewModel vm;
  late McpServerService server;
  late McpTestClient client;
  late String barrelMesh;
  late String acMesh;

  setUp(() async {
    root = Directory.systemTemp.createTempSync('lumina_mcp_sel_');
    configDir = Directory('${root.path}/config')..createSync();
    final projectDir = Directory('${root.path}/SelProject')..createSync();
    const project = LuminaProject(projectName: 'SelProject', activeLevel: mainLevel);
    File('${projectDir.path}/SelProject.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
    Directory('${projectDir.path}/contents/levels').createSync(recursive: true);
    vm = EditorViewModel(initialProject: project, projectLocation: root.path, enableTimers: false, autoInitAssets: false);
    server = McpServerService(vm, configDir: configDir, settings: McpServerSettings.load(configDir: configDir));
    expect(await server.start(port: 0), isTrue);
    client = McpTestClient(server.url!, server.token);
    await client.handshake();
    await vm.ensureDefaultLevelAssets();
    expect(barrelGlb.existsSync() && acGlb.existsSync(), isTrue, reason: 'test-assets must hold the barrel and the AC unit');
    await vm.processImportPipeline(sourceFilePath: barrelGlb.path);
    await vm.processImportPipeline(sourceFilePath: acGlb.path);
    String meshOf(String name) =>
        vm.realAssets.firstWhere((a) => a.type == AssetType.filamesh && a.fileName.contains(name)).relativePath;
    barrelMesh = meshOf('fuel_barrel_red');
    acMesh = meshOf('aircon_small');
    vm.clearSelection();
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

  Future<String> spawnWall() async {
    final wall = await ok('spawn_actor', {
      'type': 'Primitive',
      'name': 'Wall_North',
      'location': [100, 200, 0],
      'scale': [4, 0.2, 3],
    });
    return (wall['actor'] as Map)['id'] as String;
  }

  List<Map<String, Object?>> actorsOf(Map<String, Object?> selection) =>
      ((selection['level'] as Map)['actors'] as List).map((a) => Map<String, Object?>.from(a as Map)).toList();

  test('an empty selection: no actors, no assets, the level tab', () async {
    final s = await ok('get_selection');
    final level = s['level'] as Map;
    expect(level['count'], 0);
    expect(level['primary_actor_id'], isNull);
    expect(level['actors'], isEmpty);
    final browser = s['content_browser'] as Map;
    expect(browser['count'], 0);
    expect(browser['assets'], isEmpty);
    expect(browser['primary_asset'], isNull);
    expect(browser['current_folder'], 'contents');
    final tab = s['active_tab'] as Map;
    expect(tab['kind'], 'level');
    expect(tab['index'], 0);
    expect(tab['category'], 'level');
    expect(tab['title'], 'L_Main');
    expect(tab['asset'], isNull);
    expect(tab['selection'], isNull);
    expect((s['open_tabs'] as List), hasLength(1));
  });

  test('one selected Primitive wall: id, name, type, transform, mobility, components', () async {
    final wall = await spawnWall();
    final s = await ok('get_selection');
    expect((s['level'] as Map)['count'], 1);
    expect((s['level'] as Map)['primary_actor_id'], wall);
    final a = actorsOf(s).single;
    expect(a['id'], wall);
    expect(a['name'], 'Wall_North');
    expect(a['type'], 'Primitive');
    expect(a['primary'], isTrue);
    expect(a['location'], [100, 200, 0]);
    expect(a['rotation'], [0, 0, 0]);
    expect(a['scale'], [4, 0.2, 3]);
    expect(a['mobility'], isA<String>());
    expect(a['visible'], isTrue);
    expect(a['parent'], isNull);
    expect(a['blueprint'], isNull);
    final components = (a['components'] as List).cast<Map>();
    expect(components, isNotEmpty);
    final node = vm.actors.firstWhere((x) => x.id == wall);
    expect(components.map((c) => c['id']), node.components.map((c) => c.id));
    expect(components.map((c) => c['type']), contains('LuminaProceduralMeshComponent'));
    expect(components.every((c) => !c.containsKey('properties')), isTrue, reason: 'properties only on request');

    final depth = vm.transactions.history(limit: 1000).length;
    final bare = await ok('get_selection', {'include_components': false});
    expect(actorsOf(bare).single.containsKey('components'), isFalse);
    expect(vm.transactions.history(limit: 1000).length, depth, reason: 'no undo step');
  });

  test('several selected actors in selection order, the primary one marked; parent and mesh asset reported', () async {
    final wall = await spawnWall();
    final barrel = ((await ok('spawn_actor_from_asset', {'asset': barrelMesh, 'location': [300, 0, 0]}))['actor'] as Map)['id'] as String;
    final light = ((await ok('spawn_actor', {'type': 'PointLight', 'name': 'Lamp'}))['actor'] as Map)['id'] as String;
    final folder = (await ok('create_folder', {'name': 'Lights', 'wrap_ids': [light]}))['folder_id'] as String;

    await ok('select_actors', {'ids': [wall, barrel, light]});
    final s = await ok('get_selection');
    final actors = actorsOf(s);
    expect(actors.map((a) => a['id']), [wall, barrel, light]);
    final primary = vm.primarySelectedActor!.id;
    expect((s['level'] as Map)['primary_actor_id'], primary);
    expect(actors.where((a) => a['primary'] == true).map((a) => a['id']), [primary]);

    final lamp = actors.firstWhere((a) => a['id'] == light);
    expect(lamp['parent'], {'id': folder, 'name': 'Lights', 'type': 'Folder'});
    expect(lamp['type'], 'PointLight');
    final barrelEntry = actors.firstWhere((a) => a['id'] == barrel);
    expect(barrelEntry['mesh_asset_path'], startsWith('contents/'));
    expect(barrelEntry['mesh_asset_path'], contains('fuel_barrel_red'));

    // Toggling another actor in makes it the primary one.
    vm.clearSelection();
    vm.toggleActorSelection(wall);
    vm.toggleActorSelection(barrel);
    final toggled = await ok('get_selection');
    expect((toggled['level'] as Map)['primary_actor_id'], barrel);
  });

  test('the Content Browser selection: Browse to asset, then two selected assets with the last primary', () async {
    final barrelAsset = vm.realAssets.firstWhere((a) => a.relativePath == barrelMesh);
    vm.browseToAsset(barrelAsset);
    final s = await ok('get_selection');
    final browser = s['content_browser'] as Map;
    final folder = barrelMesh.substring(0, barrelMesh.lastIndexOf('/'));
    expect(browser['current_folder'], folder);
    expect(browser['count'], 1);
    expect(browser['primary_asset'], barrelMesh);
    expect((browser['assets'] as List).single, {
      'path': barrelMesh,
      'name': barrelAsset.fileName.replaceAll('.lmas', ''),
      'type': 'filamesh',
      'primary': true,
    });

    vm.selectContentBrowserAssets([barrelMesh, acMesh]);
    final two = (await ok('get_selection'))['content_browser'] as Map;
    expect(two['count'], 2);
    expect((two['assets'] as List).map((a) => (a as Map)['path']), [barrelMesh, acMesh]);
    expect(two['primary_asset'], acMesh);
    expect((two['assets'] as List).where((a) => (a as Map)['primary'] == true).map((a) => (a as Map)['path']), [acMesh]);
  });

  test('an active Blueprint editor tab reports its asset, graph and selected node', () async {
    await ok('create_asset', {'type': 'actor', 'name': 'BP_Crate', 'parent_class': 'LuminaActor'});
    const asset = 'contents/blueprints/BP_Crate.lmas';
    await ok('open_asset_editor', {'asset': asset});
    final node = ((await ok('add_blueprint_node', {'asset': asset, 'node': 'print_string', 'x': 200, 'y': 80}))['node'] as Map)['id'] as String;
    final editor = vm.editorSessionFor(vm.currentTab.id) as BlueprintEditorViewModel;
    editor.activeGraphEditor.select(node);

    final s = await ok('get_selection');
    final tab = s['active_tab'] as Map;
    expect(tab['kind'], 'sub_editor');
    expect(tab['category'], 'Blueprint');
    expect(tab['title'], 'BP_Crate');
    expect((tab['asset'] as Map)['path'], asset);
    expect((tab['asset'] as Map)['type'], 'actor');
    final selection = tab['selection'] as Map;
    expect(selection['editor'], 'blueprint');
    expect(selection['graph'], 'event');
    expect(selection['selected_node_ids'], [node]);
    expect(((selection['selected_nodes'] as List).single as Map)['id'], node);
    expect(((selection['selected_nodes'] as List).single as Map)['title'], isNotEmpty);
    expect((s['open_tabs'] as List), hasLength(2));
    expect(((s['open_tabs'] as List)[1] as Map)['asset_path'], asset);
  });

  test('include_properties: every component carries the properties get_actor returns', () async {
    final wall = await spawnWall();
    final s = await ok('get_selection', {'include_properties': true});
    final components = (actorsOf(s).single['components'] as List).cast<Map>();
    final fromGetActor = ((await ok('get_actor', {'id': wall}))['components'] as List).cast<Map>();
    expect(components.map((c) => c['id']), fromGetActor.map((c) => c['id']));
    for (var i = 0; i < components.length; i++) {
      expect(components[i]['properties'], fromGetActor[i]['properties']);
      expect(components[i]['properties'], isNotEmpty);
    }
  });

  test('the lumina://selection resource is listed and reads the default selection', () async {
    final wall = await spawnWall();
    final resources = ((await client.request('resources/list'))['resources'] as List).cast<Map>();
    expect(resources.map((r) => r['uri']), contains('lumina://selection'));
    final read = await client.request('resources/read', {'uri': 'lumina://selection'});
    final content = (read['contents'] as List).single as Map;
    expect(content['mimeType'], 'application/json');
    final fromResource = jsonDecode(content['text'] as String) as Map;
    expect(fromResource, await ok('get_selection'));
    expect(((fromResource['level'] as Map)['primary_actor_id']), wall);
  });

  test('get_selection is read-only and listed in the level and asset groups', () async {
    final tools = {for (final t in await client.listTools()) t['name']: t};
    final tool = tools['get_selection']!;
    expect((tool['_meta'] as Map)['lumina/risk'], 'readOnly');
    expect(((tool['_meta'] as Map)['lumina/groups'] as List), unorderedEquals(['level', 'asset']));
    expect((tool['annotations'] as Map)['readOnlyHint'], isTrue);
    expect((await client.listTools(groups: ['level'])).map((t) => t['name']), contains('get_selection'));
    expect((await client.listTools(groups: ['asset'])).map((t) => t['name']), contains('get_selection'));
  });

  test('through the stdio bridge, tools/call get_selection answers with the selected actor', () async {
    final wall = await spawnWall();
    final exe = Platform.resolvedExecutable.replaceAll(r'\', '/');
    final cache = exe.indexOf('/bin/cache/');
    var dart = 'dart';
    if (cache >= 0) {
      final sdkDart = '${exe.substring(0, cache)}/bin/cache/dart-sdk/bin/dart${Platform.isWindows ? '.exe' : ''}';
      if (File(sdkDart).existsSync()) dart = sdkDart;
    }
    final process = await Process.start(
      dart,
      ['${Directory.current.path}/bin/lumina_mcp_bridge.dart'],
      environment: {...Platform.environment, 'LUMINA_CONFIG_DIR': configDir.path},
    );
    addTearDown(process.kill);
    process.stderr.transform(utf8.decoder).listen(stderr.write);
    final lines = StreamIterator(process.stdout.transform(utf8.decoder).transform(const LineSplitter()));
    Future<Map<String, Object?>> ask(Map<String, Object?> message) async {
      process.stdin.writeln(jsonEncode(message));
      expect(await lines.moveNext().timeout(const Duration(seconds: 30)), isTrue);
      return Map<String, Object?>.from(jsonDecode(lines.current) as Map);
    }

    await ask({
      'jsonrpc': '2.0',
      'id': 1,
      'method': 'initialize',
      'params': {'protocolVersion': '2025-06-18', 'capabilities': {}, 'clientInfo': {'name': 'selection-bridge', 'version': '0'}},
    });
    process.stdin.writeln(jsonEncode({'jsonrpc': '2.0', 'method': 'notifications/initialized'}));
    final call = await ask({
      'jsonrpc': '2.0',
      'id': 2,
      'method': 'tools/call',
      'params': {'name': 'get_selection', 'arguments': {'include_components': false}},
    });
    final result = call['result'] as Map;
    expect(result['isError'], isFalse);
    final data = result['structuredContent'] as Map;
    expect((data['level'] as Map)['primary_actor_id'], wall);
    expect(((data['level'] as Map)['actors'] as List).single, containsPair('name', 'Wall_North'));
  });
}
