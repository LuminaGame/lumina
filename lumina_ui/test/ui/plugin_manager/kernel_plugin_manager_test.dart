import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:lumina_editor_data/lumina_editor.dart'
    show LuminaProject, PluginOrigin, PluginRegistryService, PluginRepository, PluginScanRoot, ProjectRepository;
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/plugin_manager/view_models/plugin_manager_view_model.dart';
import 'package:lumina_ui/ui/features/plugin_manager/views/plugin_manager_view.dart';
import 'package:path/path.dart' as p;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../plugin_process/kernel_plugin_harness.dart';
import '../plugin_process/plugin_process_harness.dart' show waitFor, waitForStatus;

/// The Plugin Manager for kernel plugins, over a real project, a real
/// `.lmplugin`, a really compiled kernel and its real process.
void main() {
  late KernelPluginHarness h;
  late PluginRegistryService registry;
  late PluginManagerViewModel pm;

  Future<void> setUpManager(WidgetTester tester, {String? sdkStamp}) async {
    await tester.runAsync(() async {
      h = await KernelPluginHarness.create();
      final project = Directory(p.join(h.root.path, 'project'))..createSync(recursive: true);
      File(p.join(project.path, 'Fixture.lmproject'))
          .writeAsStringSync(jsonEncode(const LuminaProject(projectName: 'Fixture', enabledPlugins: []).toMap()));
      await h.sample(sdkStamp: sdkStamp);
      registry = PluginRegistryService(
        repo: PluginRepository(roots: [PluginScanRoot(dir: h.pluginsDir, origin: PluginOrigin.user)]),
        projectRepo: ProjectRepository(),
      );
      await registry.initialize(project.path);
      pm = PluginManagerViewModel(
        registryService: registry,
        // What the editor does after the switch: the kernel plugins follow
        // the registry live.
        onSetEnabled: (name, enabled, {cascade = false}) => h.manager.syncKernelPlugins(registry.enabledKernelPlugins),
        processOf: h.manager.supervisorOf,
        runsInEditorProcess: (_) => false,
        onSetRunInEditorProcess: (_, _) async {},
        kernels: h.kernels,
      );
      pm.selectedEntry = registry.entries.single;
    });
    addTearDown(() => tester.runAsync(() async {
          pm.dispose();
          await h.dispose();
        }));
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: Scaffold(child: PluginManagerView(viewModel: pm))));
    await tester.pump();
  }

  String badge(WidgetTester tester) => tester
      .widget<Text>(find.descendant(of: find.byKey(const ValueKey('plugin_kernel_badge_kernel_sample')), matching: find.byType(Text)))
      .data!;

  testWidgets('a Kernel badge with the SDK and the shipped kernel; live Enable/Disable with no rebuild notice',
      (tester) async {
    await setUpManager(tester);
    expect(badge(tester), 'Kernel');

    // Enable: no Restart required, the process starts.
    // Tapped on the real clock: the switch starts a real process.
    await tester.runAsync(() async {
      await tester.tap(find.byType(Switch).first);
      await waitFor(() => h.manager.supervisorOf('kernel_sample') != null, reason: 'the supervisor');
      await waitForStatus(h.manager.supervisorOf('kernel_sample')!, PluginProcessStatus.running);
    });
    await tester.pump();
    expect(registry.entries.single.restartPending, isFalse);
    expect(find.text('Restart required'), findsNothing);
    final sdk = h.kernels.stateOf('kernel_sample')!.vmSdk;
    expect(badge(tester), 'Kernel · Dart $sdk · shipped');
    expect(find.byKey(const ValueKey('plugin_kernel_details_kernel_sample')), findsOneWidget);

    // The in-process override does not apply to a kernel plugin.
    final override = tester.widget<Switch>(find.byKey(const ValueKey('plugin_process_in_editor_kernel_sample')));
    expect(override.onChanged, isNull);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('plugin_process_in_editor_note_kernel_sample'))).data,
      contains('kernel plugin'),
    );

    // Disable: stopped and gone, still no notice.
    final s = h.manager.supervisorOf('kernel_sample')!;
    await tester.runAsync(() async {
      await tester.tap(find.byType(Switch).first);
      await waitForStatus(s, PluginProcessStatus.stopped);
      expect(h.manager.supervisorOf('kernel_sample'), isNull);
    });
    await tester.pump();
    expect(s.state.value.status, PluginProcessStatus.stopped);
    expect(find.text('Restart required'), findsNothing);
    expect(registry.enabledKernelPlugins, isEmpty);
  });

  testWidgets('a kernel from another SDK shows recompiled', (tester) async {
    await setUpManager(tester, sdkStamp: '2.19.0');
    // Tapped on the real clock: the switch starts a real process.
    await tester.runAsync(() async {
      await tester.tap(find.byType(Switch).first);
      await waitFor(() => h.manager.supervisorOf('kernel_sample') != null, reason: 'the supervisor');
      await waitForStatus(h.manager.supervisorOf('kernel_sample')!, PluginProcessStatus.running, timeout: const Duration(seconds: 60));
    });
    await tester.pump();
    final sdk = h.kernels.stateOf('kernel_sample')!.vmSdk;
    expect(badge(tester), 'Kernel · Dart $sdk · recompiled');
  });

  test('the in-process override is unavailable for a process plugin without a registration_class', () async {
    final root = Directory.systemTemp.createTempSync('lumina_pm_shellless_');
    addTearDown(() => root.deleteSync(recursive: true));
    final plugins = Directory(p.join(root.path, 'plugins', 'shellless'))..createSync(recursive: true);
    File(p.join(plugins.path, 'shellless.lmplugin')).writeAsStringSync(jsonEncode({
      'name': 'shellless',
      'version': '1.0.0',
      'isolation': 'process',
      'modules': [
        {'name': 'shellless', 'type': 'editor', 'entry_library': 'lib/s.dart', 'process_class': 'SProcess'},
      ],
    }));
    final project = Directory(p.join(root.path, 'project'))..createSync();
    File(p.join(project.path, 'P.lmproject')).writeAsStringSync(jsonEncode(const LuminaProject(projectName: 'P').toMap()));
    final registry = PluginRegistryService(
      repo: PluginRepository(roots: [PluginScanRoot(dir: plugins.parent, origin: PluginOrigin.user)]),
      projectRepo: ProjectRepository(),
    );
    await registry.initialize(project.path);
    final vm = PluginManagerViewModel(registryService: registry);
    expect(vm.isKernel('shellless'), isFalse);
    expect(vm.inEditorUnavailableReason('shellless'), contains('registration_class'));
    vm.dispose();
  });
}
