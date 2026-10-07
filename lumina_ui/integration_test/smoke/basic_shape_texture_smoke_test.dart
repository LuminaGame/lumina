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

/// A textured material assigned to basic shapes draws its texture on them, in
/// the level viewport and in Play: on a real Third Person project an MCP
/// client imports the road sign from test-assets (its base colour a sign
/// atlas), compiles the imported material with matc, spawns a cube, a sphere
/// and a plane with `spawn_actor` at their default 100 cm size, and assigns
/// the material to all three. Each shows the atlas — the whole image upright
/// on every cube face and on the plane, wrapped around the sphere — not the
/// one texel colour a shape without texture coordinates samples.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const scenario = 'Basic shape textures: a textured material shows its texture on a cube, a sphere and a plane in the viewport and in Play';
  testWidgets(scenario, (tester) async {
    final sign = File('${SmokeArtifacts.testAssetsDir.path}/Props/roadsigns/roadsign9.glb');
    expect(sign.existsSync(), isTrue, reason: 'test-assets must hold the road sign');
    final usedAssets = [sign.path];

    final root = Directory.systemTemp.createTempSync('lumina_smoke_shape_tex_');
    const name = 'smoke_shape_textures';
    final projectDir = (await tester.runAsync(() => scaffoldGameProject(root, name: name, widgetLibrary: 'flutter')))!;
    final project = LuminaProject.fromMap(
        Map<String, dynamic>.from(jsonDecode(File('$projectDir/$name.lmproject').readAsStringSync()) as Map));
    final vm = EditorViewModel(initialProject: project, projectLocation: root.path);
    await tester.runAsync(vm.ensureDefaultLevelAssets);
    await tester.runAsync(() => vm.processImportPipeline(sourceFilePath: sign.path));
    final signMaterial = vm.realAssets.firstWhere((a) => a.type == AssetType.filamat && a.relativePath.toLowerCase().contains('roadsign'));
    final signMesh = vm.realAssets.firstWhere((a) => a.type == AssetType.filamesh && a.fileName.contains('roadsign9'));

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

      double lum(img.Pixel p) => 0.2126 * p.r + 0.7152 * p.g + 0.0722 * p.b;

      /// What changed on the shapes between [before] (their own grey) and
      /// [after] (the sign material): how many pixels, how warm they are (the
      /// atlas' rust and yellow), and their detail — the mean luminance step
      /// between neighbouring changed pixels. One texel's colour, however it
      /// is shaded, is smooth; the atlas' lettering and rust are not. The
      /// toolbar and status bar are left out.
      ({int changed, double warm, double detail}) shapeChange(img.Image before, img.Image after) {
        bool changed(int x, int y) {
          final a = after.getPixel(x, y);
          final b = before.getPixel(x, y);
          return (a.r - b.r).abs() + (a.g - b.g).abs() + (a.b - b.b).abs() >= 90;
        }

        var count = 0, warm = 0, pairs = 0;
        var steps = 0.0;
        for (var y = 40; y < after.height - 40; y++) {
          for (var x = 0; x < after.width - 1; x++) {
            if (!changed(x, y)) continue;
            count++;
            final a = after.getPixel(x, y);
            if (a.r > a.b + 10) warm++;
            if (changed(x + 1, y)) {
              steps += (lum(a) - lum(after.getPixel(x + 1, y))).abs();
              pairs++;
            }
          }
        }
        return (changed: count, warm: count == 0 ? 0.0 : warm / count, detail: pairs == 0 ? 0.0 : steps / pairs);
      }

      void expectTextured(({int changed, double warm, double detail}) change, String where) {
        expect(change.changed, greaterThan(1500), reason: '$where: the shapes draw the assigned material ($change)');
        expect(change.warm, greaterThan(0.2), reason: '$where: the atlas rust and yellow, not black or white ($change)');
        expect(change.detail, greaterThan(6.0), reason: '$where: the atlas detail, not one texel colour ($change)');
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

      // --- A cube, a sphere and a standing plane, 8 m ahead of the player start ------
      // (it faces +Y), all at the default 100 cm size.
      final start = vm.actors.firstWhere((a) => a.type == 'PlayerStart');
      List<double> ahead(double side, double up) => [start.location[0] + side, start.location[1] + 800, up];
      final ids = <String>[];
      Future<String> spawn(String shapeName, List<double> location, [List<double>? rotation]) async {
        final spawned = await ok('spawn_actor', {
          'type': 'Primitive',
          'name': 'Textured_$shapeName',
          'location': location,
          'rotation': ?rotation,
        });
        final id = (spawned.data['actor'] as Map)['id'] as String;
        if (shapeName != 'box') {
          await ok('set_actor_property', {'id': id, 'property': 'LuminaProceduralMeshComponent.shape', 'value': shapeName});
        }
        final props = vm.actors.firstWhere((a) => a.id == id).components.firstWhere((c) => c.type == 'LuminaProceduralMeshComponent').properties;
        expect([props['sizeX'], props['sizeY'], props['sizeZ']], [100.0, 100.0, 100.0], reason: '$shapeName keeps the default size');
        ids.add(id);
        return id;
      }

      await spawn('box', ahead(-280, 50));
      await spawn('sphere', ahead(170, 50));
      // Pitched up 90°: the plane stands and faces the player (−Y).
      await spawn('plane', ahead(470, 50), [90, 0, 0]);
      // The imported sign itself, for comparison: it draws the same atlas
      // through the same material, with its own glTF texture coordinates.
      await ok('spawn_actor_from_asset', {'asset': signMesh.relativePath, 'location': ahead(-470, 0)});
      await ok('clear_selection');
      final target = ahead(100, 50);
      await ok('set_camera', {'distance': 800.0, 'pitch': 8.0, 'yaw': 0.0, 'target': target});
      await rec.hold(const Duration(milliseconds: 1500));
      final viewportBefore = imageOf(await ok('viewport_screenshot'), 'shape_textures_viewport_before');
      await ok('save_level');
      final playBefore = await playShot('shape_textures_play_before');

      // --- The imported sign material, compiled with matc and saved -------------------
      final compiled = await call('compile_material', {'asset': signMaterial.relativePath, 'save': true});
      expect(compiled.data['ok'], isTrue, reason: compiled.text);
      await ok('select_tab', {'index': 0});
      await rec.hold(const Duration(milliseconds: 600));

      // --- Assigned to all three: the viewport draws the atlas on each ----------------
      for (final id in ids) {
        final assigned = await ok('set_actor_property', {'id': id, 'property': 'material', 'value': signMaterial.relativePath});
        expect(assigned.data['material_warning'], isNull, reason: assigned.text);
      }
      await ok('clear_selection');
      await ok('set_camera', {'distance': 800.0, 'pitch': 8.0, 'yaw': 0.0, 'target': target});
      await rec.hold(const Duration(milliseconds: 2000));
      final viewportAfter = imageOf(await ok('viewport_screenshot'), 'shape_textures_viewport_after_assign');
      final inViewport = shapeChange(viewportBefore, viewportAfter);
      debugPrint('[shape_textures_smoke] viewport change: $inViewport');
      expectTextured(inViewport, 'viewport');
      await ok('set_camera', {'distance': 520.0, 'pitch': 5.0, 'yaw': 0.0, 'target': ahead(-380, 140)});
      await rec.hold(const Duration(milliseconds: 1200));
      imageOf(await ok('viewport_screenshot'), 'shape_textures_viewport_cube_close');
      await ok('set_camera', {'distance': 800.0, 'pitch': 8.0, 'yaw': 0.0, 'target': target});
      await ok('select_actors', {'ids': [ids.first]});
      await rec.hold(const Duration(milliseconds: 800));
      final editorShot = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
      SmokeArtifacts.saveScreenshot('shape_textures_editor', editorShot, usedAssets: usedAssets);

      // --- Play: the game camera sees the textured shapes -------------------------------
      await ok('save_level');
      final playAfter = await playShot('shape_textures_play');
      final inPlay = shapeChange(playBefore, playAfter);
      debugPrint('[shape_textures_smoke] Play change: $inPlay');
      expectTextured(inPlay, 'Play');

      for (var i = 0; i < 60 && rec.recorded < const Duration(milliseconds: 10300); i++) {
        await call('set_camera', {'yaw': -40.0 + 8 * (i + 1), 'target': target, 'distance': 700.0 + 20 * math.sin(i / 6)});
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
