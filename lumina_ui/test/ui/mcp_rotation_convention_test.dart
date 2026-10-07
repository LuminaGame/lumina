import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_server_service.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_server_settings.dart';
import 'package:lumina_ui/ui/features/mcp_server/tools/rotation_convention.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_editor_view_model.dart';
import 'package:vector_math/vector_math_64.dart';

import '../helpers/mcp_test_client.dart';
import '../helpers/temp_project.dart';

/// Every MCP tool names a rotation triple the same way, and the numbers mean
/// what the words say: a level actor (spawn_actor, set_actor_transform,
/// set_actors_transform) and a Blueprint component
/// (set_blueprint_component_transform) take `[pitch, roll, yaw]` with yaw 90
/// facing +X and a positive pitch looking up — a real editor on a real temp
/// project, over a real MCP client.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const levelPath = 'contents/levels/L_Main.lmas';
  const blueprint = 'contents/blueprints/BP_Pointer.lmas';

  late Directory root;
  late EditorViewModel vm;
  late McpServerService server;
  late McpTestClient client;

  setUp(() async {
    root = Directory.systemTemp.createTempSync('lumina_mcp_rot_');
    final configDir = Directory('${root.path}/config')..createSync();
    final projectDir = Directory('${root.path}/RotProject')..createSync();
    const project = LuminaProject(projectName: 'RotProject', activeLevel: levelPath);
    File('${projectDir.path}/RotProject.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
    Directory('${projectDir.path}/contents/levels').createSync(recursive: true);
    vm = EditorViewModel(initialProject: project, projectLocation: root.path, enableTimers: false, autoInitAssets: false);
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

  Future<Map<String, Object?>> ok(String tool, [Map<String, Object?> args = const {}]) async {
    final r = await client.callTool(tool, args);
    expect(r.isError, isFalse, reason: '$tool: ${r.text}');
    return r.data;
  }

  /// The drawn forward (runtime −Z) of [q] in authoring axes (Z up).
  Vector3 forwardOf(Quaternion q) => Vector3.array(LuminaAxes.toAuthoringLocation(q.rotateVector(Vector3(0, 0, -1))));

  void expectForward(List<double> stored, List<double> expected, String reason) {
    final f = forwardOf(LuminaAxes.rotation(stored));
    for (var i = 0; i < 3; i++) {
      expect(f[i], closeTo(expected[i], 1e-6), reason: '$reason: stored $stored faces $f, expected $expected');
    }
  }

  test('every tool names a rotation triple [pitch, roll, yaw], and every rotation argument states its convention',
      () async {
    final tools = await client.listTools();
    expect(tools.length, greaterThan(100));
    final order = RegExp(r'\[\s*(roll|pitch|yaw)\s*,\s*(roll|pitch|yaw)\s*,\s*(roll|pitch|yaw)\s*\]', caseSensitive: false);
    final wrong = <String>[];
    final undescribed = <String>[];

    void scan(String where, Object? node) {
      if (node is Map) {
        for (final e in node.entries) {
          if (e.value is String && (e.key == 'description' || e.key == 'title')) {
            for (final m in order.allMatches(e.value as String)) {
              if (m.group(0)!.toLowerCase().replaceAll(RegExp(r'\s'), '') != '[pitch,roll,yaw]') wrong.add('$where: ${m.group(0)}');
            }
          }
          if (e.key == 'properties' && e.value is Map) {
            for (final p in (e.value as Map).entries) {
              final name = p.key as String;
              final schema = p.value as Map;
              if ((name == 'rotation' || name.endsWith('_rotation')) && schema['type'] == 'array') {
                final text = schema['description'] as String? ?? '';
                final named = text.contains(kMcpRotationConvention) ||
                    text.contains(kMcpBoneRotationConvention) ||
                    RegExp(r'\[x, y, z\]').hasMatch(text);
                if (!named) undescribed.add('$where.$name: $text');
              }
            }
          }
          scan('$where.${e.key}', e.value);
        }
      } else if (node is List) {
        for (var i = 0; i < node.length; i++) {
          scan('$where[$i]', node[i]);
        }
      }
    }

    for (final t in tools) {
      scan(t['name'] as String, t);
    }
    expect(wrong, isEmpty, reason: 'rotation orders other than [pitch, roll, yaw]');
    expect(undescribed, isEmpty, reason: 'rotation arguments that do not say what their three numbers are');
    // The convention itself says which way yaw and pitch turn.
    expect(kMcpRotationConvention, allOf(contains('[pitch, roll, yaw]'), contains('yaw 90 faces +X'), contains('pitch looks up')));
    for (final name in ['spawn_actor', 'set_actor_transform', 'set_actors_transform', 'set_blueprint_component_transform']) {
      final t = tools.firstWhere((t) => t['name'] == name);
      final rotation = (((t['inputSchema'] as Map)['properties'] as Map)['rotation'] as Map)['description'] as String;
      expect(rotation, contains(kMcpRotationConvention), reason: name);
    }
  });

  test('a level actor turned through spawn_actor, set_actor_transform and set_actors_transform faces the named way',
      () async {
    final spawned = (await ok('spawn_actor', {'type': 'PointLight', 'rotation': [0, 0, 90]}))['actor'] as Map;
    final id = spawned['id'] as String;
    final stored = vm.actors.firstWhere((a) => a.id == id).rotation;
    expect(stored, [0.0, 0.0, 90.0]);
    expectForward(stored, [1, 0, 0], 'spawn_actor yaw 90');

    await ok('set_actor_transform', {'id': id, 'rotation': [30, 0, -90]});
    final pitched = vm.actors.firstWhere((a) => a.id == id).rotation;
    expect(pitched, [30.0, 0.0, -90.0]);
    expectForward(pitched, [-0.8660254037844387, 0, 0.5], 'set_actor_transform pitch 30, yaw -90');

    await ok('set_actors_transform', {'ids': [id], 'rotation': [0, 0, 180]});
    final turned = vm.actors.firstWhere((a) => a.id == id).rotation;
    expectForward(turned, [0, -1, 0], 'set_actors_transform yaw 180');

    final read = await ok('get_actor', {'id': id});
    expect((read['rotation'] as List).cast<num>().map((v) => v.toDouble()), [0.0, 0.0, 180.0]);
  });

  test('a Blueprint component turned through set_blueprint_component_transform faces the named way in the game',
      () async {
    await ok('create_asset', {'type': 'actor', 'name': 'BP_Pointer', 'parent_class': 'LuminaActor'});
    final added = (await ok('add_blueprint_component', {'asset': blueprint, 'type': 'LuminaSceneComponent'}))['component'] as Map;
    final component = added['id'] as String;
    await ok('set_blueprint_component_transform', {'asset': blueprint, 'component': component, 'rotation': [0, 0, 90]});
    final editor = vm.editorSessionFor(vm.openTabs.firstWhere((t) => t.id.endsWith('BP_Pointer.lmas')).id)
        as BlueprintEditorViewModel;
    expect(editor.getComponent(component)!.properties['rotation'], [0.0, 0.0, 90.0]);

    // What the game builds from the Blueprint: the component faces +X.
    final cls = LuminaBlueprintClass.fromDocument(editor.document, name: 'BP_Pointer');
    final actor = cls.instantiate(location: Vector3.zero()) as LuminaBlueprintRuntime;
    final built = actor.blueprintComponents[component] as LuminaSceneComponent;
    final f = forwardOf(built.worldRotation);
    for (var i = 0; i < 3; i++) {
      expect(f[i], closeTo([1.0, 0.0, 0.0][i], 1e-6), reason: 'component forward $f');
    }
    expect(LuminaBlueprintFunctionLibrary.getRelativeRotation(built).yaw, closeTo(90, 1e-6));
  });
}
