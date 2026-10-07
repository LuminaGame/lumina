import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:lumina_plugin_pcg/lumina_plugin_pcg.dart';
import 'package:lumina_ui/ui/core/host/editor_host.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// A plugin that owns a top-level menu, registered through the real
/// registry exactly as the generated registrar does.
class _TerrainPlugin extends LuminaEditorPlugin {
  int raised = 0;

  @override
  String get pluginName => 'terrain_tools';

  @override
  void register(LuminaEditorContext context) {
    context.registerMenu(const EditorMenuDescriptor(id: 'terrain', title: 'Terrain'));
    context.registerMenuItem(
      'Terrain/Sculpt/Raise',
      EditorCommand(id: 'terrain_tools.raise', label: 'Raise', canExecute: () => true, execute: (_) => raised++),
    );
  }
}

/// A top-level Plugins menu between Tools and Window holds the
/// Plugin Manager, New Plugin… and one submenu per plugin; Tools keeps only
/// the built-in tools.
void main() {
  // The editor viewport's tickers never let pumpAndSettle settle.
  Future<void> settle(WidgetTester tester, {int frames = 20}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  Future<EditorViewModel> pumpEditor(WidgetTester tester) async {
    final dir = Directory.systemTemp.createTempSync('lumina_plugins_menu_');
    addTearDown(() {
      try {
        dir.deleteSync(recursive: true);
      } catch (_) {}
    });
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    // The real lumina_plugin_pcg, compiled in as a project editor host's
    // registrar would.
    LuminaEditorHost.plugins = [LuminaPluginPcgPlugin()];
    addTearDown(() => LuminaEditorHost.plugins = const []);
    final vm = EditorViewModel(
      initialProject: const LuminaProject(projectName: 'PluginsMenuGame'),
      projectLocation: dir.path,
      enableTimers: false,
      autoInitAssets: false,
    );
    addTearDown(vm.dispose);
    await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)));
    await settle(tester);
    return vm;
  }

  List<String> topLevelTitles(WidgetTester tester) => [
        for (final item in tester.widget<Menubar>(find.byType(Menubar)).children)
          ((item as MenuButton).child as Text).data!,
      ];

  Finder barItem(String title) => find.descendant(of: find.byType(Menubar), matching: find.text(title));

  testWidgets('the menu bar reads File … Tools, Plugins, Window, Help', (tester) async {
    await pumpEditor(tester);
    expect(topLevelTitles(tester), ['File', 'Edit', 'View', 'Build', 'Debug', 'Tools', 'Plugins', 'Window', 'Help']);
  });

  testWidgets('Tools keeps the built-in tools and no plugin entries', (tester) async {
    await pumpEditor(tester);
    await tester.tap(barItem('Tools'));
    await settle(tester);
    expect(find.text('AI Agent Access (MCP)...'), findsOneWidget);
    expect(find.text('Material Editor'), findsOneWidget);
    expect(find.text('Clear Derived Data Cache'), findsOneWidget);
    expect(find.text('PCG'), findsNothing);
    expect(find.text('New Plugin...'), findsNothing);
    expect(find.text('Plugin Manager...'), findsNothing);
  });

  testWidgets('Plugins holds the Plugin Manager, New Plugin… and PCG with its five items in three sections', (tester) async {
    await pumpEditor(tester);
    await tester.tap(barItem('Plugins'));
    await settle(tester);
    expect(find.text('Plugin Manager...'), findsOneWidget);
    expect(find.text('New Plugin...'), findsOneWidget);
    expect(find.byType(MenuDivider), findsOneWidget, reason: 'one divider before the plugin submenus');
    await tester.tap(find.text('PCG'));
    await settle(tester);
    for (final label in ['New PCG Graph', 'Place PCG Volume', 'Generate All', 'Cleanup All', 'About Procedural Content Generation']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.byType(MenuDivider), findsNWidgets(3), reason: 'create | run | about inside PCG');
  });

  testWidgets('Plugins → Plugin Manager… opens the Plugin Manager tab', (tester) async {
    final vm = await pumpEditor(tester);
    await tester.tap(barItem('Plugins'));
    await settle(tester);
    await tester.tap(find.text('Plugin Manager...'));
    await settle(tester);
    expect(vm.openTabs[vm.activeTabIndex].title, 'Plugins');
    expect(find.text('ALL PLUGINS'), findsOneWidget);
  });

  testWidgets('with no plugin items the Plugins menu shows exactly its two entries', (tester) async {
    final vm = await pumpEditor(tester);
    // Registering PCG again with nothing drops every contribution it made.
    vm.extensionRegistry
      ..beginRegistration('lumina_plugin_pcg')
      ..endRegistration();
    await settle(tester);
    await tester.tap(barItem('Plugins'));
    await settle(tester);
    expect(find.text('Plugin Manager...'), findsOneWidget);
    expect(find.text('New Plugin...'), findsOneWidget);
    expect(find.text('PCG'), findsNothing);
    expect(find.byType(MenuDivider), findsNothing);
  });

  testWidgets('a plugin-owned Terrain menu sits after Plugins and runs Terrain ▸ Sculpt ▸ Raise', (tester) async {
    final vm = await pumpEditor(tester);
    final terrain = _TerrainPlugin();
    vm.extensionRegistry.registerPlugin(terrain);
    await settle(tester);
    expect(topLevelTitles(tester), ['File', 'Edit', 'View', 'Build', 'Debug', 'Tools', 'Plugins', 'Terrain', 'Window', 'Help']);
    await tester.tap(barItem('Terrain'));
    await settle(tester);
    await tester.tap(find.text('Sculpt'));
    await settle(tester);
    await tester.tap(find.text('Raise'));
    await settle(tester);
    expect(terrain.raised, 1);
  });

  testWidgets('a rejected menu path shows on the plugin\'s Plugin Manager row as an issue', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final root = Directory.systemTemp.createTempSync('lumina_plugins_menu_issue_');
    addTearDown(() {
      try {
        root.deleteSync(recursive: true);
      } catch (_) {}
    });
    // A real project on disk with a real plugin manifest in its plugins root.
    final pDir = Directory('${root.path}/IssueGame')..createSync(recursive: true);
    const project = LuminaProject(projectName: 'IssueGame');
    File('${pDir.path}/IssueGame.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
    File('${pDir.path}/plugins/bad_menu_tools/bad_menu_tools.lmplugin')
      ..createSync(recursive: true)
      ..writeAsStringSync(jsonEncode({
        'name': 'bad_menu_tools',
        'friendly_name': 'Bad Menu Tools',
        'version': '1.0.0',
        'modules': [
          {'name': 'B', 'type': 'editor', 'entry_library': 'lib/b.dart', 'registration_class': 'B'},
        ],
      }));
    final vm = EditorViewModel(initialProject: project, projectDirPath: root.path, enableTimers: false, autoInitAssets: false);
    addTearDown(vm.dispose);
    vm.extensionRegistry
      ..beginRegistration('bad_menu_tools')
      ..registerMenuItem('Edit/Sneaky', EditorCommand(id: 'bad_menu_tools.sneaky', label: 'Sneaky', canExecute: () => true, execute: (_) {}))
      ..endRegistration();
    await tester.runAsync(() => vm.rescanPlugins());
    final entry = vm.pluginRegistry.entries.firstWhere((e) => e.descriptor.name == 'bad_menu_tools');
    expect(entry.issues.map((i) => i.type), contains(PluginIssueType.invalidMenuPath));

    await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)));
    await settle(tester);
    await tester.tap(barItem('Plugins'));
    await settle(tester);
    await tester.tap(find.text('Plugin Manager...'));
    await settle(tester);
    expect(find.text('Bad Menu Tools'), findsWidgets);
    expect(find.text('Issue'), findsOneWidget, reason: 'the plugin card carries the menu issue badge');
    expect(find.text('Sneaky'), findsNothing);
  });

  test('no Material widgets; menu_bar_widget.dart and menu_tree_builder.dart stay ≤ 1100 lines', () {
    for (final path in [
      'lib/ui/features/main_editor/views/menu_bar_widget.dart',
      'lib/ui/features/main_editor/views/menu_tree_builder.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, isNot(contains('package:flutter/material.dart')), reason: path);
      expect(source.split('\n').length, lessThanOrEqualTo(1100), reason: path);
    }
  });
}
