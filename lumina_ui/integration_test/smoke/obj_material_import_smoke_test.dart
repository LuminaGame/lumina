import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/main_editor/views/viewport_widget.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Smoke — an OBJ's MTL colours and texture maps in the editor.
///
/// Boots the real Lumina Studio on a real project and imports two OBJ files
/// through the editor's import pipeline: Filament's Cornell box
/// (`cornell_box.obj` + `cornell_box.mtl`: white, red and green `Kd` walls)
/// and a 1 m crate whose MTL (`Textured Crate.mtl`, a name with a space)
/// points at `textures/Banana Peel.png` — the base colour image of the real
/// `banana_bunch_medium.glb` from test-assets, written next to the OBJ —
/// with a capitalisation that differs from the file on disk. Both are placed
/// in the level and the Filament viewport orbits them: the box shows its red
/// and green walls, the crate the banana-yellow texture. PNGs of the front and
/// back views plus a WebM of the whole scenario.
///
/// Runs on GPU 1 (NVIDIA RTX PRO 2000) — `tool/smoke_report.dart` injects the
/// GPU environment.
Future<void> _settle(WidgetTester tester, [int frames = 10]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
  }
}

/// Pixel counts of [rect] in a PNG frame: the Cornell box's red and green
/// walls, and the banana texture's warm olive/yellow (red and green above
/// blue; the sky, the grid and an untextured grey all lean blue here).
class _Colours {
  final int red;
  final int green;
  final int banana;
  final int total;
  const _Colours(this.red, this.green, this.banana, this.total);

  @override
  String toString() => 'red $red, green $green, banana $banana of $total px';
}

Future<_Colours> _measure(WidgetTester tester, Uint8List png, Rect rect) async {
  return (await tester.runAsync(() async {
    final codec = await ui.instantiateImageCodec(png);
    final frame = await codec.getNextFrame();
    final data = (await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final width = frame.image.width;
    frame.image.dispose();
    var red = 0, green = 0, banana = 0, total = 0;
    for (var y = rect.top.toInt(); y < rect.bottom.toInt(); y++) {
      for (var x = rect.left.toInt(); x < rect.right.toInt(); x++) {
        final o = (y * width + x) * 4;
        final r = data.getUint8(o), g = data.getUint8(o + 1), b = data.getUint8(o + 2);
        total++;
        if (r > 55 && r > g * 1.6 && r > b * 1.4) red++;
        if (g > 45 && g > r * 1.4 && g > b * 1.4) green++;
        if (g > 40 && r > 35 && b < g * 0.85 && b < r * 0.95 && r < g * 1.3) banana++;
      }
    }
    return _Colours(red, green, banana, total);
  }))!;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const bananaRel = 'Props/Banana Bunch/banana_bunch_medium.glb';
  const cornellRel = 'filament/assets/models/cornell_box/cornell_box.obj';
  const usedAssets = [cornellRel, 'filament/assets/models/cornell_box/cornell_box.mtl', '$bananaRel (base colour image)'];
  const testName = 'OBJ Material Import Smoke: Cornell box MTL colours and a textured OBJ crate';

  testWidgets(testName, (tester) async {
    final cornell = File('${Directory.current.parent.path}/$cornellRel');
    final banana = File('${SmokeArtifacts.testAssetsDir.path}/$bananaRel');
    if (!cornell.existsSync() || !banana.existsSync()) {
      markTestSkipped('asset missing: $cornellRel or $bananaRel');
      return;
    }
    final root = Directory.systemTemp.createTempSync('obj_material_smoke_');
    EditorViewModel? vm;
    try {
      final pDir = Directory('${root.path}/ObjMaterials')..createSync(recursive: true);
      const project = LuminaProject(projectName: 'ObjMaterials', activeLevel: 'contents/levels/L_Main.lmas');
      File('${pDir.path}/ObjMaterials.lmproject').writeAsStringSync(jsonEncode(project.toMap()));

      // The OBJ files as they come: the Cornell box with its MTL, and a crate
      // with its MTL and the texture in a subfolder.
      final source = Directory('${root.path}/source files')..createSync();
      cornell.copySync('${source.path}/cornell_box.obj');
      File('${cornell.parent.path}/cornell_box.mtl').copySync('${source.path}/cornell_box.mtl');
      final glb = GlbDocument.parse(banana.readAsBytesSync(), label: 'banana');
      final material = (glb.json['materials'] as List).cast<Map>().first;
      final texture = (glb.json['textures'] as List)[(material['pbrMetallicRoughness']['baseColorTexture'] as Map)['index'] as int] as Map;
      final imageIndex = (texture['source'] ?? (texture['extensions'] as Map)['EXT_texture_webp']['source']) as int;
      final image = (glb.json['images'] as List)[imageIndex] as Map;
      final view = (glb.json['bufferViews'] as List)[image['bufferView'] as int] as Map;
      final offset = view['byteOffset'] as int? ?? 0;
      // The GLB stores it as WebP; an MTL names PNG / JPEG / TGA files.
      final png = img.encodePng(img.decodeImage(glb.bin.sublist(offset, offset + (view['byteLength'] as int)))!);
      File('${source.path}/textures/banana peel.png')
        ..parent.createSync()
        ..writeAsBytesSync(png);
      File('${source.path}/Textured Crate.mtl').writeAsStringSync('newmtl Crate\nKd 1 1 1\nmap_Kd textures/Banana Peel.png\n');
      final crate = StringBuffer('mtllib Textured Crate.mtl\n');
      // A 1 m cube standing on the ground, each face mapped to the whole image.
      const corners = [
        [-0.5, 0, -0.5], [0.5, 0, -0.5], [0.5, 1, -0.5], [-0.5, 1, -0.5],
        [-0.5, 0, 0.5], [0.5, 0, 0.5], [0.5, 1, 0.5], [-0.5, 1, 0.5],
      ];
      for (final c in corners) {
        crate.writeln('v ${c[0]} ${c[1]} ${c[2]}');
      }
      crate.write('vt 0 0\nvt 1 0\nvt 1 1\nvt 0 1\n');
      crate.write('vn 0 0 -1\nvn 0 0 1\nvn -1 0 0\nvn 1 0 0\nvn 0 -1 0\nvn 0 1 0\nusemtl Crate\n');
      const faces = [
        ([2, 1, 4, 3], 1), ([5, 6, 7, 8], 2), ([1, 5, 8, 4], 3), ([6, 2, 3, 7], 4), ([1, 2, 6, 5], 5), ([8, 7, 3, 4], 6),
      ];
      for (final (v, n) in faces) {
        crate.writeln('f ${v[0]}/1/$n ${v[1]}/2/$n ${v[2]}/3/$n ${v[3]}/4/$n');
      }
      final crateObj = File('${source.path}/Textured Crate.obj')..writeAsStringSync(crate.toString());

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

      final logStart = EngineLoggerService().logs.length;
      await importWhileRecording('${source.path}/cornell_box.obj');
      await importWhileRecording(crateObj.path);
      final warnings = [
        for (final e in EngineLoggerService().logs.skip(logStart))
          if (e.level == 'warning' && e.message.startsWith('OBJ')) e.message,
      ];
      expect(warnings, isEmpty, reason: 'every MTL and texture was found');

      final materials = {
        for (final f in Directory('${pDir.path}/contents').listSync(recursive: true).whereType<File>())
          if (f.path.endsWith('.lmas'))
            for (final a in [LuminaAsset.fromBytes(f.readAsBytesSync())])
              if (a.type == AssetType.filamat) a.name: a,
      };
      expect(materials['M_cornell_box_red']!.metadata['baseColor'], startsWith('0.63'));
      expect(materials['M_cornell_box_green']!.metadata['baseColor'], startsWith('0.14'));
      final crateMaterial = materials.values.singleWhere((m) => m.name.endsWith('Crate'));
      expect(crateMaterial.references.single.slotName, 'baseColorMap');
      editor.refreshAssets();
      await rec.hold(const Duration(milliseconds: 500));

      // Both in the level: the box at −X, the crate at +X.
      final meshes = editor.realAssets.where((a) => a.type == AssetType.filamesh).toList();
      await tester.runAsync(() => editor.spawnActorFromAsset(
          meshes.firstWhere((a) => a.fileName == 'cornell_box.lmas'), location: [-160.0, 0.0, 0.0]));
      await rec.hold(const Duration(milliseconds: 600));
      await tester.runAsync(() => editor.spawnActorFromAsset(
          meshes.firstWhere((a) => a.fileName.contains('Crate')), location: [140.0, 0.0, 0.0]));
      await rec.hold(const Duration(milliseconds: 600));
      editor.selectActor(null);

      // Camera: [yaw, pitch, distance, target x, y, z]. Yaw 0 looks along +Y
      // with +X to the right; yaw 180 from the other side, +X on the left.
      Future<void> orbitTo(double yaw, {double from = 0, int steps = 45, List<double> target = const [0.0, 0.0, 90.0], double distance = 620}) async {
        for (var i = 1; i <= steps; i++) {
          final t = i / steps;
          editor.restoreCameraSnapshot([from + (yaw - from) * t, 8.0, distance, ...target]);
          await rec.hold(const Duration(milliseconds: 60));
        }
        await rec.hold(const Duration(milliseconds: 1200));
      }

      final viewport = tester.getRect(find.byType(ViewportWidget)).deflate(24);
      final left = Rect.fromLTRB(viewport.left, viewport.top, viewport.center.dx - 8, viewport.bottom);
      final right = Rect.fromLTRB(viewport.center.dx + 8, viewport.top, viewport.right, viewport.bottom);
      final results = <String, (_Colours, _Colours)>{}; // view → (box, crate)
      editor.restoreCameraSnapshot([-40.0, 8.0, 620.0, 0.0, 0.0, 90.0]);
      await rec.hold(const Duration(milliseconds: 800));
      for (final (view, yaw, from) in [('front', 0.0, -40.0), ('back', 180.0, 0.0)]) {
        await orbitTo(yaw, from: from);
        final png = await SmokeArtifacts.captureWidgetPng(tester, find.byKey(boundaryKey));
        SmokeArtifacts.saveScreenshot('obj_material_import_$view', png, usedAssets: usedAssets);
        final a = await _measure(tester, png, left);
        final b = await _measure(tester, png, right);
        results[view] = yaw == 0 ? (a, b) : (b, a);
      }
      // The box's walls face inwards: each side wall shows from the other side.
      const box = [-160.0, 0.0, 100.0];
      final boxViews = <String, _Colours>{};
      var from = 180.0;
      for (final (view, yaw) in [('box_side_a', 90.0), ('box_side_b', 270.0)]) {
        await orbitTo(yaw, from: from, target: box, distance: 420);
        from = yaw;
        final png = await SmokeArtifacts.captureWidgetPng(tester, find.byKey(boundaryKey));
        SmokeArtifacts.saveScreenshot('obj_material_import_$view', png, usedAssets: usedAssets);
        boxViews[view] = await _measure(tester, png, viewport);
      }
      for (final e in results.entries) {
        // ignore: avoid_print
        print('[obj_material_smoke] ${e.key}: box ${e.value.$1} | crate ${e.value.$2}');
      }
      for (final e in boxViews.entries) {
        // ignore: avoid_print
        print('[obj_material_smoke] ${e.key}: ${e.value}');
      }
      int best(Iterable<int> counts) => counts.reduce((x, y) => x > y ? x : y);
      final boxCounts = [...results.values.map((r) => r.$1), ...boxViews.values];
      expect(best(boxCounts.map((c) => c.red)), greaterThan(2000), reason: 'the Cornell box shows its red MTL wall');
      expect(best(boxCounts.map((c) => c.green)), greaterThan(2000), reason: 'the Cornell box shows its green MTL wall');
      expect(best(results.values.map((r) => r.$2.banana)), greaterThan(2000),
          reason: 'the crate shows the banana texture its MTL names');
      expect(best(results.values.map((r) => r.$1.banana)), lessThan(best(results.values.map((r) => r.$2.banana)) ~/ 5),
          reason: 'the untextured box has none of the texture colour');

      await orbitTo(360.0, from: 270.0);
      expect(rec.recorded, greaterThanOrEqualTo(const Duration(seconds: 10)));
      rec.save(testName, usedAssets: usedAssets);
    } finally {
      vm?.dispose();
      if (root.existsSync()) root.deleteSync(recursive: true);
    }
  });
}
