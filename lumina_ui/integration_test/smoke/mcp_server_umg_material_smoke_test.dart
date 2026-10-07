import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/material_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/umg_editor_view_model.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../test/helpers/mcp_test_client.dart';

/// MCP server UMG and material smoke (beside `mcp_server_smoke_test.dart`, which is at the
/// 1100-line limit): an MCP client (JSON-RPC over HTTP) lays out a HUD
/// Widget Blueprint — a stats box with a Health label and bar, a Heal button
/// and an image of the barrel texture — binds OnClicked to a Print String and
/// compiles it to Dart, then builds a material from nodes (a Texture Sample of
/// the barrel texture times a colour parameter into Base Color, a scalar into
/// Roughness), compiles it and shows it on the preview sphere. The designer
/// canvas, the hierarchy and the graph update live on video; the agent's own
/// asset_editor_screenshot frames are saved as it received them.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const scenario = 'MCP Smoke: an agent builds a HUD widget and a material node graph';
  testWidgets(scenario, (tester) async {
    final barrel = File('${SmokeArtifacts.testAssetsDir.path}/Props/Barrels/fuel_barrel_red.glb');
    expect(barrel.existsSync(), isTrue, reason: 'test-assets must hold the red fuel barrel');
    final usedAssets = [barrel.path];

    final root = Directory.systemTemp.createTempSync('lumina_smoke_mcp09_');
    final projectDir = Directory('${root.path}/AgentHud')..createSync();
    const project = LuminaProject(projectName: 'AgentHud', activeLevel: 'contents/levels/L_Main.lmas');
    File('${projectDir.path}/AgentHud.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
    Directory('${projectDir.path}/contents/levels').createSync(recursive: true);
    Directory('${projectDir.path}/lib').createSync(recursive: true);
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

      await settle(40);
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));

      Future<void> shot(String name) async {
        await rec.hold(const Duration(milliseconds: 400));
        final png = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
        SmokeArtifacts.saveScreenshot(name, png, usedAssets: usedAssets);
        await rec.hold(const Duration(milliseconds: 900));
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
        debugPrint('[mcp09_smoke] ${reply.text}');
      }

      await tester.runAsync(() => client.handshake(clientName: 'claude-code'));

      // --- The barrel and its texture, through the real import pipeline --------
      final imported = (await ok('import_asset', {'path': barrel.path}))['imported'] as List;
      final texture = (imported.cast<Map>().firstWhere((a) => a['type'] == 'texture'))['path'] as String;
      debugPrint('[mcp09_smoke] the barrel texture: $texture');

      // --- A HUD Widget Blueprint, laid out widget by widget --------------------
      const hud = 'contents/widgets/WBP_AgentHud.lmas';
      await ok('create_asset', {'type': 'widget', 'name': 'WBP_AgentHud'});
      final tree = await ok('get_widget_tree', {'asset': hud});
      final rootId = (tree['root'] as Map)['id'];
      await settle(20);
      await ok('add_widget', {'asset': hud, 'type': 'verticalBox', 'parent': rootId, 'x': 64, 'y': 64, 'name': 'StatsBox'});
      await ok('set_widget_slot', {'asset': hud, 'widget': 'StatsBox', 'size': [360, 140]});
      await ok('add_widget', {
        'asset': hud,
        'type': 'text',
        'parent': 'StatsBox',
        'name': 'HealthLabel',
        'props': {'text': 'Health', 'fontSize': 28, 'color': '#FFD166'},
      });
      await ok('set_widget_slot', {'asset': hud, 'widget': 'HealthLabel', 'padding': [8, 8, 8, 4]});
      await ok('add_widget', {'asset': hud, 'type': 'progressBar', 'parent': 'StatsBox', 'name': 'HealthBar', 'props': {'percent': 0.75}});
      await ok('set_widget_slot', {'asset': hud, 'widget': 'HealthBar', 'padding': [8, 4, 8, 8], 'fill': true});
      await settle(10);
      await shot('mcp09_umg_stats_box');
      await ok('add_widget', {
        'asset': hud,
        'type': 'button',
        'parent': rootId,
        'name': 'HealButton',
        'x': 64,
        'y': 240,
        'props': {'label': 'Heal'},
      });
      await ok('set_widget_slot', {'asset': hud, 'widget': 'HealButton', 'size': [200, 56]});
      await ok('add_widget', {'asset': hud, 'type': 'image', 'parent': rootId, 'name': 'BarrelIcon', 'x': 480, 'y': 64, 'props': {'texture': texture}});
      await ok('set_widget_slot', {'asset': hud, 'widget': 'BarrelIcon', 'size': [240, 240]});
      await settle(10);
      await shot('mcp09_umg_heal_button_and_barrel_image');

      // OnClicked → Print String, wired with the Blueprint tools.
      final bound = await ok('bind_widget_event', {'asset': hud, 'widget': 'HealButton', 'event': 'OnClicked'});
      final printNode = ((await ok('add_blueprint_node', {'asset': hud, 'node': 'print_string', 'x': 420, 'y': 120}))['node'] as Map)['id'];
      await ok('connect_blueprint_pins', {
        'asset': hud,
        'from_node': bound['node_id'],
        'from_pin': bound['exec_pin'],
        'to_node': printNode,
        'to_pin': 'exec_in',
      });
      await ok('set_blueprint_pin_literal', {'asset': hud, 'node': printNode, 'pin': 'in_string', 'value': 'healed via mcp'});
      await settle(10);
      await shot('mcp09_umg_on_clicked_print_string_graph');
      final compiled = await ok('compile_widget', {'asset': hud});
      expect(compiled['ok'], isTrue, reason: '$compiled');
      final dart = File('${projectDir.path}/lib/widgets/wbp_agent_hud.dart');
      expect(dart.readAsStringSync(), allOf(contains('Health'), contains('healed via mcp')));
      await ok('set_widget_designer', {'asset': hud, 'mode': 'designer'});
      final designer = vm.editorSessionFor(vm.currentTab.id);
      expect(designer, isA<UmgEditorViewModel>());
      expect((designer as UmgEditorViewModel).document.allNodes.map((n) => n.name), containsAll(['StatsBox', 'HealButton', 'BarrelIcon']));
      await settle(10);
      await shot('mcp09_umg_compiled_designer');
      await agentShot(hud, 'mcp_umg_screenshot_as_the_agent_received_it');

      // --- A material built from nodes ------------------------------------------
      const mat = 'contents/materials/M_AgentGraph.lmas';
      await ok('create_asset', {'type': 'filamat', 'name': 'M_AgentGraph'});
      final initial = await ok('get_material_graph', {'asset': mat});
      await settle(20);
      // The user watches the Node Graph tab while the agent works.
      await tester.tap(find.text('Node Graph').last);
      await settle(10);
      final sample = ((await ok('add_material_node', {
        'asset': mat,
        'node': 'mat_texture_sample',
        'x': -700,
        'y': -80,
        'settings': {'parameter': 'BarrelTex'},
      }))['node'] as Map)['id'];
      final tint = ((await ok('add_material_node', {
        'asset': mat,
        'node': 'mat_vector_parameter',
        'x': -700,
        'y': 200,
        'settings': {'name': 'Tint', 'default': [1.0, 0.85, 0.7, 1.0]},
      }))['node'] as Map)['id'];
      final multiply = ((await ok('add_material_node', {'asset': mat, 'node': 'mat_multiply', 'x': -350, 'y': 40}))['node'] as Map)['id'];
      final rough = ((await ok('add_material_node', {
        'asset': mat,
        'node': 'mat_scalar_parameter',
        'x': -350,
        'y': 320,
        'settings': {'name': 'AgentRoughness', 'default': 0.45},
      }))['node'] as Map)['id'];
      await ok('connect_material_pins', {'asset': mat, 'from_node': sample, 'from_pin': 'rgb', 'to_node': multiply, 'to_pin': 'a'});
      await ok('connect_material_pins', {'asset': mat, 'from_node': tint, 'from_pin': 'rgb', 'to_node': multiply, 'to_pin': 'b'});
      await ok('connect_material_pins', {'asset': mat, 'from_node': multiply, 'from_pin': 'out', 'to_node': 'material_output', 'to_pin': 'base_color'});
      final wired = await ok('connect_material_pins', {
        'asset': mat,
        'from_node': rough,
        'from_pin': 'out',
        'to_node': 'material_output',
        'to_pin': 'roughness',
      });
      expect((wired['sync'] as Map)['ahead'], isFalse, reason: '${wired['diagnostics']}');
      // The default material's own nodes go: the graph is the agent's.
      final ours = {sample, tint, multiply, rough, 'material_output'};
      for (final n in (initial['nodes'] as List).cast<Map>()) {
        if (!ours.contains(n['id'])) await ok('remove_material_node', {'asset': mat, 'node': n['id']});
      }
      await ok('arrange_material_graph', {'asset': mat});
      final bind = await ok('set_material_texture', {'asset': mat, 'parameter': 'BarrelTex', 'texture': texture});
      expect(bind['texture'], texture);
      await ok('set_material_parameter', {'asset': mat, 'name': 'AgentRoughness', 'value': 0.35});
      await settle(10);
      await shot('mcp09_material_graph_nodes_wired');
      final source = (await ok('get_material_source', {'asset': mat}))['source'] as String;
      expect(source, allOf(contains('BarrelTex'), contains('Tint'), contains('AgentRoughness')));
      final compiledMat = await call('compile_material', {'asset': mat, 'save': true});
      expect(compiledMat.data['ok'], isTrue, reason: compiledMat.text);
      final editor = vm.editorSessionFor(vm.currentTab.id) as MaterialEditorViewModel;
      expect(editor.parameters.firstWhere((p) => p.name == 'BarrelTex').textureRef?.assetPath, texture);
      await settle(40);
      await shot('mcp09_material_compiled_preview_sphere_barrel_texture');
      await agentShot(mat, 'mcp_material_graph_screenshot_as_the_agent_received_it');

      // The agent flips between the two tabs until the video is long enough.
      for (var i = 0; rec.recorded < const Duration(milliseconds: 10300) && i < 40; i++) {
        await ok('open_asset_editor', {'asset': i.isEven ? hud : mat});
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
  }, timeout: const Timeout(Duration(minutes: 15)));
}
