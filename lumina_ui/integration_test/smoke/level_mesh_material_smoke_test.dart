import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../test/helpers/mcp_test_client.dart';
import '../../test/helpers/scaffold_game_project.dart';

/// A material assigned to a placed level mesh is what the mesh draws, in the
/// level viewport and in Play: on a real Third Person project an MCP client
/// imports the yellow fuel barrel from test-assets, places two of them in
/// front of the player start, builds a magenta material (a colour parameter
/// set and compiled with matc) and assigns it to one barrel with
/// `set_actor_property material`. The viewport turns that barrel magenta at
/// once, the Details panel names the material, the saved level's generated
/// code carries it, the level still draws it after it is reopened, and Play
/// draws it too. The other barrel keeps its own yellow throughout.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const scenario = 'Level mesh material: an assigned material draws in the viewport, after reopening and in Play';
  testWidgets(scenario, (tester) async {
    final barrel = File('${SmokeArtifacts.testAssetsDir.path}/Props/Barrels/fuel_barrel_yellow.glb');
    expect(barrel.existsSync(), isTrue, reason: 'test-assets must hold the yellow fuel barrel');
    final usedAssets = [barrel.path];

    final root = Directory.systemTemp.createTempSync('lumina_smoke_lvlmat_');
    const name = 'smoke_level_material';
    final projectDir = (await tester.runAsync(() => scaffoldGameProject(root, name: name, widgetLibrary: 'flutter')))!;
    final project = LuminaProject.fromMap(
        Map<String, dynamic>.from(jsonDecode(File('$projectDir/$name.lmproject').readAsStringSync()) as Map));
    final vm = EditorViewModel(initialProject: project, projectLocation: root.path);
    await tester.runAsync(vm.ensureDefaultLevelAssets);
    await tester.runAsync(() => vm.processImportPipeline(sourceFilePath: barrel.path));
    final barrelMesh = vm.realAssets.firstWhere((a) => a.type == AssetType.filamesh && a.fileName.contains('fuel_barrel_yellow'));

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

      /// Pixels of the assigned material's magenta (lit and shaded).
      int magentaPixels(img.Image frame) {
        var n = 0;
        for (var y = 0; y < frame.height; y += 2) {
          for (var x = 0; x < frame.width; x += 2) {
            final p = frame.getPixel(x, y);
            if (p.r > 90 && p.b > 70 && p.g < p.r * 0.45 && p.g < p.b * 0.6) n++;
          }
        }
        return n;
      }

      await tester.runAsync(() => client.handshake(clientName: 'claude-code'));

      // --- Two barrels, 5 m in front of the player start, side by side --------
      final start = vm.actors.firstWhere((a) => a.type == 'PlayerStart');
      final yaw = (start.rotation.length > 2 ? start.rotation[2] : 0.0) * math.pi / 180;
      List<double> ahead(double side) => [
            start.location[0] + 500 * math.cos(yaw) - side * math.sin(yaw),
            start.location[1] + 500 * math.sin(yaw) + side * math.cos(yaw),
            0.0,
          ];
      // Beside the character's line of sight, where the game camera sees them.
      await ok('spawn_actor_from_asset', {'asset': barrelMesh.relativePath, 'location': ahead(90)});
      final painted = vm.actors.last;
      await ok('spawn_actor_from_asset', {'asset': barrelMesh.relativePath, 'location': ahead(-250)});
      final plain = vm.actors.last;
      expect(painted.materialPath, isNull, reason: 'a placed mesh draws its own materials until one is assigned');
      await ok('focus_actor', {'id': painted.id});
      await ok('set_camera', {'distance': 900.0, 'pitch': 20.0, 'target': ahead(0)});
      await rec.hold(const Duration(milliseconds: 1200));
      final before = imageOf(await ok('viewport_screenshot'), 'level_mesh_material_viewport_before');
      final magentaBefore = magentaPixels(before);

      // --- A magenta material: a colour parameter, compiled and saved ----------
      await ok('create_asset', {'type': 'filamat', 'name': 'M_Magenta'});
      await ok('set_material_source', {'asset': 'M_Magenta', 'source': _tintMaterial});
      // The Parameters panel lists the source's parameters once it compiles.
      final first = await call('compile_material', {'asset': 'M_Magenta'});
      expect(first.data['ok'], isTrue, reason: first.text);
      await ok('set_material_parameter', {'asset': 'M_Magenta', 'name': 'tint', 'value': [0.85, 0.05, 0.75, 1.0]});
      final compiled = await call('compile_material', {'asset': 'M_Magenta', 'save': true});
      expect(compiled.data['ok'], isTrue, reason: compiled.text);
      await ok('select_tab', {'index': 0});
      await rec.hold(const Duration(milliseconds: 600));

      // --- Assigned to one barrel: the viewport draws it at once --------------
      final assigned = await ok('set_actor_property', {'id': painted.id, 'property': 'material', 'value': 'M_Magenta'});
      expect(assigned.data['material_warning'], isNull, reason: assigned.text);
      expect(painted.materialPath, 'contents/materials/M_Magenta.lmas');
      await ok('select_actors', {'ids': [painted.id]});
      await rec.hold(const Duration(milliseconds: 1500));
      final after = imageOf(await ok('viewport_screenshot'), 'level_mesh_material_viewport_after_assign');
      final magentaAfter = magentaPixels(after);
      debugPrint('[level_mesh_material_smoke] viewport magenta pixels: before $magentaBefore, after $magentaAfter');
      expect(magentaAfter, greaterThan(magentaBefore + 400), reason: 'the barrel draws the assigned material in the viewport');
      // The Details panel's Material row, scrolled into view.
      await tester.ensureVisible(find.byKey(const ValueKey('details_material_select'), skipOffstage: false));
      await rec.hold(const Duration(milliseconds: 600));
      expect(find.byKey(const ValueKey('details_material_select')), findsOneWidget, reason: 'the Details Material row');
      expect(find.descendant(of: find.byKey(const ValueKey('details_material_select')), matching: find.text('M_Magenta')), findsOneWidget);
      final editorShot = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(boundaryKey));
      SmokeArtifacts.saveScreenshot('level_mesh_material_editor_details', editorShot, usedAssets: usedAssets);
      expect(plain.materialPath, isNull);

      // --- Saved: the generated level carries it; reopened: still drawn -------
      await ok('save_level');
      final levelCode = Directory('$projectDir/lib/levels')
          .listSync()
          .whereType<File>()
          .map((f) => f.readAsStringSync())
          .firstWhere((c) => c.contains("ValueKey('${painted.id}')"));
      expect(levelCode, contains("materialOverrideAsset: 'contents/materials/M_Magenta.lmas'"));
      await ok('new_level', {'name': 'L_Other', 'template': 'empty'});
      await rec.hold(const Duration(milliseconds: 600));
      await ok('open_level', {'level': project.activeLevel});
      await ok('set_camera', {'distance': 900.0, 'pitch': 20.0, 'target': ahead(0)});
      await rec.hold(const Duration(milliseconds: 1500));
      final reopened = imageOf(await ok('viewport_screenshot'), 'level_mesh_material_viewport_reopened');
      final magentaReopened = magentaPixels(reopened);
      debugPrint('[level_mesh_material_smoke] reopened level magenta pixels: $magentaReopened');
      expect(magentaReopened, greaterThan(magentaBefore + 400), reason: 'the reopened level still draws the material');

      // --- Play: the game camera sees the magenta barrel beside the yellow one -
      await ok('start_pie');
      for (var i = 0; i < 150 && (await ok('pie_status')).data['runtime_mounted'] != true; i++) {
        await rec.hold(const Duration(milliseconds: 100));
      }
      final played = await ok('pie_play_for', {'ms': 1500, 'screenshot': true});
      final playShot = imageOf(played, 'level_mesh_material_play');
      final magentaPlay = magentaPixels(playShot);
      debugPrint('[level_mesh_material_smoke] Play magenta pixels: $magentaPlay');
      expect(magentaPlay, greaterThan(400), reason: 'Play draws the assigned material');
      await ok('stop_pie');
      await rec.hold(const Duration(milliseconds: 500));

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

const String _tintMaterial = '''
material {
    name : "M_Magenta",
    shadingModel : lit,
    parameters : [
        { type : float4, name : tint },
        { type : float, name : roughness, default : 0.6 }
    ],
}

fragment {
    void material(inout MaterialInputs material) {
        prepareMaterial(material);
        material.baseColor = materialParams.tint;
        material.roughness = materialParams.roughness;
    }
}
''';
