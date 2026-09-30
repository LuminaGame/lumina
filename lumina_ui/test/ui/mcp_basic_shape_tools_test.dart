import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_server_service.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_server_settings.dart';

import '../helpers/mcp_test_client.dart';
import '../helpers/temp_project.dart';

/// A basic shape (`Primitive`) spawned over MCP is the size the editor's own
/// Place Actors ▸ Cube gives it, in centimetres, and the tools say so — a real
/// editor on a real temp project, over a real MCP client.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const levelPath = 'contents/levels/L_Main.lmas';

  late Directory root;
  late EditorViewModel vm;
  late McpServerService server;
  late McpTestClient client;

  setUp(() async {
    root = Directory.systemTemp.createTempSync('lumina_mcp_shape_');
    final configDir = Directory('${root.path}/config')..createSync();
    final projectDir = Directory('${root.path}/ShapeProject')..createSync();
    const project = LuminaProject(projectName: 'ShapeProject', activeLevel: levelPath);
    File('${projectDir.path}/ShapeProject.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
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

  Map<String, dynamic> shapeProperties(EditorActorNode actor) =>
      actor.components.firstWhere((c) => c.type == 'LuminaProceduralMeshComponent').properties;

  test('spawn_actor "Primitive" makes a 100 cm cube, as Place Actors does, and its tools state the unit', () async {
    final spawned = await ok('spawn_actor', {'type': 'Primitive', 'name': 'Crate', 'location': [0, 0, 50]});
    final id = (spawned['actor'] as Map)['id'] as String;
    final actor = vm.actors.firstWhere((a) => a.id == id);
    final props = shapeProperties(actor);
    expect([props['sizeX'], props['sizeY'], props['sizeZ']], [100.0, 100.0, 100.0],
        reason: 'one world unit is one centimetre: a 1.0 cube is 1 cm and cannot be seen');

    await vm.ensureActorMeshDataForTest(actor);
    final mesh = actor.meshData!;
    for (var axis = 0; axis < 3; axis++) {
      expect(mesh.maxBounds[axis] - mesh.minBounds[axis], closeTo(100.0, 1e-3), reason: 'the drawn cube spans 100 cm on axis $axis');
    }

    final tools = {for (final t in await client.listTools()) t['name']: t};
    final spawnDoc = jsonEncode(tools['spawn_actor']);
    expect(spawnDoc, contains('100 cm'), reason: 'spawn_actor states the default size of a basic shape');
    final types = await ok('list_actor_types');
    final primitive = (types['types'] as List).cast<Map>().firstWhere((t) => t['id'] == 'Primitive');
    expect(primitive['description'], contains('100 cm'));
  });
}
