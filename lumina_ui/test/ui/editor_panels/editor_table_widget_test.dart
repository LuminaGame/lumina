import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart' show EditorAssetPicker;
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/core/editor_panels/editor_panel_view.dart';
import 'package:lumina_ui/ui/core/editor_panels/widgets/table/editor_table.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'editor_panel_fixture.dart';
import 'native_widget_harness.dart';

/// The native table: one On Cell Committed per edit, asset cells through
/// the editor's asset picker, a 2,000-row sort within a frame, and Shift
/// multi-selection.
void main() {
  const name = 'Mapping';

  Map<String, Object?> table({int rows = 3}) => {
        'columns': [
          {'id': 'bone', 'label': 'Bone', 'kind': 'text', 'width': 140},
          {'id': 'weight', 'label': 'Weight', 'kind': 'number', 'editable': true, 'width': 90},
          {'id': 'axis', 'label': 'Axis', 'kind': 'enum', 'editable': true, 'options': ['X', 'Y', 'Z'], 'width': 80},
          {'id': 'mesh', 'label': 'Mesh', 'kind': 'assetRef', 'editable': true, 'typeFilter': 'SkeletalMesh', 'width': 220},
        ],
        'rows': [
          for (var i = 0; i < rows; i++)
            {
              'id': 'r$i',
              'cells': {'bone': 'bone_${(rows - i).toString().padLeft(4, '0')}', 'weight': i, 'axis': 'X', 'mesh': null},
            },
        ],
        'selection': 'multi',
        'selected': <Object?>[],
      };

  group('bare', () {
    Future<(NativeWidgetHarness, EditorTableState)> mount(WidgetTester tester, {int rows = 3}) async {
      final h = NativeWidgetHarness(table(rows: rows));
      await h.pump(tester, (s) => EditorTable(name: name, state: s, onEvent: h.onEvent, onState: h.onState), size: const Size(640, 600));
      return (h, tester.state<EditorTableState>(find.byType(EditorTable)));
    }

    /// A double click with real pointer times (the table tells a double
    /// click from them).
    Future<void> doubleClick(WidgetTester tester, Offset at) async {
      final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await g.down(at, timeStamp: const Duration(seconds: 10));
      await g.up(timeStamp: const Duration(seconds: 10, milliseconds: 60));
      await tester.pump(const Duration(milliseconds: 100));
      await g.down(at, timeStamp: const Duration(seconds: 10, milliseconds: 180));
      await g.up(timeStamp: const Duration(seconds: 10, milliseconds: 240));
      await tester.pump(const Duration(milliseconds: 100));
      await g.removePointer();
    }

    Finder cell(String row, String column) => find.byKey(ValueKey('editor_table_${name}_cell_${row}_$column'));

    testWidgets('editing a number cell commits one On Cell Committed', (tester) async {
      final (h, _) = await mount(tester);
      expect(tester.getSize(find.byKey(const ValueKey('editor_table_${name}_row_r1'))).height, inInclusiveRange(22, 24));
      await doubleClick(tester, tester.getCenter(cell('r1', 'weight')));
      final field = find.byKey(const ValueKey('editor_table_cell_field'));
      expect(field, findsOneWidget);
      await tester.enterText(field, '0.75');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      final commits = h.named(LuminaEditorWidgetEvents.onCellCommitted);
      expect(commits, hasLength(1));
      expect(commits.single.args, {'row_id': 'r1', 'column_id': 'weight', 'value': 0.75, 'text': '0.75'});
      expect(((h.state.value['rows']! as List)[1] as Map)['cells'], containsPair('weight', 0.75));
      expect(field, findsNothing);
      expect(find.descendant(of: cell('r1', 'weight'), matching: find.text('0.75')), findsOneWidget);
    });

    testWidgets('sorting by a column reorders 2,000 rows: the sort fits a frame and only the visible rows build', (tester) async {
      final (h, s) = await mount(tester, rows: 2000);
      expect(s.lines.first.row!.id, 'r0');
      final header = find.byKey(const ValueKey('editor_table_${name}_header_bone'));
      // Warm up: the first sorts compile the sort and row paths (debug JIT).
      for (final c in ['weight', 'bone', 'bone', 'weight']) {
        await tester.tap(find.byKey(ValueKey('editor_table_${name}_header_$c')));
        await tester.pump();
      }
      h.events.clear();
      final built = s.linesBuilt;
      // The table's own work for a sort (2,000 rows reordered, the body
      // relaid) runs in the tap; the frame then builds the visible rows only.
      await tester.tap(header);
      await tester.pump();
      expect(s.lines.first.row!.id, 'r1999', reason: 'bone_0001 first');
      expect(s.lastRelayout.inMilliseconds, lessThan(16), reason: 'sorting 2,000 rows fits a frame');
      expect(s.linesBuilt - built, lessThanOrEqualTo(40), reason: 'virtualised: ~25 visible rows of 2,000');
      expect(h.named(LuminaEditorWidgetEvents.onSortChanged).single.args, {'column': 'bone', 'ascending': true});
      await tester.tap(header);
      await tester.pump();
      expect(s.lines.first.row!.id, 'r0');
      expect(s.lastRelayout.inMilliseconds, lessThan(16));
      expect(find.byKey(const ValueKey('editor_table_${name}_row_r1500')), findsNothing, reason: 'virtualised');
      expect(h.state.value['sort'], {'column': 'bone', 'ascending': false});
    });

    testWidgets('multi-select with Shift selects the range', (tester) async {
      final (h, _) = await mount(tester, rows: 6);
      await tester.tap(cell('r1', 'bone'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.tap(cell('r4', 'bone'));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump(const Duration(milliseconds: 400));
      expect(h.named(LuminaEditorWidgetEvents.onRowSelected).last.args, {'row_ids': ['r1', 'r2', 'r3', 'r4']});
      expect(h.state.value['selected'], ['r1', 'r2', 'r3', 'r4']);
      final selected = tester.widget<Container>(find.byKey(const ValueKey('editor_table_${name}_row_r3')));
      expect((selected.decoration! as BoxDecoration).color, EditorColors.selectionBg);
      // Right click: the row's context menu event.
      await tester.tapAt(tester.getCenter(cell('r5', 'bone')), buttons: kSecondaryMouseButton, kind: PointerDeviceKind.mouse);
      await tester.pump(const Duration(milliseconds: 400));
      expect(h.named(LuminaEditorWidgetEvents.onRowContextMenu).single.args, {'row_id': 'r5'});
    });
  });

  group('in an editor panel', () {
    late EditorPanelProject project;
    late EditorViewModel vm;
    const id = 'project/contents/editor/EPW_Mapping.lmas';

    setUp(() async {
      project = await EditorPanelProject.create('TablePanels');
      final b = EpwBuilder('EPW_Mapping', LuminaEditorPanelInfo(title: 'Mapping', dock: LuminaEditorPanelDock.right));
      final t = b.element(UmgWidgetType.editorTable, name, props: table());
      t.slot
        ..fill = true
        ..flex = 1;
      b.variable('Picked', 'String', '');
      b.onElement('cell', name, LuminaEditorWidgetEvents.onCellCommitted);
      b.node(LuminaBlueprintNodeLibrary.variableSet, 'set', {'variable': 'Picked'});
      b.wire('cell', 'exec_out', 'set');
      b.wire('cell', 'column_id', 'set', 'value');
      await b.writeTo(project.projectPath('contents/editor/EPW_Mapping.lmas'));
      // The mannequin as an import writes a skeletal mesh: the .lmas with its GLB payload.
      final glb = await File(testAsset('mannequin/MM_Idle.glb')).readAsBytes();
      final skm = File(project.projectPath('contents/meshes/skeletal/SKM_Mannequin.lmas'));
      await skm.parent.create(recursive: true);
      await skm.writeAsBytes(LuminaAsset(assetId: 'skm_mannequin', name: 'SKM_Mannequin', type: AssetType.filameshSk, rawPayload: glb, metadata: const {
        'payload_format': 'glb',
      }).toProtoBufferBytes());
      await File(project.projectPath('contents/meshes/skeletal/SKM_Mannequin.entity.glb')).writeAsBytes(glb);
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

    testWidgets('an assetRef cell opens EditorAssetPicker filtered to SkeletalMesh and commits the picked path', (tester) async {
      tester.view.physicalSize = const Size(900, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(child: EditorPanelView(host: vm.editorPanels, panelId: id)),
      ));
      await frames(tester, 10);
      final panel = vm.editorPanels.instancesOf(id).single;
      final pickers = find.byType(EditorAssetPicker);
      expect(pickers, findsNWidgets(3), reason: 'one per row');
      final picker = tester.widget<EditorAssetPicker>(pickers.at(1));
      expect(picker.typeFilter, {AssetType.filameshSk});
      await tester.tap(find.descendant(of: pickers.at(1), matching: find.byKey(const ValueKey('asset_picker_value'))));
      await frames(tester, 5);
      final skeletal = vm.realAssets.firstWhere((a) => a.type == AssetType.filameshSk);
      bool listed(String prefix) => find
          .byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('asset_picker_item_$prefix'))
          .evaluate()
          .isNotEmpty;
      expect(listed(skeletal.fileName.split('.').first), isTrue);
      expect(listed('fuel_barrel_red'), isFalse, reason: 'static meshes are filtered out');
      await tester.enterText(find.byKey(const ValueKey('asset_picker_search')), skeletal.fileName.split('.').first);
      await frames(tester, 3);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await frames(tester, 5);
      final rows = panel.element(name)!['rows']! as List;
      expect(((rows[1] as Map)['cells'] as Map)['mesh'], skeletal.relativePath);
      expect(panel.script!.variables['Picked'], 'mesh', reason: 'On Cell Committed ran the graph once');
      vm.editorPanelDocking.close(id);
      await frames(tester, 5);
    });
  });
}
