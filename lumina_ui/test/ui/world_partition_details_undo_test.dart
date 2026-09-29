import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/data/services/level_template_service.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/details_widget.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../helpers/temp_project.dart';

/// Every World Partition and data layer edit — from the
/// Details panel or an MCP tool — is one level undo step, a scrub included;
/// and `levelFiles` is the list the Open Level dialog and `list_levels` show.
void main() {
  late Directory tempDir;
  late Directory projDir;

  const project = LuminaProject(projectName: 'WpUndo', activeLevel: 'contents/levels/L_Main.lmas');

  Future<EditorViewModel> openEditor() async {
    final vm = EditorViewModel(initialProject: project, projectLocation: tempDir.path, enableTimers: false);
    await vm.ensureDefaultLevelAssets();
    return vm;
  }

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('lumina_wp_undo_');
    projDir = Directory('${tempDir.path}/WpUndo')..createSync(recursive: true);
    Directory('${projDir.path}/contents/levels').createSync(recursive: true);
    File('${projDir.path}/WpUndo.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
  });

  tearDown(() => deleteTempProject(tempDir));

  test('each setter is one undo step; undo walks back to no section at all', () async {
    final vm = await openEditor();
    addTearDown(vm.close);
    expect(vm.levelWorldPartition, isEmpty);
    final depth = vm.transactions.history(limit: 500).length;

    vm.setWorldPartitionEnabled(true);
    vm.setWorldPartitionCellSize(25600);
    vm.setWorldPartitionLoadingRange(50000);
    vm.setWorldPartitionMaxCellTransitionsPerTick(4);
    vm.addWorldPartitionDataLayer('Interiors');
    vm.setWorldPartitionDataLayerName(0, 'Rooms');
    vm.setWorldPartitionDataLayerState(0, 'activated');
    vm.addWorldPartitionDataLayer('Interiors');
    vm.removeWorldPartitionDataLayer(1);
    expect(vm.transactions.history(limit: 500).length, depth + 9);
    expect(vm.transactions.undoLabel, 'Undo Remove Data Layer Interiors');

    vm.transactions.undo();
    expect(vm.worldPartitionDataLayers.map((l) => l['name']), ['Rooms', 'Interiors']);
    vm.transactions.undo();
    vm.transactions.undo();
    expect(vm.worldPartitionDataLayers.single['initialState'], 'unloaded');
    vm.transactions.undo();
    expect(vm.worldPartitionDataLayers.single['name'], 'Interiors');
    vm.transactions.undo();
    expect(vm.worldPartitionDataLayers, isEmpty);
    vm.transactions.undo();
    expect(vm.worldPartitionMaxCellTransitionsPerTick, kWorldPartitionDefaultMaxCellTransitionsPerTick);
    vm.transactions.undo();
    expect(vm.worldPartitionLoadingRange, kWorldPartitionDefaultLoadingRange);
    vm.transactions.undo();
    expect(vm.worldPartitionCellSize, kWorldPartitionDefaultCellSize);
    vm.transactions.undo();
    expect(vm.levelWorldPartition, isEmpty, reason: 'undoing Enable removes the section it seeded');
    expect(vm.worldPartitionEnabled, isFalse);

    for (var i = 0; i < 9; i++) {
      vm.transactions.redo();
    }
    expect(vm.worldPartitionCellSize, 25600);
    expect(vm.worldPartitionDataLayers.single['name'], 'Rooms');
    expect(vm.worldPartitionDataLayers.single['initialState'], 'activated');
  });

  test('a scrub previews without recording and commits one step from the pre-gesture value', () async {
    final vm = await openEditor();
    addTearDown(vm.close);
    vm.setWorldPartitionEnabled(true);
    final depth = vm.transactions.history(limit: 500).length;
    vm.setWorldPartitionCellSize(13000, commit: false);
    vm.setWorldPartitionCellSize(15000, commit: false);
    expect(vm.worldPartitionCellSize, 15000, reason: 'the preview is live');
    expect(vm.transactions.history(limit: 500).length, depth);
    vm.setWorldPartitionCellSize(16000);
    expect(vm.transactions.history(limit: 500).length, depth + 1);
    vm.transactions.undo();
    expect(vm.worldPartitionCellSize, kWorldPartitionDefaultCellSize);
    // An unchanged value records nothing.
    vm.setWorldPartitionCellSize(kWorldPartitionDefaultCellSize);
    expect(vm.transactions.history(limit: 500).length, depth);
  });

  testWidgets('Details: enabling and adding a layer are undoable from the panel', (tester) async {
    late EditorViewModel vm;
    await tester.runAsync(() async => vm = await openEditor());
    addTearDown(vm.dispose);
    vm.clearSelection();
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: SizedBox(width: 340, height: 900, child: DetailsWidget(viewModel: vm)),
    ));
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.byKey(const ValueKey('wp_enabled')));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byKey(const ValueKey('wp_add_layer')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(vm.worldPartitionDataLayers, hasLength(1));
    expect(vm.transactions.undoLabel, 'Undo Add Data Layer DataLayer');

    vm.transactions.undo();
    await tester.pump(const Duration(milliseconds: 200));
    expect(vm.worldPartitionDataLayers, isEmpty);
    expect(find.byKey(const ValueKey('wp_layer_name_0')), findsNothing);
    vm.transactions.undo();
    await tester.pump(const Duration(milliseconds: 200));
    expect(vm.worldPartitionEnabled, isFalse);
    expect(find.byKey(const ValueKey('wp_cell_size')), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  test('levelFiles: the project\'s contents/levels/*.lmas, relative and sorted', () async {
    final vm = await openEditor();
    addTearDown(vm.close);
    await vm.createLevelFromTemplate('L_Beta', kEmptyLevelTemplateId);
    await vm.createLevelFromTemplate('L_Alpha', kEmptyLevelTemplateId);
    File('${projDir.path}/contents/levels/notes.txt').writeAsStringSync('not a level');
    expect(vm.levelFiles, [
      'contents/levels/L_Alpha.lmas',
      'contents/levels/L_Beta.lmas',
      'contents/levels/L_Main.lmas',
    ]);
  });
}
