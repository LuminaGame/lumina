import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_server_service.dart';

import '../helpers/temp_project.dart';

class _LaunchPlugin extends LuminaEditorPlugin {
  late EditorMcp mcp;

  @override
  String get pluginName => 'launch_probe';

  @override
  void register(LuminaEditorContext context) => mcp = context.mcp;
}

/// How an external MCP client starts the stdio bridge.
void main() {
  late Directory root;
  late EditorViewModel vm;

  setUp(() {
    root = Directory.systemTemp.createTempSync('lumina_mcp_launch_');
    final projectDir = Directory('${root.path}/LaunchGame')..createSync();
    const project = LuminaProject(projectName: 'LaunchGame', activeLevel: 'contents/levels/L_Main.lmas');
    File('${projectDir.path}/LaunchGame.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
    vm = EditorViewModel(initialProject: project, projectLocation: root.path, enableTimers: false, autoInitAssets: false);
  });

  tearDown(() async {
    await vm.close();
    await deleteTempProject(root);
  });

  test('the launch is a real Dart executable and the real bridge script; plugins see the same', () {
    final launch = vm.mcpServer.clientLaunch;
    expect(File(launch.command).existsSync(), isTrue, reason: launch.command);
    expect(launch.command.replaceAll(r'\', '/').split('/').last, Platform.isWindows ? 'dart.exe' : 'dart');
    expect(launch.args, hasLength(1));
    expect(launch.args.single, endsWith('lumina_mcp_bridge.dart'));
    expect(File(launch.args.single).existsSync(), isTrue);
    String norm(String path) => path.replaceAll(r'\', '/').toLowerCase();
    expect(norm(McpServerService.dartExecutable), norm(launch.command));

    final plugin = _LaunchPlugin();
    vm.extensionRegistry.registerPlugin(plugin);
    final seen = plugin.mcp.clientLaunch!;
    expect(seen.command, launch.command);
    expect(seen.args, launch.args);
    expect(EditorMcp.detached().clientLaunch, isNull);
  });
}
