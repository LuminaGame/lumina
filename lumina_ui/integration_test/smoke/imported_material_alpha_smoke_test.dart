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

/// Imported glTF materials keep their sides and alpha mode once compiled: on a
/// real Third Person project an MCP client imports five 2 m cards (glTF files
/// written for the test) and the fuel barrel from test-assets: a red
/// single-sided board, a green double-sided leaf, a blue double-sided glass
/// (`BLEND`, alpha 0.35) half in front of the leaf, and two `MASK` cards at
/// cutoff 0.5 (orange alpha 0.6, magenta alpha 0.3). Each card's imported
/// material is compiled with matc, saved and assigned to its placed card. From
/// the front every card but the magenta one draws and the leaf shows through
/// the glass; from behind the leaf and the glass still draw while the
/// single-sided board is culled.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const scenario = 'Imported materials: double-sided, masked and transparent glTF materials draw as the glTF says';
  testWidgets(scenario, (tester) async {
    final barrel = File('${SmokeArtifacts.testAssetsDir.path}/Props/Barrels/fuel_barrel_yellow.glb');
    expect(barrel.existsSync(), isTrue, reason: 'test-assets must hold the yellow fuel barrel');
    final usedAssets = [barrel.path];

    final root = Directory.systemTemp.createTempSync('lumina_smoke_impmat_');
    const name = 'smoke_imported_material';
    final projectDir = (await tester.runAsync(() => scaffoldGameProject(root, name: name, widgetLibrary: 'flutter')))!;
    final project = LuminaProject.fromMap(
        Map<String, dynamic>.from(jsonDecode(File('$projectDir/$name.lmproject').readAsStringSync()) as Map));
    final vm = EditorViewModel(initialProject: project, projectLocation: root.path);
    await tester.runAsync(vm.ensureDefaultLevelAssets);

    // The cards, one glTF material each.
    final cards = <String, Map<String, Object?>>{
      'BoardMat': {
        'pbrMetallicRoughness': {'baseColorFactor': [0.9, 0.05, 0.05, 1.0], 'metallicFactor': 0.0, 'roughnessFactor': 0.7},
      },
      'LeafMat': {
        'doubleSided': true,
        'pbrMetallicRoughness': {'baseColorFactor': [0.08, 0.8, 0.08, 1.0], 'metallicFactor': 0.0, 'roughnessFactor': 0.7},
      },
      'GlassMat': {
        'doubleSided': true,
        'alphaMode': 'BLEND',
        'pbrMetallicRoughness': {'baseColorFactor': [0.05, 0.1, 1.0, 0.35], 'metallicFactor': 0.0, 'roughnessFactor': 0.3},
      },
      'KeepMat': {
        'alphaMode': 'MASK',
        'pbrMetallicRoughness': {'baseColorFactor': [0.95, 0.45, 0.02, 0.6], 'metallicFactor': 0.0, 'roughnessFactor': 0.7},
      },
      'CutMat': {
        'alphaMode': 'MASK',
        'pbrMetallicRoughness': {'baseColorFactor': [0.9, 0.05, 0.8, 0.3], 'metallicFactor': 0.0, 'roughnessFactor': 0.7},
      },
    };
    final src = Directory('${root.path}/cards')..createSync();
    for (final e in cards.entries) {
      final card = e.key.replaceAll('Mat', '').toLowerCase();
      final file = File('${src.path}/card_$card.glb')..writeAsBytesSync(_cardGlb({'name': e.key, ...e.value}));
      await tester.runAsync(() => vm.processImportPipeline(sourceFilePath: file.path));
    }
    await tester.runAsync(() => vm.processImportPipeline(sourceFilePath: barrel.path));
    RealAssetInfo meshOf(String fileName) =>
        vm.realAssets.firstWhere((a) => a.type == AssetType.filamesh && a.fileName.contains(fileName));
    RealAssetInfo materialOf(String matName) =>
        vm.realAssets.firstWhere((a) => a.type == AssetType.filamat && a.fileName.contains(matName));

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

      /// Pixels (every second one) whose hue lies in [from, to] degrees, with
      /// at least [minSaturation] and [minValue]: the lit, tone-mapped card
      /// colours keep their hue.
      int hue(img.Image frame, double from, double to, {double minSaturation = 0.35, double minValue = 0.3}) {
        var n = 0;
        for (var y = 0; y < frame.height; y += 2) {
          for (var x = 0; x < frame.width; x += 2) {
            final p = frame.getPixel(x, y);
            final r = p.r / 255, g = p.g / 255, b = p.b / 255;
            final max = [r, g, b].reduce(math.max), min = [r, g, b].reduce(math.min);
            if (max <= 0 || max < minValue || (max - min) / max < minSaturation) continue;
            final d = max - min;
            var h = max == r ? 60 * (((g - b) / d) % 6) : max == g ? 60 * ((b - r) / d + 2) : 60 * ((r - g) / d + 4);
            if (h < 0) h += 360;
            if (from <= to ? (h >= from && h <= to) : (h >= from || h <= to)) n++;
          }
        }
        return n;
      }

      int red(img.Image f) => hue(f, 345, 15);
      int green(img.Image f) => hue(f, 85, 150, minValue: 0.2);
      // The green leaf seen through the blue glass.
      int teal(img.Image f) => hue(f, 150, 195, minSaturation: 0.25);
      int keep(img.Image f) => hue(f, 25, 60, minSaturation: 0.4, minValue: 0.4);
      int magenta(img.Image f) => hue(f, 280, 335, minSaturation: 0.3);

      await tester.runAsync(() => client.handshake(clientName: 'claude-code'));

      // --- Compile and save every imported card material --------------------
      for (final mat in cards.keys) {
        final asset = materialOf(mat).relativePath;
        final compiled = await call('compile_material', {'asset': asset, 'save': true});
        expect(compiled.data['ok'], isTrue, reason: '$mat: ${compiled.text}');
      }
      await ok('select_tab', {'index': 0});
      await rec.hold(const Duration(milliseconds: 600));

      // --- The cards in a row 6 m ahead of the player start, facing −Y -------
      final start = vm.actors.firstWhere((a) => a.type == 'PlayerStart');
      final p = [start.location[0], start.location[1] + 600, 0.0];
      List<double> at(double dx, double dy) => [p[0] + dx, p[1] + dy, p[2]];
      final placements = <String, List<double>>{
        'BoardMat': at(-330, 0),
        'LeafMat': at(0, 0),
        'GlassMat': at(110, -90),
        'KeepMat': at(560, 0),
        'CutMat': at(800, 0),
      };
      for (final e in placements.entries) {
        final card = e.key.replaceAll('Mat', '').toLowerCase();
        await ok('spawn_actor_from_asset', {'asset': meshOf('card_$card').relativePath, 'location': e.value});
        final actor = vm.actors.last;
        final assigned = await ok('set_actor_property', {
          'id': actor.id,
          'property': 'material',
          'value': materialOf(e.key).relativePath,
        });
        expect(assigned.data['material_warning'], isNull, reason: assigned.text);
      }
      await ok('spawn_actor_from_asset', {'asset': meshOf('fuel_barrel_yellow').relativePath, 'location': at(330, 60)});
      await call('select_actors', {'ids': <String>[]});

      // --- Front (yaw 0, from −Y), side and back (yaw 180) ------------------
      final target = at(230, 0)..[2] = 100;
      Future<img.Image> view(double yaw, String artifact) async {
        await ok('set_camera', {'distance': 1500.0, 'pitch': 6.0, 'yaw': yaw, 'target': target});
        await rec.hold(const Duration(milliseconds: 1500));
        return imageOf(await ok('viewport_screenshot'), artifact);
      }

      final front = await view(0, 'imported_material_alpha_front');
      // Edge-on: the cards vanish, what stays is the editor's own colour.
      final side = await view(90, 'imported_material_alpha_side');
      final back = await view(180, 'imported_material_alpha_back');
      String counts(img.Image f) =>
          'red ${red(f)} green ${green(f)} teal ${teal(f)} keep ${keep(f)} magenta ${magenta(f)}';
      debugPrint('[imported_material_alpha_smoke] front: ${counts(front)}');
      debugPrint('[imported_material_alpha_smoke] side: ${counts(side)}');
      debugPrint('[imported_material_alpha_smoke] back: ${counts(back)}');

      expect(red(front) - red(side), greaterThan(500), reason: 'the single-sided board draws from the front');
      expect(red(back) - red(side), lessThan(60), reason: 'the single-sided board is culled from behind');
      expect(green(front), greaterThan(200), reason: 'the leaf draws from the front');
      expect(green(back), greaterThan(200), reason: 'the double-sided leaf still draws from behind');
      expect(teal(front), greaterThan(250), reason: 'the leaf shows through the transparent glass');
      expect(keep(front) - keep(side), greaterThan(500), reason: 'the masked card above its cutoff draws');
      expect(magenta(front) + magenta(back), lessThan(40), reason: 'the masked card below its cutoff is cut away');

      for (var i = 0; i < 60 && rec.recorded < const Duration(milliseconds: 10300); i++) {
        await call('set_camera', {'yaw': 12.0 * (i + 1)});
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

/// A real GLB: one 2 m × 2 m card standing on the ground, facing +Z (glTF),
/// drawn with [material].
Uint8List _cardGlb(Map<String, Object?> material) {
  final bin = BytesBuilder()
    ..add(Float32List.fromList([-1, 0, 0, 1, 0, 0, 1, 2, 0, -1, 2, 0]).buffer.asUint8List())
    ..add(Float32List.fromList([0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1]).buffer.asUint8List())
    ..add(Uint16List.fromList([0, 1, 2, 0, 2, 3]).buffer.asUint8List());
  while (bin.length % 4 != 0) {
    bin.addByte(0);
  }
  final json = {
    'asset': {'version': '2.0'},
    'scene': 0,
    'scenes': [
      {'nodes': [0]},
    ],
    'nodes': [
      {'mesh': 0, 'name': 'Card'},
    ],
    'meshes': [
      {
        'name': 'Card',
        'primitives': [
          {'attributes': {'POSITION': 0, 'NORMAL': 1}, 'indices': 2, 'material': 0},
        ],
      },
    ],
    'materials': [material],
    'buffers': [
      {'byteLength': bin.length},
    ],
    'bufferViews': [
      {'buffer': 0, 'byteOffset': 0, 'byteLength': 48, 'target': 34962},
      {'buffer': 0, 'byteOffset': 48, 'byteLength': 48, 'target': 34962},
      {'buffer': 0, 'byteOffset': 96, 'byteLength': 12, 'target': 34963},
    ],
    'accessors': [
      {'bufferView': 0, 'componentType': 5126, 'count': 4, 'type': 'VEC3', 'min': [-1, 0, 0], 'max': [1, 2, 0]},
      {'bufferView': 1, 'componentType': 5126, 'count': 4, 'type': 'VEC3'},
      {'bufferView': 2, 'componentType': 5123, 'count': 6, 'type': 'SCALAR'},
    ],
  };
  final jsonChunk = BytesBuilder()..add(utf8.encode(jsonEncode(json)));
  while (jsonChunk.length % 4 != 0) {
    jsonChunk.addByte(0x20);
  }
  final jsonBytes = jsonChunk.toBytes();
  final binBytes = bin.toBytes();
  ByteData word2(int a, int b) => ByteData(8)
    ..setUint32(0, a, Endian.little)
    ..setUint32(4, b, Endian.little);
  return (BytesBuilder()
        ..add(word2(0x46546C67, 2).buffer.asUint8List())
        ..add((ByteData(4)..setUint32(0, 12 + 8 + jsonBytes.length + 8 + binBytes.length, Endian.little)).buffer.asUint8List())
        ..add(word2(jsonBytes.length, 0x4E4F534A).buffer.asUint8List())
        ..add(jsonBytes)
        ..add(word2(binBytes.length, 0x004E4942).buffer.asUint8List())
        ..add(binBytes))
      .toBytes();
}
