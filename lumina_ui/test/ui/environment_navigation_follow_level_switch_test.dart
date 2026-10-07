import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/environment_lighting_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/navigation_editor_view_model.dart';

import '../helpers/temp_project.dart';

/// The Environment Lighting and Navigation tabs follow the open
/// level instead of editing the one they were opened on.
void main() {
  late Directory tempDir;
  late Directory projDir;
  const project = LuminaProject(projectName: 'FollowGame', activeLevel: 'contents/levels/L_Main.lmas');
  const main = 'contents/levels/L_Main.lmas';
  const other = 'contents/levels/L_Other.lmas';

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('lumina_follow_level_');
    projDir = Directory('${tempDir.path}/FollowGame')..createSync(recursive: true);
    Directory('${projDir.path}/contents/levels').createSync(recursive: true);
    File('${projDir.path}/FollowGame.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
  });

  tearDown(() => deleteTempProject(tempDir));

  /// L_Main at 18:00 and cell size 40, L_Other (Default template) untouched; both saved.
  Future<EditorViewModel> twoLevels() async {
    final vm = EditorViewModel(initialProject: project, projectLocation: tempDir.path, enableTimers: false);
    await vm.ensureDefaultLevelAssets();
    await vm.createLevelFromTemplate('L_Other', kDefaultLevelTemplateId);
    await vm.saveLevelAndGenerateCode();
    expect(await vm.openLevelGuarded(main), isTrue);
    return vm;
  }

  test('the Environment tab reloads the opened level; an edit lands on that level\'s Sun', () async {
    final vm = await twoLevels();
    final env = EnvironmentLightingViewModel(editor: vm)..open();
    env.setTimeOfDay(18);
    await vm.saveLevelAndGenerateCode();
    final mainSun = env.sunActor!;
    final mainTime = env.state.timeOfDay;

    expect(await vm.openLevelGuarded(other), isTrue);
    expect(vm.project.isDirty, isFalse, reason: 'following the level creates nothing by itself');
    expect(env.state.timeOfDay, isNot(mainTime), reason: 'L_Other\'s own environment');
    expect(identical(env.sunActor, mainSun), isFalse);
    if (env.sunActor != null) expect(vm.actors.contains(env.sunActor), isTrue, reason: 'L_Other\'s Sun');

    env.setSunIntensity(12345);
    final sun = env.sunActor!;
    expect(vm.actors.contains(sun), isTrue, reason: 'the edit lands on an actor of the open level');
    expect(sun.lightIntensity, 12345);
    expect(env.state.sunIntensityLux, 12345);
    expect(mainSun.lightIntensity, isNot(12345), reason: 'L_Main\'s unloaded Sun is untouched');
    env.dispose();
    await vm.close();
  });

  test('the Navigation tab reloads the opened level\'s config', () async {
    final vm = await twoLevels();
    final nav = NavigationEditorViewModel(editor: vm)..open();
    nav.setCellSize(40);
    await vm.saveLevelAndGenerateCode();
    expect(nav.config.cellSize, 40);

    expect(await vm.openLevelGuarded(other), isTrue);
    expect(nav.config.cellSize, isNot(40), reason: 'L_Other\'s own navigation settings');
    nav.setCellSize(55);
    expect((vm.levelNavigation['config'] as Map)['cellSize'], 55);

    expect(await vm.openLevelGuarded(main, ifDirty: UnsavedLevelChoice.discard), isTrue);
    expect(nav.config.cellSize, 40, reason: 'back on L_Main, its saved value');
    nav.dispose();
    await vm.close();
  });
}
