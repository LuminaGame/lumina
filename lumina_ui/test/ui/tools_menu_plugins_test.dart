import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina_plugin_pcg/lumina_plugin_pcg.dart';
import 'package:lumina_ui/ui/core/host/editor_host.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/main_editor/views/content_browser_widget.dart';
import 'package:lumina_ui/ui/features/plugin_manager/views/new_plugin_wizard.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The built-in `tools.plugins` / `tools.plugins.new` commands
/// (Plugin Manager, New Plugin wizard) were never on screen. They moved, with
/// every plugin item, from Tools into the top-level Plugins menu.
Finder _barItem(String title) => find.descendant(of: find.byType(Menubar), matching: find.text(title));

void main() {
  // The editor viewport's tickers never let pumpAndSettle settle.
  Future<void> settle(WidgetTester tester, {int frames = 20}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  Future<EditorViewModel> pumpEditor(WidgetTester tester) async {
    final dir = Directory.systemTemp.createTempSync('lumina_tools_plugins_');
    addTearDown(() => dir.deleteSync(recursive: true));
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final vm = EditorViewModel(
      initialProject: const LuminaProject(projectName: 'ToolsGame'),
      projectLocation: dir.path,
      enableTimers: false,
      autoInitAssets: false,
    );
    addTearDown(vm.dispose);
    await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)));
    await settle(tester);
    return vm;
  }

  testWidgets('Plugins → Plugin Manager... opens the Plugin Manager tab', (tester) async {
    final vm = await pumpEditor(tester);

    await tester.tap(_barItem('Plugins'));
    await settle(tester);
    expect(find.text('Plugin Manager...'), findsOneWidget, reason: 'the Plugins menu offers the Plugin Manager');
    await tester.tap(find.text('Plugin Manager...'));
    await settle(tester);

    expect(vm.openTabs.where((t) => t.title == 'Plugins'), hasLength(1));
    expect(vm.openTabs[vm.activeTabIndex].title, 'Plugins');
    expect(find.text('ALL PLUGINS'), findsOneWidget, reason: 'the Plugin Manager is on screen');

    // Reopening focuses the same tab instead of adding a second one.
    vm.selectTab(0);
    await settle(tester);
    await tester.tap(_barItem('Plugins'));
    await settle(tester);
    await tester.tap(find.text('Plugin Manager...'));
    await settle(tester);
    expect(vm.openTabs.where((t) => t.title == 'Plugins'), hasLength(1));
    expect(vm.openTabs[vm.activeTabIndex].title, 'Plugins');
  });

  testWidgets('Plugins → New Plugin... opens the wizard with a context that outlives the menu', (tester) async {
    await pumpEditor(tester);

    await tester.tap(_barItem('Plugins'));
    await settle(tester);
    expect(find.text('New Plugin...'), findsOneWidget, reason: 'the Plugins menu offers the wizard');
    await tester.tap(find.text('New Plugin...'));
    await settle(tester);

    expect(find.text('New Plugin Wizard'), findsOneWidget);
    // After generating, the wizard offers "Enable now" on this context; the
    // menu item's own context is gone once the menu has closed.
    final wizard = tester.widget<NewPluginWizardDialog>(find.byType(NewPluginWizardDialog));
    expect(wizard.rootContext.mounted, isTrue, reason: 'the wizard would silently skip its Enable dialog');
  });

  testWidgets('Plugins → PCG submenu displays plugin commands from multi-segment menu paths', (tester) async {
    // The real lumina_plugin_pcg, compiled in.
    LuminaEditorHost.plugins = [LuminaPluginPcgPlugin()];
    addTearDown(() => LuminaEditorHost.plugins = const []);
    await pumpEditor(tester);

    await tester.tap(_barItem('Plugins'));
    await settle(tester);
    expect(find.text('PCG'), findsOneWidget, reason: 'the Plugins menu has the PCG submenu');
    await tester.tap(find.text('PCG'));
    await settle(tester);

    expect(find.text('New PCG Graph'), findsOneWidget);
    expect(find.text('Place PCG Volume'), findsOneWidget);
    expect(find.text('Generate All'), findsOneWidget);
    expect(find.text('Cleanup All'), findsOneWidget);
  });

  testWidgets('Content Browser "+ New Asset" modal shows registered plugin asset types', (tester) async {
    // The real lumina_plugin_pcg, compiled in.
    LuminaEditorHost.plugins = [LuminaPluginPcgPlugin()];
    addTearDown(() => LuminaEditorHost.plugins = const []);
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final dir = Directory.systemTemp.createTempSync('lumina_cb_plugins_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final vm = EditorViewModel(
      initialProject: const LuminaProject(projectName: 'ToolsGame'),
      projectLocation: dir.path,
      enableTimers: false,
      autoInitAssets: false,
    );
    addTearDown(vm.dispose);
    await tester.pumpWidget(
      ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(child: ContentBrowserWidget(viewModel: vm)),
      ),
    );
    await settle(tester);

    final newAssetBtn = find.text('New Asset').first;
    expect(newAssetBtn, findsOneWidget);
    await tester.tap(newAssetBtn);
    await settle(tester);

    expect(find.text('Create New Lumina Asset'), findsOneWidget);
    final itemFinder = find.text('New PCG Graph (.lmas)');
    expect(itemFinder, findsOneWidget);
    await tester.ensureVisible(itemFinder);
    await settle(tester);

    await tester.tap(itemFinder);
    await settle(tester, frames: 50);

    // Verify PCG graph asset was created on disk and opened in sub-editor tab
    expect(
      File('${vm.projectDirPath}/contents/pcg/PCG_Graph_1.lmas').existsSync(),
      isTrue,
      reason: 'PCG Graph asset file is created on disk',
    );
    expect(
      vm.openTabs.any((t) => t.category.contains('pcg.graph') || t.title.contains('PCG_Graph')),
      isTrue,
      reason: 'Created PCG Graph is opened in sub-editor',
    );
  });
}
