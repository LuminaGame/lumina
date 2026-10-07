import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
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

/// Smoke — Collada and 3DS models with external textures in the editor.
///
/// Boots the real Lumina Studio on a real project and imports two models
/// written from real test-assets meshes, each with its base colour image kept
/// as a separate file the way those formats ship:
///
/// - `Jerry Can.dae` (Collada, the geometry and UVs of
///   `Props/JerryCan/jerrycan.glb`) whose `<init_from>` is
///   `Maps/JerryCan_BC.png`, the file on disk being `maps/jerrycan_bc.png`;
/// - `BANANA.3DS` (3DS, `Props/Banana Bunch/banana_bunch_medium.glb`) whose
///   material map is the 8.3 name `BANANA.PNG`, the file on disk being
///   `textures/Banana.png`.
///
/// Both go through the editor's import pipeline, together with the original
/// `jerrycan.glb` as a reference, are placed in the level and the Filament
/// viewport orbits them: the Collada can shows the same red paint as the
/// original, the banana bunch its yellow. PNGs of four views plus a WebM of
/// the whole scenario.
///
/// Runs on GPU 1 (NVIDIA RTX PRO 2000) — `tool/smoke_report.dart` injects the
/// GPU environment.
Future<void> _settle(WidgetTester tester, [int frames = 10]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
  }
}

/// Pixel counts in a frame: the jerry can texture's red paint and the banana
/// texture's warm olive / yellow. The sky, the grid and an untextured grey
/// have neither.
class _Colours {
  final int red;
  final int banana;
  final int total;

  /// Mean colour of the region, 0..255.
  final List<double> mean;
  const _Colours(this.red, this.banana, this.total, this.mean);

  double distanceTo(_Colours o) {
    var d = 0.0;
    for (var i = 0; i < 3; i++) {
      d += (mean[i] - o.mean[i]) * (mean[i] - o.mean[i]);
    }
    return math.sqrt(d);
  }

  @override
  String toString() => 'red $red, banana $banana of $total px, mean ${mean.map((v) => v.toStringAsFixed(1)).join('/')}';
}

Future<_Colours> _measure(WidgetTester tester, Uint8List png, Rect rect) async {
  return (await tester.runAsync(() async {
    final codec = await ui.instantiateImageCodec(png);
    final frame = await codec.getNextFrame();
    final data = (await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final width = frame.image.width;
    frame.image.dispose();
    var red = 0, banana = 0, total = 0;
    final sum = [0.0, 0.0, 0.0];
    for (var y = rect.top.toInt(); y < rect.bottom.toInt(); y++) {
      for (var x = rect.left.toInt(); x < rect.right.toInt(); x++) {
        final o = (y * width + x) * 4;
        final r = data.getUint8(o), g = data.getUint8(o + 1), b = data.getUint8(o + 2);
        total++;
        sum[0] += r;
        sum[1] += g;
        sum[2] += b;
        if (r > 20 && r > g * 1.6 && r > b * 1.4) red++;
        if (g > 40 && r > 35 && b < g * 0.85 && b < r * 0.95 && r < g * 1.3) banana++;
      }
    }
    return _Colours(red, banana, total, [for (final v in sum) v / total]);
  }))!;
}

/// The base colour image of a test-assets GLB, as PNG (they store WebP;
/// Collada and 3DS files name PNG / JPEG / TGA images).
Uint8List _baseColourPng(GlbDocument glb) {
  final material = (glb.json['materials'] as List).cast<Map>().first;
  final texture = (glb.json['textures'] as List)[(material['pbrMetallicRoughness']['baseColorTexture'] as Map)['index'] as int] as Map;
  final imageIndex = (texture['source'] ?? (texture['extensions'] as Map)['EXT_texture_webp']['source']) as int;
  final image = (glb.json['images'] as List)[imageIndex] as Map;
  final view = (glb.json['bufferViews'] as List)[image['bufferView'] as int] as Map;
  final offset = view['byteOffset'] as int? ?? 0;
  return img.encodePng(img.decodeImage(glb.bin.sublist(offset, offset + (view['byteLength'] as int)))!);
}

/// [mesh] as a Collada 1.4.1 document (metres, Y up) with one material
/// whose diffuse texture is [texture]. UVs are written with V up, as
/// Collada stores them.
String _collada(GlbMeshData mesh, String name, String texture) {
  final n = mesh.positions.length ~/ 3;
  final uv = [for (var i = 0; i < n; i++) ...[mesh.uvs[i * 2], 1 - mesh.uvs[i * 2 + 1]]];
  String floats(Iterable<double> v) => v.map((x) => x.toStringAsFixed(6)).join(' ');
  return '''<?xml version="1.0" encoding="utf-8"?>
<COLLADA xmlns="http://www.collada.org/2005/11/COLLADASchema" version="1.4.1">
  <asset><unit name="meter" meter="1"/><up_axis>Y_UP</up_axis></asset>
  <library_images><image id="diffuse_png" name="diffuse_png"><init_from>$texture</init_from></image></library_images>
  <library_effects><effect id="$name-fx"><profile_COMMON>
    <newparam sid="diffuse-surface"><surface type="2D"><init_from>diffuse_png</init_from></surface></newparam>
    <newparam sid="diffuse-sampler"><sampler2D><source>diffuse-surface</source></sampler2D></newparam>
    <technique sid="common"><lambert><diffuse><texture texture="diffuse-sampler" texcoord="UVMap"/></diffuse></lambert></technique>
  </profile_COMMON></effect></library_effects>
  <library_materials><material id="$name-mat" name="$name"><instance_effect url="#$name-fx"/></material></library_materials>
  <library_geometries><geometry id="$name-mesh" name="$name"><mesh>
    <source id="pos"><float_array id="pos-a" count="${n * 3}">${floats(mesh.positions)}</float_array>
      <technique_common><accessor source="#pos-a" count="$n" stride="3"><param name="X" type="float"/><param name="Y" type="float"/><param name="Z" type="float"/></accessor></technique_common></source>
    <source id="uv"><float_array id="uv-a" count="${n * 2}">${floats(uv)}</float_array>
      <technique_common><accessor source="#uv-a" count="$n" stride="2"><param name="S" type="float"/><param name="T" type="float"/></accessor></technique_common></source>
    <vertices id="verts"><input semantic="POSITION" source="#pos"/></vertices>
    <triangles material="$name" count="${mesh.indices.length ~/ 3}"><input semantic="VERTEX" source="#verts" offset="0"/><input semantic="TEXCOORD" source="#uv" offset="0" set="0"/>
      <p>${mesh.indices.join(' ')}</p></triangles>
  </mesh></geometry></library_geometries>
  <library_visual_scenes><visual_scene id="scene"><node id="$name-node" name="$name">
    <instance_geometry url="#$name-mesh"><bind_material><technique_common>
      <instance_material symbol="$name" target="#$name-mat"><bind_vertex_input semantic="UVMap" input_semantic="TEXCOORD" input_set="0"/></instance_material>
    </technique_common></bind_material></instance_geometry>
  </node></visual_scene></library_visual_scenes>
  <scene><instance_visual_scene url="#scene"/></scene>
</COLLADA>
''';
}

/// [mesh] as a binary 3DS file: Z up (the glTF Y axis becomes Z), V up, one
/// material named [name] whose texture map is [texture].
Uint8List _threeDs(GlbMeshData mesh, String name, String texture) {
  Uint8List chunk(int id, List<Uint8List> body) {
    final length = 6 + body.fold<int>(0, (n, b) => n + b.length);
    final head = ByteData(6)
      ..setUint16(0, id, Endian.little)
      ..setUint32(2, length, Endian.little);
    return Uint8List.fromList([...head.buffer.asUint8List(), for (final b in body) ...b]);
  }

  Uint8List cstr(String s) => Uint8List.fromList([...latin1.encode(s), 0]);
  Uint8List u16(List<int> v) {
    final d = ByteData(v.length * 2);
    for (var i = 0; i < v.length; i++) {
      d.setUint16(i * 2, v[i], Endian.little);
    }
    return d.buffer.asUint8List();
  }

  Uint8List u32(int v) => (ByteData(4)..setUint32(0, v, Endian.little)).buffer.asUint8List();
  Uint8List f32(List<double> v) {
    final d = ByteData(v.length * 4);
    for (var i = 0; i < v.length; i++) {
      d.setFloat32(i * 4, v[i], Endian.little);
    }
    return d.buffer.asUint8List();
  }

  final n = mesh.positions.length ~/ 3;
  final faces = mesh.indices.length ~/ 3;
  final p = mesh.positions;
  return chunk(0x4D4D, [
    chunk(0x0002, [u32(3)]),
    chunk(0x3D3D, [
      chunk(0x3D3E, [u32(3)]),
      chunk(0xAFFF, [
        chunk(0xA000, [cstr(name)]),
        chunk(0xA020, [chunk(0x0011, [Uint8List.fromList([255, 255, 255])])]),
        chunk(0xA200, [chunk(0x0030, [u16([100])]), chunk(0xA300, [cstr(texture)])]),
      ]),
      chunk(0x4000, [
        cstr(name),
        chunk(0x4100, [
          chunk(0x4110, [u16([n]), f32([for (var i = 0; i < n; i++) ...[p[i * 3], -p[i * 3 + 2], p[i * 3 + 1]]])]),
          chunk(0x4140, [u16([n]), f32([for (var i = 0; i < n; i++) ...[mesh.uvs[i * 2], 1 - mesh.uvs[i * 2 + 1]]])]),
          chunk(0x4120, [
            u16([faces, for (var f = 0; f < faces; f++) ...[mesh.indices[f * 3], mesh.indices[f * 3 + 1], mesh.indices[f * 3 + 2], 0]]),
            chunk(0x4130, [cstr(name), u16([faces, for (var f = 0; f < faces; f++) f])]),
          ]),
          chunk(0x4160, [f32([1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0])]),
        ]),
      ]),
    ]),
  ]);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const canRel = 'Props/JerryCan/jerrycan.glb';
  const bananaRel = 'Props/Banana Bunch/banana_bunch_medium.glb';
  const usedAssets = [canRel, '$canRel (as Collada + external PNG)', '$bananaRel (as 3DS + external PNG)'];
  const testName = 'Assimp Format Import Smoke: a Collada jerry can and a 3DS banana bunch with external textures';

  testWidgets(testName, (tester) async {
    final canGlb = File('${SmokeArtifacts.testAssetsDir.path}/$canRel');
    final bananaGlb = File('${SmokeArtifacts.testAssetsDir.path}/$bananaRel');
    if (!canGlb.existsSync() || !bananaGlb.existsSync()) {
      markTestSkipped('asset missing: $canRel or $bananaRel');
      return;
    }
    if (!FlutterAssimp.isSupportedFormat('dae') || !FlutterAssimp.isSupportedFormat('3ds')) {
      markTestSkipped('the Assimp bridge has no Collada / 3DS importer');
      return;
    }
    final root = Directory.systemTemp.createTempSync('assimp_format_smoke_');
    EditorViewModel? vm;
    try {
      final pDir = Directory('${root.path}/ModelFormats')..createSync(recursive: true);
      const project = LuminaProject(projectName: 'ModelFormats', activeLevel: 'contents/levels/L_Main.lmas');
      File('${pDir.path}/ModelFormats.lmproject').writeAsStringSync(jsonEncode(project.toMap()));

      // The source files as they come: the model and, beside it in a
      // subfolder, its texture under a differently capitalised name.
      final source = Directory('${root.path}/source files')..createSync();
      final canDoc = GlbDocument.parse(canGlb.readAsBytesSync(), label: 'jerry can');
      final bananaDoc = GlbDocument.parse(bananaGlb.readAsBytesSync(), label: 'banana');
      final canMesh = (await tester.runAsync(() => GlbParserService.parseGlb(canGlb.readAsBytesSync())))!;
      final bananaMesh = (await tester.runAsync(() => GlbParserService.parseGlb(bananaGlb.readAsBytesSync())))!;
      File('${source.path}/maps/jerrycan_bc.png')
        ..parent.createSync()
        ..writeAsBytesSync(_baseColourPng(canDoc));
      final dae = File('${source.path}/Jerry Can.dae')
        ..writeAsStringSync(_collada(canMesh, 'Can', 'Maps/JerryCan_BC.png'));
      File('${source.path}/textures/Banana.png')
        ..parent.createSync()
        ..writeAsBytesSync(_baseColourPng(bananaDoc));
      final threeDs = File('${source.path}/BANANA.3DS')..writeAsBytesSync(_threeDs(bananaMesh, 'Banana', 'BANANA.PNG'));
      final reference = canGlb.copySync('${source.path}/jerrycan.glb');
      // ignore: avoid_print
      print('[assimp_format_smoke] jerry can ${canMesh.vertexCount} v / ${canMesh.triangleCount} t, bounds '
          '${canMesh.minBounds} .. ${canMesh.maxBounds}; banana ${bananaMesh.vertexCount} v / '
          '${bananaMesh.triangleCount} t, bounds ${bananaMesh.minBounds} .. ${bananaMesh.maxBounds}');

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
      // The original GLB first: the reference the Collada copy must match.
      await importWhileRecording(reference.path);
      await importWhileRecording(dae.path);
      await importWhileRecording(threeDs.path);
      final problems = [
        for (final e in EngineLoggerService().logs.skip(logStart))
          if ((e.level == 'warning' || e.level == 'error') && e.message.contains('not found')) e.message,
      ];
      expect(problems, isEmpty, reason: 'both textures were found');

      final lmas = [
        for (final f in Directory('${pDir.path}/contents').listSync(recursive: true).whereType<File>())
          if (f.path.endsWith('.lmas')) LuminaAsset.fromBytes(f.readAsBytesSync()),
      ];
      final materials = lmas.where((a) => a.type == AssetType.filamat).toList();
      // ignore: avoid_print
      print('[assimp_format_smoke] materials: ${[for (final m in materials) '${m.name} ${m.references.map((r) => r.slotName)}']}');
      for (final name in ['jerry can_can', 'banana']) {
        final material = materials.singleWhere((a) => a.name.toLowerCase().contains(name));
        expect(material.references.map((r) => r.slotName), contains('baseColorMap'), reason: '$name samples its texture');
      }
      editor.refreshAssets();
      await rec.hold(const Duration(milliseconds: 500));

      // The original GLB jerry can at −X, its Collada copy at +X, the 3DS
      // banana bunch (hanging from its origin) further along +X.
      final meshes = editor.realAssets.where((a) => a.type == AssetType.filamesh).toList();
      for (final (file, location) in [
        ('jerrycan.lmas', [-35.0, 0.0, 0.0]),
        ('Jerry Can.lmas', [35.0, 0.0, 0.0]),
        ('BANANA.lmas', [220.0, 0.0, 115.0]),
      ]) {
        await tester.runAsync(() => editor.spawnActorFromAsset(meshes.firstWhere((a) => a.fileName == file), location: location));
        await rec.hold(const Duration(milliseconds: 600));
      }
      editor.selectActor(null);

      // Camera: [yaw, pitch, distance, target x, y, z]. Yaw 0 looks along +Y
      // with +X to the right; yaw 180 from the other side, +X on the left.
      var yawNow = -40.0;
      Future<void> orbitTo(double yaw, {int steps = 45, List<double> target = const [0.0, 0.0, 22.0], double distance = 150}) async {
        final from = yawNow;
        for (var i = 1; i <= steps; i++) {
          final t = i / steps;
          editor.restoreCameraSnapshot([from + (yaw - from) * t, 12.0, distance, ...target]);
          await rec.hold(const Duration(milliseconds: 60));
        }
        yawNow = yaw;
        await rec.hold(const Duration(milliseconds: 1200));
      }

      final viewport = tester.getRect(find.byType(ViewportWidget)).deflate(24);
      final left = Rect.fromLTRB(viewport.left, viewport.top, viewport.center.dx - 8, viewport.bottom);
      final right = Rect.fromLTRB(viewport.center.dx + 8, viewport.top, viewport.right, viewport.bottom);
      editor.restoreCameraSnapshot([yawNow, 12.0, 150.0, 0.0, 0.0, 22.0]);
      await rec.hold(const Duration(milliseconds: 800));
      final cans = <String, (_Colours, _Colours)>{}; // view → (GLB, Collada)
      for (final (view, yaw) in [('cans_front', 0.0), ('cans_back', 180.0)]) {
        await orbitTo(yaw);
        final png = await SmokeArtifacts.captureWidgetPng(tester, find.byKey(boundaryKey));
        SmokeArtifacts.saveScreenshot('assimp_format_import_$view', png, usedAssets: usedAssets);
        final a = await _measure(tester, png, left);
        final b = await _measure(tester, png, right);
        cans[view] = yaw == 0 ? (a, b) : (b, a);
      }
      final bananaViews = <String, _Colours>{};
      for (final (view, yaw) in [('banana_a', 90.0), ('banana_b', 270.0)]) {
        await orbitTo(yaw, target: const [220.0, 0.0, 55.0], distance: 230);
        final png = await SmokeArtifacts.captureWidgetPng(tester, find.byKey(boundaryKey));
        SmokeArtifacts.saveScreenshot('assimp_format_import_$view', png, usedAssets: usedAssets);
        bananaViews[view] = await _measure(tester, png, viewport);
      }
      for (final e in cans.entries) {
        // ignore: avoid_print
        print('[assimp_format_smoke] ${e.key}: GLB can ${e.value.$1} | Collada can ${e.value.$2}');
      }
      for (final e in bananaViews.entries) {
        // ignore: avoid_print
        print('[assimp_format_smoke] ${e.key}: ${e.value}');
      }
      expect(cans.values.map((c) => c.$1.red).reduce((a, b) => a > b ? a : b), greaterThan(400),
          reason: 'the reference jerry can shows its red paint');
      for (final (glbCan, daeCan) in cans.values) {
        // The same paint in the same places: the Collada texture coordinates
        // (V up) come out of the conversion as glTF's. Untextured, the can has
        // no red at all; sampled upside down, about a quarter of it.
        expect((daeCan.red - glbCan.red).abs(), lessThan(glbCan.red * 0.15),
            reason: 'the Collada jerry can shows the red of the texture its <init_from> names, where the original has it');
        expect(daeCan.distanceTo(glbCan), lessThan(15), reason: 'the Collada jerry can looks like the original GLB');
      }
      expect(bananaViews.values.map((c) => c.banana).reduce((a, b) => a > b ? a : b), greaterThan(2000),
          reason: 'the 3DS banana bunch shows the texture its material map names');

      await orbitTo(360.0, target: const [90.0, 0.0, 40.0], distance: 480);
      expect(rec.recorded, greaterThanOrEqualTo(const Duration(seconds: 10)));
      rec.save(testName, usedAssets: usedAssets);
    } finally {
      vm?.dispose();
      if (root.existsSync()) root.deleteSync(recursive: true);
    }
  });
}
