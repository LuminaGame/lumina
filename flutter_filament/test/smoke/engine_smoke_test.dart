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

    // Streaming through the asynchronous resource path: sixty textured quads
    // arrive in bursts while the rig keeps rendering. Every quad's vertex
    // buffer, index buffer and texture are created and filled with the async
    // API and its renderable is added only when its upload group completed,
    // so a half-uploaded object is never drawn. Measured: how many frames each
    // object took to become visible, and that the renderer skipped none.
    test('engine: asynchronous uploads keep the frame', () async {
      SmokeArtifacts.resetRecordedAssets();
      const name = 'engine: asynchronous uploads keep the frame';
      final vulkan = FilamentGpu.listVulkanDevices().isNotEmpty;
      final rig = SmokeRig.create(width: smokeVideoWidth, height: smokeVideoHeight, backend: vulkan ? FilamentBackend.vulkan : null);
      final engine = rig.engine;
      smokeLog('asynchronous mode on ${engine.gpuName.isEmpty ? engine.backend : engine.gpuName}: ${engine.isAsynchronousModeEnabled}');
      rig.camera.setProjection(fovDegrees: 50, aspect: smokeVideoWidth / smokeVideoHeight, near: 0.1, far: 100);
      rig.camera.lookAt(eyeX: 0, eyeY: 0, eyeZ: 14, centerX: 0, centerY: 0, centerZ: 0);
      final material = buildUnlitMaterial(engine, textured: true);

      const total = 60;
      const perBurst = 10;
      const burstEvery = 24; // frames
      const columns = 10;
      final frames = smokeVideoFrames();
      SmokeArtifacts.checkVideoDuration(name, frames, smokeVideoFps);

      final pending = <int, _StreamedQuad>{};
      final visibleAtFrame = <int, int>{};
      final startedAtFrame = <int, int>{};
      final objects = <_StreamedQuad>[];
      final instances = <FilamentMaterialInstance>[];
      var started = 0;

      void startBurst(int frame) {
        for (var i = 0; i < perBurst && started < total; i++, started++) {
          final id = started;
          final quad = _StreamedQuad.start(engine, id);
          pending[id] = quad;
          startedAtFrame[id] = frame;
          objects.add(quad);
        }
      }

      // The async completions arrive while frames render; the continuation
      // runs on the Dart event loop, so the loop below yields between frames.
      final pngs = <Uint8List>[];
      Uint8List? middle;
      final frameMs = <int>[];
      final tm = FilamentTransformManager(engine);
      Future<void> run() async {
        for (var f = 0; f < frames; f++) {
          if (f % burstEvery == 0 && started < total) startBurst(f);
          await Future<void>.delayed(Duration.zero);
          // Objects whose group completed this frame become renderables.
          for (final id in pending.keys.toList()) {
            final q = pending[id]!;
            if (!q.allDone) continue;
            pending.remove(id);
            if (!q.allCompleted) continue;
            final mi = material.createInstance()
              ..setFloat3('baseColor', 1, 1, 1)
              ..setTexture('tex', q.texture, sampler: const TextureSampler(filterMin: SamplerMinFilter.linear, filterMag: SamplerMagFilter.linear));
            instances.add(mi);
            final col = id % columns, row = id ~/ columns;
            final e = engine.createEntity();
            RenderableBuilder(1)
              ..boundingBox(-1, -1, -1, 1, 1, 1)
              ..culling(false)
              ..material(0, mi)
              ..geometry(0, PrimitiveType.triangles, q.vb, ib: q.ib)
              ..build(engine, e);
            tm.create(e);
            tm.setTransform(e, [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, (col - columns / 2 + 0.5) * 1.3, (2.5 - row) * 1.3, 0, 1]);
            rig.scene.addEntity(e);
            rig.entities.add(e);
            visibleAtFrame[id] = f;
          }
          final clock = Stopwatch()..start();
          final px = rig.renderFrame(warmup: 0);
          frameMs.add(clock.elapsedMilliseconds);
          final png = SmokeArtifacts.encodePng(smokeVideoWidth, smokeVideoHeight, px);
          if (f == frames - 1) {
            middle = png;
            expect(countForegroundPixels(px, smokeVideoWidth), greaterThan(smokeVideoWidth * smokeVideoHeight ~/ 20),
                reason: 'the streamed quads are on screen');
          }
          pngs.add(png);
        }
      }

      await run();

      final latencies = [for (final id in visibleAtFrame.keys) visibleAtFrame[id]! - startedAtFrame[id]!]..sort();
      final median = latencies.isEmpty ? -1 : latencies[latencies.length ~/ 2];
      final p90 = latencies.isEmpty ? -1 : latencies[(latencies.length * 9) ~/ 10];
      smokeLog('async streaming: ${visibleAtFrame.length}/$total visible, time-to-visible median $median frames, '
          'p90 $p90, max ${latencies.isEmpty ? -1 : latencies.last}; frame ms median ${(frameMs..sort())[frameMs.length ~/ 2]}, max ${frameMs.last}');
      expect(visibleAtFrame.length, total, reason: 'every object became visible');
      expect(median, lessThanOrEqualTo(engine.isAsynchronousModeEnabled ? 12 : 3),
          reason: 'amortized: a few jobs per frame, ten objects per burst');
      expect(frameMs.last, lessThan(250), reason: 'no frame stalled on an upload');

      SmokeArtifacts.saveVideoFromPngFrames(name, pngs, fps: smokeVideoFps);
      SmokeArtifacts.saveScreenshot(name, middle!);

      rig.releaseEntities();
      for (final mi in instances) {
        mi.dispose();
      }
      material.dispose();
      for (final q in objects) {
        q.dispose();
      }
      rig.dispose();
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}


/// One streamed object: its three resources created and filled through the
/// asynchronous API, each with its own upload; `allDone` once every upload
/// reported, `allCompleted` when none was cancelled.
class _StreamedQuad {
  _StreamedQuad._(this.vb, this.ib, this.texture, this.uploads);

  final FilamentVertexBuffer vb;
  final FilamentIndexBuffer ib;
  final FilamentTexture texture;
  final List<FilamentAsyncUpload> uploads;
  final List<FilamentAsyncStatus?> _results = [];

  static _StreamedQuad start(FilamentEngine engine, int id) {
    // The three resources are allocated synchronously (cheap) and every fill
    // goes through the asynchronous path, each with its own upload.
    final vb = FilamentVertexBuffer.create(
      engine: engine,
      vertexCount: 4,
      bufferCount: 2,
      attributes: const [
        VertexAttributeDesc(attribute: VertexAttribute.position, bufferIndex: 0, type: AttributeType.float3, byteOffset: 0, byteStride: 12),
        VertexAttributeDesc(attribute: VertexAttribute.uv0, bufferIndex: 1, type: AttributeType.float2, byteOffset: 0, byteStride: 8),
      ],
    );
    final ib = FilamentIndexBuffer.create(engine: engine, indexCount: 6, type: IndexType.ushort);
    final texture = FilamentTexture.create2D(engine: engine, width: 64, height: 64, format: TextureFormat.rgba8, levels: 1);
    final uploads = <FilamentAsyncUpload>[];
    const s = 0.55;
    uploads.add(vb.setBufferAtAsync(engine, 0, NativeBuffer.fromTypedData(Float32List.fromList([-s, -s, 0, s, -s, 0, s, s, 0, -s, s, 0])), autoFree: true));
    uploads.add(vb.setBufferAtAsync(engine, 1, NativeBuffer.fromTypedData(Float32List.fromList([0, 1, 1, 1, 1, 0, 0, 0])), autoFree: true));
    uploads.add(ib.setBufferAsync(engine, NativeBuffer.fromTypedData(Uint16List.fromList([0, 1, 2, 0, 2, 3])), autoFree: true));
    // A distinct solid colour per object, so the frame proves which arrived.
    final pixels = Uint8List(64 * 64 * 4);
    final hue = (id * 37) % 360;
    final (r, g, b) = _hsv(hue.toDouble());
    for (var i = 0; i < pixels.length; i += 4) {
      pixels[i] = r;
      pixels[i + 1] = g;
      pixels[i + 2] = b;
      pixels[i + 3] = 255;
    }
    uploads.add(texture.setImageAsync(pixelData: pixels, width: 64, height: 64));
    final quad = _StreamedQuad._(vb, ib, texture, uploads);
    for (final u in uploads) {
      quad._results.add(null);
      final index = quad._results.length - 1;
      u.done.then((status) => quad._results[index] = status);
    }
    return quad;
  }

  bool get allDone => _results.every((r) => r != null);
  bool get allCompleted => _results.every((r) => r == FilamentAsyncStatus.completed);

  void dispose() {
    texture.dispose();
    ib.dispose();
    vb.dispose();
  }

  static (int, int, int) _hsv(double h) {
    final x = (1 - ((h / 60) % 2 - 1).abs());
    final (double r, double g, double b) = switch ((h ~/ 60) % 6) {
      0 => (1, x, 0),
      1 => (x, 1, 0),
      2 => (0, 1, x),
      3 => (0, x, 1),
      4 => (x, 0, 1),
      _ => (1, 0, x),
    };
    return ((60 + r * 195).round(), (60 + g * 195).round(), (60 + b * 195).round());
  }
}
