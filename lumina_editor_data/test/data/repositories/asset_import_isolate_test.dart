import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';

/// Regression coverage: asset import must not downscale textures on the UI
/// isolate and freeze the editor.
///
/// Since the 2048 px texture budget landed, `convertStagedAsset` has to decode
/// and resize oversized source art. Doing that on the calling isolate froze the
/// whole editor mid-import — the window manager offered to force-quit it.
void main() {
  late Directory projectDir;

  setUp(() {
    projectDir = Directory.systemTemp.createTempSync('import_isolate_');
    Directory('${projectDir.path}/contents/textures').createSync(recursive: true);
  });

  tearDown(() {
    if (projectDir.existsSync()) projectDir.deleteSync(recursive: true);
  });

  test('convertStagedAsset keeps the calling isolate responsive while downscaling', () async {
    final staged = File('${projectDir.path}/SM_Oversized.glb');
    staged.writeAsBytesSync(_glbWithEmbeddedPng(_solidPng(4096, 4096)));

    var ticks = 0;
    final ticker = Stream<void>.periodic(const Duration(milliseconds: 1)).listen((_) => ticks++);
    final sw = Stopwatch()..start();

    final converted = await AssetRepository().convertStagedAsset(
      projectPath: projectDir.path,
      stagedFilePath: staged.path,
      detectedType: AssetType.filamesh,
    );

    sw.stop();
    await ticker.cancel();

    // A blocked event loop still fires the timer once per `await` in the method
    // — a handful of ticks regardless of how long the resize takes. A worker
    // leaves the loop turning, so ticks track elapsed milliseconds instead.
    expect(
      ticks,
      greaterThan(sw.elapsedMilliseconds ~/ 4),
      reason: 'the import must hand the decode off to a worker; running it inline '
          'starves the event loop and the editor stops repainting. '
          'Got $ticks ticks over ${sw.elapsedMilliseconds} ms',
    );

    // The fix must move the work, not skip it.
    final payload = converted['primaryPayload'] as Uint8List;
    expect(_embeddedImageSize(payload), equals(const [2048, 2048]));
  });
}

Uint8List _solidPng(int width, int height) {
  final rgba = Uint8List(width * height * 4);
  for (int i = 0; i < rgba.length; i += 4) {
    rgba[i] = 200;
    rgba[i + 1] = 90;
    rgba[i + 2] = 40;
    rgba[i + 3] = 255;
  }
  return TgaDecoderService.encodePng(rgba, width, height);
}

/// Width/height of the first embedded image, read from its PNG IHDR.
List<int> _embeddedImageSize(Uint8List glb) {
  final byteData = ByteData.sublistView(glb);
  final jsonLength = byteData.getUint32(12, Endian.little);
  final json = jsonDecode(utf8.decode(glb.sublist(20, 20 + jsonLength))) as Map;
  final binStart = 20 + jsonLength + 8;
  final image = (json['images'] as List).first as Map;
  final bv = (json['bufferViews'] as List)[image['bufferView'] as int] as Map;
  final offset = binStart + ((bv['byteOffset'] as int?) ?? 0);
  final ihdr = ByteData.sublistView(glb, offset + 16, offset + 24);
  return [ihdr.getUint32(0, Endian.big), ihdr.getUint32(4, Endian.big)];
}

Uint8List _glbWithEmbeddedPng(Uint8List png) {
  final positions = Float32List.fromList([0, 0, 0, 1, 0, 0, 0, 1, 0]);
  final geometry = positions.buffer.asUint8List();

  final binBuilder = BytesBuilder()..add(png);
  final pngPad = (4 - (png.length % 4)) % 4;
  binBuilder.add(Uint8List(pngPad));
  final geometryOffset = png.length + pngPad;
  binBuilder.add(geometry);
  final bin = binBuilder.toBytes();

  final json = {
    'asset': {'version': '2.0'},
    'buffers': [
      {'byteLength': bin.length},
    ],
    'bufferViews': [
      {'buffer': 0, 'byteOffset': 0, 'byteLength': png.length},
      {'buffer': 0, 'byteOffset': geometryOffset, 'byteLength': geometry.length},
    ],
    'images': [
      {'bufferView': 0, 'mimeType': 'image/png'},
    ],
    'textures': [
      {'source': 0},
    ],
    'materials': [
      {
        'name': 'M_Oversized',
        'pbrMetallicRoughness': {
          'baseColorTexture': {'index': 0},
        },
      },
    ],
    'accessors': [
      {
        'bufferView': 1,
        'componentType': 5126,
        'count': 3,
        'type': 'VEC3',
        'min': [0.0, 0.0, 0.0],
        'max': [1.0, 1.0, 0.0],
      },
    ],
    'meshes': [
      {
        'name': 'Mesh0',
        'primitives': [
          {
            'attributes': {'POSITION': 0},
            'material': 0,
          },
        ],
      }
    ],
    'nodes': [
      {'name': 'MeshNode', 'mesh': 0},
    ],
    'scenes': [
      {
        'nodes': [0],
      }
    ],
    'scene': 0,
  };

  final jsonBytes = utf8.encode(jsonEncode(json));
  final jsonPadded = (jsonBytes.length + 3) & ~3;
  final jsonChunk = Uint8List(jsonPadded)
    ..fillRange(0, jsonPadded, 0x20)
    ..setRange(0, jsonBytes.length, jsonBytes);

  final binPadded = (bin.length + 3) & ~3;
  final binChunk = Uint8List(binPadded)..setRange(0, bin.length, bin);

  final total = 12 + 8 + jsonPadded + 8 + binPadded;
  final glb = Uint8List(total);
  final bd = ByteData.sublistView(glb);

  bd.setUint32(0, 0x46546C67, Endian.little);
  bd.setUint32(4, 2, Endian.little);
  bd.setUint32(8, total, Endian.little);
  bd.setUint32(12, jsonPadded, Endian.little);
  bd.setUint32(16, 0x4E4F534A, Endian.little);
  glb.setRange(20, 20 + jsonPadded, jsonChunk);

  final binHeader = 20 + jsonPadded;
  bd.setUint32(binHeader, binPadded, Endian.little);
  bd.setUint32(binHeader + 4, 0x004E4942, Endian.little);
  glb.setRange(binHeader + 8, binHeader + 8 + binPadded, binChunk);

  return glb;
}
