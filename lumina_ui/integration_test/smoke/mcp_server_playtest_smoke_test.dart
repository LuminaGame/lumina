import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../test/helpers/mcp_test_client.dart';
import '../../test/helpers/scaffold_game_project.dart';

/// MCP server playtest smoke (the scenario lives beside `mcp_server_smoke_test.dart`,
/// which is at the 1100-line limit): on a real Third Person project with a
/// fuel barrel from test-assets in front of the player start, an MCP client
/// (JSON-RPC over HTTP) stages and applies a Project Settings change, plays
/// the game — W held, the mannequin running toward the barrel, a jump — and
/// reads the actors back; then runs Build All as a job and starts a real
/// `flutter build` Cook & Package, polls it and cancels it. The editor reacts
/// on video. A second scenario runs the same walk and jump as one
/// `pie_sequence` call with two screenshots; a third starts Play from a
/// Blueprint editor tab and checks the first screenshots show the game.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const scenario = 'MCP Smoke: an agent changes Project Settings, play-tests the mannequin toward a barrel, builds and cancels a real cook';
  testWidgets(scenario, (tester) async {
    final barrel = File('${SmokeArtifacts.testAssetsDir.path}/Props/Barrels/fuel_barrel_red.glb');
    expect(barrel.existsSync(), isTrue, reason: 'test-assets must hold the fuel barrel');
    final usedAssets = [barrel.path];

    final root = Directory.systemTemp.createTempSync('lumina_smoke_mcp07_');
    const name = 'smoke_mcp_playtest';
    final projectDir = (await tester.runAsync(() => scaffoldGameProject(root, name: name, widgetLibrary: 'flutter')))!;
    // The host's runner, so Cook & Package can run a real `flutter build`.
    final host = Platform.isWindows ? 'windows' : 'linux';
    final created = (await tester.runAsync(() => Process.run(
        'flutter', ['create', '--platforms=$host', '--no-pub', '--project-name', name, '.'],
        workingDirectory: projectDir, runInShell: Platform.isWindows)))!;
    expect(created.exitCode, 0, reason: '${created.stdout}\n${created.stderr}');
    final project = LuminaProject.fromMap(
        Map<String, dynamic>.from(jsonDecode(File('$projectDir/$name.lmproject').readAsStringSync()) as Map));
    expect(project.mapsAndModes.defaultGameMode, LuminaThirdPersonContent.gameModeBlueprintPath);

    final vm = EditorViewModel(initialProject: project, projectLocation: root.path);
    await tester.runAsync(vm.ensureDefaultLevelAssets);
    await tester.runAsync(() => vm.processImportPipeline(sourceFilePath: barrel.path));
    final barrelMesh = vm.realAssets.firstWhere((a) => a.type == AssetType.filamesh && a.fileName.contains('fuel_barrel_red'));

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
        final png = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
        SmokeArtifacts.saveScreenshot(name, png, usedAssets: usedAssets);
        await rec.hold(const Duration(milliseconds: 1000));
      }

      /// A call the editor answers while the recorder keeps pumping frames:
      /// Play and the build run on the editor's frames and event loop.
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

      await tester.runAsync(() => client.handshake(clientName: 'claude-code'));

      // --- The barrel, 6 m in front of the player start ------------------------
      final start = vm.actors.firstWhere((a) => a.type == 'PlayerStart');
      final yaw = (start.rotation.length > 2 ? start.rotation[2] : 0.0) * math.pi / 180;
      final barrelAt = [start.location[0] + 600 * math.cos(yaw), start.location[1] + 600 * math.sin(yaw), 0.0];
      await ok('spawn_actor_from_asset', {'asset': barrelMesh.relativePath, 'location': barrelAt});
      await ok('focus_actor', {'id': vm.actors.last.id});
      await settle(20);
      await shot('mcp07_barrel_in_front_of_player_start');

      // --- Project Settings: stage gravity -490, the tab shows it, apply --------
      final staged = await ok('set_project_settings', {'changes': {'physics.gravity_z': -490}});
      expect(staged['validation_errors'], isEmpty);
      await settle(20);
      expect(vm.currentTab.category, 'projectSettings');
      await tester.tap(find.byKey(const ValueKey('project_settings_nav_physics')));
      await settle(10);
      expect(tester.widget<TextField>(find.byKey(const ValueKey('project_settings_gravity'))).controller!.text, '-490.0');
      await shot('mcp07_project_settings_gravity_staged');
      final applied = await ok('apply_project_settings');
      expect(applied['saved'], isTrue);
      expect(((jsonDecode(File('$projectDir/$name.lmproject').readAsStringSync()) as Map)['physics'] as Map)['gravity_z'], -490);
      await settle(10);
      await shot('mcp07_project_settings_applied');
      await ok('select_tab', {'index': 0});
      await settle(10);

      // --- Play: W held, the mannequin runs toward the barrel, then jumps -------
      await ok('start_pie');
      for (var i = 0; i < 150 && (await ok('pie_status'))['runtime_mounted'] != true; i++) {
        await rec.hold(const Duration(milliseconds: 100));
      }
      final status = await ok('pie_status');
      expect(status['runtime_mounted'], isTrue, reason: 'last error: ${status['last_error']}');
      await ok('pie_play_for', {'ms': 800});
      final from = ((await ok('pie_status'))['player_location'] as List).cast<num>();
      expect((await ok('pie_key', {'key': 'W', 'action': 'down'}))['held_keys'], ['KeyW']);
      final moved = await call('pie_play_for', {'ms': 2000, 'screenshot': true});
      expect(moved.isError, isFalse, reason: moved.text);
      final agentPng = base64Decode(moved.content.firstWhere((c) => c['type'] == 'image')['data'] as String);
      SmokeArtifacts.saveScreenshot('mcp_playtest_after_move', Uint8List.fromList(agentPng), usedAssets: usedAssets);
      await ok('pie_key', {'key': 'W', 'action': 'up'});
      await shot('mcp07_mannequin_ran_toward_the_barrel');

      final jump = await ok('pie_action', {'action': 'IA_Jump'});
      expect(jump['pressed'], ['KeySpace']);
      final midJump = await call('pie_play_for', {'ms': 300, 'screenshot': true});
      expect(midJump.isError, isFalse, reason: midJump.text);
      SmokeArtifacts.saveScreenshot('mcp_playtest_mid_jump',
          Uint8List.fromList(base64Decode(midJump.content.firstWhere((c) => c['type'] == 'image')['data'] as String)),
          usedAssets: usedAssets);
      await shot('mcp07_mannequin_mid_jump');
      await ok('pie_play_for', {'ms': 500});

      final pawn = ((await ok('pie_get_actors', {'class_contains': 'Character'}))['actors'] as List).cast<Map>().single;
      expect(pawn['is_possessed_pawn'], isTrue);
      final at = (pawn['location'] as List).cast<num>();
      final distance = math.sqrt(math.pow(at[0] - from[0], 2) + math.pow(at[1] - from[1], 2));
      debugPrint('[mcp07_smoke] the pawn moved ${distance.toStringAsFixed(0)} cm toward the barrel');
      expect(distance, greaterThan(100), reason: 'W for 2 s walks the mannequin');
      final stopped = await ok('stop_pie');
      expect(stopped['held_keys'], isEmpty);
      await settle(20);

      // --- Build All as a job, the Build Manager showing the steps --------------
      final buildAll = await ok('start_build', {'kind': 'build_all'});
      await settle(10);
      expect(vm.currentTab.category, 'buildManager');
      Map<String, Object?> built = const {};
      for (var i = 0; i < 20; i++) {
        built = await ok('wait_job', {'id': buildAll['job_id'], 'timeout_ms': 5000});
        if (built['timed_out'] != true) break;
      }
      expect(built['state'], 'succeeded', reason: '${built['error']} ${built['log']}');
      await settle(10);
      await shot('mcp07_build_all_succeeded');

      // --- A real flutter build: Cook & Package, polled, then cancelled ---------
      await ok('set_build_settings', {'targets': [host], 'configuration': 'Debug'});
      final before = _flutterBuildPids();
      final cook = await ok('start_build', {'kind': 'cook_and_package'});
      final cookId = cook['job_id'] as String;
      var sawProgress = false;
      var flutterBuildRunning = false;
      var logIndex = 0;
      for (var i = 0; i < 240 && !flutterBuildRunning; i++) {
        final job = await ok('get_job', {'id': cookId, 'since_log_index': logIndex});
        logIndex = job['next_log_index'] as int;
        // Progress is measurable over the asset steps (the cook itself
        // reports null): the finished steps show it.
        final build = await ok('get_build_status');
        if ((job['progress'] is num && (job['progress'] as num) > 0) || (build['completed_steps'] as int) > 0) sawProgress = true;
        if ((job['log'] as List).any((l) => ((l as Map)['message'] as String).contains('Running flutter build $host'))) {
          flutterBuildRunning = true;
        }
        expect(job['state'], 'running', reason: '${job['error']}');
        await rec.hold(const Duration(milliseconds: 100));
      }
      expect(sawProgress && flutterBuildRunning, isTrue, reason: 'the asset steps advanced and flutter build started');
      await rec.hold(const Duration(milliseconds: 1500));
      final running = await ok('get_build_status');
      expect(running['is_running'], isTrue);
      await shot('mcp07_real_cook_running_in_build_manager');
      final cancelled = await ok('cancel_job', {'id': cookId});
      expect(cancelled['state'], 'cancelled');
      var left = _flutterBuildPids().difference(before);
      for (var i = 0; i < 40 && left.isNotEmpty; i++) {
        await rec.hold(const Duration(milliseconds: 250));
        left = _flutterBuildPids().difference(before);
      }
      debugPrint('[mcp07_smoke] flutter build processes left after cancel_job: $left');
      final leftovers = Set<int>.of(left);
      // Never leave a build running on the machine, whatever the check says.
      for (final pid in leftovers) {
        Process.killPid(pid);
      }
      expect(leftovers, isEmpty, reason: 'cancel_job kills flutter build and its children');
      await settle(10);
      await shot('mcp07_cook_cancelled');

      // The agent orbits the level until the video is long enough.
      await ok('select_tab', {'index': 0});
      for (var i = 0; i < 60 && rec.recorded < const Duration(milliseconds: 10300); i++) {
        await ok('set_camera', {'yaw': 20.0 + 8 * (i + 1)});
        await rec.hold(const Duration(milliseconds: 200));
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

  const sequenceScenario = 'MCP Smoke: pie_sequence walks the mannequin toward a barrel and jumps in one call, with two screenshots';
  testWidgets(sequenceScenario, (tester) async {
    final barrel = File('${SmokeArtifacts.testAssetsDir.path}/Props/Barrels/fuel_barrel_red.glb');
    expect(barrel.existsSync(), isTrue, reason: 'test-assets must hold the fuel barrel');
    final usedAssets = [barrel.path];

    final root = Directory.systemTemp.createTempSync('lumina_smoke_mcpseq_');
    const name = 'smoke_mcp_sequence';
    final projectDir = (await tester.runAsync(() => scaffoldGameProject(root, name: name, widgetLibrary: 'flutter')))!;
    final project = LuminaProject.fromMap(
        Map<String, dynamic>.from(jsonDecode(File('$projectDir/$name.lmproject').readAsStringSync()) as Map));
    final vm = EditorViewModel(initialProject: project, projectLocation: root.path);
    await tester.runAsync(vm.ensureDefaultLevelAssets);
    await tester.runAsync(() => vm.processImportPipeline(sourceFilePath: barrel.path));
    final barrelMesh = vm.realAssets.firstWhere((a) => a.type == AssetType.filamesh && a.fileName.contains('fuel_barrel_red'));

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
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
      }
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));

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

      await tester.runAsync(() => client.handshake(clientName: 'claude-code'));

      // A first sequence finds where W walks from the player start (and
      // stops Play at its end); the barrel goes 8 m along that line.
      final probe = await call('pie_sequence', {
        'stop_at_end': true,
        'steps': [
          {'play_ms': 1500, 'label': 'land'},
          {'key': 'W', 'hold_ms': 500, 'label': 'probe forward'},
        ],
      });
      expect(probe.isError, isFalse, reason: probe.text);
      expect(probe.data['stopped_pie'], isTrue);
      final probeSteps = (probe.data['steps'] as List).cast<Map>();
      final p0 = (probeSteps[0]['player_location'] as List).cast<num>();
      final p1 = (probeSteps[1]['player_location'] as List).cast<num>();
      final dx = (p1[0] - p0[0]).toDouble(), dy = (p1[1] - p0[1]).toDouble();
      final len = math.sqrt(dx * dx + dy * dy);
      expect(len, greaterThan(50), reason: 'W walks the pawn');
      final barrelAt = [p0[0] + 800 * dx / len, p0[1] + 800 * dy / len, 0.0];
      await rec.hold(const Duration(milliseconds: 500));
      expect((await call('spawn_actor_from_asset', {'asset': barrelMesh.relativePath, 'location': barrelAt})).isError, isFalse);
      await rec.hold(const Duration(milliseconds: 800));

      // One call: Play starts, the pawn lands while the viewport loads its
      // meshes, a screenshot, W for a second, a jump, a screenshot mid-air,
      // and the check that the player moved.
      final reply = await call('pie_sequence', {
        'screenshot_max_width': 1280,
        'steps': [
          {'play_ms': 1500, 'label': 'land'},
          {'screenshot': true, 'label': 'before walking'},
          {'key': 'W', 'hold_ms': 1000, 'label': 'walk toward the barrel'},
          {'action': 'IA_Jump', 'label': 'jump'},
          {'advance_frames': 12},
          {'screenshot': true, 'label': 'after walking and jumping'},
          {'expect': {'player_moved': true, 'min_distance_cm': 200}},
        ],
      });
      expect(reply.isError, isFalse, reason: reply.text);
      final data = reply.data;
      final content = reply.content;
      final pngs = <Uint8List>[];
      for (var i = 1; i < content.length; i++) {
        if (content[i]['type'] != 'image') continue;
        expect(content[i - 1]['text'], contains('Step'), reason: 'each image follows its caption');
        pngs.add(Uint8List.fromList(base64Decode(content[i]['data'] as String)));
      }
      expect(pngs, hasLength(2));
      SmokeArtifacts.saveScreenshot('mcp_sequence_before_walking', pngs[0], usedAssets: usedAssets);
      SmokeArtifacts.saveScreenshot('mcp_sequence_after_walking_and_jumping', pngs[1], usedAssets: usedAssets);
      final shots = (data['screenshots'] as List).cast<Map>();
      final a = (shots[0]['player_location'] as List).cast<num>();
      final b = (shots[1]['player_location'] as List).cast<num>();
      final moved = math.sqrt(math.pow(b[0] - a[0], 2) + math.pow(b[1] - a[1], 2));
      debugPrint('[mcp_sequence_smoke] the pawn moved ${moved.toStringAsFixed(0)} cm between the screenshots; '
          'z ${a[2].toStringAsFixed(0)} → ${b[2].toStringAsFixed(0)}');
      expect(moved, greaterThan(200));
      expect(b[2], greaterThan(a[2]), reason: 'mid-jump');
      expect(data['released_keys'], isEmpty, reason: 'the tap released W itself');
      expect((data['final_status'] as Map)['paused'], isTrue);

      // The paused game in the editor, then Play stopped.
      await rec.hold(const Duration(milliseconds: 1500));
      final shot = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
      SmokeArtifacts.saveScreenshot('mcp_sequence_editor_paused_after_sequence', shot, usedAssets: usedAssets);
      expect((await call('stop_pie')).isError, isFalse);
      await rec.hold(const Duration(milliseconds: 500));
      for (var i = 0; i < 60 && rec.recorded < const Duration(milliseconds: 10300); i++) {
        await call('set_camera', {'yaw': 20.0 + 8 * (i + 1)});
        await rec.hold(const Duration(milliseconds: 200));
      }
      rec.save(sequenceScenario, usedAssets: usedAssets);
    } finally {
      client.close();
      await tester.runAsync(server.stop);
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
      try {
        root.deleteSync(recursive: true);
      } catch (_) {}
    }
  }, timeout: const Timeout(Duration(minutes: 10)));

  const blueprintTabScenario = 'MCP Smoke: Play started from a Blueprint editor tab shows the game camera in the first screenshots';
  testWidgets(blueprintTabScenario, (tester) async {
    final barrel = File('${SmokeArtifacts.testAssetsDir.path}/Props/Barrels/fuel_barrel_red.glb');
    expect(barrel.existsSync(), isTrue, reason: 'test-assets must hold the fuel barrel');
    final usedAssets = [barrel.path];

    final root = Directory.systemTemp.createTempSync('lumina_smoke_mcptab_');
    const name = 'smoke_mcp_pie_tab';
    final projectDir = (await tester.runAsync(() => scaffoldGameProject(root, name: name, widgetLibrary: 'flutter')))!;
    final project = LuminaProject.fromMap(
        Map<String, dynamic>.from(jsonDecode(File('$projectDir/$name.lmproject').readAsStringSync()) as Map));
    final vm = EditorViewModel(initialProject: project, projectLocation: root.path);
    await tester.runAsync(vm.ensureDefaultLevelAssets);
    await tester.runAsync(() => vm.processImportPipeline(sourceFilePath: barrel.path));
    final barrelMesh = vm.realAssets.firstWhere((a) => a.type == AssetType.filamesh && a.fileName.contains('fuel_barrel_red'));

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
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
      }
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));

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

      Future<McpToolReply> ok(String tool, [Map<String, Object?> args = const {}]) async {
        final reply = await call(tool, args);
        expect(reply.isError, isFalse, reason: '$tool: ${reply.text}');
        return reply;
      }

      img.Image imageOf(McpToolReply reply, String artifact) {
        final png = Uint8List.fromList(base64Decode(reply.content.firstWhere((c) => c['type'] == 'image')['data'] as String));
        SmokeArtifacts.saveScreenshot(artifact, png, usedAssets: usedAssets);
        return img.decodePng(png)!;
      }

      /// The "PIE ACTIVE" banner: the editor's primary orange, top centre.
      bool showsPlayBanner(img.Image frame) {
        for (var y = 0; y < math.min(48, frame.height); y++) {
          for (var x = (frame.width * 0.35).round(); x < (frame.width * 0.65).round(); x++) {
            final p = frame.getPixel(x, y);
            if ((p.r - 0xFB).abs() < 12 && (p.g - 0x7C).abs() < 12 && p.b < 24) return true;
          }
        }
        return false;
      }

      /// Mean per-channel difference of the 3D view below the banner.
      double viewDifference(img.Image a, img.Image b) {
        var sum = 0.0, n = 0;
        for (var y = 60; y < math.min(a.height, b.height) - 30; y += 4) {
          for (var x = 0; x < math.min(a.width, b.width); x += 4) {
            final p = a.getPixel(x, y), q = b.getPixel(x, y);
            sum += ((p.r - q.r).abs() + (p.g - q.g).abs() + (p.b - q.b).abs()) / 3;
            n++;
          }
        }
        return sum / n;
      }

      await tester.runAsync(() => client.handshake(clientName: 'claude-code'));

      // The barrel 6 m in front of the player start; the editor camera frames
      // the level from above, far from where the game camera will look.
      final start = vm.actors.firstWhere((a) => a.type == 'PlayerStart');
      final yaw = (start.rotation.length > 2 ? start.rotation[2] : 0.0) * math.pi / 180;
      await ok('spawn_actor_from_asset', {
        'asset': barrelMesh.relativePath,
        'location': [start.location[0] + 600 * math.cos(yaw), start.location[1] + 600 * math.sin(yaw), 0.0],
      });
      await ok('frame_level');
      await ok('set_camera', {'pitch': 55.0});
      await rec.hold(const Duration(milliseconds: 800));
      final editorView = imageOf(await ok('viewport_screenshot'), 'mcp_pie_tab_editor_view_before_play');
      expect(showsPlayBanner(editorView), isFalse);

      // An agent edits the character Blueprint: its tab is in front.
      await ok('open_asset_editor', {'asset': LuminaThirdPersonContent.characterBlueprintPath});
      await rec.hold(const Duration(milliseconds: 800));
      expect(vm.activeTabIndex, isNot(0));

      // Play, and a screenshot straight away: the game camera, not the editor's.
      await ok('start_pie');
      expect(vm.activeTabIndex, 0, reason: 'start_pie shows the level viewport, where Play runs');
      final first = imageOf(await ok('viewport_screenshot'), 'mcp_pie_tab_first_screenshot_after_start_pie');
      expect(showsPlayBanner(first), isTrue);
      final firstDiff = viewDifference(editorView, first);
      debugPrint('[mcp_pie_tab_smoke] first screenshot after start_pie differs from the editor view by $firstDiff');
      expect(firstDiff, greaterThan(8), reason: 'the game camera looks from behind the pawn, not from the editor camera');

      // The Blueprint tab in front again while Play runs: the play-testing
      // screenshots bring the level viewport back and show the running game.
      await ok('open_asset_editor', {'asset': LuminaThirdPersonContent.characterBlueprintPath});
      await rec.hold(const Duration(milliseconds: 500));
      expect(vm.activeTabIndex, isNot(0));
      final advanced = await ok('pie_advance', {'frames': 30, 'screenshot': true});
      expect(advanced.data['screenshot_error'], isNull);
      expect(vm.activeTabIndex, 0);
      final advancedShot = imageOf(advanced, 'mcp_pie_tab_pie_advance_from_blueprint_tab');
      expect(showsPlayBanner(advancedShot), isTrue);
      expect(viewDifference(editorView, advancedShot), greaterThan(8));

      await ok('open_asset_editor', {'asset': LuminaThirdPersonContent.characterBlueprintPath});
      await rec.hold(const Duration(milliseconds: 500));
      await ok('pie_key', {'key': 'W', 'action': 'down'});
      final played = await ok('pie_play_for', {'ms': 1500, 'screenshot': true});
      await ok('pie_key', {'key': 'W', 'action': 'up'});
      expect(vm.activeTabIndex, 0);
      final playedShot = imageOf(played, 'mcp_pie_tab_pie_play_for_from_blueprint_tab');
      expect(showsPlayBanner(playedShot), isTrue);
      expect(viewDifference(editorView, playedShot), greaterThan(8));

      await ok('resume_pie');
      await rec.hold(const Duration(milliseconds: 1500));
      final shot = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
      SmokeArtifacts.saveScreenshot('mcp_pie_tab_editor_while_playing', shot, usedAssets: usedAssets);
      await ok('stop_pie');
      await rec.hold(const Duration(milliseconds: 500));
      for (var i = 0; i < 60 && rec.recorded < const Duration(milliseconds: 10300); i++) {
        await call('set_camera', {'yaw': 20.0 + 8 * (i + 1)});
        await rec.hold(const Duration(milliseconds: 200));
      }
      rec.save(blueprintTabScenario, usedAssets: usedAssets);
    } finally {
      client.close();
      await tester.runAsync(server.stop);
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
      try {
        root.deleteSync(recursive: true);
      } catch (_) {}
    }
  }, timeout: const Timeout(Duration(minutes: 10)));
}

/// Pids of running `flutter build <platform>` tool processes (the Flutter
/// tool's snapshot under dart), whoever started them.
Set<int> _flutterBuildPids() {
  if (Platform.isWindows) {
    final out = Process.runSync('powershell', [
      '-NoProfile',
      '-Command',
      "Get-CimInstance Win32_Process | Where-Object { \$_.CommandLine -match 'flutter_tools\\.snapshot.* build (windows|linux|web)' } | "
          'ForEach-Object { \$_.ProcessId }',
    ]).stdout.toString();
    return {for (final l in const LineSplitter().convert(out)) if (int.tryParse(l.trim()) != null) int.parse(l.trim())};
  }
  final out = Process.runSync('ps', ['-eo', 'pid=,args=']).stdout.toString();
  return {
    for (final l in const LineSplitter().convert(out))
      if (RegExp(r'flutter_tools\.snapshot.* build (windows|linux|web)').hasMatch(l)) int.parse(l.trim().split(RegExp(r'\s+')).first),
  };
}
