import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_server_service.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_server_settings.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/particle_system_document.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/anim_graph_asset_service.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/sequencer_offscreen_frame_source.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/anim_blueprint_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/animation_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/particle_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/sequencer_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/skeletal_mesh_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/anim_blueprint/anim_blueprint_sub_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/particle/particle_sub_editor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' show ShadcnApp, Size, SizedBox;

import '../helpers/anim_test_project.dart';
import '../helpers/mcp_test_client.dart';
import '../helpers/scaffold_game_project.dart';
import '../helpers/temp_project.dart';

/// The Animation Blueprint, Blend Space, Animation, Skeletal
/// Mesh, Sequencer and Particle editors as MCP tools, through a real
/// JSON-RPC-over-HTTP client against a real launcher Third Person project
/// with the Manny mannequin, a walk clip, the red fuel barrel (spawned in the
/// level) and the blue access card imported through the real pipeline.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late String projectDir;
  late EditorViewModel vm;
  late McpServerService server;
  late McpTestClient client;

  final assets = '${Directory.current.parent.path}/test-assets';
  const quinn = LuminaThirdPersonContent.projectMeshAssetPath;
  const manny = 'contents/meshes/skeletal/SKM_Manny_Simple.lmas';
  const walk = 'contents/animations/MF_Unarmed_Walk_Fwd/MF_Unarmed_Walk_Fwd.lmas';
  const barrelMesh = 'contents/meshes/static/fuel_barrel_red.lmas';
  const card = 'contents/meshes/static/access_card_blue.lmas';
  late String barrelTexture;
  late String barrelId;
  const barrelZ = 50.0;

  Future<Map<String, Object?>> ok(String tool, [Map<String, Object?> args = const {}]) async {
    final reply = await client.callTool(tool, args);
    expect(reply.isError, isFalse, reason: '$tool: ${reply.text}');
    return reply.data;
  }

  /// A refusal: a tool error, or a -32602 for arguments the schema rejects.
  Future<String> refused(String tool, Map<String, Object?> args) async {
    try {
      final reply = await client.callTool(tool, args);
      expect(reply.isError, isTrue, reason: '$tool should refuse: ${reply.text}');
      return reply.text;
    } on McpRpcError catch (e) {
      return e.message;
    }
  }

  T session<T>(String relative) => vm.editorSessionFor(vm.realAssets.firstWhere((a) => a.relativePath == relative).lmasPath!) as T;

  setUpAll(() async {
    root = Directory.systemTemp.createTempSync('lumina_mcp_anim_seq_');
    projectDir = await scaffoldGameProject(root, name: 'agent_anim', widgetLibrary: 'flutter');
    ensureTemplateAnimAssets(projectDir);
    final project = LuminaProject.fromMap(
        Map<String, dynamic>.from(jsonDecode(File('$projectDir/agent_anim.lmproject').readAsStringSync()) as Map));
    final configDir = Directory('${root.path}/config')..createSync();
    vm = EditorViewModel(initialProject: project, projectLocation: root.path, enableTimers: false, autoInitAssets: false);
    await vm.ensureDefaultLevelAssets();
    vm.refreshAssets();
    server = McpServerService(vm, configDir: configDir, settings: McpServerSettings.load(configDir: configDir));
    expect(await server.start(port: 0), isTrue);
    client = McpTestClient(server.url!, server.token);
    await client.handshake();
    for (final file in [
      'mannequin/SKM_Manny_Simple.glb',
      'mannequin/MF_Unarmed_Walk_Fwd.glb',
      'Props/Barrels/fuel_barrel_red.glb',
      'Props/Access_cards/access_card_blue.glb',
    ]) {
      await ok('import_asset', {'path': '$assets/$file'});
    }
    for (final a in [manny, walk, barrelMesh, card]) {
      expect(File('$projectDir/$a').existsSync(), isTrue, reason: '$a was imported');
    }
    barrelTexture = vm.realAssets
        .firstWhere((a) => a.type == AssetType.texture && a.relativePath.contains('fuel_barrel_red'))
        .relativePath;
    final spawned = await ok('spawn_actor_from_asset', {'asset': barrelMesh, 'location': [100, 0, barrelZ]});
    barrelId = (spawned['actor'] as Map?)?['id'] as String? ?? spawned['id'] as String;
  });

  tearDownAll(() async {
    client.close();
    await server.stop();
    await vm.close();
    await deleteTempProject(root);
  });

  group('Anim Blueprint and Blend Space', () {
    const abp = 'contents/animations/SKM_Superhero_Female/ABP_Agent.lmas';
    const bs = 'contents/animations/SKM_Superhero_Female/BS_Agent.lmas';
    late List<String> clips;

    test('create_asset needs a target mesh for an Anim Blueprint and a Blend Space', () async {
      final missing = await refused('create_asset', {'type': 'animBlueprint', 'name': 'Agent'});
      expect(missing, allOf(contains('target_mesh'), contains(quinn), contains(manny)));
      final created = await ok('create_asset', {'type': 'animBlueprint', 'name': 'Agent', 'target_mesh': quinn});
      expect(created['path'], abp);
      final doc = await ok('get_anim_blueprint', {'asset': abp});
      expect(doc['target_mesh'], quinn);
      clips = (doc['clips'] as List).cast<String>();
      expect(clips.length, greaterThan(1));

      expect(await refused('create_asset', {'type': 'blendSpace', 'name': 'Agent'}), contains('target_mesh'));
      expect((await ok('create_asset', {'type': 'blendSpace', 'name': 'Agent', 'target_mesh': quinn}))['path'], bs);
      final space = await ok('get_blend_space', {'asset': bs});
      expect(space['axes'], hasLength(2));
      expect(space['clips'], clips);
    });

    test('variables and states: one transaction per add_anim_state; an unknown clip lists the clips', () async {
      await ok('add_anim_variable', {'asset': abp, 'name': 'GroundSpeed', 'type': 'float', 'default': 0});
      var doc = await ok('get_anim_blueprint', {'asset': abp});
      expect(doc['variables'], [
        {'name': 'GroundSpeed', 'type': 'float', 'default': 0},
      ]);
      // A new Anim Blueprint starts with the template's Idle state; the agent
      // replaces it with its own.
      final machine = doc['state_machine'] as Map;
      expect((machine['states'] as List).map((s) => (s as Map)['name']), ['Idle']);
      expect(await refused('add_anim_state', {'asset': abp, 'name': 'Idle', 'x': 0, 'y': 0}), contains('already'));
      await ok('delete_anim_state', {'asset': abp, 'state': 'Idle'});

      final editor = session<AnimBlueprintEditorViewModel>(abp);
      final depth = editor.transactions.history().length;
      await ok('add_anim_state', {
        'asset': abp,
        'name': 'Idle',
        'x': 0,
        'y': 0,
        'pose': {'kind': 'clip', 'clip': clips[0]},
      });
      expect(editor.transactions.history().length, depth + 1);
      expect(editor.transactions.undoLabel, startsWith('Undo MCP: Add state Idle'));
      await ok('add_anim_state', {
        'asset': abp,
        'name': 'Moving',
        'x': 300,
        'y': 0,
        'pose': {'kind': 'clip', 'clip': clips[1]},
      });
      expect(editor.transactions.history().length, depth + 2);
      expect(
        await refused('add_anim_state', {
          'asset': abp,
          'name': 'Broken',
          'x': 0,
          'y': 200,
          'pose': {'kind': 'clip', 'clip': 'NoSuchClip'},
        }),
        allOf(contains('NoSuchClip'), contains(clips[0]), contains(clips[1])),
      );
      expect(editor.transactions.history().length, depth + 2, reason: 'a refused add records nothing');
      doc = await ok('get_anim_blueprint', {'asset': abp});
      final m = doc['state_machine'] as Map;
      expect(m['entry_state'], 'Idle');
      final states = {for (final s in (m['states'] as List).cast<Map>()) s['name']: s};
      expect(states.keys, ['Idle', 'Moving']);
      expect((states['Moving']!['pose'] as Map)['clip'], clips[1]);
      expect(states['Moving']!['x'], 300.0);
      await ok('move_anim_state', {'asset': abp, 'state': 'Moving', 'x': 320, 'y': 10});
      await ok('rename_anim_state', {'asset': abp, 'state': 'Moving', 'name': 'Moving2'});
      await ok('rename_anim_state', {'asset': abp, 'state': 'Moving2', 'name': 'Moving'});
      final moved = ((await ok('get_anim_blueprint', {'asset': abp}))['state_machine'] as Map)['states'] as List;
      expect(moved.cast<Map>().firstWhere((s) => s['name'] == 'Moving')['x'], 320.0);
    });

    test('a transition rule authored in graph "transition:idle_to_moving" compiles to lib/anim/abp_agent.dart', () async {
      final added = await ok('add_anim_transition', {'asset': abp, 'from': 'Idle', 'to': 'Moving', 'blend_duration': 0.2});
      expect(added['id'], 'idle_to_moving');
      final result = added['result_node'] as Map;
      expect(result['node'], LuminaBlueprintNodeLibrary.transitionResult);
      const graph = 'transition:idle_to_moving';
      final get = (await ok('add_anim_graph_node', {
        'asset': abp,
        'graph': graph,
        'node': 'variable_get',
        'x': 0,
        'y': 80,
        'literals': {'variable': 'GroundSpeed'},
      }))['node'] as Map;
      final greater = (await ok('add_anim_graph_node', {'asset': abp, 'graph': graph, 'node': 'float_greater', 'x': 200, 'y': 80}))['node'] as Map;
      await ok('set_anim_graph_pin_literal', {'asset': abp, 'graph': graph, 'node': greater['id'], 'pin': 'b', 'value': 10});
      final getOut = ((get['outputs'] as List).cast<Map>().firstWhere((p) => p['type'] == 'float'))['id'];
      final greaterOut = ((greater['outputs'] as List).cast<Map>().first)['id'];
      await ok('connect_anim_graph_pins',
          {'asset': abp, 'graph': graph, 'from_node': get['id'], 'from_pin': getOut, 'to_node': greater['id'], 'to_pin': 'a'});
      await ok('connect_anim_graph_pins', {
        'asset': abp,
        'graph': graph,
        'from_node': greater['id'],
        'from_pin': greaterOut,
        'to_node': result['id'],
        'to_pin': 'can_enter',
      });
      expect(await refused('add_anim_graph_node', {'asset': abp, 'graph': graph, 'node': 'print_string'}), contains('pure nodes only'));
      expect(await refused('add_anim_graph_node', {'asset': abp, 'graph': 'transition:nope', 'node': 'float_greater'}),
          contains('transition:idle_to_moving'));

      final compiled = await ok('compile_anim_blueprint', {'asset': abp, 'save': true});
      expect(compiled['status'], isNot('error'), reason: '${compiled['compile_rows']}');
      expect(compiled['generated_file'], 'lib/anim/abp_agent.dart');
      expect(File('$projectDir/lib/anim/abp_agent.dart').existsSync(), isTrue);
      expect(compiled['saved'], isTrue);
      final t = ((await ok('get_anim_blueprint', {'asset': abp}))['state_machine'] as Map)['transitions'] as List;
      expect(t.single, allOf(containsPair('id', 'idle_to_moving'), containsPair('blend_duration', 0.2)));
      await ok('set_anim_transition', {'asset': abp, 'id': 'idle_to_moving', 'priority': 2});
    });

    test('the rule with its can_enter wire removed is a located compile error', () async {
      const graph = 'transition:idle_to_moving';
      final g = await ok('get_anim_graph', {'asset': abp, 'graph': graph});
      final wire = (g['wires'] as List).cast<Map>().firstWhere((w) => w['to_pin'] == 'can_enter');
      await ok('remove_anim_graph_wire', {'asset': abp, 'graph': graph, 'wire': wire['id']});
      final reply = await client.callTool('compile_anim_blueprint', {'asset': abp});
      expect(reply.isError, isTrue);
      expect(reply.data['status'], 'error');
      final row = (reply.data['compile_rows'] as List).cast<Map>().firstWhere((r) => '${r['message']}'.contains('the Result is not connected'));
      expect(row['graph'], graph);
      await ok('connect_anim_graph_pins', {
        'asset': abp,
        'graph': graph,
        'from_node': wire['from_node'],
        'from_pin': wire['from_pin'],
        'to_node': wire['to_node'],
        'to_pin': 'can_enter',
      });
    });

    test('anim_blueprint_preview drives GroundSpeed: 300 → Moving, 0 → Idle', () async {
      // Back to Idle when GroundSpeed drops under 10.
      final back = await ok('add_anim_transition', {'asset': abp, 'from': 'Moving', 'to': 'Idle', 'blend_duration': 0.2});
      final graph = 'transition:${back['id']}';
      final result = back['result_node'] as Map;
      final get = (await ok('add_anim_graph_node', {'asset': abp, 'graph': graph, 'node': 'variable_get', 'literals': {'variable': 'GroundSpeed'}}))['node'] as Map;
      final less = (await ok('add_anim_graph_node', {'asset': abp, 'graph': graph, 'node': 'float_less', 'literals': {'b': 10}}))['node'] as Map;
      await ok('connect_anim_graph_pins', {
        'asset': abp,
        'graph': graph,
        'from_node': get['id'],
        'from_pin': ((get['outputs'] as List).cast<Map>().firstWhere((p) => p['type'] == 'float'))['id'],
        'to_node': less['id'],
        'to_pin': 'a',
      });
      await ok('connect_anim_graph_pins', {
        'asset': abp,
        'graph': graph,
        'from_node': less['id'],
        'from_pin': ((less['outputs'] as List).cast<Map>().first)['id'],
        'to_node': result['id'],
        'to_pin': 'can_enter',
      });
      expect((await ok('compile_anim_blueprint', {'asset': abp}))['status'], isNot('error'));
      var preview = await ok('anim_blueprint_preview', {'asset': abp, 'overrides': {'GroundSpeed': 300}, 'frames': 60});
      expect(preview['preview_state'], 'Moving', reason: '${preview['preview_error']}');
      expect(preview['preview_clip'], clips[1]);
      preview = await ok('anim_blueprint_preview', {'asset': abp, 'overrides': {'GroundSpeed': 0}, 'frames': 60});
      expect(preview['preview_state'], 'Idle');
      expect(await refused('anim_blueprint_preview', {'asset': abp, 'overrides': {'Nope': 1}}), contains('GroundSpeed'));
    });

    test('variables: rename, retype, default, delete', () async {
      await ok('add_anim_variable', {'asset': abp, 'name': 'Tmp', 'type': 'bool'});
      await ok('rename_anim_variable', {'asset': abp, 'name': 'Tmp', 'new_name': 'IsBusy'});
      await ok('set_anim_variable', {'asset': abp, 'name': 'IsBusy', 'type': 'integer', 'default': 3});
      var vars = (await ok('get_anim_blueprint', {'asset': abp}))['variables'] as List;
      expect(vars.cast<Map>().firstWhere((v) => v['name'] == 'IsBusy'), {'name': 'IsBusy', 'type': 'integer', 'default': 3});
      await ok('delete_anim_variable', {'asset': abp, 'name': 'IsBusy'});
      vars = (await ok('get_anim_blueprint', {'asset': abp}))['variables'] as List;
      expect(vars.cast<Map>().map((v) => v['name']), ['GroundSpeed']);
      expect(await refused('add_anim_variable', {'asset': abp, 'name': 'X', 'type': 'nope'}), contains('Unknown variable type'));
    });

    test('blend space axes, samples snapped to the divisions, the preview point and save', () async {
      await ok('set_blend_space_axis', {'asset': bs, 'index': 0, 'name': 'Direction', 'min': -180, 'max': 180});
      expect(await refused('set_blend_space_axis', {'asset': bs, 'index': 0, 'min': 10, 'max': 10}), contains('max'));
      final sample = await ok('add_blend_space_sample', {'asset': bs, 'clip': clips[0], 'x': 3, 'y': 251});
      expect(sample['x'], 0.0);
      expect(sample['y'], 250.0);
      expect(await refused('add_blend_space_sample', {'asset': bs, 'clip': 'NoSuchClip', 'x': 0, 'y': 0}), contains(clips[0]));
      final picked = await ok('set_blend_space_preview', {'asset': bs, 'x': 0, 'y': 250});
      expect(picked['picked_clip'], clips[0]);
      await ok('set_blend_space_divisions', {'asset': bs, 'x': 8});
      expect((await ok('get_blend_space', {'asset': bs}))['divisions'], {'x': 8, 'y': 4});
      await ok('save_blend_space', {'asset': bs});
      final reopened = AnimGraphAssetService.readBlendSpace(projectDir, bs)!;
      expect(reopened.samples, hasLength(1));
      expect(reopened.axes.first.name, 'Direction');
    });
  });

  group('Animation and Skeletal Mesh', () {
    test('notifies (clamped), a curve key read back at the seek position, rate scale and root motion saved', () async {
      final doc = await ok('get_animation', {'asset': walk});
      final clipList = (doc['clips'] as List).cast<Map>();
      expect(clipList, hasLength(1));
      final duration = clipList.single['duration_s'] as double;
      expect(duration, greaterThan(0));
      final added = await ok('add_animation_notify', {'asset': walk, 'name': 'Footstep_L', 'time': 0.25, 'type': 'footstep'});
      expect(added['time'], 0.25);
      expect(added['id'], isA<String>());
      final late = await ok('add_animation_notify', {'asset': walk, 'name': 'Late', 'time': 999});
      expect(late['time'], duration);
      expect(late['clamped'], isTrue);
      await ok('remove_animation_notify', {'asset': walk, 'notify': late['id']});
      await ok('add_animation_curve', {'asset': walk, 'name': 'FootPlant'});
      await ok('add_animation_curve_key', {'asset': walk, 'curve': 'FootPlant', 'time': 0.5, 'value': 1.0});
      final seek = await ok('animation_preview', {'asset': walk, 'action': 'seek', 'time': 0.5});
      expect(seek['position_s'], closeTo(0.5, 1e-9));
      expect((seek['curves'] as Map)['FootPlant'], closeTo(1.0, 1e-9));
      await ok('set_animation_settings', {'asset': walk, 'rate_scale': 1.2, 'root_motion': true});
      expect((await ok('get_animation', {'asset': walk}))['is_dirty'], isTrue);
      await ok('save_animation', {'asset': walk});

      final reopened = AnimationEditorViewModel(assetPath: '$projectDir/$walk');
      await reopened.load();
      expect(reopened.notifies.map((n) => (n.name, n.time)), [('Footstep_L', 0.25)]);
      expect(reopened.curves.single.keys.map((k) => (k.time, k.value)), [(0.5, 1.0)]);
      expect(reopened.rateScale, 1.2);
      expect(reopened.enableRootMotion, isTrue);
      reopened.dispose();
    });

    test('sockets on hand_r: unique names, transform and preview asset saved; an unknown bone lists bones', () async {
      final skeleton = await ok('get_skeleton', {'asset': manny, 'bone_filter': 'hand'});
      final bones = (skeleton['bones'] as List).cast<Map>().map((b) => b['name']);
      expect(bones, containsAll(['hand_l', 'hand_r']));
      final first = await ok('add_skeletal_socket', {'asset': manny, 'bone': 'hand_r', 'name': 'hand_r_keycard'});
      expect(first['name'], 'hand_r_keycard');
      final second = await ok('add_skeletal_socket', {'asset': manny, 'bone': 'hand_r', 'name': 'hand_r_keycard'});
      expect(second['name'], isNot('hand_r_keycard'));
      expect(second['name'], startsWith('hand_r_keycard'));
      await ok('remove_skeletal_socket', {'asset': manny, 'socket': second['name']});
      await ok('set_skeletal_socket', {
        'asset': manny,
        'socket': 'hand_r_keycard',
        'location': [5, 0, 2],
        'rotation': [0, 0, 90],
        'preview_asset': card,
      });
      final unknown = await refused('add_skeletal_socket', {'asset': manny, 'bone': 'hnd_r'});
      expect(unknown, allOf(contains('hnd_r'), contains('root')));
      await ok('save_skeletal_mesh', {'asset': manny});
      final reopened = SkeletalMeshEditorViewModel(assetPath: '$projectDir/$manny');
      await reopened.load();
      final socket = reopened.sockets.firstWhere((s) => s.name == 'hand_r_keycard');
      expect(socket.parentBone, 'hand_r');
      expect(socket.relativeLocation, [5.0, 0.0, 2.0]);
      expect(socket.relativeRotation, [0.0, 0.0, 90.0]);
      expect(socket.previewAssetPath, card);
      reopened.dispose();
    });

    test('material slots, a sampler texture, bone retargeting; preview weights refuse a mesh without morphs', () async {
      final mat = (await ok('create_asset', {'type': 'filamat', 'name': 'M_AgentMat'}))['path'] as String;
      final slots = await ok('get_skeletal_material_slots', {'asset': manny});
      expect(slots['slots'], isNotEmpty);
      expect((slots['available_materials'] as List), contains(mat));
      final set = await ok('set_skeletal_material_slot', {'asset': manny, 'slot': 0, 'material': mat});
      final samplers = ((set['slot'] as Map)['samplers'] as List).cast<String>();
      expect(samplers, isNotEmpty);
      await ok('set_skeletal_slot_texture', {'asset': manny, 'slot': 0, 'parameter': samplers.first, 'texture': barrelTexture});
      expect(await refused('set_skeletal_slot_texture', {'asset': manny, 'slot': 0, 'parameter': 'nope', 'texture': barrelTexture}),
          contains(samplers.first));
      await ok('set_bone_retargeting', {'asset': manny, 'bone': 'pelvis', 'option': 'Skeleton'});
      expect(await refused('set_bone_retargeting', {'asset': manny, 'bone': 'pelvis', 'option': 'Bogus'}),
          allOf(contains('Animation'), contains('Skeleton')));
      expect(await refused('set_skeletal_preview_weights', {'asset': manny, 'morphs': {'Smile': 0.7}}), contains('no morph targets'));
      final weights = await ok('get_vertex_weights', {'asset': manny, 'vertices': [0, 1]});
      expect((weights['vertices'] as List).cast<Map>().first['weight_sum'], closeTo(1.0, 0.02));
      await ok('save_skeletal_mesh', {'asset': manny});
      final reopened = SkeletalMeshEditorViewModel(assetPath: '$projectDir/$manny');
      await reopened.load();
      expect(reopened.materialSlots.first.assignedMaterialPath!.replaceAll(r'\', '/'), endsWith('/$mat'));
      expect(reopened.materialSlots.first.textureBindings[samplers.first]!.assetPath.replaceAll(r'\', '/'), endsWith(barrelTexture));
      expect(reopened.boneRetargeting['pelvis'], 'Skeleton');
      reopened.dispose();
    });
  });

  group('Sequencer', () {
    const seq = 'contents/sequencers/SEQ_AgentFlyby.lmas';
    late String track;

    double barrelZNow() => vm.actors.firstWhere((a) => a.id == barrelId).location[2];

    test('a transform track on the barrel, keys, playback, scrub moves the level and stop restores it', () async {
      expect((await ok('create_asset', {'type': 'sequencer', 'name': 'SEQ_AgentFlyby'}))['path'], seq);
      expect(await refused('add_sequencer_track', {'asset': seq, 'actor': 'nope', 'kind': 'transform'}), contains('list_actors'));
      final added = await ok('add_sequencer_track', {'asset': seq, 'actor': barrelId, 'kind': 'transform'});
      track = (added['track'] as Map)['id'] as String;
      final channels = ((added['track'] as Map)['channels'] as List).cast<Map>().map((c) => c['name']).toList();
      expect(channels, ['Location.X', 'Location.Y', 'Location.Z', 'Rotation.X', 'Rotation.Y', 'Rotation.Z', 'Scale.X', 'Scale.Y', 'Scale.Z']);

      final editor = session<SequencerViewModel>(seq);
      final depth = editor.transactions.history().length;
      await ok('add_sequencer_key', {'asset': seq, 'track': track, 'channel': 'Location.Z', 'frame': 0, 'value': 0});
      await ok('add_sequencer_key', {'asset': seq, 'track': track, 'channel': 'Location.Z', 'frame': 60, 'value': 200, 'interpolation': 'cubic'});
      expect(editor.transactions.history().length, depth + 2, reason: 'one step per key edit');
      expect(await refused('add_sequencer_key', {'asset': seq, 'track': track, 'channel': 'Location.W', 'frame': 0, 'value': 1}),
          allOf(contains('Location.X'), contains('Scale.Z')));

      await ok('set_sequence_playback', {'asset': seq, 'fps': 30, 'length_frames': 90, 'range': [0, 60]});
      final doc = await ok('get_sequence', {'asset': seq});
      expect(doc['fps'], 30);
      expect(doc['length_frames'], 90);
      expect(doc['playback_range'], [0, 60]);
      final z = ((doc['tracks'] as List).cast<Map>().single['channels'] as List).cast<Map>().firstWhere((c) => c['name'] == 'Location.Z');
      expect((z['keys'] as List).cast<Map>().map((k) => (k['frame'], k['value'], k['interpolation'])),
          [(0, 0.0, 'linear'), (60, 200.0, 'cubic')]);

      await ok('scrub_sequence', {'asset': seq, 'frame': 30});
      final actor = await ok('get_actor', {'id': barrelId});
      final scrubbedZ = ((actor['actor'] as Map?)?['location'] ?? actor['location']) as List;
      expect(scrubbedZ[2] as num, allOf(greaterThan(0), lessThan(200)));
      await ok('stop_sequence', {'asset': seq});
      expect(barrelZNow(), barrelZ);

      final key = await ok('set_sequencer_key',
          {'asset': seq, 'track': track, 'channel': 'Location.Z', 'key': 1, 'value': 180, 'out_tangent': 0.5, 'in_tangent': 0.5});
      expect(key['key'], containsPair('value', 180.0));
      await ok('move_sequencer_key', {'asset': seq, 'track': track, 'channel': 'Location.Z', 'key': 1, 'frame': 55});
      await ok('rename_sequencer_track', {'asset': seq, 'track': track, 'name': 'Barrel Rise'});
      final renamed = (await ok('get_sequence', {'asset': seq}))['tracks'] as List;
      expect((renamed.single as Map)['actor_name'], 'Barrel Rise');
    });

    test('render_sequence: refuses a dirty sequence, runs as a job, refuses a second render, cancels', () async {
      expect(await refused('render_sequence', {'asset': seq, 'width': 640, 'height': 360, 'start_frame': 0, 'end_frame': 29, 'output_name': 'agent_flyby'}),
          contains('Save the sequence before rendering.'));
      if (!SequencerOffscreenFrameSource.isSupported) {
        markTestSkipped('the native offscreen render is not built');
        return;
      }
      final started = await ok('render_sequence', {
        'asset': seq,
        'width': 640,
        'height': 360,
        'start_frame': 0,
        'end_frame': 29,
        'output_name': 'agent_flyby',
        'save_first': true,
      });
      final job = started['job_id'] as String;
      final second = await refused('render_sequence', {'asset': seq, 'width': 64, 'height': 64, 'output_name': 'other'});
      expect(second, contains(job));
      var waited = await ok('wait_job', {'id': job, 'timeout_ms': 25000});
      for (var i = 0; i < 10 && waited['timed_out'] == true; i++) {
        waited = await ok('wait_job', {'id': job, 'timeout_ms': 25000});
      }
      expect(waited['state'], 'succeeded', reason: '$waited');
      final out = Directory('$projectDir/saved/movie_renders/agent_flyby');
      final pngs = out.listSync().whereType<File>().where((f) => f.path.endsWith('.png')).toList();
      expect(pngs, hasLength(30));
      // The placed barrel (an .lmas mesh) is in the frame, not only
      // the background.
      pngs.sort((a, b) => a.path.compareTo(b.path));
      final first = img.decodePng(pngs.first.readAsBytesSync())!;
      final bg = first.getPixel(0, 0);
      var differing = 0;
      for (final px in first) {
        if ((px.r - bg.r).abs() + (px.g - bg.g).abs() + (px.b - bg.b).abs() > 30) differing++;
      }
      expect(differing / (first.width * first.height), greaterThan(0.01), reason: 'the barrel is drawn in ${pngs.first.path}');
      expect(out.listSync().whereType<File>().any((f) => f.path.endsWith('.json')), isTrue, reason: 'manifest');
      expect((waited['result'] as Map)['frames'], 30);

      final later = await ok('render_sequence',
          {'asset': seq, 'width': 320, 'height': 180, 'start_frame': 0, 'end_frame': 89, 'output_name': 'agent_cancel'});
      final cancelled = await ok('cancel_job', {'id': later['job_id']});
      expect(cancelled['state'], 'cancelled');
      final editor = session<SequencerViewModel>(seq);
      for (var i = 0; i < 400 && editor.isRendering; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 25));
      }
      final dir = Directory('$projectDir/saved/movie_renders/agent_cancel');
      final count = dir.existsSync() ? dir.listSync().where((f) => f.path.endsWith('.png')).length : 0;
      expect(count, lessThan(90));
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(dir.existsSync() ? dir.listSync().where((f) => f.path.endsWith('.png')).length : 0, count, reason: 'no frame after cancel');
    });
  });

  group('Particles', () {
    const ps = 'contents/particles/PS_AgentSparks.lmas';

    test('the emitter stack, stage values, a rejected edit, a burst, the barrel mesh, the preview and save', () async {
      expect((await ok('create_asset', {'type': 'particle', 'name': 'PS_AgentSparks'}))['path'], ps);
      var doc = await ok('get_particle_system', {'asset': ps});
      expect(doc['backend'], ParticleEditorViewModel.backendLabel);
      final first = (doc['emitters'] as List).cast<Map>().single;
      final lifetime = (first['stages'] as Map)['lifetime'] as Map;
      expect((lifetime['speed'] as List).first, 100.0);
      final gravity = (((first['stages'] as Map)['forces'] as Map)['gravity'] as List).cast<num>();
      expect(gravity.map((g) => g * g).reduce((a, b) => a + b), closeTo(980.0 * 980.0, 1e-6));

      await ok('add_particle_emitter', {'asset': ps, 'name': 'Embers'});
      expect((await ok('get_particle_system', {'asset': ps}))['emitters'], hasLength(2));
      final set = await ok('set_particle_emitter', {
        'asset': ps,
        'emitter': 'Embers',
        'spawn_rate': 120,
        'max_particles': 400,
        'lifetime': [0.5, 1.5],
        'cone_angle_degrees': 25,
        'drag': 0.2,
      });
      expect(set['edited'], 'Embers');
      var embers = (set['emitter'] as Map)['stages'] as Map;
      expect(embers['spawn'], allOf(containsPair('spawn_rate', 120.0), containsPair('max_particles', 400)));
      expect(embers['lifetime'], allOf(containsPair('lifetime', [0.5, 1.5]), containsPair('cone_angle_degrees', 25.0)));
      expect((embers['forces'] as Map)['drag'], 0.2);
      final rejected = await refused('set_particle_emitter', {'asset': ps, 'emitter': 'Embers', 'max_particles': 0});
      expect(rejected, contains('maxParticles must be at least 1'));
      doc = await ok('get_particle_system', {'asset': ps});
      embers = (doc['emitters'] as List).cast<Map>().firstWhere((e) => e['name'] == 'Embers')['stages'] as Map;
      expect((embers['spawn'] as Map)['max_particles'], 400);

      await ok('add_particle_burst', {'asset': ps, 'emitter': 'Embers', 'time': 0, 'count': 50});
      await ok('add_particle_color_stop', {'asset': ps, 'emitter': 'Embers', 't': 0, 'rgba': [1, 0.5, 0, 1]});
      await ok('add_particle_size_point', {'asset': ps, 'emitter': 'Embers', 't': 1, 'scale': 0.2});
      final render = await ok('set_particle_render', {'asset': ps, 'emitter': 'Embers', 'mesh': barrelMesh});
      expect((((render['emitter'] as Map)['stages'] as Map)['render'] as Map)['mesh'], barrelMesh);
      final stepped = await ok('particle_preview', {'asset': ps, 'action': 'step', 'frames': 30});
      expect(stepped['sim_time'], closeTo(0.5, 1e-6));
      expect(stepped['active_particles'] as int, greaterThan(0));

      final before = await ok('get_particle_system', {'asset': ps});
      await ok('save_particle_system', {'asset': ps});
      final reopened = ParticleEditorViewModel(assetPath: '$projectDir/$ps', projectDirPath: projectDir)..open();
      expect(reopened.document.toJsonString(), session<ParticleEditorViewModel>(ps).document.toJsonString());
      expect(reopened.emitters.map((e) => e.name).toList(), (before['emitters'] as List).cast<Map>().map((e) => e['name']).toList());
      expect(reopened.emitters.last.config.meshAssetPath, barrelMesh);
      expect(LuminaAsset.fromBytes(File('$projectDir/$ps').readAsBytesSync()).metadata[ParticleSystemDocument.metadataKey], isNotNull);
      reopened.dispose();
    });
  });

  group('tabs', () {
    const abp = 'contents/animations/SKM_Superhero_Female/ABP_Agent.lmas';
    const ps = 'contents/particles/PS_AgentSparks.lmas';

    /// The call runs on the real event loop while the test pumps frames.
    Future<McpToolReply> call(WidgetTester tester, String tool, Map<String, Object?> args) async {
      McpToolReply? reply;
      Object? error;
      await tester.runAsync(() async {
        client.callTool(tool, args).then<void>((r) {
          reply = r;
        }, onError: (Object e) {
          error = e;
        });
      });
      for (var i = 0; i < 400 && reply == null && error == null; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      }
      if (error != null) throw error!;
      expect(reply, isNotNull, reason: '$tool did not answer');
      return reply!;
    }

    Future<void> mount(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    void expectVaried(Map<String, Object?> image) {
      expect(image['mimeType'], 'image/png');
      final decoded = img.decodePng(base64Decode(image['data'] as String))!;
      expect(decoded.width, greaterThan(64));
      final first = decoded.getPixel(0, 0);
      var varied = false;
      for (var y = 0; y < decoded.height && !varied; y += 5) {
        for (var x = 0; x < decoded.width; x += 5) {
          final p = decoded.getPixel(x, y);
          if (p.r != first.r || p.g != first.g || p.b != first.b) {
            varied = true;
            break;
          }
        }
      }
      expect(varied, isTrue, reason: 'the editor frame is not one flat colour');
    }

    testWidgets('the mounted tabs adopt the agent\'s view models with its unsaved edits', (tester) async {
      await mount(tester);
      final added = await call(tester, 'add_particle_emitter', {'asset': ps, 'name': 'Unsaved Sparks'});
      expect(added.isError, isFalse, reason: added.text);
      final particleSession = session<ParticleEditorViewModel>(ps);
      await call(tester, 'add_anim_state', {'asset': abp, 'name': 'Unsaved', 'x': 600, 'y': 0});
      final abpSession = session<AnimBlueprintEditorViewModel>(abp);
      await call(tester, 'open_asset_editor', {'asset': ps});
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      final particleEditor = tester.state(find.byType(ParticleSubEditor)) as dynamic;
      expect(identical(particleEditor.viewModelForTest, particleSession), isTrue);
      expect(identical(session<ParticleEditorViewModel>(ps), particleSession), isTrue);
      expect(find.textContaining('Unsaved Sparks'), findsWidgets);
      await call(tester, 'open_asset_editor', {'asset': abp});
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      final abpEditor = tester.state<AnimBlueprintSubEditorState>(find.byType(AnimBlueprintSubEditor));
      expect(identical(abpEditor.viewModel, abpSession), isTrue);
      expect(identical(session<AnimBlueprintEditorViewModel>(abp), abpSession), isTrue);
      expect(abpEditor.viewModel.machine!.state('Unsaved'), isNotNull);
      await drainRealIo(tester);
      await tester.pumpWidget(const SizedBox());
      await drainRealIo(tester);
    });

    testWidgets('asset_editor_screenshot of ABP_Agent and PS_AgentSparks is a real PNG', (tester) async {
      await mount(tester);
      for (final asset in [abp, ps]) {
        final shot = await call(tester, 'asset_editor_screenshot', {'asset': asset, 'max_width': 800});
        expect(shot.isError, isFalse, reason: shot.text);
        expectVaried(shot.content.firstWhere((c) => c['type'] == 'image'));
      }
      await drainRealIo(tester);
      await tester.pumpWidget(const SizedBox());
      await drainRealIo(tester);
    });
  });
}
