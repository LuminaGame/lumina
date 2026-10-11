// Trellis is an installed optional plugin supplied through local overrides.
// ignore_for_file: depend_on_referenced_packages
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:lumina_editor_api/testing.dart';
import 'package:lumina_plugin_trellis_image/lumina_plugin_trellis_image.dart';
import 'package:lumina_plugin_trellis_image/src/shell/image_client.dart';
import 'package:lumina_plugin_trellis_image/src/ui/image_workspace.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/core/plugin_3d_viewport_container.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:trellis_plugin/src/process/trellis_process.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const name = 'Qwen image approval generates and saves a real Trellis mesh';
  testWidgets(name, (tester) async {
    final root = Platform.environment['LUMINA_QWEN_IMAGE_ROOT'];
    final trellisDir = Platform.environment['LUMINA_TRELLIS_PLUGIN'];
    if (root == null || trellisDir == null) {
      markTestSkipped('Set real Qwen runtime and Trellis plugin paths.');
      return;
    }
    final modelsDir =
        '${Platform.environment['LOCALAPPDATA']}/Lumina/trellis_models';
    const fixtures = [
      'Props/Barrels/fuel_barrel_red.glb',
      'Props/AC_units/ac_unit_a_300x300.glb',
    ];
    final assets = SmokeArtifacts.testAssetsDir.path;
    for (final path in fixtures) {
      expect(await File('$assets/$path').exists(), isTrue);
    }
    final imageHost = await LoopbackHost.start(settings: const {});
    final trellisHost = await LoopbackHost.start(
      settings: const {},
      pluginDir: trellisDir,
    );
    final imageExit = runPluginProcessMain(
      imageHost.launch('lumina_plugin_trellis_image'),
      TrellisImageProcess(),
    );
    final trellisExit = runPluginProcessMain(
      trellisHost.launch('trellis_plugin'),
      TrellisProcess(restoreOnStart: false),
    );
    await imageHost.contributions;
    await trellisHost.contributions;
    await trellisHost.channel.call('trellis.config.set', {
      'config': {
        'models_directory': modelsDir,
        'executable_path': '$trellisDir/bin/windows-x64/trellis2_cli.exe',
        'default_quality': 'coarse',
        'default_background_mode': 'white',
        'default_steps': 4,
        'default_texture_enabled': false,
      },
    });
    final client = ImageClient(imageHost.channel, trellis: trellisHost.channel);
    addTearDown(() async {
      client.dispose();
      await imageHost.call(PluginMethods.shutdown);
      await trellisHost.call(PluginMethods.shutdown);
      await imageExit;
      await trellisExit;
      await imageHost.close();
      await trellisHost.close();
    });
    await tester.runAsync(() async {
      await client.call('image.configure', {
        'root': root,
        'binary': '$root/runtime/sd-cli.exe',
        'gpu': '0',
      });
      await client.call('image.generate', {
        'prompt':
            'Product photo of a red ceramic teapot, white background, no text.',
        'width': 512,
        'height': 512,
        'steps': 20,
        'seed': 42,
      });
      while (client.busy) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
    });
    expect(client.error, isNull);
    expect(client.draft, isNotNull);
    expect(
      (await trellisHost.channel.call('trellis.state') as Map)['result'],
      isNull,
    );
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final boundary = GlobalKey();
    final mesh = ValueNotifier('$assets/${fixtures.first}');
    addTearDown(mesh.dispose);
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: ShadcnApp(
          theme: luminaEditorTheme(),
          home: Scaffold(
            child: ResizablePanel.horizontal(
              children: [
                ResizablePane(
                  initialSize: 780,
                  minSize: 600,
                  child: ImageWorkspace(client: client),
                ),
                ResizablePane.flex(
                  minSize: 300,
                  child: ValueListenableBuilder<String>(
                    valueListenable: mesh,
                    builder: (_, value, _) => Plugin3DViewportContainer(
                      options: Plugin3DViewportOptions(
                        meshPath: value,
                        title: 'Generated mesh and real props',
                        cameraDistance: 400,
                        showGizmo: false,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('qwen_approve_3d')));
    await tester.tap(find.byKey(const Key('qwen_approve_3d')));
    await tester.runAsync(() async {
      while (client.busy) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
      await client.call('image.state');
    });
    expect(client.error, isNull);
    final result = client.state['result'] as Map;
    expect(
      await File(
        '${trellisHost.project!.dir}/${result['asset_path']}',
      ).exists(),
      isTrue,
    );
    expect(
      await File(result['glb_path'] as String).length(),
      greaterThan(1000),
    );
    mesh.value = result['glb_path'] as String;
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 16)),
      );
    }
    final recorder = SmokeRecorder(tester, boundary: find.byKey(boundary));
    await recorder.hold(const Duration(milliseconds: 1500));
    SmokeArtifacts.saveScreenshot(
      name,
      await SmokeArtifacts.captureIntegrationPng(
        binding,
        tester,
        boundary: find.byKey(boundary),
      ),
      usedAssets: fixtures,
    );
    for (var i = 0; i < 8; i++) {
      mesh.value = i % 3 == 0
          ? result['glb_path'] as String
          : '$assets/${fixtures[i % 2]}';
      await recorder.hold(const Duration(milliseconds: 1500));
    }
    recorder.save(name, usedAssets: fixtures);
    await tester.pumpWidget(const SizedBox());
  }, timeout: const Timeout(Duration(minutes: 20)));
}
