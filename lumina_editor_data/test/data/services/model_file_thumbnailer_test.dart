import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumina/testing.dart';
import 'package:lumina_editor_data/lumina_editor.dart';

/// The command-line thumbnailer behind file-manager previews: a model file
/// on disk (not a project asset) rendered by the editor's thumbnail renderer
/// into a PNG. Renders on a real headless engine (GPU 1 through
/// `FILAMENT_GPU`); the PNGs land in `build/thumbnails/model_files/`.
File _testAsset(String relative) => File('${SmokeArtifacts.testAssetsDir.path}/$relative');

/// The neutral studio IBL flutter_filament ships with its example.
Uint8List? _studioIbl() {
  final f = File('../flutter_filament/example/assets/ibl/default_env/default_env_ibl.ktx');
  return f.existsSync() ? f.readAsBytesSync() : null;
}

/// Fraction of pixels that differ from the corner (backdrop) colour.
double _contentFraction(img.Image image) {
  final bg = image.getPixel(0, 0);
  var n = 0;
  for (final p in image) {
    if ((p.r - bg.r).abs() + (p.g - bg.g).abs() + (p.b - bg.b).abs() > 24) n++;
  }
  return n / (image.width * image.height);
}

/// A unit cube as Wavefront OBJ text (8 vertices, 12 triangles).
const String _cubeObj = '''
o Cube
v -0.5 -0.5 -0.5
v 0.5 -0.5 -0.5
v 0.5 0.5 -0.5
v -0.5 0.5 -0.5
v -0.5 -0.5 0.5
v 0.5 -0.5 0.5
v 0.5 0.5 0.5
v -0.5 0.5 0.5
f 1 3 2
f 1 4 3
f 5 6 7
f 5 7 8
f 1 2 6
f 1 6 5
f 4 7 3
f 4 8 7
f 1 5 8
f 1 8 4
f 2 3 7
f 2 7 6
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;
  final out = Directory('build/thumbnails/model_files');

  setUpAll(() => out.createSync(recursive: true));
  setUp(() => temp = Directory.systemTemp.createTempSync('model_thumb_'));
  tearDown(() {
    try {
      temp.deleteSync(recursive: true);
    } on FileSystemException catch (_) {}
  });

  group('ModelThumbnailCommand.parse', () {
    test('input, output and the default size', () {
      final r = ModelThumbnailCommand.parse(['--lumina-thumbnail', 'a.glb', 'a.png']);
      expect(r.error, isNull);
      expect(r.request!.input, 'a.glb');
      expect(r.request!.output, 'a.png');
      expect(r.request!.size, ModelThumbnailCommand.defaultSize);
    });

    test('--size in both spellings, and the flag anywhere', () {
      expect(ModelThumbnailCommand.parse(['--lumina-thumbnail', 'a.fbx', 'b.png', '--size', '128']).request!.size, 128);
      expect(ModelThumbnailCommand.parse(['--size=512', '--lumina-thumbnail', 'a.obj', 'b.png']).request!.size, 512);
    });

    test('a missing output or a size out of range is a usage error', () {
      expect(ModelThumbnailCommand.parse(['--lumina-thumbnail', 'a.glb']).error, contains('usage'));
      expect(ModelThumbnailCommand.parse(['--lumina-thumbnail', 'a.glb', 'b.png', '--size', '0']).error, contains('size'));
      expect(ModelThumbnailCommand.parse(['--lumina-thumbnail', 'a.glb', 'b.png', '--size', '5000']).error, contains('size'));
      expect(ModelThumbnailCommand.parse(['--lumina-thumbnail', 'a.glb', 'b.png', '--size', 'big']).error, contains('size'));
    });
  });

  test('supported extensions, case-insensitive', () {
    expect(ModelFileThumbnailer.supports('C:/x/Chair.FBX'), isTrue);
    expect(ModelFileThumbnailer.supports('/x/a.gltf'), isTrue);
    expect(ModelFileThumbnailer.supports('/x/a.obj'), isTrue);
    expect(ModelFileThumbnailer.supports('/x/a.glb'), isTrue);
    expect(ModelFileThumbnailer.supports('/x/a.png'), isFalse);
    expect(ModelFileThumbnailer.supports('/x/glb'), isFalse);
  });

  group('render', () {
    late FilamentThumbnailRenderer renderer;
    setUpAll(() => renderer = FilamentThumbnailRenderer()..environmentIbl = _studioIbl());
    tearDownAll(() => renderer.dispose());

    Future<img.Image> renderFile(String path, String name) async {
      final png = await ModelFileThumbnailer.render(path, renderer);
      expect(png, isNotNull, reason: 'no thumbnail for $path');
      File('${out.path}/$name').writeAsBytesSync(png!);
      return img.decodePng(png)!;
    }

    test('a binary glTF from disk: the fuel barrel', () async {
      final barrel = _testAsset('Props/Barrels/fuel_barrel_red.glb');
      if (!barrel.existsSync()) return markTestSkipped('test-assets missing');
      final image = await renderFile(barrel.path, 'fuel_barrel_red.png');
      expect(image.width, 256);
      expect(_contentFraction(image), greaterThan(0.05));
      // Textured, not a flat silhouette: the painted metal and its rust vary.
      final bg = image.getPixel(0, 0);
      final lumas = <num>{};
      for (final p in image) {
        if ((p.r - bg.r).abs() + (p.g - bg.g).abs() + (p.b - bg.b).abs() > 24) lumas.add(p.luminance);
      }
      expect(lumas.length, greaterThan(40));
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('an FBX converted as the import converts it: the casino chair', () async {
      final chair = _testAsset('FBX/StaticMeshes/SM_Casino_Chair.FBX');
      if (!chair.existsSync()) return markTestSkipped('test-assets missing');
      final image = await renderFile(chair.path, 'sm_casino_chair.png');
      expect(_contentFraction(image), greaterThan(0.05));
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('a .gltf with its external .bin', () async {
      final gltf = _testAsset('mannequin/exports/MM_Land.gltf');
      if (!gltf.existsSync()) return markTestSkipped('test-assets missing');
      final image = await renderFile(gltf.path, 'mm_land.png');
      expect(_contentFraction(image), greaterThan(0.03));
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('an OBJ written to disk', () async {
      final obj = File('${temp.path}/cube.obj')..writeAsStringSync(_cubeObj);
      final image = await renderFile(obj.path, 'cube_obj.png');
      expect(_contentFraction(image), greaterThan(0.05));
    }, timeout: const Timeout(Duration(minutes: 2)));
  });

  group('run', () {
    test('writes the PNG at the asked size and leaves no temporary file', () async {
      final barrel = _testAsset('Props/Barrels/fuel_barrel_red.glb');
      if (!barrel.existsSync()) return markTestSkipped('test-assets missing');
      final output = '${temp.path}/thumb.png';
      final code = await ModelThumbnailCommand.run(
        ModelThumbnailRequest(input: barrel.path, output: output, size: 128),
        ibl: _studioIbl(),
      );
      expect(code, ModelThumbnailCommand.exitOk);
      final image = img.decodePng(File(output).readAsBytesSync())!;
      expect(image.width, 128);
      expect(image.height, 128);
      expect(File('$output.tmp').existsSync(), isFalse);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('an unsupported file is refused before any engine starts', () async {
      final text = File('${temp.path}/notes.txt')..writeAsStringSync('not a model');
      final code = await ModelThumbnailCommand.run(ModelThumbnailRequest(input: text.path, output: '${temp.path}/x.png'));
      expect(code, ModelThumbnailCommand.exitInput);
      expect(File('${temp.path}/x.png').existsSync(), isFalse);
    });

    test('a missing input is an input error', () async {
      final code = await ModelThumbnailCommand.run(
          ModelThumbnailRequest(input: '${temp.path}/gone.glb', output: '${temp.path}/x.png'));
      expect(code, ModelThumbnailCommand.exitInput);
    });

    test('a truncated binary glTF fails cleanly without writing', () async {
      final barrel = _testAsset('Props/Barrels/fuel_barrel_red.glb');
      if (!barrel.existsSync()) return markTestSkipped('test-assets missing');
      final bytes = barrel.readAsBytesSync();
      final broken = File('${temp.path}/broken.glb')..writeAsBytesSync(bytes.sublist(0, bytes.length ~/ 3));
      final code = await ModelThumbnailCommand.run(ModelThumbnailRequest(input: broken.path, output: '${temp.path}/x.png'));
      expect(code, anyOf(ModelThumbnailCommand.exitInput, ModelThumbnailCommand.exitRender));
      expect(File('${temp.path}/x.png').existsSync(), isFalse);
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}
