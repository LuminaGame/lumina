import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/core/editor_panels/editor_panel_host.dart';
import 'package:lumina_ui/ui/core/editor_panels/editor_panel_runtime.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';

import 'editor_panel_fixture.dart';

/// The editor library's level nodes on a real project and level with real
/// imported props: a project editor panel finds actors by label, edits them
/// inside one transaction (one Edit ▸ Undo step), and a transaction it leaves
/// open is ended by the editor with a warning.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late EditorPanelProject project;
  late EditorViewModel vm;
  late Map<String, String> ids;

  Map<String, dynamic> at(double x) => {
        'location': [x, 0.0, 0.0],
        'rotation': [0.0, 0.0, 0.0],
        'scale': [1.0, 1.0, 1.0],
      };

  EpwBuilder levelTools() {
    final b = EpwBuilder('EPW_LevelTools',
        LuminaEditorPanelInfo(title: 'Level Tools', dock: LuminaEditorPanelDock.right, capabilities: {LuminaEditorPanelCapability.level}));
    b.element(UmgWidgetType.text, 'StatusText', props: {'text': 'Idle'});
    b.variable('Ids', 'Array:String', <Object?>[]);
    // FindBarrels → Ids = Get Level Actors (Label Filter "Barrel*").
    b.customEvent('find', 'FindBarrels');
    b.node('editor_get_level_actors', 'actors', {'label_filter': 'Barrel*'});
    b.node(LuminaBlueprintNodeLibrary.variableSet, 'set_ids', {'variable': 'Ids'});
    b.wire('find', 'exec_out', 'set_ids');
    b.wire('actors', 'return_value', 'set_ids', 'value');
    // LineUp (A, B) → Begin "Line up" → Set A → Set B → End.
    b.customEvent('line_up', 'LineUp', ['A', 'B']);
    b.node('editor_begin_transaction', 'begin', {'label': 'Line up'});
    b.node('editor_set_actor_transform', 'set_a', {'transform': at(0)});
    b.node('editor_set_actor_transform', 'set_b', {'transform': at(100)});
    b.node('editor_end_transaction', 'end');
    b.chain(['line_up', 'begin', 'set_a', 'set_b', 'end']);
    b.wire('line_up', 'A', 'set_a', 'actor_id');
    b.wire('line_up', 'B', 'set_b', 'actor_id');
    b.wire('begin', 'return_value', 'end', 'transaction');
    // LeaveOpen (A) → Begin "Nudge" → Set A (no End).
    b.customEvent('leave', 'LeaveOpen', ['A']);
    b.node('editor_begin_transaction', 'begin2', {'label': 'Nudge'});
    b.node('editor_set_actor_transform', 'set_c', {'transform': at(500)});
    b.chain(['leave', 'begin2', 'set_c']);
    b.wire('leave', 'A', 'set_c', 'actor_id');
    return b;
  }

  setUp(() async {
    project = await EditorPanelProject.create('LevelPanels');
    await levelTools().writeTo(project.projectPath('contents/editor/EPW_LevelTools.lmas'));
    vm = await project.open();
    await vm.ensureDefaultLevelAssets();
    await vm.processImportPipeline(sourceFilePath: testAsset('Props/Barrels/fuel_barrel_red.glb'));
    await vm.processImportPipeline(sourceFilePath: testAsset('Props/AC_units/aircon_small.glb'));
    RealAssetInfo mesh(String name) => vm.realAssets.firstWhere((a) => a.type == AssetType.filamesh && a.fileName.contains(name));
    ids = {};
    for (final (asset, label) in [(mesh('fuel_barrel_red'), 'Barrel_A'), (mesh('fuel_barrel_red'), 'Barrel_B'), (mesh('aircon_small'), 'AC_Unit')]) {
      final before = {for (final a in vm.actors) a.id};
      await vm.spawnActorFromAsset(asset, location: [300, 300, 0]);
      final added = vm.actors.firstWhere((a) => !before.contains(a.id));
      vm.renameActorWithTransaction(added.id, label);
      ids[label] = added.id;
    }
    await EditorPanelProject.startPanels(vm);
    await until(() => vm.editorPanels.panels.isNotEmpty, reason: 'the panel to be found');
    await vm.editorPanels.trustProjectPanels();
  });

  tearDown(() async {
    await vm.close();
    await project.dispose();
  });

  EditorPanelInstance openPanel() {
    final id = vm.editorPanels.panels.keys.single;
    expect(vm.editorPanels.panel(id)!.errors, isEmpty);
    expect(vm.editorPanels.trustOf(id), EditorPanelTrust.trusted);
    expect(vm.editorPanels.panel(id)!.graphClass, isNotNull);
    vm.editorPanelDocking.open(id);
    return vm.editorPanels.instancesOf(id).single;
  }

  test('Get Level Actors with a label filter finds the two barrels', () async {
    final panel = openPanel();
    panel.script!.callBlueprint('FindBarrels', const {});
    expect(panel.script!.variables['Ids'], unorderedEquals([ids['Barrel_A'], ids['Barrel_B']]));
  });

  test('Get Level Actor Tree groups the level actors by type for a Tree View', () async {
    final panel = openPanel();
    final tree = LuminaBlueprintFunctionLibrary.functions['editor_get_level_actor_tree']!(
        LuminaBlueprintCallContext(panel.script!), {'label_filter': '*'})['return_value'] as List;
    final found = [for (final folder in tree) for (final a in (folder as Map)['children'] as List) (a as Map)['id']];
    expect(found, containsAll([ids['Barrel_A'], ids['Barrel_B'], ids['AC_Unit']]));
    final barrels = LuminaBlueprintFunctionLibrary.functions['editor_get_level_actor_tree']!(
        LuminaBlueprintCallContext(panel.script!), {'label_filter': 'Barrel*'})['return_value'] as List;
    expect([for (final f in barrels) ...((f as Map)['children'] as List).map((a) => (a as Map)['label'])], unorderedEquals(['Barrel_A', 'Barrel_B']));
  });

  test('a transaction of two Set Actor Transform is one undo step that restores both', () async {
    final panel = openPanel();
    final a = vm.actors.firstWhere((x) => x.id == ids['Barrel_A']);
    final b = vm.actors.firstWhere((x) => x.id == ids['Barrel_B']);
    final before = (List<double>.of(a.location), List<double>.of(b.location));
    final depth = vm.transactions.history().length;
    panel.script!.callBlueprint('LineUp', {'A': a.id, 'B': b.id});
    await pumpEventQueue();
    expect(a.location, [0.0, 0.0, 0.0]);
    expect(b.location, [100.0, 0.0, 0.0]);
    expect(vm.transactions.undoLabel, 'Undo Line up');
    expect(vm.transactions.history().length, depth + 1, reason: 'one step for both edits');
    vm.commands.execute('edit.undo');
    expect(a.location, before.$1);
    expect(b.location, before.$2);
    vm.commands.execute('edit.redo');
    expect(b.location, [100.0, 0.0, 0.0]);
  });

  test('a transaction left open is ended by the host with a warning in the Output Log', () async {
    final panel = openPanel();
    final a = ids['Barrel_A']!;
    panel.script!.callBlueprint('LeaveOpen', {'A': a});
    await pumpEventQueue();
    expect(vm.editorPanels.transactions.openOf(panel), isNull);
    expect(vm.transactions.undoLabel, 'Undo Nudge');
    expect(vm.logger.logs.map((l) => l.message), contains(contains("transaction 'Nudge' was left open")));
    expect(vm.actors.firstWhere((x) => x.id == a).location, [500.0, 0.0, 0.0]);
  });
}
