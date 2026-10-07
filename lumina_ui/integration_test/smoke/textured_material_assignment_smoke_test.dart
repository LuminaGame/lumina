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

/// A textured material assigned to another placed mesh draws its texture, in
/// the level viewport and in Play: on a real Third Person project an MCP client
/// imports the road sign from test-assets (one material, its base colour a
/// sign atlas, its factor white) and the black fuel barrel (drawn white by its
/// own material), compiles the imported sign material with matc and assigns it
/// to the barrel with `set_actor_property material`. The barrel then shows the
/// atlas' rusty sign metal in the viewport and in Play: the white factor alone
/// would keep it white, an unbound sampler would draw it one flat black.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const scenario = 'Textured material assignment: an imported textured material draws its texture on another mesh in the viewport and in Play';
  testWidgets(scenario, (tester) async {
    final sign = File('${SmokeArtifacts.testAssetsDir.path}/Props/roadsigns/roadsign9.glb');
    final barrel = File('${SmokeArtifacts.testAssetsDir.path}/Props/Barrels/fuel_barrel_black.glb');
    expect(sign.existsSync() && barrel.existsSync(), isTrue, reason: 'test-assets must hold the road sign and the black barrel');
    final usedAssets = [sign.path, barrel.path];

    final root = Directory.systemTemp.createTempSync('lumina_smoke_texmat_');
    const name = 'smoke_textured_material';
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
    expect(signAsset.references.map((r) => r.slotName), contains('baseColorMap'), reason: 'the import records the texture');

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

      /// What changed on the barrel between [before] and [after]: the pixels
      /// that differ, and in [after] their luminance spread and how many are
      /// warm (the atlas' rust and paint, redder than blue). The barrel's own
      /// material draws it white; the sign material's white factor alone would
      /// keep it white, and an unbound sampler draws it one flat black.
      ({int changed, double spread, double warm}) barrelChange(img.Image before, img.Image after) {
        final lum = <double>[];
        var warm = 0;
        // Below the toolbar and Play's fading "Press F4" hint.
        for (var y = after.height * 18 ~/ 100; y < after.height; y += 2) {
          for (var x = 0; x < after.width; x += 2) {
            final a = after.getPixel(x, y);
            final b = before.getPixel(x, y);
            if ((a.r - b.r).abs() + (a.g - b.g).abs() + (a.b - b.b).abs() < 90) continue;
            lum.add(0.2126 * a.r + 0.7152 * a.g + 0.0722 * a.b);
            if (a.r > a.b + 10) warm++;
          }
        }
        if (lum.isEmpty) return (changed: 0, spread: 0.0, warm: 0.0);
        final mean = lum.reduce((p, q) => p + q) / lum.length;
        final spread = math.sqrt(lum.map((v) => (v - mean) * (v - mean)).reduce((p, q) => p + q) / lum.length);
        return (changed: lum.length, spread: spread, warm: warm / lum.length);
      }

      void expectTextured(({int changed, double spread, double warm}) change, String where) {
        expect(change.changed, greaterThan(300), reason: '$where: the barrel draws the assigned material ($change)');
        expect(change.spread, greaterThan(18), reason: '$where: the atlas texture, not one flat colour ($change)');
        expect(change.warm, greaterThan(0.2), reason: '$where: the atlas rust, not black or white ($change)');
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

      // --- The black barrel, 5 m in front of the player start ----------------------
      final start = vm.actors.firstWhere((a) => a.type == 'PlayerStart');
      final yaw = (start.rotation.length > 2 ? start.rotation[2] : 0.0) * math.pi / 180;
      List<double> ahead(double side, [double up = 0.0]) => [
            start.location[0] + 500 * math.cos(yaw) - side * math.sin(yaw),
            start.location[1] + 500 * math.sin(yaw) + side * math.cos(yaw),
            up,
          ];
      await ok('spawn_actor_from_asset', {'asset': barrelMesh.relativePath, 'location': ahead(90)});
      final barrelActor = vm.actors.last;
      await ok('clear_selection');
      await ok('set_camera', {'distance': 450.0, 'pitch': 12.0, 'target': ahead(90, 50)});
      await rec.hold(const Duration(milliseconds: 1200));
      final viewportBefore = imageOf(await ok('viewport_screenshot'), 'textured_material_viewport_before');
      await ok('save_level');
      final playBefore = await playShot('textured_material_play_before');

      // --- The imported sign material, compiled with matc and saved ---------------
      final compiled = await call('compile_material', {'asset': signMaterial.relativePath, 'save': true});
      expect(compiled.data['ok'], isTrue, reason: compiled.text);
      final saved = LuminaAsset.fromBytes(File(signMaterial.lmasPath!).readAsBytesSync());
      expect(saved.references.map((r) => r.slotName), contains('baseColorMap'), reason: 'saving keeps the texture slot');
      await ok('select_tab', {'index': 0});
      await rec.hold(const Duration(milliseconds: 600));

      // --- Assigned to the barrel: the viewport draws the atlas --------------------
      final assigned = await ok('set_actor_property', {'id': barrelActor.id, 'property': 'material', 'value': signMaterial.relativePath});
      expect(assigned.data['material_warning'], isNull, reason: assigned.text);
      await ok('clear_selection');
      await ok('set_camera', {'distance': 450.0, 'pitch': 12.0, 'target': ahead(90, 50)});
      await rec.hold(const Duration(milliseconds: 2000));
      final viewportAfter = imageOf(await ok('viewport_screenshot'), 'textured_material_viewport_after_assign');
      final inViewport = barrelChange(viewportBefore, viewportAfter);
      debugPrint('[textured_material_smoke] viewport barrel change: $inViewport');
      expectTextured(inViewport, 'viewport');
      await ok('select_actors', {'ids': [barrelActor.id]});
      await rec.hold(const Duration(milliseconds: 600));
      final editorShot = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
      SmokeArtifacts.saveScreenshot('textured_material_editor', editorShot, usedAssets: usedAssets);

      // --- Play: the game camera sees the textured barrel ---------------------------
      await ok('save_level');
      final playAfter = await playShot('textured_material_play');
      final inPlay = barrelChange(playBefore, playAfter);
      debugPrint('[textured_material_smoke] Play barrel change: $inPlay');
      expectTextured(inPlay, 'Play');

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
