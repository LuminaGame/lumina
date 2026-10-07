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

/// A Blueprint that sets a texture parameter at BeginPlay draws that texture
/// in Play: on a real Third Person project an MCP client imports the road sign
/// (its material's base colour a rusty sign atlas), the black fuel barrel and
/// the slot machine's display image (a texture asset), compiles the sign
/// material with matc and builds BP_TexturedBarrel: the barrel mesh with the
/// sign material as its Material Override, and an event graph BeginPlay →
/// Create Dynamic Material Instance → Set Texture Parameter Value
/// (baseColorMap = the display texture `.lmas`). Played without the last wire
/// the barrel shows the rusty atlas; wired, the display's blue screen. The
/// Material Override is still loading at BeginPlay, so the dynamic instance
/// is made, and the texture bound, once it has.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const scenario = 'Blueprint texture parameter: Set Texture Parameter Value at BeginPlay draws a texture asset in Play';
  testWidgets(scenario, (tester) async {
    final sign = File('${SmokeArtifacts.testAssetsDir.path}/Props/roadsigns/roadsign9.glb');
    final barrel = File('${SmokeArtifacts.testAssetsDir.path}/Props/Barrels/fuel_barrel_black.glb');
    final display = File('${SmokeArtifacts.testAssetsDir.path}/FBX/TextureFixtures/SM_Slot_Machine/SM_Slot_Machine_MI_Display_1_Emissive.png');
    expect(sign.existsSync() && barrel.existsSync() && display.existsSync(), isTrue,
        reason: 'test-assets must hold the road sign, the black barrel and the slot machine display image');
    final usedAssets = [sign.path, barrel.path, display.path];

    final root = Directory.systemTemp.createTempSync('lumina_smoke_bptexparam_');
    const name = 'smoke_bp_texture_parameter';
    final projectDir = (await tester.runAsync(() => scaffoldGameProject(root, name: name, widgetLibrary: 'flutter')))!;
    final project = LuminaProject.fromMap(
        Map<String, dynamic>.from(jsonDecode(File('$projectDir/$name.lmproject').readAsStringSync()) as Map));
    final vm = EditorViewModel(initialProject: project, projectLocation: root.path);
    await tester.runAsync(vm.ensureDefaultLevelAssets);
    await tester.runAsync(() => vm.processImportPipeline(sourceFilePath: sign.path));
    await tester.runAsync(() => vm.processImportPipeline(sourceFilePath: barrel.path));
    await tester.runAsync(() => vm.processImportPipeline(sourceFilePath: display.path));
    final barrelMesh = vm.realAssets.firstWhere((a) => a.type == AssetType.filamesh && a.fileName.contains('fuel_barrel_black'));
    final signMaterial = vm.realAssets.firstWhere((a) => a.type == AssetType.filamat && a.relativePath.toLowerCase().contains('roadsign'));
    final displayTexture = vm.realAssets.firstWhere((a) => a.type == AssetType.texture && a.fileName.contains('Display_1'));
    expect(displayTexture.relativePath, endsWith('.lmas'), reason: 'the image is a texture asset');

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

      Future<Map<String, Object?>> ok(String tool, [Map<String, Object?> args = const {}]) async {
        final reply = await call(tool, args);
        expect(reply.isError, isFalse, reason: '$tool: ${reply.text}');
        return reply.data;
      }

      img.Image imageOf(McpToolReply reply, String artifact) {
        final png = Uint8List.fromList(base64Decode(reply.content.firstWhere((c) => c['type'] == 'image')['data'] as String));
        SmokeArtifacts.saveScreenshot(artifact, png, usedAssets: usedAssets);
        return img.decodePng(png)!;
      }

      Future<img.Image> playShot(String artifact) async {
        await ok('start_pie');
        for (var i = 0; i < 150 && (await ok('pie_status'))['runtime_mounted'] != true; i++) {
          await rec.hold(const Duration(milliseconds: 100));
        }
        final reply = await call('pie_play_for', {'ms': 2500, 'screenshot': true});
        expect(reply.isError, isFalse, reason: reply.text);
        final shot = imageOf(reply, artifact);
        await ok('stop_pie');
        await rec.hold(const Duration(milliseconds: 500));
        return shot;
      }

      /// The pixels that differ between [a] and [b], and the mean colour of
      /// those pixels in each.
      ({int changed, List<double> meanA, List<double> meanB}) change(img.Image a, img.Image b) {
        final sa = [0.0, 0.0, 0.0];
        final sb = [0.0, 0.0, 0.0];
        var n = 0;
        for (var y = 0; y < b.height; y += 2) {
          for (var x = 0; x < b.width; x += 2) {
            final p = a.getPixel(x, y);
            final q = b.getPixel(x, y);
            if ((p.r - q.r).abs() + (p.g - q.g).abs() + (p.b - q.b).abs() < 90) continue;
            n++;
            sa[0] += p.r;
            sa[1] += p.g;
            sa[2] += p.b;
            sb[0] += q.r;
            sb[1] += q.g;
            sb[2] += q.b;
          }
        }
        List<double> mean(List<double> s) => [for (final v in s) n == 0 ? 0.0 : v / n];
        return (changed: n, meanA: mean(sa), meanB: mean(sb));
      }

      await tester.runAsync(() => client.handshake(clientName: 'claude-code'));

      // --- The sign material, compiled with matc ------------------------------------
      final compiled = await call('compile_material', {'asset': signMaterial.relativePath, 'save': true});
      expect(compiled.data['ok'], isTrue, reason: compiled.text);

      // --- BP_TexturedBarrel: the barrel drawn with the sign material ---------------
      await ok('create_asset', {'type': 'actor', 'name': 'BP_TexturedBarrel', 'parent_class': 'LuminaActor'});
      const bp = 'contents/blueprints/BP_TexturedBarrel.lmas';
      final graph = await ok('get_blueprint', {'asset': bp});
      final mesh = ((await ok('add_blueprint_component', {'asset': bp, 'type': 'LuminaStaticMeshComponent'}))['component'] as Map)['id'];
      await ok('set_blueprint_component_property', {'asset': bp, 'component': mesh, 'property': 'staticMeshAsset', 'value': barrelMesh.relativePath});
      await ok('set_blueprint_component_property', {'asset': bp, 'component': mesh, 'property': 'materialOverride', 'value': signMaterial.relativePath});

      // BeginPlay → Create Dynamic Material Instance → Set Texture Parameter Value.
      String nodeId(Map<String, Object?> added) => (added['node'] as Map)['id'] as String;
      var begin = (graph['nodes'] as List).cast<Map>().where((n) => n['node'] == 'event_beginplay').firstOrNull?['id'] as String?;
      begin ??= nodeId(await ok('add_blueprint_node', {'asset': bp, 'node': 'event_beginplay', 'x': 60, 'y': 80}));
      final getMesh = nodeId(await ok('add_blueprint_node', {
        'asset': bp,
        'node': 'get_component_by_class',
        'x': 60,
        'y': 260,
        'literals': {'class': 'Component:LuminaStaticMeshComponent'},
      }));
      final create = nodeId(await ok('add_blueprint_node', {'asset': bp, 'node': 'create_dynamic_material_instance', 'x': 380, 'y': 80}));
      final setTexture = nodeId(await ok('add_blueprint_node', {
        'asset': bp,
        'node': 'set_texture_parameter_value',
        'x': 720,
        'y': 80,
        'literals': {'parameter_name': 'baseColorMap', 'value': displayTexture.relativePath},
      }));
      await ok('connect_blueprint_pins', {'asset': bp, 'from_node': begin, 'from_pin': 'exec_out', 'to_node': create, 'to_pin': 'exec_in'});
      await ok('connect_blueprint_pins', {'asset': bp, 'from_node': getMesh, 'from_pin': 'return_value', 'to_node': create, 'to_pin': 'target'});
      await ok('connect_blueprint_pins', {'asset': bp, 'from_node': create, 'from_pin': 'return_value', 'to_node': setTexture, 'to_pin': 'target'});
      final unwired = await ok('compile_blueprint', {'asset': bp, 'save': true});
      expect(unwired['status'], isNot('error'), reason: '$unwired');
      await rec.hold(const Duration(milliseconds: 600));
      final graphShot = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
      SmokeArtifacts.saveScreenshot('bp_texture_parameter_graph_unwired', graphShot, usedAssets: usedAssets);

      // --- Placed 5 m in front of the player start -----------------------------------
      await ok('select_tab', {'index': 0});
      final start = vm.actors.firstWhere((a) => a.type == 'PlayerStart');
      final yaw = (start.rotation.length > 2 ? start.rotation[2] : 0.0) * math.pi / 180;
      List<double> ahead(double side, [double up = 0.0]) => [
            start.location[0] + 500 * math.cos(yaw) - side * math.sin(yaw),
            start.location[1] + 500 * math.sin(yaw) + side * math.cos(yaw),
            up,
          ];
      await ok('spawn_actor_from_asset', {'asset': bp, 'location': ahead(90)});
      await ok('clear_selection');
      await ok('set_camera', {'distance': 450.0, 'pitch': 12.0, 'target': ahead(90, 50)});
      await rec.hold(const Duration(milliseconds: 1200));
      await ok('save_level');

      // --- Play without the last wire: the sign material's own atlas ------------------
      final before = await playShot('bp_texture_parameter_play_before');

      // --- Wired: BeginPlay binds the display texture ---------------------------------
      await ok('connect_blueprint_pins', {'asset': bp, 'from_node': create, 'from_pin': 'exec_out', 'to_node': setTexture, 'to_pin': 'exec_in'});
      final wired = await ok('compile_blueprint', {'asset': bp, 'save': true});
      expect(wired['status'], isNot('error'), reason: '$wired');
      await rec.hold(const Duration(milliseconds: 600));
      final wiredShot = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
      SmokeArtifacts.saveScreenshot('bp_texture_parameter_graph_wired', wiredShot, usedAssets: usedAssets);
      await ok('select_tab', {'index': 0});
      await rec.hold(const Duration(milliseconds: 400));
      final after = await playShot('bp_texture_parameter_play_after');

      final c = change(before, after);
      debugPrint('[bp_texture_parameter_smoke] barrel change: $c');
      expect(c.changed, greaterThan(300), reason: 'the barrel draws another texture once BeginPlay sets it ($c)');
      // The atlas' rust and dark metal give way to the display's blue screen.
      double blueOverRed(List<double> m) => m[2] / math.max(1.0, m[0]);
      expect(blueOverRed(c.meanB), greaterThan(blueOverRed(c.meanA) + 0.15), reason: 'the display texture is bluer ($c)');
      expect(c.meanB[2], greaterThan(c.meanA[2] + 30), reason: 'the display texture is brighter blue ($c)');

      await ok('set_camera', {'distance': 450.0, 'pitch': 12.0, 'target': ahead(90, 50)});
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
