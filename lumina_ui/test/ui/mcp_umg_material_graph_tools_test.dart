import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_server_service.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_server_settings.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/material_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/umg_editor_view_model.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' show ShadcnApp, Size, SizedBox;

import '../helpers/mcp_test_client.dart';
import '../helpers/temp_project.dart';

/// The UMG designer and the material node graph as MCP tools,
/// through a real JSON-RPC-over-HTTP client against a real temp project: a
/// Widget Blueprint laid out, wired and compiled to Dart with the real
/// codegen; a material authored as nodes whose regenerated `.mat` source the
/// real filamat compiler takes; the barrel's texture imported through the
/// real pipeline and bound to an Image and to a sampler.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late Directory projectDir;
  late EditorViewModel vm;
  late McpServerService server;
  late McpTestClient client;

  const hud = 'contents/widgets/WBP_AgentHud.lmas';
  const mat = 'contents/materials/M_AgentGraph.lmas';
  final barrel = File('${Directory.current.parent.path}/test-assets/Props/Barrels/fuel_barrel_red.glb');

  Future<void> boot({String widgetLibrary = kUmgWidgetLibraryShadcn}) async {
    root = Directory.systemTemp.createTempSync('lumina_mcp_umg_mat_');
    final configDir = Directory('${root.path}/config')..createSync();
    projectDir = Directory('${root.path}/AgentHud')..createSync();
    final project = LuminaProject(
      projectName: 'AgentHud',
      activeLevel: 'contents/levels/L_Main.lmas',
      ui: ProjectUiSettings(widgetLibrary: widgetLibrary),
    );
    File('${projectDir.path}/AgentHud.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
    Directory('${projectDir.path}/contents/levels').createSync(recursive: true);
    Directory('${projectDir.path}/lib').createSync(recursive: true);
    vm = EditorViewModel(initialProject: project, projectLocation: root.path, enableTimers: false, autoInitAssets: false);
    server = McpServerService(vm, configDir: configDir, settings: McpServerSettings.load(configDir: configDir));
    expect(await server.start(port: 0), isTrue);
    client = McpTestClient(server.url!, server.token);
    await client.handshake();
  }

  Future<void> shutdown() async {
    client.close();
    await server.stop();
    await vm.close();
    await deleteTempProject(root);
  }

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

  /// The barrel's imported texture, project-relative.
  Future<String?> barrelTexture() async {
    if (!barrel.existsSync()) return null;
    final imported = (await ok('import_asset', {'path': barrel.path}))['imported'] as List;
    final texture = imported.cast<Map>().where((a) => a['type'] == 'texture').firstOrNull;
    expect(texture, isNotNull, reason: 'the barrel GLB carries a texture: $imported');
    return texture!['path'] as String;
  }

  UmgEditorViewModel widgetVm() => vm.editorSessionFor('${vm.projectDirPath}/$hud') as UmgEditorViewModel;
  MaterialEditorViewModel materialVm() => vm.editorSessionFor('${vm.projectDirPath}/$mat') as MaterialEditorViewModel;

  Map<String, Object?> findWidget(Map<String, Object?> node, String name) =>
      findWidgetOrNull(node, name) ?? (throw StateError('no widget $name'));

  group('UMG tools', () {
    setUp(() async {
      await boot();
      await ok('create_asset', {'type': 'widget', 'name': 'WBP_AgentHud'});
    });
    tearDown(shutdown);

    test('list_widget_types: capacities, slot kinds, default props, events, the shadcn requirement, by category', () async {
      final all = await ok('list_widget_types');
      expect(all['widget_library'], kUmgWidgetLibraryShadcn);
      final types = {for (final t in (all['types'] as List).cast<Map>()) t['id']: t};
      expect(types['canvasPanel'], allOf(containsPair('capacity', 'many'), containsPair('child_slot_kind', 'canvas')));
      expect(types['text']!['default_props'], allOf(containsPair('text', 'Text Block'), containsPair('fontSize', 16.0)));
      expect(types['button']!['events'], contains('OnClicked'));
      expect(types['shadcnPrimaryButton'], containsPair('requires_widget_library', 'shadcn'));
      expect(types['text']!.containsKey('requires_widget_library'), isFalse);
      final panels = (await ok('list_widget_types', {'category': 'panels'}))['types'] as List;
      expect(panels, isNotEmpty);
      expect(panels.every((t) => (t as Map)['category'] == 'panels'), isTrue);
    });

    test('lay out a HUD: add, props, canvas position, reorder; refusals; slots; props; rename collision; undo', () async {
      var tree = await ok('get_widget_tree', {'asset': hud});
      final rootId = (tree['root'] as Map)['id'] as String;
      expect(tree['mode'], 'designer');
      expect(tree['is_dirty'], isFalse);

      final box = await ok('add_widget', {'asset': hud, 'type': 'verticalBox', 'parent': rootId, 'x': 40, 'y': 40, 'name': 'StatsBox'});
      final boxId = (box['widget'] as Map)['id'] as String;
      await ok('add_widget', {'asset': hud, 'type': 'text', 'parent': 'StatsBox', 'name': 'HealthLabel', 'props': {'text': 'Health', 'fontSize': 24}});
      await ok('add_widget', {'asset': hud, 'type': 'progressBar', 'parent': boxId, 'name': 'HealthBar', 'props': {'percent': 0.75}});
      tree = await ok('get_widget_tree', {'asset': hud});
      var stats = findWidget(tree['root'] as Map<String, Object?>, 'StatsBox');
      expect([for (final c in (stats['children'] as List).cast<Map>()) c['name']], ['HealthLabel', 'HealthBar']);
      expect((stats['slot'] as Map)['position'], [40.0, 40.0]);
      expect((stats['slot'] as Map)['kind'], 'canvas');
      final label = findWidget(tree['root'] as Map<String, Object?>, 'HealthLabel');
      expect(label['props'], allOf(containsPair('text', 'Health'), containsPair('fontSize', 24.0)));
      expect((label['slot'] as Map).keys, isNot(contains('anchor_min')), reason: 'only the box slot fields');
      expect(findWidget(tree['root'] as Map<String, Object?>, 'HealthBar')['props'], containsPair('percent', 0.75));
      expect(tree['is_dirty'], isTrue);

      await ok('move_widget', {'asset': hud, 'widget': 'HealthBar', 'parent': 'StatsBox', 'index': 0});
      tree = await ok('get_widget_tree', {'asset': hud});
      stats = findWidget(tree['root'] as Map<String, Object?>, 'StatsBox');
      expect([for (final c in (stats['children'] as List).cast<Map>()) c['name']], ['HealthBar', 'HealthLabel']);

      // Refusals carry the designer's reasons.
      expect(await refused('add_widget', {'asset': hud, 'type': 'text', 'parent': 'HealthLabel'}), contains('cannot contain children'));
      await ok('add_widget', {'asset': hud, 'type': 'sizeBox', 'parent': rootId, 'name': 'Frame'});
      await ok('add_widget', {'asset': hud, 'type': 'text', 'parent': 'Frame'});
      expect(await refused('add_widget', {'asset': hud, 'type': 'text', 'parent': 'Frame'}), contains('exactly one child'));
      expect(await refused('remove_widget', {'asset': hud, 'widget': rootId}), contains('root'));

      // Slots: the canvas slot by preset, the box slot by padding and alignment.
      final slot = await ok('set_widget_slot', {
        'asset': hud,
        'widget': 'StatsBox',
        'anchor_preset': 'center',
        'size': [320, 120],
        'alignment': [0.5, 0.5],
      });
      final canvas = (slot['widget'] as Map)['slot'] as Map;
      expect(canvas['anchor_min'], [0.5, 0.5]);
      expect(canvas['anchor_max'], [0.5, 0.5]);
      expect(canvas['size'], [320.0, 120.0]);
      expect(canvas['alignment'], [0.5, 0.5]);
      final boxSlot = await ok('set_widget_slot', {'asset': hud, 'widget': 'HealthLabel', 'padding': [4, 4, 4, 4], 'h_align': 'center'});
      expect((boxSlot['widget'] as Map)['slot'], allOf(containsPair('padding', [4.0, 4.0, 4.0, 4.0]), containsPair('h_align', 'center')));
      expect(await refused('set_widget_slot', {'asset': hud, 'widget': 'HealthLabel', 'anchor_preset': 'center'}), contains('box'));

      // Props: unknown keys list the valid ones; a texture binds through bindTexture.
      expect(await refused('set_widget_properties', {'asset': hud, 'widget': 'HealthLabel', 'props': {'fontsize': 30}}), contains('fontSize'));
      expect(await refused('rename_widget', {'asset': hud, 'widget': 'HealthBar', 'name': 'HealthLabel'}),
          allOf(contains('field'), contains('"healthLabel"')));

      // One MCP step per call on the widget tab's own stack; undo takes the
      // add back together with its props.
      final editor = widgetVm();
      expect(editor.transactions.undoLabel, 'Undo MCP: Edit Slot HealthLabel');
      final history = editor.transactions.history().map((h) => h.label).toList();
      expect(history, contains('MCP: Add Text (+3)'), reason: 'add, rename and two props: $history');
      expect(history.every((l) => l.startsWith('MCP: ')), isTrue, reason: '$history');
      await ok('add_widget', {'asset': hud, 'type': 'text', 'parent': 'StatsBox', 'props': {'text': 'Armor', 'fontSize': 18}});
      expect(editor.transactions.undoLabel, 'Undo MCP: Add Text (+2)');
      final count = editor.document.allNodes.length;
      final undone = await ok('undo', {'asset': hud});
      expect(undone['undone'], 'Undo MCP: Add Text (+2)');
      expect(editor.document.allNodes.length, count - 1);
      expect(editor.document.allNodes.any((n) => n.props['text'] == 'Armor'), isFalse);
    });

    test('an image shows the barrel texture: props.texture is its path and the saved .lmas references it', () async {
      final texture = await barrelTexture();
      if (texture == null) {
        markTestSkipped('test-assets not present');
        return;
      }
      final root = ((await ok('get_widget_tree', {'asset': hud}))['root'] as Map)['id'];
      await ok('add_widget', {'asset': hud, 'type': 'image', 'parent': root, 'name': 'BarrelIcon', 'x': 400, 'y': 40});
      final set = await ok('set_widget_properties', {'asset': hud, 'widget': 'BarrelIcon', 'props': {'texture': texture}});
      expect(((set['widget'] as Map)['props'] as Map)['texture'], texture);
      final saved = await ok('save_widget', {'asset': hud});
      expect(saved['is_dirty'], isFalse);
      final onDisk = LuminaAsset.fromBytes(File('${vm.projectDirPath}/$hud').readAsBytesSync());
      expect(onDisk.references.map((r) => r.assetPath), contains(texture));
      expect(await refused('set_widget_properties', {'asset': hud, 'widget': 'BarrelIcon', 'props': {'texture': 'contents/nope.lmas'}}),
          contains('nope'));
    });

    test('bind OnClicked, wire it with the Blueprint tools, compile to Dart; the saved widget reopens with it all', () async {
      final root = ((await ok('get_widget_tree', {'asset': hud}))['root'] as Map)['id'];
      await ok('add_widget', {'asset': hud, 'type': 'verticalBox', 'parent': root, 'x': 40, 'y': 40, 'name': 'StatsBox'});
      await ok('add_widget', {'asset': hud, 'type': 'text', 'parent': 'StatsBox', 'name': 'HealthLabel', 'props': {'text': 'Health'}});
      await ok('add_widget', {'asset': hud, 'type': 'progressBar', 'parent': 'StatsBox', 'name': 'HealthBar'});
      await ok('add_widget', {'asset': hud, 'type': 'button', 'parent': root, 'name': 'HealButton', 'x': 40, 'y': 200});
      final bound = await ok('bind_widget_event', {'asset': hud, 'widget': 'HealButton', 'event': 'OnClicked'});
      final eventNode = bound['node_id'] as String;
      expect(bound['exec_pin'], 'exec_out');
      expect(await refused('bind_widget_event', {'asset': hud, 'widget': 'HealButton', 'event': 'OnTeleport'}), contains('OnClicked'));

      final printNode = ((await ok('add_blueprint_node', {'asset': hud, 'node': 'print_string', 'x': 400, 'y': 120}))['node'] as Map)['id'];
      await ok('connect_blueprint_pins', {'asset': hud, 'from_node': eventNode, 'from_pin': 'exec_out', 'to_node': printNode, 'to_pin': 'exec_in'});
      await ok('set_blueprint_pin_literal', {'asset': hud, 'node': printNode, 'pin': 'in_string', 'value': 'healed via mcp'});
      final editor = widgetVm();
      expect(editor.graphEditor.transactions.undoLabel, startsWith('Undo MCP: '));

      // stack "graph" reverts the last graph edit only.
      await ok('undo', {'asset': hud, 'stack': 'graph'});
      expect(editor.graphEditor.getGraphNode(printNode as String)!.literals['in_string'], isNot('healed via mcp'));
      await ok('redo', {'asset': hud, 'stack': 'graph'});
      expect(editor.graphEditor.getGraphNode(printNode)!.literals['in_string'], 'healed via mcp');

      final compiled = await ok('compile_widget', {'asset': hud});
      expect(compiled['ok'], isTrue, reason: '$compiled');
      final dart = File('${vm.projectDirPath}/lib/widgets/wbp_agent_hud.dart');
      expect(compiled['file_path'], dart.path);
      expect(dart.existsSync(), isTrue);
      expect(dart.readAsStringSync(), allOf(contains('Health'), contains('healed via mcp')));

      final reopened = UmgEditorViewModel(assetPath: '${vm.projectDirPath}/$hud', projectDirPathOverride: vm.projectDirPath);
      addTearDown(reopened.dispose);
      await reopened.load();
      final top = reopened.document.root.children.map((n) => n.name).toList();
      expect(top, containsAll(['StatsBox', 'HealButton']));
      final stats = reopened.document.root.children.firstWhere((n) => n.name == 'StatsBox');
      expect(stats.children.map((n) => n.name), containsAll(['HealthLabel', 'HealthBar']));
      expect(
        reopened.document.blueprint!.eventGraph.nodes.any((n) =>
            n.registryId == LuminaBlueprintNodeLibrary.eventWidgetElement &&
            n.literals['element'] == 'HealButton' &&
            n.literals['event'] == 'OnClicked'),
        isTrue,
      );
    });
  });

  group('UMG on the flutter widget library', () {
    setUp(() => boot(widgetLibrary: kUmgWidgetLibraryFlutter));
    tearDown(shutdown);

    test('add_blueprint_node names the element and class settings; a Get <Element> placed with them compiles', () async {
      final tools = {for (final t in await client.listTools()) t['name']: t};
      final description = tools['add_blueprint_node']!['description'] as String;
      expect(description, allOf(contains('"element"'), contains('"class"'), contains('WidgetElement:text')));

      await ok('create_asset', {'type': 'widget', 'name': 'WBP_AgentHud'});
      final root = ((await ok('get_widget_tree', {'asset': hud}))['root'] as Map)['id'];
      await ok('add_widget', {'asset': hud, 'type': 'text', 'parent': root, 'name': 'ScoreText', 'x': 40, 'y': 30});
      final event = ((await ok('add_blueprint_node', {'asset': hud, 'node': 'event_widget_construct', 'x': 0, 'y': 0}))['node'] as Map)['id'];
      final get = (await ok('add_blueprint_node', {
        'asset': hud, 'node': 'get_widget_variable', 'x': 0, 'y': 200, 'literals': {'element': 'ScoreText'},
      }))['node'] as Map;
      expect(get['title'], 'ScoreText');
      final set = ((await ok('add_blueprint_node', {'asset': hud, 'node': 'set_element_text', 'x': 300, 'y': 0, 'literals': {'in_text': 'Score: 0'}}))['node'] as Map)['id'];
      await ok('connect_blueprint_pins', {'asset': hud, 'from_node': event, 'from_pin': 'exec_out', 'to_node': set, 'to_pin': 'exec_in'});
      await ok('connect_blueprint_pins', {'asset': hud, 'from_node': get['id'], 'from_pin': 'return_value', 'to_node': set, 'to_pin': 'target'});
      final compiled = await ok('compile_widget', {'asset': hud});
      expect(compiled['ok'], isTrue, reason: '$compiled');
    });

    test('a shadcn button fails compile_widget with the validator error and writes no Dart file', () async {
      await ok('create_asset', {'type': 'widget', 'name': 'WBP_AgentHud'});
      final root = ((await ok('get_widget_tree', {'asset': hud}))['root'] as Map)['id'];
      await ok('add_widget', {'asset': hud, 'type': 'shadcnPrimaryButton', 'parent': root, 'name': 'Fancy'});
      final reply = await client.callTool('compile_widget', {'asset': hud});
      expect(reply.isError, isTrue);
      expect(reply.data['ok'], isFalse);
      expect((reply.data['errors'] as List).join('\n'), contains('shadcn'));
      expect((reply.data['validation_errors'] as List), isNotEmpty);
      expect(File('${vm.projectDirPath}/lib/widgets/wbp_agent_hud.dart').existsSync(), isFalse);
    });
  });

  group('material graph tools', () {
    setUp(() async {
      await boot();
      await ok('create_asset', {'type': 'filamat', 'name': 'M_AgentGraph'});
    });
    tearDown(shutdown);

    Map<String, Object?> nodeOf(Map<String, Object?> graph, String id) =>
        (graph['nodes'] as List).cast<Map<String, Object?>>().firstWhere((n) => n['id'] == id);
    Map<String, Object?>? wireInto(Map<String, Object?> graph, String node, String pin) => (graph['wires'] as List)
        .cast<Map<String, Object?>>()
        .where((w) => w['to_node'] == node && w['to_pin'] == pin)
        .firstOrNull;

    test('list_material_nodes has typed pins and no output node; the default material graph is in sync', () async {
      final listed = await ok('list_material_nodes');
      final nodes = {for (final n in (listed['nodes'] as List).cast<Map>()) n['id']: n};
      expect(nodes.keys, containsAll(['mat_scalar_parameter', 'mat_texture_sample', 'mat_lerp']));
      expect(nodes.keys, isNot(contains('mat_output')));
      expect(nodes.keys, isNot(contains('mat_custom_fragment')));
      expect((nodes['mat_scalar_parameter']!['outputs'] as List).first, containsPair('type', 'float'));
      expect((nodes['mat_texture_sample']!['inputs'] as List).cast<Map>().map((p) => p['type']), contains('Texture2D'));
      final params = (await ok('list_material_nodes', {'category': 'Parameters'}))['nodes'] as List;
      expect(params.every((n) => (n as Map)['category'] == 'Parameters'), isTrue);
      expect((await ok('list_material_nodes', {'query': 'lerp'}))['nodes'], isNotEmpty);

      final graph = await ok('get_material_graph', {'asset': mat});
      expect(graph['nodes'] as List, anyElement(containsPair('id', 'material_output')));
      expect((graph['sync'] as Map)['ahead'], isFalse);
      expect((graph['output_pins'] as List).cast<Map>().firstWhere((p) => p['id'] == 'roughness')['used'], isTrue);
      expect(await refused('add_material_node', {'asset': mat, 'node': 'mat_output', 'x': 0, 'y': 0}), contains('mat_output'));
      expect(await refused('remove_material_node', {'asset': mat, 'node': 'material_output'}), contains('output'));
    });

    test('a scalar parameter wired to roughness regenerates the source; graph undo restores graph and source', () async {
      final before = (await ok('get_material_source', {'asset': mat}))['source'] as String;
      final added = await ok('add_material_node', {
        'asset': mat,
        'node': 'mat_scalar_parameter',
        'x': -300,
        'y': 200,
        'settings': {'name': 'AgentRoughness', 'default': 0.35},
      });
      final nodeId = (added['node'] as Map)['id'] as String;
      final wired = await ok('connect_material_pins', {
        'asset': mat,
        'from_node': nodeId,
        'from_pin': 'out',
        'to_node': 'material_output',
        'to_pin': 'roughness',
      });
      expect((wired['sync'] as Map)['ahead'], isFalse);
      final source = (await ok('get_material_source', {'asset': mat}))['source'] as String;
      expect(source, contains('AgentRoughness'));
      expect(source, contains('material.roughness = materialParams.AgentRoughness'));

      final editor = materialVm();
      expect(editor.graph.transactions.undoLabel, 'Undo MCP: Connect pins');
      expect(editor.graph.transactions.history().map((h) => h.label).take(2), ['MCP: Connect pins', 'MCP: Add ScalarParameter']);

      final compiled = await client.callTool('compile_material', {'asset': mat});
      expect(compiled.data['ok'], isTrue, reason: compiled.text);

      await ok('undo', {'asset': mat, 'stack': 'graph'});
      await ok('undo', {'asset': mat, 'stack': 'graph'});
      expect((await ok('get_material_source', {'asset': mat}))['source'], before);
      final graph = await ok('get_material_graph', {'asset': mat});
      expect((graph['nodes'] as List).cast<Map>().any((n) => n['id'] == nodeId), isFalse);
    });

    test('set_material_source reparses into the graph; undo without stack reverts the source, not the graph', () async {
      final source = (await ok('get_material_source', {'asset': mat}))['source'] as String;
      final fragment = source.substring(0, source.indexOf('fragment {'));
      final edited = '${fragment}fragment {\n    void material(inout MaterialInputs material) {\n        prepareMaterial(material);\n'
          '        material.baseColor = vec4(0.8, 0.2, 0.1, 1.0);\n    }\n}\n';
      await ok('set_material_source', {'asset': mat, 'source': edited});
      var graph = await ok('get_material_graph', {'asset': mat});
      final wire = wireInto(graph, 'material_output', 'base_color');
      expect(wire, isNotNull, reason: '${graph['wires']}');
      final constant = nodeOf(graph, wire!['from_node'] as String);
      expect(constant['node'], 'mat_constant4');

      // A graph edit on top, reverted on the graph stack; the source stack
      // then reverts set_material_source.
      final half = await ok('add_material_node', {'asset': mat, 'node': 'mat_constant', 'x': -200, 'y': 400, 'settings': {'value': 0.5}});
      await ok('connect_material_pins', {
        'asset': mat,
        'from_node': (half['node'] as Map)['id'],
        'from_pin': 'out',
        'to_node': 'material_output',
        'to_pin': 'metallic',
      });
      await ok('undo', {'asset': mat, 'stack': 'graph'});
      await ok('undo', {'asset': mat, 'stack': 'graph'});
      expect(materialVm().currentCode, edited);
      final undone = await ok('undo', {'asset': mat});
      expect(undone['undone'], 'Undo MCP: Set Material Source');
      expect(materialVm().currentCode, source);
      graph = await ok('get_material_graph', {'asset': mat});
      expect((graph['sync'] as Map)['ahead'], isFalse);
    });

    test('a float2 into base_color is accepted but keeps the graph ahead; a Texture2D into base_color is refused', () async {
      final uv = ((await ok('add_material_node', {'asset': mat, 'node': 'mat_texture_coordinate', 'x': -400, 'y': 0}))['node'] as Map)['id'];
      final wired = await ok('connect_material_pins', {
        'asset': mat,
        'from_node': uv,
        'from_pin': 'out',
        'to_node': 'material_output',
        'to_pin': 'base_color',
      });
      expect((wired['sync'] as Map)['ahead'], isTrue);
      final issue = (wired['diagnostics'] as List).cast<Map>().firstWhere(
          (d) => d['severity'] == 'error' && (d['node_id'] == uv || d['node_id'] == 'material_output'),
          orElse: () => fail('no diagnostic names the node: ${wired['diagnostics']}'));
      final compiled = await client.callTool('compile_material', {'asset': mat});
      expect(compiled.isError, isTrue);
      expect(compiled.data['ok'], isFalse);
      expect((compiled.data['issues'] as List).cast<Map>().map((i) => i['message']), contains(issue['message']));
      final removed = await ok('remove_material_wire', {'asset': mat, 'wire': (wired['wire'] as Map)['id']});
      expect((removed['sync'] as Map)['ahead'], isFalse);

      final tex = ((await ok('add_material_node', {'asset': mat, 'node': 'mat_texture_parameter', 'x': -400, 'y': 200}))['node'] as Map)['id'];
      expect(
        await refused('connect_material_pins', {'asset': mat, 'from_node': tex, 'from_pin': 'tex', 'to_node': 'material_output', 'to_pin': 'base_color'}),
        contains('A Texture2D goes into a TextureSample\'s Tex input'),
      );
    });

    test('parameter values, a sampler texture binding and the header settings', () async {
      final texture = await barrelTexture();
      final added = await ok('add_material_node', {
        'asset': mat,
        'node': 'mat_scalar_parameter',
        'x': -300,
        'y': 200,
        'settings': {'name': 'AgentRoughness', 'default': 0.35},
      });
      await ok('connect_material_pins', {
        'asset': mat,
        'from_node': (added['node'] as Map)['id'],
        'from_pin': 'out',
        'to_node': 'material_output',
        'to_pin': 'roughness',
      });
      final set = await ok('set_material_parameter', {'asset': mat, 'name': 'AgentRoughness', 'value': 0.8});
      expect(set['is_dirty'], isTrue);
      final params = (await ok('get_material_source', {'asset': mat}))['parameters'] as Map;
      expect((params['AgentRoughness'] as Map)['value'], 0.8);
      expect(await refused('set_material_parameter', {'asset': mat, 'name': 'AgentRoughness', 'value': [1, 0]}), contains('float'));
      expect(await refused('set_material_parameter', {'asset': mat, 'name': 'albedoMap', 'value': 1}), contains('set_material_texture'));

      if (texture != null) {
        final editor = materialVm();
        final depth = editor.graph.transactions.history().length;
        final bound = await ok('set_material_texture', {'asset': mat, 'parameter': 'albedoMap', 'texture': texture});
        expect(bound['texture'], texture);
        final after = (await ok('get_material_source', {'asset': mat}))['parameters'] as Map;
        expect((after['albedoMap'] as Map)['texture'], texture);
        expect(editor.graph.transactions.history().length, depth + 1);
        expect(editor.graph.transactions.undoLabel, 'Undo MCP: Set albedoMap texture');
        await ok('set_material_texture', {'asset': mat, 'parameter': 'albedoMap'});
        expect(((await ok('get_material_source', {'asset': mat}))['parameters'] as Map)['albedoMap'], containsPair('texture', null));
      }

      await ok('set_material_settings', {'asset': mat, 'shading_model': 'unlit'});
      expect((await ok('get_material_source', {'asset': mat}))['source'], contains('shadingModel : unlit'));
      final graph = await ok('get_material_graph', {'asset': mat});
      expect((graph['output_pins'] as List).cast<Map>().firstWhere((p) => p['id'] == 'roughness')['used'], isFalse);
    });

    test('a world-height tint handed from the vertex stage through a variable: nodes, source, compile', () async {
      Future<String> add(String node, double x, double y, [Map<String, Object?>? settings]) async =>
          ((await ok('add_material_node', {'asset': mat, 'node': node, 'x': x, 'y': y, 'settings': ?settings}))['node']
              as Map)['id'] as String;
      Future<Map<String, Object?>> connect(String from, String fromPin, String to, String toPin) => ok(
          'connect_material_pins', {'asset': mat, 'from_node': from, 'from_pin': fromPin, 'to_node': to, 'to_pin': toPin});

      final listed = (await ok('list_material_nodes', {'category': 'Vertex'}))['nodes'] as List;
      expect(listed.cast<Map>().map((n) => n['id']), containsAll(['mat_set_vertex_variable', 'mat_vertex_variable']));

      final world = await add('mat_world_position', -900, 400);
      final low = await add('mat_constant3', -900, 520, {'value': [0.1, 0.3, 1.0]});
      final high = await add('mat_constant3', -900, 640, {'value': [1.0, 0.45, 0.1]});
      final mask = await add('mat_component_mask', -700, 400, {'r': false, 'g': true, 'b': false, 'a': false});
      final lerp = await add('mat_lerp', -500, 500);
      final setter = await add('mat_set_vertex_variable', -300, 500, {'name': 'heightTint'});
      await connect(world, 'out', mask, 'in');
      await connect(low, 'out', lerp, 'a');
      await connect(high, 'out', lerp, 'b');
      await connect(mask, 'out', lerp, 'alpha');
      await connect(lerp, 'out', setter, 'value');
      final reader = await add('mat_vertex_variable', -300, 100);
      final wired = await connect(reader, 'rgb', 'material_output', 'base_color');
      expect((wired['sync'] as Map)['ahead'], isFalse, reason: '${wired['diagnostics']}');

      final graph = await ok('get_material_graph', {'asset': mat});
      expect(graph['vertex_block'], 'graph');
      expect(graph['variables'], [
        {'name': 'heightTint', 'set_by': [setter], 'read_by': [reader]},
      ]);
      expect(nodeOf(graph, reader)['settings'], containsPair('name', 'heightTint'), reason: 'reads the first variable');
      final source = (await ok('get_material_source', {'asset': mat}))['source'] as String;
      expect(source, contains('heightTint'));
      expect(source, contains('void materialVertex(inout MaterialVertexInputs material)'));
      expect(source, contains('mulMat4x4Float3(getUserWorldFromWorldMatrix(), material.worldPosition.xyz).xyz.g'));
      expect(source, contains('variable_heightTint.rgb'));
      final compiled = await client.callTool('compile_material', {'asset': mat});
      expect(compiled.data['ok'], isTrue, reason: compiled.text);

      // A texture sample cannot run per vertex: the wire is taken, reported,
      // and the source is not rewritten.
      final tex = await add('mat_texture_sample', -900, 800, {'parameter': 'albedoMap'});
      final bad = await connect(tex, 'r', lerp, 'alpha');
      expect((bad['sync'] as Map)['ahead'], isTrue);
      expect((bad['diagnostics'] as List).cast<Map>().map((d) => d['message']).join('\n'),
          contains('not available in the vertex stage'));
      await ok('undo', {'asset': mat, 'stack': 'graph'});
      expect(((await ok('get_material_graph', {'asset': mat}))['sync'] as Map)['ahead'], isFalse);
    });

    test('the Logic nodes are listed and creatable: a Compare picks a roughness through an If, and compiles', () async {
      Future<String> add(String node, double x, double y, [Map<String, Object?>? settings]) async =>
          ((await ok('add_material_node', {'asset': mat, 'node': node, 'x': x, 'y': y, 'settings': ?settings}))['node']
              as Map)['id'] as String;
      Future<Map<String, Object?>> connect(String from, String fromPin, String to, String toPin) => ok(
          'connect_material_pins', {'asset': mat, 'from_node': from, 'from_pin': fromPin, 'to_node': to, 'to_pin': toPin});

      final listed = ((await ok('list_material_nodes', {'category': 'Logic'}))['nodes'] as List).cast<Map>();
      expect(listed.map((n) => n['id']), ['mat_compare', 'mat_and', 'mat_or', 'mat_not', 'mat_if']);
      final compareSpec = listed.firstWhere((n) => n['id'] == 'mat_compare');
      expect((compareSpec['outputs'] as List).cast<Map>().single['type'], 'bool');
      expect(compareSpec['settings'], {'op': '>='});

      final time = await add('mat_time', -700, 300);
      final cmp = await add('mat_compare', -500, 300, {'b': 2.0});
      final pick = await add('mat_if', -300, 300, {'then': 0.2, 'else': 0.8});
      await connect(time, 'out', cmp, 'a');
      await connect(cmp, 'out', pick, 'condition');
      final wired = await connect(pick, 'out', 'material_output', 'roughness');
      expect((wired['sync'] as Map)['ahead'], isFalse, reason: '${wired['diagnostics']}');
      await ok('set_material_node_setting', {'asset': mat, 'node': cmp, 'key': 'op', 'value': '<'});
      final source = (await ok('get_material_source', {'asset': mat}))['source'] as String;
      expect(source, contains('material.roughness = ((getUserTime().x < 2.0) ? 0.2 : 0.8);'));
      final compiled = await client.callTool('compile_material', {'asset': mat});
      expect(compiled.data['ok'], isTrue, reason: compiled.text);
    });
  });

  group('asset_editor_screenshot', () {
    setUp(() async {
      await boot();
      await ok('create_asset', {'type': 'widget', 'name': 'WBP_AgentHud'});
    });
    tearDown(shutdown);

    testWidgets('opens the widget tab and returns a real PNG of the designer', (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(vm.openTabs.length, 1, reason: 'no widget tab yet');

      /// The call runs on the real event loop while the test pumps frames.
      Future<McpToolReply> call(String tool, Map<String, Object?> args) async {
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

      final shot = await call('asset_editor_screenshot', {'asset': hud, 'max_width': 800});
      expect(shot.isError, isFalse, reason: shot.text);
      expect(vm.currentTab.category, 'Widget');
      final image = shot.content.firstWhere((c) => c['type'] == 'image');
      expect(image['mimeType'], 'image/png');
      final decoded = img.decodePng(base64Decode(image['data'] as String))!;
      expect(decoded.width, lessThanOrEqualTo(800));
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
      expect(varied, isTrue, reason: 'the designer frame is not one flat colour');
      expect(shot.text, contains('PNG of the Widget editor for $hud'));
      await drainRealIo(tester);
      await tester.pumpWidget(const SizedBox());
      await drainRealIo(tester);
    });
  });
}

Map<String, Object?>? findWidgetOrNull(Map<String, Object?> node, String name) {
  if (node['name'] == name) return node;
  for (final c in (node['children'] as List).cast<Map<String, Object?>>()) {
    final hit = findWidgetOrNull(c, name);
    if (hit != null) return hit;
  }
  return null;
}
