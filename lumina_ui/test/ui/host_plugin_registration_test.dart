import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:lumina_plugin_miniai/lumina_plugin_miniai.dart';
import 'package:lumina_ui/ui/core/host/editor_host.dart';
import 'package:lumina_ui/ui/core/services/user_plugin_dir.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' show LucideIcons, Text;

import '../helpers/temp_project.dart';

/// Reads its panels' visibility inside `register()`, as a plugin building a
/// toolbar button that follows its panel does.
class _VisibilityPlugin extends LuminaEditorPlugin {
  late ValueListenable<bool> chat;
  late ValueListenable<bool> log;

  @override
  String get pluginName => 'visibility_probe';

  @override
  void register(LuminaEditorContext context) {
    context.registerPanel(EditorPanelDescriptor(
      id: 'visibility_probe.chat',
      title: 'Probe Chat',
      icon: LucideIcons.messageSquare,
      defaultDock: PanelDefaultDock.right,
      builder: (_) => const Text('chat'),
    ));
    context.registerPanel(EditorPanelDescriptor(
      id: 'visibility_probe.log',
      title: 'Probe Log',
      icon: LucideIcons.list,
      defaultDock: PanelDefaultDock.bottom,
      builder: (_) => const Text('log'),
    ));
    chat = context.panels.visibility('visibility_probe.chat');
    log = context.panels.visibility('visibility_probe.log');
  }

  @override
  void unregister(LuminaEditorContext context) {}
}

/// Contributes a menu item and a panel, then fails.
class _ThrowingPlugin extends LuminaEditorPlugin {
  @override
  String get pluginName => 'throwing_probe';

  @override
  void register(LuminaEditorContext context) {
    context.registerPanel(EditorPanelDescriptor(
      id: 'throwing_probe.panel',
      title: 'Throwing Panel',
      icon: LucideIcons.list,
      defaultDock: PanelDefaultDock.right,
      builder: (_) => const Text('never'),
    ));
    context.registerMenuItem(
      'Plugins/Throwing/Item',
      EditorCommand(id: 'throwing_probe.item', label: 'Item', canExecute: () => true, execute: (_) {}),
    );
    throw StateError('probe failure during register');
  }

  @override
  void unregister(LuminaEditorContext context) {}
}

/// The code plugins compiled into a project editor register while the
/// editor view model is constructed; they see the saved layout, and one
/// failing plugin leaves the editor usable.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late Directory projectDir;
  const project = LuminaProject(projectName: 'HostPlugins', activeLevel: 'contents/levels/L_Main.lmas');
  EditorViewModel? vm;

  setUp(() {
    root = Directory.systemTemp.createTempSync('lumina_host_plugins_');
    projectDir = Directory('${root.path}/HostPlugins')..createSync();
    File('${projectDir.path}/HostPlugins.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
    PluginDataDir.override = Directory('${root.path}/plugin_data');
  });

  tearDown(() async {
    LuminaEditorHost.plugins = const [];
    PluginDataDir.override = null;
    await vm?.close();
    vm = null;
    await deleteTempProject(root);
  });

  void writeLayout(Map<String, Object?> json) {
    File('${projectDir.path}/.lumina/editor_layout.json')
      ..createSync(recursive: true)
      ..writeAsStringSync(jsonEncode(json));
  }

  EditorViewModel boot() =>
      vm = EditorViewModel(initialProject: project, projectLocation: root.path, enableTimers: false, autoInitAssets: false);

  test('a host plugin reading panel visibility in register() sees the saved layout', () {
    writeLayout({
      'pluginPanelVisible': {'visibility_probe.chat': true},
      'activeRightPanel': 'visibility_probe.chat',
      'bottomVisible': true,
      'activeBottomTab': 0,
    });
    final plugin = _VisibilityPlugin();
    LuminaEditorHost.plugins = [plugin];

    final editor = boot();

    expect(editor.extensionRegistry.registeredPlugins, contains(plugin));
    expect(plugin.chat.value, isTrue, reason: 'the saved layout has the right-dock panel open');
    expect(plugin.log.value, isFalse, reason: 'the bottom panel shows the Content Browser tab');
    expect(editor.isPluginPanelShowing('visibility_probe.chat'), isTrue);

    // The notifiers keep following the layout.
    editor.panelsController.hide('visibility_probe.chat');
    expect(plugin.chat.value, isFalse);
    editor.showPluginPanel('visibility_probe.log');
    expect(plugin.log.value, isTrue);
    expect(editor.layoutState.activeBottomTab, kBuiltInBottomTabs);
  });

  test('a host plugin showing its panel in register() keeps it shown after the layout loads', () {
    writeLayout({'pluginPanelVisible': <String, bool>{}});
    LuminaEditorHost.plugins = [_ShowOnRegisterPlugin()];

    final editor = boot();

    expect(editor.isPluginPanelShowing('show_probe.panel'), isTrue);
    expect(editor.layoutState.pluginPanelVisible['show_probe.panel'], isTrue);
    final saved = jsonDecode(File('${projectDir.path}/.lumina/editor_layout.json').readAsStringSync()) as Map;
    expect((saved['pluginPanelVisible'] as Map)['show_probe.panel'], isTrue, reason: 'the show was saved into the project layout');
  });

  test('the real MiniAI plugin registers as a host plugin and its panel follows the saved layout', () {
    writeLayout({
      'pluginPanelVisible': {LuminaPluginMiniaiPlugin.chatPanelId: true},
      'activeRightPanel': LuminaPluginMiniaiPlugin.chatPanelId,
    });
    final plugin = LuminaPluginMiniaiPlugin();
    LuminaEditorHost.plugins = [plugin];

    final editor = boot();

    expect(editor.extensionRegistry.registeredPlugins, contains(plugin));
    expect(editor.extensionRegistry.allPanels.map((p) => p.id), contains(LuminaPluginMiniaiPlugin.chatPanelId));
    expect(editor.panelsController.visibility(LuminaPluginMiniaiPlugin.chatPanelId).value, isTrue);
    final button = editor.extensionRegistry.slotButtons(EditorSlot.levelToolbarAfterBlueprints).where((b) => b.plugin == plugin.pluginName);
    expect(button, hasLength(1));
    expect(button.single.button.state.value.active, isTrue, reason: 'the AI button follows the open chat panel');
    expect(editor.logs.any((l) => l.message == 'Registered code plugin lumina_plugin_miniai'), isTrue);
  });

  test('a host plugin that throws in register() leaves the editor usable and records the error', () async {
    // Installed in the project, so the Plugin Manager lists it.
    File('${projectDir.path}/plugins/throwing_probe/throwing_probe.lmplugin')
      ..createSync(recursive: true)
      ..writeAsStringSync(jsonEncode({
        'name': 'throwing_probe',
        'version': '1.0.0',
        'modules': [{'name': 'M', 'type': 'editor', 'entry_library': 'm.dart', 'registration_class': 'MC'}],
      }));
    final good = _VisibilityPlugin();
    LuminaEditorHost.plugins = [_ThrowingPlugin(), good];

    final editor = boot();

    // The other plugin registered; the failing one left nothing behind.
    expect(editor.extensionRegistry.registeredPlugins, [good]);
    expect(editor.extensionRegistry.allPanels.map((p) => p.id), isNot(contains('throwing_probe.panel')));
    expect(editor.extensionRegistry.allMenuCommands.map((e) => e.value.id), isNot(contains('throwing_probe.item')));
    expect(editor.extensionRegistry.registrationErrorOf('throwing_probe'), contains('probe failure during register'));

    // Output Log, with the plugin's name.
    final logged = editor.logs.where((l) => l.level == 'error' && l.message.contains('throwing_probe'));
    expect(logged, isNotEmpty);
    expect(logged.first.message, contains('probe failure during register'));
    expect(editor.logs.any((l) => l.message == 'Registered code plugin throwing_probe'), isFalse);

    // The Plugin Manager shows it as that plugin's issue.
    await editor.pluginsScanned;
    final entry = editor.pluginRegistry.entries.firstWhere((e) => e.descriptor.name == 'throwing_probe');
    expect(entry.issues.map((i) => i.type), contains(PluginIssueType.registrationFailed));
    expect(entry.issues.firstWhere((i) => i.type == PluginIssueType.registrationFailed).message, contains('probe failure during register'));

    // The editor still works.
    editor.showPluginPanel('visibility_probe.chat');
    expect(good.chat.value, isTrue);
  });
}

class _ShowOnRegisterPlugin extends LuminaEditorPlugin {
  @override
  String get pluginName => 'show_probe';

  @override
  void register(LuminaEditorContext context) {
    context.registerPanel(EditorPanelDescriptor(
      id: 'show_probe.panel',
      title: 'Show Probe',
      icon: LucideIcons.list,
      defaultDock: PanelDefaultDock.right,
      builder: (_) => const Text('show'),
    ));
    context.panels.show('show_probe.panel');
  }

  @override
  void unregister(LuminaEditorContext context) {}
}
