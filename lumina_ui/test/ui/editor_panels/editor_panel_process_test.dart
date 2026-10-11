import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/core/editor_panels/editor_panel_runtime.dart';
import 'package:lumina_ui/ui/core/services/plugin_process/plugin_process_launcher.dart';
import 'package:lumina_ui/ui/core/services/plugin_process/plugin_process_manager.dart';
import 'package:lumina_ui/ui/core/services/plugin_process/plugin_process_supervisor.dart';
import 'package:lumina_ui/ui/core/services/plugin_process/plugin_supervisor_timings.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:path/path.dart' as p;

import '../plugin_process/plugin_process_harness.dart' show dartExecutable;
import 'editor_panel_fixture.dart';

/// Never constructed: the sample runs as a real child process.
class _PureSamplePart extends LuminaPluginProcess {
  @override
  String get pluginName => 'pure_sample';

  @override
  void register(PluginProcessContext context) {}
}

/// An editor panel of a plugin whose process is the pure sample process of
/// `lumina_plugin_process`, running as a real child process: the panel calls
/// it, receives its events and element-state patches (coalesced), and sees it
/// crash; a call while it is down fails at once.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late EditorPanelProject project;
  late EditorViewModel vm;
  late PluginProcessManager processes;
  late String panelId;
  const panelPath = 'content/EPW_Status.lmas';

  EpwBuilder statusPanel() {
    final b = EpwBuilder('EPW_Status', LuminaEditorPanelInfo(title: 'Sample Status', dock: LuminaEditorPanelDock.right, capabilities: {LuminaEditorPanelCapability.process}));
    b.element(UmgWidgetType.text, 'StatusText', props: {'text': 'Idle'});
    b.variable('Result', 'Json');
    b.variable('Progress', 'Json');
    b.variable('ErrorCode', 'String', '');
    b.variable('State', 'String', '');
    b.variable('Events', 'Int', 0);
    // CallStatus → Call Plugin Process ("status", {}) → Result / ErrorCode.
    b.customEvent('call', 'CallStatus');
    b.node('editor_call_plugin_process', 'do_call', {'method': 'status'});
    b.node(LuminaBlueprintNodeLibrary.variableSet, 'set_result', {'variable': 'Result'});
    b.node(LuminaBlueprintNodeLibrary.variableSet, 'set_error', {'variable': 'ErrorCode'});
    b.wire('call', 'exec_out', 'do_call');
    b.wire('do_call', 'completed', 'set_result');
    b.wire('do_call', 'result', 'set_result', 'value');
    b.wire('do_call', 'failed', 'set_error');
    b.wire('do_call', 'error_code', 'set_error', 'value');
    // On Plugin Process Event (progress) → Progress = Data.
    b.node(LuminaEditorEventNodes.pluginProcessEvent, 'on_progress', {'event': 'progress'});
    b.node(LuminaBlueprintNodeLibrary.variableSet, 'set_progress', {'variable': 'Progress'});
    b.wire('on_progress', 'exec_out', 'set_progress');
    b.wire('on_progress', 'data', 'set_progress', 'value');
    // On Plugin Process State Changed → State.
    b.node(LuminaEditorEventNodes.pluginProcessStateChanged, 'on_state');
    b.node(LuminaBlueprintNodeLibrary.variableSet, 'set_state', {'variable': 'State'});
    b.wire('on_state', 'exec_out', 'set_state');
    b.wire('on_state', 'state', 'set_state', 'value');
    return b;
  }

  setUp(() async {
    project = await EditorPanelProject.create('ProcessPanels', plugins: ['pure_sample']);
    final plugin = project.writePlugin('pure_sample', friendlyName: 'Pure Sample');
    await statusPanel().writeTo(p.join(plugin.path, panelPath));
    vm = await project.open();
    final dart = dartExecutable();
    final script = p.join(Directory.current.parent.path, 'lumina_plugin_process', 'example', 'pure_process.dart');
    processes = PluginProcessManager(
      host: vm.extensionRegistry,
      processes: {'pure_sample': _PureSamplePart.new},
      launcher: PluginProcessLauncher(executable: dart, leadingArgs: [script], runInShell: Platform.isWindows && dart == 'dart'),
      timings: const PluginSupervisorTimings(
        pingInterval: Duration(milliseconds: 300),
        restartBackoff: [Duration(seconds: 30)],
        startTimeout: Duration(seconds: 60),
        callTimeout: Duration(seconds: 10),
      ),
    );
    vm.extensionRegistry.attachProcesses(processes);
    await processes.startAll();
    final supervisor = processes.supervisorOf('pure_sample')!;
    await until(() => supervisor.state.value.status == PluginProcessStatus.running, timeout: const Duration(seconds: 90),
        reason: 'the sample process to run');
    await EditorPanelProject.startPanels(vm);
    await until(() => vm.editorPanels.panels.isNotEmpty, reason: 'the plugin panel to be found');
    panelId = vm.editorPanels.panels.keys.single;
    expect(panelId, 'pure_sample/$panelPath');
    expect(vm.editorPanels.panel(panelId)!.errors, isEmpty);
  });

  tearDown(() async {
    await processes.shutdownAll();
    await vm.close();
    await project.dispose();
  });

  EditorPanelInstance openPanel() {
    vm.editorPanelDocking.open(panelId);
    return vm.editorPanels.instancesOf(panelId).single;
  }

  test('a call, an event, a patch, a burst of patches and a crash reach the plugin panel', () async {
    final panel = openPanel();
    final vars = panel.script!.variables;
    final supervisor = processes.supervisorOf('pure_sample')!;

    // Call Plugin Process ("status", {}) → Result Json from the handler.
    panel.script!.callBlueprint('CallStatus', const {});
    await until(() => vars['Result'] != null || '${vars['ErrorCode']}'.isNotEmpty, reason: 'the call to answer');
    expect(vars['ErrorCode'], '');
    expect((vars['Result'] as Map)['state'], 'idle');

    // The process emits progress {value: 0.5} → On Plugin Process Event.
    await supervisor.call('emitProgress', {'value': 0.5});
    await until(() => vars['Progress'] != null, reason: 'the progress event');
    expect(vars['Progress'], {'value': 0.5});

    // patchPanel sets StatusText.text = "Ready" without running the graph.
    final traced = <String>[];
    panel.script!.trace = (e) => traced.add(e.nodeId);
    await supervisor.call('patchStatus', {'panel': panelPath, 'text': 'Ready'});
    await until(() => panel.element('StatusText')!['text'] == 'Ready', reason: 'the patch');
    expect(traced, isEmpty, reason: 'a patch never runs the graph');

    // 200 patches in 1 s are coalesced to at most 30 rebuilds.
    final rebuilds = panel.rebuilds;
    await supervisor.call('patchBurst', {'panel': panelPath, 'count': 200, 'periodMs': 1000});
    await until(() => panel.element('StatusText')!['text'] == 'Step 200', reason: 'the last patch');
    expect(panel.rebuilds - rebuilds, lessThanOrEqualTo(30));
    expect(panel.rebuilds - rebuilds, greaterThan(5));

    // Kill the process → On Plugin Process State Changed (crashed); a call
    // then fails at once with `unavailable`.
    Process.killPid(supervisor.state.value.pid!);
    await until(() => vars['State'] == 'crashed', reason: 'the crash to reach the panel');
    vars['ErrorCode'] = '';
    final watch = Stopwatch()..start();
    panel.script!.callBlueprint('CallStatus', const {});
    await until(() => '${vars['ErrorCode']}'.isNotEmpty, reason: 'the failed call');
    expect(vars['ErrorCode'], PluginErrorCodes.unavailable);
    expect(watch.elapsedMilliseconds, lessThan(1000), reason: 'never hangs');
  }, timeout: const Timeout(Duration(minutes: 4)));

  test('the supervisor relays host.panelState patches as they come', () async {
    final PluginProcessSupervisor supervisor = processes.supervisorOf('pure_sample')!;
    final seen = <PluginPanelStatePatch>[];
    final sub = supervisor.panelStates.listen(seen.add);
    await supervisor.call('patchStatus', {'panel': panelPath, 'text': 'Hello'});
    await until(() => seen.isNotEmpty);
    await sub.cancel();
    expect(seen.single.panel, panelPath);
    expect(seen.single.ops.single.set, {'text': 'Hello'});
  }, timeout: const Timeout(Duration(minutes: 3)));
}
