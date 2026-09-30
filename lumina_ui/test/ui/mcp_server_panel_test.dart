import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_server_service.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_server_settings.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_tool.dart';
import 'package:lumina_ui/ui/features/mcp_server/views/mcp_server_panel.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../helpers/temp_project.dart';
import '../helpers/mcp_test_client.dart';

/// Tools → AI Agent Access (MCP), the panel over the real
/// server: status, port, the registration commands, copy, the switch.
void main() {
  late Directory root;
  late Directory configDir;
  late EditorViewModel vm;
  late McpServerService server;

  setUp(() {
    root = Directory.systemTemp.createTempSync('lumina_mcp_panel_test_');
    configDir = Directory('${root.path}/config')..createSync();
    const project = LuminaProject(projectName: 'PanelProject', activeLevel: 'contents/levels/L_Main.lmas');
    Directory('${root.path}/PanelProject').createSync();
    File('${root.path}/PanelProject/PanelProject.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
    vm = EditorViewModel(initialProject: project, projectLocation: root.path, enableTimers: false, autoInitAssets: false);
    server = McpServerService(vm, configDir: configDir, settings: McpServerSettings.load(configDir: configDir));
  });

  tearDown(() async {
    await server.stop();
    vm.dispose();
    // Windows frees the folder once the git probe exits.
    await deleteTempProject(root);
  });

  Future<void> pumpPanel(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: McpServerPanel(service: server)));
    await tester.pump();
  }

  testWidgets('shows LISTENING, the real port and both registration commands; copies the HTTP one', (tester) async {
    await tester.runAsync(() => server.start(port: 0));
    await pumpPanel(tester);

    expect(find.text('AI AGENT ACCESS (MCP)'), findsOneWidget);
    expect(find.text('LISTENING'), findsOneWidget);
    expect(find.text(server.url!), findsOneWidget);

    final http = tester.widget<SelectableText>(find.byKey(const ValueKey('mcp_server_command_http')));
    expect(http.data, contains('--transport http'));
    expect(http.data, contains('127.0.0.1:${server.port}/mcp'));
    // Masked until revealed.
    expect(http.data, isNot(contains(server.token)));
    await tester.tap(find.byKey(const ValueKey('mcp_server_reveal_token')));
    await tester.pump();
    final revealed = tester.widget<SelectableText>(find.byKey(const ValueKey('mcp_server_command_http')));
    expect(revealed.data, contains(server.token));

    final stdio = tester.widget<SelectableText>(find.byKey(const ValueKey('mcp_server_command_stdio')));
    expect(stdio.data, contains('lumina_mcp_bridge.dart'));

    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.tap(find.byKey(const ValueKey('mcp_server_copy_http')));
    await tester.pump();
    expect(copied, server.httpRegistrationCommand);
    expect(find.text('Copied'), findsOneWidget);
  });

  testWidgets('the switch stops and starts the server and persists the setting', (tester) async {
    await tester.runAsync(() => server.start(port: 0));
    await pumpPanel(tester);
    expect(server.settings.enabled, isTrue);

    await tester.tap(find.byKey(const ValueKey('mcp_server_enabled')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
    expect(server.settings.enabled, isFalse);
    expect(server.isRunning, isFalse);
    expect(find.text('STOPPED'), findsOneWidget);
    final saved = jsonDecode(File('${configDir.path}/${McpServerSettings.fileName}').readAsStringSync()) as Map;
    expect(saved['enabled'], isFalse);

    // Back on: the panel starts it on the settings' port, or an ephemeral one
    // when that port is taken by a running editor; either way it listens.
    await tester.tap(find.byKey(const ValueKey('mcp_server_enabled')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
    expect(server.settings.enabled, isTrue);
    expect(server.isRunning, isTrue);
    expect(find.text('LISTENING'), findsOneWidget);
    // The panel started this server inside the test's fake-async zone, so its
    // idle timer is a fake one: stop it before the body ends.
    await tester.runAsync(server.stop);
  });

  testWidgets('Recent calls lists each tools/call, a failing one marked as failed',(tester) async {
    await tester.runAsync(() async {
      await server.start(port: 0);
      final client = McpTestClient(server.url!, server.token);
      try {
        await client.handshake();
        await client.callTool('project_info');
        // Refused with -32602: recorded as a failed call.
        await expectLater(client.callTool('focus_actor', {'id': 'nobody'}), throwsA(isA<McpRpcError>()));
      } finally {
        client.close();
      }
    });
    await pumpPanel(tester);

    expect(server.recentCalls.map((c) => c.tool), containsAll(<String>['project_info', 'focus_actor']));
    expect(server.recentCalls.firstWhere((c) => c.tool == 'project_info').ok, isTrue);
    expect(server.recentCalls.firstWhere((c) => c.tool == 'focus_actor').ok, isFalse);
    await tester.ensureVisible(find.text('project_info'));
    expect(find.text('project_info'), findsOneWidget);
    expect(find.text('focus_actor'), findsOneWidget);
    expect(find.byIcon(LucideIcons.circleX), findsWidgets, reason: 'the failing call is marked');
    expect(find.byIcon(LucideIcons.circleCheck), findsWidgets);
    await tester.runAsync(server.stop);
  });

  testWidgets('Recent calls shows the job a call started and its state',(tester) async {
    await tester.runAsync(() async {
      await server.start(port: 0);
      final client = McpTestClient(server.url!, server.token);
      try {
        await client.handshake();
        final started = await client.callTool('set_widget_library', {'library': 'flutter'});
        expect(started.isError, isFalse, reason: started.text);
        await client.callTool('wait_job', {'id': started.data['job_id'], 'timeout_ms': 20000});
      } finally {
        client.close();
      }
    });
    await pumpPanel(tester);
    final row = server.recentCalls.indexWhere((c) => c.tool == 'set_widget_library');
    expect(server.recentCalls[row].jobId, 'job_1');
    final badge = find.byKey(ValueKey('mcp_recent_call_job_$row'));
    await tester.ensureVisible(badge);
    expect(tester.widget<Text>(find.descendant(of: badge, matching: find.byType(Text))).data, 'job_1 · succeeded');
    await tester.runAsync(server.stop);
  });

  testWidgets('Tools → AI Agent Access (MCP)... is a registered command that opens the tab', (tester) async {
    final command = vm.commands.byId('tools.aiAgentAccess');
    expect(command, isNotNull);
    expect(command!.label, 'AI Agent Access (MCP)...');
    expect(vm.openTabs.any((t) => t.category == 'mcpServer'), isFalse);
    vm.commands.execute('tools.aiAgentAccess');
    expect(vm.openTabs.any((t) => t.category == 'mcpServer' && t.title == 'AI Agent Access (MCP)'), isTrue);
    expect(vm.currentTab.category, 'mcpServer');
  });

  // The risk ceiling, the tool catalogue, denied calls and
  // the project trash.
  testWidgets('the risk ceiling persists and shrinks tools/list; the catalogue counts; a denial shows; Empty trash empties',
      (tester) async {
    tester.view.physicalSize = const Size(2000, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    late McpTestClient client;
    await tester.runAsync(() async {
      await server.start(port: 0);
      client = McpTestClient(server.url!, server.token);
      await client.handshake();
    });
    addTearDown(client.close);
    await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: Scaffold(child: McpServerPanel(service: server))));
    await tester.pump();

    expect(tester.widget<Text>(find.byKey(const ValueKey('mcp_catalogue_header'))).data,
        '374 tools · 70 read-only · 39 editor state · 234 edits · 24 destructive · 7 external');
    await tester.tap(find.byKey(const ValueKey('mcp_catalogue_group_asset')));
    await tester.pump();
    expect(find.byKey(const ValueKey('mcp_catalogue_tool_delete_asset')), findsOneWidget);

    late int everything;
    await tester.runAsync(() async => everything = (await client.listTools()).length);
    await tester.tap(find.byKey(const ValueKey('mcp_max_risk')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mcp_max_risk_editorState')));
    await tester.pumpAndSettle();
    expect(server.settings.maxRisk, McpToolRisk.editorState);
    final saved = jsonDecode(File('${configDir.path}/${McpServerSettings.fileName}').readAsStringSync()) as Map;
    expect(saved['max_risk'], 'editorState');
    late int lookOnly;
    await tester.runAsync(() async {
      lookOnly = (await client.listTools()).length;
      await client.callTool('spawn_actor', {'type': 'PointLight'});
    });
    expect(lookOnly, lessThan(everything));
    await tester.pump();
    expect(find.byKey(const ValueKey('mcp_recent_call_denied_0')), findsOneWidget, reason: 'the denied badge');

    // A trashed material, then Empty trash… → confirm.
    await tester.runAsync(() async {
      server.settings.setMaxRisk(McpToolRisk.external);
      await client.callTool('create_asset', {'type': 'filamat', 'name': 'M_Trash'});
      await client.callTool('delete_asset', {'asset': 'contents/materials/M_Trash.lmas'});
    });
    await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: Scaffold(child: McpServerPanel(key: UniqueKey(), service: server))));
    await tester.pump();
    expect(tester.widget<Text>(find.byKey(const ValueKey('mcp_trash_summary'))).data, startsWith('1 items'));
    await tester.tap(find.byKey(const ValueKey('mcp_empty_trash')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mcp_empty_trash_dialog')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('mcp_empty_trash_confirm')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const ValueKey('mcp_trash_summary'))).data, startsWith('0 items'));
    expect(Directory('${vm.projectDirPath}/.lumina/trash').existsSync(), isFalse);
    await tester.runAsync(server.stop);
  });
}
