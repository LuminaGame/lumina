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

/// A material built in the Material Editor's node graph draws its texture
/// upright on a mesh: on a real Third Person project an MCP client imports
/// the road sign from test-assets, creates a new material, builds it in the
/// node graph (a Texture Sample of the sign atlas into Base Color), compiles
/// and saves it, and assigns it to a cube. A second cube carries the sign's
/// imported material, which samples the atlas upright; framed the same way,
/// the two faces match (STOP / DEAD END on top, the lettering readable), and
/// differ from the atlas turned upside down. Viewport and Play.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const scenario = 'Material graph texture orientation: a Texture Sample built in the node graph draws the sign atlas upright on a cube in the viewport and in Play';
  testWidgets(scenario, (tester) async {
    final sign = File('${SmokeArtifacts.testAssetsDir.path}/Props/roadsigns/roadsign9.glb');
    expect(sign.existsSync(), isTrue, reason: 'test-assets must hold the road sign');
    final usedAssets = [sign.path];

    final root = Directory.systemTemp.createTempSync('lumina_smoke_graph_uv_');
    const name = 'smoke_graph_uv';
    final projectDir = (await tester.runAsync(() => scaffoldGameProject(root, name: name, widgetLibrary: 'flutter')))!;
    final project = LuminaProject.fromMap(
        Map<String, dynamic>.from(jsonDecode(File('$projectDir/$name.lmproject').readAsStringSync()) as Map));
    final vm = EditorViewModel(initialProject: project, projectLocation: root.path);
    await tester.runAsync(vm.ensureDefaultLevelAssets);
    await tester.runAsync(() => vm.processImportPipeline(sourceFilePath: sign.path));
    final signMaterial = vm.realAssets.firstWhere((a) => a.type == AssetType.filamat && a.relativePath.toLowerCase().contains('roadsign'));
    final atlas = LuminaAsset.fromBytes(File(signMaterial.lmasPath!).readAsBytesSync())
        .references
        .firstWhere((r) => r.slotName == 'baseColorMap')
        .assetPath;

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

      /// The framed cube face (the middle of the frame), as mean luminance
      /// over a 16 × 16 grid of cells.
      List<double> faceGrid(img.Image shot, {bool upsideDown = false}) {
        final x0 = shot.width * 0.36, x1 = shot.width * 0.64;
        final y0 = shot.height * 0.14, y1 = shot.height * 0.85;
        const n = 16;
        double cell(int i, int j) {
          var sum = 0.0, count = 0;
          for (var y = (y0 + (y1 - y0) * j / n).floor(); y < (y0 + (y1 - y0) * (j + 1) / n).floor(); y++) {
            for (var x = (x0 + (x1 - x0) * i / n).floor(); x < (x0 + (x1 - x0) * (i + 1) / n).floor(); x++) {
              final p = shot.getPixel(x, y);
              sum += 0.2126 * p.r + 0.7152 * p.g + 0.0722 * p.b;
              count++;
            }
          }
          return sum / count;
        }

        return [
          for (var j = 0; j < n; j++)
            for (var i = 0; i < n; i++) cell(i, upsideDown ? n - 1 - j : j),
        ];
      }

      double meanDiff(List<double> a, List<double> b) {
        var sum = 0.0;
        for (var k = 0; k < a.length; k++) {
          sum += (a[k] - b[k]).abs();
        }
        return sum / a.length;
      }

      double spread(List<double> a) {
        final mean = a.reduce((x, y) => x + y) / a.length;
        return math.sqrt(a.map((v) => (v - mean) * (v - mean)).reduce((x, y) => x + y) / a.length);
      }

      await tester.runAsync(() => client.handshake(clientName: 'claude-code'));

      // --- A new material, built in the node graph ------------------------------------
      const graphMaterial = 'contents/materials/M_GraphSign.lmas';
      await ok('create_asset', {'type': 'filamat', 'folder': 'materials', 'name': 'M_GraphSign'});
      await ok('open_asset_editor', {'asset': graphMaterial});
      await rec.hold(const Duration(milliseconds: 800));
      final sample = (await ok('add_material_node', {'asset': graphMaterial, 'node': 'mat_texture_sample', 'x': -520.0, 'y': -80.0}))
          .data['node'] as Map;
      final parameter = (sample['settings'] as Map)['parameter'] as String;
      await ok('connect_material_pins',
          {'asset': graphMaterial, 'from_node': sample['id'], 'from_pin': 'rgba', 'to_node': 'material_output', 'to_pin': 'base_color'});
      // Metallic 0 and roughness 1, as the imported sign material is: the
      // template's metallic 0.8 / roughness 0.3 would darken the atlas and add
      // a highlight the comparison below would see.
      for (final (pin, value, y) in [('metallic', 0.0, 160.0), ('roughness', 1.0, 260.0)]) {
        final k = (await ok('add_material_node', {'asset': graphMaterial, 'node': 'mat_constant', 'x': -320.0, 'y': y, 'settings': {'value': value}}))
            .data['node'] as Map;
        await ok('connect_material_pins',
            {'asset': graphMaterial, 'from_node': k['id'], 'from_pin': 'out', 'to_node': 'material_output', 'to_pin': pin});
      }
      await ok('set_material_texture', {'asset': graphMaterial, 'parameter': parameter, 'texture': atlas});
      final source = (await ok('get_material_source', {'asset': graphMaterial})).data['source'] as String;
      debugPrint('[graph_uv_smoke] source:\n$source');
      expect(source, contains('flipUV : false'));
      final compiled = await call('compile_material', {'asset': graphMaterial, 'save': true});
      expect(compiled.data['ok'], isTrue, reason: compiled.text);
      await ok('arrange_material_graph', {'asset': graphMaterial});
      await rec.hold(const Duration(milliseconds: 1200));
      imageOf(await ok('asset_editor_screenshot', {'asset': graphMaterial, 'max_width': 1400}), 'graph_uv_material_graph');

      // The sign's imported material: the upright reference.
      final reference = await call('compile_material', {'asset': signMaterial.relativePath, 'save': true});
      expect(reference.data['ok'], isTrue, reason: reference.text);
      await ok('select_tab', {'index': 0});
      await rec.hold(const Duration(milliseconds: 600));

      // --- Two cubes 3.2 m ahead of the player start (it faces +Y) ----------------------
      final start = vm.actors.firstWhere((a) => a.type == 'PlayerStart');
      List<double> ahead(double side, double up) => [start.location[0] + side, start.location[1] + 320, up];
      Future<String> cube(String label, double side, String material) async {
        final spawned = await ok('spawn_actor', {'type': 'Primitive', 'name': label, 'location': ahead(side, 170)});
        final id = (spawned.data['actor'] as Map)['id'] as String;
        final assigned = await ok('set_actor_property', {'id': id, 'property': 'material', 'value': material});
        expect(assigned.data['material_warning'], isNull, reason: assigned.text);
        return id;
      }

      await cube('Graph_Cube', -110, graphMaterial);
      await cube('Imported_Cube', 110, signMaterial.relativePath);
      await ok('clear_selection');

      // Each cube framed the same way, straight onto its face.
      Future<img.Image> framed(double side, String artifact) async {
        await ok('set_camera', {'distance': 210.0, 'pitch': 0.0, 'yaw': 0.0, 'target': ahead(side, 170)});
        await rec.hold(const Duration(milliseconds: 1500));
        return imageOf(await ok('viewport_screenshot'), artifact);
      }

      final graphFace = faceGrid(await framed(-110, 'graph_uv_viewport_graph_cube'));
      final importedShot = await framed(110, 'graph_uv_viewport_imported_cube');
      final importedFace = faceGrid(importedShot);
      final importedUpsideDown = faceGrid(importedShot, upsideDown: true);
      final same = meanDiff(graphFace, importedFace);
      final flipped = meanDiff(graphFace, importedUpsideDown);
      debugPrint('[graph_uv_smoke] face difference: upright $same, upside down $flipped, detail ${spread(graphFace)}');
      expect(spread(graphFace), greaterThan(12.0), reason: 'the face shows the atlas, not one colour');
      expect(same, lessThan(flipped * 0.5), reason: 'the graph material draws the atlas as the imported one does, upright');

      await ok('set_camera', {'distance': 420.0, 'pitch': 4.0, 'yaw': 0.0, 'target': ahead(0, 170)});
      await rec.hold(const Duration(milliseconds: 1200));
      imageOf(await ok('viewport_screenshot'), 'graph_uv_viewport_both');
      final editorShot = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
      SmokeArtifacts.saveScreenshot('graph_uv_editor', editorShot, usedAssets: usedAssets);

      // --- Play: the game camera sees both cubes ----------------------------------------
      await ok('save_level');
      await ok('start_pie');
      for (var i = 0; i < 150 && (await ok('pie_status')).data['runtime_mounted'] != true; i++) {
        await rec.hold(const Duration(milliseconds: 100));
      }
      imageOf(await ok('pie_play_for', {'ms': 1500, 'screenshot': true}), 'graph_uv_play');
      await ok('stop_pie');
      await rec.hold(const Duration(milliseconds: 500));

      for (var i = 0; i < 60 && rec.recorded < const Duration(milliseconds: 10300); i++) {
        await call('set_camera', {'yaw': -30.0 + 6 * (i + 1), 'target': ahead(0, 170), 'distance': 420.0 + 15 * math.sin(i / 6)});
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
