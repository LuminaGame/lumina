// A plugin that drives an external agent (MiniAI's Claude Code provider)
// binds the agent's tagged MCP session to one of its own callers: while the
// binding holds, the session's HTTP calls run as that caller, inside the
// plugin's transaction.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:lumina_ui/ui/core/editor_level_access.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/host_editor_mcp.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_server_service.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_server_settings.dart';

import '../helpers/mcp_test_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late Directory configDir;
  late EditorViewModel vm;
  late McpServerService server;
  late EditorMcp mcp;
  late EditorViewModelLevelAccess level;

  setUp(() async {
    root = Directory.systemTemp.createTempSync('lumina_mcp_attr_');
    configDir = Directory('${root.path}/config')..createSync();
    final projectDir = Directory('${root.path}/Projects/AttrProject')..createSync(recursive: true);
    const project = LuminaProject(projectName: 'AttrProject', activeLevel: 'contents/levels/L_Main.lmas');
    File('${projectDir.path}/AttrProject.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
    Directory('${projectDir.path}/contents/levels').createSync(recursive: true);
    vm = EditorViewModel(initialProject: project, projectLocation: '${root.path}/Projects', enableTimers: false, autoInitAssets: false);
    server = McpServerService(vm, configDir: configDir, settings: McpServerSettings.load(configDir: configDir));
    expect(await server.start(port: 0), isTrue);
    mcp = HostEditorMcp(server.tools, launch: () => server.clientLaunch).scoped('lumina_plugin_miniai');
    level = EditorViewModelLevelAccess(vm);
  });

  tearDown(() async {
    await server.stop();
    await vm.close();
    try {
      root.deleteSync(recursive: true);
    } catch (_) {}
  });

  test('the host attributes external calls and says so', () {
    expect(mcp.attributesExternalCalls, isTrue);
    expect(EditorMcp.detached().attributesExternalCalls, isFalse);
  });

  test('clientLaunch carries the config directory the bridge must read', () {
    expect(server.clientLaunch.environment['LUMINA_CONFIG_DIR'], configDir.path);
  });

  test('a tagged session inside the binding: one undo step for the turn, snapshots under the turn caller', () async {
    final client = McpTestClient('${server.url}?caller=cc-chat1', server.token);
    addTearDown(client.close);
    await client.handshake(clientName: 'claude-code');
    await level.runTransaction('AI: two lights', () async {
      await mcp.attributeExternalCalls('cc-chat1', 'miniai:chat1:1', () async {
        expect((await client.callTool('spawn_actor', {'type': 'PointLight'})).isError, isFalse);
        expect((await client.callTool('spawn_actor', {'type': 'SpotLight'})).isError, isFalse);
        final w = await client.callTool('fs_write', {'path': 'lib/agent/note.dart', 'content': '// note\n'});
        expect(w.isError, isFalse, reason: w.text);
      });
    });
    expect(level.undoTopLabel, 'AI: two lights', reason: 'both spawns are one step');
    final history = await client.callTool('fs_history', {'caller': 'miniai:chat1:1'});
    final snapshots = (history.data['snapshots'] as List).cast<Map>();
    expect(snapshots.map((s) => s['path']), ['lib/agent/note.dart']);
    expect(level.undoIfTop('AI: two lights'), isTrue);
    expect(vm.actors.where((a) => a.type == 'PointLight' || a.type == 'SpotLight'), isEmpty);
  });

  test('outside the binding, or with another tag, the session is not attributed', () async {
    final tagged = McpTestClient('${server.url}?caller=cc-chat1', server.token);
    final other = McpTestClient('${server.url}?caller=cc-other', server.token);
    addTearDown(tagged.close);
    addTearDown(other.close);
    await tagged.handshake(clientName: 'claude-code');
    await other.handshake(clientName: 'claude-code');
    await tagged.callTool('fs_write', {'path': 'lib/before.dart', 'content': '// before\n'});
    await mcp.attributeExternalCalls('cc-chat1', 'miniai:chat1:2', () async {
      await other.callTool('fs_write', {'path': 'lib/other.dart', 'content': '// other\n'});
    });
    await tagged.callTool('fs_write', {'path': 'lib/after.dart', 'content': '// after\n'});
    final history = await tagged.callTool('fs_history', {'caller_prefix': 'miniai:'});
    expect(history.data['snapshots'], isEmpty);
    // An in-process call still records its caller.
    await mcp.callTool('fs_write', {'path': 'lib/in_process.dart', 'content': '// ip\n'}, caller: 'miniai:chat1:3');
    final inProcess = await tagged.callTool('fs_history', {'caller': 'miniai:chat1:3'});
    expect((inProcess.data['snapshots'] as List).single['path'], 'lib/in_process.dart');
  });
}
