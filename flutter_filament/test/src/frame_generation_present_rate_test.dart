import 'dart:ffi' as ffi;
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:ffi/ffi.dart';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:test/test.dart';

import '../smoke/smoke_helper.dart';

/// Frame generation multiplies the presented frame rate: without vsync the
/// generated frames are presented off the render thread, spaced evenly between
/// the rendered frames, so the render loop keeps its own pace.
void main() {
  group('frame generation present rate on an RTX GPU (Vulkan, no vsync)', () {
    SmokeRig? rig;
    LoadedGltf? gltf;

    setUp(() {
      if (!DlssFrameGeneration.available) return;
      Dlss.requestExtensions();
      DlssFrameGeneration.requestExtensions();
      FilamentEngine? engine;
      try {
        engine = FilamentEngine.create(backend: FilamentBackend.vulkan);
      } catch (_) {
        engine = null;
      }
      if (engine == null) return;
      rig = SmokeRig.adopt(engine, width: 1024, height: 768, swapChainFlags: SwapChainConfig.disableVsync);
      rig!.addSun();
      gltf = loadGltfIntoScene(rig!, 'Props/AC_units/ac_unit_a_300x300.glb');
      rig!.view.temporalAntiAliasingOptions = const TemporalAntiAliasingOptions(motionVectors: true);
    });

    tearDown(() {
      if (gltf != null) gltf!.dispose(rig!.scene);
      gltf = null;
      rig?.dispose();
      rig = null;
      Dlss.clearExtensionRequest();
      DlssFrameGeneration.clearExtensionRequest();
    });

    /// Renders [frames] frames the way an uncapped, CPU-bound game loop does: 8 ms of game
    /// work on the render thread per frame, no sleeps, no readbacks. Returns the presents
    /// per second, the coefficient of variation of the present intervals and the presents
    /// per rendered frame.
    (double, double, double) measure(SmokeRig r, int frames) {
      final tm = FilamentTransformManager(r.engine);
      final root = gltf!.asset.rootEntity;
      r.engine.flushAndWait();
      final before = r.renderer.getPresentTimes(1024);
      final start = before.isEmpty ? 0 : before.last;
      var rendered = 0;
      final clock = Stopwatch()..start();
      for (var i = 0; rendered < frames && i < frames * 20; i++) {
        tm.setTransform(root, [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0.002 * i, 0, 0, 1]);
        if (r.renderer.beginFrame(r.swapChain)) {
          r.renderer.render(r.view);
          r.renderer.endFrame();
          rendered++;
        }
        // the game's own work for the next frame
        final until = clock.elapsedMicroseconds + 8000;
        while (clock.elapsedMicroseconds < until) {}
      }
      r.engine.flushAndWait();
      final times = r.renderer.getPresentTimes(1024).where((t) => t > start).toList();
      final intervals = [for (var i = 1; i < times.length; i++) (times[i] - times[i - 1]) / 1e6];
      final mean = intervals.reduce((a, b) => a + b) / intervals.length;
      final sd = math.sqrt(intervals.map((x) => (x - mean) * (x - mean)).reduce((a, b) => a + b) / intervals.length);
      return (1000 / mean, sd / mean, times.length / rendered);
    }

    String fmt((double, double, double) m) =>
        '${m.$1.toStringAsFixed(1)} presents/s, cv ${m.$2.toStringAsFixed(2)}, ${m.$3.toStringAsFixed(2)} per rendered frame';

    test('DLSS frame generation multiplies the presents per second', () {
      if (!DlssFrameGeneration.available || rig == null) {
        markTestSkipped('needs nvngx_dlssg and a Vulkan device');
        return;
      }
      final r = rig!;
      final probe = DlssFrameGeneration.probe(r.engine);
      if (probe == null || !probe.available) {
        markTestSkipped('Frame Generation not available here: $probe');
        return;
      }
      measure(r, 20);
      final off = measure(r, 100);
      smokeLog('frame generation off: ${fmt(off)}');
      for (final generated in [1, 3, 5]) {
        if (generated > probe.multiFrameCountMax) continue;
        final generator = DlssFrameGenerator.create(engine: r.engine, view: r.view, generatedFrames: generated);
        try {
          measure(r, 20);
          final on = measure(r, 100);
          smokeLog('${generated + 1}x: ${fmt(on)} (${(on.$1 / off.$1).toStringAsFixed(2)}x the presents of off)');
          expect(on.$3, closeTo(generated + 1, 0.05), reason: '${generated + 1} presents per rendered frame');
          expect(on.$1, greaterThan(off.$1 * (generated + 1) * 0.7),
              reason: '${generated + 1}x presents ${generated + 1} times the frames per second of rendering alone');
          expect(on.$2, lessThan(0.35), reason: '${generated + 1}x: evenly paced presents');
        } finally {
          generator.destroy();
        }
      }
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('FSR3 frame generation doubles the presents per second', () {
      if (rig == null) {
        markTestSkipped('needs a Vulkan device');
        return;
      }
      final r = rig!;
      r.view.temporalAntiAliasingOptions =
          const TemporalAntiAliasingOptions(enabled: true, motionVectors: true, algorithm: TaaAlgorithm.fsr3);
      measure(r, 20);
      final off = measure(r, 100);
      r.view.temporalAntiAliasingOptions =
          const TemporalAntiAliasingOptions(
          enabled: true, motionVectors: true, algorithm: TaaAlgorithm.fsr3, frameGeneration: true);
      measure(r, 20);
      final on = measure(r, 100);
      smokeLog('FSR3 frame generation off: ${fmt(off)}; on: ${fmt(on)} (${(on.$1 / off.$1).toStringAsFixed(2)}x)');
      expect(on.$3, closeTo(2, 0.05));
      expect(on.$1, greaterThan(off.$1 * 2 * 0.7));
      expect(on.$2, lessThan(0.35));
    }, timeout: const Timeout(Duration(minutes: 3)));
  });

  group('frame generation present rate in a native window (Windows, Vulkan, no vsync)', () {
    // A 30 fps game (33 ms of game work per frame) presenting to a composed desktop window.
    // 2x doubles the presents; above the display's refresh the window's presentation engine
    // hands the images back at its own pace, so 4x and 6x are logged, not required to scale.
    test('DLSS frame generation presents 2x / 4x / 6x the frames to a real swap chain', () {
      if (!Platform.isWindows || !DlssFrameGeneration.available) {
        markTestSkipped('needs Windows and nvngx_dlssg');
        return;
      }
      final window = _NativeWindow.open(1024, 768, 'frame generation present rate');
      Dlss.requestExtensions();
      DlssFrameGeneration.requestExtensions();
      final engine = FilamentEngine.create(backend: FilamentBackend.vulkan)!;
      final swapChain = engine.createSwapChain(window.hwnd, flags: SwapChainConfig.disableVsync);
      final renderer = engine.createRenderer();
      final scene = engine.createScene();
      final view = engine.createView();
      final cameraEntity = engine.createEntity();
      final camera = engine.createCamera(cameraEntity);
      // the swap chain covers the client area, inside the window's frame
      final (cw, ch) = window.clientSize;
      view
        ..scene = scene
        ..camera = camera
        ..setViewport(0, 0, cw, ch);
      camera.setProjection(fovDegrees: 45, aspect: cw / ch, near: 0.1, far: 1000);
      camera.lookAt(eyeX: 0, eyeY: 1, eyeZ: 5, centerX: 0, centerY: 0, centerZ: 0);
      final sun = engine.createEntity();
      LightBuilder(LightType.directional)
        ..intensity(100000)
        ..direction(0.4, -1.0, -0.6)
        ..build(engine, sun);
      scene.addEntity(sun);
      final bytes = loadTestAsset('Props/AC_units/ac_unit_a_300x300.glb');
      final provider = FilamentMaterialProvider.createUbershader(engine: engine);
      final loader = FilamentAssetLoader.create(engine: engine, materialProvider: provider);
      final asset = loader.createAsset(bytes)!;
      final resources = FilamentResourceLoader.create(engine: engine)..registerDefaultProviders(engine);
      resources.loadResources(asset);
      asset.addToScene(scene);
      view.temporalAntiAliasingOptions = const TemporalAntiAliasingOptions(motionVectors: true);
      final tm = FilamentTransformManager(engine);

      (double, double, double) measure(int frames) {
        engine.flushAndWait();
        final before = renderer.getPresentTimes(1024);
        final start = before.isEmpty ? 0 : before.last;
        var rendered = 0;
        final clock = Stopwatch()..start();
        for (var i = 0; rendered < frames && i < frames * 20; i++) {
          window.pump();
          tm.setTransform(asset.rootEntity, [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0.002 * i, 0, 0, 1]);
          final until = clock.elapsedMicroseconds + 33000;
          while (clock.elapsedMicroseconds < until) {}
          if (renderer.beginFrame(swapChain)) {
            renderer.render(view);
            renderer.endFrame();
            rendered++;
          }
        }
        engine.flushAndWait();
        final times = renderer.getPresentTimes(1024).where((t) => t > start).toList();
        final intervals = [for (var i = 1; i < times.length; i++) (times[i] - times[i - 1]) / 1e6];
        final mean = intervals.reduce((a, b) => a + b) / intervals.length;
        final sd = math.sqrt(intervals.map((x) => (x - mean) * (x - mean)).reduce((a, b) => a + b) / intervals.length);
        return (1000 / mean, sd / mean, times.length / rendered);
      }

      try {
        final probe = DlssFrameGeneration.probe(engine);
        if (probe == null || !probe.available) {
          markTestSkipped('Frame Generation not available here: $probe');
          return;
        }
        measure(20);
        final off = measure(100);
        smokeLog('window, frame generation off: ${off.$1.toStringAsFixed(1)} presents/s, cv ${off.$2.toStringAsFixed(2)}');
        for (final generated in [1, 3, 5]) {
          if (generated > probe.multiFrameCountMax) continue;
          final generator = DlssFrameGenerator.create(engine: engine, view: view, generatedFrames: generated);
          try {
            measure(20);
            final on = measure(100);
            smokeLog('window, ${generated + 1}x: ${on.$1.toStringAsFixed(1)} presents/s, cv ${on.$2.toStringAsFixed(2)}, '
                '${on.$3.toStringAsFixed(2)} per rendered frame (${(on.$1 / off.$1).toStringAsFixed(2)}x)');
            expect(on.$3, closeTo(generated + 1, 0.05), reason: '${generated + 1} presents per rendered frame');
            expect(on.$1, greaterThan(off.$1 * 1.6), reason: 'more presents per second than off');
            expect(on.$2, lessThan(0.35), reason: 'evenly paced');
          } finally {
            generator.destroy();
          }
        }
      } finally {
        engine.flushAndWait();
        asset.removeFromScene(scene);
        loader.destroyAsset(asset);
        resources.dispose();
        loader.dispose();
        provider.dispose();
        engine.destroyEntity(sun);
        view.dispose();
        scene.dispose();
        camera.dispose();
        engine.destroyEntity(cameraEntity);
        renderer.dispose();
        swapChain.dispose();
        engine.dispose();
        window.close();
        Dlss.clearExtensionRequest();
        DlssFrameGeneration.clearExtensionRequest();
      }
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}

/// A plain top-level Win32 window (the predefined STATIC class, so no window
/// procedure is needed) for a real Vulkan swap chain.
class _NativeWindow {
  _NativeWindow._(this.hwnd, this._msg);

  final ffi.Pointer<ffi.Void> hwnd;
  final ffi.Pointer<ffi.Uint8> _msg;

  static final _user32 = ffi.DynamicLibrary.open('user32.dll');
  static final _create = _user32.lookupFunction<
      ffi.Pointer<ffi.Void> Function(ffi.Uint32, ffi.Pointer<Utf16>, ffi.Pointer<Utf16>, ffi.Uint32, ffi.Int32,
          ffi.Int32, ffi.Int32, ffi.Int32, ffi.Pointer<ffi.Void>, ffi.Pointer<ffi.Void>, ffi.Pointer<ffi.Void>,
          ffi.Pointer<ffi.Void>),
      ffi.Pointer<ffi.Void> Function(int, ffi.Pointer<Utf16>, ffi.Pointer<Utf16>, int, int, int, int, int,
          ffi.Pointer<ffi.Void>, ffi.Pointer<ffi.Void>, ffi.Pointer<ffi.Void>, ffi.Pointer<ffi.Void>)>('CreateWindowExW');
  static final _destroy = _user32.lookupFunction<ffi.Int32 Function(ffi.Pointer<ffi.Void>),
      int Function(ffi.Pointer<ffi.Void>)>('DestroyWindow');
  static final _peek = _user32.lookupFunction<
      ffi.Int32 Function(ffi.Pointer<ffi.Uint8>, ffi.Pointer<ffi.Void>, ffi.Uint32, ffi.Uint32, ffi.Uint32),
      int Function(ffi.Pointer<ffi.Uint8>, ffi.Pointer<ffi.Void>, int, int, int)>('PeekMessageW');
  static final _clientRect = _user32.lookupFunction<ffi.Int32 Function(ffi.Pointer<ffi.Void>, ffi.Pointer<ffi.Int32>),
      int Function(ffi.Pointer<ffi.Void>, ffi.Pointer<ffi.Int32>)>('GetClientRect');
  static final _dispatch = _user32.lookupFunction<ffi.IntPtr Function(ffi.Pointer<ffi.Uint8>),
      int Function(ffi.Pointer<ffi.Uint8>)>('DispatchMessageW');

  static _NativeWindow open(int width, int height, String title) {
    const wsOverlappedWindow = 0x00CF0000, wsVisible = 0x10000000;
    final cls = 'STATIC'.toNativeUtf16();
    final name = title.toNativeUtf16();
    try {
      final hwnd = _create(0, cls, name, wsOverlappedWindow | wsVisible, 100, 100, width, height, ffi.nullptr,
          ffi.nullptr, ffi.nullptr, ffi.nullptr);
      if (hwnd == ffi.nullptr) throw StateError('CreateWindowExW failed');
      return _NativeWindow._(hwnd, calloc<ffi.Uint8>(64));
    } finally {
      calloc.free(cls);
      calloc.free(name);
    }
  }

  /// The size of the client area (what the swap chain covers).
  (int, int) get clientSize {
    final rect = calloc<ffi.Int32>(4);
    try {
      _clientRect(hwnd, rect);
      return (rect[2] - rect[0], rect[3] - rect[1]);
    } finally {
      calloc.free(rect);
    }
  }

  /// Handles the pending messages of the window.
  void pump() {
    const pmRemove = 1;
    while (_peek(_msg, ffi.nullptr, 0, 0, pmRemove) != 0) {
      _dispatch(_msg);
    }
  }

  void close() {
    _destroy(hwnd);
    calloc.free(_msg);
  }
}
