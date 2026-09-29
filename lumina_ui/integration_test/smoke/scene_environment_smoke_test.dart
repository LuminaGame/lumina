// Scene environment smoke: proves the editor's 3D viewports have a real
// skybox and real image-based lighting, so imported PBR meshes are lit
// instead of rendering as black silhouettes.
//
// Evidence: PNG + WebM published through SmokeArtifacts, plus the measured
// mean luminance of the mesh pixels printed into the test log.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/gestures.dart' show PointerDeviceKind, kPrimaryMouseButton;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/sub_editor_3d_viewport.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

/// Mean luminance over every pixel of [png].
double meanLuminance(Uint8List png) {
  final im = img.decodePng(png)!;
  var sum = 0.0;
  var n = 0;
  for (final p in im) {
    sum += 0.2126 * p.r + 0.7152 * p.g + 0.0722 * p.b;
    n++;
  }
  return sum / n;
}

/// Mean luminance over a relative crop of [png] (0..1 fractions of the frame).
({double luma, int pixels}) cropLuminance(
  Uint8List png, {
  required double x0,
  required double x1,
  required double y0,
  required double y1,
}) {
  final im = img.decodePng(png)!;
  var sum = 0.0;
  var n = 0;
  for (var y = (y0 * im.height).round(); y < (y1 * im.height).round(); y++) {
    for (var x = (x0 * im.width).round(); x < (x1 * im.width).round(); x++) {
      final p = im.getPixel(x, y);
      sum += 0.2126 * p.r + 0.7152 * p.g + 0.0722 * p.b;
      n++;
    }
  }
  return (luma: n == 0 ? 0.0 : sum / n, pixels: n);
}

/// Per-channel median colour over a relative crop of [png]. Robust to HUD
/// text, grid lines and actor labels drawn on top of the 3D viewport.
(int, int, int) medianColor(
  Uint8List png, {
  required double x0,
  required double x1,
  required double y0,
  required double y1,
}) {
  final im = img.decodePng(png)!;
  final rs = <int>[];
  final gs = <int>[];
  final bs = <int>[];
  for (var y = (y0 * im.height).round(); y < (y1 * im.height).round(); y++) {
    for (var x = (x0 * im.width).round(); x < (x1 * im.width).round(); x++) {
      final p = im.getPixel(x, y);
      rs.add(p.r.toInt());
      gs.add(p.g.toInt());
      bs.add(p.b.toInt());
    }
  }
  rs.sort();
  gs.sort();
  bs.sort();
  final mid = rs.length ~/ 2;
  return (rs[mid], gs[mid], bs[mid]);
}

/// The framed preview mesh, found in the frame rather than at a fixed box, so
/// the measurement follows the mesh whatever the preview camera's opening
/// pose (the fixed crops went stale when the pose changed in 0e11867).
///
/// The backdrop colour is the median of a ring inset from the frame edge
/// (the edge itself carries the viewport's focus outline). A pixel belongs to
/// the mesh when it is far from that colour and sits in a solid 9×9 block of
/// such pixels, which drops the one- and two-pixel grid lines.
({int pixels, double meanLuma, double darkFraction, Rect bounds}) meshSegment(Uint8List png) {
  final im = img.decodePng(png)!;
  final w = im.width, h = im.height;
  final iy = (h * 0.12).round(), ix = (w * 0.04).round();
  final ring = <img.Pixel>[
    for (var x = ix; x < w - ix; x++) ...[im.getPixel(x, iy), im.getPixel(x, h - iy)],
    for (var y = iy; y < h - iy; y++) ...[im.getPixel(ix, y), im.getPixel(w - ix, y)],
  ];
  int median(num Function(img.Pixel) channel) {
    final values = ring.map((p) => channel(p).toInt()).toList()..sort();
    return values[values.length ~/ 2];
  }
  final bgR = median((p) => p.r), bgG = median((p) => p.g), bgB = median((p) => p.b);

  // Integral image of "far from the backdrop".
  final integral = List<int>.filled((w + 1) * (h + 1), 0);
  for (var y = 0; y < h; y++) {
    var row = 0;
    for (var x = 0; x < w; x++) {
      final p = im.getPixel(x, y);
      if ((p.r - bgR).abs() + (p.g - bgG).abs() + (p.b - bgB).abs() > 60) row++;
      integral[(y + 1) * (w + 1) + x + 1] = integral[y * (w + 1) + x + 1] + row;
    }
  }
  const k = 9, half = k ~/ 2;
  var pixels = 0, dark = 0;
  var sum = 0.0;
  var minX = w, minY = h, maxX = 0, maxY = 0;
  for (var y = iy; y < h - iy; y++) {
    final y0 = (y - half).clamp(0, h), y1 = (y + half + 1).clamp(0, h);
    for (var x = ix; x < w - ix; x++) {
      final x0 = (x - half).clamp(0, w), x1 = (x + half + 1).clamp(0, w);
      final count = integral[y1 * (w + 1) + x1] - integral[y0 * (w + 1) + x1] - integral[y1 * (w + 1) + x0] + integral[y0 * (w + 1) + x0];
      if (count < 0.9 * k * k) continue;
      final p = im.getPixel(x, y);
      final luma = 0.2126 * p.r + 0.7152 * p.g + 0.0722 * p.b;
      sum += luma;
      if (luma < 25) dark++;
      pixels++;
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }
  }
  return (
    pixels: pixels,
    meanLuma: pixels == 0 ? 0.0 : sum / pixels,
    darkFraction: pixels == 0 ? 1.0 : dark / pixels,
    bounds: pixels == 0 ? Rect.zero : Rect.fromLTRB(minX / w, minY / h, maxX / w, maxY / h),
  );
}

Future<void> settle(WidgetTester tester, {int frames = 90}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Static Mesh sub-editor lights a real imported PBR mesh', (tester) async {
    const rel = 'Props/AC_units/roof_aircon_unit_150x150_a.glb';
    final glbFile = File('${SmokeArtifacts.testAssetsDir.path}/$rel');
    expect(glbFile.existsSync(), isTrue, reason: 'real test asset must exist');
    final bytes = glbFile.readAsBytesSync();

    final mesh = GlbMeshData(
      positions: const [0, 0, 0, 1, 0, 0, 0, 1, 0],
      indices: const [0, 1, 2],
      minBounds: const [-1, -1, -1],
      maxBounds: const [1, 1, 1],
      rawPayload: bytes,
    );

    final key = GlobalKey();
    await tester.pumpWidget(
      ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(
          child: RepaintBoundary(
            key: key,
            child: SizedBox(
              width: 640,
              height: 480,
              child: SubEditor3DViewport(title: 'Static Mesh', glbMesh: mesh),
            ),
          ),
        ),
      ),
    );
    await settle(tester);
    final rec = SmokeRecorder(tester, boundary: find.byKey(key));
    await rec.hold(const Duration(seconds: 2));

    // Measured on the framing the viewport opens with.
    final png = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(key));
    final m = meshSegment(png);
    // ignore: avoid_print
    print('MEASURE sub_editor: frameLuma=${meanLuminance(png).toStringAsFixed(2)} '
        'meshLuma=${m.meanLuma.toStringAsFixed(2)} dark=${(m.darkFraction * 100).toStringAsFixed(1)}% '
        'meshPx=${m.pixels} bounds=${m.bounds}');

    SmokeArtifacts.saveScreenshot('scene_environment_static_mesh_lit', png, usedAssets: [glbFile.path]);
    await rec.hold(const Duration(seconds: 1));

    // Orbit all the way round the mesh with the left mouse button, so the
    // image-based lighting is seen on every side of it.
    final viewport = find.byType(SubEditor3DViewport);
    final centre = tester.getCenter(viewport);
    final orbit = await tester.startGesture(centre, kind: PointerDeviceKind.mouse, buttons: kPrimaryMouseButton);
    for (var i = 0; i < 90; i++) {
      await orbit.moveBy(const Offset(8, 0));
      await tester.pump(const Duration(milliseconds: 16));
      await rec.capture();
    }
    await orbit.up();
    await rec.hold(const Duration(seconds: 1));

    // Zoom in and back out with the wheel.
    final wheel = TestPointer(9, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(wheel.hover(centre));
    for (var i = 0; i < 15; i++) {
      await tester.sendEventToBinding(wheel.scroll(const Offset(0, -40)));
      await tester.pump(const Duration(milliseconds: 16));
      await rec.capture();
    }
    await rec.hold(const Duration(milliseconds: 700));
    for (var i = 0; i < 15; i++) {
      await tester.sendEventToBinding(wheel.scroll(const Offset(0, 40)));
      await tester.pump(const Duration(milliseconds: 16));
      await rec.capture();
    }
    await rec.hold(const Duration(seconds: 1));

    // Reset View returns to the opening pose.
    final reset = find.text('Reset View');
    if (reset.evaluate().isNotEmpty) {
      await tester.tap(reset.first);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await rec.hold(const Duration(milliseconds: 1500));
    rec.save('Static Mesh sub-editor lights a real imported PBR mesh', usedAssets: [glbFile.path]);

    expect(m.pixels, greaterThan(2000), reason: 'the mesh must actually be on screen');
    expect(m.bounds.width, greaterThan(0.1), reason: 'the framed mesh fills part of the view: ${m.bounds}');
    // Without an IndirectLight the faces the key light does not reach render
    // black: a large share of the mesh goes dark and
    // its mean drops. With the IBL bound this frame measures a mean luma of
    // about 131 and about 4% of the mesh below 25 (the fan inside the grille).
    expect(m.darkFraction, lessThan(0.15),
        reason: 'no side of the mesh renders black: image-based lighting reaches it');
    expect(m.meanLuma, greaterThan(100.0), reason: 'the mesh is lit as a whole');
  }, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets('Level viewport renders the Environment actor as a real sky', (tester) async {
    final tempDir = Directory.systemTemp.createTempSync('scene_env_smoke_');
    final pDir = Directory('${tempDir.path}/SkySmokeProject')..createSync(recursive: true);
    File('${pDir.path}/SkySmokeProject.lmproject').writeAsStringSync('{}');
    addTearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    final vm = EditorViewModel(
      initialProject: LuminaProject(
        projectName: 'SkySmokeProject',
        activeLevel: 'contents/levels/L_Main.lmas',
      ),
      projectLocation: tempDir.path,
    );
    addTearDown(vm.dispose);
    await tester.runAsync(() => vm.ensureDefaultLevelAssets());

    // A level with a real `Sky & Atmosphere` Environment actor, exactly as the
    // Place Actors menu and the launcher templates spawn it.
    vm.setLevelEnvironment(const {
      'version': 1,
      'sky': {
        'mode': 'color',
        'colorHex': '#5C7FB8',
        'skyIntensity': 30000.0,
        'iblIntensity': 30000.0,
        'rotationDegrees': 0.0,
        'showSun': true,
      },
    });

    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: ShadcnApp(
          theme: luminaEditorTheme(),
          home: MainEditorView(viewModel: vm),
        ),
      ),
    );
    await settle(tester);
    final rec = SmokeRecorder(tester, boundary: find.byKey(key));
    await rec.hold(const Duration(seconds: 2));

    final png = await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: find.byKey(key));
    // The *median* colour inside the 3D viewport rectangle. A mean would be
    // pulled around by the grid lines, the actor name labels and the amber
    // Tris/FPS/CPU HUD, which change every frame; the median is the colour the
    // viewport is actually filled with.
    final sky = medianColor(png, x0: 0.20, x1: 0.78, y0: 0.24, y1: 0.58);
    // ignore: avoid_print
    print('MEASURE level_viewport: skyMedian=(${sky.$1},${sky.$2},${sky.$3}) '
        'frameLuma=${meanLuminance(png).toStringAsFixed(2)}');

    SmokeArtifacts.saveScreenshot('scene_environment_level_sky', png);
    await rec.hold(const Duration(seconds: 1));

    // The sky follows the Environment actor live: sweep its colour through a
    // sunset, dusk and a pale noon, hide and show the sun, then return to the
    // authored blue.
    Map<String, Object> environment(String colorHex, {bool showSun = true}) => {
          'version': 1,
          'sky': {
            'mode': 'color',
            'colorHex': colorHex,
            'skyIntensity': 30000.0,
            'iblIntensity': 30000.0,
            'rotationDegrees': 0.0,
            'showSun': showSun,
          },
        };
    for (final hex in ['#E08A4F', '#2B3A67', '#9EC9F0']) {
      vm.setLevelEnvironment(environment(hex));
      await settle(tester, frames: 10);
      await rec.hold(const Duration(milliseconds: 1500));
    }
    vm.setLevelEnvironment(environment('#5C7FB8', showSun: false));
    await settle(tester, frames: 10);
    await rec.hold(const Duration(milliseconds: 1500));
    vm.setLevelEnvironment(environment('#5C7FB8'));
    await settle(tester, frames: 10);
    await rec.hold(const Duration(seconds: 2));
    rec.save('Level viewport renders the Environment actor as a real sky');

    // Measured baseline with no skybox bound (the bug): the viewport median was
    // the flat dark editor clear colour (57, 59, 73), frame luminance 38.8.
    // With the Environment actor realised: (104, 143, 193), frame luminance
    // 53.3.
    expect(sky.$3, greaterThan(sky.$1 + 40),
        reason: 'the Environment actor must paint a real blue skybox, not a flat grey clear colour');
    expect(sky.$3, greaterThan(140), reason: 'the sky must be bright, not near-black');
  }, timeout: const Timeout(Duration(minutes: 5)));
}
