import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart' show EditorAssetPicker;
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/core/editor_panels/editor_panel_runtime.dart';
import 'package:lumina_ui/ui/core/editor_panels/editor_panel_view.dart';
import 'package:lumina_ui/ui/core/editor_panels/widgets/editor_tree_view.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'editor_panel_fixture.dart';

/// The editor widget set in a running panel: a three-level Tree View in the
/// Outliner's row style, a Resizable Split that honours its minimums and
/// keeps its split, and the Asset Picker element (the editor's
/// EditorAssetPicker) firing On Asset Picked.
void main() {
  late EditorPanelProject project;
  late EditorViewModel vm;
  const id = 'project/contents/editor/EPW_Widgets.lmas';

  EpwBuilder widgets() {
    final b = EpwBuilder('EPW_Widgets', LuminaEditorPanelInfo(title: 'Widgets', dock: LuminaEditorPanelDock.right));
    b.element(UmgWidgetType.assetPicker, 'Picker', props: {'typeFilter': 'StaticMesh', 'placeholder': 'Pick a mesh'});
    b.element(UmgWidgetType.treeView, 'Tree', props: {
      'items': [
        {
          'id': 'level',
          'label': 'L_Main',
          'children': [
            {
              'id': 'props',
              'label': 'Props',
              'children': [
                {'id': 'barrel', 'label': 'Barrel_A', 'icon': 'box'},
              ],
            },
          ],
        },
      ],
    });
    final split = b.element(UmgWidgetType.resizableSplit, 'Split',
        props: {'orientation': 'horizontal', 'split': 0.3, 'minFirst': 150.0, 'minSecond': 120.0});
    split.slot.fill = true;
    b.element(UmgWidgetType.text, 'Left', props: {'text': 'left pane'}, parent: split.id);
    b.element(UmgWidgetType.text, 'Right', props: {'text': 'right pane'}, parent: split.id);
    b.document.findNode('n_Tree')!.slot
      ..fill = true
      ..flex = 1;
    b.variable('Selected', 'String', '');
    b.variable('Picked', 'String', '');
    b.onElement('sel', 'Tree', LuminaEditorWidgetEvents.onItemSelected);
    b.node(LuminaBlueprintNodeLibrary.variableSet, 'set_sel', {'variable': 'Selected'});
    b.wire('sel', 'exec_out', 'set_sel');
    b.wire('sel', 'item_id', 'set_sel', 'value');
    b.onElement('pick', 'Picker', LuminaEditorWidgetEvents.onAssetPicked);
    b.node(LuminaBlueprintNodeLibrary.variableSet, 'set_pick', {'variable': 'Picked'});
    b.wire('pick', 'exec_out', 'set_pick');
    b.wire('pick', 'asset_path', 'set_pick', 'value');
    return b;
  }

  setUp(() async {
    project = await EditorPanelProject.create('WidgetPanels');
    await widgets().writeTo(project.projectPath('contents/editor/EPW_Widgets.lmas'));
    vm = await project.open();
    await vm.ensureDefaultLevelAssets();
    await vm.processImportPipeline(sourceFilePath: testAsset('Props/Barrels/fuel_barrel_red.glb'));
    await EditorPanelProject.startPanels(vm);
    await until(() => vm.editorPanels.panel(id) != null, reason: 'the panel');
    expect(vm.editorPanels.panel(id)!.errors, isEmpty);
    await vm.editorPanels.trustProjectPanels();
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

  Future<EditorPanelInstance> pumpPanel(WidgetTester tester, {Key? key}) async {
    tester.view.physicalSize = const Size(600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(child: KeyedSubtree(key: key ?? const ValueKey('first'), child: EditorPanelView(host: vm.editorPanels, panelId: id))),
    ));
    await frames(tester);
    return vm.editorPanels.instancesOf(id).single;
  }

  Future<void> closeAll(WidgetTester tester) async {
    vm.editorPanelDocking.close(id);
    await frames(tester);
  }

  testWidgets('Tree View: three levels in Outliner rows, chevrons, selection highlight, On Item Selected', (tester) async {
    final panel = await pumpPanel(tester);
    Finder row(String item) => find.byKey(ValueKey('editor_tree_row_Tree_$item'));
    expect(row('level'), findsOneWidget);
    expect(row('props'), findsNothing, reason: 'collapsed');
    final height = tester.getSize(row('level')).height;
    expect(height, inInclusiveRange(22, 24));
    expect(find.descendant(of: row('level'), matching: find.byIcon(LucideIcons.chevronRight)), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('editor_tree_chevron_Tree_level')));
    await frames(tester);
    expect(find.descendant(of: row('level'), matching: find.byIcon(LucideIcons.chevronDown)), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('editor_tree_chevron_Tree_props')));
    await frames(tester);
    expect(row('barrel'), findsOneWidget, reason: 'the third level');
    expect(tester.getTopLeft(row('barrel')).dx, tester.getTopLeft(row('level')).dx);
    // Indent per depth inside the row.
    final iconX = tester.getTopLeft(find.descendant(of: row('barrel'), matching: find.byIcon(LucideIcons.box))).dx;
    final levelIconX = tester.getTopLeft(find.descendant(of: row('level'), matching: find.byIcon(LucideIcons.folder))).dx;
    expect(iconX - levelIconX, greaterThan(20));
    await tester.tap(row('barrel'));
    await tester.pump(const Duration(milliseconds: 400));
    await frames(tester);
    expect(panel.script!.variables['Selected'], 'barrel');
    expect(panel.element('Tree')!['selected'], ['barrel']);
    final box = tester.widget<Container>(find.descendant(of: row('barrel'), matching: find.byType(Container)).first);
    expect((box.decoration! as BoxDecoration).color, EditorColors.selectionBg);
    expect(tester.widget<EditorTreeView>(find.byType(EditorTreeView)).selected, ['barrel']);
    await closeAll(tester);
  });

  testWidgets('Resizable Split honours its minimum sizes and keeps its split', (tester) async {
    final panel = await pumpPanel(tester);
    final left = find.byKey(const ValueKey('editor_split_Split_first')).first;
    final width = tester.getSize(left).width;
    expect(width, greaterThanOrEqualTo(150));
    // Drag the divider far to the left: the first pane stops at 150.
    Offset divider() => tester.getRect(left).centerRight + const Offset(2, 0);
    await tester.dragFrom(divider(), const Offset(-400, 0));
    await frames(tester);
    expect(tester.getSize(left).width, closeTo(150, 1), reason: 'stops at its minimum');
    // Drag it right: the split is kept in the element state.
    await tester.dragFrom(divider(), const Offset(140, 0));
    await frames(tester);
    expect(tester.getSize(left).width, closeTo(290, 2));
    final kept = tester.getSize(left).width;
    final split = panel.element('Split')!['split'];
    expect(split, isA<double>());
    // Shown again: the same split.
    await tester.pumpWidget(const SizedBox());
    await frames(tester, 3);
    await pumpPanel(tester, key: const ValueKey('again'));
    expect(tester.getSize(find.byKey(const ValueKey('editor_split_Split_first')).first).width, closeTo(kept, 2));
    await closeAll(tester);
  });

  testWidgets('the Asset Picker element is the editor\'s asset picker and fires On Asset Picked', (tester) async {
    final panel = await pumpPanel(tester);
    expect(find.byType(EditorAssetPicker), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('asset_picker_value')));
    await frames(tester);
    final item = find.byWidgetPredicate(
        (w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('asset_picker_item_fuel_barrel_red'));
    expect(item, findsOneWidget, reason: 'the picker lists the static meshes');
    // Choose it from the keyboard: search, Enter.
    await tester.enterText(find.byKey(const ValueKey('asset_picker_search')), 'fuel_barrel');
    await frames(tester, 3);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await frames(tester);
    final mesh = vm.realAssets.firstWhere((a) => a.type == AssetType.filamesh).relativePath;
    expect(panel.script!.variables['Picked'], mesh);
    expect(panel.element('Picker')!['value'], mesh);
    await closeAll(tester);
  });
}
