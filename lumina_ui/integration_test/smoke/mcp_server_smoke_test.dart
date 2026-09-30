import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart' show PointerDeviceKind, kSecondaryButton;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/details_widget.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_tool.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/blueprint_sub_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/graph_canvas.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../test/helpers/mcp_test_client.dart';
import '../../test/helpers/scaffold_game_project.dart';

/// 03: an MCP client (JSON-RPC over HTTP, nothing shared with
/// the server) drives the real editor while the recorder runs: the AI Agent
/// Access tab, a barrel from test-assets placed through
/// `spawn_actor_from_asset`, moved across the viewport with
/// `set_actor_transform`, undone and redone; then a material created, broken,
/// compiled (the tab shows the error), fixed and compiled with the real
/// filamat compiler; then a Blueprint with a Print String on BeginPlay wired
/// and compiled to Dart, the graph canvas showing the node; then the camera
/// framed, a viewport screenshot taken as MCP image content, Play started,
/// the log read and Play stopped. The editor must react live: every step is
/// on video.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  mcpRiskAndTrashScenario(binding);
  mcpDoorBlueprintScenario(binding);
  mcpFileAndCodeScenario(binding);
  mcpLevelBlockoutScenario(binding);
  mcpSelectionScenario(binding);

  testWidgets('MCP Smoke: an agent places and moves a barrel, compiles a material, authors a Blueprint, screenshots and plays through the editor\'s MCP server',
      (tester) async {
    final barrel = File('${SmokeArtifacts.testAssetsDir.path}/Props/Barrels/fuel_barrel_red.glb');
    expect(barrel.existsSync(), isTrue, reason: 'test-assets must hold ${barrel.path}');

    final tempProjectsDir = Directory.systemTemp.createTempSync('lumina_smoke_mcp_');
    final pDir = Directory('${tempProjectsDir.path}/SmokeMcp')..createSync(recursive: true);
    const project = LuminaProject(projectName: 'SmokeMcp', activeLevel: 'contents/levels/L_Main.lmas');
    File('${pDir.path}/SmokeMcp.lmproject').writeAsStringSync(jsonEncode(project.toMap()));

    final vm = EditorViewModel(initialProject: project, projectLocation: tempProjectsDir.path);
    await tester.runAsync(() => vm.ensureDefaultLevelAssets());
    await tester.runAsync(() => vm.processImportPipeline(sourceFilePath: barrel.path));
    final mesh = vm.realAssets.firstWhere((a) => a.type == AssetType.filamesh && a.fileName.contains('fuel_barrel_red'));

    // The server under test is the editor's own (`vm.mcpServer`, the one the
    // AI Agent Access tab shows), on an ephemeral port; its connection file
    // lands in this run's temp LuminaConfigDir (integration_test/
    // flutter_test_config.dart), so a running editor's port and
    // ~/.config/lumina are never touched.
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
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)),
        ),
      );

      Future<void> settle([int frames = 20]) async {
        for (var i = 0; i < frames; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
        }
      }

      await settle(40);
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      final usedAssets = [barrel.path];

      Future<void> shot(String name) async {
        final png = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
        SmokeArtifacts.saveScreenshot(name, png, usedAssets: usedAssets);
        await rec.hold(const Duration(milliseconds: 1200));
      }

      Future<McpToolReply> call(String tool, [Map<String, Object?> args = const {}]) async {
        final reply = (await tester.runAsync(() => client.callTool(tool, args)))!;
        await settle(10);
        return reply;
      }

      // --- The tab a user opens to connect an agent -------------------------
      await rec.hold(const Duration(seconds: 1));
      vm.commands.execute('tools.aiAgentAccess');
      await settle(15);
      expect(find.text('LISTENING'), findsOneWidget);
      expect(find.text(server.url!), findsOneWidget);
      await shot('mcp_ai_agent_access_tab');

      // --- The handshake, as Claude Code does it ----------------------------
      final init = (await tester.runAsync(client.handshake))!;
      expect((init['serverInfo'] as Map)['name'], 'lumina-studio');
      final tools = (await tester.runAsync(client.listTools))!;
      expect(tools.map((t) => t['name']), contains('spawn_actor_from_asset'));

      // Back to the level so the viewport shows what the agent does.
      vm.selectTab(0);
      await settle(15);
      await rec.hold(const Duration(milliseconds: 800));

      // --- The agent places the barrel -------------------------------------
      final actorsBefore = vm.actors.length;
      final spawned = await call('spawn_actor_from_asset', {'asset': mesh.relativePath, 'location': [0, 0, 0]});
      expect(spawned.isError, isFalse, reason: spawned.text);
      expect(vm.actors.length, actorsBefore + 1);
      final actor = vm.actors.last;
      expect(actor.meshData, isNotNull, reason: 'the barrel must draw');
      expect(find.text(actor.name), findsWidgets, reason: 'the Outliner lists the placed actor');
      vm.focusCameraOnActor(actor);
      await settle(20);
      await shot('mcp_barrel_placed');

      // --- The agent moves it across the viewport, step by step ------------
      for (var i = 1; i <= 8; i++) {
        final moved = await call('set_actor_transform', {
          'id': actor.id,
          'location': [25.0 * i, 0, 0],
        });
        expect(moved.isError, isFalse, reason: moved.text);
        await rec.hold(const Duration(milliseconds: 250));
      }
      expect(actor.location[0], 200.0);
      final rotated = await call('set_actor_transform', {
        'id': actor.id,
        'rotation': [0, 0, 45],
      });
      expect(rotated.isError, isFalse, reason: rotated.text);
      await shot('mcp_barrel_moved_and_rotated');

      // --- Undo and redo through MCP: Edit → Undo would do the same -------
      final undone = await call('undo');
      expect(undone.isError, isFalse, reason: undone.text);
      expect(actor.rotation[2], 0.0);
      await rec.hold(const Duration(milliseconds: 600));
      final undoneMove = await call('undo');
      expect(undoneMove.isError, isFalse, reason: undoneMove.text);
      expect(actor.location[0], 175.0);
      await shot('mcp_after_undo');
      final redone = await call('redo');
      expect(redone.isError, isFalse, reason: redone.text);
      expect(actor.location[0], 200.0);
      await rec.hold(const Duration(milliseconds: 600));

      // --- Saved to disk as File → Save Level would ------------------------
      final saved = await call('save_level');
      expect(saved.isError, isFalse, reason: saved.text);
      final level = jsonDecode(File('${vm.projectDirPath}/contents/levels/L_Main.lmas').readAsStringSync()) as Map;
      final actors = ((level['metadata'] as Map)['actors'] as List).cast<Map>();
      expect(actors.any((a) => a['id'] == actor.id && (a['location'] as List)[0] == 200.0), isTrue);

      // --- a material, compiled with the real compiler -------------------
      final created = await call('create_asset', {'type': 'filamat', 'name': 'M_Agent'});
      expect(created.isError, isFalse, reason: created.text);
      final broken = await call('set_material_source', {'asset': 'M_Agent', 'source': _brokenMaterial});
      expect(broken.isError, isFalse, reason: broken.text);
      expect(vm.currentTab.category, 'Material', reason: 'the Material editor tab opened for the edit');
      await settle(20);
      final failed = await call('compile_material', {'asset': 'M_Agent'});
      expect(failed.data['ok'], isFalse, reason: 'an undeclared parameter cannot compile');
      await settle(20);
      await shot('mcp_material_compile_error');
      await call('set_material_source', {'asset': 'M_Agent', 'source': _goodMaterial});
      final compiled = await call('compile_material', {'asset': 'M_Agent', 'save': true});
      expect(compiled.data['ok'], isTrue, reason: compiled.text);
      await settle(30);
      await shot('mcp_material_compiled');

      // --- a Blueprint authored node by node ------------------------------
      final bp = await call('create_asset', {'type': 'actor', 'name': 'BP_Agent', 'parent_class': 'LuminaActor'});
      expect(bp.isError, isFalse, reason: bp.text);
      const bpAsset = 'contents/blueprints/BP_Agent.lmas';
      var graph = (await call('get_blueprint', {'asset': bpAsset})).data;
      expect(vm.currentTab.category, 'Blueprint', reason: 'the Blueprint editor tab opened for the edit');
      var beginPlay = ((graph['nodes'] as List).cast<Map>().where((n) => n['node'] == 'event_beginplay').firstOrNull)?['id'] as String?;
      beginPlay ??= ((await call('add_blueprint_node', {'asset': bpAsset, 'node': 'event_beginplay', 'x': 60, 'y': 80})).data['node'] as Map)['id'] as String;
      await rec.hold(const Duration(milliseconds: 500));
      final printNode = ((await call('add_blueprint_node', {'asset': bpAsset, 'node': 'print_string', 'x': 360, 'y': 90})).data['node'] as Map)['id'] as String;
      await rec.hold(const Duration(milliseconds: 500));
      final wired = await call('connect_blueprint_pins', {
        'asset': bpAsset, 'from_node': beginPlay, 'from_pin': 'exec_out', 'to_node': printNode, 'to_pin': 'exec_in',
      });
      expect(wired.isError, isFalse, reason: wired.text);
      await call('set_blueprint_pin_literal', {'asset': bpAsset, 'node': printNode, 'pin': 'in_string', 'value': 'hello from mcp'});
      await settle(20);
      await shot('mcp_blueprint_node_wired');
      final bpCompiled = await call('compile_blueprint', {'asset': bpAsset, 'save': true});
      expect(bpCompiled.data['status'], isNot('error'), reason: bpCompiled.text);
      expect(File(bpCompiled.data['generated_file'] as String).readAsStringSync(), contains('hello from mcp'));
      graph = (await call('get_blueprint', {'asset': bpAsset})).data;
      expect((graph['wires'] as List), isNotEmpty);
      await settle(20);
      await shot('mcp_blueprint_compiled');
      vm.selectTab(0);
      await settle(10);

      // --- frame the barrel, screenshot it, Play, read the log
      final framed = await call('set_camera', {'yaw': -35, 'pitch': 25, 'distance': 500, 'target': [200, 0, 40]});
      expect(framed.isError, isFalse, reason: framed.text);
      await settle(20);
      final shotReply = await call('viewport_screenshot', {'max_width': 1600});
      expect(shotReply.isError, isFalse, reason: shotReply.text);
      final agentPng = base64Decode(shotReply.content.firstWhere((c) => c['type'] == 'image')['data'] as String);
      // The agent's own view of the level goes into the report beside the
      // recorder's frames: what the agent saw is what the user saw.
      SmokeArtifacts.saveScreenshot('mcp_viewport_screenshot_as_the_agent_received_it', agentPng, usedAssets: usedAssets);
      await rec.hold(const Duration(milliseconds: 800));

      final playing = await call('start_pie');
      expect(playing.isError, isFalse, reason: playing.text);
      expect(vm.isPlaying, isTrue);
      await rec.hold(const Duration(seconds: 2));
      expect((await call('pie_status')).data['playing'], isTrue);
      await shot('mcp_play_in_editor_running');
      final pieLog = (await call('read_output_log', {'contains': 'PIE'})).data;
      expect((pieLog['entries'] as List), isNotEmpty);
      final stoppedPie = await call('stop_pie');
      expect(stoppedPie.isError, isFalse, reason: stoppedPie.text);
      expect(vm.isPlaying, isFalse);
      await settle(20);
      await rec.hold(const Duration(milliseconds: 600));

      // The panel lists what the agent did.
      vm.commands.execute('tools.aiAgentAccess');
      await settle(15);
      expect(find.text('save_level'), findsWidgets);
      expect(find.text('compile_blueprint'), findsWidgets);
      expect(find.text('stop_pie'), findsWidgets);
      await shot('mcp_recent_calls');

      rec.save('MCP Smoke: an agent places and moves a barrel, compiles a material, authors a Blueprint, screenshots and plays through the editor\'s MCP server',
          usedAssets: usedAssets);
    } finally {
      client.close();
      await tester.runAsync(server.stop);
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
      try {
        tempProjectsDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });
}

/// Risk levels, agent-attributed undo and the project trash.
void mcpRiskAndTrashScenario(IntegrationTestWidgetsFlutterBinding binding) {
  testWidgets('MCP Smoke: risk catalogue, agent-only undo, the risk ceiling and the project trash', (tester) async {
    final red = File('${SmokeArtifacts.testAssetsDir.path}/Props/Barrels/fuel_barrel_red.glb');
    final dented = File('${SmokeArtifacts.testAssetsDir.path}/Props/Barrels/dented_barrel.glb');
    expect(red.existsSync() && dented.existsSync(), isTrue, reason: 'test-assets must hold the barrels');

    final tempProjectsDir = Directory.systemTemp.createTempSync('lumina_smoke_mcp_risk_');
    final pDir = Directory('${tempProjectsDir.path}/SmokeMcpRisk')..createSync(recursive: true);
    const project = LuminaProject(projectName: 'SmokeMcpRisk', activeLevel: 'contents/levels/L_Main.lmas');
    File('${pDir.path}/SmokeMcpRisk.lmproject').writeAsStringSync(jsonEncode(project.toMap()));

    final vm = EditorViewModel(initialProject: project, projectLocation: tempProjectsDir.path);
    await tester.runAsync(() => vm.ensureDefaultLevelAssets());
    await tester.runAsync(() => vm.processImportPipeline(sourceFilePath: red.path));
    await tester.runAsync(() => vm.processImportPipeline(sourceFilePath: dented.path));
    final redMesh = vm.realAssets.firstWhere((a) => a.type == AssetType.filamesh && a.fileName.contains('fuel_barrel_red'));
    final dentedMesh = vm.realAssets.firstWhere((a) => a.type == AssetType.filamesh && a.fileName.contains('dented_barrel'));

    final server = vm.mcpServer;
    expect(await tester.runAsync(() => server.start(port: 0)), isTrue);
    final client = McpTestClient(server.url!, server.token);
    final viewer = McpTestClient('${server.url!}?groups=level,view', server.token);

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
      final usedAssets = [red.path, dented.path];

      Future<void> shot(String name) async {
        final png = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
        SmokeArtifacts.saveScreenshot(name, png, usedAssets: usedAssets);
        await rec.hold(const Duration(milliseconds: 1200));
      }

      Future<McpToolReply> call(McpTestClient c, String tool, [Map<String, Object?> args = const {}]) async {
        final reply = (await tester.runAsync(() => c.callTool(tool, args)))!;
        await settle(10);
        return reply;
      }

      Future<void> openPanel() async {
        vm.commands.execute('tools.aiAgentAccess');
        await settle(15);
      }

      /// Scrolls the AI Agent Access tab to [key] (from the top: the tab keeps
      /// its scroll offset between visits).
      Future<void> reveal(Key key) async {
        final scrollable = find.descendant(of: find.byKey(const ValueKey('mcp_server_panel_scroll')), matching: find.byType(Scrollable)).first;
        tester.state<ScrollableState>(scrollable).position.jumpTo(0);
        await settle(3);
        await tester.scrollUntilVisible(find.byKey(key), 200, scrollable: scrollable);
        await settle(5);
      }

      // --- The catalogue: 373 tools by group, each with its risk ---------------
      await tester.runAsync(() => client.handshake(clientName: 'claude-code'));
      await openPanel();
      await reveal(const ValueKey('mcp_catalogue_header'));
      expect(tester.widget<Text>(find.byKey(const ValueKey('mcp_catalogue_header'))).data,
          '373 tools · 70 read-only · 38 editor state · 234 edits · 24 destructive · 7 external');
      for (final g in ['asset', 'level', 'blueprint', 'material', 'view', 'pie', 'log']) {
        await reveal(ValueKey('mcp_catalogue_group_$g'));
        await tester.tap(find.byKey(ValueKey('mcp_catalogue_group_$g')));
        await settle(5);
      }
      await reveal(const ValueKey('mcp_catalogue_tool_delete_asset'));
      await shot('mcp_risk_catalogue');

      // A second client asks for the level and view groups only.
      await tester.runAsync(() => viewer.handshake(clientName: 'viewer'));
      final viewerTools = (await tester.runAsync(viewer.listTools))!;
      expect(viewerTools, hasLength(47));
      debugPrint('[mcp04_smoke] a ?groups=level,view session lists ${viewerTools.length} tools (the full catalogue: 373)');

      // --- One agent call, one undo step --------------------------------------
      vm.selectTab(0);
      await settle(15);
      final spawned = await call(client, 'spawn_actor_from_asset', {'asset': redMesh.relativePath, 'location': [120, 0, 0]});
      expect(spawned.isError, isFalse, reason: spawned.text);
      final barrel = vm.actors.last;
      final moved = await call(client, 'set_actor_transform', {
        'id': barrel.id,
        'location': [180, 60, 0],
        'rotation': [0, 0, 30],
      });
      expect(moved.isError, isFalse, reason: moved.text);
      expect(vm.transactions.undoLabel, startsWith('Undo MCP: '));
      await tester.tap(find.descendant(of: find.byType(Menubar), matching: find.text('Edit')));
      await settle(10);
      expect(find.textContaining('Undo MCP: '), findsWidgets, reason: 'the Edit menu names the agent step');
      await shot('mcp_edit_menu_agent_undo');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(10);

      // --- The user renames it; the agent may not undo the user's edit --------
      vm.renameActorWithTransaction(barrel.id, 'UserBarrel');
      await settle(10);
      final refused = await call(client, 'undo', {'scope': 'agent'});
      expect(refused.isError, isTrue);
      expect(refused.text, contains("the user's"));
      expect(barrel.name, 'UserBarrel');
      await openPanel();
      await reveal(const ValueKey('mcp_recent_call_0'));
      await shot('mcp_agent_undo_refused');

      // --- Look only: an edit is denied ----------------------------------------
      server.settings.setMaxRisk(McpToolRisk.editorState);
      await settle(5);
      final denied = await call(client, 'spawn_actor', {'type': 'PointLight'});
      expect(jsonDecode(denied.text)['status'], 'denied');
      await reveal(const ValueKey('mcp_recent_call_denied_0'));
      expect(find.byKey(const ValueKey('mcp_recent_call_denied_0')), findsOneWidget);
      await shot('mcp_denied_by_ceiling');
      server.settings.setMaxRisk(McpToolRisk.external);

      // --- delete_asset goes to the trash; restore_asset brings it back --------
      vm.selectTab(0);
      await settle(10);
      final placed = await call(client, 'spawn_actor_from_asset', {'asset': dentedMesh.relativePath, 'location': [-150, 0, 0]});
      expect(placed.isError, isFalse, reason: placed.text);
      final dentedActor = vm.actors.last;
      await rec.hold(const Duration(seconds: 1));
      final deleted = await call(client, 'delete_asset', {'asset': dentedMesh.relativePath});
      expect(deleted.isError, isFalse, reason: deleted.text);
      final trashId = deleted.data['trash_id'] as String;
      expect(vm.actors.any((a) => a.id == dentedActor.id), isFalse);
      expect(vm.realAssets.any((a) => a.relativePath == dentedMesh.relativePath), isFalse);
      await shot('mcp_asset_in_trash');
      final listed = await call(client, 'list_trash');
      expect((listed.data['entries'] as List).map((e) => (e as Map)['trash_id']), contains(trashId));
      await openPanel();
      await reveal(const ValueKey('mcp_trash_summary'));
      expect(tester.widget<Text>(find.byKey(const ValueKey('mcp_trash_summary'))).data, startsWith('1 items'));
      await rec.hold(const Duration(seconds: 1));
      vm.selectTab(0);
      await settle(10);
      final restored = await call(client, 'restore_asset', {'trash_id': trashId});
      expect(restored.isError, isFalse, reason: restored.text);
      expect(vm.actors.any((a) => a.id == dentedActor.id), isTrue);
      expect(vm.realAssets.any((a) => a.relativePath == dentedMesh.relativePath), isTrue);
      await settle(20);
      await shot('mcp_asset_restored');
      // The restore is one undo step too: undo puts it back in the trash.
      final unrestored = await call(client, 'undo');
      expect(unrestored.isError, isFalse, reason: unrestored.text);
      expect(vm.actors.any((a) => a.id == dentedActor.id), isFalse);
      await settle(20);
      await rec.hold(const Duration(milliseconds: 900));
      final rerestored = await call(client, 'redo');
      expect(rerestored.isError, isFalse, reason: rerestored.text);
      expect(vm.actors.any((a) => a.id == dentedActor.id), isTrue);
      await settle(20);
      await rec.hold(const Duration(milliseconds: 900));

      rec.save('MCP Smoke: risk catalogue, agent-only undo, the risk ceiling and the project trash', usedAssets: usedAssets);
    } finally {
      client.close();
      viewer.close();
      await tester.runAsync(server.stop);
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
      try {
        tempProjectsDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });
}

/// Components on a level actor (the Details panel reacting),
/// a door Blueprint built member by member (Components tree, My Blueprint,
/// the function graph tab, a timeline), placed, and the Level Blueprint
/// wired and compiled — every step through `tools/call`.
void mcpDoorBlueprintScenario(IntegrationTestWidgetsFlutterBinding binding) {
  const scenario =
      'MCP Smoke: an agent builds a door Blueprint with components, a function, a variable and a timeline, and wires the Level Blueprint';
  testWidgets(scenario, (tester) async {
    final barrel = File('${SmokeArtifacts.testAssetsDir.path}/Props/Barrels/fuel_barrel_red.glb');
    final acUnit = File('${SmokeArtifacts.testAssetsDir.path}/Props/AC_units/ac_unit_a_300x300.glb');
    expect(barrel.existsSync() && acUnit.existsSync(), isTrue, reason: 'test-assets must hold the barrel and the AC unit');

    final tempProjectsDir = Directory.systemTemp.createTempSync('lumina_smoke_mcp_door_');
    final pDir = Directory('${tempProjectsDir.path}/SmokeMcpDoor')..createSync(recursive: true);
    const project = LuminaProject(projectName: 'SmokeMcpDoor', activeLevel: 'contents/levels/L_Main.lmas');
    File('${pDir.path}/SmokeMcpDoor.lmproject').writeAsStringSync(jsonEncode(project.toMap()));

    final vm = EditorViewModel(initialProject: project, projectLocation: tempProjectsDir.path);
    await tester.runAsync(() => vm.ensureDefaultLevelAssets());
    await tester.runAsync(() => vm.processImportPipeline(sourceFilePath: barrel.path));
    await tester.runAsync(() => vm.processImportPipeline(sourceFilePath: acUnit.path));
    final barrelMesh = vm.realAssets.firstWhere((a) => a.type == AssetType.filamesh && a.fileName.contains('fuel_barrel_red'));
    final acMesh = vm.realAssets.firstWhere((a) => a.type == AssetType.filamesh && a.fileName.contains('ac_unit_a_300x300'));

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
      final usedAssets = [barrel.path, acUnit.path];

      Future<void> shot(String name) async {
        final png = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
        SmokeArtifacts.saveScreenshot(name, png, usedAssets: usedAssets);
        await rec.hold(const Duration(milliseconds: 1200));
      }

      Future<Map<String, Object?>> ok(String tool, [Map<String, Object?> args = const {}]) async {
        final reply = (await tester.runAsync(() => client.callTool(tool, args)))!;
        expect(reply.isError, isFalse, reason: '$tool: ${reply.text}');
        await settle(12);
        return reply.data;
      }

      await tester.runAsync(client.handshake);

      /// Scrolls the Details panel (it builds lazily) until [target] shows.
      Future<void> revealInDetails(Finder target) async {
        final scrollables = find.descendant(of: find.byType(DetailsWidget), matching: find.byType(Scrollable));
        for (var i = 0; i < 60 && target.evaluate().isEmpty; i++) {
          final list = tester.stateList<ScrollableState>(scrollables).firstWhere((s) => s.position.axis == Axis.vertical);
          final p = list.position;
          if (p.pixels >= p.maxScrollExtent) break;
          p.jumpTo((p.pixels + 150).clamp(0.0, p.maxScrollExtent));
          await settle(3);
        }
        expect(target, findsWidgets);
        await tester.ensureVisible(target.first);
        await settle(10);
      }

      // --- A level actor's components: the Details panel follows ------------
      await ok('spawn_actor_from_asset', {'asset': barrelMesh.relativePath, 'location': [0, 0, 0]});
      final barrelId = vm.actors.last.id;
      await ok('focus_actor', {'id': barrelId});
      await rec.hold(const Duration(milliseconds: 800));
      final lightComponent = (await ok('add_actor_component', {'actor_id': barrelId, 'type': 'LuminaPointLightComponent'}))['component'] as Map;
      final light = lightComponent['id'];
      await ok('set_actor_property', {'id': barrelId, 'property': '$light.intensity', 'value': 8000});
      expect(vm.selectedActorIds, {barrelId});
      final barrelNode = vm.actors.firstWhere((a) => a.id == barrelId);
      expect(barrelNode.components.firstWhere((c) => c.id == light).properties['intensity'], 8000);
      await revealInDetails(find.descendant(of: find.byType(DetailsWidget), matching: find.text('Intensity')));
      await shot('mcp05_barrel_point_light_in_details');
      final capsule = ((await ok('add_actor_component', {'actor_id': barrelId, 'type': 'LuminaCapsuleComponent'}))['component'] as Map)['id'];
      await ok('set_actor_collision', {'actor_id': barrelId, 'component': capsule, 'preset': 'BlockAll'});
      expect(barrelNode.components.firstWhere((c) => c.id == capsule).properties['preset'], 'blockAll');
      await revealInDetails(find.byKey(ValueKey('details_collision_$capsule')));
      await shot('mcp05_barrel_collision_block_all');

      // --- The door Blueprint, built member by member -------------------------
      await ok('create_asset', {'type': 'actor', 'name': 'BP_AgentDoor', 'parent_class': 'LuminaActor'});
      const door = 'contents/blueprints/BP_AgentDoor.lmas';
      await ok('get_blueprint', {'asset': door});
      final mesh = ((await ok('add_blueprint_component', {'asset': door, 'type': 'LuminaStaticMeshComponent'}))['component'] as Map)['id'];
      await ok('set_blueprint_component_property', {'asset': door, 'component': mesh, 'property': 'staticMeshAsset', 'value': acMesh.relativePath});
      await ok('rename_blueprint_component', {'asset': door, 'component': mesh, 'name': 'DoorMesh'});
      final box = ((await ok('add_blueprint_component', {'asset': door, 'type': 'LuminaBoxComponent', 'parent': mesh}))['component'] as Map)['id'];
      await ok('set_blueprint_component_collision', {'asset': door, 'component': box, 'preset': 'Trigger', 'generate_overlap_events': true});
      await settle(30);
      await shot('mcp05_door_components_tree');

      final variable = await ok('add_blueprint_variable', {'asset': door, 'name': 'OpenAngle', 'type': 'Float', 'default': 90});
      expect((variable['variable'] as Map)['name'], 'OpenAngle');
      await shot('mcp05_door_open_angle_variable');

      await ok('add_blueprint_function', {'asset': door, 'name': 'OpenDoor'});
      await ok('set_blueprint_function_signature', {
        'asset': door,
        'function': 'OpenDoor',
        'inputs': [
          {'name': 'Angle', 'type': 'Float'},
        ],
      });
      final fnGraph = await ok('get_blueprint', {'asset': door, 'graph': 'function:OpenDoor'});
      final entry = (fnGraph['nodes'] as List).cast<Map>().firstWhere((n) => (n['outputs'] as List).cast<Map>().any((p) => p['name'] == 'Angle'))['id'];
      final print = ((await ok('add_blueprint_node', {
        'asset': door,
        'graph': 'function:OpenDoor',
        'node': 'print_string',
        'x': 420,
        'y': 120,
        'literals': {'in_string': 'Door opening'},
      }))['node'] as Map)['id'];
      await ok('connect_blueprint_pins',
          {'asset': door, 'graph': 'function:OpenDoor', 'from_node': entry, 'from_pin': 'exec_out', 'to_node': print, 'to_pin': 'exec_in'});
      await settle(30);
      await shot('mcp05_door_open_door_function_graph');

      final timeline = ((await ok('add_blueprint_node', {'asset': door, 'node': 'timeline', 'x': 360, 'y': 260}))['node'] as Map)['id'];
      await ok('set_blueprint_timeline', {'asset': door, 'node': timeline, 'length': 2, 'auto_play': true});
      await ok('add_timeline_track', {'asset': door, 'node': timeline, 'name': 'Alpha', 'type': 'float'});
      await ok('set_timeline_keys', {
        'asset': door,
        'node': timeline,
        'track': 'Alpha',
        'keys': [
          {'time': 0, 'value': [0]},
          {'time': 2, 'value': [1], 'interp': 'cubic'},
        ],
      });
      await settle(30);
      await shot('mcp05_door_timeline_alpha_track');

      final compiled = await ok('compile_blueprint', {'asset': door, 'save': true});
      expect(compiled['status'], isNot('error'));
      expect(File(compiled['generated_file'] as String).readAsStringSync(), contains('OpenDoor('));
      await shot('mcp05_door_compiled');

      // --- Placed in the level, then the Level Blueprint ----------------------
      await ok('select_tab', {'index': 0});
      await ok('spawn_actor_from_asset', {'asset': door, 'location': [250, 0, 0]});
      await ok('frame_level');
      await settle(30);
      await shot('mcp05_door_placed_in_level');

      final level = await ok('get_blueprint', {'asset': 'level'});
      expect(level['is_level_blueprint'], isTrue);
      var begin = (level['nodes'] as List).cast<Map>().where((n) => n['node'] == 'event_beginplay').firstOrNull?['id'];
      begin ??= ((await ok('add_blueprint_node', {'asset': 'level', 'node': 'event_beginplay', 'x': 60, 'y': 80}))['node'] as Map)['id'];
      final hello = ((await ok('add_blueprint_node', {
        'asset': 'level',
        'node': 'print_string',
        'x': 380,
        'y': 90,
        'literals': {'in_string': 'Level ready'},
      }))['node'] as Map)['id'];
      await ok('connect_blueprint_pins', {'asset': 'level', 'from_node': begin, 'from_pin': 'exec_out', 'to_node': hello, 'to_pin': 'exec_in'});
      final levelCompiled = await ok('compile_blueprint', {'asset': 'level', 'save': true});
      expect(levelCompiled['status'], isNot('error'));
      expect(levelCompiled['generated_code'], contains('Level ready'));
      await settle(30);
      await shot('mcp05_level_blueprint_wired_and_compiled');

      rec.save(scenario, usedAssets: usedAssets);
    } finally {
      client.close();
      await tester.runAsync(server.stop);
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
      try {
        tempProjectsDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });
}

/// On a scaffolded Third Person game with barrels placed, an
/// agent writes a Blueprint-callable barrel-stack function with a type error,
/// sees `dart_analyze` report it (Output Log + Recent calls), fixes it with
/// `fs_edit`, finds the new node in BP_ThirdPersonCharacter's palette,
/// regenerates the game code with `run_codegen`, and is refused a read
/// outside the project — every step through `tools/call`.
void mcpFileAndCodeScenario(IntegrationTestWidgetsFlutterBinding binding) {
  const scenario = 'MCP Smoke: an agent writes, analyzes and fixes game code, finds its Blueprint node and regenerates the code';
  testWidgets(scenario, (tester) async {
    final red = File('${SmokeArtifacts.testAssetsDir.path}/Props/Barrels/fuel_barrel_red.glb');
    final empty = File('${SmokeArtifacts.testAssetsDir.path}/Props/Barrels/empty_barrel.glb');
    expect(red.existsSync() && empty.existsSync(), isTrue, reason: 'test-assets must hold the barrels');

    final root = Directory.systemTemp.createTempSync('lumina_smoke_mcp_fs_');
    const name = 'mcp_fs_smoke';
    final projectDir = (await tester.runAsync(() => scaffoldGameProject(root, name: name, widgetLibrary: 'flutter')))!;
    expect(File('$projectDir/.dart_tool/package_config.json').existsSync(), isTrue, reason: 'flutter pub get --offline resolved the game');
    final project = (await tester.runAsync(() => ProjectRepository().loadProject('$projectDir/$name.lmproject')))!;
    final vm = EditorViewModel(initialProject: project, projectLocation: root.path);
    await tester.runAsync(vm.ensureDefaultLevelAssets);
    await tester.runAsync(() => vm.processImportPipeline(sourceFilePath: red.path));
    await tester.runAsync(() => vm.processImportPipeline(sourceFilePath: empty.path));
    final redMesh = vm.realAssets.firstWhere((a) => a.type == AssetType.filamesh && a.fileName.contains('fuel_barrel_red'));
    final emptyMesh = vm.realAssets.firstWhere((a) => a.type == AssetType.filamesh && a.fileName.contains('empty_barrel'));

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
      final usedAssets = [red.path, empty.path];

      Future<void> shot(String name) async {
        final png = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
        SmokeArtifacts.saveScreenshot(name, png, usedAssets: usedAssets);
        await rec.hold(const Duration(milliseconds: 1200));
      }

      Future<McpToolReply> call(String tool, [Map<String, Object?> args = const {}]) async {
        final reply = (await tester.runAsync(() => client.callTool(tool, args)))!;
        await settle(10);
        return reply;
      }

      Future<Map<String, Object?>> ok(String tool, [Map<String, Object?> args = const {}]) async {
        final reply = await call(tool, args);
        expect(reply.isError, isFalse, reason: '$tool: ${reply.text}');
        return reply.data;
      }

      Future<void> showOutputLog() async {
        await tester.tap(find.text('Output Log').first);
        await settle(8);
      }

      await tester.runAsync(() => client.handshake(clientName: 'claude-code'));

      // --- The barrels the function is about -----------------------------------
      for (final (i, mesh) in [redMesh, emptyMesh, redMesh].indexed) {
        await ok('spawn_actor_from_asset', {'asset': mesh.relativePath, 'location': [300, 0, 90.0 * i]});
      }
      await ok('focus_actor', {'id': vm.actors.last.id});
      await ok('set_camera', {'distance': 450, 'pitch': 15});
      await showOutputLog();
      await settle(20);

      // --- A barrel-stack function with a type error ---------------------------
      const path = 'lib/agent/barrel_stack.dart';
      const broken = "import 'package:lumina/lumina_runtime.dart';\n\n"
          '/// The height of [count] stacked barrels, in cm.\n'
          "@BlueprintCallable(category: 'Agent')\n"
          "double barrelStackHeight(int count) => '\${count * 90}';\n";
      final written = await ok('fs_write', {'path': path, 'content': broken});
      expect(written['created'], isTrue);
      final failing = await ok('dart_analyze', {'paths': ['lib/agent']});
      expect(failing['ok'], isFalse);
      final error = (failing['diagnostics'] as List).cast<Map>().firstWhere((d) => d['severity'] == 'error');
      expect(error['file'], path);
      expect(error['code'], 'return_of_invalid_type');
      await settle(10);
      expect(find.textContaining('dart analyze: 1 error'), findsWidgets, reason: 'the Output Log shows the analysis');
      expect(find.textContaining('return_of_invalid_type'), findsWidgets, reason: 'the Output Log names the error');
      await shot('mcp_fs_analyze_error');
      vm.commands.execute('tools.aiAgentAccess');
      await settle(15);
      expect(find.text('dart_analyze'), findsWidgets, reason: 'Recent calls lists the analysis');
      await rec.hold(const Duration(milliseconds: 800));

      // --- Fixed with fs_edit, analyzed clean -----------------------------------
      final edit = await ok('fs_edit', {'path': path, 'old_string': "=> '\${count * 90}';", 'new_string': '=> count * 90.0;'});
      expect(edit['diff'], contains('+double barrelStackHeight(int count) => count * 90.0;'));
      final clean = await ok('dart_analyze', {'paths': ['lib/agent']});
      expect(clean['ok'], isTrue, reason: '$clean');
      vm.selectTab(0);
      await settle(10);
      await showOutputLog();
      expect(find.textContaining('dart analyze: no errors'), findsWidgets);
      await shot('mcp_fs_analyze_clean');

      // --- The node in the Third Person Blueprint's palette ---------------------
      const fnId = 'fn:package:$name/agent/barrel_stack.dart#barrelStackHeight';
      for (var i = 0; i < 1200 && !vm.blueprintFunctions.functions.any((f) => f.spec.id == fnId); i++) {
        await settle(2);
      }
      expect(vm.blueprintFunctions.functions.map((f) => f.spec.id), contains(fnId), reason: '${vm.blueprintFunctions.diagnostics}');
      final bpAsset = vm.realAssets.firstWhere((a) => a.relativePath == LuminaThirdPersonContent.characterBlueprintPath);
      vm.openSubEditorTab('Blueprint', asset: bpAsset);
      await settle(20);
      final bp = tester.state<BlueprintSubEditorState>(find.byType(BlueprintSubEditor)).viewModel;
      for (var i = 0; i < 200 && bp.graphNodes.isEmpty; i++) {
        await settle(2);
      }
      final canvas = find.byType(BlueprintGraphCanvas);
      BlueprintGraphCanvasState state() => tester.state<BlueprintGraphCanvasState>(canvas);
      Offset topLeft() => tester.getTopLeft(canvas);
      final wheel = TestPointer(12, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(wheel.hover(topLeft() + const Offset(4, 4)));
      for (var i = 0; i < 4; i++) {
        await tester.sendEventToBinding(wheel.scroll(const Offset(0, 40)));
        await rec.hold(const Duration(milliseconds: 60));
      }
      await tester.sendEventToBinding(wheel.removePointer());
      state().frameCanvasPoint(const Offset(0, 4000));
      await settle(4);
      await tester.tapAt(topLeft() + const Offset(0, 4000) * state().zoom + state().panOffset, buttons: kSecondaryButton);
      await settle();
      await rec.typeText(find.byKey(const ValueKey('palette_search')), 'Barrel Stack Height', perCharacter: const Duration(milliseconds: 50));
      await settle();
      expect(find.byKey(const ValueKey('palette_entry_$fnId')), findsOneWidget);
      await shot('mcp_fs_palette_barrel_stack_height');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(6);

      // --- run_codegen: the game's Dart regenerated ------------------------------
      vm.selectTab(0);
      await settle(10);
      final codegen = await ok('run_codegen');
      expect(codegen['written_files'], containsAll(['lib/main.dart', 'lib/levels/${dartFileName(vm.activeLevelName)}']));
      await showOutputLog();
      expect(find.textContaining('Save Level complete'), findsWidgets);
      await shot('mcp_fs_run_codegen');

      // --- A read outside the project is refused ---------------------------------
      final outside = await call('fs_read', {'path': '../../etc/passwd'});
      expect(outside.isError, isTrue);
      expect(outside.text, contains('outside the project'));
      vm.commands.execute('tools.aiAgentAccess');
      await settle(15);
      expect(server.recentCalls.first.tool, 'fs_read');
      expect(server.recentCalls.first.ok, isFalse);
      expect(find.textContaining('outside the project'), findsWidgets);
      await shot('mcp_fs_read_outside_refused');

      // The agent checks the file's snapshots: each call is a new Recent calls row.
      for (var i = 0; i < 30 && rec.recorded < const Duration(milliseconds: 10300); i++) {
        final history = await ok('fs_history', {'path': path, 'limit': 5});
        expect(history['snapshots'], isNotEmpty);
        await rec.hold(const Duration(milliseconds: 400));
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

/// On a real editor, an agent blocks out a new level through
/// `tools/call` only — a new level from the Default template, three props
/// from test-assets in an Outliner folder, one attached to another, scaled
/// together, soloed and restored; World Partition with a data layer, dusk
/// light with fog, a NavMeshBoundsVolume and a real navigation bake; the
/// viewport's snapping, show flags, buffer visualisation and quality; then
/// saved and reopened after a round trip to L_Main. The Outliner, Details,
/// tabs and viewport react on video.
void mcpLevelBlockoutScenario(IntegrationTestWidgetsFlutterBinding binding) {
  const scenario = 'MCP Smoke: an agent blocks out a new level with folders, attachments, World Partition, lighting and navigation';
  testWidgets(scenario, (tester) async {
    final card = File('${SmokeArtifacts.testAssetsDir.path}/Props/Access_cards/access_card_blue.glb');
    final banana = File('${SmokeArtifacts.testAssetsDir.path}/Props/Banana Bunch/banana_bunch_medium.glb');
    final aircon = File('${SmokeArtifacts.testAssetsDir.path}/Props/AC_units/aircon_small.glb');
    expect(card.existsSync() && banana.existsSync() && aircon.existsSync(), isTrue,
        reason: 'test-assets must hold the access card, the banana bunch and the small aircon');

    final tempProjectsDir = Directory.systemTemp.createTempSync('lumina_smoke_mcp_level_');
    final pDir = Directory('${tempProjectsDir.path}/SmokeMcpLevel')..createSync(recursive: true);
    const project = LuminaProject(projectName: 'SmokeMcpLevel', activeLevel: 'contents/levels/L_Main.lmas');
    File('${pDir.path}/SmokeMcpLevel.lmproject').writeAsStringSync(jsonEncode(project.toMap()));

    final vm = EditorViewModel(initialProject: project, projectLocation: tempProjectsDir.path);
    await tester.runAsync(() => vm.ensureDefaultLevelAssets());
    for (final glb in [card, banana, aircon]) {
      await tester.runAsync(() => vm.processImportPipeline(sourceFilePath: glb.path));
    }
    String meshOf(String name) =>
        vm.realAssets.firstWhere((a) => a.type == AssetType.filamesh && a.fileName.contains(name)).relativePath;

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
      final usedAssets = [card.path, banana.path, aircon.path];

      Future<void> shot(String name) async {
        final png = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
        SmokeArtifacts.saveScreenshot(name, png, usedAssets: usedAssets);
        await rec.hold(const Duration(milliseconds: 1200));
      }

      Future<McpToolReply> call(String tool, [Map<String, Object?> args = const {}]) async {
        final reply = (await tester.runAsync(() => client.callTool(tool, args)))!;
        await settle(12);
        return reply;
      }

      Future<Map<String, Object?>> ok(String tool, [Map<String, Object?> args = const {}]) async {
        final reply = await call(tool, args);
        expect(reply.isError, isFalse, reason: '$tool: ${reply.text}');
        return reply.data;
      }

      await tester.runAsync(() => client.handshake(clientName: 'claude-code'));

      // --- A new level from the Default template -------------------------------
      final created = await ok('new_level', {'name': 'L_AgentYard', 'template': 'default', 'if_dirty': 'save'});
      expect(created['active_level'], 'contents/levels/L_AgentYard.lmas');
      expect(File('${pDir.path}/contents/levels/L_AgentYard.lmas').existsSync(), isTrue);
      await settle(20);
      expect(vm.currentTab.title, 'L_AgentYard', reason: 'the level tab is named after the new level');
      expect(find.text('L_AgentYard'), findsWidgets);

      // --- Three props, a folder around them, one attached, scaled together ----
      String idOf(Map<String, Object?> r) => (r['actor'] as Map)['id'] as String;
      final cardId = idOf(await ok('spawn_actor_from_asset', {'asset': meshOf('access_card_blue'), 'location': [0, -60, 40]}));
      final bananaId = idOf(await ok('spawn_actor_from_asset', {'asset': meshOf('banana_bunch_medium'), 'location': [0, 40, 40]}));
      final airconId = idOf(await ok('spawn_actor_from_asset', {'asset': meshOf('aircon_small'), 'location': [0, 160, 0]}));
      await ok('focus_actor', {'id': bananaId});
      await ok('set_camera', {'distance': 520, 'pitch': 18, 'yaw': 35});
      await shot('mcp06_new_level_with_three_props');

      final folder = await ok('create_folder', {'name': 'Props', 'wrap_ids': [cardId, bananaId, airconId]});
      final folderId = folder['folder_id'] as String;
      expect(folder['children'], unorderedEquals([cardId, bananaId, airconId]));
      await settle(10);
      expect(find.text('Props'), findsWidgets, reason: 'the Outliner shows the folder');
      await shot('mcp06_props_folder_in_outliner');

      final attached = await ok('attach_actors', {'ids': [bananaId], 'parent_id': cardId});
      expect(attached['attached'], [bananaId]);
      expect(vm.actors.firstWhere((a) => a.id == bananaId).parentId, cardId);
      await shot('mcp06_banana_attached_to_card');

      await ok('set_actors_transform', {'ids': [cardId, bananaId, airconId], 'scale': [2, 2, 2]});
      await settle(10);
      expect(find.text('3 Actors Selected'), findsOneWidget, reason: 'the multi-select Details panel shows the edit');
      await shot('mcp06_three_props_scaled_in_multi_edit');

      final solo = await ok('solo_actor', {'id': cardId});
      expect(solo['visible_ids'], containsAll([cardId, bananaId, folderId]));
      expect(vm.actors.firstWhere((a) => a.id == airconId).isVisible, isFalse);
      await shot('mcp06_card_soloed');
      await ok('clear_solo');
      expect(vm.actors.firstWhere((a) => a.id == airconId).isVisible, isTrue);
      await rec.hold(const Duration(milliseconds: 600));

      // --- World Partition with a data layer ------------------------------------
      await ok('set_world_partition', {'enabled': true});
      final layer = await ok('add_data_layer', {'name': 'Interiors'});
      expect(layer['name'], 'Interiors');
      await ok('set_data_layer', {'layer': 'Interiors', 'initial_state': 'loaded'});
      await settle(10);
      expect(find.text('WORLD PARTITION'), findsOneWidget, reason: 'the Details panel shows the level settings');
      expect(find.byKey(const ValueKey('wp_layer_state_0')), findsOneWidget);
      await shot('mcp06_world_partition_interiors_layer');

      // --- Dusk light with fog: the Environment Lighting tab --------------------
      final env = await ok('set_level_environment', {'time_of_day': 18.5, 'fog_enabled': true, 'fog_density': 0.03, 'exposure': 0.6});
      expect(env['open_tab'], 'lighting');
      await settle(30);
      expect(vm.currentTab.category, 'lighting');
      await shot('mcp06_dusk_with_fog_in_environment_lighting');

      // --- A NavMeshBoundsVolume and the real bake: the Navigation tab ----------
      await ok('select_tab', {'index': 0});
      await ok('spawn_actor', {'type': 'NavMeshBoundsVolume'});
      await ok('set_navigation_settings', {'agent_radius': 40, 'cell_size': 20});
      final nav = await ok('build_navigation');
      expect(nav['walkable_cells'] as int, greaterThan(0));
      expect(nav['volume_count'], 1);
      await settle(30);
      expect(vm.currentTab.category, 'navmesh');
      await shot('mcp06_navigation_built');

      // --- The viewport toolbar: snapping, Collision, Roughness, epic ----------
      await ok('select_tab', {'index': 0});
      await ok('set_viewport_snapping', {'translate_enabled': true, 'translate_step': 50, 'rotate_step': 15, 'grid_step': 100});
      await ok('set_show_flags', {'flags': {'Collision': true}});
      expect(vm.showFlags['Collision'], isTrue);
      await ok('set_buffer_visualization', {'buffer': 'Roughness'});
      expect(vm.viewMode, 'Buffer');
      await settle(20);
      await shot('mcp06_roughness_buffer_with_collision');
      await ok('set_camera', {'view_mode': 'Lit'});
      await ok('set_viewport_quality', {'preset': 'epic'});
      expect(vm.qualityPreset, 'epic');
      await settle(20);
      await shot('mcp06_lit_epic_quality');

      // --- Save, to L_Main and back ---------------------------------------------
      await ok('save_level');
      final saved = jsonDecode(File('${pDir.path}/contents/levels/L_AgentYard.lmas').readAsStringSync()) as Map;
      expect(((saved['metadata'] as Map)['worldPartition'] as Map)['dataLayers'], isNotEmpty);
      await ok('open_level', {'level': 'L_Main', 'if_dirty': 'save'});
      expect(vm.project.activeLevel, 'contents/levels/L_Main.lmas');
      await settle(20);
      expect(vm.actors.any((a) => a.name == 'Props'), isFalse);
      await shot('mcp06_back_on_l_main');
      await ok('open_level', {'level': 'L_AgentYard', 'if_dirty': 'save'});
      await settle(20);
      expect(vm.actors.where((a) => a.type == 'Folder').map((a) => a.name), contains('Props'));
      expect(vm.actors.firstWhere((a) => a.id == bananaId).parentId, cardId, reason: 'the attachment was saved');
      await ok('focus_actor', {'id': bananaId});
      await shot('mcp06_l_agent_yard_reopened');

      // The agent orbits the reopened yard until the video is long enough.
      for (var i = 0; i < 60 && rec.recorded < const Duration(milliseconds: 10300); i++) {
        await ok('set_camera', {'yaw': 35.0 + 8 * (i + 1)});
        await rec.hold(const Duration(milliseconds: 200));
      }
      rec.save(scenario, usedAssets: usedAssets);
    } finally {
      client.close();
      await tester.runAsync(server.stop);
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
      try {
        tempProjectsDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  }, timeout: const Timeout(Duration(minutes: 15)));
}

void mcpSelectionScenario(IntegrationTestWidgetsFlutterBinding binding) {
  const scenario = 'MCP Smoke: an agent reads what the user selected in the level, the Content Browser and a Blueprint graph';
  testWidgets(scenario, (tester) async {
    final barrel = File('${SmokeArtifacts.testAssetsDir.path}/Props/Barrels/fuel_barrel_yellow.glb');
    final aircon = File('${SmokeArtifacts.testAssetsDir.path}/Props/AC_units/roof_aircon_unit_150x150_a.glb');
    expect(barrel.existsSync() && aircon.existsSync(), isTrue, reason: 'test-assets must hold the yellow barrel and the roof aircon');

    final tempProjectsDir = Directory.systemTemp.createTempSync('lumina_smoke_mcp_sel_');
    final pDir = Directory('${tempProjectsDir.path}/SmokeMcpSel')..createSync(recursive: true);
    const project = LuminaProject(projectName: 'SmokeMcpSel', activeLevel: 'contents/levels/L_Main.lmas');
    File('${pDir.path}/SmokeMcpSel.lmproject').writeAsStringSync(jsonEncode(project.toMap()));

    final vm = EditorViewModel(initialProject: project, projectLocation: tempProjectsDir.path);
    await tester.runAsync(() => vm.ensureDefaultLevelAssets());
    for (final glb in [barrel, aircon]) {
      await tester.runAsync(() => vm.processImportPipeline(sourceFilePath: glb.path));
    }
    String meshOf(String name) =>
        vm.realAssets.firstWhere((a) => a.type == AssetType.filamesh && a.fileName.contains(name)).relativePath;
    final barrelMesh = meshOf('fuel_barrel_yellow');
    final airconMesh = meshOf('roof_aircon_unit_150x150_a');

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
      final usedAssets = [barrel.path, aircon.path];

      Future<void> shot(String name) async {
        final png = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
        SmokeArtifacts.saveScreenshot(name, png, usedAssets: usedAssets);
        await rec.hold(const Duration(milliseconds: 1200));
      }

      Future<Map<String, Object?>> ok(String tool, [Map<String, Object?> args = const {}]) async {
        final reply = (await tester.runAsync(() => client.callTool(tool, args)))!;
        await settle(12);
        expect(reply.isError, isFalse, reason: '$tool: ${reply.text}');
        return reply.data;
      }

      await tester.runAsync(() => client.handshake(clientName: 'claude-code'));

      // --- A wall, a barrel and an aircon; two of them selected ----------------
      String idOf(Map<String, Object?> r) => (r['actor'] as Map)['id'] as String;
      final wallId = idOf(await ok('spawn_actor', {
        'type': 'Primitive',
        'name': 'Wall_North',
        'location': [0, -150, 0],
        'scale': [4, 0.2, 2],
      }));
      final barrelId = idOf(await ok('spawn_actor_from_asset', {'asset': barrelMesh, 'location': [0, 0, 0]}));
      final airconId = idOf(await ok('spawn_actor_from_asset', {'asset': airconMesh, 'location': [0, 150, 0]}));
      await ok('set_camera', {'distance': 700, 'pitch': 22, 'yaw': 30});
      await ok('select_actors', {'ids': [wallId, barrelId]});
      await settle(10);

      final level = (await ok('get_selection'))['level'] as Map;
      expect(level['count'], 2);
      final actors = (level['actors'] as List).cast<Map>();
      expect(actors.map((a) => a['id']), [wallId, barrelId]);
      expect(level['primary_actor_id'], vm.primarySelectedActor!.id);
      expect(actors.firstWhere((a) => a['id'] == wallId)['type'], 'Primitive');
      expect(actors.firstWhere((a) => a['id'] == barrelId)['mesh_asset_path'], contains('fuel_barrel_yellow'));
      expect(actors.every((a) => a['id'] != airconId), isTrue);
      await shot('mcp_selection_two_actors_selected');

      // --- The Content Browser: a click on the aircon's tile --------------------
      vm.selectedFolder = airconMesh.substring(0, airconMesh.lastIndexOf('/'));
      await settle(20);
      final tile = find.byKey(ValueKey('asset_item_$airconMesh'));
      expect(tile, findsOneWidget);
      await tester.tap(tile);
      await settle(10);
      final browser = (await ok('get_selection'))['content_browser'] as Map;
      expect(browser['current_folder'], vm.selectedFolder);
      expect(browser['primary_asset'], airconMesh);
      expect(((browser['assets'] as List).single as Map)['type'], 'filamesh');
      await shot('mcp_selection_content_browser_asset');

      // --- A Blueprint editor tab with one graph node selected -----------------
      await ok('create_asset', {'type': 'actor', 'name': 'BP_Beacon', 'parent_class': 'LuminaActor'});
      const bp = 'contents/blueprints/BP_Beacon.lmas';
      await ok('open_asset_editor', {'asset': bp});
      final added = await ok('add_blueprint_node', {'asset': bp, 'node': 'print_string', 'x': 260, 'y': 120});
      final nodeId = (added['node'] as Map)['id'] as String;
      await settle(30);
      final editor = vm.editorSessionFor(vm.currentTab.id) as BlueprintEditorViewModel;
      editor.activeGraphEditor.select(nodeId);
      await settle(20);
      expect(find.byType(BlueprintGraphCanvas), findsWidgets);
      final tab = (await ok('get_selection'))['active_tab'] as Map;
      expect(tab['kind'], 'sub_editor');
      expect((tab['asset'] as Map)['path'], bp);
      expect((tab['selection'] as Map)['selected_node_ids'], [nodeId]);
      await shot('mcp_selection_blueprint_node');

      // --- Back on the level: the selection is still there ---------------------
      await ok('select_tab', {'index': 0});
      await settle(20);
      expect(((await ok('get_selection'))['level'] as Map)['count'], 2);
      await shot('mcp_selection_back_on_level');

      // The agent orbits the props until the video is long enough.
      for (var i = 0; i < 60 && rec.recorded < const Duration(milliseconds: 10300); i++) {
        await ok('set_camera', {'yaw': 30.0 + 8 * (i + 1)});
        await rec.hold(const Duration(milliseconds: 200));
      }
      rec.save(scenario, usedAssets: usedAssets);
    } finally {
      client.close();
      await tester.runAsync(server.stop);
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
      try {
        tempProjectsDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  }, timeout: const Timeout(Duration(minutes: 15)));
}

const String _brokenMaterial = '''
material {
    name : "M_Agent",
    shadingModel : lit,
    parameters : [
        { type : float, name : roughness, default : 0.5 }
    ],
}

fragment {
    void material(inout MaterialInputs material) {
        prepareMaterial(material);
        material.baseColor = vec4(materialParams.undeclaredColor, 1.0);
        material.roughness = materialParams.roughness;
    }
}
''';

const String _goodMaterial = '''
material {
    name : "M_Agent",
    shadingModel : lit,
    parameters : [
        { type : float, name : roughness, default : 0.5 }
    ],
}

fragment {
    void material(inout MaterialInputs material) {
        prepareMaterial(material);
        material.baseColor = vec4(0.85, 0.15, 0.1, 1.0);
        material.roughness = materialParams.roughness;
    }
}
''';
