import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lumina/data/services/level_template_service.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/main_editor/views/new_level_dialog.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

/// Level templates smoke — boots the real editor on a real temp project and
/// creates one level of each New Level template (`Empty`, `Default`,
/// `Open World`) through the real `File → New Level…` dialog. Real props from
/// `test-assets/` are placed into the Open World level so the partition grid
/// and the outliner's cell column have real geometry to describe. Captures the
/// Filament frame of each level as PNG plus a WebM of switching between them,
/// and asserts each `.lmas` on disk carries exactly the sections its template
/// promises.
///
/// Runs on GPU 1 (NVIDIA RTX PRO 2000) — `tool/smoke_report.dart` injects
/// `CUDA_VISIBLE_DEVICES=1 VK_DEVICE_INDEX=1 __NV_PRIME_RENDER_OFFLOAD=1
/// __VK_LAYER_NV_optimus=NVIDIA_only DRI_PRIME=1`.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const usedAssets = [
    'Props/Barrels/fuel_barrel_red.glb',
    'Props/AC_units/ac_unit_a_300x300.glb',
    'Props/Banana Bunch/banana_bunch_medium.glb',
  ];

  testWidgets('Level Templates Smoke: Empty / Default / Open World through the real dialog',
      (tester) async {
    final tempProjectsDir = Directory.systemTemp.createTempSync('lumina_smoke_level_templates_');
    final pDir = Directory('${tempProjectsDir.path}/SmokeLevelTemplates')..createSync(recursive: true);
    const project = LuminaProject(
      projectName: 'SmokeLevelTemplates',
      activeLevel: 'contents/levels/L_Main.lmas',
    );
    File('${pDir.path}/SmokeLevelTemplates.lmproject').writeAsStringSync(jsonEncode(project.toMap()));

    try {
      final vm = EditorViewModel(
        initialProject: project,
        projectLocation: tempProjectsDir.path,
        enableTimers: false,
      );
      await tester.runAsync(() => vm.ensureDefaultLevelAssets());

      tester.view.physicalSize = const Size(1920, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: ShadcnApp(
            theme: luminaEditorTheme(),
            home: MainEditorView(viewModel: vm),
          ),
        ),
      );

      /// Animations run on the real clock in an integration test, so each
      /// frame has to wait for real time to pass.
      Future<void> settle([int frames = 20]) async {
        for (var i = 0; i < frames; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
        }
      }

      await settle(40);
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      await rec.hold(const Duration(seconds: 1));

      /// Drives the real `File → New Level…` dialog end to end.
      Future<void> newLevelThroughDialog(String name, String templateId) async {
        vm.commands.execute('file.newLevel', tester.element(find.byType(MainEditorView)));
        await settle(20);
        expect(find.byType(NewLevelDialog), findsOneWidget, reason: 'the real dialog, not a stub');
        await rec.hold(const Duration(milliseconds: 800));
        for (final t in LevelTemplateCatalog.all) {
          expect(find.text(t.title), findsOneWidget);
          expect(find.text(t.description), findsOneWidget,
              reason: 'every template says what it seeds');
        }
        await tester.enterText(find.byKey(const ValueKey('new_level_name')), name);
        await settle(5);
        await tester.tap(find.byKey(ValueKey('new_level_template_$templateId')));
        await settle(10);
        await rec.hold(const Duration(seconds: 1));
        await tester.tap(find.byKey(const ValueKey('new_level_create')));
        await settle(40);
        await rec.hold(const Duration(milliseconds: 800));
        expect(find.byType(NewLevelDialog), findsNothing);
        expect(vm.project.activeLevel, 'contents/levels/$name.lmas');
      }

      Map<String, dynamic> metadataOf(String name) {
        final raw = File('${pDir.path}/contents/levels/$name.lmas').readAsStringSync();
        return Map<String, dynamic>.from((jsonDecode(raw) as Map)['metadata'] as Map);
      }

      // --- Empty -------------------------------------------------------------
      await newLevelThroughDialog('L_Smoke_Empty', kEmptyLevelTemplateId);
      final emptyMeta = metadataOf('L_Smoke_Empty');
      expect(emptyMeta.containsKey('actors'), isFalse, reason: 'Empty seeds nothing');
      expect(emptyMeta.containsKey('worldPartition'), isFalse);
      expect(vm.actors, isEmpty);
      final emptyPng = await SmokeArtifacts.captureIntegrationPng(binding, tester,
          boundary: find.byKey(boundaryKey));
      SmokeArtifacts.saveScreenshot('level_templates_empty', emptyPng, usedAssets: usedAssets);
      await rec.hold(const Duration(seconds: 1));

      // --- Default -----------------------------------------------------------
      await newLevelThroughDialog('L_Smoke_Default', kDefaultLevelTemplateId);
      final defaultMeta = metadataOf('L_Smoke_Default');
      expect(defaultMeta['actors'], isNotEmpty);
      expect(defaultMeta.containsKey('worldPartition'), isFalse,
          reason: 'Default is not an open world');
      expect(vm.actors.map((a) => a.type),
          containsAll(['PlayerStart', 'DirectionalLight', 'Environment', 'Primitive']));
      await settle(40);
      final defaultPng = await SmokeArtifacts.captureIntegrationPng(binding, tester,
          boundary: find.byKey(boundaryKey));
      SmokeArtifacts.saveScreenshot('level_templates_default', defaultPng, usedAssets: usedAssets);
      await rec.hold(const Duration(seconds: 1));

      // --- Open World --------------------------------------------------------
      await newLevelThroughDialog('L_Smoke_OpenWorld', kOpenWorldLevelTemplateId);
      final openMeta = metadataOf('L_Smoke_OpenWorld');
      final section = Map<String, dynamic>.from(openMeta['worldPartition'] as Map);
      expect(section['enabled'], isTrue);
      expect(section['cellSize'], kWorldPartitionDefaultCellSize);
      expect(section['loadingRange'], kWorldPartitionDefaultLoadingRange);
      expect(section['maxCellTransitionsPerTick'], kWorldPartitionDefaultMaxCellTransitionsPerTick);
      final seededStart = (openMeta['actors'] as List)
          .cast<Map>()
          .firstWhere((a) => a['type'] == 'PlayerStart');
      expect(
        (seededStart['components'] as List).any((c) => c['type'] == kStreamingSourceComponentType),
        isTrue,
        reason: 'the PlayerStart carries a real streaming source',
      );
      // The viewport grid is now the authored cell grid (128 m cells).
      expect(vm.gridStep, kWorldPartitionDefaultCellSize);
      expect(vm.worldPartitionEnabled, isTrue);

      // Real props from test-assets/, imported through the real pipeline and
      // deliberately dropped into three different partition cells.
      final assetsDir = SmokeArtifacts.testAssetsDir;
      // Stored locations are centimetres, Z up; the runtime
      // partitions on its ground plane, runtime X/Z = stored X/−Y, in
      // 12 800 cm cells. These fall in cells x = 0, 2 and −2.
      const placements = <List<double>>[
        [1000.0, 1000.0, 100.0],
        [30000.0, -4000.0, 100.0],
        [-20000.0, 14000.0, 100.0],
      ];
      for (var i = 0; i < usedAssets.length; i++) {
        final src = File('${assetsDir.path}/${usedAssets[i]}');
        if (!src.existsSync()) continue;
        await tester.runAsync(() => vm.processImportPipeline(sourceFilePath: src.path));
        final base = usedAssets[i].split('/').last.split('.').first;
        final imported = vm.realAssets.where((a) => a.fileName.startsWith(base)).firstOrNull;
        if (imported == null) continue;
        await tester.runAsync(() => vm.spawnActorFromAsset(imported, location: placements[i]));
        await settle(5);
        await rec.hold(const Duration(milliseconds: 600));
      }
      await settle(40);

      final cells = vm.actors
          .where((a) => a.type != 'Folder')
          .map((a) => vm.worldPartitionCellOf(a))
          .toSet();
      expect(cells.length, greaterThan(1),
          reason: 'the placed props really fall in different partition cells');

      // Deselect so the details panel shows the level's own World Partition
      // section (with the honest "no streaming while editing" note).
      vm.clearSelection();
      await settle(30);
      expect(find.text('WORLD PARTITION'), findsOneWidget);
      expect(find.textContaining('does not stream cells in and out while editing'), findsOneWidget);

      final openPng = await SmokeArtifacts.captureIntegrationPng(binding, tester,
          boundary: find.byKey(boundaryKey));
      SmokeArtifacts.saveScreenshot('level_templates_open_world_grid', openPng,
          usedAssets: usedAssets);
      await rec.hold(const Duration(seconds: 1));

      // Save → the section reaches the generated Dart and drives the real
      // engine subsystem.
      await tester.runAsync(() => vm.saveLevelAndGenerateCode());
      final generated = File('${pDir.path}/lib/levels/l_smoke_open_world.dart').readAsStringSync();
      expect(generated, contains('LuminaWorldPartitionSubsystem(cellSize: 12800.0000, '
          'maxCellTransitionsPerTick: 10)'));
      expect(generated, contains('partition.registerSource(component)'));
      expect(generated, contains('loadingRadius: 25000.0000'));

      // --- Switching between the three levels, on video -----------------------
      for (final level in const [
        'L_Smoke_Empty',
        'L_Smoke_Default',
        'L_Smoke_OpenWorld',
        'L_Smoke_Default',
        'L_Smoke_OpenWorld',
      ]) {
        vm.switchLevel('contents/levels/$level.lmas');
        await settle(30);
        await rec.hold(const Duration(milliseconds: 1200));
      }
      rec.save('Level Templates Smoke: Empty / Default / Open World through the real dialog', usedAssets: usedAssets);

      // Final state: back on the Open World level with its partition loaded.
      expect(vm.project.activeLevel, 'contents/levels/L_Smoke_OpenWorld.lmas');
      expect(vm.worldPartitionEnabled, isTrue);
      expect(vm.gridStep, kWorldPartitionDefaultCellSize);

      // Each of the three files on disk carries exactly its template's sections.
      expect(metadataOf('L_Smoke_Empty').keys, isNot(contains('actors')));
      expect(metadataOf('L_Smoke_Empty').keys, isNot(contains('worldPartition')));
      expect(metadataOf('L_Smoke_Default').keys, contains('actors'));
      expect(metadataOf('L_Smoke_Default').keys, isNot(contains('worldPartition')));
      expect(metadataOf('L_Smoke_OpenWorld').keys, containsAll(['actors', 'worldPartition']));

      vm.dispose();
    } finally {
      if (tempProjectsDir.existsSync()) {
        tempProjectsDir.deleteSync(recursive: true);
      }
    }
  });
}
