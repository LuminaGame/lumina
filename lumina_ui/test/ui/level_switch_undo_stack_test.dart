import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/data/services/level_template_service.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';

import '../helpers/temp_project.dart';

/// The level undo stack does not reach across an Open Level.
void main() {
  late Directory tempDir;
  late Directory projDir;
  const project = LuminaProject(projectName: 'UndoStackGame', activeLevel: 'contents/levels/L_Main.lmas');

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('lumina_level_undo_');
    projDir = Directory('${tempDir.path}/UndoStackGame')..createSync(recursive: true);
    Directory('${projDir.path}/contents/levels').createSync(recursive: true);
    File('${projDir.path}/UndoStackGame.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
  });

  tearDown(() => deleteTempProject(tempDir));

  Future<EditorViewModel> editorWithTwoLevels() async {
    final vm = EditorViewModel(initialProject: project, projectLocation: tempDir.path, enableTimers: false);
    await vm.ensureDefaultLevelAssets();
    await vm.createLevelFromTemplate('L_Other', kEmptyLevelTemplateId);
    await vm.saveLevelAndGenerateCode();
    return vm;
  }

  test('an edit saved in L_Main is not undone while L_Other is open, and L_Other stays clean', () async {
    final vm = await editorWithTwoLevels();
    expect(await vm.openLevelGuarded('contents/levels/L_Main.lmas'), isTrue);
    vm.spawnNewActor('PointLight');
    await vm.saveLevelAndGenerateCode();
    expect(vm.transactions.canUndo, isTrue);

    expect(await vm.openLevelGuarded('contents/levels/L_Other.lmas'), isTrue);
    final otherActors = vm.actors.map((a) => a.id).toList();
    expect(vm.transactions.canUndo, isFalse, reason: 'L_Main\'s steps do not reach L_Other');
    expect(vm.transactions.canRedo, isFalse);
    vm.transactions.undo();
    expect(vm.actors.map((a) => a.id).toList(), otherActors);
    expect(vm.project.isDirty, isFalse);
    await vm.close();
  });

  test('New Level stays one undo step that returns to the previous level', () async {
    final vm = EditorViewModel(initialProject: project, projectLocation: tempDir.path, enableTimers: false);
    await vm.ensureDefaultLevelAssets();
    await vm.createLevelFromTemplate('L_Third', kEmptyLevelTemplateId);
    expect(vm.project.activeLevel, 'contents/levels/L_Third.lmas');
    expect(vm.transactions.undoLabel, 'Undo New Level L_Third');
    vm.transactions.undo();
    expect(vm.project.activeLevel, 'contents/levels/L_Main.lmas');
    expect(File('${projDir.path}/contents/levels/L_Third.lmas').existsSync(), isFalse);
    expect(vm.transactions.canRedo, isTrue, reason: 'redo brings the new level back');
    vm.transactions.redo();
    expect(vm.project.activeLevel, 'contents/levels/L_Third.lmas');
    await vm.close();
  });
}
