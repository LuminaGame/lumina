import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/services/editor_graphics_preferences.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/graphics_device_preferences_page.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const name = 'Editor graphics preferences persist the real Vulkan device';
  const assets = [
    'Props/Barrels/fuel_barrel_red.glb',
    'Props/AC_units/aircon_small.glb',
  ];
  testWidgets(name, (tester) async {
    final root = Directory.systemTemp.createTempSync('graphics_smoke_');
    final config = Directory('${root.path}/config')..createSync();
    final projectDir = Directory('${root.path}/GraphicsSmoke')..createSync();
    const project = LuminaProject(
      projectName: 'GraphicsSmoke',
      activeLevel: 'contents/levels/L_Main.lmas',
    );
    File(
      '${projectDir.path}/GraphicsSmoke.lmproject',
    ).writeAsStringSync(jsonEncode(project.toMap()));
    final store = EditorGraphicsPreferences(
      configDir: config,
      environment: const {},
    );
    final gpu = store.devices.firstWhere(
      (device) => device.name.contains('RTX PRO 2000'),
    );
    store.select(gpu.name);
    final vm = EditorViewModel(
      initialProject: project,
      projectLocation: root.path,
    );
    try {
      await tester.runAsync(() => vm.ensureDefaultLevelAssets());
      for (var i = 0; i < assets.length; i++) {
        final source = File(
          '${SmokeArtifacts.testAssetsDir.path}/${assets[i]}',
        );
        expect(source.existsSync(), isTrue);
        await tester.runAsync(
          () => vm.processImportPipeline(sourceFilePath: source.path),
        );
        final stem = source.uri.pathSegments.last.replaceAll('.glb', '');
        final imported = vm.realAssets.firstWhere(
          (asset) => asset.fileName.startsWith(stem),
        );
        await tester.runAsync(
          () =>
              vm.spawnActorFromAsset(imported, location: [i * 180.0, 0.0, 0.0]),
        );
      }
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: ShadcnApp(
            theme: luminaEditorTheme(),
            home: Row(
              children: [
                Expanded(child: MainEditorView(viewModel: vm)),
                SizedBox(
                  width: 440,
                  child: Scaffold(
                    child: GraphicsDevicePreferencesPage(
                      configDir: config,
                      environment: const {},
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 16)),
        );
      }
      expect(LuminaGraphicsDevices.inUse.value, contains('RTX PRO 2000'));
      final recorder = SmokeRecorder(tester, boundary: find.byKey(boundary));
      for (var i = 0; i < 6; i++) {
        await tester.tap(
          find.byKey(const ValueKey('editor_prefs_graphics_device')),
        );
        await tester.pump(const Duration(milliseconds: 200));
        await recorder.hold(const Duration(seconds: 1));
        await tester.tap(find.text(i.isEven ? 'Automatic' : gpu.label).last);
        await tester.pump(const Duration(milliseconds: 200));
        await recorder.hold(const Duration(seconds: 1));
      }
      expect(EditorGraphicsPreferences(configDir: config).selected, gpu.name);
      expect(LuminaGraphicsDevices.inUse.value, contains('RTX PRO 2000'));
      SmokeArtifacts.saveScreenshot(
        name,
        await SmokeArtifacts.captureIntegrationPng(
          binding,
          tester,
          boundary: find.byKey(boundary),
        ),
        usedAssets: assets,
      );
      recorder.save(name, usedAssets: assets);
      await tester.pumpWidget(const SizedBox.shrink());
    } finally {
      vm.dispose();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      root.deleteSync(recursive: true);
    }
  });
}
