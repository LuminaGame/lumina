import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/core/services/user_plugin_dir.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/marketplace/view_models/marketplace_view_model.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../test/helpers/marketplace_test_backend.dart' as market;
import '../../test/helpers/mcp_test_client.dart';

/// MCP server content smoke (beside `mcp_server_smoke_test.dart`, which is at the
/// 1100-line limit): an MCP client (JSON-RPC over HTTP) organises content
/// while the recorder runs — Import Asset Folder of the test-assets barrels
/// as a job, a banana bunch import, a Hero folder with two moves and a
/// collection, regenerated thumbnails — then generates and enables a
/// content-only plugin, installs the Barrel listing from a real Marketplace
/// server the test signed into, initialises git and commits everything, and
/// clears the Derived Data Cache. The editor reacts on video.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const scenario = 'MCP Smoke: an agent organises imported content, enables a new plugin, installs from the Marketplace and commits';
  testWidgets(scenario, (tester) async {
    final unavailable = market.MarketplaceTestBackend.unavailableReason;
    expect(unavailable, isNull, reason: 'the Marketplace server must be runnable here');
    final barrelsDir = Directory('${SmokeArtifacts.testAssetsDir.path}/Props/Barrels');
    final banana = File('${SmokeArtifacts.testAssetsDir.path}/Props/Banana Bunch/banana_bunch_long.glb');
    expect(banana.existsSync(), isTrue, reason: 'test-assets must hold the banana bunch');
    final barrelFiles = barrelsDir.listSync().whereType<File>().where((f) => f.path.endsWith('.glb')).toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    final usedAssets = [for (final f in barrelFiles) f.path, banana.path];

    final backend = (await tester.runAsync(market.MarketplaceTestBackend.start))!;
    final root = Directory.systemTemp.createTempSync('lumina_smoke_mcp08_');
    UserPluginDir.override = Directory('${root.path}/user_plugins')..createSync();
    MarketplaceViewModel.httpClientFactory = market.realHttpClient;
    final account = (await tester.runAsync(() => backend.signUpUser(backend.client(), username: 'mcp_agent_studio')))!;

    final projectDir = market.createMarketplaceTestProject(root, 'AgentContent').path;
    const project = LuminaProject(projectName: 'AgentContent', activeLevel: 'contents/levels/L_Main.lmas');
    final vm = EditorViewModel(
      initialProject: project,
      projectLocation: root.path,
      enableTimers: false,
      autoGenerateThumbnails: true,
    );
    expect(vm.editorPreferences.setMarketplaceUrl(backend.url.toString()), isTrue);
    await tester.runAsync(vm.ensureDefaultLevelAssets);
    vm.setPaneSize(bottomHeight: 460);

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

      Future<Map<String, Object?>> finish(String id) async {
        Map<String, Object?> job = const {};
        for (var i = 0; i < 40; i++) {
          job = await ok('wait_job', {'id': id, 'timeout_ms': 5000});
          if (job['timed_out'] != true) break;
        }
        expect(job['state'], 'succeeded', reason: '${job['error']} ${job['log']}');
        return job;
      }

      Future<void> waitFor(bool Function() done, {Duration timeout = const Duration(minutes: 2)}) async {
        final end = DateTime.now().add(timeout);
        while (!done()) {
          if (DateTime.now().isAfter(end)) fail('timed out');
          await rec.hold(const Duration(milliseconds: 100));
        }
      }

      await tester.runAsync(() => client.handshake(clientName: 'claude-code'));
      // The project is under git before the agent starts, so the Content
      // Browser badges its new files and the final commit clears them.
      final init = await ok('source_control_init');
      expect(init['is_repo'], isTrue);

      // --- Import Asset Folder: the barrels fill contents/Props tile by tile ----
      final plan = await ok('import_asset_folder', {'path': barrelsDir.path, 'target_folder': 'contents/Props', 'dry_run': true});
      debugPrint('[mcp08_smoke] Import Asset Folder plans ${(plan['imports'] as List).length} barrels');
      final folderJob = await ok('import_asset_folder', {'path': barrelsDir.path, 'target_folder': 'contents/Props'});
      final imported = await finish(folderJob['job_id'] as String);
      expect((imported['result'] as Map)['imported'], (plan['imports'] as List).length);
      await tester.runAsync(() => vm.thumbnailQueueIdle.timeout(const Duration(minutes: 2)));
      await settle(20);
      expect(vm.selectedFolder, 'contents/Props');
      await shot('mcp08_import_asset_folder_barrels');
      final bananaImport = await ok('import_asset', {'path': banana.path, 'folder': 'contents/Props'});
      final bananaPath = ((bananaImport['imported'] as List).cast<Map>().firstWhere((a) => a['type'] == 'filamesh'))['path'] as String;

      // --- A Hero folder, two moves, a collection --------------------------------
      await ok('create_content_folder', {'parent': 'contents/Props', 'name': 'Hero'});
      await ok('move_asset', {'asset': 'contents/Props/fuel_barrel_red.lmas', 'folder': 'contents/Props/Hero'});
      await ok('move_asset', {'asset': bananaPath, 'folder': 'contents/Props/Hero'});
      await tester.runAsync(() => vm.thumbnailQueueIdle.timeout(const Duration(minutes: 1)));
      await settle(20);
      expect(vm.selectedFolder, 'contents/Props/Hero');
      expect(vm.visibleAssets.map((a) => a.fileName), containsAll(['fuel_barrel_red.lmas', 'banana_bunch_long.lmas']));
      await shot('mcp08_hero_folder_after_moves');
      final hero = ['contents/Props/Hero/fuel_barrel_red.lmas', 'contents/Props/Hero/banana_bunch_long.lmas'];
      await ok('create_collection', {'name': 'Hero Props'});
      final added = await ok('add_to_collection', {'collection': 'Hero Props', 'assets': hero});
      expect(added['count'], 2);
      vm.activeCollection = 'Hero Props';
      await settle(20);
      await shot('mcp08_hero_props_collection');

      // --- Regenerate the two thumbnails: their .lmas files are rewritten --------
      final before = {for (final p in hero) p: File('$projectDir/$p').lastModifiedSync()};
      await rec.hold(const Duration(milliseconds: 1100));
      final regen = await ok('regenerate_thumbnails', {'assets': hero});
      expect(regen['queued'], 2);
      await tester.runAsync(() => vm.thumbnailQueueIdle.timeout(const Duration(minutes: 1)));
      await settle(10);
      for (final p in hero) {
        expect(File('$projectDir/$p').lastModifiedSync().isAfter(before[p]!), isTrue, reason: '$p: the embedded PNG was re-rendered');
      }
      vm.activeCollection = null;

      // --- A content-only plugin: generated as a job, enabled -------------------
      final pluginJob = await ok('create_plugin', {'name': 'lumina_plugin_agent_props', 'template': 'contentOnly', 'friendly_name': 'Agent Props'});
      await finish(pluginJob['job_id'] as String);
      final enabled = await ok('set_plugin_enabled', {'name': 'lumina_plugin_agent_props', 'enabled': true});
      expect(enabled['restart_required'], isFalse);
      await settle(30);
      expect(vm.currentTab.category, 'plugins');
      await shot('mcp08_plugin_manager_agent_props_enabled');

      // --- The Marketplace: the user signed in; the agent searches and installs --
      expect(await tester.runAsync(() => vm.marketplace.signIn(account.user.username, 'correct horse battery')), isTrue);
      final hits = await ok('marketplace_search', {'query': 'Barrel'});
      final barrelId = (hits['results'] as List).cast<Map>().firstWhere((l) => l['title'] == 'Barrel')['id'] as String;
      final install = await ok('marketplace_install', {'id': barrelId, 'folder': 'contents/Marketplace'});
      var sawProgress = false;
      for (var i = 0; i < 200; i++) {
        final job = await ok('get_job', {'id': install['job_id']});
        final progress = job['progress'];
        if (progress is num && progress > 0 && progress < 1 && !sawProgress) {
          sawProgress = true;
          await shot('mcp08_marketplace_install_progress');
        }
        if (job['state'] != 'running') break;
        await rec.hold(const Duration(milliseconds: 50));
      }
      final installed = await finish(install['job_id'] as String);
      debugPrint('[mcp08_smoke] Marketplace install progress seen mid-download: $sawProgress');
      final record = installed['result'] as Map;
      expect(File('$projectDir/${record['license_file']}').existsSync(), isTrue);
      if (!sawProgress) await shot('mcp08_marketplace_install_progress');
      await ok('select_tab', {'index': 0});
      vm.selectedFolder = record['installed_to'] as String;
      await tester.runAsync(() => vm.thumbnailQueueIdle.timeout(const Duration(minutes: 2)));
      await settle(20);
      await shot('mcp08_marketplace_barrel_in_content_browser');

      // --- Source Control: the agent's work shows as changes; commit clears them -
      final status = await ok('source_control_status');
      expect(status['changes'], isNotEmpty);
      vm.selectedFolder = 'contents/Props/Hero';
      await settle(20);
      await shot('mcp08_source_control_changes_badged');
      final commit = await ok('source_control_commit', {'all': true, 'message': 'Agent: organise props'});
      expect((commit['hash'] as String).length, 40);
      expect((await ok('source_control_status'))['changes'], isEmpty);
      debugPrint('[mcp08_smoke] committed ${(status['changes'] as List).length} change(s) as ${commit['hash']}');
      vm.selectedFolder = 'contents/Props/Hero';
      await settle(20);
      await shot('mcp08_source_control_committed_badges_clear');
      final history = await ok('source_control_history', {'path': hero.first});
      expect((history['entries'] as List).cast<Map>().first['subject'], 'Agent: organise props');

      // --- Clear the Derived Data Cache -----------------------------------------
      final freed = await ok('clear_derived_data_cache');
      debugPrint('[mcp08_smoke] Clear Derived Data Cache freed ${freed['entries']} entries, ${freed['bytes']} bytes');
      await waitFor(() => !vm.sourceControl.isBusy);

      // The agent browses the folders until the video is long enough.
      final folders = ['contents/Props', 'contents/Props/Hero', record['installed_to'] as String];
      for (var i = 0; rec.recorded < const Duration(milliseconds: 10300) && i < 60; i++) {
        vm.selectedFolder = folders[i % folders.length];
        await rec.hold(const Duration(milliseconds: 400));
      }
      rec.save(scenario, usedAssets: usedAssets);
    } finally {
      client.close();
      await tester.runAsync(server.stop);
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
      UserPluginDir.override = null;
      await tester.runAsync(backend.stop);
      try {
        root.deleteSync(recursive: true);
      } catch (_) {}
    }
  }, timeout: const Timeout(Duration(minutes: 20)));
}
