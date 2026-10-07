import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';

/// Saving a level regenerates `lib/main.dart`; the launcher must keep
/// installing the project's default game mode, or a built Third Person game
/// spawns a bare pawn instead of its mannequin character.
///
/// The project is scaffolded for real by [ProjectRepository]; only the two
/// external commands are replaced by their filesystem effects (no network
/// `pub get`, no full `flutter create`).
void main() {
  late Directory root;
  late Directory configDir;
  const name = 'mode_game';

  Future<ProcessResult> runner(String exec, List<String> args, {String? workingDirectory, bool runInShell = false}) async {
    if (args.isNotEmpty && args.first == 'create') {
      final target = args.last;
      final projectName = args[args.indexOf('--project-name') + 1];
      Directory('$target/lib').createSync(recursive: true);
      File('$target/pubspec.yaml').writeAsStringSync(
        'name: $projectName\nenvironment:\n  sdk: ^3.12.0\ndependencies:\n  flutter:\n    sdk: flutter\nflutter:\n  uses-material-design: true\n',
      );
      File('$target/lib/main.dart').writeAsStringSync('void main() {}\n');
    }
    return ProcessResult(0, 0, '', '');
  }

  String projectDir() => '${root.path}/$name';
  String mainDart() => File('${projectDir()}/lib/main.dart').readAsStringSync();

  Future<EditorViewModel> openAndSave({String? defaultGameMode}) async {
    var project = (await ProjectRepository(configDir: configDir).loadProject('${projectDir()}/$name.lmproject'))!;
    if (defaultGameMode != null) {
      project = project.copyWith(mapsAndModes: project.mapsAndModes.copyWith(defaultGameMode: defaultGameMode));
    }
    final vm = EditorViewModel(initialProject: project, projectLocation: root.path, enableTimers: false);
    addTearDown(vm.dispose);
    await vm.ensureDefaultLevelAssets();
    await vm.saveLevelAndGenerateCode();
    return vm;
  }

  setUp(() async {
    root = Directory.systemTemp.createTempSync('lumina_main_mode_');
    configDir = Directory.systemTemp.createTempSync('lumina_main_mode_cfg_');
    await ProjectRepository(configDir: configDir, processRunner: runner)
        .createProject(projectName: name, projectLocation: root.path, template: kThirdPersonTemplateId);
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
    if (configDir.existsSync()) configDir.deleteSync(recursive: true);
  });

  test("saving the level keeps the Third Person project's GameMode Blueprint in main.dart", () async {
    // The template's game mode is BP_ThirdPersonGameMode.
    const install = "luminaGameModeFactories['${LuminaThirdPersonContent.gameModeBlueprintPath}']!()";
    expect(mainDart(), contains(install), reason: 'project creation writes it');

    await openAndSave();

    final code = mainDart();
    expect(code, contains("import 'actors/actors.g.dart';"));
    expect(code, contains("import 'input/project_input.g.dart';"));
    expect(code, contains('world.gameMode ??= $install;'));
    expect(code, contains('luminaAddProjectInput('));
    expect(code, isNot(contains('world.gameMode ??= LuminaGameMode();')));
  });

  test('a default game mode declared elsewhere under lib/ is imported from where it is declared', () async {
    Directory('${projectDir()}/lib/actors/rules').createSync(recursive: true);
    File('${projectDir()}/lib/actors/rules/arena_mode.dart').writeAsStringSync(
      "import 'package:lumina/lumina.dart';\n\nclass ArenaGameMode extends LuminaGameMode {}\n",
    );

    await openAndSave(defaultGameMode: 'ArenaGameMode');

    final code = mainDart();
    expect(code, contains("import 'actors/rules/arena_mode.dart';"));
    expect(code, contains('world.gameMode ??= ArenaGameMode();'));
  });

  test('a default game mode whose class no longer exists falls back to the engine default', () async {
    await openAndSave(defaultGameMode: 'GoneGameMode');

    final code = mainDart();
    expect(code, contains('world.gameMode ??= LuminaGameMode();'), reason: 'the build must still compile');
    expect(code, isNot(contains('GoneGameMode')));
  });

  test('saving keeps the ShadcnLayer of a shadcn project and drops it once the pubspec has no shadcn', () async {
    expect(mainDart(), contains('shadcn.ShadcnLayer('), reason: 'the scaffold wraps a shadcn project');
    await openAndSave();
    expect(mainDart(), contains('shadcn.ShadcnLayer('), reason: 'regeneration keeps the wrap');

    UmgWidgetLibraryService.apply(projectDir(), kUmgWidgetLibraryFlutter);
    await openAndSave();
    expect(mainDart(), isNot(contains('shadcn')), reason: 'never emit a launcher the pubspec cannot build');
  });
}
