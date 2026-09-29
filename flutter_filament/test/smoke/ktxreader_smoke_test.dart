// ktxreader smoke: a UASTC/zstd KTX2 (Ktx2Reader, GPU transcode) is mapped
// onto a quad and rendered; a KTX1 cubemap bundle (Ktx1Bundle/Ktx1Reader)
// becomes a Filament cubemap texture used as a skybox.
import 'dart:io';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_filament/testing.dart';
import 'package:test/test.dart';

import 'smoke_helper.dart';

void main() {
  group('KtxReader Smoke Tests', () {
    late SmokeRig rig;

    setUp(() {
      SmokeArtifacts.resetRecordedAssets();
      rig = SmokeRig.create(width: 256, height: 256);
      rig.camera.setProjectionOrtho(left: -1, right: 1, bottom: -1, top: 1, near: 0.1, far: 10);
      rig.camera.lookAt(eyeX: 0, eyeY: 0, eyeZ: 2, centerX: 0, centerY: 0, centerZ: 0);
    });

    tearDown(() => rig.dispose());

    test('KtxReader: KTX2 UASTC colour grid transcodes and renders on a quad', () {
      final file = File('test/assets/color_grid_uastc_zstd.ktx2');
      SmokeArtifacts.recordAsset(file.absolute.path);
      final reader = Ktx2Reader(rig.engine);
      expect(reader.requestFormat(TextureFormat.srgb8A8), Ktx2Result.success);
      expect(reader.requestFormat(TextureFormat.srgb8A8), Ktx2Result.formatAlreadyRequested);
      reader.requestFormat(TextureFormat.rgba8);
      final texture = reader.load(file.readAsBytesSync(), Ktx2TransferFunction.sRGB);
      expect(texture, isNotNull);
      expect(texture!.width(), greaterThan(1));
      smokeLog('ktx2 ${texture.width()}x${texture.height()} levels=${texture.levels} format=${texture.format}');

      final material = buildUnlitMaterial(rig.engine, textured: true);
      final mi = material.createInstance()
        ..setFloat3('baseColor', 1, 1, 1)
        ..setTexture('tex', texture, sampler: const TextureSampler.trilinear());
      final quad = SmokeQuad.create(rig.engine, size: 1.8);
      addQuadRenderable(rig, quad, mi);
      final px = rig.screenshot('KtxReader Smoke Tests KtxReader: KTX2 UASTC colour grid transcodes and renders on a quad');
      final stats = frameStats(px);
      smokeLog('ktx2 quad $stats');
      expect(stats.distinct, greaterThan(50), reason: 'colour grid has many distinct colours');
      expect(countForegroundPixels(px, rig.width), greaterThan(rig.width * rig.height ~/ 2));

      rig.releaseEntities(); // Renderables before their material instance
      mi.dispose();
      material.dispose();
      quad.dispose();
      texture.dispose();
      reader.destroy();
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('KtxReader: KTX1 cubemap bundle becomes a skybox texture', () {
      final file = File('example/assets/ibl/lightroom_14b/lightroom_14b_skybox.ktx');
      SmokeArtifacts.recordAsset(file.absolute.path);
      final bundle = Ktx1Bundle(file.readAsBytesSync());
      expect(bundle.isCubemap, isTrue);
      expect(bundle.numMipLevels, greaterThanOrEqualTo(1));
      final face = bundle.getBlob(mipLevel: 0, face: 0);
      expect(face, isNotNull);
      expect(face!.length, greaterThan(0));
      final texture = Ktx1Reader.createTexture(rig.engine, bundle, srgb: true);
      expect(bundle.isDestroyed, isTrue, reason: 'ownership moves to the engine');
      expect(texture, isNotNull);
      expect(texture!.target, TextureSamplerType.samplerCubemap);

      final sky = FilamentSkybox.build(rig.engine, environment: texture);
      rig.scene.skybox = sky;
      rig.camera.setProjection(fovDegrees: 90, aspect: 1, near: 0.1, far: 100);
      final px = rig.screenshot('KtxReader Smoke Tests KtxReader: KTX1 cubemap bundle becomes a skybox texture');
      final stats = frameStats(px);
      smokeLog('ktx1 skybox $stats');
      expect(stats.distinct, greaterThan(1000), reason: 'photographic environment fills the frame');

      rig.scene.skybox = null;
      sky.dispose();
      texture.dispose();
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}
