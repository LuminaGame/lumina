import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/core/property_editors/enum_field.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/details_widget.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_server_service.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_server_settings.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_tool.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../helpers/mcp_test_client.dart';
import '../helpers/temp_project.dart';

/// Level files (new / open with the unsaved-work guard),
/// Outliner folders, attach / detach and solo, multi-actor Details edits,
/// the level's World Partition, data layers, environment and navigation,
/// and every viewport toolbar setting — a real MCP client over HTTP against
/// a real editor on a real temp project with real imported props.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final assets = '${Directory.current.parent.path}/test-assets/Props';
  final cardGlb = File('$assets/Access_cards/access_card_blue.glb');
  final bananaGlb = File('$assets/Banana Bunch/banana_bunch_medium.glb');
  const mainLevel = 'contents/levels/L_Main.lmas';

  late Directory root;
  late Directory projectDir;
  late EditorViewModel vm;
  late McpServerService server;
  late McpTestClient client;
  late String card;
  late String banana;

  setUp(() async {
    root = Directory.systemTemp.createTempSync('lumina_mcp_level_');
    final configDir = Directory('${root.path}/config')..createSync();
    projectDir = Directory('${root.path}/YardProject')..createSync();
    const project = LuminaProject(projectName: 'YardProject', activeLevel: mainLevel);
    File('${projectDir.path}/YardProject.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
    Directory('${projectDir.path}/contents/levels').createSync(recursive: true);
    vm = EditorViewModel(initialProject: project, projectLocation: root.path, enableTimers: false, autoInitAssets: false);
    server = McpServerService(vm, configDir: configDir, settings: McpServerSettings.load(configDir: configDir));
    expect(await server.start(port: 0), isTrue);
    client = McpTestClient(server.url!, server.token);
    await client.handshake();
    await vm.ensureDefaultLevelAssets();
    expect(cardGlb.existsSync() && bananaGlb.existsSync(), isTrue, reason: 'test-assets must hold the card and the banana');
    await vm.processImportPipeline(sourceFilePath: cardGlb.path);
    await vm.processImportPipeline(sourceFilePath: bananaGlb.path);
    String meshOf(String name) =>
        vm.realAssets.firstWhere((a) => a.type == AssetType.filamesh && a.fileName.contains(name)).relativePath;
    card = ((await client.callTool('spawn_actor_from_asset', {'asset': meshOf('access_card_blue'), 'location': [100, 0, 0]}))
        .data['actor'] as Map)['id'] as String;
    banana = ((await client.callTool('spawn_actor_from_asset', {'asset': meshOf('banana_bunch_medium'), 'location': [300, 50, 20]}))
        .data['actor'] as Map)['id'] as String;
    // The level starts clean, so the level-switch tools are not refused.
    await client.callTool('save_level');
  });

  tearDown(() async {
    client.close();
    await server.stop();
    await vm.close();
    await deleteTempProject(root);
  });

  Future<McpToolReply> call(String tool, [Map<String, Object?> args = const {}]) => client.callTool(tool, args);
  Future<Map<String, Object?>> ok(String tool, [Map<String, Object?> args = const {}]) async {
    final r = await call(tool, args);
    expect(r.isError, isFalse, reason: '$tool: ${r.text}');
    return r.data;
  }

  Future<void> expectToolError(String tool, Map<String, Object?> args, Matcher message) async {
    try {
      final r = await call(tool, args);
      expect(r.isError, isTrue, reason: '$tool should fail: ${r.text}');
      expect(r.text, message);
    } on McpRpcError catch (e) {
      expect(e.message, message);
    }
  }

  int depth() => vm.transactions.history(limit: 1000).length;
  EditorActorNode node(String id) => vm.actors.firstWhere((a) => a.id == id);
  List<double> world(String id) {
    final out = [0.0, 0.0, 0.0];
    for (String? current = id; current != null; current = node(current).parentId) {
      final l = node(current).location;
      for (var i = 0; i < 3; i++) {
        out[i] += l[i];
      }
    }
    return out;
  }

  File levelFile(String name) => File('${projectDir.path}/contents/levels/$name.lmas');

  group('level files', () {
    test('list_level_templates lists empty, default and open_world', () async {
      final templates = ((await ok('list_level_templates'))['templates'] as List).cast<Map>();
      expect(templates.map((t) => t['id']), ['empty', 'default', 'open_world']);
      expect(templates.every((t) => (t['title'] as String).isNotEmpty && (t['description'] as String).isNotEmpty), isTrue);
    });

    test('new_level from open_world: file, active level, World Partition; list_levels; undo; an existing name is refused', () async {
      final created = await ok('new_level', {'name': 'L_AgentYard', 'template': 'open_world'});
      expect(created['active_level'], 'contents/levels/L_AgentYard.lmas');
      expect(levelFile('L_AgentYard').existsSync(), isTrue);
      expect((await ok('project_info'))['active_level'], 'contents/levels/L_AgentYard.lmas');
      final wp = (await ok('get_level_settings'))['world_partition'] as Map;
      expect(wp['enabled'], isTrue);
      expect(wp['cell_size'], 12800);

      final levels = ((await ok('list_levels'))['levels'] as List).cast<Map>();
      expect(levels.map((l) => l['name']), containsAll(['L_Main', 'L_AgentYard']));
      expect(levels.firstWhere((l) => l['name'] == 'L_AgentYard')['active'], isTrue);
      expect(levels.firstWhere((l) => l['name'] == 'L_Main')['active'], isFalse);
      expect(levels.firstWhere((l) => l['active'] == true), contains('is_dirty'));

      await ok('undo');
      expect(levelFile('L_AgentYard').existsSync(), isFalse);
      expect(vm.project.activeLevel, mainLevel);

      final before = levelFile('L_Main').readAsBytesSync();
      await expectToolError('new_level', {'name': 'L_Main'}, contains('already exists'));
      expect(levelFile('L_Main').readAsBytesSync(), before, reason: 'the existing level is untouched');
      expect(vm.project.activeLevel, mainLevel);
      await expectToolError('new_level', {'name': 'L_X', 'template': 'castle'}, allOf(contains('empty'), contains('open_world')));
    });

    test('open_level refuses unsaved work, saves or discards on request; unknown levels are listed; open_asset_editor guards too',
        () async {
      await ok('new_level', {'name': 'L_Other', 'template': 'empty'});
      final light = ((await ok('spawn_actor', {'type': 'PointLight', 'name': 'SavedLight'}))['actor'] as Map)['id'];
      await expectToolError('open_level', {'level': 'L_Main'}, allOf(contains('L_Other'), contains('unsaved')));
      expect(vm.project.activeLevel, 'contents/levels/L_Other.lmas');

      final saved = await ok('open_level', {'level': 'L_Main', 'if_dirty': 'save'});
      expect(saved['active_level'], mainLevel);
      expect(levelFile('L_Other').readAsStringSync(), contains('SavedLight'));
      expect(vm.actors.map((a) => a.name), isNot(contains('SavedLight')), reason: 'L_Main is open (ids $light are per level)');

      await ok('open_level', {'level': 'contents/levels/L_Other.lmas'});
      expect(vm.actors.map((a) => a.name), contains('SavedLight'));
      await ok('spawn_actor', {'type': 'PointLight', 'name': 'DroppedLight'});
      await ok('open_level', {'level': 'L_Main', 'if_dirty': 'discard'});
      expect(vm.project.activeLevel, mainLevel);
      // After a discard the freshly opened level still reads as
      // unsaved, so leaving it again needs if_dirty too.
      await ok('open_level', {'level': 'L_Other', 'if_dirty': 'discard'});
      expect(vm.actors.map((a) => a.name), isNot(contains('DroppedLight')));
      expect(vm.actors.map((a) => a.name), contains('SavedLight'));

      await expectToolError('open_level', {'level': 'nope'}, allOf(contains('L_Main'), contains('L_Other')));

      // open_asset_editor on a level applies the same guard.
      await ok('spawn_actor', {'type': 'PointLight', 'name': 'Pending'});
      await expectToolError('open_asset_editor', {'asset': mainLevel}, allOf(contains('L_Other'), contains('unsaved')));
      await ok('open_asset_editor', {'asset': mainLevel, 'if_dirty': 'save'});
      expect(vm.project.activeLevel, mainLevel);
      expect(levelFile('L_Other').readAsStringSync(), contains('Pending'));
    });

    test('if_dirty "discard" is reviewed as destructive by the approval chain', () async {
      await ok('spawn_actor', {'type': 'PointLight'});
      await ok('new_level', {'name': 'L_Side', 'if_dirty': 'save'});
      await ok('spawn_actor', {'type': 'PointLight'});
      server.settings.setMaxRisk(McpToolRisk.mutating);
      try {
        final denied = await call('open_level', {'level': 'L_Main', 'if_dirty': 'discard'});
        expect(denied.isError, isTrue);
        expect(denied.text, contains('"risk":"destructive"'));
        expect(vm.project.activeLevel, 'contents/levels/L_Side.lmas');
        await ok('open_level', {'level': 'L_Main', 'if_dirty': 'save'});
        expect(vm.project.activeLevel, mainLevel);
      } finally {
        server.settings.setMaxRisk(McpToolRisk.external);
      }
    });
  });

  group('outliner', () {
    test('create_folder wraps in one undo step; names are unique; cycles skipped; rename and delete a folder', () async {
      final cardWorld = world(card), bananaWorld = world(banana);
      final d0 = depth();
      final folder = await ok('create_folder', {'name': 'Props', 'wrap_ids': [card, banana]});
      final folderId = folder['folder_id'] as String;
      expect(folder['name'], 'Props');
      expect(node(folderId).type, 'Folder');
      expect(node(card).parentId, folderId);
      expect(node(banana).parentId, folderId);
      expect(depth(), d0 + 1);
      expect(vm.isOutlinerExpanded(folderId), isTrue);

      await ok('undo');
      expect(vm.actors.any((a) => a.id == folderId), isFalse);
      expect(node(card).parentId, isNull);
      expect(world(card), cardWorld);
      expect(world(banana), bananaWorld);
      await ok('redo');

      final second = await ok('create_folder', {'name': 'Props'});
      expect(second['name'], isNot('Props'));
      expect(second['name'], startsWith('Props'));
      expect(node(second['folder_id'] as String).parentId, isNull);

      final child = (await ok('create_folder', {'name': 'Sub', 'parent_folder_id': folderId}))['folder_id'] as String;
      final cycle = await ok('move_to_folder', {'ids': [folderId], 'folder_id': child});
      expect(cycle['moved'], isEmpty);
      expect(((cycle['skipped'] as List).single as Map)['reason'], contains('cycle'));

      await ok('rename_actor', {'id': folderId, 'name': 'Yard'});
      expect(node(folderId).name, 'Yard');
      await ok('delete_actor', {'id': folderId, 'keep_children': true});
      expect(vm.actors.any((a) => a.id == folderId), isFalse);
      expect(node(card).parentId, isNull);
      expect(node(banana).parentId, isNull);
      expect(world(card), cardWorld);
    });

    test('move_to_folder moves, keeps world locations and selects the moved actors', () async {
      final folderId = (await ok('create_folder', {'name': 'Crates'}))['folder_id'] as String;
      final bananaWorld = world(banana);
      final moved = await ok('move_to_folder', {'ids': [card, banana], 'folder_id': folderId});
      expect(moved['moved'], unorderedEquals([card, banana]));
      expect(world(banana), bananaWorld);
      expect(vm.selectedActorIds, {card, banana});
      final again = await ok('move_to_folder', {'ids': [card], 'folder_id': folderId});
      expect(((again['skipped'] as List).single as Map)['reason'], contains('already'));
      await expectToolError('move_to_folder', {'ids': [card], 'folder_id': banana}, contains('not a folder'));
    });

    test('attach_actors keeps the world location; a folder parent is skipped; detach_actors; one undo step each', () async {
      final bananaWorld = world(banana);
      final d0 = depth();
      final attached = await ok('attach_actors', {'ids': [banana], 'parent_id': card});
      expect(attached['attached'], [banana]);
      expect(node(banana).parentId, card);
      expect(world(banana), bananaWorld);
      expect(node(banana).location, isNot(bananaWorld), reason: 'the stored location is now relative to the card');
      expect(depth(), d0 + 1);

      final folderId = (await ok('create_folder', {'name': 'F'}))['folder_id'] as String;
      final toFolder = await ok('attach_actors', {'ids': [card], 'parent_id': folderId});
      expect(toFolder['attached'], isEmpty);
      expect(((toFolder['skipped'] as List).single as Map)['reason'], contains('folder'));
      final cycle = await ok('attach_actors', {'ids': [card], 'parent_id': banana});
      expect(((cycle['skipped'] as List).single as Map)['reason'], contains('cycle'));

      final d1 = depth();
      final detached = await ok('detach_actors', {'ids': [banana]});
      expect(detached['moved'], [banana]);
      expect(node(banana).parentId, isNull);
      expect(world(banana), bananaWorld);
      expect(depth(), d1 + 1);
      await ok('undo');
      expect(node(banana).parentId, card);
      expect(world(banana), bananaWorld);
    });

    test('solo_actor shows only the actor and its family; clear_solo restores the exact map; solo while solo switches', () async {
      await ok('attach_actors', {'ids': [banana], 'parent_id': card});
      final lamp = ((await ok('spawn_actor', {'type': 'PointLight'}))['actor'] as Map)['id'] as String;
      await ok('set_actor_property', {'id': lamp, 'property': 'visible', 'value': false});
      final before = {for (final a in vm.actors) a.id: a.isVisible};

      final solo = await ok('solo_actor', {'id': card});
      expect(solo['solo_active'], isTrue);
      expect(solo['visible_ids'], unorderedEquals([card, banana]));
      for (final a in vm.actors) {
        expect(a.isVisible, a.id == card || a.id == banana, reason: a.name);
      }

      final cleared = await ok('clear_solo');
      expect(cleared['solo_active'], isFalse);
      expect({for (final a in vm.actors) a.id: a.isVisible}, before);

      await ok('solo_actor', {'id': card});
      final switched = await ok('solo_actor', {'id': lamp});
      expect(switched['visible_ids'], [lamp]);
      await ok('clear_solo');
      expect({for (final a in vm.actors) a.id: a.isVisible}, before);
      await expectToolError('clear_solo', {}, contains('No solo'));
    });
  });

  group('details (multi-edit)', () {
    test('get_multi_edit, set_actors_transform (absolute, relative axis), locked actors skipped', () async {
      final view = await ok('get_multi_edit', {'ids': [card, banana]});
      expect(vm.selectedActorIds, {card, banana});
      expect((view['location'] as Map)['mixed'], [true, true, true]);
      expect((view['scale'] as Map)['mixed'], [false, false, false]);

      final d0 = depth();
      await ok('set_actors_transform', {'ids': [card, banana], 'scale': [2, 2, 2]});
      expect(node(card).scale, [2, 2, 2]);
      expect(node(banana).scale, [2, 2, 2]);
      expect(depth(), d0 + 1);

      final zCard = node(card).location[2], zBanana = node(banana).location[2];
      final xBanana = node(banana).location[0];
      await ok('set_actors_transform', {'ids': [card, banana], 'location': [0, 0, 100], 'relative': true, 'axis': 2});
      expect(node(card).location[2], zCard + 100);
      expect(node(banana).location[2], zBanana + 100);
      expect(node(banana).location[0], xBanana, reason: 'one axis only');
      await ok('undo');
      expect(node(card).location[2], zCard);

      await ok('set_actor_property', {'id': banana, 'property': 'locked', 'value': true});
      final r = await ok('set_actors_transform', {'ids': [card, banana], 'rotation': [0, 0, 45]});
      expect(node(card).rotation[2], 45);
      expect(node(banana).rotation[2], 0);
      expect(((r['skipped'] as List).single as Map)['id'], banana);
      expect(((r['skipped'] as List).single as Map)['reason'], contains('locked'));
    });

    test('component property, enabled and remove across two PointLights: one undo step each', () async {
      String light(Map<String, Object?> r) => (r['actor'] as Map)['id'] as String;
      final a = light(await ok('spawn_actor', {'type': 'PointLight', 'location': [0, 0, 200]}));
      final b = light(await ok('spawn_actor', {'type': 'PointLight', 'location': [200, 0, 200]}));
      const type = 'LuminaPointLightComponent';
      Map<String, dynamic> props(String id) => node(id).components.firstWhere((c) => c.type == type).properties;

      final d0 = depth();
      final set = await ok('set_actors_component_property', {'ids': [a, b], 'component_type': type, 'property': 'intensity', 'value': 3000});
      expect(set['changed'], unorderedEquals([a, b]));
      expect(props(a)['intensity'], 3000);
      expect(props(b)['intensity'], 3000);
      expect(depth(), d0 + 1);
      final view = await ok('get_multi_edit', {'ids': [a, b]});
      final block = (view['components'] as List).cast<Map>().firstWhere((c) => c['component_type'] == type);
      expect((block['properties'] as List).cast<Map>().firstWhere((p) => p['id'] == 'intensity')['value'], 3000);
      await expectToolError('set_actors_component_property',
          {'ids': [a, b], 'component_type': type, 'property': 'nope', 'value': 1}, contains('intensity'));

      await ok('set_actors_component_enabled', {'ids': [a, b], 'component_type': type, 'enabled': false});
      expect(node(a).components.firstWhere((c) => c.type == type).enabled, isFalse);
      expect(node(b).components.firstWhere((c) => c.type == type).enabled, isFalse);
      await ok('undo');
      expect(node(a).components.firstWhere((c) => c.type == type).enabled, isTrue);
      expect(node(b).components.firstWhere((c) => c.type == type).enabled, isTrue);

      final d1 = depth();
      await ok('remove_actors_component', {'ids': [a, b], 'component_type': type});
      expect(node(a).components.where((c) => c.type == type), isEmpty);
      expect(node(b).components.where((c) => c.type == type), isEmpty);
      expect(depth(), d1 + 1);
      await ok('undo');
      expect(node(a).components.where((c) => c.type == type), hasLength(1));
      expect(node(b).components.where((c) => c.type == type), hasLength(1));
    });
  });

  group('level settings', () {
    test('World Partition and data layers: one level undo step each, saved into the .lmas; bad states listed', () async {
      await ok('set_world_partition', {'enabled': true, 'cell_size': 25600, 'loading_range': 50000});
      var wp = (await ok('get_level_settings'))['world_partition'] as Map;
      expect(wp['enabled'], isTrue);
      expect(wp['cell_size'], 25600);
      expect(wp['loading_range'], 50000);
      expect(vm.selectedActorIds, isEmpty, reason: 'the Details panel shows the level settings');
      final cells = ((await ok('get_level_settings'))['actor_cells'] as List).cast<Map>();
      expect(cells.firstWhere((c) => c['id'] == card)['cell'], isNotNull);

      final d0 = depth();
      final added = await ok('add_data_layer', {'name': 'Interiors'});
      expect(added['name'], 'Interiors');
      expect(depth(), d0 + 1);
      await ok('set_data_layer', {'layer': 'Interiors', 'initial_state': 'loaded'});
      expect(depth(), d0 + 2);
      wp = (await ok('get_level_settings'))['world_partition'] as Map;
      expect(((wp['data_layers'] as List).single as Map)['initial_state'], 'loaded');
      await expectToolError('set_data_layer', {'layer': 'Interiors', 'initial_state': 'on'},
          allOf(contains('unloaded'), contains('loaded'), contains('activated')));

      await ok('save_level');
      final saved = jsonDecode(levelFile('L_Main').readAsStringSync()) as Map;
      final section = (saved['metadata'] as Map)['worldPartition'] as Map;
      expect(section['cellSize'], 25600);
      expect(((section['dataLayers'] as List).single as Map)['name'], 'Interiors');

      await ok('remove_data_layer', {'layer': 0});
      expect(vm.worldPartitionDataLayers, isEmpty);
      expect(depth(), d0 + 3);
      await ok('undo');
      expect(vm.worldPartitionDataLayers.single['initialState'], 'loaded');
      await ok('undo');
      expect(vm.worldPartitionDataLayers.single['initialState'], 'unloaded');
      await ok('undo');
      expect(vm.worldPartitionDataLayers, isEmpty);
    });

    testWidgets('the Details level panel shows the agent\'s data layer state', (tester) async {
      await tester.runAsync(() async {
        await ok('set_world_partition', {'enabled': true});
        await ok('add_data_layer', {'name': 'Interiors'});
        await ok('set_data_layer', {'layer': 0, 'initial_state': 'loaded'});
      });
      await tester.pumpWidget(ShadcnApp(
        theme: luminaEditorTheme(),
        home: SizedBox(width: 340, height: 900, child: DetailsWidget(viewModel: vm)),
      ));
      await tester.pump(const Duration(milliseconds: 200));
      final field = tester.widget<EnumField>(find.byKey(const ValueKey('wp_layer_state_0')));
      expect(field.value, 'loaded');
      await tester.pumpWidget(const SizedBox());
    });

    test('set_level_environment: fields held, level section written, lighting tab open, one undo; bad sky mode listed', () async {
      final before = (await ok('get_level_settings'))['environment'] as Map;
      final r = await ok('set_level_environment', {'time_of_day': 18.5, 'fog_enabled': true, 'fog_density': 0.05, 'exposure': 1.2});
      expect(r['open_tab'], 'lighting');
      final env = (await ok('get_level_settings'))['environment'] as Map;
      expect(env['time_of_day'], 18.5);
      expect(env['fog_enabled'], isTrue);
      expect(env['fog_density'], 0.05);
      expect(env['exposure'], 1.2);
      final section = vm.levelEnvironment;
      expect((section['sun'] as Map)['timeOfDay'], 18.5);
      expect((section['postProcess'] as Map)['fogEnabled'], isTrue);
      expect((section['postProcess'] as Map)['exposure'], 1.2);
      expect(vm.currentTab.category, 'lighting');

      await ok('undo');
      final undone = (await ok('get_level_settings'))['environment'] as Map;
      expect(undone['time_of_day'], before['time_of_day']);
      expect(undone['fog_enabled'], before['fog_enabled']);
      expect(undone['exposure'], before['exposure']);

      await expectToolError('set_level_environment', {'sky_mode': 'hdr'}, allOf(contains('color'), contains('environment')));
      await ok('reset_level_environment');
      expect(((await ok('get_level_settings'))['environment'] as Map)['time_of_day'], isNot(18.5));
    });

    test('build_navigation: refused without a volume; a real bake over a NavMeshBoundsVolume', () async {
      await expectToolError('build_navigation', {}, contains('Add a NavMeshBoundsVolume first'));
      await ok('spawn_actor', {'type': 'NavMeshBoundsVolume'});
      final settings = await ok('set_navigation_settings', {'agent_radius': 40, 'cell_size': 20});
      expect((settings['config'] as Map)['agent_radius'], 40);
      expect(vm.currentTab.category, 'navmesh');
      final built = await ok('build_navigation');
      expect(built['walkable_cells'] as int, greaterThan(0));
      expect(built['volume_count'], 1);
      expect(built['cell_size'], 20);
      final nav = (await ok('get_level_settings'))['navigation'] as Map;
      expect((nav['volumes'] as List), hasLength(1));
      expect((nav['last_build'] as Map)['walkable_cells'], built['walkable_cells']);
      final log = await ok('read_output_log', {'contains': 'Build Navigation requested'});
      expect(log['matched'], greaterThan(0));
    });
  });

  group('viewport settings', () {
    test('snapping, show flags, buffer visualization, quality and camera speed; none is an undo step', () async {
      final d0 = depth();
      await ok('set_viewport_snapping',
          {'translate_enabled': true, 'translate_step': 50, 'rotate_step': 15, 'grid_step': 100, 'grid_visible': true});
      var s = await ok('get_viewport_settings');
      expect((s['snapping'] as Map)['translate_enabled'], isTrue);
      expect((s['snapping'] as Map)['translate_step'], 50);
      expect((s['snapping'] as Map)['rotate_step'], 15);
      expect(s['grid_step'], 100);
      expect(s['grid_visible'], isTrue);
      await expectToolError('set_viewport_snapping', {'translate_step': 7}, allOf(contains('50'), contains('100')));

      await ok('set_show_flags', {'flags': {'Collision': true, 'Grid': false}});
      expect(vm.showFlags['Collision'], isTrue);
      expect(vm.showFlags['Grid'], isFalse);
      await expectToolError('set_show_flags', {'flags': {'Fog': true}}, contains('Selection Bounds'));

      await ok('set_buffer_visualization', {'buffer': 'Roughness'});
      s = await ok('get_viewport_settings');
      expect(s['view_mode'], 'Buffer');
      expect(s['buffer_visualization'], 'Roughness');

      await ok('set_viewport_quality', {'preset': 'epic', 'resolution_scale': 150, 'ssao': true});
      final q = (await ok('get_viewport_settings'))['quality'] as Map;
      expect(q['preset'], 'epic');
      expect(q['resolution_scale'], 150);
      expect(q['ssao'], isTrue);
      await expectToolError('set_viewport_quality', {'resolution_scale': 300}, contains('50'));

      await ok('set_camera', {'speed_level': 6});
      expect((await ok('get_camera'))['speed_level'], 6);
      expect(depth(), d0, reason: 'viewport settings are not undo steps');
      await vm.flushQualitySettings();
    });
  });

  group('safety and listing', () {
    const newTools = {
      'list_levels': ('readOnly', 'level'), 'list_level_templates': ('readOnly', 'level'), //
      'new_level': ('mutating', 'level'), 'open_level': ('mutating', 'level'),
      'create_folder': ('mutating', 'outliner'), 'move_to_folder': ('mutating', 'outliner'),
      'attach_actors': ('mutating', 'outliner'), 'detach_actors': ('mutating', 'outliner'),
      'solo_actor': ('mutating', 'outliner'), 'clear_solo': ('mutating', 'outliner'),
      'get_multi_edit': ('readOnly', 'details'), 'set_actors_transform': ('mutating', 'details'),
      'set_actors_component_property': ('mutating', 'details'), 'set_actors_component_enabled': ('mutating', 'details'),
      'remove_actors_component': ('destructive', 'details'),
      'get_level_settings': ('readOnly', 'level'), 'set_world_partition': ('mutating', 'level'),
      'add_data_layer': ('mutating', 'level'), 'set_data_layer': ('mutating', 'level'), 'remove_data_layer': ('mutating', 'level'),
      'set_level_environment': ('mutating', 'level'), 'reset_level_environment': ('mutating', 'level'),
      'set_navigation_settings': ('mutating', 'level'), 'build_navigation': ('mutating', 'level'),
      'get_viewport_settings': ('readOnly', 'view'), 'set_viewport_snapping': ('editorState', 'view'),
      'set_show_flags': ('editorState', 'view'), 'set_buffer_visualization': ('editorState', 'view'),
      'set_viewport_quality': ('editorState', 'view'),
    };

    test('every mutating tool is refused while Play runs', () async {
      final refused = <String, Map<String, Object?>>{
        'new_level': {'name': 'L_Play'},
        'open_level': {'level': 'L_Main'},
        'create_folder': {'name': 'F'},
        'move_to_folder': {'ids': [card]},
        'attach_actors': {'ids': [banana], 'parent_id': card},
        'detach_actors': {'ids': [banana]},
        'solo_actor': {'id': card},
        'clear_solo': {},
        'set_actors_transform': {'ids': [card], 'scale': [2, 2, 2]},
        'set_actors_component_property': {'ids': [card], 'component_type': 'X', 'property': 'p', 'value': 1},
        'set_actors_component_enabled': {'ids': [card], 'component_type': 'X', 'enabled': false},
        'remove_actors_component': {'ids': [card], 'component_type': 'X'},
        'set_world_partition': {'enabled': true},
        'add_data_layer': {'name': 'L'},
        'set_data_layer': {'layer': 0, 'name': 'M'},
        'remove_data_layer': {'layer': 0},
        'set_level_environment': {'exposure': 1},
        'reset_level_environment': {},
        'set_navigation_settings': {'cell_size': 20},
        'build_navigation': {},
      };
      expect(refused.keys.toSet(), {
        for (final e in newTools.entries)
          if (e.value.$1 == 'mutating' || e.value.$1 == 'destructive') e.key,
      });
      vm.transactions.isFrozen = true;
      try {
        for (final e in refused.entries) {
          await expectToolError(e.key, e.value, contains('Stop Play first'));
        }
      } finally {
        vm.transactions.isFrozen = false;
      }
    });

    test('tools/list: each new tool with a description, a schema, its risk and groups', () async {
      final tools = {for (final t in await client.listTools()) t['name'] as String: t};
      for (final e in newTools.entries) {
        final t = tools[e.key];
        expect(t, isNotNull, reason: e.key);
        expect((t!['description'] as String).length, greaterThan(40), reason: e.key);
        expect((t['inputSchema'] as Map)['type'], 'object', reason: e.key);
        final meta = t['_meta'] as Map;
        expect(meta['lumina/risk'], e.value.$1, reason: e.key);
        expect(meta['lumina/groups'], contains(e.value.$2), reason: e.key);
      }
      final setCamera = tools['set_camera']!;
      expect(((setCamera['inputSchema'] as Map)['properties'] as Map), contains('speed_level'));
      for (final gap in ['data layer', 'surface snap', 'grid extent', 'renaming or deleting a level', 'no relative attach']) {
        expect(tools.values.any((t) => (t['description'] as String).toLowerCase().contains(gap)), isTrue,
            reason: 'the "$gap" gap is named');
      }
    });
  });
}
