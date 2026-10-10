import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:lumina_plugin_miniai/src/llm/llm_types.dart';
import 'package:lumina_plugin_miniai/src/local/vllm_manager.dart';
import 'package:lumina_plugin_miniai/src/settings/provider_settings.dart';
import 'package:lumina_plugin_miniai/src/vllm_section.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/core/plugin_3d_viewport_container.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const name =
      'Mini AI connects to native Gemma and streams a response beside a real GPU viewport';
  testWidgets(name, (tester) async {
    final endpoint = Platform.environment['LUMINA_VLLM_TEST_URL'];
    if (endpoint == null) {
      markTestSkipped(
        'Set LUMINA_VLLM_TEST_URL to a real Gemma vllm.cpp server.',
      );
      return;
    }
    const models = [
      'Props/Barrels/fuel_barrel_red.glb',
      'Props/AC_units/ac_unit_a_300x300.glb',
    ];
    final assets = SmokeArtifacts.testAssetsDir.path;
    for (final model in models) {
      if (!File('$assets/$model').existsSync()) {
        markTestSkipped('Missing test-assets/$model');
        return;
      }
    }
    final root = Directory.systemTemp.createTempSync('miniai_vllm_smoke_');
    addTearDown(() => root.deleteSync(recursive: true));
    final settings = ProviderSettings(PluginStorage(userDir: root));
    final manager = VllmManager(PluginStorage(userDir: root), settings)
      ..endpoint = endpoint;
    addTearDown(settings.dispose);
    addTearDown(manager.dispose);
    final mesh = ValueNotifier('$assets/${models.first}');
    final response = ValueNotifier('');
    addTearDown(mesh.dispose);
    addTearDown(response.dispose);
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final boundary = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: ShadcnApp(
          theme: luminaEditorTheme(),
          home: Scaffold(
            child: ResizablePanel.horizontal(
              children: [
                ResizablePane(
                  initialSize: 620,
                  minSize: 420,
                  child: Container(
                    color: EditorColors.sidebar,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          VllmSection(manager: manager),
                          const Gap(12),
                          ValueListenableBuilder<String>(
                            valueListenable: response,
                            builder: (_, value, _) => Text(value),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                ResizablePane.flex(
                  minSize: 300,
                  child: ValueListenableBuilder<String>(
                    valueListenable: mesh,
                    builder: (_, value, _) => Plugin3DViewportContainer(
                      options: Plugin3DViewportOptions(
                        meshPath: value,
                        title: 'Real scene props',
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
    for (var i = 0; i < 50; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 16)),
      );
    }
    final recorder = SmokeRecorder(tester, boundary: find.byKey(boundary));
    await recorder.hold(const Duration(seconds: 1));
    await tester.tap(find.byKey(const ValueKey('miniai_vllm_connect')));
    await tester.runAsync(() async {
      for (var i = 0; i < 100 && !manager.ready; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    });
    expect(manager.ready, isTrue, reason: manager.status);
    expect(settings.selected?.model, VllmManager.modelId);
    await recorder.hold(const Duration(seconds: 2));
    await tester.runAsync(() async {
      final provider = settings.providerFor(settings.selected!);
      await for (final event in provider.stream(
        const LlmRequest(
          model: VllmManager.modelId,
          messages: [LlmMessage.user('Reply with the word READY.')],
          temperature: 0,
          maxTokens: 8,
        ),
        cancel: CancelToken(),
      )) {
        if (event is LlmError) fail(event.message);
        if (event is TextDelta) response.value += event.text;
      }
    });
    expect(response.value, contains('READY'));
    for (var i = 0; i < 6; i++) {
      mesh.value = '$assets/${models[i % models.length]}';
      await recorder.hold(const Duration(milliseconds: 1500));
    }
    SmokeArtifacts.saveScreenshot(
      name,
      await SmokeArtifacts.captureIntegrationPng(
        binding,
        tester,
        boundary: find.byKey(boundary),
      ),
      usedAssets: models,
    );
    recorder.save(name, usedAssets: models);
    await tester.pumpWidget(const SizedBox());
  }, timeout: const Timeout(Duration(minutes: 5)));
}
