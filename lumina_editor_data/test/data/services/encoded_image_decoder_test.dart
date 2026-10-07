import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina/testing.dart';

/// The decoder follows the bytes' real format, and decodes alike on
/// the root isolate (`dart:ui`'s codec) and on any other (`package:image`).
///
/// The images are the real `Props/Barrels/dented_barrel.glb` texture (a
/// 512x256 WebP) re-encoded by real encoders, plus flutter_filament's KTX2
/// test texture.
void main() {
  final barrelFile = File('${SmokeArtifacts.testAssetsDir.path}/Props/Barrels/dented_barrel.glb');
  final ktx2File = File('../flutter_filament/test/assets/roughness.ktx2');

  late Map<EncodedImageFormat, Uint8List> encoded;

  setUpAll(() {
    if (!barrelFile.existsSync()) return;
    final doc = GlbDocument.parse(barrelFile.readAsBytesSync());
    final image = (doc.json['images'] as List).first as Map;
    final view = (doc.json['bufferViews'] as List)[image['bufferView'] as int] as Map;
    final at = (view['byteOffset'] as int?) ?? 0;
    final webp = doc.bin.sublist(at, at + (view['byteLength'] as int));
    final texture = img.decodeImage(webp)!;
    // Half the texels translucent, so premultiplication is exercised too.
    final translucent = texture.convert(numChannels: 4);
    for (final p in translucent) {
      if (p.x.isEven) p.a = 97;
    }
    encoded = {
      EncodedImageFormat.png: img.encodePng(translucent, level: 1),
      EncodedImageFormat.jpeg: img.encodeJpg(texture, quality: 95),
      EncodedImageFormat.webp: webp,
      EncodedImageFormat.gif: img.encodeGif(texture),
      EncodedImageFormat.bmp: img.encodeBmp(texture),
      EncodedImageFormat.tga: img.encodeTga(translucent),
      if (ktx2File.existsSync()) EncodedImageFormat.ktx2: ktx2File.readAsBytesSync(),
    };
  });

  bool skipIfNoAssets() {
    if (barrelFile.existsSync()) return false;
    markTestSkipped('test-assets missing: ${barrelFile.path}');
    return true;
  }

  test('sniff names each format from its bytes', () {
    if (skipIfNoAssets()) return;
    for (final MapEntry(key: format, value: bytes) in encoded.entries) {
      expect(EncodedImageFormat.sniff(bytes), format, reason: format.name);
    }
    expect(EncodedImageFormat.sniff(Uint8List.fromList('{"not": "an image"}'.codeUnits)), EncodedImageFormat.unknown);
    expect(EncodedImageFormat.sniff(Uint8List(4)), EncodedImageFormat.unknown);
  });

  test('a PNG is a PNG whatever it is called: its signature wins over any TGA reading', () {
    if (skipIfNoAssets()) return;
    final png = encoded[EncodedImageFormat.png]!;
    // The PNG's IHDR tag, read as a TGA header, is 18505x21060.
    expect(ByteData.sublistView(png, 12, 16).getUint16(0, Endian.little), 18505);
    expect(EncodedImageFormat.sniff(png), EncodedImageFormat.png);
  });

  test('KTX2 and unknown bytes are not decoded to pixels', () async {
    if (skipIfNoAssets()) return;
    if (encoded.containsKey(EncodedImageFormat.ktx2)) {
      expect(await EncodedImageDecoder.decodeRgba(encoded[EncodedImageFormat.ktx2]!), isNull);
    }
    expect(await EncodedImageDecoder.decodeRgba(Uint8List.fromList(List.filled(64, 7))), isNull);
  });

  test('a truncated PNG throws a FormatException instead of decoding garbage', () async {
    if (skipIfNoAssets()) return;
    final png = encoded[EncodedImageFormat.png]!;
    final truncated = Uint8List.sublistView(png, 0, 40);
    await expectLater(Isolate.run(() => _decodeOffRoot(truncated)), throwsA(isA<FormatException>()));
  });

  // Package:image 4.9 applies an explicit `convert(alpha:)` to an
  // existing alpha channel, so the worker decode came back opaque.
  test('a translucent PNG keeps its alpha on a worker isolate (premultiplied like the root)', () async {
    final image = img.Image(width: 2, height: 1, numChannels: 4)
      ..setPixelRgba(0, 0, 200, 100, 50, 97)
      ..setPixelRgba(1, 0, 200, 100, 50, 255);
    final png = img.encodePng(image);
    final offRoot = await Isolate.run(() => _decodeOffRoot(png));
    expect(offRoot.rgba, [76, 38, 19, 97, 200, 100, 50, 255]);
    final onRoot = (await EncodedImageDecoder.decodeRgba(png))!;
    expect(onRoot.rgba, offRoot.rgba);
  });

  test('an opaque RGB JPEG still decodes with alpha 255 on a worker isolate', () async {
    final image = img.Image(width: 8, height: 8)..clear(img.ColorRgb8(10, 200, 30));
    final offRoot = await Isolate.run(() => _decodeOffRoot(img.encodeJpg(image, quality: 100)));
    expect({for (var i = 3; i < offRoot.rgba.length; i += 4) offRoot.rgba[i]}, {255});
  });

  test('the root isolate has the platform codec, a worker isolate does not', () async {
    expect(EncodedImageDecoder.platformCodecAvailable, isTrue);
    expect(await Isolate.run(() => EncodedImageDecoder.platformCodecAvailable), isFalse);
  });

  for (final format in [
    EncodedImageFormat.png,
    EncodedImageFormat.jpeg,
    EncodedImageFormat.webp,
    EncodedImageFormat.gif,
    EncodedImageFormat.bmp,
    EncodedImageFormat.tga,
  ]) {
    test('${format.name} decodes to the same premultiplied texels on the root and on a worker isolate', () async {
      if (skipIfNoAssets()) return;
      final bytes = encoded[format]!;
      final onRoot = (await EncodedImageDecoder.decodeRgba(bytes))!;
      final offRoot = await Isolate.run(() => _decodeOffRoot(bytes));
      expect((offRoot.width, offRoot.height), (512, 256));
      expect((onRoot.width, onRoot.height), (512, 256));
      final diff = _maxAbsDiff(onRoot.rgba, offRoot.rgba);
      // Lossless formats match texel for texel; the two JPEG and lossy WebP
      // decoders may round a colour conversion differently.
      final tolerance = switch (format) {
        EncodedImageFormat.jpeg || EncodedImageFormat.webp => 3,
        _ => 0,
      };
      expect(diff, lessThanOrEqualTo(tolerance), reason: '${format.name}: largest channel difference $diff');
    });
  }
}

Future<DecodedRgbaImage> _decodeOffRoot(Uint8List bytes) async => (await EncodedImageDecoder.decodeRgba(bytes))!;

int _maxAbsDiff(Uint8List a, Uint8List b) {
  if (a.length != b.length) return 255;
  var worst = 0;
  for (var i = 0; i < a.length; i++) {
    final d = (a[i] - b[i]).abs();
    if (d > worst) worst = d;
  }
  return worst;
}
