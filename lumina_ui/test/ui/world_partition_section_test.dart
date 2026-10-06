import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/data/services/level_template_service.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/details_widget.dart';
import 'package:lumina_ui/ui/features/main_editor/views/outliner_widget.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

/// The level's own `World Partition` details section:
/// real data, live-edited, reaching the level file and the generated code.
void main() {
  late Directory tempDir;
  late Directory projDir;

  const project = LuminaProject(
    projectName: 'WpGame',
    activeLevel: 'contents/levels/L_Main.lmas',
  );

  Future<EditorViewModel> openEditor() async {
    final vm = EditorViewModel(initialProject: project, projectLocation: tempDir.path, enableTimers: false);
    await vm.ensureDefaultLevelAssets();
    return vm;
  }

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('lumina_wp_section_');
    projDir = Directory('${tempDir.path}/WpGame')..createSync(recursive: true);
    Directory('${projDir.path}/contents/levels').createSync(recursive: true);
    File('${projDir.path}/WpGame.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<void> pumpDetails(WidgetTester tester, EditorViewModel vm) async {
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: SizedBox(width: 340, height: 900, child: DetailsWidget(viewModel: vm)),
    ));
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets('with nothing selected the level shows its World Partition section', (tester) async {
    late EditorViewModel vm;
    await tester.runAsync(() async => vm = await openEditor());
    addTearDown(vm.dispose);
    vm.clearSelection();

    await pumpDetails(tester, vm);

    expect(find.text('WORLD PARTITION'), findsOneWidget);
    expect(find.byKey(const ValueKey('wp_enabled')), findsOneWidget);
    // The honest boundary, said once.
    expect(
      find.textContaining('the editor shows the whole level while editing'),
      findsOneWidget,
    );
    // Disabled level: the knobs are not shown until the section exists.
    expect(vm.worldPartitionEnabled, isFalse);
    expect(find.byKey(const ValueKey('wp_cell_size')), findsNothing);

    // Enabling authors a real section carrying the runtime's own defaults.
    await tester.tap(find.byKey(const ValueKey('wp_enabled')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(vm.worldPartitionEnabled, isTrue);
    expect(vm.worldPartitionCellSize, kWorldPartitionDefaultCellSize);
    expect(vm.worldPartitionLoadingRange, kWorldPartitionDefaultLoadingRange);
    expect(vm.worldPartitionMaxCellTransitionsPerTick, kWorldPartitionDefaultMaxCellTransitionsPerTick);
    expect(find.byKey(const ValueKey('wp_cell_size')), findsOneWidget);
    expect(find.byKey(const ValueKey('wp_loading_range')), findsOneWidget);
    expect(find.byKey(const ValueKey('wp_max_transitions')), findsOneWidget);
  });

  testWidgets('editing cellSize marks the level dirty and changes the viewport grid spacing', (tester) async {
    late EditorViewModel vm;
    await tester.runAsync(() async => vm = await openEditor());
    addTearDown(vm.dispose);
    vm.clearSelection();
    await tester.runAsync(() => vm.saveLevelAndGenerateCode());
    expect(vm.project.isDirty, isFalse);

    final snapStep = vm.editorGridStep;
    expect(vm.gridStep, snapStep, reason: 'no partition → the project grid step');

    await pumpDetails(tester, vm);
    await tester.tap(find.byKey(const ValueKey('wp_enabled')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(vm.gridStep, kWorldPartitionDefaultCellSize, reason: 'the viewport draws the cell grid');
    expect(vm.gridExtent, greaterThanOrEqualTo(kWorldPartitionDefaultCellSize * 4));
    expect(vm.editorGridStep, snapStep, reason: 'the stored snap grid step is untouched');

    await tester.runAsync(() => vm.saveLevelAndGenerateCode());
    expect(vm.project.isDirty, isFalse);

    await tester.enterText(find.byKey(const ValueKey('wp_cell_size')), '64');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump(const Duration(milliseconds: 200));

    expect(vm.worldPartitionCellSize, 64.0);
    expect(vm.gridStep, 64.0, reason: 'the viewport grid follows the authored cell size');
    expect(vm.project.isDirty, isTrue, reason: 'editing the section dirties the level');

    await tester.runAsync(() => vm.saveLevelAndGenerateCode());
    final onDisk = jsonDecode(File('${projDir.path}/contents/levels/L_Main.lmas').readAsStringSync()) as Map;
    expect((onDisk['metadata'] as Map)['worldPartition']['cellSize'], 64.0);
    final generated = File('${projDir.path}/lib/levels/l_main.dart').readAsStringSync();
    expect(generated, contains('LuminaWorldPartitionSubsystem(cellSize: 64.0000'));
  });

  testWidgets('data layers are real: added here, registered in the generated code', (tester) async {
    late EditorViewModel vm;
    await tester.runAsync(() async => vm = await openEditor());
    addTearDown(vm.dispose);
    vm.clearSelection();
    vm.setWorldPartitionEnabled(true);

    await pumpDetails(tester, vm);
    await tester.tap(find.byKey(const ValueKey('wp_add_layer')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(vm.worldPartitionDataLayers.length, 1);

    await tester.enterText(find.byKey(const ValueKey('wp_layer_name_0')), 'Gameplay');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump(const Duration(milliseconds: 200));
    vm.setWorldPartitionDataLayerState(0, 'activated');

    await tester.runAsync(() => vm.saveLevelAndGenerateCode());
    final generated = File('${projDir.path}/lib/levels/l_main.dart').readAsStringSync();
    expect(generated, contains("registerLayer('Gameplay', initialState: DataLayerState.activated"));

    await tester.tap(find.byKey(const ValueKey('wp_layer_remove_0')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(vm.worldPartitionDataLayers, isEmpty);
  });

  testWidgets('the outliner reports which cell each actor falls in', (tester) async {
    late EditorViewModel vm;
    await tester.runAsync(() async => vm = await openEditor());
    addTearDown(vm.dispose);
    await tester.runAsync(() => vm.createLevelFromTemplate('L_Open', kOpenWorldLevelTemplateId));

    // Mirrors LuminaWorldPartitionSubsystem.cellAt exactly: its X/Z ground
    // plane, floor(x/cellSize) and floor(z/cellSize), with the stored Z-up
    // location converted (runtime z = −y). Height is not a grid axis.
    // Cells are 12 800 cm.
    final start = vm.actors.firstWhere((a) => a.type == 'PlayerStart');
    expect(vm.worldPartitionCellOf(start), (0, 0));
    start.location = [30000.0, 1000.0, 900.0];
    expect(vm.worldPartitionCellOf(start), (2, -1),
        reason: 'height must not move an actor between cells');

    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      // OutlinerWidget does not listen to the view model itself; MainEditorView
      // wraps it in a ListenableBuilder, so the test mounts it the same way.
      home: SizedBox(
        width: 420,
        height: 900,
        child: ListenableBuilder(
          listenable: vm,
          builder: (_, _) => OutlinerWidget(viewModel: vm),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('2, -1'), findsOneWidget);

    vm.setWorldPartitionEnabled(false);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('2, -1'), findsNothing, reason: 'no cell column without a partition');
  });
}
