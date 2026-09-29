// skybox smoke: a KTX environment skybox (real lightroom cubemap) and a
// solid-colour skybox behind a real prop, with background pixels asserted.
import 'dart:io';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_filament/testing.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';

import 'smoke_helper.dart';

void main() {
  group('Skybox Smoke Tests', () {
    late SmokeRig rig;
    late FilamentIndirectLight ibl;

    setUp(() {
      SmokeArtifacts.resetRecordedAssets();
      rig = SmokeRig.create(width: 320, height: 240);
      rig.addSun();
      ibl = rig.addIbl();
    });

    tearDown(() {
      rig.scene.setIndirectLight(null);
      ibl.dispose();
      rig.dispose();
      SmokeArtifacts.resetRecordedAssets();
    });

    test('Skybox: KTX environment and solid colour backgrounds behind a real prop', () {
      final gltf = loadGltfIntoScene(rig, 'Props/AC_units/roof_aircon_unit_150x150_a.glb');
      try {
        final none = rig.renderFrame();
        final (nr, ng, nb) = pixelAt(none, rig.width, 4, 4);

        final ktxSky = FilamentSkybox.fromKtx(
          rig.engine,
          File('example/assets/ibl/lightroom_14b/lightroom_14b_skybox.ktx').readAsBytesSync(),
          showSun: true,
        );
        expect(rig.engine.isValidSkybox(ktxSky), isTrue);
        expect(ktxSky.texture, isNotNull);
        rig.scene.skybox = ktxSky;
        expect(rig.scene.skybox?.nativePointer.address, ktxSky.nativePointer.address);
        final env = rig.screenshot('Skybox Smoke Tests Skybox: KTX environment and solid colour backgrounds behind a real prop');
        final envStats = frameStats(env);
        final (er, eg, eb) = pixelAt(env, rig.width, 4, 4);
        print('bg none=($nr,$ng,$nb) env=($er,$eg,$eb) envDistinct=${envStats.distinct}');
        expect((er - nr).abs() + (eg - ng).abs() + (eb - nb).abs(), greaterThan(30), reason: 'environment replaces the clear colour');
        expect(envStats.distinct, greaterThan(2000), reason: 'a photographic cubemap has many colours');

        final solid = FilamentSkybox.build(rig.engine, color: Vector4(0.9, 0.1, 0.1, 1.0));
        rig.scene.skybox = solid;
        final red = rig.renderFrame();
        final (sr, sg, sb) = pixelAt(red, rig.width, 4, 4);
        print('solid bg=($sr,$sg,$sb)');
        // Tone mapping lifts the dark channels, so compare channel dominance.
        expect(sr, greaterThan(200));
        expect(sg, lessThan(sr - 80));
        expect(sb, lessThan(sr - 80));
        solid.setColor(r: 0.1, g: 0.1, b: 0.9, a: 1.0);
        final blue = rig.renderFrame();
        final (br, _, bb) = pixelAt(blue, rig.width, 4, 4);
        expect(bb, greaterThan(150));
        expect(br, lessThan(bb - 60));

        rig.scene.skybox = null;
        solid.dispose();
        ktxSky.dispose();
      } finally {
        gltf.dispose(rig.scene);
      }
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}
