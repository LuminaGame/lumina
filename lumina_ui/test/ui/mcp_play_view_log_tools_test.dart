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
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../helpers/temp_project.dart';
import '../helpers/blueprint_test_project.dart';
import '../helpers/mcp_test_client.dart';

/// The Output Log, camera, screenshot and Play-In-Editor
/// tools over a real temp project through a real JSON-RPC-over-HTTP client;
/// the screenshot and PIE cases pump the real `MainEditorView`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late Directory configDir;
  late EditorViewModel vm;
  late McpServerService server;
  late McpTestClient client;

  setUp(() async {
    root = Directory.systemTemp.createTempSync('lumina_mcp_play_test_');
    configDir = Directory('${root.path}/config')..createSync();
    final projectDir = Directory('${root.path}/McpPlay')..createSync();
    const project = LuminaProject(projectName: 'McpPlay', activeLevel: 'contents/levels/L_Main.lmas');
    File('${projectDir.path}/McpPlay.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
    Directory('${projectDir.path}/contents/levels').createSync(recursive: true);
    Directory('${projectDir.path}/contents/blueprints').createSync(recursive: true);
    Directory('${projectDir.path}/lib').createSync(recursive: true);
    vm = EditorViewModel(initialProject: project, projectLocation: root.path, enableTimers: false, autoInitAssets: false);
    server = McpServerService(vm, configDir: configDir, settings: McpServerSettings.load(configDir: configDir));
    expect(await server.start(port: 0), isTrue);
    client = McpTestClient(server.url!, server.token);
    await client.handshake();
  });

  tearDown(() async {
    client.close();
    await server.stop();
    vm.dispose();
    // Windows frees the folder once the git probe exits.
    await deleteTempProject(root);
  });

  group('output log tools', () {
    test('read_output_log tails, filters by level / source / text, and pages with since_index', () async {
      final tail = (await client.callTool('read_output_log', {'tail': 5})).data;
      final entries = (tail['entries'] as List).cast<Map>();
      expect(entries.length, lessThanOrEqualTo(5));
      expect(tail['total'], vm.logs.length);
      expect(tail['next_index'], vm.logs.length);
      final indices = entries.map((e) => e['index'] as int).toList();
      expect(indices, orderedEquals([...indices]..sort()), reason: 'newest last');
      expect(indices.last, vm.logs.length - 1);

      await client.callTool('spawn_actor', {'type': 'PointLight'});
      final spawned = (await client.callTool('read_output_log', {'contains': 'spawned'})).data;
      expect((spawned['entries'] as List).any((e) => ((e as Map)['message'] as String).contains('Spawned new actor')), isTrue);

      vm.logger.log('a deliberate error', level: 'error', source: 'McpTest');
      final errors = (await client.callTool('read_output_log', {'level': 'error'})).data;
      expect((errors['entries'] as List), isNotEmpty);
      expect((errors['entries'] as List).every((e) => (e as Map)['level'] == 'error'), isTrue);
      final bySource = (await client.callTool('read_output_log', {'source': 'mcptest'})).data;
      expect((bySource['entries'] as List).map((e) => (e as Map)['message']), contains('a deliberate error'));

      final cursor = errors['next_index'] as int;
      vm.logger.log('after the cursor', source: 'McpTest');
      final newer = (await client.callTool('read_output_log', {'since_index': cursor - 1})).data;
      expect((newer['entries'] as List).map((e) => (e as Map)['message']), contains('after the cursor'));
      expect((newer['entries'] as List).every((e) => ((e as Map)['index'] as int) >= cursor), isTrue);

      await client.callTool('clear_output_log');
      expect(vm.logs, isEmpty);
    });
  });

  group('camera tools', () {
    test('get_camera / set_camera / focus_actor / frame_level drive the view model\'s camera', () async {
      final before = (await client.callTool('get_camera')).data;
      expect(before['yaw'], vm.cameraYaw);
      expect(before['distance'], vm.cameraDistance);
      expect(before['mode'], 'Perspective');

      final set = await client.callTool('set_camera', {
        'yaw': 45,
        'pitch': 30,
        'distance': 800,
        'target': [100, 0, 50],
      });
      expect(set.isError, isFalse, reason: set.text);
      expect(vm.cameraYaw, 45.0);
      expect(vm.cameraPitch, 30.0);
      expect(vm.cameraDistance, 800.0);
      expect([vm.cameraPanX, vm.cameraPanY, vm.cameraPanZ], [100.0, 0.0, 50.0]);

      await client.callTool('set_camera', {'mode': 'Top', 'view_mode': 'Wireframe'});
      expect(vm.cameraMode, 'Top');
      expect(vm.viewportMode, 'Wireframe');
      await client.callTool('set_camera', {'mode': 'Perspective', 'view_mode': 'Lit'});
      expect(vm.cameraMode, 'Perspective');

      final badPitch = await client.callTool('set_camera', {'pitch': 120});
      expect(badPitch.isError, isTrue);
      await expectLater(
        client.callTool('set_camera', {'mode': 'Isometric'}),
        throwsA(isA<McpRpcError>().having((e) => e.message, 'message', contains('mode'))),
      );

      await client.callTool('spawn_actor', {
        'type': 'Primitive',
        'location': [300, 200, 10],
      });
      final actor = vm.actors.last;
      final focused = await client.callTool('focus_actor', {'id': actor.id});
      expect(focused.isError, isFalse, reason: focused.text);
      expect((focused.data['target'] as List), [300.0, 200.0, 10.0]);
      expect(vm.selectedActorId, actor.id);

      final distanceBefore = vm.cameraDistance;
      await client.callTool('spawn_actor', {
        'type': 'Primitive',
        'location': [-4000, -4000, 0],
      });
      final framed = await client.callTool('frame_level');
      expect(framed.isError, isFalse, reason: framed.text);
      expect(vm.cameraDistance, isNot(distanceBefore));
    });
  });

  group('screenshot and Play tools (the real editor pumped)', () {
    Future<void> pumpEditor(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    testWidgets('viewport_screenshot returns a real PNG of the viewport, and of the editor', (tester) async {
      final notShown = await tester.runAsync(() => client.callTool('viewport_screenshot'));
      expect(notShown!.isError, isTrue);
      expect(notShown.text, contains('not shown'));

      await pumpEditor(tester);
      final shot = (await tester.runAsync(() => client.callTool('viewport_screenshot', {'max_width': 640})))!;
      expect(shot.isError, isFalse, reason: shot.text);
      final image = shot.content.firstWhere((c) => c['type'] == 'image');
      expect(image['mimeType'], 'image/png');
      final decoded = img.decodePng(base64Decode(image['data'] as String));
      expect(decoded, isNotNull);
      expect(decoded!.width, lessThanOrEqualTo(640));
      expect(decoded.width, greaterThan(64));
      final first = decoded.getPixel(0, 0);
      var varied = false;
      for (var y = 0; y < decoded.height && !varied; y += 7) {
        for (var x = 0; x < decoded.width; x += 7) {
          final p = decoded.getPixel(x, y);
          if (p.r != first.r || p.g != first.g || p.b != first.b) {
            varied = true;
            break;
          }
        }
      }
      expect(varied, isTrue, reason: 'the viewport frame is not one flat colour');
      expect(shot.text, contains('PNG of the viewport'));

      final editorShot = (await tester.runAsync(() => client.callTool('viewport_screenshot', {'target': 'editor', 'max_width': 1600})))!;
      expect(editorShot.isError, isFalse, reason: editorShot.text);
      final editorImage = img.decodePng(base64Decode(editorShot.content.first['data'] as String))!;
      final viewportFull = (await tester.runAsync(() => client.callTool('viewport_screenshot', {'max_width': 1600})))!;
      final viewportImage = img.decodePng(base64Decode(viewportFull.content.first['data'] as String))!;
      expect(editorImage.width, greaterThan(viewportImage.width), reason: 'the editor holds panels beside the viewport');

      // A sub-editor tab hides the level viewport; the tool says so.
      vm.openSubEditorTab('mcpServer', title: 'AI Agent Access (MCP)');
      await tester.pump();
      final hidden = (await tester.runAsync(() => client.callTool('viewport_screenshot')))!;
      expect(hidden.isError, isTrue);
      expect(hidden.text, contains('select_tab'));
      final back = (await tester.runAsync(() => client.callTool('select_tab', {'index': 0})))!;
      expect(back.isError, isFalse);
      expect(vm.activeTabIndex, 0);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('start / pause / step / resume / stop Play through MCP, with level edits refused meanwhile', (tester) async {
      await pumpEditor(tester);
      Future<McpToolReply> call(String tool, [Map<String, Object?> args = const {}]) async {
        final reply = (await tester.runAsync(() => client.callTool(tool, args)))!;
        await tester.pump(const Duration(milliseconds: 16));
        return reply;
      }

      expect((await call('pie_status')).data['playing'], isFalse);
      final stepIdle = await call('step_pie');
      expect(stepIdle.isError, isTrue);

      final started = await call('start_pie');
      expect(started.isError, isFalse, reason: started.text);
      expect(started.data['playing'], isTrue);
      expect(vm.isPlaying, isTrue);
      final again = await call('start_pie');
      expect(again.isError, isTrue);

      final refused = await call('spawn_actor', {'type': 'PointLight'});
      expect(refused.isError, isTrue);
      expect(refused.text, contains('stop_pie'));

      final paused = await call('pause_pie');
      expect(paused.data['paused'], isTrue, reason: paused.text);
      expect(vm.isPaused, isTrue);
      final stepped = await call('step_pie');
      expect(stepped.isError, isFalse, reason: stepped.text);
      final notPausedYet = await call('resume_pie');
      expect(notPausedYet.data['paused'], isFalse);
      final stepRunning = await call('step_pie');
      expect(stepRunning.isError, isTrue);
      expect(stepRunning.text, contains('pause_pie'));

      final stopped = await call('stop_pie');
      expect(stopped.isError, isFalse, reason: stopped.text);
      expect(stopped.data['playing'], isFalse);
      expect(vm.isPlaying, isFalse);
      final stopAgain = await call('stop_pie');
      expect(stopAgain.isError, isTrue);

      final log = (await call('read_output_log', {'contains': 'PIE'})).data;
      expect((log['entries'] as List), isNotEmpty);
      await tester.pumpWidget(const SizedBox());
    });

    test('start_pie with a Blueprint that does not compile is a tool error naming the blocker', () async {
      // A float wired into an exec pin: the validator refuses it, so Play must
      // not start. Written straight to disk, as connect_blueprint_pins would
      // never produce it.
      final doc = LuminaBlueprintDocument(parentClass: 'LuminaActor');
      doc.eventGraph.nodes.addAll([
        LuminaBlueprintNodeLibrary.place('event_tick', nodeId: 'node_tick', x: 0, y: 0, context: const LuminaBlueprintTypeContext()),
        LuminaBlueprintNodeLibrary.place('print_string', nodeId: 'node_print', x: 300, y: 0, context: const LuminaBlueprintTypeContext()),
      ]);
      doc.eventGraph.wires.add(const LuminaBlueprintWire(
        id: 'wire_bad',
        fromNodeId: 'node_tick',
        fromPinId: 'delta_seconds',
        toNodeId: 'node_print',
        toPinId: 'exec_in',
      ));
      writeBlueprint(vm.projectDirPath, 'BP_Broken', doc);
      vm.refreshAssets();
      // Opening it makes it an "open Blueprint" that Play compiles first.
      final opened = await client.callTool('get_blueprint', {'asset': 'contents/blueprints/BP_Broken.lmas'});
      expect(opened.isError, isFalse, reason: opened.text);

      final started = await client.callTool('start_pie');
      expect(started.isError, isTrue);
      expect(started.text, contains('BP_Broken'));
      expect(vm.isPlaying, isFalse);
      final status = (await client.callTool('pie_status')).data;
      expect(status['playing'], isFalse);
      expect((status['blockers'] as List), isNotEmpty);
      expect(server.recentCalls.first.tool, 'pie_status');
      expect(server.recentCalls.where((c) => c.tool == 'start_pie').first.ok, isFalse);
    });
  });
}
