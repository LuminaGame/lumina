import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_server_service.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_server_settings.dart';
import 'package:path/path.dart' as p;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../helpers/mcp_test_client.dart';
import 'editor_panels/editor_panel_fixture.dart';

/// Editor panels over a real MCP client against a real editor: listing with
/// trust and errors, clicking an element through `editor_panel_interact`
/// and reading `editor_panel_state`, an "Expose to MCP" custom event as its
/// own tool, an untrusted panel exposing nothing, and a PNG of a docked
/// panel.
void main() {
  late EditorPanelProject project;
  late EditorViewModel vm;
  late McpServerService server;
  late McpTestClient client;
  const batchId = 'project/contents/editor/EPW_BatchRename.lmas';
  const strangerId = 'project/contents/editor/EPW_Stranger.lmas';
  const pluginId = 'prop_tools/content/EPW_PropTools.lmas';

  void setStatus(EpwBuilder b, String id, {String? text}) {
    b.node(LuminaBlueprintNodeLibrary.getWidgetVariable, '${id}_get', {'element': 'StatusText'});
    b.node('set_element_text', id, {'in_text': ?text});
    b.wire('${id}_get', 'return_value', id, 'target');
  }

  EpwBuilder batchRename() {
    final b = EpwBuilder('EPW_BatchRename',
        LuminaEditorPanelInfo(title: 'Batch Rename', dock: LuminaEditorPanelDock.right, capabilities: {LuminaEditorPanelCapability.mcp}));
    b.element(UmgWidgetType.text, 'StatusText', props: {'text': 'Idle'});
    b.element(UmgWidgetType.button, 'RenameButton', props: {'label': 'Rename'});
    b.onElement('click', 'RenameButton', 'OnClicked');
    setStatus(b, 'renamed', text: 'Renamed by click');
    b.chain(['click', 'renamed']);
    // RenameSelected (Prefix) — exposed to MCP.
    b.customEvent('exposed', 'RenameSelected', ['Prefix'], {'exposeToMcp': true, 'mcpDescription': 'Renames with Prefix.'});
    setStatus(b, 'prefixed');
    b.chain(['exposed', 'prefixed']);
    b.wire('exposed', 'Prefix', 'prefixed', 'in_text');
    return b;
  }

  EpwBuilder stranger() {
    final b = EpwBuilder('EPW_Stranger',
        LuminaEditorPanelInfo(title: 'Stranger', dock: LuminaEditorPanelDock.right, capabilities: {LuminaEditorPanelCapability.mcp}));
    b.element(UmgWidgetType.text, 'StatusText', props: {'text': 'Idle'});
    b.customEvent('hidden', 'Hidden', const [], {'exposeToMcp': true});
    setStatus(b, 'h', text: 'ran');
    b.chain(['hidden', 'h']);
    return b;
  }

  setUp(() async {
    project = await EditorPanelProject.create('McpPanels', plugins: ['prop_tools']);
    await batchRename().writeTo(project.projectPath('contents/editor/EPW_BatchRename.lmas'));
    await stranger().writeTo(project.projectPath('contents/editor/EPW_Stranger.lmas'));
    final plugin = project.writePlugin('prop_tools', friendlyName: 'Prop Tools');
    final tools = EpwBuilder('EPW_PropTools', LuminaEditorPanelInfo(title: 'Prop Tools', dock: LuminaEditorPanelDock.right));
    tools.element(UmgWidgetType.text, 'Hello', props: {'text': 'hello'});
    await tools.writeTo(p.join(plugin.path, 'content', 'EPW_PropTools.lmas'));
    vm = await project.open();
    await EditorPanelProject.startPanels(vm);
    await until(() => vm.editorPanels.panels.length == 3, reason: 'the three panels');
    await vm.editorPanels.trustProjectPanels([batchId]);
    final configDir = Directory(p.join(project.root.path, 'mcp'))..createSync();
    server = McpServerService(vm, configDir: configDir, settings: McpServerSettings.load(configDir: configDir));
    expect(await server.start(port: 0), isTrue);
    client = McpTestClient(server.url!, server.token);
    await client.handshake();
  });

  tearDown(() async {
    client.close();
    await server.stop();
    await vm.close();
    await project.dispose();
  });

  Future<Map<String, Object?>> ok(String tool, [Map<String, Object?> args = const {}]) async {
    final r = await client.callTool(tool, args);
    expect(r.isError, isFalse, reason: '$tool: ${r.text}');
    return r.data;
  }

  test('editor_panels_list lists the panels with their trust, owner and errors', () async {
    final panels = {for (final p in (await ok('editor_panels_list'))['panels'] as List) (p as Map)['id']: p};
    expect(panels.keys, containsAll([batchId, strangerId, pluginId]));
    expect(panels[batchId]!['trusted'], isTrue);
    expect(panels[strangerId]!['trusted'], isFalse);
    expect(panels[pluginId]!['trusted'], isTrue, reason: 'trusted with its plugin');
    expect(panels[pluginId]!['owner'], 'prop_tools');
    expect(panels[batchId]!['capabilities'], ['mcp']);
    expect(panels[batchId]!['errors'], isEmpty);
    expect(panels[batchId]!['dock'], 'right');
  });

  test('editor_panel_interact clicks RenameButton through the graph; editor_panel_state shows the new status', () async {
    await ok('editor_panel_open', {'panel': batchId});
    await ok('editor_panel_interact', {'panel': batchId, 'element': 'RenameButton', 'action': 'click'});
    final state = await ok('editor_panel_state', {'panel': batchId});
    expect(((state['elements'] as Map)['StatusText'] as Map)['text'], 'Renamed by click');
  });

  test('an "Expose to MCP" event is a tool typed from its inputs; an untrusted panel exposes nothing', () async {
    final tools = {for (final t in await client.listTools()) t['name']: t};
    final exposed = tools['panel_project_RenameSelected'];
    expect(exposed, isNotNull);
    final schema = exposed!['inputSchema'] as Map;
    expect(((schema['properties'] as Map)['Prefix'] as Map)['type'], 'string');
    expect(schema['required'], ['Prefix']);
    expect(tools.containsKey('panel_project_Hidden'), isFalse, reason: 'the Stranger panel is not trusted');
    final state = await ok('panel_project_RenameSelected', {'Prefix': 'SM_'});
    expect(((state['elements'] as Map)['StatusText'] as Map)['text'], 'SM_');
    // Trusted later: its event becomes a tool too.
    await vm.editorPanels.trustProjectPanels([strangerId]);
    final after = {for (final t in await client.listTools()) t['name']};
    expect(after, contains('panel_project_Hidden'));
  });

  testWidgets('editor_panel_screenshot is a PNG of the docked panel', (tester) async {
    tester.view.physicalSize = const Size(2000, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)));
    await tester.pump(const Duration(milliseconds: 300));
    vm.editorPanelDocking.open(batchId);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    McpToolReply? reply;
    await tester.runAsync(() async {
      client.callTool('editor_panel_screenshot', {'panel': batchId, 'max_width': 600}).then((r) => reply = r);
    });
    for (var i = 0; i < 400 && reply == null; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    }
    expect(reply, isNotNull);
    expect(reply!.isError, isFalse, reason: reply!.text);
    final image = reply!.content.firstWhere((c) => c['type'] == 'image');
    final png = base64Decode(image['data'] as String);
    expect(png.sublist(1, 4), utf8.encode('PNG'));
    expect(reply!.data['panel'], batchId);
    vm.editorPanelDocking.close(batchId);
    await tester.pumpWidget(const SizedBox());
  });
}
