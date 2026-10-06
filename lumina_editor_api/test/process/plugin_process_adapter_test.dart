import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart';

import 'support/loopback_host.dart';

const IconData _icon = IconData(0xe145, fontFamily: 'MaterialIcons');

/// A data-only plugin written against the in-process API, unchanged.
class _DataPlugin extends LuminaEditorPlugin {
  final ValueNotifier<EditorButtonState> button = ValueNotifier(const EditorButtonState(icon: _icon, tooltip: 'Ready'));
  final ValueNotifier<bool> checked = ValueNotifier(true);
  final List<String> calls = [];
  EditorLevelAccess? level;

  @override
  String get pluginName => 'sample';

  @override
  void register(LuminaEditorContext context) {
    calls.add('register');
    if (context is LuminaEditorHostContext) level = context.level;
    context.registerMenu(const EditorMenuDescriptor(id: 'data', title: 'Data', placement: EditorMenuPlacement.beforeHelp));
    context.registerMenuItem(
      'Data/Place',
      EditorCommand(
        id: 'data.place',
        label: 'Place',
        icon: _icon,
        canExecute: () => level != null,
        execute: (buildContext) async {
          calls.add('place:${buildContext == null}');
          await level!.addActors([const EditorActorSpec(name: 'Placed', type: 'Empty', location: [0, 0, 0])]);
        },
      ),
      options: EditorMenuItemOptions(order: 1, section: 'make', checked: checked),
    );
    context.registerSlotButton(EditorSlotButton(
      id: 'status',
      slot: EditorSlot.statusBarLeft,
      state: button,
      command: EditorCommand(id: 'data.status', label: 'Status', canExecute: () => true, execute: (_) {}),
    ));
    context.registerToolbarButton(EditorToolbarButton(
      id: 'tb',
      tooltip: 'Toolbar',
      icon: _icon,
      group: 'levelToolbarAfterBlueprints',
      command: EditorCommand(id: 'data.tb', label: 'Toolbar', canExecute: () => true, execute: (_) {}),
    ));
    context.registerConsoleCommand('data.echo', 'Echoes.', (args) => calls.add('echo:${args.join(',')}'));
    context.registerImporter(EditorImporter(
      extensions: const ['csv'],
      description: 'CSV tables',
      import: (source, ctx) async {
        final text = await source.readAsString();
        if (!text.contains(',')) return const ImportResult.failure('not a CSV table');
        final out = File('${ctx.targetDirectory}/table.lmas')..writeAsStringSync(text);
        return ImportResult.success(out.path);
      },
    ));
    context.mcp.registerTool(McpTool(
      name: 'settings',
      description: 'The plugin settings.',
      inputSchema: McpSchema.object({}),
      handler: (_) => McpToolResult.json({'settings': context.pluginSettings.value}),
      risk: McpToolRisk.readOnly,
      groups: {McpToolGroups.plugin},
    ));
    context.panels.show('data.panel');
  }

  @override
  void onProjectOpened(EditorProjectInfo project) => calls.add('opened:${project.name}');

  @override
  Future<void> onProjectClosing() async => calls.add('closing');

  @override
  Future<void> onEditorShutdown() async => calls.add('shutdown');

  @override
  void unregister(LuminaEditorContext context) => calls.add('unregister');
}

/// A plugin that builds a widget panel: it needs the editor process.
class _PanelPlugin extends LuminaEditorPlugin {
  @override
  String get pluginName => 'sample';

  @override
  void register(LuminaEditorContext context) {
    context.registerPanel(EditorPanelDescriptor(
      id: 'p',
      title: 'Panel',
      icon: _icon,
      builder: (_) => const SizedBox(),
    ));
  }
}

void main() {
  late LoopbackHost host;

  tearDown(() => host.close());

  test('an unchanged data-only plugin runs in a plugin process', () async {
    host = await LoopbackHost.start();
    final plugin = _DataPlugin();
    final exit = runPluginProcessMain(host.launch('sample'), PluginProcessAdapter(plugin));
    final c = await host.contributions;

    expect(c.menus.single.toJson(), {'id': 'data', 'title': 'Data', 'placement': 'beforeHelp', 'order': 0});
    final item = c.menuItems.single;
    expect((item.path, item.order, item.section, item.checked), ('Data/Place', 1, 'make', true));
    expect(item.command.icon, pluginIconOf(_icon));
    expect(item.command.dynamicEnablement, isTrue);
    expect([for (final b in c.slotButtons) '${b.id}@${b.slot}'], ['status@statusBarLeft', 'tb@levelToolbarAfterBlueprints']);
    expect(c.slotButtons.first.state.tooltip, 'Ready');
    expect(c.consoleCommands.single.name, 'data.echo');
    expect(c.importers.single.extensions, ['csv']);
    expect(c.mcpTools.single.name, 'settings');
    expect(plugin.level, isNotNull, reason: 'the adapter is a LuminaEditorHostContext');
    while (plugin.calls.length < 2) {
      await host.call(PluginMethods.ping);
    }
    expect(plugin.calls, ['register', 'opened:Proj']);
    expect(host.requests.single.$2, {'op': 'show', 'panelId': 'data.panel'});

    // Commands: canExecute, then execute with a null BuildContext and a level edit.
    expect(await host.call(PluginMethods.canExecute, {'commandId': 'data.place'}), isTrue);
    await host.call(PluginMethods.command, {'commandId': 'data.place'});
    expect(plugin.calls, contains('place:true'));
    expect(host.level.actors.single.name, 'Placed');

    // Live state.
    plugin.button.value = const EditorButtonState(icon: _icon, tooltip: 'Working', tone: EditorTone.warning);
    final s = await host.next(PluginMethods.slotState);
    expect((s['state'] as Map)['tone'], 'warning');
    plugin.checked.value = false;
    expect(await host.next(PluginMethods.menuChecked), {'path': 'Data/Place', 'checked': false});

    // Console, importer, MCP tool.
    await host.call(PluginMethods.console, {'name': 'data.echo', 'args': ['x', 'y']});
    expect(plugin.calls, contains('echo:x,y'));
    final id = c.importers.single.id;
    final good = File('${host.root.path}/t.csv')..writeAsStringSync('a,b');
    final bad = File('${host.root.path}/t2.csv')..writeAsStringSync('ab');
    final ok = await host.call(PluginMethods.import, {'importerId': id, 'sourcePath': good.path, 'targetDirectory': host.root.path}) as Map;
    expect(File(ok['assetPath'] as String).readAsStringSync(), 'a,b');
    expect(
      await host.call(PluginMethods.import, {'importerId': id, 'sourcePath': bad.path, 'targetDirectory': host.root.path}),
      {'success': false, 'error': 'not a CSV table'},
    );
    final tool = await host.call(PluginMethods.mcpTool, {'tool': 'settings', 'arguments': {}}) as Map;
    expect(tool['structuredContent'], {'settings': {'density': 3}});

    await host.call(PluginMethods.projectClosing);
    await host.call(PluginMethods.shutdown);
    expect(await exit, PluginProcessExitCodes.ok);
    expect(plugin.calls.sublist(plugin.calls.length - 3), ['closing', 'shutdown', 'unregister']);
  });

  test('a plugin that registers a widget panel is refused with a clear message', () async {
    host = await LoopbackHost.start();
    final exit = runPluginProcessMain(host.launch('sample'), PluginProcessAdapter(_PanelPlugin()));
    final log = await host.next(PluginMethods.log);
    expect(log['level'], 'error');
    expect(log['message'], contains('registerPanel needs the editor process'));
    expect(log['message'], contains('panel "p" is a widget builder'));
    expect(await exit, PluginProcessExitCodes.registerFailed);
  });

  test('pluginIconOf and iconDataOf round-trip an icon', () {
    const icon = IconData(0xe900, fontFamily: 'Lucide', fontPackage: 'shadcn_flutter', matchTextDirection: true);
    final spec = pluginIconOf(icon);
    expect(spec, const PluginIconSpec(0xe900, fontFamily: 'Lucide', fontPackage: 'shadcn_flutter', matchTextDirection: true));
    expect(PluginIconSpec.fromJson(spec.toJson()), spec);
    expect(iconDataOf(spec), icon);
  });
}
