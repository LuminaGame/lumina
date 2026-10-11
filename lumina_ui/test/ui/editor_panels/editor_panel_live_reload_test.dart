import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/core/editor_panels/editor_panel_runtime.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:path/path.dart' as p;

import 'editor_panel_fixture.dart';

/// Live reload on real files: saving a panel swaps the running instance in
/// place within 500 ms (typed text and matching variables kept), a broken
/// save keeps the last good version running under an error banner, and
/// disabling the plugin removes its panel and menu items with no restart.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late EditorPanelProject project;
  late EditorViewModel vm;
  late String file;
  const id = 'prop_tools/content/EPW_Rename.lmas';

  EpwBuilder rename({String label = 'Rename', bool broken = false}) {
    final b = EpwBuilder('EPW_Rename', LuminaEditorPanelInfo(title: 'Rename', dock: LuminaEditorPanelDock.right));
    b.element(UmgWidgetType.editableText, 'NameField', props: {'text': ''});
    b.element(UmgWidgetType.button, 'RenameButton', props: {'label': label});
    b.variable('Count', 'Int', 0);
    b.variable('Note', 'String', 'fresh');
    b.onElement('click', 'RenameButton', 'OnClicked');
    b.node(LuminaBlueprintNodeLibrary.variableGet, 'get', {'variable': 'Count'});
    b.node('int_add', 'add', {'b': 1});
    b.node(LuminaBlueprintNodeLibrary.variableSet, 'set', {'variable': 'Count'});
    b.wire('click', 'exec_out', 'set');
    b.wire('get', 'value', 'add', 'a');
    b.wire('add', 'return_value', 'set', 'value');
    if (broken) b.onElement('bad', 'RenameButton', 'OnTextCommitted');
    return b;
  }

  setUp(() async {
    project = await EditorPanelProject.create('ReloadPanels', plugins: ['prop_tools']);
    final plugin = project.writePlugin('prop_tools', friendlyName: 'Prop Tools');
    file = p.join(plugin.path, 'content', 'EPW_Rename.lmas');
    await rename().writeTo(file);
    vm = await project.open();
    await EditorPanelProject.startPanels(vm);
    await until(() => vm.editorPanels.panel(id) != null, reason: 'the plugin panel');
  });

  tearDown(() async {
    await vm.close();
    await project.dispose();
  });

  EditorPanelInstance openPanel() {
    vm.editorPanelDocking.open(id);
    return vm.editorPanels.instancesOf(id).single;
  }

  test('a save swaps the running panel within 500 ms, keeping typed text and matching variables', () async {
    final panel = openPanel();
    final first = panel.runtime;
    // The user typed into the field (what the renderer writes) and clicked twice.
    LuminaUmgElementBinding.write(panel.map, 'NameField', 'text', 'Barrel_');
    vm.editorPanels.fire(panel, 'RenameButton', 'OnClicked');
    vm.editorPanels.fire(panel, 'RenameButton', 'OnClicked');
    expect(panel.script!.variables['Count'], 2);

    Duration? took;
    vm.editorPanels.onReloaded = (panelId, d) => took = d;
    final saved = Stopwatch()..start();
    await rename(label: 'Rename All').writeTo(file);
    await until(() => !identical(panel.runtime, first), timeout: const Duration(seconds: 5), reason: 'the reload');
    final swap = saved.elapsed;
    expect(swap, lessThan(const Duration(milliseconds: 500)));
    expect(took, isNotNull);
    expect(panel.element('RenameButton')!['label'], 'Rename All');
    expect(panel.element('NameField')!['text'], 'Barrel_', reason: 'the typed value is kept');
    expect(panel.script!.variables['Count'], 2, reason: 'a variable of the same name and type is kept');
    vm.editorPanels.fire(panel, 'RenameButton', 'OnClicked');
    expect(panel.script!.variables['Count'], 3, reason: 'the new script runs');
  });

  test('a save with a graph error keeps the last good version running under the error banner', () async {
    final panel = openPanel();
    final good = panel.runtime;
    await rename(label: 'Broken', broken: true).writeTo(file);
    await until(() => panel.reloadErrors != null, timeout: const Duration(seconds: 5), reason: 'the failed reload');
    expect(identical(panel.runtime, good), isTrue);
    expect(panel.reloadErrors!.single, contains('OnTextCommitted'));
    vm.editorPanels.fire(panel, 'RenameButton', 'OnClicked');
    expect(panel.script!.variables['Count'], 1, reason: 'the last good version still runs');
    expect(panel.element('RenameButton')!['label'], 'Rename');
  });

  test('disabling the plugin removes its panel and menu items without a restart', () async {
    openPanel();
    bool listed() => vm.extensionRegistry.menuEntriesUnder('Plugins').any((e) => e.path == 'Plugins/Prop Tools/Rename');
    expect(listed(), isTrue);
    expect(vm.extensionRegistry.allPanels.any((d) => d.id.endsWith(id)), isTrue);
    final result = await vm.enablePlugin('prop_tools', false);
    expect(result.restartRequired, isFalse, reason: 'a content plugin needs no restart');
    await until(() => vm.editorPanels.panel(id) == null, reason: 'the panel to go');
    expect(vm.editorPanels.isOpen(id), isFalse);
    expect(listed(), isFalse);
    expect(vm.extensionRegistry.allPanels.any((d) => d.id.endsWith(id)), isFalse);
    expect(vm.pluginRestartRequired, isFalse);
  });
}
