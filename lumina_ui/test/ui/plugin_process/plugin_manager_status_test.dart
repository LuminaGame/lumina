import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/plugin_manager/view_models/plugin_manager_view_model.dart';
import 'package:lumina_ui/ui/features/plugin_manager/views/plugin_manager_view.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../helpers/temp_project.dart';
import 'plugin_process_harness.dart';

/// The Plugin Manager for an isolated plugin: its process Status, Restart,
/// last exit code, log tail and the project's "Run in editor process"
/// override, over a real project, a real `.lmplugin` and a real process.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('status badge, details, Restart and the in-editor-process override', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late Directory root;
    late EditorViewModel vm;
    late PluginProcessHarness h;
    late PluginManagerViewModel pm;
    await tester.runAsync(() async {
      root = Directory.systemTemp.createTempSync('lumina_pm_status_');
      vm = EditorViewModel(
        initialProject: const LuminaProject(projectName: 'PmStatus', activeLevel: 'contents/levels/L_Main.lmas'),
        projectLocation: root.path,
        enableTimers: false,
        autoInitAssets: false,
      );
      await vm.ensureDefaultLevelAssets();
      await ProjectRepository().saveProject(vm.project, vm.projectDirPath);
      final pluginsDir = Directory('${vm.projectDirPath}/plugins');
      File('${pluginsDir.path}/$kFakePluginName/$kFakePluginName.lmplugin')
        ..createSync(recursive: true)
        ..writeAsStringSync(jsonEncode({
          'name': kFakePluginName,
          'friendly_name': 'Fake Plugin',
          'version': '1.0.0',
          'category': 'Tools',
          'isolation': 'process',
          'modules': [
            {'name': 'Fake', 'type': 'editor', 'entry_library': 'fake.dart', 'registration_class': 'FakePlugin', 'process_class': 'FakeProcess'},
          ],
        }));
      final registryService = PluginRegistryService(
        repo: PluginRepository(roots: [PluginScanRoot(dir: pluginsDir, origin: PluginOrigin.project)]),
        projectRepo: ProjectRepository(),
      );
      await registryService.initialize(vm.projectDirPath);
      h = await PluginProcessHarness.create(timings: kFastTimings);
      h.mode = 'normal';
      await h.supervisor.start();
      await waitForStatus(h.supervisor, PluginProcessStatus.running);
      pm = PluginManagerViewModel(
        registryService: registryService,
        processOf: h.manager.supervisorOf,
        runsInEditorProcess: vm.pluginRunsInEditorProcess,
        onSetRunInEditorProcess: (name, inEditor) async {
          await vm.setPluginRunsInEditorProcess(name, inEditor);
          h.inEditor = inEditor;
          await h.manager.setRunInEditorProcess(name, inEditor);
        },
      );
      pm.selectedEntry = registryService.entries.firstWhere((e) => e.descriptor.name == kFakePluginName);
    });
    addTearDown(() => tester.runAsync(() async {
          await h.dispose();
          await vm.close();
          await deleteTempProject(root);
        }));

    await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: Scaffold(child: PluginManagerView(viewModel: pm))));
    await tester.pump();
    Text statusText() => tester.widget<Text>(find.descendant(
          of: find.byKey(const ValueKey('plugin_process_status_$kFakePluginName')).first,
          matching: find.byType(Text),
        ));
    // Card and details both show it.
    expect(find.byKey(const ValueKey('plugin_process_status_$kFakePluginName')), findsNWidgets(2));
    expect(statusText().data, 'Running');
    expect(find.byKey(const ValueKey('plugin_process_section_$kFakePluginName')), findsOneWidget);

    // It crashes: Crashed with the exit code, its log tail in the details.
    final s = h.supervisor;
    await tester.runAsync(() async {
      await s.call('exit', {'code': 3}).catchError((_) => null);
      await waitForStatus(s, PluginProcessStatus.crashed);
    });
    await tester.pump();
    expect(statusText().data, 'Crashed');
    final detail = tester.widget<Text>(find.byKey(const ValueKey('plugin_process_detail_$kFakePluginName')));
    expect(detail.data, contains('last exit code 3'));
    final log = find.byKey(const ValueKey('plugin_process_manager_log_$kFakePluginName'));
    expect(find.descendant(of: log, matching: find.textContaining('fake plugin exiting with code 3')), findsOneWidget);

    // Restart from the manager.
    await tester.runAsync(() async {
      await waitForStatus(s, PluginProcessStatus.running); // the automatic restart
      final pid = s.state.value.pid;
      await tester.tap(find.byKey(const ValueKey('plugin_process_manager_restart_$kFakePluginName')));
      await waitFor(() => s.state.value.status == PluginProcessStatus.running && s.state.value.pid != pid, reason: 'the manual restart');
    });
    await tester.pump();
    expect(statusText().data, 'Running');
    expect(s.state.value.restarts, 0);

    // The override: written to the project, the plugin moves into the editor.
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('plugin_process_in_editor_$kFakePluginName')));
      await waitForStatus(s, PluginProcessStatus.inProcess);
    });
    await tester.pump();
    expect(statusText().data, 'In process');
    final saved = jsonDecode(File('${vm.projectDirPath}/PmStatus.lmproject').readAsStringSync()) as Map;
    expect(saved['plugin_isolation'], {kFakePluginName: 'in_process'});
    expect(vm.pluginRunsInEditorProcess(kFakePluginName), isTrue);

    // And back.
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('plugin_process_in_editor_$kFakePluginName')));
      await waitForStatus(s, PluginProcessStatus.running);
    });
    await tester.pump();
    final again = jsonDecode(File('${vm.projectDirPath}/PmStatus.lmproject').readAsStringSync()) as Map;
    expect(again.containsKey('plugin_isolation'), isFalse);
  });
}
