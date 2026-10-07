import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../test/helpers/mcp_test_client.dart';
import '../../test/helpers/scaffold_game_project.dart';

/// Saving a texture that an assigned material draws updates what the editor
/// shows, without reassigning the material: on a real Third Person project an
/// MCP client imports the road sign (its material's base colour a rusty sign
/// atlas) and the black fuel barrel, compiles the sign material and assigns it
/// to a placed barrel. Turning the atlas texture's sRGB off in the Texture
/// editor and saving brightens the barrel in the level viewport (its colour
/// data is now read as linear); a Blueprint whose Static Mesh component draws
/// the same material shows the change in its 3D Viewport when sRGB is turned
/// back on and saved.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const scenario = 'Texture save refresh: saving a texture updates the level actor and the Blueprint preview drawing its material';
  testWidgets(scenario, (tester) async {
    final sign = File('${SmokeArtifacts.testAssetsDir.path}/Props/roadsigns/roadsign9.glb');
    final barrel = File('${SmokeArtifacts.testAssetsDir.path}/Props/Barrels/fuel_barrel_black.glb');
    expect(sign.existsSync() && barrel.existsSync(), isTrue, reason: 'test-assets must hold the road sign and the black barrel');
    final usedAssets = [sign.path, barrel.path];

    final root = Directory.systemTemp.createTempSync('lumina_smoke_texsave_');
    const name = 'smoke_texture_save';
    final projectDir = (await tester.runAsync(() => scaffoldGameProject(root, name: name, widgetLibrary: 'flutter')))!;
    final project = LuminaProject.fromMap(
        Map<String, dynamic>.from(jsonDecode(File('$projectDir/$name.lmproject').readAsStringSync()) as Map));
    final vm = EditorViewModel(initialProject: project, projectLocation: root.path);
    await tester.runAsync(vm.ensureDefaultLevelAssets);
    await tester.runAsync(() => vm.processImportPipeline(sourceFilePath: sign.path));
    await tester.runAsync(() => vm.processImportPipeline(sourceFilePath: barrel.path));
    final barrelMesh = vm.realAssets.firstWhere((a) => a.type == AssetType.filamesh && a.fileName.contains('fuel_barrel_black'));
    final signMaterial = vm.realAssets.firstWhere((a) => a.type == AssetType.filamat && a.relativePath.toLowerCase().contains('roadsign'));
    final signAsset = LuminaAsset.fromBytes(File(signMaterial.lmasPath!).readAsBytesSync());
    final atlas = signAsset.references.firstWhere((r) => r.slotName == 'baseColorMap').assetPath.replaceAll(r'\', '/');
    final atlasRelative = atlas.contains('/contents/') ? atlas.substring(atlas.indexOf('/contents/') + 1) : atlas;

    final server = vm.mcpServer;
    expect(await tester.runAsync(() => server.start(port: 0)), isTrue);
    final client = McpTestClient(server.url!, server.token);

    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final boundaryKey = GlobalKey();
    try {
      await tester.pumpWidget(RepaintBoundary(
        key: boundaryKey,
        child: ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)),
      ));
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
      }
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));

      /// A call the editor answers while the recorder keeps pumping frames.
      Future<McpToolReply> call(String tool, [Map<String, Object?> args = const {}]) async {
        McpToolReply? reply;
        Object? error;
        unawaited(client.callTool(tool, args).then((r) => reply = r, onError: (Object e) => error = e));
        while (reply == null && error == null) {
          await rec.hold(const Duration(milliseconds: 66));
        }
        if (error != null) throw error!;
        return reply!;
      }

      Future<McpToolReply> ok(String tool, [Map<String, Object?> args = const {}]) async {
        final reply = await call(tool, args);
        expect(reply.isError, isFalse, reason: '$tool: ${reply.text}');
        return reply;
      }

      img.Image imageOf(McpToolReply reply, String artifact) {
        final png = Uint8List.fromList(base64Decode(reply.content.firstWhere((c) => c['type'] == 'image')['data'] as String));
        SmokeArtifacts.saveScreenshot(artifact, png, usedAssets: usedAssets);
        return img.decodePng(png)!;
      }

      /// The pixels that differ between [a] and [b] (same size), and their
      /// mean luminance in each.
      ({int changed, double lumA, double lumB}) change(img.Image a, img.Image b) {
        var n = 0;
        var la = 0.0;
        var lb = 0.0;
        for (var y = 0; y < math.min(a.height, b.height); y += 2) {
          for (var x = 0; x < math.min(a.width, b.width); x += 2) {
            final p = a.getPixel(x, y);
            final q = b.getPixel(x, y);
            if ((p.r - q.r).abs() + (p.g - q.g).abs() + (p.b - q.b).abs() < 45) continue;
            n++;
            la += 0.2126 * p.r + 0.7152 * p.g + 0.0722 * p.b;
            lb += 0.2126 * q.r + 0.7152 * q.g + 0.0722 * q.b;
          }
        }
        return (changed: n, lumA: n == 0 ? 0.0 : la / n, lumB: n == 0 ? 0.0 : lb / n);
      }

      Future<void> saveAtlas({required bool srgb}) async {
        final set = await ok('set_texture_settings', {'asset': atlasRelative, 'srgb': srgb});
        expect((set.data['settings'] as Map)['srgb'], srgb);
        await ok('save_texture', {'asset': atlasRelative});
      }

      await tester.runAsync(() => client.handshake(clientName: 'claude-code'));

      // --- The sign material on a placed barrel ----------------------------------------
      final compiled = await call('compile_material', {'asset': signMaterial.relativePath, 'save': true});
      expect(compiled.data['ok'], isTrue, reason: compiled.text);
      await ok('select_tab', {'index': 0});
      final start = vm.actors.firstWhere((a) => a.type == 'PlayerStart');
      final yaw = (start.rotation.length > 2 ? start.rotation[2] : 0.0) * math.pi / 180;
      List<double> ahead(double side, [double up = 0.0]) => [
            start.location[0] + 500 * math.cos(yaw) - side * math.sin(yaw),
            start.location[1] + 500 * math.sin(yaw) + side * math.cos(yaw),
            up,
          ];
      await ok('spawn_actor_from_asset', {'asset': barrelMesh.relativePath, 'location': ahead(90)});
      final barrelActor = vm.actors.last;
      final assigned = await ok('set_actor_property', {'id': barrelActor.id, 'property': 'material', 'value': signMaterial.relativePath});
      expect(assigned.data['material_warning'], isNull, reason: assigned.text);
      await ok('clear_selection');
      await ok('set_camera', {'distance': 300.0, 'pitch': 12.0, 'target': ahead(90, 50)});
      await rec.hold(const Duration(milliseconds: 2000));
      final viewportBefore = imageOf(await ok('viewport_screenshot'), 'texture_save_viewport_before');

      // --- The atlas saved with sRGB off: the barrel brightens, nothing reassigned -------
      await saveAtlas(srgb: false);
      await ok('select_tab', {'index': 0});
      await rec.hold(const Duration(milliseconds: 2000));
      final viewportAfter = imageOf(await ok('viewport_screenshot'), 'texture_save_viewport_after_srgb_off');
      final inViewport = change(viewportBefore, viewportAfter);
      debugPrint('[texture_save_smoke] viewport change: $inViewport');
      expect(inViewport.changed, greaterThan(300), reason: 'the barrel draws the saved texture ($inViewport)');
      expect(inViewport.lumB, greaterThan(inViewport.lumA + 15), reason: 'sRGB data read as linear is brighter ($inViewport)');
      expect(vm.actors.firstWhere((a) => a.id == barrelActor.id).materialPath, signMaterial.relativePath,
          reason: 'the assignment is untouched');
      final editorShot = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
      SmokeArtifacts.saveScreenshot('texture_save_editor', editorShot, usedAssets: usedAssets);

      // --- A Blueprint drawing the same material: its 3D Viewport follows ----------------
      await ok('create_asset', {'type': 'actor', 'name': 'BP_SignBarrel', 'parent_class': 'LuminaActor'});
      const bp = 'contents/blueprints/BP_SignBarrel.lmas';
      await ok('get_blueprint', {'asset': bp});
      final mesh = ((await ok('add_blueprint_component', {'asset': bp, 'type': 'LuminaStaticMeshComponent'})).data['component'] as Map)['id'];
      await ok('set_blueprint_component_property', {'asset': bp, 'component': mesh, 'property': 'staticMeshAsset', 'value': barrelMesh.relativePath});
      await ok('set_blueprint_component_property', {'asset': bp, 'component': mesh, 'property': 'materialOverride', 'value': signMaterial.relativePath});
      await ok('compile_blueprint', {'asset': bp, 'save': true});
      await ok('open_asset_editor', {'asset': bp});
      await rec.hold(const Duration(milliseconds: 300));
      await tester.tap(find.text('3D Viewport').first);
      await rec.hold(const Duration(milliseconds: 3000));
      final previewBefore = imageOf(await ok('asset_editor_screenshot', {'asset': bp}), 'texture_save_blueprint_before');

      await saveAtlas(srgb: true);
      await ok('open_asset_editor', {'asset': bp});
      await rec.hold(const Duration(milliseconds: 3000));
      final previewAfter = imageOf(await ok('asset_editor_screenshot', {'asset': bp}), 'texture_save_blueprint_after_srgb_on');
      final inPreview = change(previewBefore, previewAfter);
      debugPrint('[texture_save_smoke] Blueprint preview change: $inPreview');
      expect(inPreview.changed, greaterThan(200), reason: 'the preview draws the saved texture ($inPreview)');
      expect(inPreview.lumB, lessThan(inPreview.lumA - 10), reason: 'sRGB on again darkens it ($inPreview)');

      // The level viewport follows the second save too.
      await ok('select_tab', {'index': 0});
      await rec.hold(const Duration(milliseconds: 2000));
      final viewportBack = imageOf(await ok('viewport_screenshot'), 'texture_save_viewport_after_srgb_on');
      final back = change(viewportAfter, viewportBack);
      debugPrint('[texture_save_smoke] viewport back: $back');
      expect(back.lumB, lessThan(back.lumA - 15), reason: 'sRGB on again darkens the level barrel ($back)');

      for (var i = 0; i < 60 && rec.recorded < const Duration(milliseconds: 10300); i++) {
        await call('set_camera', {'yaw': 20.0 + 8 * (i + 1)});
        await rec.hold(const Duration(milliseconds: 200));
      }
      rec.save(scenario, usedAssets: usedAssets);
    } finally {
      client.close();
      await tester.runAsync(server.stop);
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
      try {
        root.deleteSync(recursive: true);
      } catch (_) {}
    }
  }, timeout: const Timeout(Duration(minutes: 10)));
}
