import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/core/editor_panels/editor_panel_docking.dart';
import 'package:lumina_ui/ui/core/editor_panels/editor_panel_runtime.dart';
import 'package:lumina_ui/ui/core/services/plugin_process/plugin_process_manager.dart';
import 'package:lumina_ui/ui/features/launcher/services/project_editor_resolver.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:path/path.dart' as p;

import '../../helpers/editor_host_fixture.dart' show fixedFlutterInfo;
import 'editor_panel_fixture.dart';
import 'kimodo_plugin_fixture.dart';

/// Kimodo as a real user plugin and a kernel plugin: its process compiled
/// into a kernel with this Dart SDK and run on the Dart VM (no weights), its
/// whole UI the editor panel Widget Blueprints it ships, run by the editor's
/// Blueprint VM and patched by the process.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final skip = kimodoSkipReason();

  late EditorPanelProject project;
  late EditorViewModel vm;
  late PluginProcessManager processes;
  late Link plugin;
  late bool hasQuinn;

  final editorId = kimodoPanelId(kKimodoEditorAsset);
  final weightsId = kimodoPanelId(kKimodoWeightsAsset);

  setUp(() async {
    if (skip != null) return;
    // No weights: an empty models folder (the machine's downloaded weights stay out).
    final models = await Directory.systemTemp.createTemp('kimodo_no_weights_');
    addTearDown(() => models.delete(recursive: true));
    project = await EditorPanelProject.create('KimodoKernel', plugins: [kKimodoPlugin], pluginSettings: {
      kKimodoPlugin: {'models_dir': models.path, 'device': 'cpu'},
    });
    hasQuinn = importQuinn(project.projectDir);
    plugin = installKimodoUserPlugin(kimodoCheckout()!);
    vm = await project.open();
    processes = attachKernelProcesses(vm, Directory(p.join(project.root.path, 'plugin_kernels')));
    await processes.syncKernelPlugins([await kimodoDescriptor(plugin)]);
    await until(() => processes.supervisorOf(kKimodoPlugin)?.state.value.status == PluginProcessStatus.running,
        timeout: const Duration(minutes: 4), reason: 'the Kimodo kernel to compile and run');
    await EditorPanelProject.startPanels(vm);
    await until(() => vm.editorPanels.panel(editorId) != null, reason: 'the Kimodo editor panel');
  });

  tearDown(() async {
    if (skip != null) return;
    await processes.shutdownAll();
    await vm.close();
    if (plugin.existsSync()) plugin.deleteSync();
    await project.dispose();
  });

  Map<String, Object?> state(EditorPanelInstance panel, String element) => panel.element(element) ?? const {};
  Future<Map<Object?, Object?>> editorState() async =>
      await processes.supervisorOf(kKimodoPlugin)!.call('kimodo.editor.open', const {}) as Map<Object?, Object?>;

  test('the kernel plugin needs no editor build; its panels compile and drive the process', () async {
    // A kernel plugin: nothing to compile into the project editor.
    final descriptor = await kimodoDescriptor(plugin);
    expect(descriptor.isKernelPlugin, isTrue);
    final resolver = ProjectEditorResolver(
        engineRoot: LuminaWorkspace.root, cache: EditorBuildCache(root: Directory(p.join(project.root.path, 'builds'))),
        flutterInfo: fixedFlutterInfo, everyProject: false);
    expect(await resolver.enabledCodePlugins(project.projectDir.path), isEmpty, reason: 'no build splash');

    // Every panel compiles in the editor scope with no errors.
    for (final asset in [kKimodoEditorAsset, kKimodoMappingAsset, kKimodoWeightsAsset, kKimodoSettingsAsset]) {
      final rt = vm.editorPanels.panel(kimodoPanelId(asset));
      expect(rt, isNotNull, reason: asset);
      expect(rt!.errors, isEmpty, reason: '$asset: ${rt.errors.join('\n')}');
    }
    final rt = vm.editorPanels.panel(editorId)!;
    expect((rt.title, rt.info.dock), ('Kimodo Text to Motion', LuminaEditorPanelDock.tab));
    expect(vm.editorPanels.panel(weightsId)!.info.dock, LuminaEditorPanelDock.dialog);
    expect(vm.editorPanels.panel(kimodoPanelId(kKimodoSettingsAsset))!.info.dock, LuminaEditorPanelDock.projectSettings);

    // Plugins ▸ Kimodo ▸ Open Kimodo Editor docks the tab with the viewport,
    // the timeline and the sidebar, filled by the process.
    final open = vm.extensionRegistry.allMenuCommands.firstWhere((e) => e.key == 'Plugins/Kimodo/Open Kimodo Editor').value;
    await open.execute(null);
    await until(() => vm.layoutState.pluginPanelVisible[EditorPanelDocking.tabLayoutKey(editorId)] == true,
        reason: 'the editor tab');
    // The tab's view opens its instance when it builds (no widgets here).
    vm.editorPanels.open(editorId);
    await until(() => vm.editorPanels.isOpen(editorId), reason: 'the editor panel instance');
    final panel = vm.editorPanels.instancesOf(editorId).single;
    await until(() => (state(panel, 'KimodoTimeline')['clips'] as List?)?.isNotEmpty ?? false, reason: 'the open patch');
    expect(state(panel, 'KimodoViewport')['scene'], isA<Map>());
    expect(((state(panel, 'PromptList')['items'] as List).single as Map)['label'], contains('a person walks forward'));
    expect(state(panel, 'Toolbar')['isEnabled'], isTrue);

    if (hasQuinn) {
      // Picking a skeletal mesh shows it in the viewport.
      vm.editorPanels.fire(panel, 'MeshPicker', 'OnAssetPicked', {'asset_path': kQuinnMesh});
      await until(() {
        final nodes = ((state(panel, 'KimodoViewport')['scene'] as Map?)?['nodes'] as List?) ?? const [];
        return nodes.any((n) => n is Map && n['id'] == 'character' && n['asset'] == kQuinnMesh);
      }, reason: 'the character in the viewport');
      expect('${state(panel, 'CharacterInfo')['text']}', contains('SKM_Quinn_Simple'));
    }

    // A Left Hand key added on the timeline, then dragged by 2 frames: the
    // timeline shows the drag at once, the process takes it on release.
    vm.editorPanels.fire(panel, 'KimodoTimeline', 'OnKeyAdded', {'track': 'left_hand', 'frame': 30});
    await until(() => ((state(panel, 'KimodoTimeline')['keys'] as List?) ?? const []).isNotEmpty, reason: 'the key');
    final key = (state(panel, 'KimodoTimeline')['keys'] as List).single as Map;
    expect((key['track'], key['frame']), ('left_hand', 30));
    final dragged = [
      {...key, 'frame': 32},
    ];
    LuminaUmgElementBinding.write(panel.map, 'KimodoTimeline', 'keys', dragged);
    vm.editorPanels.fire(panel, 'KimodoTimeline', 'OnKeyCommit', {
      'key_ids': [key['id']],
      'delta_frames': 2,
    });
    expect(((state(panel, 'KimodoTimeline')['keys'] as List).single as Map)['frame'], 32, reason: 'at once');
    var s = await editorState();
    for (var i = 0; i < 50 && ((s['keys'] as List).single as Map)['frame'] != 32; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      s = await editorState();
    }
    expect(((s['keys'] as List).single as Map)['frame'], 32, reason: 'the process state on release');

    // Generate without weights opens the weights dialog (headless here: the
    // dialog panel instance opens and fills from the process).
    if (hasQuinn) {
      vm.editorPanels.docking = null;
      vm.editorPanels.fire(panel, 'GenerateButton', 'OnClicked');
      await until(() => vm.editorPanels.isOpen(weightsId), reason: 'the weights dialog');
      final dialog = vm.editorPanels.instancesOf(weightsId).single;
      await until(() => '${state(dialog, 'NvidiaLicence')['text']}'.contains('NVIDIA'), reason: 'the licence text');
      expect(state(dialog, 'DownloadButton')['isEnabled'], isFalse, reason: 'no licence accepted yet');
      expect('${state(panel, 'HudState')['text']}', startsWith('Weights missing'));
      vm.editorPanels.fire(dialog, 'CloseButton', 'OnClicked');
      await until(() => !vm.editorPanels.isOpen(weightsId), reason: 'the dialog to close');
    }

    // Killing the process disables the inputs and shows Restart; Restart
    // reloads the state from the process.
    final supervisor = processes.supervisorOf(kKimodoPlugin)!;
    Process.killPid(supervisor.state.value.pid!);
    await until(() => state(panel, 'Toolbar')['isEnabled'] == false, reason: 'the inputs to be disabled');
    expect(state(panel, 'Sidebar')['isEnabled'], isFalse);
    expect(state(panel, 'KimodoTimeline')['isEnabled'], isFalse);
    expect(state(panel, 'CrashBar')['visibility'], 'Visible');
    expect('${state(panel, 'CrashText')['text']}', contains('Restart'));
    LuminaUmgElementBinding.write(panel.map, 'KimodoTimeline', 'keys', const <Object?>[]);
    vm.editorPanels.fire(panel, 'RestartButton', 'OnClicked');
    await until(() => state(panel, 'Toolbar')['isEnabled'] == true, timeout: const Duration(minutes: 2), reason: 'Restart');
    await until(() => ((state(panel, 'KimodoTimeline')['keys'] as List?) ?? const []).length == 1, reason: 'the reloaded keys');
    expect(((state(panel, 'KimodoTimeline')['keys'] as List).single as Map)['frame'], 32);
    expect(state(panel, 'CrashBar')['visibility'], 'Collapsed');
  }, skip: skip, timeout: const Timeout(Duration(minutes: 10)));
}
