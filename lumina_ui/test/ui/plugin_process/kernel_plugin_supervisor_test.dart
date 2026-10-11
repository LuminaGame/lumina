import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:lumina_editor_data/lumina_editor.dart'
    show LuminaProject, PluginOrigin, PluginRegistryService, PluginRepository, PluginScanRoot, ProjectRepository;
import 'package:path/path.dart' as p;

import 'kernel_plugin_harness.dart';
import 'plugin_process_harness.dart' show waitFor, waitForStatus;

/// Kernel plugins follow the plugin registry live, with a really compiled
/// `.dill` run on the real Dart VM: enabled → started as `dart <kernel>`
/// with its contributions; disabled → stopped and gone; no editor build or
/// restart.
void main() {
  late KernelPluginHarness h;
  late PluginRegistryService registry;

  Future<void> sync() => h.manager.syncKernelPlugins(registry.enabledKernelPlugins);

  setUp(() async {
    h = await KernelPluginHarness.create();
    final project = Directory(p.join(h.root.path, 'project'))..createSync(recursive: true);
    File(p.join(project.path, 'Fixture.lmproject'))
        .writeAsStringSync(jsonEncode(const LuminaProject(projectName: 'Fixture', enabledPlugins: []).toMap()));
    registry = PluginRegistryService(
      repo: PluginRepository(roots: [PluginScanRoot(dir: h.pluginsDir, origin: PluginOrigin.user)]),
      projectRepo: ProjectRepository(),
    );
  });
  tearDown(() => h.dispose());

  bool hasMenu() => h.registry.allMenuCommands.any((e) => e.key.contains('Kernel Sample/Place Barrels'));
  bool hasPanel() => h.registry.allPanels.any((panel) => panel.id == 'kernel_sample.panel');
  bool hasTool() => h.mcpTools.tools.any((t) => t.name.contains('kernel_sample_count'));

  test('enable starts dart <kernel> with its menu item, panel and MCP tool; disable stops it within 2 s', () async {
    final d = await h.sample();
    await registry.initialize(p.join(h.root.path, 'project'));
    expect(registry.enabledKernelPlugins, isEmpty);

    final enabled = await registry.setEnabled(d.name, true);
    expect(enabled.restartRequired, isFalse, reason: 'a kernel plugin applies live');
    expect(registry.entries.single.restartPending, isFalse);
    await sync();
    final s = h.manager.supervisorOf(d.name)!;
    await waitForStatus(s, PluginProcessStatus.running);
    final line = s.lastCommandLine!;
    expect(p.basenameWithoutExtension(line.first), 'dart');
    expect(p.equals(line[1], d.processKernelFile!.path), isTrue, reason: 'the command line names the kernel');
    expect(line, contains(PluginProcessLaunch.flag));
    await waitFor(() => hasMenu() && hasPanel() && hasTool(), reason: 'the contributions');
    expect(s.viewOf('kernel_sample.view')!.value.find('status')!['value'], 'Ready');
    final processPid = await s.call('pid');
    expect(processPid, isA<int>());
    expect(processPid, isNot(pid), reason: 'its own process, not the editor');

    final disabled = await registry.setEnabled(d.name, false);
    expect(disabled.restartRequired, isFalse);
    final sw = Stopwatch()..start();
    await sync();
    expect(sw.elapsed, lessThan(const Duration(seconds: 2)), reason: 'graceful shutdown answered at once');
    expect(s.state.value.status, PluginProcessStatus.stopped);
    expect(hasMenu() || hasPanel() || hasTool(), isFalse, reason: 'contributions gone');
    expect(h.manager.supervisorOf(d.name), isNull);
    expect(h.crashReporter.filed, isEmpty);
  });

  test('a killed kernel plugin is a plugin crash and restarts, as a compiled isolated plugin', () async {
    final d = await h.sample();
    await registry.initialize(p.join(h.root.path, 'project'));
    await registry.setEnabled(d.name, true);
    await sync();
    final s = h.manager.supervisorOf(d.name)!;
    await waitForStatus(s, PluginProcessStatus.running);
    final pid = s.reportedPid!;
    expect(Process.killPid(pid, ProcessSignal.sigkill), isTrue);
    await waitFor(() => h.crashReporter.filed.isNotEmpty, reason: 'a plugin crash report');
    expect(h.crashReporter.filed.single.plugin, d.name);
    await waitFor(() => s.startCount == 2 && s.state.value.status == PluginProcessStatus.running,
        reason: 'the automatic restart');
    expect(s.reportedPid, isNot(pid));
  });

  test('a tampered kernel (hash mismatch) is not started; the reason says why', () async {
    final d = await h.sample();
    final dill = d.processKernelFile!;
    dill.writeAsBytesSync([...dill.readAsBytesSync(), 0, 1, 2]);
    await registry.initialize(p.join(h.root.path, 'project'));
    await registry.setEnabled(d.name, true);
    await sync();
    final s = h.manager.supervisorOf(d.name)!;
    await waitFor(() => s.state.value.status == PluginProcessStatus.stopped && s.preparationError != null);
    expect(s.preparationError, contains('does not match'));
    expect(s.state.value.reason, contains('does not match'));
    expect(s.startCount, 0);
    expect(h.kernels.stateOf(d.name)!.error, contains('does not match'));
    expect(hasMenu(), isFalse);
  });
}
