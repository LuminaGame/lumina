// iblprefilter smoke: a procedural HDR equirect (bright warm sun, blue sky,
// dark ground) is converted to a cubemap and prefiltered on the GPU into
// specular reflections + irradiance; the result lights a real barrel.
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_filament/testing.dart';
import 'package:test/test.dart';

import 'smoke_helper.dart';

/// Float16 encoder for the equirect upload.
int _half(double v) {
  final f = Float32List(1)..[0] = v;
  final bits = f.buffer.asUint32List()[0];
  final sign = (bits >> 16) & 0x8000;
  var exp = ((bits >> 23) & 0xff) - 127 + 15;
  var mant = bits & 0x7fffff;
  if (exp <= 0) return sign;
  if (exp >= 31) return sign | 0x7c00;
  return sign | (exp << 10) | (mant >> 13);
}

void main() {
  group('IblPrefilter Smoke Tests', () {
    late SmokeRig rig;

    setUp(() {
      SmokeArtifacts.resetRecordedAssets();
      rig = SmokeRig.create(width: 320, height: 240);
    });

    tearDown(() {
      rig.dispose();
      SmokeArtifacts.resetRecordedAssets();
    });

    test('IblPrefilter: equirect → cubemap → specular/irradiance filters light a real prop', () {
      const w = 128, h = 64;
      final pixels = Uint8List(w * h * 8);
      final bd = ByteData.sublistView(pixels);
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          final v = y / h;
          final u = x / w;
          double r, g, b;
          if (v < 0.5) {
            r = 0.3; g = 0.5; b = 1.2; // sky
          } else {
            r = 0.25; g = 0.18; b = 0.1; // ground
          }
          final sun = math.exp(-(math.pow((u - 0.25) * 30, 2) + math.pow((v - 0.2) * 30, 2)));
          r += sun * 40; g += sun * 30; b += sun * 15;
          final o = (y * w + x) * 8;
          bd.setUint16(o, _half(r), Endian.little);
          bd.setUint16(o + 2, _half(g), Endian.little);
          bd.setUint16(o + 4, _half(b), Endian.little);
          bd.setUint16(o + 6, _half(1), Endian.little);
        }
      }
      final equirect = FilamentTexture.create2D(
        engine: rig.engine, width: w, height: h, levels: 8, format: TextureFormat.rgba16f,
        usage: TextureUsage.sampleable | TextureUsage.uploadable | TextureUsage.colorAttachment | TextureUsage.genMipmappable,
      );
      equirect.setImage(width: w, height: h, level: 0, pixelData: pixels, pixelFormat: PixelFormat.rgba, pixelType: PixelType.half);
      equirect.generateMipmaps(rig.engine);

      final ctx = IblPrefilterContext(rig.engine);
      final toCube = EquirectangularToCubemap(ctx);
      final envCube = toCube.run(equirect);
      toCube.destroy();
      expect(envCube.target, TextureSamplerType.samplerCubemap);
      expect(envCube.width(), greaterThanOrEqualTo(64));

      final specular = SpecularFilter(ctx, SpecularFilterConfig(sampleCount: 256));
      final reflections = specular.run(envCube);
      specular.destroy();
      expect(reflections.levels, greaterThan(1), reason: 'roughness mip chain');
      final irradianceFilter = IrradianceFilter(ctx, IrradianceFilterConfig(sampleCount: 256));
      final irradiance = irradianceFilter.run(envCube);
      irradianceFilter.destroy();
      expect(irradiance.target, TextureSamplerType.samplerCubemap);
      print('prefilter env=${envCube.width()} reflections=${reflections.width()} levels=${reflections.levels} irradiance=${irradiance.width()}');

      final ibl = FilamentIndirectLight.build(rig.engine, reflections: reflections, irradiance: null, intensity: 30000);
      rig.scene.setIndirectLight(ibl);
      final gltf = loadGltfIntoScene(rig, 'Props/Barrels/bent_barrel.glb');
      try {
        final px = rig.screenshot('IblPrefilter Smoke Tests IblPrefilter: equirect → cubemap → specular/irradiance filters light a real prop');
        final fg = countForegroundPixels(px, rig.width);
        final stats = frameStats(px);
        print('prefiltered IBL barrel fg=$fg $stats');
        expect(fg, greaterThan(rig.width * rig.height ~/ 40));
        expect(stats.distinct, greaterThan(300), reason: 'reflections shade the barrel');
        rig.scene.setIndirectLight(null);
        final unlit = rig.renderFrame();
        expect(countChangedPixels(px, unlit), greaterThan(fg ~/ 4), reason: 'removing the IBL darkens the prop');
      } finally {
        gltf.dispose(rig.scene);
        rig.scene.setIndirectLight(null);
        ibl.dispose();
        irradiance.dispose();
        reflections.dispose();
        envCube.dispose();
        equirect.dispose();
        ctx.destroy();
      }
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}
