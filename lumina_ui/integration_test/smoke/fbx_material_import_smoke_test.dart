import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/main_editor/views/viewport_widget.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Smoke — an FBX's materials and textures in the editor.
///
/// Boots the real Lumina Studio on a real project, imports the Unreal-exported
/// `SM_Slot_Machine.FBX` twice through the editor's import pipeline — once as
/// it is in `test-assets` (no texture anywhere near it: the materials keep
/// the FBX's own colours, a Phong-derived roughness, and the missing normal
/// map is named in the Output Log), once as a copy with the slot machine's
/// textures dropped next to it (the referenced tread-plate normal map and
/// the neon-green / display emissive and matte normal maps matched to their
/// materials by name) — places both side by side in the level and orbits the
/// Filament level viewport around them. Pixel colours are measured in each
/// machine's half of the viewport: only the textured one shows neon green and
/// the display's warm, saturated image. PNGs of the front and back views plus
/// a WebM of the whole scenario.
///
/// Runs on GPU 1 (NVIDIA RTX PRO 2000) — `tool/smoke_report.dart` injects the
/// GPU environment.
Future<void> _settle(WidgetTester tester, [int frames = 10]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
  }
}

/// Pixel counts of [rect] in a PNG frame: neon-green tint (green above red
/// and blue by 10 %: the neon trims are thin and their green emission rides
/// on the FBX's default 0.8 grey base, so it reads as a pale green) and warm saturated colour (the display's gold/orange/red).
class _Colours {
  final int green;
  final int warm;
  final int total;
  final List<double> mean;
  const _Colours(this.green, this.warm, this.total, this.mean);

  @override
  String toString() =>
      'green $green, warm $warm of $total px, mean RGB ${mean.map((c) => c.toStringAsFixed(0)).join('/')}';
}

Future<_Colours> _measure(WidgetTester tester, Uint8List png, Rect rect) async {
  return (await tester.runAsync(() async {
    final codec = await ui.instantiateImageCodec(png);
    final frame = await codec.getNextFrame();
    final data = (await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final width = frame.image.width;
    frame.image.dispose();
    var green = 0, warm = 0, total = 0;
    final sum = [0.0, 0.0, 0.0];
    for (var y = rect.top.toInt(); y < rect.bottom.toInt(); y++) {
      for (var x = rect.left.toInt(); x < rect.right.toInt(); x++) {
        final o = (y * width + x) * 4;
        final r = data.getUint8(o), g = data.getUint8(o + 1), b = data.getUint8(o + 2);
        sum[0] += r;
        sum[1] += g;
        sum[2] += b;
        total++;
        if (g > 120 && g > r * 1.1 && g > b * 1.1) green++;
        if (r > 140 && r > b * 1.6 && (r - b) > 70) warm++;
      }
    }
    return _Colours(green, warm, total, [for (final s in sum) total == 0 ? 0.0 : s / total]);
  }))!;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const fbxRel = 'FBX/StaticMeshes/SM_Slot_Machine.FBX';
  const texturesRel = 'FBX/TextureFixtures/SM_Slot_Machine';
  const usedAssets = [fbxRel, '$texturesRel/ (4 textures, see test-assets/FBX/README.md)'];
  const testName = 'FBX Material Import Smoke: SM_Slot_Machine without and with its textures (neon green, display emissive)';

  testWidgets(testName, (tester) async {
    final assets = SmokeArtifacts.testAssetsDir.path;
    final fbx = File('$assets/$fbxRel');
    final textures = Directory('$assets/$texturesRel');
    if (!fbx.existsSync() || !textures.existsSync()) {
      markTestSkipped('test asset missing: $fbxRel or $texturesRel');
      return;
    }
    final root = Directory.systemTemp.createTempSync('fbx_material_smoke_');
    EditorViewModel? vm;
    try {
      final pDir = Directory('${root.path}/FbxMaterials')..createSync(recursive: true);
      const project = LuminaProject(projectName: 'FbxMaterials', activeLevel: 'contents/levels/L_Main.lmas');
      File('${pDir.path}/FbxMaterials.lmproject').writeAsStringSync(jsonEncode(project.toMap()));

      // The textured copy: the FBX with the textures dropped next to it.
      final source = Directory('${root.path}/source')..createSync();
      final texturedFbx = fbx.copySync('${source.path}/SM_Slot_Machine_Textured.FBX');
      for (final f in textures.listSync().whereType<File>()) {
        f.copySync('${source.path}/${f.uri.pathSegments.last}');
      }

      vm = EditorViewModel(initialProject: project, projectLocation: root.path, enableTimers: false);
      final editor = vm;
      await tester.runAsync(() => editor.ensureDefaultLevelAssets());

      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final boundaryKey = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: boundaryKey,
        child: ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: editor)),
      ));
      await _settle(tester, 40);
      final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
      await rec.hold(const Duration(seconds: 1));

      Future<void> importWhileRecording(String path) async {
        var done = false;
        final importing = editor.processImportPipeline(sourceFilePath: path).whenComplete(() => done = true);
        while (!done) {
          await rec.hold(const Duration(milliseconds: 100));
        }
        await importing;
      }

      // 1. Without textures: FBX colours + Phong roughness, missing map warned.
      final logStart = EngineLoggerService().logs.length;
      await importWhileRecording(fbx.path);
      final warnings = [
        for (final e in EngineLoggerService().logs.skip(logStart))
          if (e.level == 'warning' && e.message.contains('T_Tread_Plate_Normal.png')) e.message,
      ];
      expect(warnings, hasLength(1), reason: 'the missing normal map is named in the Output Log');
      expect(warnings.single, contains('M_Rubber_Foot_Rest'));
      LuminaAsset material(String mesh, String name) =>
          LuminaAsset.fromBytes(File('${pDir.path}/contents/materials/$mesh/$name.lmas').readAsBytesSync());
      final plain = material('SM_Slot_Machine', 'M_Neon_Green');
      expect(plain.metadata['baseColor'], startsWith('0.8'));
      expect(double.parse(plain.metadata['roughness']!), closeTo(0.549, 0.001));
      expect(plain.references, isEmpty);

      // 2. With the textures next to the FBX.
      await importWhileRecording(texturedFbx.path);
      final neon = material('SM_Slot_Machine_Textured', 'M_Neon_Green');
      expect(neon.references.single.slotName, 'emissiveMap');
      expect(neon.references.single.assetPath, 'contents/textures/SM_Slot_Machine_Textured/T_Neon_Green_Emissive.lmas');
      expect(material('SM_Slot_Machine_Textured', 'M_Display_1').references.single.slotName, 'emissiveMap');
      expect(material('SM_Slot_Machine_Textured', 'M_Rubber_Foot_Rest').references.single.assetPath,
          'contents/textures/SM_Slot_Machine_Textured/T_Tread_Plate_Normal.lmas');
      final normal = LuminaAsset.fromBytes(File(
              '${pDir.path}/contents/textures/SM_Slot_Machine_Textured/T_Plastic_Black_Matte_1_Normal.lmas')
          .readAsBytesSync());
      expect((jsonDecode(normal.metadata['texture_settings']!) as Map)['srgb'], isFalse, reason: 'normal maps are linear');
      editor.refreshAssets();
      await rec.hold(const Duration(milliseconds: 500));

      // 3. Both in the level, 1.4 m apart: plain at −X, textured at +X.
      Future<void> place(String name, List<double> at) async {
        final asset = editor.realAssets.firstWhere(
          (a) => a.fileName == '$name.lmas' && a.type == AssetType.filamesh,
          orElse: () => throw StateError('$name produced no static mesh asset'),
        );
        await tester.runAsync(() => editor.spawnActorFromAsset(asset, location: at));
        await rec.hold(const Duration(milliseconds: 600));
      }

      await place('SM_Slot_Machine', [-70.0, 0.0, 0.0]);
      await place('SM_Slot_Machine_Textured', [70.0, 0.0, 0.0]);
      editor.selectActor(null);

      // Camera: [yaw, pitch, distance, target x, y, z]. Yaw 0 looks along +Y
      // with +X to the right; yaw 180 from the other side, +X on the left.
      Future<void> orbitTo(double yaw, {double from = 0, int steps = 45}) async {
        for (var i = 1; i <= steps; i++) {
          final t = i / steps;
          editor.restoreCameraSnapshot([from + (yaw - from) * t, 6.0, 470.0, 0.0, 0.0, 130.0]);
          await rec.hold(const Duration(milliseconds: 60));
        }
        await rec.hold(const Duration(milliseconds: 1200));
      }

      final viewport = tester.getRect(find.byType(ViewportWidget)).deflate(24);
      final left = Rect.fromLTRB(viewport.left, viewport.top, viewport.center.dx - 8, viewport.bottom);
      final right = Rect.fromLTRB(viewport.center.dx + 8, viewport.top, viewport.right, viewport.bottom);
      final results = <String, (_Colours, _Colours)>{}; // view → (plain, textured)
      editor.restoreCameraSnapshot([-40.0, 6.0, 470.0, 0.0, 0.0, 130.0]);
      await rec.hold(const Duration(milliseconds: 800));
      for (final (view, yaw, from) in [('front', 0.0, -40.0), ('back', 180.0, 0.0)]) {
        await orbitTo(yaw, from: from);
        final png = await SmokeArtifacts.captureWidgetPng(tester, find.byKey(boundaryKey));
        SmokeArtifacts.saveScreenshot('fbx_material_import_slot_machines_$view', png, usedAssets: usedAssets);
        final a = await _measure(tester, png, left);
        final b = await _measure(tester, png, right);
        // +X (textured) is on the right from the front, on the left from the back.
        results[view] = yaw == 0 ? (a, b) : (b, a);
      }
      for (final e in results.entries) {
        // ignore: avoid_print
        print('[fbx_material_smoke] ${e.key}: plain ${e.value.$1} | textured ${e.value.$2}');
      }

      final plainGreen = results.values.map((r) => r.$1.green).reduce((x, y) => x > y ? x : y);
      final texturedGreen = results.values.map((r) => r.$2.green).reduce((x, y) => x > y ? x : y);
      final plainWarm = results.values.map((r) => r.$1.warm).reduce((x, y) => x > y ? x : y);
      final texturedWarm = results.values.map((r) => r.$2.warm).reduce((x, y) => x > y ? x : y);
      expect(texturedGreen, greaterThan(20), reason: 'the textured machine shows its neon green (emissive map) on the display trims');
      expect(plainGreen, lessThan(texturedGreen ~/ 10), reason: 'the FBX alone carries no green: grey 0.8 neon');
      expect(texturedWarm, greaterThan(200), reason: 'the display emits its warm, saturated image');
      expect(plainWarm, lessThan(texturedWarm ~/ 5), reason: 'without the texture the display is the FBX dark grey');

      // Back to the front for the end of the video.
      await orbitTo(360.0, from: 180.0);
      expect(rec.recorded, greaterThanOrEqualTo(const Duration(seconds: 10)));
      rec.save(testName, usedAssets: usedAssets);
    } finally {
      vm?.dispose();
      if (root.existsSync()) root.deleteSync(recursive: true);
    }
  });
}
