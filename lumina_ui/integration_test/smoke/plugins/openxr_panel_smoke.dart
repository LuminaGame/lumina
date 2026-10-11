import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/core/editor_panels/editor_panel_docking.dart';
import 'package:lumina_ui/ui/core/services/user_plugin_dir.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../../test/ui/editor_panels/openxr_plugin_fixture.dart';
import '../../../test/ui/plugin_process/plugin_process_harness.dart' show waitFor, waitForStatus;

/// The OpenXR plugin's panel, an editor panel Widget Blueprint it ships as
/// content, run by the editor's Blueprint VM and driven by the plugin's real
/// process (simulated OpenXR runtime), docked right while a level of real
/// models renders: opened from Plugins ▸ OpenXR ▸ OpenXR Panel, the tracking
/// origin and stereo mode changed in its selects, the VR preview started
/// from the panel and stopped from the status bar menu.
void openxrPanelSmoke(IntegrationTestWidgetsFlutterBinding binding, Future<void> Function(WidgetTester, {int frames}) settle) {
  const name = 'Plugin Isolation Smoke: OpenXR panel from an editor panel widget blueprint';
  testWidgets(name, (tester) async {
    const models = ['Props/Barrels/empty_barrel.glb', 'Props/AC_units/ac_unit_a_300x300.glb', 'Props/Barrels/fuel_barrel_red.glb'];
    final checkout = openxrCheckout();
    expect(checkout, isNotNull, reason: openxrSkipReason());
    tester.view.physicalSize = const Size(1920, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final temp = Directory.systemTemp.createTempSync('openxr_smoke_');
    final previousUserDir = UserPluginDir.override;
    final previousDataDir = LuminaDataDir.override;
    UserPluginDir.override = Directory('${temp.path}/user_plugins')..createSync();
    LuminaDataDir.override = Directory('${temp.path}/lumina_data')..createSync();
    final link = installOpenxrUserPlugin(checkout!);
    addTearDown(() {
      if (link.existsSync()) link.deleteSync();
      UserPluginDir.override = previousUserDir;
      LuminaDataDir.override = previousDataDir;
    });
    try {
      final projectsDir = Directory('${temp.path}/projects')..createSync();
      final pDir = Directory('${projectsDir.path}/OpenXrSmoke')..createSync();
      const project = LuminaProject(
        projectName: 'OpenXrSmoke',
        activeLevel: 'contents/levels/L_Main.lmas',
        enabledPlugins: [kOpenxrPlugin],
        settings: EngineScalabilitySettings(targetFps: 60),
      );
      File('${pDir.path}/OpenXrSmoke.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
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
        await tester.runAsync(() => vm.spawnActorFromAsset(meshes[i], location: [i * 250.0 - 250.0, 0.0, 0.0]));
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

      // The plugin's real process, then its editor panels.
      final processes = attachOpenxrProcess(vm, checkout);
      addTearDown(() => tester.runAsync(processes.shutdownAll));
      await tester.runAsync(() async {
        await vm.pluginsScanned;
        await processes.startAll();
        await waitForStatus(processes.supervisorOf(kOpenxrPlugin)!, PluginProcessStatus.running);
        await vm.startEditorPanels();
        await waitFor(() => vm.editorPanels.panel(kOpenxrPanelId) != null, reason: 'the OpenXR panel');
      });
      expect(vm.editorPanels.panel(kOpenxrPanelId)!.errors, isEmpty);

      final boundaryKey = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: boundaryKey,
        child: ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)),
      ));
      await settle(tester, frames: 30);
      vm.frameLevelBounds();
      await settle(tester, frames: 20);
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      Future<void> shot(String suffix) async {
        final png = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
        SmokeArtifacts.saveScreenshot('$name ($suffix)', png, usedAssets: used);
      }

      Map<String, Object?> state(String element) => vm.editorPanels.instancesOf(kOpenxrPanelId).single.element(element) ?? const {};
      Future<void> until(bool Function() ok, String reason) async {
        for (var i = 0; i < 150 && !ok(); i++) {
          await rec.hold(const Duration(milliseconds: 100));
        }
        expect(ok(), isTrue, reason: reason);
      }

      int meshActors() => vm.actors.where((a) => a.meshAssetPath != null && a.meshAssetPath!.isNotEmpty).length;
      final modelsInLevel = meshActors();
      expect(modelsInLevel, greaterThanOrEqualTo(used.length));
      await rec.hold(const Duration(seconds: 2));

      // Plugins ▸ OpenXR ▸ OpenXR Panel.
      final open = vm.extensionRegistry.allMenuCommands.firstWhere((e) => e.key == 'Plugins/OpenXR/OpenXR Panel').value;
      await open.execute(null);
      await settle(tester, frames: 10);
      final view = find.byKey(ValueKey('editor_panel_view_$kOpenxrPanelId'));
      expect(view, findsOneWidget);
      expect(find.ancestor(of: view, matching: find.byKey(const ValueKey('right_dock'))), findsOneWidget);
      expect(vm.panelsController.isVisible(EditorPanelDocking.descriptorId(kOpenxrPanelId)), isTrue);
      await until(() => '${state('RuntimeName')['text']}'.startsWith('Runtime: '), 'the status from the process');
      expect(find.descendant(of: view, matching: find.text('Start VR Preview')), findsOneWidget);
      await rec.hold(const Duration(seconds: 2));
      await shot('opened from the Plugins menu');

      // Tracking origin and stereo mode through the panel's selects.
      Future<void> pick(String current, String next) async {
        await tester.tap(find.descendant(of: view, matching: find.text(current)));
        await settle(tester, frames: 10);
        await tester.tap(find.text(next).last);
        await settle(tester, frames: 10);
      }

      await pick('Floor level (standing)', 'Stage (room scale)');
      await until(() => state('TrackingOrigin')['selectedOption'] == 'Stage (room scale)', 'the stage origin');
      await pick('Instanced', 'Multiview');
      await until(() => state('StereoMode')['selectedOption'] == 'Multiview', 'multiview');
      final picked = await tester.runAsync(() => processes.supervisorOf(kOpenxrPlugin)!.call('status')) as Map;
      expect((picked['tracking_origin'], picked['stereo_mode']), ('stage', 'multiview'));
      await rec.hold(const Duration(seconds: 2));
      await shot('tracking origin and stereo mode changed');

      // Start the VR preview from the panel.
      await tester.tap(find.descendant(of: view, matching: find.text('Start VR Preview')));
      await until(() => state('TogglePreview')['label'] == 'Stop VR Preview', 'the preview to start');
      await settle(tester, frames: 5);
      expect(state('TogglePreview')['style'], 'destructive');
      expect(state('SessionState')['text'], 'Session: focused (preview running)');
      expect(find.descendant(of: view, matching: find.text('Stop VR Preview')), findsOneWidget);
      vm.frameLevelBounds();
      await rec.hold(const Duration(seconds: 2));
      await shot('VR preview running');

      // Stop it from the status bar button's menu: the open panel follows.
      final slot = find.byWidgetPredicate((w) {
        final key = w.key;
        return key is ValueKey<String> &&
            key.value.startsWith('slot_button_') &&
            !key.value.startsWith('slot_button_frame_') &&
            key.value.endsWith('openxr.status_badge');
      });
      expect(slot, findsOneWidget);
      await tester.tap(find.descendant(of: slot, matching: find.byType(GhostButton)));
      await settle(tester, frames: 10);
      await rec.hold(const Duration(seconds: 1));
      await tester.tap(find.byKey(const ValueKey('slot_menu_tools.lumina_plugin_openxr.statusMenu.togglePreview')));
      await until(() => state('TogglePreview')['label'] == 'Start VR Preview', 'the preview to stop');
      await settle(tester, frames: 5);
      expect(state('TogglePreview')['style'], 'primary');
      expect(state('SessionState')['text'], isNot(contains('preview running')));
      expect(find.descendant(of: view, matching: find.text('Start VR Preview')), findsOneWidget);
      vm.frameLevelBounds();
      await rec.hold(const Duration(seconds: 2));
      await shot('VR preview stopped from the status bar');

      // Expand About.
      await tester.tap(find.descendant(of: view, matching: find.text('About OpenXR Support')));
      await settle(tester, frames: 10);
      await rec.hold(const Duration(seconds: 2));
      expect(meshActors(), modelsInLevel, reason: 'the level is untouched');
      rec.save(name, usedAssets: used);
    } finally {
      try {
        if (link.existsSync()) link.deleteSync();
        temp.deleteSync(recursive: true);
      } catch (_) {}
    }
  });
}
