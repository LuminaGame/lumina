import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';

import '../helpers/mcp_test_client.dart';
import '../helpers/temp_project.dart';

/// A real "probe" plugin that registers MCP tools and keeps its
/// `context.mcp` to call tools in process.
class _ProbePlugin extends LuminaEditorPlugin {
  late EditorMcp mcp;
  late EditorLevelAccess level;
  bool addBadTools = false;

  @override
  String get pluginName => 'probe';

  @override
  void register(LuminaEditorContext context) {
    mcp = context.mcp;
    level = (context as LuminaEditorHostContext).level;
    mcp.registerTool(McpTool(
      name: 'count_actors',
      description: 'How many actors the open level holds.',
      inputSchema: McpSchema.object({}),
      handler: (_) => McpToolResult.json({'count': level.actors.length}),
      risk: McpToolRisk.readOnly,
      groups: {McpToolGroups.level},
    ));
    if (addBadTools) {
      mcp.registerTool(McpTool(
        name: 'odd',
        description: 'An unknown group.',
        inputSchema: McpSchema.object({}),
        handler: (_) => McpToolResult.text('x'),
        risk: McpToolRisk.readOnly,
        groups: {'nonsense'},
      ));
      mcp.registerTool(McpTool(
        name: 'restart',
        description: 'Wraps a forbidden entry point.',
        inputSchema: McpSchema.object({}),
        handler: (_) => McpToolResult.text('x'),
        risk: McpToolRisk.external,
        groups: {McpToolGroups.core},
        wraps: {'editor.restart'},
      ));
    }
  }

  @override
  void unregister(LuminaEditorContext context) {}
}

class _DenyMutating implements McpApprovalPolicy {
  final List<McpCallContext> seen = [];
  @override
  McpApprovalDecision review(McpCallContext call) {
    seen.add(call);
    return call.risk <= McpToolRisk.editorState ? const McpApprovalDecision.allow() : const McpApprovalDecision.deny('probe policy: read only');
  }
}

void main() {
  late Directory root;
  late EditorViewModel vm;
  late _ProbePlugin plugin;
  const levelPath = 'contents/levels/L_Main.lmas';

  setUp(() async {
    root = Directory.systemTemp.createTempSync('lumina_plugins13_');
    final projectDir = Directory('${root.path}/McpGame')..createSync();
    const project = LuminaProject(projectName: 'McpGame', activeLevel: levelPath);
    File('${projectDir.path}/McpGame.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
    Directory('${projectDir.path}/contents/levels').createSync(recursive: true);
    vm = EditorViewModel(initialProject: project, projectLocation: root.path, enableTimers: false, autoInitAssets: false);
    plugin = _ProbePlugin();
    vm.extensionRegistry.registerPlugin(plugin);
  });

  tearDown(() async {
    await vm.mcpServer.stop();
    await vm.close();
    await deleteTempProject(root);
  });

  test('a plugin tool is listed as <plugin>.<name> in the plugin group; bad ones are refused; re-registering replaces', () {
    final tool = vm.mcpServer.tools.byName('probe.count_actors');
    expect(tool, isNotNull);
    expect(tool!.groups, {McpToolGroups.level, McpToolGroups.plugin});
    expect(plugin.mcp.listTools(groups: {McpToolGroups.plugin}).map((t) => t.name), contains('probe.count_actors'));

    final again = _ProbePlugin()..addBadTools = true;
    vm.extensionRegistry.registerPlugin(again);
    expect(vm.mcpServer.tools.byName('probe.odd'), isNull);
    expect(vm.mcpServer.tools.byName('probe.restart'), isNull);
    final errors = vm.logger.logs.where((l) => l.level == 'error' && l.message.contains('Plugin probe')).map((l) => l.message).toList();
    expect(errors.any((m) => m.contains('nonsense')), isTrue, reason: errors.join('\n'));
    expect(errors.any((m) => m.contains('editor.restart')), isTrue, reason: errors.join('\n'));
    expect(vm.mcpServer.tools.tools.where((t) => t.name == 'probe.count_actors'), hasLength(1), reason: 'replaced, not doubled');
  });

  test('in process: a plugin tool and a host tool run with real data; bad arguments throw', () async {
    await vm.ensureDefaultLevelAssets();
    final count = await plugin.mcp.callTool('probe.count_actors', {});
    expect(count.structuredContent!['count'], vm.actors.length);
    final listed = await plugin.mcp.callTool('list_actors', {});
    expect(listed.isError, isFalse);
    for (final a in vm.actors) {
      expect(jsonEncode(listed.structuredContent), contains(a.name));
    }
    expect(() => plugin.mcp.callTool('spawn_actor', {'location': 'here'}), throwsA(isA<JsonRpcException>()));
  });

  test('in process calls pass the approval chain as inProcess, and every call is reported', () async {
    await vm.ensureDefaultLevelAssets();
    final policy = _DenyMutating();
    vm.mcpServer.tools.approvalPolicies.add(policy);
    final events = <McpToolCallEvent>[];
    final sub = plugin.mcp.calls.listen(events.add);
    addTearDown(sub.cancel);
    final before = vm.actors.length;

    final denied = await plugin.mcp.callTool('spawn_actor', {'type': 'PointLight'}, caller: 'miniai-chat-1');
    expect(denied.isError, isTrue);
    expect(denied.deniedReason, 'probe policy: read only');
    expect(vm.actors.length, before, reason: 'the level is unchanged');
    expect(policy.seen.last.transport, McpTransport.inProcess);
    expect(policy.seen.last.clientName, 'miniai-chat-1');
    expect(policy.seen.last.risk, McpToolRisk.mutating);

    await plugin.mcp.callTool('probe.count_actors', {});
    await Future<void>.delayed(Duration.zero);
    expect(events.map((e) => (e.tool, e.denied, e.caller)), [('spawn_actor', true, 'miniai-chat-1'), ('probe.count_actors', false, 'probe')]);
  });

  test('an in-process spawn of a real barrel is one MCP undo step; undo removes it', () async {
    final glb = File('${Directory.current.parent.path}/test-assets/Props/Barrels/dented_barrel.glb');
    if (!glb.existsSync()) {
      markTestSkipped('test-assets not present');
      return;
    }
    await vm.ensureDefaultLevelAssets();
    await vm.processImportPipeline(sourceFilePath: glb.path);
    final mesh = vm.realAssets.firstWhere((a) => a.type == AssetType.filamesh && a.fileName.contains('dented_barrel'));
    final before = vm.actors.length;
    final placed = await plugin.mcp.callTool('spawn_actor_from_asset', {'asset': mesh.relativePath, 'location': [0, 0, 0]});
    expect(placed.isError, isFalse, reason: '${placed.content}');
    expect(vm.actors.length, before + 1);
    expect(vm.transactions.undoLabel, startsWith('Undo MCP: '));
    expect(vm.transactions.undoTopOrigin!.clientName, 'probe');
    expect(vm.transactions.undoTopOrigin!.tool, 'spawn_actor_from_asset');
    vm.commands.execute('edit.undo');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(vm.actors.length, before);
  });

  // Plugin transactions × plugin MCP tools: MiniAI runs a whole assistant turn — several in-process
  // tool calls — inside runTransaction; the turn must be one undo step.
  test('in-process calls inside runTransaction are one undo step labelled by the group', () async {
    final glb = File('${Directory.current.parent.path}/test-assets/Props/Barrels/dented_barrel.glb');
    if (!glb.existsSync()) {
      markTestSkipped('test-assets not present');
      return;
    }
    await vm.ensureDefaultLevelAssets();
    await vm.processImportPipeline(sourceFilePath: glb.path);
    final mesh = vm.realAssets.firstWhere((a) => a.type == AssetType.filamesh && a.fileName.contains('dented_barrel'));
    final before = vm.actors.length;
    await plugin.level.runTransaction('AI: place two barrels', () async {
      for (final x in [0, 300]) {
        final r = await plugin.mcp.callTool('spawn_actor_from_asset', {'asset': mesh.relativePath, 'location': [x, 0, 0]}, caller: 'miniai:chat-1');
        expect(r.isError, isFalse, reason: '${r.content}');
      }
    });
    expect(vm.actors.length, before + 2);
    expect(vm.transactions.undoLabel, 'Undo AI: place two barrels');
    expect(vm.transactions.undoTopOrigin!.clientName, 'miniai:chat-1', reason: 'the step keeps the agent attribution');
    vm.commands.execute('edit.undo');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(vm.actors.length, before, reason: 'one Undo took both');
  });

  test('over HTTP an external agent lists and calls the plugin tool', () async {
    final server = vm.mcpServer;
    expect(await server.start(port: 0), isTrue);
    final client = McpTestClient(server.url!, server.token);
    addTearDown(client.close);
    await client.handshake();
    final list = await client.post({'jsonrpc': '2.0', 'id': 2, 'method': 'tools/list'});
    final names = [for (final t in (((list.json as Map)['result'] as Map)['tools'] as List)) (t as Map)['name']];
    expect(names, contains('probe.count_actors'));
    final reply = await client.callTool('probe.count_actors');
    expect(reply.isError, isFalse, reason: reply.text);
    expect(reply.data['count'], vm.actors.length);
  });
}
