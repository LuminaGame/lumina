import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_server_service.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_server_settings.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_component_registry.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/blueprint_asset_catalog.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_editor_view_model.dart';

import '../helpers/mcp_test_client.dart';
import '../helpers/temp_project.dart';

/// Components of level actors and Blueprints, a Blueprint's
/// members and graphs, and the Level Blueprint — a real MCP client over HTTP
/// against a real editor on a real temp project with a real imported barrel.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final barrelGlb = File('${Directory.current.parent.path}/test-assets/Props/Barrels/fuel_barrel_red.glb');
  const levelPath = 'contents/levels/L_Main.lmas';
  const door = 'contents/blueprints/BP_AgentDoor.lmas';

  late Directory root;
  late EditorViewModel vm;
  late McpServerService server;
  late McpTestClient client;
  late RealAssetInfo barrelMesh;
  late String barrelId;
  late String lightId;

  setUp(() async {
    root = Directory.systemTemp.createTempSync('lumina_mcp_comp_');
    final configDir = Directory('${root.path}/config')..createSync();
    final projectDir = Directory('${root.path}/CompProject')..createSync();
    const project = LuminaProject(projectName: 'CompProject', activeLevel: levelPath);
    File('${projectDir.path}/CompProject.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
    Directory('${projectDir.path}/contents/levels').createSync(recursive: true);
    // A real Blueprint Interface asset, as the interface editor writes it.
    BlueprintAssetCatalog.writeInterface(projectDir.path, const LuminaBlueprintInterfaceDocument(name: 'BPI_Interactable'));
    vm = EditorViewModel(initialProject: project, projectLocation: root.path, enableTimers: false, autoInitAssets: false);
    server = McpServerService(vm, configDir: configDir, settings: McpServerSettings.load(configDir: configDir));
    expect(await server.start(port: 0), isTrue);
    client = McpTestClient(server.url!, server.token);
    await client.handshake();
    await vm.ensureDefaultLevelAssets();
    if (barrelGlb.existsSync()) {
      await vm.processImportPipeline(sourceFilePath: barrelGlb.path);
      barrelMesh = vm.realAssets.firstWhere((a) => a.type == AssetType.filamesh && a.fileName.contains('fuel_barrel_red'));
      await client.callTool('spawn_actor_from_asset', {'asset': barrelMesh.relativePath});
      barrelId = vm.actors.last.id;
    }
    await client.callTool('spawn_actor', {'type': 'PointLight', 'location': [0, 0, 300]});
    lightId = vm.actors.last.id;
    await client.callTool('create_asset', {'type': 'actor', 'name': 'BP_AgentDoor', 'parent_class': 'LuminaActor'});
  });

  tearDown(() async {
    client.close();
    await server.stop();
    await vm.close();
    await deleteTempProject(root);
  });

  Future<McpToolReply> call(String tool, [Map<String, Object?> args = const {}]) => client.callTool(tool, args);
  Future<Map<String, Object?>> ok(String tool, [Map<String, Object?> args = const {}]) async {
    final r = await call(tool, args);
    expect(r.isError, isFalse, reason: '$tool: ${r.text}');
    return r.data;
  }

  Future<void> expectToolError(String tool, Map<String, Object?> args, Matcher message) async {
    try {
      final r = await call(tool, args);
      expect(r.isError, isTrue, reason: '$tool should fail: ${r.text}');
      expect(r.text, message);
    } on McpRpcError catch (e) {
      expect(e.message, message);
    }
  }

  Map<String, Object?> actorComponent(Map<String, Object?> actor, String id) =>
      Map<String, Object?>.from((actor['components'] as List).cast<Map>().firstWhere((c) => c['id'] == id));

  BlueprintEditorViewModel doorEditor() => vm.editorSessionFor(vm.openTabs.firstWhere((t) => t.id.endsWith('BP_AgentDoor.lmas')).id)
      as BlueprintEditorViewModel;

  bool skipWithoutAssets() {
    if (barrelGlb.existsSync()) return false;
    markTestSkipped('test-assets not present');
    return true;
  }

  group('level actor components', () {
    test('list_component_types: 17 Details types, 17 Blueprint types with availability', () async {
      final actor = await ok('list_component_types', {'context': 'actor'});
      expect(actor['count'], 17);
      final light = (actor['types'] as List).cast<Map>().firstWhere((t) => t['type'] == 'LuminaPointLightComponent');
      expect((light['properties'] as List).cast<Map>().map((p) => p['id']), contains('intensity'));
      final bp = await ok('list_component_types', {'context': 'blueprint'});
      expect(bp['count'], BlueprintComponentRegistry.registeredComponents.length);
      final bpLight = (bp['types'] as List).cast<Map>().firstWhere((t) => t['type'] == 'LuminaPointLightComponent');
      expect(bpLight['is_available'], isFalse);
      expect(bpLight['gap_reason'], contains('light component support'));
    });

    test('add_actor_component: unique ids, one undo step each; properties settable; unknown types listed', () async {
      if (skipWithoutAssets()) return;
      final a = await ok('add_actor_component', {'actor_id': barrelId, 'type': 'LuminaPointLightComponent'});
      final b = await ok('add_actor_component', {'actor_id': barrelId, 'type': 'LuminaPointLightComponent'});
      final idA = (a['component'] as Map)['id'] as String, idB = (b['component'] as Map)['id'] as String;
      expect(idA, isNot(idB));
      expect(vm.transactions.undoLabel, 'Undo MCP: Add Component');
      final actor = await ok('get_actor', {'id': barrelId});
      expect((actor['components'] as List).cast<Map>().map((c) => c['id']), containsAll([idA, idB]));

      await ok('set_actor_property', {'id': barrelId, 'property': '$idA.intensity', 'value': 5000});
      expect(actorComponent(await ok('get_actor', {'id': barrelId}), idA)['properties'], containsPair('intensity', 5000));

      await ok('undo');
      await ok('undo');
      expect((await ok('get_actor', {'id': barrelId}))['components'] as List, isNot(contains(predicate((c) => (c as Map)['id'] == idB))));
      await expectToolError('add_actor_component', {'actor_id': barrelId, 'type': 'Nope'}, contains('LuminaPointLightComponent'));
    });

    test('remove_actor_component removes exactly the named one; undo restores it in place', () async {
      if (skipWithoutAssets()) return;
      final idA = ((await ok('add_actor_component', {'actor_id': barrelId, 'type': 'LuminaPointLightComponent'}))['component'] as Map)['id'];
      final idB = ((await ok('add_actor_component', {'actor_id': barrelId, 'type': 'LuminaPointLightComponent'}))['component'] as Map)['id'];
      await ok('set_actor_property', {'id': barrelId, 'property': '$idA.intensity', 'value': 1234});
      final before = [for (final c in vm.actors.firstWhere((a) => a.id == barrelId).components) c.id];
      await ok('remove_actor_component', {'actor_id': barrelId, 'component': idA});
      final after = [for (final c in vm.actors.firstWhere((a) => a.id == barrelId).components) c.id];
      expect(after, isNot(contains(idA)));
      expect(after, contains(idB));
      await ok('undo');
      final restored = vm.actors.firstWhere((a) => a.id == barrelId).components;
      expect([for (final c in restored) c.id], before, reason: 'same index');
      expect(restored.firstWhere((c) => c.id == idA).properties['intensity'], 1234);
    });

    test('set_actor_component_enabled: one undo step', () async {
      if (skipWithoutAssets()) return;
      final id = ((await ok('add_actor_component', {'actor_id': barrelId, 'type': 'LuminaPointLightComponent'}))['component'] as Map)['id'] as String;
      await ok('set_actor_component_enabled', {'actor_id': barrelId, 'component': id, 'enabled': false});
      expect(actorComponent(await ok('get_actor', {'id': barrelId}), id)['enabled'], isFalse);
      expect(vm.selectedActorIds, {barrelId}, reason: 'Details shows the actor');
      await ok('undo');
      expect(actorComponent(await ok('get_actor', {'id': barrelId}), id)['enabled'], isTrue);
    });

    test('set_actor_collision: presets, overrides, refusal on a non-collision component', () async {
      if (skipWithoutAssets()) return;
      final capsule = ((await ok('add_actor_component', {'actor_id': barrelId, 'type': 'LuminaCapsuleComponent'}))['component'] as Map)['id'] as String;
      await ok('set_actor_collision', {'actor_id': barrelId, 'component': capsule, 'preset': 'BlockAll'});
      final props = vm.actors.firstWhere((a) => a.id == barrelId).components.firstWhere((c) => c.id == capsule).properties;
      expect(props['preset'], 'blockAll');
      expect((props['responses'] as Map)['pawn'], 'block');
      await ok('set_actor_collision', {'actor_id': barrelId, 'component': capsule, 'preset': 'Trigger', 'generate_overlap_events': true});
      final trig = vm.actors.firstWhere((a) => a.id == barrelId).components.firstWhere((c) => c.id == capsule).properties;
      expect(trig['objectType'], 'worldDynamic');
      expect(trig['generateOverlapEvents'], isTrue);
      final light = ((await ok('add_actor_component', {'actor_id': lightId, 'type': 'LuminaPointLightComponent'}))['component'] as Map)['id'];
      await expectToolError('set_actor_collision', {'actor_id': lightId, 'component': light, 'preset': 'BlockAll'}, contains('no Collision section'));
    });

    test('a placed Blueprint: collision and physics go into its instance override; a plain light has no Physics', () async {
      if (skipWithoutAssets()) return;
      final mesh = ((await ok('add_blueprint_component', {'asset': door, 'type': 'LuminaStaticMeshComponent'}))['component'] as Map)['id'];
      final box = ((await ok('add_blueprint_component', {'asset': door, 'type': 'LuminaBoxComponent'}))['component'] as Map)['id'];
      await ok('compile_blueprint', {'asset': door, 'save': true});
      await ok('spawn_actor_from_asset', {'asset': door});
      final instance = vm.actors.last.id;
      await ok('set_actor_collision', {'actor_id': instance, 'component': box, 'preset': 'BlockAll'});
      final override = vm.actors.last.components.firstWhere((c) => c.id == '$instance.collision.$box');
      expect(override.properties['preset'], 'blockAll');
      await ok('set_actor_physics', {
        'actor_id': instance,
        'component': mesh,
        'physics': {'simulate': true, 'overrideMass': true, 'massKg': 25},
      });
      final physics = vm.actors.last.components.firstWhere((c) => c.id == '$instance.collision.$mesh').properties['physics'] as Map;
      expect(physics, containsPair('simulate', true));
      expect(physics, containsPair('massKg', 25));
      await expectToolError('set_actor_physics', {'actor_id': lightId, 'component': 'x', 'physics': {'simulate': true}},
          contains('no Physics section'));
    });
  });

  group('Blueprint class', () {
    test('components tree: add, set property, child, reparent, rename rules, unavailable types', () async {
      if (skipWithoutAssets()) return;
      final levelHistory = vm.transactions.history(limit: 200).length;
      final mesh = ((await ok('add_blueprint_component', {'asset': door, 'type': 'LuminaStaticMeshComponent'}))['component'] as Map)['id'] as String;
      final editor = doorEditor();
      expect(editor.transactions.undoLabel, startsWith('Undo MCP: '));
      await ok('set_blueprint_component_property',
          {'asset': door, 'component': mesh, 'property': 'staticMeshAsset', 'value': barrelMesh.relativePath});
      expect(editor.getComponent(mesh)!.properties['staticMeshAsset'], barrelMesh.relativePath);
      final boxReply = await ok('add_blueprint_component', {'asset': door, 'type': 'LuminaBoxComponent', 'parent': mesh});
      final box = (boxReply['component'] as Map)['id'] as String;
      expect((boxReply['component'] as Map)['parent_id'], mesh);
      final reparented = await ok('reparent_blueprint_component', {'asset': door, 'component': box, 'parent': null});
      expect((reparented['component'] as Map)['parent_id'], isNot(mesh));
      await expectToolError('rename_blueprint_component', {'asset': door, 'component': mesh, 'name': 'Door Mesh'}, contains('identifier'));
      await ok('rename_blueprint_component', {'asset': door, 'component': mesh, 'name': 'DoorMesh'});
      expect(editor.getComponent(mesh)!.name, 'DoorMesh');
      await expectToolError('add_blueprint_component', {'asset': door, 'type': 'LuminaPointLightComponent'}, contains('light component support'));
      expect(vm.transactions.history(limit: 200).length, levelHistory, reason: 'the level stack is unchanged');
    });

    test('a Spring Arm: Use Pawn Control Rotation and the other settings the runtime reads are settable', () async {
      final arm = ((await ok('add_blueprint_component', {'asset': door, 'type': 'LuminaSpringArmComponent'}))['component'] as Map)['id'] as String;
      final editor = doorEditor();
      // The runtime's defaults, seeded on add.
      expect(editor.getComponent(arm)!.properties, containsPair('usePawnControlRotation', false));
      const values = <String, Object>{
        'usePawnControlRotation': true,
        'inheritPitch': true,
        'inheritYaw': true,
        'inheritRoll': false,
        'enableCameraRotationLag': true,
        'cameraRotationLagSpeed': 14.0,
        'doCollisionTest': false,
        'probeSize': 25.0,
      };
      for (final e in values.entries) {
        await ok('set_blueprint_component_property', {'asset': door, 'component': arm, 'property': e.key, 'value': e.value});
      }
      final props = editor.getComponent(arm)!.properties;
      for (final e in values.entries) {
        expect(props[e.key], e.value, reason: e.key);
      }
      await expectToolError('set_blueprint_component_property',
          {'asset': door, 'component': arm, 'property': 'usePawnControlRotation', 'value': 'yes'}, contains('true or false'));
      // What the editor writes is what the game builds.
      final built = LuminaBlueprintComponents.construct(
          LuminaActor(root: LuminaSceneComponent()), [editor.getComponent(arm)!])[arm] as LuminaSpringArmComponent;
      expect(built.bUsePawnControlRotation, isTrue);
      expect(built.bInheritRoll, isFalse);
      expect(built.bDoCollisionTest, isFalse);
      expect(built.cameraRotationLagSpeed, 14.0);
      expect(built.probeSize, 25.0);
    });

    test('component transform is one undo step on the Blueprint tab', () async {
      final mesh = ((await ok('add_blueprint_component', {'asset': door, 'type': 'LuminaStaticMeshComponent'}))['component'] as Map)['id'] as String;
      final editor = doorEditor();
      final depth = editor.transactions.history(limit: 200).length;
      await ok('set_blueprint_component_transform', {'asset': door, 'component': mesh, 'location': [0, 50, 100]});
      expect(editor.getComponent(mesh)!.properties['location'], [0.0, 50.0, 100.0]);
      expect(editor.transactions.history(limit: 200).length, depth + 1);
    });

    test('parent class and class defaults', () async {
      await ok('set_blueprint_parent_class', {'asset': door, 'parent_class': 'LuminaPawn'});
      expect((await ok('get_blueprint', {'asset': door}))['parent_class'], 'LuminaPawn');
      await expectToolError('set_blueprint_parent_class', {'asset': door, 'parent_class': 'Foo'}, contains('LuminaCharacter'));
      await ok('set_blueprint_class_default', {'asset': door, 'key': 'initialHealth', 'value': 150});
      expect(((await ok('get_blueprint', {'asset': door}))['class_defaults'] as Map)['initialHealth'], 150);
      await expectToolError('set_blueprint_class_default', {'asset': door, 'key': 'speed', 'value': 1}, contains('initialHealth'));
    });
  });

  group('Blueprint members', () {
    test('variables: unique names, rename follows nodes, type, delete lists removed nodes', () async {
      expect((await ok('add_blueprint_variable', {'asset': door, 'name': 'OpenAngle', 'type': 'Float', 'default': 90}))['variable'],
          containsPair('name', 'OpenAngle'));
      expect(((await ok('add_blueprint_variable', {'asset': door, 'name': 'OpenAngle', 'type': 'Float'}))['variable'] as Map)['name'], 'OpenAngle2');
      final getter = ((await ok('add_blueprint_node', {'asset': door, 'node': 'variable_get', 'literals': {'variable': 'OpenAngle'}}))['node'] as Map)['id'];
      await ok('rename_blueprint_variable', {'asset': door, 'variable': 'OpenAngle', 'name': 'TargetAngle'});
      final nodes = ((await ok('get_blueprint', {'asset': door}))['nodes'] as List).cast<Map>();
      expect((nodes.firstWhere((n) => n['id'] == getter)['literals'] as Map)['variable'], 'TargetAngle');
      await ok('set_blueprint_variable_type', {'asset': door, 'variable': 'TargetAngle', 'type': 'Integer'});
      expect(doorEditor().document.variables.firstWhere((v) => v.name == 'TargetAngle').typeName, 'Integer');
      final deleted = await ok('delete_blueprint_variable', {'asset': door, 'variable': 'TargetAngle'});
      expect(deleted['removed_nodes'], [getter]);
    });

    test('a function with a signature, a body in its graph, and a compile that generates it', () async {
      final fn = await ok('add_blueprint_function', {'asset': door, 'name': 'OpenDoor'});
      expect(fn['graph'], 'function:OpenDoor');
      await ok('set_blueprint_function_signature', {
        'asset': door,
        'function': 'OpenDoor',
        'inputs': [
          {'name': 'Angle', 'type': 'Float'},
        ],
        'pure': false,
        'category': 'Door',
      });
      final print = ((await ok('add_blueprint_node', {'asset': door, 'graph': 'function:OpenDoor', 'node': 'print_string'}))['node'] as Map)['id'];
      final graph = await ok('get_blueprint', {'asset': door, 'graph': 'function:OpenDoor'});
      final entry = (graph['nodes'] as List).cast<Map>().firstWhere((n) => (n['outputs'] as List).cast<Map>().any((p) => p['name'] == 'Angle'));
      await ok('connect_blueprint_pins',
          {'asset': door, 'graph': 'function:OpenDoor', 'from_node': entry['id'], 'from_pin': 'exec_out', 'to_node': print, 'to_pin': 'exec_in'});
      final compiled = await ok('compile_blueprint', {'asset': door});
      expect(compiled['status'], isNot('error'));
      expect(File(compiled['generated_file'] as String).readAsStringSync(), contains('OpenDoor('));

      await expectToolError('add_blueprint_node', {'asset': door, 'graph': 'function:OpenDoor', 'node': 'event_beginplay'},
          contains('does not accept'));
      await expectToolError('add_blueprint_node', {'asset': door, 'graph': 'construction', 'node': 'print_string'},
          contains('Construction Script'));
    });

    test('macros, dispatchers, interfaces and custom event parameters', () async {
      final macro = (await ok('add_blueprint_macro', {'asset': door, 'name': 'Twice'}))['macro'] as String;
      final sig = await ok('set_blueprint_macro_signature', {
        'asset': door,
        'macro': macro,
        'inputs': [
          {'name': 'Value', 'type': 'Float'},
        ],
      });
      expect((sig['inputs'] as List).cast<Map>().map((v) => v['name']), contains('Value'));
      await ok('delete_blueprint_macro', {'asset': door, 'macro': macro});
      expect(doorEditor().document.macros, isEmpty);

      final d = (await ok('add_blueprint_dispatcher', {'asset': door, 'name': 'OnOpened'}))['dispatcher'];
      final params = await ok('set_blueprint_dispatcher_parameters', {
        'asset': door,
        'dispatcher': d,
        'parameters': [
          {'name': 'By', 'type': 'Actor'},
        ],
      });
      expect((params['parameters'] as List).single, containsPair('name', 'By'));

      expect((await ok('implement_blueprint_interface', {'asset': door, 'interface': 'BPI_Interactable'}))['interfaces'], ['BPI_Interactable']);
      await expectToolError('implement_blueprint_interface', {'asset': door, 'interface': 'BPI_Nope'}, contains('BPI_Interactable'));

      final knock = ((await ok('add_blueprint_node', {'asset': door, 'node': 'custom_event', 'literals': {'name': 'Knock'}}))['node'] as Map)['id'];
      final withParams = await ok('set_custom_event_parameters', {
        'asset': door,
        'node': knock,
        'parameters': [
          {'name': 'Strength', 'type': 'Float'},
        ],
      });
      expect(((withParams['node'] as Map)['outputs'] as List).cast<Map>().map((p) => p['name']), contains('Strength'));
    });

    test('timelines: settings, tracks, keys', () async {
      final tl = ((await ok('add_blueprint_node', {'asset': door, 'node': 'timeline'}))['node'] as Map)['id'];
      await ok('set_blueprint_timeline', {'asset': door, 'node': tl, 'length': 2, 'loop': false, 'auto_play': true});
      final track = (await ok('add_timeline_track', {'asset': door, 'node': tl, 'name': 'Alpha', 'type': 'float'}))['track'];
      expect(track, 'Alpha');
      await ok('set_timeline_keys', {
        'asset': door,
        'node': tl,
        'track': 'Alpha',
        'keys': [
          {'time': 0, 'value': [0]},
          {'time': 2, 'value': [1], 'interp': 'cubic'},
        ],
      });
      final timelines = (await ok('get_blueprint', {'asset': door}))['timelines'] as List;
      final t = timelines.cast<Map>().single;
      expect(t['length'], 2.0);
      expect(t['auto_play'], isTrue);
      final keys = ((t['tracks'] as List).cast<Map>().single['keys'] as List).cast<Map>();
      expect(keys.last, containsPair('interp', 'cubic'));
      await expectToolError('set_timeline_keys', {'asset': door, 'node': tl, 'track': 'Nope', 'keys': []}, contains('Alpha'));
    });

    test('collapse two nodes to a function, then expand the call back', () async {
      final a = ((await ok('add_blueprint_node', {'asset': door, 'node': 'print_string', 'x': 300, 'y': 400}))['node'] as Map)['id'];
      final b = ((await ok('add_blueprint_node', {'asset': door, 'node': 'print_string', 'x': 600, 'y': 400}))['node'] as Map)['id'];
      await ok('connect_blueprint_pins', {'asset': door, 'from_node': a, 'from_pin': 'exec_out', 'to_node': b, 'to_pin': 'exec_in'});
      final collapsed = await ok('collapse_blueprint_nodes', {'asset': door, 'nodes': [a, b], 'to': 'function', 'name': 'SayTwice'});
      expect(doorEditor().document.function('SayTwice'), isNotNull);
      final call = (collapsed['call_node'] as Map)['id'];
      final nodes = ((await ok('get_blueprint', {'asset': door}))['nodes'] as List).cast<Map>();
      expect(nodes.where((n) => n['id'] == a || n['id'] == b), isEmpty);
      expect(nodes.where((n) => n['id'] == call), hasLength(1));
      final expanded = await ok('expand_blueprint_node', {'asset': door, 'node': call});
      expect((expanded['restored_nodes'] as List), hasLength(2));
      expect(doorEditor().document.function('SayTwice'), isNull);
    });
  });

  group('Level Blueprint, undo stacks, Play and the catalogue', () {
    test('the Level Blueprint: nodes, compile with save; no components', () async {
      final bp = await ok('get_blueprint', {'asset': 'level'});
      expect(bp['is_level_blueprint'], isTrue);
      expect(vm.currentTab.title, contains('Level Blueprint'));
      var begin = (bp['nodes'] as List).cast<Map>().where((n) => n['node'] == 'event_beginplay').firstOrNull?['id'];
      begin ??= ((await ok('add_blueprint_node', {'asset': 'level', 'node': 'event_beginplay', 'x': 60, 'y': 80}))['node'] as Map)['id'];
      final print = ((await ok('add_blueprint_node', {'asset': 'level', 'node': 'print_string', 'literals': {'in_string': 'Hello level'}}))['node'] as Map)['id'];
      await ok('connect_blueprint_pins', {'asset': 'level', 'from_node': begin, 'from_pin': 'exec_out', 'to_node': print, 'to_pin': 'exec_in'});
      final compiled = await ok('compile_blueprint', {'asset': 'level', 'save': true});
      expect(compiled['generated_file'], endsWith('lib/levels/l_main.dart'));
      expect(compiled['generated_code'], contains('Hello level'));
      expect(File('${vm.projectDirPath}/$levelPath').readAsStringSync(), contains(LuminaLevelBlueprintDocument.metadataKey));
      await expectToolError('add_blueprint_component', {'asset': 'level', 'type': 'LuminaBoxComponent'}, contains('Level Blueprint has no components'));

      // Its edits undo on the Level Blueprint tab's own stack.
      final extra = ((await ok('add_blueprint_node', {'asset': 'level', 'node': 'print_string'}))['node'] as Map)['id'];
      final undone = await ok('undo', {'asset': 'level', 'scope': 'agent'});
      expect(undone['undone'], 'Undo MCP: Add Print String');
      final after = ((await ok('get_blueprint', {'asset': 'level'}))['nodes'] as List).cast<Map>();
      expect(after.where((n) => n['id'] == extra), isEmpty);
      expect(after.where((n) => n['id'] == print), hasLength(1));
    });

    test('Blueprint edits are one step on the tab stack, the level stack unchanged; Play refuses edits', () async {
      await ok('add_blueprint_variable', {'asset': door, 'name': 'Probe', 'type': 'Float'});
      final editor = doorEditor();
      final level = vm.transactions.history(limit: 200).map((h) => h.label).toList();
      final depth = editor.transactions.history(limit: 200).length;
      await ok('add_blueprint_function', {'asset': door, 'name': 'StepFn'});
      expect(editor.transactions.history(limit: 200).length, depth + 1);
      expect(editor.transactions.undoLabel, startsWith('Undo MCP: '));
      expect(vm.transactions.history(limit: 200).map((h) => h.label).toList(), level);

      // Play-In-Editor freezes edits (the flag start_pie sets).
      vm.transactions.isFrozen = true;
      try {
        await expectToolError('add_blueprint_variable', {'asset': door, 'name': 'X', 'type': 'Float'}, contains('Stop Play first'));
        await expectToolError('add_actor_component', {'actor_id': lightId, 'type': 'LuminaPointLightComponent'}, contains('Stop Play first'));
      } finally {
        vm.transactions.isFrozen = false;
      }
    });

    test('tools/list: every new tool has a description, a schema, a risk and known groups', () async {
      const newTools = {
        'list_component_types', 'add_actor_component', 'remove_actor_component', 'set_actor_component_enabled', //
        'set_actor_collision', 'set_actor_physics', 'add_blueprint_component', 'remove_blueprint_component',
        'rename_blueprint_component', 'reparent_blueprint_component', 'duplicate_blueprint_component',
        'set_blueprint_component_property', 'set_blueprint_component_transform', 'set_blueprint_component_collision',
        'set_blueprint_component_physics', 'set_blueprint_class_default', 'set_blueprint_parent_class',
        'reset_blueprint_components', 'add_blueprint_variable', 'rename_blueprint_variable', 'set_blueprint_variable_type',
        'set_blueprint_variable_default', 'delete_blueprint_variable', 'add_blueprint_function', 'rename_blueprint_function',
        'delete_blueprint_function', 'set_blueprint_function_signature', 'add_blueprint_local_variable',
        'rename_blueprint_local_variable', 'set_blueprint_local_variable_type', 'delete_blueprint_local_variable',
        'add_blueprint_macro', 'rename_blueprint_macro', 'delete_blueprint_macro', 'set_blueprint_macro_signature',
        'add_blueprint_dispatcher', 'rename_blueprint_dispatcher', 'delete_blueprint_dispatcher',
        'set_blueprint_dispatcher_parameters', 'implement_blueprint_interface', 'remove_blueprint_interface',
        'set_custom_event_parameters', 'set_blueprint_timeline', 'add_timeline_track', 'remove_timeline_track',
        'rename_timeline_track', 'set_timeline_keys', 'collapse_blueprint_nodes', 'expand_blueprint_node',
      };
      final tools = {for (final t in await client.listTools()) t['name']: t};
      for (final name in newTools) {
        final t = tools[name];
        expect(t, isNotNull, reason: name);
        expect((t!['description'] as String).trim(), isNotEmpty, reason: name);
        expect((t['inputSchema'] as Map)['type'], 'object', reason: name);
        final meta = t['_meta'] as Map;
        expect(meta['lumina/risk'], isNotNull, reason: name);
        expect((meta['lumina/groups'] as List), isNotEmpty, reason: name);
      }
      expect((tools['list_component_types']!['_meta'] as Map)['lumina/groups'], containsAll(['component', 'blueprint']));
      expect((tools['remove_actor_component']!['_meta'] as Map)['lumina/risk'], 'destructive');
      expect((tools['reset_blueprint_components']!['_meta'] as Map)['lumina/risk'], 'destructive');
    });
  });
}
