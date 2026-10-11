import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/core/services/plugin_process/kernel_dart_sdk.dart';
import 'package:lumina_ui/ui/core/services/plugin_process/kernel_plugin_preparer.dart';
import 'package:lumina_ui/ui/core/services/plugin_process/plugin_dialog_queue.dart';
import 'package:lumina_ui/ui/core/services/plugin_process/plugin_supervisor_timings.dart';
import 'package:lumina_ui/ui/core/services/user_plugin_dir.dart';
import 'package:lumina_ui/ui/core/widgets/plugin_view/plugin_process_dialog.dart';
import 'package:lumina_ui/ui/features/plugin_manager/services/plugin_importer.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/core/widgets/plugin_view/plugin_view_scope.dart' show pluginControlKey;
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../test/ui/plugin_process/fixtures/kernel_sample_plugin.dart';
import '../../test/ui/plugin_process/plugin_process_harness.dart';

/// The editor viewport runs tickers while mounted: pump a bounded run of
/// frames on the live clock.
Future<void> settle(WidgetTester tester, {int frames = 20}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
  }
}

/// An isolated plugin in a real project: its declarative panel sits in the
/// right dock while real models render in the level; its process is killed
/// from outside on camera, the editor keeps rendering, the panel says the
/// plugin stopped, and Restart brings it back.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Plugin Isolation Smoke: a killed plugin process leaves the editor running and Restart recovers it', (tester) async {
    const name = 'Plugin Isolation Smoke: a killed plugin process leaves the editor running and Restart recovers it';
    const models = ['Props/Barrels/empty_barrel.glb', 'Props/AC_units/ac_unit_a_300x300.glb', 'Props/Banana Bunch/banana_bunch_medium.glb'];
    tester.view.physicalSize = const Size(1920, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final tempProjectsDir = Directory.systemTemp.createTempSync('plugin_iso_smoke_');
    final pDir = Directory('${tempProjectsDir.path}/IsoSmoke')..createSync(recursive: true);
    late PluginProcessHarness h;
    try {
      const project = LuminaProject(projectName: 'IsoSmoke', activeLevel: 'contents/levels/L_Main.lmas', settings: EngineScalabilitySettings(targetFps: 60));
      File('${pDir.path}/IsoSmoke.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
      final vm = EditorViewModel(initialProject: project, projectDirPath: tempProjectsDir.path, enableTimers: false);
      addTearDown(vm.dispose);
      await tester.runAsync(() => vm.ensureDefaultLevelAssets());
      final used = <String>[];
      for (final m in models) {
        final src = File('${SmokeArtifacts.testAssetsDir.path}/$m');
        if (!src.existsSync()) continue;
        used.add(m);
        await tester.runAsync(() => vm.processImportPipeline(sourceFilePath: src.path));
      }
      expect(used, isNotEmpty, reason: 'test-assets models are needed');
      vm.refreshAssets();
      final meshes = vm.realAssets.where((a) => a.type == AssetType.filamesh).toList();
      for (var i = 0; i < meshes.length; i++) {
        await tester.runAsync(() => vm.spawnActorFromAsset(meshes[i], location: [i * 250.0 - 250.0, 0.0, 0.0]));
      }
      // A sun and a sky, so the models are lit.
      await tester.runAsync(() => vm.extensionRegistry.level.addActors(const [
            EditorActorSpec(
              name: 'DirectionalLight_Sun',
              type: 'DirectionalLight',
              location: [0.0, -400.0, 800.0],
              rotation: [-50.0, 0.0, 30.0],
              components: [
                EditorComponentSpec(type: 'LuminaDirectionalLightComponent', name: 'Sun', properties: {
                  'intensity': 100000.0,
                  'effectiveColorHex': '#FFF2E0',
                  'castShadows': true,
                }),
              ],
            ),
            EditorActorSpec(
              name: 'SkyAtmosphere_Env',
              type: 'Environment',
              location: [0.0, 0.0, 0.0],
              components: [
                EditorComponentSpec(type: 'LuminaSkyComponent', name: 'Sky', properties: {
                  'mode': 'color',
                  'colorHex': '#5A86C6',
                  'skyIntensity': 30000.0,
                  'iblIntensity': 30000.0,
                }),
              ],
            ),
          ]));

      // The isolated plugin: a real child process over the plugin protocol;
      // no automatic restart, so the stop stays on screen until Restart.
      await tester.runAsync(() async {
        h = await PluginProcessHarness.create(
          registry: vm.extensionRegistry,
          timings: const PluginSupervisorTimings(
            pingInterval: Duration(milliseconds: 500),
            restartBackoff: [],
            startTimeout: Duration(seconds: 30),
            shutdownTimeout: Duration(seconds: 2),
          ),
        );
        h.mode = 'normal';
        await h.supervisor.start();
        await waitForStatus(h.supervisor, PluginProcessStatus.running);
      });
      addTearDown(() => tester.runAsync(h.dispose));
      final s = h.supervisor;

      final boundaryKey = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: boundaryKey,
        child: ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)),
      ));
      await settle(tester, frames: 30);
      vm.showPluginPanel(kFakePanelId);
      vm.frameLevelBounds();
      await settle(tester, frames: 30);
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      Future<void> shot(String suffix) async {
        final png = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
        SmokeArtifacts.saveScreenshot('$name ($suffix)', png, usedAssets: used);
      }

      final stopped = find.byKey(const ValueKey('plugin_process_stopped_$kFakePluginName'));
      expect(find.byKey(const ValueKey('right_dock')), findsOneWidget);
      expect(stopped, findsNothing);
      await rec.hold(const Duration(seconds: 2));
      // The panel is rendered from the process's spec; a press runs there
      // and comes back as a patch.
      Future<void> press() async {
        await tester.tap(find.descendant(of: find.byKey(pluginControlKey(kFakeViewId, 'press')), matching: find.text('Press')));
        await tester.runAsync(() => waitFor(() => s.viewOf(kFakeViewId)!.value.find('count')!['value'] == 'pressed 1',
            reason: 'the patched panel'));
        await settle(tester, frames: 10);
        expect(find.text('pressed 1'), findsOneWidget);
      }

      await press();
      await rec.hold(const Duration(seconds: 2));
      await shot('running');

      // Killed from outside, as a native crash would end it.
      final pid = s.reportedPid!;
      Process.killPid(pid, ProcessSignal.sigkill);
      await tester.runAsync(() => waitForStatus(s, PluginProcessStatus.stopped));
      await settle(tester, frames: 10);
      expect(stopped, findsOneWidget);
      expect(vm.actors.where((a) => a.meshAssetPath != null && a.meshAssetPath!.isNotEmpty), hasLength(meshes.length), reason: 'the level is untouched');
      await rec.hold(const Duration(seconds: 3));
      await tester.tap(find.byKey(const ValueKey('plugin_process_details_$kFakePluginName')));
      await settle(tester, frames: 10);
      await rec.hold(const Duration(seconds: 2));
      await shot('stopped');

      // The editor keeps working: orbit the level while the plugin is down.
      vm.frameLevelBounds();
      await rec.hold(const Duration(seconds: 2));

      await tester.tap(find.byKey(const ValueKey('plugin_process_restart_$kFakePluginName')));
      await tester.runAsync(() => waitForStatus(s, PluginProcessStatus.running));
      await settle(tester, frames: 20);
      expect(stopped, findsNothing);
      expect(s.reportedPid, isNot(pid));
      await rec.hold(const Duration(seconds: 1));
      await press(); // a fresh process: its own count again
      await rec.hold(const Duration(seconds: 2));
      await shot('restarted');
      rec.save(name, usedAssets: used);
    } finally {
      try {
        if (tempProjectsDir.existsSync()) tempProjectsDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  testWidgets('Plugin Isolation Smoke: kernel plugin added and removed while the editor runs', (tester) async {
    const name = 'Plugin Isolation Smoke: kernel plugin added and removed while the editor runs';
    const models = ['Props/Barrels/empty_barrel.glb', 'Props/AC_units/ac_unit_a_300x300.glb'];
    tester.view.physicalSize = const Size(1920, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final temp = Directory.systemTemp.createTempSync('kernel_smoke_');
    final previousUserDir = UserPluginDir.override;
    final previousDataDir = LuminaDataDir.override;
    UserPluginDir.override = Directory('${temp.path}/user_plugins')..createSync();
    LuminaDataDir.override = Directory('${temp.path}/lumina_data')..createSync();
    KernelDartSdk.override = sdkDart();
    addTearDown(() {
      UserPluginDir.override = previousUserDir;
      LuminaDataDir.override = previousDataDir;
      KernelDartSdk.override = null;
    });
    try {
      // The reference kernel plugin as a zip, its kernel stamped with
      // another Dart SDK: the editor must recompile it.
      final zip = File('${temp.path}/kernel_sample-1.0.0.zip');
      await tester.runAsync(() async {
        final src = await writeKernelSamplePlugin(Directory('${temp.path}/src'), sdkStamp: '2.19.0');
        final archive = Archive();
        for (final f in src.listSync(recursive: true).whereType<File>()) {
          final rel = f.path.substring(src.path.length + 1).replaceAll(r'\', '/');
          if (rel.startsWith('.dart_tool/')) continue;
          archive.addFile(ArchiveFile.bytes('kernel_sample/$rel', f.readAsBytesSync()));
        }
        zip.writeAsBytesSync(ZipEncoder().encodeBytes(archive));
      });

      final projectsDir = Directory('${temp.path}/projects')..createSync();
      final pDir = Directory('${projectsDir.path}/KernelSmoke')..createSync();
      const project = LuminaProject(
          projectName: 'KernelSmoke', activeLevel: 'contents/levels/L_Main.lmas', settings: EngineScalabilitySettings(targetFps: 60));
      File('${pDir.path}/KernelSmoke.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
      final vm = EditorViewModel(initialProject: project, projectDirPath: projectsDir.path, enableTimers: false);
      addTearDown(vm.dispose);
      await tester.runAsync(() => vm.ensureDefaultLevelAssets());
      final used = <String>[];
      for (final m in models) {
        final src = File('${SmokeArtifacts.testAssetsDir.path}/$m');
        if (!src.existsSync()) continue;
        used.add(m);
        await tester.runAsync(() => vm.processImportPipeline(sourceFilePath: src.path));
      }
      expect(used, isNotEmpty, reason: 'test-assets models are needed');
      vm.refreshAssets();
      final meshes = vm.realAssets.where((a) => a.type == AssetType.filamesh).toList();
      for (var i = 0; i < meshes.length; i++) {
        await tester.runAsync(() => vm.spawnActorFromAsset(meshes[i], location: [i * 250.0 - 125.0, 0.0, 0.0]));
      }
      await tester.runAsync(() => vm.extensionRegistry.level.addActors(const [
            EditorActorSpec(
              name: 'DirectionalLight_Sun',
              type: 'DirectionalLight',
              location: [0.0, -400.0, 800.0],
              rotation: [-50.0, 0.0, 30.0],
              components: [
                EditorComponentSpec(type: 'LuminaDirectionalLightComponent', name: 'Sun', properties: {
                  'intensity': 100000.0,
                  'effectiveColorHex': '#FFF2E0',
                  'castShadows': true,
                }),
              ],
            ),
            EditorActorSpec(
              name: 'SkyAtmosphere_Env',
              type: 'Environment',
              location: [0.0, 0.0, 0.0],
              components: [
                EditorComponentSpec(type: 'LuminaSkyComponent', name: 'Sky', properties: {
                  'mode': 'color',
                  'colorHex': '#5A86C6',
                  'skyIntensity': 30000.0,
                  'iblIntensity': 30000.0,
                }),
              ],
            ),
          ]));
      await tester.runAsync(() => vm.pluginsScanned);

      final boundaryKey = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: boundaryKey,
        child: ShadcnApp(
          theme: luminaEditorTheme(),
          builder: (context, child) => PluginDialogLayer(queue: PluginDialogQueue.shared, child: child ?? const SizedBox.shrink()),
          home: MainEditorView(viewModel: vm),
        ),
      ));
      await settle(tester, frames: 30);
      vm.frameLevelBounds();
      await settle(tester, frames: 20);
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      Future<void> shot(String suffix) async {
        final png = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
        SmokeArtifacts.saveScreenshot('$name ($suffix)', png, usedAssets: used);
      }

      await rec.hold(const Duration(seconds: 2));
      final actorsBefore = vm.actors.length;

      // Installed from the zip, as Plugin Manager > Import from Zip does,
      // then enabled: no build, no restart.
      await tester.runAsync(() async {
        final result =
            await PluginImporter(existing: [for (final e in vm.pluginRegistry.entries) e.descriptor]).importZip(zip.path);
        expect(result.status, PluginImportStatus.installed, reason: result.messages.join('\n'));
        await vm.rescanPlugins();
      });
      final entry = vm.pluginRegistry.entries.firstWhere((e) => e.descriptor.name == kKernelSampleName);
      expect(entry.descriptor.isKernelPlugin, isTrue);
      vm.openSubEditorTab('plugins', title: 'Plugins');
      await settle(tester, frames: 10);
      late Future<void> enabling;
      await tester.runAsync(() async {
        enabling = vm.enablePlugin(kKernelSampleName, true);
      });
      // "Preparing ... for Dart x" while the kernel is recompiled.
      var sawPreparing = false;
      for (var i = 0; i < 300; i++) {
        final sup = vm.pluginProcesses.supervisorOf(kKernelSampleName);
        if (sup != null && sup.state.value.status == PluginProcessStatus.running) break;
        if (vm.pluginProcesses.kernels.stateOf(kKernelSampleName)?.progress != null) sawPreparing = true;
        await rec.hold(const Duration(milliseconds: 200));
      }
      await tester.runAsync(() => enabling);
      final s = vm.pluginProcesses.supervisorOf(kKernelSampleName)!;
      expect(s.state.value.status, PluginProcessStatus.running);
      expect(sawPreparing, isTrue, reason: 'the kernel from another SDK is recompiled');
      expect(vm.pluginProcesses.kernels.stateOf(kKernelSampleName)!.source, KernelSource.recompiled);
      expect(vm.pluginRestartRequired, isFalse, reason: 'no build or restart');
      await rec.hold(const Duration(seconds: 2));
      await shot('enabled in the plugin manager');

      // Back to the level: the plugin's panel and menu item are there.
      vm.selectTab(0);
      await settle(tester, frames: 10);
      await tester.runAsync(() => waitFor(
          () => vm.extensionRegistry.allPanels.any((panel) => panel.id == 'kernel_sample.panel'),
          reason: 'the panel'));
      vm.showPluginPanel('kernel_sample.panel');
      await settle(tester, frames: 10);
      final command =
          vm.extensionRegistry.allMenuCommands.firstWhere((e) => e.key.contains('Kernel Sample/Place Barrels')).value;
      await rec.hold(const Duration(seconds: 2));

      // Its command asks first, through a dialog the process opens.
      await tester.runAsync(() async {
        unawaited(Future<void>.sync(() => command.execute(null)));
        await waitFor(() => PluginDialogQueue.shared.current != null, reason: 'the confirm dialog');
      });
      await settle(tester, frames: 10);
      expect(find.text('Place barrels?'), findsOneWidget);
      await rec.hold(const Duration(seconds: 2));
      await shot('confirm dialog from the plugin process');
      await tester.tap(find.byKey(const ValueKey('plugin_dialog_action_confirm')));
      for (var i = 0; i < 100 && vm.actors.length < actorsBefore + 3; i++) {
        await rec.hold(const Duration(milliseconds: 100));
      }
      expect(vm.actors.length, actorsBefore + 3, reason: 'placed through the level proxy');
      final copies = vm.actors.where((a) => a.name.startsWith('KernelBarrel')).toList();
      expect(copies, hasLength(3));
      expect(copies.every((a) => a.meshData != null), isTrue, reason: 'the copies draw the barrel model');
      vm.frameLevelBounds();
      await rec.hold(const Duration(seconds: 2));
      await shot('actors placed by the kernel plugin');

      // Disabled: gone, while the viewport keeps rendering.
      await tester.runAsync(() async {
        await vm.enablePlugin(kKernelSampleName, false);
        await waitForStatus(s, PluginProcessStatus.stopped);
      });
      await settle(tester, frames: 10);
      expect(vm.pluginProcesses.supervisorOf(kKernelSampleName), isNull);
      expect(vm.extensionRegistry.allPanels.where((panel) => panel.id == 'kernel_sample.panel'), isEmpty);
      expect(vm.extensionRegistry.allMenuCommands.where((e) => e.key.contains('Kernel Sample')), isEmpty);
      expect(vm.pluginRestartRequired, isFalse);
      vm.frameLevelBounds();
      await rec.hold(const Duration(seconds: 2));
      await shot('disabled');
      rec.save(name, usedAssets: used);
    } finally {
      try {
        temp.deleteSync(recursive: true);
      } catch (_) {}
    }
  });
}
