import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina_ui/editor_entry.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:path/path.dart' as p;

import '../helpers/temp_project.dart';

/// `editor.restart` saves and hands off to the launcher, which
/// rebuilds the project's editor; with no launcher the exit(70) contract stays.
void main() {
  final original = EditorHandOff.instance;
  final starts = <List<String>>[];
  final exits = <int>[];
  late Directory temp;

  setUp(() {
    starts.clear();
    exits.clear();
    temp = Directory.systemTemp.createTempSync('restart_hand_off_');
    EditorHandOff.instance = EditorHandOff(
      startDetached: (exe, args) async => starts.add([exe, ...args]),
      exitApp: exits.add,
    );
  });
  tearDown(() async {
    EditorHandOff.instance = original;
    LuminaEditorHost.args = const EditorLaunchArgs();
    LuminaEditorHost.info = null;
    await deleteTempProject(temp);
  });

  EditorViewModel editor() => EditorViewModel(
        initialProject: const LuminaProject(projectName: 'RestartGame'),
        projectLocation: temp.path,
        enableTimers: false,
        autoInitAssets: false,
      );

  testWidgets('with --launcher-exe: the launcher gets --project <dir> detached and the editor exits', (tester) async {
    final launcher = File(p.join(temp.path, Platform.isWindows ? 'lumina_ui.exe' : 'lumina_ui'))..writeAsStringSync('stock editor');
    LuminaEditorHost.args = EditorLaunchArgs.parse(['--project', p.join(temp.path, 'RestartGame'), '--launcher-exe', launcher.path]);
    final vm = editor();
    addTearDown(vm.dispose);
    expect(vm.commands.execute('editor.restart'), isTrue);
    await drainRealIo(tester);
    expect(starts, [
      [launcher.path, '--project', vm.projectDirPath],
    ]);
    expect(exits, [0]);
  });

  testWidgets('without a launcher: exit(70), nothing started', (tester) async {
    final vm = editor();
    addTearDown(vm.dispose);
    vm.commands.execute('editor.restart');
    await drainRealIo(tester);
    expect(starts, isEmpty);
    expect(exits, [EditorHandOff.restartExitCode]);
    expect(EditorHandOff.restartExitCode, 70);
  });

  test('a project editor finds the stock editor under its engine root', () {
    final root = Directory(p.join(temp.path, 'engine'))..createSync();
    final exe = Platform.isWindows
        ? File(p.join(root.path, 'lumina_ui', 'build', 'windows', 'x64', 'runner', 'Release', 'lumina_ui.exe'))
        : File(p.join(root.path, 'lumina_ui', 'build', 'linux', 'x64', 'release', 'bundle', 'lumina_ui'));
    exe.createSync(recursive: true);
    LuminaEditorHost.info = EditorHostInfo(packageName: 'restart_game_editor', engineRoot: root.path);
    expect(LuminaEditorHost.launcherExecutable(), exe.path);
    expect(LuminaEditorHost.engineRoot, root.path);
  });

  test('the command line: --project, --rebuild, --no-plugins, --launcher-exe', () {
    final a = EditorLaunchArgs.parse(['--project', r'C:\P\Game', '--rebuild', '--no-plugins', '--launcher-exe=/x/lumina_ui']);
    expect(a.project, r'C:\P\Game');
    expect(a.rebuild, isTrue);
    expect(a.noPlugins, isTrue);
    expect(a.launcherExe, '/x/lumina_ui');
    expect(EditorLaunchArgs.parse(const []).project, isNull);
    expect(LuminaWorkspace.root, isNotEmpty);
  });
}
