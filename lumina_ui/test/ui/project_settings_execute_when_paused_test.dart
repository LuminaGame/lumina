import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/project_settings_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/project_settings_sub_editor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Project Settings ▸ Input: an input action's "When Paused" checkbox (the
/// action fires while the game is paused), saved in a real temporary
/// `.lmproject` and read back.
void main() {
  late Directory tempDir;
  late Directory projDir;
  late File manifest;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('lumina_paused_input_settings_');
    projDir = Directory('${tempDir.path}/PauseGame')..createSync(recursive: true);
    const project = LuminaProject(
      projectName: 'PauseGame',
      activeLevel: 'contents/levels/L_Main.lmas',
      input: ProjectInputSettings(actions: [ProjectInputAction(name: 'IA_Pause'), ProjectInputAction(name: 'IA_Jump')]),
    );
    manifest = File('${projDir.path}/PauseGame.lmproject')..writeAsStringSync(jsonEncode(project.toMap()));
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  List<Map<String, dynamic>> savedActions() =>
      (((jsonDecode(manifest.readAsStringSync()) as Map<String, dynamic>)['input'] as Map)['actions'] as List)
          .cast<Map<String, dynamic>>();

  test('the flag is saved only when set and read back', () async {
    final vm = ProjectSettingsViewModel(projectDirPath: projDir.path);
    await vm.load();
    vm.updateAction(0, executeWhenPaused: true);
    expect(await vm.apply(), isTrue);
    expect(savedActions()[0]['execute_when_paused'], isTrue);
    expect(savedActions()[1].containsKey('execute_when_paused'), isFalse);
    final reopened = ProjectSettingsViewModel(projectDirPath: projDir.path);
    await reopened.load();
    expect(reopened.project.input.actions[0].executeWhenPaused, isTrue);
    // A rename keeps the flag.
    reopened.updateAction(0, name: 'IA_Menu');
    expect(reopened.project.input.actions[0].executeWhenPaused, isTrue);
    reopened.updateAction(0, executeWhenPaused: false);
    expect(await reopened.apply(), isTrue);
    expect(savedActions()[0].containsKey('execute_when_paused'), isFalse);
  });

  testWidgets('the Input category shows a When Paused checkbox per action and ticking it sets the flag', (tester) async {
    final vm = ProjectSettingsViewModel(projectDirPath: projDir.path);
    await tester.runAsync(vm.load);
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(
        child: ProjectSettingsSubEditor(assetName: 'PauseGame.lmproject', projectDirPath: projDir.path, viewModel: vm),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('project_settings_nav_${ProjectSettingsCategory.input}')));
    await tester.pumpAndSettle();
    expect(find.text('When Paused'), findsNWidgets(2));
    final box = find.byKey(const ValueKey('project_settings_action_paused_0'));
    await tester.ensureVisible(box);
    await tester.pumpAndSettle();
    await tester.tap(box);
    await tester.pumpAndSettle();
    expect(vm.project.input.actions[0].executeWhenPaused, isTrue);
    expect(vm.project.input.actions[1].executeWhenPaused, isFalse);
    await tester.tap(box);
    await tester.pumpAndSettle();
    expect(vm.project.input.actions[0].executeWhenPaused, isFalse);
  });
}
