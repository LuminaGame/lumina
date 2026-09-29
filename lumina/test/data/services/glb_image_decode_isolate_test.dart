import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumina/data/services/fbx_import_service.dart';
import 'package:lumina/data/services/glb_animation_merger.dart';
import 'package:lumina/data/services/glb_parser_service.dart';
import 'package:lumina/data/services/tga_decoder_service.dart';
import 'package:lumina/testing.dart';

import '../../helpers/oversized_glb_fixture.dart';
import '../../helpers/peak_rss.dart';

/// Off the root isolate `dart:ui`'s image codec is unavailable, and
/// `parseGlb` used to hand whatever it could not decode to the TGA decoder. A
/// PNG's `IHDR` chunk tag read as a TGA header is an 18505x21060 image, so each
/// PNG texture allocated ~1.56 GB of zeros and baked black vertex colours.
///
/// Every image here is the real `Props/Barrels/dented_barrel.glb` texture
/// (512x256), re-encoded by real encoders in memory.
void main() {
  final barrelFile = File('${SmokeArtifacts.testAssetsDir.path}/Props/Barrels/dented_barrel.glb');
  final ktx2File = File('../flutter_filament/test/assets/roughness.ktx2');

  late Uint8List barrel;
  late img.Image texture;
  late Uint8List png;
  late Uint8List jpeg;
  late Uint8List tga;
  late Uint8List webp;

  setUpAll(() {
    if (!barrelFile.existsSync()) return;
    barrel = barrelFile.readAsBytesSync();
    final doc = GlbDocument.parse(barrel);
    final image = (doc.json['images'] as List).first as Map;
    final view = (doc.json['bufferViews'] as List)[image['bufferView'] as int] as Map;
    final at = (view['byteOffset'] as int?) ?? 0;
    webp = doc.bin.sublist(at, at + (view['byteLength'] as int));
    texture = img.decodeImage(webp)!;
    png = img.encodePng(texture, level: 1);
    jpeg = img.encodeJpg(texture, quality: 95);
    tga = img.encodeTga(texture);
  });

  bool skipIfNoAssets() {
    if (barrelFile.existsSync()) return false;
    markTestSkipped('test-assets missing: ${barrelFile.path}');
    return true;
  }

  group('TgaDecoderService refuses what is not a TGA it can hold', () {
    test('a PNG is not read as an 18505x21060 TGA', () {
      if (skipIfNoAssets()) return;
      final watch = Stopwatch()..start();
      final decoded = TgaDecoderService.decode(png);
      watch.stop();
      expect(
        decoded == null ? null : '${decoded.width}x${decoded.height}',
        isNull,
        reason: 'the PNG signature is not a TGA header (took ${watch.elapsedMilliseconds} ms)',
      );
      expect(TgaDecoderService.tgaToPng(png), isNull);
    });

    test('JPEG, WebP and KTX2 bytes are refused too', () {
      if (skipIfNoAssets()) return;
      expect(TgaDecoderService.decode(jpeg), isNull);
      expect(TgaDecoderService.decode(webp), isNull);
      if (ktx2File.existsSync()) {
        expect(TgaDecoderService.decode(ktx2File.readAsBytesSync()), isNull);
      }
    });

    test('a header claiming more pixels than its data can hold allocates nothing', () {
      if (skipIfNoAssets()) return;
      // Uncompressed: the real 512x256 barrel TGA with its size fields
      // rewritten to 16384x16384 (805 MB of BGR the file does not carry).
      final lying = Uint8List.fromList(tga);
      ByteData.sublistView(lying)
        ..setUint16(12, 16384, Endian.little)
        ..setUint16(14, 16384, Endian.little);
      expect(TgaDecoderService.decode(lying), isNull);

      // RLE: one 128-pixel run packet cannot fill a 16384x16384 image.
      final rle = Uint8List.fromList([
        0, 0, 10, 0, 0, 0, 0, 0, 0, 0, 0, 0, //
        0x00, 0x40, 0x00, 0x40, // 16384 x 16384
        24, 0x20,
        0xFF, 30, 60, 90,
      ]);
      expect(TgaDecoderService.decode(rle), isNull);
    });

    test('a real TGA still decodes to the pixels package:image reads', () {
      if (skipIfNoAssets()) return;
      final decoded = TgaDecoderService.decode(tga)!;
      expect((decoded.width, decoded.height), (512, 256));
      final reference = img.decodeTga(tga)!.convert(numChannels: 4).getBytes(order: img.ChannelOrder.rgba);
      expect(decoded.rgbaBytes, equals(reference));
    });
  });

  group('parseGlb bakes the same vertex colours on any isolate', () {
    for (final format in ['png', 'jpeg', 'webp', 'tga']) {
      test('$format base colour texture', () async {
        if (skipIfNoAssets()) return;
        final glb = switch (format) {
          'png' => oversizedGlbFromTestAsset(barrel, longEdge: 512),
          'jpeg' => oversizedGlbFromTestAsset(barrel, longEdge: 512, encode: img.encodeJpg, mimeType: 'image/jpeg'),
          'tga' => oversizedGlbFromTestAsset(barrel, longEdge: 512, encode: img.encodeTga, mimeType: 'image/x-tga'),
          _ => barrel,
        };

        final rootWatch = Stopwatch()..start();
        final onRoot = (await GlbParserService.parseGlb(glb))!;
        rootWatch.stop();
        final peak = PeakRss.start();
        final background = await _parseOnBackgroundIsolate(glb);
        final grownMb = peak?.grownMb();
        // ignore: avoid_print
        print('[image decode] $format: root isolate ${rootWatch.elapsedMilliseconds} ms, '
            'background isolate ${background.micros ~/ 1000} ms, peak RSS +${grownMb ?? '?'} MB');

        final rootColors = onRoot.vertexColors!;
        expect(_mean(rootColors), greaterThan(30.0), reason: 'the root isolate bakes the barrel texture');
        final diff = _maxAbsDiff(rootColors, background.colors);
        expect(
          diff,
          lessThanOrEqualTo(format == 'png' || format == 'tga' ? 0 : 3),
          reason: 'background mean ${_mean(background.colors).toStringAsFixed(1)} vs root '
              '${_mean(rootColors).toStringAsFixed(1)}: the same texture must bake the same colours on any isolate',
        );
        if (grownMb != null) {
          expect(grownMb, lessThan(256), reason: 'decoding a 512x256 texture must not allocate gigabytes');
        }
      }, timeout: const Timeout(Duration(minutes: 3)));
    }
  });

  group('the sanitizer picks the decoder from the bytes, not the label', () {
    test('a .tga uri that resolves to a .png keeps the PNG', () {
      if (skipIfNoAssets()) return;
      final dir = Directory.systemTemp.createTempSync('lumina_bug30_uri_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final glb = oversizedGlbFromTestAsset(barrel,
          longEdge: 512, externalImageName: 'T_DentedBarrel.png', writeImageNextTo: dir, mimeType: 'image/x-tga');
      final doc = GlbDocument.parse(glb);
      ((doc.json['images'] as List).first as Map)['uri'] = 'T_DentedBarrel.tga';

      final sanitized = GlbParserService.convertGlbTgaToPng(doc.encode(), searchDirs: [dir.path]);

      expect(_embeddedImages(sanitized).single, equals(File('${dir.path}/T_DentedBarrel.png').readAsBytesSync()));
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('an embedded PNG labelled image/tga keeps the PNG', () {
      if (skipIfNoAssets()) return;
      final glb = oversizedGlbFromTestAsset(barrel, longEdge: 512, mimeType: 'image/tga');

      final sanitized = GlbParserService.convertGlbTgaToPng(glb);

      final embedded = _embeddedImages(sanitized).single;
      expect(img.decodePng(embedded)?.width, 512);
      final label = ((GlbDocument.parse(sanitized).json['images'] as List).single as Map)['mimeType'];
      expect(label, 'image/png', reason: 'Filament picks its texture provider by this label');
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('FBX import embeds a PNG saved as .tga as a PNG, and a JPEG saved as .png as a JPEG', () {
      if (skipIfNoAssets()) return;
      final dir = Directory.systemTemp.createTempSync('lumina_bug30_fbx_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final doc = GlbDocument.parse(barrel);
      File('${dir.path}/T_Color.tga').writeAsBytesSync(png);
      File('${dir.path}/T_Photo.png').writeAsBytesSync(jpeg);
      doc.json['images'] = [
        {'uri': 'T_Color.tga'},
        {'uri': 'T_Photo.png'},
      ];
      doc.json['textures'] = [
        {'source': 0},
        {'source': 1},
      ];
      doc.json.remove('extensionsUsed');
      doc.json.remove('extensionsRequired');

      final result = FbxImportService.resolveExternalImages(doc.encode(), sourceDir: dir);

      expect(result.missing, isEmpty);
      final out = GlbDocument.parse(result.glb);
      final images = (out.json['images'] as List).cast<Map>();
      expect(images.map((i) => i['mimeType']), ['image/png', 'image/jpeg']);
      final bytes = _embeddedImages(result.glb);
      expect(bytes[0], equals(png), reason: 'the PNG is embedded as it is, not transcoded from a misread TGA header');
      expect(bytes[1], equals(jpeg));
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}

/// [glb]'s baked vertex colours, parsed in a fresh isolate (no `dart:ui`
/// image codec there).
Future<({Uint8List colors, int micros})> _parseOnBackgroundIsolate(Uint8List glb) => Isolate.run(() async {
      final watch = Stopwatch()..start();
      final mesh = (await GlbParserService.parseGlb(glb))!;
      return (colors: mesh.vertexColors!, micros: watch.elapsedMicroseconds);
    });

/// The bytes of every image embedded in [glb], in image order.
List<Uint8List> _embeddedImages(Uint8List glb) {
  final doc = GlbDocument.parse(glb);
  final views = (doc.json['bufferViews'] as List).cast<Map>();
  return [
    for (final image in (doc.json['images'] as List).cast<Map>())
      if (image['bufferView'] is int)
        () {
          final view = views[image['bufferView'] as int];
          final at = (view['byteOffset'] as int?) ?? 0;
          return doc.bin.sublist(at, at + (view['byteLength'] as int));
        }(),
  ];
}

double _mean(Uint8List bytes) {
  var sum = 0;
  for (final b in bytes) {
    sum += b;
  }
  return bytes.isEmpty ? 0 : sum / bytes.length;
}

int _maxAbsDiff(Uint8List a, Uint8List b) {
  if (a.length != b.length) return 255;
  var worst = 0;
  for (var i = 0; i < a.length; i++) {
    final d = (a[i] - b[i]).abs();
    if (d > worst) worst = d;
  }
  return worst;
}
