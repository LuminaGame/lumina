// image smoke: the real milkyway.png is decoded (imageio), resampled and
// colour-transformed (LinearImage ops), re-encoded to PNG, uploaded as a GPU
// texture and rendered on a quad.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_filament/testing.dart';
import 'package:test/test.dart';

import 'smoke_helper.dart';

void main() {
  group('Image Smoke Tests', () {
    late SmokeRig rig;

    setUp(() {
      SmokeArtifacts.resetRecordedAssets();
      rig = SmokeRig.create(width: 256, height: 256);
      rig.camera.setProjectionOrtho(left: -1, right: 1, bottom: -1, top: 1, near: 0.1, far: 10);
      rig.camera.lookAt(eyeX: 0, eyeY: 0, eyeZ: 2, centerX: 0, centerY: 0, centerZ: 0);
      rig.view.postProcessingEnabled = false;
    });

    tearDown(() => rig.dispose());

    test('Image: decode → resample → colour transform → encode → GPU texture', () {
      final file = File('example/assets/sky/milkyway.png');
      SmokeArtifacts.recordAsset(file.absolute.path);
      final decoded = decodeImage(file.readAsBytesSync(), sourceName: 'milkyway.png');
      expect(decoded.width, greaterThan(64));
      expect(decoded.channels, anyOf(3, 4));
      print('milkyway ${decoded.width}x${decoded.height}x${decoded.channels}');

      final small = resampleImage(decoded, 128, 64, filter: ImageFilter.lanczos);
      expect(small.width, 128);
      expect(small.height, 64);
      final flipped = verticalFlip(small);
      expect(compareImages(small, flipped, epsilon: 1e-3), isNot(0), reason: 'flip changes the image');
      final mips = generateMipmaps(small);
      expect(mips.length, getMipmapCount(small));
      expect(mips.length, greaterThanOrEqualTo(3));
      expect(mips[0].width, 64, reason: 'first generated level halves 128');
      final srgb = linearToSrgb(small);
      final gray = toGrayscale(srgb);
      expect(gray.channels, 1);

      final png = encodeImage(ImageEncoderFormat.png, srgb);
      expect(png.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
      final roundTrip = decodeImage(png, colorSpace: ImageColorSpace.linear, sourceName: 'rt.png');
      expect(roundTrip.width, 128);

      // Upload as RGBA8 (LinearImage floats → bytes).
      final w = srgb.width, h = srgb.height, c = srgb.channels;
      final rgba = Uint8List(w * h * 4);
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          for (var k = 0; k < 4; k++) {
            final v = k < c ? srgb.getPixel(x, y, k) : 1.0;
            rgba[(y * w + x) * 4 + k] = (v.clamp(0.0, 1.0) * 255).round();
          }
        }
      }
      final texture = FilamentTexture.create2D(engine: rig.engine, width: w, height: h, format: TextureFormat.srgb8A8, levels: 1);
      texture.setImage(pixelData: rgba, width: w, height: h, pixelFormat: PixelFormat.rgba, pixelType: PixelType.ubyte);
      final material = buildUnlitMaterial(rig.engine, textured: true);
      final mi = material.createInstance()
        ..setFloat3('baseColor', 1, 1, 1)
        ..setTexture('tex', texture, sampler: const TextureSampler(filterMin: SamplerMinFilter.linear, filterMag: SamplerMagFilter.linear));
      final quad = SmokeQuad.create(rig.engine, size: 1.9);
      addQuadRenderable(rig, quad, mi);
      final px = rig.screenshot('Image Smoke Tests Image: decode → resample → colour transform → encode → GPU texture');
      final stats = frameStats(px);
      print('milkyway quad $stats');
      expect(stats.distinct, greaterThan(500), reason: 'photographic texture on screen');

      rig.releaseEntities(); // Renderables before their material instance
      mi.dispose();
      material.dispose();
      quad.dispose();
      texture.dispose();
      for (final m in mips) {
        m.destroy();
      }
      roundTrip.destroy();
      gray.destroy();
      srgb.destroy();
      flipped.destroy();
      small.destroy();
      decoded.destroy();
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}
