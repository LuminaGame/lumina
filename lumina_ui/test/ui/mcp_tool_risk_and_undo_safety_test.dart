import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_protocol.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_server_service.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_server_settings.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_tool.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/material_editor_view_model.dart';

import '../helpers/mcp_test_client.dart';
import '../helpers/temp_project.dart';

/// Denies rename_actor for the client named "probe" (a real policy class,
/// registered as a plugin would register one).
class _DenyRenameForProbe implements McpApprovalPolicy {
  @override
  McpApprovalDecision review(McpCallContext call) => call.tool == 'rename_actor' && call.clientName == 'probe'
      ? const McpApprovalDecision.deny('probe may not rename actors')
      : const McpApprovalDecision.allow();
}

class _ThrowingPolicy implements McpApprovalPolicy {
  @override
  McpApprovalDecision review(McpCallContext call) => throw StateError('policy exploded');
}

/// Risk levels, groups, honest annotations, the approval
/// chain, agent-attributed undo and recoverable asset operations — a real
/// MCP client over HTTP against a real editor on a real temp project.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final assets = '${Directory.current.parent.path}/test-assets/Props/Barrels';
  final redBarrel = File('$assets/fuel_barrel_red.glb');
  final dentedBarrel = File('$assets/dented_barrel.glb');

  late Directory root;
  late Directory configDir;
  late EditorViewModel vm;
  late McpServerService server;
  late McpTestClient client;

  const levelPath = 'contents/levels/L_Main.lmas';

  setUp(() async {
    root = Directory.systemTemp.createTempSync('lumina_mcp_risk_');
    configDir = Directory('${root.path}/config')..createSync();
    final projectDir = Directory('${root.path}/RiskProject')..createSync();
    const project = LuminaProject(projectName: 'RiskProject', activeLevel: levelPath);
    File('${projectDir.path}/RiskProject.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
    Directory('${projectDir.path}/contents/levels').createSync(recursive: true);
    vm = EditorViewModel(initialProject: project, projectLocation: root.path, enableTimers: false, autoInitAssets: false);
    server = McpServerService(vm, configDir: configDir, settings: McpServerSettings.load(configDir: configDir));
    expect(await server.start(port: 0), isTrue);
    client = McpTestClient(server.url!, server.token);
    await client.handshake();
  });

  tearDown(() async {
    client.close();
    await server.stop();
    await vm.close();
    await deleteTempProject(root);
  });

  McpTestClient connect({String query = '', String? name}) {
    final c = McpTestClient('${server.url!}$query', server.token);
    addTearDown(c.close);
    return c;
  }

  Map<String, Object?> jsonText(McpToolReply r) => Map<String, Object?>.from(jsonDecode(r.text) as Map);

  const expectedReadOnly = {
    'project_info', 'list_actors', 'get_actor', 'list_actor_types', 'undo_state', 'list_assets', 'get_material_source',
    'get_material_issues', 'list_blueprint_nodes', 'get_blueprint', 'get_blueprint_diagnostics', 'pie_status',
    'viewport_screenshot', 'get_camera', 'read_output_log', 'list_tool_groups', 'list_trash', 'list_component_types', //
    // File and code tools
    'fs_list', 'fs_read', 'fs_search', 'fs_history', 'dart_analyze',
    // Level and viewport tools
    'list_levels', 'list_level_templates', 'get_multi_edit', 'get_level_settings', 'get_viewport_settings',
    // Project, build and playtest tools
    'get_project_settings', 'get_editor_preferences', 'get_build_settings', 'get_build_status', 'list_jobs', 'get_job',
    'wait_job', 'standalone_status', 'pie_get_actors',
    // Content, plugin and source control tools
    'list_content_folders', 'list_collections', 'list_plugins', 'marketplace_status', 'marketplace_search',
    'marketplace_get_listing', 'marketplace_list_installed', 'source_control_status', 'source_control_history',
    // UMG and material graph tools
    'list_widget_types', 'get_widget_tree', 'list_material_nodes', 'get_material_graph', 'asset_editor_screenshot',
    // Animation, sequencer and particle tools
    'get_anim_blueprint', 'get_anim_graph', 'get_blend_space', 'get_animation', 'get_skeleton', 'get_skeletal_material_slots',
    'get_vertex_weights', 'get_sequence', 'get_particle_system',
    // Asset editor tools
    'get_landscape', 'get_static_mesh', 'get_texture', 'get_physics_asset', 'validate_physics_asset', 'get_audio',
    'probe_audio_attenuation', 'get_enum', 'get_interface',
  };
  const expectedEditorState = {
    'select_actors', 'clear_selection', 'open_asset_editor', 'select_tab', 'set_camera', 'focus_actor', 'frame_level',
    'start_pie', 'stop_pie', 'pause_pie', 'resume_pie', 'step_pie', 'clear_output_log', //
    'set_viewport_snapping', 'set_show_flags', 'set_buffer_visualization', 'set_viewport_quality', // Viewport settings
    // Playtest
    'eject_pie', 'possess_pie', 'pie_key', 'pie_axis', 'pie_mouse_move', 'pie_action', 'pie_click', 'pie_type_text',
    'pie_advance', 'pie_play_for', 'stop_standalone', 'cancel_job',
    'set_widget_designer', // UMG designer
    // Previews and scrubbing change what the user sees, not the document
    'anim_blueprint_preview', 'set_blend_space_preview', 'animation_preview', 'scrub_sequence', 'stop_sequence',
    'particle_preview',
    'set_texture_view', 'set_static_mesh_preview_lod', // View settings
  };

  group('risk, groups and annotations', () {
    test('the risk table: 69 read-only, 38 editor state, 234 edits, 24 destructive, 7 external; every tool has known groups and _meta',
        () async {
      final tools = await client.listTools();
      expect(tools, hasLength(372));
      Set<String> withRisk(String r) => {
            for (final t in tools)
              if ((t['_meta'] as Map)['lumina/risk'] == r) t['name'] as String,
          };
      expect(withRisk('readOnly'), expectedReadOnly);
      expect(withRisk('editorState'), expectedEditorState);
      expect(withRisk('mutating'), hasLength(234));
      expect(withRisk('external'), {
        'set_widget_library', 'start_build', 'launch_web_build', 'play_standalone', //
        'create_plugin', 'marketplace_add_to_library', 'marketplace_install', // Plugins and marketplace
      });
      expect(withRisk('mutating'), containsAll(['restore_asset', 'set_material_source', 'undo', 'redo', 'spawn_actor']));
      expect(withRisk('destructive'), {
        'delete_asset', 'remove_actor_component', 'remove_blueprint_component', 'reset_blueprint_components', //
        'delete_blueprint_variable', 'delete_blueprint_function', 'delete_blueprint_local_variable', 'delete_blueprint_macro',
        'delete_blueprint_dispatcher', 'remove_blueprint_interface', 'remove_timeline_track', 'fs_delete',
        'remove_actors_component',
        'delete_content_folder', 'clear_derived_data_cache', 'source_control_revert', // Content and source control
        // Asset editors
        'create_landscape', 'remove_foliage_layer', 'remove_static_mesh_lod', 'remove_physics_body',
        'remove_physics_constraint', 'remove_enum_value', 'remove_interface_function', 'save_enum',
      });
      for (final t in tools) {
        final groups = ((t['_meta'] as Map)['lumina/groups'] as List).cast<String>();
        expect(groups, isNotEmpty, reason: '${t['name']}');
        expect(McpToolGroups.known.containsAll(groups), isTrue, reason: '${t['name']}: $groups');
      }
    });

    test('annotations follow the risk and what the handler does', () async {
      final tools = {for (final t in await client.listTools()) t['name']: (t['annotations'] as Map)};
      expect(tools['clear_selection'], containsPair('readOnlyHint', false));
      expect(tools['clear_selection'], containsPair('destructiveHint', false));
      expect(tools['clear_selection'], containsPair('idempotentHint', true));
      expect(tools['set_actor_transform'], containsPair('destructiveHint', false));
      expect(tools['set_actor_transform'], containsPair('idempotentHint', true));
      expect(tools['delete_actor'], containsPair('destructiveHint', true));
      expect(tools['spawn_actor'], containsPair('idempotentHint', false));
      expect(tools['import_asset'], containsPair('openWorldHint', true));
      expect(tools['list_actors'], containsPair('readOnlyHint', true));
      expect(tools['start_pie'], containsPair('idempotentHint', false));
      final destructive = [for (final e in tools.entries) if (e.value['destructiveHint'] == true) e.key]..sort();
      expect(destructive, [
        'clear_derived_data_cache', 'create_landscape', 'create_plugin', // Content (destructive), plugins (external), landscape
        'delete_actor',
        'delete_anim_state', 'delete_anim_transition', 'delete_anim_variable', // Animation
        'delete_asset', 'delete_blueprint_dispatcher', 'delete_blueprint_function', //
        'delete_blueprint_local_variable', 'delete_blueprint_macro', 'delete_blueprint_variable',
        'delete_collection', 'delete_content_folder', // Content (removes a list entry; to the trash)
        'delete_particle_emitter', 'delete_sequencer_key', 'delete_sequencer_track', // Particles and sequencer
        'edit_project_input', // remove_action / remove_context / remove_mapping
        'fs_delete', 'launch_web_build',
        'marketplace_add_to_library', 'marketplace_install', // External
        'play_standalone', // External
        'remove_actor_component', 'remove_actors_component',
        'remove_anim_graph_node', 'remove_anim_graph_wire', 'remove_animation_curve', 'remove_animation_curve_key', // Animation
        'remove_animation_notify', 'remove_blend_space_sample', // Animation
        'remove_blueprint_component', 'remove_blueprint_interface', 'remove_blueprint_node', 'remove_blueprint_wire', 'remove_data_layer',
        'remove_enum_value', 'remove_foliage_layer', 'remove_interface_function', // Asset editors
        'remove_material_node', 'remove_material_wire', // Material graph
        'remove_particle_burst', 'remove_particle_color_stop', 'remove_particle_size_point', // Particles
        'remove_physics_body', 'remove_physics_constraint', // Physics asset
        'remove_skeletal_socket', // Skeleton
        'remove_static_mesh_lod', // Static mesh
        'remove_timeline_track', 'remove_widget', 'reset_blueprint_components',
        'save_enum', // Rewires every Switch on the enum project-wide
        'set_widget_library', 'source_control_revert', 'start_build', // External; 08: revert
      ]);
    });

    test('no read-only tool records a transaction or changes the selection', () async {
      await client.callTool('spawn_actor', {'type': 'PointLight'});
      final actor = vm.actors.last;
      vm.selectActors([actor.id]);
      await client.callTool('create_asset', {'type': 'filamat', 'name': 'M_Read'});
      await client.callTool('create_asset', {'type': 'actor', 'name': 'BP_Read', 'parent_class': 'LuminaActor'});
      final history = vm.transactions.history().map((h) => h.label).toList();
      final selection = vm.selectedActorIds.toSet();
      final samples = <String, Object?>{
        'id': actor.id,
        'asset': 'contents/materials/M_Read.lmas',
      };
      const blueprintTools = {'get_blueprint', 'get_blueprint_diagnostics', 'list_blueprint_nodes'};
      for (final t in server.tools.tools.where((t) => t.readOnly)) {
        final required = ((t.inputSchema['required'] as List?) ?? const []).cast<String>();
        final args = {
          for (final r in required) r: (r == 'asset' && blueprintTools.contains(t.name)) ? 'contents/blueprints/BP_Read.lmas' : samples[r],
        };
        try {
          await client.callTool(t.name, args);
        } on McpRpcError {
          // A missing optional context is fine; what matters is nothing changed.
        }
        expect(vm.transactions.history().map((h) => h.label).toList(), history, reason: '${t.name} recorded an undo step');
        expect(vm.selectedActorIds.toSet(), selection, reason: '${t.name} changed the selection');
      }
    });

    test('the registry refuses a tool with no group, an unknown group, or a never-exposed entry point', () {
      final registry = McpToolRegistry();
      McpTool tool({Set<String> groups = const {McpToolGroups.level}, Set<String> wraps = const {}}) => McpTool(
            name: 'probe_tool',
            description: 'probe',
            inputSchema: McpSchema.object(const {}),
            handler: (_) => McpToolResult.text('ok'),
            risk: McpToolRisk.mutating,
            groups: groups,
            wraps: wraps,
          );
      expect(() => registry.register(tool(groups: const {})), throwsStateError);
      expect(() => registry.register(tool(groups: const {'nope'})), throwsStateError);
      expect(
        () => registry.register(tool(wraps: const {'editor.restart'})),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('editor.restart'))),
      );
      for (final t in server.tools.tools) {
        expect(t.wraps.intersection(McpExposure.neverExpose), isEmpty, reason: t.name);
      }
    });

    test('groups: ?groups= on the URL, params.groups, -32602 for unknown ones, calls outside the groups still run', () async {
      final level = connect(query: '?groups=level');
      await level.handshake();
      expect(await level.listTools(), hasLength(35), reason: '26 level (13 actor, 4 level file, 9 level settings) + 9 core (4 job tools)');
      final levelView = connect(query: '?groups=level,view');
      await levelView.handshake();
      expect(await levelView.listTools(), hasLength(47), reason: '26 level + 12 view (with asset_editor_screenshot) + 9 core');
      expect(await client.listTools(groups: ['blueprint']), hasLength(50), reason: '41 Blueprint (9 graph, 31 member, list_component_types) + 9 core');
      // Settings (Project Settings + Editor Preferences) and build (run_codegen is in code and build).
      expect(await client.listTools(groups: ['settings']), hasLength(19), reason: '10 settings + 9 core');
      expect(await client.listTools(groups: ['build']), hasLength(15), reason: '6 build + 9 core');
      // Content (Content Browser, Marketplace, DDC) and scm.
      expect(await client.listTools(groups: ['content']), hasLength(30), reason: '14 Content Browser + 6 Marketplace + DDC + 9 core');
      expect(await client.listTools(groups: ['scm']), hasLength(15), reason: '6 source control + 9 core');
      // The UMG designer and the material graph (asset_editor_screenshot is in both and in view).
      expect(await client.listTools(groups: ['umg']), hasLength(26), reason: '16 UMG + asset_editor_screenshot + 9 core');
      // The animation editors, the Sequencer and particles (each with asset_editor_screenshot).
      expect(await client.listTools(groups: ['animation']), hasLength(66),
          reason: '22 Anim Blueprint + 9 Blend Space + 12 Animation + 13 Skeletal Mesh + asset_editor_screenshot + 9 core');
      expect(await client.listTools(groups: ['sequencer']), hasLength(24), reason: '14 Sequencer + asset_editor_screenshot + 9 core');
      expect(await client.listTools(groups: ['particle']), hasLength(29), reason: '19 Particle + asset_editor_screenshot + 9 core');
      expect(await client.listTools(groups: ['material_graph']), hasLength(21), reason: '11 material graph + asset_editor_screenshot + 9 core');
      // The asset editors, each with asset_editor_screenshot, and their umbrella.
      expect(await client.listTools(groups: ['landscape']), hasLength(21), reason: '11 Landscape + asset_editor_screenshot + 9 core');
      expect(await client.listTools(groups: ['static_mesh']), hasLength(19), reason: '9 Static Mesh + asset_editor_screenshot + 9 core');
      expect(await client.listTools(groups: ['texture']), hasLength(15), reason: '5 Texture + asset_editor_screenshot + 9 core');
      expect(await client.listTools(groups: ['physics_asset']), hasLength(21), reason: '11 Physics Asset + asset_editor_screenshot + 9 core');
      expect(await client.listTools(groups: ['audio']), hasLength(14), reason: '4 Sound + asset_editor_screenshot + 9 core');
      expect(await client.listTools(groups: ['blueprint_types']), hasLength(22), reason: '12 Enumeration / Interface + asset_editor_screenshot + 9 core');
      expect(await client.listTools(groups: ['asset_editors']), hasLength(62), reason: '52 + asset_editor_screenshot + 9 core');
      final bad = connect(query: '?groups=nope');
      await expectLater(
        bad.handshake(),
        throwsA(isA<McpRpcError>()
            .having((e) => e.code, 'code', -32602)
            .having((e) => e.message, 'message', allOf(contains('nope'), contains('blueprint')))),
      );
      final camera = await level.callTool('get_camera');
      expect(camera.isError, isFalse, reason: 'groups size the list; they are not a permission');

      final groups = (await level.callTool('list_tool_groups')).data;
      // A tool may sit in more than one group (list_component_types: component + blueprint).
      final distinct = {for (final g in groups['groups'] as List) ...((g as Map)['tools'] as List)};
      expect(distinct, hasLength(groups['tool_count'] as int));
      expect(groups['tool_count'], 372);
      expect(groups['active_groups'], ['level']);
      expect(groups['max_risk'], 'external');
    });
  });

  group('approval', () {
    test('the risk ceiling hides and denies tools above it; denials are recorded and logged', () async {
      server.settings.setMaxRisk(McpToolRisk.editorState);
      final names = (await client.listTools()).map((t) => t['name']).toSet();
      expect(names, isNot(contains('spawn_actor')));
      expect(names, contains('set_camera'));
      final before = vm.actors.length;
      final denied = await client.callTool('spawn_actor', {'type': 'PointLight'});
      expect(denied.isError, isTrue);
      final body = jsonText(denied);
      expect(body['status'], 'denied');
      expect(body['risk'], 'mutating');
      expect(body['tool'], 'spawn_actor');
      expect(vm.actors.length, before);
      expect(server.recentCalls.first.denied, isTrue);
      expect(server.recentCalls.first.risk, McpToolRisk.mutating);
      expect(vm.logs.any((l) => l.source == 'MCP' && l.message.contains('spawn_actor denied')), isTrue);
      expect(jsonDecode(File('${configDir.path}/${McpServerSettings.fileName}').readAsStringSync())['max_risk'], 'editorState');

      server.settings.setMaxRisk(McpToolRisk.mutating);
      expect((await client.callTool('spawn_actor', {'type': 'PointLight'})).isError, isFalse);
      await client.callTool('create_asset', {'type': 'filamat', 'name': 'M_Keep'});
      final delete = await client.callTool('delete_asset', {'asset': 'contents/materials/M_Keep.lmas'});
      expect(jsonText(delete)['status'], 'denied');
      expect(File('${vm.projectDirPath}/contents/materials/M_Keep.lmas').existsSync(), isTrue);
    });

    test('a policy sees the client: only the "probe" client is refused rename_actor; a throwing policy denies', () async {
      server.approvalPolicies.add(_DenyRenameForProbe());
      await client.callTool('spawn_actor', {'type': 'PointLight'});
      final id = vm.actors.last.id;
      final probe = connect();
      await probe.handshake(clientName: 'probe');
      final refused = await probe.callTool('rename_actor', {'id': id, 'name': 'Probed'});
      expect(jsonText(refused)['reason'], 'probe may not rename actors');
      expect((await client.callTool('rename_actor', {'id': id, 'name': 'Renamed'})).isError, isFalse);
      expect(vm.actors.last.name, 'Renamed');

      server.approvalPolicies.add(_ThrowingPolicy());
      final thrown = await client.callTool('get_camera');
      expect(jsonText(thrown)['reason'], contains('policy exploded'));
    });
  });

  group('agent-attributed undo', () {
    test('one call is one undo step labelled MCP: … carrying its session', () async {
      await client.callTool('spawn_actor', {'type': 'Primitive'});
      final actor = vm.actors.last;
      final depth = vm.transactions.history(limit: 200).length;
      final reply = await client.callTool('set_actor_transform', {
        'id': actor.id,
        'location': [10, 20, 30],
        'rotation': [0, 0, 90],
        'scale': [2, 2, 2],
      });
      expect(reply.isError, isFalse, reason: reply.text);
      expect(vm.transactions.history(limit: 200).length, depth + 1);
      expect(vm.transactions.undoLabel, startsWith('Undo MCP: '));
      expect(vm.transactions.undoLabel, endsWith('(+2)'));
      expect(vm.transactions.undoTopOrigin!.tool, 'set_actor_transform');
      expect(vm.transactions.undoTopOrigin!.sessionId, server.sessionList.first.id);
      expect(vm.transactions.undoTopOrigin!.clientName, 'lumina-ui-test-client');

      final undone = await client.callTool('undo');
      expect(undone.isError, isFalse, reason: undone.text);
      expect(actor.location, [0.0, 0.0, 0.0]);
      expect(actor.rotation, [0.0, 0.0, 0.0]);
      expect(actor.scale, [1.0, 1.0, 1.0]);
    });

    test('scope "agent" undoes only this session\'s steps', () async {
      if (!redBarrel.existsSync()) return markTestSkipped('test-assets not present');
      await vm.ensureDefaultLevelAssets();
      await vm.processImportPipeline(sourceFilePath: redBarrel.path);
      final mesh = vm.realAssets.where((a) => a.type == AssetType.filamesh && a.fileName.contains('fuel_barrel_red')).first;
      final spawned = await client.callTool('spawn_actor_from_asset', {'asset': mesh.relativePath});
      expect(spawned.isError, isFalse, reason: spawned.text);
      final barrel = vm.actors.last;
      vm.renameActorWithTransaction(barrel.id, 'UserNamed');

      final refused = await client.callTool('undo', {'scope': 'agent'});
      expect(refused.isError, isTrue);
      expect(refused.text, contains("the user's"));
      expect(refused.text, contains('UserNamed'));
      expect(barrel.name, 'UserNamed', reason: 'nothing changed');

      final any = await client.callTool('undo', {'scope': 'any'});
      expect(any.data['origin'], 'user');
      expect(barrel.name, isNot('UserNamed'));
      final mine = await client.callTool('undo', {'scope': 'agent'});
      expect(mine.isError, isFalse, reason: mine.text);
      expect(vm.actors.any((a) => a.id == barrel.id), isFalse);
      final redone = await client.callTool('redo', {'scope': 'agent'});
      expect(redone.isError, isFalse, reason: redone.text);
      expect(vm.actors.any((a) => a.id == barrel.id), isTrue);

      final state = (await client.callTool('undo_state')).data;
      expect(state['agent_depth'], 1);
      expect((state['undo_origin'] as Map)['tool'], 'spawn_actor_from_asset');
      expect((state['history'] as List).length, greaterThanOrEqualTo(1));
    });

    test('a Blueprint and a Material tab each undo on their own stack', () async {
      await client.callTool('create_asset', {'type': 'actor', 'name': 'BP_Agent', 'parent_class': 'LuminaActor'});
      const bp = 'contents/blueprints/BP_Agent.lmas';
      final levelHistory = vm.transactions.history().map((h) => h.label).toList();
      final added = await client.callTool('add_blueprint_node', {'asset': bp, 'node': 'print_string', 'x': 300, 'y': 100});
      expect(added.isError, isFalse, reason: added.text);
      final nodeId = (added.data['node'] as Map)['id'];
      final undone = await client.callTool('undo', {'asset': bp});
      expect(undone.isError, isFalse, reason: undone.text);
      expect(undone.data['undone'], 'Undo MCP: Add Print String');
      final nodes = ((await client.callTool('get_blueprint', {'asset': bp})).data['nodes'] as List).cast<Map>();
      expect(nodes.any((n) => n['id'] == nodeId), isFalse);
      expect(vm.transactions.history().map((h) => h.label).toList(), levelHistory, reason: 'the level stack is untouched');

      await client.callTool('create_asset', {'type': 'filamat', 'name': 'M_Undo'});
      const mat = 'contents/materials/M_Undo.lmas';
      final original = (await client.callTool('get_material_source', {'asset': mat})).data['source'] as String;
      final edited = '$original\n// agent edit\n';
      expect((await client.callTool('set_material_source', {'asset': mat, 'source': edited})).isError, isFalse);
      final back = await client.callTool('undo', {'asset': mat});
      expect(back.isError, isFalse, reason: back.text);
      final editor = vm.editorSessionFor(vm.currentTab.id) as MaterialEditorViewModel;
      expect(editor.currentCode, original);

      await client.callTool('set_material_source', {'asset': mat, 'source': edited});
      editor.updateCodeFromEditor('$edited// the user typed this\n');
      final refused = await client.callTool('undo', {'asset': mat});
      expect(refused.isError, isTrue);
      expect(refused.text, contains('the source changed since'));
      expect(editor.currentCode, contains('the user typed this'));
      expect(editor.transactions.canUndo, isTrue, reason: 'the refused step stays');
    });
  });

  group('recoverable asset operations', () {
    test('delete_asset trashes the files and the actor; undo, redo, list_trash and restore_asset bring them back', () async {
      if (!redBarrel.existsSync()) return markTestSkipped('test-assets not present');
      await vm.ensureDefaultLevelAssets();
      await vm.processImportPipeline(sourceFilePath: redBarrel.path);
      final mesh = vm.realAssets.where((a) => a.type == AssetType.filamesh && a.fileName.contains('fuel_barrel_red')).first;
      await client.callTool('spawn_actor_from_asset', {'asset': mesh.relativePath});
      final barrel = vm.actors.last;
      final lmas = File(mesh.lmasPath!);
      final source = File('${vm.projectDirPath}/${mesh.relativePath}');
      final lmasBytes = lmas.readAsBytesSync();
      final sourceBytes = source.readAsBytesSync();

      final deleted = await client.callTool('delete_asset', {'asset': mesh.relativePath});
      expect(deleted.isError, isFalse, reason: deleted.text);
      final trashId = deleted.data['trash_id'] as String;
      expect(lmas.existsSync(), isFalse);
      expect(source.existsSync(), isFalse);
      expect(vm.actors.any((a) => a.id == barrel.id), isFalse);
      final entryDir = Directory('${vm.projectDirPath}/.lumina/trash/$trashId');
      final manifest = jsonDecode(File('${entryDir.path}/manifest.json').readAsStringSync()) as Map;
      for (final f in (manifest['files'] as List).cast<Map>()) {
        final stored = File('${entryDir.path}/${f['stored']}');
        expect(sha256.convert(stored.readAsBytesSync()).toString(), f['sha256'], reason: '${f['original']}');
      }
      expect(vm.logs.any((l) => l.source == 'MCP' && l.message.contains('delete_asset') && l.message.contains(trashId)), isTrue);

      await client.callTool('undo');
      expect(lmas.readAsBytesSync(), lmasBytes);
      expect(source.readAsBytesSync(), sourceBytes);
      expect(vm.actors.any((a) => a.id == barrel.id), isTrue, reason: 'the same actor id');
      await client.callTool('redo');
      expect(lmas.existsSync(), isFalse);
      final listed = (await client.callTool('list_trash')).data;
      expect((listed['entries'] as List).map((e) => (e as Map)['trash_id']), contains(trashId));

      vm.transactions.clear();
      final restored = await client.callTool('restore_asset', {'trash_id': trashId});
      expect(restored.isError, isFalse, reason: restored.text);
      expect(lmas.readAsBytesSync(), lmasBytes);
      expect(vm.actors.any((a) => a.id == barrel.id), isTrue);

      final again = await client.callTool('delete_asset', {'asset': mesh.relativePath});
      final againId = again.data['trash_id'] as String;
      lmas.writeAsStringSync('a new file at the same path');
      final conflict = await client.callTool('restore_asset', {'trash_id': againId});
      expect(conflict.isError, isTrue);
      expect(conflict.text, contains(mesh.relativePath.split('/').last.split('.').first));
    });

    test('import_asset and create_asset are one undo step each that moves exactly their files to the trash', () async {
      if (!dentedBarrel.existsSync()) return markTestSkipped('test-assets not present');
      final imported = await client.callTool('import_asset', {'path': dentedBarrel.path});
      expect(imported.isError, isFalse, reason: imported.text);
      final created = (imported.data['created_files'] as List).cast<String>();
      expect(created.any((f) => f.endsWith('.lmas')), isTrue);
      expect(created.any((f) => f.endsWith('.glb')), isTrue);
      for (final f in created) {
        expect(File('${vm.projectDirPath}/$f').existsSync(), isTrue, reason: f);
      }
      await client.callTool('undo');
      for (final f in created) {
        expect(File('${vm.projectDirPath}/$f').existsSync(), isFalse, reason: f);
      }
      final assetsAfterUndo = (await client.callTool('list_assets', {'query': 'dented'})).data;
      expect(assetsAfterUndo['count'], 0);
      await client.callTool('redo');
      for (final f in created) {
        expect(File('${vm.projectDirPath}/$f').existsSync(), isTrue, reason: f);
      }

      final m = await client.callTool('create_asset', {'type': 'filamat', 'name': 'M_Undo'});
      expect(m.data['created_files'], contains('contents/materials/M_Undo.lmas'));
      await client.callTool('undo');
      expect(File('${vm.projectDirPath}/contents/materials/M_Undo.lmas').existsSync(), isFalse);
      final trash = vm.projectTrash.list();
      expect(trash.first.files.map((f) => f.original), contains('contents/materials/M_Undo.lmas'));
    });
  });
}
