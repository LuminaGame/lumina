import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/data/services/level_template_service.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../helpers/temp_project.dart';

/// Opening another level (File → Open Level, double-clicking a
/// level, `openAssetEditorByPath`) dropped the current level's unsaved
/// actors without asking. No mocks: a real temp project with two
/// real level files.
void main() {
  late Directory tempDir;
  late Directory projDir;

  const project = LuminaProject(
    projectName: 'UnsavedLevelGame',
    activeLevel: 'contents/levels/L_Main.lmas',
  );

  File levelFile(String name) => File('${projDir.path}/contents/levels/$name.lmas');

  /// L_Main and L_Other on disk, the editor on L_Main with one unsaved actor.
  Future<(EditorViewModel, EditorActorNode)> openDirtyEditor() async {
    final vm = EditorViewModel(initialProject: project, projectLocation: tempDir.path, enableTimers: false);
    await vm.ensureDefaultLevelAssets();
    await vm.createLevelFromTemplate('L_Other', kEmptyLevelTemplateId);
    vm.switchLevel('contents/levels/L_Main.lmas');
    vm.spawnNewActor('Primitive');
    final unsaved = vm.actors.last;
    vm.renameActor(unsaved.id, 'UnsavedCrate');
    expect(vm.project.isDirty, isTrue);
    expect(levelFile('L_Main').readAsStringSync(), isNot(contains(unsaved.id)));
    return (vm, unsaved);
  }

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('lumina_open_level_unsaved_');
    projDir = Directory('${tempDir.path}/UnsavedLevelGame')..createSync(recursive: true);
    Directory('${projDir.path}/contents/levels').createSync(recursive: true);
    File('${projDir.path}/UnsavedLevelGame.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
  });

  // The editor's git probe may still hold the folder on Windows.
  tearDown(() async {
    await deleteTempProject(tempDir);
  });

  test('opening a level by path with no one to ask keeps a dirty level open', () async {
    final (vm, unsaved) = await openDirtyEditor();
    addTearDown(vm.dispose);

    vm.openAssetEditorByPath('contents/levels/L_Other.lmas');
    await Future<void>.delayed(Duration.zero);

    expect(vm.project.activeLevel, 'contents/levels/L_Main.lmas', reason: 'nothing asked, so nothing switched');
    expect(vm.actors.map((a) => a.id), contains(unsaved.id), reason: 'the unsaved actor is still there');
  });

  // The prompt's Save runs real async disk I/O (save + codegen), which a
  // widget test's fake zone does not complete; the smoke drives that button.
  test('choosing Save writes the level, then opens the other one', () async {
    final (vm, unsaved) = await openDirtyEditor();
    addTearDown(vm.dispose);

    final opened = await vm.openLevelGuarded('contents/levels/L_Other.lmas', ifDirty: UnsavedLevelChoice.save);

    expect(opened, isTrue);
    expect(levelFile('L_Main').readAsStringSync(), contains(unsaved.id), reason: 'L_Main was saved first');
    expect(vm.project.activeLevel, 'contents/levels/L_Other.lmas');

    // No save still in flight may land afterwards and put L_Main back.
    await Future<void>.delayed(const Duration(milliseconds: 800));
    expect(vm.project.activeLevel, 'contents/levels/L_Other.lmas', reason: 'the switch sticks');
    final manifest = jsonDecode(File('${projDir.path}/UnsavedLevelGame.lmproject').readAsStringSync()) as Map;
    expect(manifest['active_level'] ?? manifest['activeLevel'], 'contents/levels/L_Other.lmas');
  });

  test('a save that is still running when the level changes does not switch it back', () async {
    final (vm, _) = await openDirtyEditor();
    addTearDown(vm.dispose);

    await vm.saveLevelAndGenerateCode();
    vm.switchLevel('contents/levels/L_Other.lmas');
    await Future<void>.delayed(const Duration(milliseconds: 800));

    expect(vm.project.activeLevel, 'contents/levels/L_Other.lmas');
  });

  test("choosing Don't Save opens the other level; Cancel or no choice keeps the dirty one", () async {
    final (vm, unsaved) = await openDirtyEditor();
    addTearDown(vm.dispose);
    final before = levelFile('L_Main').readAsStringSync();

    expect(await vm.openLevelGuarded('contents/levels/L_Other.lmas', ifDirty: UnsavedLevelChoice.cancel), isFalse);
    expect(await vm.openLevelGuarded('contents/levels/L_Other.lmas'), isFalse);
    expect(vm.actors.map((a) => a.id), contains(unsaved.id));

    expect(await vm.openLevelGuarded('contents/levels/L_Other.lmas', ifDirty: UnsavedLevelChoice.discard), isTrue);
    expect(vm.project.activeLevel, 'contents/levels/L_Other.lmas');
    expect(levelFile('L_Main').readAsStringSync(), before);
  });

  Future<EditorViewModel> pumpOpenLevelPrompt(WidgetTester tester) async {
    late EditorViewModel vm;
    await tester.runAsync(() async => vm = (await openDirtyEditor()).$1);
    await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)));
    await tester.pump(const Duration(milliseconds: 200));
    vm.commands.execute('file.openLevel', tester.element(find.byType(MainEditorView)));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('L_Other.lmas'));
    await tester.pump(const Duration(milliseconds: 400));
    return vm;
  }

  /// Real disk work (save + codegen) runs behind async gaps: pump real time
  /// until [done] holds, or give up after ~10 s and let the expects report.
  Future<void> letDiskWorkLand(WidgetTester tester, {bool Function()? done}) async {
    for (var i = 0; i < 200; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      if (i >= 10 && (done == null || done())) return;
    }
  }

  testWidgets('File → Open Level on a dirty level asks, and Cancel keeps it', (tester) async {
    final vm = await pumpOpenLevelPrompt(tester);
    addTearDown(vm.dispose);

    expect(find.byKey(const ValueKey('unsaved_level_prompt')), findsOneWidget);
    expect(vm.project.activeLevel, 'contents/levels/L_Main.lmas', reason: 'nothing switches before the answer');

    await tester.tap(find.byKey(const ValueKey('unsaved_level_prompt_cancel')));
    await letDiskWorkLand(tester);
    expect(vm.project.activeLevel, 'contents/levels/L_Main.lmas');
    expect(vm.actors.any((a) => a.name == 'UnsavedCrate'), isTrue);
  });

  testWidgets("Don't Save opens the other level and leaves L_Main on disk as it was", (tester) async {
    final vm = await pumpOpenLevelPrompt(tester);
    addTearDown(vm.dispose);
    final before = levelFile('L_Main').readAsStringSync();

    await tester.tap(find.byKey(const ValueKey('unsaved_level_prompt_discard')));
    await letDiskWorkLand(tester);
    expect(vm.project.activeLevel, 'contents/levels/L_Other.lmas');
    expect(levelFile('L_Main').readAsStringSync(), before);
  });
}
