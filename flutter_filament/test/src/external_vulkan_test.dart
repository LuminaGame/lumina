import 'dart:io' show Platform, sleep;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4;

import '../smoke/smoke_helper.dart';

/// An engine on a Vulkan device someone else created, rendering into images
/// someone else owns: the path an OpenXR bridge drives on a headset
/// (`XR_KHR_vulkan_enable2` makes the device, the compositor owns the
/// swapchain images). [ExternalVulkanOffscreen] plays the runtime here: its
/// own instance, device and images, read back after each frame.
void main() {
  const size = 512;

  ExternalVulkanOffscreen? offscreen;
  FilamentEngine? engine;
  SmokeRig? rig;
  FilamentSwapChain? swapChain;

  bool skip() {
    if (Platform.environment['FILAMENT_TEST_BACKEND'] == 'opengl') return true;
    return offscreen == null || engine == null;
  }

  void setUpExternal({int layers = 1, bool multiview = false, EngineConfig? config}) {
    offscreen = ExternalVulkanOffscreen.create(width: size, height: size, layers: layers, multiview: multiview);
    if (offscreen == null) return;
    engine = FilamentEngine.createOnExternalVulkan(offscreen!.context, config: config);
    if (engine == null) return;
    rig = SmokeRig.adopt(engine!, width: size, height: size);
    swapChain = FilamentSwapChain.external(engine!, offscreen!.provider);
  }

  void tearDownExternal() {
    swapChain?.dispose();
    swapChain = null;
    rig?.dispose();
    rig = null;
    engine = null;
    offscreen?.dispose();
    offscreen = null;
  }

  /// Renders [frames] frames into the external swapchain and returns how
  /// many began.
  int renderFrames(int frames, {void Function(int frame)? onFrame}) {
    var rendered = 0;
    final clock = Stopwatch()..start();
    while (rendered < frames && clock.elapsed < const Duration(seconds: 20)) {
      if (rig!.renderer.beginFrame(swapChain!)) {
        onFrame?.call(rendered);
        rig!.renderer.render(rig!.view);
        rig!.renderer.endFrame();
        rendered++;
      } else {
        sleep(const Duration(milliseconds: 4));
      }
    }
    engine!.flushAndWait();
    return rendered;
  }

  /// The image the last of [frames] frames went to.
  int lastImage(int frames) => (frames - 1) % offscreen!.imageCount;

  group('an engine on an external Vulkan device', () {
    setUp(setUpExternal);
    tearDown(tearDownExternal);

    test('adopts the given instance and device', () {
      if (skip()) return markTestSkipped('no Vulkan device');
      expect(engine!.isExternalVulkan, isTrue);
      expect(engine!.backend, FilamentBackend.vulkan);
      final given = offscreen!.context;
      final adopted = ExternalVulkanContext.of(engine!)!;
      expect(adopted.instance, given.instance);
      expect(adopted.physicalDevice, given.physicalDevice);
      expect(adopted.device, given.device);
      expect(adopted.queueFamily, given.queueFamily);
      expect(adopted.queueIndex, given.queueIndex);
      expect(engine!.gpuName, isNotEmpty);
      expect(swapChain, isNotNull);
    });

    test('Filament submits on a queue of its own when the family has two', () {
      if (skip()) return markTestSkipped('no Vulkan device');
      // Desktop GPUs (and Adreno) offer several graphics queues: index 0 is the
      // runtime's (OpenXR's graphics binding), index 1 Filament's driver thread.
      expect(offscreen!.context.queueIndex, 1);
      expect(ExternalVulkanContext.of(engine!)!.queueIndex, 1);
    });

    test('clears a provider image to the clear colour', () {
      if (skip()) return markTestSkipped('no Vulkan device');
      // Without post-processing the clear colour reaches the image as written
      // (with it, tone mapping and the sRGB transfer would apply).
      rig!.view.postProcessingEnabled = false;
      rig!.renderer.setClearOptions(r: 0.2, g: 0.4, b: 0.6, a: 1);
      const frames = 4;
      expect(renderFrames(frames), frames);
      final pixels = offscreen!.readPixels(lastImage(frames))!;
      // Linear clear colour into a UNORM image: 0.2, 0.4, 0.6 of 255.
      for (final at in [0, (size * size ~/ 2 + size ~/ 2) * 4, (size * size - 1) * 4]) {
        expect(pixels[at], closeTo(51, 1), reason: 'red at byte $at');
        expect(pixels[at + 1], closeTo(102, 1), reason: 'green at byte $at');
        expect(pixels[at + 2], closeTo(153, 1), reason: 'blue at byte $at');
      }
    });

    test('acquires and presents the images in turn', () {
      if (skip()) return markTestSkipped('no Vulkan device');
      expect(renderFrames(4), 4);
      final events = offscreen!.events;
      expect(events.take(8).map((e) => e.toString()), [
        'acquire 0', 'present 0', 'acquire 1', 'present 1', 'acquire 2', 'present 2', 'acquire 0', 'present 0',
      ]);
    });

    test('stereo options on an engine without stereo fall back to one eye, not to a black frame', () {
      if (skip()) return markTestSkipped('no Vulkan device');
      rig!.view.stereoscopicOptions = const StereoscopicOptions(enabled: true);
      expect(rig!.view.stereoscopicOptions.enabled, isTrue);
      expect(rig!.view.isStereoActive(engine!), isFalse);
      rig!.view.postProcessingEnabled = false;
      rig!.renderer.setClearOptions(r: 0.2, g: 0.4, b: 0.6, a: 1);
      expect(renderFrames(3), 3);
      final pixels = offscreen!.readPixels(lastImage(3))!;
      expect(pixels[0], closeTo(51, 1));
    });

    test('renders a lit barrel from test-assets', () {
      if (skip()) return markTestSkipped('no Vulkan device');
      rig!.addSun();
      final ibl = rig!.addIbl();
      final barrel = loadGltfIntoScene(rig!, 'Props/Barrels/fuel_barrel_red.glb');
      try {
        rig!.renderer.setClearOptions(r: 0.05, g: 0.08, b: 0.15, a: 1);
        const frames = 6;
        expect(renderFrames(frames), frames);
        final pixels = offscreen!.readPixels(lastImage(frames))!;
        final foreground = countPixelsDifferingFrom(pixels, 13, 20, 38, tolerance: 6);
        expect(foreground / (size * size), greaterThan(0.05),
            reason: 'the barrel covers $foreground of ${size * size} pixels');
      } finally {
        barrel.dispose(rig!.scene);
        rig!.scene.setIndirectLight(null);
        ibl.dispose();
      }
    });
  });

  group('multiview into a two-layer image', () {
    setUp(() => setUpExternal(
          layers: 2,
          multiview: true,
          config: EngineConfig(stereoscopicType: StereoscopicType.multiview, stereoscopicEyeCount: 2),
        ));
    tearDown(tearDownExternal);

    Uint8List layer(int frames, int index) => offscreen!.readPixels(lastImage(frames), layer: index)!;

    test('both eyes render in one pass and differ by the eye offset', () {
      if (skip()) return markTestSkipped('no Vulkan device');
      if (!engine!.isStereoSupported(StereoscopicType.multiview)) {
        return markTestSkipped('the device has no multiview');
      }
      rig!.view.stereoscopicOptions = const StereoscopicOptions(enabled: true);
      rig!.addSun();
      final barrel = loadGltfIntoScene(rig!, 'Props/Barrels/fuel_barrel_red.glb');
      var barrelGone = false;
      try {
        rig!.camera.setEyeModelMatrix(0, eyeTranslation(-0.032));
        rig!.camera.setEyeModelMatrix(1, eyeTranslation(0.032));
        const frames = 6;
        expect(renderFrames(frames), frames);
        final left = layer(frames, 0);
        final right = layer(frames, 1);
        expect(countPixelsDifferingFrom(left, 13, 20, 38, tolerance: 6), greaterThan(size * size ~/ 50));
        expect(countPixelsDifferingFrom(right, 13, 20, 38, tolerance: 6), greaterThan(size * size ~/ 50));
        expect(rig!.view.isStereoActive(engine!), isTrue);
        expect(countChangedPixels(left, right), greaterThan(100), reason: 'the eyes see the barrel from 6.4 cm apart');

        // Each layer is what a single-eye camera at that eye sees. A stereo
        // view renders without post-processing (linear output, the
        // compositor's sRGB image encodes it), so the single eye does too.
        final head = rig!.camera.modelMatrix;
        final eyes = [left, right];
        barrelGone = true;
        barrel.dispose(rig!.scene);
        tearDownExternal();
        setUpExternal();
        if (skip()) return;
        rig!.addSun();
        rig!.view.postProcessingEnabled = false;
        final single = loadGltfIntoScene(rig!, 'Props/Barrels/fuel_barrel_red.glb');
        try {
          for (var eye = 0; eye < 2; eye++) {
            rig!.camera.modelMatrix = head.multiplied(eyeTranslation(eye == 0 ? -0.032 : 0.032));
            final rendered = renderFrames(frames);
            final pixels = offscreen!.readPixels(lastImage(rendered))!;
            expect(psnr(pixels, eyes[eye]), greaterThan(40), reason: 'eye $eye against its single-eye render');
          }
        } finally {
          single.dispose(rig!.scene);
        }
        return;
      } finally {
        if (!barrelGone) barrel.dispose(rig!.scene);
      }
    });
  });
}

/// Peak signal-to-noise ratio of two RGBA8 images over their RGB channels, in dB.
double psnr(Uint8List a, Uint8List b) {
  var sum = 0.0;
  var n = 0;
  for (var i = 0; i < a.length; i += 4) {
    for (var ch = 0; ch < 3; ch++) {
      final d = a[i + ch] - b[i + ch];
      sum += d * d;
      n++;
    }
  }
  final mse = sum / n;
  return mse == 0 ? double.infinity : 10 * math.log(255 * 255 / mse) / math.ln10;
}

/// A model matrix moving an eye [x] metres along the head's X axis.
Matrix4 eyeTranslation(double x) => Matrix4.translationValues(x, 0, 0);
