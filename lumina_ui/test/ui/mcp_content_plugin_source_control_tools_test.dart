import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_marketplace_shared/lumina_marketplace_shared.dart' show MarketplaceClient;
import 'package:lumina_ui/ui/core/services/user_plugin_dir.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/content_browser_widget.dart';
import 'package:lumina_ui/ui/features/marketplace/view_models/marketplace_view_model.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_server_service.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_server_settings.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_tool.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../helpers/marketplace_test_backend.dart' as market;
import '../helpers/mcp_test_client.dart';
import '../helpers/temp_project.dart';

/// Denies every external call, as a user's "ask me first" policy would when
/// the user says no (the MCP approval chain).
class _DenyExternal implements McpApprovalPolicy {
  @override
  McpApprovalDecision review(McpCallContext call) => call.risk == McpToolRisk.external
      ? const McpApprovalDecision.deny('not approved: the user declined this external call')
      : const McpApprovalDecision.allow();
}

/// The Content Browser's organisation work (folders, moves,
/// collections, thumbnails, Import Asset Folder), Plugins, the Marketplace,
/// Source Control and Clear Derived Data Cache — a real MCP client over HTTP
/// against a real editor on a temp project, with real test-assets GLBs, real
/// plugin generation, a real Marketplace server process and real `git`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const mainLevel = 'contents/levels/L_Main.lmas';
  final assets = Platform.environment['LUMINA_TEST_ASSETS'] ?? '${Directory.current.parent.path}/test-assets';
  final barrels = '$assets/Props/Barrels';
  final redBarrel = '$barrels/fuel_barrel_red.glb';
  final blackBarrel = '$barrels/fuel_barrel_black.glb';
  final banana = '$assets/Props/Banana Bunch/banana_bunch_long.glb';
  final skipAssets = File(redBarrel).existsSync() && File(banana).existsSync() ? null : 'test-assets missing';

  late Directory root;
  late Directory projectDir;
  late EditorViewModel vm;
  late McpServerService server;
  late McpTestClient client;

  File manifestFile() => File('${projectDir.path}/AgentGame.lmproject');

  Future<McpToolReply> call(String tool, [Map<String, Object?> args = const {}]) => client.callTool(tool, args);
  Future<Map<String, Object?>> ok(String tool, [Map<String, Object?> args = const {}]) async {
    final r = await call(tool, args);
    expect(r.isError, isFalse, reason: '$tool: ${r.text}');
    return r.data;
  }

  Future<String> err(String tool, [Map<String, Object?> args = const {}]) async {
    final r = await call(tool, args);
    expect(r.isError, isTrue, reason: '$tool should fail: ${r.text}');
    return r.text;
  }

  Future<void> expectInvalid(String tool, Map<String, Object?> args, Matcher message) => expectLater(
        call(tool, args),
        throwsA(isA<McpRpcError>().having((e) => e.code, 'code', -32602).having((e) => e.message, 'message', message)),
      );

  /// Waits for [id] with repeated bounded `wait_job` calls.
  Future<Map<String, Object?>> finish(String id, {int rounds = 24}) async {
    Map<String, Object?> job = const {};
    for (var i = 0; i < rounds; i++) {
      job = await ok('wait_job', {'id': id, 'timeout_ms': 20000});
      if (job['timed_out'] != true) break;
    }
    return job;
  }

  /// `import_asset` of [path] into [folder]; returns the new mesh's `.lmas`.
  Future<String> importMesh(String path, {String? folder}) async {
    final r = await ok('import_asset', {'path': path, 'folder': ?folder});
    final imported = (r['imported'] as List).cast<Map>();
    return imported.firstWhere((a) => a['type'] == 'filamesh')['path'] as String;
  }

  setUp(() async {
    root = Directory.systemTemp.createTempSync('lumina_mcp08_');
    final configDir = Directory('${root.path}/config')..createSync();
    UserPluginDir.override = Directory('${root.path}/user_plugins')..createSync();
    PluginDataDir.override = Directory('${root.path}/plugin_data')..createSync();
    projectDir = Directory('${root.path}/AgentGame')..createSync();
    const project = LuminaProject(projectName: 'AgentGame', activeLevel: mainLevel);
    manifestFile().writeAsStringSync(jsonEncode(project.toMap()));
    Directory('${projectDir.path}/contents/levels').createSync(recursive: true);
    vm = EditorViewModel(initialProject: project, projectLocation: root.path, enableTimers: false, autoInitAssets: false);
    server = McpServerService(vm, configDir: configDir, settings: McpServerSettings.load(configDir: configDir));
    expect(await server.start(port: 0), isTrue);
    client = McpTestClient(server.url!, server.token);
    await client.handshake();
    await vm.ensureDefaultLevelAssets();
  });

  tearDown(() async {
    client.close();
    await server.stop();
    await vm.close();
    UserPluginDir.override = null;
    PluginDataDir.override = null;
    await deleteTempProject(root);
  });

  group('create_asset folders and shells', () {
    test('actor and widget honour folder; texture and filamesh are errors naming import_asset, nothing written', () async {
      final door = await ok('create_asset', {'type': 'actor', 'name': 'BP_Door', 'folder': 'blueprints/doors', 'parent_class': 'LuminaActor'});
      expect(door['path'], 'contents/blueprints/doors/BP_Door.lmas');
      final file = File('${projectDir.path}/contents/blueprints/doors/BP_Door.lmas');
      expect(file.existsSync(), isTrue);
      expect(LuminaAsset.fromBytes(file.readAsBytesSync()).metadata['parent_class'], 'LuminaActor');
      expect(File('${projectDir.path}/contents/blueprints/BP_Door.lmas').existsSync(), isFalse);

      final hud = await ok('create_asset', {'type': 'widget', 'name': 'WBP_Hud', 'folder': 'ui'});
      expect(hud['path'], 'contents/ui/WBP_Hud.lmas');
      expect(File('${projectDir.path}/contents/ui/WBP_Hud.lmas').existsSync(), isTrue);

      final before = vm.contentsSnapshot();
      expect(await err('create_asset', {'type': 'texture', 'name': 'T_X'}), contains('import_asset'));
      expect(await err('create_asset', {'type': 'filamesh', 'name': 'SM_X'}), contains('import_asset'));
      expect(vm.contentsSnapshot().keys, unorderedEquals(before.keys), reason: 'no empty shell was written');
    });

    testWidgets('New Asset → Blueprint creates the class in the selected Content Browser folder', (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Directory('${projectDir.path}/contents/blueprints/doors').createSync(recursive: true);
      vm.refreshAssets();
      vm.selectedFolder = 'contents/blueprints/doors';
      await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: Scaffold(child: ContentBrowserWidget(viewModel: vm))));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New Asset').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('New Blueprint / Actor (.lmas)'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {});
      await tester.tap(find.text('Create Blueprint'));
      await tester.pumpAndSettle();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      expect(File('${projectDir.path}/contents/blueprints/doors/BP_NewBlueprint.lmas').existsSync(), isTrue);
      expect(File('${projectDir.path}/contents/blueprints/BP_NewBlueprint.lmas').existsSync(), isFalse);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('folders, moves, rename and duplicate', () {
    test('create_content_folder makes Props then Props_1 with keep-markers; list_content_folders shows both empty', () async {
      final a = await ok('create_content_folder', {'parent': 'contents', 'name': 'Props'});
      expect(a['path'], 'contents/Props');
      expect(Directory('${projectDir.path}/contents/Props').listSync().whereType<File>(), isNotEmpty, reason: 'keep-marker');
      final b = await ok('create_content_folder', {'parent': 'contents', 'name': 'Props'});
      expect(b['path'], 'contents/Props_1');
      expect(vm.selectedFolder, 'contents', reason: 'the browser shows the parent with the new tile');
      final tree = await ok('list_content_folders');
      Map? find(List nodes, String path) {
        for (final n in nodes.cast<Map>()) {
          if (n['path'] == path) return n;
          final hit = find(n['children'] as List, path);
          if (hit != null) return hit;
        }
        return null;
      }

      final nodes = tree['folders'] as List;
      expect(find(nodes, 'contents/Props'), containsPair('asset_count', 0));
      expect(find(nodes, 'contents/Props_1'), containsPair('asset_count', 0));
      expect(find(nodes, 'contents/levels'), containsPair('asset_count', 1));
      await expectInvalid('create_content_folder', {'parent': '/etc', 'name': 'x'}, contains('contents'));
    }, skip: skipAssets);

    test('move_asset moves the .lmas, list_assets lists it there, and a placed actor still resolves its mesh', () async {
      final mesh = await importMesh(redBarrel);
      final placed = await ok('spawn_actor_from_asset', {'asset': mesh});
      final actorId = placed['id'] ?? (placed['actor'] as Map?)?['id'];
      await ok('create_content_folder', {'parent': 'contents', 'name': 'Props'});
      final moved = await ok('move_asset', {'asset': 'fuel_barrel_red.lmas', 'folder': 'contents/Props'});
      expect(moved['path'], 'contents/Props/fuel_barrel_red.lmas');
      expect(File('${projectDir.path}/contents/Props/fuel_barrel_red.lmas').existsSync(), isTrue);
      expect(File('${projectDir.path}/$mesh').existsSync(), isFalse);
      final listed = await ok('list_assets', {'folder': 'contents/Props'});
      expect((listed['assets'] as List).cast<Map>().map((a) => a['path']), contains('contents/Props/fuel_barrel_red.lmas'));
      final actor = vm.actors.firstWhere((a) => a.id == actorId);
      final ref = actor.meshAssetPath!.replaceAll(r'\', '/');
      expect(ref, endsWith('contents/Props/fuel_barrel_red.lmas'), reason: 'the reference was rewritten');
      final resolved = p(ref) ? ref : '${projectDir.path}/$ref';
      expect(File(resolved).existsSync(), isTrue, reason: 'the actor still loads its mesh');
      expect(vm.selectedFolder, 'contents/Props');
    }, skip: skipAssets);

    test('move_asset refuses the active level; a game_default_map level moves with a warning and the manifest untouched', () async {
      final active = await err('move_asset', {'asset': mainLevel, 'folder': 'contents/Maps'});
      expect(active, contains('Open another level first'));
      expect(File('${projectDir.path}/$mainLevel').existsSync(), isTrue);

      File('${projectDir.path}/$mainLevel').copySync('${projectDir.path}/contents/levels/L_Second.lmas');
      vm.refreshAssets();
      await ok('set_project_settings', {'changes': {'maps_and_modes.game_default_map': 'contents/levels/L_Second.lmas'}});
      await ok('apply_project_settings');
      final bytes = manifestFile().readAsBytesSync();
      final moved = await ok('move_asset', {'asset': 'contents/levels/L_Second.lmas', 'folder': 'contents/Maps'});
      expect(moved['path'], 'contents/Maps/L_Second.lmas');
      expect((moved['warnings'] as List).join(' '), contains('maps_and_modes.game_default_map'));
      expect(manifestFile().readAsBytesSync(), bytes, reason: 'the tools never write the .lmproject');
    });

    test('rename_content_folder renames, the selection follows; bad names and the root are refused', () async {
      await importMesh(redBarrel);
      await ok('create_content_folder', {'parent': 'contents', 'name': 'Props'});
      await ok('move_asset', {'asset': 'fuel_barrel_red.lmas', 'folder': 'contents/Props'});
      final renamed = await ok('rename_content_folder', {'folder': 'contents/Props', 'new_name': 'Barrels'});
      expect(renamed['path'], 'contents/Barrels');
      expect(File('${projectDir.path}/contents/Barrels/fuel_barrel_red.lmas').existsSync(), isTrue);
      expect(vm.selectedFolder, 'contents/Barrels');
      expect(await err('rename_content_folder', {'folder': 'contents/Barrels', 'new_name': 'a/b'}),
          contains('That name is empty, invalid or already taken.'));
      expect(await err('rename_content_folder', {'folder': 'contents', 'new_name': 'Stuff'}), contains('root'));
    }, skip: skipAssets);

    test('delete_content_folder trashes the folder, removes the actor; undo brings all back; the open level\'s folder is refused',
        () async {
      await importMesh(redBarrel);
      await ok('create_content_folder', {'parent': 'contents', 'name': 'Barrels'});
      await ok('move_asset', {'asset': 'fuel_barrel_red.lmas', 'folder': 'contents/Barrels'});
      await ok('spawn_actor_from_asset', {'asset': 'contents/Barrels/fuel_barrel_red.lmas'});
      final actor = vm.actors.last;
      expect(await err('delete_content_folder', {'folder': 'contents/levels'}), contains('open level'));

      final deleted = await ok('delete_content_folder', {'folder': 'contents/Barrels'});
      final trashId = deleted['trash_id'] as String;
      expect(deleted['trashed_assets'], contains('contents/Barrels/fuel_barrel_red.lmas'));
      expect(Directory('${projectDir.path}/contents/Barrels').existsSync(), isFalse);
      expect(File('${projectDir.path}/.lumina/trash/$trashId/files/contents/Barrels/fuel_barrel_red.lmas').existsSync(), isTrue);
      expect(vm.actors.any((a) => a.id == actor.id), isFalse);

      final undone = await ok('undo', {'scope': 'agent'});
      expect(undone['undone'], contains('MCP'));
      expect(File('${projectDir.path}/contents/Barrels/fuel_barrel_red.lmas').existsSync(), isTrue);
      expect(Directory('${projectDir.path}/contents/Barrels').listSync().whereType<File>().length, greaterThanOrEqualTo(2),
          reason: 'the asset and the keep-marker');
      expect(vm.actors.any((a) => a.id == actor.id), isTrue, reason: 'the actor comes back with its id');

      final tool = server.tools.byName('delete_content_folder')!;
      expect(tool.wraps, contains('EditorViewModel.deleteContentFolderToTrash'));
      expect(tool.wraps, isNot(contains('EditorViewModel.deleteContentFolder')));
    }, skip: skipAssets);

    test('rename_asset keeps the id and the referencing material resolves; duplicate_asset gives <name>_1 with a fresh id', () async {
      final mesh = await importMesh(redBarrel);
      final before = vm.realAssets.firstWhere((a) => a.relativePath == mesh);
      final renamed = await ok('rename_asset', {'asset': 'fuel_barrel_red.lmas', 'new_name': 'SM_Barrel_Red'});
      expect(renamed['path'], mesh.replaceFirst('fuel_barrel_red.lmas', 'SM_Barrel_Red.lmas'));
      expect(renamed['asset_id'], before.assetId);
      expect(File('${projectDir.path}/${renamed['path']}').existsSync(), isTrue);
      expect(File('${projectDir.path}/$mesh').existsSync(), isFalse);
      // Every reference (the mesh's material and textures, and anything that
      // points at the mesh) still resolves by id.
      for (final a in vm.realAssets) {
        for (final r in a.references) {
          expect(vm.realAssets.any((x) => x.assetId == r.assetId), isTrue, reason: '${a.relativePath} ${r.slotName} → ${r.assetId}');
        }
      }

      final dup = await ok('duplicate_asset', {'asset': renamed['path']});
      expect(dup['path'], (renamed['path'] as String).replaceFirst('SM_Barrel_Red.lmas', 'SM_Barrel_Red_1.lmas'));
      expect(dup['asset_id'], isNot(before.assetId));
      expect(File('${projectDir.path}/${dup['path']}').existsSync(), isTrue);
    }, skip: skipAssets);
  });

  group('collections and thumbnails', () {
    test('create / add / remove / delete a collection in contents/.collections.json; a duplicate name is refused', () async {
      final red = await importMesh(redBarrel);
      final black = await importMesh(blackBarrel);
      Map<String, Object?> file() =>
          Map<String, Object?>.from(jsonDecode(File('${projectDir.path}/contents/.collections.json').readAsStringSync()) as Map);
      List<Map> heroAssets() => (((file()['collections'] as List).cast<Map>().firstWhere((c) => c['name'] == 'Hero Props'))['assets']
              as List)
          .cast<Map>();

      await ok('create_collection', {'name': 'Hero Props'});
      final added = await ok('add_to_collection', {'collection': 'Hero Props', 'assets': [red, black]});
      expect(added['count'], 2);
      final ids = {for (final a in vm.realAssets.where((a) => a.relativePath == red || a.relativePath == black)) a.assetId};
      expect(heroAssets().map((a) => a['asset_id'] ?? a['assetId']).toSet(), ids);
      expect(await err('create_collection', {'name': 'Hero Props'}), contains('already exists'));
      final listed = await ok('list_collections');
      expect(((listed['collections'] as List).cast<Map>().single['assets'] as List), hasLength(2));

      await ok('remove_from_collection', {'collection': 'Hero Props', 'assets': [black]});
      expect(heroAssets(), hasLength(1));
      await ok('delete_collection', {'name': 'Hero Props'});
      expect((file()['collections'] as List).cast<Map>().where((c) => c['name'] == 'Hero Props'), isEmpty);
    }, skip: skipAssets);

    test('regenerate_thumbnails queues each asset and reports its thumbnail path', () async {
      final red = await importMesh(redBarrel);
      final black = await importMesh(blackBarrel);
      final r = await ok('regenerate_thumbnails', {'assets': [red, black]});
      expect(r['queued'], 2);
      final thumbs = (r['thumbnails'] as List).cast<Map>();
      expect(thumbs.map((t) => t['asset']), unorderedEquals([red, black]));
      for (final t in thumbs) {
        expect(t['png_path'], isA<String>());
      }
    }, skip: skipAssets);
  });

  group('import_asset_folder', () {
    test('dry run plans every barrel and writes nothing; the job imports them; skip, rename, bad target and cancel', () async {
      final expected = ImportFolderScanner.scan(barrels).files.length;
      final plan = await ok('import_asset_folder', {'path': barrels, 'target_folder': 'contents/Props', 'dry_run': true});
      expect(plan['imports'], hasLength(expected));
      expect(((plan['imports'] as List).first as Map)['target'], startsWith('contents/Props/'));
      expect(Directory('${projectDir.path}/contents/Props').existsSync(), isFalse, reason: 'a dry run imports nothing');

      final started = await ok('import_asset_folder', {'path': barrels, 'target_folder': 'contents/Props'});
      final done = await finish(started['job_id'] as String);
      expect(done['state'], 'succeeded', reason: '${done['error']}');
      expect(done['kind'], 'import_folder');
      expect((done['result'] as Map)['imported'], expected);
      for (final f in Directory(barrels).listSync().whereType<File>().where((f) => f.path.endsWith('.glb'))) {
        final base = f.uri.pathSegments.last.replaceAll('.glb', '');
        expect(File('${projectDir.path}/contents/Props/$base.lmas').existsSync(), isTrue, reason: base);
      }

      final again = await ok('import_asset_folder', {'path': barrels, 'target_folder': 'contents/Props', 'conflict_policy': 'skip'});
      final skipped = await finish(again['job_id'] as String);
      expect((skipped['result'] as Map)['skipped'], expected);
      expect((skipped['result'] as Map)['imported'], 0);

      final renamed = await ok('import_asset_folder', {'path': barrels, 'target_folder': 'contents/Props', 'conflict_policy': 'rename'});
      final copies = await finish(renamed['job_id'] as String);
      expect((copies['result'] as Map)['imported'], expected);
      expect(File('${projectDir.path}/contents/Props/fuel_barrel_red_1.lmas').existsSync(), isTrue);

      await expectInvalid('import_asset_folder', {'path': barrels, 'target_folder': '/etc'}, contains('contents/'));

      final cancelled = await ok('import_asset_folder', {'path': barrels, 'target_folder': 'contents/Cancel'});
      final stopped = await ok('cancel_job', {'id': cancelled['job_id']});
      expect(stopped['state'], 'cancelled');
      final settled = await finish(cancelled['job_id'] as String);
      expect(((settled['result'] as Map?)?['cancelled'] as int? ?? 0), greaterThan(0), reason: '${settled['result']}');
    }, skip: skipAssets, timeout: const Timeout(Duration(minutes: 6)));
  });

  group('plugins', () {
    test('create_plugin validates, generates content-only and code plugins as jobs; set_plugin_enabled reports restarts', () async {
      await expectInvalid('create_plugin', {'name': 'bad name!', 'template': 'contentOnly'}, contains('lowercase'));
      final content = await ok('create_plugin', {'name': 'lumina_plugin_agent_tools', 'template': 'contentOnly'});
      final contentJob = await finish(content['job_id'] as String);
      expect(contentJob['state'], 'succeeded', reason: '${contentJob['error']} ${contentJob['log']}');
      expect(contentJob['kind'], 'create_plugin');
      final result = contentJob['result'] as Map;
      expect(result['success'], isTrue);
      final dir = result['plugin_dir'] as String;
      expect(File('$dir/lumina_plugin_agent_tools.lmplugin').existsSync(), isTrue);
      expect((contentJob['log'] as List).cast<Map>().map((l) => l['message']).join('\n'), contains('Scaffolding'));

      final code = await ok('create_plugin', {'name': 'agent_code_tools', 'template': 'blank'});
      final codeJob = await finish(code['job_id'] as String, rounds: 40);
      expect(codeJob['state'], 'succeeded', reason: '${codeJob['error']} ${codeJob['log']}');

      Map listed(Map<String, Object?> list, String name) =>
          (list['plugins'] as List).cast<Map>().firstWhere((p) => p['name'] == name);
      final plugins = await ok('list_plugins', {'group': 'installed'});
      expect(listed(plugins, 'lumina_plugin_agent_tools'), allOf(containsPair('content_only', true), containsPair('enabled', false)));
      expect(listed(plugins, 'agent_code_tools'), allOf(containsPair('content_only', false), containsPair('enabled', false)));

      final contentOn = await ok('set_plugin_enabled', {'name': 'lumina_plugin_agent_tools', 'enabled': true});
      expect(contentOn['restart_required'], isFalse);
      expect(vm.sourceFolders.map((f) => f.replaceAll(r'\', '/')), contains(endsWith('lumina_plugin_agent_tools/content')));

      final codeOn = await ok('set_plugin_enabled', {'name': 'agent_code_tools', 'enabled': true});
      expect(codeOn['restart_required'], isTrue);
      expect(codeOn['message'], contains('The agent cannot restart it'));
      expect(vm.pluginRestartRequired, isTrue, reason: 'the Restart Editor banner shows; nothing exited');

      // remove_plugin: a dry run lists what would go and deletes nothing;
      // then the enabled code plugin is removed and disabled.
      final dry = await ok('remove_plugin', {'name': 'agent_code_tools', 'dry_run': true});
      expect(dry['dry_run'], isTrue);
      expect(dry['origin'], 'project');
      expect((dry['plugin_dir'] as String).replaceAll(r'\', '/'), endsWith('plugins/agent_code_tools'));
      expect(dry['file_count'] as int, greaterThan(0));
      expect(dry['bytes'] as int, greaterThan(0));
      expect(dry['enabled'], isTrue);
      expect(dry['every_project'], isFalse);
      expect(dry['restart_required'], isTrue);
      expect(dry['data'], isEmpty);
      final codeDir = Directory(dry['plugin_dir'] as String);
      expect(codeDir.existsSync(), isTrue, reason: 'a dry run deletes nothing');
      final removed = await ok('remove_plugin', {'name': 'agent_code_tools'});
      expect(removed['removed'], isTrue, reason: '$removed');
      expect(removed['disabled'], ['agent_code_tools']);
      expect(removed['message'], contains('The agent cannot restart it'));
      expect(codeDir.existsSync(), isFalse);
      expect(jsonDecode(manifestFile().readAsStringSync())['enabled_plugins'], isNot(contains('agent_code_tools')));
      expect(vm.pluginRestartRequired, isTrue, reason: 'the banner stays after the rescan');
      final after = await ok('list_plugins', {'group': 'installed'});
      expect((after['plugins'] as List).cast<Map>().map((p) => p['name']), isNot(contains('agent_code_tools')));
      await expectInvalid('remove_plugin', {'name': 'agent_code_tools'}, contains('No plugin'));
      final builtIn = vm.pluginRegistry.entries.where((e) => e.descriptor.origin == PluginOrigin.engine).firstOrNull;
      if (builtIn != null) await expectInvalid('remove_plugin', {'name': builtIn.descriptor.name}, contains('built-in'));

      await expectInvalid('set_plugin_enabled', {'name': 'no_such_plugin', 'enabled': true}, contains('lumina_plugin_agent_tools'));
    }, timeout: const Timeout(Duration(minutes: 8)));
  });

  group('marketplace', () {
    final skipMarket = market.MarketplaceTestBackend.unavailableReason;
    market.MarketplaceTestBackend? backend;
    setUpAll(() async {
      if (skipMarket != null) return;
      MarketplaceViewModel.httpClientFactory = market.realHttpClient;
      backend = await market.MarketplaceTestBackend.start();
    });
    tearDownAll(() async => backend?.stop());

    test('signed out install is refused; signed in: search, install as a job, list installed; no token leaks', () async {
      expect(vm.editorPreferences.setMarketplaceUrl(backend!.url.toString()), isTrue);
      final signedOut = await ok('marketplace_status');
      expect(signedOut['signed_in'], isFalse);
      final hits0 = await ok('marketplace_search', {'query': 'Barrel'});
      final barrelId = (hits0['results'] as List).cast<Map>().firstWhere((l) => l['title'] == 'Barrel')['id'] as String;
      expect(await err('marketplace_install', {'id': barrelId}), contains('Sign in in Window → Marketplace'));

      final MarketplaceClient api = backend!.client();
      final account = await backend!.signUpUser(api);
      expect(await vm.marketplace.signIn(account.user.username, 'correct horse battery'), isTrue);
      final status = await call('marketplace_status');
      expect(status.data['signed_in'], isTrue);
      expect((status.data['user'] as Map)['username'], account.user.username);
      final raw = jsonEncode(status.raw);
      for (final secret in [vm.marketplace.service.client.accessToken, vm.marketplace.service.client.refreshToken]) {
        if (secret != null) expect(raw.contains(secret), isFalse, reason: 'marketplace_status never returns the session');
      }

      final hits = await ok('marketplace_search', {'query': 'Barrel'});
      expect(hits['total'], greaterThanOrEqualTo(1));
      final detail = await ok('marketplace_get_listing', {'id': barrelId});
      expect(detail['can_install'], isTrue);
      expect(detail['install_label'], 'Add to Project');

      final started = await ok('marketplace_install', {'id': barrelId, 'folder': 'contents/Marketplace'});
      expect(vm.currentTab.category, EditorViewModel.marketplaceCategory, reason: 'Window → Marketplace opens');
      final done = await finish(started['job_id'] as String);
      expect(done['state'], 'succeeded', reason: '${done['error']} ${done['log']}');
      expect(done['kind'], 'marketplace_install');
      expect(done['progress'], 1.0);
      final record = done['result'] as Map;
      expect(record['installed_to'], startsWith('contents/Marketplace/'));
      expect(File('${projectDir.path}/${record['license_file']}').existsSync(), isTrue);
      expect(Directory('${projectDir.path}/${record['installed_to']}').existsSync(), isTrue);
      final installed = await ok('marketplace_list_installed');
      expect((installed['installed'] as List).cast<Map>().map((r) => r['id']), contains(barrelId));
      final names = [for (final t in await client.listTools()) t['name'] as String];
      expect(names.where((n) => n.contains('uninstall')), isEmpty);
      expect(names.where((n) => n.contains('sign_in')), isEmpty);
    }, skip: skipMarket, timeout: const Timeout(Duration(minutes: 4)));

    test('with a policy that denies external calls, marketplace_install is not approved and writes nothing', () async {
      expect(vm.editorPreferences.setMarketplaceUrl(backend!.url.toString()), isTrue);
      server.approvalPolicies.add(_DenyExternal());
      final hits = await ok('marketplace_search', {'query': 'Barrel'});
      final barrelId = (hits['results'] as List).cast<Map>().firstWhere((l) => l['title'] == 'Barrel')['id'] as String;
      final denied = await call('marketplace_install', {'id': barrelId, 'folder': 'contents/Marketplace'});
      expect(denied.isError, isTrue);
      expect(jsonDecode(denied.text), allOf(containsPair('status', 'denied'), containsPair('risk', 'external')));
      expect((jsonDecode(denied.text) as Map)['reason'], contains('not approved'));
      expect(Directory('${projectDir.path}/contents/Marketplace').existsSync(), isFalse);
      final added = await call('marketplace_add_to_library', {'id': barrelId});
      expect(added.isError, isTrue);
    }, skip: skipMarket);
  });

  group('source control', () {
    test('status, init, commit, history, revert, empty message, identity', () async {
      final status0 = await ok('source_control_status');
      expect(status0['available'], isTrue, reason: 'git must be installed');
      expect(status0['is_repo'], isFalse);
      final init = await ok('source_control_init');
      expect(init['is_repo'], isTrue);
      expect(init['last_commit'], isNotNull);

      await ok('create_content_folder', {'parent': 'contents', 'name': 'Props'});
      final mesh = await importMesh(redBarrel, folder: 'contents/Props');
      final status1 = await ok('source_control_status', {'summaries': true});
      final changes = (status1['changes'] as List).cast<Map>();
      expect(changes.firstWhere((c) => c['path'] == mesh), containsPair('state', 'untracked'));

      final committed = await ok('source_control_commit', {'all': true, 'message': 'Agent: add barrels'});
      expect((committed['hash'] as String).length, 40);
      expect((await ok('source_control_status'))['changes'], isEmpty);
      final history = await ok('source_control_history', {'path': mesh});
      expect((history['entries'] as List).cast<Map>().single['subject'], 'Agent: add barrels');

      final file = File('${projectDir.path}/$mesh');
      final original = file.readAsBytesSync();
      file.writeAsBytesSync([...original, 1, 2, 3]);
      await ok('source_control_status');
      final reverted = await ok('source_control_revert', {'path': mesh});
      expect(reverted['reverted'], isTrue);
      expect(file.readAsBytesSync(), original);
      expect(await err('source_control_revert', {'path': 'contents/nothing.lmas'}), contains('changes'));

      await expectInvalid('source_control_commit', {'all': true, 'message': '  '}, contains('message'));
      await expectInvalid('source_control_commit', {'message': 'x'}, contains('paths'));

      // A repo whose identity is empty: git refuses; the tool points at
      // source_control_set_identity, which then lets the commit through.
      await Process.run('git', ['config', 'user.name', ''], workingDirectory: projectDir.path);
      File('${projectDir.path}/contents/Props/notes.json').writeAsStringSync('{"note": 1}');
      await ok('source_control_status');
      final refused = await err('source_control_commit', {'all': true, 'message': 'Agent: notes'});
      expect(refused, contains('source_control_set_identity'));
      await ok('source_control_set_identity', {'name': 'Lumina Agent', 'email': 'agent@lumina.local'});
      final after = await ok('source_control_commit', {'all': true, 'message': 'Agent: notes'});
      expect((after['hash'] as String).length, 40);
    }, skip: skipAssets, timeout: const Timeout(Duration(minutes: 3)));
  });

  group('derived data cache and the registry', () {
    test('clear_derived_data_cache frees the entries a texture-budgeted load stored', () async {
      final cache = DerivedDataCache(projectDir.path);
      await cache.sanitizedGlb(File(redBarrel).readAsBytesSync(), maxTextureSize: 64, label: 'fuel_barrel_red.glb');
      expect(cache.entries(), isNotEmpty, reason: 'the oversized textures were downscaled into the cache');
      final freed = await ok('clear_derived_data_cache');
      expect(freed['entries'], greaterThanOrEqualTo(1));
      expect(freed['bytes'], greaterThan(0));
      expect(cache.entries(), isEmpty);
    }, skip: skipAssets);

    test('every content, plugin and source control tool declares its risk and groups', () async {
      const expected = {
        'list_content_folders': ('readOnly', {'content'}),
        'list_collections': ('readOnly', {'content'}),
        'list_plugins': ('readOnly', {'plugin'}),
        'marketplace_status': ('readOnly', {'content', 'plugin'}),
        'marketplace_search': ('readOnly', {'content', 'plugin'}),
        'marketplace_get_listing': ('readOnly', {'content', 'plugin'}),
        'marketplace_list_installed': ('readOnly', {'content', 'plugin'}),
        'source_control_status': ('readOnly', {'scm'}),
        'source_control_history': ('readOnly', {'scm'}),
        'create_content_folder': ('mutating', {'content'}),
        'rename_content_folder': ('mutating', {'content'}),
        'move_asset': ('mutating', {'content'}),
        'rename_asset': ('mutating', {'content'}),
        'duplicate_asset': ('mutating', {'content'}),
        'create_collection': ('mutating', {'content'}),
        'add_to_collection': ('mutating', {'content'}),
        'remove_from_collection': ('mutating', {'content'}),
        'delete_collection': ('mutating', {'content'}),
        'regenerate_thumbnails': ('mutating', {'content'}),
        'import_asset_folder': ('mutating', {'content'}),
        'set_plugin_enabled': ('mutating', {'plugin'}),
        'source_control_init': ('mutating', {'scm'}),
        'source_control_commit': ('mutating', {'scm'}),
        'source_control_set_identity': ('mutating', {'scm'}),
        'delete_content_folder': ('destructive', {'content'}),
        'clear_derived_data_cache': ('destructive', {'content'}),
        'source_control_revert': ('destructive', {'scm'}),
        'create_plugin': ('external', {'plugin'}),
        'remove_plugin': ('destructive', {'plugin'}),
        'marketplace_add_to_library': ('external', {'content', 'plugin'}),
        'marketplace_install': ('external', {'content', 'plugin'}),
      };
      final listed = {for (final t in await client.listTools()) t['name'] as String: t};
      for (final e in expected.entries) {
        final t = listed[e.key];
        expect(t, isNotNull, reason: '${e.key} is registered');
        final meta = t!['_meta'] as Map;
        expect(meta['lumina/risk'], e.value.$1, reason: e.key);
        expect((meta['lumina/groups'] as List).toSet(), e.value.$2, reason: e.key);
      }
      final annotations = {for (final e in listed.entries) e.key: e.value['annotations'] as Map};
      expect(annotations['delete_collection'], containsPair('destructiveHint', true));
      expect(annotations['import_asset_folder'], containsPair('openWorldHint', true));
      expect(annotations['create_content_folder'], containsPair('destructiveHint', false));
    });
  });
}

bool p(String path) => path.startsWith('/') || RegExp(r'^[A-Za-z]:').hasMatch(path);
