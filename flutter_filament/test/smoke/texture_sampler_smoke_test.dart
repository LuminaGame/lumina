// texture_sampler smoke: a 2x2 checker texture magnified over a quad with
// nearest vs linear sampling; nearest keeps hard edges (few distinct colours),
// linear blends (many). Both frames are published as PNGs.
import 'dart:typed_data';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_filament/testing.dart';
import 'package:test/test.dart';

import 'smoke_helper.dart';

void main() {
  group('TextureSampler Smoke Tests', () {
    late SmokeRig rig;

    setUp(() {
      SmokeArtifacts.resetRecordedAssets();
      rig = SmokeRig.create(width: 256, height: 256);
      rig.camera.setProjectionOrtho(left: -1, right: 1, bottom: -1, top: 1, near: 0.1, far: 10);
      rig.camera.lookAt(eyeX: 0, eyeY: 0, eyeZ: 2, centerX: 0, centerY: 0, centerZ: 0);
      rig.view.postProcessingEnabled = false;
    });

    tearDown(() => rig.dispose());

    test('TextureSampler: nearest vs linear magnification of a 2x2 checker', () {
      final texture = FilamentTexture.create2D(
        engine: rig.engine, width: 2, height: 2, format: TextureFormat.rgba8, levels: 1,
        usage: TextureUsage.defaultUsage,
      );
      // red, green / blue, white
      texture.setImage(
        pixelData: Uint8List.fromList([255, 0, 0, 255, 0, 255, 0, 255, 0, 0, 255, 255, 255, 255, 255, 255]),
        width: 2, height: 2, pixelFormat: PixelFormat.rgba, pixelType: PixelType.ubyte,
      );
      final material = buildUnlitMaterial(rig.engine, textured: true);
      final mi = material.createInstance();
      mi.setFloat3('baseColor', 1, 1, 1);
      final quad = SmokeQuad.create(rig.engine, size: 1.6);
      addQuadRenderable(rig, quad, mi);

      const nearest = TextureSampler(filterMin: SamplerMinFilter.nearest, filterMag: SamplerMagFilter.nearest);
      expect(nearest.packed, isNot(const TextureSampler.trilinear().packed));
      mi.setTexture('tex', texture, sampler: nearest);
      final nearestPx = rig.renderFrame();
      final nearestStats = frameStats(nearestPx);

      const linear = TextureSampler(filterMin: SamplerMinFilter.linear, filterMag: SamplerMagFilter.linear);
      mi.setTexture('tex', texture, sampler: linear);
      final linearPx = rig.screenshot('TextureSampler Smoke Tests TextureSampler: nearest vs linear magnification of a 2x2 checker');
      final linearStats = frameStats(linearPx);
      smokeLog('nearest=$nearestStats linear=$linearStats');

      // Nearest: bottom-left quadrant (UV origin is bottom-left) is the pure red texel.
      final (r, g, b) = pixelAt(nearestPx, rig.width, 64, 192);
      expect(r, greaterThan(200));
      expect(g, lessThan(40));
      expect(b, lessThan(40));
      expect(nearestStats.distinct, lessThan(40), reason: 'nearest keeps 4 flat texels + background');
      expect(linearStats.distinct, greaterThan(nearestStats.distinct * 4), reason: 'linear blends texels');

      rig.releaseEntities(); // Renderables before their material instance
      mi.dispose();
      material.dispose();
      quad.dispose();
      texture.dispose();
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}
