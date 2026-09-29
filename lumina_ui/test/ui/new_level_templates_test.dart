import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/data/services/level_template_service.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/main_editor/views/new_level_dialog.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

/// `File → New
/// Level…` offers Empty / Default / Open World and each one produces a
/// materially different real `.lmas` on disk (no mocks: real temp
/// project, real files, no fixtures).
void main() {
  late Directory tempDir;
  late Directory projDir;

  const project = LuminaProject(
    projectName: 'TemplateGame',
    activeLevel: 'contents/levels/L_Main.lmas',
  );

  Future<EditorViewModel> openEditor() async {
    final vm = EditorViewModel(initialProject: project, projectLocation: tempDir.path, enableTimers: false);
    await vm.ensureDefaultLevelAssets();
    return vm;
  }

  Map<String, dynamic> readLevel(String name) => jsonDecode(
        File('${projDir.path}/contents/levels/$name.lmas').readAsStringSync(),
      ) as Map<String, dynamic>;

  Map<String, dynamic> metadataOf(String name) =>
      Map<String, dynamic>.from(readLevel(name)['metadata'] as Map);

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('lumina_level_templates_');
    projDir = Directory('${tempDir.path}/TemplateGame')..createSync(recursive: true);
    Directory('${projDir.path}/contents/levels').createSync(recursive: true);
    File('${projDir.path}/TemplateGame.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('Empty seeds nothing: no actors key, empty outliner, no exception', () async {
    final vm = await openEditor();
    addTearDown(vm.dispose);

    await vm.createLevelFromTemplate('L_Empty', kEmptyLevelTemplateId);

    final metadata = metadataOf('L_Empty');
    expect(metadata.containsKey('actors'), isFalse, reason: 'Empty is honestly empty');
    expect(metadata.containsKey('worldPartition'), isFalse);
    expect(vm.project.activeLevel, 'contents/levels/L_Empty.lmas');
    expect(vm.actors, isEmpty, reason: 'the outliner shows nothing');
    expect(vm.levelWorldPartition, isEmpty);
  });

  test('Default writes the catalog actor set and the outliner shows it without a reload', () async {
    final vm = await openEditor();
    addTearDown(vm.dispose);

    await vm.createLevelFromTemplate('L_Default', kDefaultLevelTemplateId);

    final seeded = LevelTemplateCatalog.byId(kDefaultLevelTemplateId).levelActors;
    final onDisk = metadataOf('L_Default')['actors'] as List;
    expect(onDisk.length, seeded.length);
    expect(onDisk.map((a) => a['name']), seeded.map((a) => a['name']));

    // In memory, immediately — no project reload.
    expect(vm.actors.map((a) => a.name), seeded.map((a) => a['name']));
    expect(vm.actors.map((a) => a.type), containsAll(['PlayerStart', 'DirectionalLight', 'Environment', 'Primitive']));
    expect(metadataOf('L_Default').containsKey('worldPartition'), isFalse);
  });

  test('Open World writes the runtime defaults and a streaming source, and round-trips', () async {
    final vm = await openEditor();
    addTearDown(vm.dispose);

    await vm.createLevelFromTemplate('L_OpenWorld', kOpenWorldLevelTemplateId);

    final section = metadataOf('L_OpenWorld')['worldPartition'] as Map;
    expect(section['enabled'], isTrue);
    expect(section['cellSize'], kWorldPartitionDefaultCellSize);
    expect(section['loadingRange'], kWorldPartitionDefaultLoadingRange);
    expect(section['maxCellTransitionsPerTick'], kWorldPartitionDefaultMaxCellTransitionsPerTick);
    expect(section['dataLayers'], isEmpty);

    // Loaded into the live session.
    expect(vm.worldPartitionEnabled, isTrue);
    expect(vm.worldPartitionCellSize, kWorldPartitionDefaultCellSize);

    final start = vm.actors.singleWhere((a) => a.type == 'PlayerStart');
    final source = start.components.singleWhere((c) => c.type == kStreamingSourceComponentType);
    expect(source.enabled, isTrue);
    expect(source.properties['priority'], 1);
    expect(source.properties.containsKey('loadingRadius'), isFalse,
        reason: 'the source inherits the section loadingRange');

    // Save → reload: the section survives byte-for-byte.
    final before = jsonEncode(vm.levelWorldPartition);
    await vm.saveLevelAndGenerateCode();
    expect(jsonEncode(metadataOf('L_OpenWorld')['worldPartition']), before);

    vm.switchLevel('contents/levels/L_Main.lmas');
    expect(vm.levelWorldPartition, isEmpty, reason: 'L_Main authors no partition');
    vm.switchLevel('contents/levels/L_OpenWorld.lmas');
    expect(jsonEncode(vm.levelWorldPartition), before);
    expect(vm.actors.any((a) => a.type == 'PlayerStart'), isTrue);
  });

  test('the generated level Dart carries the partition; a plain level does not', () async {
    final vm = await openEditor();
    addTearDown(vm.dispose);

    await vm.createLevelFromTemplate('L_OpenWorld', kOpenWorldLevelTemplateId);
    await vm.saveLevelAndGenerateCode();
    final open = File('${projDir.path}/lib/levels/l_open_world.dart').readAsStringSync();
    expect(open, contains('LuminaWorldPartitionSubsystem(cellSize: 12800.0000, maxCellTransitionsPerTick: 10)'));
    expect(open, contains('loadingRadius: 25000.0000'));
    expect(open, contains('partition.registerSource(component)'));

    await vm.createLevelFromTemplate('L_Default', kDefaultLevelTemplateId);
    await vm.saveLevelAndGenerateCode();
    final plain = File('${projDir.path}/lib/levels/l_default.dart').readAsStringSync();
    expect(plain, isNot(contains('LuminaWorldPartitionSubsystem')));
    expect(plain, isNot(contains('LuminaStreamingSourceComponent')));
  });

  test('creating a level is one undoable action', () async {
    final vm = await openEditor();
    addTearDown(vm.dispose);
    final before = vm.project.activeLevel;
    final undoDepthBefore = vm.transactions.canUndo;

    await vm.createLevelFromTemplate('L_Undoable', kOpenWorldLevelTemplateId);
    final file = File('${projDir.path}/contents/levels/L_Undoable.lmas');
    expect(file.existsSync(), isTrue);
    expect(vm.project.activeLevel, 'contents/levels/L_Undoable.lmas');
    expect(vm.transactions.canUndo, isTrue);
    expect(vm.transactions.undoLabel, 'Undo New Level L_Undoable');

    vm.transactions.undo();
    expect(file.existsSync(), isFalse, reason: 'the new level file is gone');
    expect(vm.project.activeLevel, before, reason: 'back on the previously active level');
    expect(vm.levelWorldPartition, isEmpty);
    expect(vm.realAssets.any((a) => a.fileName == 'L_Undoable.lmas'), isFalse);
    expect(vm.transactions.canUndo, undoDepthBefore);

    vm.transactions.redo();
    expect(file.existsSync(), isTrue);
    expect(vm.project.activeLevel, 'contents/levels/L_Undoable.lmas');
    expect(vm.worldPartitionEnabled, isTrue);
  });

  testWidgets('the New Level dialog offers the three templates and creates through them', (tester) async {
    late EditorViewModel vm;
    await tester.runAsync(() async => vm = await openEditor());
    addTearDown(vm.dispose);

    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: MainEditorView(viewModel: vm),
    ));
    await tester.pump(const Duration(milliseconds: 200));

    vm.commands.execute('file.newLevel', tester.element(find.byType(MainEditorView)));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(NewLevelDialog), findsOneWidget);
    for (final t in LevelTemplateCatalog.all) {
      expect(find.text(t.title), findsOneWidget);
      expect(find.text(t.description), findsOneWidget);
    }

    await tester.enterText(find.byKey(const ValueKey('new_level_name')), 'L_FromDialog');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('new_level_template_open_world')));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byKey(const ValueKey('new_level_create')));
    // Creating the level is real disk I/O behind an async gap; give it real
    // time to land instead of only pumping the fake clock.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    }

    expect(File('${projDir.path}/contents/levels/L_FromDialog.lmas').existsSync(), isTrue);
    expect(metadataOf('L_FromDialog')['worldPartition'], isNotNull);
    expect(vm.project.activeLevel, 'contents/levels/L_FromDialog.lmas');
  });
}
