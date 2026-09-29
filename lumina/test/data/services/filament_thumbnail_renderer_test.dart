import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumina/data/services/game_template_service.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina/testing.dart';

/// Thumbnails are rendered by Filament, not
/// drawn on a CPU canvas. These run a real headless engine (GPU 1 through
/// `FILAMENT_GPU`), so each result is read back from the GPU.
///
/// The PNGs land in `build/thumbnails/` for a human to look at.

/// The neutral studio IBL flutter_filament ships with its example.
Uint8List? _studioIbl() {
  final f = File('../flutter_filament/example/assets/ibl/default_env/default_env_ibl.ktx');
  return f.existsSync() ? f.readAsBytesSync() : null;
}

File _testAsset(String relative) => File('${SmokeArtifacts.testAssetsDir.path}/$relative');

void _save(String name, Uint8List png) {
  final dir = Directory('build/thumbnails')..createSync(recursive: true);
  final file = File('${dir.path}/$name')..writeAsBytesSync(png);
  // ignore: avoid_print
  print('thumbnail: ${file.absolute.path}');
}

/// Fraction of pixels that differ from [bg] by more than a few levels.
double _fractionDiffering(img.Image image, img.Pixel bg) {
  var n = 0;
  for (final p in image) {
    final d = (p.r - bg.r).abs() + (p.g - bg.g).abs() + (p.b - bg.b).abs();
    if (d > 24) n++;
  }
  return n / (image.width * image.height);
}

/// Mean (r, g, b) of the pixel rectangle [l,t)-[r,b).
(double, double, double) _mean(img.Image image, int l, int t, int r, int b) {
  var sr = 0.0, sg = 0.0, sb = 0.0;
  var n = 0;
  for (var y = t; y < b; y++) {
    for (var x = l; x < r; x++) {
      final p = image.getPixel(x, y);
      sr += p.r;
      sg += p.g;
      sb += p.b;
      n++;
    }
  }
  return (sr / n, sg / n, sb / n);
}

/// The box around every pixel that is not the backdrop.
(int, int, int, int) _contentBox(img.Image image, img.Pixel bg) {
  var l = image.width, t = image.height, r = -1, b = -1;
  for (final p in image) {
    final d = (p.r - bg.r).abs() + (p.g - bg.g).abs() + (p.b - bg.b).abs();
    if (d <= 24) continue;
    l = math.min(l, p.x);
    t = math.min(t, p.y);
    r = math.max(r, p.x);
    b = math.max(b, p.y);
  }
  return (l, t, r, b);
}

(double, double, double) _centre(img.Image image) {
  final cx = image.width ~/ 2, cy = image.height ~/ 2;
  return _mean(image, cx - 16, cy - 16, cx + 16, cy + 16);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FilamentThumbnailRenderer renderer;

  setUpAll(() {
    renderer = FilamentThumbnailRenderer(iblKtx: _studioIbl());
  });

  tearDownAll(() => renderer.dispose());

  test('renderMesh(fuel_barrel_red.glb): a 256×256 render of the barrel that fills the frame', () async {
    final glbFile = _testAsset('Props/Barrels/fuel_barrel_red.glb');
    if (!glbFile.existsSync()) {
      markTestSkipped('test-assets missing: ${glbFile.path}');
      return;
    }
    final png = await renderer.renderMesh(glbFile.readAsBytesSync());
    expect(png, isNotNull, reason: 'the headless engine rendered nothing');
    _save('mesh_fuel_barrel_red.png', png!);

    final image = img.decodePng(png)!;
    expect(image.width, 256);
    expect(image.height, 256);
    final bg = image.getPixel(0, 0);
    expect(_fractionDiffering(image, bg), greaterThanOrEqualTo(0.20), reason: 'the barrel fills the frame');
    // Every barrel in Props/Barrels shares one texture atlas: white paint and
    // rust (the "red" is only in the file name; no base colour factor tints
    // it). So its centre is that warm off-white, not the backdrop.
    final (r, g, b) = _centre(image);
    expect(r, greaterThan(bg.r + 60), reason: 'centre is the lit barrel: rgb($r, $g, $b)');
    expect(r, greaterThanOrEqualTo(g), reason: 'warm paint and rust: rgb($r, $g, $b)');
    expect(g, greaterThanOrEqualTo(b), reason: 'warm paint and rust: rgb($r, $g, $b)');
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('renderMesh(jerrycan.glb): the red can renders red at the centre (R > G + 30)', () async {
    final glbFile = _testAsset('Props/JerryCan/jerrycan.glb');
    if (!glbFile.existsSync()) {
      markTestSkipped('test-assets missing: ${glbFile.path}');
      return;
    }
    final png = await renderer.renderMesh(glbFile.readAsBytesSync());
    expect(png, isNotNull);
    _save('mesh_jerrycan.png', png!);
    final image = img.decodePng(png)!;
    final bg = image.getPixel(0, 0);
    expect(_fractionDiffering(image, bg), greaterThanOrEqualTo(0.20), reason: 'the can fills the frame');
    final (r, g, b) = _centre(image);
    expect(r, greaterThan(g + 30), reason: 'red-dominant centre: rgb($r, $g, $b)');
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('renderMesh frames a 3.5 m AC unit and a 1.2 m banana bunch alike: large, whole, not clipped', () async {
    for (final rel in ['Props/AC_units/ac_unit_a_300x300.glb', 'Props/Banana Bunch/banana_bunch_medium.glb']) {
      final f = _testAsset(rel);
      if (!f.existsSync()) continue;
      final png = await renderer.renderMesh(f.readAsBytesSync());
      expect(png, isNotNull, reason: rel);
      _save('mesh_${f.uri.pathSegments.last.replaceAll('.glb', '')}.png', png!);
      final image = img.decodePng(png)!;
      final (l, t, r, b) = _contentBox(image, image.getPixel(0, 0));
      final extent = math.max(r - l, b - t) / image.width;
      expect(extent, greaterThan(0.55), reason: '$rel spans most of the frame ($l,$t)-($r,$b)');
      expect(l > 0 && t > 0 && r < image.width - 1 && b < image.height - 1, isTrue,
          reason: '$rel is not clipped by the frame ($l,$t)-($r,$b)');
    }
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('renderMaterial: a material whose base colour is (0.1, 0.8, 0.1) renders a green sphere', () async {
    // What the Material Editor saves: the .mat source, no compiled package
    // yet, and the parameter values in `parameter_defaults`.
    const source = '''material {
    name : "M_Thumb_Green",
    shadingModel : lit,
    blending : opaque,
    parameters : [
        { type : float4, name : baseColor },
        { type : float, name : roughness }
    ],
}

fragment {
    void material(inout MaterialInputs material) {
        prepareMaterial(material);
        material.baseColor = materialParams.baseColor;
        material.roughness = materialParams.roughness;
    }
}
''';
    final asset = LuminaAsset(
      assetId: 'm-green',
      name: 'M_Thumb_Green',
      type: AssetType.filamat,
      rawMatSource: source,
      metadata: {
        'parameter_defaults': jsonEncode({
          'baseColor': [0.1, 0.8, 0.1, 1.0],
          'roughness': 0.5,
        }),
      },
    );
    final png = await renderer.renderMaterial(asset);
    expect(png, isNotNull);
    _save('material_green.png', png!);
    final image = img.decodePng(png)!;
    expect(image.width, 256);
    final (r, g, b) = _centre(image);
    expect(g, greaterThan(r + 30), reason: 'green-dominant centre: rgb($r, $g, $b)');
    expect(g, greaterThan(b + 30), reason: 'green-dominant centre: rgb($r, $g, $b)');
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('renderMaterial of a material with no source falls back to a lit preview sphere', () async {
    const asset = LuminaAsset(assetId: 'm-empty', name: 'M_Ground_PBR', type: AssetType.filamat);
    final png = await renderer.renderMaterial(asset);
    expect(png, isNotNull);
    _save('material_fallback.png', png!);
    final image = img.decodePng(png)!;
    final bg = image.getPixel(0, 0);
    expect(_fractionDiffering(image, bg), greaterThanOrEqualTo(0.20), reason: 'the sphere is drawn');
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('renderLevel: the Third Person template (cm, Z up) is framed from its bounds', () async {
    final png = await renderer.renderLevel(GameTemplateCatalog.thirdPerson.levelActors);
    expect(png, isNotNull);
    _save('level_third_person.png', png!);
    final image = img.decodePng(png)!;
    final bg = image.getPixel(0, 0);
    expect(_fractionDiffering(image, bg), greaterThanOrEqualTo(0.20), reason: 'the yard fills the frame');
  }, timeout: const Timeout(Duration(minutes: 2)));
}
