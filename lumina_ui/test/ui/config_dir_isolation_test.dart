import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/launcher/view_models/launcher_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/services/editor_quality_settings.dart';
import 'package:lumina_ui/ui/features/plugin_manager/view_models/plugin_manager_view_model.dart';
import 'package:lumina_ui/ui/features/plugin_manager/views/new_plugin_wizard.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/blueprint_editor_view_model.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The user's own editor config directory, derived from HOME alone. These
/// tests only stat files there; they never write them.
String _userConfigDir() {
  final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '.';
  return Directory('$home/.config/lumina').absolute.path;
}

String _stamp(File f) =>
    f.existsSync() ? '${f.lengthSync()} bytes, modified ${f.lastModifiedSync().toIso8601String()}' : 'absent';

/// The editor quality store, the Blueprint editor and the plugin
/// wizard built `~/.config/lumina` themselves, and no test redirected the
/// default, so test runs read and wrote the user's own files.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUp(() => tempDir = Directory.systemTemp.createTempSync('config_isolation_'));
  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('the Launcher and the editor quality store leave the real ~/.config/lumina untouched', () async {
    final realFiles = [
      for (final name in ['recent_projects.json', 'editor_quality.json', 'launcher_settings.json', 'plugin_wizard.json'])
        File('${_userConfigDir()}/$name'),
    ];
    final before = realFiles.map(_stamp).toList();

    // Checked before anything is written, so a regression fails here without
    // touching the user's files.
    expect(ProjectRepository().resolvedConfigDir.absolute.path, isNot(_userConfigDir()));
    final store = EditorQualityStore();
    expect(store.configDir.absolute.path, isNot(_userConfigDir()));

    final projectDir = Directory('${tempDir.path}/isolation_game')..createSync();
    await ProjectRepository().saveProject(const LuminaProject(projectName: 'isolation_game'), projectDir.path);

    final launcher = LauncherViewModel();
    addTearDown(launcher.dispose);
    expect(await launcher.openExternal('${projectDir.path}/isolation_game.lmproject'), isNotNull);
    expect(launcher.allRecentProjects.map((e) => e.projectDir), contains(projectDir.absolute.path));

    await store.save(projectDir.path, const EditorQualitySettings(preset: 'low'));
    expect((await store.load(projectDir.path)).preset, 'low');

    expect(realFiles.map(_stamp).toList(), before, reason: 'a test run must not touch the user\'s editor config');
  });

  test('the Blueprint editor looks its project up in the resolved recent projects', () async {
    expect(ProjectRepository().resolvedConfigDir.absolute.path, isNot(_userConfigDir()));

    final projectDir = Directory('${tempDir.path}/bp_game');
    Directory('${projectDir.path}/contents').createSync(recursive: true);
    await ProjectRepository().addRecentProject(const LuminaProject(projectName: 'bp_game'), projectDir: projectDir.path);

    // A Blueprint outside any project folder falls back to the recent list.
    final loose = Directory('${tempDir.path}/loose')..createSync();
    final vm = BlueprintEditorViewModel(assetPath: '${loose.path}/BP_Loose.lmas');
    addTearDown(vm.dispose);
    expect(vm.projectDir, projectDir.absolute.path);
  });

  testWidgets('the New Plugin wizard reads its defaults from the resolved config directory', (tester) async {
    final configDir = LuminaConfigDir.resolve();
    expect(configDir.absolute.path, isNot(_userConfigDir()));
    File('${configDir.path}/plugin_wizard.json')
      ..createSync(recursive: true)
      ..writeAsStringSync(jsonEncode({'author': 'Isolated Author'}));

    final projectDir = Directory('${tempDir.path}/wizard_game/plugins')..createSync(recursive: true);
    final registry = PluginRegistryService(
      repo: PluginRepository(roots: [PluginScanRoot(dir: projectDir, origin: PluginOrigin.project)]),
      projectRepo: ProjectRepository(),
    );
    await tester.runAsync(() => registry.initialize(projectDir.parent.path));
    final viewModel = PluginManagerViewModel(registryService: registry);

    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(
        child: Builder(
          builder: (context) => NewPluginWizardDialog(
            rootContext: context,
            viewModel: viewModel,
            projectRoot: projectDir.parent,
            onClose: () {},
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final author = tester.widget<TextField>(find.byKey(const Key('author_field')));
    expect(author.controller!.text, 'Isolated Author');
  });
}
