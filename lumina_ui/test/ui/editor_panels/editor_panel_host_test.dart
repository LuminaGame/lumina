import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart' show MapPluginSettingsHandle;
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/core/editor_panels/editor_panel_docking.dart';
import 'package:lumina_ui/ui/core/editor_panels/editor_panel_runtime.dart';
import 'package:lumina_ui/ui/core/editor_panels/editor_panel_view.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:path/path.dart' as p;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'editor_panel_fixture.dart';

/// Editor panels from a real project and a real content plugin, docked in a
/// real editor: listed under Window ▸ Editor Panels, a right panel docked and
/// resizable with its minimum width and the editor's tokens (Construct once,
/// Destruct on close), a Content Browser drag onto an element flagged
/// "Accepts Asset Drops", Play leaving the panel running, a tab panel with
/// the Content Drawer toggle, a modal dialog panel answering its opener, and
/// a Project Settings panel writing the plugin's project settings.
void main() {
  late EditorPanelProject project;
  late EditorViewModel vm;
  const batchId = 'project/contents/editor/EPW_BatchRename.lmas';
  const confirmId = 'project/contents/editor/EPW_Confirm.lmas';
  const tabId = 'prop_tools/content/EPW_PropTools.lmas';
  const settingsId = 'prop_tools/content/EPW_PropSettings.lmas';
  late String barrelMesh;

  void setText(EpwBuilder b, String id, String element, Map<String, dynamic> literals) {
    b.node(LuminaBlueprintNodeLibrary.getWidgetVariable, '${id}_get', {'element': element});
    b.node('set_element_text', id, literals);
    b.wire('${id}_get', 'return_value', id, 'target');
  }

  EpwBuilder batchRename() {
    final b = EpwBuilder(
        'EPW_BatchRename',
        LuminaEditorPanelInfo(
            title: 'Batch Rename', icon: 'pencil', dock: LuminaEditorPanelDock.right, contentDroppable: true, capabilities: const {}));
    b.element(UmgWidgetType.text, 'StatusText', props: {'text': 'Idle'});
    b.element(UmgWidgetType.button, 'RenameButton', props: {'label': 'Rename'});
    b.element(UmgWidgetType.button, 'DialogButton', props: {'label': 'Ask'});
    b.element(UmgWidgetType.text, 'DropZone', props: {'text': 'Drop a mesh here', 'acceptsAssetDrops': true, 'assetDropTypes': 'filamesh'});
    b.variable('Constructed', 'Int', 0);
    b.variable('Dropped', 'String', '');
    b.variable('DialogResult', 'Json');
    b.variable('DialogClosed', 'Int', 0);
    // Construct → Constructed += 1 → Log "constructed".
    b.node(LuminaBlueprintNodeLibrary.eventWidgetConstruct, 'construct');
    b.node(LuminaBlueprintNodeLibrary.variableGet, 'c_get', {'variable': 'Constructed'});
    b.node('int_add', 'c_add', {'b': 1});
    b.node(LuminaBlueprintNodeLibrary.variableSet, 'c_set', {'variable': 'Constructed'});
    b.node('editor_log_to_output', 'log_c', {'message': 'batch rename constructed'});
    b.chain(['construct', 'c_set', 'log_c']);
    b.wire('c_get', 'value', 'c_add', 'a');
    b.wire('c_add', 'return_value', 'c_set', 'value');
    // Destruct → Log "destructed".
    b.node(LuminaBlueprintNodeLibrary.eventWidgetDestruct, 'destruct');
    b.node('editor_log_to_output', 'log_d', {'message': 'batch rename destructed'});
    b.chain(['destruct', 'log_d']);
    // Rename → StatusText "Renamed".
    b.onElement('rename', 'RenameButton', 'OnClicked');
    setText(b, 'renamed', 'StatusText', {'in_text': 'Renamed'});
    b.chain(['rename', 'renamed']);
    // A Content Browser drop → Dropped = Asset Path.
    b.onElement('drop', 'DropZone', LuminaEditorWidgetEvents.onAssetDropped);
    b.node(LuminaBlueprintNodeLibrary.variableSet, 'set_drop', {'variable': 'Dropped'});
    b.wire('drop', 'exec_out', 'set_drop');
    b.wire('drop', 'asset_path', 'set_drop', 'value');
    // Ask → Open Editor Panel (EPW_Confirm) → Closed: DialogResult.
    b.onElement('ask', 'DialogButton', 'OnClicked');
    b.node('editor_open_editor_panel', 'open_dialog', {'panel': 'EPW_Confirm'});
    b.node(LuminaBlueprintNodeLibrary.variableSet, 'set_result', {'variable': 'DialogResult'});
    b.node(LuminaBlueprintNodeLibrary.variableGet, 'n_get', {'variable': 'DialogClosed'});
    b.node('int_add', 'n_add', {'b': 1});
    b.node(LuminaBlueprintNodeLibrary.variableSet, 'n_set', {'variable': 'DialogClosed'});
    b.wire('ask', 'exec_out', 'open_dialog');
    b.wire('open_dialog', 'closed', 'set_result');
    b.wire('open_dialog', 'result', 'set_result', 'value');
    b.wire('set_result', 'exec_out', 'n_set');
    b.wire('n_get', 'value', 'n_add', 'a');
    b.wire('n_add', 'return_value', 'n_set', 'value');
    return b;
  }

  EpwBuilder confirm() {
    final b = EpwBuilder('EPW_Confirm',
        LuminaEditorPanelInfo(title: 'Confirm', dock: LuminaEditorPanelDock.dialog, minWidth: 260, minHeight: 120));
    b.element(UmgWidgetType.button, 'OkButton', props: {'label': 'OK'});
    b.onElement('ok', 'OkButton', 'OnClicked');
    b.node(LuminaJsonBlueprintNodes.makeObject, 'json', {
      'keys': ['ok'],
      'values': [true],
    });
    b.node('editor_close_this_panel', 'close');
    b.chain(['ok', 'close']);
    b.wire('json', 'return_value', 'close', 'result');
    return b;
  }

  EpwBuilder propTools() {
    final b = EpwBuilder('EPW_PropTools', LuminaEditorPanelInfo(title: 'Prop Tools', icon: 'box', dock: LuminaEditorPanelDock.tab, contentBrowserOpened: false));
    b.element(UmgWidgetType.text, 'Heading', props: {'text': 'Prop Tools workspace'});
    return b;
  }

  EpwBuilder propSettings() {
    final b = EpwBuilder('EPW_PropSettings', LuminaEditorPanelInfo(title: 'Prop Tools Settings', dock: LuminaEditorPanelDock.projectSettings));
    b.element(UmgWidgetType.text, 'SettingsText', props: {'text': 'Quality'});
    b.element(UmgWidgetType.button, 'SaveButton', props: {'label': 'Use High'});
    b.variable('Saved', 'String', '');
    b.onElement('save', 'SaveButton', 'OnClicked');
    b.node(LuminaJsonBlueprintNodes.parse, 'value', {'text': '"high"'});
    b.node('editor_set_project_plugin_setting', 'set', {'key': 'quality'});
    b.node(LuminaBlueprintNodeLibrary.variableSet, 'done', {'variable': 'Saved', 'value': 'yes'});
    b.chain(['save', 'value', 'set']);
    b.wire('value', 'json', 'set', 'value');
    b.wire('set', 'completed', 'done');
    return b;
  }

  setUp(() async {
    project = await EditorPanelProject.create('HostPanels', plugins: ['prop_tools']);
    await batchRename().writeTo(project.projectPath('contents/editor/EPW_BatchRename.lmas'));
    await confirm().writeTo(project.projectPath('contents/editor/EPW_Confirm.lmas'));
    final plugin = project.writePlugin('prop_tools', friendlyName: 'Prop Tools');
    await propTools().writeTo(p.join(plugin.path, 'content', 'EPW_PropTools.lmas'));
    await propSettings().writeTo(p.join(plugin.path, 'content', 'EPW_PropSettings.lmas'));
    vm = await project.open();
    await vm.ensureDefaultLevelAssets();
    await vm.processImportPipeline(sourceFilePath: testAsset('Props/Barrels/fuel_barrel_red.glb'));
    barrelMesh = vm.realAssets.firstWhere((a) => a.type == AssetType.filamesh).relativePath;
    await EditorPanelProject.startPanels(vm);
    await until(() => vm.editorPanels.panels.length == 4, reason: 'the four panels');
    await vm.editorPanels.trustProjectPanels();
    for (final rt in vm.editorPanels.panels.values) {
      expect(rt.errors, isEmpty, reason: rt.id);
    }
  });

  tearDown(() async {
    await vm.close();
    await project.dispose();
  });

  Future<void> frames(WidgetTester tester, [int count = 20]) async {
    for (var i = 0; i < count; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  Future<void> pumpEditor(WidgetTester tester) async {
    tester.view.physicalSize = const Size(2400, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)));
    await tester.pump(const Duration(milliseconds: 500));
  }

  EditorPanelInstance instance(String id) => vm.editorPanels.instancesOf(id).single;

  /// Closes every panel (their world stops ticking) before the test ends.
  Future<void> closeAll(WidgetTester tester) async {
    for (final id in vm.editorPanels.panels.keys) {
      vm.editorPanelDocking.close(id);
    }
    await frames(tester, 5);
  }

  test('the project panel and the plugin panels are listed under Window ▸ Editor Panels', () {
    final titles = [for (final rt in vm.editorPanelDocking.menuPanels) rt.title];
    expect(titles, containsAll(['Batch Rename', 'Prop Tools']));
    expect(titles, isNot(contains('Confirm')), reason: 'a dialog is opened by its panels only');
    expect(titles, isNot(contains('Prop Tools Settings')), reason: 'a settings section lives in Project Settings');
    expect(vm.commands.byId(EditorPanelDocking.commandId(batchId)), isNotNull);
    expect(vm.commands.byId(EditorPanelDocking.commandId(tabId)), isNotNull);
    expect(vm.editorPanels.trustOf(tabId).name, 'plugin', reason: 'a plugin panel is trusted with its plugin');
    // The plugin's panel also sits in its plugin menu.
    expect(vm.extensionRegistry.menuEntriesUnder('Plugins').map((e) => e.path), contains('Plugins/Prop Tools/Prop Tools'));
  });

  testWidgets('a right panel docks resizable with its minimum width and the editor tokens; Construct once, Destruct on close',
      (tester) async {
    await pumpEditor(tester);
    vm.editorPanelDocking.open(batchId);
    await frames(tester);
    final view = find.byKey(const ValueKey('editor_panel_view_$batchId'));
    expect(view, findsOneWidget);
    expect(find.ancestor(of: view, matching: find.byKey(const ValueKey('right_dock'))), findsOneWidget);
    expect(find.ancestor(of: view, matching: find.byType(ResizablePane)), findsWidgets);
    final box = tester.widget<Container>(view);
    expect(box.color, EditorColors.sidebar);
    expect(box.constraints!.minWidth, 200);
    expect(tester.getSize(view).width, greaterThanOrEqualTo(200));
    final panel = instance(batchId);
    expect(panel.script!.variables['Constructed'], 1);
    await frames(tester);
    expect(panel.script!.variables['Constructed'], 1, reason: 'Construct runs once');

    // The panel's button runs its graph.
    await tester.tap(find.text('Rename'));
    await frames(tester, 3);
    expect(panel.element('StatusText')!['text'], 'Renamed');
    expect(find.text('Renamed'), findsOneWidget);

    // Play starts and stops: the panel keeps running.
    final world = LuminaWorld(worldType: LuminaWorldType.game);
    vm.pieController.startHeadlessForTest(world);
    await frames(tester, 3);
    vm.pieController.stopHeadlessForTest();
    expect(panel.script, isNotNull);
    panel.element('StatusText')!['text'] = 'Idle';
    await tester.tap(find.text('Rename'));
    await frames(tester, 3);
    expect(panel.element('StatusText')!['text'], 'Renamed', reason: 'the graph still runs after Play');

    // Closing runs Destruct.
    vm.editorPanelDocking.close(batchId);
    await frames(tester);
    expect(vm.editorPanels.isOpen(batchId), isFalse);
    expect(vm.logger.logs.map((l) => l.message), contains('batch rename destructed'));
  });

  testWidgets('a Content Browser drag onto an element that accepts drops fires On Asset Dropped', (tester) async {
    await pumpEditor(tester);
    vm.selectedFolder = p.dirname(barrelMesh).replaceAll(r'\', '/');
    vm.editorPanelDocking.open(batchId);
    await frames(tester);
    final card = find.byKey(ValueKey('asset_item_$barrelMesh'));
    expect(card, findsOneWidget);
    final zone = find.byKey(const ValueKey('editor_panel_drop_DropZone'));
    expect(zone, findsOneWidget);
    final gesture = await tester.startGesture(tester.getCenter(card));
    await tester.pump(const Duration(milliseconds: 50));
    final to = tester.getCenter(zone);
    for (var i = 1; i <= 10; i++) {
      await gesture.moveTo(Offset.lerp(tester.getCenter(card), to, i / 10)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await frames(tester, 3);
    expect(instance(batchId).script!.variables['Dropped'], barrelMesh);
    await closeAll(tester);
  });

  testWidgets('a tab panel shows the Content Drawer toggle and its pin', (tester) async {
    await pumpEditor(tester);
    vm.editorPanelDocking.open(tabId);
    await frames(tester, 30);
    expect(vm.currentTab.title, 'Prop Tools');
    expect(find.text('Prop Tools workspace'), findsOneWidget);
    // contentBrowserOpened false: no docked Content Browser; the bottom-left
    // Content Drawer toggle (the status bar's folder button in a tab) opens it.
    expect(find.byKey(const ValueKey('sub_editor_bottom_pane')), findsNothing);
    expect(vm.activeSubEditorDrawer, isNotNull);
    final toggle = find.byKey(const ValueKey('status_bar_content_drawer'));
    expect(toggle, findsOneWidget);
    expect(tester.getTopLeft(toggle).dx, lessThan(400), reason: 'bottom-left');
    await tester.tap(toggle);
    await frames(tester, 30);
    expect(find.byKey(const ValueKey('sub_editor_bottom_panel_pin')), findsOneWidget);
    expect(vm.layoutState.pluginPanelVisible[EditorPanelDocking.tabLayoutKey(tabId)], isTrue, reason: 'restored with the layout');
    await closeAll(tester);
  });

  testWidgets('a dialog panel is modal and answers its opener; Escape answers null', (tester) async {
    await pumpEditor(tester);
    vm.editorPanelDocking.open(batchId);
    await frames(tester);
    final panel = instance(batchId);
    await tester.tap(find.text('Ask'));
    await frames(tester, 20);
    expect(find.byKey(const ValueKey('editor_panel_dialog_$confirmId')), findsOneWidget);
    await tester.tap(find.text('OK'));
    await frames(tester, 30);
    expect(find.byKey(const ValueKey('editor_panel_dialog_$confirmId')), findsNothing);
    expect(panel.script!.variables['DialogResult'], {'ok': true});
    expect(panel.script!.variables['DialogClosed'], 1);

    await tester.tap(find.text('Ask'));
    await frames(tester, 20);
    expect(find.byKey(const ValueKey('editor_panel_dialog_$confirmId')), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await frames(tester, 30);
    expect(find.byKey(const ValueKey('editor_panel_dialog_$confirmId')), findsNothing);
    expect(panel.script!.variables['DialogClosed'], 2);
    expect(panel.script!.variables['DialogResult'], isNull);
    await closeAll(tester);
  });

  testWidgets('a projectSettings panel is the plugin\'s Project Settings section and writes its project settings',
      (tester) async {
    final sections = vm.extensionRegistry.projectSettingsSections;
    final section = sections.where((s) => s.$2.id == 'editorPanel:$settingsId').single;
    expect(section.$1, 'prop_tools');
    tester.view.physicalSize = const Size(900, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(child: Builder(builder: (c) => section.$2.builder(c, MapPluginSettingsHandle()))),
    ));
    await frames(tester, 5);
    expect(find.byType(EditorPanelView), findsOneWidget);
    await tester.tap(find.text('Use High'));
    await tester.runAsync(() => until(() => instance(settingsId).script!.variables['Saved'] == 'yes'));
    await frames(tester, 3);
    final saved = jsonDecode(await tester.runAsync(() => File(project.projectPath('HostPanels.lmproject')).readAsString()) ?? '{}');
    expect((saved as Map)['plugin_settings'], {
      'prop_tools': {'quality': 'high'},
    });
    // What the plugin process receives as pluginSettings (core.settings).
    expect(vm.extensionRegistry.settingsFor('prop_tools').value, {'quality': 'high'});
    await closeAll(tester);
  });
}
