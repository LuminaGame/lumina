import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/launcher/services/project_editor_resolver.dart';
import 'package:lumina_ui/ui/features/launcher/view_models/launcher_view_model.dart';
import 'package:lumina_ui/ui/features/launcher/views/launcher_view.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:path/path.dart' as p;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../helpers/editor_host_fixture.dart';
import '../helpers/temp_project.dart';

/// A project lives in whatever folder it was copied, cloned or renamed to:
/// `--project <dir>` (and every launcher Open) edits that folder, not
/// `<parent>/<project name>`.
void main() {
  late Directory temp;
  late Directory folder;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('lumina_project_folder_');
    // The folder name differs from the project name, and a folder with the
    // project's name sits beside it.
    folder = Directory(p.join(temp.path, 'renamed_checkout'))..createSync();
    File(p.join(folder.path, 'HostGame.lmproject'))
        .writeAsStringSync(jsonEncode(const LuminaProject(projectName: 'HostGame').toMap()));
    Directory(p.join(temp.path, 'HostGame')).createSync();
  });
  tearDown(() => deleteTempProject(temp));

  test('the editor view model edits the folder it was given, whatever the project is called', () {
    final vm = EditorViewModel(
      initialProject: const LuminaProject(projectName: 'HostGame'),
      projectDir: folder.path,
      enableTimers: false,
      autoInitAssets: false,
    );
    addTearDown(vm.dispose);
    expect(p.equals(vm.projectDirPath, folder.path), isTrue, reason: vm.projectDirPath);
  });

  testWidgets('--project <dir> opens the editor on <dir>, not on <parent>/<project name>', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final config = Directory(p.join(temp.path, 'config'))..createSync();
    final resolver = ProjectEditorResolver(
      engineRoot: LuminaWorkspace.root,
      cache: EditorBuildCache(root: Directory(p.join(temp.path, 'cache'))),
      flutterInfo: fixedFlutterInfo,
      // A plugin-less project opens in this editor (no per-project build).
      everyProject: false,
    );
    late LauncherViewModel launcher;
    await tester.runAsync(() async => launcher = LauncherViewModel(configDir: config, editorResolver: resolver));
    String? openedDir;
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: LauncherView(
        viewModel: launcher,
        initialProjectDir: folder.path,
        editorBuilder: (project, projectDir, warning) {
          openedDir = projectDir;
          return Text('opened ${project.projectName}');
        },
      ),
    ));
    for (var i = 0; i < 60 && find.text('opened HostGame').evaluate().isEmpty; i++) {
      await drainRealIo(tester, rounds: 2);
    }
    expect(find.text('opened HostGame'), findsOneWidget);
    expect(openedDir, isNotNull);
    expect(p.equals(openedDir!, folder.path), isTrue, reason: 'opened $openedDir');
    await tester.pumpWidget(const SizedBox());
    await drainRealIo(tester);
  });
}
