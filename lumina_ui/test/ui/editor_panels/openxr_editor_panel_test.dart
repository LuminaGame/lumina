import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/core/editor_panels/editor_panel_docking.dart';
import 'package:lumina_ui/ui/core/editor_panels/editor_panel_runtime.dart';
import 'package:lumina_ui/ui/core/services/plugin_process/plugin_process_manager.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';

import 'editor_panel_fixture.dart';
import 'openxr_plugin_fixture.dart';

/// The OpenXR plugin as a real user plugin with its real process (the
/// simulated OpenXR runtime): its panel is the editor panel Widget Blueprint
/// it ships as content, docked right, run by the editor's Blueprint VM and
/// driven by the process.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final skip = openxrSkipReason();

  late EditorPanelProject project;
  late EditorViewModel vm;
  late PluginProcessManager processes;
  late Link plugin;

  setUp(() async {
    if (skip != null) return;
    project = await EditorPanelProject.create('OpenXrPanel', plugins: [kOpenxrPlugin]);
    plugin = installOpenxrUserPlugin(openxrCheckout()!);
    vm = await project.open();
    processes = attachOpenxrProcess(vm, openxrCheckout()!);
    await processes.startAll();
    await until(() => processes.supervisorOf(kOpenxrPlugin)?.state.value.status == PluginProcessStatus.running,
        timeout: const Duration(seconds: 120), reason: 'the OpenXR process to run');
    await EditorPanelProject.startPanels(vm);
    await until(() => vm.editorPanels.panel(kOpenxrPanelId) != null, reason: 'the OpenXR panel to be found');
  });

  tearDown(() async {
    if (skip != null) return;
    await processes.shutdownAll();
    await vm.close();
    if (plugin.existsSync()) plugin.deleteSync();
    await project.dispose();
  });

  Map<String, Object?> state(EditorPanelInstance panel, String element) => panel.element(element) ?? const {};
  Future<Map<Object?, Object?>> status() async =>
      await processes.supervisorOf(kOpenxrPlugin)!.call('status') as Map<Object?, Object?>;

  /// A Combo Box choice, as the panel's renderer makes it: the selection is
  /// written, then On Value Changed and On Selection Changed fire.
  void choose(EditorPanelInstance panel, String element, String label) {
    final node = vm.editorPanels.panel(kOpenxrPanelId)!.document.allNodes.firstWhere((n) => n.name == element);
    final s = LuminaUmgElementBinding.selectComboOption(panel.map, element, label, fallbackOptions: node.props['options']);
    vm.editorPanels.fire(panel, element, LuminaWidgetEvents.onValueChanged, {'value': label});
    vm.editorPanels.fire(panel, element, LuminaWidgetEvents.onSelectionChanged, s.eventArgs);
  }

  test('the OpenXR panel docks right, shows the simulated runtime and drives the process', () async {
    final rt = vm.editorPanels.panel(kOpenxrPanelId)!;
    expect(rt.errors, isEmpty, reason: 'its graph compiles in the editor scope');
    expect(rt.title, 'OpenXR');
    expect(rt.info.dock, LuminaEditorPanelDock.right);
    expect(rt.info.capabilities, {LuminaEditorPanelCapability.process});
    expect(vm.editorPanels.trustOf(kOpenxrPanelId).name, 'plugin', reason: 'trusted with its plugin');
    expect(vm.extensionRegistry.menuEntriesUnder('Plugins').map((e) => e.path), contains('Plugins/OpenXR/OpenXR Panel'));

    // Plugins ▸ OpenXR ▸ Check Runtime (the process) opens it docked right.
    final check = vm.extensionRegistry.allMenuCommands.firstWhere((e) => e.key == 'Plugins/OpenXR/Check Runtime').value;
    await check.execute(null);
    await until(() => vm.editorPanels.isOpen(kOpenxrPanelId), reason: 'the process to open its panel');
    expect(vm.panelsController.isVisible(EditorPanelDocking.descriptorId(kOpenxrPanelId)), isTrue);
    final panel = vm.editorPanels.instancesOf(kOpenxrPanelId).single;

    // Construct → status → every element filled from the process.
    await until(() => '${state(panel, 'RuntimeName')['text']}'.startsWith('Runtime: '), reason: 'the first status');
    final first = await status();
    expect(state(panel, 'RuntimeName')['text'], 'Runtime: ${first['active_runtime']}');
    expect(first['is_simulated'], isTrue, reason: 'no native loader bridge on the Dart VM');
    expect(state(panel, 'ManifestPath')['text'],
        '${first['manifest_path']}'.isEmpty ? 'Manifest: None detected' : 'Manifest: ${first['manifest_path']}');
    expect(state(panel, 'RuntimeKind')['text'], 'No physical OpenXR runtime active: using the simulated HMD for development.');
    expect(state(panel, 'SessionState')['text'], 'Session: idle');
    expect(state(panel, 'TogglePreview')['label'], 'Start VR Preview');
    expect(state(panel, 'TogglePreview')['style'], 'primary');
    expect(state(panel, 'TrackingOrigin')['selectedOption'], 'Floor level (standing)');
    expect(state(panel, 'StereoMode')['selectedOption'], 'Instanced');
    expect(state(panel, 'ForceSimulation')['isChecked'], isFalse);
    expect(state(panel, 'ForceSimulation')['isEnabled'], isTrue);

    // Force Simulated Runtime, Tracking Origin and Stereo mode reach the process.
    LuminaUmgElementBinding.write(panel.map, 'ForceSimulation', 'isChecked', true);
    vm.editorPanels.fire(panel, 'ForceSimulation', LuminaWidgetEvents.onValueChanged, {'value': true});
    choose(panel, 'TrackingOrigin', 'Stage (room scale)');
    choose(panel, 'StereoMode', 'Multiview');
    await until(() => state(panel, 'StereoMode')['selectedOption'] == 'Multiview' && panel.script!.variables['Status'] is Map &&
        (panel.script!.variables['Status'] as Map)['stereo_mode'] == 'multiview', reason: 'the stereo mode round trip');
    var now = await status();
    expect(now['simulation_forced'], isTrue);
    expect(state(panel, 'ManifestPath')['text'], 'Manifest: internal://simulated');
    expect(state(panel, 'ForceSimulation')['isChecked'], isTrue);
    expect(now['tracking_origin'], 'stage');
    expect(now['stereo_mode'], 'multiview');
    choose(panel, 'TrackingOrigin', 'Floor level (standing)');
    await until(() => (panel.script!.variables['Status'] as Map)['tracking_origin'] == 'floorLevel', reason: 'floor level');
    now = await status();
    expect(now['tracking_origin'], 'floorLevel');
    expect(state(panel, 'TrackingOrigin')['selectedOption'], 'Floor level (standing)');

    // Toggle VR Preview from the Plugins menu: the open panel's button
    // follows within 100 ms of the change.
    final toggle = vm.extensionRegistry.allMenuCommands.firstWhere((e) => e.key == 'Plugins/OpenXR/Toggle VR Preview').value;
    final watch = Stopwatch()..start();
    final done = toggle.execute(null);
    await until(() => state(panel, 'TogglePreview')['label'] == 'Stop VR Preview', reason: 'the button to follow');
    final reached = watch.elapsedMilliseconds;
    await done;
    final roundTrip = watch.elapsedMilliseconds;
    expect(reached, lessThan(roundTrip + 100), reason: 'the panel follows within 100 ms of the command finishing');
    expect(state(panel, 'TogglePreview')['style'], 'destructive');
    expect(state(panel, 'SessionState')['text'], 'Session: focused (preview running)');
    expect((await status())['vr_preview_active'], isTrue);

    // The panel's own button stops it.
    vm.editorPanels.fire(panel, 'TogglePreview', LuminaWidgetEvents.onClicked);
    await until(() => state(panel, 'TogglePreview')['label'] == 'Start VR Preview', reason: 'the panel button');
    expect(state(panel, 'TogglePreview')['style'], 'primary');
    expect((await status())['vr_preview_active'], isFalse);

    // Killing the process disables the inputs; Restart enables them again.
    final supervisor = processes.supervisorOf(kOpenxrPlugin)!;
    Process.killPid(supervisor.state.value.pid!);
    await until(() => state(panel, 'TogglePreview')['isEnabled'] == false, reason: 'the inputs to be disabled');
    for (final e in ['ForceSimulation', 'TrackingOrigin', 'StereoMode', 'TogglePreview']) {
      expect(state(panel, e)['isEnabled'], isFalse, reason: e);
    }
    await supervisor.restart();
    await until(() => state(panel, 'TogglePreview')['isEnabled'] == true, timeout: const Duration(seconds: 120), reason: 'Restart');
    for (final e in ['ForceSimulation', 'TrackingOrigin', 'StereoMode', 'TogglePreview']) {
      expect(state(panel, e)['isEnabled'], isTrue, reason: e);
    }
    // A fresh process: its own defaults reach the panel again.
    await until(() => state(panel, 'StereoMode')['selectedOption'] == 'Instanced', reason: 'the restarted process status');
  }, skip: skip, timeout: const Timeout(Duration(minutes: 6)));
}
