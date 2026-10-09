import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_filament/testing.dart';
import 'package:test/test.dart';

import 'rtx_neural_scene.dart';
import 'smoke_helper.dart';

/// The hooks Lumina's official NVIDIA neural rendering path builds on: the
/// external post pass (the HDR frame, depth and motion with history validity
/// before colour grading), on a real animated character under a moving camera.
void main() {
  group('rtx neural Smoke Tests', () {
    SmokeRig? rig;

    tearDown(() {
      rig?.dispose();
      rig = null;
    });

    test('external post pass visualises motion and history', () async {
      if (smokeBackend != FilamentBackend.vulkan) {
        markTestSkipped(
          'the external post pass needs the Vulkan backend ($smokeBackendName)',
        );
        return;
      }
      final r = rig = SmokeRig.create(
        width: smokeVideoWidth,
        height: smokeVideoHeight,
      );
      r.addSun();
      r.addIbl();
      const name =
          'rtx neural Smoke Tests external post pass visualises motion and history';
      final gltf = loadGltfIntoScene(r, 'mannequin/MF_Unarmed_Walk_Fwd.glb');
      DebugPostPass? pass;
      try {
        final animator = gltf.asset.animator;
        final duration = animator.getAnimationDuration(0);
        final box = gltf.asset.getBoundingBox();
        final center = box.center;
        final extent = box.max - box.min;
        final radius = math.max(extent.x, math.max(extent.y, extent.z)) / 2;
        final dist = radius * 2.4 + 0.1;
        r.camera.setProjection(
          fovDegrees: 45,
          aspect: r.width / r.height,
          near: dist * 0.01,
          far: dist * 20,
        );
        r.view.temporalAntiAliasingOptions = const TemporalAntiAliasingOptions(
          enabled: true,
          motionVectors: true,
        );
        pass = DebugPostPass.create(
          engine: r.engine,
          view: r.view,
          mode: DebugPostPassMode.motion,
        );

        // Three segments: motion, history (with a camera cut in its middle), passthrough.
        final frames = smokeVideoFrames();
        final third = frames ~/ 3;
        var cut = 0.0;
        final shots = <DebugPostPassMode, Uint8List>{};
        DebugPostPassMode modeAt(int frame) => frame < third
            ? DebugPostPassMode.motion
            : frame < 2 * third
            ? DebugPostPassMode.history
            : DebugPostPassMode.passthrough;

        final last = r.video(
          name,
          onFrame: (frame, t) {
            final mode = modeAt(frame);
            if (pass!.mode != mode) pass.mode = mode;
            if (frame == third + third ~/ 2) {
              // a camera cut: the next frame has no usable history
              cut = 1.4;
              r.view.resetExternalPostPassHistory();
            }
            final angle = 0.6 + t * math.pi * 0.6 + cut;
            r.camera.lookAt(
              eyeX: center.x + dist * math.sin(angle),
              eyeY: center.y + dist * 0.35,
              eyeZ: center.z + dist * math.cos(angle),
              centerX: center.x,
              centerY: center.y,
              centerZ: center.z,
            );
            animator.applyAnimation(0, (frame / smokeVideoFps) % duration);
            animator.updateBoneMatrices();
          },
          alsoScreenshot: false,
        );
        shots[DebugPostPassMode.passthrough] = last;

        // One still per mode after the clip, the camera still orbiting and the character
        // walking (motion), then a camera cut (history).
        var step = 0;
        void advance() {
          step++;
          final angle = 0.6 + math.pi * 0.6 + cut + step * 0.02;
          r.camera.lookAt(
            eyeX: center.x + dist * math.sin(angle),
            eyeY: center.y + dist * 0.35,
            eyeZ: center.z + dist * math.cos(angle),
            centerX: center.x,
            centerY: center.y,
            centerZ: center.z,
          );
          animator.applyAnimation(
            0,
            ((frames + step) / smokeVideoFps) % duration,
          );
          animator.updateBoneMatrices();
        }

        pass.mode = DebugPostPassMode.motion;
        advance();
        r.renderFrame(warmup: 0);
        advance();
        shots[DebugPostPassMode.motion] = r.renderFrame(warmup: 0);
        pass.mode = DebugPostPassMode.history;
        cut += 0.5;
        advance();
        shots[DebugPostPassMode.history] = r.renderFrame(warmup: 0);
        for (final entry in shots.entries) {
          SmokeArtifacts.saveScreenshot(
            '$name (${entry.key.name})',
            SmokeArtifacts.encodePng(r.width, r.height, entry.value),
          );
        }
        expect(
          pass.frameCount,
          greaterThanOrEqualTo(frames),
          reason: 'the pass ran on every frame',
        );
        expect(pass.lastSize, (r.width, r.height));
        expect(
          frameStats(last).distinct,
          greaterThan(200),
          reason: 'the character must be visible through the pass',
        );
      } finally {
        pass?.destroy();
        gltf.dispose(r.scene);
      }
    }, timeout: const Timeout(Duration(minutes: 10)));

    test('guide buffers of a ray-traced scene', () async {
      if (smokeBackend != FilamentBackend.vulkan) {
        markTestSkipped(
          'the guide buffers need the Vulkan backend ($smokeBackendName)',
        );
        return;
      }
      RayTracing.requestExtensions();
      final engine = FilamentEngine.create(backend: FilamentBackend.vulkan)!;
      final r = rig = SmokeRig.adopt(
        engine,
        width: smokeVideoWidth,
        height: smokeVideoHeight,
      );
      r.addSun();
      r.addIbl();
      const name = 'rtx neural Smoke Tests guide buffers of a ray-traced scene';
      final scene = GuideScene.build(r);
      final readbacks = <GuideBuffer, GuideBufferReadback>{};
      try {
        r.scene.rayTracingEnabled = engine.supportsRayQuery;
        r.view.guideBufferOptions = const GuideBufferOptions(enabled: true);
        for (final g in GuideBuffer.values) {
          readbacks[g] = GuideBufferReadback.attach(
            engine: engine,
            view: r.view,
            which: g,
            width: r.width,
            height: r.height,
          );
        }

        final frames = smokeVideoFrames();
        SmokeArtifacts.checkVideoDuration(name, frames, smokeVideoFps);
        SmokeArtifacts.checkVideoSize(name, r.width, r.height);
        final pngs = <Uint8List>[];
        for (var f = 0; f < frames; f++) {
          scene.orbit(f / (frames - 1));
          final mode = (f * GuideView.values.length) ~/ frames;
          final colour = r.renderFrame(warmup: f == 0 ? 3 : 0);
          final image = await GuideView.values[mode].render(
            r,
            readbacks,
            colour,
          );
          pngs.add(SmokeArtifacts.encodePng(r.width, r.height, image));
        }
        SmokeArtifacts.saveVideoFromPngFrames(name, pngs, fps: smokeVideoFps);

        // the six views of the final pose, 3 x 2 at half size
        final colour = r.renderFrame(warmup: 1);
        final w = r.width ~/ 2;
        final h = r.height ~/ 2;
        final grid = Uint8List(w * 3 * h * 2 * 4);
        for (final view in GuideView.values) {
          final image = await view.render(r, readbacks, colour);
          final ox = (view.index % 3) * w;
          final oy = (view.index ~/ 3) * h;
          for (var y = 0; y < h; y++) {
            for (var x = 0; x < w; x++) {
              final s = ((y * 2) * r.width + x * 2) * 4;
              final d = ((oy + y) * w * 3 + ox + x) * 4;
              grid.setRange(d, d + 4, image, s);
            }
          }
        }
        SmokeArtifacts.saveScreenshot(
          '$name (colour, normal, roughness / diffuse, specular, hit distance)',
          SmokeArtifacts.encodePng(w * 3, h * 2, grid),
        );

        final normalRb = readbacks[GuideBuffer.normalRoughness]!;
        final normals = await normalRb.read(r.renderer);
        final floorNormal = normalRb.at(normals, r.width ~/ 2, r.height - 8);
        expect(
          floorNormal[1],
          greaterThan(0.95),
          reason: 'the floor normal points up',
        );
        if (engine.supportsRayQuery) {
          final hits = await readbacks[GuideBuffer.specularHitDistance]!.read(
            r.renderer,
          );
          var surfaces = 0;
          for (final d in hits) {
            if (d > 0 && d < 65000) surfaces++;
          }
          expect(
            surfaces,
            greaterThan(1000),
            reason: 'mirror rays from the floor hit the props',
          );
        }
      } finally {
        for (final rb in readbacks.values) {
          rb.dispose();
        }
        scene.dispose();
        RayTracing.clearExtensionRequest();
      }
    }, timeout: const Timeout(Duration(minutes: 15)));

    test('DLSS Ray Reconstruction denoises ReSTIR lighting', () async {
      if (smokeBackend != FilamentBackend.vulkan) {
        markTestSkipped(
          'Ray Reconstruction needs the Vulkan backend ($smokeBackendName)',
        );
        return;
      }
      if (!DlssRayReconstruction.available) {
        markTestSkipped(
          'nvngx_dlssd not available (tool/dlss/fetch_sdk.dart on an RTX machine)',
        );
        return;
      }
      Dlss.requestExtensions();
      RayTracing.requestExtensions();
      final engine = FilamentEngine.create(backend: FilamentBackend.vulkan)!;
      final r = rig = SmokeRig.adopt(
        engine,
        width: smokeVideoWidth,
        height: smokeVideoHeight,
      );
      const name =
          'rtx neural Smoke Tests DLSS Ray Reconstruction denoises ReSTIR lighting';
      final scene = GuideScene.build(r);
      DlssRayReconstruction? rr;
      try {
        if (!engine.supportsRayQuery ||
            !DlssRayReconstruction.supported(engine)) {
          markTestSkipped(
            'no ray query or Ray Reconstruction on this GPU: ${DlssRayReconstruction.lastErrorMessage}',
          );
          return;
        }
        // 48 coloured point lights circling above the props, shaded by raw one-ray ReSTIR
        final lights = <int>[];
        final rnd = math.Random(5);
        final phases = <double>[];
        for (var i = 0; i < 48; i++) {
          final e = engine.createEntity();
          LightBuilder(LightType.point)
            ..color(
              0.3 + 0.7 * rnd.nextDouble(),
              0.3 + 0.7 * rnd.nextDouble(),
              0.3 + 0.7 * rnd.nextDouble(),
            )
            ..intensity(80000)
            ..position(0, 1, 0)
            ..falloff(3.5)
            ..build(engine, e);
          r.scene.addEntity(e);
          r.entities.add(e);
          lights.add(e);
          phases.add(rnd.nextDouble() * math.pi * 2);
        }
        final lm = FilamentLightManager(engine);
        void moveLights(double t) {
          for (var i = 0; i < lights.length; i++) {
            final a = phases[i] + t * math.pi * 2 * (i.isEven ? 1 : -1) * 0.5;
            final radius = 1.0 + (i % 4) * 0.8;
            lm.setPosition(
              lights[i],
              radius * math.cos(a),
              0.35 + (i % 3) * 0.5,
              radius * math.sin(a),
            );
          }
        }

        r.camera.setExposure(
          aperture: 16,
          shutterSpeed: 1 / 125,
          sensitivity: 100,
        );
        r.scene.rayTracingEnabled = true;
        r.view.restirOptions = const RestirOptions(
          enabled: true,
          initialCandidates: 2,
          spatialSamples: 0,
          temporal: false,
        );
        r.view.temporalAntiAliasingOptions = const TemporalAntiAliasingOptions(
          enabled: true,
          motionVectors: true,
        );

        // the still comparison: Filament's TAA on the left, Ray Reconstruction on the right
        scene.orbit(0.5);
        moveLights(0.25);
        final taa = r.renderFrame(warmup: 30);
        rr = DlssRayReconstruction.create(
          engine: engine,
          view: r.view,
          options: DlssRayReconstructionOptions(
            quality: DlssQuality.maxQuality,
            outputWidth: r.width,
            outputHeight: r.height,
          ),
        );
        final denoised = r.renderFrame(warmup: 30);
        final side = Uint8List(r.width * 2 * r.height * 4);
        for (var y = 0; y < r.height; y++) {
          final row = y * r.width * 4;
          side.setRange(
            y * r.width * 8,
            y * r.width * 8 + r.width * 4,
            taa,
            row,
          );
          side.setRange(
            y * r.width * 8 + r.width * 4,
            (y + 1) * r.width * 8,
            denoised,
            row,
          );
        }
        SmokeArtifacts.saveScreenshot(
          '$name (TAA left, Ray Reconstruction right)',
          SmokeArtifacts.encodePng(r.width * 2, r.height, side),
        );

        rr.resetHistory();
        final last = r.video(
          name,
          onFrame: (frame, t) {
            scene.orbit(t);
            moveLights(t);
          },
          alsoScreenshot: true,
        );
        expect(
          rr.lastError,
          isNull,
          reason: 'NGX reported no error during the clip',
        );
        expect(frameStats(last).distinct, greaterThan(200));
        final gpu = rr.lastGpuTimeNanos;
        final (rw, rh) = rr.renderResolution;
        smokeLog(
          'Ray Reconstruction ${rw}x$rh -> ${r.width}x${r.height}: ${(gpu / 1e6).toStringAsFixed(3)} ms GPU',
        );
      } finally {
        rr?.destroy();
        scene.dispose();
        Dlss.clearExtensionRequest();
        RayTracing.clearExtensionRequest();
      }
    }, timeout: const Timeout(Duration(minutes: 15)));

    test('DLSS frame generation presents generated frames of an animated character', () async {
      if (smokeBackend != FilamentBackend.vulkan) {
        markTestSkipped(
          'frame generation needs the Vulkan backend ($smokeBackendName)',
        );
        return;
      }
      if (!DlssFrameGeneration.available) {
        markTestSkipped(
          'nvngx_dlssg not available (tool/dlss/fetch_sdk.dart on an RTX machine)',
        );
        return;
      }
      Dlss.requestExtensions();
      DlssFrameGeneration.requestExtensions();
      final engine = FilamentEngine.create(backend: FilamentBackend.vulkan)!;
      final r = rig = SmokeRig.adopt(
        engine,
        width: smokeVideoWidth,
        height: smokeVideoHeight,
      );
      r.addSun();
      r.addIbl();
      const name =
          'rtx neural Smoke Tests DLSS frame generation presents generated frames of an animated character';
      final gltf = loadGltfIntoScene(r, 'mannequin/MF_Unarmed_Walk_Fwd.glb');
      DlssFrameGenerator? generator;
      try {
        final probe = DlssFrameGeneration.probe(engine);
        if (probe == null || !probe.available) {
          markTestSkipped(
            'Frame Generation not available: $probe ${DlssFrameGeneration.lastErrorMessage}',
          );
          return;
        }
        final animator = gltf.asset.animator;
        final duration = animator.getAnimationDuration(0);
        final box = gltf.asset.getBoundingBox();
        final center = box.center;
        final extent = box.max - box.min;
        final radius = math.max(extent.x, math.max(extent.y, extent.z)) / 2;
        final dist = radius * 2.4 + 0.1;
        r.camera.setProjection(
          fovDegrees: 45,
          aspect: r.width / r.height,
          near: dist * 0.01,
          far: dist * 20,
        );
        r.view.temporalAntiAliasingOptions = const TemporalAntiAliasingOptions(
          enabled: true,
          motionVectors: true,
        );
        final count = math.min(3, math.max(1, probe.multiFrameCountMax));
        generator = DlssFrameGenerator.create(
          engine: engine,
          view: r.view,
          generatedFrames: count,
        );
        smokeLog(
          'probe: $probe; generating $count frame(s) per rendered frame (${count + 1}x)',
        );

        // The view shows (and the readback reads) the first generated frame of every rendered
        // frame: the video is made of generated frames.
        final frames = smokeVideoFrames();
        final last = r.video(
          name,
          onFrame: (frame, t) {
            final angle = 0.6 + t * math.pi * 0.6;
            r.camera.lookAt(
              eyeX: center.x + dist * math.sin(angle),
              eyeY: center.y + dist * 0.35,
              eyeZ: center.z + dist * math.cos(angle),
              centerX: center.x,
              centerY: center.y,
              centerZ: center.z,
            );
            animator.applyAnimation(0, (frame / smokeVideoFps) % duration);
            animator.updateBoneMatrices();
          },
          alsoScreenshot: true,
        );
        expect(
          generator.lastResult,
          1,
          reason: DlssFrameGeneration.lastErrorMessage,
        );
        expect(generator.frameCount, greaterThanOrEqualTo(frames - 5));
        expect(frameStats(last).distinct, greaterThan(200));
        final presents = r.renderer.getPresentTimes();
        final intervals = [
          for (var i = 1; i < presents.length; i++)
            (presents[i] - presents[i - 1]) / 1e6,
        ];
        smokeLog(
          '${generator.frameCount} rendered frames with generation; last ${presents.length} presents, '
          'mean interval ${(intervals.reduce((a, b) => a + b) / intervals.length).toStringAsFixed(2)} ms; '
          'NGX GPU ${(generator.lastGpuTimeNanos / 1e6).toStringAsFixed(3)} ms per rendered frame',
        );
      } finally {
        generator?.destroy();
        gltf.dispose(r.scene);
        Dlss.clearExtensionRequest();
        DlssFrameGeneration.clearExtensionRequest();
      }
    }, timeout: const Timeout(Duration(minutes: 15)));
  });
}
