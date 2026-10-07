import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_server_service.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_server_settings.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/material_editor_view_model.dart';

import '../helpers/mcp_test_client.dart';
import '../helpers/temp_project.dart';

/// The asset, material and Blueprint tools over a real temp
/// project — a barrel imported from test-assets, a material compiled with
/// the real filamat compiler, a Blueprint authored node by node and
/// compiled to Dart — through a real JSON-RPC-over-HTTP client.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late Directory configDir;
  late EditorViewModel vm;
  late McpServerService server;
  late McpTestClient client;

  final barrel = File('${Directory.current.parent.path}/test-assets/Props/Barrels/fuel_barrel_red.glb');

  setUp(() async {
    root = Directory.systemTemp.createTempSync('lumina_mcp_assets_test_');
    configDir = Directory('${root.path}/config')..createSync();
    final projectDir = Directory('${root.path}/McpAssets')..createSync();
    const project = LuminaProject(projectName: 'McpAssets', activeLevel: 'contents/levels/L_Main.lmas');
    File('${projectDir.path}/McpAssets.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
    Directory('${projectDir.path}/contents/levels').createSync(recursive: true);
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
    // Wait for the source-control probe, then delete with a retry.
    await vm.close();
    await deleteTempProject(root);
  });

  group('asset tools', () {
    test('import_asset imports a barrel GLB and list_assets finds it by type, folder and query', () async {
      if (!barrel.existsSync()) {
        markTestSkipped('test-assets not present');
        return;
      }
      final imported = await client.callTool('import_asset', {'path': barrel.path});
      expect(imported.isError, isFalse, reason: imported.text);
      final created = (imported.data['imported'] as List).cast<Map>();
      expect(created.any((a) => a['type'] == 'filamesh' && (a['path'] as String).contains('fuel_barrel_red')), isTrue);
      expect(created.any((a) => (a['path'] as String).startsWith('contents/meshes/')), isTrue);
      for (final a in created) {
        expect(File('${vm.projectDirPath}/${a['path']}').existsSync(), isTrue, reason: '${a['path']}');
      }

      final meshes = (await client.callTool('list_assets', {'type': 'filamesh'})).data;
      expect((meshes['assets'] as List).every((a) => (a as Map)['type'] == 'filamesh'), isTrue);
      expect((meshes['count'] as int), greaterThanOrEqualTo(1));
      final byQuery = (await client.callTool('list_assets', {'query': 'BARREL'})).data;
      expect((byQuery['count'] as int), greaterThanOrEqualTo(1));
      final byFolder = (await client.callTool('list_assets', {'folder': 'meshes'})).data;
      expect((byFolder['assets'] as List).every((a) => ((a as Map)['path'] as String).startsWith('contents/meshes')), isTrue);
      final materials = (await client.callTool('list_assets', {'type': 'filamat'})).data;
      expect((materials['assets'] as List).every((a) => (a as Map)['type'] == 'filamat'), isTrue);

      final missing = await client.callTool('import_asset', {'path': '/nope.glb'});
      expect(missing.isError, isTrue);
      expect(missing.text, contains('/nope.glb'));
      final badType = await client.callTool('list_assets', {'type': 'teapot'});
      expect(badType.isError, isTrue);
      expect(badType.text, contains('filamesh'));
    });

    test('create_asset writes a material with the default source and a Blueprint with its parent class', () async {
      final material = await client.callTool('create_asset', {'type': 'filamat', 'folder': 'materials', 'name': 'M_Agent'});
      expect(material.isError, isFalse, reason: material.text);
      final matFile = File('${vm.projectDirPath}/contents/materials/M_Agent.lmas');
      expect(matFile.existsSync(), isTrue);
      final matAsset = LuminaAsset.fromBytes(matFile.readAsBytesSync());
      expect(matAsset.type, AssetType.filamat);
      expect(matAsset.rawMatSource, contains('material {'));
      expect(matAsset.rawMatSource, contains('fragment {'));
      // glTF texture coordinates sampled unflipped: a texture draws upright.
      expect(matAsset.rawMatSource, contains('flipUV : false'));
      expect(vm.realAssets.any((a) => a.relativePath == 'contents/materials/M_Agent.lmas'), isTrue);
      final again = await client.callTool('create_asset', {'type': 'filamat', 'name': 'M_Agent'});
      expect(again.isError, isTrue);
      expect(again.text, contains('already exists'));

      final blueprint = await client.callTool('create_asset', {'type': 'actor', 'name': 'BP_Agent', 'parent_class': 'LuminaActor'});
      expect(blueprint.isError, isFalse, reason: blueprint.text);
      final bpFile = File('${vm.projectDirPath}/contents/blueprints/BP_Agent.lmas');
      expect(bpFile.existsSync(), isTrue);
      expect(LuminaAsset.fromBytes(bpFile.readAsBytesSync()).metadata['parent_class'], 'LuminaActor');

      // A value outside the schema's enum is refused before the handler runs
      // (-32602), naming the accepted classes.
      await expectLater(
        client.callTool('create_asset', {'type': 'actor', 'name': 'BP_Bad', 'parent_class': 'AActor'}),
        throwsA(isA<McpRpcError>().having((e) => e.message, 'message', contains('LuminaCharacter'))),
      );
      expect(File('${vm.projectDirPath}/contents/blueprints/BP_Bad.lmas').existsSync(), isFalse);
    });

    test('open_asset_editor opens the Content Browser\'s tab for the asset, once', () async {
      await client.callTool('create_asset', {'type': 'filamat', 'name': 'M_Open'});
      final opened = await client.callTool('open_asset_editor', {'asset': 'contents/materials/M_Open.lmas'});
      expect(opened.isError, isFalse, reason: opened.text);
      expect(opened.data['category'], 'Material');
      expect(vm.currentTab.category, 'Material');
      expect(vm.currentTab.asset?.relativePath, 'contents/materials/M_Open.lmas');
      final tabs = vm.openTabs.length;
      await client.callTool('open_asset_editor', {'asset': 'M_Open'});
      expect(vm.openTabs.length, tabs, reason: 'the same asset opens one tab');

      await expectLater(
        client.callTool('open_asset_editor', {'asset': 'contents/materials/M_Nope.lmas'}),
        throwsA(isA<McpRpcError>().having((e) => e.message, 'message', contains('list_assets'))),
      );
      expect(vm.openTabs.length, tabs, reason: 'an unknown asset opens nothing');
    });

    test('delete_asset removes the files', () async {
      await client.callTool('create_asset', {'type': 'filamat', 'name': 'M_Gone'});
      final file = File('${vm.projectDirPath}/contents/materials/M_Gone.lmas');
      expect(file.existsSync(), isTrue);
      final deleted = await client.callTool('delete_asset', {'asset': 'M_Gone'});
      expect(deleted.isError, isFalse, reason: deleted.text);
      expect(file.existsSync(), isFalse);
      expect(vm.realAssets.any((a) => a.fileName == 'M_Gone.lmas'), isFalse);
    });
  });

  group('material tools', () {
    const brokenSource = '''
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
    const goodSource = '''
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
        material.baseColor = vec4(0.8, 0.1, 0.1, 1.0);
        material.roughness = materialParams.roughness;
    }
}
''';

    const vertexBlockSource = '''
material {
    name : "M_Agent",
    shadingModel : unlit,
    blending : fade,
    requires : [ tangents ],
    variables : [ tint ]
}

fragment {
    void material(inout MaterialInputs material) {
        prepareMaterial(material);
        material.baseColor = vec4(variable_tint.rgb, 0.7);
    }
}

vertex {
    void materialVertex(inout MaterialVertexInputs material) {
        material.tint = vec4(material.worldNormal * 0.5 + 0.5, 1.0);
    }
}
''';

    test('get / set / compile a material through its editor tab, with the real compiler', () async {
      await client.callTool('create_asset', {'type': 'filamat', 'name': 'M_Agent'});
      final source = await client.callTool('get_material_source', {'asset': 'contents/materials/M_Agent.lmas'});
      expect(source.isError, isFalse, reason: source.text);
      expect(source.data['source'], contains('material {'));
      expect(source.data['source'], contains('fragment {'));
      expect(source.data['shading_model'], 'lit');
      expect((source.data['parameters'] as Map).keys, contains('roughness'));
      // The tab is open and bound to the same view model the tool edits.
      expect(vm.currentTab.category, 'Material');
      final editor = vm.editorSessionFor(vm.currentTab.id);
      expect(editor, isA<MaterialEditorViewModel>());

      final set = await client.callTool('set_material_source', {'asset': 'M_Agent', 'source': brokenSource});
      expect(set.isError, isFalse, reason: set.text);
      expect((editor as MaterialEditorViewModel).currentCode, brokenSource);
      expect(editor.isDirty, isTrue);

      final broken = await client.callTool('compile_material', {'asset': 'M_Agent'});
      expect(broken.data['ok'], isFalse, reason: broken.text);
      expect(broken.isError, isTrue);
      final issues = (broken.data['issues'] as List).cast<Map>();
      // matc's own message, at the .mat line it names.
      final undeclaredLine = brokenSource.split('\n').indexWhere((l) => l.contains('undeclaredColor')) + 1;
      final error = issues.firstWhere((i) => i['severity'] == 'error', orElse: () => {});
      expect(error['message'], contains("'undeclaredColor'"), reason: '$issues');
      expect(error['line'], undeclaredLine, reason: '$issues');
      final asked = await client.callTool('get_material_issues', {'asset': 'M_Agent'});
      expect(asked.data['issues'], issues);

      await client.callTool('set_material_source', {'asset': 'M_Agent', 'source': goodSource});
      final good = await client.callTool('compile_material', {'asset': 'M_Agent', 'save': true});
      expect(good.data['ok'], isTrue, reason: good.text);
      expect((good.data['compiled_bytes'] as int), greaterThan(0));
      expect(good.data['saved'], isTrue);
      final onDisk = LuminaAsset.fromBytes(File('${vm.projectDirPath}/contents/materials/M_Agent.lmas').readAsBytesSync());
      expect(onDisk.rawMatSource, goodSource);

      // The whole Filament definition compiles: a vertex block after the fragment, variables, fade blending.
      await client.callTool('set_material_source', {'asset': 'M_Agent', 'source': vertexBlockSource});
      final wave = await client.callTool('compile_material', {'asset': 'M_Agent'});
      expect(wave.data['ok'], isTrue, reason: wave.text);
      final waveSource = await client.callTool('get_material_source', {'asset': 'M_Agent'});
      expect(waveSource.data['blending'], 'fade');
      expect(waveSource.data['shading_model'], 'unlit');

      final notMaterial = await client.callTool('create_asset', {'type': 'actor', 'name': 'BP_NotMat'});
      expect(notMaterial.isError, isFalse);
      await expectLater(
        client.callTool('get_material_source', {'asset': 'BP_NotMat'}),
        throwsA(isA<McpRpcError>().having((e) => e.message, 'message', contains('filamat'))),
      );
    });
  });

  group('blueprint tools', () {
    test('list_blueprint_nodes is the node library with pins, narrowed by category and query', () async {
      final all = (await client.callTool('list_blueprint_nodes')).data;
      final ids = (all['nodes'] as List).map((n) => (n as Map)['id']).toList();
      expect(ids, containsAll(<String>['event_beginplay', 'branch', 'print_string']));
      final print = (all['nodes'] as List).cast<Map>().firstWhere((n) => n['id'] == 'print_string');
      expect((print['inputs'] as List).map((p) => (p as Map)['id']), containsAll(<String>['exec_in', 'in_string']));
      expect((print['outputs'] as List).map((p) => (p as Map)['id']), contains('exec_out'));

      final flow = (await client.callTool('list_blueprint_nodes', {'category': 'Flow Control'})).data;
      expect((flow['nodes'] as List), isNotEmpty);
      expect((flow['nodes'] as List).every((n) => (n as Map)['category'] == 'Flow Control'), isTrue);
      final byQuery = (await client.callTool('list_blueprint_nodes', {'query': 'print'})).data;
      expect((byQuery['nodes'] as List).map((n) => (n as Map)['id']), contains('print_string'));
    });

    test('a Print String on BeginPlay is authored, wired, given a literal and compiled to Dart', () async {
      await client.callTool('create_asset', {'type': 'actor', 'name': 'BP_Agent', 'parent_class': 'LuminaActor'});
      const asset = 'contents/blueprints/BP_Agent.lmas';
      var bp = (await client.callTool('get_blueprint', {'asset': asset})).data;
      expect(bp['parent_class'], 'LuminaActor');
      expect(vm.currentTab.category, 'Blueprint', reason: 'the Blueprint editor tab opens for the agent\'s edits');
      final editor = vm.editorSessionFor(vm.currentTab.id);
      expect(editor, isA<BlueprintEditorViewModel>());

      String? beginPlay = ((bp['nodes'] as List).cast<Map>().where((n) => n['node'] == 'event_beginplay').firstOrNull)?['id'] as String?;
      if (beginPlay == null) {
        final added = await client.callTool('add_blueprint_node', {'asset': asset, 'node': 'event_beginplay', 'x': 60, 'y': 80});
        expect(added.isError, isFalse, reason: added.text);
        beginPlay = (added.data['node'] as Map)['id'] as String;
      }
      final added = await client.callTool('add_blueprint_node', {'asset': asset, 'node': 'print_string', 'x': 300, 'y': 100});
      expect(added.isError, isFalse, reason: added.text);
      final printNode = (added.data['node'] as Map)['id'] as String;
      expect((editor as BlueprintEditorViewModel).getGraphNode(printNode), isNotNull);
      expect(editor.transactions.canUndo, isTrue);
      expect(editor.transactions.undoLabel, 'Undo MCP: Add Print String');

      final wired = await client.callTool('connect_blueprint_pins', {
        'asset': asset,
        'from_node': beginPlay,
        'from_pin': 'exec_out',
        'to_node': printNode,
        'to_pin': 'exec_in',
      });
      expect(wired.isError, isFalse, reason: wired.text);
      final wireId = (wired.data['wire'] as Map)['id'] as String;

      final literal = await client.callTool('set_blueprint_pin_literal', {
        'asset': asset,
        'node': printNode,
        'pin': 'in_string',
        'value': 'hello from mcp',
      });
      expect(literal.isError, isFalse, reason: literal.text);

      bp = (await client.callTool('get_blueprint', {'asset': asset})).data;
      final node = (bp['nodes'] as List).cast<Map>().firstWhere((n) => n['id'] == printNode);
      expect(node['literals'], containsPair('in_string', 'hello from mcp'));
      expect((bp['wires'] as List).cast<Map>().any((w) => w['id'] == wireId && w['to_node'] == printNode), isTrue);

      final compiled = await client.callTool('compile_blueprint', {'asset': asset, 'save': true});
      expect(compiled.data['status'], isNot('error'), reason: compiled.text);
      final generated = File(compiled.data['generated_file'] as String);
      expect(generated.existsSync(), isTrue, reason: generated.path);
      expect(generated.readAsStringSync(), contains('hello from mcp'));
      expect(compiled.data['saved'], isTrue);
      final diagnostics = (await client.callTool('get_blueprint_diagnostics', {'asset': asset})).data;
      expect(diagnostics['status'], isNot('error'));

      // Each edit is one step on the Blueprint editor's own undo stack.
      editor.undo(); // literal
      expect(editor.getGraphNode(printNode)!.literals['in_string'], isNot('hello from mcp'));
      editor.undo(); // wire
      expect(editor.graphWires.any((w) => w.id == wireId), isFalse);
      editor.undo(); // node
      expect(editor.getGraphNode(printNode), isNull);
      editor.redo();
      expect(editor.getGraphNode(printNode), isNotNull);

      final removedWire = await client.callTool('remove_blueprint_wire', {'asset': asset, 'wire': 'wire_nope'});
      expect(removedWire.isError, isTrue);
      final removed = await client.callTool('remove_blueprint_node', {'asset': asset, 'node': printNode});
      expect(removed.isError, isFalse, reason: removed.text);
      expect(editor.getGraphNode(printNode), isNull);
    });

    test('bad pins and unknown library ids are refused with the reason', () async {
      await client.callTool('create_asset', {'type': 'actor', 'name': 'BP_Pins', 'parent_class': 'LuminaActor'});
      const asset = 'contents/blueprints/BP_Pins.lmas';
      final tick = (await client.callTool('add_blueprint_node', {'asset': asset, 'node': 'event_tick'})).data['node'] as Map;
      final print = (await client.callTool('add_blueprint_node', {'asset': asset, 'node': 'print_string'})).data['node'] as Map;
      final deltaPin = (tick['outputs'] as List).cast<Map>().firstWhere((p) => p['type'] == 'float')['id'] as String;
      final mismatch = await client.callTool('connect_blueprint_pins', {
        'asset': asset,
        'from_node': tick['id'],
        'from_pin': deltaPin,
        'to_node': print['id'],
        'to_pin': 'exec_in',
      });
      expect(mismatch.isError, isTrue);
      expect(mismatch.text, contains(deltaPin));
      expect(mismatch.text, contains('exec_in'));

      final unknown = await client.callTool('add_blueprint_node', {'asset': asset, 'node': 'Print String'});
      expect(unknown.isError, isTrue);
      expect(unknown.text, contains('list_blueprint_nodes'));

      final noPin = await client.callTool('set_blueprint_pin_literal', {'asset': asset, 'node': print['id'], 'pin': 'nope', 'value': 1});
      expect(noPin.isError, isTrue);
      expect(noPin.text, contains('in_string'));
    });
  });
}
