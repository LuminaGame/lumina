import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/main_editor/views/viewport_widget.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Smoke — an FBX draws its texture the right way up, like its glTF.
///
/// Boots the real Lumina Studio on a real project and imports:
///
/// - `Props/roadsigns/roadsign9.glb` from test-assets (its base colour a sign
///   atlas: the sign face shows one region of it);
/// - `Road Sign.fbx`, an ASCII FBX of the same mesh with V-up texture
///   coordinates (as FBX stores them) and the atlas as an external PNG;
/// - `Quadrants.fbx`, a 2 m quad whose texture has four coloured quadrants
///   (red top-left, green top-right, blue bottom-left, yellow bottom-right):
///   the absolute reference, independent of any other import.
///
/// The two signs stand side by side and the viewport orbits them: front and
/// back look the same on both. The quad, seen from the front, shows red at
/// its top-left and yellow at its bottom-right. PNGs of three views plus a
/// WebM of the whole scenario.
///
/// Runs on GPU 1 (NVIDIA RTX PRO 2000) — `tool/smoke_report.dart` injects the
/// GPU environment.
Future<void> _settle(WidgetTester tester, [int frames = 10]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
  }
}

/// The RGBA pixels of a captured PNG.
Future<({ByteData data, int width})> _pixels(WidgetTester tester, Uint8List png) async {
  return (await tester.runAsync(() async {
    final codec = await ui.instantiateImageCodec(png);
    final frame = await codec.getNextFrame();
    final data = (await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final width = frame.image.width;
    frame.image.dispose();
    return (data: data, width: width);
  }))!;
}

/// A coarse colour histogram (4 levels per channel), normalised, of the
/// pixels in [rect] that differ from [background] (the same view before the
/// models were placed): the models only, not the sky and grid.
({List<double> bins, int count}) _histogram(({ByteData data, int width}) px, ({ByteData data, int width}) background, Rect rect) {
  final bins = List<double>.filled(64, 0);
  var total = 0;
  for (var y = rect.top.toInt(); y < rect.bottom.toInt(); y++) {
    for (var x = rect.left.toInt(); x < rect.right.toInt(); x++) {
      final o = (y * px.width + x) * 4;
      var diff = 0;
      for (var c = 0; c < 3; c++) {
        diff += (px.data.getUint8(o + c) - background.data.getUint8(o + c)).abs();
      }
      if (diff < 40) continue;
      final r = px.data.getUint8(o) >> 6, g = px.data.getUint8(o + 1) >> 6, b = px.data.getUint8(o + 2) >> 6;
      bins[r * 16 + g * 4 + b]++;
      total++;
    }
  }
  return (bins: [for (final v in bins) v / math.max(total, 1)], count: total);
}

/// Histogram intersection: 1 for the same colours in the same amounts.
double _similarity(List<double> a, List<double> b) {
  var s = 0.0;
  for (var i = 0; i < a.length; i++) {
    s += math.min(a[i], b[i]);
  }
  return s;
}

/// The mean colour of a small square around ([x], [y]).
List<double> _meanAt(({ByteData data, int width}) px, int x, int y, [int r = 6]) {
  final sum = [0.0, 0.0, 0.0];
  var n = 0;
  for (var j = y - r; j <= y + r; j++) {
    for (var i = x - r; i <= x + r; i++) {
      final o = (j * px.width + i) * 4;
      for (var c = 0; c < 3; c++) {
        sum[c] += px.data.getUint8(o + c);
      }
      n++;
    }
  }
  return [for (final v in sum) v / n];
}

/// Which of the quad's quadrant colours [rgb] is (lit and tone-mapped).
String? _quadrant(List<double> rgb) {
  final [r, g, b] = rgb;
  final max = [r, g, b].reduce(math.max);
  if (max < 25) return null;
  final hi = [r > 0.55 * max, g > 0.55 * max, b > 0.55 * max];
  if (hi[0] && hi[1] && !hi[2]) return 'yellow';
  if (hi[0] && !hi[1] && !hi[2]) return 'red';
  if (!hi[0] && hi[1] && !hi[2]) return 'green';
  if (!hi[0] && !hi[1] && hi[2]) return 'blue';
  return null;
}

/// The base colour image of a test-assets GLB, as PNG (they store WebP; an
/// FBX names a PNG / JPEG / TGA file).
Uint8List _baseColourPng(GlbDocument glb) {
  final material = (glb.json['materials'] as List).cast<Map>().first;
  final texture = (glb.json['textures'] as List)[(material['pbrMetallicRoughness']['baseColorTexture'] as Map)['index'] as int] as Map;
  final imageIndex = (texture['source'] ?? (texture['extensions'] as Map)['EXT_texture_webp']['source']) as int;
  final image = (glb.json['images'] as List)[imageIndex] as Map;
  final view = (glb.json['bufferViews'] as List)[image['bufferView'] as int] as Map;
  final offset = view['byteOffset'] as int? ?? 0;
  return img.encodePng(img.decodeImage(glb.bin.sublist(offset, offset + (view['byteLength'] as int)))!);
}

/// An ASCII FBX 7.4 document (metres, Y up) of triangles [indices] over
/// [positions] with texture coordinates [uvs] in FBX's V-up convention, one
/// Lambert material [name] whose diffuse colour samples [texture].
String _fbx(String name, List<double> positions, List<double> uvs, List<int> indices, String texture) {
  String list(Iterable<num> v) => v.map((x) => x is int ? '$x' : (x as double).toStringAsFixed(6)).join(',');
  final polygons = [
    for (var f = 0; f < indices.length; f += 3) ...[indices[f], indices[f + 1], -indices[f + 2] - 1],
  ];
  return '''; FBX 7.4.0 project file
FBXHeaderExtension:  {
	FBXHeaderVersion: 1003
	FBXVersion: 7400
}
GlobalSettings:  {
	Version: 1000
	Properties70:  {
		P: "UpAxis", "int", "Integer", "",1
		P: "UpAxisSign", "int", "Integer", "",1
		P: "FrontAxis", "int", "Integer", "",2
		P: "FrontAxisSign", "int", "Integer", "",1
		P: "CoordAxis", "int", "Integer", "",0
		P: "CoordAxisSign", "int", "Integer", "",1
		P: "UnitScaleFactor", "double", "Number", "",100
	}
}
Objects:  {
	Geometry: 1000, "Geometry::$name", "Mesh" {
		Vertices: *${positions.length} {
			a: ${list(positions)}
		}
		PolygonVertexIndex: *${polygons.length} {
			a: ${list(polygons)}
		}
		GeometryVersion: 124
		LayerElementUV: 0 {
			Version: 101
			Name: "UVMap"
			MappingInformationType: "ByPolygonVertex"
			ReferenceInformationType: "IndexToDirect"
			UV: *${uvs.length} {
				a: ${list(uvs)}
			}
			UVIndex: *${indices.length} {
				a: ${list(indices)}
			}
		}
		LayerElementMaterial: 0 {
			Version: 101
			Name: ""
			MappingInformationType: "AllSame"
			ReferenceInformationType: "IndexToDirect"
			Materials: *1 {
				a: 0
			}
		}
		Layer: 0 {
			Version: 100
			LayerElement:  {
				Type: "LayerElementUV"
				TypedIndex: 0
			}
			LayerElement:  {
				Type: "LayerElementMaterial"
				TypedIndex: 0
			}
		}
	}
	Model: 2000, "Model::$name", "Mesh" {
		Version: 232
		Properties70:  {
		}
		Shading: T
		Culling: "CullingOff"
	}
	Material: 3000, "Material::$name", "" {
		Version: 102
		ShadingModel: "lambert"
		MultiLayer: 0
		Properties70:  {
			P: "DiffuseColor", "Color", "", "A",1,1,1
		}
	}
	Texture: 4000, "Texture::$name", "" {
		Type: "TextureVideoClip"
		Version: 202
		TextureName: "Texture::$name"
		Media: "Video::$name"
		FileName: "$texture"
		RelativeFilename: "$texture"
	}
	Video: 5000, "Video::$name", "Clip" {
		Type: "Clip"
		FileName: "$texture"
		RelativeFilename: "$texture"
	}
}
Connections:  {
	C: "OO",2000,0
	C: "OO",1000,2000
	C: "OO",3000,2000
	C: "OP",4000,3000, "DiffuseColor"
	C: "OO",5000,4000
}
''';
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const signRel = 'Props/roadsigns/roadsign9.glb';
  const usedAssets = [signRel, '$signRel (as FBX + external PNG)', 'Quadrants.fbx (2 m quad, four-colour texture)'];
  const testName = 'FBX Texture Orientation Smoke: an FBX road sign matches its glTF and a quad shows its texture upright';

  testWidgets(testName, (tester) async {
    final signGlb = File('${SmokeArtifacts.testAssetsDir.path}/$signRel');
    if (!signGlb.existsSync()) {
      markTestSkipped('asset missing: $signRel');
      return;
    }
    if (!FlutterAssimp.isAvailable) {
      markTestSkipped('the Assimp bridge is not loaded');
      return;
    }
    final root = Directory.systemTemp.createTempSync('fbx_uv_smoke_');
    EditorViewModel? vm;
    try {
      final pDir = Directory('${root.path}/TextureOrientation')..createSync(recursive: true);
      const project = LuminaProject(projectName: 'TextureOrientation', activeLevel: 'contents/levels/L_Main.lmas');
      File('${pDir.path}/TextureOrientation.lmproject').writeAsStringSync(jsonEncode(project.toMap()));

      // The source files: the sign as FBX beside its atlas, the quad beside
      // its four-colour image, and the original GLB.
      final source = Directory('${root.path}/source files')..createSync();
      final signDoc = GlbDocument.parse(signGlb.readAsBytesSync(), label: 'road sign');
      final signMesh = (await tester.runAsync(() => GlbParserService.parseGlb(signGlb.readAsBytesSync())))!;
      File('${source.path}/Road Sign.png').writeAsBytesSync(_baseColourPng(signDoc));
      final n = signMesh.positions.length ~/ 3;
      final signFbx = File('${source.path}/Road Sign.fbx')
        ..writeAsStringSync(_fbx(
          'RoadSign',
          signMesh.positions,
          [for (var i = 0; i < n; i++) ...[signMesh.uvs[i * 2], 1 - signMesh.uvs[i * 2 + 1]]],
          signMesh.indices,
          'Road Sign.png',
        ));
      final quadImage = img.Image(width: 64, height: 64);
      for (final (x0, y0, c) in [
        (0, 0, img.ColorRgb8(230, 20, 20)),
        (32, 0, img.ColorRgb8(20, 210, 30)),
        (0, 32, img.ColorRgb8(20, 40, 230)),
        (32, 32, img.ColorRgb8(235, 225, 20)),
      ]) {
        img.fillRect(quadImage, x1: x0, y1: y0, x2: x0 + 31, y2: y0 + 31, color: c);
      }
      File('${source.path}/quadrants.png').writeAsBytesSync(img.encodePng(quadImage));
      final quadFbx = File('${source.path}/Quadrants.fbx')
        ..writeAsStringSync(_fbx(
          'Quadrants',
          const [-1, 0, 0, 1, 0, 0, 1, 2, 0, -1, 2, 0],
          const [0, 0, 1, 0, 1, 1, 0, 1], // V up: (0, 1) is the image's top-left
          const [0, 1, 2, 0, 2, 3],
          'quadrants.png',
        ));
      final reference = signGlb.copySync('${source.path}/roadsign9.glb');
      // ignore: avoid_print
      print('[fbx_uv_smoke] road sign ${signMesh.vertexCount} v / ${signMesh.triangleCount} t, bounds '
          '${signMesh.minBounds} .. ${signMesh.maxBounds}');

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
      await importWhileRecording(reference.path);
      await importWhileRecording(signFbx.path);
      await importWhileRecording(quadFbx.path);
      final problems = [
        for (final e in EngineLoggerService().logs.skip(logStart))
          if ((e.level == 'warning' || e.level == 'error') && e.message.contains('not found')) e.message,
      ];
      expect(problems, isEmpty, reason: 'both textures were found');
      editor.refreshAssets();
      await rec.hold(const Duration(milliseconds: 500));

      final viewport = tester.getRect(find.byType(ViewportWidget)).deflate(24);
      final left = Rect.fromLTRB(viewport.left, viewport.top, viewport.center.dx - 8, viewport.bottom);
      final right = Rect.fromLTRB(viewport.center.dx + 8, viewport.top, viewport.right, viewport.bottom);
      // The sign's plate stands in the glTF YZ plane, facing ±X (the level's
      // ±X too): seen from yaw 90 (looking along +X) and yaw 270. The two
      // signs stand side by side along Y, the plates 140 cm apart.
      const gap = 70.0;
      final signTarget = [0.0, 0.0, signMesh.maxBounds[1] * 100 - 60];
      const signDistance = 380.0;
      const views = [('signs_front', 90.0), ('signs_back', 270.0)];
      Future<({ByteData data, int width})> shot(String? artifact) async {
        final png = await SmokeArtifacts.captureWidgetPng(tester, find.byKey(boundaryKey));
        if (artifact != null) SmokeArtifacts.saveScreenshot(artifact, png, usedAssets: usedAssets);
        return _pixels(tester, png);
      }

      // The empty level from each sign view, to tell the signs from the sky.
      final backgrounds = <String, ({ByteData data, int width})>{};
      for (final (view, yaw) in views) {
        editor.restoreCameraSnapshot([yaw, 6.0, signDistance, ...signTarget]);
        await rec.hold(const Duration(milliseconds: 1200));
        backgrounds[view] = await shot(null);
      }

      final meshes = editor.realAssets.where((a) => a.type == AssetType.filamesh).toList();
      Future<void> place(String file, List<double> location) async {
        await tester.runAsync(() => editor.spawnActorFromAsset(meshes.firstWhere((a) => a.fileName == file), location: location));
        await rec.hold(const Duration(milliseconds: 600));
        editor.selectActor(null);
      }

      await place('roadsign9.lmas', [0.0, -gap, 0.0]);
      await place('Road Sign.lmas', [0.0, gap, 0.0]);

      var yawNow = 270.0;
      List<double> targetNow = signTarget;
      var distanceNow = signDistance;
      Future<void> orbitTo(double yaw, {List<double>? target, double? distance, int steps = 45}) async {
        final (fromYaw, fromTarget, fromDistance) = (yawNow, targetNow, distanceNow);
        final toTarget = target ?? targetNow;
        final toDistance = distance ?? distanceNow;
        for (var i = 1; i <= steps; i++) {
          final t = i / steps;
          editor.restoreCameraSnapshot([
            fromYaw + (yaw - fromYaw) * t,
            6.0,
            fromDistance + (toDistance - fromDistance) * t,
            for (var c = 0; c < 3; c++) fromTarget[c] + (toTarget[c] - fromTarget[c]) * t,
          ]);
          await rec.hold(const Duration(milliseconds: 60));
        }
        (yawNow, targetNow, distanceNow) = (yaw, toTarget, toDistance);
        await rec.hold(const Duration(milliseconds: 1200));
      }

      // The same colours in the same amounts on both signs, front and back.
      final similarity = <String, double>{};
      for (final (view, yaw) in views) {
        await orbitTo(yaw);
        final px = await shot('fbx_texture_orientation_$view');
        final a = _histogram(px, backgrounds[view]!, left);
        final b = _histogram(px, backgrounds[view]!, right);
        // ignore: avoid_print
        print('[fbx_uv_smoke] $view: ${a.count} px left, ${b.count} px right');
        expect(math.min(a.count, b.count), greaterThan(500), reason: '$view: both signs are in view');
        similarity[view] = _similarity(a.bins, b.bins);
      }
      // ignore: avoid_print
      print('[fbx_uv_smoke] sign GLB vs FBX colour similarity: $similarity');

      // The quad, away from the signs. A glTF mesh faces its +Z, the level's
      // −Y: the camera at yaw 0 (looking along +Y, +X to the right) sees its
      // front, upright.
      const quadAt = [0.0, 1500.0, 0.0];
      await place('Quadrants.lmas', quadAt);
      await orbitTo(0.0, target: [quadAt[0], quadAt[1], 100.0], distance: 420.0, steps: 60);
      final quadPx = await shot('fbx_texture_orientation_quad');
      final c = viewport.center;
      const d = 45;
      final corners = {
        'top-left': _quadrant(_meanAt(quadPx, c.dx.toInt() - d, c.dy.toInt() - d)),
        'top-right': _quadrant(_meanAt(quadPx, c.dx.toInt() + d, c.dy.toInt() - d)),
        'bottom-left': _quadrant(_meanAt(quadPx, c.dx.toInt() - d, c.dy.toInt() + d)),
        'bottom-right': _quadrant(_meanAt(quadPx, c.dx.toInt() + d, c.dy.toInt() + d)),
      };
      // ignore: avoid_print
      print('[fbx_uv_smoke] quad corners on screen: $corners');

      expect(corners, {'top-left': 'red', 'top-right': 'green', 'bottom-left': 'blue', 'bottom-right': 'yellow'},
          reason: 'the FBX quad shows its texture upright');
      for (final e in similarity.entries) {
        expect(e.value, greaterThan(0.85), reason: '${e.key}: the FBX sign shows the same atlas region as the glTF sign');
      }

      await orbitTo(360.0, target: const [0.0, 700.0, 150.0], distance: 1500, steps: 70);
      expect(rec.recorded, greaterThanOrEqualTo(const Duration(seconds: 10)));
      rec.save(testName, usedAssets: usedAssets);
    } finally {
      vm?.dispose();
      if (root.existsSync()) root.deleteSync(recursive: true);
    }
  });
}
