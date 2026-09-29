import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/anim_blueprint_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/particle_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/sub_editor_3d_viewport.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../test/helpers/anim_test_project.dart';
import '../../test/helpers/mcp_test_client.dart';
import '../../test/helpers/scaffold_game_project.dart';

/// MCP server animation smoke (beside `mcp_server_smoke_test.dart`, which is at the
/// 1100-line limit): an MCP client (JSON-RPC over HTTP) on a launcher Third
/// Person project builds ABP_Agent (Idle → Moving on GroundSpeed > 10) for
/// the template mannequin, compiles it and drives its preview from 0 to
/// 300 cm/s in the Filament preview; adds a hand_r_keycard socket to the
/// imported Manny with the access card previewing in the hand; puts a
/// Footstep_L notify on the imported walk clip; keys the red barrel's rise in
/// SEQ_AgentFlyby, scrubs it in the level viewport and renders frames 0–29
/// as a job; builds PS_AgentSparks with a barrel-mesh Embers emitter and
/// plays it. Every editor updates live on video; the agent's own
/// asset_editor_screenshot frames are saved as it received them, with the
/// first rendered movie frame.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const scenario = 'MCP Smoke: an agent animates a mannequin, sequences a barrel and sprays particles';
  testWidgets(scenario, (tester) async {
    final assets = SmokeArtifacts.testAssetsDir.path;
    final files = [
      '$assets/mannequin/SKM_Manny_Simple.glb',
      '$assets/mannequin/MF_Unarmed_Walk_Fwd.glb',
      '$assets/Props/Barrels/fuel_barrel_red.glb',
      '$assets/Props/Access_cards/access_card_blue.glb',
    ];
    for (final f in files) {
      expect(File(f).existsSync(), isTrue, reason: 'test-assets must hold $f');
    }
    final usedAssets = [...files];

    final root = Directory.systemTemp.createTempSync('lumina_smoke_mcp10_');
    final projectDir = (await tester.runAsync(() => scaffoldGameProject(root, name: 'agent_anim', widgetLibrary: 'flutter')))!;
    ensureTemplateAnimAssets(projectDir);
    final project = LuminaProject.fromMap(
        Map<String, dynamic>.from(jsonDecode(File('$projectDir/agent_anim.lmproject').readAsStringSync()) as Map));
    final vm = EditorViewModel(initialProject: project, projectLocation: root.path, enableTimers: false);
    await tester.runAsync(vm.ensureDefaultLevelAssets);

    final server = vm.mcpServer;
    expect(await tester.runAsync(() => server.start(port: 0)), isTrue);
    final client = McpTestClient(server.url!, server.token);

    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final boundaryKey = GlobalKey();
    try {
      await tester.pumpWidget(RepaintBoundary(
        key: boundaryKey,
        child: ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)),
      ));

      Future<void> settle([int frames = 20]) async {
        for (var i = 0; i < frames; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
        }
      }

      await settle(60);
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));

      Future<void> shot(String name) async {
        await rec.hold(const Duration(milliseconds: 400));
        final png = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
        SmokeArtifacts.saveScreenshot(name, png, usedAssets: usedAssets);
        await rec.hold(const Duration(milliseconds: 700));
      }

      /// A call the editor answers while the recorder keeps pumping frames.
      Future<McpToolReply> call(String tool, [Map<String, Object?> args = const {}]) async {
        McpToolReply? reply;
        Object? error;
        unawaited(client.callTool(tool, args).then((r) => reply = r, onError: (Object e) => error = e));
        while (reply == null && error == null) {
          await rec.hold(const Duration(milliseconds: 66));
        }
        if (error != null) throw error!;
        return reply!;
      }

      Future<Map<String, Object?>> ok(String tool, [Map<String, Object?> args = const {}]) async {
        final reply = await call(tool, args);
        expect(reply.isError, isFalse, reason: '$tool: ${reply.text}');
        return reply.data;
      }

      /// The agent's own screenshot, saved as it received it.
      Future<void> agentShot(String asset, String name) async {
        final reply = await call('asset_editor_screenshot', {'asset': asset, 'max_width': 1400});
        expect(reply.isError, isFalse, reason: reply.text);
        final image = reply.content.firstWhere((c) => c['type'] == 'image');
        SmokeArtifacts.saveScreenshot(name, base64Decode(image['data'] as String), usedAssets: usedAssets);
        debugPrint('[mcp10_smoke] ${reply.text}');
      }

      await tester.runAsync(() => client.handshake(clientName: 'claude-code'));

      // --- The mannequin, the walk clip, the barrel and the card, imported ------
      for (final f in files) {
        await ok('import_asset', {'path': f});
      }
      const manny = 'contents/meshes/skeletal/SKM_Manny_Simple.lmas';
      const walk = 'contents/animations/MF_Unarmed_Walk_Fwd/MF_Unarmed_Walk_Fwd.lmas';
      const barrelMesh = 'contents/meshes/static/fuel_barrel_red.lmas';
      const card = 'contents/meshes/static/access_card_blue.lmas';
      final spawned = await ok('spawn_actor_from_asset', {'asset': barrelMesh, 'location': [0, 250, 0]});
      final barrelId = (spawned['actor'] as Map)['id'] as String;
      await ok('focus_actor', {'id': barrelId});
      await settle(30);

      // --- 1. ABP_Agent: Idle → Moving on GroundSpeed > 10, and back ----------
      const quinn = LuminaThirdPersonContent.projectMeshAssetPath;
      final abp = (await ok('create_asset', {'type': 'animBlueprint', 'name': 'Agent', 'target_mesh': quinn}))['path'] as String;
      final doc = await ok('get_anim_blueprint', {'asset': abp});
      final clips = (doc['clips'] as List).cast<String>();
      final idleClip = clips.firstWhere((c) => c.contains('Idle'), orElse: () => clips.first);
      final moveClip = clips.firstWhere((c) => c.contains('Walk_Fwd'), orElse: () => clips[1]);
      await ok('add_anim_variable', {'asset': abp, 'name': 'GroundSpeed', 'type': 'float', 'default': 0});
      await ok('set_anim_state_pose', {'asset': abp, 'state': 'Idle', 'pose': {'kind': 'clip', 'clip': idleClip}});
      await ok('move_anim_state', {'asset': abp, 'state': 'Idle', 'x': 80, 'y': 120});
      await ok('add_anim_state', {'asset': abp, 'name': 'Moving', 'x': 420, 'y': 120, 'pose': {'kind': 'clip', 'clip': moveClip}});
      Future<void> rule(String from, String to, String compare) async {
        final t = await ok('add_anim_transition', {'asset': abp, 'from': from, 'to': to, 'blend_duration': 0.2});
        final graph = 'transition:${t['id']}';
        final result = t['result_node'] as Map;
        final get = (await ok('add_anim_graph_node', {'asset': abp, 'graph': graph, 'node': 'variable_get', 'x': 0, 'y': 80, 'literals': {'variable': 'GroundSpeed'}}))['node'] as Map;
        final cmp = (await ok('add_anim_graph_node', {'asset': abp, 'graph': graph, 'node': compare, 'x': 220, 'y': 80, 'literals': {'b': 10}}))['node'] as Map;
        await ok('connect_anim_graph_pins', {
          'asset': abp,
          'graph': graph,
          'from_node': get['id'],
          'from_pin': ((get['outputs'] as List).cast<Map>().firstWhere((p) => p['type'] == 'float'))['id'],
          'to_node': cmp['id'],
          'to_pin': 'a',
        });
        await ok('connect_anim_graph_pins', {
          'asset': abp,
          'graph': graph,
          'from_node': cmp['id'],
          'from_pin': ((cmp['outputs'] as List).cast<Map>().first)['id'],
          'to_node': result['id'],
          'to_pin': 'can_enter',
        });
        await settle(10);
      }

      await rule('Idle', 'Moving', 'float_greater');
      await shot('mcp10_abp_idle_to_moving_rule_graph');
      await rule('Moving', 'Idle', 'float_less');
      final compiled = await ok('compile_anim_blueprint', {'asset': abp, 'save': true});
      expect(compiled['status'], isNot('error'), reason: '${compiled['compile_rows']}');
      expect(File('$projectDir/lib/anim/abp_agent.dart').existsSync(), isTrue);
      await ok('get_anim_blueprint', {'asset': abp});
      final abpVm = vm.editorSessionFor(vm.currentTab.id) as AnimBlueprintEditorViewModel;
      await settle(30);
      // Sweep the owner from standing to a walk while the Filament preview plays.
      String? state;
      for (final speed in [0, 60, 120, 180, 240, 300]) {
        state = (await ok('anim_blueprint_preview', {'asset': abp, 'overrides': {'GroundSpeed': speed}, 'frames': 20}))['preview_state'] as String?;
        await rec.hold(const Duration(milliseconds: 500));
      }
      expect(state, 'Moving', reason: abpVm.previewError ?? '');
      expect(abpVm.preview.hasNativeWorld, isTrue, reason: 'the preview renders through flutter_filament');
      await shot('mcp10_abp_preview_moving_at_300');
      await agentShot(abp, 'mcp_anim_blueprint_screenshot_as_the_agent_received_it');
      state = (await ok('anim_blueprint_preview', {'asset': abp, 'overrides': {'GroundSpeed': 0}, 'frames': 40}))['preview_state'] as String?;
      expect(state, 'Idle');
      await rec.hold(const Duration(milliseconds: 800));

      // --- 2. A hand_r_keycard socket with the access card in the hand --------
      final socket = await ok('add_skeletal_socket', {'asset': manny, 'bone': 'hand_r', 'name': 'hand_r_keycard'});
      expect(socket['name'], 'hand_r_keycard');
      await ok('set_skeletal_socket', {
        'asset': manny,
        'socket': 'hand_r_keycard',
        'location': [5, 0, 2],
        'rotation': [0, 0, 90],
        'preview_asset': card,
      });
      await ok('save_skeletal_mesh', {'asset': manny});
      await settle(40);
      // The card is attached to hand_r in the Filament preview.
      final viewport = tester.widgetList<SubEditor3DViewport>(find.byType(SubEditor3DViewport))
          .where((v) => v.socketAttachments.isNotEmpty)
          .toList();
      expect(viewport, hasLength(1), reason: 'the Skeletal Mesh preview carries the socket attachment');
      final attachment = viewport.single.socketAttachments.single;
      expect(attachment.boneName, 'hand_r');
      expect(attachment.assetPath.replaceAll(r'\', '/'), endsWith(card));
      await shot('mcp10_skeletal_mesh_hand_r_keycard_socket');
      // The card itself, without the bone and socket overlays over it: out
      // along the fingers (a right-hand bone's −X points to the fingertips).
      await tester.tap(find.text('Show Bones'));
      await tester.tap(find.text('Display Sockets'));
      await ok('set_skeletal_socket', {'asset': manny, 'socket': 'hand_r_keycard', 'location': [-14, 0, 0], 'rotation': [0, 0, 0]});
      await ok('save_skeletal_mesh', {'asset': manny});
      await settle(40);
      await shot('mcp10_skeletal_mesh_keycard_in_hand_r_overlays_off');
      // The same frame with the preview cleared: the difference is the card.
      await ok('set_skeletal_socket', {'asset': manny, 'socket': 'hand_r_keycard', 'preview_asset': ''});
      await settle(20);
      await shot('mcp10_skeletal_mesh_hand_r_without_preview_asset');
      await ok('set_skeletal_socket', {'asset': manny, 'socket': 'hand_r_keycard', 'preview_asset': card});
      await ok('save_skeletal_mesh', {'asset': manny});
      await settle(20);
      await agentShot(manny, 'mcp_skeletal_mesh_screenshot_as_the_agent_received_it');

      // --- 3. A Footstep_L notify on the walk clip ------------------------------
      final notify = await ok('add_animation_notify', {'asset': walk, 'name': 'Footstep_L', 'time': 0.25, 'type': 'footstep'});
      expect(notify['time'], 0.25);
      await ok('animation_preview', {'asset': walk, 'action': 'seek', 'time': 0.25});
      await ok('save_animation', {'asset': walk});
      await settle(30);
      await shot('mcp10_animation_footstep_notify');
      await agentShot(walk, 'mcp_animation_screenshot_as_the_agent_received_it');

      // --- 4. SEQ_AgentFlyby: the barrel rises, scrubbed in the level, rendered -
      const seq = 'contents/sequencers/SEQ_AgentFlyby.lmas';
      await ok('create_asset', {'type': 'sequencer', 'name': 'SEQ_AgentFlyby'});
      final track = ((await ok('add_sequencer_track', {'asset': seq, 'actor': barrelId, 'kind': 'transform'}))['track'] as Map)['id'];
      await ok('add_sequencer_key', {'asset': seq, 'track': track, 'channel': 'Location.Z', 'frame': 0, 'value': 0});
      await ok('add_sequencer_key', {'asset': seq, 'track': track, 'channel': 'Location.Z', 'frame': 60, 'value': 200, 'interpolation': 'cubic'});
      await ok('add_sequencer_key', {'asset': seq, 'track': track, 'channel': 'Rotation.Z', 'frame': 0, 'value': 0});
      await ok('add_sequencer_key', {'asset': seq, 'track': track, 'channel': 'Rotation.Z', 'frame': 60, 'value': 180});
      await ok('set_sequence_playback', {'asset': seq, 'fps': 30, 'length_frames': 90, 'range': [0, 60]});
      await settle(20);
      await shot('mcp10_sequencer_barrel_keys');
      await agentShot(seq, 'mcp_sequencer_screenshot_as_the_agent_received_it');
      await ok('select_tab', {'index': 0});
      await ok('set_camera', {'target': [0, 250, 100], 'distance': 650, 'pitch': 12, 'yaw': 30});
      await settle(20);
      for (var f = 0; f <= 60; f += 6) {
        await ok('scrub_sequence', {'asset': seq, 'frame': f});
        await rec.hold(const Duration(milliseconds: 200));
      }
      final z = vm.actors.firstWhere((a) => a.id == barrelId).location[2];
      expect(z, closeTo(200, 1e-6), reason: 'the scrub moved the level barrel');
      await shot('mcp10_sequencer_scrub_barrel_risen_in_level');
      await ok('stop_sequence', {'asset': seq});
      expect(vm.actors.firstWhere((a) => a.id == barrelId).location[2], 0.0);
      final render = await ok('render_sequence', {
        'asset': seq,
        'width': 640,
        'height': 360,
        'start_frame': 0,
        'end_frame': 29,
        'output_name': 'agent_flyby',
        'save_first': true,
      });
      final job = render['job_id'] as String;
      Map<String, Object?> status = {};
      for (var i = 0; i < 20; i++) {
        status = await ok('wait_job', {'id': job, 'timeout_ms': 5000});
        if (status['timed_out'] != true) break;
      }
      expect(status['state'], 'succeeded', reason: '$status');
      final out = Directory('$projectDir/saved/movie_renders/agent_flyby');
      final pngs = out.listSync().whereType<File>().where((f) => f.path.endsWith('.png')).toList()..sort((a, b) => a.path.compareTo(b.path));
      expect(pngs, hasLength(30));
      SmokeArtifacts.saveScreenshot('mcp10_movie_render_first_frame', pngs.first.readAsBytesSync(), usedAssets: usedAssets);
      debugPrint('[mcp10_smoke] rendered ${pngs.length} frames to ${out.path}');

      // --- 5. PS_AgentSparks: a barrel-mesh Embers emitter, played --------------
      const ps = 'contents/particles/PS_AgentSparks.lmas';
      await ok('create_asset', {'type': 'particle', 'name': 'PS_AgentSparks'});
      await ok('get_particle_system', {'asset': ps});
      await ok('add_particle_emitter', {'asset': ps, 'name': 'Embers'});
      await ok('set_particle_emitter', {
        'asset': ps,
        'emitter': 'Embers',
        'spawn_rate': 120,
        'max_particles': 400,
        'lifetime': [0.5, 1.5],
        'cone_angle_degrees': 25,
        'drag': 0.2,
      });
      await ok('add_particle_burst', {'asset': ps, 'emitter': 'Embers', 'time': 0, 'count': 50});
      await ok('set_particle_render', {'asset': ps, 'emitter': 'Embers', 'mesh': barrelMesh});
      await ok('save_particle_system', {'asset': ps});
      await settle(30);
      final played = await ok('particle_preview', {'asset': ps, 'action': 'play', 'frames': 30});
      expect(played['active_particles'] as int, greaterThan(0));
      final psVm = vm.editorSessionFor(vm.currentTab.id) as ParticleEditorViewModel;
      expect(psVm.emitters.last.config.meshAssetPath, barrelMesh);
      await rec.hold(const Duration(milliseconds: 1500));
      await shot('mcp10_particles_embers_playing');
      await agentShot(ps, 'mcp_particle_screenshot_as_the_agent_received_it');

      // The agent flips between the editors until the video is long enough.
      final tabs = [abp, manny, walk, seq, ps];
      for (var i = 0; rec.recorded < const Duration(milliseconds: 10300) && i < 40; i++) {
        await ok('open_asset_editor', {'asset': tabs[i % tabs.length]});
        await rec.hold(const Duration(milliseconds: 700));
      }
      rec.save(scenario, usedAssets: usedAssets);
    } finally {
      client.close();
      await tester.runAsync(server.stop);
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
      try {
        root.deleteSync(recursive: true);
      } catch (_) {}
    }
  }, timeout: const Timeout(Duration(minutes: 20)));
}
