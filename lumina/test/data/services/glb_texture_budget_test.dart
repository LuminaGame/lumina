import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/data/services/glb_parser_service.dart';
import 'package:lumina/data/services/tga_decoder_service.dart';

/// Regression coverage: a GLB import must not keep 8K textures uncompressed
/// and exhaust VRAM.
///
/// `convertGlbTgaToPng` used to re-embed every source image at its original
/// resolution. An 8192x8192 RGBA8 texture costs ~341 MB of VRAM once Filament
/// has built its mip chain, so a handful of such images exhausted the device
/// heap and Filament aborted the process in `VulkanTexture` with
/// `Unable to allocate image memory. error=-2`.
void main() {
  group('GlbParserService texture budget', () {
    test('downscales an oversized embedded PNG to the default 2048 budget', () {
      final glb = _glbWithEmbeddedPng(_solidPng(4096, 4096));

      final sanitized = GlbParserService.convertGlbTgaToPng(glb);

      final dims = _embeddedImageDimensions(sanitized);
      expect(dims, hasLength(1));
      expect(
        dims.single,
        equals(const _Dim(2048, 2048)),
        reason: 'a 4096x4096 source image must be downscaled to the 2048 budget '
            'so it costs ~21 MB of VRAM instead of ~85 MB',
      );
    });

    test('preserves aspect ratio when downscaling a non-square image', () {
      final glb = _glbWithEmbeddedPng(_solidPng(4096, 1024));

      final sanitized = GlbParserService.convertGlbTgaToPng(glb);

      expect(_embeddedImageDimensions(sanitized).single, equals(const _Dim(2048, 512)));
    });

    test('leaves an image that is already within budget untouched', () {
      final png = _solidPng(256, 256);
      final glb = _glbWithEmbeddedPng(png);

      final sanitized = GlbParserService.convertGlbTgaToPng(glb);

      expect(_embeddedImageDimensions(sanitized).single, equals(const _Dim(256, 256)));
      expect(
        _embeddedImageBytes(sanitized).single,
        equals(png),
        reason: 'an in-budget image must not be re-encoded',
      );
    });

    test('honours an explicit maxTextureSize', () {
      final glb = _glbWithEmbeddedPng(_solidPng(512, 512));

      final sanitized = GlbParserService.convertGlbTgaToPng(glb, maxTextureSize: 64);

      expect(_embeddedImageDimensions(sanitized).single, equals(const _Dim(64, 64)));
    });

    test('maxTextureSize: 0 disables the budget', () {
      final glb = _glbWithEmbeddedPng(_solidPng(4096, 4096));

      final sanitized = GlbParserService.convertGlbTgaToPng(glb, maxTextureSize: 0);

      expect(_embeddedImageDimensions(sanitized).single, equals(const _Dim(4096, 4096)));
    });

    // An in-budget WebP texture is read from its header, so
    // the real WebP props stay on the cheap, synchronous path (and out of the
    // persistent derived-data cache) instead of being decoded to learn their size.
    test('inspectImageWork reads WebP headers of a real prop', () {
      final assets = Platform.environment['LUMINA_TEST_ASSETS'] ?? '${Directory.current.parent.path}/test-assets';
      final barrel = File('$assets/Props/Barrels/dented_barrel.glb');
      if (!barrel.existsSync()) return markTestSkipped('test-assets missing');
      final glb = barrel.readAsBytesSync();

      final inBudget = GlbParserService.inspectImageWork(glb);
      expect(inBudget.needsDecoding, isFalse, reason: 'a 512x256 WebP fits the 2048 budget');
      expect(inBudget.selfContained, isTrue);

      final overBudget = GlbParserService.inspectImageWork(glb, maxTextureSize: 256);
      expect(overBudget.needsDecoding, isTrue, reason: '512 px is over a 256 budget');
      expect(overBudget.selfContained, isTrue);
    });

    test('inspectImageWork reports an image referenced by uri as not self-contained', () {
      final png = _solidPng(8, 8);
      final glb = _glbWithEmbeddedPng(png);
      final data = ByteData.sublistView(glb);
      final jsonLength = data.getUint32(12, Endian.little);
      final json = jsonDecode(utf8.decode(glb.sublist(20, 20 + jsonLength))) as Map<String, dynamic>;
      (json['images'] as List).first = {'uri': 'basecolor.png'};
      final external = _glbFromJson(json, Uint8List(0));

      final work = GlbParserService.inspectImageWork(external);
      expect(work.needsDecoding, isTrue);
      expect(work.selfContained, isFalse);
    });
  });
}

Uint8List _glbFromJson(Map<String, dynamic> json, Uint8List bin) {
  var jsonBytes = utf8.encode(jsonEncode(json));
  final pad = (4 - jsonBytes.length % 4) % 4;
  jsonBytes = Uint8List.fromList([...jsonBytes, ...List.filled(pad, 0x20)]);
  final total = 12 + 8 + jsonBytes.length + (bin.isEmpty ? 0 : 8 + bin.length);
  final out = BytesBuilder()
    ..add((ByteData(12)
          ..setUint32(0, 0x46546C67, Endian.little)
          ..setUint32(4, 2, Endian.little)
          ..setUint32(8, total, Endian.little))
        .buffer
        .asUint8List())
    ..add((ByteData(8)
          ..setUint32(0, jsonBytes.length, Endian.little)
          ..setUint32(4, 0x4E4F534A, Endian.little))
        .buffer
        .asUint8List())
    ..add(jsonBytes);
  return out.toBytes();
}

class _Dim {
  final int width;
  final int height;
  const _Dim(this.width, this.height);

  @override
  bool operator ==(Object other) =>
      other is _Dim && other.width == width && other.height == height;

  @override
  int get hashCode => Object.hash(width, height);

  @override
  String toString() => '${width}x$height';
}

/// A solid-colour RGBA PNG of the requested size, built with the engine's own
/// pure-Dart encoder so the fixture needs no external asset.
Uint8List _solidPng(int width, int height) {
  final rgba = Uint8List(width * height * 4);
  for (int i = 0; i < rgba.length; i += 4) {
    rgba[i] = 180;
    rgba[i + 1] = 120;
    rgba[i + 2] = 60;
    rgba[i + 3] = 255;
  }
  return TgaDecoderService.encodePng(rgba, width, height);
}

/// Minimal GLB carrying [png] as `images[0]` through a bufferView, plus the
/// `textures`/`materials` entries a real asset would have.
Uint8List _glbWithEmbeddedPng(Uint8List png) {
  final json = {
    'asset': {'version': '2.0'},
    'buffers': [
      {'byteLength': png.length},
    ],
    'bufferViews': [
      {'buffer': 0, 'byteOffset': 0, 'byteLength': png.length},
    ],
    'images': [
      {'bufferView': 0, 'mimeType': 'image/png'},
    ],
    'textures': [
      {'source': 0},
    ],
    'materials': [
      {
        'pbrMetallicRoughness': {
          'baseColorTexture': {'index': 0},
        },
      },
    ],
  };

  var jsonStr = jsonEncode(json);
  var jsonBytes = utf8.encode(jsonStr);
  final pad = (4 - (jsonBytes.length % 4)) % 4;
  if (pad > 0) {
    jsonStr += ' ' * pad;
    jsonBytes = utf8.encode(jsonStr);
  }

  final binPad = (4 - (png.length % 4)) % 4;
  final binBytes = BytesBuilder()
    ..add(png)
    ..add(Uint8List(binPad));
  final bin = binBytes.toBytes();

  final builder = BytesBuilder();
  builder.add(
    (ByteData(12)
          ..setUint32(0, 0x46546C67, Endian.little)
          ..setUint32(4, 2, Endian.little)
          ..setUint32(8, 12 + 8 + jsonBytes.length + 8 + bin.length, Endian.little))
        .buffer
        .asUint8List(),
  );
  builder.add(
    (ByteData(8)
          ..setUint32(0, jsonBytes.length, Endian.little)
          ..setUint32(4, 0x4E4F534A, Endian.little))
        .buffer
        .asUint8List(),
  );
  builder.add(jsonBytes);
  builder.add(
    (ByteData(8)
          ..setUint32(0, bin.length, Endian.little)
          ..setUint32(4, 0x004E4942, Endian.little))
        .buffer
        .asUint8List(),
  );
  builder.add(bin);
  return builder.toBytes();
}

List<Uint8List> _embeddedImageBytes(Uint8List glb) {
  final byteData = ByteData.sublistView(glb);
  final jsonLength = byteData.getUint32(12, Endian.little);
  final json = jsonDecode(utf8.decode(glb.sublist(20, 20 + jsonLength))) as Map;
  final binStart = 20 + jsonLength + 8;
  final bufferViews = json['bufferViews'] as List;

  return [
    for (final img in (json['images'] as List? ?? const []))
      () {
        final bv = bufferViews[(img as Map)['bufferView'] as int] as Map;
        final offset = (bv['byteOffset'] as int?) ?? 0;
        final length = bv['byteLength'] as int;
        return glb.sublist(binStart + offset, binStart + offset + length);
      }(),
  ];
}

/// Reads width/height straight out of each embedded PNG's IHDR chunk.
List<_Dim> _embeddedImageDimensions(Uint8List glb) {
  return [
    for (final png in _embeddedImageBytes(glb))
      () {
        expect(
          png.sublist(0, 8),
          equals(const [137, 80, 78, 71, 13, 10, 26, 10]),
          reason: 'embedded image should still be a PNG',
        );
        final ihdr = ByteData.sublistView(png, 16, 24);
        return _Dim(ihdr.getUint32(0, Endian.big), ihdr.getUint32(4, Endian.big));
      }(),
  ];
}
