import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_server_service.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_server_settings.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../helpers/mcp_test_client.dart';
import '../helpers/scaffold_game_project.dart';
import '../helpers/temp_project.dart';

/// `pie_sequence`: a scripted play test in one MCP call — a real MCP client
/// over HTTP against a real editor on a Third Person scaffold in a temp
/// directory. Play runs headless: the world is mounted when Play starts and
/// unmounted when it stops, as the level viewport does.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory scaffoldRoot;
  late String gameDir;

  setUpAll(() async {
    scaffoldRoot = Directory.systemTemp.createTempSync('lumina_mcp_seq_');
    gameDir = await scaffoldGameProject(scaffoldRoot, name: 'seq_game', widgetLibrary: 'flutter');
  });
  tearDownAll(() => deleteTempProject(scaffoldRoot));

  late EditorViewModel vm;
  late McpServerService server;
  late McpTestClient client;
  LuminaWorld? world;

  /// Mounts a headless world when Play starts and drops it when Play stops.
  void followPlay() {
    final pie = vm.pieController;
    if (vm.isPlaying && !pie.isPlaying) {
      world = LuminaWorld();
      pie.startHeadlessForTest(world!);
    } else if (!vm.isPlaying && pie.isPlaying) {
      pie.stopHeadlessForTest();
    }
  }

  Future<void> openEditor() async {
    final configDir = Directory('${scaffoldRoot.path}/config_${DateTime.now().microsecondsSinceEpoch}')..createSync();
    final project = LuminaProject.fromMap(
        Map<String, dynamic>.from(jsonDecode(File('$gameDir/seq_game.lmproject').readAsStringSync()) as Map));
    vm = EditorViewModel(initialProject: project, projectLocation: scaffoldRoot.path, enableTimers: false, autoInitAssets: false);
    await vm.ensureDefaultLevelAssets();
    vm.refreshAssets();
    vm.addListener(followPlay);
    server = McpServerService(vm, configDir: configDir, settings: McpServerSettings.load(configDir: configDir));
    expect(await server.start(port: 0), isTrue);
    client = McpTestClient(server.url!, server.token);
    await client.handshake();
  }

  Future<void> closeEditor() async {
    vm.removeListener(followPlay);
    if (vm.pieController.isPlaying) vm.pieController.stopHeadlessForTest();
    client.close();
    await server.stop();
    await vm.close();
  }

  List<double> loc(Object? v) => (v as List).map((e) => (e as num).toDouble()).toList();
  double distance(List<double> a, List<double> b) =>
      math.sqrt(math.pow(a[0] - b[0], 2) + math.pow(a[1] - b[1], 2) + math.pow(a[2] - b[2], 2));

  group('pie_sequence (headless Play)', () {
    setUp(openEditor);
    tearDown(closeEditor);

    Future<void> expectInvalid(Map<String, Object?> args, Matcher message) => expectLater(
          client.callTool('pie_sequence', args),
          throwsA(isA<McpRpcError>().having((e) => e.code, 'code', -32602).having((e) => e.message, 'message', message)),
        );

    test('held keys are released at the end; Play stays running, paused', () async {
      final reply = await client.callTool('pie_sequence', {
        'steps': [
          {'advance_frames': 20},
          {'key': 'W', 'state': 'down', 'label': 'W down'},
          {'advance_frames': 30, 'label': 'walk'},
        ],
      });
      expect(reply.isError, isFalse, reason: reply.text);
      final data = reply.data;
      expect(data['started_pie'], isTrue);
      final steps = (data['steps'] as List).cast<Map>();
      expect(steps, hasLength(3));
      expect(steps[1]['kind'], 'key');
      expect(steps[1]['label'], 'W down');
      expect(distance(loc(steps[2]['player_location']), loc(steps[1]['player_location'])), greaterThan(20),
          reason: 'W held across the frames walks the pawn');
      expect(data['released_keys'], ['KeyW']);
      final input = world!.getSubsystem<LuminaInputSubsystem>()!;
      expect(input.isKeyDown(LuminaKey.keyW), isFalse, reason: 'released in the world');
      final status = data['final_status'] as Map;
      expect(status['held_keys'], isEmpty);
      expect(status['playing'], isTrue);
      expect(status['paused'], isTrue);
      expect(vm.isPlaying, isTrue);
      expect(server.playTesting.heldKeys, isEmpty);
    });

    test('an invalid step stops the sequence with a clear error and stops the Play it started', () async {
      final reply = await client.callTool('pie_sequence', {
        'steps': [
          {'advance_frames': 10},
          {'action': 'IA_Nope', 'label': 'bad action'},
          {'advance_frames': 10},
        ],
      });
      expect(reply.isError, isTrue);
      expect(reply.text, allOf(contains('Step 1'), contains('IA_Nope'), contains('IA_Jump')));
      final data = reply.data;
      expect(data['failed_step'], 1);
      expect((data['steps'] as List), hasLength(2), reason: 'step 2 never ran');
      expect(((data['steps'] as List)[1] as Map)['ok'], isFalse);
      expect(data['stopped_pie'], isTrue);
      expect(vm.isPlaying, isFalse, reason: 'the sequence started Play, so an error stops it');

      final kept = await client.callTool('pie_sequence', {
        'keep_pie_on_error': true,
        'steps': [
          {'action': 'IA_Nope'},
        ],
      });
      expect(kept.isError, isTrue);
      expect(kept.data['stopped_pie'], isFalse);
      expect(vm.isPlaying, isTrue, reason: 'keep_pie_on_error keeps it');
    });

    test('a failed expect fails its step with what it measured', () async {
      final reply = await client.callTool('pie_sequence', {
        'steps': [
          {'advance_frames': 10},
          {'expect': {'min_distance_cm': 100000}, 'label': 'far away'},
        ],
      });
      expect(reply.isError, isTrue);
      expect(reply.data['failed_step'], 1);
      expect(reply.text, allOf(contains('far away'), contains('min_distance_cm')));
    });

    test('limits and malformed steps are -32602 before anything runs', () async {
      await expectInvalid({
        'steps': [for (var i = 0; i < 51; i++) {'advance_frames': 1}],
      }, contains('50'));
      await expectInvalid({
        'steps': [for (var i = 0; i < 11; i++) {'screenshot': true}],
      }, contains('10 screenshots'));
      await expectInvalid({
        'steps': [
          {'play_ms': 6000},
          {'key': 'W', 'hold_ms': 4001},
        ],
      }, contains('10000'));
      await expectInvalid({
        'steps': [
          {'advance_frames': 1},
          {'jump': true},
        ],
      }, allOf(contains('step 1'), contains('advance_frames')));
      await expectInvalid({
        'steps': [
          {'key': 'W', 'action': 'IA_Jump'},
        ],
      }, contains('step 0'));
      await expectInvalid({'steps': <Object?>[]}, contains('1..50'));
      expect(vm.isPlaying, isFalse, reason: 'nothing started');
    });

    test('refusals: start false without Play; a sub-editor tab hides the viewport', () async {
      final noPlay = await client.callTool('pie_sequence', {
        'start': false,
        'steps': [
          {'advance_frames': 1},
        ],
      });
      expect(noPlay.isError, isTrue);
      expect(noPlay.text, contains('call start_pie first'));

      vm.openSubEditorTab('mcpServer', title: 'AI Agent Access (MCP)');
      final hidden = await client.callTool('pie_sequence', {
        'steps': [
          {'advance_frames': 1},
        ],
      });
      expect(hidden.isError, isTrue);
      expect(hidden.text, contains('select_tab'));
      expect(vm.isPlaying, isFalse);
    });
  });

  group('pie_sequence with screenshots (the real editor pumped)', () {
    testWidgets('walks, jumps and returns two captioned screenshots; the player moved', (tester) async {
      await tester.runAsync(openEditor);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(closeEditor);
      });
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      final reply = (await tester.runAsync(() => client.callTool('pie_sequence', {
            'screenshot_max_width': 640,
            'steps': [
              {'advance_frames': 20},
              {'screenshot': true, 'label': 'start'},
              {'key': 'W', 'hold_ms': 800, 'label': 'walk forward'},
              {'action': 'IA_Jump'},
              {'advance_frames': 10},
              {'screenshot': true, 'label': 'after jump'},
              {'expect': {'player_moved': true}},
            ],
          })))!;
      expect(reply.isError, isFalse, reason: reply.text);
      final images = [for (final c in reply.content) if (c['type'] == 'image') c];
      expect(images, hasLength(2));
      for (final image in images) {
        final decoded = img.decodePng(base64Decode(image['data'] as String));
        expect(decoded, isNotNull);
        expect(decoded!.width, lessThanOrEqualTo(640));
      }
      // Each image follows its caption.
      final captions = <String>[
        for (var i = 1; i < reply.content.length; i++)
          if (reply.content[i]['type'] == 'image') reply.content[i - 1]['text'] as String,
      ];
      expect(captions[0], allOf(contains('Step 1'), contains('"start"')));
      expect(captions[1], allOf(contains('Step 5'), contains('"after jump"')));
      final data = reply.data;
      final shots = (data['screenshots'] as List).cast<Map>();
      expect([for (final s in shots) s['label']], ['start', 'after jump']);
      expect(distance(loc(shots[1]['player_location']), loc(shots[0]['player_location'])), greaterThan(50),
          reason: 'W held for 800 ms walked the pawn');
      final steps = (data['steps'] as List).cast<Map>();
      expect(steps[3]['kind'], 'action');
      expect((steps[3]['result'] as Map)['pressed'], ['KeySpace']);
      expect(steps[6]['ok'], isTrue);
      expect(data['started_pie'], isTrue);
      expect((data['final_status'] as Map)['paused'], isTrue);
      expect(vm.isPlaying, isTrue);
    });
  });

  group('PIE screenshots with a sub-editor tab in front (the real editor pumped)', () {
    testWidgets('start_pie shows the level viewport, and a pie_advance screenshot is a frame of the running Play', (tester) async {
      await tester.runAsync(openEditor);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(closeEditor);
      });
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      /// A call the editor answers while frames keep coming, as in the app.
      Future<McpToolReply> call(String tool, [Map<String, Object?> args = const {}]) async {
        McpToolReply? reply;
        Object? error;
        // Sent from the real zone, so the client's timers are real ones.
        await tester.runAsync(() async {
          unawaited(client.callTool(tool, args).then((r) => reply = r, onError: (Object e) => error = e));
        });
        while (reply == null && error == null) {
          await tester.pump(const Duration(milliseconds: 16));
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
        }
        if (error != null) throw error!;
        return reply!;
      }

      /// Whether [reply]'s image shows the "PIE ACTIVE" banner: the editor's
      /// primary orange at the top centre of the viewport.
      bool showsPlayBanner(McpToolReply reply) {
        final image = reply.content.firstWhere((c) => c['type'] == 'image', orElse: () => const {});
        expect(image['data'], isNotNull, reason: 'no image in: ${reply.text}');
        final decoded = img.decodePng(base64Decode(image['data'] as String))!;
        for (var y = 0; y < math.min(48, decoded.height); y++) {
          for (var x = (decoded.width * 0.35).round(); x < (decoded.width * 0.65).round(); x++) {
            final p = decoded.getPixel(x, y);
            if ((p.r - 0xFB).abs() < 12 && (p.g - 0x7C).abs() < 12 && p.b < 24) return true;
          }
        }
        return false;
      }

      // An agent edits a Blueprint: its editor tab is in front of the level.
      vm.openSubEditorTab('mcpServer', title: 'AI Agent Access (MCP)');
      await tester.pump(const Duration(milliseconds: 16));
      expect(vm.activeTabIndex, isNot(0));

      final started = await call('start_pie');
      expect(started.isError, isFalse, reason: started.text);
      expect(vm.activeTabIndex, 0, reason: 'Play runs in the level viewport, so start_pie shows it');
      final right = await call('viewport_screenshot', {'max_width': 1280});
      expect(right.isError, isFalse, reason: right.text);
      expect(showsPlayBanner(right), isTrue, reason: 'viewport_screenshot right after start_pie shows Play');

      // The agent opens a Blueprint again while Play runs, then asks for a frame.
      vm.openSubEditorTab('mcpServer', title: 'AI Agent Access (MCP)');
      await tester.pump(const Duration(milliseconds: 16));
      expect(vm.activeTabIndex, isNot(0));
      final advanced = await call('pie_advance', {'frames': 2, 'screenshot': true});
      expect(advanced.isError, isFalse, reason: advanced.text);
      expect(advanced.data['screenshot_error'], isNull, reason: '${advanced.data['screenshot_error']}');
      expect(vm.activeTabIndex, 0, reason: 'the play-testing screenshot brings the level viewport forward');
      expect(showsPlayBanner(advanced), isTrue, reason: 'the frame is of the running Play, not the editor before it');

      // Stopped, and the Blueprint trace's fade (lit for 500 ms) runs out.
      expect((await call('stop_pie')).isError, isFalse);
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 33));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      }
    });
  });
}
