import 'dart:async';
import 'dart:convert';
import 'dart:io';
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

/// A basic shape's size is authored Z up like its location: on a real Third
/// Person project an MCP client spawns a basic shape (a 100 cm cube by
/// default) and sets `LuminaProceduralMeshComponent.sizeZ` to 300 — the cube
/// becomes a 3 m tall pillar, in the level viewport and in Play, not a 3 m
/// long beam. A banana bunch from test-assets stands beside it for scale.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const scenario = 'Basic shape size axes: sizeZ is the height of a spawned shape in the viewport and in Play';
  testWidgets(scenario, (tester) async {
    final banana = File('${SmokeArtifacts.testAssetsDir.path}/Props/Banana Bunch/banana_bunch_medium.glb');
    expect(banana.existsSync(), isTrue, reason: 'test-assets must hold the banana bunch');
    final usedAssets = [banana.path];

    final root = Directory.systemTemp.createTempSync('lumina_smoke_shape_axes_');
    const name = 'smoke_shape_axes';
    final projectDir = (await tester.runAsync(() => scaffoldGameProject(root, name: name, widgetLibrary: 'flutter')))!;
    final project = LuminaProject.fromMap(
        Map<String, dynamic>.from(jsonDecode(File('$projectDir/$name.lmproject').readAsStringSync()) as Map));
    final vm = EditorViewModel(initialProject: project, projectLocation: root.path);
    await tester.runAsync(vm.ensureDefaultLevelAssets);
    await tester.runAsync(() => vm.processImportPipeline(sourceFilePath: banana.path));
    final bananaMesh = vm.realAssets.firstWhere((a) => a.type == AssetType.filamesh && a.fileName.contains('banana_bunch'));

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

      /// The screen box of the pixels that turned the shape's green between
      /// [before] and [after] (the ground's speckle and the character's idle
      /// change from frame to frame; nothing else in the yard is green). The
      /// viewport's toolbar and status bar are left out.
      ({int width, int height, int count}) changedBox(img.Image before, img.Image after) {
        bool green(img.Pixel p) => p.g > p.r + 35 && p.g > p.b + 35;
        var minX = after.width, minY = after.height, maxX = -1, maxY = -1, count = 0;
        for (var y = 40; y < after.height - 40; y++) {
          for (var x = 0; x < after.width; x++) {
            if (!green(after.getPixel(x, y)) || green(before.getPixel(x, y))) continue;
            count++;
            if (x < minX) minX = x;
            if (x > maxX) maxX = x;
            if (y < minY) minY = y;
            if (y > maxY) maxY = y;
          }
        }
        return count == 0 ? (width: 0, height: 0, count: 0) : (width: maxX - minX + 1, height: maxY - minY + 1, count: count);
      }

      Future<img.Image> playShot(String artifact) async {
        await ok('start_pie');
        for (var i = 0; i < 150 && (await ok('pie_status')).data['runtime_mounted'] != true; i++) {
          await rec.hold(const Duration(milliseconds: 100));
        }
        final shot = imageOf(await ok('pie_play_for', {'ms': 1500, 'screenshot': true}), artifact);
        await ok('stop_pie');
        await rec.hold(const Duration(milliseconds: 500));
        return shot;
      }

      await tester.runAsync(() => client.handshake(clientName: 'claude-code'));

      // 8 m ahead of the player start (it faces +Y) and 2.5 m to its right,
      // where the Play camera sees it beside the character.
      final start = vm.actors.firstWhere((a) => a.type == 'PlayerStart');
      final spot = [start.location[0] + 250, start.location[1] + 800, 0.0];
      await ok('spawn_actor_from_asset', {'asset': bananaMesh.relativePath, 'location': [spot[0] - 120, spot[1], 0.0]});
      await ok('clear_selection');
      await ok('set_camera', {'distance': 900.0, 'pitch': 8.0, 'target': [spot[0], spot[1], 150.0]});
      await rec.hold(const Duration(milliseconds: 1200));
      final viewportBefore = imageOf(await ok('viewport_screenshot'), 'shape_axes_viewport_before');
      await ok('save_level');
      final playBefore = await playShot('shape_axes_play_before');

      // --- A default basic shape, then sizeZ = 300 ----------------------------------
      final spawned = await ok('spawn_actor', {'type': 'Primitive', 'name': 'Pillar_Z', 'location': [spot[0], spot[1], 150.0]});
      final id = (spawned.data['actor'] as Map)['id'] as String;
      final cube = vm.actors.firstWhere((a) => a.id == id);
      final cubeProps = cube.components.firstWhere((c) => c.type == 'LuminaProceduralMeshComponent').properties;
      expect([cubeProps['sizeX'], cubeProps['sizeY'], cubeProps['sizeZ']], [100.0, 100.0, 100.0], reason: 'a 100 cm cube');
      await ok('set_actor_property', {'id': id, 'property': 'LuminaProceduralMeshComponent.sizeZ', 'value': 300});
      await ok('set_actor_property', {'id': id, 'property': 'LuminaProceduralMeshComponent.colorHex', 'value': '#2EB82E'});
      await ok('clear_selection');
      await ok('set_camera', {'distance': 900.0, 'pitch': 8.0, 'target': [spot[0], spot[1], 150.0]});
      await rec.hold(const Duration(milliseconds: 2000));
      final viewportAfter = imageOf(await ok('viewport_screenshot'), 'shape_axes_viewport_tall');
      final inViewport = changedBox(viewportBefore, viewportAfter);
      debugPrint('[shape_axes_smoke] viewport pillar box: $inViewport');
      expect(inViewport.count, greaterThan(500), reason: 'the shape is drawn ($inViewport)');
      expect(inViewport.height, greaterThan(inViewport.width * 2), reason: 'sizeZ 300 on a 100 cm base is a tall pillar ($inViewport)');
      await ok('select_actors', {'ids': [id]});
      await rec.hold(const Duration(milliseconds: 600));
      final editorShot = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
      SmokeArtifacts.saveScreenshot('shape_axes_editor_details', editorShot, usedAssets: usedAssets);

      // --- Play: the same pillar --------------------------------------------------------
      await ok('save_level');
      final playAfter = await playShot('shape_axes_play_tall');
      final inPlay = changedBox(playBefore, playAfter);
      debugPrint('[shape_axes_smoke] Play pillar box: $inPlay');
      expect(inPlay.count, greaterThan(300), reason: 'Play draws the shape ($inPlay)');
      expect(inPlay.height, greaterThan(inPlay.width * 2), reason: 'Play draws it as tall too ($inPlay)');

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
