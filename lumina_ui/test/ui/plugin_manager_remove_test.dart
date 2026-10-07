import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/marketplace/services/marketplace_install_dirs.dart';
import 'package:lumina_ui/ui/features/plugin_manager/services/plugin_remover.dart';
import 'package:lumina_ui/ui/features/plugin_manager/view_models/plugin_manager_view_model.dart';
import 'package:lumina_ui/ui/features/plugin_manager/views/plugin_manager_view.dart';
import 'package:path/path.dart' as p;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'plugin_remover_test.dart' show filesUnder, linkFolder, lockFolder, writePlugin;

/// The Plugin Manager's Remove, end to end through the details pane and the
/// confirmation dialog, on real plugin folders in a temp directory.
void main() {
  late Directory temp;
  late Directory engineDir;
  late Directory userDir;
  late Directory projectDir;
  late Directory dataDir;
  late PluginRegistryService registry;
  late PluginManagerViewModel vm;
  late List<String> setEnabledCalls;
  late int rescans;

  Directory projectPlugins() => Directory(p.join(projectDir.path, 'plugins'));
  List<String> enabledInProject() =>
      ((jsonDecode(File(p.join(projectDir.path, 'project.lmproject')).readAsStringSync()) as Map)['enabled_plugins'] as List? ?? const [])
          .cast<String>();

  setUp(() async {
    temp = Directory.systemTemp.createTempSync('lm_pm_rm_');
    engineDir = Directory(p.join(temp.path, 'engine'))..createSync();
    userDir = Directory(p.join(temp.path, 'user'))..createSync();
    projectDir = Directory(p.join(temp.path, 'project'))..createSync();
    dataDir = Directory(p.join(temp.path, 'plugin_data'))..createSync();
    final configDir = Directory(p.join(temp.path, 'config'))..createSync();
    projectPlugins().createSync();
    File(p.join(projectDir.path, 'project.lmproject'))
        .writeAsStringSync(jsonEncode({'project_name': 'project', 'engine_version': '0.0.1', 'enabled_plugins': <String>[]}));
    registry = PluginRegistryService(
      repo: PluginRepository(roots: [
        PluginScanRoot(dir: engineDir, origin: PluginOrigin.engine),
        PluginScanRoot(dir: projectPlugins(), origin: PluginOrigin.project),
        PluginScanRoot(dir: userDir, origin: PluginOrigin.user),
      ]),
      projectRepo: ProjectRepository(),
    );
    setEnabledCalls = [];
    rescans = 0;
    vm = PluginManagerViewModel(
      registryService: registry,
      onSetEnabled: (name, enabled, {cascade = false}) async => setEnabledCalls.add('$name:$enabled:$cascade'),
      onPluginsChanged: () async {
        rescans++;
        await registry.refresh();
      },
      isPluginLoaded: (name) => name == 'loaded_plugin',
      removerFactory: () => PluginRemover(
        pluginDataDir: dataDir,
        marketplaceDirs: MarketplaceInstallDirs(
          projectRoot: projectDir.path,
          pluginDir: userDir.path,
          themesDir: p.join(configDir.path, 'themes'),
          templatesDir: p.join(configDir.path, 'templates'),
          editorLicensesFile: p.join(configDir.path, 'marketplace', 'licenses.json'),
        ),
      ),
    );
  });

  tearDown(() {
    vm.dispose();
    try {
      temp.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows can hold a handle for a moment; the temp dir is left behind.
    }
  });

  Future<void> pumpView(WidgetTester tester) async {
    await registry.initialize(projectDir.path);
    tester.view.physicalSize = const Size(1500, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: Scaffold(child: PluginManagerView(viewModel: vm))));
    await tester.pumpAndSettle();
  }

  Future<void> tapAndWait(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
  }

  Future<void> select(WidgetTester tester, String name) async {
    await tapAndWait(tester, find.text('Plugin $name').first);
    expect(vm.selectedEntry?.descriptor.name, name);
  }

  Future<void> openRemove(WidgetTester tester, String name) async {
    await select(tester, name);
    await tapAndWait(tester, find.byKey(const ValueKey('plugin_remove')));
    expect(find.byKey(const ValueKey('plugin_remove_dialog')), findsOneWidget);
  }

  Finder inDialog(Finder f) => find.descendant(of: find.byKey(const ValueKey('plugin_remove_dialog')), matching: f);

  bool listed(String name) => registry.entries.any((e) => e.descriptor.name == name);

  testWidgets('removing a user plugin lists its folder first, then deletes it and selects the neighbour', (tester) async {
    final dir = writePlugin(userDir, 'user_a');
    writePlugin(userDir, 'user_b');
    await pumpView(tester);
    await openRemove(tester, 'user_a');

    expect(inDialog(find.text(dir.path)), findsOneWidget);
    expect(inDialog(find.textContaining('3 files')), findsOneWidget);
    expect(inDialog(find.textContaining('every project on this machine')), findsOneWidget);
    expect(find.byKey(const ValueKey('plugin_remove_no_data')), findsOneWidget);
    expect(dir.existsSync(), isTrue, reason: 'nothing is deleted before Remove');

    // Cancel deletes nothing.
    await tapAndWait(tester, find.byKey(const ValueKey('plugin_remove_cancel')));
    expect(find.byKey(const ValueKey('plugin_remove_dialog')), findsNothing);
    expect(dir.existsSync(), isTrue);

    await tapAndWait(tester, find.byKey(const ValueKey('plugin_remove')));
    await tapAndWait(tester, find.byKey(const ValueKey('plugin_remove_confirm')));

    expect(find.byKey(const ValueKey('plugin_remove_dialog')), findsNothing);
    expect(dir.existsSync(), isFalse);
    expect([for (final e in userDir.listSync()) p.basename(e.path)], ['user_b'], reason: 'no set-aside folder is left');
    expect(listed('user_a'), isFalse);
    expect(find.text('Plugin user_a'), findsNothing);
    expect(rescans, 1);
    expect(vm.selectedEntry?.descriptor.name, 'user_b');
    expect(setEnabledCalls, isEmpty, reason: 'it was not enabled');
  });

  testWidgets('removing an enabled project plugin disables it and its dependents in the project', (tester) async {
    final dir = writePlugin(projectPlugins(), 'base_plugin');
    writePlugin(projectPlugins(), 'top_plugin', dependsOn: ['base_plugin']);
    await registry.initialize(projectDir.path);
    await registry.setEnabled('top_plugin', true);
    expect(enabledInProject(), ['base_plugin', 'top_plugin']);
    await pumpView(tester);
    await openRemove(tester, 'base_plugin');

    expect(inDialog(find.textContaining('removed from this project')), findsOneWidget);
    final enabledNote = tester.widget<Text>(find.byKey(const ValueKey('plugin_remove_enabled'))).data!;
    expect(enabledNote, contains('enabled_plugins'));
    expect(enabledNote, contains('top_plugin'));
    expect(enabledNote, contains('rebuilt on the next restart'));

    await tapAndWait(tester, find.byKey(const ValueKey('plugin_remove_confirm')));

    expect(dir.existsSync(), isFalse);
    expect(enabledInProject(), isEmpty);
    expect(setEnabledCalls, ['base_plugin:false:true']);
    expect(listed('base_plugin'), isFalse);
    final top = registry.entries.singleWhere((e) => e.descriptor.name == 'top_plugin');
    expect(top.enabled, isFalse);
    expect(top.restartPending, isTrue, reason: 'the rescan keeps the pending restart');
    expect(find.text('Restart required'), findsOneWidget);
  });

  testWidgets('a junction or symlink install is removed as a link; its target keeps every file', (tester) async {
    final target = writePlugin(Directory(p.join(temp.path, 'checkout')), 'dev_plugin');
    final before = filesUnder(target);
    final link = p.join(userDir.path, 'dev_plugin');
    linkFolder(link, target.path);
    await pumpView(tester);
    await openRemove(tester, 'dev_plugin');

    final note = tester.widget<Text>(find.byKey(const ValueKey('plugin_remove_linked'))).data!;
    expect(note, startsWith('Linked from '));
    expect(note, contains('only the link is removed'));
    expect(find.byKey(const ValueKey('plugin_remove_size')), findsNothing);

    await tapAndWait(tester, find.byKey(const ValueKey('plugin_remove_confirm')));

    expect(FileSystemEntity.typeSync(link, followLinks: false), FileSystemEntityType.notFound);
    expect(filesUnder(target), before);
    expect(listed('dev_plugin'), isFalse);
  });

  testWidgets('saved data is listed with its size and deleted only when ticked', (tester) async {
    writePlugin(userDir, 'data_plugin');
    final userData = Directory(p.join(dataDir.path, 'data_plugin'))..createSync();
    File(p.join(userData.path, 'settings.json')).writeAsStringSync('0123456789');
    final projectData = Directory(p.join(projectDir.path, '.lumina', 'plugins', 'data_plugin'))..createSync(recursive: true);
    File(p.join(projectData.path, 'chat.json')).writeAsStringSync('01234');
    await pumpView(tester);
    await openRemove(tester, 'data_plugin');

    expect(find.text(userData.path), findsOneWidget);
    expect(find.text(projectData.path), findsOneWidget);
    expect(find.textContaining('1 file, 10 B'), findsOneWidget);
    expect(find.textContaining('1 file, 5 B'), findsOneWidget);
    final box = tester.widget<Checkbox>(find.byKey(const ValueKey('plugin_remove_data')));
    expect(box.state, CheckboxState.unchecked);

    await tapAndWait(tester, find.byKey(const ValueKey('plugin_remove_data')));
    expect(tester.widget<Checkbox>(find.byKey(const ValueKey('plugin_remove_data'))).state, CheckboxState.checked);
    await tapAndWait(tester, find.byKey(const ValueKey('plugin_remove_confirm')));

    expect(Directory(p.join(userDir.path, 'data_plugin')).existsSync(), isFalse);
    expect(userData.existsSync(), isFalse);
    expect(projectData.existsSync(), isFalse);
  });

  testWidgets('saved data stays when the box is not ticked', (tester) async {
    writePlugin(userDir, 'data_plugin');
    final userData = Directory(p.join(dataDir.path, 'data_plugin'))..createSync();
    File(p.join(userData.path, 'settings.json')).writeAsStringSync('{}');
    await pumpView(tester);
    await openRemove(tester, 'data_plugin');
    await tapAndWait(tester, find.byKey(const ValueKey('plugin_remove_confirm')));
    expect(Directory(p.join(userDir.path, 'data_plugin')).existsSync(), isFalse);
    expect(File(p.join(userData.path, 'settings.json')).existsSync(), isTrue);
  });

  testWidgets('a user plugin that replaced a built-in gives its place back; built-ins have no Remove', (tester) async {
    writePlugin(engineDir, 'shared_plugin');
    writePlugin(userDir, 'shared_plugin', version: '2.0.0');
    writePlugin(userDir, 'loaded_plugin');
    await pumpView(tester);
    await openRemove(tester, 'shared_plugin');
    final back = tester.widget<Text>(find.byKey(const ValueKey('plugin_remove_comes_back'))).data!;
    expect(back, contains('built-in shared_plugin'));
    expect(back, contains(p.join(engineDir.path, 'shared_plugin')));

    await tapAndWait(tester, find.byKey(const ValueKey('plugin_remove_confirm')));

    final entry = registry.entries.singleWhere((e) => e.descriptor.name == 'shared_plugin');
    expect(entry.descriptor.origin, PluginOrigin.engine);
    expect(vm.selectedEntry?.descriptor.origin, PluginOrigin.engine);
    expect(find.byKey(const ValueKey('plugin_built_in_note')), findsOneWidget);
    expect(find.byKey(const ValueKey('plugin_remove')), findsNothing);

    // A plugin this session loaded stays active until a restart.
    await openRemove(tester, 'loaded_plugin');
    expect(find.byKey(const ValueKey('plugin_remove_loaded')), findsOneWidget);
    await tapAndWait(tester, find.byKey(const ValueKey('plugin_remove_cancel')));
  });

  testWidgets('a removal that cannot move the folder shows what was not removed and changes nothing', (tester) async {
    final dir = writePlugin(userDir, 'stuck_plugin');
    await registry.initialize(projectDir.path);
    await registry.setEnabled('stuck_plugin', true);
    await pumpView(tester);
    await openRemove(tester, 'stuck_plugin');
    final unlock = lockFolder(dir);
    try {
      await tapAndWait(tester, find.byKey(const ValueKey('plugin_remove_confirm')));
    } finally {
      unlock();
    }

    expect(find.byKey(const ValueKey('plugin_remove_error')), findsOneWidget);
    expect(find.textContaining('Nothing was removed'), findsOneWidget);
    expect(find.textContaining(dir.path), findsWidgets);
    expect(dir.existsSync(), isTrue);
    expect(listed('stuck_plugin'), isTrue);
    expect(enabledInProject(), ['stuck_plugin']);
    expect(setEnabledCalls, isEmpty);
    expect(rescans, 0);
    await tapAndWait(tester, find.byKey(const ValueKey('plugin_remove_close')));
    expect(find.byKey(const ValueKey('plugin_remove_dialog')), findsNothing);
  });
}
