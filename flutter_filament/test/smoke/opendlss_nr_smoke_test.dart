import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_filament/testing.dart';
import 'package:test/test.dart';

import 'smoke_helper.dart';

/// OpenDLSS-NR (experimental, third-party) running as the external post pass
/// on real props under an orbiting camera. The weights are a synthetic model
/// of the network's layout (small random values written by the test): the
/// frame shows the pipeline and its cost, not a trained network's look.
void main() {
  group('opendlss nr Smoke Tests', () {
    SmokeRig? rig;
    Directory? temp;

    tearDown(() async {
      rig?.dispose();
      rig = null;
      if (temp != null && await temp!.exists()) await temp!.delete(recursive: true);
      temp = null;
    });

    test('OpenDLSS-NR pass with synthetic weights', () async {
      if (smokeBackend != FilamentBackend.vulkan) {
        markTestSkipped('OpenDLSS-NR needs the Vulkan backend ($smokeBackendName)');
        return;
      }
      OpenDlssNr.requestDeviceFeatures();
      final r = rig = SmokeRig.create(width: smokeVideoWidth, height: smokeVideoHeight);
      final capability = OpenDlssNr.capability(r.engine);
      if (!capability.supported) {
        markTestSkipped('OpenDLSS-NR not supported here: ${capability.reason}');
        return;
      }
      r.addSun();
      r.addIbl();
      const name = 'opendlss nr Smoke Tests OpenDLSS-NR pass with synthetic weights';
      final ac = loadGltfIntoScene(r, 'Props/AC_units/ac_unit_a_300x300.glb');
      final barrel = loadGltfIntoScene(r, 'Props/Barrels/fuel_barrel_red.glb', frameCamera: false);
      temp = await Directory.systemTemp.createTemp('opendlss_nr_smoke');
      // Zero weights: the network's residual and blend are 0, so the frame must come back through the whole
      // pipeline (proxy, network, composite, tone upgrade) nearly unchanged. Random weights: the cost of a
      // real model, and an output that visibly differs.
      final zeroDir = '${temp!.path}/zero';
      final randomDir = '${temp!.path}/random';
      OpenDlssNr.writeSyntheticModel(zeroDir);
      OpenDlssNr.writeSyntheticModel(randomDir, seed: 11, random: true);
      for (final dir in [zeroDir, randomDir]) {
        final check = OpenDlssNr.validateModel(dir);
        expect(check.ok, isTrue, reason: check.message);
      }
      final zero = OpenDlssNr.loadModel(r.engine, zeroDir);
      final random = OpenDlssNr.loadModel(r.engine, randomDir);
      OpenDlssNrPass? pass;
      try {
        final box = ac.asset.getBoundingBox();
        final center = box.center;
        final extent = box.max - box.min;
        final radius = math.max(extent.x, math.max(extent.y, extent.z)) / 2;
        // the barrel beside the unit, scaled to its height
        final barrelBox = barrel.asset.getBoundingBox();
        final scale = (box.max.y - box.min.y) / (barrelBox.max.y - barrelBox.min.y);
        FilamentTransformManager(r.engine).setTransform(barrel.asset.rootEntity, [
          scale, 0, 0, 0, //
          0, scale, 0, 0,
          0, 0, scale, 0,
          center.x + radius * 1.6 - barrelBox.center.x * scale, box.min.y - barrelBox.min.y * scale,
          center.z - barrelBox.center.z * scale, 1,
        ]);
        final dist = radius * 5.0 + 0.1;
        r.camera.setProjection(fovDegrees: 45, aspect: r.width / r.height, near: dist * 0.01, far: dist * 20);
        r.view.temporalAntiAliasingOptions = const TemporalAntiAliasingOptions(enabled: true, motionVectors: true);
        void place(double t) {
          final angle = 0.4 + t * math.pi * 0.5;
          r.camera.lookAt(
            eyeX: center.x + dist * math.sin(angle),
            eyeY: center.y + dist * 0.35,
            eyeZ: center.z + dist * math.cos(angle),
            centerX: center.x + radius * 0.8,
            centerY: center.y,
            centerZ: center.z,
          );
        }

        pass = OpenDlssNrPass.create(engine: r.engine, view: r.view, model: zero, controls: const OpenDlssNrControls(enabled: false));
        // Stills first, from one camera: bypassed and zero weights must match.
        place(0);
        final stills = <String, Uint8List>{};
        stills['bypassed'] = r.renderFrame(warmup: 4);
        pass.controls = const OpenDlssNrControls();
        stills['zero weights'] = r.renderFrame(warmup: 8);
        var sum = 0;
        final a = stills['bypassed']!, b = stills['zero weights']!;
        for (var i = 0; i < a.length; i++) {
          sum += (a[i] - b[i]).abs();
        }
        final meanDifference = sum / a.length;
        expect(meanDifference, lessThan(4.0), reason: 'zero weights reproduce the frame (mean |difference| $meanDifference)');

        // The clip, in thirds: bypassed, zero weights, random weights at a third of the intensity.
        final frames = smokeVideoFrames();
        final third = frames ~/ 3;
        var usedFrames = 0;
        r.video(
          name,
          onFrame: (frame, t) {
            if (frame == 2 * third) {
              usedFrames += pass!.status.frames;
              pass!.destroy();
              pass = OpenDlssNrPass.create(engine: r.engine, view: r.view, model: random, controls: const OpenDlssNrControls(intensity: 0.35));
            } else if (frame < 2 * third) {
              final controls = frame < third ? const OpenDlssNrControls(enabled: false) : const OpenDlssNrControls();
              if (pass!.controls != controls) pass!.controls = controls;
            }
            place(t);
          },
          alsoScreenshot: false,
        );
        stills['random weights'] = r.renderFrame(warmup: 2);
        for (final entry in stills.entries) {
          SmokeArtifacts.saveScreenshot('$name (${entry.key})', SmokeArtifacts.encodePng(r.width, r.height, entry.value));
        }
        final status = pass!.status;
        // ignore: avoid_print
        print('OpenDLSS-NR ${status.width}x${status.height}: ${status.gpuMsAverage.toStringAsFixed(2)} ms average, '
            'zero weights mean |difference| ${meanDifference.toStringAsFixed(2)}');
        expect(status.failed, isFalse, reason: status.failure);
        expect(usedFrames + status.frames, greaterThanOrEqualTo(frames));
      } finally {
        pass?.destroy();
        zero.destroy();
        random.destroy();
        barrel.dispose(r.scene);
        ac.dispose(r.scene);
      }
    }, timeout: const Timeout(Duration(minutes: 10)));
  });
}
