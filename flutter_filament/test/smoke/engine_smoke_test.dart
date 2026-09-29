// engine smoke: EngineConfig, feature level, backend and isValid* queries on
// a real GPU engine, plus a frame proving the configured engine renders.
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_filament/testing.dart';
import 'package:test/test.dart';

import 'smoke_helper.dart';

void main() {
  group('Engine Smoke Tests', () {
    test('Engine: config, capabilities, validity queries and a rendered frame', () {
      SmokeArtifacts.resetRecordedAssets();
      final engine = FilamentEngine.create(
        backend: smokeBackend,
        config: const EngineConfig(commandBufferSizeMB: 4, minCommandBufferSizeMB: 2, jobSystemThreadCount: 2),
      );
      expect(engine, isNotNull);
      final cfg = engine!.config;
      expect(cfg.commandBufferSizeMB, greaterThanOrEqualTo(4), reason: 'Filament clamps to >= 3x minCommandBufferSizeMB');
      expect(cfg.minCommandBufferSizeMB, 2);
      expect(cfg.jobSystemThreadCount, 2);
      expect(engine.backend, smokeBackend == FilamentBackend.defaultBackend ? isNotNull : smokeBackend);
      expect(engine.supportedFeatureLevel.index, greaterThanOrEqualTo(FeatureLevel.fl1.index));
      expect(engine.activeFeatureLevel, isNotNull);
      expect(engine.maxAutomaticInstances, greaterThanOrEqualTo(1));
      smokeLog('backend=${engine.backend} supported=${engine.supportedFeatureLevel} active=${engine.activeFeatureLevel}');

      final rig = SmokeRig.adopt(engine, width: 256, height: 256);
      expect(engine.isValidRenderer(rig.renderer), isTrue);
      expect(engine.isValidView(rig.view), isTrue);
      expect(engine.isValidScene(rig.scene), isTrue);
      expect(engine.isValidSwapChain(rig.swapChain), isTrue);
      expect(engine.isValidCamera(rig.camera), isTrue);

      rig.camera.setProjectionOrtho(left: -1, right: 1, bottom: -1, top: 1, near: 0.1, far: 10);
      rig.camera.lookAt(eyeX: 0, eyeY: 0, eyeZ: 2, centerX: 0, centerY: 0, centerZ: 0);
      final material = buildUnlitMaterial(engine);
      expect(engine.isValidMaterial(material.nativePointer), isTrue);
      final mi = material.createInstance()..setFloat3('baseColor', 0.2, 0.6, 1.0);
      expect(engine.isValidMaterialInstance(material.nativePointer, mi.nativePointer), isTrue);
      final quad = SmokeQuad.create(engine, size: 1.0);
      expect(engine.isValidVertexBuffer(quad.vb.nativePointer), isTrue);
      expect(engine.isValidIndexBuffer(quad.ib.nativePointer), isTrue);
      addQuadRenderable(rig, quad, mi);

      final px = rig.screenshot('Engine Smoke Tests Engine: config, capabilities, validity queries and a rendered frame');
      expect(countForegroundPixels(px, rig.width), greaterThan(rig.width * rig.height ~/ 6));
      engine.flushAndWait();
      expect(engine.isDisposed, isFalse);

      final materialPtr = material.nativePointer;
      rig.releaseEntities(); // Renderables before their material instance
      mi.dispose();
      material.dispose();
      expect(engine.isValidMaterial(materialPtr), isFalse);
      quad.dispose();
      rig.dispose();
      expect(engine.isDisposed, isTrue);
    }, timeout: const Timeout(Duration(minutes: 3)));

    // The linked Filament's version is readable, and a material
    // compiled for exactly its material version is accepted by the engine
    // that renders a real barrel. The version goes into the scenario name,
    // which is the report caption.
    test('filament version (${FilamentInfo.version}, material ${FilamentInfo.materialVersion})', () {
      SmokeArtifacts.resetRecordedAssets();
      final name = 'filament version (${FilamentInfo.version}, material ${FilamentInfo.materialVersion})';
      expect(FilamentInfo.version, isNotEmpty);
      final rig = SmokeRig.create(width: 480, height: 320)..addSun();
      rig.addIbl();
      final barrel = loadGltfIntoScene(rig, 'Props/Barrels/fuel_barrel_red.glb');

      FilamentMaterialBuilder.initEngine();
      final builder = FilamentMaterialBuilder.create()
        ..setName('VersionProbe')
        ..setShading(FilamatShading.unlit)
        ..requireAttribute(VertexAttribute.position.value)
        ..addParameter('baseColor', UniformType.float3)
        ..setCode('void material(inout MaterialInputs material) { prepareMaterial(material); '
            'material.baseColor.rgb = materialParams.baseColor; }');
      final package = builder.build()!;
      builder.dispose();
      expect(filamentMaterialPackageVersion(package), FilamentInfo.materialVersion,
          reason: 'filamat builds for the material version the linked engine reports');
      // fromBuffer throws a StateError when the engine rejects the package.
      late final FilamentMaterial material;
      expect(() => material = FilamentMaterial.fromBuffer(engine: rig.engine, filamatBuffer: package), returnsNormally,
          reason: 'the engine accepts a package of FilamentInfo.materialVersion');

      // Three frames of the barrel.
      final pixels = rig.renderFrame(warmup: 2);
      expect(countForegroundPixels(pixels, rig.width), greaterThan(rig.width * rig.height ~/ 50), reason: 'the barrel is drawn');
      SmokeArtifacts.saveScreenshot(name, SmokeArtifacts.encodePng(rig.width, rig.height, pixels));
      material.dispose();
      barrel.dispose(rig.scene);
      rig.dispose();
    }, timeout: const Timeout(Duration(minutes: 3)));

    // The same frame rendered on each discrete GPU, chosen by name.
    test('engine: renders on the chosen GPU', () {
      final discrete = FilamentGpu.listVulkanDevices().where((d) => d.type == FilamentGpuType.discrete).toList();
      if (discrete.isEmpty) {
        markTestSkipped('no discrete Vulkan GPU on this host');
        return;
      }
      final frames = <Uint8List>[];
      for (final gpu in discrete) {
        SmokeArtifacts.resetRecordedAssets();
        final engine = FilamentEngine.create(backend: FilamentBackend.vulkan, gpu: FilamentGpuPreference(deviceName: gpu.name))!;
        expect(engine.gpuName, gpu.name);
        final rig = SmokeRig.adopt(engine, width: 256, height: 256);
        rig.camera.setProjectionOrtho(left: -1, right: 1, bottom: -1, top: 1, near: 0.1, far: 10);
        rig.camera.lookAt(eyeX: 0, eyeY: 0, eyeZ: 2, centerX: 0, centerY: 0, centerZ: 0);
        final material = buildUnlitMaterial(engine);
        final mi = material.createInstance()..setFloat3('baseColor', 0.2, 0.6, 1.0);
        final quad = SmokeQuad.create(engine, size: 1.0);
        addQuadRenderable(rig, quad, mi);
        final px = rig.screenshot('engine: renders on the chosen GPU (${gpu.name})');
        expect(countForegroundPixels(px, rig.width), greaterThan(rig.width * rig.height ~/ 6));
        frames.add(px);
        rig.releaseEntities(); // Renderables before their material instance
        mi.dispose();
        material.dispose();
        quad.dispose();
        rig.dispose();
      }
      for (var i = 1; i < frames.length; i++) {
        final changed = countChangedPixels(frames.first, frames[i]);
        expect(changed, lessThan(frames.first.length ~/ 4 ~/ 100), reason: '${discrete[i].name} differs by $changed pixels');
      }
    }, timeout: const Timeout(Duration(minutes: 3)));

    // Two viewports (each its own swap chain, renderer, view,
    // scene and camera) on one hosted engine draw one real textured asset,
    // uploaded once: the second viewport gets an instance, not a copy.
    test('engine: two viewports share one engine and one upload', () {
      SmokeArtifacts.resetRecordedAssets();
      const name = 'engine: two viewports share one engine and one upload';
      const assetPath = 'fixtures/YVO3D_44368.glb';
      final vulkan = FilamentGpu.listVulkanDevices().isNotEmpty;
      final backend = vulkan ? FilamentBackend.vulkan : smokeBackend;
      final leaseA = FilamentEngineHost.acquire(owner: 'viewport A', backend: backend)!;
      final leaseB = FilamentEngineHost.acquire(owner: 'viewport B', backend: backend)!;
      final engine = leaseA.engine;
      expect(identical(engine, leaseB.engine), isTrue);
      expect(FilamentEngineHost.leaseCount(engine), 2);
      final baseline = engine.resourceCounts;
      // ignore: avoid_print
      print('shared engine smoke on ${engine.gpuName.isEmpty ? engine.backend : engine.gpuName}');

      const w = smokeVideoWidth ~/ 2;
      const h = smokeVideoHeight;
      final a = SmokeRig.adopt(engine, width: w, height: h)..addSun();
      final ibl = a.addIbl();
      // Viewport A draws once with an empty scene so its render targets
      // exist before the asset is measured.
      a.renderFrame(warmup: 2);
      final beforeUpload = engine.gpuMemory;

      final provider = FilamentMaterialProvider.createUbershader(engine: engine);
      final loader = FilamentAssetLoader.create(engine: engine, materialProvider: provider);
      final (asset, instances) = loader.createInstancedAsset(loadTestAsset(assetPath), 1);
      expect(asset, isNotNull);
      final resources = FilamentResourceLoader.create(engine: engine)..registerDefaultProviders(engine);
      expect(resources.loadResources(asset!), isTrue);
      final instanceA = instances.single;
      a.scene.addEntities(instanceA.entities);
      final box = asset.getBoundingBox();
      a.renderFrame(warmup: 2);
      final afterUpload = engine.gpuMemory;
      final withA = engine.resourceCounts;
      expect((withA - baseline).textures, greaterThanOrEqualTo(3), reason: 'the asset has three PNG textures');

      // Viewport B: its own rig on the same engine, empty frame first, then
      // an instance of the already uploaded asset.
      final b = SmokeRig.adopt(engine, width: w, height: h)..addSun();
      b.scene.setIndirectLight(ibl);
      b.renderFrame(warmup: 2);
      final beforeInstance = engine.gpuMemory;
      final instanceB = loader.createInstance(asset)!;
      b.scene.addEntities(instanceB.entities);
      b.renderFrame(warmup: 2);
      final afterInstance = engine.gpuMemory;
      final withB = engine.resourceCounts;
      expect(withB.textures, withA.textures, reason: 'the second viewport uploads no texture');
      expect((withB - withA).views, 1);
      expect((withB - withA).scenes, 1);
      expect((withB - withA).swapChains, 1);
      const mib = 1024 * 1024;
      if (beforeUpload != null && afterUpload != null && beforeInstance != null && afterInstance != null) {
        final upload = afterUpload.usageBytes - beforeUpload.usageBytes;
        final instance = afterInstance.usageBytes - beforeInstance.usageBytes;
        // ignore: avoid_print
        print('shared engine VRAM: asset upload ${(upload / mib).toStringAsFixed(1)} MiB, '
            'second viewport instance ${(instance / mib).toStringAsFixed(1)} MiB, '
            'second viewport render targets ${((beforeInstance.usageBytes - afterUpload.usageBytes) / mib).toStringAsFixed(1)} MiB');
        expect(upload, greaterThan(24 * mib), reason: 'the first viewport pays for the textures');
        expect(instance, lessThan(4 * mib), reason: 'an instance on the shared engine adds no texture memory');
      }

      // Both views side by side; each camera orbits its own side of the asset.
      final center = box.center;
      final extent = box.max - box.min;
      final radius = [extent.x, extent.y, extent.z].reduce(math.max) / 2;
      final dist = radius * 2.8 + 0.1;
      void orbit(SmokeRig rig, double angle) {
        rig.camera.setProjection(fovDegrees: 45, aspect: w / h, near: dist * 0.01, far: dist * 20);
        rig.camera.lookAt(
          eyeX: center.x + dist * math.sin(angle),
          eyeY: center.y + dist * 0.35,
          eyeZ: center.z + dist * math.cos(angle),
          centerX: center.x,
          centerY: center.y,
          centerZ: center.z,
        );
      }

      Uint8List sideBySide(Uint8List left, Uint8List right) {
        final out = Uint8List(w * 2 * h * 4);
        for (var y = 0; y < h; y++) {
          out.setRange(y * w * 2 * 4, y * w * 2 * 4 + w * 4, left, y * w * 4);
          out.setRange(y * w * 2 * 4 + w * 4, (y + 1) * w * 2 * 4, right, y * w * 4);
        }
        return out;
      }

      final frames = smokeVideoFrames();
      SmokeArtifacts.checkVideoDuration(name, frames, smokeVideoFps);
      final pngs = <Uint8List>[];
      Uint8List? middle;
      for (var f = 0; f < frames; f++) {
        final t = f / (frames - 1);
        orbit(a, 2 * math.pi * t);
        orbit(b, 2 * math.pi * t + math.pi);
        final left = a.renderFrame(warmup: 0);
        final right = b.renderFrame(warmup: 0);
        if (f == frames ~/ 2) {
          expect(countForegroundPixels(left, w), greaterThan(w * h ~/ 50), reason: 'viewport A draws the asset');
          expect(countForegroundPixels(right, w), greaterThan(w * h ~/ 50), reason: 'viewport B draws the asset');
        }
        final png = SmokeArtifacts.encodePng(w * 2, h, sideBySide(left, right));
        if (f == frames ~/ 2) middle = png;
        pngs.add(png);
      }
      SmokeArtifacts.saveVideoFromPngFrames(name, pngs, fps: smokeVideoFps);
      SmokeArtifacts.saveScreenshot(name, middle!);

      // Teardown: B's viewport, then A's, then the shared asset; the engine
      // lives until the last lease.
      b.scene.removeEntities(instanceB.entities);
      b.scene.setIndirectLight(null);
      b.disposeViewport();
      leaseB.release();
      expect(engine.isDisposed, isFalse);
      a.scene.removeEntities(instanceA.entities);
      a.scene.setIndirectLight(null);
      loader.destroyAsset(asset);
      resources.dispose();
      loader.dispose();
      provider.dispose();
      ibl.dispose();
      a.disposeViewport();
      final left = engine.resourceCounts - baseline;
      expect(left.textures, 0, reason: 'nothing of the asset is left: $left');
      expect(left.views, 0);
      expect(left.scenes, 0);
      expect(left.swapChains, 0);
      expect(left.renderables, 0);
      expect(left.lights, 0);
      leaseA.release();
      expect(engine.isDisposed, isTrue);
      expect(FilamentEngineHost.liveEngineCount, 0);
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}
