import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina/data/services/glb_parser_service.dart';

/// `convertGlbTgaToPng` enforces a texture budget, which means decoding and
/// resizing oversized source images — ~37 s for an asset carrying fourteen
/// 8192x8192 PNGs. Run on the UI isolate that freezes the editor for the whole
/// load, so `convertGlbTgaToPngAsync` moves the work to a background isolate.
void main() {
  group('GlbParserService.convertGlbTgaToPngAsync', () {
    test('produces byte-identical output to the synchronous path', () async {
      final glb = _glbWithEmbeddedPng(_solidPng(512, 512));

      final sync = GlbParserService.convertGlbTgaToPng(glb, maxTextureSize: 128);
      final async = await GlbParserService.convertGlbTgaToPngAsync(glb, maxTextureSize: 128);

      expect(async, equals(sync));
    });

    test('leaves the calling isolate responsive while it works', () async {
      final glb = _glbWithEmbeddedPng(_solidPng(2048, 2048));

      var ticks = 0;
      final ticker = Stream<void>.periodic(const Duration(milliseconds: 1))
          .listen((_) => ticks++);

      await GlbParserService.convertGlbTgaToPngAsync(glb, maxTextureSize: 256);
      await ticker.cancel();

      expect(
        ticks,
        greaterThan(0),
        reason: 'the event loop must keep turning while the worker downscales; '
            'the synchronous path would starve it for the whole resize',
      );
    });

    test('replays the worker isolate log lines onto the calling logger', () async {
      final logger = EngineLoggerService();
      logger.clear();
      final glb = _glbWithEmbeddedPng(_solidPng(512, 512));

      await GlbParserService.convertGlbTgaToPngAsync(glb, maxTextureSize: 64);

      final messages = logger.logs.map((e) => e.message).toList();
      expect(
        messages.any((m) => m.contains('Downscaled') && m.contains('512x512 → 64x64')),
        isTrue,
        reason: 'downscale lines produced inside the worker must reach the editor '
            'Output Log, not just the worker isolate stdout. Got: $messages',
      );
      expect(
        messages.any((m) => m.contains('Sanitized GLB textures')),
        isTrue,
      );
    });

    test('capturing logs suppresses direct emission and preserves timestamps', () {
      final logger = EngineLoggerService();
      logger.clear();

      final captured = logger.captureLogs(() {
        logger.log('captured line', level: 'success', source: 'UnitTest');
      });

      expect(captured, hasLength(1));
      expect(captured.single.message, equals('captured line'));
      expect(captured.single.level, equals('success'));
      expect(
        logger.logs,
        isEmpty,
        reason: 'a captured entry must not also land in the live log buffer',
      );

      logger.replay(captured);
      expect(logger.logs, hasLength(1));
      expect(
        logger.logs.single.timestamp,
        equals(captured.single.timestamp),
        reason: 'replay must keep the moment the work happened, not the replay time',
      );
    });
  });
}

Uint8List _solidPng(int width, int height) {
  final rgba = Uint8List(width * height * 4);
  for (int i = 0; i < rgba.length; i += 4) {
    rgba[i] = 90;
    rgba[i + 1] = 160;
    rgba[i + 2] = 210;
    rgba[i + 3] = 255;
  }
  return TgaDecoderService.encodePng(rgba, width, height);
}

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
  final bin = (BytesBuilder()
        ..add(png)
        ..add(Uint8List(binPad)))
      .toBytes();

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
