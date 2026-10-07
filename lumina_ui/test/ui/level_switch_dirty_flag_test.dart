import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';

import '../helpers/temp_project.dart';

/// A level opened after Don't Save is clean.
void main() {
  late Directory tempDir;
  late Directory projDir;
  const project = LuminaProject(projectName: 'DirtyFlagGame', activeLevel: 'contents/levels/L_Main.lmas');

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('lumina_level_dirty_');
    projDir = Directory('${tempDir.path}/DirtyFlagGame')..createSync(recursive: true);
    Directory('${projDir.path}/contents/levels').createSync(recursive: true);
    File('${projDir.path}/DirtyFlagGame.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
  });

  tearDown(() => deleteTempProject(tempDir));

  test('Don\'t Save opens the other level clean, and the manifest does not record it as dirty', () async {
    final vm = EditorViewModel(initialProject: project, projectLocation: tempDir.path, enableTimers: false);
    await vm.ensureDefaultLevelAssets();
    await vm.createLevelFromTemplate('L_Other', kEmptyLevelTemplateId);
    await vm.saveLevelAndGenerateCode();
    vm.spawnNewActor('Primitive');
    expect(vm.project.isDirty, isTrue);

    expect(await vm.openLevelGuarded('contents/levels/L_Main.lmas', ifDirty: UnsavedLevelChoice.discard), isTrue);
    expect(vm.project.activeLevel, 'contents/levels/L_Main.lmas');
    expect(vm.project.isDirty, isFalse, reason: 'L_Main was just loaded from disk');
    final manifest = jsonDecode(File('${projDir.path}/DirtyFlagGame.lmproject').readAsStringSync()) as Map;
    expect(manifest['is_dirty'], isFalse);

    // Leaving it again needs no answer.
    expect(await vm.openLevelGuarded('contents/levels/L_Other.lmas'), isTrue);
    await vm.close();
  });
}
