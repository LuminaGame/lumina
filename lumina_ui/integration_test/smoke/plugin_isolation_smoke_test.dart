import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/core/services/plugin_process/plugin_supervisor_timings.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/core/widgets/plugin_view/plugin_view_scope.dart' show pluginControlKey;
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

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
}
