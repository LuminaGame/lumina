import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/core/host/editor_host.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/lumina_guide.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_server_service.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_server_settings.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_tool.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/material_graph.dart';

import '../helpers/mcp_test_client.dart';
import '../helpers/temp_project.dart';

/// The Lumina engine guide for AI models: the `lumina-engine` skill shipped
/// as Flutter assets, served by `get_lumina_guide` and the `lumina://guide`
/// resources — a real MCP client over HTTP against a real editor on a real
/// temp project. The guide's tool, node, pin and argument names are checked
/// against the live registry and node library, so it never cites a name that
/// does not exist.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final skillDir = Directory('${Directory.current.path}/skills/lumina-engine');
  const mainLevel = 'contents/levels/L_Main.lmas';

  late Directory root;
  late EditorViewModel vm;
  late McpServerService server;
  late McpTestClient client;
  late Map<String, Object?> initialize;

  setUp(() async {
    root = Directory.systemTemp.createTempSync('lumina_mcp_guide_');
    final configDir = Directory('${root.path}/config')..createSync();
    final projectDir = Directory('${root.path}/GuideProject')..createSync();
    const project = LuminaProject(projectName: 'GuideProject', activeLevel: mainLevel);
    File('${projectDir.path}/GuideProject.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
    Directory('${projectDir.path}/contents/levels').createSync(recursive: true);
    vm = EditorViewModel(
      initialProject: project,
      projectLocation: root.path,
      enableTimers: false,
      autoInitAssets: false,
    );
    server = McpServerService(
      vm,
      configDir: configDir,
      settings: McpServerSettings.load(configDir: configDir),
    );
    expect(await server.start(port: 0), isTrue);
    client = McpTestClient(server.url!, server.token);
    initialize = await client.handshake();
  });

  tearDown(() async {
    client.close();
    await server.stop();
    await vm.close();
    await deleteTempProject(root);
  });

  String fileText(String relative) =>
      LuminaGuide.stripFrontMatter(File('${skillDir.path}/$relative').readAsStringSync());

  test('no topic: the overview without front matter, then every topic with its title and how to ask for one', () async {
    final reply = await client.callTool('get_lumina_guide');
    expect(reply.isError, isFalse, reason: reply.text);
    final text = reply.text;
    expect(text, startsWith('# Lumina engine guide'));
    expect(text, isNot(contains('name: lumina-engine')), reason: 'front matter stripped');
    expect(text, contains(fileText('SKILL.md')));
    for (final t in LuminaGuide.topics) {
      expect(text, contains('- `${t.id}`: ${t.title}'));
    }
    expect(text, contains('get_lumina_guide'));
    expect(text, contains('lumina://guide/<topic>'));
  });

  test('each topic returns exactly its reference file; an unknown topic is refused with the topic list', () async {
    for (final t in LuminaGuide.topics) {
      final reply = await client.callTool('get_lumina_guide', {'topic': t.id});
      expect(reply.isError, isFalse, reason: '${t.id}: ${reply.text}');
      expect(reply.text, fileText('reference/${t.id}.md'), reason: t.id);
    }
    // The schema's enum refuses it before the handler runs, listing the topics.
    await expectLater(
      client.callTool('get_lumina_guide', {'topic': 'teleporters'}),
      throwsA(
        isA<McpRpcError>().having(
          (e) => e.message,
          'message',
          allOf(contains('"topic"'), contains('blueprints'), contains('filament-materials')),
        ),
      ),
    );
  });

  test('the filament-materials topic is served: blocks, prepareMaterial, the upstream page and its licence', () async {
    final reply = await client.callTool('get_lumina_guide', {'topic': 'filament-materials'});
    expect(reply.isError, isFalse, reason: reply.text);
    expect(reply.text, contains('material {'));
    expect(reply.text, contains('fragment {'));
    expect(reply.text, contains('prepareMaterial(material)'));
    expect(reply.text, contains('https://google.github.io/filament/main/materials.html'));
    expect(reply.text, contains('Apache License 2.0'));
  });

  test('read-only, in core: a ?groups=level session lists it, and it answers while Play runs', () async {
    final tool = server.tools.byName('get_lumina_guide')!;
    expect(tool.risk, McpToolRisk.readOnly);
    expect(tool.groups, {McpToolGroups.core});
    expect((await client.listTools(groups: ['level'])).map((t) => t['name']), contains('get_lumina_guide'));
    expect((await client.listTools(groups: ['umg'])).map((t) => t['name']), contains('get_lumina_guide'));
    // Play running: the editor's flag and the frozen undo stack start_pie sets.
    vm.startSimulation();
    vm.transactions.isFrozen = true;
    try {
      expect(vm.isPlaying, isTrue);
      final reply = await client.callTool('get_lumina_guide', {'topic': 'play-testing'});
      expect(reply.isError, isFalse, reason: reply.text);
    } finally {
      vm.transactions.isFrozen = false;
      vm.stopSimulation();
    }
  });

  test(
    'resources: lumina://guide and one per topic, the same text as the tool; a template; unknown is invalid',
    () async {
      final resources = ((await client.request('resources/list'))['resources'] as List).cast<Map>();
      final uris = resources.map((r) => r['uri']).toList();
      expect(uris, contains('lumina://guide'));
      for (final t in LuminaGuide.topics) {
        expect(uris, contains('lumina://guide/${t.id}'));
      }
      Future<String> read(String uri) async {
        final contents = ((await client.request('resources/read', {'uri': uri}))['contents'] as List).single as Map;
        expect(contents['mimeType'], 'text/markdown');
        expect(contents['uri'], uri);
        return contents['text'] as String;
      }

      expect(await read('lumina://guide'), (await client.callTool('get_lumina_guide')).text);
      expect(await read('lumina://guide/input'), (await client.callTool('get_lumina_guide', {'topic': 'input'})).text);
      final templates = ((await client.request('resources/templates/list'))['resourceTemplates'] as List).cast<Map>();
      expect(templates.map((t) => t['uriTemplate']), contains('lumina://guide/{topic}'));
      await expectLater(
        client.request('resources/read', {'uri': 'lumina://guide/nope'}),
        throwsA(isA<McpRpcError>().having((e) => e.message, 'message', contains('camera-spring-arm'))),
      );
    },
  );

  test('as a project editor host dependency (assets keyed packages/lumina_ui/…), the guide still loads', () async {
    // A generated host app depends on lumina_ui, so Flutter bundles its assets
    // under `packages/lumina_ui/`. Serve the asset channel that way: only the
    // packaged keys exist, read from this package's files on disk.
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final requested = <String>[];
    messenger.setMockMessageHandler('flutter/assets', (message) async {
      final key = Uri.decodeFull(utf8.decode(message!.buffer.asUint8List(message.offsetInBytes, message.lengthInBytes)));
      requested.add(key);
      if (!key.startsWith(EditorAssets.packagePrefix)) return null;
      final file = File('${Directory.current.path}/${key.substring(EditorAssets.packagePrefix.length)}');
      if (!file.existsSync()) return null;
      final bytes = file.readAsBytesSync();
      return ByteData.sublistView(bytes);
    });
    final wasPackaged = EditorAssets.packaged;
    EditorAssets.packaged = true;
    addTearDown(() {
      EditorAssets.packaged = wasPackaged;
      messenger.setMockMessageHandler('flutter/assets', null);
    });

    final guide = LuminaGuide();
    expect(await guide.topic('blueprints'), fileText('reference/blueprints.md'));
    expect(await guide.topic('project-layout'), fileText('reference/project-layout.md'));
    expect(await guide.overview(), startsWith(fileText('SKILL.md')));
    expect(requested, everyElement(startsWith(EditorAssets.packagePrefix)));
  });

  test('a tool that throws: the caller gets the exception message only, the stack goes to the Output Log', () async {
    server.tools.register(
      McpTool(
        name: 'throwing_probe',
        risk: McpToolRisk.readOnly,
        groups: const {McpToolGroups.core},
        title: 'Throwing probe',
        description: 'Throws.',
        inputSchema: McpSchema.object({}),
        handler: (_) async => throw StateError('the probe broke'),
      ),
    );
    final reply = await client.callTool('throwing_probe');
    expect(reply.isError, isTrue);
    expect(reply.text, 'throwing_probe failed: Bad state: the probe broke');
    expect(reply.text, isNot(contains('#0')));
    expect(reply.text, isNot(contains('.dart')));
    final logged = vm.logger.logs.where((l) => l.message.contains('throwing_probe failed: Bad state: the probe broke'));
    expect(logged, isNotEmpty, reason: 'the failure is in the Output Log');
    expect(logged.first.level, 'error');
    expect(logged.first.message, contains('#0'), reason: 'with its stack trace');
  });

  test('the initialize instructions tell clients to read a topic with get_lumina_guide', () {
    expect(initialize['instructions'], contains('get_lumina_guide'));
  });

  test('bundle: topics = reference files, the pubspec ships the folder, sizes stay small', () {
    final files = skillDir.childFiles('reference').map((f) => f.uri.pathSegments.last.replaceAll('.md', '')).toSet();
    expect(
      files,
      LuminaGuide.topicIds,
      reason: 'LuminaGuide.topics and skills/lumina-engine/reference/*.md must match',
    );
    final pubspec = File('${Directory.current.path}/pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('- skills/lumina-engine/\n'));
    expect(pubspec, contains('- skills/lumina-engine/reference/\n'));
    expect(fileText('SKILL.md').length, lessThanOrEqualTo(4000));
    for (final id in LuminaGuide.topicIds) {
      expect(fileText('reference/$id.md').length, lessThanOrEqualTo(12000), reason: id);
    }
  });

  test('every snake_case name the guide cites is a tool, a tool argument, a node id or a pin id', () {
    final tools = server.tools.tools;
    final known = <String>{for (final t in tools) t.name};
    void props(Object? schema) {
      if (schema is Map) {
        final p = schema['properties'];
        if (p is Map) {
          for (final e in p.entries) {
            known.add(e.key as String);
            props(e.value);
          }
        }
        props(schema['items']);
        final values = schema['enum'];
        if (values is List) known.addAll(values.whereType<String>());
      } else if (schema is List) {
        schema.forEach(props);
      }
    }

    for (final t in tools) {
      props(t.inputSchema);
    }
    for (final spec in LuminaBlueprintNodeLibrary.all) {
      known.add(spec.id);
      for (final pin in [...spec.inputs, ...spec.outputs]) {
        known.add(pin.id);
      }
    }
    // The material expression catalog `list_material_nodes` serves.
    for (final spec in MaterialNodes.all) {
      known.add(spec.id);
      for (final pin in [...spec.inputs, ...spec.outputs]) {
        known.add(pin.id);
      }
    }
    // Names the guide cites that are neither: pie_sequence step fields, the
    // node settings `add_blueprint_node` takes in `literals`, and manifest keys.
    known.addAll(const [
      'play_ms', 'hold_ms', 'hold_frames', 'advance_frames', 'mouse_move', 'player_moved', 'min_distance_cm', //
      'log_contains', 'maps_and_modes', 'accepted_game_modes', 'material_slots', 'node_id', 'user_index',
      // set_actor_property's actor properties and a Maps & Modes key (named in descriptions), .lmas JSON keys.
      'light_intensity', 'light_color', 'default_pawn_class', 'asset_id', 'raw_payload',
      // A node-setting key the pitfalls topic says never to use.
      'widget_id',
    ]);
    final cited = RegExp(r'`([a-z][a-z0-9]*(?:_[a-z0-9]+)+)`');
    final unknown = <String>{};
    for (final f in [File('${skillDir.path}/SKILL.md'), ...skillDir.childFiles('reference')]) {
      for (final m in cited.allMatches(f.readAsStringSync())) {
        if (!known.contains(m.group(1))) unknown.add('${f.uri.pathSegments.last}: ${m.group(1)}');
      }
    }
    expect(unknown, isEmpty, reason: 'names in the guide that no tool, argument, node or pin has');
  });
}

extension on Directory {
  List<File> childFiles(String sub) =>
      Directory('$path/$sub').listSync().whereType<File>().where((f) => f.path.endsWith('.md')).toList();
}
