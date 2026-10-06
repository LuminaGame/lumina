import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:lumina_ui/ui/core/services/plugin_process/plugin_supervisor_timings.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'plugin_process_harness.dart';

/// The guard around an isolated plugin's panels: spinner while starting,
/// "`<plugin>` stopped: `<reason>`" with Restart and Details when its process
/// is gone, the panel itself while it runs.
void main() {
  // No automatic restarts: the process stays stopped until Restart.
  const timings = PluginSupervisorTimings(
    pingInterval: Duration(milliseconds: 300),
    restartBackoff: [],
    startTimeout: Duration(seconds: 30),
    callTimeout: Duration(seconds: 5),
    shutdownTimeout: Duration(seconds: 2),
  );

  testWidgets('a declarative panel of a real plugin process: running, stopped with the reason, Details, Restart', (tester) async {
    late PluginProcessHarness h;
    await tester.runAsync(() async {
      h = await PluginProcessHarness.create(timings: timings);
      h.mode = 'normal';
    });
    addTearDown(() => tester.runAsync(h.dispose));
    final s = h.supervisor;
    await tester.runAsync(() async {
      await s.start();
      await waitForStatus(s, PluginProcessStatus.running);
    });
    final panel = h.registry.allPanels.firstWhere((p) => p.id == kFakePanelId);
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(child: SizedBox(width: 600, height: 500, child: Builder(builder: panel.builder))),
    ));
    await tester.pump();
    final stoppedCard = find.byKey(const ValueKey('plugin_process_stopped_$kFakePluginName'));
    expect(stoppedCard, findsNothing);
    expect(find.byKey(const ValueKey('plugin_process_guard_child')), findsOneWidget);

    // The process dies: the panel says so, the editor goes on.
    await tester.runAsync(() async {
      await s.call('exit', {'code': 3}).catchError((_) => null);
      await waitForStatus(s, PluginProcessStatus.stopped);
    });
    await tester.pump();
    expect(stoppedCard, findsOneWidget);
    final reason = tester.widget<Text>(find.byKey(const ValueKey('plugin_process_reason_$kFakePluginName')));
    expect(reason.data, startsWith('$kFakePluginName stopped: exited with code 3'));

    await tester.tap(find.byKey(const ValueKey('plugin_process_details_$kFakePluginName')));
    await tester.pump();
    final log = find.byKey(const ValueKey('plugin_process_log_$kFakePluginName'));
    expect(log, findsOneWidget);
    expect(find.descendant(of: log, matching: find.textContaining('fake plugin exiting with code 3')), findsOneWidget);

    // Restart: a spinner while it starts, then the panel again.
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('plugin_process_restart_$kFakePluginName')));
      await tester.pump();
      await waitFor(() => s.state.value.status != PluginProcessStatus.stopped, reason: 'the restart to begin');
    });
    await tester.pump();
    if (s.state.value.status == PluginProcessStatus.starting) {
      expect(find.byKey(const ValueKey('plugin_process_starting_$kFakePluginName')), findsOneWidget);
    }
    await tester.runAsync(() => waitForStatus(s, PluginProcessStatus.running));
    await tester.pump();
    expect(stoppedCard, findsNothing);
    expect(find.byKey(const ValueKey('plugin_process_starting_$kFakePluginName')), findsNothing);
  });

  testWidgets('a shell panel of an isolated plugin is guarded; a plugin without a process part is not', (tester) async {
    late PluginProcessHarness h;
    await tester.runAsync(() async {
      h = await PluginProcessHarness.create(timings: timings);
    });
    addTearDown(() => tester.runAsync(h.dispose));
    final r = h.registry;
    r.beginRegistration(kFakePluginName);
    r.registerPanel(EditorPanelDescriptor(id: 'shell_panel', title: 'Shell', icon: LucideIcons.box, builder: (_) => const Text('shell body')));
    r.registerTab(EditorTabDescriptor(id: 'shell_tab', title: 'Shell Tab', builder: (_) => const Text('tab body')));
    r.endRegistration();
    r.beginRegistration('other_plugin');
    final plain = EditorPanelDescriptor(id: 'plain_panel', title: 'Plain', icon: LucideIcons.box, builder: (_) => const Text('plain body'));
    r.registerPanel(plain);
    r.endRegistration();
    expect(identical(r.allPanels.firstWhere((p) => p.id == 'plain_panel'), plain), isTrue);

    // Never started: stopped, so the shell panel is covered.
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(
        child: Column(children: [
          SizedBox(height: 300, child: Builder(builder: r.allPanels.firstWhere((p) => p.id == 'shell_panel').builder)),
          SizedBox(height: 100, child: Builder(builder: r.findTab('shell_tab')!.builder)),
        ]),
      ),
    ));
    await tester.pump();
    expect(find.byKey(const ValueKey('plugin_process_stopped_$kFakePluginName')), findsNWidgets(2));
    expect(find.text('shell body'), findsOneWidget, reason: 'the shell keeps its place under the card');
  });
}
