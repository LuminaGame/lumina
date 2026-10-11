import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/core/editor_panels/editor_panel_host.dart';
import 'package:lumina_ui/ui/core/editor_panels/editor_panel_trust.dart';
import 'package:lumina_ui/ui/core/editor_panels/editor_panel_view.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/plugin_manager/services/plugin_importer.dart';
import 'package:lumina_ui/ui/features/plugin_manager/view_models/plugin_manager_view_model.dart';
import 'package:lumina_ui/ui/features/plugin_manager/views/plugin_import_dialogs.dart';
import 'package:path/path.dart' as p;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'editor_panel_fixture.dart';

/// Trust: a project's panels run only after the per-user prompt (stored by
/// project path and capability hash, asked again when capabilities grow);
/// a plugin's panels run with their plugin and its import confirmation lists
/// them; a runaway graph is stopped by the step budget.
void main() {
  late EditorPanelProject project;
  late EditorViewModel vm;
  const id = 'project/contents/editor/EPW_Batch.lmas';
  late String file;

  EpwBuilder batch({Set<LuminaEditorPanelCapability> caps = const {LuminaEditorPanelCapability.level}}) {
    final b = EpwBuilder('EPW_Batch', LuminaEditorPanelInfo(title: 'Batch', dock: LuminaEditorPanelDock.right, capabilities: caps));
    b.element(UmgWidgetType.button, 'SpinButton', props: {'label': 'Spin'});
    b.variable('Constructed', 'Boolean', false);
    b.variable('I', 'Int', 0);
    b.node(LuminaBlueprintNodeLibrary.eventWidgetConstruct, 'construct');
    b.node(LuminaBlueprintNodeLibrary.variableSet, 'mark', {'variable': 'Constructed', 'value': true});
    b.chain(['construct', 'mark']);
    // Spin → a loop that never ends in time.
    b.onElement('spin', 'SpinButton', 'OnClicked');
    b.node('for_loop', 'loop', {'first_index': 0, 'last_index': 2000000000});
    b.node(LuminaBlueprintNodeLibrary.variableSet, 'count', {'variable': 'I'});
    b.wire('spin', 'exec_out', 'loop');
    b.wire('loop', 'loop_body', 'count');
    b.wire('loop', 'index', 'count', 'value');
    return b;
  }

  setUp(() async {
    project = await EditorPanelProject.create('TrustPanels');
    file = project.projectPath('contents/editor/EPW_Batch.lmas');
    await batch().writeTo(file);
    vm = await project.open();
    await EditorPanelProject.startPanels(vm);
    await until(() => vm.editorPanels.panel(id) != null, reason: 'the project panel');
  });

  tearDown(() async {
    await vm.close();
    await project.dispose();
  });

  Future<void> frames(WidgetTester tester, [int count = 10]) async {
    for (var i = 0; i < count; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  Future<void> pumpPanel(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(child: SizedBox(width: 340, height: 500, child: EditorPanelView(host: vm.editorPanels, panelId: id))),
    ));
    await frames(tester);
  }

  testWidgets('a project panel waits for trust; "Trust and run" runs it and is stored per user', (tester) async {
    expect(vm.editorPanels.trustOf(id), EditorPanelTrust.untrusted);
    await pumpPanel(tester);
    expect(find.byKey(const ValueKey('editor_panel_review_$id')), findsOneWidget, reason: 'the "Not trusted · Review" placeholder');
    expect(find.text('Spin'), findsNothing);
    expect(vm.editorPanels.instancesOf(id).single.script, isNull, reason: 'nothing runs before trust');
    // The prompt opens on first open and lists the panel with its capabilities.
    expect(find.byKey(const ValueKey('editor_panel_trust_dialog')), findsOneWidget);
    expect(find.textContaining('edit level actors'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('editor_panel_trust_run')));
    // The decision is written with real file IO, then the panel starts.
    for (var i = 0; i < 100 && vm.editorPanels.instancesOf(id).single.script == null; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    await frames(tester);
    expect(find.text('Spin'), findsOneWidget);
    final instance = vm.editorPanels.instancesOf(id).single;
    expect(instance.script!.variables['Constructed'], isTrue);
    final stored = jsonDecode(await tester.runAsync(() => vm.editorPanels.trust.file.readAsString()) ?? '{}') as Map;
    final key = p.normalize(p.absolute(project.projectDir.path)).replaceAll(r'\', '/');
    expect((stored['projects'] as Map)[key], {'contents/editor/EPW_Batch.lmas': vm.editorPanels.panel(id)!.info.capabilityHash});
    vm.editorPanelDocking.close(id);
    await frames(tester);
  });

  test('the decision survives reopening and is asked again when capabilities grow', () async {
    await vm.editorPanels.trustProjectPanels();
    await vm.close();
    vm = await project.open();
    await EditorPanelProject.startPanels(vm);
    await until(() => vm.editorPanels.panel(id) != null);
    expect(vm.editorPanels.trustOf(id), EditorPanelTrust.trusted, reason: 'stored in editor_panel_trust.json');
    expect(File(p.join(LuminaDataDir.resolve().path, EditorPanelTrustStore.fileName)).existsSync(), isTrue);

    await batch(caps: {LuminaEditorPanelCapability.level, LuminaEditorPanelCapability.assets}).writeTo(file);
    await until(() => vm.editorPanels.panel(id)!.info.allows(LuminaEditorPanelCapability.assets), reason: 'the reload');
    expect(vm.editorPanels.trustOf(id), EditorPanelTrust.untrusted, reason: 'assets added: asked again');
  });

  testWidgets('a plugin panel runs without a prompt and the import confirmation lists it with its capabilities',
      (tester) async {
    // A plugin folder with an editor panel, imported into the user plugin dir.
    final source = Directory(p.join(project.root.path, 'downloads', 'prop_tools'))..createSync(recursive: true);
    File(p.join(source.path, 'prop_tools.lmplugin')).writeAsStringSync(jsonEncode({
      'name': 'prop_tools',
      'friendly_name': 'Prop Tools',
      'version': '1.0.0',
      'category': 'Editor',
      'can_contain_content': true,
    }));
    final panel = EpwBuilder('EPW_PropTools', LuminaEditorPanelInfo(title: 'Prop Tools', dock: LuminaEditorPanelDock.right, capabilities: {LuminaEditorPanelCapability.level, LuminaEditorPanelCapability.process}));
    panel.element(UmgWidgetType.text, 'Hello', props: {'text': 'Prop Tools ready'});
    await tester.runAsync(() => panel.writeTo(p.join(source.path, 'content', 'EPW_PropTools.lmas')));
    final manager = PluginManagerViewModel(registryService: vm.pluginRegistry, folderPicker: () async => source.path);
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late BuildContext context;
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(child: Builder(builder: (c) {
        context = c;
        return const SizedBox.expand();
      })),
    ));
    await tester.runAsync(() => startPluginImport(context, manager, PluginImportSource.folder));
    await frames(tester);
    expect(find.byKey(const ValueKey('plugin_import_done_dialog')), findsOneWidget);
    expect(find.byKey(const ValueKey('editor_panel_summary_list')), findsOneWidget);
    expect(find.textContaining('Prop Tools · right'), findsOneWidget);
    expect(find.textContaining('edit level actors, talk to its plugin process'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('plugin_import_ok')));
    await frames(tester);

    // Enabled: its panel runs with no trust prompt.
    await tester.runAsync(() async {
      await vm.rescanPlugins();
      final r = await vm.enablePlugin('prop_tools', true);
      expect(r.restartRequired, isFalse);
      await until(() => vm.editorPanels.panel('prop_tools/content/EPW_PropTools.lmas') != null, reason: 'the plugin panel');
    });
    const pluginPanel = 'prop_tools/content/EPW_PropTools.lmas';
    expect(vm.editorPanels.trustOf(pluginPanel), EditorPanelTrust.plugin);
    vm.editorPanelDocking.open(pluginPanel);
    expect(vm.editorPanels.instancesOf(pluginPanel).single.constructed, isTrue);
    vm.editorPanelDocking.close(pluginPanel);
    manager.dispose();
  });

  testWidgets('an endless loop is stopped by the step budget; the panel says so and the editor stays responsive',
      (tester) async {
    await tester.runAsync(() => vm.editorPanels.trustProjectPanels());
    await pumpPanel(tester);
    final instance = vm.editorPanels.instancesOf(id).single;
    final watch = Stopwatch()..start();
    await tester.tap(find.text('Spin'));
    await tester.pump();
    final frame = watch.elapsedMilliseconds;
    await frames(tester);
    expect(frame, lessThan(300), reason: 'the frame that ran the event stayed under 300 ms');
    expect(instance.stoppedMessage, 'Stopped: On Clicked (SpinButton) ran too long');
    expect(find.textContaining('ran too long'), findsOneWidget);
    expect(find.byKey(const ValueKey('editor_panel_banner_Reload')), findsOneWidget);
    expect((instance.script!.variables['I'] as int), greaterThan(1000));
    vm.editorPanelDocking.close(id);
    await frames(tester);
  });
}
