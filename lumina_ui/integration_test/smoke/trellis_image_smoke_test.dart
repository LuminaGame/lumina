// Trellis is an installed optional plugin supplied through local overrides.
// ignore_for_file: depend_on_referenced_packages
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:lumina_editor_api/testing.dart';
import 'package:lumina_editor_data/lumina_editor.dart' show EngineLoggerService, LuminaUmgViewport, LuminaUmgViewportState;
import 'package:lumina_plugin_trellis_image/lumina_plugin_trellis_image.dart';
import 'package:lumina_plugin_trellis_image/src/shell/image_client.dart';
import 'package:lumina_plugin_trellis_image/src/ui/image_workspace.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/core/plugin_extension_registry.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme_access.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:trellis_plugin/src/process/trellis_process.dart';

/// Trellis Image Studio inside the editor's plugin context: the generated
/// mesh is reviewed in the editor's 3D viewport (Lit / Unlit / Wireframe),
/// simplified and saved; nothing reaches the project before Save.
/// `LUMINA_TRELLIS_PLUGIN` names the local Trellis plugin folder;
/// `LUMINA_TRELLIS_OUTPUT` a real Trellis output GLB (the review scenario),
/// `LUMINA_QWEN_IMAGE_ROOT` the Qwen runtime (the generation scenario).
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> frames(WidgetTester tester, int n) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
    }
  }

  Future<void> waitFor(WidgetTester tester, bool Function() done, {Duration timeout = const Duration(minutes: 5)}) async {
    final end = DateTime.now().add(timeout);
    while (!done()) {
      if (DateTime.now().isAfter(end)) fail('timed out');
      await frames(tester, 2);
    }
  }

  Future<Set<String>> files(String dir) async {
    final out = <String>{};
    await for (final e in Directory(dir).list(recursive: true)) {
      if (e is File) out.add(e.path.substring(dir.length + 1).replaceAll(r'\', '/'));
    }
    return out;
  }

  Widget app(GlobalKey boundary, ImageClient client, PluginExtensionRegistry host) => RepaintBoundary(
        key: boundary,
        child: ShadcnApp(
          theme: luminaEditorTheme(),
          home: Scaffold(
            child: ImageWorkspace(client: client, host: host, editorTheme: const HostEditorThemeAccess()),
          ),
        ),
      );

  /// Waits until the viewport draws the mesh's triangle edges.
  Future<void> waitForWireframe(WidgetTester tester) => waitFor(tester, () {
        final c = tester.state<LuminaUmgViewportState>(find.byType(LuminaUmgViewport)).controller;
        return c != null && c.runtime.viewMode == 'wireframe' && c.runtime.wireframeNodeIds.isNotEmpty;
      }, timeout: const Duration(minutes: 2));

  /// Turns the camera with a virtual left drag over the viewport.
  Future<void> orbit(WidgetTester tester, double dx) async {
    final viewport = find.byKey(const Key('trellis_preview_viewport'));
    final centre = tester.getCenter(viewport);
    final g = await tester.startGesture(centre, kind: PointerDeviceKind.mouse, buttons: kPrimaryMouseButton);
    for (var i = 0; i < 12; i++) {
      await g.moveBy(Offset(dx / 12, 0));
      await frames(tester, 1);
    }
    await g.up();
  }

  const review = 'Trellis Image Studio reviews, simplifies to 25% and saves a real Trellis mesh';
  testWidgets(review, (tester) async {
    final trellisDir = Platform.environment['LUMINA_TRELLIS_PLUGIN'];
    final output = Platform.environment['LUMINA_TRELLIS_OUTPUT'];
    if (trellisDir == null || output == null || !File(output).existsSync()) {
      markTestSkipped('Set LUMINA_TRELLIS_PLUGIN and LUMINA_TRELLIS_OUTPUT (a real Trellis output GLB).');
      return;
    }
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final temp = Directory.systemTemp.createTempSync('trellis_smoke_');
    // The output as the Trellis process leaves it in its temp folder.
    final outDir = Directory('${temp.path}/trellis_out_review')..createSync();
    final generated = '${outDir.path}/trellis_mesh.glb';
    File(output).copySync(generated);

    late LoopbackHost imageHost, trellisHost;
    late Future<int> imageExit, trellisExit;
    late ImageClient client;
    await tester.runAsync(() async {
      imageHost = await LoopbackHost.start(settings: const {});
      trellisHost = await LoopbackHost.start(settings: const {}, pluginDir: trellisDir);
      imageExit = runPluginProcessMain(imageHost.launch('lumina_plugin_trellis_image'), TrellisImageProcess());
      trellisExit = runPluginProcessMain(
        trellisHost.launch('trellis_plugin'),
        TrellisProcess(restoreOnStart: false, outputRoot: temp),
      );
      await imageHost.contributions;
      await trellisHost.contributions;
      client = ImageClient(imageHost.channel, trellis: trellisHost.channel);
      await client.call('image.state');
    });
    final host = PluginExtensionRegistry(logger: EngineLoggerService());
    addTearDown(() async {
      client.dispose();
      await imageHost.call(PluginMethods.shutdown);
      await trellisHost.call(PluginMethods.shutdown);
      await imageExit;
      await trellisExit;
      await imageHost.close();
      await trellisHost.close();
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });
    final projectDir = trellisHost.project!.dir;
    final projectBefore = (await tester.runAsync(() => files(projectDir)))!;

    final boundary = GlobalKey();
    await tester.pumpWidget(app(boundary, client, host));
    await frames(tester, 3);
    final job = client.job!;
    await tester.runAsync(() => job.review(generated));
    await waitFor(tester, () => find.byKey(const Key('trellis_preview_viewport')).evaluate().isNotEmpty);
    final full = job.preview!.stats.triangles;
    final recorder = SmokeRecorder(tester, boundary: find.byKey(boundary));
    await frames(tester, 120); // the 1 M-vertex mesh loads into the viewport

    // Lit, turned with a virtual drag; Unlit; Wireframe of the full mesh.
    await recorder.hold(const Duration(milliseconds: 1200));
    await orbit(tester, 260);
    await recorder.hold(const Duration(milliseconds: 1200));
    SmokeArtifacts.saveScreenshot('$review (lit)', await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundary)));
    await tester.tap(find.byKey(const ValueKey('trellis_preview_mode_unlit')));
    await recorder.hold(const Duration(milliseconds: 1500));
    SmokeArtifacts.saveScreenshot('$review (unlit)', await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundary)));
    await tester.tap(find.byKey(const ValueKey('trellis_preview_mode_wireframe')));
    await waitForWireframe(tester);
    await frames(tester, 10);
    await recorder.hold(const Duration(milliseconds: 1500));
    await tester.tap(find.byKey(const ValueKey('trellis_preview_mode_lit')));
    await recorder.hold(const Duration(milliseconds: 800));

    // Simplify to 25%.
    await tester.tap(find.byKey(const ValueKey('trellis_simplify_preset_25')));
    await frames(tester, 2);
    await tester.tap(find.byKey(const Key('trellis_simplify_apply')));
    await waitFor(tester, () => job.preview?.simplified != null && !job.working);
    final simplified = job.preview!.simplified!;
    expect((simplified.after.triangles - full * 0.25).abs(), lessThanOrEqualTo(full * 0.25 * 0.05));
    expect((await tester.runAsync(() => files(projectDir)))!, projectBefore, reason: 'nothing is saved before Save');
    await frames(tester, 90);
    await recorder.hold(const Duration(milliseconds: 1200));
    await orbit(tester, -260);
    await recorder.hold(const Duration(milliseconds: 1000));
    await tester.tap(find.byKey(const ValueKey('trellis_preview_mode_wireframe')));
    await waitForWireframe(tester);
    await frames(tester, 10);
    await recorder.hold(const Duration(milliseconds: 1500));
    SmokeArtifacts.saveScreenshot('$review (simplified wireframe)',
        await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundary)));
    await tester.tap(find.byKey(const ValueKey('trellis_preview_mode_lit')));
    await recorder.hold(const Duration(milliseconds: 1000));

    // Save to a project folder.
    await tester.enterText(find.byKey(const Key('trellis_save_name')), 'SM_Trellis_Review');
    await tester.enterText(find.byKey(const Key('trellis_save_folder')), 'contents/meshes/generated');
    await tester.tap(find.byKey(const Key('trellis_save')));
    await waitFor(tester, () => job.preview?.savedAssetPath != null && !job.working);
    await recorder.hold(const Duration(milliseconds: 1500));
    SmokeArtifacts.saveScreenshot(review, await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundary)));
    recorder.save(review);
    final added = (await tester.runAsync(() => files(projectDir)))!.difference(projectBefore);
    expect(added, {
      'contents/meshes/generated/SM_Trellis_Review.glb',
      'contents/meshes/generated/SM_Trellis_Review.entity.glb',
      'contents/meshes/generated/SM_Trellis_Review.lmas',
    });
    await tester.pumpWidget(const SizedBox());
    await frames(tester, 3);
  }, timeout: const Timeout(Duration(minutes: 20)));

  const generation = 'Qwen image approval generates a real Trellis mesh that is saved only on Save';
  testWidgets(generation, (tester) async {
    final root = Platform.environment['LUMINA_QWEN_IMAGE_ROOT'];
    final trellisDir = Platform.environment['LUMINA_TRELLIS_PLUGIN'];
    if (root == null || trellisDir == null) {
      markTestSkipped('Set real Qwen runtime and Trellis plugin paths.');
      return;
    }
    final modelsDir = '${Platform.environment['LOCALAPPDATA']}/Lumina/trellis_models';
    final imageHost = await LoopbackHost.start(settings: const {});
    final trellisHost = await LoopbackHost.start(settings: const {}, pluginDir: trellisDir);
    final imageExit = runPluginProcessMain(imageHost.launch('lumina_plugin_trellis_image'), TrellisImageProcess());
    final trellisExit = runPluginProcessMain(trellisHost.launch('trellis_plugin'), TrellisProcess(restoreOnStart: false));
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
      await client.call('image.configure', {'root': root, 'binary': '$root/runtime/sd-cli.exe', 'gpu': '0'});
      await client.call('image.generate', {
        'prompt': 'Product photo of a red ceramic teapot, white background, no text.',
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
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final boundary = GlobalKey();
    final host = PluginExtensionRegistry(logger: EngineLoggerService());
    final projectDir = trellisHost.project!.dir;
    final projectBefore = (await tester.runAsync(() => files(projectDir)))!;
    await tester.pumpWidget(app(boundary, client, host));
    await tester.pump();
    final recorder = SmokeRecorder(tester, boundary: find.byKey(boundary));
    await recorder.hold(const Duration(milliseconds: 1500));
    await tester.tap(find.byKey(const Key('qwen_approve_3d')));
    await tester.runAsync(() async {
      while (client.busy) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
    });
    await frames(tester, 60);
    expect(client.error, isNull);
    expect(client.job!.preview, isNotNull, reason: 'the generated mesh opens for review');
    expect((await tester.runAsync(() => files(projectDir)))!, projectBefore, reason: 'nothing is saved before Save');
    await recorder.hold(const Duration(milliseconds: 1500));
    await orbit(tester, 200);
    await recorder.hold(const Duration(milliseconds: 1500));
    await tester.tap(find.byKey(const ValueKey('trellis_preview_mode_wireframe')));
    await frames(tester, 30);
    await recorder.hold(const Duration(milliseconds: 1500));
    await tester.tap(find.byKey(const ValueKey('trellis_preview_mode_lit')));
    await tester.tap(find.byKey(const Key('trellis_save')));
    await waitFor(tester, () => client.job!.preview?.savedAssetPath != null);
    await tester.runAsync(() => client.call('image.state'));
    final result = client.state['result'] as Map;
    expect(await File('$projectDir/${result['asset_path']}').exists(), isTrue);
    await recorder.hold(const Duration(milliseconds: 1500));
    for (var i = 0; i < 3; i++) {
      await orbit(tester, 150);
      await recorder.hold(const Duration(milliseconds: 900));
    }
    SmokeArtifacts.saveScreenshot(generation, await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundary)));
    recorder.save(generation);
    await tester.pumpWidget(const SizedBox());
  }, timeout: const Timeout(Duration(minutes: 20)));
}
