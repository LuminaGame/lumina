import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_editor_sessions.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_server_service.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_server_settings.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_tool.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/build_pipeline_service.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/project_settings_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/sub_editor_modal.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../helpers/flutter_build_stand_in.dart';
import '../helpers/mcp_test_client.dart';
import '../helpers/scaffold_game_project.dart';
import '../helpers/temp_project.dart';
import '../helpers/widget_graph_fixture.dart';

/// Project Settings, Editor Preferences, the Build menu as
/// jobs, Play Standalone and PIE play-testing — a real MCP client over HTTP
/// against a real editor on real temp projects (a Third Person scaffold for
/// the play-testing), real `.lmproject` / `editor_preferences.json` on disk
/// and real child processes (build / game stand-ins).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const mainLevel = 'contents/levels/L_Main.lmas';
  const linuxHost = HostBuildTargets(flutterAvailable: true, flutterVersion: '3.47.0', targets: ['linux', 'web'], operatingSystem: 'linux');

  late Directory root;
  late Directory projectDir;
  late Directory recordDir;
  late EditorViewModel vm;
  late McpServerService server;
  late McpTestClient client;

  Map<String, Object?> manifest() =>
      Map<String, Object?>.from(jsonDecode(File('${projectDir.path}/AgentGame.lmproject').readAsStringSync()) as Map);

  Future<McpToolReply> call(String tool, [Map<String, Object?> args = const {}]) => client.callTool(tool, args);
  Future<Map<String, Object?>> ok(String tool, [Map<String, Object?> args = const {}]) async {
    final r = await call(tool, args);
    expect(r.isError, isFalse, reason: '$tool: ${r.text}');
    return r.data;
  }

  Future<void> expectInvalid(String tool, Map<String, Object?> args, Matcher message) => expectLater(
        call(tool, args),
        throwsA(isA<McpRpcError>().having((e) => e.code, 'code', -32602).having((e) => e.message, 'message', message)),
      );

  group('project settings, editor preferences and builds (a temp project)', () {
    setUp(() async {
      root = Directory.systemTemp.createTempSync('lumina_mcp07_');
      final configDir = Directory('${root.path}/config')..createSync();
      recordDir = Directory('${root.path}/record')..createSync();
      projectDir = Directory('${root.path}/AgentGame')..createSync();
      final project = LuminaProject(
        projectName: 'AgentGame',
        activeLevel: mainLevel,
        template: kThirdPersonTemplateId,
        input: GameTemplateCatalog.byId(kThirdPersonTemplateId).input,
        packaging: const ProjectPackagingSettings(targets: ['linux']),
        extraFields: const {'studio_note': 'kept by every save'},
      );
      File('${projectDir.path}/AgentGame.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
      Directory('${projectDir.path}/contents/levels').createSync(recursive: true);
      vm = EditorViewModel(initialProject: project, projectLocation: root.path, enableTimers: false, autoInitAssets: false);
      vm.buildProcessStarter = flutterBuildStandIn(recordDir);
      vm.buildHostTargets = linuxHost;
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
      await deleteTempProject(root);
    });

    ProjectSettingsViewModel tab() => server.sessions.boundProjectSettings!;

    test('get_project_settings returns all nine categories from the manifest, clean', () async {
      final s = await ok('get_project_settings');
      for (final c in ['description', 'scalability', 'input', 'maps_and_modes', 'physics', 'packaging', 'branding', 'web_loading', 'ui']) {
        expect(s[c], isA<Map>(), reason: c);
        expect((s[c] as Map)['dirty'], isFalse, reason: c);
        expect((s[c] as Map)['validation_errors'], isEmpty, reason: c);
      }
      expect((s['physics'] as Map)['gravity_z'], -980);
      expect(s['dirty'], isFalse);
      final input = s['input'] as Map;
      final gameplay = (input['mapping_contexts'] as List).cast<Map>().single;
      expect(gameplay['name'], 'Gameplay');
      expect((gameplay['mappings'] as List).cast<Map>().first, allOf(containsPair('action', 'IA_Move'), containsPair('key', 'KeyW')));
      expect(((await ok('get_project_settings', {'category': 'physics'})).keys), containsAll(['physics', 'dirty']));
      // A read opens nothing.
      expect(vm.openTabs.any((t) => t.category == 'projectSettings'), isFalse);
    });

    test('set_project_settings stages on the tab, apply writes the .lmproject, revert restores the applied values', () async {
      final staged = await ok('set_project_settings', {
        'changes': {'physics.gravity_z': -490, 'scalability.target_fps': 30},
      });
      expect(staged['staged'], isTrue);
      expect(staged['validation_errors'], isEmpty);
      expect(vm.openTabs.any((t) => t.category == 'projectSettings'), isTrue, reason: 'the tab opens, as for a user');
      expect(tab().project.physics.gravityZ, -490);
      expect(tab().isDirty, isTrue);
      expect(((manifest()['physics'] as Map)['gravity_z'] as num), -980, reason: 'staged only: the disk is untouched');
      expect((((await ok('get_project_settings'))['physics']) as Map)['dirty'], isTrue);

      await expectInvalid('set_project_settings', {'changes': {'physics.nope': 1}}, allOf(contains('physics.nope'), contains('physics.gravity_z')));
      await expectInvalid('set_project_settings', {'changes': {'physics.gravity_z': 'down'}}, contains('number'));

      final applied = await ok('apply_project_settings');
      expect(applied['saved'], isTrue);
      expect(applied['validation_errors'], isEmpty);
      expect(applied['manifest_path'], endsWith('AgentGame.lmproject'));
      final disk = manifest();
      expect(((disk['physics'] as Map)['gravity_z'] as num), -490);
      expect(((disk['settings'] as Map)['target_fps'] as num), 30);
      expect(disk['studio_note'], 'kept by every save', reason: 'unknown manifest keys ride along');
      expect(vm.project.physics.gravityZ, -490, reason: 'the editor took the applied settings');

      await ok('set_project_settings', {'changes': {'physics.gravity_z': -100}});
      expect(tab().project.physics.gravityZ, -100);
      await ok('revert_project_settings');
      expect(tab().project.physics.gravityZ, -490);
      expect(tab().isDirty, isFalse);
    });

    test('GameMode and Character Blueprints created in a subfolder after the tab opened are listed and accepted', () async {
      // The first edit opens the tab and binds its view model.
      await ok('set_project_settings', {'changes': {'physics.gravity_z': -490}});
      await ok('create_asset', {'type': 'actor', 'name': 'BP_RunnerGameMode', 'parent_class': 'LuminaGameMode', 'folder': 'blueprints/runner'});
      await ok('create_asset', {'type': 'actor', 'name': 'BP_RunnerCharacter', 'parent_class': 'LuminaCharacter', 'folder': 'blueprints/runner'});
      const mode = 'contents/blueprints/runner/BP_RunnerGameMode.lmas';
      const pawn = 'contents/blueprints/runner/BP_RunnerCharacter.lmas';

      final read = (await ok('get_project_settings', {'category': 'maps_and_modes'}))['maps_and_modes'] as Map;
      expect(read['accepted_game_modes'], contains(mode));
      expect(read['accepted_pawn_classes'], contains(pawn));

      await ok('set_project_settings', {
        'changes': {'maps_and_modes.default_game_mode': mode, 'maps_and_modes.default_pawn_class': pawn},
      });
      expect(tab().project.mapsAndModes.defaultGameMode, mode);
      expect(tab().project.mapsAndModes.defaultPawnClass, pawn);
      expect((await ok('apply_project_settings'))['validation_errors'], isEmpty);
      final disk = manifest()['maps_and_modes'] as Map;
      expect(disk['default_game_mode'], mode);
      expect(disk['default_pawn_class'], pawn);
    });

    testWidgets('mounting the Project Settings tab after an MCP edit adopts the same view model (no second load)', (tester) async {
      await tester.runAsync(() => ok('set_project_settings', {'changes': {'physics.gravity_z': -490}}));
      final staged = tab();
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(
          child: SubEditorWorkspaceWidget(
            assetType: 'projectSettings',
            assetName: 'Project Settings',
            tabId: McpEditorSessions.projectSettingsTabId,
            editorViewModel: vm,
          ),
        ),
      ));
      await tester.pump();
      final state = tester.state<State<ProjectSettingsSubEditor>>(find.byType(ProjectSettingsSubEditor));
      expect(identical((state as dynamic).viewModelForTest, staged), isTrue, reason: 'the tab adopted the MCP view model');
      expect(staged.isDirty, isTrue, reason: 'a second load() would have reset the working copy to the disk');
      await tester.tap(find.byKey(const ValueKey('project_settings_nav_physics')));
      await tester.pump();
      final gravity = tester.widget<TextField>(find.byKey(const ValueKey('project_settings_gravity')));
      expect(gravity.controller!.text, '-490.0');
      await tester.pumpWidget(const SizedBox());
    });

    test('the widget library changes only through set_widget_library, a job that saves the manifest', () async {
      await expectInvalid('set_project_settings', {'changes': {'ui.widget_library': 'flutter'}}, contains('set_widget_library'));
      await expectInvalid('set_widget_library', {'library': 'material'}, contains('shadcn'));
      final sw = Stopwatch()..start();
      final started = await ok('set_widget_library', {'library': 'flutter'});
      expect(sw.elapsedMilliseconds, lessThan(200), reason: 'a job id comes back at once');
      final id = started['job_id'] as String;
      expect(server.recentCalls.first.jobId, id, reason: 'Recent calls shows the job beside the call');
      final done = await ok('wait_job', {'id': id, 'timeout_ms': 20000});
      expect(done['state'], 'succeeded', reason: '${done['error']}');
      expect(done['kind'], 'project_settings_apply');
      expect(((manifest()['ui'] as Map)['widget_library']), 'flutter');
    });

    test('edit_project_input: add J → IA_Jump, apply; unknown keys are -32602; remove_action drops its mappings', () async {
      final added = await ok('edit_project_input', {'op': 'add_mapping', 'context': 'Gameplay', 'action': 'IA_Jump', 'key': 'J'});
      expect(added['validation_errors'], isEmpty);
      final gameplay = tab().project.input.mappingContexts.firstWhere((c) => c.name == 'Gameplay');
      expect(gameplay.mappings.where((m) => m.action == 'IA_Jump' && m.keyId == LogicalKeyboardKey.keyJ.keyId), hasLength(1));
      expect((await ok('apply_project_settings'))['saved'], isTrue);
      final contexts = ((manifest()['input'] as Map)['mapping_contexts'] as List).cast<Map>();
      final mappings = (contexts.firstWhere((c) => c['name'] == 'Gameplay')['mappings'] as List).cast<Map>();
      expect(mappings.where((m) => m['action'] == 'IA_Jump' && m['key_id'] == LogicalKeyboardKey.keyJ.keyId && m['key'] == 'J'), hasLength(1));

      await expectInvalid('edit_project_input', {'op': 'add_mapping', 'context': 'Gameplay', 'action': 'IA_Jump', 'key': 'NotAKey'},
          allOf(contains('NotAKey'), contains('Space'), contains('LeftShift')));

      final removed = await ok('edit_project_input', {'op': 'remove_action', 'action': 'IA_Dash'});
      expect(removed['removed_mappings'], 2);
      expect(tab().project.input.actions.any((a) => a.name == 'IA_Dash'), isFalse);
      expect(tab().project.input.mappingContexts.expand((c) => c.mappings).any((m) => m.action == 'IA_Dash'), isFalse);
      await expectInvalid('edit_project_input', {'op': 'remove_action', 'action': 'IA_Dash'}, contains('IA_Jump'));
    });

    test('set_project_icon copies a real 512×512 PNG into branding/; a .txt is refused with chooseIcon\'s message', () async {
      final png = img.Image(width: 512, height: 512);
      img.fill(png, color: img.ColorRgb8(240, 120, 20));
      img.fillCircle(png, x: 256, y: 256, radius: 180, color: img.ColorRgb8(20, 40, 90));
      final source = File('${root.path}/icon.png')..writeAsBytesSync(img.encodePng(png));
      final set = await ok('set_project_icon', {'path': source.path});
      expect(set['validation_errors'], isEmpty);
      expect(File('${projectDir.path}/branding/app_icon.png').existsSync(), isTrue);
      expect(((set['settings'] as Map)['branding'] as Map)['icon'], 'branding/app_icon.png');
      expect(tab().project.branding.icon, 'branding/app_icon.png');

      final text = File('${root.path}/notes.txt')..writeAsStringSync('not an image');
      final refused = await call('set_project_icon', {'path': text.path});
      expect(refused.isError, isTrue);
      expect(refused.text, contains('A project icon must be an'));
    });

    test('Editor Preferences: read, set both, the file holds them; out of range and marketplace_url are refused', () async {
      final prefs = await ok('get_editor_preferences');
      expect(prefs['import_workers'], 1);
      expect(prefs['flight_camera_control'], 'rmbHeld');
      await ok('set_editor_preferences', {'import_workers': 3, 'flight_camera_control': 'never'});
      final file = File(prefs['file'] as String);
      final saved = jsonDecode(file.readAsStringSync()) as Map;
      expect(saved['importWorkers'], 3);
      expect(saved['flightCameraControl'], 'never');
      await expectInvalid('set_editor_preferences', {'import_workers': 9}, contains('1..4'));
      final refused = await call('set_editor_preferences', {'marketplace_url': 'http://x'});
      expect(refused.isError, isTrue);
      expect(refused.text, contains('supply-chain'));
      expect(vm.editorPreferences.marketplaceUrl, isNot('http://x'));
    });

    test('Generate Dart Code (run_codegen, listed in build) writes main + level; build_navigation stays a single tool', () async {
      final built = await ok('run_codegen');
      final written = (built['written_files'] as List).cast<String>();
      expect(written, containsAll(['lib/main.dart', 'lib/levels/l_main.dart']));
      expect(File('${projectDir.path}/lib/main.dart').existsSync(), isTrue);
      expect(File('${projectDir.path}/lib/levels/l_main.dart').existsSync(), isTrue);
      final all = (await client.listTools()).map((t) => t['name']).toList();
      expect(all.where((n) => n == 'build_navigation'), hasLength(1));
      final buildGroup = (await client.listTools(groups: ['build'])).map((t) => t['name']).toSet();
      expect(buildGroup, containsAll(['run_codegen', 'get_build_settings', 'set_build_settings', 'start_build', 'get_build_status', 'launch_web_build']));
      final registered = server.tools.tools.where((t) => t.groups.contains(McpToolGroups.build)).map((t) => t.name).toSet();
      expect(registered.contains('build_navigation'), isFalse);
    });

    test('set_build_settings: targets and Shipping reach get_build_settings, the cook argv and the .lmproject', () async {
      final set = await ok('set_build_settings', {'targets': ['linux', 'web'], 'configuration': 'Shipping', 'extra_flags': '--no-tree-shake-icons'});
      expect(set['selected_targets'], ['linux', 'web']);
      final read = await ok('get_build_settings');
      expect(read['selected_targets'], ['linux', 'web']);
      expect(read['configuration'], 'Shipping');
      expect(read['flutter_version'], '3.47.0');
      expect(((read['cook_arguments'] as Map)['linux'] as List), containsAll(['--release', '--no-tree-shake-icons']));
      expect(((manifest()['packaging'] as Map)['targets'] as List), ['linux', 'web']);
      expect((read['steps'] as List).length, 4);
      await ok('set_build_settings', {'steps': {'regenerateThumbnails': false}});
      expect(((await ok('get_build_settings'))['steps'] as List).cast<Map>().firstWhere((s) => s['step'] == 'regenerateThumbnails')['enabled'], isFalse);
      await expectInvalid('set_build_settings', {'targets': ['amiga']}, contains('amiga'));
    });

    test('start_build: Build All and Cook & Package as jobs; a second build is refused; the linux package exists', () async {
      // The default level's M_Ground_PBR has no compiled package here (no
      // matc in unit tests), so Precompile Materials is unticked, as a user
      // without the material compiler would.
      await ok('set_build_settings', {'steps': {'precompileMaterials': false}});
      var sw = Stopwatch()..start();
      final started = await ok('start_build', {'kind': 'build_all'});
      expect(sw.elapsedMilliseconds, lessThan(200));
      expect(vm.openTabs.any((t) => t.category == 'buildManager'), isTrue);
      final done = await ok('wait_job', {'id': started['job_id'], 'timeout_ms': 25000});
      expect(done['state'], 'succeeded', reason: '${done['error']} ${done['log']}');
      final steps = ((done['result'] as Map)['steps'] as List).cast<Map>();
      expect(steps.firstWhere((x) => x['step'] == 'precompileMaterials'), allOf(containsPair('enabled', false), containsPair('status', 'pending')));
      for (final s in ['buildNavigation', 'regenerateThumbnails', 'validateAssets']) {
        expect(steps.firstWhere((x) => x['step'] == s)['status'], anyOf('ok', 'skipped'), reason: s);
      }
      expect(steps.firstWhere((x) => x['step'] == 'validateAssets')['status'], 'ok');
      expect((done['result'] as Map)['last_pipeline_status'], 'ok');

      sw = Stopwatch()..start();
      final cook = await ok('start_build', {'kind': 'cook_and_package'});
      expect(sw.elapsedMilliseconds, lessThan(200));
      final second = await call('start_build', {'kind': 'build_all'});
      expect(second.isError, isTrue);
      expect(second.text, contains(cook['job_id'] as String));
      Map<String, Object?> cooked = {};
      for (var i = 0; i < 6; i++) {
        cooked = await ok('wait_job', {'id': cook['job_id'], 'timeout_ms': 20000});
        if (cooked['timed_out'] != true) break;
      }
      expect(cooked['state'], 'succeeded', reason: '${cooked['error']} ${cooked['log']}');
      final linux = ((cooked['result'] as Map)['targets'] as Map)['linux'] as Map;
      expect(linux['status'], 'ok');
      expect(Directory(linux['package_dir'] as String).existsSync(), isTrue);
      final log = (await ok('get_job', {'id': cook['job_id'], 'tail': 2000}))['log'] as List;
      expect(log.any((l) => ((l as Map)['message'] as String).contains('Compiling lib/main.dart for linux')), isTrue,
          reason: 'the job log carries the flutter build output');
    });

    test('cancel_job kills a long flutter build: cancelled within 2 s and the child is gone', () async {
      vm.buildProcessStarter = sleepingFlutterBuildStandIn(recordDir);
      await ok('set_build_settings', {'steps': {'precompileMaterials': false}});
      final cook = await ok('start_build', {'kind': 'cook_and_package'});
      final id = cook['job_id'] as String;
      for (var i = 0; i < 200 && standInPids(recordDir).isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      final pid = standInPids(recordDir).single;
      expect(processAlive(pid), isTrue);
      final status = await ok('get_build_status');
      expect(status['is_running'], isTrue);
      expect(status['job_id'], id);
      final sw = Stopwatch()..start();
      final cancelled = await ok('cancel_job', {'id': id});
      expect(cancelled['state'], 'cancelled');
      for (var i = 0; i < 40 && processAlive(pid); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      expect(sw.elapsedMilliseconds, lessThan(2000));
      expect(processAlive(pid), isFalse, reason: 'flutter build was killed');
      expect(vm.buildManagerViewModel.isRunning, isFalse);
    });

    test('a build the user started from the Build menu is visible through get_build_status', () async {
      vm.buildProcessStarter = sleepingFlutterBuildStandIn(recordDir);
      vm.buildManagerViewModel.setStepEnabled(BuildStepKind.precompileMaterials, false);
      vm.commands.execute('build.cookAndPackage');
      for (var i = 0; i < 200 && standInPids(recordDir).isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      final status = await ok('get_build_status');
      expect(status['is_running'], isTrue);
      expect(status['job_id'], isNull, reason: 'no agent job runs it');
      expect((status['steps'] as List).cast<Map>().firstWhere((s) => s['step'] == 'cookAndPackage')['status'], 'running');
      final refused = await call('start_build', {'kind': 'build_all'});
      expect(refused.isError, isTrue);
      expect(refused.text, contains('Build menu'));
      vm.buildManagerViewModel.cancel();
      for (var i = 0; i < 100 && vm.buildManagerViewModel.isRunning; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      expect(vm.buildManagerViewModel.isRunning, isFalse);
    });

    test('continue_on_validation_failure: false skips the cook with a reason and no dialog; true cooks', () async {
      await ok('set_build_settings', {'steps': {'precompileMaterials': false}});
      File('${projectDir.path}/contents/meshes/SM_Broken.lmas')
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(const LuminaAsset(assetId: 'mesh-broken', name: 'SM_Broken', type: AssetType.filamesh, references: [
          AssetReference(slotName: 'material_0', assetId: 'mat-x', assetPath: 'contents/materials/M_X.lmas'),
        ]).toProtoBufferBytes());
      var asked = 0;
      vm.buildManagerViewModel.confirmCookDespiteValidation = (_) async {
        asked++;
        return true;
      };
      final skip = await ok('start_build', {'kind': 'cook_and_package'});
      final skipped = await ok('wait_job', {'id': skip['job_id'], 'timeout_ms': 25000});
      expect(skipped['state'], 'failed');
      final steps = ((skipped['result'] as Map)['steps'] as List).cast<Map>();
      expect(steps.firstWhere((s) => s['step'] == 'validateAssets')['status'], 'failed');
      expect(steps.firstWhere((s) => s['step'] == 'cookAndPackage')['status'], 'skipped');
      final log = ((await ok('get_job', {'id': skip['job_id'], 'tail': 2000}))['log'] as List).map((l) => (l as Map)['message'] as String);
      expect(log.any((m) => m.contains('continue_on_validation_failure is false')), isTrue);
      expect(asked, 0, reason: 'the tab\'s dialog is never asked while an agent\'s build runs');
      expect(File('${recordDir.path}/argv.log').existsSync(), isFalse, reason: 'no flutter build ran');

      final go = await ok('start_build', {'kind': 'cook_and_package', 'continue_on_validation_failure': true});
      Map<String, Object?> cooked = {};
      for (var i = 0; i < 6; i++) {
        cooked = await ok('wait_job', {'id': go['job_id'], 'timeout_ms': 20000});
        if (cooked['timed_out'] != true) break;
      }
      final cookStep = ((cooked['result'] as Map)['steps'] as List).cast<Map>().firstWhere((s) => s['step'] == 'cookAndPackage');
      expect(cookStep['status'], 'ok', reason: '${cooked['error']}');
      expect(File('${recordDir.path}/argv.log').existsSync(), isTrue, reason: 'flutter build ran');
      expect(asked, 0);
      expect(vm.buildManagerViewModel.confirmCookOverride, isNull, reason: 'the hook is the tab\'s again');
    });

    test('play_standalone builds with the stand-in, runs the game as a job, stop_standalone cancels it and the pid is gone', () async {
      const binary = 'agent_game';
      final platform = Platform.isWindows ? 'windows' : 'linux';
      File('${projectDir.path}/$platform/CMakeLists.txt')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('cmake_minimum_required(VERSION 3.14)\nproject(agent_game LANGUAGES CXX)\nset(BINARY_NAME "$binary")\n');
      vm.standaloneFlutterExecutable = standaloneFlutterStandIn(recordDir, binaryName: binary);
      final started = await ok('play_standalone');
      final id = started['job_id'] as String;
      final stages = <String>{};
      int? pid;
      for (var i = 0; i < 300; i++) {
        final job = await ok('get_job', {'id': id});
        if (job['stage'] is String) stages.add(job['stage'] as String);
        final status = await ok('standalone_status');
        if (status['state'] == 'running') {
          pid = status['pid'] as int?;
          break;
        }
        expect(job['state'], 'running', reason: '${job['error']} ${job['result']} ${job['log']}');
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      expect(pid, isNotNull, reason: 'the game runs');
      expect(stages, contains('building'));
      expect(processAlive(pid!), isTrue);
      expect((await call('play_standalone')).isError, isTrue, reason: 'one standalone game at a time');
      final stopped = await ok('stop_standalone');
      expect(stopped['cancelled_job'], id);
      expect((await ok('get_job', {'id': id}))['state'], 'cancelled');
      for (var i = 0; i < 40 && processAlive(pid); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      expect(processAlive(pid), isFalse);
    });

    test('every play-testing tool without Play says "call start_pie first"; every new tool declares risk and groups', () async {
      for (final tool in ['pie_key', 'pie_axis', 'pie_mouse_move', 'pie_action', 'pie_click', 'pie_type_text', 'pie_advance', 'pie_play_for', 'pie_get_actors']) {
        final args = switch (tool) {
          'pie_key' => {'key': 'W', 'action': 'down'},
          'pie_axis' => {'key': 'MouseX', 'value': 1},
          'pie_mouse_move' => {'dx': 1, 'dy': 0},
          'pie_action' => {'action': 'IA_Jump'},
          'pie_click' => {'x': 1, 'y': 1},
          'pie_type_text' => {'text': 'x'},
          'pie_advance' => {'frames': 1},
          'pie_play_for' => {'ms': 10},
          _ => <String, Object?>{},
        };
        final r = await call(tool, args);
        expect(r.isError, isTrue, reason: tool);
        expect(r.text, contains('call start_pie first'), reason: tool);
      }
      const added = {
        'list_jobs', 'get_job', 'wait_job', 'cancel_job', 'get_project_settings', 'set_project_settings', 'edit_project_input',
        'set_project_icon', 'set_web_loading_logo', 'apply_project_settings', 'revert_project_settings', 'set_widget_library',
        'get_editor_preferences', 'set_editor_preferences', 'get_build_settings', 'set_build_settings', 'start_build',
        'get_build_status', 'launch_web_build', 'play_standalone', 'stop_standalone', 'standalone_status', 'eject_pie',
        'possess_pie', 'pie_key', 'pie_axis', 'pie_mouse_move', 'pie_action', 'pie_click', 'pie_type_text', 'pie_advance',
        'pie_play_for', 'pie_get_actors',
      };
      final listed = {for (final t in await client.listTools()) t['name'] as String: t};
      for (final name in added) {
        final meta = listed[name]?['_meta'] as Map?;
        expect(meta, isNotNull, reason: name);
        expect(McpToolRisk.parse(meta!['lumina/risk']), isNotNull, reason: name);
        expect((meta['lumina/groups'] as List), isNotEmpty, reason: name);
      }
      expect(listed['start_build']!['_meta'], containsPair('lumina/risk', 'external'));
      expect(listed['cancel_job']!['_meta'], containsPair('lumina/groups', ['core']));
    });
  });

  group('play-testing (a Third Person scaffold, headless Play)', () {
    late Directory scaffoldRoot;
    late String gameDir;

    setUpAll(() async {
      scaffoldRoot = Directory.systemTemp.createTempSync('lumina_mcp07_play_');
      gameDir = await scaffoldGameProject(scaffoldRoot, name: 'play_game', widgetLibrary: 'flutter');
    });
    tearDownAll(() => deleteTempProject(scaffoldRoot));

    late LuminaWorld world;

    setUp(() async {
      final configDir = Directory('${scaffoldRoot.path}/config_${DateTime.now().microsecondsSinceEpoch}')..createSync();
      final project = LuminaProject.fromMap(
          Map<String, dynamic>.from(jsonDecode(File('$gameDir/play_game.lmproject').readAsStringSync()) as Map));
      vm = EditorViewModel(initialProject: project, projectLocation: scaffoldRoot.path, enableTimers: false, autoInitAssets: false);
      await vm.ensureDefaultLevelAssets();
      vm.refreshAssets();
      server = McpServerService(vm, configDir: configDir, settings: McpServerSettings.load(configDir: configDir));
      expect(await server.start(port: 0), isTrue);
      client = McpTestClient(server.url!, server.token);
      await client.handshake();
      final started = await call('start_pie');
      expect(started.isError, isFalse, reason: started.text);
      world = LuminaWorld();
      vm.pieController.startHeadlessForTest(world);
      // The pawn spawns deferred: the first frames register it and land it.
      await ok('pie_advance', {'frames': 30});
    });

    tearDown(() async {
      if (vm.pieController.isPlaying) vm.pieController.stopHeadlessForTest();
      client.close();
      await server.stop();
      await vm.close();
    });

    List<double> location(Map<String, Object?> r) => (r['player_location'] as List).map((v) => (v as num).toDouble()).toList();
    double horizontal(List<double> a, List<double> b) => math.sqrt(math.pow(a[0] - b[0], 2) + math.pow(a[1] - b[1], 2));

    test('keys and actions walk and jump the pawn through the project\'s bindings; an unknown action lists them', () async {
      final start = location(await ok('pie_status'));
      expect((await ok('pie_key', {'key': 'W', 'action': 'down'}))['held_keys'], ['KeyW']);
      final walked = await ok('pie_advance', {'frames': 60});
      expect(horizontal(location(walked), start), greaterThan(100), reason: 'a second of W walks the pawn');
      expect(walked['held_keys'], ['KeyW']);
      expect((await ok('pie_key', {'key': 'W', 'action': 'up'}))['held_keys'], isEmpty);
      await ok('pie_advance', {'frames': 60});

      final grounded = location(await ok('pie_status'));
      final jump = await ok('pie_action', {'action': 'IA_Jump'});
      expect(jump['pressed'], ['KeySpace']);
      final rising = await ok('pie_advance', {'frames': 10});
      expect(location(rising)[2], greaterThan(grounded[2] + 5), reason: 'the pawn\'s Z rose');
      await ok('pie_advance', {'frames': 90});

      final before = location(await ok('pie_status'));
      final strafe = await ok('pie_action', {'action': 'IA_Move', 'value': [1, 0], 'hold_frames': 30});
      expect(strafe['pressed'], ['KeyD']);
      final after = location(strafe);
      // W walked along the controller's forward; D strafes across it.
      final w = [location(walked)[0] - start[0], location(walked)[1] - start[1]];
      final wLength = math.sqrt(w[0] * w[0] + w[1] * w[1]);
      final forward = [w[0] / wLength, w[1] / wLength];
      final moved = [after[0] - before[0], after[1] - before[1]];
      final along = moved[0] * forward[0] + moved[1] * forward[1];
      final side = math.sqrt(moved[0] * moved[0] + moved[1] * moved[1]);
      expect(side, greaterThan(20), reason: 'IA_Move [1, 0] moved the pawn');
      expect(along.abs(), lessThan(side * 0.5), reason: 'sideways, not forward');

      final nope = await call('pie_action', {'action': 'IA_Nope'});
      expect(nope.isError, isTrue);
      expect(nope.text, allOf(contains('IA_Move'), contains('IA_Jump'), contains('KeySpace')));
    });

    test('pie_axis MouseX turns the controller; a zero mouse move changes nothing', () async {
      final controller = vm.pieController.game!.playerController!;
      final yaw = controller.controlRotation.y;
      await ok('pie_axis', {'key': 'MouseX', 'value': 40});
      await ok('pie_advance', {'frames': 1});
      expect(controller.controlRotation.y, isNot(closeTo(yaw, 1e-6)));
      final turned = controller.controlRotation.clone();
      await ok('pie_mouse_move', {'dx': 0, 'dy': 0});
      await ok('pie_advance', {'frames': 1});
      expect((controller.controlRotation - turned).length, lessThan(1e-9));
      await expectInvalid('pie_axis', {'key': 'W', 'value': 1}, contains('digital'));
    });

    test('pie_advance logs one line for all its frames; 601 frames is -32602', () async {
      final before = vm.logs.length;
      final advanced = await ok('pie_advance', {'frames': 60});
      final lines = vm.logs.sublist(before).where((l) => l.source == 'PIE').map((l) => l.message).toList();
      expect(lines.where((m) => m.startsWith('PIE advanced 60 frames')), hasLength(1));
      expect(lines.where((m) => m.startsWith('PIE stepped')), isEmpty);
      expect((advanced['log'] as List).any((l) => ((l as Map)['message'] as String).startsWith('PIE advanced 60 frames')), isTrue);
      expect(advanced['frames_advanced'], greaterThanOrEqualTo(90));
      await expectInvalid('pie_advance', {'frames': 601}, contains('600'));
    });

    test('held keys are released when Play stops', () async {
      final input = world.getSubsystem<LuminaInputSubsystem>()!;
      await ok('pie_key', {'key': 'W', 'action': 'down'});
      expect(input.isKeyDown(LuminaKey.keyW), isTrue);
      expect((await ok('pie_status'))['held_keys'], ['KeyW']);
      final stopped = await ok('stop_pie');
      expect(stopped['released_keys'], ['KeyW']);
      expect(input.isKeyDown(LuminaKey.keyW), isFalse, reason: 'injectKeyUp reached the world before it went away');
      expect(stopped['held_keys'], isEmpty);
    });

    test('eject drops presses with a note; possess accepts them again; a session that ends lets its keys go', () async {
      await ok('pie_key', {'key': 'W', 'action': 'down'});
      final ejected = await ok('eject_pie');
      expect(ejected['ejected'], isTrue);
      expect(ejected['released_keys'], ['KeyW']);
      final dropped = await ok('pie_key', {'key': 'Space', 'action': 'down'});
      expect(dropped['dropped'], isTrue);
      expect(dropped['note'], contains('possess_pie'));
      expect((await ok('pie_status'))['held_keys'], isEmpty);
      final possessed = await ok('possess_pie');
      expect(possessed['ejected'], isFalse);
      expect((await ok('pie_key', {'key': 'W', 'action': 'down'}))['held_keys'], ['KeyW']);
      final input = world.getSubsystem<LuminaInputSubsystem>()!;
      expect(input.isKeyDown(LuminaKey.keyW), isTrue);
      await client.post(const {}, method: 'DELETE');
      expect(input.isKeyDown(LuminaKey.keyW), isFalse, reason: 'the session ended; its keys were released');
      expect(server.playTesting.heldKeys, isEmpty);
    });

    test('pie_get_actors: the possessed character, where pie_status says the player is', () async {
      final actors = ((await ok('pie_get_actors', {'class_contains': 'Character'}))['actors'] as List).cast<Map>();
      expect(actors, hasLength(1));
      expect(actors.single['is_possessed_pawn'], isTrue);
      expect(actors.single['class'], 'BP_ThirdPersonCharacter');
      expect(actors.single['velocity'], isA<List>());
      final there = (await ok('pie_status'))['player_location'] as List;
      for (var i = 0; i < 3; i++) {
        expect((actors.single['location'] as List)[i] as num, closeTo(there[i] as num, 0.01));
      }
      final all = ((await ok('pie_get_actors'))['actors'] as List).cast<Map>();
      expect(all.any((a) => a['id'] != null), isTrue, reason: 'placed actors carry their editor id');
    });
  });

  group('clicks and text in the PIE widget layer (the real editor pumped)', () {
    testWidgets("pie_click fires a button's On Clicked; pie_type_text types into the clicked field and submits it", (tester) async {
      root = Directory.systemTemp.createTempSync('lumina_mcp07_ui_');
      final configDir = Directory('${root.path}/config')..createSync();
      projectDir = Directory('${root.path}/AgentGame')..createSync();
      const project = LuminaProject(projectName: 'AgentGame', activeLevel: mainLevel);
      File('${projectDir.path}/AgentGame.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
      Directory('${projectDir.path}/contents/levels').createSync(recursive: true);
      File('${projectDir.path}/contents/widgets/WBP_AgentForm.lmas')
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(LuminaAsset(
          assetId: 'wbp_agent_form',
          name: 'WBP_AgentForm',
          type: AssetType.widget,
          rawPayload: Uint8List.fromList(utf8.encode(agentFormDocument().toFormattedJson())),
        ).toProtoBufferBytes());
      vm = EditorViewModel(initialProject: project, projectLocation: root.path, enableTimers: false, autoInitAssets: false);
      server = McpServerService(vm, configDir: configDir, settings: McpServerSettings.load(configDir: configDir));
      await tester.runAsync(() async {
        expect(await server.start(port: 0), isTrue);
        client = McpTestClient(server.url!, server.token);
        await client.handshake();
      });
      addTearDown(() async {
        LuminaUserWidgets.clear();
        LuminaWidgetClassRegistry.clear();
        if (vm.pieController.isPlaying) vm.pieController.stopHeadlessForTest();
        client.close();
        await server.stop();
        vm.dispose();
        await deleteTempProject(root);
      });
      Future<McpToolReply> ui(String tool, [Map<String, Object?> args = const {}]) async =>
          (await tester.runAsync(() => client.callTool(tool, args)))!;

      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      expect((await ui('start_pie')).isError, isFalse);
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      final character = _FormCharacter();
      world.persistentLevel.registerActor(character);
      vm.pieController.startHeadlessForTest(world);
      vm.pieController.registerWidgetClasses();
      vm.pieController.registerWidgetScripts();
      world.beginPlay();
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(find.text('Start'), findsOneWidget, reason: 'the form is in the PIE widget layer');
      expect(find.text('Waiting'), findsOneWidget);

      final nothingFocused = await ui('pie_type_text', {'text': 'hello'});
      expect(nothingFocused.isError, isTrue);
      expect(nothingFocused.text, contains('click the field with pie_click first'));

      final viewport = server.viewportBoundaryKey.currentContext!.findRenderObject()! as RenderBox;
      Offset inViewport(Finder f) => viewport.globalToLocal(tester.getCenter(f));
      final button = inViewport(find.text('Start'));
      final clicked = await ui('pie_click', {'x': button.dx, 'y': button.dy});
      expect(clicked.isError, isFalse, reason: clicked.text);
      await tester.pump();
      expect(find.text('Clicked!'), findsOneWidget, reason: 'On Clicked (StartButton) ran');
      expect(vm.logs.any((l) => l.message.contains('StartButton clicked')), isTrue, reason: 'its Print String reached the log');

      final field = inViewport(find.byKey(const ValueKey('umg_rt_field_n_field')));
      expect((await ui('pie_click', {'x': field.dx, 'y': field.dy})).isError, isFalse);
      await tester.pump();
      final typed = await ui('pie_type_text', {'text': 'hello', 'submit': true});
      expect(typed.isError, isFalse, reason: typed.text);
      expect(typed.data['text'], 'hello');
      await tester.pump();
      expect(find.text('Committed!'), findsOneWidget, reason: "the field's onSubmitted fired On Text Committed");
      final outside = await tester.runAsync(() async {
        try {
          await client.callTool('pie_click', {'x': -5, 'y': 10});
          return null;
        } on McpRpcError catch (e) {
          return e;
        }
      });
      expect(outside?.code, -32602);
      expect(outside?.message, contains('outside the viewport'));
      await tester.pumpWidget(const SizedBox());
    });
  });
}

/// Creates WBP_AgentForm and adds it to the viewport at BeginPlay.
class _FormCharacter extends LuminaCharacter {
  @override
  void onBeginPlay() {
    super.onBeginPlay();
    final widget = LuminaBlueprintFunctionLibrary.createWidget(this, 'WBP_AgentForm');
    LuminaBlueprintFunctionLibrary.addToViewport(this, widget, 0);
  }
}
