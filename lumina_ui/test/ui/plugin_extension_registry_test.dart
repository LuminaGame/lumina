import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_ui/ui/core/plugin_extension_registry.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:lumina/lumina.dart';

class TestContextPlugin extends LuminaEditorPlugin {
  @override
  String get pluginName => 'TestContextPlugin';

  @override
  void register(LuminaEditorContext context) {
    context.registerMenuItem('Tools/Test', EditorCommand(
      id: 'test.menu', label: 'Test Menu', canExecute: () => true, execute: (_) {}
    ));
    context.registerToolbarButton(EditorToolbarButton(
      id: 'test.toolbar', tooltip: 'Test', icon: const IconData(0), group: 'Test',
      command: EditorCommand(id: 'test.toolbar', label: 'T', canExecute: () => true, execute: (_) {})
    ));
    context.registerPanel(EditorPanelDescriptor(
      id: 'test.panel', title: 'Test', icon: const IconData(0), builder: (_) => const SizedBox()
    ));
    context.registerAssetType(EditorAssetTypeHandler(
      customTypeId: 'test.type', displayName: 'Test', icon: const IconData(0),
      thumbnailBuilder: (_) async => null
    ));
    context.registerImporter(EditorImporter(
      extensions: ['.test'], description: 'Test', import: (s, c) async => const ImportResult.success('test')
    ));
    context.registerDetailsCustomization(DetailsCustomization(
      targetTypeId: 'TestActor', sectionTitle: 'Test', builder: (_, _) => const SizedBox()
    ));
    context.registerConsoleCommand('testcmd', 'Test command', (args) {});
  }

  @override
  void unregister(LuminaEditorContext context) {}
}

void main() {
  test('PluginExtensionRegistry registers 7 extension points', () {
    final logger = EngineLoggerService();
    final registry = PluginExtensionRegistry(logger: logger);
    
    registry.beginRegistration('TestContextPlugin');
    final plugin = TestContextPlugin();
    plugin.register(registry);
    registry.endRegistration();

    expect(registry.allMenuCommands.length, 1);
    expect(registry.allToolbarButtons.length, 1);
    expect(registry.allPanels.length, 1);
    expect(registry.allAssetTypes.length, 1);
    expect(registry.allImporters.length, 1);
    expect(registry.allDetailsCustomizations.length, 1);
    expect(registry.allConsoleCommands.length, 1);
  });

  // A plugin registered a second time (the boot registrar and a
  // test, or a re-enable) replaced nothing and doubled every contribution:
  // two "PCG" Details sections, duplicate Tools items, two asset handlers.
  test('registering the same plugin again replaces its contributions instead of doubling them', () {
    final registry = PluginExtensionRegistry(logger: EngineLoggerService());
    for (var i = 0; i < 2; i++) {
      registry.registerPlugin(TestContextPlugin());
    }
    expect(registry.allMenuCommands.length, 1);
    expect(registry.allToolbarButtons.length, 1);
    expect(registry.allPanels.length, 1);
    expect(registry.allAssetTypes.length, 1);
    expect(registry.allImporters.length, 1);
    expect(registry.allDetailsCustomizations.length, 1);
    expect(registry.allConsoleCommands.length, 1);
    expect(registry.logger.logs.where((l) => l.message.contains('Duplicate')), isEmpty,
        reason: 'a re-registration is not a duplicate-id conflict');
  });

  // Plugin items live in the Plugins menu or in a menu the plugin
  // owns; built-in menus refuse them. Registrations run inside
  // beginRegistration exactly as the generated registrar does.
  group('menu path rules', () {
    EditorCommand cmd(String id) => EditorCommand(id: id, label: id, canExecute: () => true, execute: (_) {});

    PluginExtensionRegistry registerAs(String plugin, void Function(PluginExtensionRegistry r) body,
        {PluginExtensionRegistry? into}) {
      final r = into ?? PluginExtensionRegistry(logger: EngineLoggerService());
      r.beginRegistration(plugin);
      body(r);
      r.endRegistration();
      return r;
    }

    List<String> paths(PluginExtensionRegistry r, String root) => r.menuEntriesUnder(root).map((e) => e.path).toList();

    test('Plugins/PCG/New PCG Graph lands in the Plugins tree under PCG', () {
      final r = registerAs('lumina_plugin_pcg', (r) => r.registerMenuItem('Plugins/PCG/New PCG Graph', cmd('pcg.new')));
      expect(paths(r, 'Plugins'), ['Plugins/PCG/New PCG Graph']);
      expect(r.menuIssuesFor('lumina_plugin_pcg'), isEmpty);
    });

    test('legacy Tools/PCG/… moves to Plugins ▸ PCG with one deprecation line per plugin', () {
      final logger = EngineLoggerService()..clear();
      final r = registerAs('lumina_plugin_pcg', (r) {
        r.registerMenuItem('Tools/PCG/Generate All', cmd('pcg.gen'));
        r.registerMenuItem('Tools/PCG/Cleanup All', cmd('pcg.clean'));
      }, into: PluginExtensionRegistry(logger: logger));
      expect(paths(r, 'Plugins'), ['Plugins/PCG/Generate All', 'Plugins/PCG/Cleanup All']);
      expect(paths(r, 'Tools'), isEmpty, reason: 'no plugin item stays in Tools');
      expect(logger.logs.where((l) => l.message.contains('deprecated')), hasLength(1));
      expect(r.menuIssuesFor('lumina_plugin_pcg'), isEmpty, reason: 'a remap is a warning, not an issue');
    });

    test('Edit/Foo is an invalidMenuPath issue and the item is in no menu', () {
      final logger = EngineLoggerService()..clear();
      final r = registerAs('bad_plugin', (r) => r.registerMenuItem('Edit/Foo', cmd('bad.foo')),
          into: PluginExtensionRegistry(logger: logger));
      expect(r.menuIssuesFor('bad_plugin').map((i) => i.type), [PluginIssueType.invalidMenuPath]);
      expect(r.allMenuCommands.map((e) => e.value.id), isNot(contains('bad.foo')));
      expect(logger.logs.any((l) => l.level == 'error' && l.message.contains('bad_plugin') && l.message.contains('Edit/Foo')), isTrue,
          reason: 'the Output Log names the plugin and the path');
    });

    test('registerMenu(title: Tools) is a menuConflict', () {
      final r = registerAs('tools_thief', (r) => r.registerMenu(const EditorMenuDescriptor(id: 'tools', title: 'Tools')));
      expect(r.menuIssuesFor('tools_thief').map((i) => i.type), [PluginIssueType.menuConflict]);
      expect(r.pluginMenus, isEmpty);
    });

    test('two plugins registering Terrain: the second gets menuConflict', () {
      final r = registerAs('terrain_a', (r) => r.registerMenu(const EditorMenuDescriptor(id: 'terrain', title: 'Terrain')));
      registerAs('terrain_b', (r) => r.registerMenu(const EditorMenuDescriptor(id: 'terrain2', title: 'Terrain')), into: r);
      expect(r.pluginMenus.map((m) => (m.plugin, m.menu.title)), [('terrain_a', 'Terrain')]);
      expect(r.menuIssuesFor('terrain_a'), isEmpty);
      expect(r.menuIssuesFor('terrain_b').map((i) => i.type), [PluginIssueType.menuConflict]);
    });

    test('a plugin fills its own menu at any depth; another plugin cannot', () {
      final r = registerAs('terrain_a', (r) {
        r.registerMenu(const EditorMenuDescriptor(id: 'terrain', title: 'Terrain', placement: EditorMenuPlacement.beforeHelp));
        r.registerMenuItem('Terrain/Sculpt/Raise', cmd('terrain.raise'));
      });
      registerAs('intruder', (r) => r.registerMenuItem('Terrain/Lower', cmd('intruder.lower')), into: r);
      expect(paths(r, 'Terrain'), ['Terrain/Sculpt/Raise']);
      expect(r.pluginMenus.single.menu.placement, EditorMenuPlacement.beforeHelp);
      expect(r.menuIssuesFor('intruder').map((i) => i.type), [PluginIssueType.invalidMenuPath]);
    });

    test('a fourth plugin menu is tooManyMenus and folds into Plugins ▸ <title>', () {
      final r = registerAs('many', (r) {
        for (final t in ['M1', 'M2', 'M3', 'M4']) {
          r.registerMenu(EditorMenuDescriptor(id: t, title: t));
        }
        r.registerMenuItem('M4/Go', cmd('many.go'));
      });
      expect(r.pluginMenus.map((m) => m.menu.title), ['M1', 'M2', 'M3']);
      expect(r.menuIssuesFor('many').map((i) => i.type), [PluginIssueType.tooManyMenus]);
      expect(paths(r, 'Plugins'), ['Plugins/M4/Go']);
    });

    test('built-in items keep their Tools paths; re-registering a plugin clears its issues', () {
      final r = registerAs('BuiltIn', (r) => r.registerMenuItem('Tools/Material Editor', cmd('tools.materialEditor')));
      registerAs('bad_plugin', (r) => r.registerMenuItem('Help/Foo', cmd('bad.help')), into: r);
      expect(paths(r, 'Tools'), ['Tools/Material Editor']);
      expect(r.menuIssuesFor('bad_plugin'), hasLength(1));
      registerAs('bad_plugin', (r) => r.registerMenuItem('Plugins/Bad/Fixed', cmd('bad.fixed')), into: r);
      expect(r.menuIssuesFor('bad_plugin'), isEmpty);
      expect(paths(r, 'Plugins'), ['Plugins/Bad/Fixed']);
    });

    test('an item with no group is grouped under the plugin title', () {
      final r = registerAs('hello_tools', (r) => r.registerMenuItem('Plugins/About', cmd('hello.about')));
      expect(paths(r, 'Plugins'), ['Plugins/hello_tools/About']);
      r.setPluginTitles({'hello_tools': 'Hello Tools'});
      expect(paths(r, 'Plugins'), ['Plugins/Hello Tools/About']);
    });
  });

  // Buttons in named slots, namespaced per plugin, ordered.
  group('slot buttons', () {
    EditorCommand cmd(String id) => EditorCommand(id: id, label: id, canExecute: () => true, execute: (_) {});
    EditorSlotButton button(String id, {EditorSlot slot = EditorSlot.levelToolbarEnd, int order = 0}) => EditorSlotButton(
          id: id,
          slot: slot,
          order: order,
          state: ValueNotifier(EditorButtonState(icon: const IconData(0), tooltip: id)),
          command: cmd('cmd.$id'),
        );
    List<String> ids(PluginExtensionRegistry r, EditorSlot slot) => r.slotButtons(slot).map((b) => b.effectiveId).toList();

    test('buttons sort by order, ties in registration order; ids are <plugin>.<id>', () {
      final r = PluginExtensionRegistry(logger: EngineLoggerService());
      r.beginRegistration('lumina_plugin_x');
      r.registerSlotButton(button('late', order: 10));
      r.registerSlotButton(button('first'));
      r.registerSlotButton(button('second'));
      r.registerSlotButton(button('ai', slot: EditorSlot.levelToolbarAfterBlueprints));
      r.endRegistration();
      expect(ids(r, EditorSlot.levelToolbarEnd), ['lumina_plugin_x.first', 'lumina_plugin_x.second', 'lumina_plugin_x.late']);
      expect(ids(r, EditorSlot.levelToolbarAfterBlueprints), ['lumina_plugin_x.ai']);
      expect(r.slotButtons(EditorSlot.levelToolbarAfterBlueprints).single.plugin, 'lumina_plugin_x');
      expect(ids(r, EditorSlot.statusBarLeft), isEmpty);
    });

    test('a duplicate id from the same plugin is rejected with an error; another plugin may reuse the id', () {
      final logger = EngineLoggerService()..clear();
      final r = PluginExtensionRegistry(logger: logger);
      r.beginRegistration('lumina_plugin_x');
      r.registerSlotButton(button('ai'));
      r.registerSlotButton(button('ai', slot: EditorSlot.statusBarRight));
      r.endRegistration();
      r.beginRegistration('lumina_plugin_y');
      r.registerSlotButton(button('ai'));
      r.endRegistration();
      expect(ids(r, EditorSlot.levelToolbarEnd), ['lumina_plugin_x.ai', 'lumina_plugin_y.ai']);
      expect(ids(r, EditorSlot.statusBarRight), isEmpty, reason: 'the first button is kept');
      expect(logger.logs.where((l) => l.level == 'error' && l.message.contains('lumina_plugin_x.ai') && l.message.contains('lumina_plugin_x')),
          hasLength(1));
    });

    test('an EditorToolbarButton goes to the slot its group names, else to the toolbar end', () {
      final r = PluginExtensionRegistry(logger: EngineLoggerService());
      r.beginRegistration('lumina_plugin_x');
      for (final (id, group) in [('named', 'levelToolbarAfterBlueprints'), ('other', 'tools')]) {
        r.registerToolbarButton(EditorToolbarButton(id: id, tooltip: 'Tip $id', icon: const IconData(1), group: group, command: cmd('tb.$id')));
      }
      r.endRegistration();
      expect(ids(r, EditorSlot.levelToolbarAfterBlueprints), ['lumina_plugin_x.named']);
      expect(ids(r, EditorSlot.levelToolbarEnd), ['lumina_plugin_x.other']);
      final converted = r.slotButtons(EditorSlot.levelToolbarEnd).single.button;
      expect(converted.state.value, const EditorButtonState(icon: IconData(1), tooltip: 'Tip other'));
      expect(converted.command.id, 'tb.other');
      expect(r.allToolbarButtons.map((b) => b.id), ['named', 'other'], reason: 'the originals stay readable');
    });

    test('registering the plugin again removes its old buttons', () {
      final r = PluginExtensionRegistry(logger: EngineLoggerService());
      r.beginRegistration('lumina_plugin_x');
      r.registerSlotButton(button('old', slot: EditorSlot.statusBarLeft));
      r.endRegistration();
      r.beginRegistration('lumina_plugin_x');
      r.endRegistration();
      expect(ids(r, EditorSlot.statusBarLeft), isEmpty);
    });
  });
}
